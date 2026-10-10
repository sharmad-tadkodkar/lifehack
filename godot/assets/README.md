# Real assets go here

- `models/` — GLB (preferred) or FBX files for the car, wheel, lug nut, jack, wrench, characters, garage props.
- `textures/` — PBR texture sets (albedo / normal / roughness / AO) for the floor, walls and metal.

Nothing in `src/` references these paths directly. Point `config/assets.cfg` at a file and the
matching slot scene loads it instead of its placeholder. See `../ASSETS.md` for the full list.
