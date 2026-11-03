extends StaticBody3D
## Мішень з кільцями: центр — bullseye. Магніт рикошету цілить саме в центр.

const Util = preload("res://scripts/util.gd")

const RADIUS := 0.9

var _disc: Node3D


func setup() -> void:
	collision_layer = 4
	collision_mask = 0
	_disc = Node3D.new()
	add_child(_disc)
	var white := Util.mat(Color(0.95, 0.92, 0.85), 0.8, 0.0, true)
	var red := Util.mat(Color(0.85, 0.15, 0.12), 0.7, 0.0, true)
	var rings := [[0.9, white], [0.68, red], [0.46, white], [0.22, red]]
	var z := 0.0
	for r in rings:
		Util.cyl(_disc, r[0], r[0], 0.08, Vector3(0.0, 0.0, z), r[1], Vector3(90, 0, 0))
		z += 0.012
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = RADIUS
	c.height = 0.1
	cs.shape = c
	cs.rotation_degrees = Vector3(90, 0, 0)
	add_child(cs)
	add_to_group("scorable")


func is_scorable() -> bool:
	return true


func aim_point() -> Vector3:
	return global_position


func on_bullet_hit(hit_pos: Vector3, _dir: Vector3, _normal: Vector3, _impulse: float) -> Dictionary:
	var local := to_local(hit_pos)
	var d := Vector2(local.x, local.y).length()
	var pts := 10
	var label := "Мішень"
	if d < 0.22:
		pts = 60
		label = "BULLSEYE!"
	elif d < 0.46:
		pts = 30
	elif d < 0.68:
		pts = 20
	var tw := create_tween()
	tw.tween_property(_disc, "rotation:x", -0.25, 0.05)
	tw.tween_property(_disc, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var sound := "target_bullseye" if pts >= 60 else "hit_wood"
	return {"surface": "wood", "points": pts, "label": label, "sound": sound}
