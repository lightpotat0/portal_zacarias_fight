extends CharacterBody2D

@onready var _animated_sprite = $Moves

const SPEED = 500.0
const JUMP_VELOCITY = -800.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
		_animated_sprite.offset = Vector2(0, -10)

	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_animated_sprite.play("jump") 
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		_animated_sprite.flip_h = direction > 0
		_animated_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_animated_sprite.play("walk")

	move_and_slide()
	
	if not is_on_floor():
		_animated_sprite.play("jump")
		_animated_sprite.scale = Vector2(1.3, 1.3)
		_animated_sprite.offset = Vector2(0, -10)
	elif direction != 0:
		_animated_sprite.play("run")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
	else:
		_animated_sprite.play("stop")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
