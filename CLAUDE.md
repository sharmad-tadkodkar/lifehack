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
godot --path godot -- --size=1600x900 --shot=/tmp/shot.png --frames=120   # screenshot, then quit
```

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
  scenes/            main.tscn
  tests/             GUT tests
  addons/gut/        vendored GUT 9.7.1
```

### Conventions
- No magic numbers in scripts: add a key to the right `config/*.cfg` and read it via `Config`.
  `Config.v()` is strict and reports missing keys.
- Key bindings live in `config/input.cfg` and are registered at boot; `project.godot` has no input map.
- snake_case files and folders, PascalCase node names, typed GDScript.
