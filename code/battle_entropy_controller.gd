extends Node

const ACTIVE_DURATION: float = 5.0
const FIRST_PHASE_ACTIVE_DURATION: float = 3.0
const REST_DURATION: float = 5.0
const FIRST_PHASE_TRIGGER_CHANCE: float = 0.28
const DELAY_SECONDS: float = 0.3

@export var boss_path: NodePath
@export var player_path: NodePath
@export var camera_path: NodePath
@export var entropy_icon_path: NodePath
@export var automatic_enabled: bool = true
@export var delay_icon_texture: Texture2D
@export var invert_icon_texture: Texture2D
@export var flip_icon_texture: Texture2D

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
	if not automatic_enabled:
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


func force_effect(effect_name: StringName, duration: float = ACTIVE_DURATION) -> void:
	_clear_effect()
	_start_effect(effect_name, duration)


func force_random_effect(duration: float = ACTIVE_DURATION) -> void:
	var effects: Array[StringName] = [&"delay", &"invert", &"flip"]
	force_effect(effects.pick_random(), duration)


func _start_effect(effect_name: StringName, forced_duration: float = -1.0) -> void:
	active_effect = effect_name
	if forced_duration > 0.0:
		active_timer = forced_duration
	else:
		active_timer = FIRST_PHASE_ACTIVE_DURATION if active_effect == &"delay" else ACTIVE_DURATION

	if entropy_icon != null:
		entropy_icon.visible = true
		entropy_icon.z_index = 90
		match active_effect:
			&"delay":
				_apply_icon_texture(delay_icon_texture)
				entropy_icon.modulate = Color(1.0, 0.58, 0.06, 1.0)
				entropy_icon.tooltip_text = "Entropia: retraso"
			&"invert":
				_apply_icon_texture(invert_icon_texture)
				entropy_icon.modulate = Color(1.0, 0.35, 1.0, 1.0)
				entropy_icon.tooltip_text = "Entropia: controles invertidos"
			&"flip":
				_apply_icon_texture(flip_icon_texture)
				entropy_icon.modulate = Color(0.45, 1.0, 0.1, 1.0)
				entropy_icon.tooltip_text = "Entropia: pantalla invertida"

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
		entropy_icon.tooltip_text = ""
	_set_screen_rotation(0.0)


func _apply_icon_texture(texture: Texture2D) -> void:
	if entropy_icon == null or texture == null:
		return
	entropy_icon.texture = texture


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
