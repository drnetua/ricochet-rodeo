extends StaticBody3D
## Металевий гонг: куля від нього відбивається. Розвернутий убік, щоб рикошет летів через сцену.

const Util = preload("res://scripts/util.gd")

var _plate: Node3D


func setup(radius: float) -> void:
	collision_layer = 4
	collision_mask = 0
	_plate = Node3D.new()
	add_child(_plate)
	var steel := Util.mat(Color(0.6, 0.6, 0.62), 0.25, 1.0, true)
	Util.cyl(_plate, radius, radius, 0.06, Vector3.ZERO, steel, Vector3(90, 0, 0))
	Util.cyl(_plate, radius * 0.35, radius * 0.35, 0.065, Vector3.ZERO, Util.mat(Color(0.85, 0.2, 0.15), 0.6), Vector3(90, 0, 0))
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = 0.08
	cs.shape = c
	cs.rotation_degrees = Vector3(90, 0, 0)
	add_child(cs)
	add_to_group("scorable")


func is_scorable() -> bool:
	return true


func aim_point() -> Vector3:
	return global_position


func on_bullet_hit(_hit_pos: Vector3, _dir: Vector3, _normal: Vector3, _impulse: float) -> Dictionary:
	var tw := create_tween()
	tw.tween_property(_plate, "rotation:x", -0.35, 0.06)
	tw.tween_property(_plate, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return {"surface": "metal", "points": 0, "link": true, "label": "Дзинь!", "sound": "hit_gong"}
