extends Node3D
## Візуальні ефекти: трасери, плаваючі написи, уламки, іскри, конфеті.

const Util = preload("res://scripts/util.gd")

const CONFETTI := [
	Color(1.0, 0.3, 0.4), Color(1.0, 0.85, 0.2), Color(0.3, 0.8, 1.0),
	Color(0.5, 1.0, 0.4), Color(0.9, 0.5, 1.0),
]


func _ready() -> void:
	add_to_group("fx")


func tracer(a: Vector3, b: Vector3, color: Color, width: float = 0.045) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var m := Util.unshaded(color)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, length)
	mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mi.look_at_from_position((a + b) * 0.5, b, up)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)


## Стікери з концепту (FLUX): для рикошету й штрафу замість простого тексту.
const STICKERS := {"РИКОШЕТ": "res://assets/textures/01/sticker_ricochet.png", "ЦИВІЛЬНИЙ": "res://assets/textures/01/sticker_oops.png"}


## Плаваючий напис над точкою влучання («+45$», «РИКОШЕТ ×2!»).
func float_text(text: String, pos: Vector3, color: Color, big: bool = false) -> void:
	for key in STICKERS:
		if text.contains(key) and ResourceLoader.exists(STICKERS[key]):
			_sticker(load(STICKERS[key]), pos)
			# Під стікером лишається коротка частина напису (×2, −100$).
			var rest := text.get_slice("\n", 0).replace("РИКОШЕТ", "").replace("!", "").strip_edges()
			if key == "ЦИВІЛЬНИЙ":
				rest = text.get_slice(" ", 0)
			if rest.is_empty():
				return
			text = rest
			pos += Vector3(0.0, -0.9, 0.0)
			break
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.font_size = 96 if big else 64
	l.outline_size = 18
	l.pixel_size = 0.009
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	add_child(l)
	l.global_position = pos + Vector3(0.0, 0.7, 0.0)
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "global_position", l.global_position + Vector3(0.0, 1.4, 0.0), 1.0).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.65)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.65)
	tw.tween_callback(l.queue_free)


## Дрібні фізичні уламки (скло, тріски, іскри, конфеті).
func debris(pos: Vector3, colors: Array, count: int, piece_size: float, push: Vector3 = Vector3.ZERO, glassy: bool = false) -> void:
	for _i in count:
		var b := RigidBody3D.new()
		b.collision_layer = 0
		b.collision_mask = 1
		b.mass = 0.05
		var c: Color = colors.pick_random()
		var m := Util.glass(c) if glassy else Util.mat(c, 0.6)
		var s := piece_size * randf_range(0.6, 1.4)
		Util.box(b, Vector3(s, s * randf_range(0.3, 1.0), s * 0.6), Vector3.ZERO, m)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * s * 0.6
		cs.shape = bs
		b.add_child(cs)
		add_child(b)
		b.global_position = pos + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		b.linear_velocity = push + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 4.5), randf_range(-1.5, 1.5))
		b.angular_velocity = Vector3(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		var tw := b.create_tween()
		tw.tween_interval(randf_range(1.2, 2.0))
		tw.tween_callback(b.queue_free)


func impact(pos: Vector3, normal: Vector3, surface: String) -> void:
	match surface:
		"metal", "object":
			debris(pos, [Color(1.0, 0.9, 0.5), Color(1.0, 0.6, 0.2)], 4, 0.05, normal * 2.0)
		"solid", "wood":
			debris(pos, [Color(0.45, 0.3, 0.15), Color(0.6, 0.45, 0.25)], 3, 0.07, normal * 1.5)


func confetti(pos: Vector3) -> void:
	debris(pos, CONFETTI, 18, 0.08, Vector3(0.0, 2.0, 0.0))


## Стікер-картинка: вискакує з пружиною, підлітає і зникає.
func _sticker(tex: Texture2D, pos: Vector3) -> void:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.no_depth_test = true
	sp.render_priority = 21
	sp.pixel_size = 2.4 / float(tex.get_width())
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.shaded = false
	add_child(sp)
	sp.global_position = pos + Vector3(0.0, 0.9, 0.0)
	sp.scale = Vector3.ONE * 0.2
	sp.rotation.z = randf_range(-0.2, 0.2)
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "global_position", sp.global_position + Vector3(0.0, 1.2, 0.0), 1.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.35).set_delay(0.8)
	tw.tween_callback(sp.queue_free)
