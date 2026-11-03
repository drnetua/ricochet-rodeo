extends StaticBody3D
## Пляшка або вікно: скло, куля пробиває його і летить далі. Відновлюється через кілька секунд.

const Util = preload("res://scripts/util.gd")

var kind: String = "bottle"
var points: int = 15
var label: String = "Пляшка"
var respawn_time: float = 6.0
var glass_color: Color = Color(0.25, 0.65, 0.3, 0.7)

var _alive: bool = true
var _visual: Node3D
var _shape: CollisionShape3D
var _center := Vector3.ZERO


func setup_bottle(color: Color) -> void:
	kind = "bottle"
	points = 15
	label = "Пляшка"
	respawn_time = 6.0
	glass_color = color
	_visual = Node3D.new()
	add_child(_visual)
	var g := Util.glass(color)
	var s := 1.8
	Util.cyl(_visual, 0.09 * s, 0.1 * s, 0.32 * s, Vector3(0.0, 0.16 * s, 0.0), g)
	Util.cyl(_visual, 0.035 * s, 0.07 * s, 0.1 * s, Vector3(0.0, 0.37 * s, 0.0), g)
	Util.cyl(_visual, 0.035 * s, 0.035 * s, 0.1 * s, Vector3(0.0, 0.47 * s, 0.0), g)
	Util.cyl(_visual, 0.04 * s, 0.04 * s, 0.03 * s, Vector3(0.0, 0.53 * s, 0.0), Util.mat(Color(0.6, 0.45, 0.25), 0.8))
	Util.box(_visual, Vector3(0.12, 0.1, 0.01) * s, Vector3(0.0, 0.16 * s, 0.1 * s + 0.003), Util.mat(Color(0.95, 0.9, 0.75), 0.9))
	_center = Vector3(0.0, 0.27 * s, 0.0)
	_make_shape(Vector3(0.22 * s, 0.56 * s, 0.22 * s), _center)


func setup_window(pane: Vector2) -> void:
	kind = "window"
	points = 20
	label = "Вікно"
	respawn_time = 8.0
	glass_color = Color(0.65, 0.85, 1.0, 0.35)
	_visual = Node3D.new()
	add_child(_visual)
	Util.box(_visual, Vector3(pane.x, pane.y, 0.04), Vector3.ZERO, Util.glass(glass_color))
	Util.box(_visual, Vector3(pane.x * 0.12, pane.y * 0.7, 0.045), Vector3(-pane.x * 0.25, 0.05, 0.0), Util.glass(Color(1.0, 1.0, 1.0, 0.35)), Vector3(0, 0, -20))
	_center = Vector3.ZERO
	_make_shape(Vector3(pane.x, pane.y, 0.06), Vector3.ZERO)


func _make_shape(box_size: Vector3, center: Vector3) -> void:
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	_shape.shape = bs
	_shape.position = center
	add_child(_shape)
	collision_layer = 4
	collision_mask = 0
	add_to_group("scorable")


func is_scorable() -> bool:
	return _alive


func aim_point() -> Vector3:
	return to_global(_center)


func on_bullet_hit(_hit_pos: Vector3, dir: Vector3, _normal: Vector3, _impulse: float) -> Dictionary:
	if not _alive:
		return {"surface": "glass"}
	_alive = false
	_visual.visible = false
	_shape.set_deferred("disabled", true)
	var fx := get_tree().get_first_node_in_group("fx")
	if fx != null:
		var shard := Color(glass_color.r, glass_color.g, glass_color.b, 0.8)
		var count := 12 if kind == "window" else 8
		var piece := 0.09 if kind == "window" else 0.06
		fx.call("debris", aim_point(), [shard, shard.lightened(0.3)], count, piece, dir * 3.0, true)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = respawn_time
	add_child(t)
	t.timeout.connect(_respawn.bind(t))
	t.start()
	var sound := "glass_window" if kind == "window" else "glass_bottle"
	return {"surface": "glass", "points": points, "label": label, "sound": sound}


func _respawn(t: Timer) -> void:
	t.queue_free()
	_alive = true
	_visual.visible = true
	_shape.set_deferred("disabled", false)
	_visual.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
