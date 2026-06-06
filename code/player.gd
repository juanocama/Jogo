extends CharacterBody2D

@export var speed: float = 150.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 700.0
@export var floor_drag: float = 500.0

func _physics_process(delta: float) -> void:
	
	if GameManager.is_dialogue_active:
		return
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	var input_dir = 0
	if left and not right:
		input_dir = -1
	elif right and not left:
		input_dir = 1

	velocity.x = move_toward(velocity.x, input_dir * speed, floor_drag * delta)

	if is_on_floor():	
		if Input.is_action_just_pressed("ui_up"):
			velocity.y = jump_velocity

	velocity.y += gravity * delta
	move_and_slide()
