# Asset shopping list

## Current status (what is plugged in)

| Slot | In use | Notes |
|---|---|---|
| Car + car on the lift | **Hoonicorn V2** (`hoonicorn_v2_rigged_blender`) | Scaled 0.36, turned 180°; flat = `DEF-Wheel_Ft_L_3`, its baked `Tire_Bolts` hidden so the game's nuts replace them. Carries real sponsor decals (Ford, Monster, Forza Horizon...); hide them with `hide_materials=["Sticker_1", ...]` in `assets.cfg [car]`. |
| Spare wheel | **Rims_N_Tyres kit**, part `Wheel Rear Left_30` | `part=` picks one wheel out of the kit and centres it |
| Jack | **Hydraulic (bottle) jack** | `lift_mode="translate"`: piston + screw slide up; handle pose borrowed from the model's own animation |
| Lug wrench | **Cross wheel spanner** | Scaled 1.9 (modelled at half size), socket shifted to the origin |
| Player / bench NPC / mechanic | **character.fbx / character-2.fbx / character-3.fbx** (Mixamo) | Retargeted to Godot's humanoid skeleton by `tools/setup_mixamo.gd`; hand socket derived from the hand bones |
| Animations | 18 Mixamo clips (Breathing Idle, Standard Walk, Jogging, Kneeling Down/Idle/Inspecting, Plant A Plant, Pulling Lever, Working On Device, Pull Heavy Object, Pushing, Picking Up, Shrugging, Texting While Standing, Looking Around, Weight Shift, Standing Torch Inspect Upward, Reaching Out) | Imported as AnimationLibraries, loaded from `assets/models`. Standard Walk and Jogging were downloaded without In Place: `CharacterRig` removes their forward travel at load and measures their stride speed (walk 1.46 m/s, jog 1.85 m/s) to keep the feet planted. |
| Floor | **Poly Haven Garage Floor** (diffuse + displacement) | The 4K normal/roughness EXRs use DWA compression Godot can't read: normals come from the displacement map, roughness stays procedural. PNG versions of those two maps would plug straight in. |
| Lug nuts, tool cart, phone, garage props, wall/door textures | placeholders | not supplied yet |

The model and texture binaries are stored in **Git LFS** (`.gitattributes` at the repo root), so a clone needs
`brew install git-lfs` and `git lfs install` before `git clone` / `git lfs pull`.

**Adding more Mixamo clips:** drop the FBX files (Without Skin) into `godot/assets/models/`, then run:

```bash
godot --headless --path godot --import
godot --headless --path godot -s res://tools/setup_mixamo.gd
godot --headless --path godot --import
godot/run_tests.sh
```

The first import lets the tool read the new files' skeletons; the second applies the retarget. A clip is
named after its file (`"Weight Shift.fbx"` -> `weight_shift/mixamo_com`); map it in `config/animation.cfg`,
and add looping clips to `[mixamo_import] loop_files` before running the tool. A new locomotion clip that
was downloaded without In Place goes in `[locomotion] in_place_clips`.

Anything still tagged **PLACEHOLDER** (press **F3** in-game) is a simple shape with real materials, there
so the lighting, animation and gameplay can be built and judged until a real model replaces it.

Real assets plug in **without code changes**:

1. Drop the file under `godot/assets/models/...` (or `assets/textures/...`).
2. Point the slot at it in `godot/config/assets.cfg` (`model="res://assets/models/..."`), and fix size or
   facing there with `scale`, `offset` and `rotation_deg` if needed.
3. Name the moving parts in `assets.cfg` (`flat_wheel_node`, `handle_node`, `hand_bone`, ...), and map
   animation clip names in `config/animation.cfg`.
4. Nudge the markers in the slot's wrapper scene (`scenes/props/*.tscn`) to fit the new model. These are
   the hub pivot, jack point, stand marks, close-up cameras and grip points.
5. Run `godot/run_tests.sh`. The animation and NPC tests check that every clip the game asks for exists
   on the new model.

---

## General rules (all models)

| Rule | Why |
|---|---|
| **GLB** (glTF binary) preferred, FBX accepted | Godot 4.7 imports both natively. GLB has the fewest surprises with materials. |
| **Metres, Y up, forward = −Z** | That is Godot's convention. Many free models (Kenney, Mixamo) face **+Z**, so set `rotation_deg=Vector3(0, 180, 0)`. |
| Apply transforms in Blender before export | The rigs rotate and slide parts around their **origins**, so origins must be where the doc says. |
| Parts the code moves must be **separate nodes** | Wheels, lug nuts, jack handle and lift arm. A single merged mesh can't be animated. |
| No real-world branding | Avoid licensed car makes and logos. The only branding in the game is Oh S#IT. |
| Keep a credit line for every CC-BY asset | Add it to `godot/CREDITS.md`. CC0 assets need no credit, but it is a nice touch. |

To find a node name, double-click the imported file in Godot to open **Advanced Import Settings**. Its scene
tree shows the exact names to copy into `assets.cfg`.

---

## 1. Hero car (and the car on the lift)

**Slot:** `[car]` (hero) and `[car_background]` (lift). **Wrapper:** `scenes/props/car.tscn`

| Requirement | Detail |
|---|---|
| Four wheels as **separate nodes** | One of them is the flat. The rig takes the node named in `flat_wheel_node` and re-parents it to the hub, so it can be unbolted and slid off. |
| Wheel **origin at the hub centre** | Fix in Blender with Object › Set Origin › Origin to Geometry on each wheel. |
| **No lug nuts baked into the wheel** | The game places its own lug nut models on the bolt circle. Baked nuts would stay behind when the real ones come off. |
| Facing −Z, flat wheel = **front-left** | Front-left is the side the work spots are on. If your flat is a different wheel, point `flat_wheel_node` at it and move the markers. |
| Paint | For the glossy look, open the paint material and enable **Clearcoat** (1.0, clearcoat roughness about 0.05). |

**After swapping, nudge these in `car.tscn`:**
- `Chassis/FlatWheelPivot`: the hub centre, with +X pointing out of the car.
- `Chassis/JackPoint`: on the pinch weld just behind the front wheel.
- `LiftPivot`: the far side's tyre contact line. The car tilts around it when jacked.
- `Chassis/Collision/Shape`: the body box.
- `Spots/CornerSpot/*` and `Spots/TrunkSpot/*`: stand marks and cameras.

`bolt_circle_radius` and `nut_seat_offset` in `assets.cfg` place the nuts on the hub.

**Free sources:**
- **Kenney – Car Kit** (CC0) [kenney.nl/assets/car-kit](https://kenney.nl/assets/car-kit)
  - Each car has a `body` node and separate `wheel-front-left`, `wheel-front-right`, `wheel-back-left` and
    `wheel-back-right` nodes, so set `flat_wheel_node="wheel-front-left"`.
  - It's a stylised low-poly look.
- **Quaternius – Cars pack** (CC0) [quaternius.com/packs/cars.html](https://quaternius.com/packs/cars.html)
  - Taxi, police car, SUV, 2 sports cars and 2 normal cars, in FBX/GLB/Blend.
  - Check in the import dock that the wheels are separate nodes.
- **Sketchfab**: for a more realistic, Need-for-Speed-like car, filter by *Downloadable* plus a CC licence.
  - Pick an **unbranded** sports car whose wheels are separate objects.

## 2. Spare wheel

**Slot:** `[wheel]`. **Wrapper:** `scenes/props/wheel.tscn`

- Origin at the hub centre, axle along **+X**, outer face pointing **+X**. No lug nuts.
- Ideally it matches the car's wheels. A compact "donut" spare is fine and realistic.
- `Grip` marker (in the wrapper): where the hand holds it. The default is the top of the tread.
- Source: **Rims_N_Tyres_kit_1.0 (CC0)** on Sketchfab, or reuse one of the car's own wheels exported on its own.

## 3. Lug nuts

**Slot:** `[lug_nut]`. **Wrapper:** `scenes/props/lug_nut.tscn`. The game creates five of them (`nut_count` in the procedure JSON).

- Tiny: about 19–21 mm hex. Origin at the **seat** (the face that touches the wheel), axis **+X** pointing outward.
- Sources: most rim kits include one. Otherwise a 6-sided cylinder in Blender with a bevel is genuinely enough.

## 4. Floor (trolley) jack

**Slot:** `[jack]`. **Wrapper:** `scenes/props/jack.tscn`

| Part | Node name (`assets.cfg`) | Pivot / origin |
|---|---|---|
| Whole jack | slot origin | **Under the saddle**, on the floor. The saddle end points **−Z**, and the body and handle run back along +Z. |
| Lift arm | `lift_arm_node="LiftArm"` | At its **rear hinge**. Rotating it about local **X** raises the saddle. |
| Handle | `handle_node="Handle"` | At its **base hinge**. Rotating it about local **X** is one pump stroke. |

- Tune how far they swing with `jack_arm_raise_deg` and `jack_pump_swing_deg` in `animation.cfg [mechanics]`.
- Most downloaded jacks are one merged mesh, so in Blender split the arm and handle into their own objects
  and set each one's origin at its hinge.
- Candidates on Sketchfab (check the *Downloadable* badge and the licence on each page):
  - *Floor jack* by refaatosama46 (hydraulic trolley jack, PBR)
  - *Hydraulic Jack* by Ben Milette (CC-BY)
  - *Car Jack* by alterbotcreations (CC-BY, low poly)

## 5. Lug wrench (4-way cross wrench)

**Slot:** `[lug_wrench]`. **Wrapper:** `scenes/props/lug_wrench.tscn`

- Origin at the **socket end that goes on the nut**. Local **−Z goes into the nut**, and the long arm runs
  along +Z with the cross arm across it.
  - The game seats the socket on each nut and rotates the wrench around the nut's axis.
- `Grip` marker (in the wrapper): where the hand holds it when carried.
- Sketchfab candidates:
  - *Lug Wrench (Cross Wheel Spanner)* by dinoxwave (CC-BY, PBR)
  - *Tools / 4 Way Lug Wrench* by ROY

## 6. Tool cart

**Slot:** `[tool_cart]`. **Wrapper:** `scenes/props/tool_cart.tscn`

- Any rolling workshop cart. Origin on the floor at its centre, with the working side facing **+Z**.
- After swapping, nudge these in the wrapper:
  - `ToolCartSpot/Rests/tool_cart/lug_wrench`: where the wrench lies on the tray.
  - `.../jack`: where the jack parks beside the cart.
  - `.../drop`: where set-down items go.
- Add a `StaticBody3D` with a box shape so the player can't walk through it.

## 7. Phone (bench NPC)

**Slot:** `[phone]`. **Wrapper:** `scenes/props/phone.tscn`

- Any smartphone. Name the screen mesh **`Screen`**, and its emission and the `ScreenGlow` light are then
  driven from `npc.cfg [phone]`.
- `Grip` marker: where it sits in the hand.

## 8. Characters: Mixamo

**Slots:** `[player]`, `[npc_phone]`, `[npc_mechanic]`. **Wrappers:** `scenes/characters/*.tscn`

[mixamo.com](https://www.mixamo.com) needs a free Adobe account, and it's royalty-free in games. Suggested
characters, all in Mixamo's catalogue, for casual and work-wear looks:
- **Player:** `Remy`
- **Bench NPC:** `Kate` or `Jody`
- **Mechanic:** `Racer` or `Brian`

Pick by look; any Mixamo character works the same way.

**Download the character once:** Format **FBX Binary (.fbx)**, Pose **T-pose**, **With Skin**.

**Download each animation:** Format **FBX Binary**, **Without Skin**, **30 fps**, Keyframe Reduction **none**.
Tick **In Place** on walking and jogging clips; the game moves the body itself. (Clips downloaded
without it still work: list them in `animation.cfg [locomotion] in_place_clips`.)

### Which Mixamo clips to download

The clip names below were checked against the Mixamo catalogue. Where there are several variants with the
same name, the description tells you which one. Loop = set *Loop Mode: Linear* in the import dock.

**Player** (`[clips.player]`):

| Logical name (game asks for) | Mixamo clip | Loop | Notes |
|---|---|---|---|
| `idle` | **Breathing Idle** | ✓ | |
| `walk` | **Standard Walk** | ✓ | In Place |
| `jog` | **Jogging** | ✓ | In Place |
| `kneel_down` | **Kneeling Down** ("Standing To Kneeling Down") | | |
| `stand_up` | **Kneeling Down**, reversed: `"...@-1"` | | Or **Crouch To Stand** ("Male Crouch To Stand") |
| `kneel_idle` | **Kneeling Idle** | ✓ | Waiting between nuts during the star pattern |
| `wrench_loosen`, `wrench_tighten`, `wrench_unscrew`, `thread_nuts` | **Kneeling Inspecting** ("Kneeling And Inspecting Element With Hands") | ✓ | Mixamo has no wrench clip. This hands-busy kneel reads well, and the wrench motion itself is a tween. |
| `place_jack` | **Plant A Plant** ("Kneeling Planting A Plant") | | Kneeling reach forward and down |
| `pump_jack` | **Pulling Lever** ("Pulling A Lever Down") | ✓ | |
| `release_jack` | **Working On Device** ("Man Working On Device") | | |
| `pull_wheel` | **Pull Heavy Object** ("Pulling A Heavy Object") | | |
| `fit_wheel` | **Pushing** ("Pushing An Object Forward") | | |
| `pick_up` | **Picking Up** ("Picking Up An Object") | | |
| `shrug` | **Shrugging** ("Shoulder Shrug") | | Plays on a mistake |

**Bench NPC** (`[clips.npc_phone]`):

| Logical | Mixamo clip | Loop |
|---|---|---|
| `lean_phone` | **Texting While Standing** ("Texting On A Smart Phone While Standing"), or **Leaning** ("Leaning Square With Shoulders Against A Wall") for a pure lean | ✓ |
| `lean_glance` | **Looking Around** ("Idle Stand Looking Around") | |
| `shift_weight` | **Weight Shift** (the "Weight Shift Idle" variant) | |
| `idle` | **Breathing Idle** | ✓ |

**Mechanic** (`[clips.npc_mechanic]`):

| Logical | Mixamo clip | Loop |
|---|---|---|
| `walk` / `jog` / `idle` | **Standard Walk** / **Jogging** / **Breathing Idle** | ✓ |
| `work_overhead` | **Standing Torch Inspect Upward**, looking up under the lift | ✓ |
| `look_around` | **Looking Around** | |
| `browse_shelf` | **Reaching Out** or **Picking Up Object** | |
| `kneel_down` / `kneel_idle` / `stand_up` | **Kneeling Down** / **Kneeling Inspecting** / **Kneeling Down@-1** | / ✓ / |

### Importing Mixamo into Godot 4.7

**Automated:** `godot --headless --path godot -s res://tools/setup_mixamo.gd` does steps 2–3 below for every FBX
in `assets/models` (bone maps per Mixamo prefix, retarget, animation-library import, loop flags from
`animation.cfg [mixamo_import] loop_files`), and `CharacterRig` loads every clip library from `animation_dir` at
runtime, so you can point `assets.cfg` straight at the character FBX (no inherited scene needed). The manual steps
are kept here for reference.

1. Put the files in `assets/models/characters/<name>.fbx` and `assets/models/animations/<clip>.fbx`.
2. **Character file:** open Advanced Import Settings, select `Skeleton3D`, then under *Retarget › Bone Map*
   choose **New BoneMap** and set its profile to **SkeletonProfileHumanoid**. Godot auto-maps the
   `mixamorig:` bones. Save the BoneMap (for example `assets/models/mixamo_bonemap.tres`) and reimport.
   - The bones become Godot humanoid names and the skeleton becomes `GeneralSkeleton`, so set
     `hand_bone="RightHand"` in `assets.cfg`.
   - If you skip retargeting, the bone is `hand_bone="mixamorig_RightHand"`.
3. **Each animation file:** set *Import As* to **Animation Library**, reuse the same BoneMap, set Loop Mode for
   the looping clips (table above), and reimport.
   - Mixamo names the take `mixamo.com`, which shows up as **`mixamo_com`**. Check the import dock.
4. **Make the playable character:** right-click the character FBX, choose *New Inherited Scene*, select its
   `AnimationPlayer`, then *Animation › Manage Animations › Load Library* once per animation library.
   - Name each library after the clip, e.g. `kneeling_idle`. Save as `assets/models/characters/player.tscn`.
5. **Point the slot at it** in `assets.cfg`:
   ```
   [player]
   model="res://assets/models/characters/player.tscn"
   rotation_deg=Vector3(0, 180, 0)   ; Mixamo characters face +Z; the game's forward is -Z
   hand_bone="RightHand"
   ```
   Check the height is about 1.75 m, and use `scale` if not.
6. **Map the clips** in `animation.cfg`, using library/clip and an optional `@speed`:
   ```
   [clips.player]
   walk="standard_walk/mixamo_com"
   kneel_down="kneeling_down/mixamo_com"
   stand_up="kneeling_down/mixamo_com@-1"
   ```
7. Run `godot/run_tests.sh`. The tests report any logical clip that doesn't resolve, by name.

**Shortcut:** in Blender you can import the character and every animation, rename the actions, and export a
single GLB. The clips then arrive with your names and no library prefix.

**Grip and hold tuning:** held tools sit on the `HandSocket` (a BoneAttachment3D on `hand_bone`, placed in
the palm from the finger and thumb bones; `palm_offset` / `palm_depth` in `assets.cfg` move it toward the
knuckles and out of the palm). While carrying, the arm takes the pose in `animation.cfg [carry]` and the
fingers close into a fist, so set each tool's `Grip` marker for that pose: its frame is the hand's
(-Y toward the fingers, -Z toward the thumb, +X the back of the hand), and the handle should run along Z,
across the palm. Pick-ups need no tuning: the game works out from each clip when the hand is nearest.

## 9. Textures (Poly Haven, CC0)

Download **2K or 4K, JPG**: *Diffuse*, *Normal (GL)* (Godot uses the OpenGL normal convention) and *Rough*.

| Surface | Poly Haven texture | Where it goes |
|---|---|---|
| Garage floor | **Garage Floor** (`garage_floor`), or **Smooth Concrete Floor** for a cleaner, epoxy-like look | `assets.cfg [floor_textures]` albedo / normal / roughness / tiling. The floor shader keeps its glossy wet patches on top of the texture, so the reflective look survives. |
| Walls | **Concrete Panels** or **Factory Wall** | The `concrete` material in `scenes/environment/garage.tscn` (Shell/Walls) |
| Roller door | **Painted Metal Shutter** or **Box Profile Metal Sheet** | Replace the `RollerDoor` shader material with a StandardMaterial3D using these |
| Metal props | **Rusty Painted Metal** etc. | On the imported props as needed |

No HDRI is needed. The garage is an interior lit by its own lights, and the reflection probe captures it.

## 10. Garage set dressing

`scenes/placeholders/placeholder_garage_props.tscn` holds the workbench, tool chest, tire rack, tire stack,
two-post lift, oil drums and cones. Replace them piece by piece in `garage.tscn` (Garage/Props), keeping
`StaticBody3D` collisions so the player and the mechanic can't walk through them.

Sources:
- **Sketchfab** (*Downloadable* + CC) for realistic workshop props: workbench, rolling tool chest, two-post
  car lift, tire rack.
- **Kenney** and **Quaternius** have CC0 props in a stylised style.

If the lift or shelves move, nudge `Garage/NpcWaypoints/Stop*` (the mechanic's route) and `NPCs/NpcPhone`
(who leans on the bench).

---

### Checklist

- [ ] Hero car (wheels separate, origin at hubs, no baked nuts), plus car on the lift
- [ ] Spare wheel
- [ ] Lug nut
- [ ] Floor jack (LiftArm + Handle split, origins at hinges)
- [ ] Cross lug wrench
- [ ] Tool cart
- [ ] Phone
- [ ] 3 Mixamo characters (With Skin)
- [ ] Mixamo animations from the tables (Without Skin, In Place for walk/jog)
- [ ] Poly Haven floor, wall and door textures
- [ ] Workshop props: workbench, tool chest, tire rack, two-post lift
- [ ] Credits for any CC-BY asset in `CREDITS.md`

### Sources

- Kenney Car Kit – https://kenney.nl/assets/car-kit (CC0). Node names per Kenney's Starter Kit Racing: https://github.com/KenneyNL/Starter-Kit-Racing
- Quaternius Cars – https://quaternius.com/packs/cars.html (CC0)
- Sketchfab: Rims_N_Tyres_kit_1.0 (CC0) – https://sketchfab.com/3d-models/rims-n-tyres-kit-10-cc0-97c7a90210974cb089f15ee7682e4d65
- Sketchfab: Floor jack – https://sketchfab.com/3d-models/floor-jack-291ad834d0fe44fda68f08ec4c2bfa60 · Hydraulic Jack – https://sketchfab.com/3d-models/hydraulic-jack-f5e69416bddc40fb8a152f05888bfe94 · Car Jack – https://sketchfab.com/3d-models/car-jack-846619bef5ad4aa6b5b4951203900efe
- Sketchfab: Lug Wrench (Cross Wheel Spanner) – https://sketchfab.com/3d-models/lug-wrench-cross-wheel-spanner-2c135201029744d98680ec7c086baedb · 4 Way Lug Wrench – https://sketchfab.com/3d-models/tools-4-way-lug-wrench-81578532781542c590668ab67d1121e9
- Mixamo – https://www.mixamo.com. Clip and character names checked against the catalogue mirror at https://huggingface.co/datasets/tanish434/Mixamo-Animations-Characters
- Godot Mixamo retarget workflow (BoneMap + SkeletonProfileHumanoid) – https://9to5grind.dev/posts/bringing-mixamo-animations-to-life-in-godot/
- Poly Haven – https://polyhaven.com/a/garage_floor · https://polyhaven.com/a/smooth_concrete_floor · https://polyhaven.com/a/concrete_panels · https://polyhaven.com/a/factory_wall · https://polyhaven.com/a/painted_metal_shutter · https://polyhaven.com/a/box_profile_metal_sheet (all CC0)

## Sound and music

Everything you hear is synthesized by `tools/build_audio.gd` into `godot/assets/audio/` (no licences
needed). Each sound is a slot in `godot/config/audio.cfg`, so a recording can replace it without code
changes:

1. Drop the file (WAV or OGG, mono is fine for effects) into `godot/assets/audio/recorded/`.
2. Set its slot, e.g. `[sfx.ratchet] file="res://assets/audio/recorded/ratchet.ogg"`, and adjust `volume_db`.
3. For the music: `[music] file="res://assets/audio/recorded/track.ogg"` (enable Loop in its import settings).

| Slot | Plays when |
|---|---|
| `nut_crack`, `ratchet` | each nut is cracked loose (ratchet also on every final tightening pull) |
| `nut_spin`, `nut_drop` | a loose nut is spun off and lands in the pile |
| `nut_thread`, `nut_seat` | a nut is threaded on by hand / torqued down (and the spare seats) |
| `jack_place`, `jack_pump`, `car_creak` | the jack goes under the car, each pump stroke, the body rising |
| `valve_hiss`, `car_settle` | the release valve opens, the tyre takes the weight |
| `wheel_slide`, `wheel_thud` | a wheel slides off/on the hub, the flat is laid down |
| `pickup`, `putdown` | the moment a hand takes or leaves an item |
| `good`, `bad`, `stamp`, `fanfare` | a step done, a mistake, the finish |
| `ui_move`, `ui_select` | menus |
| `[ambience]`, `[music]` | garage hum and the background loop |

Good CC0 sources for recorded replacements: [Kenney audio packs](https://kenney.nl/assets/category:Audio)
(Impact Sounds, Interface Sounds, Music Jingles), the [Sonniss GDC game audio bundles](https://sonniss.com/gameaudiogdc)
(royalty-free), [OpenGameArt](https://opengameart.org) (filter by CC0) and [Freesound](https://freesound.org)
(filter by CC0). Add a line to `CREDITS.md` for anything that asks for attribution.

The narrator uses the operating system's text-to-speech voice (on macOS the first installed of Daniel, Arthur,
Oliver, Alex, Aaron, Samantha; set in `audio.cfg [voice]`). Its lines live in the procedure JSON (`narration`).
