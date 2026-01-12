extends CharacterBody2D

@export var speed: float = 500.0
@export var lifetime: float = 3.0  # How long bullet exists before auto-removing

var direction: Vector2 = Vector2.RIGHT
var age: float = 0.0

func _ready():
	# Set the direction if it wasn't set before
	pass

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()

func _physics_process(delta):
	age += delta
	
	# Remove bullet after lifetime
	if age >= lifetime:
		queue_free()
		return
	
	# Move bullet in direction
	velocity = direction * speed
	move_and_slide()
	
	# Check for collisions (you can add collision detection here later)
