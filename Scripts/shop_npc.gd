# shop_npc.gd - Timot the shop keeper NPC
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $interaction_area
@onready var prompt_label: Label = $prompt_label

const SHOP_UI_SCENE: String = "res://Scenes/shop_ui.tscn"

var player_in_range: bool = false
var shop_open: bool = false

func _ready() -> void:
	velocity = Vector2.ZERO
	prompt_label.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if player_in_range and not shop_open and Input.is_action_just_pressed("interact"):
		_open_shop()

func _open_shop() -> void:
	shop_open = true
	prompt_label.visible = false
	get_tree().paused = true
	Global.game_active = false
	var shop_scene: PackedScene = load(SHOP_UI_SCENE)
	var shop_instance: Node = shop_scene.instantiate()
	get_tree().current_scene.add_child(shop_instance)
	shop_instance.closed.connect(_on_shop_closed)

func _on_shop_closed() -> void:
	shop_open = false
	get_tree().paused = false
	Global.game_active = true
	if player_in_range:
		prompt_label.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not shop_open:
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
