## main_menu.gd — Front-end main menu for The Last Cipher (demo entry point).
##
## The game boots here (project.godot main_scene). Offers Play (loads the single-floor
## demo), live volume controls wired to AudioSystem, and Quit. Built entirely in code to
## match the project's programmatic-UI convention (see debug_game_loop / combat_hud).
##
## Display-only front-end: it never mutates gameplay state — it only swaps scenes and
## adjusts audio buses. AudioSystem boots in its MAIN_MENU music state, so no music
## wiring is required here.
extends Control

## Scene loaded when the player presses Play. The single-floor demo build.
const _DEMO_SCENE_PATH: String = "res://src/scenes/demo.tscn"

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _META: MetaTuning = preload("res://assets/data/meta_tuning.tres")

## Where progress is read and written. Tests point this at a temp file.
var progress_path: String = MetaProgress.DEFAULT_PATH
## Between-run progress, loaded in _ready() (ADR-0025).
var progress: MetaProgress = null

var _progress_label: Label = null
var _heirloom_row: HBoxContainer = null
var _heirloom_desc: Label = null
var _hard_toggle: CheckButton = null
var _hard_locked_label: Label = null


func _ready() -> void:
	# Stay interactive even if some earlier scene left the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress = MetaProgress.load_from(progress_path)
	_build_ui()


## Builds the full menu layout: backdrop, title, volume sliders, Play, Quit.
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "THE LAST CIPHER"
	title.add_theme_font_size_override(&"font_size", 54)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Arrange Prana. Cast. Defeat the floor boss."
	subtitle.add_theme_font_size_override(&"font_size", 22)
	subtitle.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.78))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_make_spacer(6))

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(260, 52)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override(&"font_size", 28)
	play.pressed.connect(_on_play_pressed)
	vbox.add_child(play)

	vbox.add_child(_make_spacer(4))
	_build_progress_panel(vbox)
	vbox.add_child(_make_spacer(4))

	# Volume controls — wired straight to the AudioSystem bus setters.
	_add_volume_slider(vbox, "Master", AudioSystem.get_master_volume(), AudioSystem.set_master_volume)
	_add_volume_slider(vbox, "Music", AudioSystem.get_music_volume(), AudioSystem.set_music_volume)
	_add_volume_slider(vbox, "SFX", AudioSystem.get_sfx_volume(), AudioSystem.set_sfx_volume)

	vbox.add_child(_make_spacer(8))

	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(200, 42)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.add_theme_font_size_override(&"font_size", 22)
	quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit)

	var controls := Label.new()
	controls.text = "WASD / Stick  Move      Shift / X  Dash      Space / A  Cast      Enter / Y  Confirm"
	controls.add_theme_font_size_override(&"font_size", 16)
	controls.add_theme_color_override(&"font_color", Color(0.55, 0.55, 0.62))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls)

	# Focus Play so keyboard (Enter/Space) and gamepad (ui_accept) work immediately.
	play.grab_focus()


## Builds the between-run progress block: shard/stat line, Heirloom row, Hard Mode.
func _build_progress_panel(parent: Node) -> void:
	_progress_label = _make_label("", 18, Color(1.0, 0.85, 0.4))
	parent.add_child(_progress_label)

	parent.add_child(_make_label(_COPY.heirloom_header, 15, Color(0.62, 0.62, 0.7)))
	_heirloom_row = HBoxContainer.new()
	_heirloom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_heirloom_row.add_theme_constant_override(&"separation", 8)
	parent.add_child(_heirloom_row)
	for id: StringName in _META.heirloom_ids:
		var b := Button.new()
		b.name = "Heirloom_%s" % id
		b.custom_minimum_size = Vector2(150, 50)
		b.add_theme_font_size_override(&"font_size", 14)
		var captured: StringName = id
		b.pressed.connect(func() -> void: _on_heirloom_pressed(captured))
		b.focus_entered.connect(func() -> void: _show_heirloom_desc(captured))
		b.mouse_entered.connect(func() -> void: _show_heirloom_desc(captured))
		_heirloom_row.add_child(b)
	_heirloom_desc = _make_label("", 14, Color(0.7, 0.7, 0.78))
	parent.add_child(_heirloom_desc)

	_hard_toggle = CheckButton.new()
	_hard_toggle.text = _COPY.hard_mode_label
	_hard_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hard_toggle.add_theme_font_size_override(&"font_size", 16)
	_hard_toggle.toggled.connect(_on_hard_mode_toggled)
	parent.add_child(_hard_toggle)
	_hard_locked_label = _make_label(_COPY.hard_mode_locked, 15, Color(0.5, 0.5, 0.56))
	parent.add_child(_hard_locked_label)
	_refresh_progress()
	_show_heirloom_desc(progress.equipped if progress.is_unlocked(progress.equipped) \
		else _META.heirloom_ids[0])


## Re-reads [member progress] into every progress widget.
func _refresh_progress() -> void:
	if _progress_label == null:
		return
	_progress_label.text = _COPY.progress_line_format % [
		progress.shards, progress.runs, progress.wins, progress.best_floor]
	for i: int in _META.heirloom_ids.size():
		var id: StringName = _META.heirloom_ids[i]
		var b: Button = _heirloom_row.get_child(i) as Button
		var title: String = str(MetaProgress.heirloom_info(id).get("title", id))
		if progress.equipped == id and progress.is_unlocked(id):
			b.text = _COPY.heirloom_equipped_format % title
			b.modulate = Color(1.0, 0.9, 0.5)
		elif progress.is_unlocked(id):
			b.text = _COPY.heirloom_unlocked_format % title
			b.modulate = Color.WHITE
		else:
			b.text = _COPY.heirloom_locked_format % [title, _META.cost_of(id)]
			b.modulate = Color.WHITE if progress.can_unlock(_META, id) else Color(0.6, 0.6, 0.65)
	var hard_open: bool = progress.is_hard_mode_unlocked(_META)
	_hard_toggle.visible = hard_open
	_hard_toggle.set_pressed_no_signal(progress.hard_mode_active(_META))
	_hard_locked_label.visible = not hard_open


## Unlocks a locked Heirloom (if affordable) or toggles an unlocked one, then saves.
func _on_heirloom_pressed(id: StringName) -> void:
	var changed: bool = progress.unlock(_META, id) if not progress.is_unlocked(id) \
		else progress.toggle_equip(id)
	if changed:
		progress.save_to(progress_path)
	_refresh_progress()
	_show_heirloom_desc(id)


func _on_hard_mode_toggled(on: bool) -> void:
	progress.hard_mode = on
	progress.save_to(progress_path)


## Shows what [param id] does and what pressing its button will do.
func _show_heirloom_desc(id: StringName) -> void:
	var hint: String = _COPY.heirloom_hint_buy
	if progress.is_unlocked(id):
		hint = _COPY.heirloom_hint_unequip if progress.equipped == id else _COPY.heirloom_hint_equip
	elif not progress.can_unlock(_META, id):
		hint = _COPY.heirloom_hint_poor
	_heirloom_desc.text = _COPY.heirloom_desc_format % [
		str(MetaProgress.heirloom_info(id).get("desc", "")), hint]


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Loads the demo scene. Autoloads persist across the swap, so AudioSystem and game
## state carry over; the demo's own _ready() resets state and shows its intro flow.
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(_DEMO_SCENE_PATH)


## Quits the application. Honoured by exported/web builds; stops the run in the editor.
func _on_quit_pressed() -> void:
	get_tree().quit()


## Builds a labelled 0–100 volume slider on [param parent] for one audio bus.
## [param current_db] seeds the handle; [param setter] receives the new dB on change.
## dB↔slider maps linearly over [−80, 0]; the AudioSystem setter clamps per-bus invariants.
func _add_volume_slider(parent: Node, bus_label: String, current_db: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)

	var name_label := Label.new()
	name_label.text = bus_label
	name_label.custom_minimum_size = Vector2(86, 0)
	name_label.add_theme_font_size_override(&"font_size", 18)
	name_label.add_theme_color_override(&"font_color", Color(0.78, 0.78, 0.84))
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(240, 0)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = clampf((current_db + 80.0) / 80.0 * 100.0, 0.0, 100.0)
	slider.value_changed.connect(func(v: float) -> void: setter.call(lerpf(-80.0, 0.0, v / 100.0)))
	# Persist on release so the choice survives a restart, without thrashing disk per drag step.
	slider.drag_ended.connect(func(_changed: bool) -> void: AudioSystem.save_audio_settings())
	row.add_child(slider)

	parent.add_child(row)


## Returns a fixed-height invisible spacer Control for VBox layout.
func _make_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
