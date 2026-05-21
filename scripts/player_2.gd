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
	# Gravidade
	if not is_on_floor():
		if velocity.y < 0:
			velocity.y += gravity * GRAVITY_SCALE * delta
		else:
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta

	# Pulo e Ataques Aéreos (Detecta se acabou de apertar o pulo)
	if Input.is_action_just_pressed("x") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_animated_sprite.play("jump")
		agachado = false
	
	# Ataques no ar (Mudado para 'is_action_pressed' para o caso de segurar o botão antes)
	if not is_on_floor():
		if Input.is_action_pressed("quadrado"):
			_animated_sprite.play("jump_punch")	
		elif Input.is_action_pressed("triangulo"):
			_animated_sprite.play("jump kick")	
		
	# Agachar (Funciona enquanto mantiver pressionado)
	if Input.is_action_pressed("down") and is_on_floor():
		agachado = true
		if Input.is_action_pressed("triangulo"):
			_animated_sprite.play("shift_kick")	
	else:
		agachado = false
		
	# Ataques e Bloqueio no Chão (Mudado para 'is_action_pressed' para funcionar enquanto segura)
	if is_on_floor() and not agachado:
		if Input.is_action_pressed("quadrado"): 
			atacando = true
			bloqueando = false
			animacao_ataque = "punch"
		elif Input.is_action_pressed("triangulo"): 
			atacando = true
			bloqueando = false
			animacao_ataque = "kick"
		elif Input.is_action_pressed("o"): 
			atacando = false
			bloqueando = true
			animacao_ataque = "block"
		else:
			atacando = false
			bloqueando = false

	# Movimentação Horizontal (Apenas se não estiver defendendo ou atacando no chão)
	var direction := Input.get_axis("left", "right")
	
	if direction != 0 and not bloqueando and not (atacando and is_on_floor()):
		velocity.x = direction * SPEED
		_animated_sprite.flip_h = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	move_and_slide()
	
	# Máquina de Estados de Animação
	if not is_on_floor():
		# Se já não estiver passando a animação de soco/chute aéreo, usa o pulo padrão
		if _animated_sprite.animation != "jump_punch" and _animated_sprite.animation != "jump kick":
			_animated_sprite.play("jump")
		_animated_sprite.scale = Vector2(1.3, 1.3)
		_animated_sprite.offset = Vector2(0, -10)
	else:
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)
		
		if agachado:
			if Input.is_action_pressed("triangulo"):
				_animated_sprite.play("shift_kick")
			else:
				_animated_sprite.play("shift")
		elif atacando:
			_animated_sprite.play(animacao_ataque)
		elif bloqueando:
			_animated_sprite.play(animacao_ataque)
		elif direction != 0: 
			_animated_sprite.play("walk")
		else:
			_animated_sprite.play("stop")
		
func ajustar_colisao_ao_sprite():
	var anim_atual = _animated_sprite.animation
	var frame_atual = _animated_sprite.frame
	var textura_frame = _animated_sprite.sprite_frames.get_frame_texture(anim_atual, frame_atual)
	
	if textura_frame:
		var tamanho_sprite = textura_frame.get_size()
		tamanho_sprite *= _animated_sprite.scale
		
		if collision.shape is RectangleShape2D:
			collision.shape.size = tamanho_sprite
