# torch_light.gd - flickering animation for torches

extends PointLight2D

@export var base_energy: float = 1.0       # Base brightness of the light
@export var flicker_strength: float = 0.3  # How much the light flickers (max deviation from base_energy)
@export var flicker_speed: float = 8.0     # How fast the flicker occurs

var initial_energy: float
var noise_offset_x: float = 0.0
var noise_offset_y: float = 0.0

func _ready():
	initial_energy = energy
	# Initialize noise offsets randomly for varied flickering
	noise_offset_x = randf() * 1000.0
	noise_offset_y = randf() * 1000.0

func _process(delta):
	# Update noise offsets over time
	noise_offset_x += delta * flicker_speed * 0.5
	noise_offset_y += delta * flicker_speed * 0.7

	# Use Perlin noise to create a smooth, random flicker
	# Perlin noise returns values between -1 and 1 (approximately)
	var flicker_value_x = FastNoiseLite.new()
	flicker_value_x.seed = 1234 # Consistent seed for same noise across runs
	flicker_value_x.noise_type = FastNoiseLite.TYPE_PERLIN
	var flicker_noise_x = flicker_value_x.get_noise_2d(noise_offset_x, 0.0)

	var flicker_value_y = FastNoiseLite.new()
	flicker_value_y.seed = 5678 # Different seed for another dimension of noise
	flicker_value_y.noise_type = FastNoiseLite.TYPE_PERLIN
	var flicker_noise_y = flicker_value_y.get_noise_2d(noise_offset_y, 0.0)

	# Combine the two noise values (can be weighted)
	var final_flicker = (flicker_noise_x + flicker_noise_y) * 0.5

	# Map the noise value to a flicker range
	# Example: If noise is -1 to 1, this maps it to -flicker_strength to +flicker_strength
	var energy_deviation = final_flicker * flicker_strength

	# Apply the flicker to the light's energy
	energy = base_energy + energy_deviation

	# Optional: Slight position flicker for even more realism
	# This can be subtle to avoid looking jittery
	var pos_flicker_x = FastNoiseLite.new()
	pos_flicker_x.seed = 9012
	pos_flicker_x.noise_type = FastNoiseLite.TYPE_PERLIN
	var pos_noise_x = pos_flicker_x.get_noise_2d(noise_offset_x * 0.5, 0.0)

	var pos_flicker_y = FastNoiseLite.new()
	pos_flicker_y.seed = 3456
	pos_flicker_y.noise_type = FastNoiseLite.TYPE_PERLIN
	var pos_noise_y = pos_flicker_y.get_noise_2d(noise_offset_y * 0.5, 0.0)

	position.x = initial_position.x + pos_noise_x * 1.0 # Adjust multiplier for intensity of position flicker
	position.y = initial_position.y + pos_noise_y * 1.0 # Adjust multiplier for intensity of position flicker

# Store initial position to apply offsets relative to it
var initial_position: Vector2

func _init():
	initial_position = position # Store the initial position when the script is initialized
