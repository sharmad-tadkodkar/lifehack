import type { Scenario } from '../engine/types';
import { flatTire } from './flatTire/scenario';

// Register new scenarios here.
export const scenarios: Scenario[] = [flatTire];
