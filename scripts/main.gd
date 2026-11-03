extends Node3D
## Точка входу прототипу: збирає рівень, гравця, кидалку, очки й HUD,
## тримає ритм рівня (запас кидків), slow-mo і табло в кінці.

const LEVEL_SCENE := "res://scenes/levels/01_wild_west.tscn"
const Thrower = preload("res://scripts/thrower.gd")
const Player = preload("res://scripts/player.gd")
const ScoreManager = preload("res://scripts/score_manager.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Crosshair = preload("res://scripts/ui/crosshair.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const Sfx = preload("res://scripts/fx/sfx.gd")

const THROWS_PER_LEVEL := 15
const STAR_THRESHOLDS := [300, 700, 1200]
const SLOWMO_SCALE := 0.3
const SLOWMO_TIME_MS := 650
const HITSTOP_SCALE := 0.05
const HITSTOP_TIME_MS := 45
const CROWD_COOLDOWN_MS := 4000

var score: ScoreManager
var fx: Fx
var sfx: Sfx
var player: Player
var thrower: Thrower
var hud: Hud

var throws_left: int = THROWS_PER_LEVEL
var _alive_objects: int = 0
var _level_over: bool = false
var _time_restore_at: int = 0
var _slowmo_until: int = 0
var _crowd_ready_at: int = 0
var _accent_timer: Timer


func _ready() -> void:
	Engine.time_scale = 1.0
	_setup_input()
	fx = Fx.new()
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	score = ScoreManager.new()
	add_child(score)
	add_child((load(LEVEL_SCENE) as PackedScene).instantiate())
	thrower = Thrower.new()
	add_child(thrower)
	player = Player.new()
	add_child(player)
	player.setup(score, fx, sfx)
	hud = Hud.new()
	add_child(hud)
	hud.bind(score, player)
	hud.update_throws(throws_left)
	player.emit_state()
	score.popup.connect(fx.float_text)
	score.chain_reached.connect(_on_chain)
	score.shot_finished.connect(_on_shot_finished)
	score.combo_broken.connect(_on_combo_broken)
	thrower.object_finished.connect(_on_object_finished)
	_set_aiming(true)
	_start_audio()


func _start_audio() -> void:
	sfx.play_ambience()
	sfx.play_music("gameplay", 2.0)
	# Рідкісні звуки салуну на фоні — «живий» світ.
	_accent_timer = Timer.new()
	_accent_timer.one_shot = true
	add_child(_accent_timer)
	_accent_timer.timeout.connect(_on_accent)
	_accent_timer.start(randf_range(8.0, 15.0))


func _on_accent() -> void:
	sfx.play("saloon_doors")
	_accent_timer.start(randf_range(12.0, 25.0))


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_set_aiming(false)


func _process(_delta: float) -> void:
	# Час відновлюється за реальним годинником, бо slow-mo сповільнює і таймери.
	if _time_restore_at > 0 and Time.get_ticks_msec() >= _time_restore_at:
		_time_restore_at = 0
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw"):
		_try_throw()
	elif event.is_action_pressed("restart") and _level_over:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		sfx.play("ui_click")
		_set_aiming(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)



## Ігровий режим: курсор-приціл від ОС, мишка не виходить за вікно.
## Поза ним (Esc) — звичайна стрілка.
func _set_aiming(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED if on else Input.MOUSE_MODE_VISIBLE
	Crosshair.set_aim_cursor(on)


func _try_throw() -> void:
	if _level_over or throws_left <= 0:
		return
	var body := thrower.throw_random()
	if body == null:
		return
	throws_left -= 1
	_alive_objects += 1
	# Легкий предмет — вищий і швидший свист, важкий — нижчий.
	sfx.play("throw_whoosh", 0.0, clampf(1.35 - 0.25 * body.gravity_scale, 0.75, 1.3))
	hud.update_throws(throws_left)


func _on_object_finished(_body: RigidBody3D, _was_hit: bool) -> void:
	_alive_objects -= 1
	if throws_left <= 0 and _alive_objects <= 0 and not _level_over:
		_finish_level()


func _on_chain(chain: int, _pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if chain >= 2:
		# Кожна наступна ланка ланцюжка — вищий акорд.
		sfx.play("combo_up", 0.0, 1.0 + 0.12 * float(chain - 2))
		if now >= _slowmo_until:
			sfx.play("slowmo")
		_time_fx(SLOWMO_SCALE, SLOWMO_TIME_MS)
		_slowmo_until = now + SLOWMO_TIME_MS
		if chain >= 3 and now >= _crowd_ready_at:
			sfx.play("crowd_ooh")
			_crowd_ready_at = now + CROWD_COOLDOWN_MS
	elif _time_restore_at == 0:
		_time_fx(HITSTOP_SCALE, HITSTOP_TIME_MS)


func _on_shot_finished(earned: int, _chain: int) -> void:
	if earned > 0:
		sfx.play("cash", lerpf(-8.0, 0.0, clampf(float(earned) / 150.0, 0.0, 1.0)))


func _on_combo_broken() -> void:
	sfx.play("combo_break")


func _time_fx(ts: float, ms: int) -> void:
	Engine.time_scale = ts
	_time_restore_at = Time.get_ticks_msec() + ms


func _finish_level() -> void:
	_level_over = true
	player.set_process_unhandled_input(false)
	var stars := 0
	for t in STAR_THRESHOLDS:
		if score.money >= int(t):
			stars += 1
	var star_text := ""
	for i in 3:
		star_text += "★" if i < stars else "☆"
	var acc := 0.0
	if score.shots > 0:
		acc = 100.0 * float(score.shots_scored) / float(score.shots)
	var text := "РІВЕНЬ ЗАВЕРШЕНО\n\n%s\n\nЗароблено: $ %d\nНайкращий ланцюжок: %d\nВлучні постріли: %d%%\nЦивільних зачеплено: %d\n\nEnter — ще раз" % [star_text, score.money, score.best_chain, int(acc), score.civilians_hit]
	hud.show_results(text)
	# Фанфари, по «дзиньку» на кожну зірку, потім музика магазину.
	sfx.stop_music(0.6)
	sfx.play("level_complete")
	for i in stars:
		sfx.play_delayed("star", 1.0 + 0.45 * float(i), 0.0, 1.0 + 0.12 * float(i))
	get_tree().create_timer(6.5).timeout.connect(sfx.play_music.bind("shop", 2.5))


func _setup_input() -> void:
	_bind_key("throw", KEY_SPACE)
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_key("reload", KEY_R)
	_bind_key("weapon_1", KEY_1)
	_bind_key("weapon_2", KEY_2)
	_bind_key("restart", KEY_ENTER)
	_bind_key("restart", KEY_KP_ENTER)


func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
