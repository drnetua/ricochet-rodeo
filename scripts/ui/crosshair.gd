extends Control
## Приціл замість системного курсора; «пульсує» на пострілі.

var color := Color(1.0, 1.0, 1.0, 0.95)
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var p := get_local_mouse_position()
	var r := 16.0 + _pulse * 10.0
	var shadow := Color(0.0, 0.0, 0.0, 0.6)
	draw_arc(p, r, 0.0, TAU, 40, shadow, 4.0, true)
	draw_arc(p, r, 0.0, TAU, 40, color, 2.0, true)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = p + d * (r + 3.0)
		var b: Vector2 = p + d * (r + 12.0)
		draw_line(a, b, shadow, 4.0)
		draw_line(a, b, color, 2.0)
	draw_circle(p, 2.5, color)
