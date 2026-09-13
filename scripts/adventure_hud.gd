extends CanvasLayer
class_name AdventureHUD

@export var interaction_prompt_path: NodePath = ^"Root/InteractionPrompt"
@export var interaction_prompt_label_path: NodePath = ^"Root/InteractionPrompt/PromptLabel"
@export var status_prompt_path: NodePath = ^"Root/StatusPrompt"
@export var status_prompt_label_path: NodePath = ^"Root/StatusPrompt/StatusLabel"
@export var prompt_bottom_offset: float = 84.0
@export var health_bar_path: NodePath = ^"Root/HealthBar"
@export var health_fill_path: NodePath = ^"Root/HealthBar/Margin/Row/BarStack/Fill"
@export var health_trail_path: NodePath = ^"Root/HealthBar/Margin/Row/BarStack/TrailFill"
@export var health_ember_path: NodePath = ^"Root/HealthBar/Margin/Row/BarStack/EmberOverlay"
@export var health_flash_path: NodePath = ^"Root/HealthBar/Margin/Row/BarStack/FlashOverlay"
@export var health_gradient_path: NodePath = ^"Root/HealthBar/Margin/Row/BarStack/GradientFill"
@export var health_bar_width_ratio: float = 0.44
@export var health_bar_min_width: float = 520.0
@export var health_bar_max_width: float = 640.0
@export var water_bar_path: NodePath = ^"Root/WaterBar"
@export var water_fill_path: NodePath = ^"Root/WaterBar/Margin/Row/BarStack/Fill"
@export var water_trail_path: NodePath = ^"Root/WaterBar/Margin/Row/BarStack/TrailFill"
@export var water_shimmer_path: NodePath = ^"Root/WaterBar/Margin/Row/BarStack/ShimmerOverlay"
@export var water_flash_path: NodePath = ^"Root/WaterBar/Margin/Row/BarStack/FlashOverlay"
@export var water_bar_width_ratio: float = 0.44
@export var water_bar_min_width: float = 520.0
@export var water_bar_max_width: float = 640.0
@export var debug_panel_path: NodePath = ^"Root/DebugPanel"
@export var debug_label_path: NodePath = ^"Root/DebugPanel/Margin/VBox/DebugLabel"
@export var debug_speed_slider_path: NodePath = ^"Root/DebugPanel/Margin/VBox/SpeedRow/SpeedSlider"
@export var debug_speed_value_label_path: NodePath = ^"Root/DebugPanel/Margin/VBox/SpeedRow/SpeedValueLabel"
@export var debug_pause_check_path: NodePath = ^"Root/DebugPanel/Margin/VBox/PauseRow/PauseCheck"
@export var debug_dontdie_check_path: NodePath = ^"Root/DebugPanel/Margin/VBox/DontDieRow/DontDieCheck"
@export var debug_water_drain_slider_path: NodePath = ^"Root/DebugPanel/Margin/VBox/WaterDrainRow/WaterDrainSlider"
@export var debug_water_drain_value_label_path: NodePath = ^"Root/DebugPanel/Margin/VBox/WaterDrainRow/WaterDrainValueLabel"
@export var debug_dehydration_slider_path: NodePath = ^"Root/DebugPanel/Margin/VBox/DehydrationRow/DehydrationSlider"
@export var debug_dehydration_value_label_path: NodePath = ^"Root/DebugPanel/Margin/VBox/DehydrationRow/DehydrationValueLabel"
@export var sun_path: NodePath = ^"../Sun"
@export var sun_exposure_path: NodePath = ^"../Player/SunExposure"
@export var water_supply_path: NodePath = ^"../Player/WaterSupply"

@onready var root: Control = get_node_or_null(^"Root") as Control
@onready var interaction_prompt: PanelContainer = get_node_or_null(interaction_prompt_path) as PanelContainer
@onready var interaction_prompt_label: Label = get_node_or_null(interaction_prompt_label_path) as Label
@onready var status_prompt: PanelContainer = get_node_or_null(status_prompt_path) as PanelContainer
@onready var status_prompt_label: Label = get_node_or_null(status_prompt_label_path) as Label
@onready var health_bar: PanelContainer = get_node_or_null(health_bar_path) as PanelContainer
@onready var health_fill: ProgressBar = get_node_or_null(health_fill_path) as ProgressBar
@onready var health_trail: ProgressBar = get_node_or_null(health_trail_path) as ProgressBar
@onready var health_ember: ColorRect = get_node_or_null(health_ember_path) as ColorRect
@onready var health_flash: ColorRect = get_node_or_null(health_flash_path) as ColorRect
@onready var health_gradient: ColorRect = get_node_or_null(health_gradient_path) as ColorRect
@onready var water_bar: PanelContainer = get_node_or_null(water_bar_path) as PanelContainer
@onready var water_fill: ProgressBar = get_node_or_null(water_fill_path) as ProgressBar
@onready var water_trail: ProgressBar = get_node_or_null(water_trail_path) as ProgressBar
@onready var water_shimmer: ColorRect = get_node_or_null(water_shimmer_path) as ColorRect
@onready var water_flash: ColorRect = get_node_or_null(water_flash_path) as ColorRect
@onready var debug_panel: PanelContainer = get_node_or_null(debug_panel_path) as PanelContainer
@onready var debug_label: Label = get_node_or_null(debug_label_path) as Label
@onready var debug_speed_slider: HSlider = get_node_or_null(debug_speed_slider_path) as HSlider
@onready var debug_speed_value_label: Label = get_node_or_null(debug_speed_value_label_path) as Label
@onready var debug_pause_check: TextureButton = get_node_or_null(debug_pause_check_path) as TextureButton
@onready var debug_dontdie_check: TextureButton = get_node_or_null(debug_dontdie_check_path) as TextureButton
@onready var debug_water_drain_slider: HSlider = get_node_or_null(debug_water_drain_slider_path) as HSlider
@onready var debug_water_drain_value_label: Label = get_node_or_null(debug_water_drain_value_label_path) as Label
@onready var debug_dehydration_slider: HSlider = get_node_or_null(debug_dehydration_slider_path) as HSlider
@onready var debug_dehydration_value_label: Label = get_node_or_null(debug_dehydration_value_label_path) as Label
@onready var sun: SunCycle = get_node_or_null(sun_path) as SunCycle
@onready var sun_exposure: SunExposure = get_node_or_null(sun_exposure_path) as SunExposure
@onready var water_supply: WaterSupply = get_node_or_null(water_supply_path) as WaterSupply

var _status_prompt_token: int = 0
var _last_viewport_size: Vector2i = Vector2i.ZERO
var _bound_sun: SunCycle
var _bound_exposure: SunExposure
var _bound_water_supply: WaterSupply
var _last_health: float = 100.0
var _is_critical: bool = false
var _flash_tween: Tween
var _punch_tween: Tween
var _critical_tween: Tween
var _damage_flash_cooldown: float = 0.0
var _heal_flash_cooldown: float = 0.0
var _trail_hold_timer: float = 0.0
var _trail_catchup_speed: float = 45.0
var _trail_hold_duration: float = 0.35
var _idle_glow_tween: Tween
var _heal_tween: Tween
var _is_ember_healing: bool = false
var _last_water: float = 100.0
var _water_trail_hold_timer: float = 0.0
var _water_flash_tween: Tween
var _water_damage_flash_cooldown: float = 0.0
var _water_heal_flash_cooldown: float = 0.0
var _water_is_critical: bool = false
var _water_punch_tween: Tween
var _water_heal_tween: Tween
var _water_critical_tween: Tween
var _water_idle_glow_tween: Tween
var _is_water_shimmer_gaining: bool = false
var _health_punch_scale: Vector2 = Vector2.ONE
var _water_punch_scale: Vector2 = Vector2.ONE
var _health_emphasis: float = 1.0
var _water_emphasis: float = 1.0
var _health_drop_rate: float = 0.0
var _water_drop_rate: float = 0.0
var _health_rate_prev: float = -1.0
var _water_rate_prev: float = -1.0
var _score_panel: PanelContainer
var _score_label: Label
var _score_sub_label: Label
var _mult_chip: PanelContainer
var _mult_label: Label
var _displayed_score: float = 0.0
var _target_score: int = 0
var _score_distance_m: float = 0.0
var _score_best: int = 0
var _score_punch_tween: Tween
var _mult_pop_tween: Tween
var _last_mult_tier: int = 1
var _event_feed: VBoxContainer
var _best_notified: bool = false
var _danger_vignette: ColorRect
var _danger_intensity: float = 0.0
var _health_ratio: float = 1.0
var _water_ratio: float = 1.0

# Screen vignette starts creeping in when either meter drops below this ratio.
const DANGER_RAMP_START := 0.35
const EVENT_FEED_MAX_VISIBLE := 5
const EVENT_HOLD_SECONDS := 3.8
const EVENT_FADE_SECONDS := 0.7


func _ready() -> void:
	root = _ensure_root()
	_ensure_danger_vignette()
	interaction_prompt = _ensure_interaction_prompt()
	interaction_prompt_label = interaction_prompt.get_node("PromptLabel") as Label
	status_prompt = _ensure_status_prompt()
	status_prompt_label = status_prompt.get_node("StatusLabel") as Label
	health_bar = _ensure_health_bar()
	health_fill = get_node_or_null(health_fill_path) as ProgressBar
	health_trail = get_node_or_null(health_trail_path) as ProgressBar
	health_ember = get_node_or_null(health_ember_path) as ColorRect
	health_flash = get_node_or_null(health_flash_path) as ColorRect
	health_gradient = get_node_or_null(health_gradient_path) as ColorRect
	_start_idle_glow()
	water_bar = _ensure_water_bar()
	water_fill = get_node_or_null(water_fill_path) as ProgressBar
	water_trail = get_node_or_null(water_trail_path) as ProgressBar
	water_shimmer = get_node_or_null(water_shimmer_path) as ColorRect
	water_flash = get_node_or_null(water_flash_path) as ColorRect
	_start_water_idle_glow()
	debug_panel = _ensure_debug_panel()
	if debug_panel != null:
		debug_panel.visible = false
	debug_label = get_node_or_null(debug_label_path) as Label
	debug_speed_slider = get_node_or_null(debug_speed_slider_path) as HSlider
	debug_speed_value_label = get_node_or_null(debug_speed_value_label_path) as Label
	debug_pause_check = get_node_or_null(debug_pause_check_path) as TextureButton
	debug_dontdie_check = get_node_or_null(debug_dontdie_check_path) as TextureButton
	debug_water_drain_slider = get_node_or_null(debug_water_drain_slider_path) as HSlider
	debug_water_drain_value_label = get_node_or_null(debug_water_drain_value_label_path) as Label
	debug_dehydration_slider = get_node_or_null(debug_dehydration_slider_path) as HSlider
	debug_dehydration_value_label = get_node_or_null(debug_dehydration_value_label_path) as Label
	_hide_legacy_prompt_label()
	_ensure_score_display()
	_ensure_event_feed()
	_apply_mobile_hud_layout()

	set_health(100.0, 100.0)
	set_water(100.0, 100.0)
	clear_prompt()
	clear_interaction_prompt()
	bind_sun_controls(sun)
	bind_survival_controls(sun_exposure)
	bind_water_controls(water_supply)
	_on_viewport_resized()


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var viewport_size_i := Vector2i(int(viewport_size.x), int(viewport_size.y))
	if viewport_size_i != _last_viewport_size:
		_last_viewport_size = viewport_size_i
		_on_viewport_resized()

	if _damage_flash_cooldown > 0.0:
		_damage_flash_cooldown = max(0.0, _damage_flash_cooldown - delta)
	if _heal_flash_cooldown > 0.0:
		_heal_flash_cooldown = max(0.0, _heal_flash_cooldown - delta)

	if health_trail != null and health_fill != null:
		if _trail_hold_timer > 0.0:
			_trail_hold_timer = max(0.0, _trail_hold_timer - delta)
		elif health_trail.value > health_fill.value:
			health_trail.value = move_toward(health_trail.value, health_fill.value, _trail_catchup_speed * delta)

	if _water_damage_flash_cooldown > 0.0:
		_water_damage_flash_cooldown = max(0.0, _water_damage_flash_cooldown - delta)
	if _water_heal_flash_cooldown > 0.0:
		_water_heal_flash_cooldown = max(0.0, _water_heal_flash_cooldown - delta)

	if water_trail != null and water_fill != null:
		if _water_trail_hold_timer > 0.0:
			_water_trail_hold_timer = max(0.0, _water_trail_hold_timer - delta)
		elif water_trail.value > water_fill.value:
			water_trail.value = move_toward(water_trail.value, water_fill.value, _trail_catchup_speed * delta)

	_update_bar_emphasis(delta)
	_update_danger_vignette(delta)
	_update_score_roll(delta)


func _input(event: InputEvent) -> void:
	if MobilePlatform.is_mobile():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle_debug_panel()
		get_viewport().set_input_as_handled()


func _apply_mobile_hud_layout() -> void:
	if not MobilePlatform.is_mobile():
		return
	health_bar_width_ratio = 0.34
	health_bar_min_width = 240.0
	health_bar_max_width = 360.0
	water_bar_width_ratio = 0.34
	water_bar_min_width = 240.0
	water_bar_max_width = 360.0
	prompt_bottom_offset = 176.0
	if debug_panel != null:
		debug_panel.visible = false
	if _score_label != null:
		_score_label.add_theme_font_size_override("font_size", 34)
	if _score_sub_label != null:
		_score_sub_label.add_theme_font_size_override("font_size", 16)
	if _mult_label != null:
		_mult_label.add_theme_font_size_override("font_size", 18)
	if _event_feed != null:
		_event_feed.offset_left = 100.0
		_event_feed.offset_top = 16.0
		_event_feed.offset_right = 520.0
		_event_feed.offset_bottom = 280.0
	_on_viewport_resized()


func set_health(current: float, max_health: float) -> void:
	if health_fill == null:
		return

	var previous := _last_health
	var ratio: float = current / max_health if max_health > 0.0 else 0.0

	health_fill.max_value = max_health
	health_fill.value = current

	if health_gradient != null:
		var gradient_material := health_gradient.material as ShaderMaterial
		if gradient_material != null:
			gradient_material.set_shader_parameter("fill_ratio", ratio)

	if health_trail != null:
		health_trail.max_value = max_health
		if current > health_trail.value:
			health_trail.value = current

	if health_ember != null:
		health_ember.anchor_right = clampf(ratio, 0.0, 1.0)

	if current < previous - 0.01:
		_set_ember_mode(false)
		_trail_hold_timer = _trail_hold_duration
		if _damage_flash_cooldown <= 0.0:
			_flash_damage()
			_damage_flash_cooldown = 0.45
	elif current > previous + 0.01:
		_set_ember_mode(true)
		if _heal_flash_cooldown <= 0.0:
			_flash_heal()
			_heal_flash_cooldown = 0.6

	_update_critical_pulse(ratio)
	_health_ratio = ratio
	_last_health = current


func _make_temperature_gradient_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec2 rect_size = vec2(200.0, 34.0);
uniform float corner_radius = 12.0;

// Thermometer ramp fixed to the bar: red at the empty end, icy blue at the full end.
vec3 temp_ramp(float t) {
	vec3 red = vec3(0.85, 0.10, 0.06);
	vec3 orange = vec3(0.96, 0.45, 0.10);
	vec3 amber = vec3(0.99, 0.78, 0.30);
	vec3 ice = vec3(0.55, 0.85, 0.95);
	vec3 blue = vec3(0.20, 0.55, 0.95);
	if (t < 0.25) { return mix(red, orange, t / 0.25); }
	if (t < 0.5) { return mix(orange, amber, (t - 0.25) / 0.25); }
	if (t < 0.75) { return mix(amber, ice, (t - 0.5) / 0.25); }
	return mix(ice, blue, (t - 0.75) / 0.25);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 d = abs(px - rect_size * 0.5) - rect_size * 0.5 + vec2(corner_radius);
	float sdf = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - corner_radius;
	float mask = 1.0 - smoothstep(-1.5, 0.0, sdf);

	// Reveal only the filled portion; the gradient itself stays fixed to the bar.
	float cut = 1.0 - smoothstep(fill_ratio - 0.002, fill_ratio + 0.002, UV.x);

	vec3 col = temp_ramp(UV.x);
	// Once nearly empty the whole remaining sliver locks to pure red.
	col = mix(col, vec3(0.85, 0.08, 0.05), 1.0 - smoothstep(0.15, 0.30, fill_ratio));
	// Bright leading edge so the drain point reads at a glance.
	col += vec3(0.25) * smoothstep(0.025, 0.0, abs(UV.x - fill_ratio));

	COLOR = vec4(col, mask * cut);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fill_ratio", 1.0)
	return material


func _set_ember_mode(healing: bool) -> void:
	if health_ember == null or healing == _is_ember_healing:
		return
	_is_ember_healing = healing
	var material := health_ember.material as ShaderMaterial
	if material == null:
		return
	if healing:
		material.set_shader_parameter("hot_color", Color(0.65, 1.0, 0.75, 1.0))
		material.set_shader_parameter("cool_color", Color(0.1, 0.55, 0.5, 1.0))
		material.set_shader_parameter("speed", 0.7)
	else:
		material.set_shader_parameter("hot_color", Color(1.0, 0.85, 0.35, 1.0))
		material.set_shader_parameter("cool_color", Color(0.85, 0.2, 0.05, 1.0))
		material.set_shader_parameter("speed", 1.4)


func _flash_heal() -> void:
	if health_flash != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		health_flash.color = Color(0.55, 1.0, 0.65, 1.0)
		health_flash.modulate.a = 0.6
		_flash_tween = create_tween()
		_flash_tween.tween_property(health_flash, "modulate:a", 0.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if health_bar != null:
		if _heal_tween != null and _heal_tween.is_valid():
			_heal_tween.kill()
		if _punch_tween != null and _punch_tween.is_valid():
			_punch_tween.kill()
		health_bar.rotation = 0.0
		_heal_tween = create_tween()
		_heal_tween.tween_property(self, "_health_punch_scale", Vector2(1.05, 1.05), 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_heal_tween.tween_property(self, "_health_punch_scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _flash_damage() -> void:
	if health_flash != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		health_flash.color = Color(1.0, 0.4, 0.1, 1.0)
		health_flash.modulate.a = 0.85
		_flash_tween = create_tween()
		_flash_tween.tween_property(health_flash, "modulate:a", 0.0, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if health_bar != null:
		if _punch_tween != null and _punch_tween.is_valid():
			_punch_tween.kill()
		if _heal_tween != null and _heal_tween.is_valid():
			_heal_tween.kill()
		_health_punch_scale = Vector2(1.12, 0.9)
		health_bar.rotation = deg_to_rad(-2.5)
		_punch_tween = create_tween()
		_punch_tween.set_parallel(true)
		_punch_tween.tween_property(self, "_health_punch_scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_punch_tween.tween_property(health_bar, "rotation", 0.0, 0.4) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_critical_pulse(ratio: float) -> void:
	if health_bar == null:
		return
	var should_pulse := ratio <= 0.25 and ratio > 0.0
	if should_pulse == _is_critical:
		return
	_is_critical = should_pulse

	if _critical_tween != null and _critical_tween.is_valid():
		_critical_tween.kill()

	if should_pulse:
		_critical_tween = create_tween()
		_critical_tween.set_loops()
		_critical_tween.tween_property(health_bar, "modulate", Color(1.25, 1.1, 1.0, 1.0), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_critical_tween.tween_property(health_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		health_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _start_idle_glow() -> void:
	if health_bar == null:
		return
	var panel_style := health_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style == null:
		return
	if _idle_glow_tween != null and _idle_glow_tween.is_valid():
		_idle_glow_tween.kill()
	_idle_glow_tween = create_tween()
	_idle_glow_tween.set_loops()
	_idle_glow_tween.tween_method(_apply_glow_alpha.bind(panel_style), 0.3, 0.85, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_glow_tween.tween_method(_apply_glow_alpha.bind(panel_style), 0.85, 0.3, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_glow_alpha(alpha: float, style: StyleBoxFlat) -> void:
	style.border_color.a = alpha


func _make_ember_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

uniform float speed : hint_range(0.0, 5.0) = 1.4;
uniform vec4 hot_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform vec4 cool_color : source_color = vec4(0.85, 0.2, 0.05, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float n1 = noise(uv * vec2(9.0, 3.5) + vec2(-t * 2.2, t * 0.6));
	float n2 = noise(uv * vec2(19.0, 7.0) + vec2(-t * 3.6, t * 1.3));
	float n = clamp(n1 * 0.65 + n2 * 0.45, 0.0, 1.0);
	float flicker = 0.75 + 0.25 * sin(t * 5.0 + uv.x * 12.0);
	vec3 fire = mix(cool_color.rgb, hot_color.rgb, n) * flicker;
	COLOR = vec4(fire, n * 0.55);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func set_water(current: float, max_water: float) -> void:
	if water_fill == null:
		return

	var previous := _last_water
	var ratio: float = current / max_water if max_water > 0.0 else 0.0

	water_fill.max_value = max_water
	water_fill.value = current

	if water_trail != null:
		water_trail.max_value = max_water
		if current > water_trail.value:
			water_trail.value = current

	if water_shimmer != null:
		water_shimmer.anchor_right = clampf(ratio, 0.0, 1.0)

	if current < previous - 0.01:
		_set_water_shimmer_mode(false)
		_water_trail_hold_timer = _trail_hold_duration
		_punch_water()
		if _water_damage_flash_cooldown <= 0.0:
			_flash_water(Color(1.0, 0.55, 0.4, 1.0))
			_water_damage_flash_cooldown = 0.4
	elif current > previous + 0.01:
		_set_water_shimmer_mode(true)
		_pop_water()
		if _water_heal_flash_cooldown <= 0.0:
			_flash_water(Color(0.65, 0.95, 1.0, 1.0))
			_water_heal_flash_cooldown = 0.5

	_update_water_critical_pulse(ratio)
	_water_ratio = ratio
	_last_water = current


func _flash_water(color: Color) -> void:
	if water_flash == null:
		return
	if _water_flash_tween != null and _water_flash_tween.is_valid():
		_water_flash_tween.kill()
	water_flash.color = color
	water_flash.modulate.a = 0.7
	_water_flash_tween = create_tween()
	_water_flash_tween.tween_property(water_flash, "modulate:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _punch_water() -> void:
	if water_bar == null:
		return
	if _water_punch_tween != null and _water_punch_tween.is_valid():
		_water_punch_tween.kill()
	if _water_heal_tween != null and _water_heal_tween.is_valid():
		_water_heal_tween.kill()
	_water_punch_scale = Vector2(1.1, 0.9)
	water_bar.rotation = deg_to_rad(-2.0)
	_water_punch_tween = create_tween()
	_water_punch_tween.set_parallel(true)
	_water_punch_tween.tween_property(self, "_water_punch_scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_water_punch_tween.tween_property(water_bar, "rotation", 0.0, 0.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pop_water() -> void:
	if water_bar == null:
		return
	if _water_heal_tween != null and _water_heal_tween.is_valid():
		_water_heal_tween.kill()
	if _water_punch_tween != null and _water_punch_tween.is_valid():
		_water_punch_tween.kill()
	water_bar.rotation = 0.0
	_water_heal_tween = create_tween()
	_water_heal_tween.tween_property(self, "_water_punch_scale", Vector2(1.05, 1.05), 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_water_heal_tween.tween_property(self, "_water_punch_scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_water_critical_pulse(ratio: float) -> void:
	if water_bar == null:
		return
	var should_pulse := ratio <= 0.25 and ratio > 0.0
	if should_pulse == _water_is_critical:
		return
	_water_is_critical = should_pulse

	if _water_critical_tween != null and _water_critical_tween.is_valid():
		_water_critical_tween.kill()

	if should_pulse:
		_water_critical_tween = create_tween()
		_water_critical_tween.set_loops()
		_water_critical_tween.tween_property(water_bar, "modulate", Color(1.2, 1.15, 1.3, 1.0), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_water_critical_tween.tween_property(water_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		water_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _update_bar_emphasis(delta: float) -> void:
	if delta <= 0.0:
		return
	var rate_smoothing := 1.0 - exp(-6.0 * delta)
	var scale_smoothing := 1.0 - exp(-4.0 * delta)

	if health_bar != null and health_fill != null:
		if _health_rate_prev < 0.0:
			_health_rate_prev = health_fill.value
		var rate: float = maxf(0.0, (_health_rate_prev - health_fill.value) / delta)
		_health_rate_prev = health_fill.value
		_health_drop_rate = lerpf(_health_drop_rate, rate, rate_smoothing)
		var ratio: float = health_fill.value / health_fill.max_value if health_fill.max_value > 0.0 else 0.0
		_health_emphasis = lerpf(_health_emphasis, _emphasis_target(ratio, _health_drop_rate, 1.0), scale_smoothing)
		# Pivot in the top-right corner so the enlarged bar grows into the screen.
		health_bar.pivot_offset = Vector2(health_bar.size.x, 0.0)
		health_bar.scale = _health_punch_scale * _health_emphasis

	if water_bar != null and water_fill != null:
		if _water_rate_prev < 0.0:
			_water_rate_prev = water_fill.value
		var rate: float = maxf(0.0, (_water_rate_prev - water_fill.value) / delta)
		_water_rate_prev = water_fill.value
		_water_drop_rate = lerpf(_water_drop_rate, rate, rate_smoothing)
		var ratio: float = water_fill.value / water_fill.max_value if water_fill.max_value > 0.0 else 0.0
		# Any real drain counts — below 20% even the passive trickle is an emergency.
		_water_emphasis = lerpf(_water_emphasis, _emphasis_target(ratio, _water_drop_rate, 0.5), scale_smoothing)
		water_bar.pivot_offset = Vector2(water_bar.size.x, 0.0)
		water_bar.scale = _water_punch_scale * _water_emphasis

	if health_bar != null and water_bar != null:
		# Keep the water bar stacked below the (possibly enlarged) health bar.
		var top: float = health_bar.offset_bottom + 16.0 + health_bar.size.y * (_health_emphasis - 1.0)
		var height: float = maxf(100.0, water_bar.get_combined_minimum_size().y)
		water_bar.offset_top = top
		water_bar.offset_bottom = top + height


func _emphasis_target(ratio: float, drop_rate: float, drain_threshold: float) -> float:
	# Only alarm when the resource is very low AND actively draining.
	if ratio > 0.2 or drop_rate <= drain_threshold:
		return 1.0
	var low_t: float = clampf(inverse_lerp(0.2, 0.05, ratio), 0.0, 1.0)
	return lerpf(2.0, 2.6, low_t)


func _start_water_idle_glow() -> void:
	if water_bar == null:
		return
	var panel_style := water_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style == null:
		return
	if _water_idle_glow_tween != null and _water_idle_glow_tween.is_valid():
		_water_idle_glow_tween.kill()
	_water_idle_glow_tween = create_tween()
	_water_idle_glow_tween.set_loops()
	_water_idle_glow_tween.tween_method(_apply_glow_alpha.bind(panel_style), 0.3, 0.8, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_water_idle_glow_tween.tween_method(_apply_glow_alpha.bind(panel_style), 0.8, 0.3, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_water_shimmer_mode(gaining: bool) -> void:
	if water_shimmer == null or gaining == _is_water_shimmer_gaining:
		return
	_is_water_shimmer_gaining = gaining
	var material := water_shimmer.material as ShaderMaterial
	if material == null:
		return
	if gaining:
		material.set_shader_parameter("crest_color", Color(0.8, 1.0, 1.0, 1.0))
		material.set_shader_parameter("deep_color", Color(0.2, 0.7, 1.0, 1.0))
		material.set_shader_parameter("speed", 1.8)
	else:
		material.set_shader_parameter("crest_color", Color(0.6, 0.9, 1.0, 1.0))
		material.set_shader_parameter("deep_color", Color(0.1, 0.45, 0.85, 1.0))
		material.set_shader_parameter("speed", 0.9)


func _make_water_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

uniform float speed : hint_range(0.0, 5.0) = 0.9;
uniform vec4 crest_color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.1, 0.45, 0.85, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// stacked travelling sine waves -> caustic shimmer
	float w1 = sin(uv.x * 22.0 - t * 3.0 + uv.y * 4.0);
	float w2 = sin(uv.x * 38.0 + t * 2.1 - uv.y * 6.0);
	float shimmer = 0.5 + 0.5 * (w1 * 0.6 + w2 * 0.4);
	// bright highlight band that sweeps across
	float sweep = smoothstep(0.85, 1.0, sin(uv.x * 3.0 - t * 1.5) * 0.5 + 0.5);
	vec3 col = mix(deep_color.rgb, crest_color.rgb, shimmer);
	float alpha = shimmer * 0.28 + sweep * 0.3;
	COLOR = vec4(col, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func set_debug_text(text: String) -> void:
	if debug_label == null:
		return
	var full_text := text
	if water_supply != null:
		full_text += "\nWater: %.0f / %.0f  (x%.2f dehydration)" % [water_supply.water, water_supply.max_water, water_supply.get_damage_multiplier()]
	debug_label.text = full_text


func bind_sun_controls(sun_cycle: SunCycle) -> void:
	_bound_sun = sun_cycle
	if sun_cycle == null:
		return

	if debug_speed_slider != null:
		debug_speed_slider.min_value = sun_cycle.min_degrees_per_second
		debug_speed_slider.max_value = sun_cycle.max_degrees_per_second
		debug_speed_slider.step = 0.5
		debug_speed_slider.value = sun_cycle.degrees_per_second
		if not debug_speed_slider.value_changed.is_connected(_on_speed_slider_changed):
			debug_speed_slider.value_changed.connect(_on_speed_slider_changed)

	if debug_pause_check != null:
		debug_pause_check.button_pressed = sun_cycle.paused
		if not debug_pause_check.toggled.is_connected(_on_pause_toggled):
			debug_pause_check.toggled.connect(_on_pause_toggled)

	_update_speed_value_label()


func bind_survival_controls(exposure: SunExposure) -> void:
	_bound_exposure = exposure
	if exposure == null or debug_dontdie_check == null:
		return

	debug_dontdie_check.button_pressed = exposure.invincible
	if not debug_dontdie_check.toggled.is_connected(_on_dontdie_toggled):
		debug_dontdie_check.toggled.connect(_on_dontdie_toggled)


func bind_water_controls(supply: WaterSupply) -> void:
	_bound_water_supply = supply
	if supply == null:
		return

	if debug_water_drain_slider != null:
		debug_water_drain_slider.value = supply.drain_per_second
		if not debug_water_drain_slider.value_changed.is_connected(_on_water_drain_slider_changed):
			debug_water_drain_slider.value_changed.connect(_on_water_drain_slider_changed)

	if debug_dehydration_slider != null:
		debug_dehydration_slider.value = supply.dehydration_threshold_ratio
		if not debug_dehydration_slider.value_changed.is_connected(_on_dehydration_slider_changed):
			debug_dehydration_slider.value_changed.connect(_on_dehydration_slider_changed)

	_update_water_drain_value_label()
	_update_dehydration_value_label()


func toggle_debug_panel() -> void:
	if debug_panel == null:
		return
	debug_panel.visible = not debug_panel.visible
	if debug_panel.visible:
		if _bound_sun != null and debug_speed_slider != null:
			debug_speed_slider.value = _bound_sun.degrees_per_second
		if _bound_sun != null and debug_pause_check != null:
			debug_pause_check.button_pressed = _bound_sun.paused
		if _bound_exposure != null and debug_dontdie_check != null:
			debug_dontdie_check.button_pressed = _bound_exposure.invincible
		if _bound_water_supply != null and debug_water_drain_slider != null:
			debug_water_drain_slider.value = _bound_water_supply.drain_per_second
		if _bound_water_supply != null and debug_dehydration_slider != null:
			debug_dehydration_slider.value = _bound_water_supply.dehydration_threshold_ratio


func _on_speed_slider_changed(value: float) -> void:
	if _bound_sun != null:
		_bound_sun.set_speed(value)
	_update_speed_value_label()


func _on_pause_toggled(pressed: bool) -> void:
	if _bound_sun != null:
		_bound_sun.paused = pressed


func _on_dontdie_toggled(pressed: bool) -> void:
	if _bound_exposure != null:
		_bound_exposure.invincible = pressed


func _on_water_drain_slider_changed(value: float) -> void:
	if _bound_water_supply != null:
		_bound_water_supply.drain_per_second = value
	_update_water_drain_value_label()


func _on_dehydration_slider_changed(value: float) -> void:
	if _bound_water_supply != null:
		_bound_water_supply.dehydration_threshold_ratio = value
	_update_dehydration_value_label()


func _update_speed_value_label() -> void:
	if debug_speed_value_label != null and _bound_sun != null:
		debug_speed_value_label.text = "%.1f°/s" % _bound_sun.degrees_per_second


func _update_water_drain_value_label() -> void:
	if debug_water_drain_value_label != null and _bound_water_supply != null:
		debug_water_drain_value_label.text = "%.1f/s" % _bound_water_supply.drain_per_second


func _update_dehydration_value_label() -> void:
	if debug_dehydration_value_label != null and _bound_water_supply != null:
		debug_dehydration_value_label.text = "%.0f%%" % (_bound_water_supply.dehydration_threshold_ratio * 100.0)


func show_prompt(text: String, duration: float = 0.0) -> void:
	if status_prompt == null or status_prompt_label == null:
		return
	_status_prompt_token += 1
	status_prompt_label.text = text
	status_prompt.visible = true
	if duration > 0.0:
		var token := _status_prompt_token
		var timer := get_tree().create_timer(duration)
		timer.timeout.connect(_clear_prompt_if_current.bind(token), CONNECT_ONE_SHOT)


func clear_prompt() -> void:
	_status_prompt_token += 1
	if status_prompt_label != null:
		status_prompt_label.text = ""
	if status_prompt != null:
		status_prompt.visible = false


func show_interaction_prompt(text: String) -> void:
	if interaction_prompt == null or interaction_prompt_label == null:
		return
	interaction_prompt_label.text = text
	interaction_prompt.visible = true


func clear_interaction_prompt() -> void:
	if interaction_prompt_label != null:
		interaction_prompt_label.text = ""
	if interaction_prompt != null:
		interaction_prompt.visible = false


func _clear_prompt_if_current(token: int) -> void:
	if token == _status_prompt_token:
		clear_prompt()


# --- Event feed ---------------------------------------------------------------
# Transient kill-feed-style notifications along the right edge: discrete events
# only (pickups, hits, milestones) — continuous drains stay on the bars.


func push_event(text: String, color: Color) -> void:
	if _event_feed == null:
		return

	# Room for the newcomer: retire the oldest entry early instead of letting
	# the stack grow past the cap. Newest sits on top, so oldest is the last child.
	var entries := _event_feed.get_children()
	if entries.size() >= EVENT_FEED_MAX_VISIBLE:
		var oldest := entries[entries.size() - 1] as Control
		if oldest != null:
			var out := oldest.create_tween()
			out.tween_property(oldest, "modulate:a", 0.0, 0.15)
			out.tween_callback(oldest.queue_free)

	var pill := PanelContainer.new()
	pill.name = "Event"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := _make_style(Color(0.05, 0.035, 0.03, 0.72), 12.0, Color(color.r, color.g, color.b, 0.3), 1)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 7.0
	pill.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _make_display_font())
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	pill.add_child(label)

	pill.modulate.a = 0.0
	_event_feed.add_child(pill)
	_event_feed.move_child(pill, 0)

	# Bound to the pill, so freeing it (cap eviction above) kills the tween too.
	var tween := pill.create_tween()
	tween.tween_property(pill, "modulate:a", 1.0, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(EVENT_HOLD_SECONDS)
	tween.tween_property(pill, "modulate:a", 0.0, EVENT_FADE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(pill.queue_free)


func _ensure_event_feed() -> void:
	if root == null or _event_feed != null:
		return

	_event_feed = VBoxContainer.new()
	_event_feed.name = "EventFeed"
	_event_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-left corner — the one empty HUD region (score top-center, bars
	# top-right). Newest entry on top, stack grows downward.
	_event_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_event_feed.add_theme_constant_override("separation", 8)
	_event_feed.anchor_left = 0.0
	_event_feed.anchor_right = 0.0
	_event_feed.anchor_top = 0.0
	_event_feed.anchor_bottom = 0.0
	_event_feed.offset_left = 24.0
	_event_feed.offset_right = 620.0
	_event_feed.offset_top = 24.0
	_event_feed.offset_bottom = 480.0
	root.add_child(_event_feed)


func _ensure_danger_vignette() -> void:
	var existing := root.get_node_or_null(^"DangerVignette") as ColorRect
	if existing != null:
		_danger_vignette = existing
		return

	var rect := ColorRect.new()
	rect.name = "DangerVignette"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _make_danger_vignette_material()
	rect.visible = false
	root.add_child(rect)
	# Behind every other HUD element so bars and prompts stay readable.
	root.move_child(rect, 0)
	_danger_vignette = rect


func _make_danger_vignette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 danger_color : source_color = vec4(0.78, 0.06, 0.03, 1.0);
uniform vec4 deep_color : source_color = vec4(0.25, 0.0, 0.02, 1.0);

// Two quick thumps then a rest, like a heartbeat.
float heartbeat(float time) {
	float t = fract(time / 1.15);
	float thump1 = smoothstep(0.0, 0.07, t) * smoothstep(0.24, 0.10, t);
	float thump2 = smoothstep(0.28, 0.35, t) * smoothstep(0.52, 0.38, t);
	return thump1 + 0.65 * thump2;
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.18;
	float dist = length(uv) * 2.0;

	float amp = clamp(intensity + pulse * heartbeat(TIME) * 0.30, 0.0, 1.0);

	// As danger rises the red reaches further toward screen center.
	float inner_edge = mix(1.30, 0.28, amp);
	float rim = smoothstep(inner_edge, inner_edge + 0.85, dist);

	vec3 color = mix(danger_color.rgb, deep_color.rgb, smoothstep(0.85, 1.4, dist));

	// Faint slow shimmer so a held-high intensity never looks static.
	float shimmer = 1.0 + 0.06 * sin(TIME * 2.3 + dist * 6.0) * amp;

	float alpha = clamp(rim * amp * shimmer, 0.0, 0.88);
	COLOR = vec4(color, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _update_danger_vignette(delta: float) -> void:
	if _danger_vignette == null:
		return

	var health_danger := 1.0 - clampf(_health_ratio / DANGER_RAMP_START, 0.0, 1.0)
	var water_danger := 1.0 - clampf(_water_ratio / DANGER_RAMP_START, 0.0, 1.0)
	var target := maxf(health_danger, water_danger)

	# Ease toward the target so shade/pickups fade the red out instead of snapping.
	_danger_intensity = lerpf(_danger_intensity, target, minf(1.0, delta * 4.0))
	_danger_vignette.visible = _danger_intensity > 0.005
	if not _danger_vignette.visible:
		return

	var material := _danger_vignette.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("intensity", _danger_intensity * 0.85)
	# Heartbeat only kicks in once things get properly dire.
	material.set_shader_parameter("pulse", smoothstep(0.45, 0.9, _danger_intensity))


func _ensure_root() -> Control:
	var existing := get_node_or_null(^"Root") as Control
	if existing != null:
		existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return existing

	var created := Control.new()
	created.name = "Root"
	created.set_anchors_preset(Control.PRESET_FULL_RECT)
	created.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(created)
	return created


func _ensure_health_bar() -> PanelContainer:
	var existing := get_node_or_null(health_bar_path) as PanelContainer
	if existing != null:
		return existing

	var panel := PanelContainer.new()
	panel.name = "HealthBar"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.035, 0.03, 0.85), 14.0, Color(1.0, 0.5, 0.2, 0.4), 2))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _make_snowflake_icon_texture(48)
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.name = "Label"
	label.text = "TEMPERATURE"
	label.custom_minimum_size = Vector2(150, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _make_display_font())
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.06, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 28)
	row.add_child(label)

	var bar_stack := Control.new()
	bar_stack.name = "BarStack"
	bar_stack.custom_minimum_size = Vector2(200, 34)
	bar_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_stack)

	var trail := ProgressBar.new()
	trail.name = "TrailFill"
	trail.min_value = 0.0
	trail.max_value = 100.0
	trail.value = 100.0
	trail.show_percentage = false
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	trail.add_theme_stylebox_override("background", _make_style(Color(0, 0, 0, 0), 12.0, Color(0, 0, 0, 0), 0))
	trail.add_theme_stylebox_override("fill", _make_style(Color(1.0, 0.92, 0.55, 1.0), 12.0, Color(0, 0, 0, 0), 0))
	bar_stack.add_child(trail)

	var bar := ProgressBar.new()
	bar.name = "Fill"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_stylebox_override("background", _make_style(Color(0.12, 0.06, 0.05, 0.9), 12.0, Color(1.0, 0.45, 0.15, 0.35), 2))
	bar.add_theme_stylebox_override("fill", _make_style(Color(0, 0, 0, 0), 12.0, Color(0, 0, 0, 0), 0))
	bar_stack.add_child(bar)

	var gradient := ColorRect.new()
	gradient.name = "GradientFill"
	gradient.color = Color(1, 1, 1, 1)
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
	gradient.material = _make_temperature_gradient_material()
	gradient.item_rect_changed.connect(func() -> void:
		var mat := gradient.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("rect_size", gradient.size)
	)
	bar_stack.add_child(gradient)

	var ember := ColorRect.new()
	ember.name = "EmberOverlay"
	ember.color = Color(1, 1, 1, 1)
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ember.set_anchors_preset(Control.PRESET_FULL_RECT)
	ember.material = _make_ember_shader_material()
	bar_stack.add_child(ember)

	var flash := ColorRect.new()
	flash.name = "FlashOverlay"
	flash.color = Color(1.0, 0.4, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_stack.add_child(flash)

	return panel


func _ensure_water_bar() -> PanelContainer:
	var existing := get_node_or_null(water_bar_path) as PanelContainer
	if existing != null:
		return existing

	var panel := PanelContainer.new()
	panel.name = "WaterBar"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.05, 0.07, 0.85), 14.0, Color(0.3, 0.75, 1.0, 0.4), 2))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _make_frog_icon_texture(48)
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.name = "Label"
	label.text = "FROGGIE'S HYDRATION"
	label.custom_minimum_size = Vector2(150, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _make_display_font())
	label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.15, 0.25, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var bar_stack := Control.new()
	bar_stack.name = "BarStack"
	bar_stack.custom_minimum_size = Vector2(200, 34)
	bar_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_stack)

	var trail := ProgressBar.new()
	trail.name = "TrailFill"
	trail.min_value = 0.0
	trail.max_value = 100.0
	trail.value = 100.0
	trail.show_percentage = false
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	trail.add_theme_stylebox_override("background", _make_style(Color(0, 0, 0, 0), 12.0, Color(0, 0, 0, 0), 0))
	trail.add_theme_stylebox_override("fill", _make_style(Color(0.75, 0.95, 1.0, 1.0), 12.0, Color(0, 0, 0, 0), 0))
	bar_stack.add_child(trail)

	var bar := ProgressBar.new()
	bar.name = "Fill"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_stylebox_override("background", _make_style(Color(0.04, 0.07, 0.1, 0.9), 12.0, Color(0.3, 0.75, 1.0, 0.35), 2))
	bar.add_theme_stylebox_override("fill", _make_style(Color(0.15, 0.65, 0.95, 1.0), 12.0, Color(0.55, 0.9, 1.0, 0.7), 2))
	bar_stack.add_child(bar)

	var shimmer := ColorRect.new()
	shimmer.name = "ShimmerOverlay"
	shimmer.color = Color(1, 1, 1, 1)
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shimmer.material = _make_water_shader_material()
	bar_stack.add_child(shimmer)

	var flash := ColorRect.new()
	flash.name = "FlashOverlay"
	flash.color = Color(0.6, 0.9, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_stack.add_child(flash)

	return panel


func _ensure_debug_panel() -> PanelContainer:
	var existing := get_node_or_null(debug_panel_path) as PanelContainer
	if existing != null:
		return existing

	var panel := PanelContainer.new()
	panel.name = "DebugPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.02, 0.02, 0.025, 0.9), 8.0, Color(1, 1, 1, 0.16), 1))
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 28.0
	panel.offset_bottom = -28.0
	panel.offset_right = 840.0
	panel.offset_top = -640.0
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var label := Label.new()
	label.name = "DebugLabel"
	label.text = "Game debug panel (F3)"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 0.95))
	label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(label)

	var separator := HSeparator.new()
	separator.name = "Separator"
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(separator)

	var speed_row := HBoxContainer.new()
	speed_row.name = "SpeedRow"
	speed_row.add_theme_constant_override("separation", 18)
	vbox.add_child(speed_row)

	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "Sun speed"
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	speed_label.add_theme_font_size_override("font_size", 26)
	speed_row.add_child(speed_label)

	var slider := HSlider.new()
	slider.name = "SpeedSlider"
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(315.0, 32.0)
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.min_value = 0.0
	slider.max_value = 60.0
	slider.step = 0.5
	slider.value = 6.0
	var grabber_tex := _make_circle_texture(28, Color(1, 1, 1, 1))
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	slider.add_theme_icon_override("grabber_disabled", grabber_tex)
	var groove_style := _make_style(Color(0.12, 0.06, 0.05, 0.85), 6.0, Color(1, 1, 1, 0.1), 1)
	groove_style.content_margin_top = 10.0
	groove_style.content_margin_bottom = 10.0
	slider.add_theme_stylebox_override("slider", groove_style)
	var fill_style := _make_style(Color(0.95, 0.55, 0.2, 1.0), 6.0, Color(0, 0, 0, 0), 0)
	fill_style.content_margin_top = 10.0
	fill_style.content_margin_bottom = 10.0
	slider.add_theme_stylebox_override("grabber_area", fill_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)
	speed_row.add_child(slider)

	var speed_value_label := Label.new()
	speed_value_label.name = "SpeedValueLabel"
	speed_value_label.text = "6.0°/s"
	speed_value_label.custom_minimum_size = Vector2(100.0, 0)
	speed_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_value_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 0.95))
	speed_value_label.add_theme_font_size_override("font_size", 26)
	speed_row.add_child(speed_value_label)

	var toggle_on_tex := _make_toggle_texture(72, 36, true)
	var toggle_off_tex := _make_toggle_texture(72, 36, false)

	var pause_row := HBoxContainer.new()
	pause_row.name = "PauseRow"
	pause_row.add_theme_constant_override("separation", 16)
	vbox.add_child(pause_row)

	var pause_label := Label.new()
	pause_label.text = "Pause sun"
	pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	pause_label.add_theme_font_size_override("font_size", 26)
	pause_row.add_child(pause_label)

	var pause_check := TextureButton.new()
	pause_check.name = "PauseCheck"
	pause_check.toggle_mode = true
	pause_check.ignore_texture_size = true
	pause_check.stretch_mode = TextureButton.STRETCH_SCALE
	pause_check.custom_minimum_size = Vector2(72.0, 36.0)
	pause_check.texture_normal = toggle_off_tex
	pause_check.texture_pressed = toggle_on_tex
	pause_check.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_row.add_child(pause_check)

	var dontdie_row := HBoxContainer.new()
	dontdie_row.name = "DontDieRow"
	dontdie_row.add_theme_constant_override("separation", 16)
	vbox.add_child(dontdie_row)

	var dontdie_label := Label.new()
	dontdie_label.text = "Don't die"
	dontdie_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dontdie_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	dontdie_label.add_theme_font_size_override("font_size", 26)
	dontdie_row.add_child(dontdie_label)

	var dontdie_check := TextureButton.new()
	dontdie_check.name = "DontDieCheck"
	dontdie_check.toggle_mode = true
	dontdie_check.ignore_texture_size = true
	dontdie_check.stretch_mode = TextureButton.STRETCH_SCALE
	dontdie_check.custom_minimum_size = Vector2(72.0, 36.0)
	dontdie_check.texture_normal = toggle_off_tex
	dontdie_check.texture_pressed = toggle_on_tex
	dontdie_check.button_pressed = true
	dontdie_check.mouse_filter = Control.MOUSE_FILTER_STOP
	dontdie_row.add_child(dontdie_check)

	var water_drain_row := _build_debug_slider_row(vbox, "WaterDrainRow", "Water drain/s", "WaterDrainSlider", "WaterDrainValueLabel", 0.0, 20.0, 0.1, 5.0)
	(water_drain_row[1] as Label).text = "2.0/s"

	var dehydration_row := _build_debug_slider_row(vbox, "DehydrationRow", "Dehydration %", "DehydrationSlider", "DehydrationValueLabel", 0.0, 1.0, 0.05, 0.3)
	(dehydration_row[1] as Label).text = "30%"

	return panel


func _build_debug_slider_row(vbox: VBoxContainer, row_name: String, label_text: String, slider_name: String, value_label_name: String, min_value: float, max_value: float, step: float, initial_value: float) -> Array:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 18)
	vbox.add_child(row)

	var row_label := Label.new()
	row_label.text = label_text
	row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	row_label.add_theme_font_size_override("font_size", 26)
	row.add_child(row_label)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(315.0, 32.0)
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial_value
	var grabber_tex := _make_circle_texture(28, Color(1, 1, 1, 1))
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	slider.add_theme_icon_override("grabber_disabled", grabber_tex)
	var groove_style := _make_style(Color(0.05, 0.09, 0.12, 0.85), 6.0, Color(1, 1, 1, 0.1), 1)
	groove_style.content_margin_top = 10.0
	groove_style.content_margin_bottom = 10.0
	slider.add_theme_stylebox_override("slider", groove_style)
	var fill_style := _make_style(Color(0.2, 0.65, 0.95, 1.0), 6.0, Color(0, 0, 0, 0), 0)
	fill_style.content_margin_top = 10.0
	fill_style.content_margin_bottom = 10.0
	slider.add_theme_stylebox_override("grabber_area", fill_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.name = value_label_name
	value_label.custom_minimum_size = Vector2(100.0, 0)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 0.95))
	value_label.add_theme_font_size_override("font_size", 26)
	row.add_child(value_label)

	return [slider, value_label]


func _ensure_interaction_prompt() -> PanelContainer:
	var existing := get_node_or_null(interaction_prompt_path) as PanelContainer
	if existing != null:
		_style_prompt_bubble(existing)
		return existing

	var bubble := PanelContainer.new()
	bubble.name = "InteractionPrompt"
	bubble.custom_minimum_size = Vector2(180.0, 46.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble)
	_style_prompt_bubble(bubble)

	var label := Label.new()
	label.name = "PromptLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_font_size_override("font_size", 20)
	bubble.add_child(label)
	return bubble


func _ensure_status_prompt() -> PanelContainer:
	var existing := get_node_or_null(status_prompt_path) as PanelContainer
	if existing != null:
		_style_prompt_bubble(existing)
		return existing

	var bubble := PanelContainer.new()
	bubble.name = "StatusPrompt"
	bubble.custom_minimum_size = Vector2(360.0, 46.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble)
	_style_prompt_bubble(bubble)

	var label := Label.new()
	label.name = "StatusLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_font_size_override("font_size", 18)
	bubble.add_child(label)
	return bubble


func _style_prompt_bubble(bubble: PanelContainer) -> void:
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.045, 0.05, 0.78), 8.0, Color(1, 1, 1, 0.16), 1))


func _make_style(bg_color: Color, corner_radius: float, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = int(corner_radius)
	style.corner_radius_top_right = int(corner_radius)
	style.corner_radius_bottom_left = int(corner_radius)
	style.corner_radius_bottom_right = int(corner_radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _make_display_font() -> Font:
	# Playful, chunky HUD font. SystemFont walks the list until the OS has one;
	# every listed family is a fun/bold display face, falling back to a heavy default.
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Luckiest Guy", "Chalkboard SE", "Comic Sans MS", "Marker Felt", "Impact", "Arial Black",
	])
	font.font_weight = 700
	return font


func _make_snowflake_icon_texture(size: int) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)
	var arm_len := size * 0.44
	var arm_width := size * 0.055
	var branch_len := size * 0.16
	var branch_width := size * 0.045
	var core := Color(0.85, 0.97, 1.0, 1.0)
	var edge := Color(0.45, 0.8, 1.0, 1.0)
	var segments: Array[Array] = []
	for i in 6:
		var dir := Vector2.RIGHT.rotated(TAU * i / 6.0 + TAU / 12.0)
		var tip := center + dir * arm_len
		segments.append([center, tip, arm_width])
		var branch_base := center + dir * arm_len * 0.55
		for side in [-1.0, 1.0]:
			var branch_dir := dir.rotated(side * TAU / 6.0)
			segments.append([branch_base, branch_base + branch_dir * branch_len, branch_width])
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			for seg in segments:
				var a: Vector2 = seg[0]
				var b: Vector2 = seg[1]
				var w: float = seg[2]
				var ab := b - a
				var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if p.distance_to(a + ab * t) <= w:
					var shade := p.distance_to(center) / arm_len
					image.set_pixel(x, y, core.lerp(edge, clampf(shade, 0.0, 1.0)))
					break
	return ImageTexture.create_from_image(image)


func _make_frog_icon_texture(size: int) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var head_center := Vector2(size * 0.5, size * 0.62)
	var head_radii := Vector2(size * 0.42, size * 0.32)
	var eye_r := size * 0.155
	var eyeball_r := size * 0.095
	var pupil_r := size * 0.045
	var eye_centers := [Vector2(size * 0.29, size * 0.28), Vector2(size * 0.71, size * 0.28)]
	var skin_core := Color(0.5, 0.85, 0.35, 1.0)
	var skin_edge := Color(0.16, 0.55, 0.2, 1.0)
	var mouth_center := Vector2(size * 0.5, size * 0.62)
	var mouth_r := size * 0.24
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var head_d := Vector2((p.x - head_center.x) / head_radii.x, (p.y - head_center.y) / head_radii.y).length()
			var color := Color(0, 0, 0, 0)
			if head_d <= 1.0:
				color = skin_core.lerp(skin_edge, head_d)
			for eye_center: Vector2 in eye_centers:
				var d := p.distance_to(eye_center)
				if d <= eye_r:
					color = skin_core.lerp(skin_edge, d / eye_r)
				if d <= eyeball_r:
					color = Color(0.97, 0.99, 1.0, 1.0)
				if p.distance_to(eye_center + Vector2(0, size * 0.015)) <= pupil_r:
					color = Color(0.05, 0.08, 0.06, 1.0)
			var mouth_d := p.distance_to(mouth_center)
			if p.y > mouth_center.y and absf(mouth_d - mouth_r) <= size * 0.028 and head_d <= 0.9:
				color = skin_edge.darkened(0.35)
			if color.a > 0.0:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _make_circle_texture(diameter: int, color: Color) -> ImageTexture:
	var image := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var radius := diameter / 2.0
	var center := Vector2(radius, radius)
	for y in diameter:
		for x in diameter:
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _make_toggle_texture(width: int, height: int, on: bool) -> ImageTexture:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var track_color := Color(0.95, 0.55, 0.2, 1.0) if on else Color(0.3, 0.3, 0.34, 1.0)
	var radius := height / 2.0
	for y in height:
		for x in width:
			var px := x + 0.5
			var py := y + 0.5
			var cx := clampf(px, radius, width - radius)
			if Vector2(px, py).distance_to(Vector2(cx, radius)) <= radius:
				image.set_pixel(x, y, track_color)

	var knob_radius := radius - 4.0
	var knob_center_x := width - radius if on else radius
	for y in height:
		for x in width:
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(knob_center_x, radius)) <= knob_radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1))

	return ImageTexture.create_from_image(image)


func _on_viewport_resized() -> void:
	_resize_health_bar()
	_resize_water_bar()
	_position_prompt_bubble(interaction_prompt, prompt_bottom_offset, 230.0)
	_position_prompt_bubble(status_prompt, prompt_bottom_offset + 58.0, 460.0)


func _resize_health_bar() -> void:
	if health_bar == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var smallest_side: float = min(viewport_size.x, viewport_size.y)
	var safe_margin: float = clampf(smallest_side * 0.025, 12.0, 24.0)
	var target_width: float = clampf(
		viewport_size.x * health_bar_width_ratio,
		health_bar_min_width,
		health_bar_max_width
	)

	var health_height: float = max(56.0, health_bar.get_combined_minimum_size().y)
	health_bar.anchor_left = 1.0
	health_bar.anchor_right = 1.0
	health_bar.anchor_top = 0.0
	health_bar.anchor_bottom = 0.0
	health_bar.offset_left = -safe_margin - target_width
	health_bar.offset_right = -safe_margin
	health_bar.offset_top = safe_margin
	health_bar.offset_bottom = safe_margin + health_height

	if water_bar != null:
		var water_width: float = clampf(
			viewport_size.x * water_bar_width_ratio,
			water_bar_min_width,
			water_bar_max_width
		)
		var water_top: float = safe_margin + health_height + 10.0
		water_bar.anchor_left = 1.0
		water_bar.anchor_right = 1.0
		water_bar.anchor_top = 0.0
		water_bar.anchor_bottom = 0.0
		water_bar.offset_left = -safe_margin - water_width
		water_bar.offset_right = -safe_margin
		water_bar.offset_top = water_top
		water_bar.offset_bottom = water_top + max(56.0, water_bar.get_combined_minimum_size().y)


func _resize_water_bar() -> void:
	if water_bar == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var smallest_side: float = min(viewport_size.x, viewport_size.y)
	var safe_margin: float = clampf(smallest_side * 0.025, 12.0, 24.0)
	var target_width: float = clampf(
		viewport_size.x * water_bar_width_ratio,
		water_bar_min_width,
		water_bar_max_width
	)

	# Stacks below the health bar in the same corner instead of overlapping it.
	var top_offset := safe_margin
	if health_bar != null:
		top_offset = health_bar.offset_bottom + 16.0

	water_bar.anchor_left = 1.0
	water_bar.anchor_right = 1.0
	water_bar.anchor_top = 0.0
	water_bar.anchor_bottom = 0.0
	water_bar.offset_left = -safe_margin - target_width
	water_bar.offset_right = -safe_margin
	water_bar.offset_top = top_offset
	water_bar.offset_bottom = top_offset + max(100.0, water_bar.get_combined_minimum_size().y)


func _position_prompt_bubble(bubble: Control, bottom_offset: float, width: float) -> void:
	if bubble == null:
		return
	var height: float = max(46.0, bubble.custom_minimum_size.y)
	bubble.anchor_left = 0.5
	bubble.anchor_right = 0.5
	bubble.anchor_top = 1.0
	bubble.anchor_bottom = 1.0
	bubble.offset_left = -width * 0.5
	bubble.offset_right = width * 0.5
	bubble.offset_top = -bottom_offset - height
	bubble.offset_bottom = -bottom_offset


func _hide_legacy_prompt_label() -> void:
	var legacy := get_node_or_null(^"Root/PromptLabel") as Label
	if legacy != null:
		legacy.visible = false


# --- Run score display ------------------------------------------------------


func set_score(current: int, distance_m: float, multiplier: float, best: int) -> void:
	if _score_label == null:
		return
	if current < _target_score:
		# Run reset: snap down instead of rolling backwards behind the reveal.
		_displayed_score = float(current)
		_score_label.text = _format_score(current)
		_best_notified = false
	if best > 0 and current > best and not _best_notified:
		_best_notified = true
		push_event("New best score!", Color(1.0, 0.87, 0.45))
	_target_score = current
	_score_distance_m = distance_m
	_score_best = best
	_update_score_sub_label()
	_update_mult_chip(multiplier)


func _update_score_roll(delta: float) -> void:
	if _score_label == null or _displayed_score >= float(_target_score):
		return
	var previous := int(_displayed_score)
	var t := 1.0 - exp(-9.0 * delta)
	_displayed_score = lerpf(_displayed_score, float(_target_score), t)
	if float(_target_score) - _displayed_score < 1.0:
		_displayed_score = float(_target_score)
	_score_label.text = _format_score(int(_displayed_score))
	if int(_displayed_score) / 1000 > previous / 1000:
		_punch_score()


func _update_score_sub_label() -> void:
	if _score_sub_label == null:
		return
	var text := "%d m" % int(_score_distance_m)
	if _score_best > 0:
		text += "   •   BEST %s" % _format_score(_score_best)
	_score_sub_label.text = text


func _update_mult_chip(multiplier: float) -> void:
	if _mult_chip == null:
		return
	if multiplier < 1.05:
		_mult_chip.visible = false
		_last_mult_tier = 1
		return

	_mult_chip.visible = true
	_mult_label.text = "×%.1f" % multiplier

	# White → amber → hot red as the streak climbs toward max.
	var heat := clampf((multiplier - 1.0) / 4.0, 0.0, 1.0)
	var color: Color
	if heat < 0.5:
		color = Color(1, 1, 1).lerp(Color(1.0, 0.78, 0.25), heat * 2.0)
	else:
		color = Color(1.0, 0.78, 0.25).lerp(Color(1.0, 0.35, 0.15), (heat - 0.5) * 2.0)
	_mult_label.add_theme_color_override("font_color", color)
	var style := _mult_chip.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = Color(color.r, color.g, color.b, 0.55)

	var tier := int(multiplier)
	if tier > _last_mult_tier:
		_pop_mult_chip()
		push_event("Heat streak ×%d!" % tier, color)
	_last_mult_tier = tier


func _punch_score() -> void:
	if _score_panel == null:
		return
	if _score_punch_tween != null:
		_score_punch_tween.kill()
	_score_panel.pivot_offset = _score_panel.size * 0.5
	_score_panel.scale = Vector2.ONE
	_score_punch_tween = create_tween()
	_score_punch_tween.tween_property(_score_panel, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_score_punch_tween.tween_property(_score_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_mult_chip() -> void:
	if _mult_chip == null:
		return
	if _mult_pop_tween != null:
		_mult_pop_tween.kill()
	_mult_chip.pivot_offset = _mult_chip.size * 0.5
	_mult_chip.scale = Vector2.ONE
	_mult_pop_tween = create_tween()
	_mult_pop_tween.tween_property(_mult_chip, "scale", Vector2(1.35, 1.35), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_mult_pop_tween.tween_property(_mult_chip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _ensure_score_display() -> void:
	if root == null or _score_panel != null:
		return

	# Full-width top strip whose HBox centering keeps the auto-sizing score box
	# horizontally centered as digits grow.
	var strip := HBoxContainer.new()
	strip.name = "ScoreStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 12.0
	root.add_child(strip)

	_score_panel = PanelContainer.new()
	_score_panel.name = "ScoreBox"
	_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_panel.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.035, 0.03, 0.7), 16.0, Color(1.0, 0.75, 0.3, 0.35), 2))
	strip.add_child(_score_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 4)
	_score_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = "0"
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.add_theme_font_override("font", _make_display_font())
	_score_label.add_theme_font_size_override("font_size", 52)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.45, 1.0))
	_score_label.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.02, 0.9))
	_score_label.add_theme_constant_override("outline_size", 6)
	row.add_child(_score_label)

	_mult_chip = PanelContainer.new()
	_mult_chip.name = "MultChip"
	_mult_chip.visible = false
	_mult_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mult_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mult_chip.add_theme_stylebox_override("panel", _make_style(Color(0.1, 0.05, 0.02, 0.85), 10.0, Color(1, 1, 1, 0.3), 2))
	row.add_child(_mult_chip)

	_mult_label = Label.new()
	_mult_label.name = "MultLabel"
	_mult_label.text = "×1.0"
	_mult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mult_label.add_theme_font_override("font", _make_display_font())
	_mult_label.add_theme_font_size_override("font_size", 24)
	_mult_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0, 0.9))
	_mult_label.add_theme_constant_override("outline_size", 4)
	_mult_chip.add_child(_mult_label)

	_score_sub_label = Label.new()
	_score_sub_label.name = "SubLabel"
	_score_sub_label.text = "0 m"
	_score_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_sub_label.add_theme_font_override("font", _make_display_font())
	_score_sub_label.add_theme_font_size_override("font_size", 20)
	_score_sub_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.85))
	_score_sub_label.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02, 0.8))
	_score_sub_label.add_theme_constant_override("outline_size", 3)
	column.add_child(_score_sub_label)


func _format_score(value: int) -> String:
	var digits := str(value)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
