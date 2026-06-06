extends Area2D

@onready var exclamation_mark = $ExclamationMark

var is_player_close = false

func _process(delta):
	if is_player_close and Input.is_action_just_pressed("ui_accept"):
		print("Iniciar dialogo")

func _on_area_entered(area):
	exclamation_mark.visible = true
	is_player_close = true	
	
func _on_area_exited(area):
	exclamation_mark.visible = false
	is_player_close = false	
