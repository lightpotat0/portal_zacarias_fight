extends Camera2D

@onready var target = get_node("../Player1")
@export var smooth_speed: float = 5.0

func _ready() -> void:
	limit_left = -500    
	limit_right = 1680
	
func _process(delta: float) -> void:
	if target:
		var target_position = global_position
		target_position.x = target.global_position.x
		global_position = global_position.lerp(target_position, smooth_speed * delta)
