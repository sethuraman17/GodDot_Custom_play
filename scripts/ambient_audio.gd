extends Node

## Ambient audio bed for a run: desert wind that hardens when exposed to the
## sun, a sizzle danger layer that tracks how badly the player is burning,
## and a low-water warning pulse. Autoloaded, so it discovers the player's
## SunExposure/WaterSupply nodes from the current scene instead of exports.
##
## Runs while the tree is paused (autoload) so the menu keeps a quiet wind
## bed; gameplay layers (sizzle, warning) mute during pause.

const WIND_STREAM := preload("res://assets/audio/wind.ogg")
const SIZZLE_STREAM := preload("res://assets/audio/sizzle.ogg")
const WATER_PICKUP_STREAM := preload("res://assets/audio/water_pickup.ogg")
const WATER_WARNING_STREAM := preload("res://assets/audio/water_warning.ogg")
const SHADE_RELIEF_STREAM := preload("res://assets/audio/shade_relief.ogg")
const DEATH_STREAM := preload("res://assets/audio/death.ogg")
const DEATH_FROG_STREAM := preload("res://assets/audio/death_frog.ogg")

const AMBIENCE_BUS := "Ambience"

## Wind bed levels (dB): harsher in open sun, softer in shade, faint in menu.
@export var wind_exposed_db: float = -6.0
@export var wind_shaded_db: float = -14.0
@export var wind_menu_db: float = -20.0
## Sizzle peaks here when exposed at critically low health.
@export var sizzle_max_db: float = -4.0
@export var sizzle_min_db: float = -22.0
## Low-pass cutoff while fully shaded ("muffled shelter" effect).
@export var shaded_cutoff_hz: float = 2200.0
@export var open_cutoff_hz: float = 20500.0
## Water warning pulse: below this ratio, blip every warning_interval seconds.
@export var low_water_ratio: float = 0.25
@export var warning_interval: float = 2.5

var _wind: AudioStreamPlayer
var _sizzle: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _sun_exposure: SunExposure
var _water_supply: WaterSupply
var _warning_cooldown: float = 0.0

const SILENT_DB := -60.0
const FADE_SPEED := 4.0


func _ready() -> void:
	_setup_ambience_bus()
	for stream: AudioStream in [WIND_STREAM, SIZZLE_STREAM]:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
	_wind = _make_loop_player(WIND_STREAM, wind_menu_db)
	_sizzle = _make_loop_player(SIZZLE_STREAM, SILENT_DB)


func _process(delta: float) -> void:
	if not _find_gameplay_nodes():
		return

	var paused := get_tree().paused
	var shade := _sun_exposure.shade_ratio
	var fully_shaded := shade >= _sun_exposure.full_shade_ratio_threshold

	var wind_target := wind_menu_db if paused else lerpf(wind_exposed_db, wind_shaded_db, shade)
	var sizzle_target := SILENT_DB
	if not paused and not fully_shaded:
		# Louder both with more exposure and with less health left.
		var danger := 1.0 - _sun_exposure.health / _sun_exposure.max_health
		sizzle_target = lerpf(sizzle_min_db, sizzle_max_db, danger) + lerpf(-12.0, 0.0, 1.0 - shade)

	var blend := 1.0 - exp(-FADE_SPEED * delta)
	_wind.volume_db = lerpf(_wind.volume_db, wind_target, blend)
	_sizzle.volume_db = lerpf(_sizzle.volume_db, sizzle_target, blend)
	var cutoff_target := shaded_cutoff_hz if (fully_shaded and not paused) else open_cutoff_hz
	_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, cutoff_target, blend)

	_warning_cooldown -= delta
	if not paused and _water_supply.get_water_ratio() < low_water_ratio and _water_supply.water > 0.0 and _warning_cooldown <= 0.0:
		_warning_cooldown = warning_interval
		play_oneshot(WATER_WARNING_STREAM, -8.0)


func play_water_pickup() -> void:
	play_oneshot(WATER_PICKUP_STREAM, -4.0)


func play_shade_relief() -> void:
	play_oneshot(SHADE_RELIEF_STREAM, -6.0)


func play_oneshot(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _setup_ambience_bus() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, AMBIENCE_BUS)
	AudioServer.set_bus_send(idx, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = open_cutoff_hz
	AudioServer.add_bus_effect(idx, _lowpass)


func _make_loop_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = AMBIENCE_BUS
	player.autoplay = true
	add_child(player)
	player.play()
	return player


func _find_gameplay_nodes() -> bool:
	if _sun_exposure != null and _water_supply != null:
		return true
	var scene := get_tree().current_scene
	if scene == null:
		return false
	_sun_exposure = scene.get_node_or_null(^"Player/SunExposure") as SunExposure
	_water_supply = scene.get_node_or_null(^"Player/WaterSupply") as WaterSupply
	if _sun_exposure != null and not _sun_exposure.died.is_connected(_on_player_died):
		_sun_exposure.died.connect(_on_player_died)
	return _sun_exposure != null and _water_supply != null


func _on_player_died(cause: StringName) -> void:
	# Dehydration means the froggie ran dry — she gets her own send-off.
	play_oneshot(DEATH_FROG_STREAM if cause == &"dehydration" else DEATH_STREAM, -2.0)
