extends CharacterBody2D

# Movimiento simple para probar el escenario.
# Sin vida, sin daño y sin combate por ahora.

const SPEED: float = 210.0
const JUMP_VELOCITY: float = -600.0
const GRAVITY: float = 980.0
const NORMAL_SPRITE_SCALE: Vector2 = Vector2(0.576, 0.576)
const AIR_SPRITE_SCALE: Vector2 = NORMAL_SPRITE_SCALE * 1.3
const ATTACK_SPRITE_SCALE: Vector2 = NORMAL_SPRITE_SCALE * 1.6
const DASH_SPRITE_SCALE: Vector2 = NORMAL_SPRITE_SCALE * 1.3
const DASH_SPEED: float = 520.0
const DASH_DURATION: float = 0.24
const DASH_IMPULSE_DISTANCE: float = 22.0
const DASH_DOUBLE_TAP_WINDOW: float = 0.28
const ROD_ATTACK_DURATION: float = 0.34
const ROD_ATTACK_DAMAGE_PERCENT: float = 0.06
const ROD_ATTACK_COOLDOWN: float = 0.55
const ROD_ATTACK_RANGE: float = 120.0
const ROD_ATTACK_HEIGHT: float = 90.0
const WATER_ATTACK_DURATION: float = 0.28
const WATER_PROJECTILE_DAMAGE_PERCENT: float = 0.02
const WATER_ATTACK_COOLDOWN: float = 0.5
const WATER_PROJECTILE_OFFSET: Vector2 = Vector2(84.0, -52.0)
const WATER_PROJECTILE_SCENE: PackedScene = preload("res://scenes/player_water_projectile.tscn")
const MAX_HEARTS: int = 5
const DAMAGE_INVULNERABILITY_TIME: float = 0.9
const HEART_FULL: String = "\u2665"
const HEART_EMPTY: String = "\u2661"

@export var sprite_scale_multiplier: float = 1.0

@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var sprite2D: Sprite2D = $Sprite2D
@onready var camera2D: Camera2D = $Camera2D
@onready var hearts_label: Label = get_node_or_null("../HUD/HeartsLabel") as Label

var jump_was_pressed: bool = false
var requested_animation: StringName = &""
var facing_direction: int = 1
var hearts: int = MAX_HEARTS
var damage_invulnerability_timer: float = 0.0
var dash_timer: float = 0.0
var attack_timer: float = 0.0
var rod_attack_cooldown_timer: float = 0.0
var water_attack_cooldown_timer: float = 0.0
var entropy_delay_timer: float = 0.0
var entropy_delay_seconds: float = 0.0
var entropy_invert_timer: float = 0.0
var delayed_input_queue: Array[Dictionary] = []
var current_input_sample: Dictionary = {}
var last_left_tap_time: float = -10.0
var last_right_tap_time: float = -10.0
var previous_left_pressed: bool = false
var previous_right_pressed: bool = false
var previous_left_mouse_pressed: bool = false
var previous_right_mouse_pressed: bool = false
var water_shot_spawned: bool = false
var rod_hit_done: bool = false
var active_attack_animation: StringName = &""


func _ready() -> void:
	# Los robots buscan nodos en el grupo "players".
	# Esto NO agrega vida ni daño; solo permite que sepan a quién seguir.
	add_to_group("players")

	if camera2D and camera2D.enabled:
		camera2D.make_current()

	current_input_sample = _read_raw_input_sample()
	_update_hearts_ui()
	_play_animation("idle")


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_entropy_timers(delta)
	_update_effective_input(delta)
	_update_action_timers(delta)
	_handle_dash_input()
	_handle_attack_input()

	if _is_action_locked():
		_handle_locked_movement(delta)
	else:
		_handle_jump()
		_handle_horizontal_movement()

	move_and_slide()
	_update_animation()
	global_position = global_position.round()


func _update_action_timers(delta: float) -> void:
	if damage_invulnerability_timer > 0.0:
		damage_invulnerability_timer -= delta
	if rod_attack_cooldown_timer > 0.0:
		rod_attack_cooldown_timer -= delta
	if water_attack_cooldown_timer > 0.0:
		water_attack_cooldown_timer -= delta

	if dash_timer > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			dash_timer = 0.0

	if attack_timer > 0.0:
		attack_timer -= delta
		if active_attack_animation == &"RodAttack" and not rod_hit_done:
			var rod_elapsed: float = ROD_ATTACK_DURATION - attack_timer
			if rod_elapsed >= 0.16:
				rod_hit_done = true
				_damage_bosses_with_rod()
		if active_attack_animation == &"WaterAttack" and not water_shot_spawned:
			var elapsed: float = WATER_ATTACK_DURATION - attack_timer
			if elapsed >= 0.18:
				water_shot_spawned = true
				_spawn_water_projectile()
		if attack_timer <= 0.0:
			attack_timer = 0.0
			active_attack_animation = &""
			water_shot_spawned = false
			rod_hit_done = false


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_jump() -> void:
	var jump_pressed: bool = _is_jump_pressed()
	var jump_just_pressed: bool = jump_pressed and not jump_was_pressed
	jump_was_pressed = jump_pressed

	if jump_just_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY


func _handle_dash_input() -> void:
	if attack_timer > 0.0 or dash_timer > 0.0:
		_update_previous_dash_inputs()
		return

	var left_pressed: bool = _is_left_pressed()
	var right_pressed: bool = _is_right_pressed()
	var now_seconds: float = Time.get_ticks_msec() / 1000.0

	if left_pressed and not previous_left_pressed:
		if now_seconds - last_left_tap_time <= DASH_DOUBLE_TAP_WINDOW:
			_start_dash(-1)
			last_left_tap_time = -10.0
		else:
			last_left_tap_time = now_seconds

	if right_pressed and not previous_right_pressed:
		if now_seconds - last_right_tap_time <= DASH_DOUBLE_TAP_WINDOW:
			_start_dash(1)
			last_right_tap_time = -10.0
		else:
			last_right_tap_time = now_seconds

	previous_left_pressed = left_pressed
	previous_right_pressed = right_pressed


func _handle_attack_input() -> void:
	var left_mouse_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_mouse_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var left_mouse_just_pressed: bool = left_mouse_pressed and not previous_left_mouse_pressed
	var right_mouse_just_pressed: bool = right_mouse_pressed and not previous_right_mouse_pressed

	previous_left_mouse_pressed = left_mouse_pressed
	previous_right_mouse_pressed = right_mouse_pressed

	if dash_timer > 0.0 or attack_timer > 0.0:
		return

	if left_mouse_just_pressed and rod_attack_cooldown_timer <= 0.0:
		_play_sfx(&"player_melee")
		_start_attack(&"RodAttack", ROD_ATTACK_DURATION)
		rod_attack_cooldown_timer = ROD_ATTACK_COOLDOWN
	elif right_mouse_just_pressed and water_attack_cooldown_timer <= 0.0:
		_play_sfx(&"player_water")
		_start_attack(&"WaterAttack", WATER_ATTACK_DURATION)
		water_attack_cooldown_timer = WATER_ATTACK_COOLDOWN


func _handle_horizontal_movement() -> void:
	var direction: float = _get_horizontal_direction()

	if direction != 0.0:
		facing_direction = -1 if direction < 0.0 else 1
		velocity.x = direction * SPEED
		if sprite2D:
			sprite2D.flip_h = facing_direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)


func _get_horizontal_direction() -> float:
	var direction: float = 0.0

	if _is_left_pressed():
		direction -= 1.0
	if _is_right_pressed():
		direction += 1.0

	return clamp(direction, -1.0, 1.0)


func _is_left_pressed() -> bool:
	return bool(current_input_sample.get("right", false)) if entropy_invert_timer > 0.0 else bool(current_input_sample.get("left", false))


func _is_right_pressed() -> bool:
	return bool(current_input_sample.get("left", false)) if entropy_invert_timer > 0.0 else bool(current_input_sample.get("right", false))


func _is_jump_pressed() -> bool:
	return bool(current_input_sample.get("jump", false))


func _update_entropy_timers(delta: float) -> void:
	if entropy_delay_timer > 0.0:
		entropy_delay_timer -= delta
		if entropy_delay_timer <= 0.0:
			entropy_delay_timer = 0.0
			entropy_delay_seconds = 0.0
			delayed_input_queue.clear()
	if entropy_invert_timer > 0.0:
		entropy_invert_timer -= delta
		if entropy_invert_timer <= 0.0:
			entropy_invert_timer = 0.0


func _update_effective_input(delta: float) -> void:
	var raw_sample: Dictionary = _read_raw_input_sample()
	if entropy_delay_timer <= 0.0 or entropy_delay_seconds <= 0.0:
		current_input_sample = raw_sample
		return

	delayed_input_queue.append({
		"time": entropy_delay_seconds,
		"sample": raw_sample,
	})

	for index: int in range(delayed_input_queue.size()):
		var entry: Dictionary = delayed_input_queue[index]
		entry["time"] = float(entry["time"]) - delta
		delayed_input_queue[index] = entry

	while not delayed_input_queue.is_empty() and float(delayed_input_queue[0]["time"]) <= 0.0:
		var ready_entry: Dictionary = delayed_input_queue.pop_front()
		current_input_sample = ready_entry["sample"] as Dictionary


func _read_raw_input_sample() -> Dictionary:
	return {
		"left": Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A),
		"right": Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D),
		"jump": Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W),
	}


func apply_entropy_delay(duration: float, delay_seconds: float) -> void:
	entropy_delay_timer = max(entropy_delay_timer, duration)
	entropy_delay_seconds = delay_seconds
	delayed_input_queue.clear()
	current_input_sample = _read_raw_input_sample()


func apply_entropy_invert(duration: float) -> void:
	entropy_invert_timer = max(entropy_invert_timer, duration)


func _update_animation() -> void:
	if not animationPlayer:
		return

	if dash_timer > 0.0:
		_set_sprite_scale(DASH_SPRITE_SCALE * sprite_scale_multiplier)
		_play_animation("Dash")
		return

	if attack_timer > 0.0:
		_set_sprite_scale(ATTACK_SPRITE_SCALE * sprite_scale_multiplier)
		_play_animation(active_attack_animation)
		return

	if not is_on_floor():
		_set_sprite_scale(AIR_SPRITE_SCALE * sprite_scale_multiplier)
		if velocity.y < 0.0:
			_play_animation("Jump")
		else:
			_play_animation("Fall")
		return

	_set_sprite_scale(NORMAL_SPRITE_SCALE * sprite_scale_multiplier)
	if abs(velocity.x) > 1.0:
		_play_animation("Run")
	else:
		_play_animation("idle")


func _play_animation(animation_name: StringName) -> void:
	if not animationPlayer:
		return
	if not animationPlayer.has_animation(animation_name):
		return
	if requested_animation == animation_name:
		return

	requested_animation = animation_name
	animationPlayer.play(animation_name)


func _set_sprite_scale(target_scale: Vector2) -> void:
	if sprite2D == null:
		return
	if sprite2D.scale != target_scale:
		sprite2D.scale = target_scale


func _is_action_locked() -> bool:
	return dash_timer > 0.0 or attack_timer > 0.0


func _handle_locked_movement(delta: float) -> void:
	if dash_timer > 0.0:
		velocity.x = facing_direction * DASH_SPEED
		return

	velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 8.0)


func _start_dash(direction: int) -> void:
	facing_direction = direction
	dash_timer = DASH_DURATION
	velocity.x = facing_direction * DASH_SPEED
	global_position.x += float(facing_direction) * DASH_IMPULSE_DISTANCE
	if sprite2D:
		sprite2D.flip_h = facing_direction < 0
	_play_animation("Dash")


func _start_attack(animation_name: StringName, duration: float) -> void:
	active_attack_animation = animation_name
	attack_timer = duration
	water_shot_spawned = false
	rod_hit_done = false
	velocity.x = 0.0
	_play_animation(animation_name)
	if animation_name == &"WaterAttack":
		_spawn_water_projectile()
		water_shot_spawned = true
	_set_sprite_scale(ATTACK_SPRITE_SCALE * sprite_scale_multiplier)


func _spawn_water_projectile() -> void:
	if WATER_PROJECTILE_SCENE == null:
		return

	var projectile: Node = WATER_PROJECTILE_SCENE.instantiate()
	if projectile.has_method("setup"):
		projectile.call("setup", Vector2(float(facing_direction), 0.0), WATER_PROJECTILE_DAMAGE_PERCENT)

	var projectile_parent: Node = get_parent()
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	projectile_parent.add_child(projectile)

	if projectile is Node2D:
		var offset: Vector2 = Vector2(WATER_PROJECTILE_OFFSET.x * facing_direction, WATER_PROJECTILE_OFFSET.y)
		(projectile as Node2D).global_position = (global_position + offset).round()


func _damage_bosses_with_rod() -> void:
	_destroy_robot_projectiles_with_rod()

	var bosses: Array[Node] = get_tree().get_nodes_in_group("bosses")
	for boss: Node in bosses:
		if not boss is Node2D:
			continue
		if not boss.has_method("take_damage"):
			continue

		var boss_2d: Node2D = boss as Node2D
		if _is_boss_in_rod_range(boss_2d):
			var max_health_value: int = int(boss.get("max_health"))
			var damage: int = maxi(1, int(round(float(max_health_value) * ROD_ATTACK_DAMAGE_PERCENT)))
			boss.call("take_damage", damage, self)


func _is_boss_in_rod_range(boss: Node2D) -> bool:
	var boss_rect: Rect2 = _get_boss_collision_rect(boss)
	if boss_rect.size == Vector2.ZERO:
		var to_boss: Vector2 = boss.global_position - global_position
		var in_front_fallback: bool = sign(to_boss.x) == facing_direction or abs(to_boss.x) < 8.0
		return in_front_fallback and abs(to_boss.x) <= ROD_ATTACK_RANGE and abs(to_boss.y) <= ROD_ATTACK_HEIGHT

	var closest_x: float = clampf(global_position.x, boss_rect.position.x, boss_rect.end.x)
	var closest_y: float = clampf(global_position.y, boss_rect.position.y, boss_rect.end.y)
	var to_body: Vector2 = Vector2(closest_x, closest_y) - global_position
	var in_front: bool = sign(to_body.x) == facing_direction or abs(to_body.x) < 16.0
	return in_front and abs(to_body.x) <= ROD_ATTACK_RANGE and abs(to_body.y) <= ROD_ATTACK_HEIGHT


func _get_boss_collision_rect(boss: Node2D) -> Rect2:
	var collision_shape: CollisionShape2D = boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return Rect2(boss.global_position, Vector2.ZERO)

	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	var half_size: Vector2 = rect_shape.size * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var min_point: Vector2 = collision_shape.global_transform * corners[0]
	var max_point: Vector2 = min_point
	for index: int in range(1, corners.size()):
		var global_corner: Vector2 = collision_shape.global_transform * corners[index]
		min_point.x = minf(min_point.x, global_corner.x)
		min_point.y = minf(min_point.y, global_corner.y)
		max_point.x = maxf(max_point.x, global_corner.x)
		max_point.y = maxf(max_point.y, global_corner.y)
	return Rect2(min_point, max_point - min_point)


func _update_previous_dash_inputs() -> void:
	previous_left_pressed = _is_left_pressed()
	previous_right_pressed = _is_right_pressed()


func _destroy_robot_projectiles_with_rod() -> void:
	var projectiles: Array[Node] = get_tree().get_nodes_in_group("robot_projectiles")
	for projectile: Node in projectiles:
		if not projectile is Node2D:
			continue

		var projectile_2d: Node2D = projectile as Node2D
		var to_projectile: Vector2 = projectile_2d.global_position - global_position
		var in_front: bool = sign(to_projectile.x) == facing_direction or abs(to_projectile.x) < 8.0
		if in_front and abs(to_projectile.x) <= ROD_ATTACK_RANGE and abs(to_projectile.y) <= ROD_ATTACK_HEIGHT:
			projectile.queue_free()


func take_damage(_amount: int, _source: Node = null) -> void:
	if damage_invulnerability_timer > 0.0:
		return

	hearts -= 1
	_play_sfx(&"player_hurt")
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY_TIME
	_update_hearts_ui()

	if hearts <= 0:
		_play_sfx(&"game_over")
		get_tree().reload_current_scene()


func _update_hearts_ui() -> void:
	if hearts_label == null:
		return

	var text_parts: Array[String] = []
	for index: int in range(MAX_HEARTS):
		text_parts.append(HEART_FULL if index < hearts else HEART_EMPTY)
	hearts_label.text = " ".join(text_parts)


func is_alive() -> bool:
	# Solo para compatibilidad con la IA de los robots.
	# No significa que el personaje tenga sistema de vida todavía.
	return hearts > 0


func _play_sfx(sfx_key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_key, volume_db, pitch_scale)
