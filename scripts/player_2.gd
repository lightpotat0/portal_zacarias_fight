extends CharacterBody2D

@onready var _animated_sprite = $Moves
@onready var collision = $CollisionShape2D
@export var player_1: CharacterBody2D
@onready var barra_vida: TextureProgressBar = $Player2/Bars/Bar/TextureProgressBar

const SPEED = 250.0
const JUMP_VELOCITY = -1300.0
const GRAVITY_SCALE = 3
const FALL_GRAVITY_SCALE = 5.0
const DISTANCIA_CORPO_A_CORPO = 150.0
const DISTANCIA_AFASTADO = 400.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var agachado = false
var atacando = false
var bloqueando = false
var animacao_ataque = ""

var tempo_decisao = 0.0
var intervalo_decisao = 0.15
var vida_maxima = 100.0
var vida_atual = 100.0
var morto = false
var em_knockback = false
var tempo_knockback = 0.0

var tempo_ataque = 0.0
var duracao_ataque = 0.4
var tempo_dano = 0.0
var intervalo_dano = 0.4 
var tamanho_colisao_original = Vector2.ZERO

func _ready():
	vida_atual = vida_maxima
	atualizar_barra_vida()
	if not player_1:
		for node in get_parent().get_children():
			if node is CharacterBody2D and node != self:
				player_1 = node
				break
	ajustar_colisao_ao_sprite()
	if collision.shape is RectangleShape2D:
		tamanho_colisao_original = collision.shape.size

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
		processar_animacoes()
		verificar_dano_causado(delta)
		return

	if atacando:
		tempo_ataque -= delta
		if tempo_ataque <= 0:
			atacando = false
			animacao_ataque = ""

	if not is_on_floor():
		if velocity.y < 0:
			velocity.y += gravity * GRAVITY_SCALE * delta
		else:
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta

	if player_1 and is_instance_valid(player_1):
		tempo_decisao += delta
		if tempo_decisao >= intervalo_decisao:
			tempo_decisao = 0.0
			processar_logica_ia()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	ajustar_colisao_estado()
	move_and_slide()
	processar_animacoes()
	verificar_dano_causado(delta)

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

func processar_logica_ia():
	var direcao_para_p1 = player_1.global_position.x - global_position.x
	var distancia_absoluta = abs(direcao_para_p1)
	var direcao_normalizada = sign(direcao_para_p1)

	if direcao_normalizada != 0:
		_animated_sprite.flip_h = direcao_normalizada > 0

	var acoes_possiveis = ["soco", "chute", "bloqueio", "agachar_soco", "agachar_chute", "pular", "aproximar"]
	var melhor_acao = ""
	var melhor_score = -999999.0

	var p1_atacando = player_1.get("atacando") if "atacando" in player_1 else false
	var p1_bloqueando = player_1.get("bloqueando") if "bloqueando" in player_1 else false
	var p1_agachado = player_1.get("agachado") if "agachado" in player_1 else false
	var p1_no_ar = not player_1.is_on_floor()

	for acao in acoes_possiveis:
		var score_atual = avaliar_utilidade_minimax(acao, distancia_absoluta, p1_atacando, p1_bloqueando, p1_agachado, p1_no_ar)
		score_atual += randf_range(-5.0, 5.0)
		if score_atual > melhor_score:
			melhor_score = score_atual
			melhor_acao = acao

	executar_acao_escolhida(melhor_acao, direcao_normalizada, distancia_absoluta)

func avaliar_utilidade_minimax(acao_ia, distancia, p1_ataca, p1_bloqueia, p1_agacha, p1_no_ar) -> float:
	var score = 0.0
	if acao_ia == "soco" or acao_ia == "chute":
		if distancia > DISTANCIA_CORPO_A_CORPO:
			score -= 50.0
		else:
			score += 40.0
			if p1_ataca: score -= 20.0
			if p1_bloqueia: score -= 30.0
			if p1_agacha and acao_ia == "soco": score -= 40.0

	elif acao_ia == "bloqueio":
		if p1_ataca and distancia <= DISTANCIA_CORPO_A_CORPO:
			score += 100.0
		elif distancia > DISTANCIA_CORPO_A_CORPO:
			score -= 20.0

	elif acao_ia == "agachar_soco" or acao_ia == "agachar_chute":
		if distancia <= DISTANCIA_CORPO_A_CORPO:
			if p1_no_ar: score += 90.0
			elif p1_bloqueia: score += 50.0
			else: score += 30.0
		else:
			score -= 50.0

	elif acao_ia == "pular":
		if p1_agacha and distancia <= DISTANCIA_CORPO_A_CORPO:
			score += 60.0
		elif distancia > DISTANCIA_CORPO_A_CORPO and randf() < 0.2:
			score += 20.0
		else:
			score -= 10.0

	elif acao_ia == "aproximar":
		if distancia > DISTANCIA_CORPO_A_CORPO:
			score += 80.0
		else:
			score -= 70.0

	return score

func executar_acao_escolhida(acao, direcao_normalizada, distancia):
	if atacando:
		return

	agachado = false
	bloqueando = false

	if not is_on_floor():
		if acao in ["soco", "agachar_soco"]:
			_animated_sprite.play("jump_punch")
		elif acao in ["chute", "agachar_chute"]:
			_animated_sprite.play("jump_kick")
		return

	match acao:
		"soco":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			atacando = true
			tempo_ataque = duracao_ataque
			animacao_ataque = "punch"
		"chute":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			atacando = true
			tempo_ataque = duracao_ataque
			animacao_ataque = "kick"
		"bloqueio":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			bloqueando = true
			animacao_ataque = "block"
		"agachar_soco":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			agachado = true
			atacando = true
			tempo_ataque = duracao_ataque
			animacao_ataque = "shift_punch"
		"agachar_chute":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			agachado = true
			atacando = true
			tempo_ataque = duracao_ataque
			animacao_ataque = "shift_kick"
		"pular":
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				velocity.x = direcao_normalizada * SPEED
		"aproximar":
			velocity.x = direcao_normalizada * SPEED

func processar_animacoes():
	if not is_on_floor():
		if _animated_sprite.animation == "jump_punch":
			_animated_sprite.scale = Vector2(1.6, 1.6)
			_animated_sprite.offset = Vector2(0, -15)
		elif _animated_sprite.animation == "jump_kick":
			_animated_sprite.scale = Vector2(0.8, 0.8)
			_animated_sprite.offset = Vector2(0, -15)
		else:
			_animated_sprite.play("jump")
			_animated_sprite.scale = Vector2(1.3, 1.3)
			_animated_sprite.offset = Vector2(0, -10)
	else:
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)

		if agachado:
			_animated_sprite.scale = Vector2(1.0, 1.0)
			_animated_sprite.offset = Vector2(0, 100)
			_animated_sprite.play(animacao_ataque if animacao_ataque in ["shift_punch", "shift_kick", "shift_block"] else "shift")
		elif atacando or bloqueando:
			_animated_sprite.play(animacao_ataque)
		elif abs(velocity.x) > 10:
			_animated_sprite.play("walk")
		else:
			_animated_sprite.play("stop")

func ajustar_colisao_ao_sprite():
	var anim_atual = _animated_sprite.animation
	var frame_atual = _animated_sprite.frame
	if _animated_sprite.sprite_frames.has_animation(anim_atual):
		var textura_frame = _animated_sprite.sprite_frames.get_frame_texture(anim_atual, frame_atual)
		if textura_frame:
			var tamanho_sprite = textura_frame.get_size()
			tamanho_sprite *= _animated_sprite.scale
			if collision.shape is RectangleShape2D:
				collision.shape.size = tamanho_sprite

func receber_dano(quantidade: float, direcao_dano: float):
	if morto:
		_animated_sprite.play("die")
		return
	if bloqueando:
		vida_atual -= quantidade * 0.1
		atualizar_barra_vida()
		if vida_atual <= 0:
			morrer()
		return
	vida_atual -= quantidade
	atualizar_barra_vida()
	if vida_atual <= 0:
		morrer()
	else:
		if _animated_sprite.sprite_frames.has_animation("shock"):
			_animated_sprite.play("shock")
		else:
			_animated_sprite.play("stop")
		em_knockback = true
		tempo_knockback = 0.25
		velocity.x = direcao_dano * 400.0
		if is_on_floor():
			velocity.y = -300.0
			
func verificar_dano_causado(delta):
	if not player_1 or not is_instance_valid(player_1):
		return
	tempo_dano -= delta  
	if tempo_dano > 0:
		return

	var anim_atual = _animated_sprite.animation
	var distancia = abs(player_1.global_position.x - global_position.x)
	var direcao_dano = sign(player_1.global_position.x - global_position.x)
	var dano = 0.0

	match anim_atual:
		"punch":       dano = 10.0
		"kick":        dano = 15.0
		"shift_punch": dano = 8.0
		"shift_kick":  dano = 12.0
		"jump_punch":  dano = 13.0
		"jump_kick":   dano = 18.0

	if dano > 0 and distancia <= DISTANCIA_CORPO_A_CORPO:
		player_1.receber_dano(dano, direcao_dano)
		tempo_dano = intervalo_dano
		
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

func atualizar_barra_vida():
	if barra_vida:
		barra_vida.value = vida_atual
