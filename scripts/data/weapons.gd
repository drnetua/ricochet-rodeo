extends RefCounted
## Стартові пресети зброї. У грі — .tres-ресурси в res://data/weapons/.

const WeaponData = preload("res://scripts/data/weapon_data.gd")


static func revolver() -> WeaponData:
	var w := WeaponData.new()
	w.id = "revolver"
	w.display_name = "Револьвер"
	w.mag_size = 6
	w.ricochets = 2
	w.magnet_angle_deg = 30.0
	w.fire_cooldown = 0.18
	w.reload_per_round = 0.2
	w.two_handed = false
	w.recoil_kick_deg = 16.0
	w.recoil_push = 0.06
	w.aim_lag = 10.0
	w.impulse = 7.0
	w.camera_shake = 0.35
	w.shot_sound = "revolver_shot"
	w.shot_pitch = 1.0
	w.tracer_color = Color(1.0, 0.85, 0.35, 0.95)
	return w


static func lever_rifle() -> WeaponData:
	var w := WeaponData.new()
	w.id = "lever_rifle"
	w.display_name = "Гвинтівка з важелем"
	w.mag_size = 8
	w.ricochets = 3
	w.magnet_angle_deg = 24.0
	w.fire_cooldown = 0.42
	w.reload_per_round = 0.26
	w.two_handed = true
	w.recoil_kick_deg = 10.0
	w.recoil_push = 0.1
	w.aim_lag = 7.0
	w.impulse = 11.0
	w.camera_shake = 0.55
	w.shot_sound = "rifle_shot"
	w.shot_pitch = 1.0
	w.tracer_color = Color(1.0, 0.6, 0.25, 0.95)
	return w
