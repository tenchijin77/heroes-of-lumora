# final_boss_spawner.gd
# Watches saved villager count. When win_villager_count are saved:
# stops all spawners, clears monsters, announces Mh'orzath, then spawns him.
extends Node

@export var boss_scene: PackedScene = preload("res://Scenes/mh_orzath.tscn")
@export var win_villager_count: int = 50

var _has_triggered: bool = false
var _boss_instance: Node2D = null

func _ready() -> void:
	await get_tree().process_frame
	Global.villagers_updated.connect(_on_villagers_updated)

func _on_villagers_updated(saved: int, _lost: int, _total: int) -> void:
	if saved >= win_villager_count and not _has_triggered:
		_has_triggered = true
		_trigger_boss_sequence()

func _trigger_boss_sequence() -> void:
	# Block enemy spawner from firing new waves
	Global.boss_fight_active = true

	# Stop villager spawner
	for spawner in get_tree().get_nodes_in_group("villager_spawner"):
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()

	# Despawn all live monsters
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob):
			mob.queue_free()

	# Announce
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("show_announcement"):
		ui.show_announcement("50 Villagers Saved!\nMh'orzath awakens...", 4.0)
	if ui and ui.has_method("chat_add"):
		ui.chat_add("The darkness recoils... something far worse stirs.", "System")

	print("FinalBossSpawner: win condition met — boss sequence begins")
	await get_tree().create_timer(3.5).timeout

	if not is_instance_valid(self):
		return
	_spawn_boss()

func _spawn_boss() -> void:
	if not boss_scene:
		return
	_boss_instance = boss_scene.instantiate() as Node2D
	_boss_instance.global_position = _get_spawn_position()
	get_tree().current_scene.add_child(_boss_instance)
	if _boss_instance.has_signal("mob_died"):
		_boss_instance.mob_died.connect(_on_boss_died)
	print("FinalBossSpawner: Mh'orzath has entered the world!")

func _get_spawn_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	var base: Vector2 = player.global_position if player and is_instance_valid(player) else Vector2(600.0, 400.0)
	var viewport_rect := get_viewport().get_visible_rect()
	return base + Vector2(0.0, -(viewport_rect.size.y * 0.5 + 200.0))

func _on_boss_died() -> void:
	Global.game_active = false
	var ui := get_node_or_null("/root/UI")
	if ui:
		ui.visible = false
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/victory_scene.tscn")
