extends Node
class_name WaterSupply

signal water_changed(current: float, max_water: float)
signal depleted()

@export var character_path: NodePath = ^".."
@export var hud_path: NodePath = ^"../../HUD"
@export var max_water: float = 100.0
@export var drain_per_second: float = 5.0
@export var dehydration_threshold_ratio: float = 0.3
@export var max_damage_multiplier: float = 2.5

@onready var hud: AdventureHUD = get_node_or_null(hud_path) as AdventureHUD
@onready var _character: Node3D = get_node_or_null(character_path) as Node3D

var water: float = max_water


func _ready() -> void:
	water = max_water
	_notify_water()


func _physics_process(delta: float) -> void:
	if _is_inside_force_field():
		return
	_set_water(water - drain_per_second * delta)


## Water doesn't evaporate inside an active force-field globe — levels hold
## steady (no drain, no refill) while sheltered.
func _is_inside_force_field() -> bool:
	if _character == null:
		return false
	for node in get_tree().get_nodes_in_group(ForceField.GROUP):
		var field := node as ForceField
		if field != null and field.is_active() and field.contains(_character.global_position):
			return true
	return false


func add_water(amount: float) -> void:
	_set_water(water + amount)


func lose_water(amount: float) -> void:
	_set_water(water - amount)


func reset() -> void:
	_set_water(max_water)


func _set_water(value: float) -> void:
	var previous := water
	water = clampf(value, 0.0, max_water)
	_notify_water()
	if water <= 0.0 and previous > 0.0:
		depleted.emit()


func get_water_ratio() -> float:
	return water / max_water


func get_damage_multiplier() -> float:
	var ratio := get_water_ratio()
	if ratio >= dehydration_threshold_ratio:
		return 1.0
	# Linear from 1.0 at the threshold up to max_damage_multiplier at ratio 0.
	var t := 1.0 - ratio / dehydration_threshold_ratio
	return clampf(lerpf(1.0, max_damage_multiplier, t), 1.0, max_damage_multiplier)


func _notify_water() -> void:
	water_changed.emit(water, max_water)
	if hud != null:
		hud.set_water(water, max_water)
