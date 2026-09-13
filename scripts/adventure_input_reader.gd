extends Node
class_name AdventureInputReader

@export var ensure_input_actions: bool = true
@export var mobile_controls_path: NodePath = ^"../MobileControls"

var _mobile: MobileControls


func _ready() -> void:
	if ensure_input_actions:
		ensure_default_actions()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mobile = get_node_or_null(mobile_controls_path) as MobileControls


func get_movement_vector() -> Vector2:
	var keyboard := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if _mobile != null:
		var stick := _mobile.get_move_vector()
		if stick.length_squared() > keyboard.length_squared():
			return stick
	return keyboard


func is_sprint_pressed() -> bool:
	return Input.is_action_pressed(&"sprint") or (_mobile != null and _mobile.is_sprint_held())


func is_punch_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"punch") or (_mobile != null and _mobile.consume_punch())


func is_dance_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"dance") or (_mobile != null and _mobile.consume_dance())


func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"jump") or (_mobile != null and _mobile.consume_jump())


func is_interact_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"interact") or (_mobile != null and _mobile.consume_interact())


func is_inventory_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"inventory")


func get_peek_axis() -> float:
	# +1 peeks right, -1 peeks left. Bound to , / . keys — the HID knob
	# controller sends these on rotation.
	return Input.get_action_strength(&"peek_right") - Input.get_action_strength(&"peek_left")


func is_menu_prev_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"menu_prev")


func is_menu_next_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"menu_next")


func is_menu_select_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"menu_select")


func is_force_field_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"force_field") or (_mobile != null and _mobile.consume_force_field())


func consume_look_delta() -> Vector2:
	if _mobile == null:
		return Vector2.ZERO
	return _mobile.consume_look_delta()


func is_look_dragging() -> bool:
	return _mobile != null and _mobile.is_look_dragging()


static func ensure_default_actions() -> void:
	for action_name in _required_actions():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.5)
		if InputMap.action_get_events(action_name).is_empty():
			_add_default_event(action_name)

	# The knob/menu keys come from fixed HID key POSITIONS. Bind them by
	# physical_keycode so they work regardless of the host keyboard layout:
	# e.g. a US-backslash HID (position 92) can arrive as a different logical
	# key (apostrophe, 39) on some Mac layouts, which broke menu_select.
	_rebind_physical(&"menu_prev", KEY_BRACKETLEFT)
	_rebind_physical(&"menu_next", KEY_BRACKETRIGHT)
	_rebind_physical(&"menu_select", KEY_BACKSLASH)


static func _rebind_physical(action_name: StringName, physical: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	for existing in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, existing)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical as Key
	InputMap.action_add_event(action_name, ev)


static func _required_actions() -> Array[StringName]:
	return [
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_back",
		&"jump",
		&"sprint",
		&"punch",
		&"dance",
		&"interact",
		&"inventory",
		&"peek_left",
		&"peek_right",
		&"menu_prev",
		&"menu_next",
		&"menu_select",
		&"force_field",
		&"ui_cancel",
	]


static func _add_default_event(action_name: StringName) -> void:
	match action_name:
		&"move_left":
			_add_key_event(action_name, KEY_A)
		&"move_right":
			_add_key_event(action_name, KEY_D)
		&"move_forward":
			_add_key_event(action_name, KEY_W)
		&"move_back":
			_add_key_event(action_name, KEY_S)
		&"jump":
			_add_key_event(action_name, KEY_SPACE)
		&"sprint":
			_add_key_event(action_name, KEY_SHIFT)
		&"punch":
			_add_key_event(action_name, KEY_F)
		&"dance":
			_add_key_event(action_name, KEY_G)
		&"interact":
			_add_key_event(action_name, KEY_E)
		&"inventory":
			_add_key_event(action_name, KEY_I)
		&"peek_left":
			_add_key_event(action_name, KEY_COMMA)
		&"peek_right":
			_add_key_event(action_name, KEY_PERIOD)
		&"force_field":
			_add_key_event(action_name, KEY_R)
		# menu_prev / menu_next / menu_select are bound by physical_keycode in
		# _rebind_physical (layout-independent), not here.
		&"ui_cancel":
			_add_key_event(action_name, KEY_ESCAPE)


static func _add_key_event(action_name: StringName, keycode: int) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = keycode as Key
	InputMap.action_add_event(action_name, key_event)

