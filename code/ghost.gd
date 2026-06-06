extends CharacterBody2D

@export var speed: float = 80.0
@export var acceleration: float = 300.0
@export var friction: float = 280.0
@export var shoot_cooldown: float = 5.0
@export var shoot_delay: float = 0.5
@export var min_chase_distance: float = 24.0
@export var stop_distance: float = 42.0
@export var projectile_scene: PackedScene = preload("res://scenes/proyectil.tscn")
@export var projectile_speed_multiplier: float = 2.8

var shooting: bool = false
var shoot_timer: float = 0.0
var shoot_time: float = 0.0
var shoot_spawned: bool = false
var target: Node2D
var preparing_to_shoot: bool = false
var prepare_shoot_time: float = 0.0
@export var prepare_shoot_duration: float = 2.0

@export var dash_speed_multiplier: float = 1.8
@export var dash_duration: float = 0.6
@export var dash_cooldown: float = 4.0
var dashing: bool = false
var dash_time: float = 0.0
var dash_timer: float = 0.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var idle_sprite: Sprite2D = $idle
@onready var dash_sprite: Sprite2D = $dash
@onready var up_sprite: Sprite2D = $up
@onready var shoot_sprite: Sprite2D = $shoot
@onready var shoot_node: Sprite2D = $shoot

func _ready():
	target = get_parent().get_node_or_null("kid")
	anim_player.play("idle")
	show_animation("idle")
	shoot_timer = shoot_cooldown
	dash_timer = randf_range(2.0, dash_cooldown)

func _physics_process(delta: float) -> void:
	if not target or not target.is_inside_tree():
		target = get_parent().get_node_or_null("kid")

	if target:
		if preparing_to_shoot:
			update_shoot_preparation(delta)
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		elif shooting:
			update_shoot(delta)
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		else:
			update_dash(delta)
			chase_target(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	check_player_collision()
	update_animation(delta)

func chase_target(delta: float) -> void:
	var direction = target.global_position - global_position
	var distance = direction.length()
	update_facing(direction)
	if distance > stop_distance:
		var base_velocity = direction.normalized() * speed
		if dashing:
			base_velocity *= dash_speed_multiplier
		velocity = velocity.move_toward(base_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if distance > 130.0 and shoot_timer <= 0.0 and not shooting and not preparing_to_shoot:
		prepare_to_shoot()

	if distance > stop_distance and dash_timer <= 0.0 and not dashing:
		if not preparing_to_shoot:
			start_dash()

func start_shoot() -> void:
	shooting = true
	shoot_spawned = false
	shoot_time = 0.0
	anim_player.play("shoot")
	show_animation("shoot")
	shoot_timer = shoot_cooldown

func update_shoot(delta: float) -> void:
	shoot_time += delta
	if anim_player.current_animation != "shoot":
		anim_player.play("shoot")
	show_animation("shoot")

	var shoot_duration = get_animation_duration("shoot")
	var projectile_time = min(shoot_delay, shoot_duration)
	if not shoot_spawned and shoot_time >= projectile_time:
		spawn_projectile()

	if shoot_time >= shoot_duration:
		if not shoot_spawned:
			spawn_projectile()
		shooting = false
		shoot_spawned = false

func update_animation(delta: float) -> void:
	shoot_timer -= delta
	if preparing_to_shoot:
		if anim_player.current_animation != "idle":
			anim_player.play("idle")
		show_animation("idle")
		return
	if shooting:
		if anim_player.current_animation != "shoot":
			anim_player.play("shoot")
		show_animation("shoot")
		return

	if dashing or abs(velocity.x) > 8.0:
		if anim_player.current_animation != "dash":
			anim_player.play("dash")
		show_animation("dash")
	elif target and abs(target.global_position.y - global_position.y) > 12.0:
		if anim_player.current_animation != "up":
			anim_player.play("up")
		show_animation("up")
	else:
		if anim_player.current_animation != "idle":
			anim_player.play("idle")
		show_animation("idle")

func get_animation_duration(animation_name: String) -> float:
	if not anim_player.has_animation(animation_name):
		return 0.0
	var speed_scale = abs(anim_player.speed_scale)
	var animation_length = anim_player.get_animation(animation_name).length
	if speed_scale <= 0.0:
		return animation_length
	return animation_length / speed_scale

func show_animation(name: String) -> void:
	idle_sprite.visible = name == "idle"
	dash_sprite.visible = name == "dash"
	up_sprite.visible = name == "up"
	shoot_sprite.visible = name == "shoot"

func spawn_projectile() -> void:
	if not target:
		return
	if not projectile_scene:
		projectile_scene = load("res://scenes/proyectil.tscn")
	if not projectile_scene:
		return

	var direction = (target.global_position - shoot_node.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT if shoot_sprite.flip_h else Vector2.RIGHT
	var projectile = projectile_scene.instantiate()
	projectile.direction = direction
	# spawn a bit ahead to avoid overlapping and pushing the ghost
	projectile.global_position = shoot_node.global_position + direction * 32.0
	projectile.speed = speed * projectile_speed_multiplier
	var root = get_tree().current_scene
	if root:
		root.add_child(projectile)
	shoot_spawned = true
	preparing_to_shoot = false
	prepare_shoot_time = 0.0

func start_dash() -> void:
	dashing = true
	dash_time = 0.0
	if shooting:
		shooting = false
		shoot_spawned = false
	preparing_to_shoot = false
	prepare_shoot_time = 0.0
	anim_player.play("dash")
	show_animation("dash")

func update_dash(delta: float) -> void:
	if dashing:
		dash_time += delta
		if dash_time >= dash_duration:
			dashing = false
			dash_timer = dash_cooldown
	elif dash_timer > 0.0:
		dash_timer -= delta

func prepare_to_shoot() -> void:
	preparing_to_shoot = true
	prepare_shoot_time = 0.0
	anim_player.play("idle")
	show_animation("idle")
	if dashing:
		dashing = false
		dash_timer = dash_cooldown

func update_shoot_preparation(delta: float) -> void:
	if not preparing_to_shoot:
		return
	prepare_shoot_time += delta
	if prepare_shoot_time >= prepare_shoot_duration:
		preparing_to_shoot = false
		start_shoot()

func update_facing(direction: Vector2) -> void:
	if abs(direction.x) <= 0.1:
		return
	var face_left = direction.x < 0.0
	idle_sprite.flip_h = face_left
	dash_sprite.flip_h = face_left
	up_sprite.flip_h = face_left
	shoot_sprite.flip_h = face_left

func check_player_collision() -> void:
	var collisions = get_slide_collision_count()
	for i in range(collisions):
		var collision = get_slide_collision(i)
		if not collision:
			continue
		var collider = collision.get_collider()
		if collider and collider.name == "kid":
			get_tree().change_scene_to_file("res://scenes/pelea_test.tscn")
			return
