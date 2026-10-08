# Oh S#IT: The Life Skills Game

Always write the title as "Oh S#IT" — never the profane spelling, in code, UI or docs.

Two independent projects live in this repo:

| Path | What | Stack |
|---|---|---|
| `/` (`src/`, `index.html`) | Voice-first web game, flat tire scenario | Vite + TypeScript + GSAP |
| `godot/` | 3D flat-tire garage simulation, runs locally | Godot 4.7, GDScript, GUT tests |

## Web game
```bash
npm install
npm run dev        # http://localhost:5173
npm run build
```

## Godot garage sim (`godot/`)

### Run
```bash
godot --path godot                 # play
godot -e --path godot              # open in the editor
```
Godot 4.7 (Forward+ renderer) is installed via `brew install --cask godot`; the `godot` binary is on PATH.

Debug flags go after `--`:
```bash
godot --path godot -- --size=1600x900 --shot=$PWD/godot/captures/shot.png --frames=120   # screenshot, then quit
godot --path godot -- --campos=-2.6,0.9,3.2 --camlook=-1.2,0.4,0.8 --shot=...           # move the overview camera
```
In-game: F5 reloads every `config/*.cfg` live (lighting, camera, timings), F3 toggles PLACEHOLDER tags.
`godot/captures/` is git-ignored scratch space for screenshots.

Known harmless engine warning on exit: `7 RIDs of type "Texture" were leaked` comes from Godot 4.7.2's
ReflectionProbe itself (reproduces with a bare probe in an empty scene), not from project code.

### Tests
```bash
godot/run_tests.sh                          # whole suite, headless, non-zero exit on failure
godot/run_tests.sh -gselect=test_config     # one script
```
Tests use GUT (vendored in `godot/addons/gut`, do not edit). Test files are `godot/tests/test_*.gd`.

### Structure
```
godot/
  config/            ALL tunable values (*.cfg, ConfigFile syntax, `;` comments) + procedure JSON
  src/autoload/      Config singleton: Config.v(file, section, key), Config.section(file, section)
  src/game/          main.gd (boot, graphics, debug flags)
  src/environment/   LightingRig (applies lighting.cfg), LightStrip, HexGrid, shaders/
  src/slots/         AssetSlot base + rigs: swap placeholder models for real ones via config/assets.cfg
  scenes/
    main.tscn                      Garage + WorkBay (hero car) + cameras
    environment/garage.tscn        shell, lights, probe, set dressing, car on the lift
    props/car.tscn                 car slot wrapper (CarRig): Model + FlatWheelPivot/JackPoint/LiftPivot markers
    placeholders/placeholder_*.tscn  stand-in models, replaced by real assets later (see godot/ASSETS.md)
  tests/             GUT tests
  addons/gut/        vendored GUT 9.7.1
```

### Conventions
- No magic numbers in scripts: add a key to the right `config/*.cfg` and read it via `Config`.
  `Config.v()` is strict and reports missing keys.
- Key bindings live in `config/input.cfg` and are registered at boot; `project.godot` has no input map.
- `lighting.cfg` keys are Godot property names: `[environment]` → Environment, `[node.<Name>]` → that node
  under Garage, `[strip.<group>]` → every LightStrip in the group. Typos are reported via push_error
  (and fail `test_lighting_config`). Light *positions* are layout and live in `garage.tscn`.
- Code never references a placeholder directly: slots (`AssetSlot`) load `assets.cfg [slot] model` or
  keep their `Model` child, and parts are found by the node names configured there.
- snake_case files and folders, PascalCase node names, typed GDScript.
