extends Control
## Приціл. Саме перехрестя — системний курсор: його малює ОС, тож воно
## рухається плавно навіть коли гра видає мало кадрів. Гра домальовує лише
## «пульс» — кільце, що розходиться на пострілі.

const SIZE := 64
const RING_R := 16.0
const TICK_FROM := 19.0
const TICK_TO := 28.0
const DOT_R := 2.5

var color := Color(1.0, 1.0, 1.0, 0.95)
var _pulse: float = 0.0
static var _cursor_image: Image


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## true — курсор стає прицілом; false — звичайна стрілка (пауза, меню).
static func set_aim_cursor(aim: bool) -> void:
	if not aim:
		Input.set_custom_mouse_cursor(null)
		return
	if _cursor_image == null:
		_cursor_image = _build_cursor_image()
	Input.set_custom_mouse_cursor(_cursor_image, Input.CURSOR_ARROW, Vector2(SIZE, SIZE) * 0.5)


func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	if _pulse <= 0.0:
		return
	_pulse = maxf(_pulse - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if _pulse <= 0.0 or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	var p := get_local_mouse_position()
	var r := RING_R + (1.0 - _pulse) * 14.0
	draw_arc(p, r, 0.0, TAU, 40, Color(0.0, 0.0, 0.0, 0.5 * _pulse), 4.0, true)
	draw_arc(p, r, 0.0, TAU, 40, Color(color, color.a * _pulse), 2.0, true)


## Малює перехрестя в Image 64×64 зі згладжуванням: біла лінія 2 px
## поверх темного контуру 4 px — видно і на небі, і на піску.
static func _build_cursor_image() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := Vector2(SIZE, SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length()
			var a := Vector2(absf(p.x), absf(p.y))
			var e_line := minf(absf(d - RING_R), minf(_seg_dist(a, false), _seg_dist(a, true)))
			var e_dot := d - DOT_R
			var core := maxf(clampf(1.5 - e_line, 0.0, 1.0), clampf(0.5 - e_dot, 0.0, 1.0))
			var shade := maxf(clampf(2.5 - e_line, 0.0, 1.0), clampf(2.0 - e_dot, 0.0, 1.0))
			var aw := 0.95 * core
			var ab := 0.6 * shade
			var out_a := aw + ab * (1.0 - aw)
			var v := aw / out_a if out_a > 0.0 else 0.0
			img.set_pixel(x, y, Color(v, v, v, out_a))
	return img


## Відстань від точки (у першій чверті) до штриха на осі X або Y.
static func _seg_dist(a: Vector2, vertical: bool) -> float:
	var along := a.y if vertical else a.x
	var across := a.x if vertical else a.y
	var dx := maxf(maxf(TICK_FROM - along, along - TICK_TO), 0.0)
	return Vector2(dx, across).length()
