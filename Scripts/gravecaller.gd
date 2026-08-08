# gravecaller.gd - Elite ranged DoT enemy (extends monsters.gd)
# Death Bolt ranged attack, Curse of Withering DoT, a lingering Plague Cloud,
# and a permanent Wraith minion. Trimmed elite-enemy kit from the future
# Gravecaller playable-class notes — full 10-tier progression (Reaper's
# Plague, Circle of Blight, Lichborne, etc.) is endless-mode scope.
extends "res://Scripts/monsters.gd"

const _MINION_TEXTURE_PATH: String = "res://Assets/New Sprites/NPC Sprites 2.png"
const _MINION_REGION: Rect2 = Rect2(1090, 68, 244, 289)

var _ability_cooldowns: Dictionary = {
	"curse_of_withering": 0.0,
	"plague_cloud": 0.0,
}
const _CURSE_RATE: float = 5.0
const _CURSE_DAMAGE_PER_TICK: int = 4
const _CURSE_TICKS: int = 6
const _PLAGUE_RATE: float = 8.0
const _PLAGUE_RADIUS: float = 60.0
const _PLAGUE_TICK_DAMAGE: int = 5
const _PLAGUE_DURATION: float = 4.0

var _minion: Node = null

func _ready() -> void:
	super._ready()
	max_speed = 30.0
	acceleration = 8.0
	shoot_rate = 2.0
	shoot_range = 320.0
	collision_damage = 3
	max_health = 140
	current_health = max_health
	score_value = 280
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if not mob_died.is_connected(_on_gravecaller_died):
		mob_died.connect(_on_gravecaller_died)
	call_deferred("_spawn_minion")

func reset() -> void:
	super.reset()
	for key in _ability_cooldowns:
		_ability_cooldowns[key] = 0.0
	if _minion and is_instance_valid(_minion):
		_minion.queue_free()
	_minion = null
	call_deferred("_spawn_minion")

func _process(delta: float) -> void:
	super._process(delta)
	for key in _ability_cooldowns:
		if _ability_cooldowns[key] > 0.0:
			_ability_cooldowns[key] -= delta
	if not is_instance_valid(target) or target_distance > shoot_range or not _has_line_of_sight():
		return
	if _ability_cooldowns["plague_cloud"] <= 0.0:
		_cast_plague_cloud()
		return
	if _ability_cooldowns["curse_of_withering"] <= 0.0:
		_cast_curse_of_withering()

# Death Bolt — standard ranged attack, reuses death_bolt.tscn set as bullet_scene in the .tscn.
func _cast() -> void:
	last_shoot_time = Time.get_unix_time_from_system()
	if not bullet_pool or not muzzle or not target:
		return
	var bolt = bullet_pool.spawn()
	if not bolt:
		return
	bolt.shooter = self
	bolt.global_position = muzzle.global_position
	var direction: Vector2 = muzzle.global_position.direction_to(target.global_position)
	bolt.move_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	bolt.owner_group = "monsters"
	bolt.launch(muzzle.global_position, bolt.move_direction)

func _cast_curse_of_withering() -> void:
	_ability_cooldowns["curse_of_withering"] = _CURSE_RATE
	if target and is_instance_valid(target) and target.has_method("apply_dot"):
		target.apply_dot(_CURSE_DAMAGE_PER_TICK, _CURSE_TICKS)
	_spawn_curse_vfx()

func _cast_plague_cloud() -> void:
	_ability_cooldowns["plague_cloud"] = _PLAGUE_RATE
	var pos: Vector2 = target.global_position if target and is_instance_valid(target) else global_position
	call_deferred("_spawn_plague_cloud", pos)

func _spawn_plague_cloud(pos: Vector2) -> void:
	var cloud := Area2D.new()
	cloud.collision_layer = 0
	cloud.collision_mask = 1 + 32  # Player + FriendlyNPCs
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _PLAGUE_RADIUS
	shape.shape = circle
	cloud.add_child(shape)

	var visual := CPUParticles2D.new()
	visual.amount = 24
	visual.lifetime = _PLAGUE_DURATION
	visual.local_coords = false
	visual.spread = 180.0
	visual.initial_velocity_min = 5.0
	visual.initial_velocity_max = 20.0
	visual.scale_amount_min = 3.0
	visual.scale_amount_max = 6.0
	visual.color = Color(0.35, 0.7, 0.2, 0.7)
	cloud.add_child(visual)

	var main := get_tree().root.get_node_or_null("main")
	var parent: Node = main if main else get_tree().current_scene
	parent.add_child(cloud)
	cloud.global_position = pos
	visual.emitting = true

	var tick_timer := Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	cloud.add_child(tick_timer)
	tick_timer.timeout.connect(func():
		if not is_instance_valid(cloud):
			return
		for body in cloud.get_overlapping_bodies():
			if is_instance_valid(body) and (body.is_in_group("player") or body.is_in_group("friendly")) and body.has_method("take_damage"):
				body.take_damage(_PLAGUE_TICK_DAMAGE, null)
	)
	get_tree().create_timer(_PLAGUE_DURATION).timeout.connect(func():
		if is_instance_valid(cloud): cloud.queue_free()
	)

func _spawn_minion() -> void:
	if not is_instance_valid(self) or not visible:
		return
	var minion := CharacterBody2D.new()
	minion.set_script(load("res://Scripts/enemy_pet.gd"))
	minion.global_position = global_position + Vector2(-40, 0)
	var main := get_tree().root.get_node_or_null("main")
	var parent: Node = main if main else get_tree().current_scene
	if not parent:
		return
	parent.add_child(minion)
	var tex := load(_MINION_TEXTURE_PATH) as Texture2D
	minion.init(self, tex, _MINION_REGION, "a Wraith minion", int(max_health * 0.5), 10)
	_minion = minion

func _on_gravecaller_died() -> void:
	if _minion and is_instance_valid(_minion) and _minion.has_method("notify_owner_died"):
		_minion.notify_owner_died()

func _spawn_curse_vfx() -> void:
	if not target or not is_instance_valid(target):
		return
	var p := CPUParticles2D.new()
	p.global_position = target.global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.7
	p.spread = 180.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.3, 0.55, 0.15, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
