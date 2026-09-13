extends CanvasLayer
class_name MainMenu

## Minimal main menu drawn over the live (paused) game world. Owns the
## start / pause / game-over loop: picks a difficulty that scales sunburn
## and water-drain speed, shows per-difficulty best scores, and reopens on
## death showing the run results with a RETRY button.

@export var run_score_path: NodePath = ^"../Player/RunScore"
@export var sun_exposure_path: NodePath = ^"../Player/SunExposure"
@export var water_supply_path: NodePath = ^"../Player/WaterSupply"
@export var character_swapper_path: NodePath = ^"../Player/CharacterSwapper"
@export var heat_wave_path: NodePath = ^"../HeatWave"

const DIFFICULTY_ORDER: Array[String] = ["easy", "normal", "hard"]
const DIFFICULTIES: Dictionary = {
	"easy": {"label": "EASY", "sun": 0.6, "water": 0.6},
	"normal": {"label": "NORMAL", "sun": 1.0, "water": 1.0},
	"hard": {"label": "HARD", "sun": 1.75, "water": 1.75},
}

const CHARACTER_ORDER: Array[String] = ["robot", "wanderer", "srini"]

const COLOR_ACCENT := Color(1.0, 0.6, 0.25, 1.0)
const COLOR_TEXT_DIM := Color(1.0, 0.9, 0.7, 0.65)

@onready var run_score: RunScore = get_node_or_null(run_score_path) as RunScore
@onready var sun_exposure: SunExposure = get_node_or_null(sun_exposure_path) as SunExposure
@onready var water_supply: WaterSupply = get_node_or_null(water_supply_path) as WaterSupply
@onready var character_swapper: PlayerCharacterSwapper = get_node_or_null(character_swapper_path) as PlayerCharacterSwapper
@onready var heat_wave: HeatWaveManager = get_node_or_null(heat_wave_path) as HeatWaveManager

var selected_difficulty: String = "normal"
var selected_character: String = PlayerCharacterSwapper.DEFAULT_CHARACTER

var _in_run: bool = false
var _has_results: bool = false
var _last_score: int = 0
var _last_distance: float = 0.0
var _last_best: int = 0
var _last_is_new_best: bool = false
var _last_death_cause: StringName = &"heat"
var _base_sun_damage: float = 10.0
var _base_water_drain: float = 5.0

var _root: Control
var _start_button: Button
var _difficulty_buttons: Dictionary = {}
var _character_buttons: Dictionary = {}
var _best_labels: Dictionary = {}
var _title_label: Label
var _tagline_label: Label
var _difficulty_row: HBoxContainer
var _character_block: VBoxContainer
# Knob flow: 0 = choosing difficulty, 1 = choosing character. Rotate cycles the
# active stage; click confirms it and advances (stage 1 click starts the run).
var _menu_stage: int = 0
var _results_block: VBoxContainer
var _result_score_label: Label
var _result_distance_label: Label
var _result_best_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	if sun_exposure != null:
		_base_sun_damage = sun_exposure.sun_damage_per_second
	if water_supply != null:
		_base_water_drain = water_supply.drain_per_second
	if run_score != null:
		selected_difficulty = run_score.difficulty
		run_score.run_ended.connect(_on_run_ended)
	else:
		push_warning("MainMenu: RunScore not found at %s" % run_score_path)

	_build_ui()
	_open_menu()


func _input(event: InputEvent) -> void:
	# Esc toggles the pause menu (unchanged).
	if event.is_action_pressed(&"ui_cancel"):
		if _root.visible and _in_run:
			_close_menu()
		elif not _root.visible:
			_open_menu()
		return

	# Knob-driven navigation while the menu is showing. Two stages: rotate to
	# move within the active stage (difficulty, then character), click to
	# confirm. Confirming difficulty moves focus to character; confirming
	# character starts the run. The HID controller sends menu_prev/menu_next per
	# detent and menu_select on press; the same knob does camera peek / inventory
	# once a run is underway.
	if not _root.visible:
		return
	if event.is_action_pressed(&"menu_next"):
		_cycle_stage(1)
	elif event.is_action_pressed(&"menu_prev"):
		_cycle_stage(-1)
	elif event.is_action_pressed(&"menu_select"):
		_confirm_stage()


func _cycle_stage(step: int) -> void:
	# Locked during a run (pause menu shows RESUME only).
	if _in_run:
		return
	if _menu_stage == 0:
		_cycle_difficulty(step)
	else:
		_cycle_character(step)


func _confirm_stage() -> void:
	# In the pause menu a click just resumes.
	if _in_run:
		_on_start_pressed()
		return
	# Fresh start / retry: difficulty first, then character, then go.
	if _menu_stage == 0:
		_menu_stage = 1
		_refresh_labels()
	else:
		_on_start_pressed()


func _open_menu() -> void:
	_menu_stage = 0   # always start the knob flow on difficulty
	_refresh_labels()
	_root.visible = true
	get_tree().paused = true
	_start_button.grab_focus()


func _close_menu() -> void:
	_root.visible = false
	get_tree().paused = false


func _on_start_pressed() -> void:
	if not _in_run:
		_start_run()
	_close_menu()


func _start_run() -> void:
	if character_swapper != null:
		character_swapper.apply_character(selected_character)
	if heat_wave != null:
		heat_wave.reset()
	var preset: Dictionary = DIFFICULTIES[selected_difficulty]
	if sun_exposure != null:
		sun_exposure.sun_damage_per_second = _base_sun_damage * float(preset["sun"])
		sun_exposure.invincible = false
		sun_exposure.reset_run()
	if water_supply != null:
		water_supply.drain_per_second = _base_water_drain * float(preset["water"])
	if run_score != null:
		run_score.set_difficulty(selected_difficulty)
		run_score.reset_run()
	_has_results = false
	_in_run = true


func _on_run_ended(final_score: int, distance_m: float, best: int, is_new_best: bool, cause: StringName) -> void:
	_in_run = false
	_has_results = true
	_last_score = final_score
	_last_distance = distance_m
	_last_best = best
	_last_is_new_best = is_new_best
	_last_death_cause = cause
	# The menu pauses the tree, but zero the hazards anyway so the respawned
	# player can't burn if anything ignores pause. _start_run restores both
	# rates from the base values.
	if sun_exposure != null:
		sun_exposure.invincible = true
		sun_exposure.sun_damage_per_second = 0.0
	if water_supply != null:
		water_supply.drain_per_second = 0.0
	_open_menu()


func _on_difficulty_pressed(diff: String) -> void:
	selected_difficulty = diff
	_refresh_labels()


func _cycle_difficulty(step: int) -> void:
	# Difficulty is locked mid-run (the pause menu shows RESUME), so ignore.
	if _in_run:
		return
	var idx := DIFFICULTY_ORDER.find(selected_difficulty)
	if idx < 0:
		idx = 0
	idx = wrapi(idx + step, 0, DIFFICULTY_ORDER.size())
	selected_difficulty = DIFFICULTY_ORDER[idx]
	_refresh_labels()


func _on_character_pressed(character_id: String) -> void:
	selected_character = character_id
	_refresh_labels()


func _cycle_character(step: int) -> void:
	if _in_run:
		return
	var idx := CHARACTER_ORDER.find(selected_character)
	if idx < 0:
		idx = 0
	idx = wrapi(idx + step, 0, CHARACTER_ORDER.size())
	selected_character = CHARACTER_ORDER[idx]
	_refresh_labels()


func _refresh_labels() -> void:
	if _has_results:
		if _last_death_cause == &"dehydration":
			_title_label.text = "THE FROGGIE DIDN'T SURVIVE"
			_title_label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0, 1.0))
		else:
			_title_label.text = "YOU COLLAPSED FROM THE HEAT"
			_title_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3, 1.0))
		_title_label.add_theme_font_size_override("font_size", 52)
		_result_score_label.text = _format_score(_last_score)
		_result_distance_label.text = "You made it %d m from home" % int(_last_distance)
		if _last_is_new_best:
			_result_best_label.text = "★ NEW BEST! ★"
			_result_best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		else:
			_result_best_label.text = "BEST  %s" % _format_score(_last_best)
			_result_best_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	else:
		_title_label.text = "BEAT THE HEAT"
		_title_label.add_theme_font_size_override("font_size", 82)
		_title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_tagline_label.visible = not _has_results
	_results_block.visible = _has_results
	_start_button.text = "RESUME" if _in_run else ("RETRY" if _has_results else "START")
	for diff in DIFFICULTY_ORDER:
		var button := _difficulty_buttons[diff] as Button
		button.button_pressed = diff == selected_difficulty
		button.disabled = _in_run
		var best := run_score.get_best(diff) if run_score != null else 0
		var label := _best_labels[diff] as Label
		label.text = "Best  %s" % _format_score(best) if best > 0 else "Best  —"
		label.add_theme_color_override(
			"font_color", COLOR_ACCENT if diff == selected_difficulty else COLOR_TEXT_DIM
		)
	for character_id in CHARACTER_ORDER:
		var character_button := _character_buttons[character_id] as Button
		character_button.button_pressed = character_id == selected_character
		character_button.disabled = _in_run

	# Show which stage the knob is on: the active group is bright, the other
	# dimmed. During a run both are locked/dim (RESUME only).
	if _difficulty_row != null and _character_block != null:
		if _in_run:
			_difficulty_row.modulate.a = 0.55
			_character_block.modulate.a = 0.55
		else:
			_difficulty_row.modulate.a = 1.0 if _menu_stage == 0 else 0.4
			_character_block.modulate.a = 1.0 if _menu_stage == 1 else 0.4


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.08, 0.03, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.04, 0.03, 0.92), 20.0, Color(1.0, 0.6, 0.25, 0.5), 3))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 68)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 50)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "BEAT THE HEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	column.add_child(title)
	_title_label = title

	var tagline := Label.new()
	tagline.name = "Tagline"
	tagline.text = "Run far. Stay in the shade. Keep the froggie hydrated."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(tagline)
	_tagline_label = tagline

	column.add_child(_build_results_block())

	column.add_child(_make_spacer(14))
	_difficulty_row = _build_difficulty_row()
	column.add_child(_difficulty_row)
	column.add_child(_make_spacer(10))
	_character_block = _build_character_row()
	column.add_child(_character_block)
	column.add_child(_make_spacer(14))

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "START"
	_start_button.custom_minimum_size = Vector2(360, 76)
	_start_button.add_theme_font_size_override("font_size", 38)
	_start_button.add_theme_stylebox_override("normal", _make_style(Color(0.85, 0.42, 0.1, 0.95), 14.0, Color(1.0, 0.75, 0.4, 0.8), 2))
	_start_button.add_theme_stylebox_override("hover", _make_style(Color(1.0, 0.52, 0.15, 1.0), 14.0, Color(1.0, 0.85, 0.5, 1.0), 2))
	_start_button.add_theme_stylebox_override("pressed", _make_style(Color(0.7, 0.33, 0.08, 1.0), 14.0, Color(1.0, 0.75, 0.4, 0.8), 2))
	_start_button.add_theme_stylebox_override("focus", _make_style(Color(0, 0, 0, 0), 14.0, Color(1.0, 0.9, 0.6, 0.9), 2))
	_start_button.pressed.connect(_on_start_pressed)
	var start_wrap := CenterContainer.new()
	start_wrap.name = "StartWrap"
	start_wrap.add_child(_start_button)
	column.add_child(start_wrap)

	var hints := Label.new()
	hints.name = "Hints"
	hints.text = "Knob: rotate to choose · click to confirm  —  difficulty ▸ character ▸ GO"
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 19)
	hints.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.45))
	column.add_child(hints)


## Run-results section shown in place of the tagline after a death:
## SCORE caption, big score number, distance line, best/new-best line.
func _build_results_block() -> VBoxContainer:
	_results_block = VBoxContainer.new()
	_results_block.name = "Results"
	_results_block.alignment = BoxContainer.ALIGNMENT_CENTER
	_results_block.add_theme_constant_override("separation", 4)
	_results_block.visible = false

	var caption := Label.new()
	caption.name = "ScoreCaption"
	caption.text = "SCORE"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_results_block.add_child(caption)

	_result_score_label = Label.new()
	_result_score_label.name = "ScoreValue"
	_result_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score_label.add_theme_font_size_override("font_size", 64)
	_result_score_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.45, 1.0))
	_results_block.add_child(_result_score_label)

	_result_distance_label = Label.new()
	_result_distance_label.name = "DistanceLabel"
	_result_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_distance_label.add_theme_font_size_override("font_size", 22)
	_result_distance_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.9))
	_results_block.add_child(_result_distance_label)

	_result_best_label = Label.new()
	_result_best_label.name = "BestLabel"
	_result_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_best_label.add_theme_font_size_override("font_size", 22)
	_results_block.add_child(_result_best_label)

	return _results_block


func _build_difficulty_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Difficulties"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)

	var group := ButtonGroup.new()
	for diff in DIFFICULTY_ORDER:
		var cell := VBoxContainer.new()
		cell.name = str(diff).capitalize()
		cell.add_theme_constant_override("separation", 6)

		var button := Button.new()
		button.name = "Pick"
		button.text = str(DIFFICULTIES[diff]["label"])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(180, 60)
		button.add_theme_font_size_override("font_size", 27)
		button.add_theme_stylebox_override("normal", _make_style(Color(0.12, 0.08, 0.05, 0.9), 12.0, Color(1.0, 0.6, 0.25, 0.25), 2))
		button.add_theme_stylebox_override("hover", _make_style(Color(0.2, 0.12, 0.07, 0.95), 12.0, Color(1.0, 0.6, 0.25, 0.5), 2))
		button.add_theme_stylebox_override("pressed", _make_style(Color(0.45, 0.22, 0.06, 1.0), 12.0, COLOR_ACCENT, 2))
		button.add_theme_stylebox_override("focus", _make_style(Color(0, 0, 0, 0), 12.0, Color(1.0, 0.9, 0.6, 0.5), 1))
		button.pressed.connect(_on_difficulty_pressed.bind(diff))
		cell.add_child(button)

		var best := Label.new()
		best.name = "Best"
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_font_size_override("font_size", 19)
		cell.add_child(best)

		_difficulty_buttons[diff] = button
		_best_labels[diff] = best
		row.add_child(cell)

	return row


## Character picker shown under the difficulty row: choose who you run as.
## The swap itself happens in _start_run via the PlayerCharacterSwapper.
func _build_character_row() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "CharacterBlock"
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "CHARACTER"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	block.add_child(caption)

	var row := HBoxContainer.new()
	row.name = "Characters"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	block.add_child(row)

	var group := ButtonGroup.new()
	for character_id in CHARACTER_ORDER:
		var button := Button.new()
		button.name = str(character_id).capitalize()
		button.text = str(PlayerCharacterSwapper.CHARACTERS[character_id]["label"])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(180, 56)
		button.add_theme_font_size_override("font_size", 25)
		button.add_theme_stylebox_override("normal", _make_style(Color(0.12, 0.08, 0.05, 0.9), 12.0, Color(1.0, 0.6, 0.25, 0.25), 2))
		button.add_theme_stylebox_override("hover", _make_style(Color(0.2, 0.12, 0.07, 0.95), 12.0, Color(1.0, 0.6, 0.25, 0.5), 2))
		button.add_theme_stylebox_override("pressed", _make_style(Color(0.45, 0.22, 0.06, 1.0), 12.0, COLOR_ACCENT, 2))
		button.add_theme_stylebox_override("focus", _make_style(Color(0, 0, 0, 0), 12.0, Color(1.0, 0.9, 0.6, 0.5), 1))
		button.pressed.connect(_on_character_pressed.bind(character_id))
		_character_buttons[character_id] = button
		row.add_child(button)

	return block


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _make_style(bg_color: Color, corner_radius: float, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = int(corner_radius)
	style.corner_radius_top_right = int(corner_radius)
	style.corner_radius_bottom_left = int(corner_radius)
	style.corner_radius_bottom_right = int(corner_radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _format_score(value: int) -> String:
	var digits := str(value)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
