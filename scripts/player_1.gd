extends CharacterBody2D

@onready var _animated_sprite = $Moves
@onready var collision = $CollisionShape2D
@onready var barra_vida: TextureProgressBar = $Bars/Bar/TextureProgressBar

@export var player_2: CharacterBody2D

const SPEED            = 250.0
const JUMP_VELOCITY    = -1300.0
const GRAVITY_SCALE    = 3
const FALL_GRAVITY_SCALE = 5.0
const ALCANCE_ATAQUE   = 150.0

# ── Durações ────────────────────────────────────────────────────────────────
const DURACAO_ATAQUE   = 0.35   # quanto tempo o ataque fica ativo
const INTERVALO_DANO   = 0.4    # cooldown entre danos causados

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# ── Estado ──────────────────────────────────────────────────────────────────
var agachado           = false
var atacando           = false
var bloqueando         = false
var animacao_ataque    = ""
var tipo_ataque_atual: String = "alto"

var vida_maxima        = 100.0
var vida_atual         = 100.0
var morto              = false

var em_knockback       = false
var tempo_knockback    = 0.0
var invencivel         = false
var tempo_invencibilidade = 0.0

var tamanho_colisao_original = Vector2.ZERO

var tempo_ataque       = 0.0   # timer de duração do ataque atual
var tempo_dano_causado = 0.0   # cooldown anti-dano múltiplo

var bloqueio_direcao_travada = null

# ── Escala padrão ────────────────────────────────────────────────────────────
# Centraliza todas as escalas aqui para não ficar espalhado em processar_animacoes
const ESCALA_PADRAO    = Vector2(1.4, 1.4)
const ESCALA_AGACHADO  = Vector2(1.1, 1.1)
const ESCALA_PULO      = Vector2(1.5, 1.5)
const ESCALA_SOCO_AR   = Vector2(1.3, 1.3)

func _ready():
	vida_atual = vida_maxima
	atualizar_barra_vida()
	if collision and collision.shape is CapsuleShape2D:
		tamanho_colisao_original = Vector2(collision.shape.radius, collision.shape.height)
	if not player_2:
		for node in get_parent().get_children():
			if node is CharacterBody2D and node != self:
				player_2 = node
				break

func _physics_process(delta):
	# ── Morto ────────────────────────────────────────────────────────────────
	if morto:
		_animated_sprite.play("die")
		_animated_sprite.scale = ESCALA_PADRAO
		_animated_sprite.modulate = Color.WHITE
		if not is_on_floor():
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# ── Knockback ────────────────────────────────────────────────────────────
	if em_knockback:
		tempo_knockback -= delta
		if tempo_knockback <= 0:
			em_knockback = false
			_animated_sprite.modulate = Color.WHITE
		if not is_on_floor():
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.5)
		move_and_slide()
		verificar_dano_causado(delta)
		return

	# ── Invencibilidade ───────────────────────────────────────────────────────
	if invencivel:
		tempo_invencibilidade -= delta
		if tempo_invencibilidade <= 0:
			invencivel = false
			_animated_sprite.modulate = Color.WHITE

	# ── Timer do ataque ───────────────────────────────────────────────────────
	# Ataque expira automaticamente — sem isso o personagem fica travado atacando
	if atacando:
		tempo_ataque -= delta
		if tempo_ataque <= 0:
			atacando = false
			animacao_ataque = ""

	# ── Gravidade ─────────────────────────────────────────────────────────────
	if not is_on_floor():
		velocity.y += gravity * (GRAVITY_SCALE if velocity.y < 0 else FALL_GRAVITY_SCALE) * delta

	# ── Pulo ──────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("x") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		agachado   = false
		atacando   = false
		bloqueando = false
		animacao_ataque = ""
		bloqueio_direcao_travada = null

	# ── Agachar ───────────────────────────────────────────────────────────────
	agachado = Input.is_action_pressed("baixo") and is_on_floor()

	# ── Direção horizontal ────────────────────────────────────────────────────
	var direction := Input.get_axis("left", "right")
	if direction != 0:
		_animated_sprite.flip_h = direction < 0

	# ── Ações no chão (não agachado) ──────────────────────────────────────────
	if is_on_floor() and not agachado:
		if Input.is_action_just_pressed("quadrado") and not atacando:
			_iniciar_ataque("punch", "alto")
		elif Input.is_action_just_pressed("triangulo") and not atacando:
			_iniciar_ataque("kick", "baixo")
		elif Input.is_action_pressed("o") and not atacando:
			if not bloqueando:
				bloqueio_direcao_travada = _animated_sprite.flip_h
			bloqueando = true
			animacao_ataque = "block"
		else:
			# Só cancela o bloqueio se o botão foi solto
			if not Input.is_action_pressed("o"):
				bloqueando = false
				bloqueio_direcao_travada = null

	# ── Ações agachado ────────────────────────────────────────────────────────
	if is_on_floor() and agachado:
		if Input.is_action_just_pressed("quadrado") and not atacando:
			_iniciar_ataque("shift_punch", "baixo")
		elif Input.is_action_just_pressed("triangulo") and not atacando:
			_iniciar_ataque("shift_kick", "baixo")
		elif Input.is_action_pressed("o") and not atacando:
			if not bloqueando:
				bloqueio_direcao_travada = _animated_sprite.flip_h
			bloqueando = true
			animacao_ataque = "shift_block"
		else:
			if not Input.is_action_pressed("o"):
				bloqueando = false
				bloqueio_direcao_travada = null

	# ── Movimento horizontal ──────────────────────────────────────────────────
	# Bloqueio e ataque no chão travam o movimento
	var trava_movimento = bloqueando or (atacando and is_on_floor())
	if direction != 0 and not trava_movimento and not agachado:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	ajustar_colisao_estado()
	move_and_slide()
	verificar_dano_causado(delta)
	processar_animacoes(direction)

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _iniciar_ataque(anim: String, tipo: String):
	atacando       = true
	bloqueando     = false
	bloqueio_direcao_travada = null
	animacao_ataque = anim
	tipo_ataque_atual = tipo
	tempo_ataque   = DURACAO_ATAQUE

func verificar_dano_causado(delta):
	tempo_dano_causado -= delta
	if not player_2 or not is_instance_valid(player_2):
		return
	if tempo_dano_causado > 0:
		return

	var distancia = abs(player_2.global_position.x - global_position.x)
	if distancia > ALCANCE_ATAQUE:
		return

	var dano      = 0.0
	var tipo_golpe = "alto"
	var direcao   = sign(player_2.global_position.x - global_position.x)
	var anim      = _animated_sprite.animation

	match anim:
		"punch":       dano = 10.0; tipo_golpe = "alto"
		"kick":        dano = 15.0; tipo_golpe = "baixo"
		"shift_punch": dano =  8.0; tipo_golpe = "baixo"
		"shift_kick":  dano = 12.0; tipo_golpe = "baixo"
		"jump_punch":  dano = 13.0; tipo_golpe = "alto"
		"jump_kick":   dano = 18.0; tipo_golpe = "alto"

	if dano > 0:
		player_2.receber_dano(dano, direcao, tipo_golpe)
		tempo_dano_causado = INTERVALO_DANO

func receber_dano(quantidade: float, direcao_dano: float, tipo_golpe: String = "alto"):
	if morto or invencivel:
		return

	# ── Verifica bloqueio ─────────────────────────────────────────────────────
	if bloqueando and bloqueio_direcao_travada != null:
		var atacante_vem_da_esquerda: bool = direcao_dano > 0
		var bloqueio_olha_esquerda: bool   = bloqueio_direcao_travada
		var atacante_nas_costas: bool = (
			(atacante_vem_da_esquerda and not bloqueio_olha_esquerda) or
			(not atacante_vem_da_esquerda and bloqueio_olha_esquerda)
		)
		if not atacante_nas_costas:
			# Bloqueio alto absorve golpes altos; bloqueio baixo absorve golpes baixos
			var bloqueio_valido = (
				(not agachado and tipo_golpe == "alto") or
				(agachado     and tipo_golpe == "baixo")
			)
			if bloqueio_valido:
				bloqueio_com_sucesso(quantidade, direcao_dano)
				return

	# ── Toma dano ─────────────────────────────────────────────────────────────
	vida_atual -= quantidade
	atualizar_barra_vida()
	_animated_sprite.modulate = Color(1, 0.2, 0.2, 1)
	invencivel = true
	tempo_invencibilidade = 0.4

	if vida_atual <= 0:
		morrer()
	else:
		em_knockback   = true
		tempo_knockback = 0.25
		velocity.x     = direcao_dano * 400.0
		if is_on_floor():
			velocity.y = -300.0

func bloqueio_com_sucesso(quantidade: float = 0.0, direcao_dano: float = 0.0):
	# Dano residual mínimo — bloqueio perfeito não é grátis
	var dano_residual = quantidade * 0.1
	vida_atual = max(0.0, vida_atual - dano_residual)
	atualizar_barra_vida()
	# Flash mais suave para indicar bloqueio (azulado em vez de vermelho)
	_animated_sprite.modulate = Color(0.6, 0.8, 1.0, 1.0)
	invencivel = true
	tempo_invencibilidade = 0.15
	if vida_atual <= 0:
		morrer()

func morrer():
	morto    = true
	velocity = Vector2.ZERO
	call_deferred("_aplicar_colisao_morto")

func _aplicar_colisao_morto():
	if collision.shape is CapsuleShape2D:
		var h = tamanho_colisao_original.y
		collision.shape.radius   = h * 0.25
		collision.shape.height   = h * 0.8
		collision.position       = Vector2(0, h * 0.35)

func ajustar_colisao_estado():
	if collision and collision.shape:
		collision.shape = collision.shape.duplicate()
	if not collision.shape is CapsuleShape2D:
		return
	var r = tamanho_colisao_original.x
	var h = tamanho_colisao_original.y
	if agachado:
		var nh = h * 0.5
		collision.shape.height   = nh
		collision.shape.radius   = min(r, nh * 0.5)
		collision.position       = Vector2(0, (h - nh) * 0.5)
	elif not is_on_floor():
		collision.shape.height   = h * 0.8
		collision.shape.radius   = r * 0.8
		collision.position       = Vector2(0, (h - h * 0.8) * 0.5)
	else:
		collision.shape.height   = h
		collision.shape.radius   = r
		collision.position       = Vector2(0, 0)

func processar_animacoes(direction: float):
	if not is_on_floor():
		# ── No ar ──────────────────────────────────────────────────────────────
		if Input.is_action_pressed("quadrado"):
			_animated_sprite.play("jump_punch")
			_animated_sprite.scale  = ESCALA_SOCO_AR
			_animated_sprite.offset = Vector2(0, -15)
		elif Input.is_action_pressed("triangulo"):
			_animated_sprite.play("jump_kick")
			_animated_sprite.scale  = ESCALA_SOCO_AR
			_animated_sprite.offset = Vector2(0, -15)
		else:
			_animated_sprite.play("jump")
			_animated_sprite.scale  = ESCALA_PULO
			_animated_sprite.offset = Vector2(0, -10)
		return

	# ── No chão ────────────────────────────────────────────────────────────────
	_animated_sprite.offset = Vector2(0, 0)

	if agachado:
		_animated_sprite.scale = ESCALA_AGACHADO
		match animacao_ataque:
			"shift_punch":
				_animated_sprite.play("shift_punch")
				_animated_sprite.scale  = Vector2(1.3, 1.3)
				_animated_sprite.offset = Vector2(0, 50)
			"shift_kick":
				_animated_sprite.play("shift_kick")
				_animated_sprite.scale  = Vector2(0.6, 0.6)
				_animated_sprite.offset = Vector2(0, 250)
			"shift_block":
				_animated_sprite.play("shift_block")
				_animated_sprite.scale  = Vector2(0.6, 0.6)
				_animated_sprite.offset = Vector2(0, 100)
			_:
				_animated_sprite.play("shift")
				_animated_sprite.offset = Vector2(0, 100)
	elif atacando or bloqueando:
		_animated_sprite.scale = ESCALA_PADRAO
		_animated_sprite.play(animacao_ataque)
	elif direction != 0:
		_animated_sprite.scale = ESCALA_PADRAO
		_animated_sprite.play("walk")
	else:
		_animated_sprite.scale = ESCALA_PADRAO
		_animated_sprite.play("stop")

func atualizar_barra_vida():
	if barra_vida:
		barra_vida.value = vida_atual
