extends StaticBody3D
## Картонний п'яний ковбой, що бреде між гравцем і парканом. Влучання — штраф і скидання комбо.

const Util = preload("res://scripts/util.gd")

@export var walk_x_limit: float = 17.0
@export var speed: float = 1.3

var _visual: Node3D
var _shape: CollisionShape3D
var _dir: float = 1.0
var _wait: float = 3.0
var _knocked: bool = false
var _t: float = 0.0
var _hic_in: float = 2.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	_build()
	position.x = -walk_x_limit


func _physics_process(delta: float) -> void:
	if _knocked:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	_t += delta
	position.x += _dir * speed * delta
	_visual.rotation.z = sin(_t * 5.0) * 0.12
	_visual.position.y = absf(sin(_t * 5.0)) * 0.06
	# Гикає, поки його видно.
	_hic_in -= delta
	if _hic_in <= 0.0 and absf(position.x) < 13.0:
		_hic_in = randf_range(3.0, 7.0)
		var sfx := get_tree().get_first_node_in_group("sfx")
		if sfx != null:
			sfx.call("play", "civilian_hic")
	if (_dir > 0.0 and position.x > walk_x_limit) or (_dir < 0.0 and position.x < -walk_x_limit):
		_dir = -_dir
		_wait = randf_range(2.5, 7.0)


func on_bullet_hit(_hit_pos: Vector3, _dir_in: Vector3, _normal: Vector3, _impulse: float) -> Dictionary:
	if _knocked:
		return {"surface": "wood"}
	_knocked = true
	# Поки лежить — не заважає стріляти в пляшки за ним.
	_shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(_visual, "rotation", Vector3(-1.45, 0.0, 0.3), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fx := get_tree().get_first_node_in_group("fx")
	if fx != null:
		fx.call("confetti", global_position + Vector3(0.0, 1.6, 0.0))
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 2.5
	add_child(t)
	t.timeout.connect(_get_up.bind(t))
	t.start()
	return {"surface": "wood", "civilian": true, "sound": "civilian_oops"}


func _get_up(t: Timer) -> void:
	t.queue_free()
	var tw := create_tween()
	tw.tween_property(_visual, "rotation", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_up)


func _on_up() -> void:
	_knocked = false
	_shape.set_deferred("disabled", false)


const CUTOUT := "res://assets/textures/01/cowboy_cutout.png"
const CUTOUT_HEIGHT := 2.5


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if ResourceLoader.exists(CUTOUT):
		_build_cutout()
		return
	var card := Util.mat(Color(0.78, 0.63, 0.42), 1.0, 0.0, true)
	var shirt := Util.mat(Color(0.3, 0.45, 0.75), 0.95, 0.0, true)
	var skin := Util.mat(Color(0.95, 0.75, 0.6), 0.9)
	var hat := Util.mat(Color(0.35, 0.22, 0.12), 0.9, 0.0, true)
	var dark := Util.mat(Color(0.08, 0.06, 0.05), 0.9)
	Util.box(_visual, Vector3(0.2, 0.75, 0.06), Vector3(-0.18, 0.38, 0.0), card)
	Util.box(_visual, Vector3(0.2, 0.75, 0.06), Vector3(0.18, 0.38, 0.0), card)
	Util.box(_visual, Vector3(0.85, 0.9, 0.08), Vector3(0.0, 1.2, 0.0), shirt)
	Util.box(_visual, Vector3(0.18, 0.7, 0.06), Vector3(-0.55, 1.2, 0.0), shirt, Vector3(0, 0, -15))
	Util.box(_visual, Vector3(0.18, 0.7, 0.06), Vector3(0.55, 1.35, 0.0), shirt, Vector3(0, 0, 60))
	Util.cyl(_visual, 0.07, 0.09, 0.35, Vector3(0.85, 1.6, 0.03), Util.glass(Color(0.4, 0.25, 0.1, 0.85)))
	Util.cyl(_visual, 0.32, 0.32, 0.07, Vector3(0.0, 1.95, 0.0), skin, Vector3(90, 0, 0))
	Util.sphere(_visual, 0.07, Vector3(0.0, 1.92, 0.06), Util.mat(Color(0.9, 0.2, 0.2), 0.6))
	Util.sphere(_visual, 0.035, Vector3(-0.11, 2.02, 0.04), dark)
	Util.sphere(_visual, 0.035, Vector3(0.11, 2.02, 0.04), dark)
	Util.box(_visual, Vector3(0.95, 0.06, 0.08), Vector3(0.0, 2.22, 0.0), hat)
	Util.box(_visual, Vector3(0.5, 0.32, 0.08), Vector3(0.0, 2.4, 0.0), hat)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 2.6, 0.4)
	cs.shape = bs
	cs.position = Vector3(0.0, 1.3, 0.0)
	add_child(cs)
	_shape = cs


## Картонна фігура: лицем — картинка FLUX, спиною — сірий картон, між ними товщина.
func _build_cutout() -> void:
	var tex := load(CUTOUT) as Texture2D
	var px := CUTOUT_HEIGHT / float(tex.get_height())
	for i in 3:
		var sp := Sprite3D.new()
		sp.texture = tex
		sp.pixel_size = px
		sp.centered = true
		sp.offset = Vector2(0.0, tex.get_height() * 0.5)
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = true
		sp.double_sided = false
		match i:
			0:
				sp.position.z = 0.012
			1:
				sp.modulate = Color(0.55, 0.42, 0.28)
				sp.position.z = 0.0
				sp.double_sided = true
			2:
				sp.modulate = Color(0.72, 0.6, 0.45)
				sp.rotation_degrees.y = 180.0
				sp.position.z = -0.012
		_visual.add_child(sp)
	var w := CUTOUT_HEIGHT * float(tex.get_width()) / float(tex.get_height())
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w * 0.75, CUTOUT_HEIGHT * 0.95, 0.3)
	cs.shape = bs
	cs.position = Vector3(0.0, CUTOUT_HEIGHT * 0.5, 0.0)
	add_child(cs)
	_shape = cs
