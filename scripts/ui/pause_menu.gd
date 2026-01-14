extends CanvasLayer

@onready var pause_panel = $PausePanel
@onready var keybinds_menu = $KeybindsMenu
@onready var dev_tools_menu= $DevToolsMenu

var is_paused: bool = false

enum MenuState {
	MAIN,
	KEYBINDS,
	DEV_TOOLS
}

var current_menu: MenuState = MenuState.MAIN

# DEV tools UI references
@onready var player_speed_slider = dev_tools_menu.get_node_or_null("PlayerSpeedSlider")
@onready var player_speed_label = dev_tools_menu.get_node_or_null("PlayerSpeedLabel")
@onready var bullet_velocity_slider = dev_tools_menu.get_node_or_null("BulletVelocitySlider")
@onready var bullet_velocity_label = dev_tools_menu.get_node_or_null("BulletVelocityLabel")
@onready var fire_rate_slider = dev_tools_menu.get_node_or_null("FireRateSlider")
@onready var fire_rate_label = dev_tools_menu.get_node_or_null("FireRateLabel")
@onready var infinite_ammo_checkbox = dev_tools_menu.get_node_or_null("InfiniteAmmoCheckBox")
@onready var infinite_hp_checkbox = dev_tools_menu.get_node_or_null("InfiniteHPCheckBox")
@onready var reset_all_button = dev_tools_menu.get_node_or_null("ResetAllButton")

# Default values
var default_player_speed: float = 200.0
var default_bullet_velocity: float = 1000.0
var default_fire_rate: float = 0.2

# Keybind Menu UI references
@onready var dash_keybind_button = keybinds_menu.get_node_or_null("DashKeybindButton")
@onready var dash_reset_button = keybinds_menu.get_node_or_null("DashResetButton")
@onready var keybind_error_label = keybinds_menu.get_node_or_null("KeybindErrorLabel")

# Keybinds Manager 
var keybinds_manager: Node = null
var waiting_for_keybind: String = "" # Action name we are waiting to rebind

# Player and gun references
var player: Node = null
var gun: Node = null

func _ready():
	# Set process mode to always so we can receive input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	#Find player node
	player = get_tree().get_first_node_in_group("player")
	if not player:
		var main = get_tree().current_scene
		if main:
			player = main.get_node_or_null("Player")
	
	# Find gun node (through player)
	if player:
		gun = player.get_node_or_null("Gun")
	
	# Get keybinds manager
	keybinds_manager = get_node("/root/KeybindManager") if has_node("/root/KeybindManager") else null
	if not keybinds_manager:
		# If not found, we'll handle it gracefully
		keybinds_manager = null
	
	# Hide pause panel initially
	if pause_panel:
		pause_panel.visible = false
	if keybinds_menu:
		keybinds_menu.visible = false
	if dev_tools_menu:
		dev_tools_menu.visible = false

	# Connect button signals
	var keybinds_button = pause_panel.get_node("KeybindsButton")
	if keybinds_button:
		keybinds_button.pressed.connect(show_keybinds_menu)
	var dev_tools_button = pause_panel.get_node("DevToolsButton")
	if dev_tools_button:
		dev_tools_button.pressed.connect(show_dev_tools_menu)

	var back_keybinds = keybinds_menu.get_node_or_null("BackButtonKeybinds")
	if back_keybinds:
		back_keybinds.pressed.connect(show_main_menu)
	var back_dev_tools = dev_tools_menu.get_node_or_null("BackButtonDevTools")
	if back_dev_tools:
		back_dev_tools.pressed.connect(show_main_menu)
	# Connect keybind UI
	if dash_keybind_button:
		dash_keybind_button.pressed.connect(_on_dash_keybind_button_pressed)
	if dash_reset_button:
		dash_reset_button.pressed.connect(_on_dash_reset_button_pressed)
	

	#Connect Dev tools
	if player_speed_slider:
		player_speed_slider.value_changed.connect(_on_player_speed_changed)
		if player:
			player_speed_slider.value = player.speed if "speed" in player else default_player_speed
		else:
			player_speed_slider.value = default_player_speed
		_update_player_speed_label()

	if bullet_velocity_slider:
		bullet_velocity_slider.value_changed.connect(_on_bullet_velocity_changed)
		if player:
			bullet_velocity_slider.value = player.bullet_speed if "bullet_speed" in player else default_bullet_velocity
		else:
			bullet_velocity_slider.value = default_bullet_velocity
		_update_bullet_velocity_label()

	if fire_rate_slider:
		fire_rate_slider.value_changed.connect(_on_fire_rate_changed)
		if gun:
			fire_rate_slider.value = gun.fire_rate if "fire_rate" in gun else default_fire_rate
		else:
			fire_rate_slider.value = default_fire_rate
		_update_fire_rate_label()
	
	if infinite_ammo_checkbox:
		infinite_ammo_checkbox.toggled.connect(_on_infinite_ammo_toggled)
		if gun and "infinite_ammo" in gun:
			infinite_ammo_checkbox.button_pressed = gun.infinite_ammo
	
	if infinite_hp_checkbox:
		infinite_hp_checkbox.toggled.connect(_on_infinite_hp_toggled)
		if player and "infinite_hp" in player:
			infinite_hp_checkbox.button_pressed = player.infinite_hp
	
	if reset_all_button:
		reset_all_button.pressed.connect(reset_all_to_defaults)
	
	# Initialize reset buttons
	var reset_speed_button = dev_tools_menu.get_node_or_null("ResetSpeedButton")
	if reset_speed_button:
		reset_speed_button.pressed.connect(reset_player_speed)
	
	var reset_velocity_button = dev_tools_menu.get_node_or_null("ResetVelocityButton")
	if reset_velocity_button:
		reset_velocity_button.pressed.connect(reset_bullet_velocity)

	var reset_fire_rate_button = dev_tools_menu.get_node_or_null("ResetFireRateButton")
	if reset_fire_rate_button:
		reset_fire_rate_button.pressed.connect(reset_fire_rate)

func _input(event):
	# Handle keybind assignment (use _input to catch mouse buttons)
	if waiting_for_keybind != "":
		var input_code = 0
		
		if event is InputEventKey and event.pressed:
			# Ignore ESC key
			if event.keycode == KEY_ESCAPE:
				waiting_for_keybind = ""
				update_keybind_display()
				get_viewport().set_input_as_handled()
				return
			
			input_code = event.keycode
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			# Skip mouse wheel buttons (they're used for zoom)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				return
			# Encode mouse button with offset (MOUSE_BUTTON_OFFSET = 1000)
			input_code = 1000 + event.button_index
			get_viewport().set_input_as_handled()
		
		if input_code != 0:
			# Check if keybinds_manager exists
			if not keybinds_manager:
				waiting_for_keybind = ""
				if keybind_error_label:
					keybind_error_label.text = "Keybinds manager not found"
				update_keybind_display()
				return
			
			var result = keybinds_manager.set_keybind(waiting_for_keybind, input_code)
			if result.success:
				waiting_for_keybind = ""
				update_keybind_display()
				if keybind_error_label:
					keybind_error_label.text = ""
			else:
				if keybind_error_label:
					keybind_error_label.text = result.error
				# Still update display to show the attempt
				waiting_for_keybind = ""
				update_keybind_display()
			return

func _unhandled_input(event):
	# Only handle ESC key 
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if current_menu == MenuState.MAIN:
				toggle_pause()
			else:
				show_main_menu()
			get_viewport().set_input_as_handled()

func toggle_pause():
	is_paused = !is_paused

	if is_paused:
		# Pause the game
		get_tree().paused = true
		show_main_menu()
	else:
		# Resume the game
		get_tree().paused = false
		hide_all_menus()
		current_menu = MenuState.MAIN

func show_main_menu():
	current_menu = MenuState.MAIN
	if pause_panel:
		pause_panel.visible = true
	if keybinds_menu:
		keybinds_menu.visible = false
	if dev_tools_menu:
		dev_tools_menu.visible = false

func show_keybinds_menu():
	current_menu = MenuState.KEYBINDS
	if pause_panel:
		pause_panel.visible = false
	if keybinds_menu:
		keybinds_menu.visible = true
	if dev_tools_menu:
		dev_tools_menu.visible = false
	
	# Update keybind display when showing the menu
	update_keybind_display()
	if keybind_error_label:
		keybind_error_label.text = ""

func show_dev_tools_menu():
	current_menu = MenuState.DEV_TOOLS
	if pause_panel:
		pause_panel.visible = false
	if keybinds_menu:
		keybinds_menu.visible = false
	if dev_tools_menu:
		dev_tools_menu.visible = true

func hide_all_menus():
	if pause_panel:
		pause_panel.visible = false
	if keybinds_menu:
		keybinds_menu.visible = false
	if dev_tools_menu:
		dev_tools_menu.visible = false

# Dev tools functions
func _on_player_speed_changed(value: float):
	if player and "speed" in player:
		player.speed = value
	_update_player_speed_label()

func _on_bullet_velocity_changed(value: float):
	if player and "bullet_speed" in player:
		player.bullet_speed = value
	_update_bullet_velocity_label()

func _on_fire_rate_changed(value: float):
	if gun and "fire_rate" in gun:
		gun.fire_rate = value
	_update_fire_rate_label()

func _on_infinite_ammo_toggled(pressed: bool):
	if gun:
		if "infinite_ammo" not in gun:
			gun.set("infinite_ammo", pressed)
		else:
			gun.infinite_ammo = pressed

func _on_infinite_hp_toggled(pressed: bool):
	if player:
		if "infinite_hp" not in player:
			player.set("infinite_hp", pressed)
		else:
			player.infinite_hp = pressed

func _update_player_speed_label():
	if player_speed_label and player_speed_slider:
		player_speed_label.text = "Player Move Speed: %.0f" % player_speed_slider.value

func _update_bullet_velocity_label():
	if bullet_velocity_label and bullet_velocity_slider:
		bullet_velocity_label.text = "Bullet Velocity: %.0f" % bullet_velocity_slider.value

func _update_fire_rate_label():
	if fire_rate_label and fire_rate_slider:
		fire_rate_label.text = "Fire Rate: %.2f sec" % fire_rate_slider.value

func reset_player_speed():
	if player_speed_slider:
		player_speed_slider.value = default_player_speed

func reset_bullet_velocity():
	if bullet_velocity_slider:
		bullet_velocity_slider.value = default_bullet_velocity

func reset_fire_rate():
	if fire_rate_slider:
		fire_rate_slider.value = default_fire_rate

func reset_all_to_defaults():
	reset_player_speed()
	reset_bullet_velocity()
	reset_fire_rate()
	if infinite_ammo_checkbox:
		infinite_ammo_checkbox.button_pressed = false
	if infinite_hp_checkbox:
		infinite_hp_checkbox.button_pressed = false

# Keybind functions
func _on_dash_keybind_button_pressed():
	if not keybinds_manager:
		return
	
	waiting_for_keybind = "dash"
	if dash_keybind_button:
		dash_keybind_button.text = "Press any key..."
	if keybind_error_label:
		keybind_error_label.text = ""

func _on_dash_reset_button_pressed():
	if keybinds_manager:
		keybinds_manager.reset_keybind("dash")
		update_keybind_display()
		if keybind_error_label:
			keybind_error_label.text = ""

# func _input(event):
# 	# Handle keybind assignment
# 	if waiting_for_keybind != "":
# 		if event is InputEventKey and event.pressed:
# 			get_viewport().set_input_as_handled()
			
# 			# Ignore ESC key
# 			if event.keycode == KEY_ESCAPE:
# 				waiting_for_keybind = ""
# 				update_keybind_display()
# 				return
			
# 			var result = keybinds_manager.set_keybind(waiting_for_keybind, event.keycode)
# 			if result.success:
# 				waiting_for_keybind = ""
# 				update_keybind_display()
# 				if keybind_error_label:
# 					keybind_error_label.text = ""
# 			else:
# 				if keybind_error_label:
# 					keybind_error_label.text = result.error
# 				# Still update display to show the attempt
# 				waiting_for_keybind = ""
# 				update_keybind_display()

func update_keybind_display():
	if not keybinds_manager or not dash_keybind_button:
		return
	
	var dash_keycode = keybinds_manager.get_keybind("dash")
	var key_string = keybinds_manager.keycode_to_string(dash_keycode)
	dash_keybind_button.text = key_string
