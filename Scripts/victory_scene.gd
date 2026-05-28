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
	Global.killer_name = "victory"
	_build_ui()
	_play_victory_music()

func _play_victory_music() -> void:
	var stream := load("res://Assets/Audio/monument_music-keys-of-wisdom-266235.mp3") as AudioStreamMP3
	if stream:
		stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -2.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()

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

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	scroll.add_child(vbox)

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
	_spacer(vbox, 40)

	# ═══════════════════════════════════════════════════════════════════════
	# DEVELOPER THANK YOU MESSAGE
	# ═══════════════════════════════════════════════════════════════════════
	_label(vbox, "Thank you for playing Heroes of Lumora!", FONT_TITLE, 22, Color(1.0, 0.95, 0.70))
	_spacer(vbox, 16)
	
	# Create a panel for the message text with word wrap
	var message_panel := PanelContainer.new()
	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Semi-transparent dark panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.03, 0.10, 0.7)
	panel_style.border_color = Color(0.40, 0.35, 0.50, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	message_panel.add_theme_stylebox_override("panel", panel_style)
	vbox.add_child(message_panel)
	
	var message_label := RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.custom_minimum_size = Vector2(700, 0)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.add_theme_font_override("normal_font", FONT_BODY)
	message_label.add_theme_font_size_override("normal_font_size", 18)
	message_label.add_theme_color_override("default_color", Color(0.88, 0.85, 0.90))
	message_label.process_mode = Node.PROCESS_MODE_ALWAYS
	
	message_label.text = """As a solo developer learning the craft of game creation, this project has been an incredible journey of discovery. Every system, every character, every wave you survived—it all came together through experimentation, perseverance, and genuine passion for bringing this world to life.

Heroes of Lumora is my first game, but it won't be my last. This story is a window into Aldenexia—a world I'm building for my next project, [color=#FFD700]Aldenexia: Lightfall[/color]. The characters you met here, the darkness you fought, and the light you defended are all threads in a much larger tapestry.

I hope you'll join me in Aldenexia when the full story unfolds.

Thank you for defending Lumora.

[color=#B8B080]- Ross Wilkinson[/color]"""
	
	message_panel.add_child(message_label)
	_spacer(vbox, 32)
	# ═══════════════════════════════════════════════════════════════════════

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 48)
	btn_row.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(btn_row)

	var restart_btn := _button("The Wall of Heroes")
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
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
