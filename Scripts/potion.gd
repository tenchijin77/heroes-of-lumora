# potion.gd - handles potion bounce, movement toward player, and pickup sound

extends Area2D

var potion_id: String = ""
var effect_type: String = ""
var effect_value: float = 0.0
var effect_duration: float = 0.0
var speed: float = 100.0
var target: Node2D
var initial_y: float
var bounce_height: float = 15.0  # Height of bounce
var bounce_duration: float = 1.0  # Time for one bounce cycle
var activation_radius: float = 60.0  # Increased range to start moving toward player
var tween: Tween  # Declare tween as a class variable

@onready var potion_sound: AudioStreamPlayer2D = $potion_sound

func _ready() -> void:
	add_to_group("loot")  # Add to loot group for pickup detection
	target = get_tree().get_first_node_in_group("player")
	if not target:
		print("Potion warning: No player found in 'player' group!")
	initial_y = global_position.y
	if not $CollisionShape2D.shape:
		push_error("Potion: Missing CollisionShape2D shape!")
	start_bounce()

func _process(delta: float) -> void:
	if target:
		var to_target = target.global_position - global_position
		var distance = to_target.length()
		if distance <= activation_radius:
			var direction = to_target.normalized()
			global_position += direction * speed * delta
			print("Potion moving toward player at %s, distance: %f" % [str(global_position), distance])

# Start the bounce animation
func start_bounce() -> void:
	tween = create_tween()  # Initialize tween here
	tween.tween_property(self, "global_position:y", initial_y - bounce_height, bounce_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", initial_y, bounce_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(bounce_duration / 2)
	tween.set_loops(0)  # Infinite loops
	tween.play()

# Play the pickup sound
func play_pickup_sound() -> void:
	if potion_sound and potion_sound.stream:
		print("Attempting to play potion sound at %s, volume: %s, stream_paused: %s" % [str(global_position), potion_sound.volume_db, potion_sound.stream_paused])
		potion_sound.volume_db = 0.0  # Ensure volume is audible
		potion_sound.stream_paused = false  # Ensure not paused
		potion_sound.play()
		await get_tree().create_timer(0.1).timeout
		if potion_sound.playing:
			print("Potion sound playing at %s" % str(global_position))
		else:
			print("Potion sound failed to play at %s, playing status: %s" % [str(global_position), potion_sound.playing])
	else:
		print("Potion sound setup failed: potion_sound=%s, stream=%s" % [potion_sound, potion_sound.stream if potion_sound else "null"])

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

# Signal pickup to play sound and apply effect
func collect() -> void:
	play_pickup_sound()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_potion_effect(effect_type, effect_value, effect_duration)
		if tween and tween.is_running():  # Check if tween exists and is running
			tween.kill()
			
		await get_tree().create_timer(0.3).timeout
		queue_free()
		print("Picked up potion!")  # Updated debug message
