## SettingsPanel — display, comfort, audio and key-binding options (ADR-0026).
##
## Opened from the main menu and the pause menu. Every change is applied and saved
## at once (GameSettings → user://settings.cfg "game"/"keys", AudioSystem → "audio"),
## so there is no Apply button to forget. Fully keyboard / gamepad navigable; Esc
## (or Back) closes it, and Esc while waiting for a key cancels the rebind.
## Works while the tree is paused (PROCESS_MODE_ALWAYS).
class_name SettingsPanel
extends CanvasLayer

## The panel was closed.
signal closed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Settings being edited. Defaults to GameSettings.active(); tests inject their own.
var settings: GameSettings = null
## Where settings are saved; tests point this at a temp file.
var save_path: String = GameSettings.DEFAULT_PATH

var _key_buttons: Dictionary[StringName, Button] = {}
var _listening_action: StringName = &""
var _resolution: OptionButton = null
var _shake_value: Label = null
var _back: Button = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = GameSettings.active()
	GameSettings.ensure_actions()
	settings.apply_keys()
	_build()
	_back.grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05, 0.98)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)

	var title := _label(_COPY.settings_title, 40, Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override(&"separation", 48)
	root.add_child(columns)

	var left := _column(columns)
	left.add_child(_label(_COPY.settings_display_heading, 20, Color(0.75, 0.8, 1.0)))
	var fs := _check(left, _COPY.settings_fullscreen, settings.fullscreen)
	fs.toggled.connect(_on_fullscreen_toggled)
	_resolution = OptionButton.new()
	for r: Vector2i in GameSettings.RESOLUTIONS:
		_resolution.add_item("%d × %d" % [r.x, r.y])
	_resolution.select(clampi(settings.resolution_idx, 0, GameSettings.RESOLUTIONS.size() - 1))
	_resolution.disabled = settings.fullscreen
	_resolution.item_selected.connect(_on_resolution_selected)
	left.add_child(_row(_COPY.settings_window_size, _resolution))
	var vs := _check(left, _COPY.settings_vsync, settings.vsync)
	vs.toggled.connect(func(on: bool) -> void:
		settings.vsync = on
		_apply_and_save())

	left.add_child(_label(_COPY.settings_comfort_heading, 20, Color(0.75, 0.8, 1.0)))
	var shake := HSlider.new()
	shake.min_value = 0.0
	shake.max_value = 100.0
	shake.step = 10.0
	shake.value = settings.screen_shake * 100.0
	shake.custom_minimum_size = Vector2(160, 0)
	shake.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shake_value = _label("%d%%" % roundi(shake.value), 16, Color(0.8, 0.8, 0.86))
	shake.value_changed.connect(_on_shake_changed)
	var shake_box := HBoxContainer.new()
	shake_box.add_child(shake)
	shake_box.add_child(_shake_value)
	left.add_child(_row(_COPY.settings_screen_shake, shake_box))
	var fl := _check(left, _COPY.settings_reduce_flashes, settings.reduce_flashes)
	fl.toggled.connect(func(on: bool) -> void:
		settings.reduce_flashes = on
		_save())

	left.add_child(_label(_COPY.settings_audio_heading, 20, Color(0.75, 0.8, 1.0)))
	_volume(left, _COPY.settings_master, AudioSystem.get_master_volume(), AudioSystem.set_master_volume)
	_volume(left, _COPY.settings_music, AudioSystem.get_music_volume(), AudioSystem.set_music_volume)
	_volume(left, _COPY.settings_sfx, AudioSystem.get_sfx_volume(), AudioSystem.set_sfx_volume)

	var right := _column(columns)
	right.add_child(_label(_COPY.settings_controls_heading, 20, Color(0.75, 0.8, 1.0)))
	for i: int in GameSettings.REMAPPABLE.size():
		var action: StringName = GameSettings.REMAPPABLE[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 34)
		b.pressed.connect(_start_listening.bind(action))
		_key_buttons[action] = b
		var name_text: String = _COPY.settings_action_names[i] \
			if i < _COPY.settings_action_names.size() else String(action)
		right.add_child(_row(name_text, b))
	var reset := Button.new()
	reset.text = _COPY.settings_reset_keys
	reset.pressed.connect(_on_reset_keys)
	right.add_child(reset)
	right.add_child(_label(_COPY.settings_gamepad_note, 14, Color(0.55, 0.55, 0.62)))
	_refresh_keys()

	_back = Button.new()
	_back.text = _COPY.settings_back
	_back.custom_minimum_size = Vector2(220, 48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override(&"font_size", 22)
	_back.pressed.connect(close)
	root.add_child(_back)


## Closes the panel (saving is already done on every change).
func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _listening_action != &"":
		get_viewport().set_input_as_handled()
		var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if code != KEY_ESCAPE:
			rebind_with_swap(_listening_action, code)
		_listening_action = &""
		_refresh_keys()
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## Binds [param action] to [param code]. If another remappable action already uses
## that key, it takes [param action]'s old key, so no key is ever bound twice.
func rebind_with_swap(action: StringName, code: Key) -> void:
	var other: StringName = GameSettings.action_using_key(code)
	if other == action:
		return
	var old_code: Key = _first_key(action)
	settings.rebind(action, code)
	if other != &"" and old_code != KEY_NONE:
		settings.rebind(other, old_code)
	_save()


func _start_listening(action: StringName) -> void:
	_listening_action = action
	_refresh_keys()


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = _COPY.settings_press_key if action == _listening_action \
			else GameSettings.key_label(action)


func _on_reset_keys() -> void:
	settings.reset_keys()
	_save()
	_refresh_keys()


func _on_fullscreen_toggled(on: bool) -> void:
	settings.fullscreen = on
	_resolution.disabled = on
	_apply_and_save()


func _on_resolution_selected(idx: int) -> void:
	settings.resolution_idx = idx
	_apply_and_save()


func _on_shake_changed(v: float) -> void:
	settings.screen_shake = v / 100.0
	_shake_value.text = "%d%%" % roundi(v)
	_save()


func _apply_and_save() -> void:
	settings.apply_display()
	_save()


func _save() -> void:
	settings.save_to(save_path)


static func _first_key(action: StringName) -> Key:
	for ev: InputEvent in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k != null:
			return k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	return KEY_NONE


# ── Small builders ────────────────────────────────────────────────────────────

func _column(parent: Node) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	parent.add_child(col)
	return col


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var l := _label(text, 16, Color(0.82, 0.82, 0.88))
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(control)
	return row


func _check(parent: Node, text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	parent.add_child(c)
	return c


func _volume(parent: Node, text: String, current_db: float, setter: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = clampf((current_db + 80.0) / 80.0 * 100.0, 0.0, 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v / 100.0 * 80.0 - 80.0)
		AudioSystem.save_audio_settings())
	parent.add_child(_row(text, slider))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l
