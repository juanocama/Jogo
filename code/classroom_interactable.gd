extends Area2D

@export var interaction_name: String = ""
@export var dialogue_resource: DialogueResource

@onready var exclamation_mark: Sprite2D = get_node_or_null("ExclamationMark") as Sprite2D

var player_is_close: bool = false
var dialogue_running: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_icon()


func _process(_delta: float) -> void:
	if not player_is_close:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return
	if dialogue_running or GameManager.is_dialogue_active:
		return

	if dialogue_resource != null:
		dialogue_running = true
		GameManager.is_dialogue_active = true
		DialogueManager.show_dialogue_balloon(dialogue_resource)
		await DialogueManager.dialogue_ended
		await get_tree().create_timer(0.2).timeout
		GameManager.is_dialogue_active = false
		dialogue_running = false
	elif interaction_name != "":
		print("Interactuando con: %s" % interaction_name)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = true
		_update_icon()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = false
		_update_icon()


func _update_icon() -> void:
	if exclamation_mark == null:
		return
	exclamation_mark.visible = player_is_close
