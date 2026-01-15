extends CanvasLayer

@onready var ammo_label = $AmmoLabel
@onready var reload_progress = $ReloadProgress

var gun: Node = null
var last_known_ammo: int = 20
var last_known_reloading: bool = false

func _ready():
	# Find gun node (through player)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		var main = get_tree().current_scene
		if main:
			player = main.get_node_or_null("Player")
	
	if player:
		gun = player.get_node_or_null("Gun")
	
	if not gun:
		print("AmmoCounter: Could not find gun node!")
	else:
		print("AmmoCounter: Found gun node: ", gun.name)
		if "current_ammo" in gun:
			last_known_ammo = gun.current_ammo
			update_display()

	# Initialize reload progress
	if reload_progress:
		reload_progress.min_value = 0.0
		reload_progress.max_value = 100.0  # Changed from 1.0 to match calculation
		reload_progress.value = 0.0
		reload_progress.visible = false
		reload_progress.fill_mode = 2  # FILL_CLOCKWISE for circular
		reload_progress.radial_initial_angle = 0.0
func _process(_delta):
	if gun and "current_ammo" in gun:
		# Update if ammo changed or reloading state changed
		if gun.current_ammo != last_known_ammo or ("is_reloading" in gun and gun.is_reloading != last_known_reloading):
			update_display()
			last_known_ammo = gun.current_ammo
			if "is_reloading" in gun:
				last_known_reloading = gun.is_reloading
		
		# Update reload progress if reloading
		if "is_reloading" in gun and gun.is_reloading and reload_progress:
			if "reload_time" in gun and "reload_timer" in gun:
				var reload_progress_percent = (1.0 - (gun.reload_timer / gun.reload_time)) * 100.0
				reload_progress.value = reload_progress_percent

func update_display():
	if not ammo_label:
		return

	if gun and "current_ammo" in gun:
		# Check if reloading - show circular progress, hide ammo text
		if "is_reloading" in gun and gun.is_reloading:
			ammo_label.visible = false
			if reload_progress:
				reload_progress.visible = true
		else:
			# Show ammo count as "current/max"
			ammo_label.visible = true
			if reload_progress:
				reload_progress.visible = false
				reload_progress.value = 0.0
			
			var current = str(gun.current_ammo)
			var max_ammo = str(gun.magazine_size) if "magazine_size" in gun else "20"
			ammo_label.text = current + "/" + max_ammo
