extends CharacterBody2D

@onready var _animated_sprite = $Moves
@onready var collision = $CollisionShape2D
@export var player_1: CharacterBody2D

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
var intervalo_decisao = 0.15 # Intervalo ligeiramente menor para simulações mais precisas

func _ready():
	if not player_1:
		for node in get_parent().get_children():
			if node is CharacterBody2D and node != self:
				player_1 = node
				break
	
	ajustar_colisao_ao_sprite()

func _physics_process(delta):
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

	move_and_slide()
	processar_animacoes()

func processar_logica_ia():
	var direcao_para_p1 = player_1.global_position.x - global_position.x
	var distancia_absoluta = abs(direcao_para_p1)
	var direcao_normalizada = sign(direcao_para_p1)

	if direcao_normalizada != 0:
		_animated_sprite.flip_h = direcao_normalizada > 0

	# --- IMPLEMENTAÇÃO ADAPTADA DO MINIMAX ---
	# Lista de ações possíveis que a IA pode tomar neste ciclo
	var acoes_possiveis = ["soco", "chute", "bloqueio", "agachar_soco", "agachar_chute", "pular", "aproximar"]
	
	var melhor_acao = ""
	var melhor_score = -999999.0 # Inicializa com o pior valor possível para maximizar

	# Coleta os dados do estado atual do Player 1 (Oponente "Minimizador")
	var p1_atacando = player_1.get("atacando") if "atacando" in player_1 else false
	var p1_bloqueando = player_1.get("bloqueando") if "bloqueando" in player_1 else false
	var p1_agachado = player_1.get("agachado") if "agachado" in player_1 else false
	var p1_no_ar = not player_1.is_on_floor()

	# Avalia cada ramificação da árvore de decisão de profundidade 1
	for acao in acoes_possiveis:
		# Calcula a pontuação com base na matriz de recompensa contra a ação do oponente
		var score_atual = avaliar_utilidade_minimax(acao, distancia_absoluta, p1_atacando, p1_bloqueando, p1_agachado, p1_no_ar)
		
		# Adiciona uma leve variação aleatória para a IA não se tornar 100% previsível
		score_atual += randf_range(-5.0, 5.0)

		# ETAPA MAX: Escolhe a ação que gera o maior score positivo para a IA
		if score_atual > melhor_score:
			melhor_score = score_atual
			melhor_acao = acao

	# Executa a melhor ação encontrada pelo Minimax
	executar_acao_escolhida(melhor_acao, direcao_normalizada, distancia_absoluta)

# Matriz de Avaliação de Utilidade (Função Heurística do Minimax)
func avaliar_utilidade_minimax(acao_ia, distancia, p1_ataca, p1_bloqueia, p1_agacha, p1_no_ar) -> float:
	var score = 0.0

	# Regras para quando a IA decide atacar ("soco" ou "chute")
	if acao_ia == "soco" or acao_ia == "chute":
		if distancia > DISTANCIA_CORPO_A_CORPO:
			score -= 50.0 # Péssimo: Atacar o vento de longe deixa a IA vulnerável
		else:
			score += 40.0 # Bom: Está perto para acertar
			if p1_ataca:
				score -= 20.0 # Risco de contra-ataque mútuo
			if p1_bloqueia:
				score -= 30.0 # Ruim: Oponente vai mitigar o dano
			if p1_agacha and acao_ia == "soco":
				score -= 40.0 # Ruim: Soco alto erra oponente agachado

	# Regras para quando a IA decide Bloquear
	elif acao_ia == "bloqueio":
		if p1_ataca and distancia <= DISTANCIA_CORPO_A_CORPO:
			score += 100.0 # Excelente: Minimiza perfeitamente o ataque iminente do jogador
		elif distancia > DISTANCIA_CORPO_A_CORPO:
			score -= 20.0 # Inútil: Bloquear de longe sem perigo iminente

	# Regras para ataques agachados (Antiaéreos ou rasteiras)
	elif acao_ia == "agachar_soco" or acao_ia == "agachar_chute":
		if distancia <= DISTANCIA_CORPO_A_CORPO:
			if p1_no_ar:
				score += 90.0 # Excelente: Derruba o jogador saindo do ar (Anti-Air)
			elif p1_bloqueia:
				score += 50.0 # Bom: Chute rasteiro costuma quebrar defesas altas
			else:
				score += 30.0
		else:
			score -= 50.0

	# Regras para Pular
	elif acao_ia == "pular":
		if p1_agacha and distancia <= DISTANCIA_CORPO_A_CORPO:
			score += 60.0 # Bom: Pular evita ataques rasteiros
		elif distancia > DISTANCIA_CORPO_A_CORPO and randf() < 0.2:
			score += 20.0 # Movimentação aérea casual
		else:
			score -= 10.0

	# Regras para se aproximar do jogador
	elif acao_ia == "aproximar":
		if distancia > DISTANCIA_CORPO_A_CORPO:
			score += 80.0 # Prioridade Máxima: Se está longe, precisa caçar o oponente
		else:
			score -= 70.0 # Péssimo: Continuar andando para frente colado no alvo gera penalidade

	return score

# Aplica as variáveis físicas e de animação baseadas no resultado vencedor do algoritmo
func executar_acao_escolhida(acao, direcao_normalizada, distancia):
	# Reseta estados padrões de chão
	agachado = false
	if is_on_floor():
		atacando = false
		bloqueando = false

	# Comportamento caso a IA já esteja executando um pulo
	if not is_on_floor():
		if acao in ["soco", "agachar_soco"]:
			_animated_sprite.play("jump_punch")
		elif acao in ["chute", "agachar_chute"]:
			_animated_sprite.play("jump kick")
		return

	# Traduz a string do algoritmo em ações reais da máquina de física do jogo
	match acao:
		"soco":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			atacando = true
			animacao_ataque = "punch"
		"chute":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			atacando = true
			animacao_ataque = "kick"
		"bloqueio":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			bloqueando = true
			animacao_ataque = "block"
		"agachar_soco":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			agachado = true
			animacao_ataque = "shift_punch"
		"agachar_chute":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			agachado = true
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
		elif _animated_sprite.animation == "jump kick":
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
