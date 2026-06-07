extends Node

@export var player_path: NodePath
@export var robot_path: NodePath
@export var mirror_path: NodePath
@export var timer_label_path: NodePath
@export var exit_door_path: NodePath
@export_file("*.tscn") var exit_target_scene: String = "res://scenes/Hallway.tscn"
@export var level_duration: float = 60.0
@export var robot_vision_range: float = 520.0
@export var robot_detection_interval: float = 0.8
@export var robot_detection_probability: float = 0.9
@export var robot_hidden_inspection_delay: float = 5.0
@export var robot_confused_duration_multiplier: float = 0.4
@export var robot_confused_speed_multiplier: float = 0.85
@export var robot_close_visible_detection_range: float = 240.0

@onready var player: Node2D = get_node(player_path) as Node2D
@onready var robot: CharacterBody2D = get_node(robot_path) as CharacterBody2D
@onready var mirror: Area2D = get_node(mirror_path) as Area2D
@onready var timer_label: Label = get_node(timer_label_path) as Label
@onready var exit_door: Area2D = get_node_or_null(exit_door_path) as Area2D

var active: bool = false
var finished: bool = false
var time_left: float = 60.0
var current_hidden_spot: Area2D
var spots: Array[Area2D] = []


func _ready() -> void:
	time_left = level_duration
	if exit_door != null and exit_door.has_method("set_enabled"):
		exit_door.call("set_enabled", false)
	_collect_spots()
	_connect_mirror()
	_connect_exit_door()
	_setup_robot()
	_update_timer_label()
	if timer_label != null:
		timer_label.visible = false


func _process(delta: float) -> void:
	if not active:
		return
	if finished:
		return

	time_left = maxf(time_left - delta, 0.0)
	_update_timer_label()
	if time_left <= 0.0:
		_start_victory_exit()


func get_current_hidden_spot() -> Area2D:
	return current_hidden_spot


func start_stealth_sequence() -> void:
	if active:
		return

	active = true
	finished = false
	time_left = level_duration
	current_hidden_spot = null
	if timer_label != null:
		timer_label.visible = true
	for spot: Area2D in spots:
		if spot.has_method("set_level_active"):
			spot.call("set_level_active", true)
		if spot.has_method("set_targeted"):
			spot.call("set_targeted", false)
	if robot != null and robot.has_method("begin_entry"):
		robot.call("begin_entry")
	_update_timer_label()


func request_hide(spot: Area2D) -> void:
	if not active or finished:
		return
	if current_hidden_spot != null:
		return
	if player == null:
		return
	if player.has_method("hide_in_bathroom"):
		var hide_position: Vector2 = spot.global_position
		if spot.has_method("get_hide_position"):
			hide_position = spot.call("get_hide_position")
		await player.call("hide_in_bathroom", hide_position)
		current_hidden_spot = spot
		if spot.has_method("set_player_hidden_here"):
			spot.call("set_player_hidden_here", true)
		if robot != null and robot.has_method("notify_player_hidden"):
			robot.call("notify_player_hidden", spot)


func request_unhide(spot: Area2D) -> void:
	if (not active and not finished):
		return
	if current_hidden_spot != spot:
		return
	if player == null:
		return
	if player.has_method("unhide_from_bathroom"):
		var exit_position: Vector2 = spot.global_position
		if spot.has_method("get_exit_position"):
			exit_position = spot.call("get_exit_position")
		await player.call("unhide_from_bathroom", exit_position)
		if spot.has_method("set_player_hidden_here"):
			spot.call("set_player_hidden_here", false)
		if spot.has_method("set_targeted"):
			spot.call("set_targeted", false)
		current_hidden_spot = null
		if finished:
			_disable_hiding_spots()


func defeat() -> void:
	if finished:
		return
	finished = true
	active = false
	get_tree().reload_current_scene()


func complete_victory() -> void:
	if not finished:
		return
	if current_hidden_spot == null:
		_disable_hiding_spots()
	if timer_label != null:
		timer_label.visible = false
	print("Nivel de sigilo completado")
	_enable_exit_door()


func _collect_spots() -> void:
	spots.clear()
	for spot_node: Node in get_tree().get_nodes_in_group("hiding_spots"):
		if spot_node is Area2D:
			var spot: Area2D = spot_node as Area2D
			spots.append(spot)
			if spot.has_signal("hide_requested"):
				spot.connect("hide_requested", Callable(self, "_on_hide_requested"))
			if spot.has_signal("unhide_requested"):
				spot.connect("unhide_requested", Callable(self, "_on_unhide_requested"))
			if spot.has_method("set_level_active"):
				spot.call("set_level_active", false)


func _connect_mirror() -> void:
	if mirror == null:
		return
	if mirror.has_signal("sad_bathroom_activated"):
		mirror.connect("sad_bathroom_activated", Callable(self, "_on_sad_bathroom_activated"))


func _connect_exit_door() -> void:
	if exit_door == null:
		return
	if exit_door.has_signal("interacted"):
		var callback: Callable = Callable(self, "_on_exit_door_interacted")
		if not exit_door.is_connected("interacted", callback):
			exit_door.connect("interacted", callback)


func _setup_robot() -> void:
	if robot == null:
		return
	if not robot.has_method("setup"):
		return

	var patrol_points: Array[Vector2] = [
		Vector2(110, 500),
		Vector2(360, 470),
		Vector2(610, 505),
		Vector2(850, 470),
		Vector2(1050, 505)
	]
	robot.set("vision_range", robot_vision_range)
	robot.set("detection_interval", robot_detection_interval)
	robot.set("detection_probability", robot_detection_probability)
	robot.set("hidden_inspection_delay", robot_hidden_inspection_delay)
	robot.set("confused_duration_multiplier", robot_confused_duration_multiplier)
	robot.set("confused_speed_multiplier", robot_confused_speed_multiplier)
	robot.set("close_visible_detection_range", robot_close_visible_detection_range)
	robot.call("setup", self, player, patrol_points)


func _start_victory_exit() -> void:
	finished = true
	active = false
	for spot: Area2D in spots:
		if spot.has_method("set_targeted"):
			spot.call("set_targeted", false)
	if robot != null and robot.has_method("start_exit"):
		robot.call("start_exit")


func _disable_hiding_spots() -> void:
	for spot: Area2D in spots:
		if spot.has_method("set_level_active"):
			spot.call("set_level_active", false)
		if spot.has_method("set_targeted"):
			spot.call("set_targeted", false)


func _enable_exit_door() -> void:
	if exit_door != null and exit_door.has_method("set_enabled"):
		exit_door.call("set_enabled", true)


func _update_timer_label() -> void:
	if timer_label == null:
		return

	var remaining: int = int(ceilf(time_left))
	timer_label.text = "00:%02d" % remaining


func _on_sad_bathroom_activated() -> void:
	start_stealth_sequence()


func _on_hide_requested(spot: Area2D) -> void:
	request_hide(spot)


func _on_unhide_requested(spot: Area2D) -> void:
	request_unhide(spot)


func _on_exit_door_interacted(action: StringName) -> void:
	if action != &"bathroom_exit_door":
		return
	if not finished:
		return
	if exit_target_scene != "":
		get_tree().change_scene_to_file(exit_target_scene)
