extends Node
## Очки, комбо і статистика рівня. Правила — з розділу GDD «Очки, бонуси, штрафи».

signal money_changed(money: int, delta: int)
signal combo_changed(combo: float)
signal popup(text: String, world_pos: Vector3, color: Color, big: bool)
signal chain_reached(chain: int, world_pos: Vector3)
## Кінець пострілу: скільки зароблено і найдовший ланцюжок.
signal shot_finished(earned: int, chain: int)
## Комбо згоріло через промах або цивільного (не через таймаут).
signal combo_broken

const COMBO_WINDOW := 1.5
const COMBO_STEP := 0.5
const COMBO_MAX := 4.0
const CHAIN_BONUS := 25
const CIVILIAN_FINE := 100

const GOLD := Color(1.0, 0.82, 0.25)
const RED := Color(1.0, 0.3, 0.25)
const CYAN := Color(0.4, 0.9, 1.0)

var money: int = 0
var combo: float = 1.0
var best_chain: int = 0
var shots: int = 0
var shots_scored: int = 0
var civilians_hit: int = 0

var _since_hit: float = 999.0
var _chain: int = 0
var _links: int = 0
var _shot_money: int = 0


func _process(delta: float) -> void:
	_since_hit += delta
	if combo > 1.0 and _since_hit > COMBO_WINDOW:
		_set_combo(1.0)


## Частка часу, що лишилась до згоряння комбо (для смужки в HUD).
func combo_time_left() -> float:
	if combo <= 1.0:
		return 0.0
	return clampf(1.0 - _since_hit / COMBO_WINDOW, 0.0, 1.0)


func begin_shot() -> void:
	shots += 1
	_chain = 0
	_links = 0
	_shot_money = 0


func end_shot() -> void:
	if _chain > 0:
		shots_scored += 1
		best_chain = maxi(best_chain, _chain + _links)
	elif combo > 1.0:
		_set_combo(1.0)
		combo_broken.emit()
	shot_finished.emit(_shot_money, _chain + _links if _chain > 0 else 0)


## Відскок від гонга: без грошей і комбо, але наступна ціль рахується як ланка ланцюжка.
func register_link(pos: Vector3, label: String) -> void:
	_links += 1
	popup.emit(label, pos, Color(0.9, 0.9, 0.95), false)


func register_hit(result: Dictionary, pos: Vector3) -> void:
	var base: int = int(result.get("points", 0))
	if base <= 0:
		return
	_chain += 1
	if _since_hit <= COMBO_WINDOW:
		_set_combo(minf(combo + COMBO_STEP, COMBO_MAX))
	_since_hit = 0.0
	var link_index := _chain + _links
	var reward: int = base
	if link_index >= 2:
		reward += CHAIN_BONUS * link_index
	var total: int = int(round(reward * combo))
	_add_money(total)
	_shot_money += total
	var lines := "+%d$" % total
	var label: String = str(result.get("label", ""))
	if label != "":
		lines += "\n" + label
	var tags: Array = result.get("tags", [])
	for t in tags:
		lines += "\n" + str(t)
	popup.emit(lines, pos, GOLD, false)
	if link_index >= 2:
		popup.emit("РИКОШЕТ ×%d!" % link_index, pos + Vector3(0.0, 1.3, 0.0), CYAN, true)
	chain_reached.emit(link_index, pos)


func register_civilian(pos: Vector3) -> void:
	civilians_hit += 1
	_add_money(-CIVILIAN_FINE)
	_shot_money -= CIVILIAN_FINE
	if combo > 1.0:
		combo_broken.emit()
	_set_combo(1.0)
	_since_hit = 999.0
	popup.emit("-%d$ ЦИВІЛЬНИЙ!\nОй!" % CIVILIAN_FINE, pos + Vector3(0.0, 1.5, 0.0), RED, true)


func _add_money(delta: int) -> void:
	money += delta
	money_changed.emit(money, delta)


func _set_combo(value: float) -> void:
	if is_equal_approx(value, combo):
		return
	combo = value
	combo_changed.emit(combo)
