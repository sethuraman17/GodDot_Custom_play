extends Node3D
class_name CityBuildingStreamer

## Streams an endless ruined CITY around the player, chunk-style: streets + buildings.
##
## The world is divided into fixed square cells; every cell inside spawn_radius
## deterministically rolls (world_seed mixed with its coords) what it contains, so the
## layout is stable across revisits and runs without ever storing it. Cells beyond
## despawn_radius are freed behind the player.
##
## STREET GRID: a deterministic global grid of asphalt streets every STREET_SPACING
## meters along world X and Z. Crossings are therefore always clean right-angle
## junctions — never diagonal ribbons overlapping at random. East-west streets run
## continuous through a junction; north-south streets are clipped to butt against
## them (the east-west road's sand-drift edge reads as sand blown across the mouth
## of the joining street). Ribbons conform to the terrain (sampled heights), carry
## the shared desert palette (sand edge -> asphalt -> faded center line), and get a
## thin walkable trimesh so the player stands ON the asphalt.
##
## BUILDINGS spawn ACCORDING TO the streets: cells near a street snap their building
## to the street frontage at a fixed setback, facades aligned to the street axis
## (small yaw jitter only); interior cells align to the city grid. Buildings never
## sit on a street corridor and junction corners stay open. Buildings are upright or
## lean at most ~30 deg (no toppled/flat ruins), half-buried in sand.
##
## Performance guards:
## - at most one cell instantiated per frame (no streaming hitches),
## - trimesh collision shapes cached per building mesh and SHARED by every instance,
## - desert-tinted materials cached per source material and shared likewise,
## - hard cap on live buildings, cells despawn once the player moves on.
##
## Spawned nodes are NOT in the terrain snap group — that would force the terrain
## grid to stream chunks at far positions. Heights come from a detached
## AdventureTerrainGenerator running the grid's own noise math.

const TERRAIN_GENERATOR_SCRIPT := preload("res://scripts/adventure_terrain_generator.gd")

## Single buildings ONLY (city-district one-mesh blocks were removed from the game,
## 2026-07-04 user request). Scale ranges follow AGENT_CONTEXT.md §4.5. "half" is the
## approximate world half-footprint at max scale, used for street setbacks/clearance.
const BUILDING_POOL: Array[Dictionary] = [
	{"path": "res://assets/models/ruined_building.glb", "scale_min": 22.5, "scale_max": 32.5, "can_lean": true, "weight": 4.0, "half": 13.0},
	{"path": "res://assets/third_person_adventure/environment/structures/ruined_office_building.glb", "scale_min": 65.0, "scale_max": 75.0, "can_lean": true, "weight": 1.5, "half": 31.5},
	{"path": "res://assets/third_person_adventure/environment/structures/abandoned_gatehouse.glb", "scale_min": 30.0, "scale_max": 40.0, "can_lean": true, "weight": 2.0, "half": 21.5},
	{"path": "res://assets/models/arabian_blacksmith.glb", "scale_min": 22.5, "scale_max": 30.0, "can_lean": false, "weight": 3.0, "half": 12.0},
]

## Handcrafted core (Landmarks, homestead, highway + GateStreet/EastAvenue grid) —
## never stream anything inside. 90 covers RuinedOfficeC at (58,-46), whose
## footprint reaches r~85; the handcrafted street grid itself stays within r~56.
const CORE_RADIUS := 90.0
## Streets stop only where something actually blocks them (user request: roads run
## infinitely — when one ends it resumes a little further on). 75 protects the
## handcrafted road loop (max extent r~65); the monumental rim buildings are
## handled per-segment via _street_obstacles, so a street breaks at a ruin and
## picks back up the next clear cell instead of a whole ring going roadless.
const STREET_CORE_RADIUS := 75.0
## Obstacle rects get this much extra berth (asphalt half + blend + margin).
const OBSTACLE_MARGIN := STREET_HALF + STREET_BLEND + 1.5
## Ignore props smaller than this half-extent when scanning for obstacles
## (barrels/fences may straddle a distant street line harmlessly).
const OBSTACLE_MIN_HALF := 6.0
## CityHighway waypoints — entirely inside the core today, kept as a safety net in
## case CORE_RADIUS is ever reduced or the road is extended.
const ROAD_POINTS: Array[Vector2] = [
	Vector2(14, -46), Vector2(6, -6), Vector2(-6, 12), Vector2(-16, 30), Vector2(-26, 60),
]
const ROAD_CLEARANCE := 14.0

## Big buildings (office/gatehouse at the current scales) claim a 2x2-cell block.
const BIG_BLOCK_CELLS := 2
const BIG_BLOCK_CHANCE := 0.22

## Street grid geometry. Streets sit on world lines x = k*STREET_SPACING (north-south,
## "V") and z = k*STREET_SPACING (east-west, "H").
const STREET_SPACING := 126.0
const STREET_HALF := 4.0
const STREET_BLEND := 1.2
## Building faces keep at least this + building half-footprint from a centerline.
const STREET_CLEAR := STREET_HALF + STREET_BLEND + 1.5
## North-south ribbons stop this far from an east-west centerline (butt junction).
const JUNCTION_CLIP := STREET_HALF + STREET_BLEND + 0.1
## No buildings where both street axes are closer than this (open junction corners).
const JUNCTION_PLAZA := 15.0
const H_LIFT := 0.13
const V_LIFT := 0.10
## Sand MUST match adventure_terrain_generator.gd _make_default_material() (same
## contract as terrain_road_path.gd sand_color).
const STREET_SAND := Color(0.45, 0.36, 0.28)
const STREET_ASPHALT := Color(0.22, 0.20, 0.17)
const STREET_LINE := Color(0.68, 0.60, 0.40)
const STREET_COLS: Array[float] = [-5.2, -4.0, -0.35, -0.25, 0.25, 0.35, 4.0, 5.2]
const STREET_COL_COLORS: Array[Color] = [
	STREET_SAND, STREET_ASPHALT, STREET_ASPHALT, STREET_LINE,
	STREET_LINE, STREET_ASPHALT, STREET_ASPHALT, STREET_SAND,
]

@export var target_path: NodePath = ^"../../Player"
@export var terrain_root_path: NodePath = ^"../TerrainRoot"
@export var world_seed: int = 90210
@export var cell_size: float = 42.0
@export var spawn_radius: float = 200.0
@export var despawn_radius: float = 230.0
@export var max_live_buildings: int = 200
## Fraction of leanable rolls that lean (max ~30 deg — buildings are never toppled).
@export_range(0.0, 1.0, 0.05) var lean_fraction: float = 0.3
@export var generate_collision: bool = true
@export var desert_tint_color := Color(1.0, 0.9, 0.74)
@export var debug_log := false

# Shared across every streamer instance and every spawned building.
static var _shape_cache := {}
static var _tint_cache := {}
static var _street_mat: StandardMaterial3D

# Vector2i cell -> null (rolled empty), Dictionary (queued), or Node3D (live container).
var _cells := {}
var _street_obstacles: Array[Rect2] = []
var _spawn_queue: Array[Dictionary] = []
var _scene_cache := {}
var _sampler: Node3D
var _district_noise: FastNoiseLite
var _live_count := 0
var _total_spawned := 0
var _last_cell := Vector2i(2147483647, 2147483647)
var _rescan_timer := 0.0


func _ready() -> void:
	_district_noise = FastNoiseLite.new()
	_district_noise.seed = world_seed ^ 0x5F3759DF
	_district_noise.frequency = 0.004
	_sampler = _make_height_sampler()
	# Deferred: sibling Landmarks/EnvironmentProps models must be in the tree.
	# Runs before the first _process, so no cell is evaluated obstacle-blind.
	_collect_street_obstacles.call_deferred()


func _exit_tree() -> void:
	if _sampler != null:
		_sampler.free()
		_sampler = null


func _process(delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target == null:
		return
	var pxz := Vector2(target.global_position.x, target.global_position.z)

	_rescan_timer -= delta
	var cell := _cell_of(pxz)
	if cell != _last_cell or _rescan_timer <= 0.0:
		_last_cell = cell
		_rescan_timer = 0.35
		_rescan(pxz)

	_drain_queue(pxz)


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _rescan(pxz: Vector2) -> void:
	# Despawn everything the player left behind (hysteresis vs spawn_radius).
	for cell: Vector2i in _cells.keys():
		if _cell_center(cell).distance_to(pxz) > despawn_radius:
			var val: Variant = _cells[cell]
			if val is Node3D and is_instance_valid(val):
				_live_count -= int((val as Node3D).get_meta("building_count", 0))
				(val as Node3D).queue_free()
			_cells.erase(cell)

	# Roll every not-yet-evaluated cell inside spawn_radius.
	var span := ceili(spawn_radius / cell_size) + 1
	var center_cell := _cell_of(pxz)
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var cell := center_cell + Vector2i(dx, dz)
			if _cells.has(cell):
				continue
			if _cell_center(cell).distance_to(pxz) > spawn_radius:
				continue
			var rolled := _eval_cell(cell)
			if rolled.is_empty():
				_cells[cell] = null
			else:
				_cells[cell] = rolled
				_spawn_queue.append(rolled)


## All randomness happens here, from the cell's own seed — spawning later (or never,
## if the player turns away) cannot change what the cell contains.
func _eval_cell(cell: Vector2i) -> Dictionary:
	var center := _cell_center(cell)
	if center.length() < CORE_RADIUS:
		return {}

	var streets := _streets_for_cell(cell)
	var buildings := _roll_buildings(cell, center)
	if streets.is_empty() and buildings.is_empty():
		return {}
	return {"cell": cell, "streets": streets, "buildings": buildings}


## Street ribbon segments crossing this cell. East-west ("h") segments run continuous;
## north-south ("v") segments are clipped around east-west centerlines so junctions
## are clean butt joints, never two ribbons crossing through each other.
func _streets_for_cell(cell: Vector2i) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var x0 := float(cell.x) * cell_size
	var x1 := x0 + cell_size
	var z0 := float(cell.y) * cell_size
	var z1 := z0 + cell_size

	var hline := roundf((z0 + z1) * 0.5 / STREET_SPACING) * STREET_SPACING
	if hline >= z0 and hline < z1:
		_append_street(segments, "h", hline, x0, x1, H_LIFT)

	var vline := roundf((x0 + x1) * 0.5 / STREET_SPACING) * STREET_SPACING
	if vline >= x0 and vline < x1:
		# Clip around the nearest east-west line, even one in a neighboring cell.
		var near_h := roundf((z0 + z1) * 0.5 / STREET_SPACING) * STREET_SPACING
		var gap_a := near_h - JUNCTION_CLIP
		var gap_b := near_h + JUNCTION_CLIP
		if gap_b <= z0 or gap_a >= z1:
			_append_street(segments, "v", vline, z0, z1, V_LIFT)
		else:
			_append_street(segments, "v", vline, z0, minf(gap_a, z1), V_LIFT)
			_append_street(segments, "v", vline, maxf(gap_b, z0), z1, V_LIFT)
	return segments


func _append_street(segments: Array[Dictionary], axis: String, line: float, from: float, to: float, lift: float) -> void:
	if to - from < 2.0:
		return
	# Roads run forever, but they BREAK where something stands in the way — the
	# handcrafted road loop or any discovered building footprint. A blocked cell
	# segment is skipped entirely, so the street ends and resumes a cell or two
	# later (user request: "if the road ends it starts after a while again").
	if _segment_blocked(axis, line, from, to):
		return
	segments.append({"axis": axis, "line": line, "from": from, "to": to, "lift": lift})


func _segment_blocked(axis: String, line: float, from: float, to: float) -> bool:
	var steps := maxi(2, ceili((to - from) / 7.0))
	for i in range(steps + 1):
		var t := from + (to - from) * float(i) / float(steps)
		var p := Vector2(t, line) if axis == "h" else Vector2(line, t)
		if p.length() < STREET_CORE_RADIUS:
			return true
		for rect: Rect2 in _street_obstacles:
			if rect.has_point(p):
				return true
	return false


## Discovers the handcrafted buildings' XZ footprints at runtime (merged mesh
## AABBs of Landmarks + EnvironmentProps children), so streets always break
## around them no matter how often placement batches move things. Small props
## (barrels, fences, wrecks) fall under OBSTACLE_MIN_HALF and are ignored.
func _collect_street_obstacles() -> void:
	_street_obstacles.clear()
	for group_path in ["../Landmarks", "../EnvironmentProps"]:
		var group := get_node_or_null(group_path)
		if group == null:
			continue
		for child in group.get_children():
			if not (child is Node3D):
				continue
			var rect := _merged_xz_rect(child as Node3D)
			if rect.size == Vector2.ZERO:
				continue
			if maxf(rect.size.x, rect.size.y) * 0.5 < OBSTACLE_MIN_HALF:
				continue
			_street_obstacles.append(rect.grow(OBSTACLE_MARGIN))
	if debug_log:
		print("CityStreamer: %d street obstacles discovered" % _street_obstacles.size())


func _merged_xz_rect(root: Node3D) -> Rect2:
	var found := false
	var combined := AABB()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh_instance := node as MeshInstance3D
			var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			combined = world_aabb if not found else combined.merge(world_aabb)
			found = true
		for child in node.get_children():
			stack.append(child)
	if not found:
		return Rect2()
	return Rect2(combined.position.x, combined.position.z, combined.size.x, combined.size.z)


## One building per cell packs the city TIGHT at the current (upsized) model scales:
## small buildings are ~18-26 m wide on a 42 m cell pitch -> 10-20 m gaps between
## neighbors. Big buildings (office/gatehouse, 40-63 m wide) deterministically claim
## a whole 2x2-cell block so they can never overlap their neighbors. All randomness
## stays on seeded rng streams — no cross-cell communication needed.
func _roll_buildings(cell: Vector2i, center: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var anchor := Vector2i(cell.x - posmod(cell.x, BIG_BLOCK_CELLS), cell.y - posmod(cell.y, BIG_BLOCK_CELLS))
	var big_item := _block_big_item(anchor)
	if not big_item.is_empty():
		if cell == anchor:
			out.append(big_item)
		return out  # companion cells are the big building's lot — keep them clear

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ (cell.x * 73856093) ^ (cell.y * 19349663)
	if rng.randf() > _density_at(center):
		return out

	var entry := _pick_small(rng)
	var half := float(entry["half"])
	var pos := center + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))

	# Spawn ACCORDING TO the streets: frontage cells snap to the street at a fixed
	# setback with the facade aligned to it; interior cells align to the grid axes.
	var vline := roundf(center.x / STREET_SPACING) * STREET_SPACING
	var hline := roundf(center.y / STREET_SPACING) * STREET_SPACING
	var cell_dv := absf(center.x - vline)
	var cell_dh := absf(center.y - hline)
	var yaw: float
	if cell_dv < 27.0 and cell_dv <= cell_dh:
		var side := 1.0 if center.x >= vline else -1.0
		pos.x = vline + side * (STREET_CLEAR + half + rng.randf_range(1.0, 4.0))
		yaw = (PI * 0.5 if side > 0.0 else -PI * 0.5) + rng.randf_range(-0.09, 0.09)
	elif cell_dh < 27.0:
		var side := 1.0 if center.y >= hline else -1.0
		pos.y = hline + side * (STREET_CLEAR + half + rng.randf_range(1.0, 4.0))
		yaw = (0.0 if side > 0.0 else PI) + rng.randf_range(-0.09, 0.09)
	else:
		yaw = float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.09, 0.09)
	_finalize_building(out, rng, pos, entry, yaw)
	return out


## Deterministic big-building roll for a 2x2-cell block. EVERY cell of the block
## recomputes the same answer from the anchor's own rng stream (including the
## validity checks inside _finalize_building), so a big building claims its whole
## block — or the whole block falls back to small buildings — consistently.
func _block_big_item(anchor: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = (world_seed ^ 0x0B16B00B) ^ (anchor.x * 2654435761) ^ (anchor.y * 40503)
	if rng.randf() > BIG_BLOCK_CHANCE:
		return {}
	var block_center := Vector2(anchor) * cell_size + Vector2.ONE * (cell_size * float(BIG_BLOCK_CELLS) * 0.5)
	if block_center.length() < CORE_RADIUS:
		return {}
	var entry := _pick_big(rng)
	var pos := block_center + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
	var yaw := float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.09, 0.09)
	var probe: Array[Dictionary] = []
	_finalize_building(probe, rng, pos, entry, yaw)
	return probe[0] if not probe.is_empty() else {}


## Shared constraint gate — junction plazas stay open, street corridors and the
## handcrafted core stay clear. Appends the building item if the spot is legal.
func _finalize_building(out: Array[Dictionary], rng: RandomNumberGenerator, pos: Vector2, entry: Dictionary, yaw: float) -> void:
	var half := float(entry["half"])
	var leans: bool = bool(entry["can_lean"]) and rng.randf() < lean_fraction
	var lean_dir := rng.randf_range(0.0, TAU)
	var tilt_deg := rng.randf_range(5.0, 28.0)
	var bury := rng.randf_range(0.35, 0.9) if leans else rng.randf_range(0.2, 0.6)
	var scale := rng.randf_range(float(entry["scale_min"]), float(entry["scale_max"]))

	if pos.length() < CORE_RADIUS + 6.0:
		return
	if _near_road(pos):
		return
	var dv := absf(pos.x - roundf(pos.x / STREET_SPACING) * STREET_SPACING)
	var dh := absf(pos.y - roundf(pos.y / STREET_SPACING) * STREET_SPACING)
	if dv < JUNCTION_PLAZA and dh < JUNCTION_PLAZA:
		return
	if dv < STREET_CLEAR + half or dh < STREET_CLEAR + half:
		return

	out.append({
		"pos": pos,
		"entry": entry,
		"scale": scale,
		"yaw": yaw,
		"leans": leans,
		"lean_dir": lean_dir,
		# Max ~30 deg — ruins lean, they never lie flat (user request 2026-07-04).
		"tilt_deg": tilt_deg,
		"bury": bury,
	})


## Urban belt near the core, endless (still city-dense) outskirts beyond; district
## noise varies the fill so blocks alternate with sandier stretches.
func _density_at(center: Vector2) -> float:
	var r := center.length()
	var base := 1.0
	if r >= 450.0:
		base = 0.7
	elif r >= 280.0:
		base = 0.85
	var n := _district_noise.get_noise_2d(center.x, center.y) * 0.5 + 0.5
	return base * lerpf(0.65, 1.0, smoothstep(0.3, 0.7, n))


## Small buildings pack the sub-lots and street rows; big ones anchor whole lots.
func _pick_small(rng: RandomNumberGenerator) -> Dictionary:
	return _pick_weighted(rng, [BUILDING_POOL[0], BUILDING_POOL[3]])


func _pick_big(rng: RandomNumberGenerator) -> Dictionary:
	return _pick_weighted(rng, [BUILDING_POOL[1], BUILDING_POOL[2]])


func _pick_weighted(rng: RandomNumberGenerator, pool: Array) -> Dictionary:
	var total := 0.0
	for entry: Dictionary in pool:
		total += float(entry["weight"])
	var roll := rng.randf_range(0.0, total)
	for entry: Dictionary in pool:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry
	return pool[0]


func _near_road(pos: Vector2) -> bool:
	for i in range(ROAD_POINTS.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(pos, ROAD_POINTS[i], ROAD_POINTS[i + 1])
		if pos.distance_to(closest) < ROAD_CLEARANCE:
			return true
	return false


func _drain_queue(pxz: Vector2) -> void:
	# One cell instantiated per frame keeps streaming invisible to the frame budget.
	while not _spawn_queue.is_empty():
		var item: Dictionary = _spawn_queue.pop_front()
		var cell: Vector2i = item["cell"]
		# Skip stale entries: cell despawned or re-rolled while queued.
		if not _cells.has(cell) or not (_cells[cell] is Dictionary):
			continue
		if _cell_center(cell).distance_to(pxz) > despawn_radius:
			_cells.erase(cell)
			continue
		_spawn_cell(item)
		return


func _spawn_cell(item: Dictionary) -> void:
	var cell: Vector2i = item["cell"]
	var container := Node3D.new()
	container.name = "Cell_%d_%d" % [cell.x, cell.y]
	add_child(container)

	for seg: Dictionary in item["streets"]:
		container.add_child(_build_street_mesh(seg))

	var spawned := 0
	for i in range(item["buildings"].size()):
		if _live_count >= max_live_buildings:
			if debug_log:
				print("CityStreamer: live cap reached, skipped building in %s" % container.name)
			break
		if _spawn_building(container, cell, i, item["buildings"][i]):
			spawned += 1

	container.set_meta("building_count", spawned)
	_cells[cell] = container
	if _spawn_queue.is_empty():
		print("CityStreamer: batch done — %d buildings spawned total, %d live" % [_total_spawned, _live_count])


func _spawn_building(container: Node3D, cell: Vector2i, index: int, item: Dictionary) -> bool:
	var entry: Dictionary = item["entry"]
	var path := String(entry["path"])
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var packed := _scene_cache[path] as PackedScene
	if packed == null:
		push_warning("CityBuildingStreamer could not load %s" % path)
		return false

	var pos: Vector2 = item["pos"]
	var root := Node3D.new()
	root.name = "CityBldg_%d_%d_%d" % [cell.x, cell.y, index]

	var basis := Basis(Vector3.UP, float(item["yaw"]))
	if bool(item["leans"]):
		var lean_dir := float(item["lean_dir"])
		var tilt_axis := Vector3(cos(lean_dir), 0.0, sin(lean_dir))
		basis = Basis(tilt_axis, deg_to_rad(float(item["tilt_deg"]))) * basis
	root.basis = basis
	root.scale = Vector3.ONE * float(item["scale"])

	var ground_y := 0.0
	if _sampler != null:
		ground_y = float(_sampler.call("get_height_at", pos.x, pos.y))
	root.position = Vector3(pos.x, ground_y, pos.y)

	var model := packed.instantiate()
	root.add_child(model)
	container.add_child(root)

	# Ground by bounding box against the LOWEST terrain point under the footprint
	# (center + all four AABB corners) plus a footprint-proportional burial — a
	# corner over a dune dip must still sit in the sand, never hover. At the
	# current large scales, center-only sampling left corners floating on slopes.
	var bounds := _combined_global_aabb(root)
	if bounds.size != Vector3.ZERO:
		var min_h := ground_y
		if _sampler != null:
			for corner in [
				Vector2(bounds.position.x, bounds.position.z),
				Vector2(bounds.position.x, bounds.end.z),
				Vector2(bounds.end.x, bounds.position.z),
				Vector2(bounds.end.x, bounds.end.z),
			]:
				min_h = minf(min_h, float(_sampler.call("get_height_at", corner.x, corner.y)))
		var bury := float(item["bury"]) + maxf(bounds.size.x, bounds.size.z) * 0.02
		root.position.y += (min_h - bury) - bounds.position.y

	_apply_desert_tint(root)
	if generate_collision:
		_build_colliders(root)

	_live_count += 1
	_total_spawned += 1
	if debug_log:
		print("CityStreamer: %s at (%.0f, %.0f) scale=%.1f%s | spawned=%d live=%d" % [
			root.name, pos.x, pos.y, float(item["scale"]),
			" leaning" if bool(item["leans"]) else "", _total_spawned, _live_count])
	return true


## One conforming ribbon strip: sand edge -> asphalt -> faded center line -> asphalt
## -> sand edge, vertex-colored (shared white-albedo material with
## vertex_color_is_srgb — without it the colors wash out pale, see terrain_road_path).
## Outer sand columns drop to terrain level so edges melt into the dunes. A thin
## trimesh collider makes the asphalt itself walkable.
func _build_street_mesh(seg: Dictionary) -> MeshInstance3D:
	var axis_h := String(seg["axis"]) == "h"
	var line := float(seg["line"])
	var from := float(seg["from"])
	var to := float(seg["to"])
	var lift := float(seg["lift"])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(2, ceili((to - from) / 3.5) + 1)
	var cols := STREET_COLS.size()
	for i in range(rows):
		var t := lerpf(from, to, float(i) / float(rows - 1))
		for c in range(cols):
			var o := STREET_COLS[c]
			var edge := c == 0 or c == cols - 1
			var x := t if axis_h else line + o
			var z := line + o if axis_h else t
			var y := 0.0
			if _sampler != null:
				y = float(_sampler.call("get_height_at", x, z))
			y += -0.02 if edge else lift
			st.set_color(STREET_COL_COLORS[c])
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(x, y, z))
	for i in range(rows - 1):
		for c in range(cols - 1):
			var a := i * cols + c
			var b := a + 1
			var d := a + cols
			var e := d + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(e)
			st.add_index(a)
			st.add_index(e)
			st.add_index(d)
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "Street%s_%d" % [seg["axis"].to_upper(), int(line)]
	mi.mesh = mesh
	mi.material_override = _street_material()

	var body := StaticBody3D.new()
	body.name = "StreetCollider"
	body.collision_layer = AdventureLayers.WORLD
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	mi.add_child(body)
	return mi


static func _street_material() -> StandardMaterial3D:
	if _street_mat == null:
		_street_mat = StandardMaterial3D.new()
		_street_mat.albedo_color = Color.WHITE
		_street_mat.vertex_color_use_as_albedo = true
		_street_mat.vertex_color_is_srgb = true
		_street_mat.roughness = 1.0
		_street_mat.metallic = 0.0
		_street_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _street_mat


## Same warm grade as adventure_environment_prop_setup.gd desert_tint, but the tinted
## materials are cached per SOURCE material in a static dict — every streamed copy of
## a model shares one tinted material set instead of duplicating per building.
func _apply_desert_tint(root: Node3D) -> void:
	for mesh_instance in _collect_mesh_instances(root):
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface)
			if source == null:
				continue
			var key := source.get_instance_id()
			if not _tint_cache.has(key):
				var tinted: Material = source.duplicate()
				if tinted is BaseMaterial3D:
					var base := tinted as BaseMaterial3D
					base.albedo_color = base.albedo_color * desert_tint_color
					base.roughness = maxf(base.roughness, 0.85)
					base.metallic = minf(base.metallic, 0.15)
				_tint_cache[key] = tinted
			mesh_instance.set_surface_override_material(surface, _tint_cache[key])


## Trimesh collision for the sun/shade raycast + walkable ruins. Shapes are built
## once per unique mesh and shared by every instance (static cache).
func _build_colliders(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "MeshColliders"
	body.collision_layer = AdventureLayers.WORLD
	body.collision_mask = 0
	root.add_child(body)
	for mesh_instance in _collect_mesh_instances(root):
		var mesh := mesh_instance.mesh
		if not _shape_cache.has(mesh):
			_shape_cache[mesh] = mesh.create_trimesh_shape()
		var shape: Shape3D = _shape_cache[mesh]
		if shape == null:
			continue
		var collision := CollisionShape3D.new()
		collision.name = "Collision_%s" % mesh_instance.name
		collision.shape = shape
		body.add_child(collision)
		collision.global_transform = mesh_instance.global_transform


func _collect_mesh_instances(root_node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == "MeshColliders" or node.name == "StreetCollider":
			continue
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			meshes.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return meshes


func _combined_global_aabb(root: Node3D) -> AABB:
	var combined := AABB()
	var found := false
	for mesh_instance in _collect_mesh_instances(root):
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		combined = world_aabb if not found else combined.merge(world_aabb)
		found = true
	return combined if found else AABB()


## Detached AdventureTerrainGenerator configured exactly like the grid's chunks
## (sample_origin zero => global coords), purely for height queries — never forces
## the grid to stream chunks at far positions.
func _make_height_sampler() -> Node3D:
	var grid := get_node_or_null(terrain_root_path)
	var sampler := TERRAIN_GENERATOR_SCRIPT.new() as Node3D
	sampler.set("generate_on_ready", false)
	sampler.set("sample_origin", Vector2.ZERO)
	sampler.set("use_bounded_edge_lift", false)
	sampler.set("use_spawn_clearings", true)
	if grid != null:
		sampler.set("height_scale", grid.get("height_scale"))
		sampler.set("noise_seed", grid.get("noise_seed"))
		sampler.set("noise_frequency", grid.get("noise_frequency"))
		sampler.set("ridge_strength", grid.get("ridge_strength"))
		sampler.set("valley_width", grid.get("valley_width"))
		if grid.has_method("_collect_feature_data"):
			sampler.set("terrain_features", grid.call("_collect_feature_data"))
	sampler.call("_configure_noise")
	return sampler
