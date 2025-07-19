# fireball.gd - controls the arrow projectile
extends Area2D

@export var speed : float = 200.0
@export var owner_group : String

@onready var destroy_timer : Timer = $destroy_timer
@onready var hit_sound = $fireball_sound



var move_direction : Vector2

func _ready():
		if hit_sound:
			hit_sound.play()

		else:
			print("⚠️ hit_sound is null!")

	

func _process (delta):
	translate(move_direction * speed * delta)
	
	# makes the angle of the arrow equal to the direction. 
	rotation = move_direction.angle()
	
	

func _on_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_destroy_timer_timeout() -> void:
	#removed in place of making the node invisible and moving to node pool use
	#queue_free()

	visible = false


func _on_visibility_changed() -> void:
	if visible == true and destroy_timer:
		destroy_timer.start()
