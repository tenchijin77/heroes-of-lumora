# coin.gd - handles coin bounce, movement toward player, and pickup sound

extends Area2D

var speed: float = 100.0
var target: Node2D
var initial_y: float
var bounce_height: float = 20.0  # Height of bounce
var bounce_duration: float = 1.0  # Time for one bounce cycle
var activation_radius: float = 30.0  # or however close you want


@onready var coin_sound: AudioStreamPlayer2D = $coin_sound

func _ready() -> void:
	add_to_group("loot")  # Add to loot group for pickup detection
	target = get_tree().get_first_node_in_group("player")
	initial_y = global_position.y
	if not $CollisionShape2D.shape:
		push_error("Coin: Missing CollisionShape2D shape!")
	start_bounce()

func _process(delta: float) -> void:
	if target:
		var to_target = target.global_position - global_position
		if to_target.length() <= activation_radius:
			var direction = to_target.normalized()
			global_position += direction * speed * delta

# Start the bounce animation
func start_bounce() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position:y", initial_y - bounce_height, bounce_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", initial_y, bounce_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(bounce_duration / 2)
	tween.set_loops(0)  # Infinite loops
	tween.play()

# Signal pickup to play sound (called from player.gd)
func play_pickup_sound() -> void:
	if coin_sound and coin_sound.stream:
		coin_sound.play()
		
func collect():
	play_pickup_sound()
	await get_tree().create_timer(0.2).timeout
	queue_free()
