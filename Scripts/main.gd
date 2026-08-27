# main.gd

extends Node2D

@onready var global_light: DirectionalLight2D = $global_light

func _ready() -> void:
	_setup_map_bounds()
	_apply_endless_class()

# Endless mode: swap the story-campaign player.tscn instance out for whichever
# class scene was chosen in class_select.tscn (e.g. woodstalker.tscn).
# Keeps the same node name/position so name-based (camera_controller.gd) and
# group-based ("player") references elsewhere keep working.
func _apply_endless_class() -> void:
	if not Global.is_endless_mode:
		return
	var class_scene: PackedScene = load(Global.selected_class_scene)
	if not class_scene:
		push_error("main.gd: could not load endless class scene: %s" % Global.selected_class_scene)
		return

	# Preserve the story-campaign player's spawn position if one is present in
	# this scene; otherwise use the level's PlayerSpawn marker, falling back
	# to the origin if neither exists.
	var old_player := get_node_or_null("player")
	var spawn_marker := get_node_or_null("PlayerSpawn") as Node2D
	var spawn_position: Vector2 = Vector2.ZERO
	if old_player:
		spawn_position = old_player.global_position
	elif spawn_marker:
		spawn_position = spawn_marker.global_position
	var idx: int = old_player.get_index() if old_player else get_child_count()
	if old_player:
		remove_child(old_player)
		old_player.queue_free()

	var new_player := class_scene.instantiate()
	new_player.name = "player"
	add_child(new_player)
	move_child(new_player, idx)
	new_player.global_position = spawn_position
	_apply_class_upgrades(new_player)

	# Fix up sibling nodes that cached a reference to the old/missing player in
	# their own @onready vars before this swap happened.
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam and "target" in cam:
		cam.target = new_player
	var spawner := get_node_or_null("enemy_spawner")
	if spawner and "player" in spawner:
		spawner.player = new_player
		# enemy_spawner.gd's _ready() disables its own processing (including
		# spawn_timer/wave_timer) if it doesn't find a player at that point,
		# which is always true here since this swap runs after all children's
		# _ready(). Re-enable it now that a real player is wired up, or no
		# monster will ever spawn.
		spawner.process_mode = Node.PROCESS_MODE_INHERIT

# Applies permanent upgrades bought in the main-menu Upgrade Store
# (class_upgrade.gd) for this specific class. Same +25 HP / +2 damage /
# +10 speed per purchase as Timot's in-run shop (shop_ui.gd), just
# permanent and tracked per class instead of per run.
func _apply_class_upgrades(new_player: Node) -> void:
	var counts: Dictionary = Global.get_class_upgrades(Global.selected_class_scene)
	var health_lv: int = counts.get("health", 0)
	var damage_lv: int = counts.get("damage", 0)
	var speed_lv: int = counts.get("speed", 0)

	if health_lv > 0 and "max_health" in new_player:
		new_player.max_health += health_lv * 25
		new_player.current_health = new_player.max_health
		if "health_bar" in new_player and new_player.health_bar and is_instance_valid(new_player.health_bar):
			new_player.health_bar.max_value = new_player.max_health
			new_player.health_bar.value = new_player.current_health
		if new_player.has_signal("health_updated"):
			new_player.emit_signal("health_updated", new_player.current_health, new_player.max_health)

	if damage_lv > 0:
		# Most classes' basic attack reads base_damage; Arcanist's reads
		# frost_bolt_damage instead (base_damage is unused there).
		if "base_damage" in new_player:
			new_player.base_damage += damage_lv * 2
		if "frost_bolt_damage" in new_player:
			new_player.frost_bolt_damage += damage_lv * 2
		if new_player.has_signal("damage_updated"):
			var dmg_stat: float = new_player.base_damage if "base_damage" in new_player else 0.0
			new_player.emit_signal("damage_updated", dmg_stat * new_player.damage_modifier)

	if speed_lv > 0 and "max_speed" in new_player:
		new_player.max_speed += speed_lv * 10.0
		if "base_max_speed" in new_player:
			new_player.base_max_speed += speed_lv * 10.0
		if new_player.has_signal("speed_updated"):
			new_player.emit_signal("speed_updated", new_player.max_speed)

func _setup_map_bounds() -> void:
	const TILE_SIZE := 32
	# Use only the grass layer — it defines the playable area.
	# Other layers (walls, town) may have tiles placed outside the grass for
	# decorative purposes, which would push the merged rect far out.
	var grass := get_node_or_null("grass") as TileMapLayer
	if not grass:
		grass = get_node_or_null("scenery/ground") as TileMapLayer
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
