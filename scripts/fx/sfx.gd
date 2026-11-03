extends Node
## Звуки гри: варіації з маніфесту, випадковий питч, пул плеєрів,
## шини SFX / Music / Ambience, музика з кросфейдом і петля ембієнту.
## Інші вузли знаходять його через групу "sfx".

const AudioManifest = preload("res://scripts/fx/audio_manifest.gd")

const POOL_SIZE := 24
const MUSIC_DB := -10.0
const AMB_DB := -6.0
const SILENT_DB := -40.0

## Базова гучність кожного ключа (поверх нормалізації в slice_sfx.py).
const DEFAULT_DB := {
	"revolver_shot": 0.0,
	"rifle_shot": 0.0,
	"dry_click": -4.0,
	"reload_open": -4.0,
	"reload_insert": -6.0,
	"reload_close": -4.0,
	"lever_cycle": -4.0,
	"gun_twirl": -6.0,
	"ricochet": -4.0,
	"hit_gong": -2.0,
	"throw_whoosh": -6.0,
	"land_dirt": -8.0,
	"cash": -8.0,
	"combo_up": -6.0,
	"combo_break": -6.0,
	"crowd_ooh": -6.0,
	"slowmo": -6.0,
	"civilian_hic": -10.0,
	"saloon_doors": -14.0,
	"star": -4.0,
	"ui_click": -6.0,
}

var _streams: Dictionary = {}
var _last: Dictionary = {}
var _pool: Array = []
var _next: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _amb: AudioStreamPlayer


func _ready() -> void:
	add_to_group("sfx")
	_ensure_bus("SFX")
	_ensure_bus("Music")
	_ensure_bus("Ambience")
	for key in AudioManifest.SFX:
		var arr: Array = []
		for path in AudioManifest.SFX[key]:
			var s := load(path) as AudioStream
			if s != null:
				arr.append(s)
		_streams[key] = arr
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_amb = _make_player("Ambience")


func has(key: String) -> bool:
	return not (_streams.get(key, []) as Array).is_empty()


## Програє випадкову варіацію (без повтору підряд) з легким розкидом питчу.
func play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var arr: Array = _streams.get(key, [])
	if arr.is_empty():
		return
	var idx := randi() % arr.size()
	if arr.size() > 1 and idx == int(_last.get(key, -1)):
		idx = (idx + 1) % arr.size()
	_last[key] = idx
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = arr[idx]
	p.volume_db = float(DEFAULT_DB.get(key, 0.0)) + volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


## Те саме із затримкою (секунди ігрового часу).
func play_delayed(key: String, delay: float, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	get_tree().create_timer(delay).timeout.connect(play.bind(key, volume_db, pitch))


func play_music(key: String, fade: float = 1.5) -> void:
	var path: String = str(AudioManifest.MUSIC.get(key, ""))
	if path == "":
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_set_loop(stream)
	var incoming := _music_b if _music_current == _music_a else _music_a
	var outgoing := _music_current
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_music_current = incoming
	var tw := create_tween()
	tw.tween_property(incoming, "volume_db", MUSIC_DB, fade)
	if outgoing != null and outgoing.playing:
		tw.parallel().tween_property(outgoing, "volume_db", SILENT_DB, fade)
		tw.tween_callback(outgoing.stop)


func stop_music(fade: float = 1.0) -> void:
	if _music_current == null or not _music_current.playing:
		return
	var p := _music_current
	var tw := create_tween()
	tw.tween_property(p, "volume_db", SILENT_DB, fade)
	tw.tween_callback(p.stop)


func play_ambience() -> void:
	if AudioManifest.AMB.is_empty():
		return
	var stream := load(str(AudioManifest.AMB.pick_random())) as AudioStream
	if stream == null:
		return
	_set_loop(stream)
	_amb.stream = stream
	_amb.volume_db = AMB_DB
	_amb.play()


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


func _set_loop(stream: AudioStream) -> void:
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
