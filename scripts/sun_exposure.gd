extends Node
class_name SunExposure

## Drains health while the character stands in direct sunlight and heals
## while fully shaded. Shade is measured by sampling rays from the
## character toward the sun (a DirectionalLight3D) and checking whether
## world geometry blocks them.

signal health_changed(current: float, max_health: float)
## cause is &"heat" (cooling bar emptied) or &"dehydration" (froggie ran dry).
signal died(cause: StringName)

@export var character_path: NodePath = ^".."
@export var sun_path: NodePath = ^"../../Sun"
@export var hud_path: NodePath = ^"../../HUD"
@export var water_supply_path: NodePath = ^"../WaterSupply"

@export var max_health: float = 100.0
@export var sun_damage_per_second: float = 10.0
@export var shade_heal_per_second: float = 6.0
@export var full_shade_ratio_threshold: float = 0.99
@export var head_height: float = 1.7
@export var sample_radius: float = 0.25
@export var ray_length: float = 250.0
@export var check_interval: float = 0.15
@export var invincible: bool = false:
	set(value):
		var turning_off := invincible and not value
		invincible = value
		if turning_off and health <= 0.0:
			_die(&"heat")

@onready var character: Node3D = get_node_or_null(character_path) as Node3D
@onready var sun: SunCycle = get_node_or_null(sun_path) as SunCycle
@onready var hud: AdventureHUD = get_node_or_null(hud_path) as AdventureHUD
@onready var water_supply: WaterSupply = get_node_or_null(water_supply_path) as WaterSupply

var health: float = max_health
var shade_ratio: float = 1.0
var last_delta_health_per_second: float = 0.0

var _timer: float = 0.0
var _respawn_transform: Transform3D
# Starts true (shade_ratio inits to 1.0) so spawning in shade logs nothing.
var _was_full_shade: bool = true
var _shade_event_cooldown: float = 0.0
var _sample_offsets: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
]


func _ready() -> void:
	if character != null:
		_respawn_transform = character.global_transform
	if water_supply != null:
		water_supply.depleted.connect(_on_water_depleted)
	health = max_health
	_update_shade_ratio()
	_notify_health()


func _physics_process(delta: float) -> void:
	if character == null or sun == null:
		return

	_timer += delta
	if _timer >= check_interval:
		_timer = 0.0
		_update_shade_ratio()

	if _shade_event_cooldown > 0.0:
		_shade_event_cooldown -= delta
	_notify_shade_transition()

	_apply_health_delta(delta)
	_update_debug_display()


# Feed line when stepping into full shade while hurt. Cooldown keeps dancing
# on a shade boundary from spamming; leaving shade stays silent — the health
# bar's damage feedback already covers it.
func _notify_shade_transition() -> void:
	var full_shade := shade_ratio >= full_shade_ratio_threshold
	if full_shade == _was_full_shade:
		return
	_was_full_shade = full_shade
	if full_shade and health < max_health * 0.95 and _shade_event_cooldown <= 0.0 and hud != null:
		hud.push_event("Shade — recovering", Color(0.62, 0.95, 0.68))
		AmbientAudio.play_shade_relief()
		_shade_event_cooldown = 8.0


func _update_shade_ratio() -> void:
	var space_state := character.get_world_3d().direct_space_state
	var to_sun := sun.global_transform.basis.z.normalized()
	var origin := character.global_position + Vector3.UP * head_height

	var shaded_count := 0
	for offset in _sample_offsets:
		var from := origin + offset * sample_radius
		var to := from + to_sun * ray_length
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = AdventureLayers.WORLD
		query.exclude = [character.get_rid()]
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			shaded_count += 1

	shade_ratio = float(shaded_count) / float(_sample_offsets.size())

	# An active force-field globe counts as full shade for anyone inside it.
	if shade_ratio < 1.0:
		for node in get_tree().get_nodes_in_group(ForceField.GROUP):
			var field := node as ForceField
			if field != null and field.is_active() and field.contains(character.global_position):
				shade_ratio = 1.0
				break


func _apply_health_delta(delta: float) -> void:
	var delta_health: float
	if shade_ratio >= full_shade_ratio_threshold:
		delta_health = shade_heal_per_second * delta
	else:
		delta_health = -sun_damage_per_second * (1.0 - shade_ratio) * delta
		delta_health *= water_supply.get_damage_multiplier() if water_supply != null else 1.0

	last_delta_health_per_second = 0.0 if delta <= 0.0 else delta_health / delta

	if delta_health == 0.0 or (health >= max_health and delta_health > 0.0):
		return

	var was_alive := health > 0.0
	health = clampf(health + delta_health, 0.0, max_health)
	_notify_health()
	if was_alive and health <= 0.0 and not invincible:
		_die(&"heat")


func _update_debug_display() -> void:
	if hud == null or character == null:
		return
	var pos := character.global_position
	var state := "HEALING" if shade_ratio >= full_shade_ratio_threshold else "TAKING DAMAGE" if last_delta_health_per_second < 0.0 else "IDLE"
	hud.set_debug_text(
		"Game debug panel (F3)\n" +
		"State: %s\n" % state +
		"Temperature: %.1f / %.1f\n" % [health, max_health] +
		"Rate: %+.1f hp/s\n" % last_delta_health_per_second +
		"Shade ratio: %.0f%% (%d/%d rays blocked)\n" % [shade_ratio * 100.0, int(round(shade_ratio * _sample_offsets.size())), _sample_offsets.size()] +
		"Pos: (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z]
	)


func _notify_health() -> void:
	health_changed.emit(health, max_health)
	if hud != null:
		hud.set_health(health, max_health)


## The froggie running completely dry is fatal even in the shade.
func _on_water_depleted() -> void:
	if invincible or health <= 0.0:
		return
	health = 0.0
	_notify_health()
	_die(&"dehydration")


## One-off damage from hazards outside the sun-drain loop (e.g. heat waves).
## Routes through the same clamp/notify/death path as continuous drain.
func apply_flat_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	_notify_health()
	if health <= 0.0 and not invincible:
		_die(&"heatwave")


func _die(cause: StringName) -> void:
	# RunScore listens to died() and ends the run; MainMenu then reopens
	# (paused) with the results and a retry button — no extra prompt here.
	died.emit(cause)
	reset_run()


## Respawn at home with full health and water. Used on death and when the
## main menu starts a fresh run.
func reset_run() -> void:
	if character != null:
		character.global_transform = _respawn_transform
		if character is CharacterBody3D:
			(character as CharacterBody3D).velocity = Vector3.ZERO
	health = max_health
	if water_supply != null:
		water_supply.reset()
	_notify_health()
