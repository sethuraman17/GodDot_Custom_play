extends Node
class_name ForceFieldAbility

## Player ability: press the force_field action (R) to deploy a ForceField
## globe a short distance ahead, snapped to the ground. One globe at a time;
## presses while one exists are ignored. The globe manages its own
## build/active/dissolve lifecycle.

@export var input_reader_path: NodePath = ^"../../InputReader"
@export var spawn_distance: float = 2.5
@export var ground_probe_height: float = 3.0

@onready var _input_reader: AdventureInputReader = get_node_or_null(input_reader_path) as AdventureInputReader

var _field: ForceField


func _physics_process(_delta: float) -> void:
	if _input_reader == null or not _input_reader.is_force_field_just_pressed():
		return
	if _field != null and is_instance_valid(_field) and not _field.is_gone():
		return
	_deploy()


func current_field() -> ForceField:
	if _field != null and is_instance_valid(_field):
		return _field
	return null


func clear() -> void:
	if _field != null and is_instance_valid(_field):
		_field.dissolve()
	_field = null


func _deploy() -> void:
	var player := get_parent() as Node3D
	if player == null:
		return

	var forward := -player.global_transform.basis.z
	var skin_pivot := player.get_node_or_null("SkinPivot") as Node3D
	if skin_pivot != null:
		# The visual model carries the facing (the body turns, not the player).
		forward = -skin_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD

	var spot := player.global_position + forward * spawn_distance
	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		spot + Vector3.UP * ground_probe_height, spot + Vector3.DOWN * 50.0
	)
	query.collision_mask = AdventureLayers.WORLD
	query.exclude = [player.get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.has("position"):
		spot.y = (hit["position"] as Vector3).y

	_field = ForceField.new()
	_field.name = "ForceFieldGlobe"
	get_tree().current_scene.add_child(_field)
	_field.global_position = spot
