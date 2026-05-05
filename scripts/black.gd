extends MenuButton

var clicado = false

func _ready() -> void:
	connect("mouse_entered", mouse_entrou)
	connect("mouse_exited", mouse_saiu)
	$"../Black1".visible = false
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		var sprite = $"../Black1"
		botao_clicado()
		
func mouse_entrou():
	if clicado: return
	$"../Black1".visible = true
	
func mouse_saiu():
	if clicado:
		$"../Black1".visible = true
	else: 
		$"../Black1".visible = false

func botao_clicado():
	clicado = true
	var sprite = $"../Black1"
	sprite.stop()
	sprite.frame = 1
	sprite.visible = true
	
