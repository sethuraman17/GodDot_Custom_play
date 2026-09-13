extends Node
class_name HumanoidLocomotionAnimator

@export var animation_player_path: NodePath
@export_file("*.fbx", "*.glb") var idle_fbx: String = ""
@export_file("*.fbx", "*.glb") var walk_fbx: String = ""
@export_file("*.fbx", "*.glb") var run_fbx: String = ""
@export_file("*.fbx", "*.glb") var jump_fbx: String = ""
@export_file("*.fbx", "*.glb") var fall_fbx: String = ""
@export_file("*.fbx", "*.glb") var land_fbx: String = ""
@export_file("*.fbx", "*.glb") var long_idle_fbx: String = ""
@export_file("*.fbx", "*.glb") var punch_fbx: String = ""
@export_file("*.fbx", "*.glb") var dance_fbx: String = ""
@export var library_name: StringName = &"adventure_locomotion"
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var run_animation: StringName = &"Run"
@export var jump_animation: StringName = &"Jump"
@export var fall_animation: StringName = &"Fall"
@export var land_animation: StringName = &"Land"
@export var long_idle_animation: StringName = &"LongIdle"
@export var punch_animation: StringName = &"Punch"
@export var dance_animation: StringName = &"Dance"
@export var long_idle_delay: float = 10.0
@export var still_idle_track_name_filters: PackedStringArray = PackedStringArray(["head", "neck"])
@export var walk_speed_threshold: float = 0.25
@export var run_speed_threshold: float = 4.8
@export var landing_vertical_speed_threshold: float = -3.0
@export var land_hold_time: float = 0.35
@export var root_motion_track_path: String = ""
@export var root_motion_track_name_hint: String = "Hips"
@export var strip_horizontal_root_motion: bool = true
@export var normalize_low_root_y: bool = true
@export var root_y_drop_tolerance: float = 0.18

## Maps a source clip's bone name (after stripping a "mixamorig_"/"mixamorig:" prefix)
## to the target skeleton's actual bone name, for characters whose rig doesn't use
## the source clips' naming verbatim (e.g. "Neck" -> "neck", "Spine1" -> "Spine01").
@export var bone_name_overrides: Dictionary = {
	"Neck": "neck",
	"Spine1": "Spine01",
	"Spine2": "Spine02",
}

@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer

var _current: StringName = &""
var _position_ratio: float = 0.0
var _root_y_reference: float = NAN
var _was_on_floor: bool = true
var _last_vertical_velocity: float = 0.0
var _land_timer: float = 0.0
var _idle_timer: float = 0.0
var _clip_overrides: Dictionary = {}
var _freeze_idle_head: bool = true
var _rescale_positions: bool = true
var _emote: StringName = &""
var _finished_connected: bool = false


func _ready() -> void:
	if animation_player == null:
		push_warning("HumanoidLocomotionAnimator has no AnimationPlayer.")
		return
	_root_y_reference = NAN
	_position_ratio = 0.0
	_import_configured_clips()
	_play(idle_animation)
	_connect_finished()


## Re-resolve the AnimationPlayer and reimport the clip set after the character
## model under animation_player_path has been swapped for a different rig.
## Cached retarget state is per-skeleton, so it must be rederived.
func rebind() -> void:
	_finished_connected = false
	_emote = &""
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_current = &""
	_root_y_reference = NAN
	_position_ratio = 0.0
	if animation_player == null:
		push_warning("HumanoidLocomotionAnimator: no AnimationPlayer after rebind.")
		return
	_import_configured_clips()
	_play(idle_animation)
	_connect_finished()


## Optional per-character clip paths. Keys: idle/walk/run/jump/fall/land/long_idle/punch/dance.
## An empty string skips that clip. Call before rebind(). Pass {} to restore the scene defaults.
func configure_clips(clips: Dictionary, freeze_idle_head: bool = true, rescale_positions: bool = true) -> void:
	_clip_overrides = clips.duplicate()
	_freeze_idle_head = freeze_idle_head
	_rescale_positions = rescale_positions


func play_punch() -> void:
	if animation_player == null or not _has_anim(punch_animation):
		return
	_emote = punch_animation
	_idle_timer = 0.0
	_play(punch_animation)


func play_dance() -> void:
	if animation_player == null or not _has_anim(dance_animation):
		return
	if _emote == dance_animation:
		_emote = &""
		_play(idle_animation)
		return
	_emote = dance_animation
	_idle_timer = 0.0
	_play(dance_animation)


func set_locomotion(horizontal_speed: float, sprinting: bool, on_floor: bool = true, vertical_velocity: float = 0.0, delta: float = 0.0) -> void:
	if animation_player == null:
		return

	if _emote == punch_animation:
		return
	if _emote == dance_animation:
		if sprinting or horizontal_speed > walk_speed_threshold:
			_emote = &""
		else:
			return

	var step_delta := delta if delta > 0.0 else 1.0 / float(Engine.physics_ticks_per_second)
	var landed := on_floor and not _was_on_floor
	if landed and _last_vertical_velocity <= landing_vertical_speed_threshold and _has_anim(land_animation):
		_idle_timer = 0.0
		_land_timer = land_hold_time
		_play(land_animation)

	_was_on_floor = on_floor
	_last_vertical_velocity = vertical_velocity

	if _land_timer > 0.0:
		_land_timer = maxf(_land_timer - step_delta, 0.0)
		return

	if not on_floor:
		_idle_timer = 0.0
		if vertical_velocity > 0.1 and _has_anim(jump_animation):
			_play(jump_animation)
		elif _has_anim(fall_animation):
			_play(fall_animation)
		else:
			_play(run_animation if _has_anim(run_animation) else idle_animation)
		return

	if horizontal_speed <= walk_speed_threshold:
		_idle_timer += step_delta
		if _idle_timer >= long_idle_delay and _has_anim(long_idle_animation):
			_play(long_idle_animation)
		else:
			_play(idle_animation)
	elif sprinting or horizontal_speed >= run_speed_threshold or not _has_anim(walk_animation):
		_idle_timer = 0.0
		_play(run_animation if _has_anim(run_animation) else idle_animation)
	else:
		_idle_timer = 0.0
		_play(walk_animation)


func _import_configured_clips() -> void:
	var lib := AnimationLibrary.new()
	_add_clip(lib, _clip_path("idle", idle_fbx), idle_animation, true, _freeze_idle_head)
	_add_clip(lib, _clip_path("walk", walk_fbx), walk_animation, true)
	_add_clip(lib, _clip_path("run", run_fbx), run_animation, true)
	_add_clip(lib, _clip_path("jump", jump_fbx), jump_animation, false)
	_add_clip(lib, _clip_path("fall", fall_fbx), fall_animation, true)
	_add_clip(lib, _clip_path("land", land_fbx), land_animation, false)
	var long_idle_path := _clip_path("long_idle", long_idle_fbx if not long_idle_fbx.is_empty() else idle_fbx)
	if long_idle_animation != idle_animation and not long_idle_path.is_empty():
		_add_clip(lib, long_idle_path, long_idle_animation, true)
	_add_clip(lib, _clip_path("punch", punch_fbx), punch_animation, false)
	_add_clip(lib, _clip_path("dance", dance_fbx), dance_animation, true)

	if lib.get_animation_list().is_empty():
		return

	if animation_player.has_animation_library(library_name):
		animation_player.remove_animation_library(library_name)
	animation_player.add_animation_library(library_name, lib)


func _clip_path(key: String, fallback: String) -> String:
	if _clip_overrides.has(key):
		return String(_clip_overrides[key])
	return fallback


func _connect_finished() -> void:
	if animation_player == null or _finished_connected:
		return
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_finished_connected = true


func _on_animation_finished(anim_name: StringName) -> void:
	if _emote != punch_animation:
		return
	var punch_lib := "%s/%s" % [String(library_name), String(punch_animation)]
	if anim_name != punch_animation and String(anim_name) != punch_lib:
		return
	_emote = &""
	_play(idle_animation)


func _add_clip(lib: AnimationLibrary, fbx_path: String, target_name: StringName, loop_clip: bool, still_head_tracks: bool = false) -> void:
	if fbx_path.is_empty():
		return
	if not ResourceLoader.exists(fbx_path):
		push_warning("Missing animation clip: %s" % fbx_path)
		return

	var scene := load(fbx_path) as PackedScene
	if scene == null:
		push_warning("Could not load animation clip: %s" % fbx_path)
		return

	var inst := scene.instantiate()
	var source_player := _find_animation_player_in(inst)
	if source_player == null or source_player.get_animation_list().is_empty():
		push_warning("No AnimationPlayer found in %s" % fbx_path)
		inst.free()
		return

	var source_name := source_player.get_animation_list()[0]
	var best_len := -1.0
	for candidate in source_player.get_animation_list():
		var candidate_anim := source_player.get_animation(candidate)
		if candidate_anim != null and candidate_anim.length > best_len:
			best_len = candidate_anim.length
			source_name = candidate
	var anim := source_player.get_animation(source_name)
	if anim != null:
		var copy := anim.duplicate()
		if loop_clip:
			copy.loop_mode = Animation.LOOP_LINEAR
		_retarget_track_paths(copy)
		_rescale_position_tracks(copy)
		_sanitize_root_motion(copy)
		if still_head_tracks:
			_freeze_named_tracks(copy, still_idle_track_name_filters)
		lib.add_animation(target_name, copy)

	inst.free()


func _retarget_track_paths(anim: Animation) -> void:
	var skeleton := _find_target_skeleton()
	if skeleton == null:
		return
	var root := animation_player.get_node_or_null(animation_player.root_node)
	if root == null:
		return
	# Rebuild the node-path portion from scratch (not just the bone name): the
	# source clips assume the skeleton sits directly under the animated root
	# (e.g. "Skeleton3D:Hips"), but a target character's skeleton may be nested
	# deeper (e.g. under an "Armature" wrapper) — reusing the source's node path
	# would silently fail to resolve any track on such a character.
	var skeleton_path := String(root.get_path_to(skeleton))

	for track_index in range(anim.get_track_count() - 1, -1, -1):
		var track_path := str(anim.track_get_path(track_index))
		var colon_index := track_path.find(":")
		if colon_index == -1:
			continue

		var bone_part := track_path.substr(colon_index + 1)
		var resolved := _resolve_bone_name(skeleton, bone_part)
		if resolved.is_empty():
			anim.remove_track(track_index)
		else:
			anim.track_set_path(track_index, NodePath("%s:%s" % [skeleton_path, resolved]))


func _rescale_position_tracks(anim: Animation) -> void:
	if not _rescale_positions:
		_position_ratio = 1.0
		return
	# Source clips and the target rig may be authored in different units (the
	# robot clips keep Hips around y=1.4 in meters; the swapped-in character's
	# skeleton is centimeter-scale with Hips resting at y~97). Bone POSITION
	# tracks are raw values in the skeleton's own bone space, so applying the
	# clips verbatim pins the pelvis at ankle height and buries the legs in the
	# ground. Rescale every position key by the ratio of the two rigs' standing
	# hip heights (derived once, from the first clip that animates the hips).
	var skeleton := _find_target_skeleton()
	if skeleton == null:
		return

	if _position_ratio == 0.0:
		var target_hips := _resolve_bone_name(skeleton, root_motion_track_name_hint)
		if target_hips.is_empty():
			return
		var target_rest_y := skeleton.get_bone_rest(skeleton.find_bone(target_hips)).origin.y
		for track_index in range(anim.get_track_count()):
			if anim.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
				continue
			if not str(anim.track_get_path(track_index)).to_lower().contains(root_motion_track_name_hint.to_lower()):
				continue
			if anim.track_get_key_count(track_index) == 0:
				continue
			var source_y := (anim.track_get_key_value(track_index, 0) as Vector3).y
			if absf(source_y) > 0.001 and absf(target_rest_y) > 0.001:
				_position_ratio = target_rest_y / source_y
			break

	if _position_ratio == 0.0 or absf(_position_ratio - 1.0) < 0.01:
		return

	for track_index in range(anim.get_track_count()):
		if anim.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		for key_index in range(anim.track_get_key_count(track_index)):
			var value: Variant = anim.track_get_key_value(track_index, key_index)
			if value is Vector3:
				anim.track_set_key_value(track_index, key_index, (value as Vector3) * _position_ratio)


func _resolve_bone_name(skeleton: Skeleton3D, source_name: String) -> String:
	if skeleton.find_bone(source_name) != -1:
		return source_name

	var stripped := source_name
	if stripped.begins_with("mixamorig_"):
		stripped = stripped.substr("mixamorig_".length())
	elif stripped.begins_with("mixamorig:"):
		stripped = stripped.substr("mixamorig:".length())

	if bone_name_overrides.has(stripped):
		stripped = bone_name_overrides[stripped]

	if skeleton.find_bone(stripped) != -1:
		return stripped

	for bone_index in range(skeleton.get_bone_count()):
		if skeleton.get_bone_name(bone_index).to_lower() == stripped.to_lower():
			return skeleton.get_bone_name(bone_index)

	return ""


func _find_target_skeleton() -> Skeleton3D:
	var root := animation_player.get_node_or_null(animation_player.root_node)
	if root == null:
		return null
	return _find_skeleton_in(root)


func _find_skeleton_in(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton_in(child)
		if found != null:
			return found
	return null


func _find_animation_player_in(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player_in(child)
		if found != null:
			return found
	return null


func _sanitize_root_motion(anim: Animation) -> void:
	for track_index in range(anim.get_track_count()):
		if not _is_root_motion_track(anim, track_index):
			continue
		var key_count := anim.track_get_key_count(track_index)
		if key_count < 2:
			return
		var first_value: Variant = anim.track_get_key_value(track_index, 0)
		if not (first_value is Vector3):
			return
		var first_position := first_value as Vector3
		if is_nan(_root_y_reference):
			_root_y_reference = first_position.y

		# root_y_drop_tolerance is authored in the source clips' meter units;
		# when position tracks were rescaled into the target rig's bone space,
		# the tolerance must scale with them or it misfires on tiny bobs.
		var tolerance := root_y_drop_tolerance * (absf(_position_ratio) if _position_ratio != 0.0 else 1.0)
		var y_offset := 0.0
		if normalize_low_root_y and first_position.y < _root_y_reference - tolerance:
			y_offset = _root_y_reference - first_position.y

		for key_index in range(key_count):
			var value: Variant = anim.track_get_key_value(track_index, key_index)
			if value is Vector3:
				var position := value as Vector3
				if strip_horizontal_root_motion:
					position.x = first_position.x
					position.z = first_position.z
				if y_offset != 0.0:
					position.y += y_offset
				anim.track_set_key_value(track_index, key_index, position)
		return


func _is_root_motion_track(anim: Animation, track_index: int) -> bool:
	var track_path := str(anim.track_get_path(track_index))
	if not root_motion_track_path.is_empty():
		return track_path == root_motion_track_path
	if root_motion_track_name_hint.is_empty():
		return false
	if not track_path.to_lower().contains(root_motion_track_name_hint.to_lower()):
		return false
	if anim.track_get_key_count(track_index) == 0:
		return false
	return anim.track_get_key_value(track_index, 0) is Vector3


func _play(anim_name: StringName) -> void:
	if anim_name == StringName() or _current == anim_name:
		return

	var library_anim := "%s/%s" % [String(library_name), String(anim_name)]
	if animation_player.has_animation(library_anim):
		animation_player.play(library_anim, 0.12)
		_current = anim_name
	elif animation_player.has_animation(anim_name):
		animation_player.play(anim_name, 0.12)
		_current = anim_name


func _freeze_named_tracks(anim: Animation, name_filters: PackedStringArray) -> void:
	if name_filters.is_empty():
		return

	for track_index in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(track_index)).to_lower()
		var should_freeze := false
		for name_filter in name_filters:
			if not name_filter.is_empty() and track_path.contains(name_filter.to_lower()):
				should_freeze = true
				break
		if not should_freeze:
			continue

		var key_count := anim.track_get_key_count(track_index)
		if key_count < 2:
			continue

		var first_value: Variant = anim.track_get_key_value(track_index, 0)
		for key_index in range(1, key_count):
			anim.track_set_key_value(track_index, key_index, first_value)


func _has_anim(anim_name: StringName) -> bool:
	if anim_name == StringName() or animation_player == null:
		return false
	return animation_player.has_animation("%s/%s" % [String(library_name), String(anim_name)]) or animation_player.has_animation(anim_name)
