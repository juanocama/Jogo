extends CharacterBody2D

@export var move_speed: float = 120.0
@export var base_visual_scale: float = 0.54
@export var frame_count: int = 6
@export var movement_frame_count: int = 2
@export var fps: float = 10.0

@export_group("Down")
@export var idle_down_texture: Texture2D
@export var walk_down_texture: Texture2D

@export_group("Up")
@export var idle_up_texture: Texture2D
@export var walk_up_texture: Texture2D

@export_group("Side")
@export var idle_side_texture: Texture2D
@export var walk_side_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Polygon2D = $Shadow

var frame_time: float = 0.0
var current_frame: int = 0
var last_direction: StringName = &"down"
var facing_sign: int = 1


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_apply_visual(Vector2.ZERO)


func face_towards(target_position: Vector2) -> void:
	var direction: Vector2 = target_position - global_position
	last_direction = _direction_name(direction)
	if direction.x != 0.0:
		facing_sign = -1 if direction.x < 0.0 else 1
	_apply_visual(Vector2.ZERO)


func move_to(target_position: Vector2) -> void:
	while global_position.distance_to(target_position) > 6.0:
		var direction: Vector2 = (target_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		_apply_visual(velocity)
		await get_tree().physics_frame

	velocity = Vector2.ZERO
	_apply_visual(Vector2.ZERO)


func move_to_with_camera(target_position: Vector2, camera: Camera2D) -> void:
	while global_position.distance_to(target_position) > 6.0:
		var direction: Vector2 = (target_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		_apply_visual(velocity)
		if camera != null:
			camera.global_position = global_position
		await get_tree().physics_frame

	velocity = Vector2.ZERO
	_apply_visual(Vector2.ZERO)
	if camera != null:
		camera.global_position = global_position


func _apply_visual(movement: Vector2) -> void:
	var moving: bool = movement.length_squared() > 1.0
	var direction_name: StringName = last_direction
	if moving:
		direction_name = _direction_name(movement)
		last_direction = direction_name
		if movement.x != 0.0:
			facing_sign = -1 if movement.x < 0.0 else 1

	var next_texture: Texture2D = _texture_for(direction_name, moving)
	if sprite != null and next_texture != null:
		sprite.texture = next_texture
		sprite.hframes = maxi(frame_count, 1)
		sprite.scale = Vector2(base_visual_scale, base_visual_scale)
		sprite.flip_h = direction_name == &"side" and facing_sign < 0

		frame_time += get_process_delta_time()
		if moving and frame_time >= 1.0 / fps:
			frame_time = 0.0
			current_frame = (current_frame + 1) % clampi(movement_frame_count, 1, maxi(frame_count, 1))
		elif not moving:
			current_frame = 0
		sprite.frame = current_frame

	if shadow != null:
		shadow.scale = Vector2(1.0, 0.72)
	z_index = int(global_position.y)


func _direction_name(vector: Vector2) -> StringName:
	if absf(vector.x) > absf(vector.y):
		return &"side"
	if vector.y < 0.0:
		return &"up"
	return &"down"


func _texture_for(direction_name: StringName, moving: bool) -> Texture2D:
	match direction_name:
		&"up":
			return walk_up_texture if moving and walk_up_texture != null else idle_up_texture
		&"side":
			return walk_side_texture if moving and walk_side_texture != null else idle_side_texture
		_:
			return walk_down_texture if moving and walk_down_texture != null else idle_down_texture
