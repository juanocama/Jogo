extends Node

@export var music_key: StringName = &""
@export var fade_seconds: float = 0.75
@export var stop_music_on_exit: bool = false
@export var stop_fade_seconds: float = 0.35


func _ready() -> void:
	if music_key == &"":
		return

	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_music"):
		audio_manager.call("play_music", music_key, fade_seconds)


func _exit_tree() -> void:
	if not stop_music_on_exit:
		return

	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", stop_fade_seconds)
