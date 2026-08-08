# enemy_pet.gd - hostile companion for elite casters (Voidknight's Skeleton, Gravecaller's Wraith)
# Spawned programmatically from the owning caster's script — no .tscn required.
# Mirrors pet.gd's movement/attack pattern but targets the player's side instead.
extends CharacterBody2D

const _CONTACT_DIST: float = 15.0

var _owner: Node = null
var _owner_alive: bool = true  # once false (owner died), a kill is permanent — no respawn
var _max_speed: float = 90.0
var _drag: float = 0.9
var _current_health: int = 40
var _max_health: int = 40
var _attack_damage: int = 8
var _attack_cooldown: float = 1.0
var _last_damage_times: Dictionary = {}
var _damage_modifier: float = 1.0
var _sprite: Sprite2D = null
var _collision: CollisionShape2D = null
var _name_label: Label = null
var _target_cache: Node = null
var _target_update_timer: float = 0.0
const _TARGET_INTERVAL: float = 0.3
const _RESPAWN_DELAY: float = 20.0
var _is_dead: bool = false

func _ready() -> void:
	add_to_group("monsters")
	collision_layer = 2            # layer 2 (monsters) — hittable by player projectiles
	collision_mask = 1 + 32 + 2048 # Player + FriendlyNPCs(incl. villagers) + Walls

	_sprite = Sprite2D.new()
	add_child(_sprite)

	_collision = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	_collision.shape = shape
	add_child(_collision)

	_name_label = Label.new()
	var font := load("res://Assets/Fonts/alagard_by_pix3m-d6awiwp.ttf") as Font
	if font:
		_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9, 1.0))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-64.0, -30.0)
	_name_label.size = Vector2(128.0, 14.0)
	add_child(_name_label)

func init(owner_caster: Node, texture: Texture2D, region_rect: Rect2, display_name: String, max_health: int, attack_damage: int, scale: Vector2 = Vector2(0.2, 0.2)) -> void:
	_owner = owner_caster
	_owner_alive = true
	if texture:
		_sprite.texture = texture
		_sprite.region_enabled = true
		_sprite.region_rect = region_rect
		_sprite.scale = scale
	_name_label.text = display_name
	_max_health = max_health
	_current_health = max_health
	_attack_damage = attack_damage
	_is_dead = false
	visible = true
	set_process(true)
	set_physics_process(true)
	if _collision:
		_collision.set_deferred("disabled", false)

func notify_owner_died() -> void:
	_owner_alive = false

func _process(delta: float) -> void:
	_target_update_timer -= delta
	if _target_update_timer <= 0.0:
		_target_update_timer = _TARGET_INTERVAL
		_update_target_cache()
	if _sprite:
		var target: Node = _target_cache if _target_cache and is_instance_valid(_target_cache) else null
		if velocity.length_squared() > 25.0:
			_sprite.flip_h = velocity.x < 0
		elif target:
			_sprite.flip_h = global_position.direction_to(target.global_position).x < 0
	_move_wobble()

func _physics_process(_delta: float) -> void:
	var target: Node = _target_cache if _target_cache and is_instance_valid(_target_cache) else null
	if target:
		var dist := global_position.distance_to(target.global_position)
		if dist > _CONTACT_DIST:
			velocity = velocity.lerp(
				global_position.direction_to(target.global_position) * _max_speed, 0.2)
		else:
			velocity = velocity.lerp(Vector2.ZERO, _drag)
	else:
		velocity = velocity.lerp(Vector2.ZERO, _drag)
	move_and_slide()
	_process_collisions()

func _process_collisions() -> void:
	var count := get_slide_collision_count()
	if count == 0:
		return
	var now := Time.get_unix_time_from_system()
	for i in count:
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if not is_instance_valid(body):
			continue
		if not (body.is_in_group("player") or body.is_in_group("friendly") or body.is_in_group("villagers")):
			continue
		var last: float = _last_damage_times.get(body, 0.0)
		if now - last < _attack_cooldown:
			continue
		_last_damage_times[body] = now
		if body.has_method("take_damage"):
			body.call_deferred("take_damage", int(_attack_damage * _damage_modifier), self)

func _update_target_cache() -> void:
	var nearest: Node = null
	var min_dist: float = INF
	var candidate_groups := ["player", "friendly", "villagers"]
	for group_name in candidate_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				var d := global_position.distance_to(node.global_position)
				if d < min_dist:
					min_dist = d
					nearest = node
	_target_cache = nearest

func _move_wobble() -> void:
	if not _sprite:
		return
	if velocity.length_squared() < 25.0:
		_sprite.rotation_degrees = 0
		return
	_sprite.rotation_degrees = sin(Time.get_unix_time_from_system() * 20.0) * 2.0

func take_damage(damage: int, _source: Node) -> void:
	if _is_dead:
		return
	_current_health -= damage
	if _current_health <= 0:
		_current_health = 0
		_die()

func _die() -> void:
	_is_dead = true
	visible = false
	set_process(false)
	set_physics_process(false)
	if _collision:
		_collision.set_deferred("disabled", true)
	_spawn_death_vfx()
	if _owner_alive:
		get_tree().create_timer(_RESPAWN_DELAY).timeout.connect(_respawn)

func _respawn() -> void:
	if not _owner_alive or not _owner or not is_instance_valid(_owner) or not _owner.visible:
		return  # owner dead/gone — stay dead permanently
	_is_dead = false
	_current_health = _max_health
	global_position = _owner.global_position + Vector2(-40, 0)
	visible = true
	set_process(true)
	set_physics_process(true)
	if _collision:
		_collision.set_deferred("disabled", false)
	_spawn_respawn_vfx()

func get_health() -> int:
	return _current_health

func get_max_health() -> int:
	return _max_health

func heal(amount: int) -> void:
	_current_health = clamp(_current_health + amount, 0, _max_health)

func set_damage_modifier(modifier: float) -> void:
	_damage_modifier = modifier

func _spawn_death_vfx() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30
	p.lifetime = 0.8
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.3, 0.3, 0.3, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_respawn_vfx() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 40
	p.lifetime = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.6, 0.2, 0.8, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
