extends Node

var is_dialogue_active = false
var candies_collected: int = 0
var collected_candy_ids: Dictionary = {}
var final_battle_candy_dialogue_shown: bool = false


func collect_candy(candy_id: StringName) -> bool:
	if collected_candy_ids.has(candy_id):
		return false
	collected_candy_ids[candy_id] = true
	candies_collected += 1
	return true


func get_candy_count() -> int:
	return candies_collected


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
