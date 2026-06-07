extends Area2D

@export var lifetime: float = 2.0
@export var explosion_radius: float = 92.0
@export var launch_velocity: Vector2 = Vector2(80.0, -250.0)
@export var fall_gravity: float = 760.0
@export var floor_y: float = 313.0
@export var damage: int = 1

var velocity: Vector2 = Vector2.ZERO
var exploded: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var explosion_shape: CollisionShape2D = $CollisionShape2D


func setup(piece_texture: Texture2D, direction: int, spawn_floor_y: float) -> void:
	if sprite != null:
		sprite.texture = piece_texture
	floor_y = spawn_floor_y
	velocity = Vector2(launch_velocity.x * float(direction), launch_velocity.y)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if explosion_shape != null:
		explosion_shape.disabled = true
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(lifetime).timeout
	if is_inside_tree():
		_explode()


func _physics_process(delta: float) -> void:
	if exploded:
		return

	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	if global_position.y >= floor_y:
		global_position.y = floor_y
		velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
		velocity.y = min(velocity.y * -0.22, 0.0)


func _explode() -> void:
	if exploded:
		return

	exploded = true
	_play_sfx(&"robot_explosion", -5.0, 1.18)
	velocity = Vector2.ZERO
	if sprite != null:
		sprite.frame = maxi(0, sprite.hframes - 1)
		sprite.scale *= 1.25
	if explosion_shape != null:
		explosion_shape.disabled = false

	var tree: SceneTree = get_tree()
	if tree == null:
		queue_free()
		return

	for player_node: Node in tree.get_nodes_in_group("players"):
		if player_node is Node2D and global_position.distance_to((player_node as Node2D).global_position) <= explosion_radius:
			_damage_body(player_node)

	await tree.create_timer(0.18).timeout
	if is_inside_tree():
		queue_free()


func _on_body_entered(body: Node) -> void:
	if exploded:
		_damage_body(body)


func _damage_body(body: Node) -> void:
	if body != null and body.is_in_group("players") and body.has_method("take_damage"):
		body.call("take_damage", damage, self)


func _play_sfx(sfx_key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_key, volume_db, pitch_scale)
