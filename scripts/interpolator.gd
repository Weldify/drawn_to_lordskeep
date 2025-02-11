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
var _paths: Array[NodePath]

var _ticked := false

func _ready() -> void:
	properties.append_array(default_properties)
	RenderingServer.frame_post_draw.connect(restore)
	reconfigure()


func _physics_process(_delta: float) -> void:
	_ticked = true


func reconfigure() -> void:
	_from.clear()
	_to.clear()
	_paths.clear()
	
	for path_name in properties:
		var path := NodePath(path_name)
		_paths.append(path)
	
	_update_to()


func restore() -> void:
	var parent := get_parent()
	
	for path in _to:
		var node := parent.get_node(path)
		
		node.set_indexed(path.get_as_property_path(), _to[path])


func record() -> void:
	for path in _to:
		_from[path] = _to[path]
	
	_update_to()


func teleport() -> void:
	for path in _to:
		_from[path] = _to[path]


func apply() -> void:
	if _ticked:
		_ticked = false
		record()
	
	var parent := get_parent()
	var fraction := Engine.get_physics_interpolation_fraction()
	for path in _from:
		if !_to.has(path): continue
		
		var node := parent.get_node(path)
		var a = _from[path]
		var b = _to[path]
		
		node.set_indexed(path.get_as_property_path(), lerp(a, b, fraction))


func _update_to() -> void:
	var parent := get_parent()
	
	for path in _paths:
		var node := parent.get_node(path)
		_to[path] = node.get_indexed(path.get_as_property_path())
