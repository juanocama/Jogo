extends Node

@export var bath_door_dialogue_resource: DialogueResource
@export var gun_pickup_dialogue_resource: DialogueResource
@export var candy_dialogue_resource: DialogueResource
@export var gun_pickup_path: NodePath
@export var candy_pickup_path: NodePath
@export var bath_door_path: NodePath
@export var background_path: NodePath
@export var burned_background_texture: Texture2D
@export var burned_background_scale: Vector2 = Vector2(0.844, 0.844)
@export var glitch_flash_count: int = 5
@export var glitch_flash_duration: float = 0.12

@onready var gun_pickup: Node2D = get_node_or_null(gun_pickup_path) as Node2D
@onready var candy_pickup: Node2D = get_node_or_null(candy_pickup_path) as Node2D
@onready var bath_door: Area2D = get_node_or_null(bath_door_path) as Area2D
@onready var background: Sprite2D = get_node_or_null(background_path) as Sprite2D

var dialogue_running: bool = false
var completed_actions: Dictionary = {}


func _ready() -> void:
	_play_scene_music(&"hallway", 0.75)
	_ensure_bath_door_available()
	_connect_action_interactables()


func handle_action(action: StringName) -> void:
	if completed_actions.has(action):
		return

	match action:
		&"bath_door_in":
			# Mantener la entrada al baño igual que antes del parche de SFX.
			# El sonido de puerta se reproduce desde bathroom_stealth_level.gd
			# cuando la escena ya cargó, para que ningún SFX bloquee el cambio de escena.
			await _show_dialogue_for_action(action, bath_door_dialogue_resource)
			get_tree().change_scene_to_file("res://scenes/bathroom.tscn")
		&"gun_pickup":
			_play_sfx(&"pickup")
			await _show_dialogue_for_action(action, gun_pickup_dialogue_resource)
			await _play_burned_hallway_glitch()
			_hide_pickup(gun_pickup)
		&"candy_2":
			_play_sfx(&"star")
			await _show_dialogue_for_action(action, candy_dialogue_resource)
			_hide_pickup(candy_pickup)


func _show_dialogue_for_action(action: StringName, resource: DialogueResource) -> void:
	if resource == null:
		return

	completed_actions[action] = true
	_disable_action(action)
	await _show_dialogue(resource)


func _show_dialogue(resource: DialogueResource) -> void:
	if dialogue_running or GameManager.is_dialogue_active:
		return

	dialogue_running = true
	GameManager.is_dialogue_active = true
	DialogueManager.show_dialogue_balloon(resource)
	await DialogueManager.dialogue_ended
	await get_tree().create_timer(0.2).timeout
	GameManager.is_dialogue_active = false
	dialogue_running = false


func _hide_pickup(pickup: Node2D) -> void:
	if pickup != null:
		pickup.visible = false


func _play_burned_hallway_glitch() -> void:
	if background == null or burned_background_texture == null:
		return

	_play_sfx(&"transition", -3.0)

	var normal_texture: Texture2D = background.texture
	var normal_scale: Vector2 = background.scale
	var flash_count: int = maxi(glitch_flash_count, 1)
	var flash_duration: float = maxf(glitch_flash_duration, 0.05)

	for _index: int in range(flash_count):
		background.texture = burned_background_texture
		background.scale = burned_background_scale
		await get_tree().create_timer(flash_duration).timeout
		background.texture = normal_texture
		background.scale = normal_scale
		await get_tree().create_timer(flash_duration).timeout


func _ensure_bath_door_available() -> void:
	# El baño es una escena de sigilo/escondidas y debe poder abrirse desde el pasillo.
	# En una versión del proyecto, BathDoorIn quedó con enabled=false dentro de Hallway.tscn;
	# por eso el jugador se paraba frente a la puerta pero nunca recibía la interacción.
	if bath_door == null:
		bath_door = get_node_or_null("../BathDoorIn") as Area2D
	if bath_door != null and bath_door.has_method("set_enabled"):
		bath_door.call("set_enabled", true)

func _connect_action_interactables() -> void:
	var callback: Callable = Callable(self, "handle_action")
	for node: Node in get_tree().get_nodes_in_group("classroom_actions"):
		if node.has_signal("interacted"):
			if not node.is_connected("interacted", callback):
				node.connect("interacted", callback)

	# Fallback explícito para la puerta del baño. Así la entrada no depende solo del grupo.
	if bath_door != null and bath_door.has_signal("interacted"):
		if not bath_door.is_connected("interacted", callback):
			bath_door.connect("interacted", callback)


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


func _play_sfx(sfx_key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_key, volume_db, pitch_scale)

