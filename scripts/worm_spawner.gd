extends Node3D
class_name WormSpawner

## Keeps AdventureWorms populated around the player the same way
## WaterDropSpawner keeps drops around: one worm per grid cell, spawned when
## its cell comes within range and freed when the player wanders away. Worms
## are pure ambiance, so a despawned worm simply restarts its burrow cycle at
## the same deterministic spot next time the player comes back.

@export var terrain_path: NodePath = ^"../TerrainRoot"
@export var player_path: NodePath = ^"../../Player"
@export var cell_size: float = 20.0
@export var spawn_radius: float = 55.0
@export var placement_seed: int = 7331

@onready var _terrain: Node = get_node_or_null(terrain_path)
@onready var _player: Node3D = get_node_or_null(player_path) as Node3D

var _worms: Dictionary = {}
var _refresh_accum := 0.0

const REFRESH_INTERVAL := 0.5


func _ready() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_refresh_cells()


func _physics_process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		_refresh_cells()


func _refresh_cells() -> void:
	var center := _player.global_position if _player != null else global_position
	var center_cell := Vector2i(floori(center.x / cell_size), floori(center.z / cell_size))
	var cell_span := ceili(spawn_radius / cell_size)

	var wanted: Dictionary = {}
	for cy in range(center_cell.y - cell_span, center_cell.y + cell_span + 1):
		for cx in range(center_cell.x - cell_span, center_cell.x + cell_span + 1):
			var cell := Vector2i(cx, cy)
			var pos := _worm_position_for_cell(cell)
			if Vector2(pos.x - center.x, pos.z - center.z).length() <= spawn_radius:
				wanted[cell] = pos

	for cell in _worms.keys():
		if not wanted.has(cell):
			var worm: Node = _worms[cell]
			if is_instance_valid(worm):
				worm.queue_free()
			_worms.erase(cell)

	for cell in wanted:
		if not _worms.has(cell):
			_worms[cell] = _spawn_worm(wanted[cell])


func _worm_position_for_cell(cell: Vector2i) -> Vector3:
	# Deterministic jitter inside the cell, same trick as the water drops:
	# stable home burrows that don't reshuffle every refresh.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, placement_seed))
	var x := (float(cell.x) + rng.randf_range(0.2, 0.8)) * cell_size
	var z := (float(cell.y) + rng.randf_range(0.2, 0.8)) * cell_size
	return Vector3(x, _ground_height(x, z), z)


func _spawn_worm(pos: Vector3) -> Node3D:
	var worm := Node3D.new()
	worm.position = pos
	# AdventureWorm's exported terrain/player paths are relative to the worm
	# itself and resolve correctly with this spawner sitting at Level/Worms.
	worm.set_script(load("res://scripts/adventure_worm.gd"))
	add_child(worm)
	return worm


func _ground_height(x: float, z: float) -> float:
	if _terrain != null and _terrain.has_method("get_height_at"):
		return _terrain.get_height_at(x, z)
	return global_position.y
