## input_prompts_device_test.gd — Button prompts follow the last-used device (beta plan U8).
##
## Coverage:
##   IP-01: a pad button switches to pad prompts; a key switches back; each emits once
##   IP-02: stick drift below the deadzone and tiny mouse moves do not switch
##   IP-03: keyboard prompts show the key bound in the InputMap (rebinds included)
##   IP-04: pad prompts use the pad copy
##   IP-05: the HUD dash hint and prep hint rebuild on a device switch
##   IP-06: pad prompts name the button bound in the InputMap (ADR-0031 rebinds)
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const Tracker = preload("res://src/core/input_prompts.gd")
const CombatHUDScript = preload("res://src/ui/combat_hud.gd")
const TEST_ACTION: StringName = &"test_prompt_action"


func after_test() -> void:
	if InputMap.has_action(TEST_ACTION):
		InputMap.erase_action(TEST_ACTION)
	InputPrompts.using_pad = false


func _pad_button() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	return e


func _key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	return e


# ── IP-01 ─────────────────────────────────────────────────────────────────────

func test_input_prompts_pad_then_key_switches_and_emits_once_each() -> void:
	var t: Node = Tracker.new()
	var seen: Array[bool] = []
	t.device_changed.connect(func(p: bool) -> void: seen.append(p))

	assert_bool(t.observe(_pad_button())).is_true()
	assert_bool(t.observe(_pad_button())).is_false()
	assert_bool(t.observe(_key())).is_true()

	assert_array(seen).contains_exactly([true, false])
	t.free()


# ── IP-02 ─────────────────────────────────────────────────────────────────────

func test_input_prompts_small_stick_and_mouse_moves_do_not_switch() -> void:
	var t: Node = Tracker.new()
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.2

	assert_bool(t.observe(drift)).is_false()
	t.using_pad = true
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(1, 1)
	assert_bool(t.observe(nudge)).is_false()
	assert_bool(t.using_pad).is_true()
	t.free()


# ── IP-03 ─────────────────────────────────────────────────────────────────────

func test_input_prompts_key_label_reads_input_map() -> void:
	InputMap.add_action(TEST_ACTION)
	var k := InputEventKey.new()
	k.keycode = KEY_G
	InputMap.action_add_event(TEST_ACTION, k)

	assert_str(Tracker.key_label(TEST_ACTION)).is_equal("G")
	assert_str(Tracker.key_label(&"no_such_action_xyz", "Z")).is_equal("Z")


# ── IP-04 ─────────────────────────────────────────────────────────────────────

func test_input_prompts_pad_uses_pad_copy() -> void:
	var t: Node = Tracker.new()
	t.using_pad = true

	assert_str(t.dash_hint()).is_equal(COPY.dash_hint_pad % Tracker.pad_label(&"dash", "X"))
	assert_str(t.special_ready()).is_equal(COPY.special_ready_pad % Tracker.pad_label(&"special", "Y"))
	assert_str(t.controls_line()).is_equal(COPY.controls_pad % [Tracker.pad_label(&"dash", "X"),
		Tracker.pad_label(&"cast", "A"), Tracker.pad_label(&"special", "Y")])
	t.using_pad = false
	assert_str(t.dash_hint()).is_equal(COPY.dash_hint_format % Tracker.key_label(&"dash", "Shift"))
	t.free()


# ── IP-05 ─────────────────────────────────────────────────────────────────────

func test_hud_dash_hint_follows_device() -> void:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)

	InputPrompts.using_pad = true
	hud._on_device_changed(true)

	assert_str(hud._dash_hint_label.text).is_equal(COPY.dash_hint_pad % Tracker.pad_label(&"dash", "X"))
	remove_child(hud)
	hud.free()


func test_prep_hint_follows_device() -> void:
	var pg := PranaGrid.new()
	pg._hint_label = Label.new()

	InputPrompts.using_pad = true
	pg._on_device_changed(true)

	assert_str(pg._hint_label.text).is_equal(COPY.prep_hint + "\n" + COPY.prep_controls_pad)
	pg._hint_label.free()
	pg.free()


# ── IP-06 ─────────────────────────────────────────────────────────────────────

func test_input_prompts_pad_label_follows_bound_button() -> void:
	InputMap.add_action(TEST_ACTION)
	assert_str(Tracker.pad_label(TEST_ACTION, "?")).is_equal("?")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event(TEST_ACTION, joy)
	assert_str(Tracker.pad_label(TEST_ACTION)).is_equal("RB")
	assert_str(Tracker.button_name(JOY_BUTTON_X)).is_equal("X")


func test_input_prompts_remembers_last_pad_device() -> void:
	var t: Node = Tracker.new()
	var e := _pad_button()
	e.device = 2
	t.observe(e)
	assert_int(t.pad_device).is_equal(2)
	t.free()
