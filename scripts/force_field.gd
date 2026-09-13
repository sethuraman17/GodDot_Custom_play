extends Node3D
class_name ForceField

## A deployable energy globe. Spends `build_time` growing into place
## (protecting from nothing), then `active_time` fully formed — while ACTIVE
## it shields anyone inside from heat waves and counts as full shade against
## the sun (SunExposure checks the "force_fields" group). Dissolves when its
## active window ends or when told to (a passing heat wave consumes it).

signal became_active
signal dissolved

const GROUP := &"force_fields"

@export var radius: float = 2.5
@export var build_time: float = 5.0
@export var active_time: float = 5.0

const WATER_SHADER := preload("res://shaders/force_field_water.gdshader")
const SETUP_MUSIC := preload("res://assets/music/force_field_setup.mp3")

var _state: int = STATE_BUILDING
var _timer: float = 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _label: Label3D
var _setup_music: AudioStreamPlayer3D

enum { STATE_BUILDING, STATE_ACTIVE, STATE_DISSOLVING }


func _ready() -> void:
	add_to_group(GROUP)
	_build_visuals()
	_setup_music = AudioStreamPlayer3D.new()
	_setup_music.name = "SetupMusic"
	_setup_music.stream = SETUP_MUSIC
	_setup_music.max_distance = 30.0
	add_child(_setup_music)
	_setup_music.play()


func _process(delta: float) -> void:
	_timer += delta
	match _state:
		STATE_BUILDING:
			var progress := clampf(_timer / build_time, 0.0, 1.0)
			_mesh.scale = Vector3.ONE * maxf(progress, 0.05)
			_material.set_shader_parameter("alpha_boost", 0.35 + 0.65 * progress)
			_label.text = "%.0f" % ceilf(build_time - _timer)
			if _timer >= build_time:
				_enter_active()
		STATE_ACTIVE:
			# Gentle shimmer so an active field reads differently from a building one.
			var pulse := 0.5 + 0.5 * sin(_timer * 6.0)
			_material.set_shader_parameter("alpha_boost", 0.9 + 0.2 * pulse)
			if _timer >= active_time:
				dissolve()
		STATE_DISSOLVING:
			var fade := clampf(1.0 - _timer / 0.4, 0.0, 1.0)
			_material.set_shader_parameter("alpha_boost", fade)
			if _timer >= 0.4:
				queue_free()


func is_active() -> bool:
	return _state == STATE_ACTIVE


func is_gone() -> bool:
	return _state == STATE_DISSOLVING


func contains(point: Vector3) -> bool:
	return global_position.distance_to(point) <= radius


func dissolve() -> void:
	if _state == STATE_DISSOLVING:
		return
	_state = STATE_DISSOLVING
	_timer = 0.0
	_label.visible = false
	# Cut the setup music if the globe is consumed mid-build.
	if _setup_music != null and _setup_music.playing:
		_setup_music.stop()
	dissolved.emit()


func _enter_active() -> void:
	_state = STATE_ACTIVE
	_timer = 0.0
	_mesh.scale = Vector3.ONE
	_material.set_shader_parameter("alpha_boost", 1.0)
	_label.text = "SAFE"
	_label.modulate = Color(0.5, 1.0, 0.8, 1.0)
	became_active.emit()


func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Globe"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_material = ShaderMaterial.new()
	_material.shader = WATER_SHADER
	_material.set_shader_parameter("alpha_boost", 0.35)
	_mesh.material_override = _material
	add_child(_mesh)

	_label = Label3D.new()
	_label.name = "Countdown"
	_label.position = Vector3(0, radius + 0.6, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.modulate = Color(0.6, 0.9, 1.0, 1.0)
	_label.outline_size = 12
	_label.text = "%.0f" % build_time
	add_child(_label)
