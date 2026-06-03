# PROTOTYPE — ADR-0013 Verification
# Question: Does the dual-input focus model (gamepad cursor + mouse hover + keyboard Tab)
#           work correctly in Godot 4.6 without cross-interference?
# Date: 2026-06-03
#
# HOW TO RUN:
#   1. Open the main project (D:\Proj\the-last-cipher) in Godot 4.6
#   2. Create a new scene: Scene > New Scene > Other Node > Node (base Node, not Node2D)
#   3. Attach this script to the root Node
#   4. Save as res://prototypes/adr-0013-verification/DualInputVerify.tscn
#   5. Run the scene (F6 or right-click scene > Run)
#
# WHAT TO OBSERVE (see README.md for full pass/fail protocol):
#   - Gamepad d-pad: cursor (yellow border) moves; index printed to Output; no focus movement
#   - Mouse hover: cursor does NOT move; index unchanged
#   - Tab key: engine focus indicator moves on slots; cursor does NOT move
#   - Switch gamepad→mouse: cursor hides automatically

extends Node

# ── Constants ──────────────────────────────────────────────────────────────────
const SLOT_SIZE   := Vector2(80, 80)
const SLOT_COLS   := 3
const SLOT_ROWS   := 3
const GRID_ORIGIN := Vector2(60, 120)
const GRID_GAP    := 8.0

# ── State (the exact variables ADR-0013 mandates) ─────────────────────────────
var _selected_slot_index: int  = 4          # Default: centre slot
var _cursor_visible:      bool = false       # Only true when last input was joypad

# ── Node refs ─────────────────────────────────────────────────────────────────
var _slots:          Array[Control] = []
var _gamepad_cursor: ColorRect
var _status_label:   Label
var _log_label:      Label
var _log_lines:      Array[String] = []
const LOG_MAX := 8

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var root_ctrl := ColorRect.new()
	root_ctrl.color          = Color(0.07, 0.07, 0.12)
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root_ctrl)

	_build_title(root_ctrl)
	_build_grid(root_ctrl)
	_build_cursor(root_ctrl)
	_build_status(root_ctrl)
	_build_instructions(root_ctrl)

	# Position cursor on default slot after one frame (slots may not have size yet)
	await get_tree().process_frame
	_move_cursor_to(_selected_slot_index)

	_log("READY — slide d-pad, hover mouse, press Tab")
	_log("Centre slot (index 4) selected by default.")

# ── Build helpers ─────────────────────────────────────────────────────────────
func _build_title(parent: Control) -> void:
	var t := Label.new()
	t.text     = "ADR-0013 Dual-Input Verification — Godot 4.6"
	t.position = Vector2(16, 12)
	t.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	t.add_theme_font_size_override("font_size", 18)
	parent.add_child(t)

func _build_grid(parent: Control) -> void:
	for i in range(SLOT_ROWS * SLOT_COLS):
		var row := i / SLOT_COLS
		var col := i % SLOT_COLS
		var pos := GRID_ORIGIN + Vector2(col, row) * (SLOT_SIZE + Vector2(GRID_GAP, GRID_GAP))

		var slot := Panel.new()
		slot.position            = pos
		slot.custom_minimum_size = SLOT_SIZE
		slot.size                = SLOT_SIZE

		# ADR-0013 required settings
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.focus_mode   = Control.FOCUS_ALL

		# Index label inside the slot
		var lbl := Label.new()
		lbl.text                     = str(i) + ("  [C]" if i == 4 else "")
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment       = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter             = Control.MOUSE_FILTER_PASS
		slot.add_child(lbl)

		# Connect focus signal to detect keyboard Tab navigation
		slot.focus_entered.connect(_on_slot_focus_entered.bind(i))
		slot.focus_exited.connect(_on_slot_focus_exited.bind(i))

		parent.add_child(slot)
		_slots.append(slot)

func _build_cursor(parent: Control) -> void:
	_gamepad_cursor              = ColorRect.new()
	_gamepad_cursor.custom_minimum_size = SLOT_SIZE + Vector2(6, 6)
	_gamepad_cursor.size         = SLOT_SIZE + Vector2(6, 6)
	_gamepad_cursor.color        = Color(1.0, 0.85, 0.2, 0.0)  # transparent fill
	_gamepad_cursor.visible      = false

	# ADR-0013: must not intercept mouse events
	_gamepad_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Gold border effect: inner transparent rect leaves a 3px border visible
	var inner := ColorRect.new()
	inner.color            = Color(0.07, 0.07, 0.12, 1.0)   # matches background
	inner.position         = Vector2(3, 3)
	inner.size             = SLOT_SIZE
	inner.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	_gamepad_cursor.add_child(inner)

	# Bright gold outline via a second overlay ring
	var ring := ColorRect.new()
	ring.color         = Color(1.0, 0.85, 0.0, 0.9)
	ring.position      = Vector2(3, 3)
	ring.size          = SLOT_SIZE
	ring.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var ring_inner := ColorRect.new()
	ring_inner.color       = Color(0.0, 0.0, 0.0, 0.0)
	ring_inner.position    = Vector2(3, 3)
	ring_inner.size        = SLOT_SIZE - Vector2(6, 6)
	ring_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(ring_inner)
	_gamepad_cursor.add_child(ring)

	parent.add_child(_gamepad_cursor)

func _build_status(parent: Control) -> void:
	_status_label          = Label.new()
	_status_label.position = Vector2(GRID_ORIGIN.x, GRID_ORIGIN.y + SLOT_ROWS * (SLOT_SIZE.y + GRID_GAP) + 16)
	_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	_status_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(_status_label)
	_update_status()

	_log_label          = Label.new()
	_log_label.position = _status_label.position + Vector2(0, 28)
	_log_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	parent.add_child(_log_label)

func _build_instructions(parent: Control) -> void:
	var lines := [
		"",
		"D-PAD    → moves gold cursor (gamepad mode)",
		"MOUSE    → hover over slots (should NOT move cursor index)",
		"TAB      → keyboard focus travels (cursor should NOT move)",
		"GAMEPAD→MOUSE → cursor hides automatically",
		"",
		"Check Output panel for index changes and test results.",
	]
	var y := GRID_ORIGIN.y
	var x := GRID_ORIGIN.x + SLOT_COLS * (SLOT_SIZE.x + GRID_GAP) + 40
	for line in lines:
		var l := Label.new()
		l.text     = line
		l.position = Vector2(x, y)
		l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		parent.add_child(l)
		y += 22

# ── ADR-0013 Input model ───────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# ADR-0013: input mode detection via _input() event type — never polled in _process()
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not _cursor_visible:
			_cursor_visible = true
			_gamepad_cursor.visible = true
			_log("MODE → GAMEPAD (cursor shown)")
			_update_status()

		# D-pad navigation
		if event is InputEventJoypadButton and event.pressed:
			var btn: int = event.button_index
			if btn == JOY_BUTTON_DPAD_RIGHT:
				_navigate_gamepad(Vector2i(1, 0))
			elif btn == JOY_BUTTON_DPAD_LEFT:
				_navigate_gamepad(Vector2i(-1, 0))
			elif btn == JOY_BUTTON_DPAD_DOWN:
				_navigate_gamepad(Vector2i(0, 1))
			elif btn == JOY_BUTTON_DPAD_UP:
				_navigate_gamepad(Vector2i(0, -1))

	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if _cursor_visible:
			_cursor_visible = false
			_gamepad_cursor.visible = false
			_log("MODE → MOUSE (cursor hidden)")
			_update_status()

# ADR-0013: 3×3 torus wrapping — right from col 2 wraps to col 0 of same row; etc.
func _navigate_gamepad(direction: Vector2i) -> void:
	var row: int = _selected_slot_index / SLOT_COLS
	var col: int = _selected_slot_index % SLOT_COLS
	row = (row + direction.y + SLOT_ROWS) % SLOT_ROWS
	col = (col + direction.x + SLOT_COLS) % SLOT_COLS
	var new_index: int = row * SLOT_COLS + col
	_selected_slot_index = new_index
	_move_cursor_to(_selected_slot_index)
	_update_status()
	print("[ADR-0013 TEST] d-pad → index=%d  row=%d col=%d" % [new_index, row, col])

func _move_cursor_to(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot_node: Control = _slots[index]
	# Offset by -3 so the 3px border ring sits outside the slot bounds
	_gamepad_cursor.global_position = slot_node.global_position - Vector2(3, 3)
	_gamepad_cursor.size            = slot_node.size + Vector2(6, 6)

# ── Keyboard accessibility callbacks ──────────────────────────────────────────
func _on_slot_focus_entered(index: int) -> void:
	# Tab/arrow navigation triggers this — cursor must NOT move
	print("[ADR-0013 TEST] Tab focus → slot %d   (cursor index still = %d — should NOT match unless you also moved d-pad)" % [index, _selected_slot_index])
	_log("KB focus: slot %d  (cursor=%d)" % [index, _selected_slot_index])
	# Visual confirmation: highlight the focused slot label
	_slots[index].get_child(0).add_theme_color_override("font_color", Color(0.2, 1.0, 1.0))

func _on_slot_focus_exited(index: int) -> void:
	if index < _slots.size():
		_slots[index].get_child(0).add_theme_color_override("font_color", Color.WHITE)

# ── UI helpers ────────────────────────────────────────────────────────────────
func _update_status() -> void:
	var mode: String = "GAMEPAD" if _cursor_visible else "MOUSE/KB"
	_status_label.text = "Mode: %-10s  _selected_slot_index: %d  cursor_visible: %s" % [
		mode, _selected_slot_index, str(_cursor_visible)
	]

func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > LOG_MAX:
		_log_lines = _log_lines.slice(_log_lines.size() - LOG_MAX)
	if _log_label:
		_log_label.text = "\n".join(_log_lines)
