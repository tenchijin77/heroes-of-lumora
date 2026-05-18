# tenchijin.gd - Archmage who arrives to turn the tide; uses frost and arcane spells
extends CharacterBody2D

@export var max_speed: float = 80.0
@export var acceleration: float = 10.0
@export var drag: float = 0.9
@export var cast_range: float = 280.0
@export var current_health: int = 200
@export var max_health: int = 200

# Spell cooldown rates
@export var frost_bolt_rate: float = 0.8
@export var frost_nova_rate: float = 45.0
@export var meteor_rate: float = 60.0
@export var disintegrate_rate: float = 10.0
@export var time_warp_rate: float = 90.0

# Spell parameters
@export var frost_bolt_damage: int = 60
@export var frost_bolt_slow: float = 0.15
@export var frost_bolt_slow_duration: float = 6.0
@export var frost_nova_range: float = 333.0
@export var frost_nova_root_duration: float = 4.0
@export var meteor_damage: int = 200
@export var meteor_dot_per_sec: int = 15
@export var meteor_dot_ticks: int = 6
@export var meteor_range: float = 333.0
@export var disintegrate_damage: int = 200
@export var time_warp_speed_bonus: float = 0.1
@export var time_warp_duration: float = 8.0
@export var escape_hp_threshold: float = 0.3
@export var recover_hp_threshold: float = 0.5

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
var _strategic_target: Vector2 = Vector2.ZERO
var ability_cooldowns: Dictionary = {
	"frost_bolt": 0.0,
	"frost_nova": 0.0,
	"meteor": 0.0,
	"disintegrate": 0.0,
	"time_warp": 0.0
}

func _ready() -> void:
	add_to_group("friendly")
	add_to_group("tenchijin")
	collision_mask = 16  # Environment only — don't collide with player or friendlies

	visible = false
	set_process(false)
	set_physics_process(false)

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	if casting_timer:
		casting_timer.wait_time = 3.0
		casting_timer.timeout.connect(func(): casting_label.text = "")

	# Connect to Anna's distress signals — deferred so all nodes are ready
	_connect_spawn_triggers.call_deferred()

func _connect_spawn_triggers() -> void:
	var anna = get_tree().get_first_node_in_group("annadaeus")
	if anna:
		if anna.has_signal("health_critical") and not anna.health_critical.is_connected(_on_summon_triggered):
			anna.health_critical.connect(_on_summon_triggered)
		if anna.has_signal("died") and not anna.died.is_connected(_on_summon_triggered):
			anna.died.connect(_on_summon_triggered)
	else:
		push_warning("Tenchijin: Annadaeus not found — wave threshold is the only trigger")
	if Global.has_signal("wave_updated"):
		Global.wave_updated.connect(_on_wave_updated)

func _on_summon_triggered() -> void:
	if not visible:
		dramatic_entrance()

func _on_wave_updated(wave: int) -> void:
	if wave >= 8 and not visible:
		dramatic_entrance()

func dramatic_entrance() -> void:
	visible = true
	set_process(true)
	set_physics_process(true)
	_show_casting_text("Tenchijin arrives! The tide turns now!")
	print("Tenchijin: Stand firm! I shall turn the tide!")

func _process(delta: float) -> void:
	_update_target()
	_update_cooldowns(delta)
	if current_target and is_instance_valid(current_target):
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
		"ESCAPING":
			_escaping_state(delta)

	_update_flip_h()

func _physics_process(_delta: float) -> void:
	move_and_slide()

func _update_cooldowns(delta: float) -> void:
	for key in ability_cooldowns:
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] -= delta

# --- Targeting & State ---
func _update_target() -> void:
	detected_monsters = detected_monsters.filter(
		func(m): return is_instance_valid(m) and m.visible and m.is_in_group("monsters")
	)
	detected_monsters.sort_custom(
		func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	# Flee when health is critical
	if current_health < max_health * escape_hp_threshold and current_state != "ESCAPING":
		current_state = "ESCAPING"
		return
	if current_state == "ESCAPING" and current_health >= max_health * recover_hp_threshold:
		current_state = "IDLE"
	if current_state == "ESCAPING":
		return

	if not detected_monsters.is_empty():
		current_target = detected_monsters[0]
		if current_state in ["IDLE", "STRATEGIC_MOVE"]:
			current_state = "POSITIONING"
	else:
		current_target = null
		if current_state in ["POSITIONING", "ATTACKING"]:
			if player and is_instance_valid(player):
				_strategic_target = player.global_position + Vector2(-150, 0).rotated(randf_range(0.0, TAU))
			current_state = "STRATEGIC_MOVE"

# --- States ---
func _idle_state(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, drag)

func _positioning_state(delta: float) -> void:
	if current_target and is_instance_valid(current_target):
		var dist := global_position.distance_to(current_target.global_position)
		if dist <= cast_range:
			current_state = "ATTACKING"
		else:
			var dir := global_position.direction_to(current_target.global_position)
			velocity = velocity.lerp(dir * max_speed, acceleration * delta)
	else:
		current_state = "STRATEGIC_MOVE"

func _attacking_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	if not current_target or not is_instance_valid(current_target):
		current_state = "POSITIONING"
		return
	var dist := global_position.distance_to(current_target.global_position)
	if dist > cast_range or not _has_clear_line_to_target(current_target):
		current_state = "POSITIONING"
		return
	_perform_spell_rotation()

func _strategic_move_state(delta: float) -> void:
	var dist := global_position.distance_to(_strategic_target)
	if dist < 80.0:
		velocity = velocity.lerp(Vector2.ZERO, drag)
		current_state = "IDLE"
	else:
		var dir := global_position.direction_to(_strategic_target)
		velocity = velocity.lerp(dir * max_speed, acceleration * delta)

func _escaping_state(delta: float) -> void:
	var closest := _find_closest_mob_globally()
	if closest and is_instance_valid(closest):
		var away := global_position.direction_to(closest.global_position).normalized()
		velocity = velocity.lerp(-away * max_speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, drag)

# --- Spell Rotation ---
func _perform_spell_rotation() -> void:
	# Time Warp: fire when 3+ enemies are pressing the player
	if ability_cooldowns["time_warp"] <= 0.0 and _allies_need_speed_buff():
		_cast_time_warp()
		return
	# Meteor: critical mass of enemies in range
	if ability_cooldowns["meteor"] <= 0.0 and _count_enemies_in_range(meteor_range) >= 3:
		_cast_meteor()
		return
	# Frost Nova: crowd control 2+ enemies
	if ability_cooldowns["frost_nova"] <= 0.0 and _count_enemies_in_range(frost_nova_range) >= 2:
		_cast_frost_nova()
		return
	# Disintegrate: single-target finisher
	if ability_cooldowns["disintegrate"] <= 0.0:
		_cast_disintegrate()
		return
	# Frost Bolt: filler attack
	if ability_cooldowns["frost_bolt"] <= 0.0:
		_cast_frost_bolt()

# --- Spells ---
func _cast_frost_bolt() -> void:
	if not bullet_pool or not muzzle or not current_target or not is_instance_valid(current_target):
		return
	ability_cooldowns["frost_bolt"] = frost_bolt_rate
	var projectile = bullet_pool.spawn()
	if not projectile:
		return
	projectile.owner_group = "friendly"
	projectile.damage = frost_bolt_damage
	projectile.slow_percent = frost_bolt_slow
	projectile.slow_duration = frost_bolt_slow_duration
	projectile.modulate = Color(0.5, 0.85, 1.0, 1.0)
	var direction := muzzle.global_position.direction_to(current_target.global_position)
	if projectile.has_method("launch"):
		projectile.launch(muzzle.global_position, direction)

func _cast_frost_nova() -> void:
	ability_cooldowns["frost_nova"] = frost_nova_rate
	_show_casting_text("Frost Nova!")
	var hit_count := 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and global_position.distance_to(mob.global_position) <= frost_nova_range:
			if mob.has_method("apply_root"):
				mob.apply_root(frost_nova_root_duration)
			hit_count += 1
	_spawn_nova_vfx()
	print("Tenchijin: Frost Nova rooted %d enemies for %.1fs" % [hit_count, frost_nova_root_duration])

func _cast_meteor() -> void:
	if not current_target or not is_instance_valid(current_target):
		return
	ability_cooldowns["meteor"] = meteor_rate
	_show_casting_text("Improved Meteor!")
	var target_pos := current_target.global_position
	_spawn_meteor_windup_vfx(target_pos)
	get_tree().create_timer(0.8).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_meteor_impact(target_pos)
	)

func _meteor_impact(impact_pos: Vector2) -> void:
	var hit_count := 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and impact_pos.distance_to(mob.global_position) <= meteor_range:
			if mob.has_method("take_damage"):
				mob.take_damage(meteor_damage, null)
			if mob.has_method("apply_dot"):
				mob.apply_dot(meteor_dot_per_sec, meteor_dot_ticks)
			hit_count += 1
	_spawn_meteor_impact_vfx(impact_pos)
	print("Tenchijin: Meteor struck %d enemies — %d dmg + %d/s DoT for %ds" % [hit_count, meteor_damage, meteor_dot_per_sec, meteor_dot_ticks])

func _cast_disintegrate() -> void:
	if not bullet_pool or not muzzle or not current_target or not is_instance_valid(current_target):
		return
	ability_cooldowns["disintegrate"] = disintegrate_rate
	_show_casting_text("Disintegrate!")
	var projectile = bullet_pool.spawn()
	if not projectile:
		return
	projectile.owner_group = "friendly"
	projectile.damage = disintegrate_damage
	projectile.modulate = Color(0.9, 0.5, 1.0, 1.0)
	var direction := muzzle.global_position.direction_to(current_target.global_position)
	if projectile.has_method("launch"):
		projectile.launch(muzzle.global_position, direction)

func _cast_time_warp() -> void:
	ability_cooldowns["time_warp"] = time_warp_rate
	_show_casting_text("Time Warp!")
	var targets: Array = []
	targets.append_array(get_tree().get_nodes_in_group("friendly"))
	targets.append_array(get_tree().get_nodes_in_group("player"))
	var buffed := 0
	for unit in targets:
		if is_instance_valid(unit) and unit.has_method("apply_speed_buff"):
			unit.apply_speed_buff(time_warp_speed_bonus, time_warp_duration)
			buffed += 1
	_spawn_time_warp_vfx()
	print("Tenchijin: Time Warp gave +%.0f%% speed to %d allies for %.1fs" % [time_warp_speed_bonus * 100.0, buffed, time_warp_duration])

# --- VFX ---
func _spawn_nova_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 100
	p.lifetime = 1.2
	p.spread = 180.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 250.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.4, 0.85, 1.0, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_meteor_windup_vfx(target_pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = target_pos + Vector2(0.0, -250.0)
	p.one_shot = true
	p.explosiveness = 0.4
	p.amount = 40
	p.lifetime = 0.7
	p.spread = 20.0
	p.direction = Vector2(0.0, 1.0)
	p.initial_velocity_min = 200.0
	p.initial_velocity_max = 350.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(1.0, 0.5, 0.1, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_meteor_impact_vfx(impact_pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = impact_pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 140
	p.lifetime = 1.8
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 280.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.color = Color(1.0, 0.35, 0.05, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_time_warp_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 70
	p.lifetime = 2.0
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.75, 0.4, 1.0, 0.9)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

# --- Utility ---
func _count_enemies_in_range(range_dist: float) -> int:
	var count := 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and global_position.distance_to(mob.global_position) <= range_dist:
			count += 1
	return count

func _find_closest_mob_globally() -> CharacterBody2D:
	var closest: CharacterBody2D = null
	var min_dist := INF
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible:
			var d := global_position.distance_to(mob.global_position)
			if d < min_dist:
				min_dist = d
				closest = mob as CharacterBody2D
	return closest

func _allies_need_speed_buff() -> bool:
	if not player or not is_instance_valid(player):
		return false
	var nearby := 0
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible and player.global_position.distance_to(mob.global_position) < 400.0:
			nearby += 1
	return nearby >= 3

func _update_avoidance_ray(target: Node2D, range_dist: float) -> void:
	if avoidance_ray and target and is_instance_valid(target):
		avoidance_ray.target_position = (target.global_position - global_position).normalized() * range_dist
		avoidance_ray.force_raycast_update()

func _has_clear_line_to_target(target: Node2D) -> bool:
	if not avoidance_ray:
		return true
	return not avoidance_ray.is_colliding() or avoidance_ray.get_collider() == target

func _update_flip_h() -> void:
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false
	elif current_target and is_instance_valid(current_target):
		sprite.flip_h = global_position.direction_to(current_target.global_position).x > 0

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("monsters") and body.visible and body is CharacterBody2D and not detected_monsters.has(body):
		detected_monsters.append(body)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if detected_monsters.has(body):
		detected_monsters.erase(body)

func _show_casting_text(text: String) -> void:
	if casting_label and casting_timer:
		casting_label.text = text
		casting_timer.start()

# --- Health / Combat ---
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

func apply_speed_buff(bonus_percent: float, duration: float) -> void:
	var saved_speed := max_speed
	max_speed *= (1.0 + bonus_percent)
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func():
		max_speed = saved_speed
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func take_damage(damage: int, _projectile_instance) -> void:
	var actual_damage := int(damage * 0.5)  # 50% damage reduction for archmage
	current_health -= actual_damage
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		_damage_flash()

func _damage_flash() -> void:
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.CYAN
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color.WHITE

func _die() -> void:
	print("Tenchijin: The archmage has fallen...")
	visible = false
	set_process(false)
	set_physics_process(false)
	if $CollisionShape2D and is_instance_valid($CollisionShape2D):
		$CollisionShape2D.set_deferred("disabled", true)
