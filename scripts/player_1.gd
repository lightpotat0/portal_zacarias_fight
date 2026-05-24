extends CharacterBody2D

@onready var _animated_sprite = $Moves
@onready var collision = $CollisionShape2D
@onready var barra_vida: TextureProgressBar = $Bars/Bar/TextureProgressBar # CORRIJA o caminho conforme sua cena

@export var player_2: CharacterBody2D

const SPEED = 250.0
const JUMP_VELOCITY = -1300.0
const GRAVITY_SCALE = 3
const FALL_GRAVITY_SCALE = 5.0
const ALCANCE_ATAQUE = 150.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var agachado = false
var atacando = false
var bloqueando = false
var animacao_ataque = ""
var vida_maxima = 100.0
var vida_atual = 100.0
var morto = false
var em_knockback = false
var tempo_knockback = 0.0
var invencivel = false
var tempo_invencibilidade = 0.0
var tamanho_colisao_original = Vector2.ZERO

func _ready():
	vida_atual = vida_maxima
	atualizar_barra_vida()
	ajustar_colisao_ao_sprite() 
	if collision.shape is RectangleShape2D:
		tamanho_colisao_original = collision.shape.size  
	if not player_2:
		for node in get_parent().get_children():
			if node is CharacterBody2D and node != self:
				player_2 = node
				break

func _physics_process(delta):
	if morto:
		_animated_sprite.play("die")
		if not is_on_floor():
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	if em_knockback:
		tempo_knockback -= delta
		if tempo_knockback <= 0:
			em_knockback = false
		if not is_on_floor():
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)
		move_and_slide()
		return

	if invencivel:
		tempo_invencibilidade -= delta
		if tempo_invencibilidade <= 0:
			invencivel = false

	if not is_on_floor():
		if velocity.y < 0:
			velocity.y += gravity * GRAVITY_SCALE * delta
		else:
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta

	if Input.is_action_just_pressed("x") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		agachado = false
		atacando = false
		bloqueando = false

	if Input.is_action_pressed("baixo") and is_on_floor():
		agachado = true
	else:
		agachado = false

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

	var direction := Input.get_axis("left", "right")
	if direction != 0:
		_animated_sprite.flip_h = direction < 0

	if direction != 0 and not bloqueando and not agachado and not (atacando and is_on_floor()):
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	ajustar_colisao_estado()
	move_and_slide()
	verificar_dano_recebido()
	processar_animacoes(direction)

func verificar_dano_recebido():
	if morto or not player_2 or not is_instance_valid(player_2) or invencivel:
		return

	var distancia = abs(player_2.global_position.x - global_position.x)
	var direcao_dano = sign(global_position.x - player_2.global_position.x)

	if distancia > ALCANCE_ATAQUE:
		return

	var anim_sprite_p2 = player_2.get("_animated_sprite")
	if not anim_sprite_p2:
		return

	var anim_atual = anim_sprite_p2.animation
	var dano = 0.0

	match anim_atual:
		"punch":       dano = 10.0
		"kick":        dano = 15.0
		"shift_punch": dano = 8.0
		"shift_kick":  dano = 12.0
		"jump_punch":  dano = 13.0
		"jump_kick":   dano = 18.0

	if dano > 0:
		receber_dano(dano, direcao_dano)

func receber_dano(quantidade: float, direcao_dano: float):
	if morto or invencivel:  
		return

	if bloqueando:
		vida_atual -= quantidade * 0.1
	else:
		vida_atual -= quantidade

	atualizar_barra_vida()
	invencivel = true
	tempo_invencibilidade = 0.4

	if vida_atual <= 0:
		morrer()
	else:
		_animated_sprite.play("damaged")
		em_knockback = true
		tempo_knockback = 0.25
		velocity.x = direcao_dano * 400.0
		if is_on_floor():
			velocity.y = -300.0

func morrer():
	morto = true
	velocity = Vector2.ZERO
	call_deferred("_aplicar_colisao_morto")

func _aplicar_colisao_morto():
	if collision.shape is RectangleShape2D:
		var largura = tamanho_colisao_original.x
		var altura = tamanho_colisao_original.y
		collision.shape.size = Vector2(largura, altura * 0.25)
		collision.position = Vector2(0, altura * 0.37)

func ajustar_colisao_estado():
	if not collision.shape is RectangleShape2D:
		return
	var largura = tamanho_colisao_original.x
	var altura = tamanho_colisao_original.y

	if agachado:
		collision.shape.size = Vector2(largura, altura * 0.5)
		collision.position = Vector2(0, altura * 0.25)
	elif not is_on_floor():
		collision.shape.size = Vector2(largura * 0.8, altura * 0.85)
		collision.position = Vector2(0, 0)
	else:
		collision.shape.size = tamanho_colisao_original
		collision.position = Vector2(0, 0)

func processar_animacoes(direction: float):
	if not is_on_floor():
		if Input.is_action_pressed("quadrado"):
			_animated_sprite.play("jump_punch")
			_animated_sprite.scale = Vector2(1.0, 1.0)
			_animated_sprite.offset = Vector2(0, -15)
		elif Input.is_action_pressed("triangulo"):
			_animated_sprite.play("jump_kick")
			_animated_sprite.scale = Vector2(1.0, 1.0)
			_animated_sprite.offset = Vector2(0, -15)
		else:
			_animated_sprite.play("jump")
			_animated_sprite.scale = Vector2(1.3, 1.3)
			_animated_sprite.offset = Vector2(0, -10)
	else:
		_animated_sprite.scale = Vector2(1.4, 1.4)
		_animated_sprite.offset = Vector2(0, 0)

		if agachado:
			_animated_sprite.scale = Vector2(0.8, 0.8)
			_animated_sprite.offset = Vector2(0, 100)
			if Input.is_action_pressed("triangulo"):
				_animated_sprite.play("shift_kick")
				_animated_sprite.scale = Vector2(0.45, 0.45)
				_animated_sprite.offset = Vector2(0, 250)
			elif Input.is_action_pressed("o"):
				_animated_sprite.play("shift_block")
				_animated_sprite.scale = Vector2(0.5, 0.5)
			elif Input.is_action_pressed("quadrado"):
				_animated_sprite.play("shift_punch")
				_animated_sprite.scale = Vector2(1.0, 1.0)
			else:
				_animated_sprite.play("shift")
		elif em_knockback:
			pass 
		elif atacando:
			_animated_sprite.play(animacao_ataque)
		elif bloqueando:
			_animated_sprite.play(animacao_ataque)
		elif direction != 0:
			_animated_sprite.play("walk")
			_animated_sprite.scale = Vector2(2.8, 2.8)
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

func atualizar_barra_vida():
	if barra_vida:
		barra_vida.value = vida_atual
