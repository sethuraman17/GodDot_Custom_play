extends CanvasLayer
class_name MobileControls

## On-screen multi-touch controls. Visible only on mobile. Feeds
## AdventureInputReader (movement vector, one-shot buttons, analog look).

const JOYSTICK_RADIUS := 108.0
const KNOB_RADIUS := 42.0
const BUTTON_SIZE := 92.0

var move_vector: Vector2 = Vector2.ZERO
var sprint_held: bool = false
var look_dragging: bool = false

var _jump_queued: bool = false
var _interact_queued: bool = false
var _force_field_queued: bool = false
var _punch_queued: bool = false
var _dance_queued: bool = false
var _look_delta: Vector2 = Vector2.ZERO

var _root: Control
var _joystick: _TouchJoystick
var _look_pad: _LookPad
var _sprint_button: Button
var _jump_button: Button
var _punch_button: Button
var _dance_button: Button
var _active: bool = false
var _action_profile: String = "default"


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active = MobilePlatform.is_mobile()
	visible = false
	if not _active:
		set_process(false)
		set_process_input(false)
		return
	_build_ui()


func _process(_delta: float) -> void:
	if not _active:
		return
	var show := not get_tree().paused
	if visible != show:
		visible = show
		if not show:
			_reset_state()


func get_move_vector() -> Vector2:
	return move_vector if _active and visible else Vector2.ZERO


func is_sprint_held() -> bool:
	return _active and visible and sprint_held


func is_look_dragging() -> bool:
	return _active and visible and look_dragging


func consume_look_delta() -> Vector2:
	var delta := _look_delta
	_look_delta = Vector2.ZERO
	return delta


func consume_jump() -> bool:
	if not _jump_queued:
		return false
	_jump_queued = false
	return true


func consume_interact() -> bool:
	if not _interact_queued:
		return false
	_interact_queued = false
	return true


func consume_force_field() -> bool:
	if not _force_field_queued:
		return false
	_force_field_queued = false
	return true


func consume_punch() -> bool:
	if not _punch_queued:
		return false
	_punch_queued = false
	return true


func consume_dance() -> bool:
	if not _dance_queued:
		return false
	_dance_queued = false
	return true


func set_action_profile(profile: String) -> void:
	_action_profile = profile
	var srini := profile == "srini"
	if _jump_button != null:
		_jump_button.visible = not srini
	if _punch_button != null:
		_punch_button.visible = srini
	if _dance_button != null:
		_dance_button.visible = srini


func add_look_delta(delta: Vector2) -> void:
	_look_delta += delta


func _reset_state() -> void:
	move_vector = Vector2.ZERO
	sprint_held = false
	look_dragging = false
	_look_delta = Vector2.ZERO
	if _joystick != null:
		_joystick.reset()
	if _sprint_button != null:
		_sprint_button.button_pressed = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_look_pad = _LookPad.new()
	_look_pad.name = "LookPad"
	_look_pad.controls = self
	_look_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_look_pad.anchor_left = 0.42
	_look_pad.anchor_right = 1.0
	_look_pad.anchor_top = 0.0
	_look_pad.anchor_bottom = 1.0
	_root.add_child(_look_pad)

	_joystick = _TouchJoystick.new()
	_joystick.name = "MoveJoystick"
	_joystick.controls = self
	_joystick.custom_minimum_size = Vector2(JOYSTICK_RADIUS * 2.4, JOYSTICK_RADIUS * 2.4)
	_joystick.anchor_left = 0.0
	_joystick.anchor_right = 0.0
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 28.0
	_joystick.offset_right = 28.0 + JOYSTICK_RADIUS * 2.4
	_joystick.offset_top = -28.0 - JOYSTICK_RADIUS * 2.4
	_joystick.offset_bottom = -28.0
	_root.add_child(_joystick)

	var pause := _make_action_button("II", Color(1.0, 0.92, 0.8, 0.92))
	pause.name = "PauseButton"
	pause.anchor_left = 0.0
	pause.anchor_right = 0.0
	pause.anchor_top = 0.0
	pause.anchor_bottom = 0.0
	pause.offset_left = 16.0
	pause.offset_top = 16.0
	pause.offset_right = 16.0 + 72.0
	pause.offset_bottom = 16.0 + 72.0
	pause.pressed.connect(_on_pause_pressed)
	_root.add_child(pause)

	var column := VBoxContainer.new()
	column.name = "ActionButtons"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = -28.0 - BUTTON_SIZE
	column.offset_right = -28.0
	column.offset_top = -36.0 - (BUTTON_SIZE * 6.0 + 70.0)
	column.offset_bottom = -36.0
	_root.add_child(column)

	var jump := _make_action_button("JUMP", Color(1.0, 0.85, 0.45, 1.0))
	jump.button_down.connect(func() -> void: _jump_queued = true)
	column.add_child(jump)
	_jump_button = jump

	_sprint_button = _make_action_button("SPRINT", Color(1.0, 0.62, 0.28, 1.0))
	_sprint_button.button_down.connect(func() -> void: sprint_held = true)
	_sprint_button.button_up.connect(func() -> void: sprint_held = false)
	column.add_child(_sprint_button)

	var punch := _make_action_button("PUNCH", Color(1.0, 0.45, 0.42, 1.0))
	punch.button_down.connect(func() -> void: _punch_queued = true)
	column.add_child(punch)
	_punch_button = punch

	var dance := _make_action_button("DANCE", Color(0.95, 0.55, 1.0, 1.0))
	dance.button_down.connect(func() -> void: _dance_queued = true)
	column.add_child(dance)
	_dance_button = dance

	var interact := _make_action_button("USE", Color(0.7, 0.92, 1.0, 1.0))
	interact.button_down.connect(func() -> void: _interact_queued = true)
	column.add_child(interact)

	var field := _make_action_button("FIELD", Color(0.55, 1.0, 0.82, 1.0))
	field.button_down.connect(func() -> void: _force_field_queued = true)
	column.add_child(field)

	set_action_profile(_action_profile)


func _make_action_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.12, 0.06, 0.02, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(color.r, color.g, color.b, 0.72)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(color.r, color.g, color.b, 0.95)))
	button.add_theme_stylebox_override("hover", _button_style(Color(color.r, color.g, color.b, 0.82)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0)))
	return button


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 46
	style.corner_radius_top_right = 46
	style.corner_radius_bottom_left = 46
	style.corner_radius_bottom_right = 46
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.35)
	return style


func _on_pause_pressed() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)


class _TouchJoystick extends Control:
	var controls: MobileControls
	var _touch_index: int = -1
	var _knob_offset: Vector2 = Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func reset() -> void:
		_touch_index = -1
		_knob_offset = Vector2.ZERO
		if controls != null:
			controls.move_vector = Vector2.ZERO
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _touch_index == -1:
				_touch_index = touch.index
				_update_from_position(touch.position)
				accept_event()
			elif not touch.pressed and touch.index == _touch_index:
				reset()
				accept_event()
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _touch_index:
				_update_from_position(drag.position)
				accept_event()

	func _update_from_position(local_pos: Vector2) -> void:
		var center := size * 0.5
		var offset := local_pos - center
		var max_len := MobileControls.JOYSTICK_RADIUS
		if offset.length() > max_len:
			offset = offset.normalized() * max_len
		_knob_offset = offset
		# Match Input.get_vector: +x right, -y forward (stick up).
		var axis := offset / max_len
		if controls != null:
			controls.move_vector = axis if axis.length() >= 0.15 else Vector2.ZERO
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, MobileControls.JOYSTICK_RADIUS, Color(0.08, 0.05, 0.03, 0.38))
		draw_arc(center, MobileControls.JOYSTICK_RADIUS, 0.0, TAU, 48, Color(1.0, 0.78, 0.4, 0.45), 3.0, true)
		draw_circle(center + _knob_offset, MobileControls.KNOB_RADIUS, Color(1.0, 0.72, 0.32, 0.82))


class _LookPad extends Control:
	var controls: MobileControls
	var _touch_index: int = -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _touch_index == -1:
				_touch_index = touch.index
				if controls != null:
					controls.look_dragging = true
				accept_event()
			elif not touch.pressed and touch.index == _touch_index:
				_touch_index = -1
				if controls != null:
					controls.look_dragging = false
				accept_event()
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _touch_index and controls != null:
				controls.add_look_delta(drag.relative)
				accept_event()
