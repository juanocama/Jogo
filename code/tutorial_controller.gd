extends Control

@export var slides: Array[Texture2D] = []
@export_file("*.tscn") var next_scene: String = "res://scenes/classroom.tscn"
@export var fade_duration: float = 0.45

@onready var slide_image: TextureRect = $SlideImage
@onready var fade_rect: ColorRect = $FadeRect

var current_slide_index: int = 0
var transition_running: bool = false


func _ready() -> void:
	transition_running = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_fullscreen()
	if slides.is_empty():
		_go_to_next_scene()
		return

	slide_image.texture = slides[current_slide_index]
	fade_rect.modulate.a = 1.0
	await _fade_screen(0.0)
	transition_running = false


func _unhandled_input(event: InputEvent) -> void:
	_handle_advance_input(event)


func _gui_input(event: InputEvent) -> void:
	_handle_advance_input(event)


func _handle_advance_input(event: InputEvent) -> void:
	if transition_running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()


func _advance() -> void:
	transition_running = true
	await _fade_screen(1.0)

	current_slide_index += 1
	if current_slide_index >= slides.size():
		_go_to_next_scene()
		return

	slide_image.texture = slides[current_slide_index]
	await _fade_screen(0.0)
	transition_running = false


func _go_to_next_scene() -> void:
	if next_scene != "":
		_change_scene_with_fade_in(next_scene)


func _fade_screen(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", target_alpha, fade_duration)
	await tween.finished


func _setup_fullscreen() -> void:
	size = get_viewport_rect().size
	slide_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func _change_scene_with_fade_in(scene_path: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var transition_layer: CanvasLayer = CanvasLayer.new()
	transition_layer.layer = 100
	var transition_rect: ColorRect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.size = get_viewport_rect().size
	transition_rect.modulate.a = 1.0
	transition_layer.add_child(transition_rect)
	tree.root.add_child(transition_layer)

	var tween: Tween = transition_layer.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(tree, "change_scene_to_file").bind(scene_path))
	tween.tween_interval(0.1)
	tween.tween_property(transition_rect, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(Callable(transition_layer, "queue_free"))
