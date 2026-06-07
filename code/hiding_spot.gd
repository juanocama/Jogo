extends Area2D

signal hide_requested(spot: Area2D)
signal unhide_requested(spot: Area2D)

@export var hide_position: Vector2
@export var exit_position: Vector2
@export var hide_icon_texture: Texture2D
@export var exit_icon_texture: Texture2D
@export var target_icon_texture: Texture2D

@onready var interaction_icon: Sprite2D = $InteractionIcon
@onready var target_icon: Sprite2D = $TargetIcon

var level_active: bool = false
var player_is_close: bool = false
var player_hidden_here: bool = false
var available: bool = true


func _ready() -> void:
	add_to_group("hiding_spots")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_icons()


func _process(_delta: float) -> void:
	if not level_active:
		return
	if not player_is_close:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	if player_hidden_here:
		unhide_requested.emit(self)
	elif available:
		hide_requested.emit(self)


func set_level_active(active: bool) -> void:
	level_active = active
	_update_icons()


func set_player_hidden_here(value: bool) -> void:
	player_hidden_here = value
	_update_icons()


func set_targeted(value: bool) -> void:
	if target_icon != null:
		target_icon.visible = value


func get_hide_position() -> Vector2:
	return hide_position


func get_exit_position() -> Vector2:
	return exit_position


func _update_icons() -> void:
	if interaction_icon == null:
		return

	interaction_icon.visible = false
	if not level_active:
		return
	if not player_is_close and not player_hidden_here:
		return

	if player_hidden_here:
		interaction_icon.texture = exit_icon_texture
		interaction_icon.visible = exit_icon_texture != null
	elif available:
		interaction_icon.texture = hide_icon_texture
		interaction_icon.visible = hide_icon_texture != null


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = true
		_update_icons()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		player_is_close = false
		_update_icons()
