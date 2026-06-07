extends Node

const PHASE_ONE_END_PERCENT: float = 0.65
const BOSS_ROLL_INTERVAL: float = 4.0
const CLOSE_MELEE_TIME: float = 2.0
const CLOSE_MELEE_DISTANCE: float = 150.0
const CLOSE_MELEE_HIT_DISTANCE: float = 215.0
const MELEE_PUSH_TARGET_X: float = -150.0
const MELEE_PUSH_DURATION: float = 0.22
const MINION_SPAWN_MIN_TIME: float = 8.0
const MINION_SPAWN_MAX_TIME: float = 12.0
const MAX_MINIONS: int = 3
const ROBOT2_PHASE_ONE_HEALTH: int = 45
const ROBOT1_PHASE_ONE_HEALTH: int = 30
const MINION_DAMAGE_TAKEN_MULTIPLIER: float = 6.0
const FLOOR_Y: float = 188.0

@export var boss_path: NodePath
@export var player_path: NodePath
@export var entropy_controller_path: NodePath
@export var boss_health_bar_path: NodePath
@export var boss_health_label_path: NodePath
@export var robot1_scene: PackedScene
@export var robot2_scene: PackedScene
@export var robot1_projectile_scene: PackedScene
@export var final_projectile_scene: PackedScene

var roll_timer: float = 1.2
var minion_timer: float = 4.0
var close_timer: float = 0.0
var action_locked: bool = false
var action_serial: int = 0
var current_action: StringName = &""

@onready var boss: Node2D = get_node_or_null(boss_path) as Node2D
@onready var player: Node2D = get_node_or_null(player_path) as Node2D
@onready var entropy_controller: Node = get_node_or_null(entropy_controller_path)
@onready var boss_health_bar: ProgressBar = get_node_or_null(boss_health_bar_path) as ProgressBar
@onready var boss_health_label: Label = get_node_or_null(boss_health_label_path) as Label


func _ready() -> void:
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
	if _get_boss_health_percent() <= PHASE_ONE_END_PERCENT:
		return

	_update_minions(delta)
	_update_boss_roll(delta)


func _configure_boss() -> void:
	if boss == null:
		return
	boss.set("ai_enabled", false)
	boss.set("damage_taken_multiplier", 0.4)
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
	minion_timer -= delta
	if minion_timer > 0.0:
		return
	minion_timer = randf_range(MINION_SPAWN_MIN_TIME, MINION_SPAWN_MAX_TIME)

	var active_minion_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("final_minions"):
		if node != null and node.is_inside_tree() and (not node.has_method("is_alive") or bool(node.call("is_alive"))):
			active_minion_count += 1
	if active_minion_count >= MAX_MINIONS:
		return

	if randf() < 0.45:
		_spawn_robot1_minion()
	else:
		_spawn_robot2_minion()


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
	if current_action == &"melee":
		close_timer = 0.0
		return

	if _is_player_near_boss_body(CLOSE_MELEE_DISTANCE):
		close_timer += delta
	else:
		close_timer = 0.0

	if close_timer >= CLOSE_MELEE_TIME and current_action != &"melee":
		close_timer = 0.0
		_start_boss_melee()


func _update_boss_roll(delta: float) -> void:
	if action_locked:
		return
	roll_timer -= delta
	if roll_timer > 0.0:
		return
	roll_timer = BOSS_ROLL_INTERVAL

	var roll: float = randf()
	if roll < 0.4:
		_play_boss_animation(&"idle")
	elif roll < 0.8:
		_start_boss_stomp()
	else:
		_start_boss_shot()


func _start_boss_stomp() -> void:
	var action_id: int = _begin_action(&"slam")
	_play_boss_animation(&"slam")
	await _wait_seconds(0.78)
	if action_id != action_serial:
		return
	if entropy_controller != null:
		if entropy_controller.has_method("force_random_effect"):
			entropy_controller.call("force_random_effect", 5.0)
		elif entropy_controller.has_method("force_effect"):
			entropy_controller.call("force_effect", &"delay", 5.0)
	_finish_action(action_id)


func _start_boss_shot() -> void:
	var action_id: int = _begin_action(&"shoot")
	_play_boss_animation(&"shoot")
	await _wait_seconds(0.34)
	if action_id != action_serial:
		return
	_spawn_final_projectile()
	await _wait_seconds(0.38)
	_finish_action(action_id)


func _start_boss_melee() -> void:
	var action_id: int = _begin_action(&"melee")
	_play_boss_animation(&"attack")
	await _wait_seconds(0.38)
	if action_id != action_serial:
		return
	if _is_player_near_boss_body(CLOSE_MELEE_HIT_DISTANCE) and player.has_method("take_damage"):
		player.call("take_damage", 1, boss)
		_push_player_to_middle()
	await _wait_seconds(0.35)
	_finish_action(action_id)


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
		anim_player.stop()
		anim_player.play(animation_name)
	elif boss.has_method("_play_state"):
		boss.call("_play_state", animation_name)


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
