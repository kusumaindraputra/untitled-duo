## TutorialCoach — an in-combat checklist that teaches the fast-pace moves by doing.
##
## Six steps (move, cast, dash, Perfect Dodge, Perfect Cast, Special) tick off when
## the player actually performs them, in any order. The first unticked step is
## highlighted as the current goal. The coach is visible only during combat, so it
## never covers the preparation grid, and it retires itself once every step is done.
##
## Wiring lives in debug_game_loop._ready() (parent owns cross-node signals). The step
## bookkeeping (notify / is_done / current_step) needs no scene tree, so tests drive
## it headless.
class_name TutorialCoach
extends PanelContainer

## Emitted once, when the last step is ticked.
signal completed

## Step ids, in display order. Copy for each is UICopy.coach_steps[i].
const STEPS: Array[StringName] = [&"move", &"cast", &"dash", &"perfect_dodge", &"perfect_cast", &"special"]
## World px Fayde must travel before "move" ticks (a nudge is not enough).
const MOVE_DISTANCE: float = 90.0
## Seconds the "done" line stays before the panel fades out.
const DONE_HOLD_SEC: float = 2.5

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _COLOR_DONE := Color(0.45, 0.9, 0.55)
const _COLOR_CURRENT := Color(1.0, 0.88, 0.45)
const _COLOR_TODO := Color(0.62, 0.62, 0.7)

## Player node, polled for movement and dashing. Set by the parent.
var player: Node2D = null

var _done: Dictionary[StringName, bool] = {}
var _labels: Array[Label] = []
var _done_label: Label = null
var _last_player_pos: Vector2 = Vector2.INF
var _moved: float = 0.0
var _finished: bool = false


func _init() -> void:
	for id: StringName in STEPS:
		_done[id] = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 240)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.82)
	style.border_color = Color(1.0, 0.85, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override(&"panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 4)
	add_child(vbox)
	var heading := Label.new()
	heading.text = _COPY.coach_heading
	heading.add_theme_font_size_override(&"font_size", 16)
	heading.add_theme_color_override(&"font_color", _COLOR_CURRENT)
	vbox.add_child(heading)
	for i: int in STEPS.size():
		var l := Label.new()
		l.add_theme_font_size_override(&"font_size", 14)
		vbox.add_child(l)
		_labels.append(l)
	_done_label = Label.new()
	_done_label.text = _COPY.coach_done
	_done_label.add_theme_font_size_override(&"font_size", 15)
	_done_label.add_theme_color_override(&"font_color", _COLOR_DONE)
	_done_label.visible = false
	vbox.add_child(_done_label)
	_refresh()


func _process(_delta: float) -> void:
	visible = _finished or _in_combat()
	if not is_instance_valid(player) or not visible:
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
	_refresh()
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


## First unticked step in display order, or &"" when all are done.
func current_step() -> StringName:
	for id: StringName in STEPS:
		if not _done[id]:
			return id
	return &""


# ── Signal adapters (argument lists match the source signals) ─────────────────

func on_cast_started(_spell: SpellEffect) -> void:
	notify(&"cast")


func on_perfect_dodge(_world_pos: Vector2) -> void:
	notify(&"perfect_dodge")


func on_perfect_cast(_world_pos: Vector2, _streak: int) -> void:
	notify(&"perfect_cast")


func on_special_fired(_prana_type_id: int, _world_pos: Vector2, _radius: float) -> void:
	notify(&"special")


func _refresh() -> void:
	if _labels.is_empty():
		return
	var current: StringName = current_step()
	for i: int in STEPS.size():
		var id: StringName = STEPS[i]
		var text: String = _COPY.coach_steps[i] if i < _COPY.coach_steps.size() else String(id)
		var l: Label = _labels[i]
		if _done[id]:
			l.text = "✔  " + text
			l.add_theme_color_override(&"font_color", _COLOR_DONE)
		elif id == current:
			l.text = "▶  " + text
			l.add_theme_color_override(&"font_color", _COLOR_CURRENT)
		else:
			l.text = "○  " + text
			l.add_theme_color_override(&"font_color", _COLOR_TODO)


func _show_done() -> void:
	if _done_label == null or not is_inside_tree():
		return
	_done_label.visible = true
	var tw: Tween = create_tween()
	tw.tween_interval(DONE_HOLD_SEC)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _in_combat() -> bool:
	var gsm: Node = get_node_or_null(^"/root/GameStateManager")
	return gsm != null and gsm.get_active_state() == GameEnums.GameState.COMBAT_PHASE
