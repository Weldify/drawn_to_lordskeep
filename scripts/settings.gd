extends Control

var look_sensitivity: float :
	set(v):
		look_sensitivity = v
		
		$TabContainer/Settings/Grid/HBoxContainer/LookSensitivitySlider.set_value_no_signal(v)
		$TabContainer/Settings/Grid/HBoxContainer/LookSensitivityBox.set_value_no_signal(v)
	

var volume: float :
	set(v):
		volume = v
		AudioServer.set_bus_volume_linear(0, v)
		
		$TabContainer/Settings/Grid/HBoxContainer2/VolumeSlider.set_value_no_signal(v)
		$TabContainer/Settings/Grid/HBoxContainer2/VolumeBox.set_value_no_signal(v)
	

var fullscreen: bool :
	set(v):
		fullscreen = v
		if v:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
			
		$TabContainer/Settings/Grid/Fullscreen.set_pressed_no_signal(v)


var interpolation_delay: int :
	set(v):
		interpolation_delay = v
		NetSynchronizer.snapshot_delay_ticks = interpolation_delay
		$TabContainer/Settings/Grid/InterpolationDelay.set_value_no_signal(v)
		print("Set to ", v)


var msaa_level: Viewport.MSAA :
	set(v):
		msaa_level = v
		get_viewport().msaa_3d = v
		print("Set msaa")
		$TabContainer/Settings/Grid/MsaaLevel.selected = v


const variables: PackedStringArray = [
	"look_sensitivity",
	"volume",
	"fullscreen",
	"interpolation_delay",
	"msaa_level"
]

var _defaults: Dictionary[StringName, Variant]

var _config_file: ConfigFile = ConfigFile.new()

func load_settings():
	_config_file.load("data/game.settings")
	
	for variable_name in variables:
		if !_config_file.has_section_key("", variable_name):
			set(variable_name, _defaults.get(variable_name))
			continue
		
		var value = _config_file.get_value("", variable_name)
		assert(value != null)
		
		set(variable_name, value)


func save_settings():
	var game_dir := DirAccess.open("")
	game_dir.make_dir("data")
	
	for variable_name in variables:
		var value = get(variable_name)
		assert(value != null, "Where da prop lad?")
		
		_config_file.set_value("", variable_name, value)
	
	var status := _config_file.save("data/game.settings")
	if status != OK:
		push_warning("Failed to save game.settings because ", error_string(status))


func _ready() -> void:
	_defaults = {
		"look_sensitivity": 0.2,
		"volume": 0.25,
		"fullscreen": true,
		"snapshot_delay_ticks": NetSynchronizer.snapshot_delay_ticks,
		"msaa_level": get_viewport().msaa_3d
	}
	
	$TabContainer.current_tab = 1
	load_settings()
	
	visible = false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		G.ui_affecting_mouse_set_visible(self, !visible)


func _update_look_sensitivity(new_value: float):
	look_sensitivity = new_value


func _update_volume(new_value: float):
	volume = new_value


func _update_fullscreen(new_value: bool):
	fullscreen = new_value


func _update_interpolation_delay(v: float):
	interpolation_delay = v as int


func _update_msaa_level(v: int):
	msaa_level = v as Viewport.MSAA


func _on_save_pressed() -> void:
	save_settings()
