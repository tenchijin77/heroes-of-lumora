# villager.gd
# This script defines the behavior for a non-combatant villager NPC.
# The villager navigates to a randomly selected extraction point, cowering/fleeing from monsters.

class_name Villager
extends CharacterBody2D

signal villager_extracted
signal villager_died

## Villager Type - Determines stats and appearance from GameData
@export var villager_type: String = "villager_commoner_male"

var move_speed: float = 40.0
var max_health: float = 25.0
var popup_message: String = "Help me!"

var current_health: float
var _extraction_point: Node2D
var can_trigger_popup: bool = true
var is_fearing: bool = false
var fear_direction: Vector2
var fear_timer: Timer
var is_extracted: bool = false
var player_in_range: bool = false

var popup_scene: PackedScene = preload("res://Assets/UI/villager_popup.tscn")

@onready var sprite: Sprite2D = $sprite_2d
@onready var navigation_agent: NavigationAgent2D = $navigation_agent_2d
@onready var interaction_area: Area2D = $interaction_area
@onready var fear_area: Area2D = $fear_area

func _ready() -> void:
	if not sprite or not fear_area or not navigation_agent:
		if OS.has_feature("editor"):
			push_error("Villager: Missing required nodes (sprite_2d, fear_area, or navigation_agent_2d)")
		queue_free()
		return
	
	if get_tree() == null:
		if OS.has_feature("editor"):
			push_error("Villager: get_tree() is null in _ready!")
		queue_free()
		return
	if OS.has_feature("editor"):
		print("Villager: Scene tree valid in _ready, node: %s" % name)
	
	var stats: Dictionary = GameData.get_villager_stats(villager_type)
	max_health = stats.get("max_health", 25.0)
	move_speed = stats.get("move_speed", 40.0)
	popup_message = stats.get("popup_message", "Help me!")
	var region: Array = stats.get("sprite_region", [135, 68, 20, 28])
	sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
	current_health = max_health
	
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	fear_area.body_entered.connect(_on_fear_area_body_entered)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	
	fear_timer = Timer.new()
	fear_timer.name = "FearTimer"
	fear_timer.wait_time = 3.0
	fear_timer.one_shot = true
	fear_timer.timeout.connect(_on_fear_timer_timeout)
	add_child(fear_timer)
	
	# Defer navigation target update to ensure scene tree is ready
	if get_tree():
		await get_tree().physics_frame
		update_navigation_target.call_deferred()
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: get_tree() is null after physics_frame, deferring navigation update" % name)
		update_navigation_target.call_deferred()
	if OS.has_feature("editor"):
		print("Villager %s: Initialized with type %s, popup_message=%s" % [name, villager_type, popup_message])

func reset() -> void:
	current_health = max_health
	is_fearing = false
	fear_direction = Vector2.ZERO
	can_trigger_popup = true
	is_extracted = false
	player_in_range = false
	if fear_timer:
		fear_timer.stop()
	set_physics_process(true)
	update_navigation_target()
	if OS.has_feature("editor"):
		print("Villager %s: Reset with type %s" % [name, villager_type])

func _physics_process(delta: float) -> void:
	if not visible or is_extracted:
		return
	if not is_fearing and not navigation_agent.is_navigation_finished():
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		var direction: Vector2 = (next_path_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		if player_in_range and can_trigger_popup:
			show_popup()
	else:
		velocity = Vector2.ZERO
		if is_fearing:
			velocity = fear_direction * move_speed
			move_and_slide()

func update_navigation_target() -> void:
	# Updates navigation target to a random extraction point
	if is_extracted:
		return
	if not get_tree():
		if OS.has_feature("editor"):
			push_error("Villager %s: get_tree() is null in update_navigation_target, retrying next frame" % name)
		update_navigation_target.call_deferred()
		return
	var extraction_points: Array[Node] = get_tree().get_nodes_in_group("extraction_points")
	if not extraction_points.is_empty():
		_extraction_point = extraction_points[randi() % extraction_points.size()] as Node2D
		navigation_agent.target_position = _extraction_point.global_position
		if OS.has_feature("editor"):
			print("Villager %s: Navigation target set to %s at %s" % [name, _extraction_point.name, _extraction_point.global_position])
	else:
		if OS.has_feature("editor"):
			push_error("Villager %s: No extraction points found in group 'extraction_points'!" % name)
		_extraction_point = null
		navigation_agent.target_position = Vector2.ZERO

func take_damage(damage: float) -> void:
	if is_extracted:
		return
	current_health -= damage
	if OS.has_feature("editor"):
		print("Villager %s: Took %s damage, current_health=%s" % [name, damage, current_health])
	if current_health <= 0:
		visible = false
		is_extracted = true
		set_physics_process(false)
		Global.lost_villagers += 1
		Global.villagers_updated.emit(Global.saved_villagers, Global.lost_villagers)
		villager_died.emit()
	else:
		show_popup()

func receive_heal(heal: float) -> void:
	if is_extracted:
		return
	current_health = min(current_health + heal, max_health)
	if OS.has_feature("editor"):
		print("Villager %s: Healed for %s, current_health=%s" % [name, heal, current_health])
	show_popup()

func fear_from(monster_position: Vector2) -> void:
	if is_extracted:
		return
	is_fearing = true
	fear_direction = (global_position - monster_position).normalized()
	fear_timer.start()
	if OS.has_feature("editor"):
		print("Villager %s: Fearing from monster at %s" % [name, monster_position])

func _on_fear_timer_timeout() -> void:
	is_fearing = false
	update_navigation_target()

func _on_navigation_finished() -> void:
	if is_extracted:
		return
	if _extraction_point and global_position.distance_squared_to(_extraction_point.global_position) < 50:
		if OS.has_feature("editor"):
			print("Villager %s: Reached extraction point %s at %s" % [name, _extraction_point.name, _extraction_point.global_position])
		visible = false
		is_extracted = true
		set_physics_process(false)
		navigation_agent.target_position = Vector2.ZERO
		Global.saved_villagers += 1
		Global.villagers_updated.emit(Global.saved_villagers, Global.lost_villagers)
		villager_extracted.emit()
	else:
		if OS.has_feature("editor"):
			print("Villager %s: Navigation finished, but not at extraction point. Recalculating." % name)
		update_navigation_target()

func show_popup() -> void:
	if not can_trigger_popup or is_extracted:
		return
	if OS.has_feature("editor"):
		print("Villager %s: Attempting to show popup with message '%s'" % [name, popup_message])
	can_trigger_popup = false
	var popup: CanvasLayer = popup_scene.instantiate()
	var label: Label = popup.get_node_or_null("Label")
	if not label:
		if OS.has_feature("editor"):
			push_error("Villager %s: Popup Label node not found!" % name)
		popup.queue_free()
		return
	label.text = popup_message
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	var screen_pos: Vector2
	if camera:
		if OS.has_feature("editor"):
			print("Villager %s: Camera found, calculating screen position" % name)
		screen_pos = global_position - camera.global_position + (viewport.get_visible_rect().size / 2)
	else:
		if OS.has_feature("editor"):
			print("Villager %s: No camera found, using default viewport position" % name)
		screen_pos = global_position
	label.global_position = screen_pos
	get_tree().current_scene.add_child(popup)
	if OS.has_feature("editor"):
		print("Villager %s: Popup added to scene at %s" % [name, screen_pos])
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)
	tween.tween_interval(5.0)
	tween.tween_callback(func(): can_trigger_popup = true)
	if OS.has_feature("editor"):
		print("Villager %s: Popup tween started" % name)

func _on_area_entered(area: Area2D) -> void:
	if is_extracted:
		return
	if area.is_in_group("monster_projectiles"):
		var damage: float = area.damage if "damage" in area else 10.0
		take_damage(damage)
		if OS.has_feature("editor"):
			print("Villager %s: Hit by monster projectile, damage=%s" % [name, damage])
	elif area.is_in_group("healing_projectiles"):
		var heal: float = area.heal_amount if "heal_amount" in area else 20.0
		receive_heal(heal)
		if OS.has_feature("editor"):
			print("Villager %s: Hit by healing projectile, heal=%s" % [name, heal])
	elif area.is_in_group("player"):
		player_in_range = true
		if OS.has_feature("editor"):
			print("Villager %s: Player entered interaction area" % name)
		show_popup()

func _on_area_exited(area: Area2D) -> void:
	if is_extracted:
		return
	if area.is_in_group("player"):
		player_in_range = false
		if OS.has_feature("editor"):
			print("Villager %s: Player exited interaction area" % name)

func _on_fear_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("monsters"):
		fear_from(body.global_position)
