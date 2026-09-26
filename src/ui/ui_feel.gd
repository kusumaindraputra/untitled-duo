## UIFeel — menu sounds, screen fades and typewriter timing (beta plan U9).
##
## Autoload. Every Button that enters the tree gets a confirm sound on press, focus
## moves play a soft tick, and ui_cancel plays a back sound. All three go through
## AudioSystem.play_event (UI bus), so the UI volume slider covers them. Focus changes
## in the first frames after new UI appears are silent, so opening a screen (which
## grabs focus) does not tick.
##
## [method fade_in] and [method typewriter_chars] are shared by the overlays; both
## respect the Reduce motion setting (GameSettings.motion_reduced()).
extends Node

## Audio events, registered in assets/data/audio_event_registry.tres.
const EVENT_FOCUS: StringName = &"ui_focus"
const EVENT_CONFIRM: StringName = &"ui_confirm"
const EVENT_BACK: StringName = &"ui_back"
## Frames after UI appears during which focus changes stay silent.
const SETTLE_FRAMES: int = 2
## Default fade-in length for overlays, seconds.
const FADE_TIME: float = 0.18
## Typewriter speed, characters per second.
const TYPE_CPS: float = 55.0
## Buttons with this meta set to true make no confirm sound (they play their own).
const SILENT_META: StringName = &"ui_silent"
const _WIRED_META: StringName = &"_ui_feel_wired"

var _last_ui_frame: int = -100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		_play(EVENT_BACK)


## True when a focus change at [param frame] should tick: UI that appeared at
## [param last_ui_frame] has had [constant SETTLE_FRAMES] frames to settle.
static func should_play_focus(frame: int, last_ui_frame: int) -> bool:
	return frame - last_ui_frame > SETTLE_FRAMES


## Characters to show [param elapsed] seconds into typing [param total] characters.
## Returns [param total] once done, or at once when motion is reduced.
static func typewriter_chars(elapsed: float, total: int, reduced: bool = false) -> int:
	if reduced:
		return total
	return clampi(int(elapsed * TYPE_CPS), 0, total)


## Fades [param item] in from transparent over [param duration] seconds, also while
## the tree is paused. With Reduce motion on it is shown at once and null is returned.
static func fade_in(item: CanvasItem, duration: float = FADE_TIME) -> Tween:
	if GameSettings.motion_reduced() or duration <= 0.0 or not item.is_inside_tree():
		item.modulate.a = 1.0
		return null
	item.modulate.a = 0.0
	var tw: Tween = item.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(item, "modulate:a", 1.0, duration)
	return tw


func _on_node_added(node: Node) -> void:
	if node is Control:
		_last_ui_frame = Engine.get_process_frames()
	var b := node as BaseButton
	# Meta flag, not is_connected(): a re-parented button enters the tree again.
	if b != null and not b.has_meta(_WIRED_META):
		b.set_meta(_WIRED_META, true)
		b.pressed.connect(_on_button_pressed.bind(b))


func _on_button_pressed(b: BaseButton) -> void:
	if is_instance_valid(b) and not bool(b.get_meta(SILENT_META, false)):
		_play(EVENT_CONFIRM)


func _on_focus_changed(_control: Control) -> void:
	if should_play_focus(Engine.get_process_frames(), _last_ui_frame):
		_play(EVENT_FOCUS)


func _play(event_name: StringName) -> void:
	if AudioSystem.has_event(event_name):
		AudioSystem.play_event(event_name)
