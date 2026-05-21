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
@onready var poof_sprite: AnimatedSprite2D = $poof_sprite


func _ready() -> void:
	add_to_group("loot")
	target = get_tree().get_first_node_in_group("player")
	initial_y = global_position.y
	if not $CollisionShape2D.shape:
		push_error("Potion: Missing CollisionShape2D shape!")
	start_bounce()
	var lifetime := get_tree().create_timer(20.0)
	lifetime.timeout.connect(_on_lifetime_expired)

func _process(delta: float) -> void:
	if target:
		var to_target = target.global_position - global_position
		var distance = to_target.length()
		if distance <= activation_radius:
			var direction = to_target.normalized()
			global_position += direction * speed * delta

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
		potion_sound.volume_db = 0.0  # Ensure volume is audible
		potion_sound.stream_paused = false  # Ensure not paused
		potion_sound.play()

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
	
	# FIXED: Start bounce AFTER position is set correctly
	initial_y = global_position.y
	start_bounce()

# Signal pickup to play sound and apply effect
func collect() -> void:
	play_pickup_sound()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_potion_effect(effect_type, effect_value, effect_duration)
		if tween and tween.is_running():  # Check if tween exists and is running
			tween.kill()
			
		if poof_sprite:
			$Sprite2D.hide()  # Hide the coin
			poof_sprite.show()
			poof_sprite.play("poof")  # Your animation name
			
	await get_tree().create_timer(0.3).timeout
	queue_free()

# FIXED: Added reset() method for NodePool compatibility
func _on_lifetime_expired() -> void:
	if is_inside_tree():
		queue_free()

func reset() -> void:
	"""Reset potion state for object pooling"""
	# Stop any active tween
	if tween and tween.is_running():
		tween.kill()
	
	# Reset all variables to defaults
	potion_id = ""
	effect_type = ""
	effect_value = 0.0
	effect_duration = 0.0
	speed = 100.0
	
	# Reset position
	global_position = Vector2.ZERO
	initial_y = 0.0
	
	# Show sprite, hide poof
	if has_node("Sprite2D"):
		$Sprite2D.show()
	if poof_sprite:
		poof_sprite.hide()
	
	# Re-find player target
	if is_inside_tree():
		target = get_tree().get_first_node_in_group("player")
	
	# DON'T start bounce here - position isn't set yet!
	# Bounce will be started in setup() after position is correct
