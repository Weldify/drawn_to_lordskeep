extends Node
class_name Interpolator

@export var default_properties: Array[StringName]

## @NOTE: We can't just directly use the @export property above...
## Because for whatever reason modifying it carries over to 
## scenes you instantiate afterwards, too?? So it's global????
var properties: Array[StringName]

# Usage:
# Call Interpolator.apply() during _process to apply the interpolated values.
# The original values will be restored automatically after rendering is finished!

var _from: Dictionary
var _to: Dictionary

class PropertyInfo:
	var path: NodePath
	var lerp_as_angle := false # For floats

var _config: Array[PropertyInfo]
var _ticked := false


func apply() -> void:
	if _ticked:
		_ticked = false
		_record()
	
	var parent := get_parent()
	var fraction := Engine.get_physics_interpolation_fraction()
	for info in _config:
		if !_from.has(info.path) or !_to.has(info.path): continue
		
		var node := parent.get_node(info.path)
		var a = _from[info.path]
		var b = _to[info.path]
		
		var result
		if info.lerp_as_angle:
			result = lerp_angle(a, b, fraction)
		else:
			result = lerp(a, b, fraction)
		
		node.set_indexed(info.path.get_as_property_path(), result)


func snap(path: NodePath, value) -> void:
	assert(_from.has(path))
	
	_from[path] = value
	_to[path] = value


func _ready() -> void:
	properties.append_array(default_properties)
	RenderingServer.frame_post_draw.connect(_restore)
	reconfigure()


func _physics_process(_delta: float) -> void:
	_ticked = true


func reconfigure() -> void:
	_from.clear()
	_to.clear()
	_config.clear()
	
	for prop in properties:
		var args := prop.split(" ")
		
		var property := PropertyInfo.new()
		property.path = NodePath(args[0])
		
		args.remove_at(0) # Index 0 is path, everything else is args
		for arg in args:
			if arg == "ANGLE":
				property.lerp_as_angle = true
				print("Lerp ass angle")
			else: assert(false, "What the fuck did you give me?")
		
		_config.append(property)
	
	_update_to()


func _restore() -> void:
	var parent := get_parent()
	
	for path in _to:
		var node := parent.get_node(path)
		
		node.set_indexed(path.get_as_property_path(), _to[path])


func _record() -> void:
	for path in _to:
		_from[path] = _to[path]
	
	_update_to()


func _update_to() -> void:
	var parent := get_parent()
	
	for info in _config:
		var node := parent.get_node(info.path)
		_to[info.path] = node.get_indexed(info.path.get_as_property_path())
