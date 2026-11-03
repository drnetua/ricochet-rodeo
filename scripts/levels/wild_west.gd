extends Node3D
## Рівень 1 «Дикий Захід»: сцена scenes/levels/01_wild_west.tscn (її збирає tools/godot/build_level_01.gd).
## Пропси й маркери лежать у сцені; цей скрипт додає небо, світло й пост-обробку, ґрунт, бекдроп,
## траву, контури моделей і створює ігрові цілі на маркерах (пляшки, вікна, мішені, гонги, цивільний).

const Util = preload("res://scripts/util.gd")
const Breakable = preload("res://scripts/world/breakable.gd")
const TargetBoard = preload("res://scripts/world/target_board.gd")
const MetalPlate = preload("res://scripts/world/metal_plate.gd")
const Civilian = preload("res://scripts/world/civilian.gd")

const OUTLINE_SHADER := preload("res://assets/shaders/outline.gdshader")
const TEX := "res://assets/textures/01/"
const MODELS := "res://assets/models/01/"
const GLASS := {
	"bottle_brown": Color(0.55, 0.28, 0.08, 0.82),
	"bottle_clear": Color(0.85, 0.92, 0.9, 0.45),
	"bottle_green": Color(0.25, 0.55, 0.18, 0.8),
}

var _outline: ShaderMaterial
var _tumbleweed: Node3D
var _tumble_t: float = 0.0


func _ready() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_environment()
	_ground()
	_backdrop()
	_apply_outlines($Props)
	_lanterns()
	_spawn_gameplay()
	_grass()
	_tumbleweed = get_node_or_null("Props/tumbleweed_1")


func _process(delta: float) -> void:
	# Перекотиполе котиться за вітром і повертається з-за лівого краю.
	if _tumbleweed == null:
		return
	_tumble_t += delta
	var p := _tumbleweed.position
	p.x += delta * 1.6
	if p.x > 9.0:
		p.x = -9.0
	p.y = 0.5 + absf(sin(_tumble_t * 3.1)) * 0.35
	_tumbleweed.position = p
	_tumbleweed.rotate_z(-delta * 3.2)


# --- Небо, світло, пост-обробка ---

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.42, 0.45, 0.72)
	psm.sky_horizon_color = Color(1.0, 0.7, 0.5)
	psm.ground_horizon_color = Color(0.9, 0.62, 0.42)
	psm.ground_bottom_color = Color(0.35, 0.22, 0.15)
	psm.sun_angle_max = 20.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.75, 0.62)
	env.fog_density = 0.0065
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.1
	env.adjustment_brightness = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	# М'яке розмиття далини, як на концепті.
	var cam := CameraAttributesPractical.new()
	cam.dof_blur_far_enabled = true
	cam.dof_blur_far_distance = 40.0
	cam.dof_blur_far_transition = 40.0
	cam.dof_blur_amount = 0.06
	we.camera_attributes = cam
	add_child(we)
	# Низьке сонце «золотої години» зліва-ззаду: освітлює фасад салуну, паркан у тіні.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.84, 0.66)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.82, -0.36, 0.3), Vector3.UP)
	# Холодне заповнення з неба з протилежного боку, щоб тіні не були чорні.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.6, 0.95)
	fill.light_energy = 0.35
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.6, -0.5, -0.4), Vector3.UP)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300.0, 2.0, 300.0)
	cs.shape = bs
	cs.position = Vector3(0.0, -1.0, 0.0)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(320.0, 320.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/ground/ground102_color.jpg")
	m.albedo_color = Color(1.12, 0.9, 0.72)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/ground/ground102_normal.jpg")
	m.normal_scale = 0.8
	m.roughness_texture = load("res://assets/textures/ground/ground102_roughness.jpg")
	m.uv1_scale = Vector3(80.0, 80.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	body.add_child(mi)


## Небо й столові гори — одна велика картинка FLUX далеко за сценою, лінія горизонту на рівні очей.
func _backdrop() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	var qm := QuadMesh.new()
	qm.size = Vector2(640.0, 275.0)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(TEX + "backdrop.jpg")
	m.disable_fog = true
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Горизонт картинки — на 55 % висоти згори; ставимо його на рівень очей (1.6 м).
	mi.position = Vector3(6.0, 1.6 + (0.55 - 0.5) * 275.0 - 4.0, -170.0)
	add_child(mi)


# --- Моделі ---

## Контур — на окремих предметах; великі горбкуваті поверхні (стіни, паркан) без нього,
## інакше оболонка просвічує крізь нерівності темними плямами.
const NO_OUTLINE := ["saloon_wall", "fence_section", "porch", "window_frame"]


func _apply_outlines(root: Node) -> void:
	for c in root.get_children():
		var skip := false
		for prefix in NO_OUTLINE:
			if String(c.name).begins_with(prefix):
				skip = true
		if skip:
			continue
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _outline


func _lanterns() -> void:
	for n in $Props.get_children():
		if not String(n.name).begins_with("lantern"):
			continue
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.light_energy = 1.6
		l.omni_range = 4.5
		l.position = Vector3(0.0, -0.1, 0.12)
		n.add_child(l)


# --- Ігрові цілі на маркерах ---

func _spawn_gameplay() -> void:
	for mk in $Spawns.get_children():
		var m3 := mk as Node3D
		match str(m3.get_meta("kind", "")):
			"bottle":
				var b: Breakable = Breakable.new()
				add_child(b)
				b.global_transform = m3.global_transform
				var id: String = str(m3.get_meta("model"))
				b.setup_bottle_model(load(MODELS + id + ".glb"), GLASS.get(id, Color(0.3, 0.6, 0.3, 0.8)), _outline)
			"window":
				var w: Breakable = Breakable.new()
				add_child(w)
				w.global_transform = m3.global_transform
				w.setup_window(m3.get_meta("pane", Vector2(1.3, 1.5)))
			"target":
				var t: TargetBoard = TargetBoard.new()
				add_child(t)
				t.global_transform = m3.global_transform
				t.setup_model(load(MODELS + "target_post.glb"), float(m3.get_meta("disc_height", 1.77)), _outline)
			"gong":
				var g: MetalPlate = MetalPlate.new()
				add_child(g)
				g.global_transform = m3.global_transform
				g.setup(float(m3.get_meta("radius", 0.75)))
			"civilian":
				var c: Civilian = Civilian.new()
				c.walk_x_limit = float(m3.get_meta("walk", 6.0))
				c.position = m3.global_position
				add_child(c)


## Кущики сухої трави — білборди з FLUX, розсипані по ґрунту (детерміновано, однаково щоразу).
func _grass() -> void:
	var tex: Array = []
	for i in 8:
		var p := TEX + "grass_%d.png" % i
		if ResourceLoader.exists(p):
			tex.append(load(p))
	if tex.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1979
	var holder := Node3D.new()
	holder.name = "Grass"
	add_child(holder)
	for i in 70:
		var z := rng.randf_range(-36.0, -3.0)
		var x := rng.randf_range(-7.0, 7.0)
		# Більше трави біля паркану й стіни, менше в центрі (там летять предмети).
		if absf(x) < 3.0 and rng.randf() < 0.6:
			x = signf(x if x != 0.0 else 1.0) * rng.randf_range(3.0, 7.0)
		var s := Sprite3D.new()
		s.texture = tex[rng.randi() % tex.size()]
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.double_sided = true
		var h := rng.randf_range(0.45, 0.9)
		s.pixel_size = h / float((s.texture as Texture2D).get_height())
		s.position = Vector3(x, h * 0.5 - 0.04, z)
		s.modulate = Color(1.0, 0.95, 0.85).lerp(Color(0.85, 0.7, 0.5), rng.randf())
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(s)
