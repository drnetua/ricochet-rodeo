extends SceneTree
## Збирає scenes/levels/01_wild_west.tscn з моделей assets/models/01: розмітка рівня 1 живе тут.
##
##   godot --headless --path . --script tools/godot/build_level_01.gd
##
## Координати: камера в (0, 1.6, 0) дивиться на −Z; предмети летять у площині z ≈ −9.
## Салун — праворуч (фасад x ≈ 7.5 дивиться на −X), паркан з пляшками — ліворуч (x ≈ −7.6)
## і впоперек позаду (z ≈ −33). Модель «дивиться» на +Z; yaw — поворот навколо Y у градусах.

const OUT := "res://scenes/levels/01_wild_west.tscn"
const M := "res://assets/models/01/"
const WALL_X := 7.8
const WALL_H := 3.424

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


func _saloon() -> void:
	# Фасад: 6 модулів по 4 м уздовж Z, два поверхи.
	for row in 2:
		for i in 6:
			place("saloon_wall", Vector3(WALL_X, row * WALL_H, -11.0 - 4.0 * i), -90.0)
	# Вікна: рама — модель, скло — Breakable (маркер трохи перед фасадом).
	var face := WALL_X - 0.275
	for p in [Vector2(-11.0, 1.75), Vector2(-15.0, 1.75), Vector2(-23.0, 1.75), Vector2(-27.0, 1.75),
			Vector2(-11.0, 5.15), Vector2(-19.0, 5.15), Vector2(-27.0, 5.15)]:
		place("window_frame", Vector3(face - 0.1, p.y, p.x), -90.0, 0.95)
		marker("window", Vector3(face - 0.08, p.y, p.x), -90.0, 1.0, {"pane": Vector2(1.35, 1.5)})
	# Двері-крила і темний проріз за ними.
	place("swing_doors", Vector3(face - 0.12, 0.45, -19.0), -90.0, 1.05)
	var door := MeshInstance3D.new()
	door.name = "doorway"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 2.75, 2.1)
	door.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.06, 0.035, 0.02)
	dm.roughness = 1.0
	door.material_override = dm
	door.position = Vector3(face - 0.02, 1.38, -19.0)
	props.add_child(door)
	door.owner = level
	# Вивіска «фальшфасаду» над дахом, ближче до гравця.
	var sign := place("saloon_sign", Vector3(face - 0.25, 2.0 * WALL_H + 0.55, -13.0), -90.0, 1.0)
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
	place("lantern", Vector3(face - 0.17, 3.0, -9.4), -90.0)
	place("lantern", Vector3(face - 0.17, 3.0, -21.0), -90.0)
	# Біля стіни: бочки, колесо, ящики.
	place("barrel", Vector3(6.35, 0.0, -10.0), 10.0)
	place("barrel", Vector3(6.55, 0.0, -11.35), -25.0, 0.95)
	place("barrel", Vector3(6.6, 0.0, -6.0), 30.0, 1.05)
	place("barrel", Vector3(6.2, 0.0, -25.2), 0.0, 0.9)
	place("wagon_wheel", Vector3(7.08, 0.0, -16.3), -90.0, 1.1, Vector2(0.0, -11.0))
	place("crate", Vector3(5.9, 0.45, -14.6), -25.0, 0.9)
	place("crate", Vector3(5.95, 1.22, -14.7), 12.0, 0.65)


func _fence() -> void:
	# Ліва лінія вздовж Z (дивиться на +X) і задня впоперек (дивиться на +Z).
	for i in 10:
		place("fence_section", Vector3(-7.6, 0.0, -4.5 - 3.0 * i), 90.0)
	for i in 5:
		place("fence_section", Vector3(-6.1 + 3.0 * i, 0.0, -33.2), 0.0)
	# Пляшки на верхній рейці.
	var ids := ["bottle_brown", "bottle_clear", "bottle_green"]
	var k := 0
	for z in [-11.0, -13.5, -16.0, -18.5, -21.0]:
		marker("bottle", Vector3(-7.6, 1.66, z), 0.0, 0.85, {"model": ids[k % 3]})
		k += 1
	for x in [-5.0, -2.0, 1.0, 4.0]:
		marker("bottle", Vector3(x, 1.66, -33.2), 0.0, 0.95, {"model": ids[k % 3]})
		k += 1
	place("rope_coil", Vector3(-7.38, 1.05, -6.4), 90.0, 1.1)


func _yard() -> void:
	place("crate", Vector3(-5.0, 0.62, -4.2), 18.0, 1.25)
	place("rocks", Vector3(-3.6, 0.0, -6.2), 20.0, 0.9)
	place("rocks", Vector3(2.4, 0.0, -6.6), -40.0, 0.55)
	place("rocks", Vector3(-1.4, 0.0, -21.5), 70.0, 0.7)
	place("cactus", Vector3(0.9, 0.0, -28.0), -15.0, 1.0)
	place("cactus", Vector3(-10.8, 0.0, -24.0), 30.0, 0.85)
	place("cactus", Vector3(-4.0, 0.0, -48.0), 0.0, 1.4)
	place("tumbleweed", Vector3(-6.0, 0.5, -12.5), 0.0, 0.9)
	place("porch", Vector3(-13.5, 0.0, -42.0), 35.0, 0.55)
	marker("civilian", Vector3(0.0, 0.0, -11.5), 0.0, 1.0, {"walk": 6.0})


func _targets() -> void:
	# Мішені на стовпах: маркер — центр диска.
	marker("target", Vector3(-5.0, 1.42, -13.0), 20.0, 1.0, {"disc_height": 1.77})
	marker("target", Vector3(4.6, 1.78, -18.0), -15.0, 1.25, {"disc_height": 1.77})
	# Гонги: рама — модель, пластина — MetalPlate, розвернуті вбік для рикошетів через сцену.
	for g in [[Vector3(-3.2, 0.0, -20.0), 28.0], [Vector3(2.0, 0.0, -25.0), -30.0]]:
		place("gong_frame", g[0], g[1], 2.4)
		marker("gong", g[0] + Vector3(0.0, 2.25, 0.0), g[1], 1.0, {"radius": 0.95})
