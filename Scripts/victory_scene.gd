# victory_scene.gd - Ending screen shown after Mh'orzath is defeated
extends Control

const FONT_TITLE: FontFile = preload("res://Assets/Fonts/alagard_by_pix3m-d6awiwp.ttf")
const FONT_BODY: FontFile = preload("res://Assets/Fonts/_bitmap_font____romulus_by_pix3m-d6aokem.ttf")

func _ready() -> void:
	add_to_group("ui_hidden")
	get_tree().paused = true
	var ui := get_node_or_null("/root/UI")
	if ui:
		ui.visible = false
	Global.game_active = false
	Global.add_high_score(
		Global.current_score, "WIN",
		Global.current_wave, Global.coins_collected,
		Global.current_time_survived,
		Global.saved_villagers, Global.lost_villagers
	)
	_build_ui()

func _build_ui() -> void:
	# Dark cosmic background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bg)

	# Centered content column
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	margin.add_child(vbox)

	# THE ECLIPSE LIFTS.
	_label(vbox, "THE ECLIPSE LIFTS.", FONT_TITLE, 54, Color(1.0, 0.88, 0.30))
	_label(vbox, "LIGHT RETURNS TO LUMORA.", FONT_TITLE, 36, Color(1.0, 0.85, 0.42))
	_spacer(vbox, 22)

	# Boss defeated line
	_label(vbox, "MH'ORZATH HAS BEEN BANISHED.", FONT_TITLE, 28, Color(0.90, 0.18, 0.12))
	_spacer(vbox, 26)

	# Stats
	_label(vbox, "50 Villagers Saved", FONT_BODY, 24, Color(0.72, 1.0, 0.72))
	_label(vbox, "%d Waves Survived" % Global.current_wave, FONT_BODY, 24, Color(0.72, 0.88, 1.0))
	_spacer(vbox, 10)
	_label(vbox, "Final Score:       %d" % Global.current_score, FONT_BODY, 20, Color(1.0, 0.90, 0.50))
	_label(vbox, "Solari Collected:  %d" % Global.coins_collected, FONT_BODY, 20, Color(1.0, 0.90, 0.50))
	_label(vbox, "Time Survived:     %s" % Global.format_time(Global.current_time_survived), FONT_BODY, 20, Color(1.0, 0.90, 0.50))
	_spacer(vbox, 30)

	# Closing quote
	_label(vbox, '"The Eclipsed One is sealed once more...', FONT_TITLE, 18, Color(0.62, 0.60, 0.72))
	_label(vbox, ' but shadows have long memories."', FONT_TITLE, 18, Color(0.62, 0.60, 0.72))
	_spacer(vbox, 34)

	# THE END
	_label(vbox, "THE END", FONT_TITLE, 60, Color(1.0, 0.88, 0.30))
	_spacer(vbox, 32)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 48)
	btn_row.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(btn_row)

	var restart_btn := _button("Play Again")
	restart_btn.pressed.connect(_on_restart_pressed)
	btn_row.add_child(restart_btn)
	restart_btn.grab_focus()

	var quit_btn := _button("Quit")
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_row.add_child(quit_btn)

	# Cinematic fade-in from black
	var fade := ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(fade.queue_free)

func _label(parent: Node, text: String, font: FontFile, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(lbl)

func _spacer(parent: Node, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(s)

func _button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(190, 52)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	return btn

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.emit_signal("pressed")

func _on_restart_pressed() -> void:
	Global.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
