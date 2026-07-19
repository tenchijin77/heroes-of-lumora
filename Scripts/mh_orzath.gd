# mh_orzath.gd - Final Boss: Mh'orzath, the Eclipsed One
extends "res://Scripts/monsters.gd"

const BOSS_MUSIC: AudioStreamMP3 = preload("res://Assets/Audio/audiodollar-adventure-game-334657.mp3")

const ARRIVAL_MESSAGE: String = "Your meddling has drawn the ire of Mh'orzath, the Eclipsed One! Tremble in fear!"

@export var event_horizon_range: float = 500.0
@export var event_horizon_damage: int = 160
@export var event_horizon_pull_strength: float = 1000.0
@export var event_horizon_cooldown: float = 15.0

@export var nihil_storm_range: float = 600.0
@export var nihil_storm_damage: int = 200
@export var nihil_storm_cooldown: float = 20.0

# Stagger the first uses so player has a moment to react
var _event_horizon_timer: float = 8.0
var _nihil_storm_timer: float = 14.0

func _ready() -> void:
	score_value = 10000
	# Override inherited monster defaults to boss-level values
	shoot_rate = 0.8       # monsters.gd default is 1.5 — boss fires nearly 2x faster
	shoot_range = 350.0    # longer reach so he doesn't have to chase
	max_speed = 65.0       # was 45 — more mobile and harder to kite
	super._ready()
	add_to_group("final_boss")
	call_deferred("_on_boss_spawned")

func _physics_process(delta: float) -> void:
	# Base monsters.gd freezes movement entirely once waypoint_stage == 2
	# (the "already at hunting grounds, just shoot" state we force in
	# _initialize_waypoint below). That leaves him permanently stuck at his
	# spawn point — fine for regular monsters, but a boss needs to be able to
	# close the distance when the fight drifts outside his shoot_range.
	if _is_rooted:
		velocity = Vector2.ZERO
		move_and_slide()
		_process_collisions()
		return
	if is_instance_valid(target) and target_distance > shoot_range:
		var dir := global_position.direction_to(target.global_position)
		velocity = velocity.lerp(dir * max_speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, drag)
	move_and_slide()
	_process_collisions()

func _initialize_waypoint() -> void:
	waypoint_stage = 2
	# Prevent the nav agent from emitting velocity_computed and overriding our zero velocity
	navigation_agent.avoidance_enabled = false
	navigation_agent.target_position = global_position  # clear any waypoint target from reset()
	# LOS should only fail for actual walls, not villagers/allies on layer 1
	avoidance_ray.collision_mask = 2048

func _on_boss_spawned() -> void:
	Global.boss_fight_active = true
	_clear_regular_monsters()
	_respawn_allies()
	_enable_magi_vulnerability()
	_start_boss_music()
	var ui = get_node_or_null("/root/UI")
	if ui and ui.has_method("show_announcement"):
		ui.show_announcement(ARRIVAL_MESSAGE)

func _start_boss_music() -> void:
	var existing := get_tree().current_scene.get_node_or_null("AudioStreamPlayer")
	if existing is AudioStreamPlayer:
		existing.stop()
	var stream := BOSS_MUSIC.duplicate() as AudioStreamMP3
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -2.0
	get_tree().current_scene.add_child(player)
	player.play()

func _process(delta: float) -> void:
	super._process(delta)
	if not visible:
		return
	_event_horizon_timer -= delta
	_nihil_storm_timer -= delta
	if _event_horizon_timer <= 0.0:
		_cast_event_horizon()
		_event_horizon_timer = event_horizon_cooldown
	if _nihil_storm_timer <= 0.0:
		_cast_nihil_storm()
		_nihil_storm_timer = nihil_storm_cooldown

# --- Abilities ---

func _cast_event_horizon() -> void:
	_announce_ability("Event Horizon")
	_spawn_event_horizon_vfx()
	var targets := _get_targets_in_range(event_horizon_range)
	# Pull phase
	for t in targets:
		if t is CharacterBody2D:
			var pull_dir := (t as CharacterBody2D).global_position.direction_to(global_position).normalized()
			(t as CharacterBody2D).velocity += pull_dir * event_horizon_pull_strength
	# Damage phase after a brief delay
	var pull_timer := get_tree().create_timer(0.5)
	pull_timer.timeout.connect(func():
		if not is_instance_valid(self) or not visible:
			return
		for t2 in _get_targets_in_range(event_horizon_range):
			if t2.has_method("take_damage"):
				t2.take_damage(event_horizon_damage, self)
	)

func _cast_nihil_storm() -> void:
	_announce_ability("Nihil Storm")
	_spawn_nihil_storm_vfx()
	for t in _get_targets_in_range(nihil_storm_range):
		if t.has_method("take_damage"):
			t.take_damage(nihil_storm_damage, self)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(14.0, 0.9)

# --- Ally Respawn ---

func _respawn_allies() -> void:
	var anna := get_tree().get_first_node_in_group("annadaeus")
	if anna and is_instance_valid(anna) and not anna.visible:
		anna.current_health = anna.max_health
		if anna.get_node_or_null("health_bar"):
			anna.get_node("health_bar").value = anna.max_health
		anna.has_emitted_health_critical = false
		anna.current_state = "FOLLOWING_PLAYER"
		anna.visible = true
		anna.set_process(true)
		anna.set_physics_process(true)
		var ac := anna.get_node_or_null("CollisionShape2D")
		if ac:
			ac.set_deferred("disabled", false)
		if anna.has_method("_force_show_text"):
			anna.call_deferred("_force_show_text", "I still draw breath! I fight with you to the end!")

	var tenchi := get_tree().get_first_node_in_group("tenchijin")
	if tenchi and is_instance_valid(tenchi) and not tenchi.visible:
		tenchi.current_health = tenchi.max_health
		if tenchi.get_node_or_null("health_bar"):
			tenchi.get_node("health_bar").value = tenchi.max_health
		if tenchi.has_method("dramatic_entrance"):
			tenchi.call_deferred("dramatic_entrance")

# --- Helpers ---

func _enable_magi_vulnerability() -> void:
	for magi in get_tree().get_nodes_in_group("magi"):
		if is_instance_valid(magi) and magi.has_method("enable_boss_targeting"):
			magi.enable_boss_targeting()

func _clear_regular_monsters() -> void:
	for mob in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(mob) or mob.is_in_group("final_boss"):
			continue
		mob.visible = false
		mob.set_process(false)
		mob.set_physics_process(false)
		var cs := mob.get_node_or_null("CollisionShape2D")
		if cs:
			cs.set_deferred("disabled", true)

func _get_targets_in_range(range_dist: float) -> Array:
	var result := []
	for group in ["player", "friendly", "healer", "villagers"]:
		for node in get_tree().get_nodes_in_group(group):
			if is_instance_valid(node) and node.visible:
				if global_position.distance_to(node.global_position) <= range_dist:
					result.append(node)
	return result

func _announce_ability(ability_name: String) -> void:
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("show_announcement"):
		ui.show_announcement("Mh'orzath: %s!" % ability_name)

# --- VFX ---

func _spawn_event_horizon_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 150
	p.lifetime = 1.8
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 12.0
	p.color = Color(0.25, 0.0, 0.5, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_nihil_storm_vfx() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 220
	p.lifetime = 2.2
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 500.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 14.0
	p.color = Color(0.05, 0.0, 0.05, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
