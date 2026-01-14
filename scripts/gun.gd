extends Node2D

# Bullet configuration
const BULLET = preload("res://scenes/bullets/bullet.tscn")
@export var fire_rate: float = 0.2  # Time between shots

# References
@onready var muzzle_marker = $MuzzleMarker
@onready var shoot_sound = $ShootSoundPlayer
@onready var reload_sound = $ReloadSoundPlayer

# Ammo Variables
@export var magazine_size: int = 20
var current_ammo: int = 20
var is_reloading: bool = false
@export var reload_time: float = 1.5
var reload_timer: float = 0.0

# Dev tools flags
var infinite_ammo: bool = false

# Shooting variables
var time_since_last_shot: float = 0.0

func _ready():
	pass

func _process(delta: float) -> void:
	# Get the player's global position (parent node)
	var player_global_pos = get_parent().global_position
	
	# Get mouse position in global coordinates
	var mouse_global_pos = get_global_mouse_position()
	
	# Calculate direction from player to mouse
	var direction_to_mouse = (mouse_global_pos - player_global_pos).normalized()
	
	# Calculate the angle to the mouse
	var angle_to_mouse = direction_to_mouse.angle()
	
	# Set orbit radius (distance from player center)
	var orbit_radius = 30.0  # Adjust this value to change how far the gun orbits
	
	# Position the gun at the orbit radius based on the angle
	# Since gun is a child of player, we use local position
	position = Vector2(cos(angle_to_mouse), sin(angle_to_mouse)) * orbit_radius
	
	# Rotate the gun to face the mouse
	look_at(mouse_global_pos)
	
	# Flip sprite if pointing left (optional, you can remove this if not needed)
	rotation_degrees = wrap(rotation_degrees, 0, 360)
	if rotation_degrees > 90 and rotation_degrees < 270:
		scale.y = -1
	else:
		scale.y = 1
	
	# Update timers
	time_since_last_shot += delta
	
	# Update reload timer
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			reload_timer = 0.0
			finish_reload()
	
	# Handle shooting with left mouse button
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if time_since_last_shot >= fire_rate and not is_reloading:
			shoot()

func _input(event):
	# Handle reload input (R)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if not infinite_ammo and current_ammo < magazine_size and not is_reloading:
				start_reload()

# Get the direction the gun is facing (based on sprite rotation)
func get_gun_direction() -> Vector2:
	var gun_sprite = get_node_or_null("GunSprite")
	if gun_sprite:
		return Vector2(cos(gun_sprite.rotation), sin(gun_sprite.rotation))
	return Vector2.RIGHT

# Shoot a bullet
func shoot():
	# Don't shoot if reloading
	if is_reloading and not infinite_ammo:
		return
	
	# Auto reload if out of ammo
	if current_ammo <= 0 and not infinite_ammo:
		start_reload()
		return
	
	# Check ammo
	if current_ammo <= 0 and not infinite_ammo:
		return
	
	# Decrement ammo
	if not infinite_ammo:
		current_ammo -= 1
	
	# Play shoot sound
	if shoot_sound:
		shoot_sound.play()
	
	# Create bullet instance
	var bullet = BULLET.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle_marker.global_position
	bullet.rotation = rotation

	var direction = Vector2.RIGHT.rotated(rotation)
	bullet.set_direction(direction)
	
	# Reset fire rate timer
	time_since_last_shot = 0.0

# Reload functions
func start_reload():
	# Do not reload if already reloading or magazine is full
	if is_reloading or current_ammo >= magazine_size:
		return
	
	# Don't reload if infinite ammo
	if infinite_ammo:
		return
	
	# Start reload
	is_reloading = true
	reload_timer = reload_time
	
	# Play reload sound
	if reload_sound:
		reload_sound.play()

func finish_reload():
	# Refill the magazine
	current_ammo = magazine_size
	is_reloading = false
