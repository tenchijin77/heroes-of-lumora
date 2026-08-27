# class_upgrade.gd - permanent per-class endless-mode upgrades, purchased
# with Global.endless_coins. Same health/damage/speed upgrades as Timot's
# in-run shop (shop_ui.gd) for now; class-specific upgrades are a to-do.
# Applied to the swapped-in player in main.gd._apply_endless_class().
extends Control

const FONT_TITLE: FontFile = preload("res://Assets/Fonts/alagard_by_pix3m-d6awiwp.ttf")
const FONT_BODY: FontFile = preload("res://Assets/Fonts/_bitmap_font____romulus_by_pix3m-d6aokem.ttf")

const CLASS_DISPLAY_NAMES: Dictionary = {
	"res://Scenes/woodstalker.tscn": "Woodstalker",
	"res://Scenes/troubadour.tscn": "Troubadour",
	"res://Scenes/arcanist.tscn": "Arcanist",
	"res://Scenes/voidknight_class.tscn": "Voidknight",
	"res://Scenes/gravecaller_class.tscn": "Gravecaller",
}

# Same base prices/scaling as Timot's shop (shop_ui.gd) — separate economy
# (Global.endless_coins), but no reason to reinvent the curve.
const BASE_PRICES: Dictionary = {"health": 20, "damage": 30, "speed": 25}
const PRICE_EXPONENT: float = 1.3

var _class_path: String = ""
var _counts: Dictionary = {}
var _solari_label: Label
var _cost_labels: Dictionary = {}
var _count_labels: Dictionary = {}
var _buy_buttons: Dictionary = {}

func _ready() -> void:
	Global.play_menu_music()
	_class_path = Global.viewing_upgrade_class
	if not CLASS_DISPLAY_NAMES.has(_class_path):
		# No class selected (e.g. scene opened directly) — bail to the picker.
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/upgrade_store.tscn")
		return
	_counts = Global.get_class_upgrades(_class_path)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	_label(vbox, "%s Upgrades" % CLASS_DISPLAY_NAMES[_class_path], FONT_TITLE, 48, Color(1.0, 0.9, 0.6))
	_solari_label = _label(vbox, "", FONT_BODY, 24, Color(1.0, 0.85, 0.3))
	_update_solari_label()
	_spacer(vbox, 20)

	_add_upgrade_row(vbox, "health", "Max Health", "+25 HP per purchase")
	_add_upgrade_row(vbox, "damage", "Damage", "+2 damage per purchase")
	_add_upgrade_row(vbox, "speed", "Speed", "+10 move speed per purchase")

	_spacer(vbox, 30)
	var back_btn := _button("Back")
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)
	back_btn.grab_focus()

func _add_upgrade_row(parent: Node, key: String, title: String, hint: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(160, 0)
	name_label.add_theme_font_override("font", FONT_BODY)
	name_label.add_theme_font_size_override("font_size", 22)
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.custom_minimum_size = Vector2(80, 0)
	count_label.add_theme_font_override("font", FONT_BODY)
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	row.add_child(count_label)
	_count_labels[key] = count_label

	var cost_label := Label.new()
	cost_label.custom_minimum_size = Vector2(120, 0)
	cost_label.add_theme_font_override("font", FONT_BODY)
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	row.add_child(cost_label)
	_cost_labels[key] = cost_label

	var buy_btn := _button("Buy")
	buy_btn.pressed.connect(_on_buy_pressed.bind(key))
	row.add_child(buy_btn)
	_buy_buttons[key] = buy_btn

	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.add_theme_font_override("font", FONT_BODY)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	row.add_child(hint_label)

	_refresh_row(key)

func _get_price(key: String) -> int:
	return roundi(BASE_PRICES[key] * pow(PRICE_EXPONENT, _counts.get(key, 0)))

func _refresh_row(key: String) -> void:
	_count_labels[key].text = "Lv %d" % _counts.get(key, 0)
	var price := _get_price(key)
	_cost_labels[key].text = "%d Solari" % price
	_buy_buttons[key].disabled = Global.endless_coins < price

func _refresh_all() -> void:
	for key in ["health", "damage", "speed"]:
		_refresh_row(key)
	_update_solari_label()

func _update_solari_label() -> void:
	_solari_label.text = "Solari: %d" % Global.endless_coins

func _on_buy_pressed(key: String) -> void:
	var price := _get_price(key)
	if not Global.spend_endless_coins(price):
		return
	_counts[key] = _counts.get(key, 0) + 1
	Global.save_progress()
	_refresh_all()

func _label(parent: Node, text: String, font: FontFile, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)
	return lbl

func _spacer(parent: Node, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)

func _button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(100, 44)
	return btn

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/upgrade_store.tscn")
