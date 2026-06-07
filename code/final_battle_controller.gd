extends Node

const PHASE_ONE_END_PERCENT: float = 0.65
const PHASE_THREE_START_PERCENT: float = 0.30
const BOSS_ROLL_INTERVAL: float = 4.0
const PHASE_TWO_ROLL_INTERVAL: float = 2.55
const PHASE_THREE_ROLL_INTERVAL: float = 1.85
const CLOSE_MELEE_TIME: float = 2.0
const CLOSE_MELEE_DISTANCE: float = 150.0
const CLOSE_MELEE_HIT_DISTANCE: float = 215.0
const MELEE_PUSH_TARGET_X: float = -150.0
const MELEE_PUSH_DURATION: float = 0.22
const MINION_SPAWN_MIN_TIME: float = 8.0
const MINION_SPAWN_MAX_TIME: float = 12.0
const PHASE_TWO_MINION_SPAWN_MIN_TIME: float = 13.0
const PHASE_TWO_MINION_SPAWN_MAX_TIME: float = 20.0
const MAX_MINIONS: int = 3
const PHASE_TWO_MAX_MINIONS: int = 1
const ROBOT2_PHASE_ONE_HEALTH: int = 45
const ROBOT1_PHASE_ONE_HEALTH: int = 30
const MINION_DAMAGE_TAKEN_MULTIPLIER: float = 6.0
const FLOOR_Y: float = 188.0
const LASER_BASE_PREPARE_TIME: float = 0.85
const LASER_MIN_PREPARE_TIME: float = 0.28
const LASER_HOLD_TIME: float = 2.0
const LASER_ACTION_RECOVERY_TIME: float = 0.28
const LASER_HIT_HALF_WIDTH: float = 115.0
const LASER_FLOOR_Y: float = 125.0
const LASER_TOP_Y: float = -390.0
const LASER_GROUND_Y: float = 188.0
const SPECIAL_ENTROPY_COOLDOWN: float = 7.2
const AMBUSH_PHASE_TWO_CHANCE: float = 0.07
const AMBUSH_PHASE_THREE_CHANCE: float = 0.17
const AMBUSH_REACTION_TIME_PHASE_TWO: float = 0.72
const AMBUSH_REACTION_TIME_PHASE_THREE: float = 0.46
const AMBUSH_SIDE_OFFSET: float = 145.0
const AMBUSH_RETURN_FLASH_TIME: float = 0.16
const FIRE_ENTROPY_DURATION: float = 5.0
const FIRE_PHASE_TWO_CHANCE: float = 0.08
const FIRE_PHASE_THREE_CHANCE: float = 0.10
const FIRE_SPEED: float = 235.0
const FIRE_HIT_RADIUS: float = 68.0
const FIRE_LEFT_X: float = -940.0
const FIRE_RIGHT_X: float = 705.0
const FIRE_Y: float = 158.0

@export var boss_path: NodePath
@export var player_path: NodePath
@export var entropy_controller_path: NodePath
@export var boss_health_bar_path: NodePath
@export var boss_health_label_path: NodePath
@export var robot1_scene: PackedScene
@export var robot2_scene: PackedScene
@export var robot1_projectile_scene: PackedScene
@export var final_projectile_scene: PackedScene
@export var laser_texture: Texture2D
@export var warning_texture: Texture2D
@export var floor_flame_texture: Texture2D

var roll_timer: float = 1.2
var minion_timer: float = 4.0
var close_timer: float = 0.0
var action_locked: bool = false
var action_serial: int = 0
var current_action: StringName = &""
var last_phase: int = 1
var standard_boss_position: Vector2 = Vector2.ZERO
var dark_flash_layer: CanvasLayer = null
var dark_flash_rect: ColorRect = null
var fire_entropy_active: bool = false
var special_entropy_cooldown_timer: float = 0.0
var active_fire_flames: Array[Sprite2D] = []

@onready var boss: Node2D = get_node_or_null(boss_path) as Node2D
@onready var player: Node2D = get_node_or_null(player_path) as Node2D
@onready var entropy_controller: Node = get_node_or_null(entropy_controller_path)
@onready var boss_health_bar: ProgressBar = get_node_or_null(boss_health_bar_path) as ProgressBar
@onready var boss_health_label: Label = get_node_or_null(boss_health_label_path) as Label


func _ready() -> void:
	if boss != null:
		standard_boss_position = boss.global_position
	_configure_boss()
	_update_boss_health_ui()


func _process(delta: float) -> void:
	if boss == null or player == null:
		return
	if boss.has_method("is_alive") and not bool(boss.call("is_alive")):
		_update_boss_health_ui()
		return

	_update_boss_health_ui()
	_update_close_melee(delta)
	_update_special_entropy_cooldown(delta)

	_update_phase_transition()
	_update_minions(delta)
	_update_boss_roll(delta)


func _configure_boss() -> void:
	if boss == null:
		return
	boss.set("ai_enabled", false)
	boss.set("damage_taken_multiplier", 0.46)
	boss.set("hit_reaction_enabled", false)
	boss.set("speed", 0.0)
	boss.set("dash_speed", 0.0)
	boss.set("stop_distance", 9999.0)
	boss.set("melee_cooldown", 9999.0)
	boss.set("shoot_cooldown", 9999.0)
	boss.set("slam_cooldown", 9999.0)
	boss.set("melee_timer", 9999.0)
	boss.set("dash_timer", 9999.0)
	boss.set("shoot_timer", 9999.0)
	boss.set("slam_timer", 9999.0)


func _update_minions(delta: float) -> void:
	var phase: int = _get_phase()
	if phase >= 3:
		_clear_final_minions()
		return

	minion_timer -= delta
	if minion_timer > 0.0:
		return
	minion_timer = _get_minion_spawn_time(phase)

	var active_minion_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("final_minions"):
		if node != null and node.is_inside_tree() and (not node.has_method("is_alive") or bool(node.call("is_alive"))):
			active_minion_count += 1
	if active_minion_count >= _get_max_minions(phase):
		return

	if phase == 2 or randf() < 0.45:
		_spawn_robot1_minion()
	else:
		_spawn_robot2_minion()


func _get_minion_spawn_time(phase: int) -> float:
	if phase == 2:
		return randf_range(PHASE_TWO_MINION_SPAWN_MIN_TIME, PHASE_TWO_MINION_SPAWN_MAX_TIME)
	return randf_range(MINION_SPAWN_MIN_TIME, MINION_SPAWN_MAX_TIME)


func _get_max_minions(phase: int) -> int:
	if phase == 2:
		return PHASE_TWO_MAX_MINIONS
	return MAX_MINIONS


func _clear_final_minions() -> void:
	for node: Node in get_tree().get_nodes_in_group("final_minions"):
		if node != null and node.is_inside_tree():
			node.queue_free()


func _spawn_robot1_minion() -> void:
	if robot1_scene == null:
		return
	var minion: Node = robot1_scene.instantiate()
	minion.set("max_health", ROBOT1_PHASE_ONE_HEALTH)
	minion.set("damage_taken_multiplier", MINION_DAMAGE_TAKEN_MULTIPLIER)
	minion.set("damage_enabled", false)
	minion.set("fall_on_death", true)
	minion.set("remove_after_death_seconds", 0.8)
	minion.set("projectile_scene", robot1_projectile_scene)
	minion.set("shoot_range", 900.0)
	minion.set("shoot_cooldown", 2.2)
	minion.set("shoot_delay", 0.28)
	minion.set("dash_cooldown", 9999.0)
	_attach_minion_health_bar(minion, 44.0, -112.0)
	if minion is Node2D:
		var minion_2d: Node2D = minion as Node2D
		minion_2d.global_position = Vector2(randf_range(140.0, 540.0), randf_range(65.0, 145.0))
		minion_2d.scale *= 1.18
	get_tree().current_scene.add_child(minion)
	minion.add_to_group("final_minions")
	minion.set("health", ROBOT1_PHASE_ONE_HEALTH)
	_refresh_minion_health_bar(minion)


func _spawn_robot2_minion() -> void:
	if robot2_scene == null:
		return
	var minion: Node = robot2_scene.instantiate()
	minion.set("max_health", ROBOT2_PHASE_ONE_HEALTH)
	minion.set("damage_taken_multiplier", MINION_DAMAGE_TAKEN_MULTIPLIER)
	minion.set("damage_enabled", true)
	minion.set("remove_after_death_seconds", 0.8)
	minion.set("shoot_range", 620.0)
	minion.set("shoot_cooldown", 2.4)
	minion.set("slam_cooldown", 4.8)
	_attach_minion_health_bar(minion, 56.0, -132.0)
	if minion is Node2D:
		var minion_2d: Node2D = minion as Node2D
		minion_2d.global_position = Vector2(randf_range(260.0, 700.0), FLOOR_Y)
		minion_2d.scale *= 1.16
	get_tree().current_scene.add_child(minion)
	minion.add_to_group("final_minions")
	minion.set("health", ROBOT2_PHASE_ONE_HEALTH)
	_refresh_minion_health_bar(minion)


func _attach_minion_health_bar(minion: Node, half_width: float, y_offset: float) -> void:
	if minion.get_node_or_null("HealthBar") != null:
		return
	var health_bar: ProgressBar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.offset_left = -half_width
	health_bar.offset_top = y_offset
	health_bar.offset_right = half_width
	health_bar.offset_bottom = y_offset + 9.0
	health_bar.max_value = float(minion.get("max_health"))
	health_bar.value = float(minion.get("max_health"))
	health_bar.show_percentage = false
	health_bar.modulate = Color(1.0, 0.18, 0.12, 1.0)
	minion.add_child(health_bar)


func _refresh_minion_health_bar(minion: Node) -> void:
	var health_bar: ProgressBar = minion.get_node_or_null("HealthBar") as ProgressBar
	if health_bar == null:
		return
	health_bar.max_value = float(minion.get("max_health"))
	health_bar.value = float(minion.get("health"))


func _update_close_melee(delta: float) -> void:
	if current_action == &"melee" or current_action == &"ambush":
		close_timer = 0.0
		return

	if _is_player_near_boss_body(CLOSE_MELEE_DISTANCE):
		close_timer += delta
	else:
		close_timer = 0.0

	if close_timer >= CLOSE_MELEE_TIME and current_action != &"melee":
		close_timer = 0.0
		_start_boss_melee()


func _update_special_entropy_cooldown(delta: float) -> void:
	if special_entropy_cooldown_timer > 0.0:
		special_entropy_cooldown_timer = maxf(0.0, special_entropy_cooldown_timer - delta)


func _update_boss_roll(delta: float) -> void:
	if action_locked:
		return
	roll_timer -= delta
	if roll_timer > 0.0:
		return
	var phase: int = _get_phase()
	roll_timer = _get_boss_roll_interval(phase)

	var roll: float = randf()
	if phase == 1:
		if roll < 0.4:
			_play_boss_animation(&"idle")
		elif roll < 0.8:
			_start_boss_stomp()
		else:
			_start_boss_shot(1)
	elif phase == 2:
		if roll < 0.07:
			_play_boss_animation(&"idle")
		elif roll < 0.34:
			_start_boss_stomp()
		elif roll < 0.34 + AMBUSH_PHASE_TWO_CHANCE and _can_start_special_entropy():
			_start_dark_ambush()
		elif roll < 0.34 + AMBUSH_PHASE_TWO_CHANCE + FIRE_PHASE_TWO_CHANCE and _can_start_special_entropy():
			_start_wandering_fire_entropy()
		elif roll < 0.82:
			_start_boss_laser(1)
		else:
			_start_boss_shot(2)
	else:
		if roll < 0.03:
			_play_boss_animation(&"idle")
		elif roll < 0.32:
			_start_boss_stomp()
		elif roll < 0.32 + AMBUSH_PHASE_THREE_CHANCE and _can_start_special_entropy():
			_start_dark_ambush()
		elif roll < 0.32 + AMBUSH_PHASE_THREE_CHANCE + FIRE_PHASE_THREE_CHANCE and _can_start_special_entropy():
			_start_wandering_fire_entropy()
		elif roll < 0.91:
			_start_boss_laser(randi_range(1, 3))
		else:
			_start_boss_shot(randi_range(2, 3))


func _get_boss_roll_interval(phase: int) -> float:
	if phase == 3:
		return PHASE_THREE_ROLL_INTERVAL
	if phase == 2:
		return PHASE_TWO_ROLL_INTERVAL
	return BOSS_ROLL_INTERVAL


func _start_boss_stomp() -> void:
	var action_id: int = _begin_action(&"slam")
	_play_boss_animation(&"slam")
	await _wait_seconds(_get_slam_wait_time(0.78))
	if action_id != action_serial:
		return
	_apply_slam_entropy()
	_finish_action(action_id)


func _start_boss_shot(projectile_count: int = 1) -> void:
	var action_id: int = _begin_action(&"shoot")
	_play_boss_animation(&"shoot")
	for projectile_index: int in range(projectile_count):
		await _wait_seconds(_get_attack_wait_time(0.28 if projectile_index == 0 else 0.34))
		if action_id != action_serial:
			return
		_spawn_final_projectile()
	await _wait_seconds(_get_attack_wait_time(0.32))
	_finish_action(action_id)


func _start_boss_laser(laser_count: int = 1) -> void:
	var action_id: int = _begin_action(&"laser")
	_play_boss_animation(&"special")
	await _wait_seconds(_get_attack_wait_time(0.25))
	if action_id != action_serial:
		return
	_spawn_laser_sequence(laser_count)
	await _wait_seconds(_get_laser_prepare_time() + _get_attack_wait_time(LASER_ACTION_RECOVERY_TIME))
	_finish_action(action_id)


func _start_boss_melee() -> void:
	var action_id: int = _begin_action(&"melee")
	_play_boss_animation(&"attack")
	await _wait_seconds(_get_attack_wait_time(0.38))
	if action_id != action_serial:
		return
	if _is_player_near_boss_body(CLOSE_MELEE_HIT_DISTANCE) and player.has_method("take_damage"):
		player.call("take_damage", 1, boss)
		_push_player_to_middle()
	await _wait_seconds(_get_attack_wait_time(0.35))
	_finish_action(action_id)


func _start_dark_ambush() -> void:
	if not _can_start_special_entropy():
		return
	_mark_special_entropy_started()
	_clear_fire_flames()
	var action_id: int = _begin_action(&"ambush")
	var phase: int = _get_phase()
	var attack_count: int = 3 if phase == 3 else 1
	var reaction_time: float = AMBUSH_REACTION_TIME_PHASE_THREE if phase == 3 else AMBUSH_REACTION_TIME_PHASE_TWO
	if entropy_controller != null and entropy_controller.has_method("force_background"):
		entropy_controller.call("force_background", &"mix", 5.4 if phase == 3 else 2.6)

	await _flash_black()
	if action_id != action_serial:
		return
	_teleport_boss_behind_player()

	for attack_index: int in range(attack_count):
		await _wait_seconds(reaction_time if attack_index == 0 else reaction_time * 0.55)
		if action_id != action_serial:
			return
		_play_boss_animation(&"attack")
		await _wait_seconds(_get_attack_wait_time(0.30))
		if action_id != action_serial:
			return
		if _is_player_near_boss_body(CLOSE_MELEE_HIT_DISTANCE + 25.0) and player.has_method("take_damage"):
			player.call("take_damage", 1, boss)
			_push_player_to_middle()
		if phase == 3 and attack_index < attack_count - 1:
			await _wait_seconds(0.12)
			await _flash_black()
			if action_id != action_serial:
				return
			_teleport_boss_behind_player()

	await _wait_seconds(AMBUSH_RETURN_FLASH_TIME)
	await _flash_black()
	if action_id != action_serial:
		return
	boss.global_position = standard_boss_position.round()
	_finish_action(action_id)


func _teleport_boss_behind_player() -> void:
	if boss == null or player == null:
		return
	var facing: int = 1
	var facing_value: Variant = player.get("facing_direction")
	if typeof(facing_value) == TYPE_INT or typeof(facing_value) == TYPE_FLOAT:
		facing = int(facing_value)
	if facing == 0:
		facing = 1
	var target_x: float = player.global_position.x - float(facing) * AMBUSH_SIDE_OFFSET
	target_x = clampf(target_x, FIRE_LEFT_X + 120.0, FIRE_RIGHT_X - 80.0)
	boss.global_position = Vector2(target_x, standard_boss_position.y).round()


func _start_wandering_fire_entropy() -> void:
	if fire_entropy_active or floor_flame_texture == null or not _can_start_special_entropy():
		return
	_mark_special_entropy_started()
	fire_entropy_active = true
	if entropy_controller != null and entropy_controller.has_method("force_background"):
		entropy_controller.call("force_background", &"fire", FIRE_ENTROPY_DURATION)

	var flame_count: int = 2 if _get_phase() == 3 else 1
	for index: int in range(flame_count):
		var direction: int = 1 if index % 2 == 0 else -1
		_spawn_floor_flame(direction, float(index) * 0.35)

	await _wait_seconds(FIRE_ENTROPY_DURATION)
	fire_entropy_active = false


func _spawn_floor_flame(initial_direction: int, start_delay: float) -> void:
	if start_delay > 0.0:
		await _wait_seconds(start_delay)
	if floor_flame_texture == null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = self

	var flame: Sprite2D = Sprite2D.new()
	flame.texture = floor_flame_texture
	flame.hframes = 3
	flame.frame = 0
	flame.z_index = 42
	flame.scale = Vector2(1.68, 1.68)
	var direction: int = initial_direction
	if direction == 0:
		direction = 1
	flame.flip_h = direction < 0
	flame.global_position = Vector2(FIRE_LEFT_X if direction > 0 else FIRE_RIGHT_X, FIRE_Y).round()
	scene_root.add_child(flame)
	active_fire_flames.append(flame)

	_animate_floor_flame(flame)
	_move_floor_flame(flame, direction)


func _animate_floor_flame(flame: Sprite2D) -> void:
	while is_instance_valid(flame):
		for frame_index: int in range(3):
			if not is_instance_valid(flame):
				return
			flame.frame = frame_index
			await _wait_seconds(0.08)


func _move_floor_flame(flame: Sprite2D, initial_direction: int) -> void:
	var elapsed: float = 0.0
	var direction: int = initial_direction
	while elapsed < FIRE_ENTROPY_DURATION and fire_entropy_active and is_instance_valid(flame):
		var step: float = 0.05
		flame.global_position.x += float(direction) * FIRE_SPEED * step
		if flame.global_position.x >= FIRE_RIGHT_X:
			direction = -1
			flame.flip_h = true
		elif flame.global_position.x <= FIRE_LEFT_X:
			direction = 1
			flame.flip_h = false
		_damage_player_with_fire(flame)
		await _wait_seconds(step)
		elapsed += step
	if is_instance_valid(flame):
		active_fire_flames.erase(flame)
		flame.queue_free()


func _damage_player_with_fire(flame: Sprite2D) -> void:
	if player == null or not player.has_method("take_damage") or not is_instance_valid(flame):
		return
	if player.global_position.distance_to(flame.global_position) <= FIRE_HIT_RADIUS:
		player.call("take_damage", 1, flame)


func _clear_fire_flames() -> void:
	fire_entropy_active = false
	for flame: Sprite2D in active_fire_flames:
		if is_instance_valid(flame):
			flame.queue_free()
	active_fire_flames.clear()


func _can_start_special_entropy() -> bool:
	return special_entropy_cooldown_timer <= 0.0 and current_action != &"ambush" and not fire_entropy_active


func _mark_special_entropy_started() -> void:
	special_entropy_cooldown_timer = SPECIAL_ENTROPY_COOLDOWN


func _flash_black() -> void:
	_ensure_dark_flash()
	if dark_flash_rect == null:
		return
	dark_flash_rect.visible = true
	dark_flash_rect.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(dark_flash_rect, "modulate:a", 1.0, 0.06)
	tween.tween_property(dark_flash_rect, "modulate:a", 0.0, 0.10)
	await tween.finished
	if dark_flash_rect != null:
		dark_flash_rect.visible = false


func _ensure_dark_flash() -> void:
	if dark_flash_rect != null:
		return
	dark_flash_layer = CanvasLayer.new()
	dark_flash_layer.layer = 80
	add_child(dark_flash_layer)
	dark_flash_rect = ColorRect.new()
	dark_flash_rect.visible = false
	dark_flash_rect.color = Color.BLACK
	dark_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_flash_rect.offset_left = 0.0
	dark_flash_rect.offset_top = 0.0
	dark_flash_rect.offset_right = 0.0
	dark_flash_rect.offset_bottom = 0.0
	dark_flash_layer.add_child(dark_flash_rect)


func _apply_slam_entropy() -> void:
	if entropy_controller == null:
		return
	if not _can_start_special_entropy():
		return
	_mark_special_entropy_started()
	var phase: int = _get_phase()
	if phase == 3 and entropy_controller.has_method("force_all_effects"):
		entropy_controller.call("force_all_effects", 5.0)
	elif phase == 2 and entropy_controller.has_method("force_random_effects"):
		entropy_controller.call("force_random_effects", 2, 5.0)
	elif entropy_controller.has_method("force_random_effect"):
		entropy_controller.call("force_random_effect", 5.0)
	elif entropy_controller.has_method("force_effect"):
		entropy_controller.call("force_effect", &"delay", 5.0)


func _get_attack_wait_time(base_time: float) -> float:
	var phase: int = _get_phase()
	if phase == 3:
		return base_time * 0.52
	if phase == 2:
		return base_time * 0.72
	return base_time


func _get_slam_wait_time(base_time: float) -> float:
	var phase: int = _get_phase()
	if phase == 3:
		return base_time * 0.42
	if phase == 2:
		return base_time * 0.58
	return base_time


func _begin_action(action_name: StringName) -> int:
	action_serial += 1
	action_locked = true
	current_action = action_name
	return action_serial


func _finish_action(action_id: int) -> void:
	if action_id != action_serial:
		return
	action_locked = false
	current_action = &""
	_play_boss_animation(&"idle")


func _is_player_near_boss_body(max_distance: float) -> bool:
	if boss == null or player == null:
		return false
	var boss_rect: Rect2 = _get_boss_collision_rect()
	if boss_rect.size == Vector2.ZERO:
		return boss.global_position.distance_to(player.global_position) <= max_distance
	var closest_x: float = clampf(player.global_position.x, boss_rect.position.x, boss_rect.end.x)
	var closest_y: float = clampf(player.global_position.y, boss_rect.position.y, boss_rect.end.y)
	var closest_point: Vector2 = Vector2(closest_x, closest_y)
	return closest_point.distance_to(player.global_position) <= max_distance


func _get_boss_collision_rect() -> Rect2:
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


func _push_player_to_middle() -> void:
	if player == null:
		return
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	var target_position: Vector2 = Vector2(MELEE_PUSH_TARGET_X, player.global_position.y)
	var push_tween: Tween = create_tween()
	push_tween.tween_property(player, "global_position", target_position, MELEE_PUSH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_laser_sequence(laser_count: int) -> void:
	if laser_texture == null:
		return
	var target_positions: Array[Vector2] = []
	for index: int in range(laser_count):
		var offset: float = 0.0
		if laser_count > 1:
			offset = float(index - (laser_count - 1) / 2.0) * 150.0
		target_positions.append(Vector2(player.global_position.x + offset, LASER_FLOOR_Y))

	for target_position: Vector2 in target_positions:
		_spawn_single_laser(target_position)


func _spawn_single_laser(target_position: Vector2) -> void:
	var warning: Sprite2D = _create_warning_sprite(target_position)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = self
	if warning != null:
		scene_root.add_child(warning)
		_animate_warning(warning)

	await _wait_seconds(_get_laser_prepare_time())
	if warning != null and is_instance_valid(warning):
		warning.queue_free()

	var laser: Sprite2D = _create_laser_sprite(target_position.x)
	scene_root.add_child(laser)
	await _animate_laser(laser)
	await _hold_laser_damage(target_position.x)
	if is_instance_valid(laser):
		laser.queue_free()


func _create_warning_sprite(target_position: Vector2) -> Sprite2D:
	if warning_texture == null:
		return null
	var warning: Sprite2D = Sprite2D.new()
	warning.texture = warning_texture
	warning.hframes = 8
	warning.frame = 0
	warning.z_index = 38
	warning.scale = Vector2(0.58, 0.24)
	warning.global_position = target_position + Vector2(0.0, 14.0)
	return warning


func _animate_warning(warning: Sprite2D) -> void:
	var frame_count: int = 4
	for frame_index: int in range(frame_count):
		if not is_instance_valid(warning):
			return
		warning.frame = frame_index
		await _wait_seconds(0.08)
	if is_instance_valid(warning):
		warning.frame = frame_count - 1


func _create_laser_sprite(target_x: float) -> Sprite2D:
	var laser: Sprite2D = Sprite2D.new()
	laser.texture = laser_texture
	laser.hframes = 6
	laser.frame = 0
	laser.centered = false
	laser.z_index = 37
	var frame_size: Vector2 = Vector2(float(laser_texture.get_width()) / 6.0, float(laser_texture.get_height()))
	var laser_scale_y: float = ((LASER_GROUND_Y - LASER_TOP_Y) / frame_size.y) + 0.42
	laser.scale = Vector2(3.05, laser_scale_y)
	laser.global_position = Vector2(target_x - (frame_size.x * laser.scale.x * 0.5), LASER_TOP_Y)
	return laser


func _animate_laser(laser: Sprite2D) -> void:
	if laser == null or not is_instance_valid(laser):
		return
	for frame_index: int in range(5):
		if not is_instance_valid(laser):
			return
		laser.frame = frame_index
		await _wait_seconds(0.045)
	if is_instance_valid(laser):
		laser.frame = 5


func _damage_player_with_laser(target_x: float) -> void:
	if player == null or not player.has_method("take_damage"):
		return
	if abs(player.global_position.x - target_x) <= LASER_HIT_HALF_WIDTH:
		player.call("take_damage", 1, boss)


func _hold_laser_damage(target_x: float) -> void:
	var elapsed: float = 0.0
	while elapsed < LASER_HOLD_TIME:
		_damage_player_with_laser(target_x)
		await _wait_seconds(0.18)
		elapsed += 0.18


func _get_laser_prepare_time() -> float:
	if _get_phase() == 3:
		return 0.8
	var health_percent: float = _get_boss_health_percent()
	var phase_progress: float = 1.0 - clampf(health_percent / PHASE_ONE_END_PERCENT, 0.0, 1.0)
	return lerpf(LASER_BASE_PREPARE_TIME, LASER_MIN_PREPARE_TIME, phase_progress)


func _spawn_final_projectile() -> void:
	if final_projectile_scene == null:
		return
	var projectile: Node = final_projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	if projectile is Node2D:
		var origin: Node2D = boss.get_node_or_null("ProjectileOrigin") as Node2D
		(projectile as Node2D).global_position = (origin.global_position if origin != null else boss.global_position + Vector2(145.0, -120.0)).round()
	var direction: Vector2 = (player.global_position - (projectile as Node2D).global_position).normalized() if projectile is Node2D else Vector2.RIGHT
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if projectile.has_method("setup"):
		projectile.call("setup", direction, 30, "players")


func _play_boss_animation(animation_name: StringName) -> void:
	if boss == null:
		return
	var anim_player: AnimationPlayer = boss.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if boss.has_method("_show_animation"):
		boss.call("_show_animation", animation_name)
	if anim_player != null and anim_player.has_animation(animation_name):
		anim_player.speed_scale = _get_animation_speed_scale(animation_name)
		anim_player.stop()
		anim_player.play(animation_name)
	elif boss.has_method("_play_state"):
		boss.call("_play_state", animation_name)


func _get_animation_speed_scale(animation_name: StringName) -> float:
	if animation_name == &"slam":
		if _get_phase() == 3:
			return 1.85
		if _get_phase() == 2:
			return 1.55
	if _get_phase() == 3 and (animation_name == &"attack" or animation_name == &"shoot" or animation_name == &"special" or animation_name == &"slam"):
		return 1.45
	if _get_phase() == 2 and (animation_name == &"attack" or animation_name == &"shoot" or animation_name == &"special"):
		return 1.25
	return 1.0


func _update_boss_health_ui() -> void:
	if boss == null:
		return
	var max_health_value: float = float(boss.get("max_health"))
	var health_value: float = float(boss.get("health"))
	if boss_health_bar != null:
		boss_health_bar.max_value = max_health_value
		boss_health_bar.value = clampf(health_value, 0.0, max_health_value)
	if boss_health_label != null:
		var percent: int = int(round((health_value / max_health_value) * 100.0)) if max_health_value > 0.0 else 0
		boss_health_label.text = "TELON PRIME  " + str(percent) + "%"


func _update_phase_transition() -> void:
	var phase: int = _get_phase()
	if phase == last_phase:
		return
	last_phase = phase
	roll_timer = minf(roll_timer, 1.0)
	minion_timer = _get_minion_spawn_time(phase) if phase < 3 else 9999.0
	if phase == 3:
		_clear_final_minions()


func _get_phase() -> int:
	var health_percent: float = _get_boss_health_percent()
	if health_percent <= PHASE_THREE_START_PERCENT:
		return 3
	if health_percent <= PHASE_ONE_END_PERCENT:
		return 2
	return 1


func _get_boss_health_percent() -> float:
	var max_health_value: float = float(boss.get("max_health"))
	var health_value: float = float(boss.get("health"))
	if max_health_value <= 0.0:
		return 1.0
	return clampf(health_value / max_health_value, 0.0, 1.0)


func _wait_seconds(seconds: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout
