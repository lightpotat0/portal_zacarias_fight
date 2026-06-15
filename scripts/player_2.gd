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
var mantendo_bloqueio = false
var tempo_bloqueio = 0.0
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
var tipo_ataque_atual: String = "medio"

var invencivel = false
var tempo_invencibilidade = 0.0

class EstadoJogo:
	var vida_ia: float
	var vida_p1: float
	var distancia: float
	var ia_atacando: bool
	var ia_bloqueando: bool
	var ia_agachado: bool
	var ia_no_ar: bool
	var p1_atacando: bool
	var p1_bloqueando: bool
	var p1_agachado: bool
	var p1_no_ar: bool

	func _init(v_ia, v_p1, dist, atk_ia, blk_ia, agch_ia, ar_ia, atk_p1, blk_p1, agch_p1, ar_p1):
		vida_ia     = v_ia
		vida_p1     = v_p1
		distancia   = dist
		ia_atacando = atk_ia
		ia_bloqueando = blk_ia
		ia_agachado = agch_ia
		ia_no_ar    = ar_ia
		p1_atacando = atk_p1
		p1_bloqueando = blk_p1
		p1_agachado = agch_p1
		p1_no_ar    = ar_p1

func _ready():
	vida_atual = vida_maxima
	atualizar_barra_vida()
	if not player_1:
		for node in get_parent().get_children():
			if node is CharacterBody2D and node != self:
				player_1 = node
				break
	if collision and collision.shape is CapsuleShape2D:
		tamanho_colisao_original = Vector2(collision.shape.radius, collision.shape.height)

func _physics_process(delta):
	if morto:
		_animated_sprite.play("die")
		_animated_sprite.scale = Vector2(1.0, 1.0)
		_animated_sprite.modulate = Color.WHITE
		if not is_on_floor():
			velocity.y += gravity * FALL_GRAVITY_SCALE * delta
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.3)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.y = 0
		move_and_slide()
		return

	if invencivel:
		tempo_invencibilidade -= delta
		if tempo_invencibilidade <= 0:
			invencivel = false
			_animated_sprite.modulate = Color.WHITE

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
		
	if mantendo_bloqueio:
		tempo_bloqueio -= delta
	if tempo_bloqueio <= 0:
		mantendo_bloqueio = false

	move_and_slide()
	ajustar_colisao_estado()
	processar_animacoes()
	verificar_dano_causado(delta)

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
		collision.shape.height = altura_original * 0.8
		collision.shape.radius = raio_original * 0.8
		collision.position = Vector2(0, (altura_original - altura_original * 0.8) * 0.5)
	else:
		collision.shape.height = altura_original
		collision.shape.radius = raio_original
		collision.position = Vector2(0, 0)

func processar_logica_ia():
	var direcao_para_p1 = player_1.global_position.x - global_position.x
	var distancia_absoluta = abs(direcao_para_p1)
	var direcao_normalizada = sign(direcao_para_p1)

	if direcao_normalizada != 0:
		_animated_sprite.flip_h = direcao_normalizada > 0
	var p1_atacando  = player_1.get("atacando")  if "atacando"  in player_1 else false
	var p1_bloqueando = player_1.get("bloqueando") if "bloqueando" in player_1 else false
	var p1_agachado  = player_1.get("agachado")  if "agachado"  in player_1 else false
	var p1_no_ar     = not player_1.is_on_floor()
	var p1_vida      = player_1.get("vida_atual") if "vida_atual" in player_1 else 100.0
	var estado_raiz = EstadoJogo.new(
		vida_atual, p1_vida, distancia_absoluta,
		atacando, bloqueando, agachado, not is_on_floor(),
		p1_atacando, p1_bloqueando, p1_agachado, p1_no_ar
	)
	if p1_atacando and distancia_absoluta <= DISTANCIA_CORPO_A_CORPO:
		mantendo_bloqueio = true
		tempo_bloqueio = 0.6
		if p1_agachado:
			agachado = true
			animacao_ataque = "shift_block"
		else:
			agachado = false
			animacao_ataque = "block"
		bloqueando = true
		velocity.x = 0
		return
	if mantendo_bloqueio:
		bloqueando = true
		velocity.x = 0
		return

	var resultado = minimax(estado_raiz, 4, -INF, INF, true)
	var melhor_acao = resultado[1]

	executar_acao_escolhida(melhor_acao, direcao_normalizada, distancia_absoluta)

func minimax(estado: EstadoJogo, profundidade: int, alpha: float, beta: float, maximizando: bool) -> Array:
	if profundidade == 0 or estado.vida_ia <= 0 or estado.vida_p1 <= 0:
		return [avaliar_estado(estado), "nenhuma"]

	var acoes_ia  = ["soco", "chute", "bloqueio", "agachar_soco", "agachar_chute", "aproximar"]
	if estado.p1_agachado and estado.p1_bloqueando:
		acoes_ia.append("pular")
	if estado.p1_no_ar:
		acoes_ia.append("pular")
	var acoes_p1 = [
		"atacar",
		"atacar",
		"atacar",
		"bloquear",
		"agachar",
		"pular",
	    "recuar"
	]

	if maximizando:
		var melhor_score = -INF
		var melhor_acao  = acoes_ia[0]

		for acao in acoes_ia:
			var novo_estado = simular_acao_ia(estado, acao)
			var resultado   = minimax(novo_estado, profundidade - 1, alpha, beta, false)
			var score       = resultado[0]
			score += randf_range(-2.0, 2.0)
			if score > melhor_score:
				melhor_score = score
				melhor_acao  = acao
			alpha = max(alpha, melhor_score)
			if beta <= alpha:
				break 
		return [melhor_score, melhor_acao]
	else:
		var pior_score = INF
		var acao_p1_escolhida = acoes_p1[0]

		for acao in acoes_p1:
			var novo_estado = simular_acao_p1(estado, acao)
			var resultado   = minimax(novo_estado, profundidade - 1, alpha, beta, true)
			var score       = resultado[0]

			if score < pior_score:
				pior_score = score
				acao_p1_escolhida = acao

			beta = min(beta, pior_score)
			if beta <= alpha:
				break  

		return [pior_score, acao_p1_escolhida]

func simular_acao_ia(e: EstadoJogo, acao: String) -> EstadoJogo:
	var n = EstadoJogo.new(
		e.vida_ia, e.vida_p1, e.distancia,
		e.ia_atacando, e.ia_bloqueando, e.ia_agachado, e.ia_no_ar,
		e.p1_atacando, e.p1_bloqueando, e.p1_agachado, e.p1_no_ar
	)

	match acao:
		"soco":
			n.ia_atacando = true
			n.ia_agachado = false
			if n.distancia <= DISTANCIA_CORPO_A_CORPO:
				if n.p1_bloqueando and n.p1_agachado == false:
					n.vida_p1 -= 10.0 * 0.1  
				elif not n.p1_bloqueando:
					n.vida_p1 -= 10.0

		"chute":
			n.ia_atacando = true
			n.ia_agachado = false
			if n.distancia <= DISTANCIA_CORPO_A_CORPO:
				if n.p1_bloqueando and n.p1_agachado:
					n.vida_p1 -= 15.0 * 0.1  
				elif not n.p1_bloqueando:
					n.vida_p1 -= 15.0

		"bloqueio":
			n.ia_bloqueando = true
			n.ia_atacando   = false
			if n.p1_atacando and n.distancia <= DISTANCIA_CORPO_A_CORPO:
				n.vida_ia -= 5.0 * 0.1   

		"agachar_soco":
			n.ia_agachado = true
			n.ia_atacando = true
			if n.distancia <= DISTANCIA_CORPO_A_CORPO:
				if not n.p1_bloqueando or not n.p1_agachado:
					n.vida_p1 -= 8.0

		"agachar_chute":
			n.ia_agachado = true
			n.ia_atacando = true
			if n.distancia <= DISTANCIA_CORPO_A_CORPO:
				if not n.p1_bloqueando or not n.p1_agachado:
					n.vida_p1 -= 12.0

		"pular":
			n.ia_no_ar  = true
			n.distancia = max(50.0, n.distancia - 80.0)  

		"aproximar":
			n.distancia = max(0.0, n.distancia - SPEED * intervalo_decisao)

	return n

func simular_acao_p1(e: EstadoJogo, acao: String) -> EstadoJogo:
	var n = EstadoJogo.new(
		e.vida_ia, e.vida_p1, e.distancia,
		e.ia_atacando, e.ia_bloqueando, e.ia_agachado, e.ia_no_ar,
		e.p1_atacando, e.p1_bloqueando, e.p1_agachado, e.p1_no_ar
	)

	match acao:
		"atacar":
			n.p1_atacando = true
			if n.distancia <= DISTANCIA_CORPO_A_CORPO:
				if n.ia_bloqueando:
					n.vida_ia -= 10.0 * 0.1
				else:
					n.vida_ia -= 10.0

		"bloquear":
			n.p1_bloqueando = true
			n.p1_atacando   = false

		"agachar":
			n.p1_agachado = true
			n.p1_atacando = false
			if n.ia_atacando and n.distancia <= DISTANCIA_CORPO_A_CORPO:
				n.vida_ia -= 0.0  

		"pular":
			n.p1_no_ar  = true
			n.p1_agachado = false

		"recuar":
			n.distancia += SPEED * intervalo_decisao * 0.8

	return n

func avaliar_estado(e: EstadoJogo) -> float:
	if e.vida_ia <= 0:
		return -10000.0
	if e.vida_p1 <= 0:
		return 10000.0

	var score = 0.0

	# Vantagem de vida
	score += (e.vida_ia - e.vida_p1) * 2.0

	# Ataques
	if e.ia_atacando and e.distancia <= DISTANCIA_CORPO_A_CORPO:
		score += 30.0
	elif e.ia_atacando and e.distancia > DISTANCIA_CORPO_A_CORPO:
		score -= 60.0

	# Bloqueio correto
	if e.ia_bloqueando and e.p1_atacando and e.distancia <= DISTANCIA_CORPO_A_CORPO:
		score += 150.0

		# Bônus extra se estiver defendendo baixo contra ataque baixo
		if e.p1_agachado and e.ia_agachado:
			score += 100.0

		# Penalidade se estiver defendendo alto contra ataque baixo
		if e.p1_agachado and not e.ia_agachado:
			score -= 100.0

	if e.ia_bloqueando and not e.p1_atacando:
		score -= 15.0

	# Ser atingido sem bloquear
	if e.p1_atacando and not e.ia_bloqueando and e.distancia <= DISTANCIA_CORPO_A_CORPO:
		score -= 150.0

	# Posicionamento
	if e.distancia > DISTANCIA_AFASTADO:
		score -= 20.0

	if e.distancia <= DISTANCIA_CORPO_A_CORPO and not e.p1_atacando:
		score += 15.0

	# Golpes errados
	if e.ia_atacando and e.p1_agachado and not e.ia_agachado:
		score -= 20.0

	if e.ia_agachado and e.ia_atacando and e.p1_agachado and e.p1_bloqueando:
		score -= 10.0

	if e.ia_agachado and e.p1_no_ar:
		score += 10.0

	# Pouca vida = jogar defensivamente
	if e.vida_ia < 30.0:
		if e.ia_bloqueando and e.p1_atacando:
			score += 20.0
		score -= 10.0
		
	if e.ia_no_ar and e.p1_agachado and e.p1_bloqueando:
		score += 40.0

	if e.ia_no_ar and e.p1_no_ar:
		score += 25.0

	if e.ia_no_ar and not (e.p1_agachado and e.p1_bloqueando) and not e.p1_no_ar:
		score -= 100.0

	return score

func executar_acao_escolhida(acao, direcao_normalizada, distancia):
	if atacando:
		var p1_atacando = player_1.get("atacando") if "atacando" in player_1 else false

		if p1_atacando and randf() < 0.7:
			atacando = false
			bloqueando = true
			animacao_ataque = "block"
		
		return

	agachado  = false
	bloqueando = false

	if not is_on_floor():
		if acao in ["soco", "agachar_soco"]:
			_animated_sprite.play("jump_punch")
		elif acao in ["chute", "agachar_chute"]:
			_animated_sprite.play("jump_kick")
		return

	var ao_alcance = distancia <= DISTANCIA_CORPO_A_CORPO

	match acao:
		"soco":
			if ao_alcance:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				atacando = true
				tempo_ataque = duracao_ataque
				animacao_ataque = "punch"
			else:
				velocity.x = direcao_normalizada * SPEED 
		"chute":
			if ao_alcance:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				atacando = true
				tempo_ataque = duracao_ataque
				animacao_ataque = "kick"
			else:
				velocity.x = direcao_normalizada * SPEED
		"bloqueio":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			bloqueando = true

			if player_1.agachado:
				agachado = true
				animacao_ataque = "shift_block"
			else:
				agachado = false
				animacao_ataque = "block"
		"agachar_soco":
			if ao_alcance:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				agachado  = true
				atacando  = true
				tempo_ataque = duracao_ataque
				animacao_ataque = "shift_punch"
			else:
				velocity.x = direcao_normalizada * SPEED
		"agachar_chute":
			if ao_alcance:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				agachado  = true
				atacando  = true
				tempo_ataque = duracao_ataque
				animacao_ataque = "shift_kick"
			else:
				velocity.x = direcao_normalizada * SPEED
		"pular":
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				velocity.x = direcao_normalizada * SPEED
		"aproximar":
			velocity.x = direcao_normalizada * SPEED * 0.7
	
func processar_animacoes():
	if em_knockback:
		if _animated_sprite.sprite_frames.has_animation("shock"):
			_animated_sprite.play("shock")
			_animated_sprite.scale = Vector2(1.0, 1.0)
		else:
			_animated_sprite.play("stop")
		return

	if not is_on_floor():
		if atacando and animacao_ataque != "":
			_animated_sprite.play(animacao_ataque)
		elif _animated_sprite.animation not in ["jump_punch", "jump_kick"]:
			_animated_sprite.play("jump")

		if _animated_sprite.animation == "jump_punch":
			_animated_sprite.scale = Vector2(1.6, 1.6)
			_animated_sprite.offset = Vector2(0, -15)
		elif _animated_sprite.animation == "jump_kick":
			_animated_sprite.scale = Vector2(0.8, 0.8)
			_animated_sprite.offset = Vector2(0, -15)
		else:
			_animated_sprite.scale = Vector2(1.3, 1.3)
			_animated_sprite.offset = Vector2(0, -10)
	else:
		_animated_sprite.scale  = Vector2(1.0, 1.0)
		_animated_sprite.offset = Vector2(0, 0)

		if agachado:
			var anim_alvo = animacao_ataque if animacao_ataque in ["shift_punch", "shift_kick", "shift_block"] else "shift"
			_animated_sprite.play(anim_alvo)
			match anim_alvo:
				"shift_punch":
					_animated_sprite.scale  = Vector2(1.2, 1.2)
					_animated_sprite.offset = Vector2(0, 50)
				"shift_kick":
					_animated_sprite.scale  = Vector2(1.0, 1.0)
					_animated_sprite.offset = Vector2(0, 50)
				"shift_block":
					_animated_sprite.scale  = Vector2(0.9, 0.9)
					_animated_sprite.offset = Vector2(0, 50)
				"shift":
					_animated_sprite.scale  = Vector2(1.1, 1.1)
					_animated_sprite.offset = Vector2(0, 50)
		elif atacando or bloqueando:
			_animated_sprite.play(animacao_ataque)
		elif abs(velocity.x) > 10:
			_animated_sprite.play("walk")
		else:
			_animated_sprite.play("stop")

func receber_dano(quantidade: float, direcao_dano: float, tipo_golpe: String = "alto"):
	if morto or invencivel:
		return
	if bloqueando:
		if (not agachado and tipo_golpe == "alto") or (agachado and tipo_golpe == "baixo"):
			vida_atual -= 0
			return
			if vida_atual <= 0:
				morrer()
			return
	vida_atual -= quantidade
	atualizar_barra_vida()
	_animated_sprite.modulate = Color(1, 0.2, 0.2, 1)
	invencivel = true
	tempo_invencibilidade = 0.4
	if vida_atual <= 0:
		morrer()
	else:
		if _animated_sprite.sprite_frames.has_animation("shock"):
			_animated_sprite.play("shock")
		else:
			_animated_sprite.play("stop")
		em_knockback = true
		tempo_knockback = 0.25
		velocity.x   = direcao_dano * 400.0
		if is_on_floor():
			velocity.y = -300.0

func verificar_dano_causado(delta):
	if not player_1 or not is_instance_valid(player_1):
		return
	tempo_dano -= delta
	if tempo_dano > 0:
		return

	var anim_atual  = _animated_sprite.animation
	var distancia   = abs(player_1.global_position.x - global_position.x)
	var direcao_dano = sign(player_1.global_position.x - global_position.x)
	var dano        = 0.0
	var tipo_golpe  = "alto"

	match anim_atual:
		"punch":      dano = 10.0;  tipo_golpe = "alto"
		"kick":       dano = 15.0;  tipo_golpe = "baixo"
		"shift_punch":dano =  8.0;  tipo_golpe = "baixo"
		"shift_kick": dano = 12.0;  tipo_golpe = "baixo"
		"jump_punch": dano = 13.0;  tipo_golpe = "alto"
		"jump_kick":  dano = 18.0;  tipo_golpe = "alto"

	if dano > 0 and distancia <= DISTANCIA_CORPO_A_CORPO:
		player_1.receber_dano(dano, direcao_dano, tipo_golpe)
		tempo_dano = intervalo_dano

func morrer():
	morto    = true
	velocity = Vector2.ZERO

func _aplicar_colisao_morto():
	if not collision.shape is CapsuleShape2D:
		return
	var h = tamanho_colisao_original.y
	collision.shape = collision.shape.duplicate()
	collision.shape.radius   = h * 0.25
	collision.shape.height   = h * 0.5
	collision.position       = Vector2(0, h * 0.25)

func atualizar_barra_vida():
	if barra_vida:
		barra_vida.value = vida_atual

func altura_sprite() -> float:
	if tamanho_colisao_original != Vector2.ZERO:
		return tamanho_colisao_original.y * 0.3
	return 30.0
