extends Area2D

@onready var exclamation_mark = $ExclamationMark

const MY_DIALOGUE = preload("res://Dialogue/Scene1/Dialogue1.dialogue")

var is_dialogue_active = false
var is_player_close = false

func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	

func _process(delta):
	if is_player_close and Input.is_action_just_pressed("ui_accept") and not is_dialogue_active:
		DialogueManager.show_dialogue_balloon(MY_DIALOGUE)

func _on_area_entered(area):
	exclamation_mark.visible = true
	is_player_close = true	
	
func _on_area_exited(area):
	exclamation_mark.visible = false
	is_player_close = false	
	
func _on_dialogue_started(dialogue):
	is_dialogue_active = true

func _on_dialogue_ended(dialogue):
	is_dialogue_active = false
		
	
