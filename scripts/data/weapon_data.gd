extends Resource
## Параметри зброї. У грі це будуть .tres-файли, які правляться в інспекторі без коду.

@export var id: String = "revolver"
@export var display_name: String = "Револьвер"
@export var mag_size: int = 6
## Скільки разів куля може відскочити від предметів і металу.
@export var ricochets: int = 2
## Конус «магніту рикошету»: куля доводиться до цілі, якщо та в межах кута.
@export var magnet_angle_deg: float = 30.0
@export var fire_cooldown: float = 0.18
@export var reload_per_round: float = 0.2
@export var two_handed: bool = false
@export var recoil_kick_deg: float = 16.0
@export var recoil_push: float = 0.06
## Чим менше — тим повільніше зброя доганяє приціл (відчуття ваги).
@export var aim_lag: float = 16.0
## Сила поштовху предмета кулею.
@export var impulse: float = 7.0
@export var camera_shake: float = 0.35
@export var shot_sound: String = "revolver_shot"
@export var shot_pitch: float = 1.0
@export var tracer_color: Color = Color(1.0, 0.85, 0.35, 0.95)
