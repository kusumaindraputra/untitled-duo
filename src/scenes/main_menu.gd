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


func _ready() -> void:
	# Stay interactive even if some earlier scene left the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	vbox.add_theme_constant_override(&"separation", 16)
	add_child(vbox)

	var title := Label.new()
	title.text = "THE LAST CIPHER"
	title.add_theme_font_size_override(&"font_size", 76)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Arrange Prana. Cast. Defeat the floor boss."
	subtitle.add_theme_font_size_override(&"font_size", 22)
	subtitle.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.78))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_make_spacer(28))

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(260, 60)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override(&"font_size", 28)
	play.pressed.connect(_on_play_pressed)
	vbox.add_child(play)

	vbox.add_child(_make_spacer(8))

	# Volume controls — wired straight to the AudioSystem bus setters.
	_add_volume_slider(vbox, "Master", AudioSystem.get_master_volume(), AudioSystem.set_master_volume)
	_add_volume_slider(vbox, "Music", AudioSystem.get_music_volume(), AudioSystem.set_music_volume)
	_add_volume_slider(vbox, "SFX", AudioSystem.get_sfx_volume(), AudioSystem.set_sfx_volume)

	vbox.add_child(_make_spacer(8))

	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(200, 48)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.add_theme_font_size_override(&"font_size", 22)
	quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit)

	vbox.add_child(_make_spacer(20))

	var controls := Label.new()
	controls.text = "WASD / Stick  Move      Shift / X  Dash      Space / A  Cast      Enter / Y  Confirm"
	controls.add_theme_font_size_override(&"font_size", 16)
	controls.add_theme_color_override(&"font_color", Color(0.55, 0.55, 0.62))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls)

	# Focus Play so keyboard (Enter/Space) and gamepad (ui_accept) work immediately.
	play.grab_focus()


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
