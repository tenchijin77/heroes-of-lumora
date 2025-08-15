#tenchijin.gd - AI for Tenchijin's logic
#tenchijin.gd - AI for Tenchijin's logic
extends CharacterBody2D

@export var max_speed: float = 30.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var cast_range: float = 250.0
@export var current_health: int = 200
@export var max_health: int = 200

@export var meteor_rate: float = 30.0
@export var time_warp_rate: float = 60.0
@export var frost_nova_rate: float = 20.0
@export var arcane_power_rate: float = 40.0
@export var disintegrate_rate: float = 15.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var detection_area: Area2D = $Area2D
@onready var health_bar: ProgressBar = $health_bar
@onready var avoidance_ray: RayCast2D = $avoidance_ray
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var casting_label: Label = $CastingLabel
@onready var casting_timer: Timer = $CastingTimer

var current_target: CharacterBody2D = null
var detected_monsters: Array[CharacterBody2D] = []
var current_state: String = "IDLE"
var last_cast_time: float = 0.0

func _ready():
	add_to_group("friendly")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	if casting_timer:
		casting_timer.timeout.connect(func(): casting_label.text = "")

func _process(delta: float) -> void:
	_update_target()
	_update_avoidance_ray(current_target, cast_range)

	match current_state:
		"IDLE":
			_idle_state(delta)
		"POSITIONING":
			_positioning_state(delta)
		"ATTACKING":
			_attacking_state(delta)
		"STRATEGIC_MOVE":
			_strategic_move_state(delta)

	_update_flip_h()

func _physics_process(delta: float) -> void:
	move_and_slide()

# --- Targeting & State Logic ---
func _update_target():
	detected_monsters = detected_monsters.filter(
		func(m): return is_instance_valid(m) and m.is_in_group("monsters")
	)
	detected_monsters.sort_custom(
		func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	if not detected_monsters.is_empty():
		current_target = detected_monsters[0]
		if current_state == "IDLE":
			current_state = "POSITIONING"
	else:
		current_target = null
		if current_state in ["POSITIONING", "ATTACKING"]:
			current_state = "STRATEGIC_MOVE"

# --- New States ---
func _idle_state(delta: float):
	velocity = Vector2.ZERO

func _positioning_state(delta: float):
	if current_target:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= cast_range:
			current_state = "ATTACKING"
		else:
			var dir = global_position.direction_to(current_target.global_position)
			velocity = velocity.lerp(dir * max_speed, acceleration * delta)
	else:
		current_state = "STRATEGIC_MOVE"

func _attacking_state(delta: float):
	velocity = Vector2.ZERO
	if not current_target or not is_instance_valid(current_target):
		current_state = "POSITIONING"
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	if dist > cast_range or not _has_clear_line_to_target(current_target):
		current_state = "POSITIONING"
		return
	
	_perform_spell_attack()

func _strategic_move_state(delta: float):
	if player:
		var player_pos = player.global_position
		var desired_pos = player_pos + Vector2(-150, 0).rotated(randf_range(0, PI * 2))
		var dist = global_position.distance_to(desired_pos)
		if dist < 100: # Close enough to the strategic position
			velocity = Vector2.ZERO
			current_state = "IDLE"
		else:
			var direction = global_position.direction_to(desired_pos)
			velocity = velocity.lerp(direction * max_speed, acceleration * delta)
	else:
		velocity = Vector2.ZERO

# --- Actions ---
func _perform_spell_attack():
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_cast_time > disintegrate_rate:
		last_cast_time = current_time
		_show_casting_text("Disintegrate!")
		_cast_disintegrate()
	# Add more conditions for other spells here

# --- Utility Functions ---
func _update_avoidance_ray(target: Node2D, range: float):
	if avoidance_ray and target and is_instance_valid(target):
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target: Node2D) -> bool:
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target

func _update_flip_h():
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false
	elif current_target:
		sprite.flip_h = global_position.direction_to(current_target.global_position).x > 0

func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("monsters") and body is CharacterBody2D and not detected_monsters.has(body):
		detected_monsters.append(body)

func _on_detection_area_body_exited(body: Node2D):
	if detected_monsters.has(body):
		detected_monsters.erase(body)

func _show_casting_text(text: String):
	if casting_label and casting_timer:
		casting_label.text = text
		casting_timer.start()

# --- Placeholder Casting Functions (to be implemented) ---
func _is_group_attack_needed() -> bool:
	return detected_monsters.size() >= 3

func _is_high_priority_target() -> bool:
	return current_target and current_target.get_health() > 500
	
func _cast_meteor():
	print("Ten: Casting Meteor!")

func _cast_time_warp():
	print("Ten: Casting Time Warp!")

func _cast_frost_nova():
	print("Ten: Casting Frost Nova!")

func _cast_arcane_power():
	print("Ten: Casting Arcane Power!")

func _cast_disintegrate():
	print("Ten: Casting Disintegrate!")
