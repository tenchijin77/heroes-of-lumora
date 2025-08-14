# shop_door.gd - controls entry to the shop area
extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://Scenes/shop_zone.tscn")
