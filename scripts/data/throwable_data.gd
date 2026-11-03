extends Resource
## Параметри предмета, який підкидає гравець.

@export var id: String = "skull"
@export var display_name: String = "Череп"
## Аркадна гравітація: легкі предмети «пливуть», важкі різко падають.
@export var gravity_scale: float = 1.0
@export var mass: float = 1.0
@export var points: int = 15
@export var size: float = 1.0
@export var color: Color = Color.WHITE
@export var metallic: float = 0.0
@export var roughness: float = 0.8
