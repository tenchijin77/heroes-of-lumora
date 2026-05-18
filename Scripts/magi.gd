# magi.gd - stationary wizard turret that shoots magic missiles at nearby monsters
extends CharacterBody2D

@export var shoot_rate: float = 1.2
@export var shoot_range: float = 280.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $muzzle
@onready var bullet_pool: NodePool = $bullet_pool
@onready var detection_area: Area2D = $detection_area

var current_target: CharacterBody2D = null
var detected_monsters: Array[CharacterBody2D] = []
var last_shoot_time: float = 0.0

func _ready() -> void:
	add_to_group("friendly")
	collision_layer = 0  # No physical presence — monsters pass through freely
	collision_mask = 0   # Stationary turret, doesn't push against anything
	velocity = Vector2.ZERO
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_error("Magi %s: detection_area not found!" % name)

func _process(_delta: float) -> void:
	_update_target()
	if current_target:
		_update_facing()
		_try_shoot()

func _update_target() -> void:
	# Prune invalid or dead entries
	detected_monsters = detected_monsters.filter(
		func(m): return is_instance_valid(m) and m.visible and m.is_in_group("monsters")
	)
	# Fallback scan: catch monsters that entered range before this magi spawned
	if detected_monsters.is_empty():
		for mob in get_tree().get_nodes_in_group("monsters"):
			if is_instance_valid(mob) and mob.visible and global_position.distance_to(mob.global_position) <= shoot_range:
				detected_monsters.append(mob as CharacterBody2D)
	if not detected_monsters.is_empty():
		detected_monsters.sort_custom(
			func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
		)
		current_target = detected_monsters[0]
	else:
		current_target = null

func _update_facing() -> void:
	sprite.flip_h = current_target.global_position.x > global_position.x

func _try_shoot() -> void:
	var time: float = Time.get_unix_time_from_system()
	if time - last_shoot_time >= shoot_rate:
		last_shoot_time = time
		_shoot()

func _shoot() -> void:
	if not current_target or not is_instance_valid(current_target):
		return
	if not bullet_pool or not muzzle:
		return
	var base_dir: Vector2 = muzzle.global_position.direction_to(current_target.global_position)
	var spreads: Array[float] = [-0.28, 0.0, 0.28]  # ~±16 degrees
	for spread in spreads:
		var missile: Area2D = bullet_pool.spawn()
		if missile:
			missile.owner_group = "friendly"
			missile.home_target = current_target
			missile.home_strength = 3.0
			missile.launch(muzzle.global_position, base_dir.rotated(spread))

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("monsters") and body.visible and body is CharacterBody2D and not detected_monsters.has(body):
		detected_monsters.append(body)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if detected_monsters.has(body):
		detected_monsters.erase(body)
