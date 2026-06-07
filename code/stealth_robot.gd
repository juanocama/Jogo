extends CharacterBody2D

enum RobotState {
	INACTIVE,
	ENTERING,
	SEARCHING,
	CHASING,
	CONFUSED,
	TARGETING_BATHROOM,
	EXITING
}

@export var normal_speed: float = 115.0
@export var chase_speed: float = 185.0
@export var enter_target: Vector2 = Vector2(80, 495)
@export var exit_target: Vector2 = Vector2(-180, 495)
@export var vision_range: float = 440.0
@export var detection_interval: float = 2.0
@export var detection_probability: float = 0.45
@export var capture_distance: float = 35.0
@export var hidden_inspection_delay: float = 7.0
@export var confused_duration_multiplier: float = 0.45
@export var confused_speed_multiplier: float = 0.8
@export var close_visible_detection_range: float = 170.0
@export var frame_count: int = 6
@export var idle_fps: float = 7.0
@export var walk_fps: float = 10.0
@export var base_visual_scale: float = 0.88

const CONFUSED_DURATION_MULTIPLIER: float = 0.7

@export_group("Sprites")
@export var idle_down_texture: Texture2D
@export var idle_up_texture: Texture2D
@export var walk_down_texture: Texture2D
@export var walk_up_texture: Texture2D
@export var walk_side_texture: Texture2D

@export_group("Alerts")
@export var alert_exclamation_texture: Texture2D
@export var alert_question_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var alert_icon: Sprite2D = $AlertIcon
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var state: int = RobotState.INACTIVE
var player: Node2D
var level_controller: Node
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0
var detection_timer: float = 0.0
var confused_timer: float = 0.0
var target_spot: Area2D
var frame_time: float = 0.0
var current_frame: int = 0
var last_direction: StringName = &"down"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	visible = false
	if alert_icon != null:
		alert_icon.visible = false
	if collision_shape != null:
		collision_shape.disabled = true


func setup(controller: Node, player_node: Node2D, points: Array[Vector2]) -> void:
	level_controller = controller
	player = player_node
	patrol_points = points


func begin_entry() -> void:
	visible = true
	if collision_shape != null:
		collision_shape.disabled = false
	global_position = Vector2(-160, enter_target.y)
	state = RobotState.ENTERING
	_set_alert(null)


func start_exit() -> void:
	state = RobotState.EXITING
	target_spot = null
	_set_alert(null)


func notify_player_hidden(spot: Area2D) -> void:
	if state == RobotState.INACTIVE or state == RobotState.EXITING:
		return

	target_spot = spot
	state = RobotState.CONFUSED
	confused_timer = hidden_inspection_delay * confused_duration_multiplier
	if alert_question_texture != null:
		_set_alert(alert_question_texture)


func _physics_process(delta: float) -> void:
	if state == RobotState.INACTIVE:
		return

	match state:
		RobotState.ENTERING:
			_move_towards(enter_target, normal_speed, delta)
			if global_position.distance_to(enter_target) <= 8.0:
				state = RobotState.SEARCHING
				detection_timer = detection_interval
		RobotState.SEARCHING:
			_update_search(delta)
		RobotState.CHASING:
			_update_chase(delta)
		RobotState.CONFUSED:
			_update_confused(delta)
		RobotState.TARGETING_BATHROOM:
			_update_targeting_bathroom(delta)
		RobotState.EXITING:
			_move_towards(exit_target, normal_speed, delta)
			if global_position.x <= exit_target.x + 4.0:
				state = RobotState.INACTIVE
				visible = false
				if level_controller != null and level_controller.has_method("complete_victory"):
					level_controller.call("complete_victory")

	_check_touch_capture()


func _update_search(delta: float) -> void:
	_move_along_patrol(delta, normal_speed)
	_update_detection(delta)


func _move_along_patrol(delta: float, speed: float) -> void:
	if patrol_points.is_empty():
		_apply_animation(delta, Vector2.ZERO)
		return

	var target: Vector2 = patrol_points[patrol_index]
	_move_towards(target, speed, delta)
	if global_position.distance_to(target) <= 10.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()


func _update_detection(delta: float) -> void:
	detection_timer -= delta
	if detection_timer > 0.0:
		return
	detection_timer = detection_interval

	if player == null:
		return
	if player.has_method("is_hidden") and bool(player.call("is_hidden")):
		return
	var distance_to_player: float = global_position.distance_to(player.global_position)
	if distance_to_player > vision_range:
		return
	if distance_to_player > close_visible_detection_range and rng.randf() > detection_probability:
		return

	state = RobotState.CHASING
	_set_alert(alert_exclamation_texture)


func _update_chase(delta: float) -> void:
	if player == null:
		return
	if player.has_method("is_hidden") and bool(player.call("is_hidden")):
		if level_controller != null and level_controller.has_method("get_current_hidden_spot"):
			var hidden_spot: Area2D = level_controller.call("get_current_hidden_spot") as Area2D
			notify_player_hidden(hidden_spot)
		return

	_move_towards(player.global_position, chase_speed, delta)


func _update_confused(delta: float) -> void:
	_move_along_patrol(delta, normal_speed * confused_speed_multiplier)
	if player != null and player.has_method("is_hidden") and not bool(player.call("is_hidden")):
		target_spot = null
		state = RobotState.CHASING
		_set_alert(alert_exclamation_texture)
		return

	confused_timer -= delta
	if confused_timer > 0.0:
		return

	if target_spot != null:
		if target_spot.has_method("set_targeted"):
			target_spot.call("set_targeted", true)
		state = RobotState.TARGETING_BATHROOM
	else:
		state = RobotState.SEARCHING
		_set_alert(null)


func _update_targeting_bathroom(delta: float) -> void:
	if target_spot == null:
		state = RobotState.SEARCHING
		_set_alert(null)
		return
	if player != null and player.has_method("is_hidden") and not bool(player.call("is_hidden")):
		if target_spot.has_method("set_targeted"):
			target_spot.call("set_targeted", false)
		target_spot = null
		state = RobotState.SEARCHING
		_set_alert(null)
		return

	var inspection_position: Vector2 = target_spot.global_position + Vector2(0.0, -45.0)
	_move_towards(inspection_position, chase_speed, delta)
	if global_position.distance_to(inspection_position) <= capture_distance:
		if player != null and player.has_method("is_hidden") and bool(player.call("is_hidden")):
			if level_controller != null and level_controller.has_method("defeat"):
				level_controller.call("defeat")
		else:
			if target_spot.has_method("set_targeted"):
				target_spot.call("set_targeted", false)
			target_spot = null
			state = RobotState.SEARCHING
			_set_alert(null)


func _move_towards(target: Vector2, speed: float, delta: float) -> void:
	var direction: Vector2 = target - global_position
	if direction.length() <= 1.0:
		velocity = Vector2.ZERO
	else:
		velocity = direction.normalized() * speed
	move_and_slide()
	_apply_animation(delta, velocity)


func _check_touch_capture() -> void:
	if state == RobotState.INACTIVE or state == RobotState.EXITING or state == RobotState.CONFUSED:
	if state == RobotState.INACTIVE or state == RobotState.EXITING or state == RobotState.CONFUSED:
		return
	if player == null:
		return
	if player.has_method("is_hidden") and bool(player.call("is_hidden")):
		return
	if global_position.distance_to(player.global_position) > capture_distance:
		return
	if level_controller != null and level_controller.has_method("defeat"):
		level_controller.call("defeat")


func _apply_animation(delta: float, movement: Vector2) -> void:
	var moving: bool = movement.length_squared() > 1.0
	var texture: Texture2D = idle_down_texture
	var direction_name: StringName = last_direction
	if moving:
		if absf(movement.x) > absf(movement.y):
			direction_name = &"side"
		else:
			direction_name = &"up" if movement.y < 0.0 else &"down"
		last_direction = direction_name
		match direction_name:
			&"up":
				texture = walk_up_texture
			&"side":
				texture = walk_side_texture if walk_side_texture != null else walk_down_texture
			_:
				texture = walk_down_texture
	else:
		texture = idle_up_texture if direction_name == &"up" else idle_down_texture

	if sprite != null and texture != null:
		sprite.texture = texture
		sprite.hframes = maxi(frame_count, 1)
		sprite.scale = Vector2(base_visual_scale, base_visual_scale)
		sprite.flip_h = direction_name == &"side" and movement.x < 0.0
		frame_time += delta
		var fps: float = walk_fps if moving else idle_fps
		if frame_time >= 1.0 / fps:
			frame_time = 0.0
			current_frame = (current_frame + 1) % maxi(frame_count, 1)
		sprite.frame = current_frame

	z_index = int(global_position.y)


func _set_alert(texture: Texture2D) -> void:
	if alert_icon == null:
		return
	alert_icon.texture = texture
	alert_icon.visible = texture != null
