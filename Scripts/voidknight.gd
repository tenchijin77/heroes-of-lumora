# voidknight.gd - Elite tank enemy (extends monsters.gd)
# Life Siphon lifesteal bolt, self-shield, AoE cone, and a permanent Skeleton
# minion. Trimmed elite-enemy kit from the future Voidknight playable-class
# notes — full passive tree (Dark Sovereignty, Improved Life Siphon, etc.) is
# endless-mode scope, not this pass.
extends "res://Scripts/monsters.gd"

const _MINION_TEXTURE_PATH: String = "res://Assets/New Sprites/NPC Sprites 2.png"
const _MINION_REGION: Rect2 = Rect2(464, 89, 169, 268)

var _ability_cooldowns: Dictionary = {
	"necrotic_grasp": 0.0,
	"shadow_ward": 0.0,
	"void_slash": 0.0,
}
const _NECROTIC_GRASP_RATE: float = 3.0
const _SHADOW_WARD_RATE: float = 8.0
const _VOID_SLASH_RATE: float = 6.0
const _VOID_SLASH_RANGE: float = 100.0
const _VOID_SLASH_DAMAGE: int = 25
const _SHADOW_WARD_AMOUNT: float = 50.0
const _LIFE_SIPHON_RATIO: float = 0.5
const _LIFE_SIPHON_DAMAGE: int = 20

var _shield_hp: float = 0.0
var _minion: Node = null

func _ready() -> void:
	super._ready()
	max_speed = 40.0
	acceleration = 10.0
	shoot_rate = 2.0    # Life Siphon bolt cadence
	shoot_range = 220.0 # Life Siphon bolt range
	collision_damage = 8
	max_health = 320
	current_health = max_health
	score_value = 320
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if not mob_died.is_connected(_on_voidknight_died):
		mob_died.connect(_on_voidknight_died)
	call_deferred("_spawn_minion")

func reset() -> void:
	super.reset()
	_shield_hp = 0.0
	for key in _ability_cooldowns:
		_ability_cooldowns[key] = 0.0
	if _minion and is_instance_valid(_minion):
		_minion.queue_free()
	_minion = null
	call_deferred("_spawn_minion")

# Life Siphon — standard ranged attack, reuses life_siphon.tscn set as bullet_scene
# in the .tscn. Heals Voidknight for half the damage dealt via projectile.gd's
# generic lifesteal_percent hook.
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
	bolt.damage = _LIFE_SIPHON_DAMAGE  # life_siphon.tscn doesn't set its own damage; projectile.gd's default (4) is too weak for an elite
	bolt.lifesteal_percent = _LIFE_SIPHON_RATIO
	bolt.launch(muzzle.global_position, bolt.move_direction)

# Necrotic Grasp / Shadow Ward / Void Slash — close-quarters abilities, checked
# independently of the Life Siphon cast gate above (own range/cooldown each).
func _process(delta: float) -> void:
	super._process(delta)
	for key in _ability_cooldowns:
		if _ability_cooldowns[key] > 0.0:
			_ability_cooldowns[key] -= delta
	if not is_instance_valid(target):
		return
	if _ability_cooldowns["void_slash"] <= 0.0 and _count_enemies_in_range(_VOID_SLASH_RANGE) >= 1:
		_cast_void_slash()
		return
	if _ability_cooldowns["shadow_ward"] <= 0.0 and _shield_hp <= 0.0 and global_position.distance_to(target.global_position) <= _VOID_SLASH_RANGE:
		_cast_shadow_ward()
		return
	if _ability_cooldowns["necrotic_grasp"] <= 0.0 and global_position.distance_to(target.global_position) <= _VOID_SLASH_RANGE:
		_cast_necrotic_grasp()

func _cast_necrotic_grasp() -> void:
	_ability_cooldowns["necrotic_grasp"] = _NECROTIC_GRASP_RATE
	if target and is_instance_valid(target) and target.has_method("apply_slow"):
		target.apply_slow(0.10, 4.0)

func _cast_shadow_ward() -> void:
	_ability_cooldowns["shadow_ward"] = _SHADOW_WARD_RATE
	_shield_hp = _SHADOW_WARD_AMOUNT
	_spawn_ward_vfx()

func _cast_void_slash() -> void:
	_ability_cooldowns["void_slash"] = _VOID_SLASH_RATE
	for group_name in ["player", "friendly"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node) and global_position.distance_to(node.global_position) <= _VOID_SLASH_RANGE:
				if node.has_method("take_damage"):
					node.take_damage(_VOID_SLASH_DAMAGE, self)
	_spawn_slash_vfx()

func _count_enemies_in_range(range_dist: float) -> int:
	var count := 0
	for group_name in ["player", "friendly"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node) and global_position.distance_to(node.global_position) <= range_dist:
				count += 1
	return count

func heal(amount: int) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

func take_damage(damage: int, projectile_instance: Node) -> void:
	var remaining := damage
	if _shield_hp > 0.0:
		var absorbed: float = min(_shield_hp, float(remaining))
		_shield_hp -= absorbed
		remaining -= int(absorbed)
	if remaining <= 0:
		return
	super.take_damage(remaining, projectile_instance)

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
	minion.init(self, tex, _MINION_REGION, "a Skeleton minion", int(max_health * 0.45), 8)
	_minion = minion

func _on_voidknight_died() -> void:
	if _minion and is_instance_valid(_minion) and _minion.has_method("notify_owner_died"):
		_minion.notify_owner_died()

func _spawn_ward_vfx() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.45, 0.2, 0.7, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_slash_vfx() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 50
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.55, 0.1, 0.85, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)
