extends Node3D
class_name DistantRuinsScatter

## Scatters ruined/fallen buildings in the far outskirts of the map, outside the
## central city cluster. Placement is deterministic (seeded), computed at runtime
## against the same noise math the terrain grid uses, so ruins sit on the sand
## exactly where chunks will stream in. Ruins are NOT in the terrain snap group:
## snapping far nodes would force the grid to generate chunks at their positions.

const PROP_SETUP_SCRIPT := preload("res://scripts/adventure_environment_prop_setup.gd")
const TERRAIN_GENERATOR_SCRIPT := preload("res://scripts/adventure_terrain_generator.gd")

## Model pool — single buildings ONLY. City-district one-mesh blocks were removed
## from the game world (2026-07-04, user request: buildings only); do not re-add
## them here. Scale ranges follow AGENT_CONTEXT.md §4.5 (binding scale standard):
## ruin ~x10, gatehouse ~x11-15, office ~x30, adobe blacksmith ~x9-12.
const RUIN_POOL: Array[Dictionary] = [
	{"path": "res://assets/models/ruined_building.glb", "scale_min": 9.0, "scale_max": 13.0, "can_fall": true},
	{"path": "res://assets/third_person_adventure/environment/structures/ruined_office_building.glb", "scale_min": 26.0, "scale_max": 34.0, "can_fall": true},
	{"path": "res://assets/third_person_adventure/environment/structures/abandoned_gatehouse.glb", "scale_min": 12.0, "scale_max": 16.0, "can_fall": true},
	{"path": "res://assets/models/arabian_blacksmith.glb", "scale_min": 9.0, "scale_max": 12.0, "can_fall": false},
]

@export var terrain_root_path: NodePath = ^"../TerrainRoot"
@export var placement_seed: int = 90210
@export_range(0, 40, 1) var ruin_count: int = 14
@export var min_radius: float = 85.0
@export var max_radius: float = 230.0
# Singles-only pool: widest structure (office x34) is ~29 m — 40 m keeps clear gaps.
@export var min_spacing: float = 40.0
@export_range(0.0, 1.0, 0.05) var fallen_fraction: float = 0.4
@export var generate_collision: bool = true


func _ready() -> void:
	_scatter.call_deferred()


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed

	var sampler := _make_height_sampler()
	var placements := _pick_placements(rng)

	var scene_cache := {}
	var index := 0
	for placement in placements:
		index += 1
		var entry := placement["entry"] as Dictionary
		var path := String(entry["path"])
		if not scene_cache.has(path):
			scene_cache[path] = load(path)
		var packed := scene_cache[path] as PackedScene
		if packed == null:
			push_warning("DistantRuinsScatter could not load %s" % path)
			continue
		_spawn_ruin(index, placement, packed, sampler, rng)
		# One ruin per frame: spreads mesh instancing + deferred trimesh collider
		# builds so startup does not hitch on a single frame.
		await get_tree().process_frame

	if sampler != null:
		sampler.free()


func _pick_placements(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var fallen_wanted := int(round(float(ruin_count) * fallen_fraction))
	var attempts := 0
	while placements.size() < ruin_count and attempts < ruin_count * 40:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		# sqrt-lerp of squared radii = uniform density over the ring area.
		var radius: float = sqrt(lerpf(min_radius * min_radius, max_radius * max_radius, rng.randf()))
		var pos := Vector2(cos(angle), sin(angle)) * radius

		var too_close := false
		for existing in placements:
			if pos.distance_to(existing["pos"] as Vector2) < min_spacing:
				too_close = true
				break
		if too_close:
			continue

		var wants_fallen := fallen_wanted > 0
		var entry := _pick_entry(rng, wants_fallen)
		var is_fallen: bool = wants_fallen and bool(entry["can_fall"])
		if is_fallen:
			fallen_wanted -= 1
		placements.append({"pos": pos, "entry": entry, "fallen": is_fallen})
	return placements


func _pick_entry(rng: RandomNumberGenerator, prefer_fallable: bool) -> Dictionary:
	if prefer_fallable:
		var fallable := RUIN_POOL.filter(func(e: Dictionary) -> bool: return bool(e["can_fall"]))
		return fallable[rng.randi_range(0, fallable.size() - 1)]
	return RUIN_POOL[rng.randi_range(0, RUIN_POOL.size() - 1)]


func _spawn_ruin(index: int, placement: Dictionary, packed: PackedScene, sampler: Node3D, rng: RandomNumberGenerator) -> void:
	var entry := placement["entry"] as Dictionary
	var pos := placement["pos"] as Vector2
	var is_fallen := bool(placement["fallen"])
	var uniform_scale := rng.randf_range(float(entry["scale_min"]), float(entry["scale_max"]))

	var root := Node3D.new()
	root.name = "FarRuin%02d%s" % [index, "_Fallen" if is_fallen else ""]
	root.set_script(PROP_SETUP_SCRIPT)
	root.set("material_profile", "none")
	root.set("apply_procedural_materials", false)
	root.set("desert_tint", true)
	root.set("generate_mesh_collision", generate_collision)

	var yaw := rng.randf_range(0.0, TAU)
	var basis := Basis(Vector3.UP, yaw)
	if is_fallen:
		# Topple around a horizontal axis roughly perpendicular to a random
		# fall direction, most of the way to flat, with a little variance.
		var fall_dir := rng.randf_range(0.0, TAU)
		var tilt_axis := Vector3(cos(fall_dir), 0.0, sin(fall_dir))
		var tilt := deg_to_rad(rng.randf_range(62.0, 84.0))
		basis = Basis(tilt_axis, tilt) * basis
	root.basis = basis
	root.scale = Vector3.ONE * uniform_scale

	var ground_y := 0.0
	if sampler != null:
		ground_y = float(sampler.call("get_height_at", pos.x, pos.y))
	root.position = Vector3(pos.x, ground_y, pos.y)

	var model := packed.instantiate()
	root.add_child(model)
	add_child(root)

	# Ground by bounding box: sink the mesh bottom below the sand line so ruins
	# read as half-buried wreckage, not props resting on the surface.
	var bury := rng.randf_range(0.5, 1.2) if is_fallen else rng.randf_range(0.2, 0.7)
	var bounds := _combined_global_aabb(root)
	if bounds.size != Vector3.ZERO:
		root.position.y += (ground_y - bury) - bounds.position.y
	print("DistantRuins: %s at (%.0f, %.0f) r=%.0f scale=%.0f %s" % [
		root.name, pos.x, pos.y, pos.length(), uniform_scale,
		String(entry["path"]).get_file()])


func _combined_global_aabb(root: Node3D) -> AABB:
	var combined := AABB()
	var found := false
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
	return combined if found else AABB()


## Builds a detached AdventureTerrainGenerator configured exactly like the grid's
## chunks (sample_origin zero => global coords) purely for height queries, so we
## never force the grid to stream chunks at far positions.
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
