extends Node3D
class_name WaterDropSpawner

@export var terrain_path: NodePath = ^"../TerrainRoot"
@export var player_path: NodePath = ^"../../Player"
@export var water_supply_path: NodePath = ^"../../Player/WaterSupply"
@export var run_score_path: NodePath = ^"../../Player/RunScore"
@export var hud_path: NodePath = ^"../../HUD"
@export var cell_size: float = 12.0
@export var spawn_radius: float = 48.0
@export var drop_water_amount: float = 27.0
@export var placement_seed: int = 1337

@onready var _terrain: Node = get_node_or_null(terrain_path)
@onready var _player: Node3D = get_node_or_null(player_path) as Node3D
@onready var _water_supply: WaterSupply = get_node_or_null(water_supply_path) as WaterSupply
@onready var _run_score: RunScore = get_node_or_null(run_score_path) as RunScore
@onready var _hud: AdventureHUD = get_node_or_null(hud_path) as AdventureHUD

var _drops: Dictionary = {}
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
			var pos := _drop_position_for_cell(cell)
			if Vector2(pos.x - center.x, pos.z - center.z).length() <= spawn_radius:
				wanted[cell] = pos

	# Free drops that drifted out of range; forgetting a collected cell here is
	# what lets water regrow once the player has wandered away and come back.
	for cell in _drops.keys():
		if not wanted.has(cell):
			# Collected drops freed themselves but stay in the dict; a typed
			# Node assignment of a freed instance is a runtime error, so keep
			# the value as Variant until validity is checked.
			var drop: Variant = _drops[cell]
			if is_instance_valid(drop):
				drop.queue_free()
			_drops.erase(cell)

	for cell in wanted:
		if not _drops.has(cell):
			_drops[cell] = _spawn_drop(wanted[cell])


func _drop_position_for_cell(cell: Vector2i) -> Vector3:
	# Deterministic jitter inside the cell: even, gap-free coverage that stays
	# put instead of reshuffling every refresh.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, placement_seed))
	var x := (float(cell.x) + rng.randf_range(0.15, 0.85)) * cell_size
	var z := (float(cell.y) + rng.randf_range(0.15, 0.85)) * cell_size
	return Vector3(x, _ground_height(x, z), z)


func _spawn_drop(pos: Vector3) -> WaterDrop:
	var drop := WaterDrop.new()
	drop.water_amount = drop_water_amount
	drop.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.65, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.65, 0.95)
	mat.emission_energy_multiplier = 0.6

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	drop.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	drop.add_child(collision)

	drop.collected.connect(_on_drop_collected)
	add_child(drop)
	return drop


func _on_drop_collected(amount: float) -> void:
	AmbientAudio.play_water_pickup()
	if _water_supply != null:
		_water_supply.add_water(amount)
	if _run_score != null:
		_run_score.add_pickup_bonus()
	if _hud != null:
		_hud.push_event("+%d water" % roundi(amount), Color(0.6, 0.92, 1.0))


func _ground_height(x: float, z: float) -> float:
	if _terrain != null and _terrain.has_method("get_height_at"):
		return _terrain.get_height_at(x, z)
	return global_position.y
