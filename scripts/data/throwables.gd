extends RefCounted
## Стартові пресети предметів для кидка.

const ThrowableData = preload("res://scripts/data/throwable_data.gd")


static func make(id: String, display_name: String, gravity_scale: float, mass: float, points: int, size: float, color: Color, roughness: float, metallic: float) -> ThrowableData:
	var d := ThrowableData.new()
	d.id = id
	d.display_name = display_name
	d.gravity_scale = gravity_scale
	d.mass = mass
	d.points = points
	d.size = size
	d.color = color
	d.roughness = roughness
	d.metallic = metallic
	return d


static func all() -> Array:
	return [
		make("coin", "Монета", 0.45, 0.3, 30, 1.15, Color(1.0, 0.78, 0.25), 0.25, 1.0),
		make("skull", "Череп бізона", 1.0, 1.5, 15, 1.8, Color(0.92, 0.88, 0.76), 0.6, 0.0),
		make("crate", "Ящик", 1.3, 3.0, 10, 1.44, Color(0.62, 0.42, 0.22), 0.85, 0.0),
		make("anvil", "Ковадло", 2.2, 8.0, 25, 1.62, Color(0.22, 0.22, 0.25), 0.4, 0.9),
		make("chicken", "Гумова курка", 0.55, 0.4, 25, 1.3, Color(1.0, 0.86, 0.2), 0.35, 0.0),
	]
