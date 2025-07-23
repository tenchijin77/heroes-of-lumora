# axe.gd - controls the axe projectile
extends Area2D

@export var speed : float = 200.0
@export var owner_group : String 
@export var damage = 12


@onready var destroy_timer : Timer = $destroy_timer
@onready var hit_sound = $projectile_sound



var move_direction : Vector2

func _ready():
	# This should run when the object is pulled from the pool and made active
	visible = true
	# Make sure collision is re-enabled when spawned
	if $CollisionShape2D: # Assuming your CollisionShape2D is a direct child
		$CollisionShape2D.disabled = false
		if hit_sound:
			hit_sound.play()

		else:
			print("⚠️ hit_sound is null!")

	if destroy_timer:
		destroy_timer.start()

func _process (delta):
	translate(move_direction * speed * delta)
	
	# makes the angle of the arrow equal to the direction. 
	rotation = move_direction.angle()
	
	# Move the axe in its set direction
	translate(move_direction * speed * delta)
	
	
	
func _on_destroy_timer_timeout() -> void:
	#removed in place of making the node invisible and moving to node pool use
	#queue_free()
	visible = false


func _on_visibility_changed() -> void:
	if visible == true and destroy_timer:
		destroy_timer.start()

func _on_body_entered(body):

	if body.is_in_group(owner_group):
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		reset()
	

func reset(): 
	visible = false # Hide the sprite
	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true) 
	if destroy_timer:
		destroy_timer.stop() # Stop the timer
	if hit_sound and hit_sound.playing:
		hit_sound.stop()
		
		

		
