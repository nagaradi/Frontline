extends Node

const KILLS_TO_WIN: int = 10

var kills: int = 0
var game_over: bool = false


func add_kill() -> void:
	if game_over:
		return

	kills += 1
	print("KILLS: ", kills)
	if kills >= KILLS_TO_WIN:
		win_game()


func win_game() -> void:
	if game_over:
		return
	game_over = true
	print("VICTORY - FRONTLINE CLEARED")

	var game_over_ui = get_node_or_null("../GameOverUI")
	if game_over_ui != null and game_over_ui.has_method("show_victory"):
		game_over_ui.show_victory(kills)
	else:
		push_warning("GameOverUI victory screen method nahi mila.")


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
