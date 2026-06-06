extends CharacterBody2D

@export var walk_speed: float = 145.0
@export var run_speed: float = 215.0
@export var vertical_depth_scale: float = 0.72

@export_group("Down")
@export var idle_down_texture: Texture2D
@export var walk_down_texture: Texture2D
@export var run_down_texture: Texture2D

@export_group("Up")
@export var idle_up_texture: Texture2D
@export var walk_up_texture: Texture2D
@export var run_up_texture: Texture2D

@export_group("Side")
@export var idle_side_texture: Texture2D
@export var walk_side_texture: Texture2D
@export var run_side_texture: Texture2D

@export_group("Animation")
@export var frame_count: int = 6
@export var idle_fps: float = 7.0
@export var walk_fps: float = 10.0
@export var run_fps: float = 14.0
@export var side_move_scale_multiplier: float = 1.2

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Polygon2D = $Shadow
@onready var camera: Camera2D = $Camera2D

var frame_time: float = 0.0
var current_frame: int = 0
var last_facing: int = 1
var last_direction: StringName = &"down"
var current_animation_key: StringName = &""


func _ready() -> void:
	add_to_group("players")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if camera != null:
		camera.make_current()
	_apply_visual_state(Vector2.ZERO, false)


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = _get_input_vector()
	var is_running: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = run_speed if is_running else walk_speed

	velocity = Vector2(input_vector.x, input_vector.y * vertical_depth_scale) * speed
	move_and_slide()

	if input_vector.x != 0.0:
		last_facing = -1 if input_vector.x < 0.0 else 1
	if input_vector.length_squared() > 0.0:
		last_direction = _get_direction_name(input_vector)

	_update_animation(delta, input_vector, is_running)
	_update_depth_visuals()


func _get_input_vector() -> Vector2:
	var direction: Vector2 = Vector2.ZERO

	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	return direction.normalized()


func _update_animation(delta: float, input_vector: Vector2, is_running: bool) -> void:
	var moving: bool = input_vector.length_squared() > 0.0
	var fps: float = idle_fps
	if moving:
		fps = run_fps if is_running else walk_fps

	var direction_name: StringName = _get_direction_name(input_vector) if moving else last_direction
	var animation_key: StringName = _get_animation_key(moving, is_running, direction_name)
	var active_frame_count: int = _get_frame_count_for_animation(animation_key)
	if animation_key != current_animation_key:
		current_animation_key = animation_key
		current_frame = 0
		frame_time = 0.0
		_apply_visual_state(input_vector, is_running)
		return

	frame_time += delta
	if frame_time >= 1.0 / fps:
		frame_time = 0.0
		current_frame = (current_frame + 1) % active_frame_count
		_apply_visual_state(input_vector, is_running)


func _apply_visual_state(input_vector: Vector2, is_running: bool) -> void:
	var moving: bool = input_vector.length_squared() > 0.0
	var direction_name: StringName = _get_direction_name(input_vector) if moving else last_direction
	var animation_key: StringName = _get_animation_key(moving, is_running, direction_name)
	var active_frame_count: int = _get_frame_count_for_animation(animation_key)
	var next_texture: Texture2D = _get_texture_for_state(moving, is_running, direction_name)

	if next_texture != null:
		sprite.texture = next_texture

	sprite.hframes = active_frame_count
	sprite.frame = mini(current_frame, active_frame_count - 1)
	sprite.flip_h = direction_name == &"side" and last_facing < 0


func _get_animation_key(moving: bool, is_running: bool, direction_name: StringName) -> StringName:
	var state_name: StringName = &"idle"
	if moving:
		state_name = &"run" if is_running else &"walk"
	return StringName("%s_%s" % [state_name, direction_name])


func _get_frame_count_for_animation(animation_key: StringName) -> int:
	match animation_key:
		&"idle_down":
			return 1
		&"idle_up":
			return 3
		&"walk_down":
			return 3
		_:
			return maxi(frame_count, 1)


func _get_direction_name(input_vector: Vector2) -> StringName:
	if input_vector.x != 0.0:
		return &"side"
	if input_vector.y != 0.0:
		return &"up" if input_vector.y < 0.0 else &"down"
	return last_direction


func _get_texture_for_state(moving: bool, is_running: bool, direction_name: StringName) -> Texture2D:
	match direction_name:
		&"up":
			if moving and is_running and run_up_texture:
				return run_up_texture
			if moving and walk_up_texture:
				return walk_up_texture
			return idle_up_texture
		&"side":
			if moving and is_running and run_side_texture:
				return run_side_texture
			if moving and walk_side_texture:
				return walk_side_texture
			return idle_side_texture
		_:
			if moving and is_running and run_down_texture:
				return run_down_texture
			if moving and walk_down_texture:
				return walk_down_texture
			return idle_down_texture


func _update_depth_visuals() -> void:
	z_index = int(global_position.y)

	var depth_factor: float = clampf((global_position.y + 180.0) / 420.0, 0.0, 1.0)
	var visual_scale: float = lerpf(0.86, 1.08, depth_factor)
	if current_animation_key == &"walk_side" or current_animation_key == &"run_side":
		visual_scale *= side_move_scale_multiplier
	sprite.scale = Vector2(0.27, 0.27) * visual_scale

	if shadow != null:
		shadow.scale = Vector2(1.0, 0.72) * visual_scale
		var shadow_color: Color = shadow.modulate
		shadow_color.a = lerpf(0.22, 0.36, depth_factor)
		shadow.modulate = shadow_color


func is_alive() -> bool:
	return true
