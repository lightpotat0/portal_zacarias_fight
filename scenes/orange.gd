extends MenuButton

var clicado = false

func _ready() -> void:
	connect("mouse_entered", mouse_entrou)
	connect("mouse_exited", mouse_saiu)
	$"../Orange1".visible = false
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		var sprite = $"../Orange1"
		botao_clicado()
		
func mouse_entrou():
	if clicado: return
	$"../Orange1".visible = true
	
func mouse_saiu():
	if clicado:
		$"../Orange1".visible = true
	else: 
		$"../Orange1".visible = false

func botao_clicado():
	clicado = true
	var sprite = $"../Orange1"
	sprite.stop()
	sprite.frame = 1
	sprite.visible = true
