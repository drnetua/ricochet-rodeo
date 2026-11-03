extends Node3D
## Візуальні ефекти: трасери, плаваючі написи, уламки, іскри, конфеті.

const Util = preload("res://scripts/util.gd")

const CONFETTI := [
	Color(1.0, 0.3, 0.4), Color(1.0, 0.85, 0.2), Color(0.3, 0.8, 1.0),
	Color(0.5, 1.0, 0.4), Color(0.9, 0.5, 1.0),
]


## 2D-шар для стікерів: поверх кадру, тож розмиття далини (DOF) і туман їх не чіпають.
var _overlay: CanvasLayer


func _ready() -> void:
	add_to_group("fx")
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)


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
			# Під стікером — коротка частина напису (×2, −100$).
			var rest := text.get_slice("\n", 0).replace("РИКОШЕТ", "").replace("!", "").strip_edges()
			if key == "ЦИВІЛЬНИЙ":
				rest = text.get_slice(" ", 0)
			if _sticker(load(STICKERS[key]), pos, rest, color):
				return
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


## Ширина стікера — частка ширини кадру, як на концепті, хоч би як далеко був рикошет.
const STICKER_SCREEN_WIDTH := 0.27
const WESTERN_FONT := "res://assets/fonts/Rye-Regular.ttf"


## Стікер-картинка над точкою рикошету: вискакує з пружиною, підлітає і зникає.
## Малюється в 2D поверх кадру. false — точка за камерою, стікер не показано.
func _sticker(tex: Texture2D, pos: Vector3, extra: String = "", extra_color: Color = Color.WHITE) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(pos):
		return false
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * STICKER_SCREEN_WIDTH
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var at := cam.unproject_position(pos + Vector3(0.0, 0.8, 0.0))
	at.x = clampf(at.x, w * 0.55, vp.x - w * 0.55)
	at.y = clampf(at.y, h * 0.9, vp.y - h * 1.2)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(w, h)
	tr.position = -Vector2(w, h) * 0.5
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	if not extra.is_empty():
		var l := Label.new()
		l.text = extra
		l.add_theme_font_override("font", load(WESTERN_FONT))
		l.add_theme_font_size_override("font_size", int(h * 0.42))
		l.add_theme_color_override("font_color", extra_color)
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.03))
		l.add_theme_constant_override("outline_size", 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(w, h * 0.6)
		l.position = Vector2(-w * 0.5, h * 0.38)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(l)
	holder.position = at
	holder.scale = Vector2.ONE * 0.2
	holder.rotation = randf_range(-0.18, 0.18)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "position", at - Vector2(0.0, h * 0.5), 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.35).set_delay(1.0)
	tw.tween_callback(holder.queue_free)
	return true
