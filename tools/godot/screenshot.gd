extends SceneTree
## Знімок кадру з гри без участі людини — для перевірки рівня поруч з концептом.
##
##   godot --path . --script tools/godot/screenshot.gd -- out.png [scene] [frames] [throw]
##
## out.png  — куди зберегти (за замовчуванням screenshot.png)
## scene    — сцена (res://scenes/main.tscn)
## frames   — скільки кадрів чекати перед знімком (90)
## throw    — "throw": підкинути предмет і зняти його в польоті

var _out := "screenshot.png"
var _frames := 90
var _throw := false
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
	_throw = args.size() > 3 and args[3] == "throw"
	var packed := load(scene_path) as PackedScene
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_n += 1
	if _throw and _n == _frames - 40:
		var main := root.get_child(root.get_child_count() - 1)
		if main.has_method("_try_throw"):
			main.call("_try_throw")
	if _n < _frames:
		return false
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out, " ", img.get_size())
	return true
