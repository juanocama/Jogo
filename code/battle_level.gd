extends Node2D

@onready var camera: Camera2D = $Camera2D

var players: Array[Node] = []
var active_player_index: int = 0
var switch_lock: bool = false


func _ready() -> void:
	players = get_tree().get_nodes_in_group("players")
	_set_active_player(0)


func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_TAB):
		_switch_player_once()

	var active_player: Node2D = _get_active_player()
	if active_player != null and camera != null:
		camera.global_position = active_player.global_position.round()

	if _all_players_dead():
		get_tree().reload_current_scene()


func _switch_player_once() -> void:
	if switch_lock:
		return
	switch_lock = true
	_set_active_player((active_player_index + 1) % max(players.size(), 1))
	await get_tree().create_timer(0.25).timeout
	switch_lock = false


func _set_active_player(index: int) -> void:
	if players.is_empty():
		return
	active_player_index = clampi(index, 0, players.size() - 1)
	for i: int in range(players.size()):
		var player: Node = players[i]
		if player != null and player.has_method("set_controlled"):
			player.call("set_controlled", i == active_player_index)


func _get_active_player() -> Node2D:
	if players.is_empty():
		return null
	var player: Node = players[active_player_index]
	if player is Node2D:
		return player as Node2D
	return null


func _all_players_dead() -> bool:
	if players.is_empty():
		return false
	for player: Node in players:
		if player != null and player.has_method("is_alive") and bool(player.call("is_alive")):
			return false
	return true
