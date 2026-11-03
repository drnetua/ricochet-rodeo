extends CanvasLayer
## HUD: гроші, комбо зі смужкою часу, кидки, набої, підказки, табло кінця рівня.
## У грі — стилізовані «дерев'яні таблички» з концептів замість простого тексту.

const Crosshair = preload("res://scripts/ui/crosshair.gd")
const ScoreManager = preload("res://scripts/score_manager.gd")
const Player = preload("res://scripts/player.gd")

var crosshair: Crosshair

var _root: Control
var _money: Label
var _combo: Label
var _combo_bar: ProgressBar
var _throws: Label
var _weapon: Label
var _ammo: Label
var _help: Label
var _fps: Label
var _results: PanelContainer
var _results_text: Label
var _score: ScoreManager
var _plaque: TextureRect
var _bullets: HBoxContainer
var _bullet_tex: Texture2D

const PLAQUE := "res://assets/textures/01/hud_plaque.png"
const BULLET := "res://assets/textures/01/hud_bullet.png"
const WESTERN_FONT := "res://assets/fonts/Rye-Regular.ttf"


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# Дерев'яна табличка з мішечком грошей (з концепту), число — західним шрифтом.
	if ResourceLoader.exists(PLAQUE):
		_plaque = TextureRect.new()
		_plaque.texture = load(PLAQUE)
		_plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_plaque.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_plaque.size = Vector2(330.0, 101.0)
		_plaque.position = Vector2(14.0, 10.0)
		_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_plaque)
	_money = _label(40, Color(1.0, 0.85, 0.3))
	_money.position = Vector2(28.0, 18.0)
	if _plaque != null:
		_money.add_theme_font_override("font", load(WESTERN_FONT))
		_money.add_theme_font_size_override("font_size", 46)
		_money.position = Vector2(118.0, 26.0)
	_combo = _label(26, Color(0.45, 0.9, 1.0))
	_combo.position = Vector2(30.0, 118.0 if _plaque != null else 78.0)
	_combo_bar = ProgressBar.new()
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_bar.show_percentage = false
	_combo_bar.min_value = 0.0
	_combo_bar.max_value = 1.0
	_combo_bar.position = Vector2(32.0, 158.0 if _plaque != null else 118.0)
	_combo_bar.custom_minimum_size = Vector2(200.0, 8.0)
	_combo_bar.visible = false
	_root.add_child(_combo_bar)
	_throws = _label(22, Color(1.0, 1.0, 1.0))
	_throws.position = Vector2(30.0, 176.0 if _plaque != null else 136.0)
	if ResourceLoader.exists(BULLET):
		_bullet_tex = load(BULLET)
		_bullets = HBoxContainer.new()
		_bullets.add_theme_constant_override("separation", 4)
		_bullets.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_bullets)
	_weapon = _label(24, Color(1.0, 1.0, 1.0))
	_ammo = _label(30, Color(1.0, 0.85, 0.3))
	for l in [_weapon, _ammo]:
		var lab: Label = l
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lab.size = Vector2(520.0, 40.0)
	_help = _label(18, Color(1.0, 1.0, 1.0, 0.75))
	_help.text = "Пробіл — кинути   ЛКМ — постріл   R — перезарядка   1/2 — зброя   Esc — курсор"
	# Лічильник кадрів лише в debug-збірках: діагностика продуктивності.
	if OS.is_debug_build():
		_fps = _label(18, Color(0.6, 1.0, 0.6, 0.9))
	crosshair = Crosshair.new()
	_root.add_child(crosshair)
	_build_results()


func bind(score: ScoreManager, player: Player) -> void:
	_score = score
	score.money_changed.connect(_on_money)
	score.combo_changed.connect(_on_combo)
	player.ammo_changed.connect(_on_ammo)
	player.weapon_changed.connect(_on_weapon)
	player.shot_fired.connect(crosshair.pulse)
	_on_money(score.money, 0)
	_on_combo(score.combo)


func update_throws(left: int) -> void:
	_throws.text = "Кидки: %d" % left


func show_results(text: String) -> void:
	_results_text.text = text
	_results.visible = true
	_results.reset_size()


func _process(_delta: float) -> void:
	var s := _root.size
	_weapon.position = Vector2(s.x - 548.0, s.y - 104.0)
	_ammo.position = Vector2(s.x - 548.0, s.y - 66.0)
	if _bullets != null:
		_bullets.position = Vector2(s.x - 24.0 - _bullets.size.x, s.y - 78.0)
		_ammo.position.y = s.y - 120.0
		_weapon.position.y = s.y - 156.0
	_help.position = Vector2(28.0, s.y - 44.0)
	if _fps != null:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
		_fps.position = Vector2(s.x - 110.0, 14.0)
	if _score != null:
		var left := _score.combo_time_left()
		_combo_bar.value = left
		_combo_bar.visible = left > 0.0
	_results.position = (s - _results.size) * 0.5


func _on_money(money: int, delta: int) -> void:
	_money.text = "$ %d" % money
	if delta == 0:
		return
	_money.pivot_offset = _money.size * 0.5
	_money.scale = Vector2.ONE * (1.25 if delta > 0 else 0.85)
	_money.modulate = Color(1.0, 1.0, 1.0) if delta > 0 else Color(1.0, 0.4, 0.35)
	var tw := _money.create_tween()
	tw.tween_property(_money, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_money, "modulate", Color(1.0, 1.0, 1.0), 0.4)


func _on_combo(combo: float) -> void:
	_combo.text = ("КОМБО ×%.1f" % combo) if combo > 1.0 else ""
	if combo > 1.0:
		_combo.pivot_offset = _combo.size * 0.5
		_combo.scale = Vector2.ONE * 1.3
		var tw := _combo.create_tween()
		tw.tween_property(_combo, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_ammo(ammo: int, mag: int, reloading: bool) -> void:
	var dots := ""
	for i in mag:
		dots += "●" if i < ammo else "○"
		if i < mag - 1:
			dots += " "
	if reloading:
		dots = "ПЕРЕЗАРЯДКА…  " + dots
	elif ammo == 0:
		dots = "R — перезарядка  " + dots
	_ammo.text = dots
	if _bullets != null:
		_ammo.text = "ПЕРЕЗАРЯДКА…" if reloading else ("R — перезарядка" if ammo == 0 else "")
		while _bullets.get_child_count() < mag:
			var tr := TextureRect.new()
			tr.texture = _bullet_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(26.0, 54.0)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bullets.add_child(tr)
		while _bullets.get_child_count() > mag:
			var last := _bullets.get_child(_bullets.get_child_count() - 1)
			_bullets.remove_child(last)
			last.queue_free()
		for i in mag:
			(_bullets.get_child(i) as TextureRect).modulate = Color(1, 1, 1, 1.0 if i < ammo else 0.22)
		_bullets.reset_size()


func _on_weapon(display_name: String) -> void:
	_weapon.text = display_name


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	_root.add_child(l)
	return l


func _build_results() -> void:
	_results = PanelContainer.new()
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.88)
	sb.border_color = Color(1.0, 0.8, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28.0)
	_results.add_theme_stylebox_override("panel", sb)
	_results_text = Label.new()
	_results_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_text.add_theme_font_size_override("font_size", 30)
	_results_text.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_results.add_child(_results_text)
	_results.visible = false
	_root.add_child(_results)
