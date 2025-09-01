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

func _ready() -> void:
	# Hide UI by default, show only for main scene
	visible = false
	# Update with initial values
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
	if node.is_in_group("ui_hidden"):
		visible = false
	if node.name == "main":
		visible = true
	if node.name == "player" and node.is_in_group("player"):
		node.damage_updated.connect(_update_player_damage)
		node.speed_updated.connect(_update_player_speed)
		node.health_updated.connect(_update_player_health)
		# Update initial stat values
		_update_player_damage(node.base_damage * node.damage_modifier)
		_update_player_speed(node.max_speed)
		_update_player_health(node.current_health, node.max_health)
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
	coin_label.text = "Coins: %d" % coins

func _update_villagers(saved: int, lost: int, total: int) -> void:
	saved_villagers_label.text = "Villagers Saved: %d" % saved
	lost_villagers_label.text = "Villagers Lost: %d" % lost
	remaining_villagers_label.text = "Villagers Remaining: %d" % (total - (saved + lost))

func _update_player_damage(damage: float) -> void:
	if player_damage:
		player_damage.text = "🗡️ %.1f" % damage
	else:
		push_error("UI: player_damage label is null!")

func _update_player_speed(speed: float) -> void:
	if player_speed:
		player_speed.text = "👟 %.1f" % speed
	else:
		push_error("UI: player_speed label is null!")

func _update_player_health(current: int, max: int) -> void:
	if player_health:
		player_health.text = "❤️ %d/%d" % [current, max]
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
