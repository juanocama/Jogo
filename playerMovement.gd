extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -600.0

@onready var animationPlayer=$AnimationPlayer
@onready var sprite2D=$Sprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	animations(direction)
	
	if direction ==1:
		sprite2D.flip_h =false
	elif direction ==-1:
		sprite2D.flip_h =true
		
func animations(direction): #Animacion por defecto si el jugador no hace nada
	if is_on_floor():
		if direction==0: #si detecta que no se mueve
			animationPlayer.play("idle") #pone la animacion idle
		else:
			animationPlayer.play("Run")
	else: 
		if velocity.y<0:
			animationPlayer.play("Jump")
		elif velocity.y>0:
			animationPlayer.play("Fall")
			
