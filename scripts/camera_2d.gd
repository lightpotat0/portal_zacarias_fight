extends Camera2D

@onready var player_1 = get_node("../Player1")
@onready var player_2 = get_node("../Player2") 
@export var smooth_speed: float = 5.0
@export var zoom_combate: Vector2 = Vector2(1.2, 1.2) 
@export var zoom_introducao: Vector2 = Vector2(0.8, 0.8) 

var batalha_comecou: bool = false
var tempo_intro: float = 0.0

func _ready() -> void:
	limit_left = -500    
	limit_right = 1680
	zoom = zoom_introducao
	bloquear_jogadores(true)
	executar_contagem_regressiva()

func _process(delta: float) -> void:
	var target_position = global_position
	
	if not batalha_comecou:
		tempo_intro += delta
		zoom = zoom.lerp(zoom_combate, 0.5 * delta) 
		
		if player_1 and player_2:
			target_position.x = (player_1.global_position.x + player_2.global_position.x) / 2
	else:
		if player_1 and player_2 and is_instance_valid(player_1) and is_instance_valid(player_2):
			target_position.x = (player_1.global_position.x + player_2.global_position.x) / 2
		elif player_1 and is_instance_valid(player_1):
			target_position.x = player_1.global_position.x

	global_position = global_position.lerp(target_position, smooth_speed * delta)

func executar_contagem_regressiva() -> void:
	await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(1.0).timeout
	batalha_comecou = true
	bloquear_jogadores(false)

func bloquear_jogadores(bloquear: bool) -> void:
	if player_1 and is_instance_valid(player_1):
		player_1.set_physics_process(!bloquear)
		if player_1.has_node("Moves"):
			var sprite_p1 = player_1.get_node("Moves")
			if bloquear:
				sprite_p1.play("begin")
				sprite_p1.speed_scale = 0.5  
				sprite_p1.scale = Vector2(1.3, 1.3)   
				sprite_p1.offset = Vector2(0, 0)     
			else:
				sprite_p1.speed_scale = 1.0  
	if player_2 and is_instance_valid(player_2):
		player_2.set_physics_process(!bloquear)
		if player_2.has_node("Moves"):
			var sprite_p2 = player_2.get_node("Moves")
			if bloquear:
				sprite_p2.play("begin")
				sprite_p2.speed_scale = 0.2
				sprite_p2.scale = Vector2(0.8, 0.8)   
				sprite_p2.offset = Vector2(0, 0)      
			else:
				sprite_p2.speed_scale = 1.0
