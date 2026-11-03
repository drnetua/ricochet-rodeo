extends SceneTree
## Знімок кадру з гри без участі людини — для перевірки рівня поруч з концептом.
##
##   godot --path . --script tools/godot/screenshot.gd -- out.png [scene] [frames] [throw]
##
## out.png  — куди зберегти (за замовчуванням screenshot.png)
## scene    — сцена (res://scenes/main.tscn)
## frames   — скільки кадрів чекати перед знімком (90)
## action   — "throw": підкинути предмет і зняти його в польоті; "reload": зняти перезарядку

var _out := "screenshot.png"
var _frames := 90
var _action := ""
var _n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var scene_path := "res://scenes/main.tscn"
	if args.size() > 1 and not args[1].is_empty():
		scene_path = args[1]
	if args.size() > 2:
		_frames = int(args[2])
	_action = args[3] if args.size() > 3 else ""
	var packed := load(scene_path) as PackedScene
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_n += 1
	var main := root.get_child(root.get_child_count() - 1)
	if _action == "throw" and _n == _frames - 40 and main.has_method("_try_throw"):
		main.call("_try_throw")
	# "reload:N" — почати перезарядку за N кадрів до знімка (за замовчуванням 2).
	var reload_at := _frames - (int(_action.get_slice(":", 1)) if _action.contains(":") else 2)
	if _action.begins_with("reload") and _n == reload_at:
		var player = main.get("player")
		if player != null:
			player.ammo[player.weapon.id] = 0
			player.call("_start_reload")
	if _n < _frames:
		return false
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out, " ", img.get_size())
	return true
