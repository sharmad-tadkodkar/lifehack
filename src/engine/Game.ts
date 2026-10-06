import { Voice } from './Voice';
import { sfx } from './Audio';
import { Scoring, diagnose } from './Scoring';
import { interpret, earlyAttempt, matchBonuses, matchRules, normalize, pick, type Interpretation } from './IntentEngine';
import { CATEGORIES, type Scenario, type SceneController, type ScoreDelta } from './types';
import { PlayScreen, type Choice } from '../ui/PlayScreen';
import { renderTitle } from '../ui/TitleScreen';
import { renderResult } from '../ui/ResultScreen';

type Source = 'voice' | 'choice' | 'text';

const UNCLEAR = [
  "Not sure the tire understood that. Neither did I. Try again?",
  "Interesting. Wrong genre. What's the actual move?",
  "Say that again, but like someone who's changed a tire before.",
  "The tire stares at you, unmoved. What do you do?",
];
const RETRY = ['So what do you do instead?', "What's the actual move?", 'Try again.', 'Okay. And instead?'];
const ALREADY = ['Already done. The car appreciates the enthusiasm.', 'Done that. Keep moving.'];
const AVOIDED = ["Correct. Don't do that. But what WILL you do?", "Good call not doing that. So what's the move?"];
const QUICK_MS = 6000;
const NUMBER_WORDS = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six'];

const scale = (d: ScoreDelta, f: number): ScoreDelta =>
  Object.fromEntries(Object.entries(d).map(([k, v]) => [k, (v as number) * (v! > 0 ? f : 1)]));

const merge = (a: ScoreDelta, b: ScoreDelta): ScoreDelta => {
  const out: ScoreDelta = { ...a };
  for (const c of CATEGORIES) if (b[c]) out[c] = (out[c] ?? 0) + b[c]!;
  return out;
};

const wait = (ms: number) => new Promise(r => setTimeout(r, ms));

export class Game {
  private app: HTMLElement;
  private voice = new Voice();
  private voiceBlocked = false;

  // round state
  private s!: Scenario;
  private screen!: PlayScreen;
  private scene!: SceneController;
  private scoring!: Scoring;
  private current = 0;
  private misses = 0;
  private busy = true;
  private pendingListen = false;
  private usedNeutral = new Set<string>();
  private struck = new Set<string>();
  private choiceOrder: Choice[] = [];
  private readyAt = 0;
  private startedAt = 0;
  private answers = 0;
  private spoken = 0;

  constructor(app: HTMLElement) {
    this.app = app;
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
  }

  showTitle(scenario: Scenario) {
    renderTitle(
      this.app,
      () => {
        sfx.unlock();
        this.voice.unlock();
      },
      () => this.play(scenario),
    );
  }

  async play(scenario: Scenario) {
    this.s = scenario;
    this.scoring = new Scoring(scenario.possible);
    this.current = 0;
    this.misses = 0;
    this.answers = 0;
    this.spoken = 0;
    this.busy = true;
    this.usedNeutral.clear();
    this.struck.clear();

    this.screen = new PlayScreen(this.app, scenario, {
      onMic: () => this.onMic(),
      onChoice: (id, label) => this.onChoice(id, label),
      onText: text => this.handle(text, 'text'),
      onToggleVoice: () => {
        this.voice.muted = !this.voice.muted;
        if (this.voice.muted) this.voice.stopSpeaking();
        return !this.voice.muted;
      },
      onToggleSound: () => {
        sfx.setMuted(!sfx.muted);
        return !sfx.muted;
      },
    });
    this.screen.setInputsEnabled(false);
    this.screen.setMicState('busy', 'Hold on…');
    if (!this.voice.canListen) this.screen.emphasizeFallback('Voice input not supported here. Choose or type below.');
    else if (this.voiceBlocked) this.screen.emphasizeFallback('Mic blocked. Choose or type below.');

    this.scene = scenario.createScene();
    this.scene.mount(this.screen.sceneEl);
    sfx.startAmbience(() => this.scene.playReaction('carPass'));

    await wait(500);
    await this.scene.intro();
    this.startedAt = performance.now();
    this.refreshChoices(true);
    await this.say(scenario.intro);
    if (this.voice.canListen && !this.voiceBlocked) this.screen.coach("Tap and say what you'd do, like you'd tell a friend.");
    this.ready();
  }

  // ---------- turn plumbing ----------

  private async say(text: string, kind?: 'good' | 'bad' | 'neutral') {
    if (!this.voiceBlocked && this.voice.canListen) this.screen.setMicState('idle');
    await Promise.all([this.screen.narrate(text, { kind }), this.voice.speak(text)]);
  }

  private ready() {
    this.busy = false;
    this.readyAt = performance.now();
    this.screen.setInputsEnabled(true);
    if (this.voice.canListen && !this.voiceBlocked) this.screen.setMicState('ready');
    if (this.pendingListen) {
      this.pendingListen = false;
      this.startListening();
    }
  }

  private onMic() {
    if (this.voice.listening) {
      this.voice.finish();
      return;
    }
    if (this.busy) {
      // Interrupt the narrator; start listening as soon as the turn settles.
      this.voice.stopSpeaking();
      this.screen.finishTyping();
      this.pendingListen = true;
      return;
    }
    this.startListening();
  }

  private onKeyDown = (e: KeyboardEvent) => {
    if (e.code !== 'Space' || e.repeat) return;
    const t = e.target as HTMLElement;
    if (t.closest('input, textarea, button') || !this.screen?.el.isConnected) return;
    e.preventDefault();
    if (!this.voice.listening) this.onMic();
  };

  private onKeyUp = (e: KeyboardEvent) => {
    if (e.code === 'Space' && this.voice.listening) this.voice.finish();
  };

  private async startListening() {
    if (!this.voice.canListen || this.voiceBlocked) return;
    this.screen.finishTyping();
    this.screen.setMicState('listening');
    this.screen.setInterim('');
    const pressedAt = performance.now();
    let text = '';
    try {
      text = await this.voice.listen({
        onInterim: t => {
          this.screen.setInterim(t);
          this.highlightFrom(t);
        },
        onLevel: l => this.screen.setLevel(l),
      });
    } catch (err) {
      this.screen.setInterim('');
      if (err === 'not-allowed') {
        this.voiceBlocked = true;
        this.screen.emphasizeFallback('Mic blocked. Choose or type below.');
      } else if (err === 'network') {
        this.voiceBlocked = true;
        this.screen.emphasizeFallback('Voice service unreachable. Choose or type below.');
      } else {
        this.screen.setMicState('ready', "Didn't catch that. Tap and try again.");
      }
      return;
    }
    this.screen.setInterim('');
    if (!text) {
      this.screen.setMicState('ready', "Didn't catch that. Tap and try again.");
      return;
    }
    this.handle(text, 'voice', pressedAt - this.readyAt);
  }

  private highlightFrom(t: string) {
    const n = normalize(t);
    for (const [pattern, key] of this.s.highlights) {
      if (matchRules(n, [[pattern]]) === 'hit') this.scene.highlight(key);
    }
  }

  private refreshChoices(newStep: boolean) {
    const step = this.s.steps[this.current];
    if (!step) return;
    if (newStep) {
      this.choiceOrder = [{ id: step.id, label: step.choice }, ...step.distractors.map(d => ({ id: d.action, label: d.label }))]
        .sort(() => Math.random() - 0.5);
    }
    this.screen.setChoices(this.choiceOrder.map(c => ({ ...c, struck: this.struck.has(c.id) })));
  }

  // ---------- input -> interpretation ----------

  private handle(text: string, source: Source, latencyMs = Infinity) {
    if (this.busy) return;
    this.begin(text, source);
    this.resolve(interpret(text, this.s, { current: this.current, usedNeutral: this.usedNeutral }), source, text, latencyMs);
  }

  private onChoice(id: string, label: string) {
    if (this.busy) return;
    const step = this.s.steps[this.current];
    let r: Interpretation;
    if (id === step.id) r = { kind: 'advance', chain: [this.current] };
    else if (id.startsWith('@')) r = earlyAttempt(this.s, this.s.steps.findIndex(s => s.id === id.slice(1)), this.current);
    else r = { kind: 'wrong', action: this.s.wrongActions.find(a => a.id === id)! };
    if (id !== step.id) this.struck.add(id);
    this.begin(label, 'choice');
    this.resolve(r, 'choice');
  }

  private begin(text: string, source: Source) {
    this.busy = true;
    this.voice.stopSpeaking();
    this.screen.setInputsEnabled(false);
    this.screen.setMicState('busy');
    this.screen.player(text, source);
    this.answers++;
    if (source === 'voice') this.spoken++;
  }

  private async resolve(r: Interpretation, source: Source, text = '', latencyMs = Infinity) {
    switch (r.kind) {
      case 'advance': {
        let prefix = '';
        if (r.skipped !== undefined) {
          const opt = this.s.steps[r.skipped].optional!;
          this.scoring.apply(opt.skipDelta);
          this.screen.toast(opt.skipDelta);
          prefix = opt.skipResponse + ' ';
        }
        const quick = source === 'voice' && latencyMs < QUICK_MS && this.misses === 0;
        return this.advance(r.chain, { source, text, prefix, quick, factor: this.misses >= 2 ? 0.6 : 1 });
      }
      case 'wrong': {
        const a = r.action;
        this.penalize(a.delta);
        if (a.scene) this.scene.playReaction(a.scene);
        return this.miss(pick(a.response));
      }
      case 'early':
        this.penalize(r.delta);
        return this.miss(r.response);
      case 'neutral': {
        this.usedNeutral.add(r.action.id);
        this.scoring.apply(r.action.delta);
        this.screen.toast(r.action.delta);
        sfx.pop();
        await this.say(`${pick(r.action.response)} So, what's next?`, 'neutral');
        return this.ready();
      }
      case 'already':
        await this.say(`${pick(ALREADY)} ${pick(this.s.steps[this.current].ask)}`, 'neutral');
        return this.ready();
      case 'avoided':
        await this.say(pick(AVOIDED), 'neutral');
        return this.ready();
      case 'unclear':
        return this.miss(pick(UNCLEAR), false);
    }
  }

  private penalize(delta: ScoreDelta) {
    this.scoring.apply(delta);
    const negative = Object.values(delta).some(v => (v as number) < 0);
    if (negative) {
      this.scoring.mistakes++;
      sfx.bad();
    }
    this.screen.toast(delta);
  }

  private async miss(line: string, counts = true) {
    this.misses++;
    const step = this.s.steps[this.current];
    if (this.misses >= 3) {
      // Keep the round moving: reveal the answer for reduced credit.
      this.scoring.hintsUsed++;
      return this.advance([this.current], { source: 'choice', text: '', prefix: `${line} Here's the move: ${step.reveal} `, factor: 0.25, revealed: true });
    }
    if (this.misses === 2) {
      this.scoring.hintsUsed++;
      line += ` Hint: ${step.hint}`;
    } else {
      line += ' ' + pick(RETRY);
    }
    this.refreshChoices(false);
    await this.say(line, counts ? 'bad' : 'neutral');
    this.ready();
  }

  private async advance(
    chain: number[],
    o: { source: Source; text: string; prefix: string; factor: number; quick?: boolean; revealed?: boolean },
  ) {
    const kf = o.source === 'choice' ? 0.75 : 1;
    const norm = normalize(o.text);
    let shown: ScoreDelta = {};
    const notes: string[] = [];

    for (const idx of chain) {
      const step = this.s.steps[idx];
      this.scoring.apply(step.delta, o.factor, kf);
      shown = merge(shown, scale(step.delta, o.factor));
      if (o.revealed) continue;
      const bonuses = o.source === 'choice' ? [] : matchBonuses(norm, step.bonuses);
      for (const b of bonuses) {
        this.scoring.apply(b.delta);
        shown = merge(shown, b.delta);
        if (b.note) notes.push(b.note);
      }
      if (!bonuses.length && step.missingNote) notes.push(step.missingNote);
    }
    let extra: string | undefined;
    if (o.quick) {
      this.scoring.apply({ safety: 0.5 });
      extra = 'Quick thinking';
    }
    if (!o.revealed) sfx.good();
    this.screen.toast(shown, extra);

    const last = this.s.steps[chain[chain.length - 1]];
    let line = o.prefix;
    if (!o.revealed) {
      line += chain.length > 1 ? `${NUMBER_WORDS[chain.length] ?? chain.length} steps in one breath. ${pick(last.success)}` : pick(last.success);
      if (notes.length) line += ' ' + notes.slice(0, 2).join(' ');
    }

    this.current = chain[chain.length - 1] + 1;
    this.misses = 0;
    this.struck.clear();
    this.screen.setProgress(this.current / this.s.steps.length);

    const finished = this.current >= this.s.steps.length;
    if (!finished) {
      line += ' ' + pick(this.s.steps[this.current].ask);
      this.refreshChoices(true);
    }

    const animate = (async () => {
      for (const idx of chain) await this.scene.playStep(this.s.steps[idx].id);
    })();
    await Promise.all([this.say(line.trim(), o.revealed ? 'neutral' : 'good'), animate]);

    if (finished) return this.finish();
    this.ready();
  }

  private async finish() {
    this.screen.setMicState('busy', '');
    await wait(400);
    await this.say(this.s.outro, 'good');
    sfx.stopAmbience();
    await wait(600);

    const score = this.scoring.total();
    const diagnosis = diagnose(score, this.s.diagnoses);
    const data = {
      scenarioLabel: `Scenario ${this.s.number} · ${this.s.title}`,
      score,
      breakdown: this.scoring.breakdown(),
      diagnosis,
      seconds: (performance.now() - this.startedAt) / 1000,
      mistakes: this.scoring.mistakes,
      hints: this.scoring.hintsUsed,
      spoken: this.spoken,
      answers: this.answers,
    };
    this.screen.destroy();
    this.scene.destroy();
    renderResult(this.app, data, () => {
      this.voice.stopSpeaking();
      this.play(this.s);
    });
    await wait(2900);
    this.voice.speak(`Your Life I.Q. is ${score}. Diagnosis: ${diagnosis.title}. ${diagnosis.line}`);
  }
}
