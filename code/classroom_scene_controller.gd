extends Node

@export var player_path: NodePath
@export var girl_path: NodePath
@export var camera_path: NodePath
@export var background_path: NodePath
@export var photo_overlay_path: NodePath
@export var photo_pickup_path: NodePath
@export var entropia_icon_path: NodePath
@export var door_interactable_path: NodePath
@export var dialogue_resource: DialogueResource
@export var photo_dialogue_resource: DialogueResource
@export var candy_dialogue_resource: DialogueResource
@export var sad_background: Texture2D
@export var camera_center: Vector2 = Vector2(581.0, 330.5)
@export var camera_zoom: Vector2 = Vector2(0.72, 0.72)
@export var door_interaction_distance: float = 155.0

@onready var player: CharacterBody2D = get_node(player_path) as CharacterBody2D
@onready var girl: CharacterBody2D = get_node(girl_path) as CharacterBody2D
@onready var camera: Camera2D = get_node(camera_path) as Camera2D
@onready var background: Sprite2D = get_node(background_path) as Sprite2D
@onready var photo_overlay: Control = get_node(photo_overlay_path) as Control
@onready var photo_pickup: Node2D = get_node(photo_pickup_path) as Node2D
@onready var entropia_icon: TextureRect = get_node(entropia_icon_path) as TextureRect
@onready var door_interactable: Area2D = get_node(door_interactable_path) as Area2D

var classroom_sad_active: bool = false
var entropy_loop_active: bool = false
var photo_interaction_running: bool = false
var candy_collected: bool = false
var dialogue_running: bool = false


func _ready() -> void:
	_play_scene_music(&"classroom_normal", 0.6)
	if photo_overlay != null:
		photo_overlay.visible = false
	if photo_pickup != null:
		photo_pickup.visible = true
	if entropia_icon != null:
		entropia_icon.visible = false
	if door_interactable != null and door_interactable.has_method("set_enabled"):
		door_interactable.call("set_enabled", false)
	_set_full_stage_camera()
	_connect_action_interactables()
	call_deferred("_run_intro")


func _process(_delta: float) -> void:
	if not classroom_sad_active:
		return
	if player == null or door_interactable == null:
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return
	if player.global_position.distance_to(door_interactable.global_position) <= door_interaction_distance:
		get_tree().change_scene_to_file("res://scenes/Hallway.tscn")


func handle_action(action: StringName) -> void:
	match action:
		&"bottom_desk":
			if candy_collected:
				return
			candy_collected = true
			_disable_action(action)
			await _show_dialogue(candy_dialogue_resource)
			GameManager.collect_candy(&"classroom_candy_local1")
		&"photo":
			await _run_photo_interaction()
		&"sad_door":
			if classroom_sad_active:
				get_tree().change_scene_to_file("res://scenes/Hallway.tscn")


func _run_intro() -> void:
	_set_full_stage_camera()
	if player != null and player.has_method("force_control_locked"):
		player.call("force_control_locked", true)

	player.global_position = Vector2(95, 630)
	girl.global_position = Vector2(-80, 630)
	if player.has_method("face_towards"):
		player.call("face_towards", girl.global_position)
	if girl.has_method("face_towards"):
		girl.call("face_towards", player.global_position)

	await _show_default_dialogue()
	await _move_girl_up_to_door()
	girl.visible = false
	_set_full_stage_camera()

	if player != null and player.has_method("force_control_locked"):
		player.call("force_control_locked", false)


func _run_photo_interaction() -> void:
	if photo_interaction_running:
		return

	photo_interaction_running = true
	_disable_action(&"photo")
	if photo_pickup != null:
		photo_pickup.visible = false
	if player != null and player.has_method("force_control_locked"):
		player.call("force_control_locked", true)
	if photo_overlay != null:
		photo_overlay.visible = true
	await _show_dialogue(photo_dialogue_resource)
	if photo_overlay != null:
		photo_overlay.visible = false
	_activate_sad_classroom()
	if player != null and player.has_method("force_control_locked"):
		player.call("force_control_locked", false)
	photo_interaction_running = false


func _activate_sad_classroom() -> void:
	if classroom_sad_active:
		return

	classroom_sad_active = true
	_play_scene_music(&"classroom_sad", 0.9)
	if background != null and sad_background != null:
		if background.texture == null:
			background.texture = sad_background
		else:
			var previous_size: Vector2 = Vector2(
				float(background.texture.get_width()) * background.scale.x,
				float(background.texture.get_height()) * background.scale.y
			)
			background.texture = sad_background
			background.scale = Vector2(
				previous_size.x / float(sad_background.get_width()),
				previous_size.y / float(sad_background.get_height())
			)
	if door_interactable != null and door_interactable.has_method("set_enabled"):
		door_interactable.call("set_enabled", true)
	if not entropy_loop_active:
		entropy_loop_active = true
		_entropy_loop()


func _entropy_loop() -> void:
	while entropy_loop_active:
		if entropia_icon != null:
			entropia_icon.visible = true
		if player != null and player.has_method("set_controls_inverted"):
			player.call("set_controls_inverted", true)
		await get_tree().create_timer(3.0).timeout

		if entropia_icon != null:
			entropia_icon.visible = false
		if player != null and player.has_method("set_controls_inverted"):
			player.call("set_controls_inverted", false)
		await get_tree().create_timer(3.0).timeout


func _show_default_dialogue() -> void:
	await _show_dialogue(dialogue_resource)


func _show_dialogue(resource: DialogueResource) -> void:
	if resource == null:
		return
	if dialogue_running or GameManager.is_dialogue_active:
		return
	dialogue_running = true
	GameManager.is_dialogue_active = true
	DialogueManager.show_dialogue_balloon(resource)
	await DialogueManager.dialogue_ended
	await get_tree().create_timer(0.2).timeout
	GameManager.is_dialogue_active = false
	dialogue_running = false


func _focus_camera_on(target_position: Vector2, duration: float) -> void:
	if camera == null:
		return

	camera.top_level = true
	camera.make_current()
	var start_position: Vector2 = camera.global_position
	var elapsed: float = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var weight: float = clampf(elapsed / duration, 0.0, 1.0)
		camera.global_position = start_position.lerp(target_position, weight)
		await get_tree().process_frame


func _move_girl_up_to_door() -> void:
	if girl == null:
		return

	if girl.has_method("move_to"):
		await girl.call("move_to", Vector2(girl.global_position.x, 430.0))


func _set_full_stage_camera() -> void:
	if camera == null:
		return
	camera.top_level = true
	camera.global_position = camera_center
	camera.zoom = camera_zoom
	camera.make_current()


func _connect_action_interactables() -> void:
	for node: Node in get_tree().get_nodes_in_group("classroom_actions"):
		if node.has_signal("interacted"):
			var callback: Callable = Callable(self, "handle_action")
			if not node.is_connected("interacted", callback):
				node.connect("interacted", callback)


func _disable_action(action: StringName) -> void:
	for node: Node in get_tree().get_nodes_in_group("classroom_actions"):
		if not node.has_method("set_enabled"):
			continue
		var node_action: StringName = StringName(node.get("action"))
		if node_action == action:
			node.call("set_enabled", false)

func _play_scene_music(music_key: StringName, fade_seconds: float = 0.75) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_music"):
		audio_manager.call("play_music", music_key, fade_seconds)

