extends CharacterBody2D

@export var speed: float = 480.0
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	$AnimationPlayer.play("proyectil")
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

func _physics_process(delta: float) -> void:
	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider and collider.name == "ghost":
			return
		if collider and collider.name == "kid":
			get_tree().change_scene_to_file("res://scenes/pelea_test.tscn")
			return
		queue_free()
		return

	if abs(global_position.x) > 2000 or abs(global_position.y) > 1200:
		queue_free()
