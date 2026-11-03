extends Node3D
## Гравець: камера з легким зсувом за прицілом, hitscan-стрільба,
## рикошети з «магнітом», перезарядка і зміна зброї.

const WeaponData = preload("res://scripts/data/weapon_data.gd")
const Weapons = preload("res://scripts/data/weapons.gd")
const Viewmodel = preload("res://scripts/viewmodel.gd")
const ScoreManager = preload("res://scripts/score_manager.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const Sfx = preload("res://scripts/fx/sfx.gd")

signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal weapon_changed(display_name: String)
signal shot_fired

const EYE_POS := Vector3(0.0, 1.6, 0.0)
const BASE_PITCH := 4.0
const SWAY_YAW := 4.0
const SWAY_PITCH := 2.5
const RANGE := 90.0
const MAX_SEGMENTS := 10
## Зброя дивиться в точку на цій відстані вздовж прицілу (без raycast:
## інакше предмети, що пролітають під курсором, смикають ствол).
const AIM_DISTANCE := 20.0

var camera: Camera3D
var viewmodel: Viewmodel
var score: ScoreManager
var fx: Fx
var sfx: Sfx
var weapons: Array = []
var weapon: WeaponData
var ammo: Dictionary = {}

var _cooldown: float = 0.0
var _want_fire: bool = false
var _reloading: bool = false
var _sway := Vector2(0.0, BASE_PITCH)
var _shake: float = 0.0
var _aim_point := Vector3(0.0, 3.0, -10.0)


func _ready() -> void:
	position = EYE_POS
	camera = Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.make_current()
	viewmodel = Viewmodel.new()
	camera.add_child(viewmodel)
	viewmodel.trick_started.connect(_on_trick_started)
	weapons = [Weapons.revolver(), Weapons.lever_rifle()]
	for w in weapons:
		ammo[w.id] = w.mag_size
	_equip(0)


func setup(score_manager: ScoreManager, effects: Fx, sounds: Sfx) -> void:
	score = score_manager
	fx = effects
	sfx = sounds


## Повторно розсилає стан для HUD, що підписався пізніше.
func emit_state() -> void:
	weapon_changed.emit(weapon.display_name)
	_emit_ammo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		_want_fire = true
	elif event.is_action_pressed("reload"):
		_start_reload()
	elif event.is_action_pressed("weapon_1"):
		_equip(0)
	elif event.is_action_pressed("weapon_2"):
		_equip(1)


func _process(delta: float) -> void:
	# Камера злегка повертається за прицілом (до ±4° / ±2.5°).
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var m := vp.get_mouse_position()
	var n := Vector2(m.x / size.x, m.y / size.y) * 2.0 - Vector2.ONE
	n = n.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	var target := Vector2(-n.x * SWAY_YAW, BASE_PITCH - n.y * SWAY_PITCH)
	_sway = _sway.lerp(target, 1.0 - exp(-5.0 * delta))
	camera.rotation_degrees = Vector3(_sway.y, _sway.x, 0.0)
	# Тряска від пострілу.
	_shake = maxf(_shake - delta * 2.5, 0.0)
	var s := _shake * _shake
	camera.h_offset = randf_range(-1.0, 1.0) * s * 0.08
	camera.v_offset = randf_range(-1.0, 1.0) * s * 0.08
	_update_aim_point()
	viewmodel.set_aim_point(_aim_point)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _want_fire:
		_want_fire = false
		_try_fire()


func _update_aim_point() -> void:
	var m := get_viewport().get_mouse_position()
	_aim_point = camera.project_ray_origin(m) + camera.project_ray_normal(m) * AIM_DISTANCE


func _equip(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if weapon != null and weapons[index] == weapon:
		return
	if _reloading:
		_cancel_reload()
	weapon = weapons[index]
	viewmodel.set_weapon(weapon)
	weapon_changed.emit(weapon.display_name)
	_emit_ammo()


func _try_fire() -> void:
	if weapon == null or _cooldown > 0.0:
		return
	var current: int = int(ammo[weapon.id])
	if current <= 0:
		sfx.play("dry_click")
		viewmodel.play_dry()
		_start_reload()
		return
	if _reloading:
		_cancel_reload()
	ammo[weapon.id] = current - 1
	_cooldown = weapon.fire_cooldown
	viewmodel.play_fire()
	_shake = maxf(_shake, weapon.camera_shake)
	sfx.play(weapon.shot_sound, 0.0, weapon.shot_pitch)
	if weapon.two_handed:
		sfx.play_delayed("lever_cycle", 0.12)
	shot_fired.emit()
	_fire_ray()
	_emit_ammo()
	if int(ammo[weapon.id]) == 0:
		get_tree().create_timer(0.35).timeout.connect(_auto_reload.bind(weapon))


## Постріл: промінь з камери через приціл, далі — сегменти рикошетів.
func _fire_ray() -> void:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var already_hit: Array = []
	var bounces_left: int = weapon.ricochets
	var seg_start := origin
	var visual_start := viewmodel.muzzle_position()
	score.begin_shot()
	for _i in MAX_SEGMENTS:
		var q := PhysicsRayQueryParameters3D.create(seg_start, seg_start + dir * RANGE)
		q.exclude = exclude
		var res := space.intersect_ray(q)
		if res.is_empty():
			fx.tracer(visual_start, seg_start + dir * 40.0, weapon.tracer_color)
			break
		var hit_pos: Vector3 = res["position"]
		var normal: Vector3 = res["normal"]
		var collider: Object = res["collider"]
		var rid: RID = res["rid"]
		fx.tracer(visual_start, hit_pos, weapon.tracer_color)
		var result: Dictionary = {"surface": "solid"}
		if collider != null and collider.has_method("on_bullet_hit"):
			result = collider.call("on_bullet_hit", hit_pos, dir, normal, weapon.impulse)
		var surface: String = str(result.get("surface", "solid"))
		_play_hit_sound(result, hit_pos)
		if bool(result.get("civilian", false)):
			score.register_civilian(hit_pos)
		elif bool(result.get("link", false)):
			# Гонг сам грошей не дає, але подовжує ланцюжок для наступної цілі.
			score.register_link(hit_pos, str(result.get("label", "")))
		elif int(result.get("points", 0)) > 0:
			score.register_hit(result, hit_pos)
			already_hit.append(collider)
		fx.impact(hit_pos, normal, surface)
		if surface == "glass":
			# Скло пробивається — куля летить далі тим самим курсом.
			exclude.append(rid)
			seg_start = hit_pos + dir * 0.02
			visual_start = hit_pos
			continue
		if (surface == "object" or surface == "metal") and bounces_left > 0:
			bounces_left -= 1
			# Кожен наступний відскок — вищий «пті-і-інг».
			var bounce_index := weapon.ricochets - bounces_left
			sfx.play("ricochet", 0.0, 1.0 + 0.1 * float(bounce_index - 1))
			dir = _ricochet_dir(hit_pos, dir, normal, collider, already_hit, surface)
			exclude.append(rid)
			seg_start = hit_pos + dir * 0.02
			visual_start = hit_pos
			continue
		break
	score.end_shot()


## Відбиття за нормаллю + аркадні правила: від підкинутих предметів куля летить углиб сцени,
## від металу — чесно за нормаллю; «магніт» доводить її до найближчої цілі в конусі.
func _ricochet_dir(from: Vector3, dir: Vector3, normal: Vector3, current: Object, already_hit: Array, surface: String) -> Vector3:
	var nn := normal.normalized()
	var out := (dir - 2.0 * dir.dot(nn) * nn).normalized()
	if surface == "object" and out.z > -0.25:
		out.z = -absf(out.z) - 0.25
		out = out.normalized()
	var best: Node3D = null
	var magnet_deg: float = weapon.magnet_angle_deg
	if surface == "metal":
		magnet_deg += 15.0
	var best_angle := deg_to_rad(magnet_deg)
	for node in get_tree().get_nodes_in_group("scorable"):
		var n3 := node as Node3D
		if n3 == null or n3 == current or already_hit.has(n3):
			continue
		if n3.has_method("is_scorable") and not bool(n3.call("is_scorable")):
			continue
		var target: Vector3 = n3.global_position
		if n3.has_method("aim_point"):
			target = n3.call("aim_point")
		var to := target - from
		if to.length() < 0.4:
			continue
		# Від металу — лише цілі перед площиною, щоб куля не проходила крізь гонг.
		if surface == "metal" and to.dot(nn) <= 0.0:
			continue
		var ang := out.angle_to(to)
		if ang < best_angle:
			best_angle = ang
			best = n3
	if best != null:
		var tp: Vector3 = best.global_position
		if best.has_method("aim_point"):
			tp = best.call("aim_point")
		return (tp - from).normalized()
	return out


## Звук влучання: ціль сама каже, який звук ("sound"); світ — пісок або дерево.
func _play_hit_sound(result: Dictionary, hit_pos: Vector3) -> void:
	var sound: String = str(result.get("sound", ""))
	if sound != "":
		sfx.play(sound)
	elif hit_pos.y < 0.1:
		sfx.play("land_dirt", 0.0, 1.3)
	else:
		sfx.play("hit_wood", -6.0, 0.85)


func _on_trick_started(two_handed: bool) -> void:
	if not two_handed and sfx != null:
		sfx.play("gun_twirl")


func _auto_reload(w: WeaponData) -> void:
	if w == weapon:
		_start_reload()


func _start_reload() -> void:
	if _reloading or weapon == null:
		return
	var missing: int = weapon.mag_size - int(ammo[weapon.id])
	if missing <= 0:
		return
	_reloading = true
	_emit_ammo()
	if not weapon.two_handed:
		sfx.play("reload_open")
	viewmodel.start_reload(missing, _on_round_loaded, _on_reload_done)


func _on_round_loaded() -> void:
	ammo[weapon.id] = mini(int(ammo[weapon.id]) + 1, weapon.mag_size)
	sfx.play("reload_insert", 0.0, 0.9 if weapon.two_handed else 1.0)
	_emit_ammo()


func _on_reload_done() -> void:
	_reloading = false
	sfx.play("lever_cycle" if weapon.two_handed else "reload_close")
	_emit_ammo()


func _cancel_reload() -> void:
	viewmodel.cancel_reload()
	_reloading = false
	_emit_ammo()


func _emit_ammo() -> void:
	ammo_changed.emit(int(ammo[weapon.id]), weapon.mag_size, _reloading)
