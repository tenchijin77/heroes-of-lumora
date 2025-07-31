#game_over.gd - handles game over screen and high score input
extends Control

@onready var leader_board : VBoxContainer = $leader_board
@onready var initials_input : LineEdit = $initials_input
@onready var submit_button : Button = $submit_button
@onready var restart_button : Button = $restart_button

var current_score : int

func _ready():
	get_tree().paused = false  # Ensure unpaused
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

func update_leader_board():
	if not leader_board:
		push_error("GameOver: Cannot update leaderboard, leader_board is null!")
		return
	for i in range(10):
		var label = leader_board.get_node_or_null("score_" + str(i + 1))
		if not label:
			push_error("GameOver: score_%d is null!" % (i + 1))
			continue
		if i < Global.high_scores.size():
			var entry = Global.high_scores[i]
			label.text = "%d. %s - %d" % [i + 1, entry.initials, entry.score]
		else:
			label.text = "%d. --- - 0" % [i + 1]
		print("GameOver: Updated score_%d text: %s" % [i + 1, label.text])

func _on_initials_input_text_submitted(new_text: String):
	if new_text.length() > 0:
		Global.add_high_score(current_score, new_text)
		update_leader_board()
		if initials_input:
			initials_input.hide()
		if submit_button:
			submit_button.hide()
		if restart_button:
			restart_button.grab_focus()

func _on_submit_button_pressed():
	if initials_input:
		var text = initials_input.text
		if text.length() > 0:
			Global.add_high_score(current_score, text)
			update_leader_board()
			initials_input.hide()
			submit_button.hide()
			if restart_button:
				restart_button.grab_focus()

func _on_restart_button_pressed():
	Global.reset()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
