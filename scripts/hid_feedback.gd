extends Node
class_name HidFeedback

## Forwards gameplay events to the Arduino HID controller so it can play
## buzzer feedback and LED-matrix icons. Events are POSTed as JSON to the
## controller's web server (adb-forwarded to localhost:8090); if the board
## is not connected the requests fail silently and the game is unaffected.

@export var endpoint: String = "http://localhost:8090/event"
@export var speed_endpoint: String = "http://localhost:8090/speed"
@export var hid_endpoint: String = "http://localhost:8090/hid"
## Auto-disarm HID when the game window loses focus, so the controller's
## WASD/etc. keystrokes can't leak into the Summer Engine editor (e.g. typing
## into the script tab). Re-arms when focus returns, but only if HID was armed
## when focus was lost.
@export var manage_hid_on_focus: bool = true
@export var player_path: NodePath = ^"../Player"
@export var sun_exposure_path: NodePath = ^"../Player/SunExposure"
@export var water_supply_path: NodePath = ^"../Player/WaterSupply"
@export var water_pickup_min: float = 2.0
@export var water_low_ratio: float = 0.3
@export var sun_poll_interval: float = 0.4
@export var speed_poll_interval: float = 0.05  # 20 Hz sprint-factor poll
@export var sprint_smoothing: float = 12.0     # ease the polled factor

@onready var _player := get_node_or_null(player_path)
@onready var _sun: SunExposure = get_node_or_null(sun_exposure_path) as SunExposure
@onready var _water: WaterSupply = get_node_or_null(water_supply_path) as WaterSupply

var _http: HTTPRequest
var _queue: PackedStringArray = []
var _busy: bool = false
var _prev_water: float = -1.0
var _in_sun: bool = false
var _sun_timer: float = 0.0

var _speed_http: HTTPRequest
var _speed_busy: bool = false
var _speed_timer: float = 0.0
var _sprint_target: float = 0.0   # last value polled from the controller
var _sprint_smooth: float = 0.0   # eased value the game actually uses

var _hid_http: HTTPRequest
var _hid_enabled: bool = false     # controller's armed state (from /speed poll)
var _suspended_by_blur: bool = false  # we disarmed on focus loss; re-arm on return


func _ready() -> void:
	if MobilePlatform.is_mobile():
		set_physics_process(false)
		return

	_http = HTTPRequest.new()
	_http.timeout = 2.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_speed_http = HTTPRequest.new()
	_speed_http.timeout = 1.0
	add_child(_speed_http)
	_speed_http.request_completed.connect(_on_speed_completed)

	_hid_http = HTTPRequest.new()
	_hid_http.timeout = 1.0
	add_child(_hid_http)

	if _player != null and _player.has_signal("worm_stunned"):
		_player.connect("worm_stunned", func() -> void: send_event("worm"))
	if _water != null:
		_water.water_changed.connect(_on_water_changed)
	if _sun != null:
		_sun.died.connect(func() -> void: send_event("died"))


func _physics_process(delta: float) -> void:
	_poll_sprint(delta)

	if _sun == null:
		return
	_sun_timer += delta
	if _sun_timer < sun_poll_interval:
		return
	_sun_timer = 0.0
	var damaging := _sun.last_delta_health_per_second < -0.01
	if damaging != _in_sun:
		_in_sun = damaging
		send_event("sun" if damaging else "shade")


func get_sprint_factor() -> float:
	return _sprint_smooth


func _poll_sprint(delta: float) -> void:
	# Ease toward the last polled factor so USB/network jitter doesn't pulse the
	# speed, then fire the next poll when due.
	var t := 1.0 - exp(-sprint_smoothing * delta)
	_sprint_smooth = lerpf(_sprint_smooth, _sprint_target, t)

	_speed_timer += delta
	if _speed_timer < speed_poll_interval or _speed_busy or _speed_http == null:
		return
	_speed_timer = 0.0
	_speed_busy = _speed_http.request(speed_endpoint) == OK


func _on_speed_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_speed_busy = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and data.has("sprint"):
			_sprint_target = clampf(float(data["sprint"]), 0.0, 1.0)
			if data.has("enabled"):
				_hid_enabled = bool(data["enabled"])
			return
	# Board unreachable / bad reply: fall back to walking so we never get stuck
	# sprinting when the link drops.
	_sprint_target = 0.0


func _notification(what: int) -> void:
	if MobilePlatform.is_mobile() or not manage_hid_on_focus:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _hid_enabled and not _suspended_by_blur:
			_suspended_by_blur = true
			_set_hid(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if _suspended_by_blur:
			_suspended_by_blur = false
			_set_hid(true)


func _set_hid(on: bool) -> void:
	if _hid_http == null:
		return
	_hid_enabled = on
	var body := JSON.stringify({"enabled": on})
	_hid_http.request(hid_endpoint, ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, body)


func _on_water_changed(current: float, max_water: float) -> void:
	if _prev_water < 0.0:
		_prev_water = current
		return
	if current > _prev_water + water_pickup_min:
		send_event("water")
	var low := water_low_ratio * max_water
	if _prev_water >= low and current < low:
		send_event("low")
	_prev_water = current


func send_event(event_name: String) -> void:
	_queue.append(event_name)
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty() or _http == null:
		return
	var event_name := _queue[0]
	_queue.remove_at(0)
	var body := JSON.stringify({"event": event_name})
	var err := _http.request(endpoint, ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, body)
	_busy = err == OK
	# On error just drop the event; feedback is best-effort.


func _on_request_completed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_busy = false
	_pump()
