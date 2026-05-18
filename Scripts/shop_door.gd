# shop_door.gd - opens the shop UI when the player enters the doorway zone
extends Area2D

const SHOP_UI_SCENE: String = "res://Scenes/shop_ui.tscn"

var shop_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not shop_open:
		_open_shop()

func _open_shop() -> void:
	shop_open = true
	get_tree().paused = true
	Global.game_active = false
	var shop_ui_scene: PackedScene = load(SHOP_UI_SCENE)
	if not shop_ui_scene:
		push_error("ShopDoor: Cannot load shop_ui.tscn!")
		return
	var shop_ui: CanvasLayer = shop_ui_scene.instantiate()
	shop_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(shop_ui)
	shop_ui.closed.connect(_on_shop_closed)

func _on_shop_closed() -> void:
	shop_open = false
	get_tree().paused = false
	Global.game_active = true
