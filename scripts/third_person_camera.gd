extends Node3D
class_name ThirdPersonAdventureCamera

@export var target_path: NodePath
@export var pitch_pivot_path: NodePath = ^"PitchPivot"
@export var spring_arm_path: NodePath = ^"PitchPivot/SpringArm3D"
@export var camera_path: NodePath = ^"PitchPivot/SpringArm3D/Camera3D"

@export var pitch_degrees: float = -22.0
@export var spring_length: float = 5.6
@export var height_offset: float = 1.9
@export var position_follow_lag: float = 14.0

@export var follow_player_facing: bool = true
@export var facing_follow_speed: float = 3.5

@export var input_reader_path: NodePath = ^"../InputReader"
@export var peek_max_degrees: float = 70.0
@export var peek_speed: float = 4.0
@export var peek_return_speed: float = 3.0

@export var touch_look_sensitivity: float = 0.0045
@export var min_pitch_degrees: float = -55.0
@export var max_pitch_degrees: float = 8.0

@export var look_ahead_time: float = 0.35
@export var look_ahead_max_distance: float = 2.5
@export var look_ahead_smoothing: float = 6.0

@export var speed_fov_boost_degrees: float = 8.0
@export var speed_fov_reference: float = 7.0
@export var speed_fov_smoothing: float = 5.0

@export var speed_shake_threshold: float = 4.5
@export var speed_shake_reference: float = 8.0
@export var speed_shake_max_angle_degrees: float = 0.06

@onready var pitch_pivot: Node3D = get_node_or_null(pitch_pivot_path) as Node3D
@onready var spring_arm: SpringArm3D = get_node_or_null(spring_arm_path) as SpringArm3D
@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var target: Node3D = get_node_or_null(target_path) as Node3D
@onready var input_reader := get_node_or_null(input_reader_path)

var _look_ahead_offset: Vector3 = Vector3.ZERO
var _shake_offset: Vector3 = Vector3.ZERO
var _base_fov: float = 68.0
var _follow_yaw: float = 0.0
var _peek_yaw: float = 0.0


func _ready() -> void:
	if spring_arm != null:
		spring_arm.spring_length = spring_length
		spring_arm.margin = 0.2
		spring_arm.collision_mask = AdventureLayers.CAMERA_MASK
		if target is CollisionObject3D:
			spring_arm.add_excluded_object((target as CollisionObject3D).get_rid())

	if camera != null:
		camera.current = true
		_base_fov = camera.fov

	if pitch_pivot != null:
		pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)

	_follow_yaw = rotation.y

	if target != null:
		global_position = _target_position()
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null or pitch_pivot == null:
		return

	var horizontal_velocity := Vector3.ZERO
	if target is CharacterBody3D:
		horizontal_velocity = (target as CharacterBody3D).velocity
		horizontal_velocity.y = 0.0
	var speed := horizontal_velocity.length()

	# Back-follow camera: the rig yaws toward the player's facing so the view
	# stays behind their back; the knob's peek keys add a temporary yaw offset
	# on top. Touch look (mobile) adds a persistent yaw/pitch while dragging.
	_apply_touch_look()
	if follow_player_facing and (input_reader == null or not input_reader.is_look_dragging()):
		_update_facing_follow(delta)
	_update_peek(delta)
	rotation.y = _follow_yaw + _peek_yaw
	_update_look_ahead(horizontal_velocity, delta)
	var desired := _target_position()
	var position_t := 1.0 if position_follow_lag <= 0.0 else 1.0 - exp(-position_follow_lag * delta)
	global_position = global_position.lerp(desired, position_t)

	_update_speed_fov(speed, delta)
	_update_speed_shake(speed)


func _apply_touch_look() -> void:
	if input_reader == null or not input_reader.has_method("consume_look_delta"):
		return
	var look: Vector2 = input_reader.consume_look_delta()
	if look == Vector2.ZERO or pitch_pivot == null:
		return
	_follow_yaw -= look.x * touch_look_sensitivity
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x - look.y * touch_look_sensitivity,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)


func _update_facing_follow(delta: float) -> void:
	if not target.has_method("get_facing_direction"):
		return
	var facing: Vector3 = target.call("get_facing_direction")
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		return
	facing = facing.normalized()
	# Walking toward the camera must not trigger a chase: the follow would
	# flip the view 180, reversing the input and spinning forever. Hold the
	# camera still and let the character run at the screen instead. Compare
	# against the follow yaw (not the peeked basis) so peeking can't distort
	# the guard.
	var follow_forward := Vector3(-sin(_follow_yaw), 0.0, -cos(_follow_yaw))
	if facing.dot(follow_forward) < -0.4:
		return
	# Rig forward is -basis.z; solve the yaw that points it along `facing`.
	var desired_yaw := atan2(-facing.x, -facing.z)
	var t := 1.0 if facing_follow_speed <= 0.0 else 1.0 - exp(-facing_follow_speed * delta)
	_follow_yaw = lerp_angle(_follow_yaw, desired_yaw, t)


func _update_peek(delta: float) -> void:
	var axis: float = 0.0
	if input_reader != null and input_reader.has_method("get_peek_axis"):
		axis = input_reader.get_peek_axis()
	if absf(axis) > 0.01:
		# Peek right = clockwise = negative yaw.
		var target_peek := -signf(axis) * deg_to_rad(peek_max_degrees)
		var t := 1.0 - exp(-peek_speed * delta)
		_peek_yaw = lerpf(_peek_yaw, target_peek, t)
	else:
		var t_back := 1.0 - exp(-peek_return_speed * delta)
		_peek_yaw = lerpf(_peek_yaw, 0.0, t_back)
		if absf(_peek_yaw) < 0.001:
			_peek_yaw = 0.0


func _update_look_ahead(horizontal_velocity: Vector3, delta: float) -> void:
	var lead := horizontal_velocity * look_ahead_time
	if lead.length() > look_ahead_max_distance:
		lead = lead.normalized() * look_ahead_max_distance

	var t := 1.0 if look_ahead_smoothing <= 0.0 else 1.0 - exp(-look_ahead_smoothing * delta)
	_look_ahead_offset = _look_ahead_offset.lerp(lead, t)


func _update_speed_fov(speed: float, delta: float) -> void:
	if camera == null:
		return

	var speed_fraction := 0.0 if speed_fov_reference <= 0.0 else clampf(speed / speed_fov_reference, 0.0, 1.0)
	var desired_fov := _base_fov + speed_fov_boost_degrees * speed_fraction
	var t := 1.0 if speed_fov_smoothing <= 0.0 else 1.0 - exp(-speed_fov_smoothing * delta)
	camera.fov = lerpf(camera.fov, desired_fov, t)


func _update_speed_shake(speed: float) -> void:
	if camera == null:
		return

	# Undo last frame's jitter before deciding the next one, or the
	# camera's local rotation drifts every frame the shake is active.
	if _shake_offset != Vector3.ZERO:
		camera.rotation -= _shake_offset
		_shake_offset = Vector3.ZERO

	var shake_range := speed_shake_reference - speed_shake_threshold
	var above_threshold := 0.0 if shake_range <= 0.0 else clampf((speed - speed_shake_threshold) / shake_range, 0.0, 1.0)
	if above_threshold <= 0.0:
		return

	# Quadratic falloff: a light jog barely shakes, full sprint shakes noticeably.
	var shake := above_threshold * above_threshold
	var max_angle := deg_to_rad(speed_shake_max_angle_degrees) * shake
	_shake_offset = Vector3(
		randf_range(-max_angle, max_angle),
		randf_range(-max_angle, max_angle) * 0.5,
		0.0
	)
	camera.rotation += _shake_offset


func _target_position() -> Vector3:
	return target.global_position + Vector3.UP * height_offset + _look_ahead_offset


func get_flat_forward() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func get_flat_right() -> Vector3:
	var right := global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		return Vector3.RIGHT
	return right.normalized()


func get_camera() -> Camera3D:
	return camera
