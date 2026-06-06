extends CharacterBody2D
class_name MainCharacter

@export var character_id: StringName = &"nino_01"
@export var is_player_controlled: bool = true

@export_category("Stats")
@export var max_health: int = 100
@export var attack_damage: int = 18
@export var invulnerability_time: float = 0.65

@export_category("Movement")
@export var walk_speed: float = 120.0
@export var run_speed: float = 180.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 850.0
@export var acceleration: float = 1100.0
@export var friction: float = 900.0
@export var dash_speed: float = 330.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.65

@export_category("Combat")
@export var attack_duration: float = 0.36
@export var attack_hit_time: float = 0.14
@export var attack_offset_x: float = 28.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_RUN := &"run"
const ANIM_JUMP := &"jump"
const ANIM_FALL := &"fall"
const ANIM_CROUCH := &"crouch"
const ANIM_ATTACK := &"attack"
const ANIM_HIT := &"hit"
const ANIM_DEATH := &"death"
const ANIM_DASH := &"dash"

const SPRITE_NODE_NAMES := [
	"idle", "walk", "run", "jump", "fall", "crouch", "attack", "hit", "death", "dash"
]

var health: int
var facing_direction: int = 1
var attacking: bool = false
var attack_timer: float = 0.0
var attack_has_hit: bool = false
var dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var hurt_timer: float = 0.0
var dead: bool = false
var previous_jump_pressed: bool = false
var previous_attack_pressed: bool = false
var previous_dash_pressed: bool = false


func _ready() -> void:
	add_to_group("players")
	health = max_health
	attack_area.monitoring = true
	attack_collision.disabled = false
	_show_animation(ANIM_IDLE)
	_play_animation(ANIM_IDLE)


func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	_update_timers(delta)
	_apply_gravity(delta)

	if is_player_controlled:
		_handle_player_input(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	_update_attack(delta)
	_update_animation()
	move_and_slide()
	global_position = global_position.round()


func _update_timers(delta: float) -> void:
	if hurt_timer > 0.0:
		hurt_timer -= delta
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			dashing = false


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0


func _handle_player_input(delta: float) -> void:
	if hurt_timer > 0.0 or attacking:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	if dashing:
		velocity.x = facing_direction * dash_speed
		return

	var input_dir := _get_horizontal_input()
	if input_dir != 0:
		facing_direction = input_dir
		_set_facing(facing_direction)

	var target_speed := walk_speed
	if _is_run_pressed():
		target_speed = run_speed

	if input_dir != 0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if _is_jump_just_pressed() and is_on_floor():
		velocity.y = jump_velocity

	if _is_attack_just_pressed():
		_start_attack()

	if _is_dash_just_pressed():
		_start_dash()


func _get_horizontal_input() -> int:
	var dir := 0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir += 1
	return clampi(dir, -1, 1)


func _is_jump_just_pressed() -> bool:
	var pressed := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
	var just_pressed := pressed and not previous_jump_pressed
	previous_jump_pressed = pressed
	return just_pressed


func _is_run_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _is_attack_just_pressed() -> bool:
	var pressed := Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_Z) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed := pressed and not previous_attack_pressed
	previous_attack_pressed = pressed
	return just_pressed


func _is_dash_just_pressed() -> bool:
	var pressed := Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_X)
	var just_pressed := pressed and not previous_dash_pressed
	previous_dash_pressed = pressed
	return just_pressed


func _start_attack() -> void:
	if attacking or dashing or dead:
		return
	attacking = true
	attack_timer = attack_duration
	attack_has_hit = false
	velocity.x = 0.0
	_play_animation(ANIM_ATTACK)
	_show_animation(ANIM_ATTACK)


func _update_attack(delta: float) -> void:
	if not attacking:
		return

	attack_timer -= delta
	var elapsed := attack_duration - attack_timer
	if not attack_has_hit and elapsed >= attack_hit_time:
		attack_has_hit = true
		_deal_attack_damage()

	if attack_timer <= 0.0:
		attacking = false


func _deal_attack_damage() -> void:
	attack_area.position.x = facing_direction * attack_offset_x
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.is_in_group("bosses") and body.has_method("take_damage"):
			body.take_damage(attack_damage, self)


func _start_dash() -> void:
	if dash_cooldown_timer > 0.0 or attacking or dead:
		return
	dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	velocity.y = 0.0
	_play_animation(ANIM_DASH)
	_show_animation(ANIM_DASH)


func take_damage(amount: int, source: Node = null) -> void:
	if dead or hurt_timer > 0.0:
		return
	health -= amount
	hurt_timer = invulnerability_time

	if source is Node2D:
		var source_2d: Node2D = source as Node2D
		var knockback_dir: float = sign(global_position.x - source_2d.global_position.x)
		if knockback_dir == 0.0:
			knockback_dir = float(-facing_direction)
		velocity.x = knockback_dir * 150.0
		velocity.y = -130.0

	if health <= 0:
		_die()
	else:
		_play_animation(ANIM_HIT)
		_show_animation(ANIM_HIT)


func heal_full() -> void:
	health = max_health
	dead = false
	hurt_timer = 0.0
	_play_animation(ANIM_IDLE)
	_show_animation(ANIM_IDLE)


func _die() -> void:
	dead = true
	health = 0
	velocity = Vector2.ZERO
	_play_animation(ANIM_DEATH)
	_show_animation(ANIM_DEATH)


func is_alive() -> bool:
	return not dead and health > 0


func set_controlled(value: bool) -> void:
	is_player_controlled = value


func _update_animation() -> void:
	if dead:
		_show_animation(ANIM_DEATH)
		return
	if hurt_timer > invulnerability_time * 0.55:
		_show_animation(ANIM_HIT)
		return
	if attacking:
		_show_animation(ANIM_ATTACK)
		return
	if dashing:
		_show_animation(ANIM_DASH)
		return

	if not is_on_floor():
		if velocity.y < 0.0:
			_play_animation(ANIM_JUMP)
			_show_animation(ANIM_JUMP)
		else:
			_play_animation(ANIM_FALL)
			_show_animation(ANIM_FALL)
		return

	if _get_horizontal_input() == 0 and Input.is_key_pressed(KEY_S):
		_play_animation(ANIM_CROUCH)
		_show_animation(ANIM_CROUCH)
		return

	if abs(velocity.x) > 8.0:
		if abs(velocity.x) > walk_speed + 10.0:
			_play_animation(ANIM_RUN)
			_show_animation(ANIM_RUN)
		else:
			_play_animation(ANIM_WALK)
			_show_animation(ANIM_WALK)
	else:
		_play_animation(ANIM_IDLE)
		_show_animation(ANIM_IDLE)


func _play_animation(anim_name: StringName) -> void:
	if anim_player == null:
		return
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func _show_animation(anim_name: StringName) -> void:
	for node_name in SPRITE_NODE_NAMES:
		var sprite := get_node_or_null(NodePath(node_name))
		if sprite is Sprite2D:
			sprite.visible = StringName(node_name) == anim_name


func _set_facing(dir: int) -> void:
	var face_left := dir < 0
	for node_name in SPRITE_NODE_NAMES:
		var sprite := get_node_or_null(NodePath(node_name))
		if sprite is Sprite2D:
			sprite.flip_h = face_left
	attack_area.position.x = facing_direction * attack_offset_x
