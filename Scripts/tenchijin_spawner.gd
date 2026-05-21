# tenchijin_spawner.gd - Manages Tenchijin's dramatic entrance
extends Node

@export var tenchijin_scene: PackedScene = preload("res://Scenes/tenchijin.tscn")
@export var spawn_wave_threshold: int = 8

var has_spawned: bool = false
var tenchijin_instance: Node2D = null

func _ready() -> void:
	# Wait for tree to be ready
	await get_tree().process_frame
	
	# Connect to Anna's signals
	var anna = get_tree().get_first_node_in_group("annadaeus")
	if anna:
		if anna.has_signal("health_critical"):
			anna.health_critical.connect(_on_anna_health_critical)
		if anna.has_signal("died"):
			anna.died.connect(_on_anna_died)
	
	# Connect to global wave signal
	if Global.has_signal("wave_updated"):
		Global.wave_updated.connect(_on_wave_updated)

func _on_anna_health_critical() -> void:
	if not has_spawned:
		_spawn_tenchijin()

func _on_anna_died() -> void:
	if not has_spawned:
		_spawn_tenchijin()

func _on_wave_updated(wave: int) -> void:
	if wave >= spawn_wave_threshold and not has_spawned:
		_spawn_tenchijin()

func _spawn_tenchijin() -> void:
	if has_spawned or not tenchijin_scene:
		return
	
	has_spawned = true
	
	# Instantiate Tenchijin
	tenchijin_instance = tenchijin_scene.instantiate()
	
	# Find spawn position
	var spawn_pos = _get_spawn_position()
	tenchijin_instance.global_position = spawn_pos
	
	# Add to scene
	get_tree().current_scene.add_child(tenchijin_instance)
	
	# Trigger dramatic entrance if Tenchijin has the method
	if tenchijin_instance.has_method("dramatic_entrance"):
		tenchijin_instance.dramatic_entrance()
	

func _get_spawn_position() -> Vector2:
	# Spawn near Anna if she exists, otherwise near player
	var anna = get_tree().get_first_node_in_group("annadaeus")
	if anna and is_instance_valid(anna):
		return anna.global_position + Vector2(150, 0)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		return player.global_position + Vector2(200, 0)
	
	# Fallback to center of town
	return Vector2(800, 400)
