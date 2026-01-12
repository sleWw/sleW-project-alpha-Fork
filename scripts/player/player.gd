extends CharacterBody2D

# Player movement variables for top-down view
@export var speed: float = 200.0

# Camera zoom variables
@export var min_zoom: float = 0.1
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D

# Store last direction for idle animations
var last_direction: Vector2 = Vector2.DOWN
var mouse_direction: Vector2 = Vector2.DOWN

# Shooting variables
@export var bullet_scene: PackedScene
@export var bullet_speed: float = 500.0
@export var fire_rate: float = 0.2  # Time between shots
var time_since_last_shot: float = 0.0
var is_shooting: bool = false

func _physics_process(delta):
	# Update time since last shot
	time_since_last_shot += delta
	
	# Get mouse position in world coordinates
	var mouse_pos = get_global_mouse_position()
	mouse_direction = (mouse_pos - global_position).normalized()
	
	# Get input direction (8-directional movement with WASD)
	# W = North (negative Y), A = West (negative X), S = South (positive Y), D = East (positive X)
	var input_direction = Vector2.ZERO
	
	# W = North (move up, negative Y)
	if Input.is_key_pressed(KEY_W):
		input_direction.y -= 1.0
	# S = South (move down, positive Y)
	if Input.is_key_pressed(KEY_S):
		input_direction.y += 1.0
	# A = West (move left, negative X)
	if Input.is_key_pressed(KEY_A):
		input_direction.x -= 1.0
	# D = East (move right, positive X)
	if Input.is_key_pressed(KEY_D):
		input_direction.x += 1.0
	
	# Normalize to prevent faster diagonal movement
	input_direction = input_direction.normalized()
	
	# Set velocity based on input
	if input_direction != Vector2.ZERO:
		velocity = input_direction * speed
		last_direction = input_direction  # Store direction for idle animations
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
	
	# Handle shooting
	handle_shooting()
	
	# Update animations
	update_animations(input_direction)
	
	# Move the character (use move_and_collide for top-down, or move_and_slide)
	# For top-down without collisions, we can use move_and_slide which should work fine
	move_and_slide()

func _input(event):
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom in
			var new_zoom = camera.zoom.x - zoom_speed
			new_zoom = clamp(new_zoom, min_zoom, max_zoom)
			camera.zoom = Vector2(new_zoom, new_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom out
			var new_zoom = camera.zoom.x + zoom_speed
			new_zoom = clamp(new_zoom, min_zoom, max_zoom)
			camera.zoom = Vector2(new_zoom, new_zoom)

func handle_shooting():
	# Check if left mouse button is pressed
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Update facing direction to mouse while shooting
		last_direction = mouse_direction
		# Check fire rate
		if time_since_last_shot >= fire_rate:
			shoot()
	else:
		# Not shooting, reset flag
		is_shooting = false

func shoot():
	if not bullet_scene:
		return
	
	time_since_last_shot = 0.0
	is_shooting = true
	
	# Create bullet instance
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	# Position bullet slightly in front of player (offset in direction of shooting)
	var spawn_offset = mouse_direction * 20  # Offset by 20 pixels in shooting direction
	bullet.global_position = global_position + spawn_offset
	
	# Set bullet direction and speed
	if bullet.has_method("set_direction"):
		bullet.set_direction(mouse_direction)
	elif "direction" in bullet:
		bullet.direction = mouse_direction
	elif "velocity" in bullet:
		bullet.velocity = mouse_direction * bullet_speed

func update_animations(direction: Vector2):
	if not animated_sprite.sprite_frames:
		return
	
	var anim_name: String = ""
	var is_moving = velocity.length() > 0
	var is_shooting_button = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# If shooting (mouse button held), use shoot animation based on mouse direction
	# Character faces mouse direction regardless of movement direction
	if is_shooting_button:
		anim_name = get_direction_animation(mouse_direction, "shoot")
		last_direction = mouse_direction  # Update facing direction to mouse
	elif is_moving:
		anim_name = get_direction_animation(direction, "walk")
		last_direction = direction
	else:
		anim_name = get_direction_animation(last_direction, "idle")
	
	if anim_name != "" and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func get_direction_animation(dir: Vector2, anim_type: String) -> String:
	var prefix = anim_type  # "walk", "idle", or "shoot"
	
	# Normalize direction
	if dir.length() < 0.1:
		dir = last_direction if last_direction.length() > 0.1 else Vector2.DOWN
	
	# For shoot animations, we have more directions (including pure left/right)
	if anim_type == "shoot":
		return get_shoot_direction_animation(dir)
	
	# Threshold for determining if it's more vertical or horizontal
	var threshold = 0.707  # Cos/Sin of 45 degrees (normalized diagonal)
	var abs_x = abs(dir.x)
	var abs_y = abs(dir.y)
	
	# Check vertical direction first (up/down)
	if abs_y > abs_x * threshold:
		# Primarily vertical
		if dir.y < 0:
			return prefix + " up"
		else:
			return prefix + " down"
	else:
		# Primarily horizontal or diagonal
		if dir.y < 0:  # Upper half (up directions)
			if dir.x < 0:
				return prefix + " left up"
			else:
				return prefix + " right up"
		else:  # Lower half (down directions)
			if dir.x < 0:
				return prefix + " left down"
			else:
				return prefix + " right down"

func get_shoot_direction_animation(dir: Vector2) -> String:
	# For shooting, we have 8 directions including pure left/right
	var abs_x = abs(dir.x)
	var abs_y = abs(dir.y)
	var threshold = 0.5  # Threshold for pure directions
	
	# Check for pure vertical (up/down)
	if abs_x < threshold:
		if dir.y < 0:
			return "shoot up"
		else:
			return "shoot down"
	# Check for pure horizontal (left/right)
	elif abs_y < threshold:
		if dir.x < 0:
			return "shoot left"
		else:
			return "shoot right"
	# Diagonals
	else:
		if dir.y < 0:  # Upper half
			if dir.x < 0:
				return "shoot left up"
			else:
				return "shoot right up"
		else:  # Lower half
			if dir.x < 0:
				return "shoot left down"
			else:
				return "shoot right down"
