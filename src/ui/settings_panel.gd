## SettingsPanel — display, comfort, audio, key and gamepad options (ADR-0026, ADR-0031).
##
## Opened from the main menu and the pause menu. Every change is applied and saved
## at once (GameSettings → user://settings.cfg "game"/"keys", AudioSystem → "audio"),
## so there is no Apply button to forget. Fully keyboard / gamepad navigable; Esc
## (or Back) closes it, and Esc while waiting for a key cancels the rebind. Gamepad
## rebinds wait for a pad button; Start or Esc cancels them.
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
var _pad_buttons: Dictionary[StringName, Button] = {}
## Pad action waiting for a button (&"" when none).
var _listening_pad: StringName = &""
var _resolution: OptionButton = null
var _shake_value: Label = null
var _text_size: OptionButton = null
## HUD size choice (ADR-0046).
var _hud_scale: OptionButton = null
## The centred content, shrunk to fit the window at large text sizes (ADR-0032).
var _root: VBoxContainer = null
var _back: Button = null
## Controls grid: action name, key button, pad button per row (ADR-0035).
var _controls_grid: GridContainer = null
## Assist option controls, greyed out while the Assist switch is off.
var _assist_controls: Array[Control] = []


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = GameSettings.active()
	GameSettings.ensure_actions()
	settings.apply_keys()
	_build()
	for child: Node in get_children():
		if child is CanvasItem:
			UIFeel.fade_in(child as CanvasItem)
	_back.grab_focus()
	_fit_later()
	_root.minimum_size_changed.connect(_fit_later)
	get_viewport().size_changed.connect(_fit_later)


## Re-centres the content after it changes size (text size), shrinking it to fit.
func _fit_later() -> void:
	_fit.call_deferred()


func _fit() -> void:
	if is_instance_valid(_root):
		UIFeel.fit_to_viewport(_root)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05, 0.98)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)
	_root = root

	var title := _label(_COPY.settings_title, 40, UIPalette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override(&"separation", 32)
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
	_shake_value = _label("%d%%" % roundi(shake.value), 16, UIPalette.TEXT)
	shake.value_changed.connect(_on_shake_changed)
	var shake_box := HBoxContainer.new()
	shake_box.add_child(shake)
	shake_box.add_child(_shake_value)
	left.add_child(_row(_COPY.settings_screen_shake, shake_box))
	var fl := _check(left, _COPY.settings_reduce_flashes, settings.reduce_flashes)
	fl.toggled.connect(func(on: bool) -> void:
		settings.reduce_flashes = on
		_save())
	var mo := _check(left, _COPY.settings_reduce_motion, settings.reduce_motion)
	mo.toggled.connect(func(on: bool) -> void:
		settings.reduce_motion = on
		_save())
	# ADR-0032: text size for every screen, and outlined bullets.
	_text_size = OptionButton.new()
	for f: float in GameSettings.TEXT_SCALES:
		_text_size.add_item("%d%%" % roundi(f * 100.0))
	_text_size.select(clampi(settings.text_scale_idx, 0, GameSettings.TEXT_SCALES.size() - 1))
	_text_size.item_selected.connect(_on_text_size_selected)
	left.add_child(_row(_COPY.settings_text_size, _text_size))
	var bo := _check(left, _COPY.settings_bullet_outline, settings.bullet_outline)
	bo.name = "BulletOutline"
	bo.toggled.connect(func(on: bool) -> void:
		settings.bullet_outline = on
		_save())


	var middle := _column(columns)
	middle.add_child(_label(_COPY.settings_audio_heading, 20, Color(0.75, 0.8, 1.0)))
	_volume(middle, _COPY.settings_master, AudioSystem.get_master_volume(), AudioSystem.set_master_volume)
	_volume(middle, _COPY.settings_music, AudioSystem.get_music_volume(), AudioSystem.set_music_volume)
	_volume(middle, _COPY.settings_sfx, AudioSystem.get_sfx_volume(), AudioSystem.set_sfx_volume)

	# F2 Assist: a master switch, then damage taken, game speed and auto-dash.
	middle.add_child(_label(_COPY.settings_assist_heading, 20, Color(0.75, 0.8, 1.0)))
	var on_switch := _check(middle, _COPY.settings_assist_enabled, settings.assist_enabled)
	on_switch.name = "AssistEnabled"
	on_switch.toggled.connect(_on_assist_toggled)
	_assist_controls.append(_percent_slider(middle, _COPY.settings_assist_damage,
		GameSettings.ASSIST_DAMAGE_MIN, settings.assist_damage,
		func(v: float) -> void: settings.assist_damage = v))
	_assist_controls.append(_percent_slider(middle, _COPY.settings_assist_speed,
		GameSettings.ASSIST_SPEED_MIN, settings.assist_speed,
		func(v: float) -> void: settings.assist_speed = v))
	var ad := _check(middle, _COPY.settings_assist_auto_dash, settings.assist_auto_dash)
	ad.toggled.connect(func(on: bool) -> void:
		settings.assist_auto_dash = on
		_save())
	_assist_controls.append(ad)
	_refresh_assist()
	middle.add_child(_label(_COPY.settings_assist_note, 14, UIPalette.TEXT_FAINT))

	# ADR-0046: HUD size, card opacity and the run timer. Each change reaches the
	# live HUD at once through the "hud_prefs" group, so it shows from the pause menu.
	middle.add_child(_label(_COPY.settings_hud_heading, 20, Color(0.75, 0.8, 1.0)))
	_hud_scale = OptionButton.new()
	_hud_scale.name = "HudScale"
	for f: float in GameSettings.HUD_SCALES:
		_hud_scale.add_item("%d%%" % roundi(f * 100.0))
	_hud_scale.select(clampi(settings.hud_scale_idx, 0, GameSettings.HUD_SCALES.size() - 1))
	_hud_scale.item_selected.connect(_on_hud_scale_selected)
	middle.add_child(_row(_COPY.settings_hud_scale, _hud_scale))
	_percent_slider(middle, _COPY.settings_hud_opacity, GameSettings.HUD_CARD_OPACITY_MIN,
		settings.hud_card_opacity, func(v: float) -> void:
			settings.hud_card_opacity = v
			_refresh_hud())
	var rt := _check(middle, _COPY.settings_run_timer, settings.show_run_timer)
	rt.name = "RunTimer"
	rt.toggled.connect(func(on: bool) -> void:
		settings.show_run_timer = on
		_save()
		_refresh_hud())

	# Keyboard key and gamepad button side by side (ADR-0031). Movement stays on
	# the left stick, so only dash / cast / special get a pad button.
	var right := _column(columns)
	right.add_child(_label(_COPY.settings_controls_heading, 20, Color(0.75, 0.8, 1.0)))
	# ADR-0035: one grid for the header and every row, so the key and pad columns line
	# up whatever width the longest action name takes at the current text size.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 8)
	grid.add_child(_sized(_label("", 14, Color.WHITE), 104))
	grid.add_child(_sized(_label(_COPY.settings_keyboard_column, 14, UIPalette.TEXT_DIM), 120))
	grid.add_child(_sized(_label(_COPY.settings_gamepad_heading, 14, UIPalette.TEXT_DIM), 90))
	for i: int in GameSettings.REMAPPABLE.size():
		var action: StringName = GameSettings.REMAPPABLE[i]
		var name_text: String = _COPY.settings_action_names[i] \
			if i < _COPY.settings_action_names.size() else String(action)
		grid.add_child(_sized(_label(name_text, 16, UIPalette.TEXT), 104))
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 32)
		b.pressed.connect(_start_listening.bind(action))
		_key_buttons[action] = b
		grid.add_child(b)
		if GameSettings.PAD_REMAPPABLE.has(action):
			var pb := Button.new()
			pb.custom_minimum_size = Vector2(90, 32)
			pb.pressed.connect(_start_listening_pad.bind(action))
			_pad_buttons[action] = pb
			grid.add_child(pb)
		else:
			grid.add_child(_sized(_label(_COPY.settings_pad_stick, 14, UIPalette.TEXT_FAINT), 90))
	right.add_child(grid)
	_controls_grid = grid
	var resets := HBoxContainer.new()
	resets.add_theme_constant_override(&"separation", 10)
	var reset := Button.new()
	reset.text = _COPY.settings_reset_keys
	reset.pressed.connect(_on_reset_keys)
	resets.add_child(reset)
	var reset_pad := Button.new()
	reset_pad.text = _COPY.settings_reset_pad
	reset_pad.pressed.connect(_on_reset_pad)
	resets.add_child(reset_pad)
	right.add_child(resets)
	_percent_slider(right, _COPY.settings_rumble, 0.0, settings.rumble,
		func(v: float) -> void: settings.rumble = v)
	right.add_child(_label(_COPY.settings_gamepad_note, 14, UIPalette.TEXT_FAINT))

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
	if _listening_pad != &"":
		_listen_pad_input(event)
		return
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


## While a pad action waits: a bindable button binds it (swapping on conflict),
## Start or Esc cancels, anything else is swallowed so menus do not move.
func _listen_pad_input(event: InputEvent) -> void:
	var joy := event as InputEventJoypadButton
	var key := event as InputEventKey
	if joy != null and joy.pressed:
		get_viewport().set_input_as_handled()
		if joy.button_index != JOY_BUTTON_START:
			if not rebind_pad_with_swap(_listening_pad, joy.button_index):
				return  # not a bindable button: keep waiting
		_listening_pad = &""
		_refresh_keys()
	elif key != null and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		if key.keycode == KEY_ESCAPE:
			_listening_pad = &""
			_refresh_keys()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventKey:
		get_viewport().set_input_as_handled()


## Binds pad [param action] to [param button]. If another pad action already uses it,
## that one takes [param action]'s old button. Returns false for a button that is not
## in GameSettings.PAD_BINDABLE.
func rebind_pad_with_swap(action: StringName, button: JoyButton) -> bool:
	if not GameSettings.PAD_BINDABLE.has(button):
		return false
	var other: StringName = GameSettings.action_using_pad(button)
	if other == action:
		return true
	var old_button: JoyButton = GameSettings.pad_button(action)
	settings.rebind_pad(action, button)
	if other != &"" and old_button != JOY_BUTTON_INVALID:
		settings.rebind_pad(other, old_button)
	_save()
	return true


func _start_listening_pad(action: StringName) -> void:
	_listening_pad = action
	_refresh_keys()


func _on_reset_pad() -> void:
	settings.reset_pad()
	_save()
	_refresh_keys()


func _start_listening(action: StringName) -> void:
	_listening_action = action
	_refresh_keys()


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = _COPY.settings_press_key if action == _listening_action \
			else GameSettings.key_label(action)
	for action: StringName in _pad_buttons:
		_pad_buttons[action].text = _COPY.settings_press_button if action == _listening_pad \
			else InputPrompts.pad_label(action, "—")


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


## Saves the text size and rescales every open screen, this one included.
func _on_text_size_selected(idx: int) -> void:
	settings.text_scale_idx = idx
	_save()
	if is_inside_tree():
		UIFeel.apply_text_scale_tree(get_tree().root, settings.text_scale_value())


## Saves the HUD size and rescales the live HUD.
func _on_hud_scale_selected(idx: int) -> void:
	settings.hud_scale_idx = idx
	_save()
	_refresh_hud()


## Tells every live HUD part to re-read the HUD options (ADR-0046).
func _refresh_hud() -> void:
	if is_inside_tree():
		get_tree().call_group(CombatHUD.HUD_PREFS_GROUP, &"refresh_hud_prefs")


func _on_shake_changed(v: float) -> void:
	settings.screen_shake = v / 100.0
	_shake_value.text = "%d%%" % roundi(v)
	_save()


func _on_assist_toggled(on: bool) -> void:
	settings.assist_enabled = on
	_refresh_assist()
	_save()


## Greys out and locks the Assist options while the switch is off.
func _refresh_assist() -> void:
	for c: Control in _assist_controls:
		var slider := c as Range
		if slider != null:
			slider.editable = settings.assist_enabled
			slider.focus_mode = Control.FOCUS_ALL if settings.assist_enabled else Control.FOCUS_NONE
		var button := c as BaseButton
		if button != null:
			button.disabled = not settings.assist_enabled
		var shown: CanvasItem = c.get_parent() as CanvasItem if slider != null else c
		shown.modulate.a = 1.0 if settings.assist_enabled else 0.45


## True when the Assist options can be changed. Test seam.
func assist_controls_enabled() -> bool:
	return not _assist_controls.is_empty() and (_assist_controls[0] as Range).editable


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
	var l := _label(text, 16, UIPalette.TEXT)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(control)
	return row


## [param control] with a fixed minimum width, for column alignment.
func _sized(control: Control, width: float) -> Control:
	control.custom_minimum_size.x = width
	if control is Label:
		(control as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return control


func _check(parent: Node, text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	parent.add_child(c)
	return c


## A 10 %-step slider from [param min_value] to 100 % with a value label; calls
## [param setter] with the new fraction and saves. Returns the slider.
func _percent_slider(parent: Node, text: String, min_value: float, current: float, setter: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value * 100.0
	slider.max_value = 100.0
	slider.step = 10.0
	slider.value = clampf(current, min_value, 1.0) * 100.0
	slider.custom_minimum_size = Vector2(120, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := _label("%d%%" % roundi(slider.value), 16, UIPalette.TEXT)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % roundi(v)
		setter.call(v / 100.0)
		_save())
	var box := HBoxContainer.new()
	box.add_child(slider)
	box.add_child(value)
	parent.add_child(_row(text, box))
	return slider


func _volume(parent: Node, text: String, current_db: float, setter: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(150, 0)
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
