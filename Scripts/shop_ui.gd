# shop_ui.gd - manages the in-game shop overlay
extends CanvasLayer

signal closed

@onready var solari_label: Label = $background_dim/shop_panel/VBoxContainer/footer/solari_label
@onready var health_cost_label: Label = $background_dim/shop_panel/VBoxContainer/upgrades/health_row/health_cost
@onready var damage_cost_label: Label = $background_dim/shop_panel/VBoxContainer/upgrades/damage_row/damage_cost
@onready var speed_cost_label: Label = $background_dim/shop_panel/VBoxContainer/upgrades/speed_row/speed_cost
@onready var guard_cost_label: Label = $background_dim/shop_panel/VBoxContainer/reinforcements/guard_row/guard_cost
@onready var magi_cost_label: Label = $background_dim/shop_panel/VBoxContainer/reinforcements/magi_row/magi_cost
@onready var health_buy_btn: Button = $background_dim/shop_panel/VBoxContainer/upgrades/health_row/health_buy
@onready var damage_buy_btn: Button = $background_dim/shop_panel/VBoxContainer/upgrades/damage_row/damage_buy
@onready var speed_buy_btn: Button = $background_dim/shop_panel/VBoxContainer/upgrades/speed_row/speed_buy
@onready var guard_buy_btn: Button = $background_dim/shop_panel/VBoxContainer/reinforcements/guard_row/guard_buy
@onready var magi_buy_btn: Button = $background_dim/shop_panel/VBoxContainer/reinforcements/magi_row/magi_buy

# Base prices in Solari
const BASE_PRICES: Dictionary = {
	"health": 20,
	"damage": 30,
	"speed": 25,
	"guard": 100,
	"magi": 150
}

const GUARD_SCENE: String = "res://Scenes/guard.tscn"
const MAGI_SCENE: String = "res://Scenes/magi.tscn"

# Reference to Global.shop_purchase_counts — persists across scene transitions
var purchase_counts: Dictionary

func _ready() -> void:
	purchase_counts = Global.shop_purchase_counts
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Explicitly set interactive elements so they respond while tree is paused
	health_buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	damage_buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	speed_buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	guard_buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	magi_buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	$background_dim/shop_panel/VBoxContainer/footer/close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_all_costs()
	_update_solari()

const PRICE_EXPONENT: float = 1.3

func _get_price(item: String) -> int:
	return roundi(BASE_PRICES[item] * pow(PRICE_EXPONENT, purchase_counts[item]))

func _update_all_costs() -> void:
	health_cost_label.text = "%d Solari" % _get_price("health")
	damage_cost_label.text = "%d Solari" % _get_price("damage")
	speed_cost_label.text = "%d Solari" % _get_price("speed")
	guard_cost_label.text = "%d Solari" % _get_price("guard")
	magi_cost_label.text = "%d Solari" % _get_price("magi")
	_update_buy_buttons()

func _update_solari() -> void:
	solari_label.text = "Solari: %d" % Global.coins_collected
	_update_buy_buttons()

func _update_buy_buttons() -> void:
	var coins: int = Global.coins_collected
	health_buy_btn.disabled = coins < _get_price("health")
	damage_buy_btn.disabled = coins < _get_price("damage")
	speed_buy_btn.disabled = coins < _get_price("speed")
	guard_buy_btn.disabled = coins < _get_price("guard")
	magi_buy_btn.disabled = coins < _get_price("magi")

func _spend_coins(amount: int) -> void:
	Global.coins_collected -= amount
	Global.emit_signal("coins_updated", Global.coins_collected)
	_update_solari()

func _on_health_buy_pressed() -> void:
	var price: int = _get_price("health")
	if Global.coins_collected < price:
		return
	_spend_coins(price)
	purchase_counts["health"] += 1
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player.max_health += 25
		player.current_health = mini(player.current_health + 25, player.max_health)
		if player.health_bar and is_instance_valid(player.health_bar):
			player.health_bar.max_value = player.max_health
			player.health_bar.value = player.current_health
		player.emit_signal("health_updated", player.current_health, player.max_health)
	_update_all_costs()

func _on_damage_buy_pressed() -> void:
	var price: int = _get_price("damage")
	if Global.coins_collected < price:
		return
	_spend_coins(price)
	purchase_counts["damage"] += 1
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player.base_damage += 2
		player.emit_signal("damage_updated", player.base_damage * player.damage_modifier)
	_update_all_costs()

func _on_speed_buy_pressed() -> void:
	var price: int = _get_price("speed")
	if Global.coins_collected < price:
		return
	_spend_coins(price)
	purchase_counts["speed"] += 1
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player.max_speed += 10.0
		player.base_max_speed += 10.0
		player.emit_signal("speed_updated", player.max_speed)
	_update_all_costs()

func _on_guard_buy_pressed() -> void:
	var price: int = _get_price("guard")
	if Global.coins_collected < price:
		return
	_spend_coins(price)
	purchase_counts["guard"] += 1
	_spawn_guard()
	_update_all_costs()

func _spawn_guard() -> void:
	var guard_scene: PackedScene = load(GUARD_SCENE)
	if not guard_scene:
		push_error("ShopUI: Could not load guard.tscn")
		return
	var detectors: Array = get_tree().get_nodes_in_group("gate_detectors")
	if detectors.is_empty():
		push_error("ShopUI: No gate_detectors found in scene")
		return
	# Cycle through north_gate → west_gate → town_center and repeat
	var spawn_marker: Node = detectors[Global.guard_spawn_index % detectors.size()].get_parent()
	Global.guard_spawn_index += 1
	var guard: Node = guard_scene.instantiate()
	var g_angle := randf() * TAU
	var g_dist := randf_range(20.0, 60.0)
	guard.global_position = spawn_marker.global_position + Vector2(cos(g_angle), sin(g_angle)) * g_dist
	get_tree().current_scene.call_deferred("add_child", guard)

func _on_magi_buy_pressed() -> void:
	var price: int = _get_price("magi")
	if Global.coins_collected < price:
		return
	_spend_coins(price)
	purchase_counts["magi"] += 1
	_spawn_magi()
	_update_all_costs()

func _spawn_magi() -> void:
	var magi_scene: PackedScene = load(MAGI_SCENE)
	if not magi_scene:
		push_error("ShopUI: Could not load magi.tscn")
		return
	var detectors: Array = get_tree().get_nodes_in_group("gate_detectors")
	if detectors.is_empty():
		push_error("ShopUI: No gate_detectors found in scene")
		return
	# Cycle independently of guards so magi spread across gates separately
	var spawn_marker: Node = detectors[Global.magi_spawn_index % detectors.size()].get_parent()
	Global.magi_spawn_index += 1
	var magi: Node = magi_scene.instantiate()
	var m_angle := randf() * TAU
	var m_dist := randf_range(30.0, 80.0)
	magi.global_position = spawn_marker.global_position + Vector2(cos(m_angle), sin(m_angle)) * m_dist
	get_tree().current_scene.call_deferred("add_child", magi)

func _on_close_pressed() -> void:
	emit_signal("closed")
	queue_free()
