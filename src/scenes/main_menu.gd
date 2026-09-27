## main_menu.gd — Front-end main menu for The Last Cipher (demo entry point).
##
## The game boots here (project.godot main_scene). Offers Play (loads the three-floor
## run), Heirlooms, Spellbook, Memories, Settings and Quit. Built entirely in code to
## match the project's programmatic-UI convention (see debug_game_loop / combat_hud).
##
## Display-only front-end: it never mutates gameplay state — it only swaps scenes and
## adjusts audio buses. AudioSystem boots in its MAIN_MENU music state, so no music
## wiring is required here.
extends Control

## Scene loaded when the player presses Play: the full three-floor run, so the
## Cipher Keeper and the ending are reachable (demo.tscn stops after floor 1).
const _RUN_SCENE_PATH: String = "res://src/scenes/main.tscn"

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _META: MetaTuning = preload("res://assets/data/meta_tuning.tres")

## Where progress is read and written. Tests point this at a temp file.
var progress_path: String = MetaProgress.DEFAULT_PATH
## Between-run progress, loaded in _ready() (ADR-0025).
var progress: MetaProgress = null

## Left column position and width, and the width of its buttons (U7 layout).
const COLUMN_LEFT: float = 96.0
const COLUMN_WIDTH: float = 420.0
const BUTTON_WIDTH: float = 280.0

var _progress_label: Label = null
var _play_button: Button = null
var _records_label: Label = null
## Controls line at the bottom; follows the last-used device (U8).
var _controls_label: Label = null
var _hard_toggle: CheckButton = null
var _hard_locked_label: Label = null
## The left column, centred vertically and shrunk to fit at large text sizes (ADR-0032).
var _column: VBoxContainer = null
## Space kept free under the column for the controls line, px.
const CONTROLS_RESERVE: float = 30.0


func _ready() -> void:
	# Stay interactive even if some earlier scene left the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress = MetaProgress.load_from(progress_path)
	GameSettings.active().apply_display_once()
	_build_ui()
	_fit_column.call_deferred()
	_column.minimum_size_changed.connect(func() -> void: _fit_column.call_deferred())
	get_viewport().size_changed.connect(func() -> void: _fit_column.call_deferred())
	UIFeel.fade_in(self, 0.35)


func _fit_column() -> void:
	if is_instance_valid(_column):
		UIFeel.fit_to_viewport(_column, 8.0, COLUMN_LEFT, CONTROLS_RESERVE)


## Builds the menu (U7): the vault backdrop with Fayde on the right; on the left the
## title, progress line, buttons (Play / Heirlooms / Memories / Settings / Quit) and
## the Hard Mode toggle, with the controls line underneath.
func _build_ui() -> void:
	var backdrop := MenuBackdrop.new()
	backdrop.animate = not GameSettings.motion_reduced()
	add_child(backdrop)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)
	_column = column

	var title := _make_label(_COPY.menu_title, 50, UIPalette.ACCENT)
	title.add_child(TitleGlow.new())
	column.add_child(title)
	column.add_child(_make_label(_COPY.menu_subtitle, 18, UIPalette.TEXT_DIM))
	_progress_label = _make_label("", 16, UIPalette.ACCENT)
	column.add_child(_progress_label)
	# F3: best run, fastest kill per boss, memories found.
	_records_label = _make_label(Records.menu_line(progress, StoryRules.total()), 14, UIPalette.TEXT_DIM)
	_records_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_records_label.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_child(_records_label)
	column.add_child(_make_spacer(10))

	_play_button = _menu_button(column, _COPY.menu_play, 28)
	_play_button.pressed.connect(_on_play_pressed)
	var heirlooms := _menu_button(column, _COPY.menu_heirlooms, 22)
	heirlooms.pressed.connect(_on_heirlooms_pressed.bind(heirlooms))
	var book: Vector2i = Spellbook.progress(progress)
	var spellbook := _menu_button(column, _COPY.spellbook_button_format % [book.x, book.y], 22)
	spellbook.pressed.connect(_on_spellbook_pressed.bind(spellbook))
	# ADR-0027: archive of recovered memory fragments and seen endings.
	var memories := _menu_button(column, _COPY.memories_button_format % [
		mini(progress.fragments_found, StoryRules.total()), StoryRules.total()], 22)
	memories.pressed.connect(_on_memories_pressed.bind(memories))
	# Volume, display, comfort and key bindings live in the Settings panel (ADR-0026).
	var settings := _menu_button(column, _COPY.settings_button, 22)
	settings.pressed.connect(_on_settings_pressed.bind(settings))
	var quit := _menu_button(column, _COPY.menu_quit, 22)
	quit.pressed.connect(_on_quit_pressed)

	column.add_child(_make_spacer(6))
	_hard_toggle = CheckButton.new()
	_hard_toggle.text = _COPY.hard_mode_label
	_hard_toggle.add_theme_font_size_override(&"font_size", 15)
	_hard_toggle.toggled.connect(_on_hard_mode_toggled)
	column.add_child(_hard_toggle)
	_hard_locked_label = _make_label(_COPY.hard_mode_locked, 15, UIPalette.TEXT_FAINT)
	column.add_child(_hard_locked_label)

	var controls := _make_label(InputPrompts.controls_line(), 14, UIPalette.TEXT_FAINT)
	_controls_label = controls
	InputPrompts.device_changed.connect(_on_device_changed)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls.offset_left = COLUMN_LEFT
	controls.offset_bottom = -10.0
	add_child(controls)

	var version := _make_label(_COPY.version_format % version_string(), 14, UIPalette.TEXT_FAINT)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -12.0
	version.offset_bottom = -8.0
	add_child(version)

	_refresh_progress()
	# Focus Play so keyboard (Enter/Space) and gamepad (ui_accept) work immediately.
	_play_button.grab_focus()


func _on_device_changed(_using_pad: bool) -> void:
	_controls_label.text = InputPrompts.controls_line()


## A left-aligned menu button of the column's width.
func _menu_button(parent: Node, text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, 42)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(b)
	return b


## The game version from project settings (application/config/version).
static func version_string() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


## Opens the Settings panel; focus returns to [param from] when it closes.
func _on_settings_pressed(from: Button) -> void:
	var panel := SettingsPanel.new()
	panel.closed.connect(from.grab_focus)
	add_child(panel)


## Opens the Memories archive; focus returns to [param from] when it closes.
func _on_memories_pressed(from: Button) -> void:
	var panel := MemoriesPanel.new()
	panel.progress = progress
	panel.closed.connect(from.grab_focus)
	add_child(panel)


## Opens the Spellbook; focus returns to [param from] when it closes.
func _on_spellbook_pressed(from: Button) -> void:
	var panel := SpellbookPanel.new()
	panel.progress = progress
	panel.closed.connect(from.grab_focus)
	add_child(panel)


## Opens the Heirloom screen; focus returns to [param from] when it closes.
func _on_heirlooms_pressed(from: Button) -> void:
	var screen := HeirloomScreen.new()
	screen.progress = progress
	screen.progress_path = progress_path
	screen.progress_changed.connect(_refresh_progress)
	screen.closed.connect(from.grab_focus)
	add_child(screen)


## Re-reads [member progress] into the progress line and the Hard Mode toggle.
func _refresh_progress() -> void:
	if _progress_label == null:
		return
	_progress_label.text = _COPY.progress_line_format % [
		progress.shards, progress.runs, progress.wins, progress.best_floor]
	var hard_open: bool = progress.is_hard_mode_unlocked(_META)
	_hard_toggle.visible = hard_open
	_hard_toggle.set_pressed_no_signal(progress.hard_mode_active(_META))
	_hard_locked_label.visible = not hard_open


func _on_hard_mode_toggled(on: bool) -> void:
	progress.hard_mode = on
	progress.save_to(progress_path)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


## Loads the demo scene. Autoloads persist across the swap, so AudioSystem and game
## state carry over; the demo's own _ready() resets state and shows its intro flow.
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(_RUN_SCENE_PATH)


## Quits the application. Honoured by exported/web builds; stops the run in the editor.
func _on_quit_pressed() -> void:
	get_tree().quit()


## Returns a fixed-height invisible spacer Control for VBox layout.
func _make_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
