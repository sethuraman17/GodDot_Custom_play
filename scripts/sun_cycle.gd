extends DirectionalLight3D
class_name SunCycle

## Continuously sweeps the sun's azimuth around the world Y axis so shade
## patterns keep shifting. Rotating only around Y preserves elevation, so
## the sun never dips below the horizon (no night). Speed and pause are
## exposed for the F3 debug panel's live slider/checkbox controls.

@export var degrees_per_second: float = 4.0
@export var min_degrees_per_second: float = 0.0
@export var max_degrees_per_second: float = 200.0
@export var paused: bool = false

var _base_basis: Basis
var _elapsed: float = 0.0


func _ready() -> void:
	_base_basis = transform.basis


func _process(delta: float) -> void:
	if not paused:
		_elapsed += delta
	transform.basis = _base_basis.rotated(Vector3.UP, deg_to_rad(_elapsed * degrees_per_second))


func set_speed(value: float) -> void:
	degrees_per_second = clampf(value, min_degrees_per_second, max_degrees_per_second)
