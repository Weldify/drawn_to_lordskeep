extends Node
class_name Interpolator

@export var properties: Array[StringName]

# Usage:
# Call Interpolator.apply() during _process to apply the interpolated values.
# The original values will be restored automatically after rendering is finished!

var _from: Dictionary
var _to: Dictionary
var _paths: Array[NodePath]

var _ticked := false

func _ready() -> void:
	RenderingServer.frame_post_draw.connect(restore)
	configure()
	_update_to()


func _physics_process(_delta: float) -> void:
	_ticked = true


func configure() -> void:
	var paths_to_erase := _paths.duplicate()
	_paths.clear()
	
	for path_name in properties:
		var path := NodePath(path_name)
		_paths.append(path)
		paths_to_erase.erase(path)
	
	for path in paths_to_erase:
		_from.erase(path)
		_to.erase(path)


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
