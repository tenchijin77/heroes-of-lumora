# villager.gd - Controls the villager npcs
extends CharacterBody2D

@export var speed: float = 100.0
@export var panic_speed: float = 200.0
@export var detection_radius: float = 200.0
@export var extraction_zone: NodePath

var state: String = "IDLE"
var target_position: Vector2
var navigation_agent: NavigationAgent2D

# Called when the node enters the scene tree
func _ready():
    navigation_agent = $NavigationAgent2D
    set_physics_process(true)

# Main movement logic
func _physics_process(delta: float):
    match state:
        "IDLE":
            _wander_randomly()
        "PANIC":
            _run_from_threat()
        "FROZEN":
            # Do nothing
            pass
        "EXTRACTING":
            _move_to_extraction()

# Detect nearby monsters
func _on_detection_area_body_entered(body):
    if body.is_in_group("monster"):
        state = "PANIC"

# Wander logic
func _wander_randomly():
    # Pick a random direction and move
    pass

# Panic logic
func _run_from_threat():
    # Move away from nearest monster
    pass

# Extraction logic
func _move_to_extraction():
    # Move toward extraction zone
    pass
