extends Node3D
class_name AdventureWorm

## Pure ambiance critter: a chain of plain, tapered spheres strung along a
## single deterministic path (the "spine") that dictates where the whole
## body is at any moment. The head travels the spine at a constant speed;
## each trailing ball just reads its own position further back along the
## same spine. No per-ball rotation or scaling -- spheres look the same
## from every angle, so there's nothing to orient. Its one gameplay effect
## is zapping the player on contact with the breaching head (see
## _check_player_hit).

enum State { UNDERGROUND, MOVING }

const RUMBLE_STREAM := preload("res://assets/audio/worm_rumble.ogg")
const BREACH_STREAM := preload("res://assets/audio/worm_breach.ogg")

@export var terrain_path: NodePath = ^"../../TerrainRoot"
@export var wander_radius: float = 13.0
@export var travel_distance_min: float = 2.5
@export var travel_distance_max: float = 11.0
@export var head_speed: float = 2.2
@export var body_length_fraction: float = 0.8
# Hard cap on how long the visible body ever gets, independent of how far a
# given trip travels -- a real worm doesn't grow longer for a longer trip.
# Without this, long trips (see travel_distance_max above) would stretch the
# same segment count thin and bring back the "looks like separate balls" gaps.
@export var body_length_max: float = 4.8
@export var breach_wavelength: float = 2.5
@export var breach_amplitude_min: float = 0.45
@export var breach_amplitude_max: float = 1.2
@export var underground_time_min: float = 2.0
@export var underground_time_max: float = 6.0
# Adjacent balls keep a fixed gap along the spine, but the vertical bob's
# slope scales with breach_amplitude -- a tall bob stretches the real 3D
# distance between two neighbors well past their radius overlap right where
# the sine is steepest, splitting them into visible separate balls. Packing
# far more of them keeps that per-step gap small enough to stay overlapped
# even at breach_amplitude_max.
@export var segment_count: int = 90
@export var base_radius: float = 0.24
@export var min_radius: float = 0.08

# Telegraph: small sand disturbances that ripple out from the worm's resting
# spot towards where it's about to surface, in the last stretch of its
# underground wait. Hints at both direction and distance before the worm
# itself appears.
@export var telegraph_lead_time: float = 1.4
@export var telegraph_marker_count: int = 14
@export var telegraph_jitter: float = 0.6

@export var player_path: NodePath = ^"../../../Player"
@export var hit_radius: float = 1.1

@onready var _terrain: Node = get_node_or_null(terrain_path)
@onready var _player: Node3D = get_node_or_null(player_path) as Node3D

var _segments: Array[MeshInstance3D] = []
var _telegraph_markers: Array[MeshInstance3D] = []

# Fraction (0..1) of the body length where each segment sits, front to back.
# Spaced by each segment's own radius rather than evenly, so the thin taper
# at the head and tail packs balls tightly while the fat middle -- already
# covered by big overlapping spheres -- can spread them out.
var _segment_offset_frac: Array[float] = []

var _state: State = State.UNDERGROUND
var _state_timer: float = 0.0
var _state_duration: float = 0.0
var _traveled: float = 0.0
var _travel_total: float = 1.0
var _breach_amplitude: float = 0.45
var _origin_xz: Vector2
var _rest_xz: Vector2
var _pending_end_xz: Vector2
var _telegraph_jitter_offsets: Array[Vector2] = []
var _arc_start: Vector3
var _arc_end: Vector3
var _has_hit_this_trip: bool = false

# Positional audio telegraph: rumble swells during the pre-breach wait so the
# player hears which direction the worm is coming from, roar fires on breach.
var _rumble: AudioStreamPlayer3D
var _roar: AudioStreamPlayer3D


func _ready() -> void:
	if MobilePlatform.is_mobile():
		segment_count = 28
		telegraph_marker_count = 8
	_segments = _build_body()
	_telegraph_markers = _build_telegraph_markers()

	var rumble_ogg := RUMBLE_STREAM as AudioStreamOggVorbis
	if rumble_ogg != null:
		rumble_ogg.loop = true
	_rumble = _make_audio_player(RUMBLE_STREAM)
	_roar = _make_audio_player(BREACH_STREAM)
	_rest_xz = Vector2(global_position.x, global_position.z)
	_origin_xz = _rest_xz
	_hide_body()
	_enter_underground()


func _make_audio_player(stream: AudioStream) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.max_distance = 55.0
	player.max_db = 3.0
	add_child(player)
	return player


func _process(delta: float) -> void:
	_state_timer += delta
	match _state:
		State.UNDERGROUND:
			var remaining := _state_duration - _state_timer
			if remaining <= telegraph_lead_time:
				var progress := clampf(1.0 - remaining / maxf(telegraph_lead_time, 0.01), 0.0, 1.0)
				_update_telegraph(progress)
				if not _rumble.playing:
					_rumble.global_position = Vector3(_rest_xz.x, _ground_height(_rest_xz), _rest_xz.y)
					_rumble.play()
				_rumble.volume_db = lerpf(-20.0, -6.0, progress)
			if _state_timer >= _state_duration:
				_begin_travel()
		State.MOVING:
			_traveled += head_speed * delta
			_update_segments()
			_rumble.global_position = _position_on_spine(clampf(_traveled, 0.0, _travel_total))
			_check_player_hit()
			var tail_distance := _traveled - _body_length()
			if tail_distance >= _travel_total:
				_rest_xz = Vector2(_arc_end.x, _arc_end.z)
				_hide_body()
				_enter_underground()


func _enter_underground() -> void:
	_state = State.UNDERGROUND
	_state_timer = 0.0
	_state_duration = randf_range(underground_time_min, underground_time_max)
	# Pick where we're headed now, not when travel starts, so the telegraph
	# has a real destination to ripple towards during the wait.
	_pending_end_xz = _pick_destination(_rest_xz)
	_telegraph_jitter_offsets = _build_telegraph_jitter()
	_hide_telegraph()
	if _rumble != null:
		_rumble.stop()


func _begin_travel() -> void:
	var end_xz := _pending_end_xz
	_arc_start = Vector3(_rest_xz.x, _ground_height(_rest_xz), _rest_xz.y)
	_arc_end = Vector3(end_xz.x, _ground_height(end_xz), end_xz.y)
	_travel_total = maxf(_arc_start.distance_to(_arc_end), 0.01)
	_traveled = 0.0
	_breach_amplitude = randf_range(breach_amplitude_min, breach_amplitude_max)
	_has_hit_this_trip = false
	_state = State.MOVING
	_state_timer = 0.0
	_roar.global_position = _arc_start
	_roar.play()
	_rumble.volume_db = -6.0
	# Leave the telegraph markers showing through the whole trip -- they only
	# clear once the worm has fully resurfaced-and-submerged (see _process,
	# where _hide_body/_enter_underground run together at the end of travel).
	_update_segments()


func _body_length() -> float:
	return minf(_travel_total * body_length_fraction, body_length_max)


func _pick_destination(start_xz: Vector2) -> Vector2:
	var distance := randf_range(travel_distance_min, travel_distance_max)
	var angle := randf_range(0.0, TAU)
	var candidate := start_xz + Vector2(cos(angle), sin(angle)) * distance
	if candidate.distance_to(_origin_xz) > wander_radius:
		candidate = _origin_xz + (candidate - _origin_xz).normalized() * (wander_radius * 0.6)
	return candidate


func _ground_height(xz: Vector2) -> float:
	if _terrain != null and _terrain.has_method("get_height_at"):
		return _terrain.get_height_at(xz.x, xz.y)
	return global_position.y


func _position_on_spine(distance: float) -> Vector3:
	var frac := clampf(distance / _travel_total, 0.0, 1.0)
	var horizontal := Vector2(_arc_start.x, _arc_start.z).lerp(Vector2(_arc_end.x, _arc_end.z), frac)
	# Sample the real terrain height at this point rather than interpolating
	# between the path's two endpoints -- the ground is noisy (bumps, holes),
	# so a straight lerp would float over dips or clip through rises.
	var ground := _ground_height(horizontal)
	# Fade the bob to zero at both ends of this segment's own path (frac 0
	# and 1) so it's always flush with the sand right when it pops into or
	# out of view -- otherwise the raw sine could be caught mid-peak at the
	# visibility cutoff, popping a ball while it's still visibly airborne.
	var surface_envelope := sin(PI * frac)
	var breach := sin(distance / breach_wavelength * TAU) * _breach_amplitude * surface_envelope
	return Vector3(horizontal.x, ground + breach, horizontal.y)


func _update_segments() -> void:
	var length := _body_length()
	for i in range(_segments.size()):
		var d := _traveled - _segment_offset_frac[i] * length
		var segment := _segments[i]

		# A ball that hasn't reached its own point on the spine yet (or has
		# already passed the destination) is still buried -- hide it rather
		# than pin it to a shared boundary position.
		if d <= 0.0 or d >= _travel_total:
			segment.visible = false
			continue

		segment.visible = true
		segment.global_position = _position_on_spine(d)


# One hit per breach: only checked while _has_hit_this_trip is still false,
# which _begin_travel resets at the start of every new trip.
func _check_player_hit() -> void:
	if _has_hit_this_trip or _player == null:
		return
	var head := _position_on_spine(_traveled)
	var head_xz := Vector2(head.x, head.z)
	var player_xz := Vector2(_player.global_position.x, _player.global_position.z)
	if head_xz.distance_to(player_xz) > hit_radius:
		return
	if not _player.has_method("apply_worm_stun"):
		return
	_has_hit_this_trip = true
	var away := player_xz - head_xz
	var knockback_dir := Vector3(away.x, 0.0, away.y).normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	_player.call("apply_worm_stun", knockback_dir)


func _hide_body() -> void:
	for segment in _segments:
		segment.visible = false


func _build_body() -> Array[MeshInstance3D]:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.6

	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 64
	noise_tex.height = 64
	noise_tex.seamless = true
	noise_tex.noise = noise

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.74, 0.42, 0.4)
	mat.albedo_texture = noise_tex
	mat.roughness = 0.9
	mat.uv1_scale = Vector3(4.0, 4.0, 1.0)

	var radii: Array[float] = []
	for i in range(segment_count):
		var mid := float(i) / float(segment_count - 1)
		var taper := sin(PI * mid)
		radii.append(lerpf(min_radius, base_radius, taper))
	_segment_offset_frac = _build_offset_fractions(radii)

	var segments: Array[MeshInstance3D] = []
	for i in range(segment_count):
		var radius: float = radii[i]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "WormSegment%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		# These are tiny and there are a lot of them now -- low poly keeps the
		# per-worm triangle budget in check.
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh_instance.mesh = mesh
		mesh_instance.material_override = mat
		mesh_instance.visible = false
		add_child(mesh_instance)
		segments.append(mesh_instance)
	return segments


# Cumulative front-to-back offset for each segment, as a 0..1 fraction of the
# total body length. The gap before a segment scales with its own radius plus
# its neighbor's, so thin segments (head/tail taper) sit close together and
# fat segments (mid-body) spread out -- density follows sphere size instead
# of being spread evenly across the index count.
func _build_offset_fractions(radii: Array[float]) -> Array[float]:
	var fractions: Array[float] = [0.0]
	var gaps: Array[float] = []
	var total := 0.0
	for i in range(radii.size() - 1):
		var gap: float = radii[i] + radii[i + 1]
		gaps.append(gap)
		total += gap
	var cumulative := 0.0
	for gap in gaps:
		cumulative += gap
		fractions.append(cumulative / total)
	return fractions


func _build_telegraph_markers() -> Array[MeshInstance3D]:
	var mat := StandardMaterial3D.new()
	# Just a touch darker/duller than the sand -- a faint shift in the ground,
	# not an object sitting on top of it.
	mat.albedo_color = Color(0.67, 0.57, 0.4)
	mat.roughness = 1.0

	var markers: Array[MeshInstance3D] = []
	for i in range(telegraph_marker_count):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "TelegraphMarker%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.22
		mesh_instance.mesh = mesh
		mesh_instance.material_override = mat
		mesh_instance.visible = false
		mesh_instance.scale = Vector3.ZERO
		add_child(mesh_instance)
		markers.append(mesh_instance)
	return markers


func _build_telegraph_jitter() -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for i in range(telegraph_marker_count):
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(0.0, telegraph_jitter)
		offsets.append(Vector2(cos(angle), sin(angle)) * radius)
	return offsets


func _hide_telegraph() -> void:
	for marker in _telegraph_markers:
		marker.visible = false
		marker.scale = Vector3.ZERO


# Reveals markers as a ripple travelling from the resting spot towards the
# destination -- near markers pop first, far ones catch up right as travel
# begins, so the spread of dots hints at the distance before the worm shows.
func _update_telegraph(progress: float) -> void:
	for i in range(_telegraph_markers.size()):
		var marker := _telegraph_markers[i]
		var frac_along := float(i + 1) / float(_telegraph_markers.size() + 1)
		var reveal_start := frac_along * 0.8
		var local_progress := clampf((progress - reveal_start) / 0.2, 0.0, 1.0)
		if local_progress <= 0.0:
			marker.visible = false
			continue
		var point := _rest_xz.lerp(_pending_end_xz, frac_along) + _telegraph_jitter_offsets[i]
		marker.visible = true
		marker.global_position = Vector3(point.x, _ground_height(point) + 0.01, point.y)
		marker.scale = Vector3(1.0, 0.2, 1.0) * local_progress
