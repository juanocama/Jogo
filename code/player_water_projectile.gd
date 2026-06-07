extends Area2D

@export var speed: float = 430.0
@export var damage_percent: float = 0.05
@export var lifetime: float = 1.35

var direction: Vector2 = Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if sprite != null:
		sprite.flip_h = direction.x < 0.0
	if anim_player != null and anim_player.has_animation(&"fly"):
		anim_player.play(&"fly")

	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()


func setup(new_direction: Vector2, new_damage_percent: float = 0.05) -> void:
	direction = new_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	damage_percent = new_damage_percent


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("bosses") and body.has_method("take_damage"):
		var max_health_value: int = int(body.get("max_health"))
		var damage: int = maxi(1, int(round(float(max_health_value) * damage_percent)))
		body.call("take_damage", damage, self)
		queue_free()
