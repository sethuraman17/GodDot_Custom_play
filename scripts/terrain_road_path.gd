extends Node3D
class_name TerrainRoadPath

@export var enabled: bool = true
@export var road_width: float = 4.0
@export var shoulder_width: float = 3.0
@export var surface_drop: float = 0.06
@export var show_preview: bool = false
@export var preview_samples_per_meter: float = 0.35
@export var preview_color: Color = Color(0.34, 0.28, 0.2, 0.82)

# Renders an opaque asphalt ribbon (no collision) that drapes over the carved
# terrain, so the road reads as a real surface. The terrain underneath keeps its
# own collision, so the player walks on road and sand alike.
@export var show_surface: bool = false
@export var surface_lift: float = 0.03
# Sun-baked warm gray — stays in the desert palette next to the brown sand.
@export var asphalt_color: Color = Color(0.22, 0.20, 0.17, 1.0)
@export var show_center_line: bool = true
@export var center_line_width: float = 0.22
@export var center_line_lift: float = 0.05
@export var center_line_color: Color = Color(0.68, 0.60, 0.40, 1.0)
# Sand drifted over the road edges: outer strips gradient from asphalt into the
# terrain sand color, so the ribbon melts into the dunes instead of ending in a
# hard dark seam. sand_color must match _make_default_material() in
# adventure_terrain_generator.gd.
@export var sand_blend: bool = true
@export var sand_blend_width: float = 1.1
@export var sand_color: Color = Color(0.45, 0.36, 0.28, 1.0)


func _ready() -> void:
	call_deferred("_rebuild_preview")


func get_terrain_feature_data() -> Dictionary:
	return {
		"type": "road_path",
		"enabled": enabled,
		"points": _get_path_points_2d(),
		"road_width": road_width,
		"shoulder_width": shoulder_width,
		"surface_drop": surface_drop,
	}


func _get_path_points_2d() -> PackedVector2Array:
	var points := PackedVector2Array()
	for child in get_children():
		if child is Marker3D:
			var marker := child as Marker3D
			points.append(Vector2(marker.global_position.x, marker.global_position.z))
	return points


func _rebuild_preview() -> void:
	for child in get_children():
		if child.is_in_group(&"terrain_feature_preview"):
			child.queue_free()

	if not (show_preview or show_surface):
		return

	var path_points := _get_path_points_3d()
	if path_points.size() < 2:
		return

	var sampled := _sample_path(path_points)
	if sampled.size() < 2:
		return

	if show_surface:
		# Opaque asphalt ribbon. No collision — the carved terrain below carries it.
		var surface: MeshInstance3D
		if sand_blend:
			surface = _build_blended_ribbon(sampled, road_width * 0.5, sand_blend_width, surface_lift)
		else:
			surface = _build_ribbon(sampled, road_width * 0.5, surface_lift)
		if surface != null:
			surface.name = "RoadSurface"
			if sand_blend:
				var blend_mat := _make_surface_material(Color.WHITE)
				blend_mat.vertex_color_use_as_albedo = true
				# Vertex colors are linear by default; our palette values are sRGB.
				# Without this the asphalt washes out to pale beige.
				blend_mat.vertex_color_is_srgb = true
				surface.material_override = blend_mat
			else:
				surface.material_override = _make_surface_material(asphalt_color)
			add_child(surface)
		if show_center_line:
			var line := _build_ribbon(sampled, center_line_width * 0.5, center_line_lift)
			if line != null:
				line.name = "RoadCenterLine"
				line.material_override = _make_surface_material(center_line_color)
				add_child(line)

	if show_preview:
		var preview := _build_ribbon(sampled, road_width * 0.5, 0.0)
		if preview != null:
			preview.name = "RoadPreview"
			preview.material_override = _make_preview_material(preview_color)
			add_child(preview)


# Builds a MeshInstance3D ribbon of the given half-width centered on the sampled
# path, lifted `lift` metres above the terrain samples. Tagged as a preview so
# the grid clears it on rebuild. No collision is ever added.
func _build_ribbon(sampled: Array, half_width: float, lift: float) -> MeshInstance3D:
	if sampled.size() < 2:
		return null

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var lift_vec := Vector3(0.0, lift, 0.0)

	for index in range(sampled.size()):
		var previous: Vector3 = sampled[maxi(index - 1, 0)]
		var current: Vector3 = sampled[index]
		var next: Vector3 = sampled[mini(index + 1, sampled.size() - 1)]
		var forward := next - previous
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var right := Vector3(forward.z, 0.0, -forward.x)
		vertices.append(to_local(current - right * half_width + lift_vec))
		vertices.append(to_local(current + right * half_width + lift_vec))

	for index in range(sampled.size() - 1):
		var i := index * 2
		indices.append(i)
		indices.append(i + 1)
		indices.append(i + 2)
		indices.append(i + 1)
		indices.append(i + 3)
		indices.append(i + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var ribbon := MeshInstance3D.new()
	ribbon.mesh = mesh
	ribbon.add_to_group(&"terrain_feature_preview")
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ribbon


# Like _build_ribbon, but with sand-drift strips outside the asphalt: four vertex
# columns per cross-section (sand | asphalt | asphalt | sand). Vertex colors carry
# the palette (material albedo stays white with vertex_color_use_as_albedo), so
# the outer edge lands exactly on the terrain sand color and the seam disappears.
# Outer columns sit lower so the drift hugs the ground.
func _build_blended_ribbon(sampled: Array, half_width: float, drift_width: float, lift: float) -> MeshInstance3D:
	if sampled.size() < 2:
		return null

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var lift_vec := Vector3(0.0, lift, 0.0)
	var edge_lift_vec := Vector3(0.0, maxf(lift - 0.025, 0.005), 0.0)
	var outer_half := half_width + maxf(drift_width, 0.05)

	for index in range(sampled.size()):
		var previous: Vector3 = sampled[maxi(index - 1, 0)]
		var current: Vector3 = sampled[index]
		var next: Vector3 = sampled[mini(index + 1, sampled.size() - 1)]
		var forward := next - previous
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var right := Vector3(forward.z, 0.0, -forward.x)
		vertices.append(to_local(current - right * outer_half + edge_lift_vec))
		vertices.append(to_local(current - right * half_width + lift_vec))
		vertices.append(to_local(current + right * half_width + lift_vec))
		vertices.append(to_local(current + right * outer_half + edge_lift_vec))
		colors.append(sand_color)
		colors.append(asphalt_color)
		colors.append(asphalt_color)
		colors.append(sand_color)

	for index in range(sampled.size() - 1):
		var i := index * 4
		for column in range(3):
			var a := i + column
			indices.append(a)
			indices.append(a + 1)
			indices.append(a + 4)
			indices.append(a + 1)
			indices.append(a + 5)
			indices.append(a + 4)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var ribbon := MeshInstance3D.new()
	ribbon.mesh = mesh
	ribbon.add_to_group(&"terrain_feature_preview")
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ribbon


func _get_path_points_3d() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_children():
		if child is Marker3D:
			points.append((child as Marker3D).global_position)
	return points


func _sample_path(points: Array[Vector3]) -> Array[Vector3]:
	var sampled: Array[Vector3] = []
	var sampler := _find_terrain_sampler()
	var spacing := 1.0 / maxf(preview_samples_per_meter, 0.05)

	for index in range(points.size() - 1):
		var start := points[index]
		var end := points[index + 1]
		var distance := start.distance_to(end)
		var steps := maxi(1, ceili(distance / spacing))
		for step_index in range(steps + 1):
			if index > 0 and step_index == 0:
				continue
			var t := float(step_index) / float(steps)
			var point := start.lerp(end, t)
			if sampler != null and sampler.has_method("get_height_at_global"):
				point.y = float(sampler.call("get_height_at_global", point.x, point.z)) + 0.045
			else:
				point.y += 0.045
			sampled.append(point)

	return sampled


func _find_terrain_sampler() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("get_height_at_global"):
			return node
		node = node.get_parent()
	return null


func _make_preview_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _make_surface_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# Weathered, matte asphalt — fully rough, no sheen, lets terrain lighting read.
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.metallic_specular = 0.0
	return mat
