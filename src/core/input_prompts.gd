## InputPrompts — which device the player used last, and the prompts to match (beta plan U8).
##
## Autoload. Watches every input event (also while the tree is paused): a gamepad button
## or a stick push past [constant STICK_DEADZONE] switches to pad prompts; a key, mouse
## click or a clear mouse move switches back. HUD, prep panel and menus read
## [method pick] / [method key_label] when they build text and connect to
## [signal device_changed] to rebuild it. Keyboard prompts read the live InputMap, so a
## rebound key (ADR-0026 Settings) shows its new name.
extends Node

## The last-used device changed. [param using_pad] is true for a gamepad.
signal device_changed(using_pad: bool)

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
## Stick movement below this does not count as switching to the pad (drift).
const STICK_DEADZONE: float = 0.5
## Mouse movement below this many px per event does not count (desk bumps).
const MOUSE_MIN_MOVE: float = 4.0

## True while the last input came from a gamepad.
var using_pad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	observe(event)


## Updates [member using_pad] from [param event]. Returns true when the device changed.
func observe(event: InputEvent) -> bool:
	var pad: bool = false
	var kbm: bool = false
	if event is InputEventJoypadButton:
		pad = (event as InputEventJoypadButton).pressed
	elif event is InputEventJoypadMotion:
		pad = absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE
	elif event is InputEventKey:
		kbm = (event as InputEventKey).pressed
	elif event is InputEventMouseButton:
		kbm = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion:
		kbm = (event as InputEventMouseMotion).relative.length() >= MOUSE_MIN_MOVE
	if pad and not using_pad:
		using_pad = true
	elif kbm and using_pad:
		using_pad = false
	else:
		return false
	device_changed.emit(using_pad)
	return true


## [param keyboard] or [param pad], whichever matches the last-used device.
func pick(keyboard: String, pad: String) -> String:
	return pad if using_pad else keyboard


## Name of the first keyboard key bound to [param action] (e.g. "Shift"), or
## [param fallback] when the action has no key.
static func key_label(action: StringName, fallback: String = "?") -> String:
	if not InputMap.has_action(action):
		return fallback
	for ev: InputEvent in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k == null:
			continue
		var code: Key = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code != KEY_NONE:
			return OS.get_keycode_string(code)
	return fallback


## The four movement keys joined, e.g. "WASD".
static func move_keys_label() -> String:
	return key_label(&"move_up", "W") + key_label(&"move_left", "A") \
		+ key_label(&"move_down", "S") + key_label(&"move_right", "D")


## Dash prompt under the HUD's dash icon.
func dash_hint() -> String:
	return pick(_COPY.dash_hint_format % key_label(&"dash", "Shift"), _COPY.dash_hint_pad)


## Special meter label when full.
func special_ready() -> String:
	return pick(_COPY.special_ready_format % key_label(&"special", "F"), _COPY.special_ready_pad)


## Second line of the preparation panel's hint.
func prep_controls() -> String:
	return pick(_COPY.prep_controls_format % [key_label(&"prana_place", "E"),
		key_label(&"prana_clear", "Q"), key_label(&"prana_type_cycle", "C")], _COPY.prep_controls_pad)


## One-line control summary for the main menu and title card.
func controls_line() -> String:
	return pick(_COPY.controls_format % [move_keys_label(), key_label(&"dash", "Shift"),
		key_label(&"cast", "Space"), key_label(&"special", "F")], _COPY.controls_pad)
