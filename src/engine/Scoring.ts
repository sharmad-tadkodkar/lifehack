import { CATEGORIES, type Category, type Diagnosis, type ScoreDelta } from './types';

// Life IQ: four categories worth 25 each. Positive points accumulate against
// what the scenario says is possible; penalties subtract from the same pool.

export class Scoring {
  private earned: Record<Category, number> = { knowledge: 0, safety: 0, sequence: 0, resourcefulness: 0 };
  private possible: Record<Category, number>;
  mistakes = 0;
  hintsUsed = 0;

  constructor(possible: Record<Category, number>) {
    this.possible = possible;
  }

  apply(delta: ScoreDelta, factor = 1, knowledgeFactor = 1) {
    for (const c of CATEGORIES) {
      const v = delta[c];
      if (!v) continue;
      // Scaling only shrinks rewards; penalties always land in full.
      const f = v > 0 ? factor * (c === 'knowledge' ? knowledgeFactor : 1) : 1;
      this.earned[c] += v * f;
    }
  }

  category(c: Category): number {
    return Math.max(0, Math.min(25, Math.round((25 * this.earned[c]) / this.possible[c])));
  }

  breakdown(): Record<Category, number> {
    return Object.fromEntries(CATEGORIES.map(c => [c, this.category(c)])) as Record<Category, number>;
  }

  total(): number {
    return CATEGORIES.reduce((sum, c) => sum + this.category(c), 0);
  }
}

export function diagnose(score: number, diagnoses: Diagnosis[]): Diagnosis {
  return [...diagnoses].sort((a, b) => b.min - a.min).find(d => score >= d.min) ?? diagnoses[diagnoses.length - 1];
}
