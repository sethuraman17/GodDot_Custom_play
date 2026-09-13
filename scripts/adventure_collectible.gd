extends Area3D
class_name WaterDrop

signal collected(amount: float)

@export var water_amount: float = 27.0


func _ready() -> void:
	collision_layer = AdventureLayers.INTERACTABLE
	collision_mask = AdventureLayers.PLAYER
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		collected.emit(water_amount)
		queue_free()
