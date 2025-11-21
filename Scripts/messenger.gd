# messenger.gd

extends CharacterBody2D

@onready var sprite: Sprite2D = $sprite_2d
@onready var collision_shape: CollisionShape2D = $collision_shape_2d
@onready var check_timer: Timer = $check_timer
@onready var health_bar: ProgressBar = $health_bar

var shout_label: Label

const SPEED: float = 150.0
const ARRIVE_DISTANCE: float = 50.0
const SHOUT_COOLDOWN: float = 6.0
const VILLAGER_CHECK_INTERVAL: float = 2.0

enum State { RUNNING, STANDING }

var state: State = State.RUNNING
var town_center_pos: Vector2 = Vector2(808, 379)

var cooldowns: Dictionary = {"north":0.0, "west":0.0, "town":0.0, "villagers":0.0}

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
	# Add to group immediately.
	add_to_group("friendly")
	call_deferred("_deferred_ready")

func _deferred_ready() -> void:
## Setup Shout Label
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
	
	# 🟢 GODOT 4: Use autowrap_mode and clip_text for wrapping
	shout_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	shout_label.clip_text = true 
	
	shout_label.position = Vector2(0, -100)
	# This size.x (400) now acts as the max width for wrapping
	shout_label.size = Vector2(400, 80) 
	shout_label.pivot_offset = shout_label.size / 2
	shout_label.modulate.a = 0.0
	
## Town Center Position
	var markers = get_tree().current_scene.get_node_or_null("town_markers")
	if markers and markers.has_node("town_center"):
		town_center_pos = markers.get_node("town_center").global_position
	
## 🚨 CRITICAL FIX: Signal Connection Argument Mismatch
	for detector in get_tree().get_nodes_in_group("gate_detectors"):
		if detector is Area2D:
			var side: String = detector.side
			print("Messenger CONNECTED to %s detector!" % side.to_upper())
			
			detector.threat_detected.connect(func(_arg=null): _on_threat_detected(side))
			detector.threat_cleared.connect(func(_arg=null): _on_threat_cleared(side))
	
	health_bar.max_value = max_health
	health_bar.value = health
	
	if check_timer:
		check_timer.wait_time = VILLAGER_CHECK_INTERVAL
		check_timer.timeout.connect(_check_villagers_only)

func _physics_process(_delta: float) -> void:
	if state == State.RUNNING:
		var dist: float = global_position.distance_to(town_center_pos)
		if dist <= ARRIVE_DISTANCE:
			state = State.STANDING
			velocity = Vector2.ZERO
			if check_timer:
				check_timer.start()
			shout("initial")
		else:
			var dir: Vector2 = (town_center_pos - global_position).normalized()
			velocity = dir * SPEED
			if sprite:
				sprite.flip_h = dir.x < 0
	move_and_slide()
	
	_move_wobble()

func _move_wobble() -> void:
	if velocity.length() > 10.0:
		sprite.rotation_degrees = sin(Time.get_ticks_msec() / 100.0) * 3.0
	else:
		sprite.rotation_degrees = move_toward(sprite.rotation_degrees, 0.0, 0.5)

## 🔑 Key Standardization and Logic
func _on_threat_detected(side: String) -> void:
	# Convert to lowercase to ensure robust dictionary lookups
	var key: String = side.to_lower()
	
	print("ATTENTION: Threat detected for key: ['%s']" % key)
	
	var now: float = Time.get_unix_time_from_system()
	
	# Use 'key' for the dictionary lookups
	if now - cooldowns[key] > SHOUT_COOLDOWN:
		shout(key)
		cooldowns[key] = now

func _on_threat_cleared(side: String) -> void:
	# Convert to lowercase for key standardization
	var key: String = side.to_lower()
	cooldowns[key] = 0.0

func _check_villagers_only() -> void:
	var now: float = Time.get_unix_time_from_system()
	for villager in get_tree().get_nodes_in_group("villagers"):
		if not is_instance_valid(villager):
			continue
		for monster in get_tree().get_nodes_in_group("monsters"):
			if monster.global_position.distance_to(villager.global_position) < 150.0:
				if now - cooldowns["villagers"] > SHOUT_COOLDOWN:
					shout("villagers")
					cooldowns["villagers"] = now
				return

func shout(key: String) -> void:
	# 1. Safety check
	if not shout_texts.has(key) or not shout_texts[key] is Array:
		print("ERROR: Tried to shout with invalid key or non-array value: %s" % key)
		return
	
	# 2. Randomly select one phrase from the array
	var text_array: Array = shout_texts[key]
	var text: String = text_array.pick_random()
	
	print("Messenger shouts: %s" % text)
	
	# 🟢 FINAL HEIGHT FIX: Use get_line_count() and a generous line height multiplier (1.7)
	shout_label.size.x = 400.0 
	
	# Set text and wait for one frame for the Label to process the wrapping internally
	shout_label.set_deferred("text", text)
	await get_tree().process_frame
	
	# Get the correct font height for line spacing
	var font_height = shout_label.get_theme_font_size("font_size") * 1.7 # Multiplier increased for guaranteed clearance
	var line_count = shout_label.get_line_count()
	
	shout_label.size.y = float(line_count) * font_height 
	shout_label.pivot_offset = shout_label.size / 2
	
	shout_label.scale = Vector2(0.2, 0.2)
	shout_label.modulate.a = 0.0
	
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(shout_label, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(shout_label, "modulate:a", 1.0, 0.25)
	
	# Calculate final Y position based on new (oversized) height
	var final_y_pos: float = -140.0 - (shout_label.size.y / 2.0)
	
	tween.tween_property(shout_label, "position:y", final_y_pos, 0.5) 
	tween.chain().tween_property(shout_label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(func(): shout_label.text = "")

# --- Villager-compatible Health Functions ---

## 🟢 Healer-compatible current health getter
func get_health() -> int:
	return int(health)

## 🟢 Healer-compatible max health getter
func get_max_health() -> int:
	return int(max_health)

## 🟢 Dedicated heal function (Used by Healer projectile/Aura)
func heal(amount: int) -> void:
	health = clamp(health + amount, 0.0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = health
	print("Messenger healed for %d → current_health = %d" % [amount, health])

# --- Damage ---

func take_damage(damage: int, _projectile_instance) -> void:
	# Check if this is a HEAL (negative damage, e.g. from Healing Aura)
	if damage < 0:
		heal(-damage)
		return
	
	# Process regular damage
	health -= damage
	print("Messenger damaged for %d → current_health = %d" % [damage, health])
		
	health_bar.value = health
	
	if health <= 0:
		print("Messenger has fallen--Goodbye, cruel world!!")
		queue_free()
