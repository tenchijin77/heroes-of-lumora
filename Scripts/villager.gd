# villager.gd - controls the villager npc behaviour
extends "res://Scripts/npc.gd"
class_name Villager

signal villager_died(villager)
signal villager_extracted(villager)

@export var speed: float = 100.0
@export var villager_type: String = "villager_commoner_male"
@export var max_health: int = 100
@export var current_health: int = 100

@onready var sprite: Sprite2D = $sprite_2d
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var health_bar: ProgressBar = $health_bar

var popup_message: String = "Help me!"
var shout_label: Label
var target_position: Vector2

func _ready() -> void:
	add_to_group("villagers")

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if navigation_agent:
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
		update_navigation_target()

	if avoidance_ray:
		avoidance_ray.enabled = true
		avoidance_ray.collision_mask = 1 << 4

	_load_villager_data()
	_setup_shout_label()
	shout(popup_message)

func _load_villager_data() -> void:
	var file = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if not file:
		push_error("Villager: Failed to open villagers.json!")
		return

	var json_data = JSON.parse_string(file.get_as_text())
	file.close()

	if json_data and json_data.has(villager_type):
		var data = json_data[villager_type]
		max_health = data.get("max_health", 100)
		current_health = max_health
		popup_message = data.get("popup_message", "Help me!")

		if health_bar:
			health_bar.max_value = max_health
			health_bar.value = current_health

func _on_navigation_finished() -> void:
	if Global.has_method("increment_saved_villagers"):
		Global.increment_saved_villagers()

	villager_extracted.emit(self)
	queue_free()

func update_navigation_target() -> void:
	var extraction_points = get_tree().get_nodes_in_group("extraction_points")
	if extraction_points.is_empty():
		push_error("Villager %s: No extraction points found!" % name)
		return

	var random_target = extraction_points[randi() % extraction_points.size()]
	target_position = random_target.global_position
	navigation_agent.set_target_position(target_position)

func _setup_shout_label() -> void:
	if not has_node("shout_label"):
		shout_label = Label.new()
		shout_label.name = "shout_label"
		shout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shout_label.add_theme_font_size_override("font_size", 24)
		shout_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
		shout_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		shout_label.add_theme_constant_override("outline_size", 8)
		add_child(shout_label)
	else:
		shout_label = $shout_label

	shout_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	shout_label.clip_text = true
	shout_label.position = Vector2(-200, -100)
	shout_label.size = Vector2(400, 80)
	shout_label.pivot_offset = shout_label.size / 2
	shout_label.modulate.a = 0.0
	shout_label.text = ""

func shout(text: String) -> void:
	if not shout_label or shout_label.text != "":
		return

	text = "A villager shouts: " + text
	shout_label.size.x = 400.0
	shout_label.set_deferred("text", text)

	if not get_tree():
		return
	await get_tree().process_frame

	if not is_instance_valid(self):
		return

	var font_height = shout_label.get_theme_font_size("font_size") * 1.7
	var line_count = shout_label.get_line_count()
	shout_label.size.y = float(line_count) * font_height
	shout_label.pivot_offset = shout_label.size / 2

	shout_label.scale = Vector2(0.2, 0.2)
	shout_label.modulate.a = 0.0

	var tween = create_tween().set_parallel()
	tween.tween_property(shout_label, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(shout_label, "modulate:a", 1.0, 0.25)

	var final_y_pos = -140.0 - (shout_label.size.y / 2.0)
	tween.tween_property(shout_label, "position:y", final_y_pos, 0.5)

	tween.chain().tween_property(shout_label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(func(): shout_label.text = "")

func take_damage(damage: int, _projectile_instance) -> void:
	current_health -= damage

	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

	if current_health <= 0:
		if Global.has_method("increment_lost_villagers"):
			Global.increment_lost_villagers()

		villager_died.emit(self)
		queue_free()

func reset(type: String = villager_type) -> void:
	villager_type = type
	current_health = max_health

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	visible = true
	set_physics_process(true)

	var file = FileAccess.open("res://Data/villagers.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()

		if json_data and json_data.has(villager_type):
			var data = json_data[villager_type]
			max_health = data.get("max_health", 100)
			current_health = max_health
			popup_message = data.get("popup_message", "Help me!")

	_setup_shout_label()
	shout(popup_message)
	update_navigation_target()

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)

	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

	print(
		"Villager %s healed for %d → current_health = %d"
		% [name, amount, current_health]
	)
