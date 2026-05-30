extends CharacterBody2D

@onready var _animated_sprite = $Moves
@onready var collision = $CollisionShape2D
@onready var barra_vida: TextureProgressBar = $Bars/Bar/TextureProgressBar 

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
var intervalo_dano = 0.4
var tempo_dano_causado = 0.0
var tipo_ataque_atual: String = "alto"

# Direção travada no momento em que o bloqueio foi iniciado
# true = olhando para esquerda, false = olhando para direita, null = sem bloqueio ativo
var bloqueio_direcao_travada = null

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
		_animated_sprite.scale = Vector2(1.5, 1.5)
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
		bloqueio_direcao_travada = null

	if Input.is_action_pressed("baixo") and is_on_floor():
		agachado = true
	else:
		agachado = false

	if is_on_floor() and not agachado:
		if Input.is_action_pressed("quadrado"):
			atacando = true
			bloqueando = false
			bloqueio_direcao_travada = null  # soltou o bloqueio
			animacao_ataque = "punch"
			tipo_ataque_atual = "alto"
		elif Input.is_action_pressed("triangulo"):
			atacando = true
			bloqueando = false
			bloqueio_direcao_travada = null  # soltou o bloqueio
			animacao_ataque = "kick"
			tipo_ataque_atual = "baixo"
		elif Input.is_action_pressed("o"):
			atacando = false
			# Só trava a direção no primeiro frame que aperta o bloqueio
			if not bloqueando:
				bloqueio_direcao_travada = _animated_sprite.flip_h
			bloqueando = true
			animacao_ataque = "block"
		else:
			atacando = false
			bloqueando = false
			bloqueio_direcao_travada = null  # resetar ao soltar

	var direction := Input.get_axis("left", "right")
	if direction != 0:
		_animated_sprite.flip_h = direction < 0

	if direction != 0 and not bloqueando and not agachado and not (atacando and is_on_floor()):
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	ajustar_colisao_estado()
	move_and_slide()
	verificar_dano_causado(delta)
	processar_animacoes(direction)

func verificar_dano_causado(delta):
	tempo_dano_causado -= delta
	if not player_2 or not is_instance_valid(player_2):
		return
	if tempo_dano_causado > 0:
		return

	var distancia = abs(player_2.global_position.x - global_position.x)
	if distancia > ALCANCE_ATAQUE:
		return

	var dano = 0.0
	var tipo_golpe = "alto"
	var direcao = sign(player_2.global_position.x - global_position.x)

	match _animated_sprite.animation:
		"punch":
			dano = 10.0
			tipo_golpe = "alto"
		"kick":
			dano = 15.0
			tipo_golpe = "baixo"
		"shift_punch":
			dano = 8.0
			tipo_golpe = "baixo"
		"shift_kick":
			dano = 12.0
			tipo_golpe = "baixo"
		"jump_punch":
			dano = 13.0
			tipo_golpe = "alto"
		"jump_kick":
			dano = 18.0
			tipo_golpe = "alto"

	if dano > 0:
		player_2.receber_dano(dano, direcao, tipo_golpe)
		tempo_dano_causado = intervalo_dano

func receber_dano(quantidade: float, direcao_dano: float, tipo_golpe: String = "alto"):
	if morto or invencivel:
		return

	if bloqueando and bloqueio_direcao_travada != null:
		var atacante_vem_da_esquerda: bool = direcao_dano > 0

		# Direção que estava olhando quando o bloqueio foi iniciado (travada)
		var bloqueio_olha_esquerda: bool = bloqueio_direcao_travada

		# Costas expostas: atacante vem do lado oposto ao que o escudo cobre
		# Ex: bloqueio olha direita (flip_h = false), mas atacante vem da direita também
		# → atacante está nas costas → dano total
		var atacante_nas_costas: bool = (
			(atacante_vem_da_esquerda and not bloqueio_olha_esquerda) or
			(not atacante_vem_da_esquerda and bloqueio_olha_esquerda)
		)

		if atacante_nas_costas:
			# Costas completamente abertas: dano total, sem redução
			pass
		else:
			# Frente coberta: verifica altura
			# Em pé bloqueia alto, agachado bloqueia baixo
			if not agachado and tipo_golpe == "alto":
				bloqueio_com_sucesso()
				return
			elif agachado and tipo_golpe == "baixo":
				bloqueio_com_sucesso()
				return
			# Altura errada: bloqueio não cobre, cai no dano normal

	vida_atual -= quantidade
	atualizar_barra_vida()
	invencivel = true
	tempo_invencibilidade = 0.4

	if vida_atual <= 0:
		morrer()
	else:
		_animated_sprite.play("damaged")
		_animated_sprite.scale = Vector2(1.5, 1.5)
		em_knockback = true
		tempo_knockback = 0.25
		velocity.x = direcao_dano * 400.0
		if is_on_floor():
			velocity.y = -300.0

func bloqueio_com_sucesso():
	# Feedback visual/sonoro do bloqueio pode ser adicionado aqui
	pass

func morrer():
	morto = true
	velocity = Vector2.ZERO
	call_deferred("_aplicar_colisao_morto")

func _aplicar_colisao_morto():
	if collision.shape is CapsuleShape2D:
		var altura_original = tamanho_colisao_original.y
		collision.shape.radius = altura_original * 0.25
		collision.shape.height = altura_original * 0.8
		collision.position = Vector2(0, altura_original * 0.35)

func ajustar_colisao_estado():
	if collision and collision.shape:
		collision.shape = collision.shape.duplicate()
	if not collision.shape is CapsuleShape2D:
		return
	var raio_original = tamanho_colisao_original.x
	var altura_original = tamanho_colisao_original.y

	if agachado:
		var nova_altura = altura_original * 0.5
		collision.shape.height = nova_altura
		collision.shape.radius = min(raio_original, nova_altura * 0.5)
		collision.position = Vector2(0, (altura_original - nova_altura) * 0.5)
	elif not is_on_floor():
		var nova_altura = altura_original * 0.85
		collision.shape.height = nova_altura
		collision.shape.radius = raio_original * 0.8
		collision.position = Vector2(0, (altura_original - nova_altura) * 0.5)
	else:
		collision.shape.height = altura_original
		collision.shape.radius = raio_original
		collision.position = Vector2(0, 0)

func processar_animacoes(direction: float):
	if not is_on_floor():
		if Input.is_action_pressed("quadrado"):
			_animated_sprite.play("jump_punch")
			_animated_sprite.scale = Vector2(1.3, 1.3)
			_animated_sprite.offset = Vector2(0, -15)
		elif Input.is_action_pressed("triangulo"):
			_animated_sprite.play("jump_kick")
			_animated_sprite.scale = Vector2(1.3, 1.3)
			_animated_sprite.offset = Vector2(0, -15)
		else:
			_animated_sprite.play("jump")
			_animated_sprite.scale = Vector2(1.5, 1.5)
			_animated_sprite.offset = Vector2(0, -10)
	else:
		_animated_sprite.scale = Vector2(1.4, 1.4)
		_animated_sprite.offset = Vector2(0, 0)

		if agachado:
			_animated_sprite.scale = Vector2(1.1, 1.1)
			_animated_sprite.offset = Vector2(0, 100)
			if Input.is_action_pressed("triangulo"):
				_animated_sprite.play("shift_kick")
				_animated_sprite.scale = Vector2(0.6, 0.6)
				_animated_sprite.offset = Vector2(0, 250)
			elif Input.is_action_pressed("o"):
				_animated_sprite.play("shift_block")
				_animated_sprite.scale = Vector2(0.6, 0.6)
				_animated_sprite.offset = Vector2(0, 100)
			elif Input.is_action_pressed("quadrado"):
				_animated_sprite.play("shift_punch")
				_animated_sprite.scale = Vector2(1.3, 1.3)
				_animated_sprite.offset = Vector2(0, 50)
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
		if collision.shape is CapsuleShape2D:
			collision.shape.height = tamanho_sprite.y
			collision.shape.radius = tamanho_sprite.x * 0.5

func atualizar_barra_vida():
	if barra_vida:
		barra_vida.value = vida_atual
