# gate_detector.gd - Reusable for all gates

extends Area2D

signal threat_detected(side: String)
signal threat_cleared(side: String)

@export var side: String = "town"  # Set in editor: "north", "west", "town"

@onready var clear_timer: Timer = $clear_timer

var monster_count: int = 0

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	clear_timer.timeout.connect(_on_clear_timer_timeout)
	add_to_group("gate_detectors")
	print("Gate detector '%s' ready at %s" % [side, global_position])

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("monsters"):
		monster_count += 1
		if monster_count == 1:
			threat_detected.emit(side)
			print(">>> %s gate under attack!" % side.to_upper())

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("monsters"):
		monster_count -= 1
		if monster_count <= 0:
			monster_count = 0
			clear_timer.start()

func _on_clear_timer_timeout() -> void:
	if monster_count == 0:
		threat_cleared.emit(side)
		print(">>> %s gate cleared" % side.to_upper())
