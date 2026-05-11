extends MenuButton

var select_screen = preload("res://scenes/luta.tscn").instantiate()

func _ready():
	self.pressed.connect(_button_pressed)
func _button_pressed():
	get_tree().root.add_child(select_screen)
	queue_free()
