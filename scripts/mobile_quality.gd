extends Node
class_name MobileQuality

## Applies cheaper world settings on mobile before sibling gameplay nodes
## finish _ready. Desktop quality is left unchanged.


func _ready() -> void:
	if not MobilePlatform.is_mobile():
		return

	Engine.max_fps = 60

	var world := get_parent()
	if world == null:
		return

	var terrain := world.get_node_or_null("Level/TerrainRoot")
	if terrain != null:
		terrain.set("subdivisions", 24)

	var city := world.get_node_or_null("Level/CityBuildings")
	if city != null:
		city.set("spawn_radius", 90.0)
		city.set("despawn_radius", 110.0)
		city.set("max_live_buildings", 40)

	var worms := world.get_node_or_null("Level/Worms")
	if worms != null:
		worms.set("spawn_radius", 36.0)
		worms.set("cell_size", 28.0)

	var light := world.get_node_or_null("Player/PlayerReadabilityLight") as Light3D
	if light != null:
		light.visible = false
		light.light_energy = 0.0

	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.shadow_blur = 1.0
		sun.directional_shadow_max_distance = 72.0
