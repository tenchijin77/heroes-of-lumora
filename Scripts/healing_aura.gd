# healing_aura.gd - healer's aura logic
extends Area2D

@export var heal_amount: int = 4
@export var heal_interval: float = 3.0
@export var target_groups: Array[String] = ["healer", "friendly", "player"]
@onready var heal_aura_timer: Timer = $heal_aura_timer
@onready var sparkle_particles: CPUParticles2D = $sparkle_particles

# Must match shader_parameter/pulse_speed on the aura_glow ShaderMaterial
const _PULSE_SPEED: float = 3.5

var _sparkle_phase: float = 0.0
var _prev_pulse: float = 0.0

func _ready():
	heal_aura_timer.wait_time = heal_interval
	heal_aura_timer.timeout.connect(_on_heal_tick)
	heal_aura_timer.start()
	_setup_sparkle_particles()

func _setup_sparkle_particles() -> void:
	sparkle_particles.amount = 12
	sparkle_particles.lifetime = 0.55
	sparkle_particles.explosiveness = 0.9
	sparkle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkle_particles.emission_sphere_radius = 110.0
	sparkle_particles.direction = Vector2.ZERO
	sparkle_particles.spread = 180.0
	sparkle_particles.gravity = Vector2.ZERO
	sparkle_particles.initial_velocity_min = 20.0
	sparkle_particles.initial_velocity_max = 55.0
	sparkle_particles.scale_amount_min = 3.0
	sparkle_particles.scale_amount_max = 7.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 1.0, 0.3, 0.9))
	grad.set_color(1, Color(0.45, 1.0, 0.3, 0.0))
	sparkle_particles.color_ramp = grad

func _process(delta: float) -> void:
	_sparkle_phase += delta * _PULSE_SPEED
	var pulse := sin(_sparkle_phase)
	if pulse >= 0.9 and _prev_pulse < 0.9:
		sparkle_particles.restart()
	_prev_pulse = pulse

func _on_heal_tick():
	var bodies = get_overlapping_bodies()
	for body in bodies:
		for group in target_groups:
			if body.is_in_group(group) and body.has_method("heal"):
				body.heal(heal_amount)
				break
