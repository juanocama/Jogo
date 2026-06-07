extends Node

var is_dialogue_active = false
var candies_collected: int = 0
var collected_candy_ids: Dictionary = {}
var final_battle_candy_dialogue_shown: bool = false
var final_battle_attempt_candies: int = 0


func collect_candy(candy_id: StringName) -> bool:
	if collected_candy_ids.has(candy_id):
		return false
	collected_candy_ids[candy_id] = true
	candies_collected += 1
	return true


func get_candy_count() -> int:
	return candies_collected


func begin_final_battle_attempt() -> void:
	final_battle_attempt_candies = candies_collected


func use_final_battle_recovery_candy(current_hearts: int, max_hearts: int) -> int:
	if final_battle_attempt_candies <= 0:
		return current_hearts
	if current_hearts >= max_hearts:
		return current_hearts
	final_battle_attempt_candies -= 1
	return mini(max_hearts, current_hearts + 2)


func build_final_battle_candy_dialogue() -> String:
	var dialogue_text: String = "~ start\n"
	dialogue_text += "ELIO: me quedan...\n"
	dialogue_text += "ELIO: " + str(candies_collected) + " dulces\n"
	if candies_collected > 0:
		dialogue_text += "ELIO: esto deberia funcionar para recuperarme un poco\n"
	dialogue_text += "=> END\n"
	return dialogue_text


func should_show_final_battle_candy_dialogue() -> bool:
	return not final_battle_candy_dialogue_shown


func mark_final_battle_candy_dialogue_shown() -> void:
	final_battle_candy_dialogue_shown = true
