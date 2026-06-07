extends Node

@export var boss_path: NodePath
@export var exit_door_path: NodePath
@export var victory_dialogue_resource: DialogueResource
@export_file("*.tscn") var exit_target_scene: String = "res://scenes/Hallway.tscn"

@onready var boss: Node = get_node_or_null(boss_path)
@onready var exit_door: Area2D = get_node_or_null(exit_door_path) as Area2D

var dialogue_running: bool = false
var victory_sequence_started: bool = false


func _ready() -> void:
	_play_scene_music(&"cafeteria_battle", 0.45)
	if exit_door != null and exit_door.has_method("set_enabled"):
		exit_door.call("set_enabled", false)

	if boss != null and boss.has_signal("defeated"):
		var defeated_callback: Callable = Callable(self, "_on_boss_defeated")
		if not boss.is_connected("defeated", defeated_callback):
			boss.connect("defeated", defeated_callback)

	_connect_action_interactables()


func handle_action(action: StringName) -> void:
	match action:
		&"battle_left_door_exit":
			if exit_target_scene != "":
				_play_sfx(&"door")
				get_tree().change_scene_to_file(exit_target_scene)


func _on_boss_defeated(_defeated_boss: Node) -> void:
	if victory_sequence_started:
		return

	victory_sequence_started = true
	_play_sfx(&"star", -2.0)
	await _show_dialogue(victory_dialogue_resource)
	if exit_door != null and exit_door.has_method("set_enabled"):
		exit_door.call("set_enabled", true)


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


func _connect_action_interactables() -> void:
	for node: Node in get_tree().get_nodes_in_group("classroom_actions"):
		if node.has_signal("interacted"):
			var callback: Callable = Callable(self, "handle_action")
			if not node.is_connected("interacted", callback):
				node.connect("interacted", callback)

func _play_scene_music(music_key: StringName, fade_seconds: float = 0.75) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_music"):
		audio_manager.call("play_music", music_key, fade_seconds)


func _play_sfx(sfx_key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_key, volume_db, pitch_scale)

