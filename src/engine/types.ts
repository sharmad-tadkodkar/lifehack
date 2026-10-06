// Core data contracts. A scenario is pure data + a scene module, so new
// scenarios (dead battery, burst pipe, ...) plug in without engine changes.

export type Category = 'knowledge' | 'safety' | 'sequence' | 'resourcefulness';
export const CATEGORIES: Category[] = ['knowledge', 'safety', 'sequence', 'resourcefulness'];
export const CATEGORY_LABEL: Record<Category, string> = {
  knowledge: 'Knowledge',
  safety: 'Safety Judgment',
  sequence: 'Correct Sequence',
  resourcefulness: 'Resourcefulness',
};

export type ScoreDelta = Partial<Record<Category, number>>;

/**
 * A rule is a list of term groups. Every group must match (AND); within a group
 * terms are separated by "|" (OR). Terms match at a word start, so "nut" also
 * matches "nuts". A trailing "$" forces a whole-word match ("aa$").
 *   ["loosen|crack|break", "nut|bolt|lug"]
 */
export type Rule = string[];

export interface Bonus {
  rules: Rule[];
  delta: ScoreDelta;
  note: string;
}

export interface EarlyResponse {
  /** Applies while this step id has not been completed yet. */
  before?: string;
  response: string;
  delta: ScoreDelta;
}

export interface Step {
  id: string;
  rules: Rule[];
  /** The question the narrator asks when this step becomes current. */
  ask: string[];
  success: string[];
  delta: ScoreDelta;
  bonuses?: Bonus[];
  /** Spoken when the step is completed without any of its bonuses. */
  missingNote?: string;
  hint: string;
  reveal: string;
  /** Responses when the player tries this step too early (first matching wins). */
  tooEarly?: EarlyResponse[];
  optional?: { skipResponse: string; skipDelta: ScoreDelta };
  /** Fallback multiple choice: the correct label and plausible wrong action ids. */
  choice: string;
  distractors: { label: string; action: string }[];
}

export interface Action {
  id: string;
  rules: Rule[];
  response: string[];
  delta: ScoreDelta;
  /** Checked before the current step (dangerous or very specific mistakes). */
  priority?: boolean;
  /** Only active between these step ids (inclusive). */
  from?: string;
  until?: string;
  /** For phrasings that contain negation by nature ("skip the nuts"). */
  ignoreNegation?: boolean;
  /** Scene reaction key, e.g. "wobble". */
  scene?: string;
}

export interface Diagnosis {
  min: number;
  title: string;
  line: string;
}

export interface SceneController {
  mount(container: HTMLElement): void;
  intro(): Promise<void>;
  playStep(stepId: string): Promise<void>;
  playReaction(key: string): void;
  highlight(key: string): void;
  destroy(): void;
}

export interface Scenario {
  id: string;
  number: string;
  title: string;
  objective: string;
  intro: string;
  outro: string;
  steps: Step[];
  wrongActions: Action[];
  neutralActions: Action[];
  /** Points available per category; earned / possible scales to 25 each. */
  possible: Record<Category, number>;
  diagnoses: Diagnosis[];
  /** Live-transcript keyword -> scene highlight key. */
  highlights: [string, string][];
  createScene(): SceneController;
}
