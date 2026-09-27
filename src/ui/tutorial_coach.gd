## TutorialCoach — short tutorial hints, one at a time, when they matter (ADR-0031).
##
## Eight steps. Two belong to the preparation phase (confirm the grid, spell tiers)
## and six to combat (move, cast, dash, Perfect Dodge, Perfect Cast, Special). The
## coach shows only the first unticked step of the phase the game is in, as a single
## line at the bottom centre, so it never covers the floor title (top) or the prep
## panel (right). Steps tick when the player actually does them, in any order; a
## ticked hint flashes a check and the next one slides in. Once every step is done the
## coach says so and retires itself.
##
## Wiring lives in debug_game_loop._start_coach() (parent owns cross-node signals).
## The bookkeeping (notify / is_done / current_step / hint_text) needs no scene tree,
## so tests drive it headless.
class_name TutorialCoach
extends PanelContainer

## Emitted once, when the last step is ticked.
signal completed

enum Phase { NONE, PREP, COMBAT }

## Step ids, in display order. Copy for each is UICopy.coach_steps_kb/_pad[i].
const STEPS: Array[StringName] = [
	&"confirm", &"move", &"cast", &"dash", &"tiers", &"perfect_dodge", &"perfect_cast", &"special",
]
## Phase in which each step's hint is shown (same order as STEPS).
const STEP_PHASES: Array[Phase] = [
	Phase.PREP, Phase.COMBAT, Phase.COMBAT, Phase.COMBAT,
	Phase.PREP, Phase.COMBAT, Phase.COMBAT, Phase.COMBAT,
]
## Action whose key/button fills the hint's %s (&"" = none; "move" uses the move keys).
const STEP_ACTIONS: Array[StringName] = [
	&"prana_confirm", &"move", &"cast", &"dash", &"", &"dash", &"cast", &"special",
]
## World px Fayde must travel before "move" ticks (a nudge is not enough).
const MOVE_DISTANCE: float = 90.0
## Seconds a ticked hint stays (with its check) before the next one shows.
const TICK_HOLD_SEC: float = 0.9
## Seconds the "done" line stays before the panel fades out.
const DONE_HOLD_SEC: float = 2.5

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _COLOR_DONE := UIPalette.GOOD
const _COLOR_HINT := Color(1.0, 0.92, 0.7)
const _COLOR_COUNT := Color(UIPalette.ACCENT, 0.8)

## Player node, polled for movement and dashing. Set by the parent.
var player: Node2D = null

var _done: Dictionary[StringName, bool] = {}
var _count_label: Label = null
var _hint_label: Label = null
## Step on screen now (&"" when none), and seconds left on a ticked hint's check.
var _shown: StringName = &""
var _tick_hold: float = 0.0
var _last_player_pos: Vector2 = Vector2.INF
var _moved: float = 0.0
var _finished: bool = false


func _init() -> void:
	for id: StringName in STEPS:
		_done[id] = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bottom centre: clear of the floor banner (top) and the prep panel (right).
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_bottom = -32.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.85)
	style.border_color = Color(UIPalette.ACCENT, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	add_theme_stylebox_override(&"panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 2)
	add_child(vbox)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override(&"font_size", 12)
	_count_label.add_theme_color_override(&"font_color", _COLOR_COUNT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_count_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override(&"font_size", 17)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint_label)
	InputPrompts.device_changed.connect(_on_device_changed)
	visible = false


func _process(delta: float) -> void:
	if _finished:
		return
	if _tick_hold > 0.0:
		_tick_hold -= delta
		return
	var phase: Phase = _current_phase()
	var step: StringName = current_step(phase)
	visible = step != &""
	if step != _shown:
		_show(step)
	if phase != Phase.COMBAT or not is_instance_valid(player):
		_last_player_pos = Vector2.INF
		return
	if not _done[&"move"]:
		if _last_player_pos != Vector2.INF:
			_moved += player.global_position.distance_to(_last_player_pos)
			if _moved >= MOVE_DISTANCE:
				notify(&"move")
		_last_player_pos = player.global_position
	if not _done[&"dash"] and player.has_method(&"is_dashing") and player.is_dashing():
		notify(&"dash")


## Ticks [param step]. Unknown or already-ticked steps are ignored. Returns true
## when this call ticked a step.
func notify(step: StringName) -> bool:
	if not _done.has(step) or _done[step]:
		return false
	_done[step] = true
	Sfx.play(&"sfx_orb_pickup")
	if step == _shown and _hint_label != null:
		_hint_label.text = "✔  " + _hint_label.text
		_hint_label.add_theme_color_override(&"font_color", _COLOR_DONE)
		_tick_hold = TICK_HOLD_SEC
	if is_done() and not _finished:
		_finished = true
		completed.emit()
		_show_done()
	return true


func is_step_done(step: StringName) -> bool:
	return _done.get(step, false)


func is_done() -> bool:
	for id: StringName in STEPS:
		if not _done[id]:
			return false
	return true


## First unticked step, in display order, whose hint belongs to [param phase];
## &"" when none is left or the phase is NONE.
func current_step(phase: Phase = Phase.COMBAT) -> StringName:
	if phase == Phase.NONE:
		return &""
	for i: int in STEPS.size():
		if STEP_PHASES[i] == phase and not _done[STEPS[i]]:
			return STEPS[i]
	return &""


## Ticks [param steps] quietly (no sound, no check flash), e.g. the lessons the guided
## first room already taught (ADR-0055). Emits [signal completed] if nothing is left.
func pretick(steps: Array[StringName]) -> void:
	for id: StringName in steps:
		if _done.has(id):
			_done[id] = true
	if is_done() and not _finished:
		_finished = true
		completed.emit()
		_show_done()


## Number of ticked steps.
func done_count() -> int:
	var n: int = 0
	for id: StringName in STEPS:
		if _done[id]:
			n += 1
	return n


## Hint line for [param step] on the keyboard or the pad, with the bound key or
## button filled in. Empty for an unknown step.
static func hint_text(step: StringName, pad: bool) -> String:
	var i: int = STEPS.find(step)
	if i < 0:
		return ""
	var lines: Array[String] = _COPY.coach_steps_pad if pad else _COPY.coach_steps_kb
	var text: String = lines[i] if i < lines.size() else String(step)
	if not text.contains("%s"):
		return text
	var action: StringName = STEP_ACTIONS[i]
	var label: String
	if action == &"move":
		label = InputPrompts.move_keys_label()
	elif pad:
		label = InputPrompts.pad_label(action)
	else:
		label = InputPrompts.key_label(action)
	return text % label


# ── Signal adapters (argument lists match the source signals) ─────────────────

## Leaving the preparation phase means the grid was confirmed: ticks the prep hint
## on screen (the first one left).
func on_combat_started(_is_boss: bool) -> void:
	var step: StringName = current_step(Phase.PREP)
	if step != &"":
		notify(step)


func on_cast_started(_spell: SpellEffect) -> void:
	notify(&"cast")


func on_perfect_dodge(_world_pos: Vector2) -> void:
	notify(&"perfect_dodge")


func on_perfect_cast(_world_pos: Vector2, _streak: int) -> void:
	notify(&"perfect_cast")


func on_special_fired(_prana_type_id: int, _world_pos: Vector2, _radius: float) -> void:
	notify(&"special")


## Rebuilds the hint on screen with the new device's key or button.
func _on_device_changed(_using_pad: bool) -> void:
	if _tick_hold <= 0.0:
		_show(_shown)


func _show(step: StringName) -> void:
	_shown = step
	if _hint_label == null or step == &"":
		return
	_count_label.text = _COPY.coach_heading % [done_count() + 1, STEPS.size()]
	_hint_label.text = hint_text(step, InputPrompts.using_pad)
	_hint_label.add_theme_color_override(&"font_color", _COLOR_HINT)
	UIFeel.fade_in(self)


func _show_done() -> void:
	if _hint_label == null or not is_inside_tree():
		return
	visible = true
	_count_label.text = ""
	_hint_label.text = _COPY.coach_done
	_hint_label.add_theme_color_override(&"font_color", _COLOR_DONE)
	var tw: Tween = create_tween()
	tw.tween_interval(DONE_HOLD_SEC)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _current_phase() -> Phase:
	var gsm: Node = get_node_or_null(^"/root/GameStateManager")
	if gsm == null:
		return Phase.NONE
	match gsm.get_active_state():
		GameEnums.GameState.PREPARATION_PHASE:
			return Phase.PREP
		GameEnums.GameState.COMBAT_PHASE:
			return Phase.COMBAT
	return Phase.NONE
