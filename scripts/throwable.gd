extends RigidBody3D
## Підкинутий предмет: модель з Blender (або заглушка з примітивів), аркадна гравітація, реакція на кулю.

const ThrowableData = preload("res://scripts/data/throwable_data.gd")
const Util = preload("res://scripts/util.gd")

signal finished(body: RigidBody3D, was_hit: bool)

const MAX_AGE := 9.0
const HIT_SOUND := {
	"coin": "hit_coin",
	"skull": "hit_bone",
	"crate": "hit_wood",
	"anvil": "hit_anvil",
	"chicken": "hit_rubber_chicken",
}
## Готові моделі з Blender (джерела — art/models/). Предмети без моделі збираються з примітивів.
const MODEL_PATHS := {
	"crate": "res://assets/models/props/crate.glb",
	"skull": "res://assets/models/props/bullskull.glb",
}

var data: ThrowableData
var hits: int = 0
var _age: float = 0.0
var _done: bool = false
var _landed: bool = false
var _visual: Node3D


func setup(d: ThrowableData) -> void:
	data = d
	mass = d.mass
	gravity_scale = d.gravity_scale
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.3
	collision_layer = 2
	collision_mask = 1 | 2
	continuous_cd = true
	# Потрібно, щоб почути, як предмет падає на землю.
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)
	add_to_group("scorable")
	_build()


func is_scorable() -> bool:
	return not _done


func aim_point() -> Vector3:
	return global_position


## Викликається стрільбою. Повертає опис влучання для очок і рикошету.
func on_bullet_hit(hit_pos: Vector3, dir: Vector3, _normal: Vector3, impulse: float) -> Dictionary:
	if _done:
		return {"surface": "solid"}
	hits += 1
	var tags: Array = []
	var pts: int = data.points
	if hits == 1 and linear_velocity.y > 0.3:
		pts += 10
		tags.append("Швидкий постріл")
	if hits >= 2:
		pts += 20 * (hits - 1)
		tags.append("Жонглювання ×%d" % hits)
	# Поштовх: переважно вгору і вбік — щоб предмет лишався в кадрі і його можна було влучити знову.
	var j := impulse * sqrt(mass)
	var side := Vector3(dir.x, 0.0, dir.z * 0.25)
	if side.length_squared() > 0.0001:
		side = side.normalized()
	apply_impulse(side * j * 0.8 + Vector3.UP * j, hit_pos - global_position)
	_age = minf(_age, 2.0)
	_punch_visual()
	return {"surface": "object", "points": pts, "label": data.display_name, "tags": tags, "sound": str(HIT_SOUND.get(data.id, "hit_wood"))}


func _on_body_entered(body: Node) -> void:
	if _landed or _done or not (body is StaticBody3D):
		return
	_landed = true
	var speed := linear_velocity.length()
	var sfx := get_tree().get_first_node_in_group("sfx")
	if sfx != null and speed > 1.0:
		# Важче — нижчий звук, швидше — гучніше.
		sfx.call("play", "land_dirt", clampf(speed - 12.0, -12.0, 0.0), clampf(1.4 - mass * 0.06, 0.8, 1.4))


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var p := global_position
	var resting := _age > 1.0 and p.y < 1.2 and linear_velocity.length() < 0.6
	if p.y < -3.0 or absf(p.x) > 22.0 or _age > MAX_AGE or resting:
		_finish()


func _finish() -> void:
	_done = true
	remove_from_group("scorable")
	collision_layer = 0
	finished.emit(self, hits > 0)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _punch_visual() -> void:
	_visual.scale = Vector3.ONE * 1.25
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var s: float = data.size
	var base := Util.mat(data.color, data.roughness, data.metallic, true)
	var dark := Util.mat(Color(0.08, 0.06, 0.05), 0.9)
	var col := CollisionShape3D.new()
	match data.id:
		"coin":
			Util.cyl(_visual, 0.5 * s, 0.5 * s, 0.12 * s, Vector3.ZERO, base, Vector3(90, 0, 0))
			Util.cyl(_visual, 0.36 * s, 0.36 * s, 0.13 * s, Vector3.ZERO, Util.mat(data.color.darkened(0.25), 0.3, 1.0), Vector3(90, 0, 0))
			var coin_shape := CylinderShape3D.new()
			coin_shape.radius = 0.5 * s
			coin_shape.height = 0.12 * s
			col.shape = coin_shape
			col.rotation_degrees = Vector3(90, 0, 0)
		"skull":
			if _add_model(s):
				# Опукла оболонка моделі: влучання в роги теж зараховуються.
				col.shape = _model_hull()
			else:
				_build_skull_placeholder(s, base, dark)
			if col.shape == null:
				var skull_shape := SphereShape3D.new()
				skull_shape.radius = 0.48 * s
				col.shape = skull_shape
		"crate":
			if not _add_model(s):
				Util.box(_visual, Vector3.ONE * s, Vector3.ZERO, base)
				var plank := Util.mat(data.color.darkened(0.35), 0.9, 0.0, true)
				Util.box(_visual, Vector3(1.3, 0.14, 0.04) * s, Vector3(0, 0, 0.51 * s), plank, Vector3(0, 0, 45))
				Util.box(_visual, Vector3(1.3, 0.14, 0.04) * s, Vector3(0, 0, 0.51 * s), plank, Vector3(0, 0, -45))
				Util.box(_visual, Vector3(1.04, 0.14, 1.04) * s, Vector3(0, 0.45 * s, 0), plank)
				Util.box(_visual, Vector3(1.04, 0.14, 1.04) * s, Vector3(0, -0.45 * s, 0), plank)
			var crate_shape := BoxShape3D.new()
			crate_shape.size = Vector3.ONE * s
			col.shape = crate_shape
		"anvil":
			Util.box(_visual, Vector3(1.0, 0.25, 0.45) * s, Vector3(0, 0.18 * s, 0), base)
			Util.box(_visual, Vector3(0.4, 0.25, 0.3) * s, Vector3(0, -0.05 * s, 0), base)
			Util.box(_visual, Vector3(0.7, 0.18, 0.45) * s, Vector3(0, -0.24 * s, 0), base)
			Util.cyl(_visual, 0.0, 0.12 * s, 0.4 * s, Vector3(-0.68 * s, 0.18 * s, 0), base, Vector3(0, 0, 90))
			var anvil_shape := BoxShape3D.new()
			anvil_shape.size = Vector3(1.2, 0.6, 0.45) * s
			col.shape = anvil_shape
		"chicken":
			Util.sphere(_visual, 0.38 * s, Vector3.ZERO, base, Vector3(1.2, 1.0, 0.9))
			Util.sphere(_visual, 0.2 * s, Vector3(0.34 * s, 0.32 * s, 0), base)
			Util.box(_visual, Vector3(0.06, 0.16, 0.2) * s, Vector3(0.34 * s, 0.54 * s, 0), Util.mat(Color(0.9, 0.15, 0.12), 0.6))
			Util.cyl(_visual, 0.0, 0.07 * s, 0.18 * s, Vector3(0.56 * s, 0.3 * s, 0), Util.mat(Color(1.0, 0.55, 0.1), 0.5), Vector3(0, 0, -90))
			var white := Util.mat(Color(1, 1, 1), 0.4)
			Util.sphere(_visual, 0.08 * s, Vector3(0.42 * s, 0.38 * s, 0.14 * s), white)
			Util.sphere(_visual, 0.035 * s, Vector3(0.46 * s, 0.38 * s, 0.2 * s), dark)
			var leg := Util.mat(Color(1.0, 0.55, 0.1), 0.5)
			Util.cyl(_visual, 0.03 * s, 0.03 * s, 0.3 * s, Vector3(-0.1 * s, -0.45 * s, 0), leg)
			Util.cyl(_visual, 0.03 * s, 0.03 * s, 0.3 * s, Vector3(0.1 * s, -0.45 * s, 0), leg)
			var chicken_shape := SphereShape3D.new()
			chicken_shape.radius = 0.42 * s
			col.shape = chicken_shape
		_:
			Util.sphere(_visual, 0.5 * s, Vector3.ZERO, base)
			var default_shape := SphereShape3D.new()
			default_shape.radius = 0.5 * s
			col.shape = default_shape
	add_child(col)


## Додає модель з Blender, якщо вона є для цього предмета. Модель — 1 м з центром у початку координат,
## тож масштаб = data.size, як і в колізії. false — моделі нема, будуємо заглушку.
func _add_model(s: float) -> bool:
	var path: String = MODEL_PATHS.get(data.id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Не вдалося завантажити модель %s" % path)
		return false
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * s
	_visual.add_child(model)
	return true

## Заглушка з примітивів, якщо моделі черепа нема.
func _build_skull_placeholder(s: float, base: Material, dark: Material) -> void:
	Util.sphere(_visual, 0.45 * s, Vector3(0, 0.05 * s, 0), base, Vector3(1.0, 0.95, 1.0))
	Util.box(_visual, Vector3(0.55, 0.25, 0.5) * s, Vector3(0, -0.32 * s, 0.08 * s), base)
	# Великі «вирячені» очі — головне джерело абсурду.
	var eye_white := Util.mat(Color(1, 1, 1), 0.4)
	Util.sphere(_visual, 0.14 * s, Vector3(-0.17 * s, 0.1 * s, 0.34 * s), eye_white)
	Util.sphere(_visual, 0.14 * s, Vector3(0.17 * s, 0.1 * s, 0.34 * s), eye_white)
	Util.sphere(_visual, 0.06 * s, Vector3(-0.15 * s, 0.1 * s, 0.47 * s), dark)
	Util.sphere(_visual, 0.06 * s, Vector3(0.19 * s, 0.1 * s, 0.47 * s), dark)
	Util.box(_visual, Vector3(0.08, 0.1, 0.06) * s, Vector3(0, -0.12 * s, 0.42 * s), dark)
	var horn := Util.mat(Color(0.3, 0.22, 0.15), 0.5, 0.0, true)
	Util.cyl(_visual, 0.02 * s, 0.09 * s, 0.5 * s, Vector3(-0.58 * s, 0.24 * s, 0), horn, Vector3(0, 0, 70))
	Util.cyl(_visual, 0.02 * s, 0.09 * s, 0.5 * s, Vector3(0.58 * s, 0.24 * s, 0), horn, Vector3(0, 0, -70))


## Опукла оболонка першої сітки моделі в координатах тіла. null — сітки нема.
func _model_hull() -> Shape3D:
	var mi := _find_mesh(_visual)
	if mi == null or mi.mesh == null:
		return null
	var hull := mi.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
	if hull == null:
		return null
	# Тіло ще не в дереві сцени, тож трансформу до _visual збираємо вручну.
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != _visual:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	xf = _visual.transform * xf
	var pts := PackedVector3Array()
	for p in hull.points:
		pts.append(xf * p)
	hull.points = pts
	return hull


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var m := _find_mesh(c)
		if m != null:
			return m
	return null
