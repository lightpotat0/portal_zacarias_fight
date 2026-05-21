extends CharacterBody2D

@onready var _animated_sprite = $Moves
@onready var collision = $CollisionShape2D

const SPEED = 500.0
const JUMP_VELOCITY = -1300.0
const GRAVITY_SCALE = 3
const FALL_GRAVITY_SCALE = 5.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var agachado = false
var atacando = false
var bloqueando = false 
var animacao_ataque = ""

func _ready():
	ajustar_colisao_ao_sprite()

func _physics_process(delta):
	if not is_on_floor():
		if velocity.y < 0:
			velocity.y += gravity * GRAVITY_SCALE * delta
		else:
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta

	if (Input.is_action_just_pressed("x") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_animated_sprite.play("jump")
		agachado = false
		if (Input.is_action_just_pressed("x") or Input.is_action_just_pressed("ui_accept")) and (Input.is_action_just_pressed("quadrado") or Input.is_action_just_pressed("ui_focus_next")):
			_animated_sprite.play("jump_punch")	
		if (Input.is_action_just_pressed("x") or Input.is_action_just_pressed("ui_accept")) and (Input.is_action_just_pressed("triangulo") or Input.is_action_just_pressed("ui_text_backspace")):
			_animated_sprite.play("jump kick")	
			
	if Input.get_axis("left", "right") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_animated_sprite.play("block")
		bloqueando = true 
		
	if (Input.is_action_just_pressed("baixo") or Input.is_action_just_pressed("ui_down")) and is_on_floor():
		agachado = true
		if (Input.is_action_just_pressed("baixo") or Input.is_action_just_pressed("ui_down")) and Input.is_action_just_pressed("triangulo"):
			_animated_sprite.play("shift_kick")	
	
	if Input.is_action_just_released("baixo") or Input.is_action_just_released("ui_down"):
		agachado = false
		
	if Input.is_action_just_pressed("quadrado") or Input.is_action_just_pressed("ui_focus_next"): 
		atacando = true
		bloqueando = false
		animacao_ataque = "punch"
	elif Input.is_action_just_pressed("triangulo") or Input.is_action_just_pressed("ui_text_backspace"): 
		atacando = true
		bloqueando = false
		animacao_ataque = "kick"
	elif Input.is_action_just_pressed("o") or Input.is_action_just_pressed("ui_cancel"): 
		atacando = true
		bloqueando = false
		animacao_ataque = "block"
	elif is_on_floor() and not Input.get_axis("ui_left", "ui_right") and not Input.get_axis("left", "right"):
		atacando = false

	var direction := Input.get_axis("ui_left", "ui_right")
	var direction2 := Input.get_axis("left", "right")
	
	var direcao_final = direction if direction != 0 else direction2
	
	if direcao_final != 0:
		velocity.x = direcao_final * SPEED
		_animated_sprite.flip_h = direcao_final > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	move_and_slide()
	
	if not is_on_floor():
		_animated_sprite.play("jump")
		_animated_sprite.scale = Vector2(1.3, 1.3)
		_animated_sprite.offset = Vector2(0, -10)
	elif direcao_final != 0: 
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
	elif bloqueando:
		_animated_sprite.play(animacao_ataque)
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
	else:
		_animated_sprite.play("stop")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
		
func ajustar_colisao_ao_sprite():
	var anim_atual = _animated_sprite.animation
	var frame_atual = _animated_sprite.frame
	var textura_frame = _animated_sprite.sprite_frames.get_frame_texture(anim_atual, frame_atual)
	
	if textura_frame:
		var tamanho_sprite = textura_frame.get_size()
		tamanho_sprite *= _animated_sprite.scale
		
		if collision.shape is RectangleShape2D:
			collision.shape.size = tamanho_sprite
