extends Area2D

@export var interaction_name: String = ""
@export var dialogue_resource: DialogueResource

var player_is_close: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not player_is_close:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	if dialogue_resource != null:
		DialogueManager.show_dialogue_balloon(dialogue_resource)
	elif interaction_name != "":
		print("Interactuando con: %s" % interaction_name)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = false
