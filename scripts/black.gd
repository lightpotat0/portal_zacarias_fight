extends MenuButton

func _ready() -> void:
	connect("mouse_entered", mouse_entrou)
	connect("mouse_exited", mouse_saiu)
	$"../Black1".pressed.connect(botao_clicado)
	$"../Black1".visible = false

func mouse_entrou():
	$"../Black1".visible = true
	
func mouse_saiu():
	$"../Black1".visible = false

func botao_clicado():
	var sprite = $"../Black1"
	sprite.frame = 1
	sprite.stop()
	
