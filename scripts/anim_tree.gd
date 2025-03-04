@tool
extends AnimationTree


## @NOTE: Changing up param settings at runtime is not supported.

## @TODO: And thats a big todo,
## Automatically generate reroute dictionary without reroute config
## by reading all properties


@export_tool_button("Start preview")
var _start_preview_action := _start_preview
var _editor_preview_active = false


@export var multiparams: Dictionary[StringName, Variant]:
	set(v):
		multiparams = v
		if Engine.is_editor_hint(): _apply_default_params()


@export_multiline var multiparams_reroute: String
var _reroute_dict: Dictionary[StringName, PackedStringArray]


func set_multiparam(parameter_name: StringName, value):
	if !_reroute_dict.has(parameter_name):
		push_warning("Reroute dictionary missing parameter ", parameter_name)
		return
	
	for rerouted_name in _reroute_dict[parameter_name]:
		if rerouted_name not in self:
			push_warning("Tried rerouting parameter ", parameter_name, " to ", rerouted_name, " but it doesn't exist.")
			continue
		
		set(rerouted_name, value)


func _ready():
	if !Engine.is_editor_hint(): _build_reroute()
	_apply_default_params()


func _apply_default_params():
	if Engine.is_editor_hint() and !_editor_preview_active: return
	
	for parameter_name in multiparams:
		var starting_value = multiparams[parameter_name]
		set_multiparam(parameter_name, starting_value)


func _build_reroute():
	_reroute_dict.clear()
	
	var cfg := ConfigFile.new()
	var err := cfg.parse(multiparams_reroute)
	if err: 
		push_error("Can't parse this bullshit, audit the input bro!")
		return
	
	for param_name in cfg.get_section_keys(""):
		var reroute_array := PackedStringArray(cfg.get_value("", param_name))
		
		for i in reroute_array.size():
			reroute_array[i] = "parameters/" + reroute_array[i]
		
		_reroute_dict[param_name] = reroute_array


func _start_preview():
	assert(Engine.is_editor_hint())
	
	_editor_preview_active = true
	_build_reroute()
	_apply_default_params()
