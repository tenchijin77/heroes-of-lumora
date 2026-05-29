# main.gd

extends Node2D

@onready var global_light: DirectionalLight2D = $global_light

func _ready() -> void:
	_setup_map_bounds()

func _setup_map_bounds() -> void:
	const TILE_SIZE := 32
	# Use only the grass layer — it defines the playable area.
	# Other layers (walls, town) may have tiles placed outside the grass for
	# decorative purposes, which would push the merged rect far out.
	var grass := get_node_or_null("grass") as TileMapLayer
	if not grass:
		return
	var used: Rect2i = grass.get_used_rect()
	if used.size == Vector2i.ZERO:
		return

	var left   := used.position.x * TILE_SIZE
	var top    := used.position.y * TILE_SIZE
	var right  := (used.position.x + used.size.x) * TILE_SIZE
	var bottom := (used.position.y + used.size.y) * TILE_SIZE

	# Clamp camera so the viewport never shows beyond the grass tiles
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_left   = left
		cam.limit_top    = top
		cam.limit_right  = right
		cam.limit_bottom = bottom

	# Invisible boundary walls so characters cannot walk onto unpainted tiles
	_add_boundary_walls(left, top, right, bottom)

func _add_boundary_walls(left: int, top: int, right: int, bottom: int) -> void:
	const T := 128  # wall thickness in pixels
	var rects := [
		Rect2(left - T,  top - T,    T,             bottom - top + T * 2),  # left
		Rect2(right,     top - T,    T,             bottom - top + T * 2),  # right
		Rect2(left,      top - T,    right - left,  T),                     # top
		Rect2(left,      bottom,     right - left,  T),                     # bottom
	]
	for r: Rect2 in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 16 + 2048  # Environment (layer 5) + Walls (layer 12)
		body.collision_mask  = 0
		var shape := CollisionShape2D.new()
		var box   := RectangleShape2D.new()
		box.size       = r.size
		shape.shape    = box
		shape.position = r.position + r.size * 0.5
		body.add_child(shape)
		add_child(body)

# Process: Update world light and screen overlay based on TimeManager's chronomancy
func _process(delta: float) -> void:
	var hour: float = TimeManager.current_time / 60.0
	# Sin curve peaks at noon (factor=1.0, full brightness) and troughs at midnight (factor=0.0, darkest)
	var sun_factor: float = (sin((hour - 6.0) / 24.0 * TAU) + 1.0) / 2.0
	# Subtract mode: 0.0 = no subtraction (full bright), 0.55 = moonlit night
	var target_subtract: float = lerp(0.55, 0.0, sun_factor)
	global_light.energy = lerp(global_light.energy, target_subtract, 0.05 * delta)
	# Screen overlay: up to 0.45 opacity at midnight, fully transparent at noon
	var target_alpha: float = lerp(0.45, 0.0, sun_factor)
	UI.set_night_alpha(lerp(UI.get_night_alpha(), target_alpha, 0.05 * delta))
