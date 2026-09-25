## WayshrinePanel — the Rest-room choice (ADR-0026).
##
## After the rest heal, the shrine offers a trade: spend HP to inscribe a sigil, or
## walk on. The panel only asks; the parent pays the HP (HealthAndDamage) and opens
## the sigil offer. Pauses the tree while open and is keyboard / gamepad navigable
## (focus starts on the trade button, or on "Walk on" when Fayde cannot pay).
class_name WayshrinePanel
extends CanvasLayer

## The player chose to pay the price.
signal trade_chosen
## The panel closed (after either choice).
signal closed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

var _trade_button: Button = null
var _leave_button: Button = null


## Builds the panel for a price of [param cost] HP. [param can_pay] disables the trade.
func setup(cost: int, can_pay: bool) -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05, 0.78)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 14)
	add_child(vbox)

	var heading := Label.new()
	heading.text = _COPY.wayshrine_heading
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override(&"font_size", 32)
	heading.add_theme_color_override(&"font_color", Color(0.95, 0.45, 0.45))
	vbox.add_child(heading)

	var body := Label.new()
	body.text = _COPY.wayshrine_body if can_pay else _COPY.wayshrine_too_weak
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override(&"font_size", 18)
	vbox.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 20)
	vbox.add_child(row)

	_trade_button = Button.new()
	_trade_button.text = _COPY.wayshrine_trade_format % cost
	_trade_button.custom_minimum_size = Vector2(200, 56)
	_trade_button.add_theme_font_size_override(&"font_size", 20)
	_trade_button.disabled = not can_pay
	_trade_button.pressed.connect(_on_trade)
	row.add_child(_trade_button)

	_leave_button = Button.new()
	_leave_button.text = _COPY.wayshrine_leave
	_leave_button.custom_minimum_size = Vector2(200, 56)
	_leave_button.add_theme_font_size_override(&"font_size", 20)
	_leave_button.pressed.connect(_close)
	row.add_child(_leave_button)


func _ready() -> void:
	get_tree().paused = true
	if _trade_button != null and not _trade_button.disabled:
		_trade_button.grab_focus()
	elif _leave_button != null:
		_leave_button.grab_focus()


## True when the trade button is enabled (test seam).
func can_trade() -> bool:
	return _trade_button != null and not _trade_button.disabled


func _on_trade() -> void:
	trade_chosen.emit()
	_close()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
