## debug_circle_2d.gd — Temporary placeholder visual for S3-11 playtest.
## Remove when real sprites are added to PlayerController and EnemyInstance.
extends Node2D

@export var radius: float = 8.0
@export var color: Color = Color.WHITE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	var parent := get_parent()
	if parent and parent.has_method(&"get_facing_direction"):
		var dir: Vector2 = parent.get_facing_direction()
		var casting: bool = parent.get(&"_cast_beam_timer") > 0.0
		if casting:
			draw_line(Vector2.ZERO, dir * 80.0, Color(1.0, 0.8, 0.2, 1.0), 3.0)
		else:
			draw_line(Vector2.ZERO, dir * (radius + 10.0), Color.YELLOW, 2.0)
