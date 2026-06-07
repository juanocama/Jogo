extends CharacterBody2D
class_name BossRobot

signal defeated(boss: BossRobot)

@export var boss_id: StringName = &"robot_01"

@export_category("Stats")
@export var max_health: int = 250
@export var contact_damage: int = 12
@export var melee_damage: int = 25
@export var projectile_damage: int = 18
@export var invulnerability_time: float = 0.2
@export var damage_enabled: bool = false
@export var damage_taken_multiplier: float = 1.0
@export var ai_enabled: bool = true
@export var hit_reaction_enabled: bool = true
@export var fall_on_death: bool = false
@export var remove_after_death_seconds: float = 0.0

@export_category("Movement")
@export var speed: float = 70.0
@export var acceleration: float = 500.0
@export var friction: float = 550.0
@export var gravity: float = 850.0
@export var stop_distance: float = 48.0

@export_category("Flying Boss")
@export var is_flying_boss: bool = false
@export var flight_height_offset: float = -95.0
@export var vertical_follow_speed: float = 95.0
@export var hover_amplitude: float = 8.0
@export var hover_speed: float = 3.0
@export var ram_height_offset: float = -25.0
@export var return_to_flight_after_ram: bool = true

@export_category("Boss Attacks")
@export var melee_range: float = 58.0
@export var melee_cooldown: float = 1.2
@export var dash_speed: float = 260.0
@export var dash_duration: float = 0.45
@export var dash_cooldown: float = 3.0
@export var shoot_range: float = 420.0
@export var shoot_cooldown: float = 2.4
@export var shoot_delay: float = 0.35
@export var slam_cooldown: float = 5.0
@export var projectile_scene: PackedScene
@export var robot_piece_scene: PackedScene
@export var robot_piece_textures: Array[Texture2D] = []

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var projectile_origin: Marker2D = $ProjectileOrigin
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar

const SPRITE_NODE_NAMES: Array[StringName] = [
	&"idle", &"walk", &"dash", &"attack", &"shoot", &"fly", &"slam", &"hit", &"death", &"special"
]

var health: int = 0
var target: Node2D = null
var facing_direction: int = -1
var state: StringName = &"idle"
var state_timer: float = 0.0
var hurt_timer: float = 0.0
var melee_timer: float = 0.0
var dash_timer: float = 0.0
var shoot_timer: float = 0.0
var slam_timer: float = 0.0
var contact_timer: float = 0.0
var attack_has_hit: bool = false
var shot_spawned: bool = false
var dead: bool = false
var hover_time: float = 0.0
var ram_target_position: Vector2 = Vector2.ZERO
var active_state_duration: float = 0.0
var next_piece_drop_percent: float = 0.35
var next_piece_texture_index: int = 0
var defeated_signal_emitted: bool = false


func _ready() -> void:
	add_to_group("bosses")
	health = max_health
	_update_health_bar()
	melee_timer = randf_range(0.2, melee_cooldown)
	dash_timer = randf_range(0.5, dash_cooldown)
	shoot_timer = randf_range(0.25, shoot_cooldown)
	slam_timer = randf_range(1.4, slam_cooldown)

	if is_flying_boss:
		gravity = 0.0
		velocity.y = 0.0
		_play_state(&"fly")
	else:
		_play_state(&"idle")


func _physics_process(delta: float) -> void:
	if dead:
		if not is_flying_boss:
			_apply_gravity(delta)
		else:
			velocity.y = move_toward(velocity.y, 0.0, friction * delta)
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		global_position = global_position.round()
		return

	_update_timers(delta)

	if not ai_enabled:
		velocity = Vector2.ZERO
		global_position = global_position.round()
		return

	_apply_gravity(delta)
	_find_target()

	if target == null:
		state = &"idle"
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if is_flying_boss:
			_update_hover(delta)
			_play_state(&"fly")
		else:
			_play_state(&"idle")
	else:
		_update_ai(delta)

	move_and_slide()
	_damage_on_contact()
	global_position = global_position.round()


func _update_timers(delta: float) -> void:
	if hurt_timer > 0.0:
		hurt_timer -= delta
	if melee_timer > 0.0:
		melee_timer -= delta
	if dash_timer > 0.0:
		dash_timer -= delta
	if shoot_timer > 0.0:
		shoot_timer -= delta
	if slam_timer > 0.0:
		slam_timer -= delta
	if contact_timer > 0.0:
		contact_timer -= delta


func _apply_gravity(delta: float) -> void:
	if is_flying_boss:
		# En modo volador nunca debe pegarse al piso.
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _find_target() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for player_node: Node in players:
		if not player_node is Node2D:
			continue
		if player_node.has_method("is_alive") and not bool(player_node.call("is_alive")):
			continue

		var player_2d: Node2D = player_node as Node2D
		var distance: float = global_position.distance_to(player_2d.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = player_2d

	target = nearest


func _update_ai(delta: float) -> void:
	if target == null:
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	_update_facing(to_target)

	match state:
		&"melee":
			_update_melee(delta)
		&"dash":
			_update_dash(delta)
		&"shoot":
			_update_shoot(delta)
		&"slam":
			_update_slam(delta)
		&"hit":
			state_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			if is_flying_boss:
				_update_hover(delta)
			if state_timer <= 0.0:
				state = &"idle"
				_play_state(&"fly" if is_flying_boss else &"idle")
		_:
			_choose_next_action(distance, to_target, delta)


func _choose_next_action(distance: float, to_target: Vector2, delta: float) -> void:
	# Robot 01 volador: persigue, dispara y baja a embestir.
	if is_flying_boss:
		if projectile_scene != null and shoot_timer <= 0.0 and distance <= shoot_range:
			_start_shoot()
			return

		if dash_timer <= 0.0 and distance <= 440.0:
			_start_dash()
			return

		if distance <= melee_range and melee_timer <= 0.0:
			_start_melee()
			return

		_chase_target(to_target, distance, delta)
		return

	# Robot terrestre.
	if distance <= melee_range and melee_timer <= 0.0:
		_start_melee()
		return

	if _uses_ground_specials() and projectile_scene != null and shoot_timer <= 0.0 and distance <= shoot_range:
		_start_shoot()
		return

	if _uses_ground_specials() and slam_timer <= 0.0 and distance > 90.0:
		_start_slam()
		return

	if dash_timer <= 0.0 and distance > melee_range and distance < 330.0:
		_start_dash()
		return

	_chase_target(to_target, distance, delta)


func _chase_target(to_target: Vector2, distance: float, delta: float) -> void:
	if is_flying_boss:
		_chase_target_flying(delta)
		return

	if distance > stop_distance:
		var desired: Vector2 = Vector2(sign(to_target.x), 0.0) * speed
		velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
		_play_state(&"walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_play_state(&"idle")


func _chase_target_flying(delta: float) -> void:
	if target == null:
		_update_hover(delta)
		return

	# Punto de vuelo normal: por encima del jugador.
	var desired_position: Vector2 = target.global_position + Vector2(0.0, flight_height_offset)
	var to_flight_point: Vector2 = desired_position - global_position
	var distance_to_flight_point: float = to_flight_point.length()

	if distance_to_flight_point > stop_distance:
		var desired_direction: Vector2 = to_flight_point.normalized()
		var desired_velocity: Vector2 = desired_direction * speed
		velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
		velocity.y = move_toward(velocity.y, desired_velocity.y, vertical_follow_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_update_hover(delta)

	_play_state(&"fly")


func _update_hover(delta: float) -> void:
	hover_time += delta
	var hover_velocity: float = cos(hover_time * hover_speed) * hover_amplitude
	velocity.y = move_toward(velocity.y, hover_velocity, vertical_follow_speed * delta)


func _start_melee() -> void:
	state = &"melee"
	active_state_duration = _get_animation_duration(&"attack", 0.55)
	state_timer = active_state_duration
	attack_has_hit = false
	melee_timer = melee_cooldown
	velocity.x = 0.0
	if is_flying_boss:
		velocity.y = 0.0
	_play_state(&"attack")


func _update_melee(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if is_flying_boss:
		_update_hover(delta)
	var elapsed: float = active_state_duration - state_timer
	var hit_time: float = min(0.3, active_state_duration * 0.45)
	if not attack_has_hit and elapsed >= hit_time:
		attack_has_hit = true
		_damage_targets_in_attack_area(melee_damage)
	if state_timer <= 0.0:
		state = &"idle"
		_play_state(&"fly" if is_flying_boss else &"idle")


func _start_dash() -> void:
	state = &"dash"
	active_state_duration = _get_animation_duration(&"dash", dash_duration)
	state_timer = max(dash_duration, active_state_duration)
	dash_timer = dash_cooldown

	if is_flying_boss and target != null:
		# La embestida baja hacia la altura del jugador, no hacia el punto alto de vuelo.
		ram_target_position = target.global_position + Vector2(0.0, ram_height_offset)
	else:
		ram_target_position = global_position + Vector2(float(facing_direction) * 180.0, 0.0)

	_play_state(&"dash")


func _update_dash(delta: float) -> void:
	state_timer -= delta

	if is_flying_boss:
		var to_ram_point: Vector2 = ram_target_position - global_position
		if to_ram_point.length() > 4.0:
			var ram_direction: Vector2 = to_ram_point.normalized()
			velocity.x = ram_direction.x * dash_speed
			velocity.y = ram_direction.y * dash_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.y = move_toward(velocity.y, 0.0, vertical_follow_speed * delta)
	else:
		velocity.x = float(facing_direction) * dash_speed

	_damage_targets_in_attack_area(contact_damage + 8)

	if state_timer <= 0.0:
		velocity.x = 0.0
		if is_flying_boss:
			velocity.y = 0.0
		state = &"idle"
		_play_state(&"fly" if is_flying_boss else &"idle")


func _start_shoot() -> void:
	state = &"shoot"
	active_state_duration = _get_animation_duration(&"shoot", 0.85)
	state_timer = active_state_duration
	shot_spawned = false
	shoot_timer = shoot_cooldown
	velocity.x = 0.0
	if is_flying_boss:
		velocity.y = 0.0
	_play_state(&"shoot")


func _update_shoot(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if is_flying_boss:
		_update_hover(delta)

	if not shot_spawned and active_state_duration - state_timer >= shoot_delay:
		shot_spawned = true
		_spawn_projectile()

	if state_timer <= 0.0:
		state = &"idle"
		_play_state(&"fly" if is_flying_boss else &"idle")


func _start_slam() -> void:
	state = &"slam"
	active_state_duration = _get_animation_duration(&"slam", 1.05)
	state_timer = max(1.05, active_state_duration)
	slam_timer = slam_cooldown
	velocity.y = -260.0
	velocity.x = float(facing_direction) * 95.0
	_play_state(&"fly")


func _update_slam(delta: float) -> void:
	state_timer -= delta
	if state_timer <= active_state_duration * 0.45:
		_play_state(&"slam")
		velocity.x = float(facing_direction) * 160.0
		if is_on_floor():
			_damage_targets_in_attack_area(melee_damage + 12)
			state_timer = 0.0
	if state_timer <= 0.0:
		state = &"idle"
		_play_state(&"idle")


func _damage_targets_in_attack_area(amount: int) -> void:
	if not damage_enabled:
		return
	attack_area.position.x = float(facing_direction) * abs(attack_area.position.x)
	for body: Node in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.is_in_group("players") and body.has_method("take_damage"):
			body.call("take_damage", amount, self)


func _damage_on_contact() -> void:
	if not damage_enabled:
		return
	if contact_timer > 0.0:
		return
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue
		var body: Object = collision.get_collider()
		if body is Node and body.is_in_group("players") and body.has_method("take_damage"):
			body.call("take_damage", contact_damage, self)
			contact_timer = 0.8
			return


func _spawn_projectile() -> void:
	if projectile_scene == null or target == null:
		return

	var projectile: Node = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	if projectile is Node2D:
		(projectile as Node2D).global_position = projectile_origin.global_position.round()

	var direction: Vector2 = (target.global_position - projectile_origin.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(float(facing_direction), 0.0)

	if projectile.has_method("setup"):
		projectile.call("setup", direction, projectile_damage, "players")


func take_damage(amount: int, source: Node = null) -> void:
	if dead or hurt_timer > 0.0:
		return
	hurt_timer = invulnerability_time
	var previous_health: int = health
	var final_amount: int = maxi(1, int(round(float(amount) * damage_taken_multiplier)))
	health -= final_amount
	health = maxi(health, 0)
	_update_health_bar()
	_drop_pieces_for_health_change(previous_health, health)

	if source is Node2D:
		var source_2d: Node2D = source as Node2D
		var dir: float = sign(global_position.x - source_2d.global_position.x)
		if dir == 0.0:
			dir = float(-facing_direction)
		var knockback_force: float = 32.0 if source.is_in_group("player_projectiles") else 80.0
		velocity.x = dir * knockback_force

	if health <= 0:
		_die()
	elif hit_reaction_enabled:
		state = &"hit"
		state_timer = 0.18
		_play_state(&"hit")


func _die() -> void:
	state = &"dead"
	dead = true
	health = 0
	_update_health_bar()
	velocity = Vector2.ZERO
	if fall_on_death:
		is_flying_boss = false
		gravity = maxf(gravity, 850.0)
	_play_state(&"death")
	$CollisionShape2D.set_deferred("disabled", true)
	$AttackArea/CollisionShape2D.set_deferred("disabled", true)
	if remove_after_death_seconds > 0.0:
		_remove_after_death()


func _remove_after_death() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(remove_after_death_seconds).timeout
	if is_instance_valid(self):
		queue_free()
	_emit_defeated_after_death_animation()


func _emit_defeated_after_death_animation() -> void:
	if defeated_signal_emitted:
		return

	defeated_signal_emitted = true
	await get_tree().create_timer(_get_animation_duration(&"death", 0.7)).timeout
	defeated.emit(self)


func is_alive() -> bool:
	return not dead and health > 0


func _uses_ground_specials() -> bool:
	return boss_id == &"robot_02" or boss_id == &"final_boss"


func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = float(max_health)
	health_bar.value = float(clampi(health, 0, max_health))


func _drop_pieces_for_health_change(previous_health: int, current_health: int) -> void:
	if boss_id != &"robot_02" or robot_piece_scene == null or robot_piece_textures.is_empty():
		return
	if max_health <= 0:
		return

	var previous_percent: float = float(previous_health) / float(max_health)
	var current_percent: float = float(current_health) / float(max_health)
	while next_piece_drop_percent >= 0.0 and previous_percent > next_piece_drop_percent and current_percent <= next_piece_drop_percent:
		_spawn_robot_piece()
		next_piece_drop_percent -= 0.05


func _spawn_robot_piece() -> void:
	var piece: Node = robot_piece_scene.instantiate()
	get_tree().current_scene.add_child(piece)

	var fall_target_position: Vector2 = global_position
	if target != null:
		var side_offset: float = randf_range(70.0, 150.0)
		side_offset *= -1.0 if randf() < 0.5 else 1.0
		fall_target_position = target.global_position + Vector2(side_offset, 0.0)

	if piece is Node2D:
		var piece_2d: Node2D = piece as Node2D
		piece_2d.global_position = (fall_target_position + Vector2(0.0, -230.0)).round()

	var texture: Texture2D = robot_piece_textures[next_piece_texture_index % robot_piece_textures.size()]
	next_piece_texture_index += 1
	var direction: int = -1 if fall_target_position.x > global_position.x else 1
	if piece.has_method("setup"):
		piece.call("setup", texture, direction, fall_target_position.y)


func _update_facing(to_target: Vector2) -> void:
	if abs(to_target.x) < 1.0:
		return
	facing_direction = -1 if to_target.x < 0.0 else 1
	for node_name: StringName in SPRITE_NODE_NAMES:
		var sprite: Node = get_node_or_null(NodePath(node_name))
		if sprite is Sprite2D:
			(sprite as Sprite2D).flip_h = facing_direction < 0
	attack_area.position.x = float(facing_direction) * abs(attack_area.position.x)
	projectile_origin.position.x = float(facing_direction) * abs(projectile_origin.position.x)


func _play_state(anim_name: StringName) -> void:
	var final_anim: StringName = anim_name
	if is_flying_boss and (anim_name == &"idle" or anim_name == &"walk"):
		final_anim = &"fly"

	_show_animation(final_anim)
	if anim_player and anim_player.has_animation(final_anim) and anim_player.current_animation != final_anim:
		anim_player.play(final_anim)


func _get_animation_duration(anim_name: StringName, fallback: float) -> float:
	if anim_player == null or not anim_player.has_animation(anim_name):
		return fallback

	var animation: Animation = anim_player.get_animation(anim_name)
	if animation == null:
		return fallback

	var speed: float = anim_player.speed_scale
	if speed <= 0.0:
		speed = 1.0
	return animation.length / speed


func _show_animation(anim_name: StringName) -> void:
	for node_name: StringName in SPRITE_NODE_NAMES:
		var sprite: Node = get_node_or_null(NodePath(node_name))
		if sprite is Sprite2D:
			(sprite as Sprite2D).visible = node_name == anim_name
