# final_boss_spawner.gd
# Attach to a Node in main.tscn. Watches saved villager count; when 100 are
# saved, spawns Mh'orzath and wires his death to the victory scene.
extends Node

@export var boss_scene: PackedScene = preload("res://Scenes/mh_orzath.tscn")
@export var win_villager_count: int = 50

var _has_spawned: bool = false
var _boss_instance: Node2D = null

func _ready() -> void:
	await get_tree().process_frame
	Global.villagers_updated.connect(_on_villagers_updated)

func _on_villagers_updated(saved: int, _lost: int, _total: int) -> void:
	if saved >= win_villager_count and not _has_spawned:
		_spawn_boss()

func _spawn_boss() -> void:
	if _has_spawned or not boss_scene:
		return
	_has_spawned = true
	_boss_instance = boss_scene.instantiate() as Node2D
	_boss_instance.global_position = _get_spawn_position()
	get_tree().current_scene.add_child(_boss_instance)
	if _boss_instance.has_signal("mob_died"):
		_boss_instance.mob_died.connect(_on_boss_died)
	print("FinalBossSpawner: Mh'orzath has entered the world!")

func _get_spawn_position() -> Vector2:
	# Spawn off the top of the viewport so the boss walks in dramatically
	var player := get_tree().get_first_node_in_group("player")
	var base := player.global_position if player and is_instance_valid(player) else Vector2(600, 400)
	var viewport_rect := get_viewport().get_visible_rect()
	return base + Vector2(0.0, -(viewport_rect.size.y * 0.5 + 200.0))

func _on_boss_died() -> void:
	Global.game_active = false
	var ui := get_node_or_null("/root/UI")
	if ui:
		ui.visible = false
	get_tree().change_scene_to_file("res://Scenes/victory_scene.tscn")
