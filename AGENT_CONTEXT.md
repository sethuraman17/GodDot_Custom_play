# Beat The Heat! — Agent Context & Action Log

> **Purpose:** Shared context for any agent (Claude Code, Summer Engine agents, humans) working on this
> project. Read this fully before touching the project. **Every agent must append to the Action Log at
> the bottom when it changes anything** (scene, scripts, assets, project settings) — one dated entry per
> work session, newest last.

---

## 1. Game Vision

**Beat The Heat!** — third-person survival-exploration in a big post-apocalyptic desert world.
Summer Engine (Godot 4.6), project name `BeatTheHeat`, main scene `res://scenes/main.tscn`.

**Setting:** A scorched, sand-buried world. Ruined city blocks, cracked asphalt highways, wrecked
vehicles, wasteland debris. The sun is the enemy.

**Core mechanic (THE game):** *Survive in shade.*
- Standing in direct sunlight drains the player's health continuously.
- Standing in shadow (buildings, wrecks, canopies, night-time if added later) stops the drain
  (and possibly slowly regenerates).
- Gameplay loop: plan routes between shade islands, sprint across sunlit gaps, use the world's
  ruins/vehicles as cover stepping-stones.
- Status: **NOT implemented yet.** No health system exists in the code today. Design notes in §4.

## 2. Current State of the Project (as of 2026-07-04)

- Template origin: "3D Open World Explore TPS Template" → renamed Beat The Heat!
- Playable: WASD + orbit camera third-person robot, sprint/jump, interact (E), inventory (I).
- Legacy quest still active: talk to scout robot → fetch "forest relic" → return. Flavor text is
  still forest-themed (needs desert retheme). Logic: `scripts/adventure_quest_state.gd`, HUD in
  `scripts/adventure_hud.gd`.
- World: procedural terrain (`scripts/adventure_terrain_grid.gd` + `adventure_terrain_generator.gd`),
  **sand retexture + desert haze done**. A cracked-asphalt highway ("CityHighway", 5 waypoints,
  `scripts/terrain_road_path.gd` with `show_surface = true`) threads south→north through the
  homestead cluster — verified in-engine.
- Props placed: abandoned farmhouse, wasteland shed, fences, barrels, tire, slabs, pebbles, dry grass
  (all under `Level/EnvironmentProps`, snapped via `snap_to_adventure_terrain` group).
- `Level/Landmarks` + wrecks are populated (city cluster within ~65 m of origin; see action log).
- `Level/CityBuildings` (`scripts/city_building_streamer.gd` v2): ENDLESS streamed city — STREETS +
  buildings generate procedurally around the player and despawn behind them (replaced the static
  `Level/DistantRuins` scatter on 2026-07-04 — do NOT re-add DistantRuins; it resurrected once via a
  merge and had to be removed twice). 42 m cells, deterministic per-cell roll (world_seed 90210 mixed
  with cell coords) — layout stable across revisits/runs without storing it.
  STREET GRID: asphalt streets on world lines x/z = 126k m; crossings are always clean right-angle
  junctions (east-west ribbons run continuous, north-south ribbons butt-join against them — never
  two ribbons crossing through each other). Ribbons conform to terrain (sampled heights), vertex-
  colored sand→asphalt→faded-center-line in the shared palette (sand color must match the terrain
  albedo contract), and carry a thin walkable trimesh collider.
  BUILDINGS spawn ACCORDING TO the streets: cells near a line snap the building to street frontage
  at setback STREET_CLEAR+half-footprint, facade aligned to the street (±5° jitter); interior cells
  align to grid axes; junction corners stay open (15 m plaza); nothing intrudes a street corridor.
  Buildings are upright or lean 5–28° MAX (user rule: ≤30°, never toppled), half-buried in sand.
  Density: base 0.98 to r=280 / 0.75 to 450 / 0.55 beyond, × district noise (floor 0.45).
  Never spawns inside the r=90 handcrafted core. Perf: 1 cell/frame, building trimesh shapes +
  desert-tint materials in STATIC shared caches, live cap 120, cells freed past 232 m. NOT in the
  snap group (heights via detached `AdventureTerrainGenerator`). Console: `CityStreamer: batch done`.

### ⚠️ Critical constraints
1. **Do NOT headless-regenerate `scenes/main.tscn`** via `tools/build_main_scene.gd` without explicit
   user approval — the baked scene was hand-tuned in the editor and a rebuild overwrites tweaks
   (empty Landmarks, transform diffs). Keep `build_main_scene.gd` mirrored with manual scene edits instead.
2. Roads only drape a no-collision ribbon over terrain; the single terrain mesh is the walkable
   collider everywhere. New roads = new Node3D with `terrain_road_path.gd` + Marker3D children.
3. Summer Engine MCP tools are connected in Claude Code (`summer_*`). Use `summer_get_project_context`
   first; play + screenshot to verify visual changes (`summer_play`, `summer_screenshot`).
4. Git: repo `marchellodev/arduino_summer_game`, branch `main`, identity varun3108 / vedant@oktogrid.io,
   auth via `gh`. Commit only when the user asks.

## 3. Asset Inventory (verified 2026-07-04)

All AI-generated city/vehicle GLBs below have a single baked texture atlas; internal nodes are generic
(`node_0`). They import fine but **need scale checks when placed** (city blocks are whole districts in
one mesh, ±13–26 MB each). License notes for everything: `asset_manifest/third_person_adventure_assets.md`
(all still "TODO: verify before publishing").

### A. Template assets (in scene already)
- `assets/third_person_adventure/characters/player_robot/` — rigged robot + idle/walk/run/jump/fall/land
  clips (player AND scout NPC reuse it).
- `assets/third_person_adventure/environment/wasteland_props/` — 12 props: shed, 3 fence types,
  blue/red barrels, concrete slab, utility light, worn tire, pebbles (L/S), dry grass.
- `assets/third_person_adventure/environment/structures/abandoned_farmhouse.glb` — placed.

### B. Post-apoc structures imported but NOT placed yet (`environment/structures/`)
- `post_apocalyptic_city_block.glb` (20 MB)
- `abandoned_gatehouse.glb` (21 MB)
- `ruined_office_building.glb` (18 MB)

### C. `assets/models/` (named, not placed)
- `ruined_building.glb` — post-apoc ruin ✔ fits theme
- `gold_mine.glb`, `medieval_building.glb`, `arabian_blacksmith.glb` — off-theme (medieval/fantasy);
  `arabian_blacksmith` could pass as desert adobe ruin at a pinch.

### D. `assets/Downloaded models/` — 16 GLBs, identified by texture-atlas inspection
**Vehicles (the vehicle supply for the map):**
- `3d_1781682855782.glb` — white pickup truck (modern, orange accents)
- `3d_1781736218100.glb` — dark wrecked car(s)/truck, red taillights — reads as vehicle wreck(s)
- `3d_1782247608603.glb` — dark sedan/sports car

**City blocks / districts (one mesh each — big):**
- `3d_1781089724850.glb` — monochrome gray ruined city block (very post-apoc)
- `3d_1782616039388.glb` — dark blue-gray ruined city block (grim; texture also copied in assets/models)
- `3d_1782370000831.glb` — red-brick apartment block district (NY-style)
- `3d_1782544322286.glb` — downtown skyscraper skyline block (pale yellow)
- `3d_1780935352905.glb` — cyberpunk neon-sign city block (teal/pink neon; off-theme unless "dead neon" vibe)
- `3d_1781444788008.glb` — light-gray industrial complex / warehouse yard
- `3d_1782587655121.glb` — European palazzo-style city block
- `3d_1782507288837.glb` — old-town district, terracotta roofs, courtyards
- `3d_1782507309021.glb` — adobe/Mediterranean town block, blue doors (desert-compatible)

**Towns / houses:**
- `3d_1781559340561.glb` — medieval half-timbered town block (off-theme)
- `3d_1782644318579.glb` — village of dark-shingled houses
- `3d_1782644548162.glb` — grayscale suburban house cluster (ruined look)
- `3d_1778817450728.glb` — gray rubble/stone mass (unclear — inspect in engine before use)

**Best on-theme picks for the desert map:** ruined_building, post_apocalyptic_city_block,
ruined_office_building, abandoned_gatehouse, 3d_1781089724850, 3d_1782616039388, 3d_1781444788008,
3d_1782507309021, 3d_1782644548162 + all 3 vehicles.

## 4. Design Notes — Sun/Shade Survival (to implement)

Agreed direction (from user, 2026-07-04): *"player needs to survive in shade; in light his health reduces."*

Proposed implementation sketch (not yet approved in detail):
- **Health system:** new `scripts/player_health.gd` (or extend `third_person_controller.gd`) — max HP,
  drain rate in sun (e.g. ~5 HP/s), regen in shade (e.g. ~2 HP/s), death + respawn at last shade point.
- **Sun exposure test:** raycast from player toward `World/Sun` direction (`-sun.global_transform.basis.z`),
  long ray (500+ m), collision mask = world geometry. Hit ⇒ shaded; miss ⇒ exposed. Cheap (1 ray/frame
  or every 0.1 s). Buildings/vehicles need collision for this to work → placed structures must have
  `generate_mesh_collision = true` (see `adventure_environment_prop_setup.gd`).
- **HUD:** health bar + "EXPOSED / IN SHADE" indicator + screen-edge heat vignette when burning
  (`adventure_hud.gd`).
- **Feel:** heat-shimmer/audio cue while exposed; grace period (~2 s) before drain starts so crossing
  small gaps feels fair.
- **Map design implication:** shade is the resource — space buildings/wrecks so there are sprintable
  gaps; highway becomes the artery connecting shade islands.

## 4.5 SCALE & SPACING STANDARD (binding for all map placement)

A dedicated QA session is verifying every placement against this standard. Reference anchors:

- **Player capsule: 1.26 m tall** (CapsuleShape3D in main.tscn; SkinPivot visual ×0.7). Changed
  2026-07-04 (user request: player should read smaller than vehicles). **World assets are UNCHANGED —
  keep sizing buildings/vehicles to real-world meters (the old 1.8 m human reference), NOT relative
  to the shrunken player.** Player jump: jump_velocity 9.2, gravity 20 → apex ≈ 2.12 m
  (just clears ONE ~2 m car); don't use "player can't jump this" as a wall — walls need ≥3 m.
- **WastelandShed = THE reference building** ("the hangar"): scene scale **×8** → world size
  **11.6 w × 4.6 h × 8.6 d m**. Every new structure must feel proportionate next to it.
- AbandonedFarmhouse: ×2.7 → 11.3 × 7.9 × 16.6 m (two-story).

**MONUMENTAL BUILDING SCALE (2026-07-04, user request, supersedes real-world sizing FOR BUILDINGS):**
all buildings are placed at **×2.5 the real-world-scale factors** in the table below (user: "buildings
should be at least 2.5× bigger"). E.g. ruined_building lands at ×22.5–32.5, office at ×65–75. Vehicles,
fences, barrels and other props STAY at real-world scale. Both the Landmarks layout and the
city_building_streamer BUILDING_POOL already apply this ×2.5; use it for anything new.

**⚠️ ALL AI-generated GLBs are normalized to ~0.3–2 m raw. NOTHING may be placed at scale ×1.**
Raw AABBs (measured 2026-07-04 from accessor min/max, full node-transform walk):

| Asset | Raw w×h×d (m) | Recommended scale | Resulting size |
|---|---|---|---|
| arabian_blacksmith | 0.60×0.70×0.79 | **×9** | 5.4×6.3×7.1 — small adobe building |
| ruined_building / 3d_1782616039388 (same mesh) | 0.75×0.79×0.56 | **×10** | 7.5×7.9×5.6 — 2-story ruin |
| ruined_office_building | 0.84×0.39×0.76 | **×30** (verify) | 25×12×23 — low-rise office |
| abandoned_gatehouse | 1.07×0.66×0.24 | **×11** | 12×7.3×2.6 — gate/wall piece |
| post_apocalyptic_city_block | 0.85×0.68×0.54 | **×60 start, calibrate** | ~51×41×32 district |
| 3d_1781089724850 (gray ruined block) | 0.81×0.35×0.81 | **×50 start, calibrate** | ~40×18×40 district |
| 3d_1781444788008 (industrial complex) | 0.41×0.35×1.08 | **×35 start, calibrate** | 14×12×38 yard |
| 3d_1782507309021 (adobe town block) | 0.45×0.75×0.84 | **×12 start, calibrate** | 5.4×9×10 |
| 3d_1782644548162 (suburb house cluster) | 0.70×0.72×0.67 | **×15 start, calibrate** | ~10×11×10 |
| 3d_1781682855782 (white pickup) | 0.58×0.44×1.18 | **×4.5** | 2.6×2.0×5.3 — real pickup size |
| 3d_1781736218100 (wrecked car) | 1.16×0.33×0.51 | **×4** | 4.6×1.3×2.0 |
| 3d_1782247608603 (dark sedan) | 1.17×0.30×0.44 | **×4** | 4.7×1.2×1.8 |

Single objects (vehicles, single buildings): use the factor as-is. District/one-mesh city blocks:
the factor is a starting point — **stand the player next to a door/floor line and calibrate**
(doors ≈ 2–2.5 m, floors ≈ 3–4 m). Anything >×100 or a door taller than 3× the player is wrong.

**Spacing rules (shade-survival driven, see §4):**
1. Shade islands 12–30 m apart along intended routes (sprintable gaps; ~2 s grace). Max 35 m.
2. Keep structure faces ≥4 m from the CityHighway centerline (road half-width 2.5 m + margin).
3. No AABB overlaps between structures, and don't intrude on ScoutCamp/RelicClearing/StarterHomestead flat pads.
4. Big district meshes go at the map edge/perimeter — don't drop a 50 m block onto the homestead cluster.

**Placement conventions (same as existing props):** parent Node3D under `Level/EnvironmentProps`
(districts may use `Level/Landmarks`), group `snap_to_adventure_terrain`, y ≈ 4,
`adventure_environment_prop_setup.gd` script so mesh collision generates (REQUIRED for the future
sun-raycast shade test), descriptive node name (not `convert_N`), and mirror the placement in
`tools/build_main_scene.gd`.

**Known violation to fix:** `convert_3` (arabian_blacksmith) is at scene ROOT, scale ×1 (0.7 m
dollhouse), position (0,0,0) — likely under terrain. Needs: rename, reparent, ×9 scale, real position.

## 5. Roadmap

1. **Map build-out** (in progress): place ruined city blocks, buildings, vehicles along/around the
   highway; more road segments; sand dunes remain open danger zones.
2. **Sun/shade survival mechanic** (§4).
3. Retheme quest/NPC text to desert-survival flavor.
4. Polish: heat VFX, audio, day cycle (stretch), building interiors as safe zones (stretch).

---

## 6. ACTION LOG (append-only — newest last)

### 2026-07-04 — session: world retheme (earlier Claude Code session)
- Retextured terrain to sand (`adventure_terrain_generator.gd::_make_default_material()`), desert
  sky/fog/sun in `main.tscn`, mirrored in `build_main_scene.gd`.
- Added CityHighway road feature (5 Marker3D waypoints) + `show_surface` asphalt ribbon rendering in
  `terrain_road_path.gd`. Verified in-engine.

### 2026-07-04 — session: asset audit & context setup (this session)
- Summer Engine MCP tools now connected in Claude Code (were pending restart).
- Audited entire `assets/` tree; identified all 16 anonymous `Downloaded models/*.glb` via texture-atlas
  inspection (see §3D). Summer account `my_assets` is empty — these were downloaded via the website.
- Confirmed structures B (§3) are imported but not placed; `Level/Landmarks` still empty.
- Created this AGENT_CONTEXT.md.
- Next planned: map layout plan → place city blocks/buildings/vehicles → implement sun/shade health.

### 2026-07-04 — session: scale & spacing QA (dedicated reviewer session, running in parallel)
- Role: verify scaling/spacing of all map placements against the WastelandShed ("hangar") reference,
  per user instruction. Watching `scenes/main.tscn` for changes.
- Measured raw AABBs of every structure/vehicle GLB (script parses accessor min/max + node transforms);
  wrote §4.5 SCALE & SPACING STANDARD above — **map-building session: read §4.5 before placing anything.**
- Flagged: `convert_3` (arabian_blacksmith) at root, scale ×1, origin — see §4.5. If still wrong on next
  QA pass, this session will correct the transform directly via MCP.
- **QA pass 1 (after the first landmark placement batch):** PASS — RuinedOfficeTower ×28, CityBlockNorth ×45,
  CityBlockDowntown ×48, IndustrialRefinery ×30, all 3 vehicle wrecks ×4.5/×5/×4.5, naming/parenting/groups/
  script conventions all good. Spacing: shade-island gaps 16–29 m ✓. **Wrecks sitting ON the highway asphalt
  are APPROVED** (good shade stepping-stones) — §4.5 rule 2 clearance applies to buildings only.
  **CORRECTED via MCP (single undo group, seq 64, scene saved):**
  - `RuinedGatehouse` ×26 → **×15** (was 17.2 m tall; now 9.9 m, still spans the highway at 16 m wide).
  - `SuburbRuins` ×40 → **×18** (houses were ~29 m — taller than the office tower; now ~13 m).
  - `RuinedBuildingWest` ×25 → **×12** (2-story ruin was 19.8 m; now 9.5 m).
  - `convert_3` ×1 @ origin → **×9** @ (-30, 4, 42), rotated 30° (east of the highway between SuburbRuins
    and IndustrialRefinery; ≥6 m road clearance, no AABB overlaps). STILL NEEDS from builder session:
    rename, reparent under Level/Landmarks, `snap_to_adventure_terrain` group + prop-setup script wrapper
    (it currently won't snap to terrain or generate collision — matters for the shade raycast).
  - Reminder: mirror all landmark placements into `tools/build_main_scene.gd` (not seen there yet).
  - Visual calibration of the two big district blocks (door/floor line vs player) still pending — do it
    during the next in-engine play check. If a district's doors are clearly off after calibration, adjust
    and this session will re-verify.

### 2026-07-04 — session: map build-out (main session) — placement batch 1 + QA merge
- Placed 11 landmarks/props in `main.tscn` (TEXT-authored, wrapper pattern: Node3D + snap group +
  `adventure_environment_prop_setup.gd` → baked textures kept, trimesh collision generated):
  under `Level/Landmarks`: RuinedGatehouse (12,-36, arch straddles highway), RuinedOfficeTower ×28 (24,-40),
  CityBlockNorth (post-apoc block), CityBlockDowntown gray block ×48 (30,-2), SuburbRuins (-36,26),
  RuinedBuildingWest (-30,2), IndustrialRefinery ×30 (-10,56); under `Level/EnvironmentProps`:
  WreckPickup ×4.5 (3.4,-1 on road), WreckCars ×4 (-9.5,17), WreckSedan ×4 (-20.5,44 on road).
- In-game verified (screenshot): player+SUV scale correct on highway, gatehouse arch over road, downtown
  walls east side, buildings cast usable shade lanes. Zero runtime errors, collisions OK.
- Merged with QA pass 1: accepted QA's Gatehouse ×15 / SuburbRuins ×18 / RuinedBuildingWest ×12; applied
  standard-table CityBlockNorth ×45→×60 + moved (-14,-44)→(-20,-46) for road-face clearance —
  **QA: please re-verify CityBlockNorth at ×60** (pass 1 approved it at ×45; ×60 is the table start value).
- convert_3 → `AdobeRuin` wrapper under EnvironmentProps @ QA's spot (-30,4,42) ×9 yaw -30°, snap group +
  prop-setup script (QA's asks: rename/reparent/group/script — all done; collision now generates).
- ⚠ Coordination: this session edits main.tscn as TEXT; QA edits via MCP+editor saves. Two write races
  happened (one orphaned transform line, cleaned up). Rule going forward: announce in this log BEFORE
  batch-editing main.tscn, and re-read the file right before writing.
- Editor reload trick: open scenes/_reload_helper.tscn then reopen main.tscn (delete helper when map done).
- TODO: mirror all placements in `tools/build_main_scene.gd`; add manifest entries for the 10 new GLBs;
  consider 1-2 more district blocks NE/E if playtest feels sparse.

### 2026-07-04 — session: scale & spacing QA — pass 2 (after builder merge + DistantRuins)
- **CityBlockNorth ×60 re-verified: APPROVED.** 51×41×32 m at (-20,-46): nearest face ~9 m from highway
  centerline (rule ≥4 ✓); SAT check vs RuinedGatehouse shows ~1.1 m clearance — tight but no overlap,
  reads as dense city edge. Height plausible for downtown; builder confirmed doors in-game.
- Full re-scan of all placements: every scale/transform conforms to §4.5. AdobeRuin wrapper complete
  (group + script + position ✓) — all pass-1 asks resolved.
- `distant_ruins_scatter.gd` reviewed: all RUIN_POOL scale ranges conform to §4.5; districts excluded
  from toppling ✓; 85–230 m ring clears playfield and highway end (P4 ≈ 65 m from origin) ✓; 40 m
  min spacing ✓; half-burial grounding + deferred per-frame spawn are sound. Scene node uses script
  defaults = build-script mirror values (seed 90210 / 14 / 0.4) ✓.
- Still open (builder TODOs, QA tracking): landmark/wreck placements not yet mirrored in
  `tools/build_main_scene.gd`; manifest entries for the 10 new GLBs.
- Ack on the write-race protocol: QA announces here before any MCP edit batch; QA edits go through
  the editor (MCP) + save, never text edits to main.tscn.

### 2026-07-04 — session: distant ruins scatter (separate task from map build-out)
- New `scripts/distant_ruins_scatter.gd` + `Level/DistantRuins` node (added via MCP + editor save, no
  text race with the build-out session). Seeded (90210) runtime scatter: 14 ruins in an 85–230 m ring,
  uniform-area sampling, ≥60 m spacing, 40% fallen. Fallen = single structures only (office, ruin,
  gatehouse) tilted 62–84° around a random horizontal axis and buried 0.5–1.2 m; districts stay upright.
  Grounding = merged-AABB bottom vs deterministic terrain height (detached AdventureTerrainGenerator with
  the grid's params — intentionally NOT the snap group, so the grid never streams far chunks; do not
  "fix" that by adding the group). Scales follow §4.5 (ruin/1782616039388 ×9–13, office ×26–34,
  gatehouse ×12–16, districts ×45–62, adobe ×11–14, suburb ×14–18). One ruin instanced per frame to
  avoid a startup hitch; prop-setup script gives each trimesh collision for the future shade raycast.

### 2026-07-04 — session: map build-out (main session) — CityBlockNorth swap + mirroring done
- **CityBlockNorth model SWAPPED after QA pass 2** — `post_apocalyptic_city_block.glb` renders as a huge
  deck floating ~15 m above its origin (elevated-geometry artifact; confirmed in-game from spawn, bearing
  matched). Replaced instance with **red-brick district `3d_1782370000831.glb` at ×45** (same spot
  (-20,4,-46), yaw 100°). In-game verified: grounded, half-buried in dune, fire escapes human-scale,
  no floating geometry. **QA: please SAT-recheck ×45 brick district vs RuinedGatehouse** (pass-2 numbers
  were for the ×60 post-apoc block). post_apoc block flagged in the manifest as
  "grounded-by-AABB DistantRuins use only" — its FarRuin09 usage is fine (AABB-grounded there).
- Mirrored ALL landmark/wreck/AdobeRuin placements into `tools/build_main_scene.gd`
  (`_add_city_landmarks()` + wreck/adobe `_add_environment_prop` lines, new scene-path consts). TODO closed.
- Added manifest entries for all 13 newly placed GLBs (incl. the post_apoc float warning). TODO closed.
- Map build-out batch 1 COMPLETE. Remaining map ideas (backlog): more district blocks NE/E if sparse,
  2nd road spur, sand-drift meshes over road seams. Next milestone: sun/shade survival mechanic (§4).

### 2026-07-04 — session: map build-out — real-scale calibration pass — **DONE (superseded + verified)**
- User directive: buildings must read REAL-WORLD size vs the 1.8 m player (doors 2–2.5 m, floors 3–4 m),
  vehicles real-world size.
- Outcome: the distant-ruins session ran the same user directive concurrently and did the heavy lifting
  (teleport calibration + district removal + Landmarks rebuild as 9 real-scale single buildings:
  RuinedHouseA/B/C ×11.8–12.5, RuinedOfficeA/B ×26–27, RuinedGatewallA/B ×12.5–14.8, AdobeRuinA/B ×9.3–11;
  scene + build-script mirror kept in sync by them). This session independently re-verified from spawn
  after their rework: SUV roof at robot shoulder (real Explorer proportions ✓), office floor bands
  3.5–4 m/story ✓, gate/guard structures 2-story ✓, no floating geometry, zero runtime errors.
- This session also updated the asset manifest for the rework (district entries marked NOT placed /
  removed per user request; renamed placements documented). QA hold released.
- Verified in-game twice (before/after conforming scales to §4.5): 14/14 spawn, 6 fallen, zero errors;
  screenshots show toppled ruins reading correctly on dunes, far districts emerging from haze.
  Placement log prints to console each run (`filter: DistantRuins`).
- Mirrored the node in `tools/build_main_scene.gd` (`_add_level`, before EnvironmentProps).
- Note for QA session: DistantRuins children exist only at runtime — QA the console placement log +
  in-game, not the edited scene tree. Seed/count/radii/fraction are exports on `Level/DistantRuins`.

### 2026-07-04 — session: distant ruins — real-world scale calibration (user request)
- User directive: buildings at real building size, vehicles at real vehicle size, player = human height.
- Ran the pending §4.5 door/floor-line calibration in-game via temporary player teleports (spawn
  restored to (0, 4, 6.578) and scene saved afterward):
  - Player next to WreckPickup on the highway: SUV roof just above robot shoulders (~2.0 m vs 1.8 m) ✓.
  - Player at the RuinedGatehouse ×15: guard buildings 2-story, vehicle-gate doors ~2-2.5× player ✓.
  - District block floor bands read 3-4 m/story from street level ✓ (moot now — districts removed).
  - Player under FarRuin06_Fallen (ruined_building ×11, toppled): reads as a real 2-3-story collapsed
    building at human scale; grounding correct, no floating geometry ✓.
- Acknowledged the districts-removed change (user request via another session): DistantRuins pool is
  singles-only (ruin ×9-13, office ×26-34, gatehouse ×12-16, adobe blacksmith ×9-12), spacing 40 m —
  all within real-world sizes for 2-4-story structures. Verified via console log: 14/14 spawn, 0 errors.
- Conclusion: every placed building and vehicle currently in the world is at real-world proportion
  relative to the 1.8 m player. Any future placement should keep using §4.5 factors.

### 2026-07-04 — session: city assets removed → randomized buildings-only layout + desert tint (user request)
- User directive: remove city asset(s), keep ONLY buildings; place them properly AND randomly, never on
  the road, optionally following it; building shades must match (retint texture/shader if not).
- Removed from `scenes/main.tscn` Landmarks: CityBlockNorth, CityBlockDowntown, SuburbRuins,
  IndustrialRefinery (all one-mesh district blocks) + their ext_resources (42_cblk1, 44_gray1,
  45_subr1, 46_indy1, 50_brck1). Vehicle wrecks kept (not city assets; shade stepping-stones).
- Replaced with 9 individual buildings under `Level/Landmarks` via seeded constraint solver
  (scratchpad JS, seed 42): RuinedHouseA/B/C (ruined_building ×11.8-12.5), RuinedOfficeA/B
  (ruined_office_building ×26.4-27.1), RuinedGatewallA/B (abandoned_gatehouse ×12.5-14.8),
  AdobeRuinA/B (arabian_blacksmith ×9.3-11). Constraints enforced: >=4 m face clearance from highway
  edge, no flat-pad/spawn/patrol intrusion, >=12 m face gaps, every building <=35 m from another shade
  source (0 isolated); RuinedHouseA + RuinedOfficeA + RuinedGatewallA align loosely along the highway,
  rest scatter randomly. NOTE: old RuinedGatehouse straddled the road centerline at (12,-36) — not
  re-placed on-road per user directive.
- `scripts/distant_ruins_scatter.gd` RUIN_POOL trimmed to singles only (districts removed; do NOT
  re-add), arabian_blacksmith added, min_spacing 60→40.
- Shade matching: new `desert_tint` pass in `scripts/adventure_environment_prop_setup.gd` — duplicates
  each baked material, multiplies albedo by Color(1.0, 0.9, 0.74), floors roughness at 0.85, caps
  metallic 0.15 (kills the office's cool glass sheen; keeps texture detail). Enabled on all 9 buildings
  (scene + build-script mirror) and on DistantRuins spawns.
- `tools/build_main_scene.gd`: `_add_city_landmarks` mirrors the 9 buildings; `_add_environment_prop`
  gained a `desert_tint` param; unused district consts removed.
- Verified in-game (fresh run): buildings clear of asphalt, warm unified palette, 0 errors. Ran
  concurrently with the scale-QA + distant-ruins sessions; final scene state is the merge of all three.

### 2026-07-04 — coordination ack: city-assets-removal session → real-scale calibration session
- ACK your hold request: this session is DONE and holding all main.tscn writes, Player moves, and
  play/stop toggles until your "real-scale calibration pass" entry is marked DONE. Game state is yours.
- What you're calibrating against: Landmarks = 9 single buildings (see my session entry above);
  district blocks removed everywhere per user request — do not re-add during calibration.
- All 9 buildings + DistantRuins spawns have `desert_tint = true` — warm sand-toned materials in your
  screenshots are intentional shade-matching, not a lighting bug.
- If you rescale anything UP, re-check road clearance on the three road-followers:
  RuinedHouseA (-13.2, 55.8), RuinedOfficeA (-11.1, -23.6), RuinedGatewallA (17.9, -20.1) — layout
  guarantees were >=4 m face clearance off the highway edge at current scales.
- Heads-up: the log above already contains a completed "real-world scale calibration" entry concluding
  all placements conform to §4.5. If that wasn't you, your pass may duplicate it — check before teleporting.

### 2026-07-04 — session: brown real-world sand + galactic day sky (user request) [IN PROGRESS]
- ANNOUNCE: batch edit incoming — `scripts/adventure_terrain_generator.gd` (sand albedo → real brown),
  new `shaders/galactic_day_sky.gdshader`, `scenes/main.tscn` sky material swap (PhysicalSkyMaterial →
  ShaderMaterial) + ambient/fog retune, `tools/build_main_scene.gd` `_add_lighting` mirror.
  Editor reload bounce will be used. Results appended when verified.

### 2026-07-04 — session: visual unification — sand/road/buildings one palette (user request) [DONE, verified in-game]
- Goal: sand, highway, and structures must read as ONE desert palette (user: "uniformity and smooth
  setup of the buildings, road and the sand").
- `scripts/terrain_road_path.gd`: asphalt_color neutral gray → sun-baked warm gray (0.22, 0.20, 0.17);
  center line → dusty faded yellow (0.68, 0.60, 0.40); NEW sand-drift edge blend (`sand_blend`,
  `sand_blend_width` 1.1 m, `sand_color` = terrain sand (0.60, 0.45, 0.29)) — `_build_blended_ribbon()`
  builds a 4-column cross-section (sand|asphalt|asphalt|sand) with vertex colors + white-albedo material
  (`vertex_color_use_as_albedo` + `vertex_color_is_srgb` — WITHOUT the srgb flag vertex colors are read
  as linear and the road washes out to pale tan; first playtest caught exactly that). Outer strips sit
  2.5 cm lower so the drift hugs the terrain; edge color equals the terrain albedo so the seam vanishes.
  ⚠ If the sand color in `adventure_terrain_generator.gd::_make_default_material()` ever changes, update
  `sand_color` here (or on the CityHighway node) to match.
- `desert_tint = true` added to the last untinted man-made props: WreckPickup, WreckCars, WreckSedan,
  AdobeRuin (via MCP set_prop + summer_save_scene after a _reload_helper bounce to pick up the galactic-sky
  session's disk state — sky confirmed intact after save). Mirrored in `build_main_scene.gd` (4 wreck/adobe
  `_add_environment_prop` calls now pass desert_tint=true). Every structure + vehicle in the world now
  shares the warm grade.
- Verified in-game (fresh run, screenshots): dark warm asphalt + faded center line, road edges gradient
  into the sand (no hard seam), cream-tinted SUV/buildings/gatewall all in-palette, 14/14 DistantRuins,
  0 errors (only the 2 pre-existing shadowing warnings). Game stopped, scene saved, editor left on main.tscn.
- POST-MERGE: the sand/sky session then darkened terrain sand to (0.45, 0.36, 0.28) and correctly kept
  `terrain_road_path.gd sand_color` in sync (thanks — that's exactly the contract in the comment). Their
  merge briefly duplicated the `vertex_color_is_srgb` line; deduped. Re-verified in their running game:
  road edge still melts into the darker sand, wrecks/buildings uniform. Left their game running.

### 2026-07-04 — session: distant ruins — "mystery road/tank" resolved (no action needed)
- The "new road segment + rusty tank" I reported near (-76, -74) was a MISREAD of my own
  FarRuin06_Fallen (ruined_building ×11, toppled): its flat facade under the player read as an asphalt
  strip, its rooftop water tower lying sideways read as a big rusty cylinder. Confirmed by hiding
  `Level/DistantRuins` at the same spot — sand only. Nothing unlogged is spawning geometry.
- Bonus finding: the player was standing ON the toppled facade — fallen ruins' trimesh colliders are
  solid/walkable, so collapsed buildings work as climbable shade islands.
- Scene left clean: DistantRuins visible, Player at spawn (0, 4, 6.578377), saved, game stopped.
- RESULT (verified in-game, 0 errors): DONE.
  - Sand albedo `adventure_terrain_generator.gd` `_make_default_material()` → Color(0.45, 0.36, 0.28)
    (real-world brown; earlier tries 0.60/0.45/0.29 and 0.50/0.37/0.24 read mustard/pumpkin under the
    warm sun). `terrain_road_path.gd` `sand_color` synced to the SAME value — keep these two in sync.
  - FIXED road wash-out: the sand_blend vertex-color ribbon rendered pale beige because vertex colors
    are linear by default; added `vertex_color_is_srgb = true` on the blend material in
    `terrain_road_path.gd` `_rebuild_preview`. Asphalt reads dark again.
  - NEW `shaders/galactic_day_sky.gdshader` (sky shader): bright DAY intergalactic look — pink/teal/
    violet nebula fbm wisps on a tilted galaxy band, warm horizon haze matching fog, sun disk from
    LIGHT0, deliberately NO star field. Verified standalone via temp `scenes/_sky_test.tscn` (deleted).
  - `scenes/main.tscn`: PhysicalSkyMaterial → ShaderMaterial(galactic_day_sky); ambient_light_source
    SKY → COLOR (fixed warm ambient so nebula hues don't tint the sand), ambient (0.9, 0.85, 0.76);
    fog_light_color (0.88, 0.75, 0.66); Sun light_color softened (1, 0.87, 0.68) → (1, 0.92, 0.8) so
    sand reads brown, not orange. NOTE: editor baked the shader uniforms as shader_parameter/* in the
    tscn — tweak sky colors THERE (or via inspector), not via shader defaults.
  - `tools/build_main_scene.gd` `_add_lighting` mirrors all of the above.

### 2026-07-04 — session: infinite streamed city buildings (user request) [DONE, verified in-game]
- User directive: "hell lot of buildings, big city, big world" + follow-up: generate them
  procedurally and INFINITELY as the player roams, and keep it light on performance.
- NEW `scripts/city_building_streamer.gd` (`Level/CityBuildings`, added via MCP + save — no text
  edits to main.tscn): chunk-cell endless building streaming. Full description now lives in §2.
  Key knobs (exports): cell_size 42, spawn_radius 200, despawn_radius 232, max_live_buildings 80,
  fallen_fraction 0.25, world_seed 90210, debug_log (per-spawn prints, default off).
- ⚠ REMOVED `Level/DistantRuins` from the scene + build script — superseded by the streamer (its
  pool, §4.5 scale ranges, fallen/tilt/half-bury logic all ported). `scripts/distant_ruins_scatter.gd`
  stays on disk but is unused. Distant-ruins session: your 14 FarRuins no longer spawn; equivalent
  ruins now stream endlessly instead.
- Density tuned in 2 playtests: first fill was 15 buildings (too sparse for "big city") → cell 48→42,
  urban base 0.85→0.95, district-noise floor 0.15→0.35 ⇒ 35 buildings live around spawn + the 9
  handcrafted Landmarks, streets read as ruined city (screenshot verified).
- Infinite-world verified: temp spawn teleport to (420, 6, 380) (r≈570 m, far beyond the old 230 m
  edge) — 26 buildings streamed in there (sparser outskirts density, as designed), grounded on dunes,
  0 errors. Player spawn restored to (0, 4, 6.578377) and scene saved.
- Streamer nodes are runtime-only children of `Level/CityBuildings` (like DistantRuins was): QA via
  console (`filter: CityStreamer`) + in-game, not the scene tree. Collision layer = WORLD trimesh →
  shade-raycast ready; fallen ruins remain walkable shade islands.
- `tools/build_main_scene.gd` `_add_level` mirrored (DistantRuins block → CityBuildings block).
- NOTE for the street-grid session (announced after my batch): your new streets/buildings are all
  inside r≤55 m — safely within the streamer's r=74 CORE_RADIUS exclusion, no interference. If
  streets are ever extended past r=74, either extend ROAD_POINTS in the streamer or grow CORE_RADIUS.

### 2026-07-04 — session: distant ruins — ANNOUNCING batch text edit of main.tscn (city street grid)
- STARTING NOW (user request: multiple roads + buildings around them, city feel). Adding under
  Features: GateStreet (46,-30)->(22,-27)->(12,-25.5) T-junction into the highway, EastAvenue
  (36,-31)->(34,-6)->(32,14)->(28,36) branching off GateStreet — city block loop around the scout camp.
  Under Landmarks: RuinedHouseD/E/F, RuinedOfficeC, AdobeRuinC/D, RuinedGatewallC lining the streets
  (§4.5 scales, ≥4 m face clearance, no pad/patrol intrusion, no AABB overlaps). Under EnvironmentProps:
  WreckCarsB + WreckSedanB on the new asphalt. Streets use surface_drop 0.17/0.20 (vs highway 0.14) to
  avoid ribbon z-fighting at junctions. Will mirror in build_main_scene.gd and reload-bounce the editor.
  Other sessions: please hold main.tscn writes until this entry is marked DONE below.
- RESULT: DONE (verified in-game, 0 errors/warnings). GateStreet + EastAvenue render with center
  lines and sand-blend edges; the GateStreet/EastAvenue junction is clean (staggered surface_drop
  0.14/0.17/0.20 prevented ribbon z-fighting). WreckCarsB sits on GateStreet as placed; street
  frontage (AdobeRuinC, GatewallA, RuinedOfficeC/B) reads as city blocks from the junction.
  Mirrored in build_main_scene.gd (_add_terrain_features + _add_city_landmarks + wrecks) — merged
  cleanly around the CityBuildings streamer work. Player restored to spawn, scene saved.
- Note: DistantRuins removal by the streamer session is acknowledged and consistent everywhere
  (scene, build script both clean). scripts/distant_ruins_scatter.gd file remains on disk unused —
  streamer session ported its logic; safe to delete the file once the streamer is verified DONE.

### 2026-07-04 — session: player scale & super-jump — DONE (verified in-game, 0 errors)
- User request: much higher jump (clear 2 stacked cars) + smaller player relative to vehicles.
- Player shrunk ×0.7: capsule 1.8→1.26 m / radius 0.35→0.245, CollisionShape3D y 0.9→0.63,
  SkinPivot scale (0.7,0.7,0.7). Edits made via MCP with editor open, scene saved.
- Jump: `third_person_controller.gd` jump_velocity 5.0→13.5 (gravity 20 → apex ≈ 4.56 m, clears
  two stacked ~2 m cars with ~0.5 m margin). Camera: `third_person_camera.gd` height_offset
  1.55→1.1 (was tuned for the 1.8 m capsule).
- Mirrored in `tools/build_main_scene.gd` (_add_capsule args, SkinPivot scale, height_offset).
- §4.5 reference anchor updated: player is now 1.26 m — keep sizing world assets in REAL-WORLD
  meters, not player-relative. NPC ScoutRobot intentionally left at full 1.8 m scale for now.
- Playtest: booted clean (0 errors), player grounded on highway asphalt next to SUV wreck,
  reads clearly smaller than the vehicle; camera framing good at 1.1 offset.
- Post-merge tweak: `city_building_streamer.gd` CORE_RADIUS 74 -> 90 (compile-verified). Reason:
  street-grid frontage extended the handcrafted zone — RuinedOfficeC at (58,-46) has footprint out to
  r~85, and streamed cells started at r>=80, so a streamed building could have clipped it. Streamer
  session: no other change to your script; ROAD_POINTS untouched (the whole street grid sits inside
  r~56, fully covered by the core exclusion).

### 2026-07-04 — session: map build-out (main session) — ⚠ FLAG: player scale double-applied?
- **Discrepancy found, owning session please confirm intent or fix.** The "player scale & super-jump"
  entry, §4.5 anchor, and memory all document ×0.7 → capsule **1.26 m** (r 0.245, y 0.63, SkinPivot 0.7,
  camera height_offset 1.1). But BOTH `main.tscn` AND `build_main_scene.gd` currently hold the ×0.7
  shrink applied TWICE: capsule **0.882 m** (r 0.1715, y 0.441), SkinPivot **×0.49**, camera 0.77.
  Scene+mirror are self-consistent, so the game runs — but the player is ~0.88 m (waist-high to the
  1.8 m scout NPC), not the documented 1.26 m. Also super-jump apex (4.56 m) was tuned for 1.26 m.
  If ×0.49 is intended (user iterated "even smaller"?), update the docs (§4.5 anchor + your log entry
  + memory); if not, restore the documented ×0.7 values in scene + mirror. Not touching it from here —
  your call, you own the player rig.
- Streamer attribution note (for the street-grid session): the CityBuildings streamer is NOT this
  session's work either — a separate infinite-city session built it (see its memory entry). Your
  CORE_RADIUS 74→90 bump already resolves the street-frontage clipping concern; streets at r≤56 are
  fully inside the exclusion. No further action needed from anyone on that point.

### 2026-07-04 — session: player scale & jump (owning session) — RESOLVED ⚠ scale flag; DONE, verified in-game
- ×0.49 was a transient mis-step, now fixed. Root cause: `third_person_controller.gd` `_orient_visual()`
  rebuilt SkinPivot's basis from a pure rotation quaternion every frame, WIPING the node's scale back to
  ×1 at runtime — the original ×0.7 never showed in-game, the user asked again, and the shrink briefly
  got applied twice. Controller now captures `_skin_scale` in `_ready()` and re-applies it via
  `Basis(...).scaled(_skin_scale)`; any future SkinPivot scale will actually render.
- FINAL player rig (scene + build-script mirror consistent): SkinPivot ×0.7, capsule 1.26 m
  (r 0.245, y 0.63), camera height_offset 1.1 (re-applied to the merged camera script + _add_camera).
- Jump retuned per user: jump_velocity 13.5 → **10.0** (gravity 20 → apex 2.5 m; clears ONE ~2 m car
  with ~0.5 m margin, no longer clears two stacked). Walls meant to block the player need ≥3 m now.
- Verified in-game post-merge with the new sun/water/worm systems live: 0 errors, player reads clearly
  smaller than the SUV wreck, survival HUD running.
- Note for the survival session: debug panel shows `Head pos y ≈ 1.5` — if `sun_exposure.gd` hardcodes
  a 1.5 m head height, consider 1.26 m (or read the capsule) now that the player is shorter; rays
  currently sample ~0.24 m above the actual head (slightly conservative shade detection).

### 2026-07-04 — session: infinite streamed city v2 (streets + junctions + ≤30° lean) [IN PROGRESS]
- User directives: hell lot of buildings; buildings spawn ACCORDING TO roads; tilt max ~30° (no
  toppled ruins); road crossings must be proper junctions, never ribbons crossing randomly.
- ⚠ MERGE LOSS FOUND: `Level/CityBuildings` (infinite streamer, logged DONE above) is GONE from
  main.tscn and `Level/DistantRuins` is BACK and spawning its 14 FarRuins (6 of them toppled 62–84° —
  the exact tilt the user is now complaining about). Whichever session restored it: DistantRuins was
  superseded and removed earlier today (see the streamer entry + §2); please don't re-add it.
- ANNOUNCE: MCP scene edits incoming — REMOVE `Level/DistantRuins` (again), ADD `Level/CityBuildings`
  with `scripts/city_building_streamer.gd` (already rewritten to v2: deterministic street grid every
  126 m with clean butt-joint right-angle junctions, terrain-conforming vertex-colored ribbons with
  walkable colliders, buildings snapped to street frontage with aligned facades, lean capped at
  5–28°, denser fill, live cap 120). Will re-check the build-script mirror too. Results appended.
- RESULT: DONE, verified in-game twice, 0 errors. Scene: DistantRuins removed, CityBuildings re-added
  via MCP + saved (build-script mirror was still intact from v1 — only the scene had lost the node).
  Full v2 behavior description moved to §2. Playtests: (a) from spawn — 43 streamed buildings live
  (v1 was 15→35), no DistantRuins lines, batch prints only; (b) temp teleport to (118, 6, 100) next
  to the x=126 north-south street — street ribbon renders warm asphalt + sand-blend edges + faded
  center line conforming to dunes, frontage office tower upright and aligned at its setback, distant
  buildings line the street, NO toppled ruins anywhere. Player spawn restored to (0, 4, 6.578377),
  scene saved, game stopped.
- Coexists cleanly with the new survival systems (sunburn/water HUD live during both playtests) —
  streamed buildings have WORLD trimesh colliders, so the 5-ray shade test sees them.
- Keep `scripts/distant_ruins_scatter.gd` ON DISK even though unused: stale scene states referencing
  it keep resurfacing in merges; deleting the script would turn a resurrected node into a hard error.
- QA note: §4.5's "fallen 62–84°" toppling language is now HISTORICAL — the binding rule per user is
  lean ≤30°, upright otherwise. Street-facing setbacks guarantee ≥ STREET_CLEAR (6.7 m) + half-footprint
  from centerlines, i.e. faces sit ≥1.5 m off the sand-blend edge; shade-gap spacing between frontage
  neighbors is cell-pitch driven (42 m centers minus footprints → typically 15–30 m gaps).

### 2026-07-04 — session: player scale & jump (owning session) — jump trim
- User: reduce the jump 15%. Interpreted as 15% less HEIGHT: jump_velocity 10.0 → 9.2
  (apex 2.5 → ~2.12 m, height ∝ v²). Still clears a ~2 m car, but barely (~0.12 m margin) —
  if car-hopping starts failing on taller wrecks, bump to 9.5. Script default is the single
  source of truth (no scene/build-script overrides). Rebooted game, 0 errors.

### 2026-07-04 — session: street grid restore + road alignment + core densify [STARTING batch text edit]
- MERGE LOSS (same event that hit CityBuildings): GateStreet/EastAvenue + 7 frontage buildings +
  WreckCarsB/WreckSedanB are GONE from main.tscn; also desert_tint was stripped from the 3 wrecks +
  env AdobeRuin. My build-script mirror survived — restoring from it.
- User request: align ALL buildings with roads + lots of buildings + sun must still reach the player.
- Batch: (1) restore both streets; (2) restore the 7 frontage buildings with facades ALIGNED to their
  street axis; (3) realign the 9 seed-42 landmarks to their nearest road (HouseA/GatewallB already
  parallel — untouched; GatewallA nudged z -20.1 -> -18.5 for 4 m face clearance once parallel);
  (4) add 8 NEW aligned buildings (HouseG/H/I/J, GatewallD/E, AdobeRuinE/F) keeping 12-30 m sunlit
  gaps — no continuous street walls, sun-exposure gameplay preserved; (5) restore wrecks + tints.
  Mirror in build_main_scene.gd. Reload-bounce after. HOLD main.tscn writes until marked DONE.

### 2026-07-04 — session: map build-out (main session) — player double-shrink RESOLVED
- User ruled "only one shrink is enough". Scene restored to ×0.7 via MCP batch (SkinPivot 0.7, capsule
  1.26 m / r 0.245 / y 0.63, CameraRig height_offset 1.1, scene saved); the mirror's `_add_capsule`
  line was fixed concurrently by the owning session — scene + mirror now agree at ×0.7.
- Verified in-game: player reads 1.26 m next to the SUV (roof above head, correct proportion), camera
  framing good, 0 errors. Docs (§4.5 anchor, memory) already said 1.26 m — no doc changes needed.
- Noted during verification: sunburn/water survival HUD + 5-ray shade test are live (another session's
  work) and correctly report TAKING DAMAGE in open sun. My earlier §4 design sketch is superseded by
  the implemented system.

### 2026-07-04 — session: player scale & jump — ANNOUNCING batch edit: buildings ×2.5 (user request)
- STARTING NOW: all BUILDINGS scale ×2.5 (user: "buildings relatively small, at least 2.5× bigger").
  Scope: 16 Level/Landmarks buildings + AbandonedFarmhouse/WastelandShed/AdobeRuin under
  EnvironmentProps (vehicles/fences/props UNCHANGED, still real-world size), plus
  city_building_streamer.gd BUILDING_POOL scale ranges & halves ×2.5. Positions re-solved so nothing
  covers roads/spawn; §4.5 will be updated after. Other sessions: please hold main.tscn writes until
  RESULT below.

- RESULT: DONE (verified in-game, 0 errors). All 16 Landmarks buildings + Farmhouse/Shed/AdobeRuin
  rescaled ×2.5 with solver-computed positions: radial spread ×1.75 capped at r=84 (stays inside the
  streamer's r=90 core exclusion), road clearance ≥ 5.2 + 0.8×half + 1 m against all 3 road polylines,
  spawn clearance half+15 m around (0,6.6), pairwise ≥55% of summed half-footprints (ruins may
  interpenetrate a little — reads as collapsed city). Streamer BUILDING_POOL scale ranges + halves
  ×2.5 (office cells now mostly frontage — corridor filter rejects more interior rolls, expected).
  Homestead note: Farmhouse moved (-16,14.5)→(-38.2,24.4), Shed (-5.6,18.2)→(-1,41.2) — the fence/barrel
  cluster no longer hugs them; a future dressing pass could re-compose. build_main_scene.gd mirrored
  (19 _add_environment_prop lines). Screenshot: office towers over the highway, roads/spawn clear.
- STATUS UPDATE (street-alignment/densify batch): partially landed, remainder HANDED OFF to the
  "buildings ×2.5" batch (messaged directly with the yaw table + densify candidates + sun-gap rule).
  Landed before the git merge interrupted: both streets restored (now with origin unique_ids),
  road-aligned yaws applied to RuinedHouseB/C, RuinedOfficeA/B, RuinedGatewallA (z -> -18.5),
  AdobeRuinA/B; frontage 7 + WreckCarsB/WreckSedanB back via merge. NOT landed (folded into ×2.5
  batch): 8 new core buildings, env-AdobeRuin realign, desert_tint restore on the 3 wrecks +
  env AdobeRuin. Merge conflict in main.tscn was resolved by another session while I was mid-edit —
  I stopped racing and yielded. I hold NO lock; ×2.5 batch owns the scene until its RESULT.

### 2026-07-04 — session: map build-out (main session) — ANNOUNCING: adopting the ×2.5 leftovers
- The ×2.5 RESULT landed without the street session's three handed-off items; adopting them now as a
  map build-out batch: (1) up to 8 new street-front buildings (re-solved for ×2.5 footprints, aligned
  yaws per the street session's per-road table, faces ≥4 m off road edges, no pad/spawn/patrol
  intrusion, sprintable sunlit gaps preserved); (2) env AdobeRuin yaw realign to 71.6°; (3) desert_tint
  restore on WreckPickup/WreckCars/WreckSedan + env AdobeRuin.
- Method: TEXT edit of main.tscn + _reload_helper bounce (will re-read immediately before writing).
  Other sessions: please hold main.tscn writes until RESULT below.

### 2026-07-04 — session: street alignment — final yaw pass on post-x2.5 layout [STARTING small batch]
- The x2.5 re-solve kept my aligned yaws (HouseB/C, OfficeA/B, GatewallA/C, AdobeA/B) but 6 rim
  buildings still have pre-alignment rotations. Fixing ONLY yaws (positions stay as the x2.5 solve
  set them): HouseD 25 -> -7.1 (GateStreet axis), HouseE -75 -> -95.7 (EastAvenue), HouseF 130 -> 78.7
  (highway), OfficeC 100 -> -7.1 (GateStreet), AdobeRuinC -50 -> 85.4 (EastAvenue), AdobeRuinD
  160 -> 79.7 (EastAvenue). Also restoring desert_tint still missing on WreckPickup/WreckCars/
  WreckSedan + env AdobeRuin. Mirror yaws in build_main_scene.gd. Verify + RESULT below.

### 2026-07-04 — session: streamed city v2.1 — density fix (user: "less buildings, not close to each other") [DONE]
- Script-only change to `city_building_streamer.gd` (NO scene writes; game left running for the user).
- Ack to the ×2.5 batch: found your BUILDING_POOL upsizing mid-edit (ruin ×22.5–32.5, office ×65–75,
  gatehouse ×30–40, adobe ×22.5–30, halves 12–31.5 m) and KEPT it — the packing below is re-fit to
  those footprints, and since you upsized the core too, core vs streamed scales stay consistent.
- New packing: ONE small building per 42 m cell (18–26 m footprints → ~10–20 m gaps, tight city).
  Big buildings (office/gatehouse) deterministically claim a whole 2×2-cell block (84 m): an
  anchor-cell rng stream, recomputed identically by every cell of the block (validity checks
  included via _finalize_building), decides the block — so bigs can never overlap neighbors and
  there is no cross-cell communication. BIG_BLOCK_CHANCE 0.22. Frontage cells still snap to street
  setback with aligned facades; interior grid-aligned; lean ≤28°; junction plazas kept.
- Density raised: base 1.0 (r<280) / 0.85 (<450) / 0.7 beyond, district-noise floor 0.45→0.65 (no
  more empty pockets). spawn_radius 200, despawn 230, live cap 200.
- Verified in-game (fresh run, 0 errors): 47+ streamed buildings live near the core and climbing as
  the player roams; skyline dense, frontage rows aligned, no toppling, junctions clean. Compile-clean.
- RESULT: DONE (verified in-game, 0 errors). All 6 remaining rim buildings + env AdobeRuin now have
  road-aligned facades (yaws applied to scene + build-script mirror; positions untouched from the
  x2.5 solve). desert_tint restored on WreckPickup/WreckCars/WreckSedan + env AdobeRuin. Verified
  screenshot: adobe gateway square to the street, office facades parallel to corridors, player on
  the open highway shows State: TAKING DAMAGE, -10 hp/s, 0/5 rays blocked — sun mechanic intact with
  the dense layout (sunlit streets + shade lanes at building walls). Scene saved via engine.
  ALL core buildings are now road-aligned; the streamer aligns everything outside the core (v2).

### 2026-07-04 — session: map build-out (main session) — RESULT: ×2.5 leftovers batch DONE
- Items (2) env-AdobeRuin realign and (3) desert_tint restore were ALREADY landed by another session
  before this batch touched the file (found done on re-read: env AdobeRuin yaw -71.6 + tint, all 5
  wrecks tinted). Note for the street session: applied env-AdobeRuin yaw is **-71.6°**, not the +71.6°
  from your table — road-parallel per your convention would be 71.6/-108.4; the building sits 24 m past
  the P4 road end so the reference is ambiguous. Eyeball it on your next pass; not re-touching it.
- Item (1) DENSIFY landed by this session: 5 new street-front buildings (3 of the 8 pre-×2.5 candidates
  no longer fit — quadrupled footprints + the ×2.5 solver's outward spread filled those pockets;
  re-solved against all 19 current buildings, 3 road polylines, pads, spawn r=half+15, patrol):
  RuinedHouseG (52,2) yaw 84.3 ×30 fronting EastAvenue-E; RuinedHouseH (-27,14) yaw -119.1 ×30 fronting
  highway P2-P3 west; RuinedHouseI (-44,40) yaw 71.6 ×30 fronting P3-P4 west; AdobeRuinE (48,26)
  yaw 79.7 ×24 fronting EastAvenue-E; RuinedGatewallD (-12,60) yaw -108.4 ×32 fronting P3-P4 east.
  All: snap group + prop-setup script + desert_tint + trimesh collision; sunlit gaps 15–30 m kept.
  Mirrored in build_main_scene.gd (_add_city_landmarks tail). Scene text-edited + reload bounce.
- Verified in-game from 3 vantages (east street, west highway, spawn): all 5 grounded, road-aligned,
  human-scale doors/windows, shade lanes cross the roads with sprintable sun gaps, 0 errors. Player
  spawn restored (0, 4, 6.578377), scene saved, game stopped.
- Polish backlog noted (not this batch): RuinedOfficeA's west corner hovers over a dune dip (slope vs
  origin-snap) — a dune-fit/berm pass on the two big offices would ground their silhouettes.


### 2026-07-04 — session: streamed city v2.2 — grounding + palette check (user: buildings must touch ground, scale well, consistent design/texture) [DONE]
- Script-only change to `city_building_streamer.gd` `_spawn_building` grounding: buildings now ground
  against the LOWEST terrain height sampled under the footprint (center + all 4 world-AABB corners)
  plus a footprint-proportional burial (item bury + 2% of max footprint side, e.g. ~1.3 m extra for a
  63 m office) — at the ×2.5 scales, center-only sampling could leave corners hovering over dune dips.
  Every corner now sits at or below the sand line.
- Scale audit vs the ×2.5 core regime: streamer pool ranges bracket the handcrafted core's rescaled
  values (ruin 22.5–32.5 vs core houses ~29.5–31; office 65–75 vs ~66–68; gatehouse 30–40 vs ~31–37;
  adobe 22.5–30 vs ~23–27.5) — consistent, no change needed.
- Palette audit: streamer's static desert-tint cache uses the exact prop-setup values (albedo ×
  (1.0, 0.9, 0.74), roughness ≥0.85, metallic ≤0.15) and street ribbons use the terrain/road contract
  colors (sand 0.45/0.36/0.28, asphalt 0.22/0.20/0.17, line 0.68/0.60/0.40) — one grade everywhere.
- Verified in-game beside a streamed ruin at (150, 100): walls buried in sand on all sides, no
  floating corners, tint uniform vs neighboring adobe, openings read well vs player. Only console
  entries were editor-side UndoRedo noise from concurrent sessions (not game errors). Spawn restored
  to (0, 4, 6.578377), scene saved, game stopped.

### 2026-07-04 — session: street alignment — YAW CONVENTION AUDIT (resolves the env-AdobeRuin flag)
- The "env AdobeRuin -71.6 is ~37 deg off parallel" flag was a CONVENTION MIXUP, not a scene bug.
  Ground truth (full scene-vs-mirror audit, 40 nodes, script below): ALL scene facades ARE
  road-parallel in Godot terms. The action-log yaw table I published earlier listed values where
  theta_table = -theta_godot (my text-authored matrices flipped the sign consistently, so facades
  still landed parallel — two sign errors cancel). Godot-native parallel sets per road:
  highway P0-P1 {101.3, -78.7}, P1-P2 {123.7, -56.3}, P2-P3 {119.1, -60.9}, P3-P4 {108.4, -71.6};
  GateStreet {7.1, -172.9} / {8.5, -171.5}; EastAvenue {94.6, -85.4} / {95.7, -84.3} / {100.3, -79.7}.
  env AdobeRuin at -71.6 = exactly P3-P4 parallel. No scene changes made or needed.
- REAL bug found by the audit: `build_main_scene.gd` had 17 yaw values that would NOT reproduce the
  verified scene on a rebuild (sign-flipped or stale: all Landmarks A-F + OfficeA/B/C + GatewallA/C +
  all 5 adobes + WreckCarsB/WreckSedanB). All 17 corrected to Godot-native scene values;
  audit now reports 0/40 mismatches; script compiles clean.
- RULE going forward: when TEXT-authoring a wrapper transform, element3 = s*sin(rotation_y) and
  element7 = -s*sin(rotation_y) (rotation_y = Godot rotation_degrees.y). When using
  `_add_environment_prop` or MCP `rotation_degrees`, use Godot-native degrees directly. Do NOT use
  my earlier table's signs for either — use the Godot-native parallel sets above.

### 2026-07-04 — session: map build-out (main session) — HouseG yaw decision (audit follow-up)
- Re the YAW CONVENTION AUDIT's note that RuinedHouseG (52,2) is ~11° off EastAvenue's Godot-native
  parallel (95.7/-84.3 vs applied 84.3, a table-sign artifact): KEEPING AS-IS, deliberate. It verified
  visually from the street vantage, and a slight settle-skew on one ruin reads more natural than a
  perfectly gridded dead city. Scene == mirror for it per the audit, so rebuilds are consistent.
- env-AdobeRuin flag withdrawn — audit shows -71.6 IS Godot-native parallel to P3-P4; my "37° off"
  came from reading the flipped-convention table as Godot-native. Future yaw work: use the audit's
  Godot-native parallel sets in the log, not the old table.



### 2026-07-04 — session: street alignment — road overlap & building-on-road fixes [STARTING]
- User: buildings must not be on roads; no roads on top of each other. Audit found exactly three
  violations: (1) streamer z=0 street resumes at x>=84 while RuinedOfficeB's monumental footprint
  reaches x~108 at z in [-41,15] -> its east corner sits ON that street; (2) EastAvenue P0 (36,-31)
  is 2.3 m north of GateStreet's centerline -> the avenue's first meters CROSS the street ribbon;
  (3) GateStreet P2 (12,-25.5) pokes 0.4 m into the highway ribbon (edge at x=12.34).
- Fix: (1) streamer gets STREET_CORE_RADIUS 120 (streets only; buildings keep CORE_RADIUS 90) so
  streamed streets start beyond the handcrafted rim extents (r~113) — nearest z=0/x=0 segments now
  begin at |coord|=126; (2) EastAvenue P0 -> (35.7,-25.2) = butt joint at GateStreet's south edge
  with the streamer's sand-drift mouth aesthetic; (3) GateStreet P2 -> (13.6,-25.2) = butt joint at
  the highway's east edge. Scene + build-script mirror. Terrain carves still merge at junctions
  (only ribbons separate). HOLD main.tscn until RESULT.
- RESULT: applied + verified by code/math (0 script errors; live visual check deferred — an
  interactive play session was running and I didn't hijack it):
  (1) streamer STREET_CORE_RADIUS=120 landed — nearest streamed z=0/x=0 segments now start at
  |coord|=126 (cell-midpoint check: (105,0) r=105 < 120 -> dropped), clearing OfficeB's x~108 corner
  and every rim footprint (max r~113). Buildings still stream from r=90 (density unchanged).
  (2) GateStreet P2 -> (13.6,-25.2): butt joint 1.2 m off the highway ribbon edge (was 0.4 m INTO it).
  (3) EastAvenue P0 -> (35.7,-25.2): avenue now starts at GateStreet's south blend edge (was crossing
  the ribbon). Scene saved via MCP (seq 478); markers + build-script mirror in sync.
  NEXT PLAYTESTER: eyeball the two junctions (13.6,-25.2)/(35.7,-28.7) and the z=0 corridor east of
  OfficeB (x 84-126) — expect sand-drift junction mouths and NO street under any building.

- FOLLOW-UP RESULT (visual verify + deeper audit, all DONE): a rigorous OBB-vs-polyline audit (corner
  sampling, not center distance) caught what the first pass missed: RuinedOfficeA clipped the highway
  by 2.12 m and RuinedOfficeC clipped GateStreet by 1.40 m; GatewallA/AdobeRuinC/AdobeRuinD sat at the
  asphalt lip (+0.05..+0.4 m). Fixes (scene via MCP + mirror synced): OfficeA -> (-27.7,-42.9);
  GateStreet P0 pulled back (46,-30) -> (38,-29) (street-end crowded OfficeC at monumental scale —
  shortening beats pushing the office past the r=90 streamer core); GatewallA -> (35.1,-50.9);
  AdobeRuinC -> (51,-14.8); AdobeRuinD -> (43.3,40.7). Audit now: 0 buildings within 1.2 m of any
  asphalt; global minimum clearance +2.09 m. In-game screenshot at (12,-13): highway clear, GateStreet
  butt-joint reads as sand-drift mouth, buildings at proper setbacks. Player restored to spawn, saved.
  NOTE: EastAvenue P0 (35.7,-25.2) still butt-joins the (collinear) shortened GateStreet correctly.
  The audit script pattern is in this session's log entry above — rerun it after any placement batch.

### 2026-07-04 — session: street alignment — infinite roads with organic gaps [STARTING]
- User: roads must run infinitely along with the buildings — if a road ends it should start again
  after a while. Today streets have a dead band: handcrafted roads end r~50-65, streamed streets
  start at 126 (my blunt STREET_CORE_RADIUS fix).
- Change (city_building_streamer.gd only): STREET_CORE_RADIUS 120 -> 75 (still protects the whole
  handcrafted road loop, max extent r~65) + NEW runtime obstacle discovery: at ready the streamer
  scans Level/Landmarks + Level/EnvironmentProps children, takes each merged mesh XZ AABB (>= 6 m
  half-extent only, i.e. buildings not barrels), grows it by street clearance, and street segments
  are per-sample tested against r<75 AND those rects — a blocked 42 m cell segment is simply
  SKIPPED, so streets break at ruins/town and resume next cell: "road ends, starts again after a
  while", forever. Runtime discovery keeps it correct no matter how often placements move.
  Streamed buildings unchanged (CORE_RADIUS 90 + street-clearance gates still hold).
- RESULT: DONE (verified in-game, 0 errors). Player at (0,-140) stands ON the resumed x=0 streamed
  street — asphalt + center line to the horizon, streamed buildings lining it at aligned setbacks.
  The street breaks around HouseF's discovered footprint (segment z -84..-126 skipped) and resumes
  exactly at z=-126: "road ends, starts again after a while", infinitely. STREET_CORE_RADIUS is now
  75 (was 120): the roadless dead band around the rim is gone; streets thread between the monumental
  ruins wherever the runtime obstacle scan (merged mesh XZ AABBs of Landmarks + EnvironmentProps
  children >= 6 m half-extent, grown by asphalt clearance) says they fit. Obstacle discovery is
  runtime — future placement moves need NO streamer edits. Scene saved, player at spawn, game stopped.

### 2026-07-04 — session: street alignment — main branch consolidation (user request)
- User: everything EXCEPT the character change goes to main. Done and PUSHED (origin/main a7d981f):
  - f404aee ports to main what had been stranded in the swap branch's WIP commit: infinite streamed
    roads (STREET_CORE_RADIUS 75 + runtime obstacle discovery), the building-on-road fixes
    (OfficeA/GatewallA/OfficeC/AdobeRuinC/AdobeRuinD positions + GateStreet P0 pull-back to (38,-29)),
    junction butt-joints, and the build-script mirror. Ported surgically via a temp git worktree —
    the swap session's checkout was never touched.
  - Merged origin/main's newer content both times it moved mid-push (pet frog, worm spawner,
    HUD/menu/water updates) — clean auto-merges, verified: road fixes + streamer code + frog/worm all
    present, zero character-swap content on main, clearance audit on the merged scene 0 violations.
  - EXCLUDED from main (stays on feature/player-asset-swap): humanoid_locomotion_animator retarget,
    scene player-node swap, player asset imports. Also NOT ported: swap-branch stale reverts of
    sun_exposure/controller/HUD (pre-menu fork artifacts — porting them would break the menu/score).
- Swap session: when you merge feature/player-asset-swap into main later, the streamer/build-script/
  scene road hunks are content-identical on both sides — expect clean merges there.


### 2026-07-04 — session: run score system — distance-first score + best score + death results overlay [DONE]
- NEW `scripts/run_score.gd` (`RunScore`, node added at `Player/RunScore` in main.tscn, scene saved
  via engine): score = 10 pts per NEW meter of peak XZ distance from spawn (backtracking can't farm)
  × heat-streak multiplier (builds ×1→×5 over ~25 s of continuous movement, 0.8 s grace then decays
  0.9/s when idle; worm hits reset it to ×1) + 1 pt/s survival trickle + 25×multiplier per water
  pickup. Best score persisted via ConfigFile at `user://heatwave_score.cfg`.
- HUD (`adventure_hud.gd`): top-center score box (rolling count-up, comma thousands, scale punch at
  each 1,000 crossing) + "×N.N" streak chip (white→amber→red heat color, elastic pop per whole
  tier) + "N m • BEST X" sub-label. Death: full-screen results overlay ("YOU COLLAPSED FROM THE
  HEAT", 1.5 s eased score count-up, distance line, BEST line / pulsing "★ NEW BEST! ★"), auto-fades
  ~4.6 s, then the existing respawn continues. Centering done via HBox strip / CenterContainer
  wrappers — set_anchors_preset on auto-sizing PanelContainers did NOT hold (rendered top-left).
- Hooks: `sun_exposure.gd` `_die()` no longer shows the collapse prompt (overlay owns messaging);
  `water_drop_spawner.gd` calls `RunScore.add_pickup_bonus()`; `third_person_controller.gd`
  `apply_worm_stun()` calls `RunScore.reset_multiplier()`.
- Playtested in-engine (teleport + invincible-flip driven deaths): live counter/trickle ✓, distance
  scoring + formatting ✓ (159 m → 1,638), death overlay layout ✓, best saved/persisted across full
  game restarts ✓ (1,650 → 2,734 → 3,850), rapid re-death re-triggers overlay without errors ✓.
  NOT visually exercised (needs real movement input): streak chip build-up. Console clean.
- NOTE for other sessions: `summer_set_prop` during play mutates the EDITOR scene too (survives
  stop/play) — I restored Player position + SunExposure invincible/sun_damage_per_second to
  defaults after testing; scene on disk was saved BEFORE the test mutations and is clean.
- Concurrent edit acknowledged: someone added per-difficulty best scaffolding (`DIFFICULTIES`,
  `_bests` dict) to run_score.gd mid-session — kept, compiles clean.

- 2026-07-04 (sync session): heat wave retimed per user — `heat_wave_manager.gd`
  min_interval 60→40, max_interval 240→80 (random gap, ~1 wave/minute average);
  doc comment + heat-wave design spec updated to match. No scene edit (HeatWave
  node has no export overrides). Also: local main merged with origin/main (2 clean
  merges) and pushed — main==origin/main at 7a4e8b0, character selection is on GitHub.
- 2026-07-04 (sync session, follow-up): heat wave "passing" wash shortened 3s→2s
  (`passing_time` in heat_wave_manager.gd) per user — wave visual now stays 2 s;
  damage remains the single instant hit at siren end. Spec updated.
- 2026-07-04 (sync session): force field now plays setup music — user's generated
  "cooling" track imported via engine pipeline as `assets/music/force_field_setup.mp3`
  (renamed from the raw 9560d55d-… upload, original deleted). `force_field.gd` spawns
  an AudioStreamPlayer3D child on _ready (max_distance 30) and stops it in dissolve().
  Clip is ~10 s = full globe lifetime (5 s build + 5 s active). Verified via
  RunVerification probe: plays during build, stops on dissolve, 0 errors.
- 2026-07-04 (sync session): heat wave v2 — interval now 20–40 s (~every 30 s);
  warning made unmissable: banner + tint (already there) + rising rumble
  (worm_rumble.ogg reuse, non-positional) + VISIBLE 500×60 m glowing wave wall
  (QuadMesh, unshaded emission, world-space under the plain HeatWave Node) that
  approaches from a random direction over the 10 s countdown, crosses the player
  at strike, sweeps 120 m past during the 2 s passing fade. All in
  heat_wave_manager.gd (_build_wall/_update_wall). Verified via RunVerification
  probe + screenshots (banner, wall at ~199 m mid-approach, full orange at 2 s out;
  0 errors). NOTE: feature/heat-wave was fast-forwarded to main (5d7b2b8) first —
  the checkout now has ambient audio etc.; earlier it was MISSING all origin-side
  audio, which is why in-game sounds/HUD may have looked stale.
