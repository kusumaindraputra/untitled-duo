## RunTimerLabel — the optional run clock in the HUD's bottom-left corner (ADR-0046).
##
## Off by default; the "Show run timer" setting turns it on. It shows the same wall
## clock the Records keep (RunManager.get_elapsed_sec, formatted like the best-run
## time), so the number on screen is the number a record would save.
##
## Bottom-left because every other corner is taken at some point (the card top-left,
## the floor map and prep panel on the right). Corner toasts stack above it through
## corner_height().
##
## Display only: the clock arrives as an injected Callable, so the label never reads
## game state itself and tests drive it with a fake clock.
class_name RunTimerLabel
extends Label

## Group the Settings panel calls refresh_hud_prefs() on.
const HUD_PREFS_GROUP: StringName = &"hud_prefs"
## Gap from the screen corner in px, and the text size before any scaling.
const MARGIN: float = 12.0
const FONT_SIZE: int = 18

## Returns the run time in seconds. Unset (no clock) keeps the label hidden.
var clock: Callable = Callable()
var _hud_scale: float = 1.0
var _enabled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override(&"font_size", FONT_SIZE)
	add_theme_color_override(&"font_color", UIPalette.TEXT)
	add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_theme_constant_override(&"outline_size", 4)
	add_to_group(HUD_PREFS_GROUP)
	refresh_hud_prefs()


func _process(_delta: float) -> void:
	refresh()


## Re-reads the timer switch and HUD scale from GameSettings.
func refresh_hud_prefs() -> void:
	_enabled = GameSettings.run_timer_on()
	_hud_scale = GameSettings.hud_scale()
	scale = Vector2(_hud_scale, _hud_scale)
	refresh()


## Updates the text and corner position from the clock. Test seam.
func refresh() -> void:
	visible = _enabled and clock.is_valid()
	if not visible:
		return
	text = RunSummaryPanel.format_time(maxf(float(clock.call()), 0.0))
	size = get_combined_minimum_size()
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1152, 648)
	position = Vector2(MARGIN, view.y - size.y * _hud_scale - MARGIN)


## Height the timer takes from the bottom edge in px, margin included; 0 when hidden.
func corner_height() -> float:
	return size.y * _hud_scale + MARGIN if visible else 0.0
