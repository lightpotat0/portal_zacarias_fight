extends CharacterBody2D

@onready var _animated_sprite = $Moves

const SPEED = 500.0
const JUMP_VELOCITY = -1300.0
const GRAVITY_SCALE = 3
const FALL_GRAVITY_SCALE = 5.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var agachado = false
var atacando = false
var animacao_ataque = ""

func _physics_process(delta):
	if not is_on_floor():
		if velocity.y < 0:
			velocity.y += gravity * GRAVITY_SCALE * delta
		else:
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta

	if Input.is_action_just_pressed("x") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_animated_sprite.play("jump")
		agachado = false
		
	if Input.is_action_just_pressed("ui_down") and is_on_floor():
		agachado = true
	if Input.is_action_just_released("ui_down"):
		agachado = false
		
	if Input.is_action_just_pressed("quadrado"):
		atacando = true
		animacao_ataque = "punch"
	elif Input.is_action_just_pressed("triangulo"):
		atacando = true
		animacao_ataque = "kick"
	elif Input.is_action_just_pressed("o"):
		atacando = true
		animacao_ataque = "block"
		
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		_animated_sprite.flip_h = direction > 0
		_animated_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_animated_sprite.play("walk")

	var direction2 := Input.get_axis("left", "right")
	if direction2:
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
		_animated_sprite.play("walk")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
	elif agachado:
		_animated_sprite.play("shift")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
	elif atacando:
		_animated_sprite.play(animacao_ataque)
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
	else:
		_animated_sprite.play("stop")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
