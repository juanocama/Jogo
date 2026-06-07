extends Area2D

signal sad_bathroom_activated

@export var dialogue_resource: DialogueResource
@export var background_node_path: NodePath
@export var sad_background: Texture2D

@onready var exclamation_mark: Sprite2D = get_node_or_null("ExclamationMark") as Sprite2D

var player_is_close: bool = false
var interaction_started: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if exclamation_mark != null:
		exclamation_mark.visible = false


func _process(_delta: float) -> void:
	if not player_is_close:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	_start_dialogue()


func _start_dialogue() -> void:
	if interaction_started:
		return
	if not player_is_close:
		return
	if GameManager.is_dialogue_active:
		return
	if dialogue_resource == null:
		return

	interaction_started = true
	GameManager.is_dialogue_active = true
	DialogueManager.show_dialogue_balloon(dialogue_resource)
	await DialogueManager.dialogue_ended
	await get_tree().create_timer(0.2).timeout
	GameManager.is_dialogue_active = false
	_change_background()
	sad_bathroom_activated.emit()


func _change_background() -> void:
	var background_node: Sprite2D = get_node_or_null(background_node_path) as Sprite2D
	if background_node == null:
		return
	if sad_background == null:
		return
	if background_node.texture == null:
		return

	var previous_size: Vector2 = Vector2(
		float(background_node.texture.get_width()) * background_node.scale.x,
		float(background_node.texture.get_height()) * background_node.scale.y
	)
	var next_size: Vector2 = Vector2(
		float(sad_background.get_width()),
		float(sad_background.get_height())
	)
	if next_size.x <= 0.0 or next_size.y <= 0.0:
		return

	background_node.texture = sad_background
	background_node.scale = Vector2(previous_size.x / next_size.x, previous_size.y / next_size.y)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = true
		if exclamation_mark != null:
			exclamation_mark.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = false
		if exclamation_mark != null:
			exclamation_mark.visible = false
