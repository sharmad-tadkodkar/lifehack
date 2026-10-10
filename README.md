# Oh S#IT: The Life Skills Game

*When life breaks down, do you know how to fix it?*

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
