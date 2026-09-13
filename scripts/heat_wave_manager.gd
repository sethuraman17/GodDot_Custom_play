extends Node
class_name HeatWaveManager

## Recurring heat-wave hazard. Each wave is scheduled 15 s out;
## a 10 s siren precedes the instant hit. While the siren
## runs, a glowing wall of heat visibly races in from a random horizon
## direction (with a rising rumble) and sweeps over the player at the strike. Players inside an
## ACTIVE ForceField globe are spared, everyone else loses half their current
## health through SunExposure. Owns its own CanvasLayer UI (banner + screen
## tint) so the shared HUD script stays untouched.

signal wave_hit(protected: bool)

@export var player_path: NodePath = ^"../Player"
@export var sun_exposure_path: NodePath = ^"../Player/SunExposure"
@export var min_interval: float = 15.0
@export var max_interval: float = 15.0
@export var warning_time: float = 10.0
@export var passing_time: float = 2.0
@export var damage_fraction: float = 0.5

enum State { IDLE, WARNING, PASSING }

const RUMBLE_STREAM := preload("res://assets/audio/worm_rumble.ogg")

## The wave wall spawns this far out at warning start and reaches the player
## exactly when the countdown hits zero, then sweeps past during PASSING.
const WALL_APPROACH_DISTANCE := 250.0
const WALL_PASS_DISTANCE := 120.0
const WALL_WIDTH := 500.0
const WALL_HEIGHT := 60.0
const WALL_BASE_ALPHA := 0.45

@onready var _player: Node3D = get_node_or_null(player_path) as Node3D
@onready var _sun_exposure: SunExposure = get_node_or_null(sun_exposure_path) as SunExposure

var _state: State = State.IDLE
var _timer: float = 0.0
var _next_wave_in: float = 0.0

var _layer: CanvasLayer
var _banner: Label
var _tint: ColorRect
var _wall: MeshInstance3D
var _wall_material: StandardMaterial3D
var _wall_dir: Vector3 = Vector3.FORWARD
var _rumble: AudioStreamPlayer


func _ready() -> void:
	_build_ui()
	_build_wall()
	_rumble = AudioStreamPlayer.new()
	_rumble.name = "WaveRumble"
	_rumble.stream = RUMBLE_STREAM
	_rumble.pitch_scale = 0.8
	add_child(_rumble)
	reset()


func _process(delta: float) -> void:
	_timer += delta
	match _state:
		State.IDLE:
			if _timer >= _next_wave_in:
				_enter_warning()
		State.WARNING:
			var remaining := warning_time - _timer
			var closeness := 1.0 - clampf(remaining / warning_time, 0.0, 1.0)
			_banner.text = "⚠  HEAT WAVE INCOMING — %d" % int(ceilf(maxf(remaining, 0.0)))
			_tint.color.a = 0.10 + 0.18 * closeness
			_update_wall(clampf(remaining / warning_time, 0.0, 1.0) * WALL_APPROACH_DISTANCE, 1.0)
			_rumble.volume_db = lerpf(-24.0, -4.0, closeness)
			if not _rumble.playing:
				_rumble.play()
			if remaining <= 0.0:
				_strike()
		State.PASSING:
			var fade := clampf(1.0 - _timer / passing_time, 0.0, 1.0)
			_tint.color.a = 0.35 * fade
			_update_wall(-(_timer / passing_time) * WALL_PASS_DISTANCE, fade)
			if _timer >= passing_time:
				_enter_idle()


## Fresh schedule; called on every run start / retry from the main menu.
func reset() -> void:
	_dissolve_all_fields()
	_enter_idle()


## Test hook: force the next wave to begin its warning in `seconds`.
func force_next_wave(seconds: float) -> void:
	_state = State.IDLE
	_timer = 0.0
	_next_wave_in = seconds
	_banner.visible = false
	_tint.color.a = 0.0
	_wall.visible = false
	if _rumble.playing:
		_rumble.stop()


func _enter_idle() -> void:
	_state = State.IDLE
	_timer = 0.0
	_next_wave_in = randf_range(min_interval, max_interval)
	_banner.visible = false
	_tint.color.a = 0.0
	_wall.visible = false
	if _rumble != null and _rumble.playing:
		_rumble.stop()


func _enter_warning() -> void:
	_state = State.WARNING
	_timer = 0.0
	_banner.visible = true
	_banner.modulate = Color(1.0, 0.75, 0.3, 1.0)
	var angle := randf() * TAU
	_wall_dir = Vector3(sin(angle), 0.0, cos(angle))
	_wall.visible = true
	_update_wall(WALL_APPROACH_DISTANCE, 1.0)
	_rumble.volume_db = -24.0
	_rumble.play()


func _strike() -> void:
	# Protection is evaluated BEFORE any field expiry this frame: a globe
	# deployed the moment the siren started is still active at the hit.
	var protected := _is_player_protected()
	if protected:
		_banner.text = "PROTECTED!"
		_banner.modulate = Color(0.5, 1.0, 0.8, 1.0)
	else:
		_banner.text = "SCORCHED!"
		_banner.modulate = Color(1.0, 0.4, 0.25, 1.0)
		if _sun_exposure != null and not _sun_exposure.invincible:
			_sun_exposure.apply_flat_damage(_sun_exposure.health * damage_fraction)
	wave_hit.emit(protected)
	_dissolve_all_fields()
	_state = State.PASSING
	_timer = 0.0
	_tint.color.a = 0.35
	if _rumble.playing:
		_rumble.stop()


func _is_player_protected() -> bool:
	if _player == null:
		return false
	for node in get_tree().get_nodes_in_group(ForceField.GROUP):
		var field := node as ForceField
		if field != null and field.is_active() and field.contains(_player.global_position):
			return true
	return false


func _dissolve_all_fields() -> void:
	for node in get_tree().get_nodes_in_group(ForceField.GROUP):
		var field := node as ForceField
		if field != null:
			field.dissolve()


## Giant translucent heat-wall. Lives directly under this plain Node, so its
## transform is world-space. Follows the player laterally so the sweep always
## crosses the camera exactly at the strike.
func _build_wall() -> void:
	_wall = MeshInstance3D.new()
	_wall.name = "WaveWall"
	var quad := QuadMesh.new()
	quad.size = Vector2(WALL_WIDTH, WALL_HEIGHT)
	_wall.mesh = quad
	_wall_material = StandardMaterial3D.new()
	_wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall_material.albedo_color = Color(1.0, 0.45, 0.1, WALL_BASE_ALPHA)
	_wall_material.emission_enabled = true
	_wall_material.emission = Color(1.0, 0.5, 0.15)
	_wall_material.emission_energy_multiplier = 2.0
	_wall.material_override = _wall_material
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.visible = false
	add_child(_wall)


## distance > 0: wall is that far out, closing in along _wall_dir.
## distance < 0: wall has swept past and is behind the player.
func _update_wall(distance: float, alpha_scale: float) -> void:
	if _player == null or _wall == null:
		return
	var base := _player.global_position
	var pos := base - _wall_dir * distance
	pos.y = base.y + WALL_HEIGHT * 0.3
	_wall.global_position = pos
	_wall.look_at(pos + _wall_dir, Vector3.UP)
	_wall_material.albedo_color.a = WALL_BASE_ALPHA * alpha_scale


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "HeatWaveUI"
	_layer.layer = 15
	add_child(_layer)

	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.color = Color(1.0, 0.42, 0.1, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tint)

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.visible = false
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 120.0
	_banner.offset_bottom = 190.0
	_banner.add_theme_font_size_override("font_size", 42)
	_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.0, 0.9))
	_banner.add_theme_constant_override("outline_size", 10)
	_layer.add_child(_banner)
