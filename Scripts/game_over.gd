# game_over.gd - handles game over screen and high score input
extends Control

@onready var leader_board: VBoxContainer = $leader_board
@onready var initials_input: LineEdit = $initials_input
@onready var submit_button: Button = $submit_button
@onready var restart_button: Button = $restart_button

var current_score: int

func _ready() -> void:
	
	add_to_group("ui_hidden")

	get_tree().paused = true  # Ensure paused to freeze game
	
	if leader_board:
		leader_board.process_mode = Node.PROCESS_MODE_ALWAYS
	if initials_input:
		initials_input.process_mode = Node.PROCESS_MODE_ALWAYS
	if submit_button:
		submit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if restart_button:
		restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if $quit_button:
		$quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if not leader_board:
		push_error("GameOver: leader_board is null!")
	if not initials_input:
		push_error("GameOver: initials_input is null!")
	if not submit_button:
		push_error("GameOver: submit_button is null!")
	if not restart_button:
		push_error("GameOver: restart_button is null!")
	current_score = Global.current_score
	update_leader_board()
	if not Global.is_high_score(current_score):
		if initials_input:
			initials_input.hide()
		if submit_button:
			submit_button.hide()
	else:
		if initials_input:
			initials_input.grab_focus()
	# Pause the survival stopwatch
	Global.game_active = false

func update_leader_board() -> void:
	if not leader_board:
		push_error("GameOver: Cannot update leaderboard, leader_board is null!")
		return
	for i in range(10):
		var label: Label = leader_board.get_node_or_null("score_" + str(i + 1))
		if not label:
			push_error("GameOver: score_%d is null!" % (i + 1))
			continue
		if i < Global.high_scores.size():
			var entry: Dictionary = Global.high_scores[i]
			label.text = "%s - Score: %d | Coins: %d | Wave: %d | Saved: %d | Lost: %d | Time: %s" % [
				entry.initials, entry.score, entry.coins, entry.wave, entry.saved_villagers, entry.lost_villagers, Global.format_time(entry.time_survived)
			]
		else:
			label.text = "--- - Score: 0 | Coins: 0 | Wave: 0 | Saved: 0 | Lost: 0 | Time: 00:00"

# Handle initials submission
func _on_initials_input_text_submitted(new_text: String) -> void:
	if new_text.length() > 0:
		Global.add_high_score(current_score, new_text, Global.current_wave, Global.coins_collected, Global.current_time_survived, Global.saved_villagers, Global.lost_villagers)
		update_leader_board()
		if initials_input:
			initials_input.hide()
		if submit_button:
			submit_button.hide()
		if restart_button:
			restart_button.grab_focus()

# Handle submit button press
func _on_submit_button_pressed() -> void:
	if initials_input:
		var text: String = initials_input.text
		if text.length() > 0:
			Global.add_high_score(current_score, text, Global.current_wave, Global.coins_collected, Global.current_time_survived, Global.saved_villagers, Global.lost_villagers)
			update_leader_board()
			initials_input.hide()
			submit_button.hide()
			if restart_button:
				restart_button.grab_focus()

# Restart game
func _on_restart_button_pressed() -> void:
	Global.reset()
	get_tree().paused = false  # Unpause the game tree
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

# Quit game
func _on_quit_button_pressed() -> void:
	get_tree().quit()
