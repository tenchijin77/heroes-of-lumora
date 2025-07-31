# potion.gd
extends Area2D

var potion_id: String = ""
var effect_type: String = ""
var effect_value: float = 0.0
var effect_duration: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(potion_data: Dictionary) -> void:
	potion_id = potion_data["id"]
	effect_type = potion_data["effect"]["type"]
	effect_value = potion_data["effect"]["value"]
	if potion_data["effect"].has("duration"):
		effect_duration = potion_data["effect"]["duration"]
	$Sprite2D.texture = load("res://Assets/Sprites/Spritesheet.png")
	$Sprite2D.region_enabled = true
	$Sprite2D.region_rect = Rect2(
		potion_data["sprite_region"][0],
		potion_data["sprite_region"][1],
		potion_data["sprite_region"][2],
		potion_data["sprite_region"][3]
	)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.apply_potion_effect(effect_type, effect_value, effect_duration)
		var sound: AudioStream = load("res://Assets/Audio/DrinkPotion.wav")
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.stream = sound
		get_tree().current_scene.add_child(player)
		player.global_position = global_position
		player.play()
		queue_free()
