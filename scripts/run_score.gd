extends Node
class_name RunScore

## Distance-first run score. Points come from every new meter of peak distance
## away from home, multiplied by a "heat streak" that builds while the player
## keeps moving and decays when they stop. A small survival trickle keeps the
## counter alive while sheltering, and water pickups pay a bonus scaled by the
## current streak. On death the final score is compared against the persisted
## best and the HUD shows the results overlay.

signal score_changed(score: int, distance_m: float, multiplier: float, best_score: int)
signal run_ended(final_score: int, distance_m: float, best_score: int, is_new_best: bool, cause: StringName)

@export var character_path: NodePath = ^".."
@export var hud_path: NodePath = ^"../../HUD"
@export var sun_exposure_path: NodePath = ^"../SunExposure"

@export var points_per_meter: float = 10.0
@export var survival_points_per_second: float = 1.0
@export var pickup_bonus: float = 25.0
@export var max_multiplier: float = 5.0
## ~25 s of continuous movement to reach max_multiplier from x1.
@export var multiplier_build_per_second: float = 0.16
@export var multiplier_decay_per_second: float = 0.9
@export var moving_speed_threshold: float = 1.5
@export var decay_grace_seconds: float = 0.8

const SAVE_PATH := "user://heatwave_score.cfg"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

@onready var character: Node3D = get_node_or_null(character_path) as Node3D
@onready var hud: AdventureHUD = get_node_or_null(hud_path) as AdventureHUD
@onready var sun_exposure: SunExposure = get_node_or_null(sun_exposure_path) as SunExposure

var score: float = 0.0
var multiplier: float = 1.0
var best_score: int = 0
var peak_distance: float = 0.0
var difficulty: String = "normal"

var _bests: Dictionary = {"easy": 0, "normal": 0, "hard": 0}

var _home_xz := Vector2.ZERO
var _grace_timer: float = 0.0


func _ready() -> void:
	_load_best()
	if character != null:
		_home_xz = Vector2(character.global_position.x, character.global_position.z)
	if sun_exposure != null:
		sun_exposure.died.connect(_on_died)
	_notify()


func _physics_process(delta: float) -> void:
	if character == null:
		return

	_update_multiplier(delta)

	var pos := character.global_position
	var distance := Vector2(pos.x, pos.z).distance_to(_home_xz)
	if distance > peak_distance:
		score += (distance - peak_distance) * points_per_meter * multiplier
		peak_distance = distance

	score += survival_points_per_second * delta
	_notify()


func _update_multiplier(delta: float) -> void:
	var speed := 0.0
	if character is CharacterBody3D:
		var v := (character as CharacterBody3D).velocity
		speed = Vector2(v.x, v.z).length()

	if speed >= moving_speed_threshold:
		_grace_timer = decay_grace_seconds
		multiplier = minf(multiplier + multiplier_build_per_second * delta, max_multiplier)
	elif _grace_timer > 0.0:
		_grace_timer -= delta
	else:
		multiplier = maxf(multiplier - multiplier_decay_per_second * delta, 1.0)


func add_pickup_bonus() -> void:
	score += pickup_bonus * multiplier
	_notify()


## Getting chomped by a worm kills the heat streak.
func reset_multiplier() -> void:
	multiplier = 1.0
	_grace_timer = 0.0
	_notify()


func set_difficulty(value: String) -> void:
	if not DIFFICULTIES.has(value):
		push_warning("Unknown difficulty '%s', keeping '%s'" % [value, difficulty])
		return
	difficulty = value
	best_score = int(_bests[difficulty])
	_save()
	_notify()


func get_best(for_difficulty: String) -> int:
	return int(_bests.get(for_difficulty, 0))


## Fresh run from the menu: zero the score without ending a run.
func reset_run() -> void:
	score = 0.0
	multiplier = 1.0
	peak_distance = 0.0
	_grace_timer = 0.0
	_notify()


func _on_died(cause: StringName) -> void:
	var final_score := int(score)
	var is_new_best := final_score > best_score
	if is_new_best:
		best_score = final_score
		_bests[difficulty] = final_score
		_save()

	run_ended.emit(final_score, peak_distance, best_score, is_new_best, cause)
	reset_run()


func _notify() -> void:
	score_changed.emit(int(score), peak_distance, multiplier, best_score)
	if hud != null:
		hud.set_score(int(score), peak_distance, multiplier, best_score)


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# Pre-difficulty saves stored a single best; count it as a Normal run.
	var legacy_best := int(config.get_value("score", "best", 0))
	for diff in DIFFICULTIES:
		var fallback := legacy_best if diff == "normal" else 0
		_bests[diff] = int(config.get_value("score", "best_%s" % diff, fallback))
	difficulty = str(config.get_value("settings", "difficulty", "normal"))
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	best_score = int(_bests[difficulty])


func _save() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	for diff in DIFFICULTIES:
		config.set_value("score", "best_%s" % diff, int(_bests[diff]))
	config.set_value("settings", "difficulty", difficulty)
	config.save(SAVE_PATH)
