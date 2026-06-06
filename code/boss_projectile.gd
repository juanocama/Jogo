extends CharacterBody2D
class_name BossProjectile

@export var speed: float = 280.0
@export var damage: int = 15
@export var target_group: StringName = &"players"
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.LEFT

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT
	if anim_player != null and anim_player.has_animation(&"fly"):
		anim_player.play(&"fly")
	if sprite != null and direction.x > 0.0:
		sprite.flip_h = true
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()


func setup(new_direction: Vector2, new_damage: int, new_target_group: StringName = &"players") -> void:
	direction = new_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT
	damage = new_damage
	target_group = new_target_group


func _physics_process(delta: float) -> void:
	velocity = direction * speed
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		var body: Object = collision.get_collider()
		if body is Node and (body as Node).is_in_group(target_group) and (body as Node).has_method("take_damage"):
			(body as Node).call("take_damage", damage, self)
		queue_free()
