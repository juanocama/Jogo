extends Control

const BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/Main Menu/Desk.png"),
	preload("res://assets/Main Menu/Burned_desk.png"),
	preload("res://assets/Main Menu/Leaves.png"),
	preload("res://assets/Main Menu/Burned_leaves.png"),
	preload("res://assets/Main Menu/Lockers.png"),
	preload("res://assets/Main Menu/Burned_locker.png"),
]

const ZOOM: float = 1.5
const PAN_DURATION: float = 6.0
const FADE_DURATION: float = 0.55
const GLITCH_DURATION: float = 0.45
const GLITCH_STEPS: int = 9
const GLITCH_JITTER_X: float = 34.0
const GLITCH_JITTER_Y: float = 8.0

@export var background_textures_override: Array[Texture2D] = []
@export var play_once: bool = false
@export var completion_hold_duration: float = 1.0
@export_file("*.tscn") var completion_scene: String = ""

@onready var image_a: TextureRect = $Image_A
@onready var image_b: TextureRect = $Image_B

var _current_index: int = 0
var _active_image: TextureRect
var _inactive_image: TextureRect
var _pan_tweens: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_active_image = image_a
	_inactive_image = image_b

	var images: Array[TextureRect] = [image_a, image_b]
	for image: TextureRect in images:
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.modulate.a = 0.0

	get_viewport().size_changed.connect(_update_background_size)
	_update_background_size()
	if play_once and not visible:
		await visibility_changed
	call_deferred("_run_background_loop")


func _run_background_loop() -> void:
	var textures: Array[Texture2D] = _get_background_textures()
	if textures.is_empty():
		return

	_show_texture(_active_image, textures[_current_index])
	_active_image.modulate.a = 1.0
	_start_pan(_active_image)

	if play_once:
		await _run_once(textures)
		return

	while is_inside_tree():
		await get_tree().create_timer(PAN_DURATION - FADE_DURATION).timeout
		var previous_index: int = _current_index
		_current_index = (_current_index + 1) % textures.size()

		_show_texture(_inactive_image, textures[_current_index])
		_inactive_image.modulate.a = 0.0
		_start_pan(_inactive_image)

		if _uses_glitch_transition(previous_index, _current_index):
			await _play_glitch_transition()
		else:
			await _play_fade_transition()

		var previous_image: TextureRect = _active_image
		_active_image = _inactive_image
		_inactive_image = previous_image


func _get_background_textures() -> Array[Texture2D]:
	if not background_textures_override.is_empty():
		return background_textures_override
	return BACKGROUND_TEXTURES


func _run_once(textures: Array[Texture2D]) -> void:
	for next_index: int in range(1, textures.size()):
		await get_tree().create_timer(PAN_DURATION - FADE_DURATION).timeout
		var previous_index: int = _current_index
		_current_index = next_index

		_show_texture(_inactive_image, textures[_current_index])
		_inactive_image.modulate.a = 0.0
		_start_pan(_inactive_image)

		if _uses_glitch_transition(previous_index, _current_index):
			await _play_glitch_transition()
		else:
			await _play_fade_transition()

		var previous_image: TextureRect = _active_image
		_active_image = _inactive_image
		_inactive_image = previous_image

	await get_tree().create_timer(completion_hold_duration).timeout
	if completion_scene != "":
		get_tree().change_scene_to_file(completion_scene)


func _update_background_size() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

	if image_a.texture != null:
		_fit_image(image_a)
	if image_b.texture != null:
		_fit_image(image_b)


func _show_texture(image: TextureRect, texture: Texture2D) -> void:
	image.texture = texture
	image.modulate = Color(1.0, 1.0, 1.0, image.modulate.a)
	_fit_image(image)


func _fit_image(image: TextureRect) -> void:
	var viewport_size: Vector2 = size
	var texture_size: Vector2 = image.texture.get_size()
	var cover_scale: float = maxf(
		viewport_size.x / texture_size.x,
		viewport_size.y / texture_size.y
	)

	image.size = texture_size * cover_scale * ZOOM
	image.position.y = (viewport_size.y - image.size.y) * 0.5


func _start_pan(image: TextureRect) -> void:
	var existing_pan: Tween = _pan_tweens.get(image) as Tween
	if existing_pan != null:
		existing_pan.kill()

	var start_x: float = size.x - image.size.x
	var end_x: float = 0.0

	image.position.x = start_x

	var pan: Tween = create_tween()
	pan.tween_property(image, "position:x", end_x, PAN_DURATION)
	_pan_tweens[image] = pan


func _uses_glitch_transition(previous_index: int, next_index: int) -> bool:
	return previous_index % 2 == 0 and next_index == previous_index + 1


func _play_fade_transition() -> void:
	var fade: Tween = create_tween()
	fade.set_parallel(true)
	fade.tween_property(_active_image, "modulate:a", 0.0, FADE_DURATION)
	fade.tween_property(_inactive_image, "modulate:a", 1.0, FADE_DURATION)
	await fade.finished


func _play_glitch_transition() -> void:
	var active_pan: Tween = _pan_tweens.get(_active_image) as Tween
	var inactive_pan: Tween = _pan_tweens.get(_inactive_image) as Tween
	if active_pan != null:
		active_pan.kill()
	if inactive_pan != null:
		inactive_pan.kill()

	var active_position: Vector2 = _active_image.position
	var inactive_position: Vector2 = _inactive_image.position
	var step_time: float = GLITCH_DURATION / float(GLITCH_STEPS)

	for step: int in range(GLITCH_STEPS):
		var show_burned: bool = step % 2 == 0 or step >= GLITCH_STEPS - 3
		var jitter: Vector2 = Vector2(
			randf_range(-GLITCH_JITTER_X, GLITCH_JITTER_X),
			randf_range(-GLITCH_JITTER_Y, GLITCH_JITTER_Y)
		)

		_active_image.modulate = Color(1.0, 0.9, 0.9, 0.0 if show_burned else 1.0)
		_inactive_image.modulate = Color(0.85, 1.0, 1.0, 1.0 if show_burned else 0.0)
		_active_image.position = active_position - jitter * 0.35
		_inactive_image.position = inactive_position + jitter

		await get_tree().create_timer(step_time).timeout

	_active_image.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_inactive_image.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_active_image.position = active_position
	_inactive_image.position = inactive_position
	_start_pan(_inactive_image)
