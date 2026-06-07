extends Node2D

@export_file("*.tscn") var start_scene: String = "res://scenes/Tutorial.tscn"
@export var scene_fade_duration: float = 0.45

var transition_running: bool = false
var fade_rect: ColorRect


func _ready() -> void:
	_setup_scene_fade()
	await _fade_scene(0.0)


func _on_start_pressed() -> void:
	if transition_running:
		return

	transition_running = true
	await _fade_scene(1.0)
	get_tree().change_scene_to_file(start_scene)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _setup_scene_fade() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.size = get_viewport_rect().size
	fade_rect.modulate.a = 1.0
	layer.add_child(fade_rect)


func _fade_scene(target_alpha: float) -> void:
	if fade_rect == null:
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", target_alpha, scene_fade_duration)
	await tween.finished
