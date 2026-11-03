extends SceneTree
## Збирає scenes/levels/01_wild_west.tscn з моделей assets/models/01: розмітка рівня 1 живе тут.
##
##   godot --headless --path . --script tools/godot/build_level_01.gd
##
## Координати: камера в (0, 1.6, 0) дивиться на −Z; предмети летять у площині z ≈ −9.
## Компактний двір, як на концепті: фасад салуну праворуч, повернутий на 30° до гравця
## (ближній край за правим краєм кадру, дальній — у глибині по центру), паркан з пляшками
## ліворуч (x ≈ −6.2) і впоперек позаду (z ≈ −25). Модель «дивиться» на +Z; yaw — поворот навколо Y у градусах.

const OUT := "res://scenes/levels/01_wild_west.tscn"
const M := "res://assets/models/01/"
const WALL_H := 3.424
## Фасад: ближній край на лінії фасаду, напрям уздовж фасаду вглиб, нормаль — у двір.
const FACADE_YAW := -60.0
const FACADE_O := Vector3(12.3, 0.0, -6.0)
const FACADE_D := Vector3(-0.5, 0.0, -0.8660254)
const FACADE_N := Vector3(-0.8660254, 0.0, 0.5)
const MODULES := 5

var level: Node3D
var props: Node3D
var spawns: Node3D
var _count := {}


func _initialize() -> void:
	level = Node3D.new()
	level.name = "WildWest"
	level.set_script(load("res://scripts/levels/wild_west.gd"))
	props = _group("Props")
	spawns = _group("Spawns")
	_saloon()
	_fence()
	_yard()
	_targets()
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err != OK:
		push_error("pack failed %d" % err)
	err = ResourceSaver.save(packed, OUT)
	print("saved ", OUT, " err=", err, " props=", props.get_child_count(), " spawns=", spawns.get_child_count())
	level.free()
	quit()


func _group(n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	level.add_child(g)
	g.owner = level
	return g


## Ставить модель: позиція, yaw, масштаб, нахил (градуси навколо світових X і Z).
func place(id: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0, tilt := Vector2.ZERO) -> Node3D:
	var inst := (load(M + id + ".glb") as PackedScene).instantiate() as Node3D
	_count[id] = int(_count.get(id, 0)) + 1
	inst.name = "%s_%d" % [id, _count[id]]
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	b = Basis(Vector3.RIGHT, deg_to_rad(tilt.x)) * Basis(Vector3.BACK, deg_to_rad(tilt.y)) * b
	inst.transform = Transform3D(b.scaled(Vector3.ONE * s), pos)
	props.add_child(inst)
	inst.owner = level
	return inst


func marker(kind: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0, meta := {}) -> Marker3D:
	var mk := Marker3D.new()
	_count[kind] = int(_count.get(kind, 0)) + 1
	mk.name = "%s_%d" % [kind, _count[kind]]
	mk.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * s), pos)
	mk.set_meta("kind", kind)
	for k in meta:
		mk.set_meta(k, meta[k])
	spawns.add_child(mk)
	mk.owner = level
	return mk


## Точка на фасаді: u — метри вздовж фасаду від ближнього краю, h — висота, n — відступ у двір.
func fp(u: float, h: float, n: float) -> Vector3:
	return FACADE_O + FACADE_D * u + FACADE_N * n + Vector3(0.0, h, 0.0)


func _saloon() -> void:
	# Фасад: модулі по 4 м, два поверхи.
	for row in 2:
		for i in MODULES:
			place("saloon_wall", fp(2.0 + 4.0 * i, row * WALL_H, -0.275), FACADE_YAW)
	# Вікна: рама — модель, скло — Breakable (маркер трохи перед фасадом).
	for w in [Vector2(2.0, 1.75), Vector2(6.0, 1.75), Vector2(14.0, 1.75), Vector2(18.0, 1.75),
			Vector2(2.0, 5.15), Vector2(10.0, 5.15), Vector2(18.0, 5.15)]:
		place("window_frame", fp(w.x, w.y, 0.1), FACADE_YAW, 0.95)
		marker("window", fp(w.x, w.y, 0.08), FACADE_YAW, 1.0, {"pane": Vector2(1.35, 1.5)})
	# Двері-крила і темний проріз за ними.
	place("swing_doors", fp(10.0, 0.45, 0.12), FACADE_YAW, 1.05)
	var door := MeshInstance3D.new()
	door.name = "doorway"
	var bm := BoxMesh.new()
	bm.size = Vector3(2.1, 2.75, 0.08)
	door.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.06, 0.035, 0.02)
	dm.roughness = 1.0
	door.material_override = dm
	door.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(FACADE_YAW)), fp(10.0, 1.38, 0.02))
	props.add_child(door)
	door.owner = level
	# Вивіска «фальшфасаду» над дахом, ближче до гравця.
	var sign := place("saloon_sign", fp(5.0, 2.0 * WALL_H + 0.55, 0.25), FACADE_YAW, 1.0)
	var label := Label3D.new()
	label.name = "SaloonText"
	label.text = "SALOON"
	label.font = load("res://assets/fonts/Rye-Regular.ttf")
	label.font_size = 105
	label.pixel_size = 0.0085
	label.outline_size = 28
	label.modulate = Color(1.0, 0.9, 0.68)
	label.outline_modulate = Color(0.35, 0.08, 0.05)
	label.position = Vector3(0.0, 0.05, 0.23)
	label.shaded = true
	label.double_sided = false
	sign.add_child(label)
	label.owner = level
	# Ліхтарі на стіні.
	place("lantern", fp(4.0, 3.0, 0.17), FACADE_YAW)
	place("lantern", fp(12.0, 3.0, 0.17), FACADE_YAW)
	# Біля стіни: бочки, колесо, ящики.
	place("barrel", fp(4.6, 0.0, 0.9), 10.0)
	place("barrel", fp(5.9, 0.0, 0.85), -25.0, 0.95)
	place("barrel", fp(3.0, 0.0, 2.6), 30.0, 1.05)
	place("barrel", fp(19.0, 0.0, 0.8), 0.0, 0.9)
	# Колесо притулене до стіни: нахил навколо лінії фасаду верхом до стіни.
	var wheel := Basis(FACADE_D, deg_to_rad(11.0)) * Basis(Vector3.UP, deg_to_rad(FACADE_YAW))
	place_basis("wagon_wheel", fp(8.0, 0.0, 0.42), wheel, 1.1)
	place("crate", fp(12.6, 0.45, 0.75), -45.0, 0.9)
	place("crate", fp(12.6, 1.22, 0.7), -20.0, 0.65)


func place_basis(id: String, pos: Vector3, b: Basis, s: float = 1.0) -> Node3D:
	var inst := place(id, pos)
	inst.transform = Transform3D(b.scaled(Vector3.ONE * s), pos)
	return inst


func _fence() -> void:
	# Ліва лінія вздовж Z (дивиться на +X) і задня впоперек (дивиться на +Z) до кінця фасаду.
	for i in 7:
		place("fence_section", Vector3(-6.2, 0.0, -4.5 - 3.0 * i), 90.0)
	for i in 3:
		place("fence_section", Vector3(-4.7 + 3.0 * i, 0.0, -25.3), 0.0)
	# Рівна полиця-рейка по верху лівого паркану — на ній стоять пляшки.
	_shelf(Vector3(-6.2, 1.6, -8.4), Vector3(-6.2, 1.6, -21.0))
	var ids := ["bottle_brown", "bottle_clear", "bottle_green"]
	var k := 0
	for z in [-9.4, -11.4, -13.4, -15.4, -17.4, -19.6]:
		marker("bottle", Vector3(-6.2, 1.64, z), 0.0, 0.85, {"model": ids[k % 3]})
		k += 1
	# Ще кілька — на бочках і ящиках біля салуну, як на барній стійці.
	marker("bottle", fp(4.6, 1.2, 0.9), 0.0, 0.8, {"model": "bottle_green"})
	marker("bottle", fp(5.9, 1.14, 0.85), 0.0, 0.8, {"model": "bottle_brown"})
	marker("bottle", fp(12.6, 1.545, 0.7), 0.0, 0.75, {"model": "bottle_clear"})
	place("rope_coil", Vector3(-5.98, 1.05, -6.4), 90.0, 1.1)


## Дошка-полиця між двома точками (текстура — з моделі паркану).
func _shelf(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "shelf_%d" % props.get_child_count()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.07, a.distance_to(b))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(M + "fence_section_Image_0.jpg")
	m.albedo_color = Color(0.85, 0.8, 0.75)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	m.roughness = 0.9
	mi.material_override = m
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	props.add_child(mi)
	mi.owner = level


func _yard() -> void:
	place("crate", Vector3(-4.4, 0.62, -4.0), 18.0, 1.25)
	place("rocks", Vector3(-3.0, 0.0, -5.8), 20.0, 0.9)
	place("rocks", Vector3(2.0, 0.0, -6.2), -40.0, 0.55)
	place("rocks", Vector3(-1.6, 0.0, -16.5), 70.0, 0.7)
	place("cactus", Vector3(-0.4, 0.0, -23.3), -15.0, 1.0)
	place("cactus", Vector3(-8.6, 0.0, -17.0), 30.0, 0.85)
	place("cactus", Vector3(-5.0, 0.0, -38.0), 0.0, 1.4)
	place("tumbleweed", Vector3(-4.5, 0.5, -11.0), 0.0, 0.9)
	place("porch", Vector3(-12.5, 0.0, -34.0), 35.0, 0.55)
	marker("civilian", Vector3(0.0, 0.0, -11.0), 0.0, 1.0, {"walk": 5.0})


func _targets() -> void:
	# Мішені на стовпах: маркер — центр диска.
	marker("target", Vector3(-3.7, 1.42, -12.3), 20.0, 1.0, {"disc_height": 1.77})
	marker("target", Vector3(3.5, 1.78, -14.8), -25.0, 1.25, {"disc_height": 1.77})
	# Гонги: рама — модель, пластина — MetalPlate, розвернуті вбік для рикошетів через сцену.
	for g in [[Vector3(-2.4, 0.0, -17.5), 28.0], [Vector3(0.6, 0.0, -21.6), -30.0]]:
		place("gong_frame", g[0], g[1], 2.2)
		marker("gong", g[0] + Vector3(0.0, 2.06, 0.0), g[1], 1.0, {"radius": 0.87})
