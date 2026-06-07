extends Node

const ACTIVE_DURATION: float = 5.0
const FIRST_PHASE_ACTIVE_DURATION: float = 3.0
const REST_DURATION: float = 5.0
const FIRST_PHASE_TRIGGER_CHANCE: float = 0.28
const DELAY_SECONDS: float = 0.2
const ENTROPY_FADE_TIME: float = 0.35

@export var boss_path: NodePath
@export var player_path: NodePath
@export var camera_path: NodePath
@export var entropy_icon_path: NodePath
@export var entropy_background_path: NodePath
@export var automatic_enabled: bool = true
@export var delay_icon_texture: Texture2D
@export var invert_icon_texture: Texture2D
@export var flip_icon_texture: Texture2D
@export var delay_background_texture: Texture2D
@export var invert_background_texture: Texture2D
@export var flip_background_texture: Texture2D
@export var mixed_background_texture: Texture2D

var active_timer: float = 0.0
var rest_timer: float = 2.0
var active_effect: StringName = &""
var active_effects: Array[StringName] = []
var entropy_icons: Array[TextureRect] = []
var entropy_fade_tween: Tween = null

@onready var boss: Node = get_node_or_null(boss_path)
@onready var player: Node = get_node_or_null(player_path)
@onready var scene_camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var entropy_icon: TextureRect = get_node_or_null(entropy_icon_path) as TextureRect
@onready var entropy_background: Sprite2D = get_node_or_null(entropy_background_path) as Sprite2D


func _ready() -> void:
	if scene_camera != null:
		scene_camera.enabled = true
		scene_camera.ignore_rotation = false
		scene_camera.make_current()
	if entropy_icon != null:
		entropy_icons.append(entropy_icon)
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
	var effects: Array[StringName] = [effect_name]
	_start_effects(effects, duration)


func force_random_effect(duration: float = ACTIVE_DURATION) -> void:
	var effects: Array[StringName] = [&"delay", &"invert", &"flip"]
	force_effect(effects.pick_random(), duration)


func force_random_effects(count: int, duration: float = ACTIVE_DURATION) -> void:
	var effects: Array[StringName] = [&"delay", &"invert", &"flip"]
	effects.shuffle()
	var selected_effects: Array[StringName] = []
	for index: int in range(clampi(count, 1, effects.size())):
		selected_effects.append(effects[index])
	_clear_effect()
	_start_effects(selected_effects, duration)


func force_all_effects(duration: float = ACTIVE_DURATION) -> void:
	_clear_effect()
	var effects: Array[StringName] = [&"delay", &"invert", &"flip"]
	_start_effects(effects, duration)


func _start_effect(effect_name: StringName, forced_duration: float = -1.0) -> void:
	var effects: Array[StringName] = [effect_name]
	_start_effects(effects, forced_duration)


func _start_effects(effect_names: Array[StringName], forced_duration: float = -1.0) -> void:
	active_effects = effect_names.duplicate()
	active_effect = active_effects[0] if not active_effects.is_empty() else &""
	if forced_duration > 0.0:
		active_timer = forced_duration
	else:
		active_timer = FIRST_PHASE_ACTIVE_DURATION if active_effects.size() == 1 and active_effects.has(&"delay") else ACTIVE_DURATION

	_hide_entropy_icons()
	_apply_entropy_background()

	for effect_name: StringName in active_effects:
		match effect_name:
			&"delay":
				if player != null and player.has_method("apply_entropy_delay"):
					player.call("apply_entropy_delay", active_timer, DELAY_SECONDS)
			&"invert":
				if player != null and player.has_method("apply_entropy_invert"):
					player.call("apply_entropy_invert", active_timer)
			&"flip":
				_set_screen_rotation(PI)


func _apply_entropy_icons_style() -> void:
	if entropy_icon == null:
		return

	_ensure_entropy_icon_count(active_effects.size())
	for index: int in range(entropy_icons.size()):
		var icon: TextureRect = entropy_icons[index]
		var should_show: bool = index < active_effects.size()
		icon.visible = should_show
		icon.z_index = 90 + index
		if not should_show:
			continue
		_configure_entropy_icon(icon, active_effects[index])


func _ensure_entropy_icon_count(count: int) -> void:
	if entropy_icon == null:
		return
	while entropy_icons.size() < count:
		var new_icon: TextureRect = entropy_icon.duplicate() as TextureRect
		new_icon.visible = false
		entropy_icon.get_parent().add_child(new_icon)
		entropy_icons.append(new_icon)


func _configure_entropy_icon(icon: TextureRect, effect_name: StringName) -> void:
	icon.offset_left = entropy_icon.offset_left
	icon.offset_right = entropy_icon.offset_right
	icon.offset_top = entropy_icon.offset_top + float(entropy_icons.find(icon)) * 70.0
	icon.offset_bottom = entropy_icon.offset_bottom + float(entropy_icons.find(icon)) * 70.0
	match effect_name:
		&"delay":
			_apply_icon_texture(icon, delay_icon_texture)
			icon.modulate = Color(1.0, 0.58, 0.06, 1.0)
			icon.tooltip_text = "Entropia: retraso"
		&"invert":
			_apply_icon_texture(icon, invert_icon_texture)
			icon.modulate = Color(1.0, 0.35, 1.0, 1.0)
			icon.tooltip_text = "Entropia: controles invertidos"
		&"flip":
			_apply_icon_texture(icon, flip_icon_texture)
			icon.modulate = Color(0.45, 1.0, 0.1, 1.0)
			icon.tooltip_text = "Entropia: pantalla invertida"


func _apply_entropy_background() -> void:
	if entropy_background == null:
		return

	var texture: Texture2D = _get_entropy_background_texture()
	if texture == null:
		return

	entropy_background.texture = texture
	entropy_background.visible = true
	_fade_entropy_background(1.0)


func _get_entropy_background_texture() -> Texture2D:
	if active_effects.size() > 1:
		return mixed_background_texture

	match active_effect:
		&"delay":
			return delay_background_texture
		&"invert":
			return invert_background_texture
		&"flip":
			return flip_background_texture
	return null


func _fade_entropy_background(target_alpha: float) -> void:
	if entropy_background == null:
		return
	if entropy_fade_tween != null and entropy_fade_tween.is_running():
		entropy_fade_tween.kill()
	entropy_fade_tween = create_tween()
	entropy_fade_tween.tween_property(entropy_background, "modulate:a", target_alpha, ENTROPY_FADE_TIME)
	if target_alpha <= 0.0:
		entropy_fade_tween.tween_callback(Callable(self, "_hide_entropy_background"))


func _hide_entropy_background() -> void:
	if entropy_background != null:
		entropy_background.visible = false


func _hide_entropy_icons() -> void:
	for icon: TextureRect in entropy_icons:
		icon.visible = false
		icon.tooltip_text = ""


func _clear_effect() -> void:
	active_effect = &""
	active_effects.clear()
	active_timer = 0.0
	_hide_entropy_icons()
	_fade_entropy_background(0.0)
	_set_screen_rotation(0.0)


func _apply_icon_texture(icon: TextureRect, texture: Texture2D) -> void:
	if icon == null or texture == null:
		return
	icon.texture = texture


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
