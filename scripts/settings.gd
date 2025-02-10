extends Control

@export var look_sensitivity: float :
	set(v):
		look_sensitivity = v
		
		$TabContainer/Settings/Grid/HBoxContainer/LookSensitivitySlider.set_value_no_signal(v)
		$TabContainer/Settings/Grid/HBoxContainer/LookSensitivityBox.set_value_no_signal(v)
	

@export var volume: float :
	set(v):
		volume = v
		AudioServer.set_bus_volume_linear(0, v)
		
		$TabContainer/Settings/Grid/HBoxContainer2/VolumeSlider.set_value_no_signal(v)
		$TabContainer/Settings/Grid/HBoxContainer2/VolumeBox.set_value_no_signal(v)
	

@export var fullscreen: bool :
	set(v):
		fullscreen = v
		if v:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
			
		$TabContainer/Settings/Grid/Fullscreen.set_pressed_no_signal(v)

var _config_file: ConfigFile = ConfigFile.new()

func load_settings():
	_config_file.load("data/game.settings")
	
	look_sensitivity = _config_file.get_value("", "look_sensitivity", 0.2) 
	volume = _config_file.get_value("", "volume", 0.25)
	fullscreen = _config_file.get_value("", "fullscreen", true)


func save_settings():
	var game_dir := DirAccess.open("")
	game_dir.make_dir("data")
	
	_config_file.set_value("", "look_sensitivity", look_sensitivity)
	_config_file.set_value("", "volume", volume)
	_config_file.set_value("", "fullscreen", fullscreen)
	
	var status := _config_file.save("data/game.settings")
	if status != OK:
		push_warning("Failed to save game.settings because ", error_string(status))


func _ready() -> void:
	$TabContainer.current_tab = 1
	visible = false
	G.ui_affecting_mouse_set_visible(self, true)
	
	load_settings()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		G.ui_affecting_mouse_set_visible(self, !visible)


func _update_look_sensitivity(new_value: float):
	look_sensitivity = new_value


func _update_volume(new_value: float):
	volume = new_value


func _update_fullscreen(new_value: bool):
	fullscreen = new_value


func _on_save_pressed() -> void:
	save_settings()
