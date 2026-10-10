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
godot --path godot -- --skip-intro --pause-menu                                         # open the Esc menu
godot --path godot --resolution 800x450 --write-movie $PWD/godot/captures/auto/f.png --fixed-fps 5 --quit-after 600 -- --skip-intro --autoplay
```
`--steps=N` fast-forwards the first N real steps, `--menu=<location>` opens that spot's menu
(wheel, jack_point, trunk, tool_cart), `--choose=a,b` picks menu rows. In zsh pass flags held in a
variable with `${=args}` (zsh does not word-split `$args`).

Controls: WASD move, Shift jog, mouse orbits (click to capture), any key skips the intro.
At a spot: E opens the action menu, 1-9 choose, Q steps away. After finishing, E plays again.
Esc opens the menu (pauses): 1 Resume, 2 Restart (skips the intro), 3 Voice on/off, 4 Music on/off, 5 Quit.
V toggles the narrator voice, M the music (remembered in `user://settings.cfg`).
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
  src/autoload/      Config singleton: Config.v(file, section, key), Config.section(file, section);
                     Sfx (audio_director.gd): Sfx.play(id, at_node), Sfx.say(text), music/ambience, buses
  src/game/          main.gd (boot, graphics, debug flags), ProcedureController (model <-> world),
                     InteractionSpot (Area3D + Stand_/Cam_/Approach/Rests markers), WorkBayVisuals (state -> props),
                     ActionPlayer (per-`mechanics` sequences: character clips + prop tweens)
  src/ui/            Hud and PauseMenu (built in code), in an AR heads-up style: HudStyle (fonts, colours,
                     labels, key caps, step bar from config/ui.cfg) and ArPanel (glass panel frame)
  src/npc/           NpcIdleLoop (bench phone NPC), NpcPatrol (mechanic walking NpcWaypoint stops)
  src/environment/   LightingRig (applies lighting.cfg), LightStrip, HexGrid, shaders/
  src/player/        PlayerController (CharacterBody3D), CameraDirector (follow cam + shot blends + intro)
  src/slots/         AssetSlot base + rigs (CarRig, CharacterRig, ItemRig, JackRig): swap placeholders for
                     real models via assets.cfg
  tools/             build_placeholder_anims.gd → regenerates placeholders/placeholder_character_anims.tres
                     setup_mixamo.gd → retarget + import settings for Mixamo FBX in assets/models (re-run after adding)
                     build_audio.gd → synthesizes assets/audio/*.wav (effects, garage hum, music loop)
  assets/models/     real models (Hoonicorn, bottle jack, cross wrench, rims kit, Mixamo characters + clips);
                     assets/textures/ Poly Haven floor. Binaries are in Git LFS (see .gitattributes).
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
timings), `npc`, `ui`, `input`, `assets` (model slots), `audio` (sound slots, mix, voice), `game` (which procedure JSON).

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
- Placement keeps each item's own scale and settles items on rest markers by their mesh bounds
  (`WorkBayVisuals.settle`); rest markers mark the surface height, not the item's centre.
- Clip maps support fallbacks (`"standard_walk/mixamo_com|shrugging/mixamo_com@0|walk"`): the first clip the
  model has wins, and the last entry is the placeholder's name, so the same map works for both.
- `test_assets` asserts the configured real models are actually in use; it fails on a clone whose LFS
  files were not pulled (`git lfs pull`).
- Mixamo walk/jog clips without In Place are fixed at load: `animation.cfg [locomotion] in_place_clips` lists
  them, `CharacterRig` strips the root bone's travel and measures the stride speed used for playback scaling.
- Picking up / setting down (`ActionPlayer._take_or_put`, `animation.cfg [pickup]`): `CharacterRig.hand_path()`
  works out where the hand goes in each pick-up clip from its bone tracks; the clip and moment where the hand
  best meets the item win, the player walks/turns/steps so it lands there, and the item glides in or out at
  that moment (`WorkBayVisuals.apply_gliding`). Rigs without a skeleton fall back to the timed `_pickup()`.
- Carrying: `CarryPose` (a SkeletonModifier3D under the skeleton) holds the arm in a clip frame with the
  fingers curled into a fist (`animation.cfg [carry]`) while idle/walking with something in hand. Item `Grip`
  markers are set for that pose (handle across the palm, tool beside the leg).
- Character AnimationPlayers and skeleton modifiers run on the physics tick, and ActionPlayer tweens use
  `TWEEN_PROCESS_PHYSICS`: physics interpolation is on, and anything moved in idle frames would jitter. A
  reparent (e.g. into the hand) calls `reset_physics_interpolation()` so it is a teleport, not a streak.
- Audio: every sound is an `audio.cfg [sfx.<id>]` slot (`file=""` = synthesized `assets/audio/<id>.wav`, regenerate
  with `godot --headless --path godot -s res://tools/build_audio.gd`). ActionPlayer plays effects positioned at the
  nut / jack / wheel; `test_audio` fails if code plays an id without a slot. The narrator (OS text-to-speech,
  `DisplayServer.tts_*`) reads lines chosen by `src/core/narrator.gd` from the JSON's `narration` block (intro, quip
  openers before mistake consequences, finish lines by mistake count); the music ducks while it speaks.
  `Sfx.played` / `Sfx.spoken` log what happened (tests read them; TTS is silent headless).
- HUD look: build panels with `HudStyle.panel(tag)` (ArPanel draws its own chamfered frame, brackets and
  scanlines) and text with `HudStyle.label()`; Michroma (`display`) for headings/values/keys, Rajdhani for
  sentences, colours in `ui.cfg [colors]` (cyan `accent`, orange `warn` / `brand`). Eurostile Extended or
  Microgramma are commercial; a licensed copy can be swapped in via `ui.cfg [fonts] display`.
- snake_case files and folders, PascalCase node names, typed GDScript.
