# priestess.gd — Modular support NPC: heals player and friendlies, damages enemies
extends CharacterBody2D

@export var max_speed : float = 30.0
@export var acceleration : float = 10.0
@export var spell_rate : float = 1.2
@export var spell_range : float = 180.0
@export var heal_amount : int = 6
@export var spell_damage : int = 4
@export var max_health : int = 20
@export var current_health : int = 20

@onready var sprite: Sprite2D = $Sprite2D
@onready var cast_point: Node2D = $cast_point
@onready var spell_pool: NodePool = $spell_pool
@onready var detection_area: Area2D = $Area2D
@onready var health_bar: ProgressBar = $health_bar

var detected_targets: Array[CharacterBody2D] = []
var current_target: CharacterBody2D = null
var current_state: String = "IDLE"
var last_cast_time: float = 0.0
var home_position: Vector2

func _ready():
	home_position = global_position
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func _process(delta: float) -> void:
	_update_target()
	match current_state:
		"IDLE":
			velocity = Vector2.ZERO
		"SUPPORTING":
			velocity = Vector2.ZERO
			_cast_spell()
		"ATTACKING":
			velocity = Vector2.ZERO
			_cast_spell()
		"RETURNING":
			_return_to_home(delta)

func _physics_process(delta: float) -> void:
	move_and_slide()

func _on_detection_area_body_entered(body: Node2D):
	if body is CharacterBody2D and (
		body.is_in_group("monsters")
		or body.is_in_group("friendly")
		or body.is_in_group("player")
	):
		if not detected_targets.has(body):
			detected_targets.append(body)

func _on_detection_area_body_exited(body: Node2D):
	detected_targets.erase(body)

func _update_target():
	detected_targets = detected_targets.filter(func(t):
		return is_instance_valid(t)
	)

	var friendlies := detected_targets.filter(func(t):
		return (t.is_in_group("friendly") or t.is_in_group("player")) and t.current_health < t.max_health
	)
	friendlies.sort_custom(func(a, b):
		return a.current_health < b.current_health
	)

	var enemies := detected_targets.filter(func(t):
		return t.is_in_group("monsters")
	)
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	if friendlies.size() > 0:
		current_target = friendlies[0]
		current_state = "SUPPORTING"
	elif enemies.size() > 0:
		current_target = enemies[0]
		current_state = "ATTACKING"
	else:
		current_target = null
		current_state = "RETURNING"

func _return_to_home(delta: float):
	var distance = global_position.distance_to(home_position)
	if distance < 5.0:
		velocity = Vector2.ZERO
		current_state = "IDLE"
	else:
		var dir = global_position.direction_to(home_position)
		velocity = velocity.lerp(dir * max_speed, acceleration * delta)

func _cast_spell():
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_cast_time > spell_rate:
		last_cast_time = current_time
		if spell_pool and cast_point and current_target and is_instance_valid(current_target):
			var spell = spell_pool.spawn()
			if spell:
				spell.global_position = cast_point.global_position
				spell.move_direction = cast_point.global_position.direction_to(current_target.global_position)
				spell.owner_group = "friendly"
				spell.heal_amount = heal_amount
				spell.damage = spell_damage
				spell.can_heal = current_target.is_in_group("friendly") or current_target.is_in_group("player")
				spell.can_damage = current_target.is_in_group("monsters")
				print("Priestess %s: Cast spell at %s" % [name, current_target.name])
			else:
				push_warning("Priestess %s: Failed to spawn spell projectile!" % name)

func take_damage(damage : int):
	current_health -= damage
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_flash(Color.RED)

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	if health_bar:
		health_bar.value = current_health
		_flash(Color.GREEN)

func _flash(color: Color):
	sprite.modulate = color
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE

func _die():
	print("Priestess %s died!" % name)
	if get_parent() is NodePool:
		get_parent().despawn(self)
	else:
		visible = false
		set_process(false)
		set_physics_process(false)
		if $CollisionShape2D:
			$CollisionShape2D.set_deferred("disabled", true)
