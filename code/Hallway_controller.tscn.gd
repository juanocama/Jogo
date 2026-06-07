extends Node

@export var bath_door_dialogue_resource: DialogueResource
@export var gun_pickup_dialogue_resource: DialogueResource
@export var candy_dialogue_resource: DialogueResource

var dialogue_running: bool = false
var completed_actions: Dictionary = {}


func _ready() -> void:
	_connect_action_interactables()


func handle_action(action: StringName) -> void:
	if completed_actions.has(action):
		return

	match action:
		&"bath_door_in":
			await _show_dialogue_for_action(action, bath_door_dialogue_resource)
		&"gun_pickup":
			await _show_dialogue_for_action(action, gun_pickup_dialogue_resource)
		&"candy_2":
			await _show_dialogue_for_action(action, candy_dialogue_resource)


func _show_dialogue_for_action(action: StringName, resource: DialogueResource) -> void:
	if resource == null:
		return

	completed_actions[action] = true
	_disable_action(action)
	await _show_dialogue(resource)


func _show_dialogue(resource: DialogueResource) -> void:
	if dialogue_running or GameManager.is_dialogue_active:
		return

	dialogue_running = true
	GameManager.is_dialogue_active = true
	DialogueManager.show_dialogue_balloon(resource)
	await DialogueManager.dialogue_ended
	await get_tree().create_timer(0.2).timeout
	GameManager.is_dialogue_active = false
	dialogue_running = false


func _connect_action_interactables() -> void:
	for node: Node in get_tree().get_nodes_in_group("classroom_actions"):
		if node.has_signal("interacted"):
			var callback: Callable = Callable(self, "handle_action")
			if not node.is_connected("interacted", callback):
				node.connect("interacted", callback)


func _disable_action(action: StringName) -> void:
	for node: Node in get_tree().get_nodes_in_group("classroom_actions"):
		if not node.has_method("set_enabled"):
			continue

		var node_action: StringName = StringName(node.get("action"))
		if node_action == action:
			node.call("set_enabled", false)
