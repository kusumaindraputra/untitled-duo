## TitleGlow — makes the game title breathe in the Prana palette (art bible §2.1).
##
## Add as a child of a Label. Each frame it sets the label's font colour from
## [method UIPalette.title_glow]: a slow cycle through the five Prana colours with one
## breath every two seconds. With reduced motion it sets one still colour and stops.
class_name TitleGlow
extends Node

var _time: float = 0.0
var _colors: Array[Color] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for type_id: int in PranaCatalog.type_count():
		_colors.append(PranaCatalog.get_type_color(type_id))
	_apply()
	if GameSettings.motion_reduced():
		set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_apply()


func _apply() -> void:
	var label := get_parent() as Label
	if label != null:
		label.add_theme_color_override(&"font_color", UIPalette.title_glow(_time, _colors))
