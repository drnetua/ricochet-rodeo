extends Node3D
## Кидає предмети з-за лівого краю так, що вершина траєкторії — по центру екрана.

const Throwable = preload("res://scripts/throwable.gd")
const ThrowableData = preload("res://scripts/data/throwable_data.gd")
const Throwables = preload("res://scripts/data/throwables.gd")

signal thrown(body: RigidBody3D)
signal object_finished(body: RigidBody3D, was_hit: bool)

@export var start_x: float = -14.0
@export var start_y: float = 0.6
## Площина польоту (глибина від камери).
@export var play_z: float = -9.0
@export var apex_height_min: float = 4.6
@export var apex_height_max: float = 5.9
@export var cooldown: float = 0.35

var _cd: float = 0.0
var _pool: Array = []


func _ready() -> void:
	_pool = Throwables.all()


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func throw_random() -> RigidBody3D:
	if _cd > 0.0:
		return null
	_cd = cooldown
	var d: ThrowableData = _pool.pick_random()
	return throw_data(d)


func throw_data(d: ThrowableData) -> RigidBody3D:
	var body: Throwable = Throwable.new()
	body.setup(d)
	add_child(body)
	# Стартова швидкість рахується від бажаної вершини:
	# vy = sqrt(2 g h), час до вершини t = vy / g, vx = dx / t.
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * d.gravity_scale
	var start := Vector3(start_x, start_y, play_z + randf_range(-0.8, 0.8))
	var apex := Vector3(randf_range(-1.5, 1.5), randf_range(apex_height_min, apex_height_max), start.z)
	var vy := sqrt(2.0 * g * (apex.y - start.y))
	var t := vy / g
	var vx := (apex.x - start.x) / t
	body.global_position = start
	body.linear_velocity = Vector3(vx, vy, 0.0)
	body.angular_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-6.0, 6.0))
	body.finished.connect(_on_finished)
	thrown.emit(body)
	return body


func _on_finished(body: RigidBody3D, was_hit: bool) -> void:
	object_finished.emit(body, was_hit)
