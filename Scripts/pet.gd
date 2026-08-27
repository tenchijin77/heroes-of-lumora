# pet.gd - Woodstalker companion: Wolf → Bear → Panther
# Spawned programmatically from player.gd — no .tscn required.
extends CharacterBody2D

const _PET_TEXTURE: String = "res://Assets/New Sprites/Pet Sprites.png"
const _STAGE_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 0, 0),                         # index 0 unused
	Rect2(70.548, 26.951, 259.146, 214.05),    # Wolf
	Rect2(481.034, 13.403, 351.384, 228.932),  # Bear
	Rect2(905.484, 72.547, 372.925, 161.191),  # Panther
]
const _STAGE_NAMES: Array[String] = ["", "a Wolf companion", "a Bear companion", "a Panther companion"]
const _LEASH_RANGE: float = 480.0  # 15 tiles (~15m) — pet only engages enemies within this radius of the player
const _CONTACT_DIST: float = 15.0  # stop pressing into the enemy once this close

var _player: Node = null
var _stage: int = 1
var _max_speed: float = 90.0
var _drag: float = 0.9
var _current_health: int = 50
var _max_health: int = 50
var _attack_damage: int = 8
var _attack_cooldown: float = 1.0
var _last_damage_times: Dictionary = {}
var _damage_modifier: float = 1.0
var _sprite: Sprite2D = null
var _collision: CollisionShape2D = null
var _pickup_area: Area2D = null
var _pickup_collision: CollisionShape2D = null
var _name_label: Label = null
var _target_cache: Node = null
var _target_update_timer: float = 0.0
const _TARGET_INTERVAL: float = 0.3
const _RESPAWN_DELAY: float = 20.0
var _is_dead: bool = false

func _ready() -> void:
	add_to_group("friendly")
	collision_layer = 32          # layer 6 (friendly)
	collision_mask  = 2048 + 2   # layer 12 (walls) + layer 2 (monsters) for contact detection

	_sprite = Sprite2D.new()
	var tex := load(_PET_TEXTURE) as Texture2D
	if tex:
		_sprite.texture = tex
		_sprite.region_enabled = true
		_sprite.region_rect = _STAGE_REGIONS[1]  # Wolf is stage 1
		_sprite.scale = Vector2(0.2, 0.2)
	add_child(_sprite)

	_collision = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	_collision.shape = shape
	add_child(_collision)

	_pickup_area = Area2D.new()
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = 256  # Loot layer — coins and potions
	add_child(_pickup_area)
	_pickup_collision = CollisionShape2D.new()
	var pickup_shape := CircleShape2D.new()
	pickup_shape.radius = 45.0
	_pickup_collision.shape = pickup_shape
	_pickup_area.add_child(_pickup_collision)
	_pickup_area.area_entered.connect(_on_pickup_area_entered)

	_name_label = Label.new()
	var font := load("res://Assets/Fonts/alagard_by_pix3m-d6awiwp.ttf") as Font
	if font:
		_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4, 1.0))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-64.0, -30.0)
	_name_label.size = Vector2(128.0, 14.0)
	_name_label.text = "a Wolf companion"
	add_child(_name_label)

	set_process(false)
	set_physics_process(false)

func init(owner_player: Node, stage: int, player_max_health: int) -> void:
	_player = owner_player
	_apply_stage(stage, player_max_health)
	set_process(true)
	set_physics_process(true)

func upgrade(new_stage: int, player_max_health: int) -> void:
	_apply_stage(new_stage, player_max_health)
	_current_health = _max_health
	if _is_dead:
		# Mid-respawn-timer — upgrading revives it immediately instead
		_is_dead = false
		visible = true
		set_process(true)
		set_physics_process(true)
		if _collision:
			_collision.set_deferred("disabled", false)
		if _pickup_collision:
			_pickup_collision.set_deferred("disabled", false)
	_spawn_upgrade_vfx()

func _apply_stage(stage: int, player_max_health: int) -> void:
	_stage = stage
	match stage:
		1:  # Wolf
			_max_health = int(player_max_health * 0.5)
			_attack_damage = 8
			_max_speed = 90.0
			_attack_cooldown = 1.0
		2:  # Bear — tank, knockback on hit
			_max_health = int(player_max_health * 0.65)
			_attack_damage = 14
			_max_speed = 75.0
			_attack_cooldown = 1.2
		3:  # Panther — fast; crit bonus handled in player.gd
			_max_health = int(player_max_health * 0.75)
			_attack_damage = 12
			_max_speed = 115.0
			_attack_cooldown = 0.7
	if _current_health > _max_health or _current_health <= 0:
		_current_health = _max_health
	if _sprite and stage < _STAGE_REGIONS.size():
		_sprite.region_rect = _STAGE_REGIONS[stage]
		_sprite.modulate = Color.WHITE
	if _name_label and stage < _STAGE_NAMES.size():
		_name_label.text = _STAGE_NAMES[stage]

func _process(delta: float) -> void:
	_target_update_timer -= delta
	if _target_update_timer <= 0.0:
		_target_update_timer = _TARGET_INTERVAL
		_update_target_cache()
	# Resolve valid leash target (enemy must be within leash range of the player)
	var target: Node = null
	if _target_cache and is_instance_valid(_target_cache) and _player and is_instance_valid(_player):
		if _is_within_leash(_target_cache):
			target = _target_cache
	if _sprite:
		if velocity.length_squared() > 25.0:
			_sprite.flip_h = velocity.x < 0
		elif target:
			_sprite.flip_h = global_position.direction_to(target.global_position).x < 0
	_move_wobble()

func _physics_process(_delta: float) -> void:
	var target: Node = null
	if _target_cache and is_instance_valid(_target_cache) and _player and is_instance_valid(_player):
		if _is_within_leash(_target_cache):
			target = _target_cache
	if target:
		var dist := global_position.distance_to(target.global_position)
		if dist > _CONTACT_DIST:
			velocity = velocity.lerp(
				global_position.direction_to(target.global_position) * _max_speed, 0.2)
		else:
			velocity = velocity.lerp(Vector2.ZERO, _drag)
	elif _player and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist > 192.0:
			velocity = velocity.lerp(
				global_position.direction_to(_player.global_position) * _max_speed, 0.15)
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
		if not is_instance_valid(body) or not body.is_in_group("monsters"):
			continue
		var last: float = _last_damage_times.get(body, 0.0)
		if now - last < _attack_cooldown:
			continue
		_last_damage_times[body] = now
		if body.has_method("take_damage"):
			body.call_deferred("take_damage", int(_attack_damage * _damage_modifier), null)
		if _stage >= 2 and body.has_method("apply_knockback"):
			body.apply_knockback(
				global_position.direction_to(body.global_position).normalized() * 180.0)

func _update_target_cache() -> void:
	var nearest: Node = null
	var min_dist: float = INF
	for mob in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(mob) and mob.visible:
			var d := global_position.distance_to(mob.global_position)
			if d < min_dist:
				min_dist = d
				nearest = mob
	_target_cache = nearest

func _is_within_leash(mob: Node) -> bool:
	if not _player or not is_instance_valid(_player):
		return false
	var dist: float = _player.global_position.distance_to(mob.global_position)
	# The boss moves fast and drags the fight far from the player — normal
	# leash range (480, 15 tiles) almost never catches him, since boss-to-
	# player distance regularly runs 450-780px. Give him a longer leash.
	var effective_leash := 900.0 if mob.is_in_group("final_boss") else _LEASH_RANGE
	return dist <= effective_leash

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
	if _pickup_collision:
		_pickup_collision.set_deferred("disabled", true)
	_spawn_death_vfx()
	get_tree().create_timer(_RESPAWN_DELAY).timeout.connect(_respawn)

func _respawn() -> void:
	if not _player or not is_instance_valid(_player):
		return  # owner gone — stay dead permanently
	_is_dead = false
	_current_health = _max_health
	global_position = _player.global_position + Vector2(40, 0)
	visible = true
	set_process(true)
	set_physics_process(true)
	if _collision:
		_collision.set_deferred("disabled", false)
	if _pickup_collision:
		_pickup_collision.set_deferred("disabled", false)
	_spawn_upgrade_vfx()

func get_health() -> int:
	return _current_health

func get_max_health() -> int:
	return _max_health

func heal(amount: int) -> void:
	_current_health = clamp(_current_health + amount, 0, _max_health)

func set_damage_modifier(modifier: float) -> void:
	_damage_modifier = modifier

func _on_pickup_area_entered(area: Area2D) -> void:
	# Coins and potions are both in the "loot" group. coin.gd's collect() just
	# plays its pickup fx; potion.gd's collect() looks up the player itself
	# and applies the effect directly — works the same whether the player or
	# the pet is what touched it.
	if area.is_in_group("loot"):
		Global.coins_collected += 1
		Global.emit_signal("coins_updated", Global.coins_collected)
		if Global.is_endless_mode:
			Global.add_endless_coins(1)
		area.collect()

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

func _spawn_upgrade_vfx() -> void:
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
	p.color = Color(1.0, 0.9, 0.3, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
