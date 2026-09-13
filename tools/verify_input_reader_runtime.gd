extends SceneTree


func _init() -> void:
	var err := await _verify()
	quit(err)


func _verify() -> int:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load res://scenes/main.tscn")
		return ERR_CANT_OPEN

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var input_reader := scene.get_node_or_null("InputReader")
	var player := scene.get_node_or_null("Player")
	var camera_rig := scene.get_node_or_null("CameraRig")
	if input_reader == null or player == null or camera_rig == null:
		push_error("Missing InputReader, Player, or CameraRig.")
		return ERR_DOES_NOT_EXIST

	if camera_rig.get("target_path") != NodePath("../Player"):
		push_error("CameraRig target_path must be ../Player.")
		return ERR_INVALID_DATA

	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		push_error("Mouse cursor must stay free (MOUSE_MODE_VISIBLE) instead of being captured.")
		return ERR_INVALID_DATA

	player.set("velocity", Vector3(0.0, 0.0, -3.0))
	var yaw_before: float = camera_rig.rotation.y
	for _i in range(30):
		camera_rig.call("_physics_process", 1.0 / 60.0)
	var yaw_after: float = camera_rig.rotation.y
	if is_equal_approx(yaw_before, yaw_after):
		push_error("CameraRig did not auto-rotate to follow the player's movement direction.")
		return ERR_INVALID_DATA

	print("input_reader_ok mouse_mode=%s yaw_before=%s yaw_after=%s" % [
		Input.mouse_mode,
		snappedf(yaw_before, 0.001),
		snappedf(yaw_after, 0.001),
	])
	return OK
