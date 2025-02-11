extends Node

## Deletes things that fell off the map, most likely due to the
## district they're in getting unloaded. We probably also want to
## try and query things inside a district and delete them just as we unload it.
## But right now we have this, as a crutch.

@export var node_to_query: Node

var next_index_to_check := 0

func _physics_process(_delta: float) -> void:
	if !multiplayer.is_server(): return
	
	var child_count := node_to_query.get_child_count()
	if child_count == 0: return
	
	if next_index_to_check > child_count-1:
		next_index_to_check = 0
	
	var child := node_to_query.get_child(next_index_to_check)
	if child is Node3D and child.global_position.y < -5:
		child.free()
	
	next_index_to_check += 1
