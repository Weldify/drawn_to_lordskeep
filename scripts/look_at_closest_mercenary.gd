extends Node

@onready var root: Node3D = $".."
@export var modifier: LookAtModifier3D

func _process(delta: float) -> void:
	var closest: Mercenary
	var closest_distance := INF
	for mercenary: Mercenary in $/root/world/Mercenaries.get_children():
		var dist := mercenary.global_position.distance_squared_to(root.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest = mercenary
	
	if !closest: return
	
	var path := closest.get_node("HeadAttachment/Viewpoint").get_path()
	modifier.origin_external_node = path
