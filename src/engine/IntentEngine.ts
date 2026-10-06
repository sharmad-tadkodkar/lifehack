import type { Action, Bonus, Rule, Scenario, Step } from './types';

// Local, offline interpreter: transcript -> what the player meant, relative to
// where they are in the scenario. Kept behind this one function so an LLM-based
// interpreter can replace it later without touching the game loop.

export type Interpretation =
  | { kind: 'advance'; chain: number[]; skipped?: number }
  | { kind: 'wrong'; action: Action }
  | { kind: 'early'; step: Step; response: string; delta: Action['delta'] }
  | { kind: 'neutral'; action: Action }
  | { kind: 'already' }
  | { kind: 'avoided'; action: Action }
  | { kind: 'unclear' };

export interface InterpretContext {
  current: number;
  usedNeutral: Set<string>;
}

const NEGATIONS = /\b(don'?t|do not|not|never|no|without|won'?t|wouldn'?t|shouldn'?t|avoid|instead of|rather than|skip)\b/;

export function normalize(text: string): string {
  return ' ' + text
    .toLowerCase()
    .replace(/[’‘`]/g, "'")
    .replace(/lugnut/g, 'lug nut')
    .replace(/\b(don'?t|do not|never) forget( to)?\b/g, ' ')
    .replace(/\bmake sure( to)?\b/g, ' ')
    .replace(/[^a-z0-9' ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim() + ' ';
}

const termCache = new Map<string, RegExp>();
function termRegex(term: string): RegExp {
  let re = termCache.get(term);
  if (!re) {
    const whole = term.endsWith('$');
    const body = (whole ? term.slice(0, -1) : term).replace(/[.*+?^${}()[\]\\]/g, '\\$&');
    re = new RegExp(` ${body}${whole ? "(?=[ '])" : ''}`, 'g');
    termCache.set(term, re);
  }
  re.lastIndex = 0;
  return re;
}

function isNegated(text: string, index: number): boolean {
  // Look back at most three words, within the same clause.
  const before = text.slice(0, index).split(/ (?:and|then|but|so) /).pop() ?? '';
  const words = before.trim().split(' ').slice(-3).join(' ');
  return NEGATIONS.test(words);
}

/** 'hit' = matched affirmatively, 'negated' = only matched under negation. */
function groupMatch(text: string, group: string, ignoreNeg: boolean): 'hit' | 'negated' | 'miss' {
  let negated = false;
  for (const term of group.split('|')) {
    const re = termRegex(term);
    let m: RegExpExecArray | null;
    while ((m = re.exec(text))) {
      if (ignoreNeg || !isNegated(text, m.index)) return 'hit';
      negated = true;
    }
  }
  return negated ? 'negated' : 'miss';
}

export function matchRules(text: string, rules: Rule[], ignoreNeg = false): 'hit' | 'negated' | 'miss' {
  let negated = false;
  for (const rule of rules) {
    const results = rule.map(g => groupMatch(text, g, ignoreNeg));
    if (results.every(r => r === 'hit')) return 'hit';
    if (results.every(r => r !== 'miss')) negated = true;
  }
  return negated ? 'negated' : 'miss';
}

export function matchBonuses(text: string, bonuses: Bonus[] = []): Bonus[] {
  return bonuses.filter(b => matchRules(text, b.rules) === 'hit');
}

function isActive(a: Action, scenario: Scenario, current: number): boolean {
  const idx = (id?: string) => scenario.steps.findIndex(s => s.id === id);
  if (a.from && current < idx(a.from)) return false;
  if (a.until && current > idx(a.until)) return false;
  return true;
}

export function interpret(rawText: string, scenario: Scenario, ctx: InterpretContext): Interpretation {
  const text = normalize(rawText);
  const { steps } = scenario;
  const { current } = ctx;

  const stepHits = new Set<number>();
  steps.forEach((s, i) => {
    if (matchRules(text, s.rules) === 'hit') stepHits.add(i);
  });

  const active = scenario.wrongActions.filter(a => isActive(a, scenario, current));
  const wrongHit = (priority: boolean) =>
    active.find(a => !!a.priority === priority && matchRules(text, a.rules, a.ignoreNegation) === 'hit');

  // 1. Dangerous / very specific mistakes override everything.
  const urgent = wrongHit(true);
  if (urgent) return { kind: 'wrong', action: urgent };

  // 2. The current step (plus any consecutive steps said in one breath).
  const chainFrom = (start: number) => {
    const chain: number[] = [];
    for (let j = start; stepHits.has(j); j++) chain.push(j);
    return chain;
  };
  if (stepHits.has(current)) return { kind: 'advance', chain: chainFrom(current) };
  if (steps[current]?.optional && stepHits.has(current + 1)) {
    return { kind: 'advance', chain: chainFrom(current + 1), skipped: current };
  }

  // 3. Ordinary wrong moves.
  const wrong = wrongHit(false);
  if (wrong) return { kind: 'wrong', action: wrong };

  // 4. Sensible side actions (once each), e.g. "grab the jack from the trunk".
  const neutral = scenario.neutralActions.find(
    a => !ctx.usedNeutral.has(a.id) && matchRules(text, a.rules) === 'hit',
  );
  if (neutral) return { kind: 'neutral', action: neutral };

  // 5. Right idea, wrong time.
  const future = [...stepHits].filter(i => i > current).sort((a, b) => a - b)[0];
  if (future !== undefined) {
    return earlyAttempt(scenario, future, current);
  }

  if ([...stepHits].some(i => i < current)) return { kind: 'already' };

  const avoided = active.find(a => !a.ignoreNegation && matchRules(text, a.rules) === 'negated');
  if (avoided) return { kind: 'avoided', action: avoided };

  return { kind: 'unclear' };
}

/** The response for attempting step `idx` while `current` is the active step. */
export function earlyAttempt(scenario: Scenario, idx: number, current: number): Interpretation & { kind: 'early' } {
  const { steps } = scenario;
  const step = steps[idx];
  const early = step.tooEarly?.find(e => !e.before || current <= steps.findIndex(s => s.id === e.before));
  return {
    kind: 'early',
    step,
    response: early?.response ?? pick(GENERIC_EARLY),
    delta: early?.delta ?? { sequence: -1.5 },
  };
}

const GENERIC_EARLY = [
  "Right idea, wrong moment. What has to happen before that?",
  "You're skipping ahead. The tire respects ambition, not shortcuts.",
  "Close, but not yet. Something comes first.",
];

export function pick<T>(list: T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}
