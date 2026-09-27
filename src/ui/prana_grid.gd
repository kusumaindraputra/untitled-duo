## PranaGrid — 9-slot Prana arrangement grid for the Preparation Phase (GDD prana-grid.md).
##
## Owns the 9-slot arrangement array, grid phase state (ARRANGEMENT / LOCKED / HIDDEN),
## and the [signal arrangement_confirmed] payload passed to CombinationResolution on
## combat start. Implements a three-path input model (ADR-0013): mouse drag-and-drop
## (Story 002), gamepad d-pad cursor (Story 004), keyboard Tab accessibility (engine).
##
## All UI child nodes are created programmatically in _create_ui_nodes() — no .tscn
## children required (follows CombatHUD pattern). Tests instantiate via .new() and
## call handlers directly; _ready() is not called in headless unit tests.
##
## Lives as a child of PranaGridLayer (CanvasLayer layer 1) in main.tscn.
## State resets on each room load via [signal GameStateManager.preparation_started].
class_name PranaGrid
extends Control  # Never Container — ADR-0013 hard constraint

## Emitted when the player confirms a valid arrangement (slot 4 non-null).
## Consumed by GameStateManager to trigger PREPARATION → COMBAT transition.
signal arrangement_confirmed

## Number of slots in the grid (3×3).
const GRID_SIZE := 9

## Centralized player-facing copy for the preparation panel (staged for localization
## — see /localize). Preloaded so it resolves without _ready() in headless tests.
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
## Quick-continue toggle (ADR-0019).
const _PACE: PaceTuning = preload("res://assets/data/pace_tuning.tres")

## Preparation panel width and slot size in px (U2: smaller panel, room stays visible).
const PANEL_WIDTH := 330.0
const SLOT_SIZE := 54.0
## Lowest panel top in px; the game loop pushes it below the HUD floor map (set_panel_top).
const PANEL_TOP := 44.0
## Space kept below the panel's content, in px.
const PANEL_BOTTOM_PAD := 12.0

## Duration in seconds for the centre-slot error flash indicator (AC-PG-05).
const ERROR_FLASH_DURATION := 0.4

## Grid phase states driven by GameStateManager signals (TR-PG-003).
enum State {
	ARRANGEMENT,  ## Player may place, move, and clear tokens.
	LOCKED,       ## Display-only; committed arrangement is frozen.
	HIDDEN,       ## Grid not visible; initial state before first wave.
}

## Current phase state. Never read this from outside — subscribe to signals.
var _state: State = State.HIDDEN

## Slot contents. Length always GRID_SIZE. null = empty. Integer type_id = filled.
## Written in Story 002 (placement/clear). Read by _on_confirm_pressed() to build
## _committed_fragments. PranaFragment objects live only in _committed_fragments.
var _slots: Array[Variant] = []

## Confirmed arrangement as PranaFragment objects. Length always GRID_SIZE.
## null entries indicate empty slots. Written only by _on_confirm_pressed().
## Read-only by convention — CombinationResolution and SCE access via getter (TR-PG-002).
var _committed_fragments: Array[PranaFragment] = []

## Type last chosen via fill_all(). Persists across waves so prep auto-fills.
## 0 = Ashfire (default). Reset to 0 only at run start (not wave start).
var _last_fill_type_id: int = 0

## Countdown timer for the centre-slot error flash indicator (AC-PG-05).
## Counts down in _process(). Zero means no flash is active.
var _error_flash_timer: float = 0.0

## Error label shown when confirm is attempted with slot 4 empty (AC-PG-05).
## Null in headless tests (._ready() not called) and before the scene node is wired.
var _error_label: Label = null

## Live PranaGridSlot nodes, indexed 0–8. Empty until _create_ui_nodes() runs.
## Guards in _place_token/_clear_slot check size before accessing.
var _slot_nodes: Array[PranaGridSlot] = []

## Confirm button reference. Null in headless tests — all callers guard with != null.
var _confirm_button: Button = null

## Build readout (RichTextLabel) showing what the current arrangement resolves to —
## primary element + tier and active non-primary modifiers (Stage 3). Null in headless.
var _build_readout_label: RichTextLabel = null

## Warning shown when the grid is full and the bag still holds Prana — prompts the
## player to right-click a slot to discard and make room (Stage 4, rule #5). Null headless.
var _full_grid_hint: Label = null
## Quick-continue hint (ADR-0019); visible when is_quick_continue_available().
var _quick_hint: Label = null

## Full-size grid panel reference. Null in headless tests. Hidden during LOCKED state.
var _grid_panel: Control = null
## The panel's VBox; its minimum height sizes the panel to its content (U2). Null headless.
var _panel_layout: VBoxContainer = null
## Gamepad strip ("PAD: …"); shown only while the slot cursor is in use (U2). Null headless.
var _gp_strip: HBoxContainer = null
## Prep hint under the header; its controls line follows the last-used device (U8).
var _hint_label: Label = null

## Compact 3×3 indicator shown in LOCKED state instead of the full grid panel.
## Null in headless tests. mouse_filter = MOUSE_FILTER_IGNORE (AC-CG-07).
var _compact_indicator: Control = null

## ColorRect dot nodes for the compact indicator, indexed 0–8.
var _dot_nodes: Array[ColorRect] = []

## Gamepad: currently selected slot index. Default: 4 (centre slot). (ADR-0013)
var _selected_slot_index: int = 4
## Gamepad: overlay visibility — true when last input was joypad. Event-driven, never polled. (ADR-0013)
var _cursor_visible: bool = false
## Gamepad cursor overlay Control. Created in _create_ui_nodes(); repositioned on each d-pad press. (ADR-0013)
var _gamepad_cursor: Control = null
## Type indicator label displayed in the gamepad HUD strip. Null in headless tests.
var _type_indicator_label: Label = null

## Bag UI: HBoxContainer holding one draggable token per PranaBag fragment. Null headless.
var _bag_container: HBoxContainer = null
## Bag UI: header label showing the bag count ("YOUR PRANA (n)"). Null headless.
var _bag_label: Label = null
## Bag Prana type currently selected for click-to-place / gamepad placement (-1 = none).
## Shared by the mouse click-to-place path and the gamepad cycle/place path.
var _selected_bag_type: int = -1


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_PASS  # root passes events to children; _gui_input handled by slots/tokens/buttons
	# Stretch to viewport so GUI hit-testing on child Controls works.
	# Without explicit size, the root Control rect is (0,0,0,0) which can block
	# Viewport._gui_call_input() from dispatching events to children.
	size = get_viewport_rect().size
	_slots.resize(GRID_SIZE)
	_slots.fill(null)
	_committed_fragments.resize(GRID_SIZE)
	add_to_group(&"prana_grid")
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.grid_locked.connect(_on_grid_locked)
	GameStateManager.grid_hidden.connect(_on_grid_hidden)
	arrangement_confirmed.connect(GameStateManager.receive_arrangement_confirmed)
	InputPrompts.device_changed.connect(_on_device_changed)
	PranaCatalog.palette_changed.connect(_on_palette_changed)
	_create_ui_nodes()
	visible = false
	# Initialize gamepad cursor position after first layout pass. (ADR-0013: must defer
	# global_position read until layout is complete.)
	await get_tree().process_frame
	if _gamepad_cursor != null:
		_gamepad_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_move_cursor_to(_selected_slot_index)
		_gamepad_cursor.visible = false


func _exit_tree() -> void:
	if arrangement_confirmed.is_connected(GameStateManager.receive_arrangement_confirmed):
		arrangement_confirmed.disconnect(GameStateManager.receive_arrangement_confirmed)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.grid_locked.is_connected(_on_grid_locked):
		GameStateManager.grid_locked.disconnect(_on_grid_locked)
	if GameStateManager.grid_hidden.is_connected(_on_grid_hidden):
		GameStateManager.grid_hidden.disconnect(_on_grid_hidden)
	if PranaCatalog.palette_changed.is_connected(_on_palette_changed):
		PranaCatalog.palette_changed.disconnect(_on_palette_changed)


## Recolours slots, bag tokens and dots when the colour-blind palette changes in
## the pause menu's Settings (ADR-0047).
func _on_palette_changed() -> void:
	for i: int in _slot_nodes.size():
		var slot := _slot_nodes[i] as PranaGridSlot
		slot.refresh(-1 if _slots[i] == null else int(_slots[i]))
	_refresh_bag_tray()
	_update_compact_dots()


## Detects input mode switch (gamepad ↔ mouse/keyboard) and dispatches d-pad navigation
## and gamepad actions. Mode detection is event-driven — never polled in _process(). (ADR-0013)
## Forbidden: grab_focus() must NEVER be called from any branch of this handler.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_cursor_visible(true)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_cursor_visible(false)
	elif event is InputEventKey and not event.echo and event.pressed and _is_grid_nav_key(event):
		# Keyboard players drive the same slot cursor as the gamepad. Only grid-relevant
		# keys flip the cursor on, so ordinary typing/shortcuts don't reveal it.
		_set_cursor_visible(true)
	# Motion events have no "just pressed" state — skip all action checks.
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return
	# Keyboard confirm bypass — works regardless of _cursor_visible (Enter key via debug_game_loop).
	if _state == State.ARRANGEMENT and Input.is_action_just_pressed(&"prana_confirm"):
		_on_confirm_pressed()
		return
	# ADR-0019 quick continue: the cast key (Space) starts the room when nothing changed.
	# Keys only — the cast action also carries the mouse / pad buttons the grid uses.
	if event is InputEventKey and event.is_action_pressed(&"cast") and is_quick_continue_available():
		_on_confirm_pressed()
		return
	if not (_cursor_visible and _state == State.ARRANGEMENT):
		return
	if Input.is_action_just_pressed(&"ui_left"):
		_navigate_gamepad(Vector2i(-1, 0))
	elif Input.is_action_just_pressed(&"ui_right"):
		_navigate_gamepad(Vector2i(1, 0))
	elif Input.is_action_just_pressed(&"ui_up"):
		_navigate_gamepad(Vector2i(0, -1))
	elif Input.is_action_just_pressed(&"ui_down"):
		_navigate_gamepad(Vector2i(0, 1))
	elif Input.is_action_just_pressed(&"prana_type_cycle"):
		_cycle_selected_type()
	elif Input.is_action_just_pressed(&"prana_place"):
		_gamepad_place()
	elif Input.is_action_just_pressed(&"prana_clear"):
		_gamepad_clear()
	elif Input.is_action_just_pressed(&"prana_confirm"):
		_on_confirm_pressed()


## Shows or hides the slot cursor and the gamepad strip together. The strip only means
## something while the cursor drives placement, so mouse players never see it (U2).
func _set_cursor_visible(on: bool) -> void:
	var changed: bool = on != _cursor_visible
	_cursor_visible = on
	if _gamepad_cursor != null:
		_gamepad_cursor.visible = on
	if _gp_strip != null and changed:
		_gp_strip.visible = on
		_queue_fit_panel()


## True when [param event] matches a grid keyboard control (arrow navigation or the
## place/clear/cycle keys), used to reveal the slot cursor for keyboard-only players.
func _is_grid_nav_key(event: InputEvent) -> bool:
	return event.is_action(&"ui_left") or event.is_action(&"ui_right") \
		or event.is_action(&"ui_up") or event.is_action(&"ui_down") \
		or event.is_action(&"prana_place") or event.is_action(&"prana_clear") \
		or event.is_action(&"prana_type_cycle")


## Ticks the error-flash timer and hides the error label when it expires (AC-PG-05).
## No-op when no flash is active.
func _process(delta: float) -> void:
	if _error_flash_timer > 0.0:
		_error_flash_timer -= delta
		if _error_flash_timer <= 0.0:
			_error_flash_timer = 0.0
			if _error_label != null:
				_error_label.visible = false


## Fills all 9 slots with [param type_id] during ARRANGEMENT state.
## Remembers the choice in [member _last_fill_type_id] for the next wave's auto-fill.
## No-op outside ARRANGEMENT — grid must be in prep phase.
func fill_all(type_id: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_last_fill_type_id = type_id
	_slots.fill(type_id)
	for i in _slot_nodes.size():
		var slot := _slot_nodes[i] as PranaGridSlot
		slot.refresh(type_id)
		_pop_slot_scale(slot)
	_update_confirm_button()


## Restores the persistent build from PranaLoadout (the grid is rebuilt per room, so
## the run's build lives in the loadout holder) and enters ARRANGEMENT state. When no
## loadout exists (headless tests / standalone), starts from an empty grid.
## Called on every new wave start, from any prior state.
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	var loadout: Node = _get_loadout()
	if loadout != null:
		var saved: Array = loadout.get_slots()
		for i in GRID_SIZE:
			_slots[i] = saved[i] if i < saved.size() else null
	else:
		_slots.fill(null)
	_committed_fragments.fill(null)
	_state = State.ARRANGEMENT
	if _compact_indicator != null:
		_compact_indicator.visible = false
	if _grid_panel != null:
		_grid_panel.visible = true
	for i in _slot_nodes.size():
		var v: Variant = _slots[i]
		(_slot_nodes[i] as PranaGridSlot).refresh(v if v != null else -1)
	_selected_bag_type = -1
	_refresh_bag_tray()
	_update_confirm_button()
	visible = true


## PranaBag.bag_changed adapter (wired by the game loop): rebuilds the tray when Prana
## land in the bag while the grid is open, e.g. the guided first room's lesson Prana
## (ADR-0055). Other states ignore it; the next preparation phase reads the bag anyway.
func on_bag_changed(_items: Array) -> void:
	if _state == State.ARRANGEMENT:
		_refresh_bag_tray()


## Resolves the persistent PranaLoadout via group, or null if none (tests).
func _get_loadout() -> Node:
	return get_tree().get_first_node_in_group(&"prana_loadout") if is_inside_tree() else null


## Resolves the run's transient PranaBag via group, or null if none (headless tests).
func _get_bag() -> Node:
	return get_tree().get_first_node_in_group(&"prana_bag") if is_inside_tree() else null


## Transitions to LOCKED state: hides the full panel, shows the compact dot indicator.
## Logs a sequencing error if no arrangement was confirmed this phase
## (committed_fragments all-null — GSM bug guard).
func _on_grid_locked() -> void:
	if _state == State.ARRANGEMENT and _slots[4] == null:
		push_error("PranaGrid: grid_locked received without arrangement_confirmed — committed_fragments all-null (Game State sequencing bug)")
	_state = State.LOCKED
	if _grid_panel != null:
		_grid_panel.visible = false
	_update_compact_dots()
	if _compact_indicator != null:
		_compact_indicator.visible = true


## Transitions to HIDDEN state (between runs or during main menu).
## Restores full opacity so the grid is ready for the next preparation phase.
func _on_grid_hidden() -> void:
	_state = State.HIDDEN
	modulate.a = 1.0
	if _compact_indicator != null:
		_compact_indicator.visible = false
	visible = false


## Called when the Confirm button is pressed (TR-PG-004).
##
## Guard: slot 4 (centre) must be non-null. If empty, fires the error flash
## indicator (AC-PG-05) and returns without emitting.
##
## On success: builds _committed_fragments (length GRID_SIZE, nulls for empty slots,
## PranaFragment for filled slots) and emits [signal arrangement_confirmed] (AC-PG-03).
func _on_confirm_pressed() -> void:
	if _slots[4] == null:
		_show_centre_error_indicator()
		return
	var fragments: Array[PranaFragment] = []
	fragments.resize(GRID_SIZE)
	for i in GRID_SIZE:
		if _slots[i] != null:
			var f := PranaFragment.new()
			f.type_id = _slots[i]
			f.level = 1
			f.stat_property = {}
			f.adjacency_effects = []
			fragments[i] = f
		else:
			fragments[i] = null
	_committed_fragments = fragments
	# Persist the build so the next room's grid restores it (the grid is rebuilt
	# per room; the run's loadout lives in the PranaLoadout holder).
	var loadout: Node = _get_loadout()
	if loadout != null:
		loadout.set_slots(_slots)
	# Discard any un-placed bag fragments — the bag is transient to one prep phase.
	var bag: Node = _get_bag()
	if bag != null and bag.has_method(&"clear"):
		bag.clear()
	_selected_bag_type = -1
	_refresh_bag_tray()
	arrangement_confirmed.emit()


## Places [param type_id] into slot [param slot_index] during ARRANGEMENT state.
## Called by PranaGridSlot.drop_data() (drag-and-drop path) and by direct
## placement logic (click-to-place path). No-op outside ARRANGEMENT.
func _place_token(idx: int, type_id: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots[idx] = type_id
	if idx < _slot_nodes.size():
		var slot := _slot_nodes[idx] as PranaGridSlot
		slot.refresh(type_id)
		_pop_slot_scale(slot)
	_update_confirm_button()


## Clears slot [param slot_index] during ARRANGEMENT state (AC-PG-07).
## Called by PranaGridSlot right-click handler. No-op outside ARRANGEMENT.
func _clear_slot(idx: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots[idx] = null
	if idx < _slot_nodes.size():
		(_slot_nodes[idx] as PranaGridSlot).refresh(-1)
	_update_confirm_button()


## Clears all 9 slots during ARRANGEMENT state (AC-PG-08).
## Called by the Clear All button. Confirm button returns to disabled state after this.
func clear_all() -> void:
	if _state != State.ARRANGEMENT:
		return
	_slots.fill(null)
	for i in _slot_nodes.size():
		(_slot_nodes[i] as PranaGridSlot).refresh(-1)
	_update_confirm_button()


# ── Bag-sourced placement (grid-as-build) ──────────────────────────────────────

## Rebuilds the bag tray: clears it and adds one draggable token per fragment in the
## PranaBag, plus updates the header count and gamepad type indicator. No-op when the
## tray container is null (headless tests).
func _refresh_bag_tray() -> void:
	if _bag_container == null:
		return
	for child: Node in _bag_container.get_children():
		child.queue_free()
	var bag: Node = _get_bag()
	var items: Array = bag.get_items() if bag != null and bag.has_method(&"get_items") else []
	if _bag_label != null:
		_bag_label.text = "─── YOUR PRANA (%d) ───" % items.size()
		# An empty bag says nothing useful; hide the tray so the room stays visible (U2).
		_bag_label.visible = not items.is_empty()
	_bag_container.visible = not items.is_empty()
	# Drop a stale selection whose type is no longer in the bag.
	if _selected_bag_type != -1 and not items.has(_selected_bag_type):
		_selected_bag_type = -1
	for tid: int in items:
		var token := PranaTypeToken.new()
		token.type_id = tid
		token.from_bag = true
		token._prana_grid = self
		_bag_container.add_child(token)
	_highlight_selected_bag_token()
	_update_type_indicator()
	_update_full_grid_hint()
	_queue_fit_panel()


## Dims bag tokens whose type isn't the current selection so the selected fragment
## reads clearly. No dimming when nothing is selected. No-op headless.
func _highlight_selected_bag_token() -> void:
	if _bag_container == null:
		return
	for child: Node in _bag_container.get_children():
		var token := child as PranaTypeToken
		if token == null:
			continue
		if _selected_bag_type == -1:
			token.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			token.modulate = Color(1.0, 1.0, 1.0, 1.0) if token.type_id == _selected_bag_type \
				else Color(1.0, 1.0, 1.0, 0.45)


## Selects (or toggles off) a bag Prana type for click-to-place (mouse) and gamepad
## placement. Re-selecting the same type clears the selection. No-op outside ARRANGEMENT.
func _select_bag_type(type_id: int) -> void:
	if _state != State.ARRANGEMENT:
		return
	_selected_bag_type = -1 if _selected_bag_type == type_id else type_id
	_highlight_selected_bag_token()
	_update_type_indicator()


## Places one fragment of [param type_id] from the bag into empty slot [param idx],
## consuming it from the bag. No-op outside ARRANGEMENT, on a filled slot, or when the
## bag holds no such fragment. In headless tests (no bag in the tree) the placement is
## allowed so slot logic stays unit-testable. Returns true on success.
func _place_from_bag(idx: int, type_id: int) -> bool:
	if _state != State.ARRANGEMENT:
		return false
	if idx < 0 or idx >= _slots.size() or _slots[idx] != null:
		return false
	var bag: Node = _get_bag()
	if bag != null and bag.has_method(&"remove_one"):
		if not bag.remove_one(type_id):
			return false
	_slots[idx] = type_id
	if idx < _slot_nodes.size():
		var slot := _slot_nodes[idx] as PranaGridSlot
		slot.refresh(type_id)
		_pop_slot_scale(slot)
	_refresh_bag_tray()
	_update_confirm_button()
	return true


## Click-to-place from a slot's left-click: places the currently selected bag fragment
## into [param idx]. No-op when no bag type is selected.
func _place_selected_bag_into(idx: int) -> void:
	if _selected_bag_type == -1:
		return
	_place_from_bag(idx, _selected_bag_type)


## Returns true when slot 4 (centre) is non-null (TR-PG-006).
## Queried by GameStateManager before the PREPARATION → COMBAT transition.
func is_loadout_valid() -> bool:
	return _slots[4] != null


## ADR-0019 — true when the next room can start with one press: in ARRANGEMENT, the
## centre slot is filled and the bag holds nothing to place (build unchanged).
func is_quick_continue_available() -> bool:
	if not _PACE.quick_continue or _state != State.ARRANGEMENT:
		return false
	if _slots.size() <= 4 or _slots[4] == null:
		return false
	var bag: Node = _get_bag()
	return bag == null or not bag.has_method(&"is_empty") or bag.is_empty()


## Returns the confirmed arrangement as an [Array][PranaFragment] of length 9 (TR-PG-002).
## Empty slots are null. Read-only by convention — do not write to the returned array.
## Consumed by CombinationResolution and SpellCastingEffects after [signal arrangement_confirmed].
func get_committed_fragments() -> Array[PranaFragment]:
	return _committed_fragments


## Starts the centre-slot error flash indicator (AC-PG-05).
## Shows the error label for ERROR_FLASH_DURATION seconds; _process() hides it.
func _show_centre_error_indicator() -> void:
	_error_flash_timer = ERROR_FLASH_DURATION
	if _error_label != null:
		_error_label.visible = true


## Returns the flat slot index for a given [param row] and [param col] (GDD Formula 1).
## Index 4 is always the centre slot (row 1, col 1).
static func slot_index(row: int, col: int) -> int:
	return row * 3 + col


## Returns the row for a given flat [param index] (inverse of Formula 1).
static func slot_row(index: int) -> int:
	return index / 3


## Returns the column for a given flat [param index] (inverse of Formula 1).
static func slot_col(index: int) -> int:
	return index % 3


# ── Private ───────────────────────────────────────────────────────────────────

## Builds all UI child nodes programmatically (follows CombatHUD pattern).
## Called once from _ready(). Headless unit tests use .new() and never call
## _ready(), so this method is never executed in the test harness.
## Player-facing labels read from _COPY (centralized UI copy, staged for localization).
func _create_ui_nodes() -> void:
	# Panel pinned to the right side of the viewport using absolute position+size
	# (same pattern as CombatHUD — anchors on CanvasLayer children are unreliable
	# until the layout pass runs, causing the panel to land off-screen).
	var vp_width := get_viewport_rect().size.x
	var panel := Panel.new()
	panel.position = Vector2(vp_width - PANEL_WIDTH - 16.0, PANEL_TOP)
	panel.size = Vector2(PANEL_WIDTH, 420.0)
	add_child(panel)
	_grid_panel = panel

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override(&"separation", 6)
	layout.offset_left = 10.0
	layout.offset_right = -10.0
	layout.offset_top = 8.0
	panel.add_child(layout)
	_panel_layout = layout
	# Wrapped labels re-measure after the first layout pass; refit whenever content height changes.
	layout.minimum_size_changed.connect(_queue_fit_panel)

	# Header
	var header := Label.new()
	header.text = _COPY.prep_header
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(header)

	var hint := Label.new()
	_hint_label = hint
	hint.text = _prep_hint_text()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override(&"font_size", 13)
	hint.add_theme_color_override(&"font_color", SpellPreview.HINT_COLOR)
	layout.add_child(hint)

	# 3×3 slot grid
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	# ADR-0042 (art bible §3.4): the grid sits in an octagonal frame, slots are circles.
	var frame := PranaGridFrame.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(frame)
	frame.add_child(grid)

	for i in GRID_SIZE:
		var slot := PranaGridSlot.new()
		slot.slot_index = i
		slot._prana_grid = self
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.focus_mode = Control.FOCUS_ALL
		grid.add_child(slot)
		_slot_nodes.append(slot)

	# Spell preview (U1) — the spell this arrangement casts: element, tier, what it does,
	# the next tier, modifiers, reactions and cascade. Updated on every slot mutation
	# via _update_build_readout().
	_build_readout_label = RichTextLabel.new()
	_build_readout_label.bbcode_enabled = true
	_build_readout_label.scroll_active = false
	_build_readout_label.fit_content = true
	_build_readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_readout_label.custom_minimum_size = Vector2(0, 36)
	_build_readout_label.add_theme_font_size_override(&"normal_font_size", 14)
	_build_readout_label.add_theme_font_size_override(&"bold_font_size", 15)
	_build_readout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_build_readout_label)

	# Bag tray — the Prana acquired from post-room rewards, awaiting placement
	# (grid-as-build model). One draggable token per fragment; click to select for
	# click-to-place, or drag onto an empty slot. Populated by _refresh_bag_tray().
	_bag_label = Label.new()
	_bag_label.text = _COPY.bag_label
	_bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_bag_label)

	_bag_container = HBoxContainer.new()
	_bag_container.add_theme_constant_override(&"separation", 4)
	_bag_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(_bag_container)

	# Full-grid swap prompt (Stage 4, rule #5): visible only when the grid is full
	# and the bag still has Prana, telling the player to free a slot first.
	_full_grid_hint = Label.new()
	_full_grid_hint.text = _COPY.full_grid_hint
	_full_grid_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_full_grid_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_full_grid_hint.add_theme_font_size_override(&"font_size", 14)
	_full_grid_hint.add_theme_color_override(&"font_color", UIPalette.ACCENT)
	_full_grid_hint.visible = false
	layout.add_child(_full_grid_hint)

	# Buttons row
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(buttons)

	# Clear All hidden — clearing would wipe the persistent build including the core.
	var clear_btn := Button.new()
	clear_btn.text = _COPY.clear_all_button
	clear_btn.pressed.connect(clear_all)
	clear_btn.visible = false
	buttons.add_child(clear_btn)

	_quick_hint = Label.new()
	_quick_hint.text = InputPrompts.pick(_COPY.quick_continue_hint, _COPY.quick_continue_hint_pad)
	_quick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quick_hint.add_theme_font_size_override(&"font_size", 14)
	_quick_hint.add_theme_color_override(&"font_color", UIPalette.GOOD)
	_quick_hint.visible = false
	layout.add_child(_quick_hint)

	_confirm_button = Button.new()
	_confirm_button.text = _COPY.confirm_button
	_confirm_button.modulate.a = 0.4
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)

	# Error label (hidden until slot 4 empty + confirm attempted)
	_error_label = Label.new()
	_error_label.text = _COPY.error_center_slot
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override(&"font_color", Color("#FF3333"))
	_error_label.visible = false
	layout.add_child(_error_label)

	# Gamepad HUD strip — shows the currently selected Prana type for gamepad placement.
	# Always present in the panel layout; _type_indicator_label updates on every _cycle_selected_type().
	var gp_strip := HBoxContainer.new()
	gp_strip.add_theme_constant_override(&"separation", 8)
	gp_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gp_strip.visible = false
	layout.add_child(gp_strip)
	_gp_strip = gp_strip

	var gp_hint := Label.new()
	gp_hint.text = _COPY.pad_prefix
	gp_strip.add_child(gp_hint)

	_type_indicator_label = Label.new()
	_type_indicator_label.text = _COPY.bag_empty
	_type_indicator_label.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
	gp_strip.add_child(_type_indicator_label)

	# Compact 3×3 dot indicator shown during LOCKED state (AC-CG-04).
	# Added directly to PranaGrid Control (not to panel) so it stays visible when
	# the panel is hidden. Pinned to bottom-right corner with 4px margin.
	_compact_indicator = Control.new()
	_compact_indicator.position = Vector2(vp_width - 68.0, get_viewport_rect().size.y - 68.0)
	_compact_indicator.custom_minimum_size = Vector2(60.0, 60.0)
	_compact_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_grid := GridContainer.new()
	dot_grid.columns = 3
	dot_grid.add_theme_constant_override(&"h_separation", 4)
	dot_grid.add_theme_constant_override(&"v_separation", 4)
	_compact_indicator.add_child(dot_grid)
	for _i in GRID_SIZE:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14.0, 14.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot_grid.add_child(dot)
		_dot_nodes.append(dot)
	add_child(_compact_indicator)
	_compact_indicator.visible = false

	# Gamepad cursor overlay — gold border Panel over the currently selected slot. (ADR-0013)
	# Added to PranaGrid root (not panel) so global_position assignments work without layout
	# interference. mouse_filter set to MOUSE_FILTER_IGNORE in _ready() after process_frame.
	# All anchors default to 0.0 — non-zero anchors offset global_position. (ADR-0013 risk)
	var cursor := Panel.new()
	var cursor_style := StyleBoxFlat.new()
	cursor_style.bg_color = Color(1.0, 1.0, 1.0, 0.0)  # transparent fill
	cursor_style.border_color = Color("#FFD700")          # gold border
	cursor_style.set_border_width_all(3)
	cursor_style.set_corner_radius_all(int(SLOT_SIZE))  # clamps to a circle round the slot
	cursor_style.anti_aliasing = true
	cursor.add_theme_stylebox_override(&"panel", cursor_style)
	cursor.z_index = 10  # renders above slot Panel nodes
	add_child(cursor)
	_gamepad_cursor = cursor


## Syncs the Confirm button appearance and disabled state with slot 4's content.
## No-op when _confirm_button is null (headless test context).
func _update_confirm_button() -> void:
	if _confirm_button == null:
		return
	var valid: bool = _slots.size() > 4 and _slots[4] != null
	_confirm_button.disabled = not valid
	_confirm_button.modulate.a = 1.0 if valid else 0.4
	var quick: bool = is_quick_continue_available()
	_confirm_button.text = _COPY.quick_continue_button if quick else _COPY.confirm_button
	if _quick_hint != null:
		_quick_hint.visible = quick
	_update_build_readout()
	_update_full_grid_hint()


## Refreshes the build readout from the current arrangement via the shared
## CombinationResolution.preview_build rules, so the preview matches what combat
## will produce. No-op when the label is null (headless tests).
func _update_build_readout() -> void:
	if _build_readout_label == null:
		return
	_build_readout_label.text = SpellPreview.to_bbcode(build_spell_card(), _type_colors(), _COPY.type_abbrevs)
	_queue_fit_panel()


## The spell card for the current arrangement (U1), using the same CombinationResolution
## rules combat uses, so the preview matches what is cast. See SpellPreview.build().
func build_spell_card() -> Dictionary:
	var ids: Array = []
	ids.resize(GRID_SIZE)
	var fragments: Array = []
	fragments.resize(GRID_SIZE)
	for i in GRID_SIZE:
		ids[i] = _slots[i]
		if _slots[i] != null:
			var f := PranaFragment.new()
			f.type_id = _slots[i]
			fragments[i] = f
	var summary: Dictionary = CombinationResolution.preview_build(ids)
	var reactions: Array = []
	var cascade: CascadeEffect = null
	if summary["primary_type"] >= 0:
		var recognition: Dictionary = CombinationResolution.compute_recognition(fragments)
		reactions = recognition["reactions"]
		cascade = recognition["cascade"]
	var names: Array = []
	for id: int in PranaTypeToken.type_count():
		var pt: PranaType = PranaCatalog.get_type(id)
		names.append(pt.name if pt != null else PranaTypeToken.type_abbrev(id))
	return SpellPreview.build(summary, reactions, cascade, names, _COPY)


## The current 9 slots as type ids (null = empty), copied. Read by the pause build view (U6).
func get_slot_types() -> Array:
	return _slots.duplicate()


## Prep hint: the instruction line, then controls for the last-used device (U8).
func _prep_hint_text() -> String:
	return _COPY.prep_hint + "\n" + InputPrompts.prep_controls()


func _on_device_changed(_using_pad: bool) -> void:
	if _hint_label != null:
		_hint_label.text = _prep_hint_text()
	if _quick_hint != null:
		_quick_hint.text = InputPrompts.pick(_COPY.quick_continue_hint, _COPY.quick_continue_hint_pad)
	_queue_fit_panel()


## Element colours in type_id order, for views outside the grid (pause build view, U6).
func get_type_colors() -> Array:
	return _type_colors()


## Element colours in type_id order (Art Bible palette via PranaTypeToken).
func _type_colors() -> Array:
	var colors: Array = []
	for id: int in PranaTypeToken.type_count():
		colors.append(PranaTypeToken.type_color(id))
	return colors


## Moves the panel's top edge to [param y] (never above PANEL_TOP) so it clears the HUD
## floor map. Called by the game loop, which owns both nodes.
func set_panel_top(y: float) -> void:
	if _grid_panel == null:
		return
	_grid_panel.position.y = maxf(PANEL_TOP, y)
	_queue_fit_panel()


## Sizes the panel to its content on the next frame, after labels have re-measured (U2).
func _queue_fit_panel() -> void:
	if _grid_panel == null or _panel_layout == null:
		return
	_fit_panel.call_deferred()


## Sets the panel height to its content's minimum height, capped to the viewport.
func _fit_panel() -> void:
	if _grid_panel == null or _panel_layout == null:
		return
	var want: float = _panel_layout.get_combined_minimum_size().y + _panel_layout.offset_top + PANEL_BOTTOM_PAD
	var cap: float = get_viewport_rect().size.y - _grid_panel.position.y - 8.0
	_grid_panel.size.y = minf(want, cap)


## True when every slot holds a fragment (no empty slot remains).
func _is_grid_full() -> bool:
	for v in _slots:
		if v == null:
			return false
	return true


## True when the full-grid swap prompt should show: in ARRANGEMENT, grid full, and
## the bag still holds Prana that cannot be placed until a slot is freed (rule #5).
func _should_show_full_grid_hint() -> bool:
	if _state != State.ARRANGEMENT or not _is_grid_full():
		return false
	var bag: Node = _get_bag()
	return bag != null and bag.has_method(&"is_empty") and not bag.is_empty()


## Syncs the full-grid swap prompt visibility. No-op when the label is null (headless).
func _update_full_grid_hint() -> void:
	if _full_grid_hint == null:
		return
	_full_grid_hint.visible = _should_show_full_grid_hint()


## Scale-pop tween for placed/filled tokens: quick overshoot → settle at 1.0.
## No-op when the slot is not in the tree (headless tests, _create_ui_nodes skipped).
func _pop_slot_scale(slot: PranaGridSlot) -> void:
	if not slot.is_inside_tree():
		return
	slot.scale = Vector2(1.2, 1.2)
	var tw := slot.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.14)


## Updates compact indicator dot colors to match _committed_fragments (AC-CG-04).
## Empty slots show Color("#333333"); filled slots show PranaCatalog.get_type(type_id).color.
## No-op when _dot_nodes is empty (headless test context before _create_ui_nodes() runs).
func _update_compact_dots() -> void:
	if _dot_nodes.is_empty():
		return
	for i in GRID_SIZE:
		var dot: ColorRect = _dot_nodes[i]
		var fragment: PranaFragment = _committed_fragments[i]
		if fragment != null:
			dot.color = PranaCatalog.get_type(fragment.type_id).color
		else:
			dot.color = Color("#333333")


## Moves the gamepad cursor to a new slot using 3x3 torus wrap arithmetic. (ADR-0013, GDD Formula 1)
## direction.x: -1 = left, +1 = right. direction.y: -1 = up, +1 = down.
func _navigate_gamepad(direction: Vector2i) -> void:
	var row: int = _selected_slot_index / 3
	var col: int = _selected_slot_index % 3
	row = (row + direction.y + 3) % 3
	col = (col + direction.x + 3) % 3
	_selected_slot_index = row * 3 + col
	_move_cursor_to(_selected_slot_index)


## Repositions the gamepad cursor overlay over the slot at [param index]. (ADR-0013)
## Reads slot global_position after layout — safe because _ready() awaits process_frame.
func _move_cursor_to(index: int) -> void:
	if _gamepad_cursor == null or _slot_nodes.is_empty():
		return
	var slot_node: Control = _slot_nodes[index]
	_gamepad_cursor.global_position = slot_node.global_position
	_gamepad_cursor.size = slot_node.size


## Cycles the selected bag Prana type through the DISTINCT types currently in the bag
## (gamepad placement source). Sets the selection to -1 when the bag is empty.
func _cycle_selected_type() -> void:
	var bag: Node = _get_bag()
	var items: Array = bag.get_items() if bag != null and bag.has_method(&"get_items") else []
	var distinct: Array[int] = []
	for tid: int in items:
		if not distinct.has(tid):
			distinct.append(tid)
	if distinct.is_empty():
		_selected_bag_type = -1
	else:
		var cur: int = distinct.find(_selected_bag_type)
		_selected_bag_type = distinct[(cur + 1) % distinct.size()]
	_highlight_selected_bag_token()
	_update_type_indicator()


## Places the selected bag fragment into the currently selected slot. Auto-selects the
## first available bag type when none is selected; no-op when the bag is empty.
func _gamepad_place() -> void:
	if _selected_bag_type == -1:
		_cycle_selected_type()
		if _selected_bag_type == -1:
			return
	_place_from_bag(_selected_slot_index, _selected_bag_type)


## Clears (discards) the currently selected slot, freeing it for a new placement.
func _gamepad_clear() -> void:
	_clear_slot(_selected_slot_index)


## Updates the gamepad type indicator to show the selected bag Prana and its remaining
## count, or "BAG EMPTY" when nothing is selectable. Uses PranaTypeToken as the single
## source of truth for the Art Bible palette. (ADR-0013) No-op when the label is null.
func _update_type_indicator() -> void:
	if _type_indicator_label == null:
		return
	if _selected_bag_type < 0 or _selected_bag_type >= PranaTypeToken.type_count():
		# Distinguish a truly empty bag from "bag has Prana but none selected yet".
		var b: Node = _get_bag()
		var has_items: bool = b != null and b.has_method(&"is_empty") and not b.is_empty()
		_type_indicator_label.text = _COPY.select_prana if has_items else _COPY.bag_empty
		_type_indicator_label.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
		return
	var bag: Node = _get_bag()
	var count: int = 0
	if bag != null and bag.has_method(&"get_items"):
		for tid: int in bag.get_items():
			if tid == _selected_bag_type:
				count += 1
	_type_indicator_label.text = "%s ×%d" % [PranaTypeToken.type_abbrev(_selected_bag_type), count]
	_type_indicator_label.add_theme_color_override(&"font_color", PranaTypeToken.type_color(_selected_bag_type))
