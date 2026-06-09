extends Node2D

@export var camera_path: NodePath = NodePath("Player/Camera2D")
@export var player_path: NodePath = NodePath("Player")
@export var girl_path: NodePath = NodePath("Player/Girl")
@export var intro_background_path: NodePath = NodePath("IntroBackgroundLayer/Background")

@export var opening_camera_position: Vector2 = Vector2(520.0, 96.0)
@export var bench_camera_position: Vector2 = Vector2(-192.0, 96.0)
@export var leaves_camera_position: Vector2 = Vector2(-560.0, -150.0)
@export var normal_zoom: Vector2 = Vector2(0.72, 0.72)
@export var leaves_zoom: Vector2 = Vector2(1.12, 1.12)

@export var opening_pan_duration: float = 4.0
@export var girl_wait_duration: float = 0.0
@export var girl_fade_duration: float = 1.2
@export var leaves_focus_duration: float = 5.0
@export var intro_fade_duration: float = 1.4

@onready var camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var player: Node = get_node_or_null(player_path)
@onready var girl: Node2D = get_node_or_null(girl_path) as Node2D
@onready var intro_background: Control = get_node_or_null(intro_background_path) as Control

var _idle_loop_running: bool = false


func _ready() -> void:
	_prepare_cutscene()
	call_deferred("_run_cutscene")


func _prepare_cutscene() -> void:
	GameManager.is_dialogue_active = true

	if girl != null:
		girl.visible = true
		girl.modulate.a = 0.0
		_set_girl_idle_down()

	if camera != null:
		camera.enabled = true
		camera.top_level = true
		camera.global_position = opening_camera_position
		camera.zoom = normal_zoom
		camera.make_current()

	if intro_background != null:
		intro_background.visible = false
		intro_background.modulate.a = 0.0

	_idle_loop_running = true
	_loop_idle_frames()


func _run_cutscene() -> void:
	await _tween_camera(opening_camera_position, bench_camera_position, normal_zoom, opening_pan_duration)
	await get_tree().create_timer(girl_wait_duration).timeout
	await _fade_in_girl()
	await _tween_camera(bench_camera_position, leaves_camera_position, leaves_zoom, leaves_focus_duration)
	await _show_intro_background()
	GameManager.is_dialogue_active = false


func _tween_camera(from_position: Vector2, to_position: Vector2, to_zoom: Vector2, duration: float) -> void:
	if camera == null:
		await get_tree().create_timer(duration).timeout
		return

	camera.global_position = from_position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", to_position, duration)
	tween.tween_property(camera, "zoom", to_zoom, duration)
	await tween.finished


func _fade_in_girl() -> void:
	if girl == null:
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(girl, "modulate:a", 1.0, girl_fade_duration)
	await tween.finished


func _show_intro_background() -> void:
	if intro_background == null:
		return

	intro_background.visible = true
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(intro_background, "modulate:a", 1.0, intro_fade_duration)
	await tween.finished


func _loop_idle_frames() -> void:
	while _idle_loop_running and is_inside_tree():
		_advance_idle_sprite(player)
		_advance_idle_sprite(girl)
		await get_tree().create_timer(0.16).timeout


func _advance_idle_sprite(character: Node) -> void:
	if character == null:
		return

	var sprite: Sprite2D = character.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.hframes <= 1:
		return

	sprite.frame = (sprite.frame + 1) % sprite.hframes


func _set_girl_idle_down() -> void:
	if girl == null:
		return

	girl.set("last_direction", &"down")

	var sprite: Sprite2D = girl.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var idle_down_texture: Texture2D = girl.get("idle_down_texture") as Texture2D
	if idle_down_texture != null:
		sprite.texture = idle_down_texture
	sprite.hframes = int(girl.get("frame_count"))
	sprite.frame = 0
	sprite.flip_h = false
