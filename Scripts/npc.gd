extends CharacterBody2D

var npc_size: String = "medium"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	if navigation_agent:
		navigation_agent.path_desired_distance = 12.0
		navigation_agent.target_desired_distance = 24.0
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_neighbors = 5
		navigation_agent.neighbor_distance = 40.0
		_auto_tune_from_collision()

func _auto_tune_from_collision() -> void:
	if not collision_shape or not collision_shape.shape or not navigation_agent:
		return

	var max_dim: float = 0.0

	# Determine footprint from collision shape
	if collision_shape.shape is RectangleShape2D:
		var size: Vector2 = collision_shape.shape.size
		max_dim = max(size.x, size.y)
	elif collision_shape.shape is CircleShape2D:
		max_dim = collision_shape.shape.radius * 2.0
	else:
		return

	# Classify NPC size
	if max_dim < 32.0:
		npc_size = "small"
	elif max_dim < 64.0:
		npc_size = "medium"
	else:
		npc_size = "large"

	# Tune navigation radius
	navigation_agent.radius = max_dim * 0.5

func _physics_process(delta: float) -> void:
	if navigation_agent and not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var dir = global_position.direction_to(next_pos)
		velocity = dir * 60.0
		move_and_slide()
