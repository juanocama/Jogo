extends Node

const ACTIVE_DURATION: float = 5.0
const FIRST_PHASE_ACTIVE_DURATION: float = 3.0
const REST_DURATION: float = 5.0
const FIRST_PHASE_TRIGGER_CHANCE: float = 0.28
const DELAY_SECONDS: float = 0.5

@export var boss_path: NodePath
@export var player_path: NodePath
@export var camera_path: NodePath
@export var entropy_icon_path: NodePath

var active_timer: float = 0.0
var rest_timer: float = 2.0
var active_effect: StringName = &""

@onready var boss: Node = get_node_or_null(boss_path)
@onready var player: Node = get_node_or_null(player_path)
@onready var scene_camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var entropy_icon: TextureRect = get_node_or_null(entropy_icon_path) as TextureRect


func _ready() -> void:
	if scene_camera != null:
		scene_camera.enabled = true
		scene_camera.ignore_rotation = false
		scene_camera.make_current()
	_clear_effect()


func _process(delta: float) -> void:
	if boss == null or not boss.has_method("is_alive") or not bool(boss.call("is_alive")):
		_clear_effect()
		return

	if active_timer > 0.0:
		active_timer -= delta
		if active_timer <= 0.0:
			_clear_effect()
			rest_timer = REST_DURATION
		return

	rest_timer -= delta
	if rest_timer <= 0.0:
		_try_start_effect()


func _try_start_effect() -> void:
	var health_percent: float = _get_boss_health_percent()

	if health_percent > 0.4:
		if randf() > FIRST_PHASE_TRIGGER_CHANCE:
			rest_timer = REST_DURATION
			return
		_start_effect(&"delay")
	else:
		_start_effect(&"invert" if randf() < 0.5 else &"flip")


func _start_effect(effect_name: StringName) -> void:
	active_effect = effect_name
	active_timer = FIRST_PHASE_ACTIVE_DURATION if active_effect == &"delay" else ACTIVE_DURATION

	if entropy_icon != null:
		entropy_icon.visible = true
		match active_effect:
			&"delay":
				entropy_icon.modulate = Color(1.0, 0.58, 0.06, 1.0)
			&"invert":
				entropy_icon.modulate = Color(1.0, 0.35, 1.0, 1.0)
			&"flip":
				entropy_icon.modulate = Color(0.45, 1.0, 0.1, 1.0)

	match active_effect:
		&"delay":
			if player != null and player.has_method("apply_entropy_delay"):
				player.call("apply_entropy_delay", active_timer, DELAY_SECONDS)
		&"invert":
			if player != null and player.has_method("apply_entropy_invert"):
				player.call("apply_entropy_invert", active_timer)
		&"flip":
			_set_screen_rotation(PI)


func _clear_effect() -> void:
	active_effect = &""
	active_timer = 0.0
	if entropy_icon != null:
		entropy_icon.visible = false
	_set_screen_rotation(0.0)


func _set_screen_rotation(target_rotation: float) -> void:
	if scene_camera == null:
		return
	scene_camera.ignore_rotation = false
	scene_camera.rotation = target_rotation


func _get_boss_health_percent() -> float:
	var max_health_value: float = float(boss.get("max_health"))
	var health_value: float = float(boss.get("health"))
	if max_health_value <= 0.0:
		return 1.0
	return clampf(health_value / max_health_value, 0.0, 1.0)
