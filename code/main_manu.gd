extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_play_scene_music(&"classroom_normal", 0.75)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/classroom.tscn")


func _on_exit_pressed():
	get_tree().quit()

func _play_scene_music(music_key: StringName, fade_seconds: float = 0.75) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_music"):
		audio_manager.call("play_music", music_key, fade_seconds)

