# villager_spawner.gd
# Spawns villagers at random intervals and positions, assigning random types from villagers.json.

extends Node

@export var villager_scene: PackedScene
@export var spawn_interval_range := Vector2(20.0, 30.0)
@export var town_spawn_rect := Rect2(Vector2(400, 300), Vector2(200, 200))

const NodePool = preload("res://Scripts/node_pool.gd")

const FORBIDDEN_ZONE_MASK = 128

@onready var spawn_timer: Timer = $villager_spawn_timer
var villager_pool: NodePool
var villager_types: Array[String] = []

func _ready() -> void:
	# Ensure only one spawner exists
	var spawners: Array = get_tree().get_nodes_in_group("villager_spawner")
	if spawners.size() > 1:
		if OS.has_feature("editor"):
			push_warning("VillagerSpawner: %d spawners detected! Only one should exist. Disabling extras." % spawners.size())
		if spawners[0] != self:
			queue_free()
			return
	add_to_group("villager_spawner")
	
	if OS.has_feature("editor"):
		print("VillagerSpawner: Ready")
	villager_pool = NodePool.new()
	add_child(villager_pool)
	villager_pool.node_scene = villager_scene
	
	# Load villager types from JSON
	var file: FileAccess = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data:
			villager_types = []
			for key in json_data.keys():
				if key != "_comment" and key is String:
					villager_types.append(key)
			if OS.has_feature("editor"):
				print("VillagerSpawner: Loaded villager types: %s" % villager_types)
		else:
			if OS.has_feature("editor"):
				push_error("VillagerSpawner: Failed to parse villagers.json!")
		file.close()
	else:
		if OS.has_feature("editor"):
			push_error("VillagerSpawner: Failed to open villagers.json!")
	
	# Setup spawn timer
	if spawn_timer:
		spawn_timer.timeout.connect(_on_villager_spawn_timer_timeout)
		spawn_timer.wait_time = randf_range(spawn_interval_range.x, spawn_interval_range.y)
		spawn_timer.autostart = false
		spawn_timer.one_shot = false
		spawn_timer.paused = true  # Start paused until wave 2
		if OS.has_feature("editor"):
			print("VillagerSpawner: Timer initialized with wait_time %s (paused)" % spawn_timer.wait_time)
	else:
		if OS.has_feature("editor"):
			push_error("VillagerSpawner: villager_spawn_timer not found!")
	
	# Connect to wave updates
	Global.wave_updated.connect(_on_wave_updated)

func _on_wave_updated(wave: int) -> void:
	# Start spawning at wave 2
	if wave >= 2 and spawn_timer.paused:
		spawn_timer.paused = false
		spawn_timer.start()
		if OS.has_feature("editor"):
			print("VillagerSpawner: Started spawning at wave %d" % wave)

func _on_villager_spawn_timer_timeout() -> void:
	# Handle timer timeout to spawn a villager
	if OS.has_feature("editor"):
		print("VillagerSpawner: Timer timeout fired!")
	if Global.saved_villagers + Global.lost_villagers < Global.total_villagers:
		_spawn_villager()
	else:
		spawn_timer.stop()
		if OS.has_feature("editor"):
			print("VillagerSpawner: Stopped spawning, villager limit reached")
	spawn_timer.wait_time = randf_range(spawn_interval_range.x, spawn_interval_range.y)
	spawn_timer.start()
	if OS.has_feature("editor"):
		print("VillagerSpawner: Timer restarted with wait_time %s" % spawn_timer.wait_time)

func _spawn_villager() -> void:
	# Spawns a villager with a random type and position
	if OS.has_feature("editor"):
		print("Spawner: Attempting to spawn villager.")
	if villager_pool:
		var villager: Villager = villager_pool.spawn()
		if villager:
			if not villager_types.is_empty():
				villager.villager_type = villager_types[randi() % villager_types.size()]
			villager.global_position = _get_random_spawn_position()
			get_tree().current_scene.add_child.call_deferred(villager)
			if OS.has_feature("editor"):
				print("Spawner: Spawned villager %s with type %s at %s" % [villager.name, villager.villager_type, villager.global_position])
			# Connect the signals to the spawner's handler functions
			if not villager.villager_died.is_connected(_on_villager_died):
				villager.villager_died.connect(_on_villager_died.bind(villager))
			if not villager.villager_extracted.is_connected(_on_villager_extracted):
				villager.villager_extracted.connect(_on_villager_extracted.bind(villager))
	else:
		if OS.has_feature("editor"):
			push_error("VillagerSpawner: villager_pool is null!")

func _on_villager_died(villager: Node2D) -> void:
	# Increment the lost villagers counter and emit the update signal
	Global.lost_villagers += 1
	Global.villagers_updated.emit(Global.saved_villagers, Global.lost_villagers, Global.total_villagers)
	if OS.has_feature("editor"):
		print("Villager died: %s, lost_villagers now %d" % [villager.name, Global.lost_villagers])

func _on_villager_extracted(villager: Node2D) -> void:
	# Increment the saved villagers counter and emit the update signal
	Global.saved_villagers += 1
	Global.villagers_updated.emit(Global.saved_villagers, Global.lost_villagers, Global.total_villagers)
	if OS.has_feature("editor"):
		print("Villager extracted: %s, saved_villagers now %d" % [villager.name, Global.saved_villagers])

func _get_random_spawn_position() -> Vector2:
	# Returns a random spawn position within the forbidden zone or town rect
	if OS.has_feature("editor"):
		print("Spawner: Attempting to get random spawn position.")
	var forbidden_zone: Area2D = get_node_or_null("/root/main/forbidden_zone")
	if forbidden_zone:
		if OS.has_feature("editor"):
			print("Spawner: Found forbidden_zone node.")
		var shape: CollisionShape2D = forbidden_zone.get_node_or_null("CollisionShape2D")
		if not shape:
			for child in forbidden_zone.get_children():
				if child is CollisionShape2D:
					shape = child
					if OS.has_feature("editor"):
						print("Spawner: Found CollisionShape2D child.")
					break
		if shape and shape.shape is RectangleShape2D:
			var rect: Rect2 = shape.global_transform * shape.shape.get_rect()
			if OS.has_feature("editor"):
				print("Spawner: Found valid RectangleShape2D, spawning inside it.")
			return Vector2(randf_range(rect.position.x, rect.position.x + rect.size.x),
							randf_range(rect.position.y, rect.position.y + rect.size.y))
		else:
			if OS.has_feature("editor"):
				print("Spawner: Forbidden zone shape is not a RectangleShape2D or no shape found.")
	else:
		if OS.has_feature("editor"):
			print("Spawner: Could not find forbidden_zone node. Falling back to town_spawn_rect.")
	return Vector2(randf_range(town_spawn_rect.position.x, town_spawn_rect.position.x + town_spawn_rect.size.x),
					randf_range(town_spawn_rect.position.y, town_spawn_rect.position.y + town_spawn_rect.size.y))
