# messenger.gd - Controls messenger movement, shouting logic, and health
extends "res://Scripts/npc.gd"

@onready var sprite: Sprite2D = $sprite_2d
@onready var check_timer: Timer = $check_timer
@onready var health_bar: ProgressBar = $health_bar

var shout_label: Label

const SPEED: float = 150.0
const NAV_SPEED: float = 120.0
const ARRIVE_DISTANCE: float = 50.0
const FLEE_DISTANCE: float = 250.0
const RETURN_DISTANCE: float = 400.0
const DIRECT_RETURN_THRESHOLD: float = 200.0
const SHOUT_COOLDOWN: float = 6.0
const VILLAGER_CHECK_INTERVAL: float = 2.0
const SNAP_THRESHOLD: float = 5.0
const THREAT_CHECK_INTERVAL: float = 0.3

enum State { RUNNING, STANDING, FLEEING, RETURNING }

var state: State = State.RUNNING
var town_center_pos: Vector2 = Vector2(808, 379)
var current_threat: CharacterBody2D = null
var last_threat_check: float = 0.0

var cooldowns: Dictionary = {
	"north": 0.0,
	"west": 0.0,
	"town": 0.0,
	"villagers": 0.0
}

var shout_texts: Dictionary = {
	"initial": [
		"Hear my warning! They emerge from the shadows!",
		"Traveler's warning: The monsters are gathering!",
		"The evil approaches! Prepare the defenses!",
		"Be warned, citizens! The siege has begun!",
		"Monsters are coming! This is not a drill!"
	],
	"north": [
		"**North Gate breached!** Rally the guards—the darkness advances!",
		"Urgent! The North Wall is under heavy attack! We need reinforcements!",
		"North is failing! They're pouring through the defenses!",
		"To the battlements! The northern flank is collapsing!",
		"Attention North! Hold the line at all costs!"
	],
	"west": [
		"By the Western Wall! The enemy strikes hard! Send aid now!",
		"Alert the West! Prepare for immediate engagement!",
		"West Gate is taking a pounding! Send archers to the perimeter!",
		"The fiends are tearing down the West! Focus fire!",
		"Scouts confirm a massive push on the West side!"
	],
	"town": [
		"**The Town is invaded!** Protect the innocents! Clear the streets!",
		"They are in the town center! All available hands, fight back!",
		"Monsters are loose among the buildings! Evacuate immediately!",
		"The heart of the town is compromised! Repel the invaders!",
		"Danger in the square! The enemy is here!"
	],
	"villagers": [
		"To the houses! The fiends target the people! Defend the Villagers!",
		"The enemy is attacking the unarmed! Guard the civilians!",
		"Help the villagers! They are cornered and defenseless!",
		"The beasts are slaughtering the innocents! Save the people!",
		"Villagers under attack! Prioritize their safety!"
	]
}

var health: float = 80.0
var max_health: float = 80.0

func _ready() -> void:
	add_to_group("friendly")
	call_deferred("_deferred_ready")

func _deferred_ready() -> void:
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
	shout_label.position = Vector2(0, -100)
	shout_label.size = Vector2(400, 80)
	shout_label.pivot_offset = shout_label.size / 2
	shout_label.modulate.a = 0.0

	var markers = get_tree().current_scene.get_node_or_null("town_markers")
	if markers and markers.has_node("town_center"):
		town_center_pos = markers.get_node("town_center").global_position

	for detector in get_tree().get_nodes_in_group("gate_detectors"):
		if detector is Area2D:
			var side: String = detector.side
			detector.threat_detected.connect(func(_arg = null): _on_threat_detected(side))
			detector.threat_cleared.connect(func(_arg = null): _on_threat_cleared(side))

	health_bar.max_value = max_health
	health_bar.value = health

	if check_timer:
		check_timer.wait_time = VILLAGER_CHECK_INTERVAL
		check_timer.timeout.connect(_check_villagers_only)

	shout("initial")

func _physics_process(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if state != State.RUNNING and (current_time - last_threat_check) > THREAT_CHECK_INTERVAL:
		current_threat = _get_nearest_monster()
		last_threat_check = current_time

	match state:
		State.RUNNING:
			var dist = global_position.distance_to(town_center_pos)
			if dist <= ARRIVE_DISTANCE:
				state = State.STANDING
				velocity = Vector2.ZERO
				if check_timer:
					check_timer.start()
				shout("initial")
			else:
				var dir = (town_center_pos - global_position).normalized()
				velocity = dir * SPEED
				if sprite:
					sprite.flip_h = dir.x < 0

		State.STANDING:
			if is_instance_valid(current_threat) and global_position.distance_to(current_threat.global_position) < FLEE_DISTANCE:
				state = State.FLEEING
			else:
				velocity = Vector2.ZERO
				current_threat = null

		State.FLEEING:
			if not is_instance_valid(current_threat) or global_position.distance_to(current_threat.global_position) > RETURN_DISTANCE:
				state = State.RETURNING
				current_threat = null
				_set_navigation_target(town_center_pos)
			else:
				_flee_from_threat(current_threat, delta)

		State.RETURNING:
			if is_instance_valid(current_threat) and global_position.distance_to(current_threat.global_position) < FLEE_DISTANCE:
				state = State.FLEEING
			elif global_position.distance_to(town_center_pos) <= ARRIVE_DISTANCE:
				state = State.STANDING
				velocity = Vector2.ZERO
				current_threat = null
			else:
				var dist_to_center = global_position.distance_to(town_center_pos)
				if dist_to_center < DIRECT_RETURN_THRESHOLD:
					var dir = (town_center_pos - global_position).normalized()
					velocity = dir * NAV_SPEED
				elif navigation_agent:
					_move_along_navigation_path(delta)
				else:
					state = State.STANDING

	_snap_velocity_to_zero()

	if state != State.STANDING:
		move_and_slide()
		_move_wobble()
	else:
		sprite.rotation_degrees = 0.0

func _snap_velocity_to_zero() -> void:
	if velocity.length() < SNAP_THRESHOLD:
		velocity = Vector2.ZERO

func _get_nearest_monster() -> CharacterBody2D:
	var nearest: CharacterBody2D = null
	var min_dist = FLEE_DISTANCE
	for monster in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(monster):
			continue
		var dist = global_position.distance_to(monster.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = monster
	return nearest

func _flee_from_threat(threat: CharacterBody2D, _delta: float) -> void:
	var flee_direction = (global_position - threat.global_position).normalized()
	velocity = flee_direction * NAV_SPEED
	if sprite:
		sprite.flip_h = flee_direction.x < 0

func _set_navigation_target(target_pos: Vector2) -> void:
	if navigation_agent:
		navigation_agent.set_target_position(target_pos)

func _move_along_navigation_path(_delta: float) -> void:
	if not navigation_agent:
		velocity = Vector2.ZERO
		return
	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_position = navigation_agent.get_next_path_position()
	if next_position == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	var direction = (next_position - global_position).normalized()
	velocity = direction * NAV_SPEED
	if sprite:
		sprite.flip_h = direction.x < 0

func take_damage(damage: int, _projectile_instance) -> void:
	if damage < 0:
		heal(-damage)
		return

	health -= damage
	health_bar.value = health

	if health <= 0:
		queue_free()

func shout(key: String) -> void:
	if not shout_texts.has(key):
		return

	var text = shout_texts[key].pick_random()
	text = "The messenger shouts: " + text
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

	var tween = create_tween().set_parallel()
	tween.tween_property(shout_label, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(shout_label, "modulate:a", 1.0, 0.25)

	var final_y_pos = -140.0 - (shout_label.size.y / 2.0)
	tween.tween_property(shout_label, "position:y", final_y_pos, 0.5)

	tween.chain().tween_property(shout_label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(func(): shout_label.text = "")

func _move_wobble() -> void:
	if velocity.length() > 10.0:
		sprite.rotation_degrees = sin(Time.get_ticks_msec() / 100.0) * 3.0
	else:
		sprite.rotation_degrees = move_toward(sprite.rotation_degrees, 0.0, 0.5)

func _on_threat_detected(side: String) -> void:
	var key = side.to_lower()
	var now = Time.get_unix_time_from_system()
	if now - cooldowns[key] > SHOUT_COOLDOWN:
		shout(key)
		cooldowns[key] = now

func _on_threat_cleared(side: String) -> void:
	var key = side.to_lower()
	cooldowns[key] = 0.0

func _check_villagers_only() -> void:
	var now = Time.get_unix_time_from_system()
	for villager in get_tree().get_nodes_in_group("villagers"):
		if not is_instance_valid(villager):
			continue
		for monster in get_tree().get_nodes_in_group("monsters"):
			if monster.global_position.distance_to(villager.global_position) < 150.0:
				if now - cooldowns["villagers"] > SHOUT_COOLDOWN:
					shout("villagers")
					cooldowns["villagers"] = now
				return

func get_health() -> int:
	return int(health)

func get_max_health() -> int:
	return int(max_health)

func heal(amount: int) -> void:
	health = clamp(health + amount, 0.0, max_health)
	if health_bar:
		health_bar.value = health
