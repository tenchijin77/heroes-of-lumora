# ui.gd - manages persistent UI elements across all scenes
extends CanvasLayer

@onready var wave_label: Label = $VBoxContainer/wave
@onready var uptime_label: Label = $VBoxContainer/uptime
@onready var score_label: Label = $VBoxContainer/score
@onready var coin_label: Label = $VBoxContainer/coins
@onready var saved_villagers_label: Label = $VBoxContainer/saved_villagers
@onready var lost_villagers_label: Label = $VBoxContainer/lost_villagers
@onready var remaining_villagers_label: Label = $VBoxContainer/remaining_villagers
@onready var time_label: Label = $VBoxContainer/time_label
@onready var date_label: Label = $VBoxContainer/date_label
@onready var touch_controls: Node = $touch_controls
@onready var player_damage: Label = $stats_container/player_damage
@onready var player_speed: Label = $stats_container/player_speed
@onready var player_health: Label = $stats_container/player_health
@onready var pause_overlay: ColorRect = $pause_overlay
@onready var resume_button: Button = $pause_overlay/pause_panel/VBoxContainer/resume_button

var is_paused: bool = false
var _night_overlay: ColorRect
var _chat_panel: Panel = null
var _chat_scroll: ScrollContainer = null
var _chat_vbox: VBoxContainer = null
var _chat_input: LineEdit = null
const CHAT_MAX_MESSAGES: int = 50
const CHAT_WIDTH: float = 380.0
const CHAT_HEIGHT: float = 180.0
const CHAT_MARGIN: float = 10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	pause_overlay.visible = false
	_setup_night_overlay()
	_update_all()
	Global.wave_updated.connect(_update_wave)
	Global.time_updated.connect(_update_time)
	Global.score_updated.connect(_update_score)
	Global.coins_updated.connect(_update_coins)
	Global.villagers_updated.connect(_update_villagers)
	TimeManager.connect("time_updated", _on_time_updated)
	_on_time_updated(TimeManager.current_time)
	# Connect to node_added signal
	get_tree().node_added.connect(_on_node_added)
	_check_scene()
	# Initialize touch controls visibility
	_toggle_touch_controls()
	_setup_chat_box()
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_connect_player(player)
		
func _setup_night_overlay() -> void:
	_night_overlay = ColorRect.new()
	_night_overlay.name = "night_overlay"
	_night_overlay.color = Color(0.0, 0.02, 0.08, 0.0)  # Deep moonless-night blue, starts transparent
	_night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_night_overlay)
	move_child(_night_overlay, 0)  # First child = renders behind all other UI elements

func set_night_alpha(alpha: float) -> void:
	if _night_overlay:
		_night_overlay.color.a = alpha

func get_night_alpha() -> float:
	return _night_overlay.color.a if _night_overlay else 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT:
			if _chat_panel:
				_chat_panel.visible = not _chat_panel.visible
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		var current_scene: Node = get_tree().current_scene
		if current_scene and current_scene.name == "main":
			_toggle_pause()

func _toggle_pause() -> void:
	if is_paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	pause_overlay.visible = true
	Global.game_active = false
	is_paused = true
	resume_button.grab_focus()

func _resume_game() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	Global.game_active = true
	is_paused = false

func _on_resume_button_pressed() -> void:
	_resume_game()

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	pause_overlay.visible = false
	visible = false
	Global.reset()
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _check_scene() -> void:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "main":
		visible = true
	else:
		visible = false
	_toggle_touch_controls()

func _on_node_added(node: Node) -> void:
	if node.name in ["main_menu", "intro_scene", "game_over", "game_over2", "shop_zone"]:
		visible = false
		is_paused = false
		pause_overlay.visible = false
	if node.is_in_group("ui_hidden"):
		visible = false
	if node.name == "main":
		visible = true
		saved_villagers_label.visible = not Global.is_endless_mode
		lost_villagers_label.visible = not Global.is_endless_mode
		remaining_villagers_label.visible = not Global.is_endless_mode
	if node.is_in_group("player"):
		_connect_player(node)
	_toggle_touch_controls()

func _update_all() -> void:
	_update_wave(Global.current_wave)
	_update_time(Global.format_time(Global.current_time_survived))
	_update_score(Global.current_score)
	_update_coins(Global.coins_collected)
	_update_villagers(Global.saved_villagers, Global.lost_villagers, Global.total_villagers)

func _update_wave(wave: int) -> void:
	wave_label.text = "Current Wave: %d" % wave

func _update_time(time: String) -> void:
	uptime_label.text = "Time Survived: %s" % time

func _update_score(score: int) -> void:
	score_label.text = "Score: %d" % score

func _update_coins(coins: int) -> void:
	coin_label.text = "Solari: %d" % coins

func _update_villagers(saved: int, lost: int, total: int) -> void:
	saved_villagers_label.text = "Villagers Saved: %d" % saved
	lost_villagers_label.text = "Villagers Lost: %d" % lost
	remaining_villagers_label.text = "Still Needed: %d" % max(0, total - saved)

func _update_player_damage(damage: float) -> void:
	if player_damage:
		player_damage.text = "Damage: 🗡️ %.1f" % damage
	else:
		push_error("UI: player_damage label is null!")

func _update_player_speed(speed: float) -> void:
	if player_speed:
		player_speed.text = "Speed: 👟 %.1f" % speed
	else:
		push_error("UI: player_speed label is null!")

func _update_player_health(current: int, max: int) -> void:
	if player_health:
		player_health.text = "Health: ❤️ %d/%d" % [current, max]
	else:
		push_error("UI: player_health label is null!")

func _on_time_updated(current_time: float) -> void:
	time_label.text = TimeManager.get_time_string()
	#date_label.text = TimeManager.get_date_string() # removed as is not needed for game play

func _toggle_touch_controls() -> void:
	if touch_controls and is_instance_valid(touch_controls):
		if not OS.has_feature("touchscreen"):
			touch_controls.visible = false
			touch_controls.process_mode = PROCESS_MODE_DISABLED
		else:
			touch_controls.visible = visible
			touch_controls.process_mode = PROCESS_MODE_INHERIT if visible else PROCESS_MODE_DISABLED

func show_announcement(text: String, duration: float = 5.0) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 8)
	label.size = Vector2(vp_size.x * 0.8, 120)
	label.position = Vector2(vp_size.x * 0.1, vp_size.y * 0.36)
	label.modulate.a = 0.0
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(duration - 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _connect_player(player) -> void:
	if not player.damage_updated.is_connected(_update_player_damage):
		player.damage_updated.connect(_update_player_damage)
	if not player.speed_updated.is_connected(_update_player_speed):
		player.speed_updated.connect(_update_player_speed)
	if not player.health_updated.is_connected(_update_player_health):
		player.health_updated.connect(_update_player_health)

	_update_player_damage(player.base_damage * player.damage_modifier)
	_update_player_speed(player.max_speed)
	_update_player_health(player.current_health, player.max_health)

func _setup_chat_box() -> void:
	_chat_panel = Panel.new()
	_chat_panel.name = "chat_panel"
	_chat_panel.position = Vector2(CHAT_MARGIN, 648.0 - CHAT_HEIGHT - CHAT_MARGIN)
	_chat_panel.size = Vector2(CHAT_WIDTH, CHAT_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_chat_panel.add_theme_stylebox_override("panel", style)
	_chat_panel.visible = false
	add_child(_chat_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4.0
	vbox.offset_right = -4.0
	vbox.offset_top = 4.0
	vbox.offset_bottom = -4.0
	vbox.add_theme_constant_override("separation", 2)
	_chat_panel.add_child(vbox)

	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_chat_scroll)

	_chat_vbox = VBoxContainer.new()
	_chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_vbox.add_theme_constant_override("separation", 1)
	_chat_scroll.add_child(_chat_vbox)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "/ for commands"
	_chat_input.add_theme_font_size_override("font_size", 12)
	_chat_input.text_submitted.connect(_on_chat_submitted)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	input_style.corner_radius_top_left = 3
	input_style.corner_radius_top_right = 3
	input_style.corner_radius_bottom_left = 3
	input_style.corner_radius_bottom_right = 3
	_chat_input.add_theme_stylebox_override("normal", input_style)
	_chat_input.add_theme_stylebox_override("focus", input_style)
	vbox.add_child(_chat_input)

func chat_add(text: String, speaker: String = "") -> void:
	if not _chat_vbox or not is_instance_valid(_chat_vbox):
		return
	var full_text := "[%s]: %s" % [speaker, text] if speaker != "" else text
	var label := Label.new()
	label.text = full_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)
	var color := Color(1.0, 1.0, 0.85, 1.0)
	match speaker:
		"System":    color = Color(0.65, 0.65, 0.65, 1.0)
		"Tenchijin": color = Color(1.0, 0.25, 0.25, 1.0)
		"Annadaeus": color = Color(0.5, 0.85, 1.0, 1.0)
		"Messenger": color = Color(1.0, 1.0, 0.3, 1.0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_vbox.add_child(label)
	# remove_child first so get_child_count() drops immediately — queue_free() alone doesn't
	if _chat_vbox.get_child_count() > CHAT_MAX_MESSAGES:
		var old := _chat_vbox.get_child(0)
		_chat_vbox.remove_child(old)
		old.queue_free()
	call_deferred("_scroll_chat_to_bottom")

func _scroll_chat_to_bottom() -> void:
	if _chat_scroll and is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)

func _on_chat_submitted(text: String) -> void:
	_chat_input.clear()
	_chat_input.release_focus()
	var trimmed := text.strip_edges()
	if trimmed == "":
		return
	if trimmed.begins_with("/"):
		_handle_command(trimmed)
	else:
		chat_add(trimmed, "You")

func _handle_command(text: String) -> void:
	var parts := text.split(" ", false)
	var cmd := parts[0].to_lower()
	match cmd:
		"/help":
			chat_add("/kill — kill all monsters on screen", "System")
			chat_add("/spawn <name> — spawn a monster (skeleton, wizard, goblin, ghost, ogre, lich...)", "System")
			chat_add("/heal [amount] — heal the player (default 100)", "System")
			chat_add("/coins [amount] — add coins (default 100)", "System")
			chat_add("/wave [n] — jump to wave n", "System")
			chat_add("/set_health <n> — set player health to n", "System")
			chat_add("/set_speed <n> — set player move speed to n", "System")
			chat_add("/set_damage <n> — set player projectile damage to n", "System")
			chat_add("/set_solari <n> — set coin total to n", "System")
			chat_add("/set_saved <n> — set villagers saved count to n", "System")
			chat_add("/set_godmode — toggle invincibility", "System")
		"/kill":
			var killed := 0
			for mob in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(mob) and mob.visible and mob.has_method("take_damage"):
					mob.take_damage(99999, null)
					killed += 1
			chat_add("Killed %d monsters." % killed, "System")
		"/spawn":
			_spawn_enemy(parts[1].to_lower() if parts.size() > 1 else "skeleton")
		"/heal":
			var amount := int(parts[1]) if parts.size() > 1 else 100
			var p := get_tree().get_first_node_in_group("player")
			if p and p.has_method("heal"):
				p.heal(amount)
				chat_add("Healed player for %d HP." % amount, "System")
			else:
				chat_add("Player not found.", "System")
		"/coins":
			var amount := int(parts[1]) if parts.size() > 1 else 100
			Global.coins_collected += amount
			Global.emit_signal("coins_updated", Global.coins_collected)
			chat_add("Added %d coins. Total: %d" % [amount, Global.coins_collected], "System")
		"/wave":
			if parts.size() > 1:
				Global.current_wave = int(parts[1])
				Global.emit_signal("wave_updated", Global.current_wave)
				chat_add("Wave set to %d." % Global.current_wave, "System")
			else:
				chat_add("Current wave: %d. Usage: /wave [n]" % Global.current_wave, "System")
		"/set_health":
			if parts.size() < 2 or not parts[1].is_valid_int():
				chat_add("Usage: /set_health <amount>", "System")
			else:
				var p := get_tree().get_first_node_in_group("player")
				if p:
					var amount := int(parts[1])
					p.current_health = amount
					p.max_health = max(p.max_health, amount)
					if p.health_bar and is_instance_valid(p.health_bar):
						p.health_bar.max_value = p.max_health
						p.health_bar.value = p.current_health
					p.emit_signal("health_updated", p.current_health, p.max_health)
					chat_add("Player health set to %d." % amount, "System")
				else:
					chat_add("Player not found.", "System")
		"/set_speed":
			if parts.size() < 2 or not parts[1].is_valid_float():
				chat_add("Usage: /set_speed <amount>", "System")
			else:
				var p := get_tree().get_first_node_in_group("player")
				if p:
					var amount := float(parts[1])
					p.max_speed = amount
					p.base_max_speed = amount
					p.emit_signal("speed_updated", p.max_speed)
					chat_add("Player speed set to %.1f." % amount, "System")
				else:
					chat_add("Player not found.", "System")
		"/set_damage":
			if parts.size() < 2 or not parts[1].is_valid_int():
				chat_add("Usage: /set_damage <amount>", "System")
			else:
				var p := get_tree().get_first_node_in_group("player")
				if p:
					var amount := int(parts[1])
					p.base_damage = amount
					p.emit_signal("damage_updated", float(p.base_damage) * p.damage_modifier)
					chat_add("Player damage set to %d." % amount, "System")
				else:
					chat_add("Player not found.", "System")
		"/set_solari":
			if parts.size() < 2 or not parts[1].is_valid_int():
				chat_add("Usage: /set_solari <amount>", "System")
			else:
				var amount := int(parts[1])
				Global.coins_collected = amount
				Global.emit_signal("coins_updated", Global.coins_collected)
				chat_add("Solari set to %d." % amount, "System")
		"/set_godmode":
			Global.godmode = not Global.godmode
			chat_add("Godmode %s." % ("ON" if Global.godmode else "OFF"), "System")
		"/set_saved":
			if parts.size() < 2 or not parts[1].is_valid_int():
				chat_add("Usage: /set_saved <amount>", "System")
			else:
				var amount := int(parts[1])
				Global.saved_villagers = amount
				Global.emit_signal("villagers_updated", Global.saved_villagers, Global.lost_villagers, Global.total_villagers)
				chat_add("Villagers saved set to %d." % amount, "System")
		_:
			chat_add("Unknown command '%s'. Type /help." % cmd, "System")

func _spawn_enemy(enemy_name: String) -> void:
	var scene_map := {
		"skeleton": "res://Scenes/skeleton.tscn",
		"wizard":   "res://Scenes/wizard.tscn",
		"goblin":   "res://Scenes/goblin.tscn",
		"ghost":    "res://Scenes/ghost.tscn",
		"ogre":     "res://Scenes/ogre.tscn",
		"lich":     "res://Scenes/lich.tscn",
		"beholder": "res://Scenes/beholder.tscn",
		"balrog":   "res://Scenes/balrog.tscn",
		"wraith":   "res://Scenes/wraith.tscn",
		"troll":    "res://Scenes/troll.tscn",
		"hezrou":   "res://Scenes/hezrou.tscn",
	}
	if not scene_map.has(enemy_name):
		chat_add("Unknown enemy '%s'. Try: skeleton, wizard, goblin, ghost, ogre, lich, beholder, balrog, wraith, troll, hezrou." % enemy_name, "System")
		return
	var scene := load(scene_map[enemy_name]) as PackedScene
	if not scene:
		chat_add("Failed to load scene for '%s'." % enemy_name, "System")
		return
	var p := get_tree().get_first_node_in_group("player")
	var spawn_pos: Vector2 = p.global_position + Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0)) if p else Vector2(400.0, 300.0)
	var monster := scene.instantiate()
	monster.global_position = spawn_pos
	get_tree().current_scene.add_child(monster)
	chat_add("Spawned %s." % enemy_name, "System")
