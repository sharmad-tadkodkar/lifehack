# Oh S#IT: The Life Skills Game

*When life breaks down, do you know how to fix it?*

**Oh S#IT** is an interactive learning game for the essential life skills nobody formally teaches you,
the moments where something goes wrong and you're the one who has to fix it. Instead of reading a
how-to or watching a video, you *do* the job: make the decisions, use the tools and see the consequences,
in a space where getting it wrong costs nothing but a laugh.

The first scenario is one almost every driver meets eventually: **a flat tire**. You learn not just the
steps but *why* they come in that order: crack the nuts loose while the tire still grips the ground, jack
at the right point, tighten in a star pattern so the wheel seats evenly. A mistake doesn't end the game.
It plays out a realistic consequence (the wheel just spins in the air, the car won't come down safely),
a narrator explains what went wrong with a bit of humour, and you try again. You finish knowing the
procedure well enough to do it at the roadside, at night, in the rain.

What makes it stick:
- **Learning by doing:** every step is an action you choose, not a slide you click past.
- **Consequences, not game overs:** wrong moves show what would really happen and why.
- **Order matters:** the game checks the real dependencies between steps, so the only way through is the right way.
- **Instant feedback:** a spoken narrator, a clear task panel and a summary of what went wrong at the end.

This repo holds two independent games about the same flat-tire scenario:

| Game | Folder | Stack |
|---|---|---|
| Voice-first web game: talk your way through a roadside flat tire | `/` (`src/`) | Vite + TypeScript |
| 3D garage simulation: change the tire yourself, step by step | `godot/` | Godot 4.7, GDScript |

## Install

### Web game
- [Node.js](https://nodejs.org) 18 or newer (includes npm). On macOS: `brew install node`.

### 3D garage (Godot)
- **Godot 4.7** (standard build, not .NET). On macOS:
  ```bash
  brew install --cask godot
  ```
  Elsewhere, download it from [godotengine.org/download](https://godotengine.org/download) and put the
  `godot` binary on your PATH. The game uses the Forward+ renderer (Metal, Vulkan or D3D12).
- **Git LFS**: the 3D models and textures are stored with Git LFS (one file is over 100 MB).
  ```bash
  brew install git-lfs
  git lfs install
  ```
  Install it **before** cloning, or run `git lfs pull` afterwards to download the real files.
- The test framework (GUT) is vendored in `godot/addons/gut`; nothing else to install.

### Get the code
```bash
git clone https://github.com/sharmad-tadkodkar/lifehack.git
cd lifehack
git lfs pull
```

## Run

### Web game
```bash
npm install
npm run dev        # open http://localhost:5173
npm run build      # production build in dist/
```
Voice input uses the browser's Web Speech API (Chrome, Edge, Safari). Elsewhere the game falls back to
multiple choice and typing.

### 3D garage
The first launch imports the assets, which takes a minute or two.
```bash
godot --path godot                               # play
godot -e --path godot                            # open in the Godot editor
godot --path godot -- --skip-intro --autoplay    # watch the whole procedure play itself
godot/run_tests.sh                               # run the test suite (headless)
```

Controls:

| Key | Action |
|---|---|
| WASD / arrows | move (Shift to jog) |
| Mouse | orbit the camera (click to capture) |
| E | open the action menu at a work spot |
| 1-9 | choose an action |
| Q | step away from the spot |
| Esc | menu: Resume / Restart / Voice / Music / Quit |
| V / M | narrator voice on/off / music on/off |
| F5 / F3 | reload config live / tag placeholder models |

Change the flat in the right order: loosen the nuts, jack the car up, remove the wheel, fit the spare,
hand-tighten, lower the car, then tighten in a star pattern. Tuning lives in `godot/config/*.cfg`;
see `CLAUDE.md` for the project layout and `godot/ASSETS.md` / `godot/CREDITS.md` for assets and credits.

## How to play

### 3D garage
You're in a garage at night next to a car with a flat front-left tire. Change it for the spare.

1. **Walk up** to a glowing work spot (the tool cart, the front-left wheel, the jack point or the
   trunk) with WASD. A prompt shows **[E]** and the spot's name.
2. **Press E** to open that spot's action menu. Your character steps into place and the camera moves in.
3. **Pick an action with 1-9**: take or put down a tool, or attempt a step. You carry one item at a
   time, so fetch the right tool first (the **IN HAND** panel shows what you're holding).
4. **Watch it play out.** Do it in the right order and the step is ticked off on the task panel. Do it
   out of order or with the wrong tool, and you see and hear why that doesn't work. That counts as a
   mistake, but you can keep going.
5. **Tighten in a star.** For the final step, tighten the nuts one at a time with 1-5, going across the
   wheel rather than round it.
6. **Finish** with the car back on the ground and every nut torqued. The mission report shows your time
   and any mistakes with the reason for each. Press **E** to play again.

Stuck? Press **Q** to step away from a spot, **Esc** for the menu, or watch a perfect run with
`godot --path godot -- --skip-intro --autoplay`.

### Web game
Press start, then say (or type) what you'd do at each moment of a roadside flat, in your own words,
for example "put the hazards on" or "loosen the lug nuts". The narrator reacts to each answer. At the end
you get a **Life IQ** score across knowledge, safety, sequence and resourcefulness, plus a diagnosis of
how you'd really cope.

## Web game details

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
