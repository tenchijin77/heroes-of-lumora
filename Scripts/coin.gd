# coin.gd - handles coin movement, bounce, and pickup sound

extends CharacterBody2D

var speed: float = 100.0
var target: Node2D
var initial_y: float
var bounce_height: float = 20.0  # Height of bounce
var bounce_duration: float = 1.0  # Time for one bounce cycle

@onready var coin_sound: AudioStreamPlayer2D = $coin_sound

func _ready() -> void:
	add_to_group("loot")  # Add to loot group for pickup detection
	target = get_tree().get_first_node_in_group("player")
	initial_y = global_position.y
	if not $CollisionShape2D.shape:
		push_error("Coin: Missing CollisionShape2D shape!")
	start_bounce()

func _physics_process(delta: float) -> void:
	if target:
		var direction: Vector2 = (target.global_position - global_position).normalized()
		var velocity: Vector2 = direction * speed
		velocity.y = 0  # Lock vertical movement to tween control
		move_and_slide()

# Start the bounce animation
func start_bounce() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position:y", initial_y - bounce_height, bounce_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", initial_y, bounce_duration / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(bounce_duration / 2)
	tween.set_loops(0)  # Infinite loops (0 means forever)
	tween.play()

# Signal pickup to play sound (called from player.gd)
func play_pickup_sound() -> void:
	if coin_sound and coin_sound.stream:
		coin_sound.play()
