# game_over2.gd - handles game over screen and high score display
extends Control

@onready var leader_board: VBoxContainer = $leader_board
@onready var restart_button: Button = $restart_button

func _ready() -> void:
	add_to_group("ui_hidden")
	get_tree().paused = true  # Ensure paused to freeze game
	if leader_board:
		leader_board.process_mode = Node.PROCESS_MODE_ALWAYS
	if restart_button:
		restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if $quit_button:
		$quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if not leader_board:
		push_error("GameOver2: leader_board is null!")
	if not restart_button:
		push_error("GameOver2: restart_button is null!")
	update_leader_board()
	# Pause the survival stopwatch
	Global.game_active = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var focused_control = get_viewport().gui_get_focus_owner()
		if focused_control:
			if focused_control == restart_button:
				_on_restart_button_pressed()

func update_leader_board() -> void:
	if not leader_board:
		push_error("GameOver2: Cannot update leaderboard, leader_board is null!")
		return
	for i in range(10):
		var label: Label = leader_board.get_node_or_null("score_" + str(i + 1))
		if not label:
			push_error("GameOver2: score_%d is null!" % (i + 1))
			continue
		if i < Global.high_scores.size():
			var entry: Dictionary = Global.high_scores[i]
			label.text = "%s - Score: %d | Coins: %d | Wave: %d | Saved: %d | Lost: %d | Time: %s" % [
				entry.initials, entry.score, entry.coins, entry.wave, entry.saved_villagers, entry.lost_villagers, Global.format_time(entry.time_survived)
			]
		else:
			label.text = "--- - Score: 0 | Coins: 0 | Wave: 0 | Saved: 0 | Lost: 0 | Time: 00:00"

# Restart game
func _on_restart_button_pressed() -> void:
	Global.reset()
	get_tree().paused = false  # Unpause the game tree
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

# Quit game
func _on_quit_button_pressed() -> void:
	get_tree().quit()
