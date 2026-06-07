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
	call_deferred("_run_background_loop")


func _run_background_loop() -> void:
	_show_texture(_active_image, BACKGROUND_TEXTURES[_current_index])
	_active_image.modulate.a = 1.0
	_start_pan(_active_image)

	while is_inside_tree():
		await get_tree().create_timer(PAN_DURATION - FADE_DURATION).timeout
		_current_index = (_current_index + 1) % BACKGROUND_TEXTURES.size()

		_show_texture(_inactive_image, BACKGROUND_TEXTURES[_current_index])
		_inactive_image.modulate.a = 0.0
		_start_pan(_inactive_image)

		var fade: Tween = create_tween()
		fade.set_parallel(true)
		fade.tween_property(_active_image, "modulate:a", 0.0, FADE_DURATION)
		fade.tween_property(_inactive_image, "modulate:a", 1.0, FADE_DURATION)
		await fade.finished

		var previous_image: TextureRect = _active_image
		_active_image = _inactive_image
		_inactive_image = previous_image


func _update_background_size() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

	if image_a.texture != null:
		_fit_image(image_a)
	if image_b.texture != null:
		_fit_image(image_b)


func _show_texture(image: TextureRect, texture: Texture2D) -> void:
	image.texture = texture
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
