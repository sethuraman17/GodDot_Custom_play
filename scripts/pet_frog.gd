extends CharacterBody3D
class_name PetFrog

## Pet companion that follows the player with ballistic hops.
## Rests when close, hops toward the player when they wander off,
## and teleports to catch up if left far behind.

@export var frog_size: float = 0.55
@export var follow_distance: float = 2.6
@export var max_hop_distance: float = 5.0
@export var hop_speed: float = 6.5
@export var hop_height_velocity: float = 6.0
@export var gravity: float = 20.0
@export var hop_pause_min: float = 0.12
@export var hop_pause_max: float = 0.4
@export var idle_hop_interval_min: float = 2.5
@export var idle_hop_interval_max: float = 6.0
@export var teleport_distance: float = 28.0
@export var turn_speed: float = 14.0
## Extra hop speed when far behind (0.35 = up to +35%).
@export var catch_up_boost: float = 0.35
@export var skin_pivot_path: NodePath = ^"SkinPivot"

@onready var skin_pivot: Node3D = get_node_or_null(skin_pivot_path) as Node3D

var _player: Node3D
var _hop_timer: float = 0.6
var _was_on_floor: bool = true
var _facing: Vector3 = Vector3.FORWARD
var _base_scale: float = 1.0
var _squash: float = 1.0
var _placed_near_player: bool = false


func _ready() -> void:
	collision_layer = AdventureLayers.NPC
	collision_mask = AdventureLayers.NPC_MASK
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	_fit_model_to_size()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return

	if not _placed_near_player:
		_placed_near_player = true
		_teleport_near_player()
		return

	var to_player := _player.global_position - global_position
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	var distance := flat_to_player.length()

	if distance > teleport_distance:
		_teleport_near_player()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Frogs stop dead when they land; all travel happens mid-hop.
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		if distance > 0.3:
			_facing = flat_to_player / distance
		if distance > follow_distance:
			# Player wandered off mid-rest — cut the lazy idle wait short,
			# more so the further behind the frog is.
			_hop_timer = minf(_hop_timer, lerpf(hop_pause_max, hop_pause_min, _urgency(distance)))
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			if distance > follow_distance:
				# Only launch once the frog is actually looking where it wants
				# to go — it hops along its own gaze, never sideways.
				var gaze := _skin_forward()
				if gaze.dot(_facing) > cos(deg_to_rad(35.0)):
					_hop_towards(gaze, distance)
			else:
				_idle_hop()

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_squash = 0.55
	_was_on_floor = is_on_floor()

	_update_skin(delta)


func _hop_towards(direction: Vector3, distance: float) -> void:
	var hop_length := clampf(distance - follow_distance * 0.5, 1.0, max_hop_distance)
	var strength := hop_length / max_hop_distance
	var urgency := _urgency(distance)
	velocity = direction * lerpf(hop_speed * 0.5, hop_speed, strength) * (1.0 + catch_up_boost * urgency)
	velocity.y = lerpf(hop_height_velocity * 0.75, hop_height_velocity, strength)
	# Chain hops with barely a breath when far behind; relax as it catches up.
	_hop_timer = lerpf(randf_range(hop_pause_min, hop_pause_max), hop_pause_min * 0.5, urgency)
	_squash = 1.45


## 0 when at follow_distance, ramping to 1 when badly left behind.
func _urgency(distance: float) -> float:
	return clampf((distance - follow_distance) / (max_hop_distance * 2.0), 0.0, 1.0)


func _skin_forward() -> Vector3:
	if skin_pivot == null:
		return _facing
	var forward := -skin_pivot.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else _facing


func _idle_hop() -> void:
	_hop_timer = randf_range(idle_hop_interval_min, idle_hop_interval_max)
	# Small hop in place, turning to face the player.
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.04:
			_facing = to_player.normalized()
	velocity.y = hop_height_velocity * 0.45
	_squash = 1.25


func _teleport_near_player() -> void:
	if _player == null:
		return
	var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	global_position = _player.global_position + side.normalized() * 1.5 + Vector3.UP * 0.5
	velocity = Vector3.ZERO


func _update_skin(delta: float) -> void:
	if skin_pivot == null:
		return

	# Stretch while airborne, squash on landing, ease back to rest.
	var target := 1.0
	if not is_on_floor():
		target = clampf(1.0 + absf(velocity.y) * 0.035, 1.0, 1.35)
	_squash = lerpf(_squash, target, 1.0 - exp(-9.0 * delta))

	if _facing.length_squared() > 0.001:
		var goal := Basis.looking_at(_facing.normalized(), Vector3.UP).get_rotation_quaternion()
		var current := skin_pivot.global_transform.basis.get_rotation_quaternion()
		var t := 1.0 - exp(-turn_speed * delta)
		var stretch := Vector3(_base_scale / sqrt(_squash), _base_scale * _squash, _base_scale / sqrt(_squash))
		var xform := skin_pivot.global_transform
		xform.basis = Basis(current.slerp(goal, t)).scaled(stretch)
		skin_pivot.global_transform = xform


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _fit_model_to_size() -> void:
	if skin_pivot == null:
		return
	var aabb := _merged_visual_aabb(skin_pivot)
	if aabb.size.length_squared() < 0.000001:
		return
	var footprint := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	_base_scale = frog_size / maxf(footprint, 0.001)
	skin_pivot.scale = Vector3.ONE * _base_scale
	# Rest the model's feet on the body origin (which sits on the floor).
	for child in skin_pivot.get_children():
		if child is Node3D:
			(child as Node3D).position.y -= aabb.position.y


func _merged_visual_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var vi := node as VisualInstance3D
			var local := vi.global_transform * vi.get_aabb()
			var relative := AABB(local.position - root.global_position, local.size)
			if found:
				result = result.merge(relative)
			else:
				result = relative
				found = true
		for child in node.get_children():
			stack.append(child)
	return result
