extends MenuButton

var clicado = false

func _ready() -> void:
	connect("mouse_entered", mouse_entrou)
	connect("mouse_exited", mouse_saiu)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		botao_clicado()
		
func mouse_entrou():
	if clicado: return
	
func mouse_saiu():
	if clicado: return

func botao_clicado():
	clicado = true
