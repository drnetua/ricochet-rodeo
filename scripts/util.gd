extends RefCounted
## Помічники для збирання моделей з примітивів.
## У грі примітиви замінюються на справжні моделі з PBR-текстурами.

static var _noise_normal: NoiseTexture2D


## Спільна normal-карта з шуму: дає матеріалам «фактуру» без текстур.
static func noise_normal() -> NoiseTexture2D:
	if _noise_normal == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.08
		var t := NoiseTexture2D.new()
		t.noise = n
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0
		t.width = 256
		t.height = 256
		_noise_normal = t
	return _noise_normal


static func mat(color: Color, roughness: float = 0.8, metallic: float = 0.0, bumpy: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if bumpy:
		m.normal_enabled = true
		m.normal_texture = noise_normal()
		m.normal_scale = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	return m


static func glass(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot_deg: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, box_size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = box_size
	return _add(parent, bm, pos, m, rot_deg, Vector3.ONE)


## Циліндр або конус (r_top = 0). Вісь — локальна Y.
static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 24
	return _add(parent, cm, pos, m, rot_deg, Vector3.ONE)


static func sphere(parent: Node3D, r: float, pos: Vector3, m: Material, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	return _add(parent, sm, pos, m, Vector3.ZERO, scl)


## Циліндр між двома точками (рука, рукав).
static func limb(parent: Node3D, a: Vector3, b: Vector3, r_a: float, r_b: float, m: Material) -> MeshInstance3D:
	var d := b - a
	var h := d.length()
	var cm := CylinderMesh.new()
	cm.top_radius = r_b
	cm.bottom_radius = r_a
	cm.height = h
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	var y := d / h
	var helper := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := helper.cross(y).normalized()
	var x := y.cross(z).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


## Статичне тіло-коробка з колізією (стіни, паркан, стовпи).
static func static_box(parent: Node3D, box_size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	parent.add_child(body)
	box(body, box_size, Vector3.ZERO, m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	cs.shape = bs
	body.add_child(cs)
	return body
