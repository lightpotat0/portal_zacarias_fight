extends CharacterBody2D

@onready var _animated_sprite = $Moves

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	_animated_sprite.play("stop")
	if not is_on_floor():
		velocity.y += gravity * delta

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
	elif direction != 0:
		_animated_sprite.play("run")  
	else:
		_animated_sprite.play("stop")
