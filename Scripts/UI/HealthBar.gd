extends Control
## Draws the health as a row of small blocks, like the original's bar.

var health := 0
var max_health := 0

func set_health(new_health: int, new_max: int) -> void:
	health = new_health
	max_health = new_max
	queue_redraw()

func _draw() -> void:
	for i in max_health:
		var color := Color(0.9, 0.25, 0.2) if i < health else Color(0.25, 0.25, 0.3)
		draw_rect(Rect2(i * 6, 0, 5, 6), color)
