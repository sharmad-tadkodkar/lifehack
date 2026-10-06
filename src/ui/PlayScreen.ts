import { gsap } from 'gsap';
import { h, ICONS, escapeHtml } from './dom';
import { CATEGORY_LABEL, CATEGORIES, type ScoreDelta } from '../engine/types';

export type MicState = 'idle' | 'ready' | 'listening' | 'busy' | 'off';

export interface PlayHandlers {
  onMic(): void;
  onChoice(id: string, label: string): void;
  onText(text: string): void;
  onToggleVoice(): boolean;
  onToggleSound(): boolean;
}

export interface Choice {
  id: string;
  label: string;
  struck?: boolean;
}

export class PlayScreen {
  readonly el: HTMLElement;
  readonly sceneEl: HTMLElement;
  private log: HTMLElement;
  private mic: HTMLButtonElement;
  private micLabel: HTMLElement;
  private interim: HTMLElement;
  private choicesEl: HTMLElement;
  private toasts: HTMLElement;
  private canvas: HTMLCanvasElement;
  private progressBar: HTMLElement;
  private level = 0;
  private shownLevel = 0;
  private raf = 0;
  private typing: { finish(): void } | null = null;
  private state: MicState = 'idle';
  private handlers: PlayHandlers;

  constructor(app: HTMLElement, meta: { number: string; title: string; objective: string }, handlers: PlayHandlers) {
    this.handlers = handlers;
    this.el = h('section', { class: 'screen play' }, `
      <header class="hud">
        <div class="brand">Oh S<span class="hash">#</span>IT</div>
        <div class="objective">
          <div class="objective-text"><span class="tag">Scenario ${meta.number} · ${escapeHtml(meta.title)}</span><span class="goal">${escapeHtml(meta.objective)}</span></div>
          <div class="progress" role="progressbar" aria-label="Repair progress"><i></i></div>
        </div>
        <div class="toggles">
          <button class="toggle on" data-t="voice" title="Narrator voice" aria-label="Toggle narrator voice">${ICONS.voice}</button>
          <button class="toggle on" data-t="sound" title="Sound effects" aria-label="Toggle sound effects">${ICONS.sound}</button>
        </div>
      </header>
      <div class="stage">
        <div class="scene"></div>
        <div class="vignette"></div>
        <div class="toasts"></div>
      </div>
      <aside class="panel">
        <div class="log" aria-live="polite"></div>
        <div class="mic-zone">
          <div class="interim"></div>
          <div class="mic-wrap">
            <canvas width="240" height="240"></canvas>
            <button class="mic" type="button" aria-label="Speak your answer">${ICONS.mic}</button>
          </div>
          <div class="mic-label">Tap to speak</div>
        </div>
        <div class="fallback">
          <div class="fallback-head"><span>Or choose</span><span class="fallback-note">Spoken answers earn full Knowledge points</span></div>
          <div class="choices"></div>
          <form class="type-form" autocomplete="off">
            ${ICONS.keyboard}
            <input type="text" placeholder="…or type what you'd do" aria-label="Type your answer" enterkeyhint="send" />
          </form>
        </div>
      </aside>
    `);
    app.replaceChildren(this.el);

    const q = <T extends Element>(s: string) => this.el.querySelector(s) as T;
    this.sceneEl = q('.scene');
    this.log = q('.log');
    this.mic = q('.mic');
    this.micLabel = q('.mic-label');
    this.interim = q('.interim');
    this.choicesEl = q('.choices');
    this.toasts = q('.toasts');
    this.canvas = q('canvas');
    this.progressBar = q('.progress i');

    this.mic.addEventListener('click', () => handlers.onMic());
    this.el.querySelectorAll<HTMLButtonElement>('.toggle').forEach(b =>
      b.addEventListener('click', () => {
        const on = b.dataset.t === 'voice' ? handlers.onToggleVoice() : handlers.onToggleSound();
        b.classList.toggle('on', on);
      }),
    );
    const form = q<HTMLFormElement>('.type-form');
    form.addEventListener('submit', e => {
      e.preventDefault();
      const input = form.querySelector('input')!;
      const v = input.value.trim();
      if (v) handlers.onText(v);
      input.value = '';
    });

    gsap.from(this.el.querySelector('.hud'), { y: -20, opacity: 0, duration: 0.8, ease: 'power3.out' });
    gsap.from(this.el.querySelector('.panel'), { y: 30, opacity: 0, duration: 0.9, delay: 0.2, ease: 'power3.out' });
    gsap.from(this.sceneEl, { opacity: 0, duration: 1.2 });

    this.loop();
  }

  /** Narrator line, typed out. Resolves when typing completes. */
  narrate(text: string, opts: { kind?: 'good' | 'bad' | 'neutral' } = {}): Promise<void> {
    this.typing?.finish();
    const row = h('div', { class: `line narrator ${opts.kind ?? ''}` }, `<span class="who">Narrator</span><p></p>`);
    this.push(row);
    const p = row.querySelector('p')!;
    return new Promise(resolve => {
      let i = 0;
      let timer = 0;
      const finish = () => {
        clearInterval(timer);
        p.textContent = text;
        this.typing = null;
        this.scrollLog();
        resolve();
      };
      this.typing = { finish };
      timer = window.setInterval(() => {
        i += 2;
        p.textContent = text.slice(0, i);
        if (i % 20 === 0) this.scrollLog();
        if (i >= text.length) finish();
      }, 28);
    });
  }

  finishTyping() {
    this.typing?.finish();
  }

  player(text: string, source: 'voice' | 'choice' | 'text') {
    const icon = source === 'voice' ? ICONS.mic : source === 'text' ? ICONS.keyboard : '';
    const row = h('div', { class: `line player ${source}` }, `<p>${icon}<span>${escapeHtml(text)}</span></p>`);
    this.push(row);
  }

  private push(row: HTMLElement) {
    this.log.append(row);
    const rows = this.log.querySelectorAll('.line');
    if (rows.length > 14) rows[0].remove();
    this.log.querySelectorAll('.line').forEach((r, i, all) => r.classList.toggle('old', i < all.length - 4));
    gsap.from(row, { opacity: 0, y: 12, duration: 0.4, ease: 'power2.out' });
    this.scrollLog();
  }

  private scrollLog() {
    this.log.scrollTo({ top: this.log.scrollHeight, behavior: 'smooth' });
  }

  setMicState(state: MicState, label?: string) {
    this.state = state;
    this.mic.dataset.state = state;
    this.mic.innerHTML = state === 'listening' ? ICONS.stop : ICONS.mic;
    this.mic.disabled = state === 'off';
    const labels: Record<MicState, string> = {
      idle: 'Tap to interrupt',
      ready: matchMedia('(pointer: fine)').matches ? 'Your move · tap or hold Space' : 'Your move · tap to speak',
      listening: 'Listening… tap when done',
      busy: '…',
      off: 'Voice unavailable here',
    };
    this.micLabel.textContent = label ?? labels[state];
    if (state !== 'listening') this.level = 0;
  }

  setInterim(text: string) {
    this.interim.textContent = text;
    this.interim.classList.toggle('show', !!text);
  }

  setLevel(l: number) {
    this.level = l;
  }

  setChoices(choices: Choice[]) {
    this.choicesEl.innerHTML = '';
    choices.forEach((c, i) => {
      const b = h('button', { type: 'button', class: 'choice' + (c.struck ? ' struck' : '') }, `<span class="k">${String.fromCharCode(65 + i)}</span><span>${escapeHtml(c.label)}</span>`);
      b.disabled = !!c.struck;
      b.addEventListener('click', () => this.handlers.onChoice(c.id, c.label));
      this.choicesEl.append(b);
    });
    gsap.from(this.choicesEl.children, { opacity: 0, y: 8, stagger: 0.05, duration: 0.35, ease: 'power2.out' });
  }

  setInputsEnabled(on: boolean) {
    this.el.classList.toggle('locked', !on);
  }

  setProgress(fraction: number) {
    gsap.to(this.progressBar, { width: `${Math.round(fraction * 100)}%`, duration: 0.8, ease: 'power2.out' });
  }

  emphasizeFallback(message: string) {
    this.el.classList.add('no-voice');
    this.setMicState('off', message);
  }

  toast(delta: ScoreDelta, extra?: string) {
    const items: string[] = [];
    for (const c of CATEGORIES) {
      const v = delta[c];
      if (!v) continue;
      items.push(`<span class="chip ${v > 0 ? 'up' : 'down'}">${v > 0 ? '+' : '−'} ${CATEGORY_LABEL[c]}</span>`);
    }
    if (extra) items.unshift(`<span class="chip note">${escapeHtml(extra)}</span>`);
    if (!items.length) return;
    const t = h('div', { class: 'toast' }, items.join(''));
    this.toasts.append(t);
    gsap.timeline({ onComplete: () => t.remove() })
      .from(t.children, { opacity: 0, y: 14, scale: 0.9, stagger: 0.07, duration: 0.35, ease: 'back.out(2)' })
      .to(t, { opacity: 0, y: -12, duration: 0.5, delay: 2.2 });
  }

  coach(text: string) {
    const c = h('div', { class: 'coach' }, escapeHtml(text));
    this.el.querySelector('.mic-wrap')!.append(c);
    gsap.fromTo(c, { opacity: 0, y: 6 }, { opacity: 1, y: 0, duration: 0.4 });
    const remove = () => gsap.to(c, { opacity: 0, duration: 0.3, onComplete: () => c.remove() });
    setTimeout(remove, 5000);
    this.mic.addEventListener('click', remove, { once: true });
  }

  // Radial waveform around the mic.
  private loop = () => {
    const ctx = this.canvas.getContext('2d')!;
    const { width: w, height: hgt } = this.canvas;
    this.shownLevel += (this.level - this.shownLevel) * 0.25;
    ctx.clearRect(0, 0, w, hgt);
    const cx = w / 2;
    const cy = hgt / 2;
    const bars = 56;
    const t = performance.now() / 1000;
    const listening = this.state === 'listening';
    const ready = this.state === 'ready';
    for (let i = 0; i < bars; i++) {
      const a = (i / bars) * Math.PI * 2;
      const wobble = Math.sin(a * 3 + t * 4) * 0.5 + Math.sin(a * 7 - t * 6) * 0.5;
      const amp = listening ? 6 + this.shownLevel * 38 * (0.6 + 0.4 * wobble) : ready ? 4 + 3 * Math.sin(t * 3 + i * 0.4) : 2.5;
      const r0 = 62;
      const x0 = cx + Math.cos(a) * r0;
      const y0 = cy + Math.sin(a) * r0;
      const x1 = cx + Math.cos(a) * (r0 + Math.max(2, amp));
      const y1 = cy + Math.sin(a) * (r0 + Math.max(2, amp));
      ctx.strokeStyle = listening ? `rgba(255,90,54,${0.55 + this.shownLevel * 0.45})` : ready ? 'rgba(255,90,54,.45)' : 'rgba(242,239,233,.16)';
      ctx.lineWidth = 3;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(x0, y0);
      ctx.lineTo(x1, y1);
      ctx.stroke();
    }
    this.raf = requestAnimationFrame(this.loop);
  };

  destroy() {
    cancelAnimationFrame(this.raf);
    this.typing?.finish();
  }
}
