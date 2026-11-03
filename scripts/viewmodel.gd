extends Node3D
## Рука зі зброєю перед камерою: наведення з інерцією, idle-похитування, віддача,
## перезарядка (одна або дві руки), трюк у простої, спалах пострілу.
## Анімації процедурні (Tween + пружини); у грі reload і трюки замінюються на AnimationPlayer.

const WeaponData = preload("res://scripts/data/weapon_data.gd")
const Util = preload("res://scripts/util.gd")

signal trick_started(two_handed: bool)

const BASE_POS := Vector3(0.42, -0.34, -0.82)
const IDLE_TRICK_AFTER := 5.0
## Поріг наведення: зброя ігнорує рухи прицілу, менші за цей кут, і йде
## слідом, лише коли приціл відійшов далі, — без дрібного тремтіння.
const AIM_DEADZONE_DEG := 1.5
const LEFT_HIDDEN := Vector3(-0.38, -0.55, 0.3)
const LEFT_ON_FOREND := Vector3(0.0, -0.085, -0.42)
const LEFT_AT_CYLINDER := Vector3(-0.08, -0.05, -0.06)
const LEFT_AT_GATE := Vector3(0.06, -0.06, -0.06)
## Моделі рук з конвеєра асетів (Meshy). Без них — заглушки з примітивів.
const HAND_REVOLVER := "res://assets/models/01/hand_revolver.glb"
const HAND_LEFT := "res://assets/models/01/hand_left.glb"
## Модель: ствол уздовж −X і трохи вгору → повертаємо стволом на −Z і вирівнюємо.
const REVOLVER_YAW := -90.0
const REVOLVER_PITCH := -15.0
const REVOLVER_SCALE := 1.55
const REVOLVER_OFFSET := Vector3(0.0, 0.05, 0.26)
const REVOLVER_MUZZLE := Vector3(-0.295, 0.169, -0.027)
## Окреме світло лише для руки: шар 20 у моделей рук і cull_mask світла.
const HERO_LAYER := 1 << 19
const OUTLINE_SHADER := "res://assets/shaders/outline.gdshader"

var weapon: WeaponData

var _aim_point := Vector3(0.0, 3.0, -10.0)
var _aim_q := Quaternion.IDENTITY
var _aim_dir := Vector3(0.0, 0.25, -1.0).normalized()
var _recoil: float = 0.0
var _push: float = 0.0
var _t: float = 0.0
var _idle: float = 0.0

var _aim: Node3D
var _gun_pivot: Node3D
var _gun: Node3D
var _lever: Node3D
var _muzzle: Node3D
var _left: Node3D
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _reload_tween: Tween
var _trick_tween: Tween
var _lever_tween: Tween

var _glove_mat: StandardMaterial3D
var _sleeve_mat: StandardMaterial3D
var _arm_prims: Node3D
var _left_prims: Node3D
var _left_model: Node3D
var _hero_outline: ShaderMaterial
## true — револьвер з моделі (рука в моделі, тож трюк і рукав інші).
var _model_mode: bool = false


func _ready() -> void:
	position = BASE_POS
	_glove_mat = Util.mat(Color(0.5, 0.3, 0.15), 0.75, 0.0, true)
	_sleeve_mat = Util.mat(Color(0.7, 0.2, 0.16), 0.95, 0.0, true)
	_aim = Node3D.new()
	add_child(_aim)
	_gun_pivot = Node3D.new()
	_aim.add_child(_gun_pivot)
	_hero_outline = ShaderMaterial.new()
	_hero_outline.shader = load(OUTLINE_SHADER)
	_hero_outline.set_shader_parameter("thickness", 0.006)
	_arm_prims = Node3D.new()
	_aim.add_child(_arm_prims)
	_build_right_arm()
	_left = Node3D.new()
	_aim.add_child(_left)
	_left_prims = Node3D.new()
	_left.add_child(_left_prims)
	_build_left_arm()
	_build_left_model()
	_hero_light()
	_aim_q = Basis.looking_at(Vector3(0.0, 0.25, -1.0).normalized(), Vector3.UP).get_rotation_quaternion()


func set_aim_point(p: Vector3) -> void:
	_aim_point = p


func muzzle_position() -> Vector3:
	if _muzzle != null:
		return _muzzle.global_position
	return global_position


func set_weapon(w: WeaponData) -> void:
	cancel_reload()
	_stop_trick()
	weapon = w
	if _gun != null:
		_gun.queue_free()
	_gun = Node3D.new()
	_gun_pivot.add_child(_gun)
	_lever = null
	_model_mode = false
	if w.id == "lever_rifle":
		_build_rifle()
	elif not _build_revolver_model():
		_build_revolver()
	_arm_prims.visible = not _model_mode
	if _left_model != null:
		_left_model.visible = not w.two_handed
		_left_prims.visible = w.two_handed
	_left.visible = w.two_handed
	_left.position = LEFT_ON_FOREND if w.two_handed else LEFT_HIDDEN
	# Анімація «дістав зброю»: ствол знизу пружинить у приціл.
	_recoil = -0.6


func _process(delta: float) -> void:
	if weapon == null:
		return
	_t += delta
	_idle += delta
	var bob := Vector3(sin(_t * 1.7) * 0.004, sin(_t * 2.3) * 0.006, 0.0)
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-9.0 * delta))
	_push = lerpf(_push, 0.0, 1.0 - exp(-11.0 * delta))
	_aim.position = bob + Vector3(0.0, 0.0, _push)
	# Зброя доганяє приціл з інерцією: важча зброя — повільніше.
	var to := _aim_point - _aim.global_position
	if to.length_squared() > 0.0001:
		var want := to.normalized()
		var ang := _aim_dir.angle_to(want)
		var dz := deg_to_rad(AIM_DEADZONE_DEG)
		if ang > dz:
			# Підтягуємо напрямок рівно настільки, щоб приціл лишився на межі зони.
			_aim_dir = _aim_dir.slerp(want, (ang - dz) / ang).normalized()
		var target_q := Basis.looking_at(_aim_dir, Vector3.UP).get_rotation_quaternion()
		_aim_q = _aim_q.slerp(target_q, 1.0 - exp(-weapon.aim_lag * delta))
	var b := Basis(_aim_q) * Basis(Vector3.RIGHT, _recoil)
	_aim.global_transform = Transform3D(b, _aim.global_position)
	if _idle > IDLE_TRICK_AFTER and not is_reloading():
		_idle = 0.0
		_play_trick()


func play_fire() -> void:
	_idle = 0.0
	_stop_trick()
	_recoil += deg_to_rad(weapon.recoil_kick_deg)
	_push += weapon.recoil_push
	_flash()
	if _lever != null:
		if _lever_tween != null and _lever_tween.is_valid():
			_lever_tween.kill()
		_lever_tween = create_tween()
		_lever_tween.tween_interval(0.12)
		_lever_tween.tween_property(_lever, "rotation:x", 1.0, 0.1)
		_lever_tween.tween_property(_lever, "rotation:x", 0.0, 0.12)


func play_dry() -> void:
	_idle = 0.0
	# Трусимо саму модель, а не півот — щоб не збивати нахил перезарядки.
	var tw := create_tween()
	tw.tween_property(_gun, "rotation:z", 0.12, 0.05)
	tw.tween_property(_gun, "rotation:z", -0.08, 0.06)
	tw.tween_property(_gun, "rotation:z", 0.0, 0.06)


func is_reloading() -> bool:
	return _reload_tween != null and _reload_tween.is_valid() and _reload_tween.is_running()


## Перезарядка по одному набою. on_round викликається на кожен набій,
## on_done — у кінці. Постріл під час перезарядки її перериває (cancel_reload).
func start_reload(rounds: int, on_round: Callable, on_done: Callable) -> void:
	if is_reloading() or weapon == null:
		return
	_stop_trick()
	_idle = 0.0
	var per: float = weapon.reload_per_round
	var two: bool = weapon.two_handed
	var hand_target: Vector3 = LEFT_AT_GATE if two else LEFT_AT_CYLINDER
	var tilt := Vector3(deg_to_rad(22.0), 0.0, deg_to_rad(-30.0 if two else 60.0))
	var tw := create_tween()
	_reload_tween = tw
	tw.tween_property(_gun_pivot, "rotation", tilt, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not two:
		tw.tween_callback(_show_left_hand)
	tw.tween_property(_left, "position", hand_target, 0.14).set_trans(Tween.TRANS_SINE)
	for _i in rounds:
		tw.tween_property(_left, "position", hand_target + Vector3(-0.02, -0.06, 0.04), per * 0.45)
		tw.tween_property(_left, "position", hand_target, per * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(on_round)
	tw.tween_property(_left, "position", LEFT_ON_FOREND if two else LEFT_HIDDEN, 0.14)
	tw.parallel().tween_property(_gun_pivot, "rotation", Vector3.ZERO, 0.18)
	if _lever != null:
		tw.tween_property(_lever, "rotation:x", 1.0, 0.1)
		tw.tween_property(_lever, "rotation:x", 0.0, 0.12)
	tw.tween_callback(_after_reload)
	tw.tween_callback(on_done)


func cancel_reload() -> void:
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_tween = null
	_gun_pivot.rotation = Vector3.ZERO
	if _lever != null:
		_lever.rotation = Vector3.ZERO
	if weapon != null:
		_left.visible = weapon.two_handed
		_left.position = LEFT_ON_FOREND if weapon.two_handed else LEFT_HIDDEN


func _show_left_hand() -> void:
	_left.visible = true
	_left.position = LEFT_HIDDEN


func _after_reload() -> void:
	_left.visible = weapon.two_handed


func _play_trick() -> void:
	_stop_trick()
	trick_started.emit(weapon.two_handed)
	_trick_tween = create_tween()
	if weapon.two_handed:
		# Гвинтівка: перекинути на плече і назад.
		_trick_tween.tween_property(_gun_pivot, "rotation:z", 0.45, 0.25).set_trans(Tween.TRANS_SINE)
		_trick_tween.tween_property(_gun_pivot, "rotation:z", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	elif _model_mode:
		# Рука з револьвером — одна модель, тож замість обертів на пальці — «показ»: підкинути ствол і повернути.
		_trick_tween.tween_property(_gun_pivot, "rotation", Vector3(0.55, 0.0, 0.5), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_trick_tween.tween_property(_gun_pivot, "rotation", Vector3(0.2, 0.0, -0.35), 0.18).set_trans(Tween.TRANS_SINE)
		_trick_tween.tween_property(_gun_pivot, "rotation", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Револьвер: два оберти на пальці.
		_trick_tween.tween_property(_gun_pivot, "rotation:x", -TAU * 2.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_trick_tween.tween_callback(_reset_pivot)


func _stop_trick() -> void:
	if _trick_tween != null and _trick_tween.is_valid():
		_trick_tween.kill()
		_reset_pivot()
	_trick_tween = null


func _reset_pivot() -> void:
	_gun_pivot.rotation = Vector3.ZERO


func _flash() -> void:
	_flash_light.light_energy = 8.0
	_flash_mesh.visible = true
	_flash_mesh.scale = Vector3(1.0, 1.0, randf_range(1.5, 2.6)) * randf_range(0.8, 1.3)
	_flash_mesh.rotation.z = randf() * TAU
	var tw := create_tween()
	tw.tween_property(_flash_light, "light_energy", 0.0, 0.09)
	tw.parallel().tween_callback(_hide_flash).set_delay(0.045)


func _hide_flash() -> void:
	if _flash_mesh != null:
		_flash_mesh.visible = false


# --- Моделі з примітивів (заглушки під майбутні моделі) ---

func _build_right_arm() -> void:
	Util.sphere(_arm_prims, 0.075, Vector3(0.0, -0.065, 0.07), _glove_mat, Vector3(1.0, 0.95, 1.3))
	Util.limb(_arm_prims, Vector3(0.0, -0.08, 0.1), Vector3(0.01, -0.12, 0.22), 0.07, 0.085, _glove_mat)
	Util.limb(_arm_prims, Vector3(0.01, -0.11, 0.2), Vector3(0.06, -0.5, 0.85), 0.09, 0.115, _sleeve_mat)


func _build_left_arm() -> void:
	Util.sphere(_left_prims, 0.07, Vector3.ZERO, _glove_mat, Vector3(1.15, 0.85, 1.2))
	Util.limb(_left_prims, Vector3(0.0, -0.02, 0.05), Vector3(-0.02, -0.06, 0.16), 0.065, 0.08, _glove_mat)
	Util.limb(_left_prims, Vector3(-0.02, -0.05, 0.15), Vector3(-0.36, -0.5, 0.75), 0.085, 0.11, _sleeve_mat)


func _build_revolver() -> void:
	var steel := Util.mat(Color(0.34, 0.35, 0.38), 0.35, 0.9, true)
	var wood := Util.mat(Color(0.45, 0.25, 0.12), 0.7, 0.0, true)
	var brass := Util.mat(Color(0.8, 0.62, 0.25), 0.3, 0.9)
	Util.box(_gun, Vector3(0.075, 0.17, 0.1), Vector3(0.0, -0.07, 0.05), wood, Vector3(-18, 0, 0))
	Util.box(_gun, Vector3(0.08, 0.09, 0.2), Vector3(0.0, 0.02, -0.06), steel)
	Util.cyl(_gun, 0.065, 0.065, 0.12, Vector3(0.0, 0.03, -0.07), steel, Vector3(90, 0, 0))
	Util.cyl(_gun, 0.034, 0.034, 0.36, Vector3(0.0, 0.05, -0.3), steel, Vector3(90, 0, 0))
	Util.box(_gun, Vector3(0.02, 0.03, 0.02), Vector3(0.0, 0.085, -0.46), brass)
	Util.box(_gun, Vector3(0.025, 0.05, 0.04), Vector3(0.0, 0.08, 0.03), steel, Vector3(-30, 0, 0))
	Util.box(_gun, Vector3(0.012, 0.05, 0.06), Vector3(0.0, -0.04, -0.03), brass)
	_gun.scale = Vector3.ONE * 1.25
	_set_muzzle(Vector3(0.0, 0.05, -0.49))


func _build_rifle() -> void:
	var steel := Util.mat(Color(0.3, 0.31, 0.34), 0.35, 0.9, true)
	var wood := Util.mat(Color(0.5, 0.28, 0.13), 0.7, 0.0, true)
	var brass := Util.mat(Color(0.82, 0.64, 0.28), 0.3, 0.9, true)
	Util.box(_gun, Vector3(0.065, 0.13, 0.36), Vector3(0.0, -0.06, 0.24), wood, Vector3(8, 0, 0))
	Util.box(_gun, Vector3(0.07, 0.1, 0.22), Vector3(0.0, 0.0, -0.04), brass)
	Util.cyl(_gun, 0.026, 0.026, 0.8, Vector3(0.0, 0.035, -0.55), steel, Vector3(90, 0, 0))
	Util.cyl(_gun, 0.018, 0.018, 0.62, Vector3(0.0, -0.01, -0.48), steel, Vector3(90, 0, 0))
	Util.box(_gun, Vector3(0.075, 0.06, 0.3), Vector3(0.0, -0.005, -0.33), wood)
	_lever = Node3D.new()
	_lever.position = Vector3(0.0, -0.05, 0.02)
	_gun.add_child(_lever)
	Util.box(_lever, Vector3(0.015, 0.09, 0.015), Vector3(0.0, -0.045, 0.0), steel)
	Util.box(_lever, Vector3(0.015, 0.015, 0.11), Vector3(0.0, -0.09, 0.05), steel)
	Util.box(_lever, Vector3(0.015, 0.07, 0.015), Vector3(0.0, -0.055, 0.1), steel)
	_gun.scale = Vector3.ONE * 1.15
	_set_muzzle(Vector3(0.0, 0.035, -0.96))


func _set_muzzle(pos: Vector3) -> void:
	_muzzle = Node3D.new()
	_muzzle.position = pos
	_gun.add_child(_muzzle)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.35)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 4.0
	_muzzle.add_child(_flash_light)
	_flash_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	_flash_mesh.mesh = sm
	_flash_mesh.material_override = Util.unshaded(Color(1.0, 0.9, 0.55))
	_flash_mesh.position = Vector3(0.0, 0.0, -0.08)
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle.add_child(_flash_mesh)


## Права рука з револьвером — одна модель Meshy. false — моделі нема.
func _build_revolver_model() -> bool:
	if not ResourceLoader.exists(HAND_REVOLVER):
		return false
	var model := (load(HAND_REVOLVER) as PackedScene).instantiate() as Node3D
	var b := Basis(Vector3.RIGHT, deg_to_rad(REVOLVER_PITCH)) * Basis(Vector3.UP, deg_to_rad(REVOLVER_YAW))
	model.transform = Transform3D(b.scaled(Vector3.ONE * REVOLVER_SCALE), REVOLVER_OFFSET)
	_gun.add_child(model)
	_hero_meshes(model)
	_set_muzzle(model.transform * REVOLVER_MUZZLE)
	_model_mode = true
	return true


## Ліва рука з набоєм для перезарядки револьвера.
func _build_left_model() -> void:
	if not ResourceLoader.exists(HAND_LEFT):
		return
	_left_model = (load(HAND_LEFT) as PackedScene).instantiate() as Node3D
	_left_model.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-35.0)).scaled(Vector3.ONE * 1.0), Vector3(-0.02, 0.0, 0.12))
	_left.add_child(_left_model)
	_hero_meshes(_left_model)


## Моделі рук: шар для «геройського» світла і товстіший контур.
func _hero_meshes(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.layers = 1 | HERO_LAYER
		mi.material_overlay = _hero_outline
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Тепле світло зверху-зліва лише на руку: вона читається на будь-якому фоні.
func _hero_light() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.65)
	l.light_energy = 0.45
	l.omni_range = 2.5
	l.light_cull_mask = HERO_LAYER
	l.position = Vector3(-0.45, 0.45, 0.25)
	add_child(l)
