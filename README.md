# Oh S#IT: The Life Skills Game

*When life breaks down, do you know how to fix it?*

A voice-first life skills game. Talk your way through a roadside flat tire; the narrator talks back.

```bash
npm install
npm run dev
```

Voice input uses the browser's Web Speech API (Chrome, Edge, Safari). Elsewhere the game falls back to multiple choice and typing.

## Structure

```
src/
  engine/
    Game.ts          turn loop: listen → interpret → score → animate → narrate
    IntentEngine.ts  local transcript interpreter (keyword groups, negation, multi-step chains)
    Scoring.ts       Life IQ: knowledge / safety / sequence / resourcefulness, 25 each
    Voice.ts         speech recognition, narrator TTS, mic level
    Audio.ts         synthesized sound effects + ambience
    types.ts         Scenario contract
  scenarios/
    index.ts         scenario registry
    flatTire/
      scenario.ts    steps, wrong answers, quips, scoring, diagnoses (pure data)
      scene.ts       SVG scene + per-step animations
  ui/                title, play and result screens
```

## Adding a scenario

1. Create `src/scenarios/<name>/scenario.ts` exporting a `Scenario` (see `engine/types.ts`).
2. Create `scene.ts` implementing `SceneController` (`intro`, `playStep(stepId)`, `playReaction`, `highlight`).
3. Register it in `src/scenarios/index.ts`.

Intent rules are lists of term groups: every group must match, terms within a group are `|`-separated and match at word starts (`"nut"` matches `"nuts"`; a trailing `$` forces a whole word).
