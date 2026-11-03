extends RefCounted
## Збирає локацію «Дикий Захід» з примітивів.
## У грі це буде окрема .tscn-сцена рівня з моделями, світлом і 2D-бекдропом.

const Util = preload("res://scripts/util.gd")
const Breakable = preload("res://scripts/world/breakable.gd")
const TargetBoard = preload("res://scripts/world/target_board.gd")
const MetalPlate = preload("res://scripts/world/metal_plate.gd")
const Civilian = preload("res://scripts/world/civilian.gd")

const WOOD := Color(0.55, 0.36, 0.2)
const WOOD_DARK := Color(0.36, 0.22, 0.12)
const SAND := Color(0.86, 0.7, 0.48)


static func build(root: Node3D) -> void:
	_environment(root)
	_ground(root)
	_saloon(root)
	_fence(root)
	_targets(root)
	_decor(root)
	var civ: Civilian = Civilian.new()
	civ.position = Vector3(-17.0, 0.0, -12.0)
	root.add_child(civ)


static func _environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.32, 0.5, 0.82)
	psm.sky_horizon_color = Color(0.98, 0.72, 0.48)
	psm.ground_horizon_color = Color(0.9, 0.68, 0.48)
	psm.ground_bottom_color = Color(0.35, 0.25, 0.18)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.98, 0.82, 0.62)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	# Низьке тепле сонце «золотої години» — як у концептах.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root.add_child(sun)


static func _ground(root: Node3D) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200.0, 2.0, 200.0)
	cs.shape = bs
	cs.position = Vector3(0.0, -1.0, 0.0)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240.0, 240.0)
	mi.mesh = pm
	mi.material_override = Util.mat(SAND, 1.0, 0.0, true)
	body.add_child(mi)


static func _saloon(root: Node3D) -> void:
	var wood := Util.mat(WOOD, 0.9, 0.0, true)
	var dark := Util.mat(WOOD_DARK, 0.9, 0.0, true)
	var z := -22.5
	Util.static_box(root, Vector3(30.0, 8.5, 1.0), Vector3(0.0, 4.25, z), wood)
	Util.static_box(root, Vector3(31.0, 1.4, 1.4), Vector3(0.0, 9.1, z + 0.1), dark)
	Util.static_box(root, Vector3(9.0, 1.6, 0.25), Vector3(0.0, 7.2, z + 0.65), dark)
	var sign_label := Label3D.new()
	sign_label.text = "САЛУН «РИКОШЕТ»"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.01
	sign_label.outline_size = 16
	sign_label.modulate = Color(1.0, 0.85, 0.4)
	sign_label.position = Vector3(0.0, 7.2, z + 0.8)
	root.add_child(sign_label)
	# Ґанок: дах і стовпи.
	Util.static_box(root, Vector3(30.0, 0.25, 2.6), Vector3(0.0, 3.9, z + 1.8), dark)
	for x in [-13.5, -7.0, 7.0, 13.5]:
		Util.static_box(root, Vector3(0.3, 3.9, 0.3), Vector3(x, 1.95, z + 2.9), dark)
	# Двері-«крила».
	Util.static_box(root, Vector3(2.6, 3.3, 0.2), Vector3(0.0, 1.65, z + 0.55), Util.mat(Color(0.12, 0.08, 0.05), 1.0))
	Util.static_box(root, Vector3(1.15, 1.4, 0.1), Vector3(-0.62, 1.8, z + 0.75), wood)
	Util.static_box(root, Vector3(1.15, 1.4, 0.1), Vector3(0.62, 1.8, z + 0.75), wood)
	# Вікна — скло, яке можна розбити.
	for x in [-11.0, -6.0, 6.0, 11.0]:
		_window(root, Vector3(x, 5.6, z + 0.55), Vector2(1.6, 1.8), dark)
	for x in [-10.5, -4.0, 4.0, 10.5]:
		_window(root, Vector3(x, 2.0, z + 0.55), Vector2(1.8, 1.6), dark)


static func _window(root: Node3D, pos: Vector3, pane: Vector2, frame_mat: Material) -> void:
	var w: Breakable = Breakable.new()
	root.add_child(w)
	w.position = pos
	w.setup_window(pane)
	var t := 0.14
	Util.box(root, Vector3(pane.x + t * 2.0, t, 0.2), pos + Vector3(0.0, pane.y * 0.5 + t * 0.5, 0.0), frame_mat)
	Util.box(root, Vector3(pane.x + t * 2.0, t, 0.2), pos - Vector3(0.0, pane.y * 0.5 + t * 0.5, 0.0), frame_mat)
	Util.box(root, Vector3(t, pane.y, 0.2), pos + Vector3(pane.x * 0.5 + t * 0.5, 0.0, 0.0), frame_mat)
	Util.box(root, Vector3(t, pane.y, 0.2), pos - Vector3(pane.x * 0.5 + t * 0.5, 0.0, 0.0), frame_mat)


static func _fence(root: Node3D) -> void:
	var wood := Util.mat(WOOD, 0.95, 0.0, true)
	var z := -14.0
	var x := -10.5
	while x <= 10.6:
		Util.static_box(root, Vector3(0.2, 1.2, 0.2), Vector3(x, 0.6, z), wood)
		x += 3.0
	Util.static_box(root, Vector3(21.5, 0.14, 0.08), Vector3(0.0, 0.55, z + 0.1), wood)
	Util.static_box(root, Vector3(21.5, 0.1, 0.34), Vector3(0.0, 1.2, z), wood)
	var colors := [Color(0.2, 0.6, 0.25, 0.75), Color(0.5, 0.28, 0.1, 0.8), Color(0.6, 0.85, 0.95, 0.55)]
	var i := 0
	for bx in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]:
		var b: Breakable = Breakable.new()
		root.add_child(b)
		b.position = Vector3(bx, 1.25, z)
		b.setup_bottle(colors[i % colors.size()])
		i += 1


static func _targets(root: Node3D) -> void:
	var wood := Util.mat(WOOD_DARK, 0.9, 0.0, true)
	var t1: TargetBoard = TargetBoard.new()
	root.add_child(t1)
	t1.position = Vector3(7.5, 2.7, -16.0)
	t1.setup()
	Util.static_box(root, Vector3(0.22, 2.0, 0.22), Vector3(7.5, 1.0, -16.15), wood)
	var t2: TargetBoard = TargetBoard.new()
	root.add_child(t2)
	t2.position = Vector3(-3.0, 4.6, -18.5)
	t2.setup()
	Util.static_box(root, Vector3(0.22, 3.8, 0.22), Vector3(-3.0, 1.9, -18.65), wood)
	# Гонги розвернуті вбік, щоб рикошети летіли через сцену в пляшки й мішені.
	_gong(root, Vector3(-8.0, 3.2, -16.5), 28.0, wood)
	_gong(root, Vector3(2.5, 5.2, -17.0), -32.0, wood)


static func _gong(root: Node3D, pos: Vector3, yaw_deg: float, wood: Material) -> void:
	var stand := Node3D.new()
	root.add_child(stand)
	stand.position = Vector3(pos.x, 0.0, pos.z)
	stand.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	var h := pos.y + 1.1
	Util.static_box(stand, Vector3(0.18, h, 0.18), Vector3(-0.9, h * 0.5, -0.1), wood)
	Util.static_box(stand, Vector3(0.18, h, 0.18), Vector3(0.9, h * 0.5, -0.1), wood)
	Util.static_box(stand, Vector3(2.0, 0.18, 0.18), Vector3(0.0, h, -0.1), wood)
	var chain := Util.mat(Color(0.3, 0.3, 0.32), 0.4, 1.0)
	Util.cyl(stand, 0.015, 0.015, 0.5, Vector3(-0.35, h - 0.25, -0.05), chain)
	Util.cyl(stand, 0.015, 0.015, 0.5, Vector3(0.35, h - 0.25, -0.05), chain)
	var plate: MetalPlate = MetalPlate.new()
	stand.add_child(plate)
	plate.position = Vector3(0.0, pos.y, 0.0)
	plate.setup(0.75)


static func _decor(root: Node3D) -> void:
	var cactus := Util.mat(Color(0.3, 0.55, 0.28), 0.8, 0.0, true)
	for p in [Vector3(-13.5, 0.0, -17.0), Vector3(14.0, 0.0, -18.0), Vector3(-17.5, 0.0, -26.0)]:
		_cactus(root, p, cactus)
	var barrel := Util.mat(Color(0.5, 0.3, 0.15), 0.85, 0.0, true)
	var hoop := Util.mat(Color(0.25, 0.25, 0.27), 0.4, 0.9)
	for p in [Vector3(-12.0, 0.0, -19.5), Vector3(-11.1, 0.0, -19.9), Vector3(12.0, 0.0, -19.6)]:
		var b := StaticBody3D.new()
		root.add_child(b)
		b.position = p
		Util.cyl(b, 0.45, 0.45, 1.2, Vector3(0.0, 0.6, 0.0), barrel)
		Util.cyl(b, 0.47, 0.47, 0.06, Vector3(0.0, 0.25, 0.0), hoop)
		Util.cyl(b, 0.47, 0.47, 0.06, Vector3(0.0, 0.95, 0.0), hoop)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.45
		c.height = 1.2
		cs.shape = c
		cs.position = Vector3(0.0, 0.6, 0.0)
		b.add_child(cs)
	# Далекі столові гори (у грі — намальований 2D-бекдроп з концепту).
	var mesa := Util.mat(Color(0.75, 0.42, 0.28), 1.0)
	Util.box(root, Vector3(40.0, 18.0, 20.0), Vector3(-45.0, 9.0, -110.0), mesa)
	Util.box(root, Vector3(55.0, 28.0, 25.0), Vector3(10.0, 14.0, -140.0), mesa)
	Util.box(root, Vector3(30.0, 14.0, 18.0), Vector3(60.0, 7.0, -95.0), mesa)


static func _cactus(root: Node3D, p: Vector3, m: Material) -> void:
	var c := StaticBody3D.new()
	root.add_child(c)
	c.position = p
	Util.cyl(c, 0.32, 0.36, 3.2, Vector3(0.0, 1.6, 0.0), m)
	Util.sphere(c, 0.32, Vector3(0.0, 3.2, 0.0), m)
	Util.cyl(c, 0.18, 0.2, 1.0, Vector3(-0.6, 1.9, 0.0), m)
	Util.cyl(c, 0.2, 0.2, 0.6, Vector3(-0.35, 1.45, 0.0), m, Vector3(0, 0, 90))
	Util.cyl(c, 0.16, 0.18, 0.9, Vector3(0.55, 2.3, 0.0), m)
	Util.cyl(c, 0.18, 0.18, 0.5, Vector3(0.32, 1.9, 0.0), m, Vector3(0, 0, 90))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 3.4, 0.7)
	cs.shape = bs
	cs.position = Vector3(0.0, 1.7, 0.0)
	c.add_child(cs)
