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
godot --path godot -- --campos=-2.6,0.9,3.2 --camlook=-1.2,0.4,0.8 --shot=...           # look-dev camera
godot --path godot -- --skip-intro --hold=move_forward,jog                              # hold input actions
godot --path godot --write-movie $PWD/godot/captures/clip/f.png --fixed-fps 30 --quit-after 90 -- --skip-intro
godot --path godot -- --skip-intro --steps=3 --menu=wheel --choose=1                    # jump into a procedure state
godot --path godot -- --skip-intro --autoplay                                           # watch the full procedure
godot --path godot --resolution 800x450 --write-movie $PWD/godot/captures/auto/f.png --fixed-fps 5 --quit-after 600 -- --skip-intro --autoplay
```
`--steps=N` fast-forwards the first N real steps, `--menu=<location>` opens that spot's menu
(wheel, jack_point, trunk, tool_cart), `--choose=a,b` picks menu rows. In zsh pass flags held in a
variable with `${=args}` (zsh does not word-split `$args`).

Controls: WASD move, Shift jog, mouse orbits (click to capture, Esc to release), any key skips the intro.
At a spot: E opens the action menu, 1-9 choose, Q steps away. After finishing, E plays again.
In-game: F5 reloads every `config/*.cfg` live (lighting, camera, timings), F3 toggles PLACEHOLDER tags.
`godot/captures/` is git-ignored scratch space for screenshots.

Known harmless engine warning on exit: `7 RIDs of type "Texture" were leaked` comes from Godot 4.7.2's
ReflectionProbe itself (reproduces with a bare probe in an empty scene), not from project code.

### Tests
```bash
godot/run_tests.sh                          # whole suite, headless, non-zero exit on failure
godot/run_tests.sh -gselect=test_config     # one script
```
Tests use GUT (vendored in `godot/addons/gut`, do not edit). Test files are `godot/tests/test_*.gd`;
`tests/procedure_helpers.gd` holds shared helpers. The procedure tests (`test_procedure_data`,
`test_step_order`, `test_star_pattern`, `test_inventory`) touch only `src/core/` — no scene, no rendering.
`test_step_order` includes an exhaustive check that only the real order of all 5040 orderings completes.
`test_procedure_flow` plays the whole procedure through the real menus/controller/visuals (and autoplay)
at 8x `Engine.time_scale`; `test_animations` / `test_npcs` check every clip the game asks for exists on the
current character models, so they double as the acceptance test after swapping in real assets.

### Structure
```
godot/
  config/            ALL tunable values (*.cfg, ConfigFile syntax, `;` comments)
  config/procedure/flat_tire.json   THE procedure: state, items, locations, steps (preconditions,
                     effects, tool, animations, mechanics, fail text per broken precondition)
  src/core/          PURE LOGIC (RefCounted, no nodes): ProcedureData (load+validate JSON),
                     ProcedureModel (state machine), Inventory (one item in hand), StarPattern, StepResult
  src/autoload/      Config singleton: Config.v(file, section, key), Config.section(file, section)
  src/game/          main.gd (boot, graphics, debug flags), ProcedureController (model <-> world),
                     InteractionSpot (Area3D + Stand_/Cam_/Approach/Rests markers), WorkBayVisuals (state -> props),
                     ActionPlayer (per-`mechanics` sequences: character clips + prop tweens)
  src/ui/            Hud (built in code; styled from config/ui.cfg)
  src/npc/           NpcIdleLoop (bench phone NPC), NpcPatrol (mechanic walking NpcWaypoint stops)
  src/environment/   LightingRig (applies lighting.cfg), LightStrip, HexGrid, shaders/
  src/player/        PlayerController (CharacterBody3D), CameraDirector (follow cam + shot blends + intro)
  src/slots/         AssetSlot base + rigs (CarRig, CharacterRig, ItemRig, JackRig): swap placeholders for
                     real models via assets.cfg
  tools/             build_placeholder_anims.gd → regenerates placeholders/placeholder_character_anims.tres
  scenes/
    main.tscn                      Garage + WorkBay (hero car) + Player + CameraDirector + Shots (intro cams)
    characters/player.tscn         CharacterBody3D + CharacterRig slot
    characters/npc_phone.tscn, npc_mechanic.tscn   ambient NPCs (same CharacterRig slot, own clip maps)
    environment/garage.tscn        shell, lights, probe, set dressing, car on the lift, NPCs + NpcWaypoints
    props/car.tscn                 car slot (CarRig): Chassis (tilts when jacked) with Model, hub, jack point;
                                   Spots/CornerSpot (wheel + jack_point) and Spots/TrunkSpot
    props/tool_cart.tscn           tool cart slot + ToolCartSpot
    props/{lug_wrench,jack,wheel,lug_nut,phone}.tscn   item slots (Grip marker = where the hand holds it)
    placeholders/placeholder_*.tscn  stand-in models, replaced by real assets later (see godot/ASSETS.md)
  tests/             GUT tests
  addons/gut/        vendored GUT 9.7.1
  ASSETS.md          what real assets to get (sources, formats, required nodes/pivots, Mixamo clips) and how
                     to plug them in; CREDITS.md lists third-party licences
```

Config files: `graphics` (window/AA), `lighting`, `camera`, `player`, `animation` (clip maps + tween
timings), `npc`, `ui`, `input`, `assets` (model slots), `game` (which procedure JSON).

### Conventions
- No magic numbers in scripts: add a key to the right `config/*.cfg` and read it via `Config`.
  `Config.v()` is strict and reports missing keys.
- Key bindings live in `config/input.cfg` and are registered at boot; `project.godot` has no input map.
- `lighting.cfg` keys are Godot property names: `[environment]` → Environment, `[node.<Name>]` → that node
  under Garage, `[strip.<group>]` → every LightStrip in the group. Typos are reported via push_error
  (and fail `test_lighting_config`). Light *positions* are layout and live in `garage.tscn`.
- Code never references a placeholder directly: slots (`AssetSlot`) load `assets.cfg [slot] model` or
  keep their `Model` child, and parts are found by the node names configured there.
- Characters play LOGICAL clip names (`rig.play("pump_jack")`); `animation.cfg [clips.<slot>]` maps them to
  the model's clip names (`"library/clip"`, optional `@speed`, negative = reversed). Placeholder clips are generated: edit `tools/build_placeholder_anims.gd`, then
  `godot --headless --path godot -s res://tools/build_placeholder_anims.gd`.
- Fixed camera shots are Camera3D nodes used as markers (CameraDirector copies transform + FOV).
- Game logic lives in `src/core` and never touches nodes. The world reads the model; `WorkBayVisuals.apply()`
  snaps every prop to the model state, and animations only play the transition before it.
- Character animation = AnimationPlayer clips (by logical name); mechanical motion (nuts, wrench, jack, car
  lift, wheel slide) = tweens in `ActionPlayer`, timed by `animation.cfg [mechanics]`. A step's JSON
  `animations` list is consumed in order by its `mechanics` sequence; unknown mechanics ids just play the clips.
- Adding/changing a step = edit the JSON; `ProcedureData` validation (and its test) catches bad references.
- snake_case files and folders, PascalCase node names, typed GDScript.
