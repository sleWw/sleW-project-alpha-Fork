extends CanvasLayer

@onready var ammo_label = $AmmoLabel
@onready var reload_progress = $ReloadProgress

var player: Node = null
var last_known_ammo: int = 20
var last_known_reloading: bool = false

func _ready():
	# Find player node 
	player = get_tree().get_first_node_in_group("player")
	if not player:
		var main = get_tree().current_scene
		if main:
			player = main.get_node_or_null("Player")
	
	if not player:
		print("AmmoCounter: Could not find player node!")
	else:
		print("AmmoCounter: Found player node: ", player.name)
		if "current_ammo" in player:
			last_known_ammo = player.current_ammo
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
	if player and "current_ammo" in player:
		# Update if ammo changed or reloading state changed
		if player.current_ammo != last_known_ammo or ("is_reloading" in player and player.is_reloading != last_known_reloading):
			update_display()
			last_known_ammo = player.current_ammo
			if "is_reloading" in player:
				last_known_reloading = player.is_reloading
		
		# Update reload progress if reloading
		if "is_reloading" in player and player.is_reloading and reload_progress:
			if "reload_time" in player and "reload_timer" in player:
				var reload_progress_percent = (1.0 - (player.reload_timer / player.reload_time)) * 100.0
				reload_progress.value = reload_progress_percent

func update_display():
	if not ammo_label:
		return
	
	if player and "current_ammo" in player:
		# Check if reloading - show circular progress, hide ammo text
		if "is_reloading" in player and player.is_reloading:
			ammo_label.visible = false
			if reload_progress:
				reload_progress.visible = true
		else:
			# Show ammo count as "current/max"
			ammo_label.visible = true
			if reload_progress:
				reload_progress.visible = false
				reload_progress.value = 0.0
			
			var current = str(player.current_ammo)
			var max_ammo = str(player.magazine_size) if "magazine_size" in player else "20"
			ammo_label.text = current + "/" + max_ammo
