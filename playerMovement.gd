extends CharacterBody2D

# Movimiento simple para probar el escenario.
# Sin vida, sin daño y sin combate por ahora.

const SPEED: float = 210.0
const JUMP_VELOCITY: float = -420.0
const GRAVITY: float = 980.0

@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var sprite2D: Sprite2D = $Sprite2D
@onready var camera2D: Camera2D = $Camera2D

var jump_was_pressed: bool = false


func _ready() -> void:
	# Los robots buscan nodos en el grupo "players".
	# Esto NO agrega vida ni daño; solo permite que sepan a quién seguir.
	add_to_group("players")

	if camera2D:
		camera2D.make_current()

	_play_animation("idle")


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement()
	move_and_slide()
	_update_animation()
	global_position = global_position.round()


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


func _handle_horizontal_movement() -> void:
	var direction: float = _get_horizontal_direction()

	if direction != 0.0:
		velocity.x = direction * SPEED
		if sprite2D:
			sprite2D.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)


func _get_horizontal_direction() -> float:
	var direction: float = 0.0

	# Funciona aunque el Input Map del proyecto no esté configurado.
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction += 1.0

	return clamp(direction, -1.0, 1.0)


func _is_jump_pressed() -> bool:
	return (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_UP)
		or Input.is_key_pressed(KEY_W)
	)


func _update_animation() -> void:
	if not animationPlayer:
		return

	if not is_on_floor():
		if velocity.y < 0.0:
			_play_animation("Jump")
		else:
			_play_animation("Fall")
		return

	if abs(velocity.x) > 1.0:
		_play_animation("Run")
	else:
		_play_animation("idle")


func _play_animation(animation_name: StringName) -> void:
	if not animationPlayer:
		return
	if not animationPlayer.has_animation(animation_name):
		return
	if animationPlayer.current_animation != animation_name:
		animationPlayer.play(animation_name)


func is_alive() -> bool:
	# Solo para compatibilidad con la IA de los robots.
	# No significa que el personaje tenga sistema de vida todavía.
	return true
