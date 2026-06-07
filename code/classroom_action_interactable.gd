extends Area2D

signal interacted(action: StringName)

@export var action: StringName = &""
@export var enabled: bool = true

@onready var exclamation_mark: Sprite2D = get_node_or_null("ExclamationMark") as Sprite2D

var player_is_close: bool = false
var interaction_running: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_icon()


func _process(_delta: float) -> void:
	if not enabled:
		return
	if not player_is_close:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return
	if interaction_running or GameManager.is_dialogue_active:
		return

	interaction_running = true
	interacted.emit(action)
	await get_tree().process_frame
	interaction_running = false


func set_enabled(value: bool) -> void:
	enabled = value
	_update_icon()


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
	exclamation_mark.visible = enabled and player_is_close
