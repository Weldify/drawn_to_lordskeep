extends Node

@onready var root: Node3D = $".."
@export var modifier: LookAtModifier3D

var target: Node3D
func _ready():
	target = Node3D.new()
	add_child(target, false, Node.INTERNAL_MODE_FRONT)
	modifier.origin_external_node = target.get_path()

func _process(delta: float) -> void:
	var closest: Mercenary
	var closest_distance := INF
	for mercenary: Mercenary in $/root/world/Mercenaries.get_children():
		var dist := mercenary.global_position.distance_squared_to(root.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest = mercenary
	
	if !closest: return
	
	var viewpoint: Node3D = closest.get_node("HeadAttachment/Viewpoint")
	target.global_position = lerp(target.global_position, viewpoint.global_position, delta * 2)
