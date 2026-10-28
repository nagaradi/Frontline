
extends Node

var kills: int = 0
var game_over: bool = false


func add_kill() -> void:
	if game_over:
		return

	kills += 1
	print("KILLS: ", kills)


func end_game() -> void:
	if game_over:
		return

	game_over = true
	print("GAME OVER - YOU WERE DEFEATED")

	var game_over_ui = get_node_or_null("../GameOverUI")

	if game_over_ui != null:
		game_over_ui.show_game_over(kills)
	else:
		push_warning("GameOverUI node nahi mila.")
