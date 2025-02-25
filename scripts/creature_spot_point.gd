extends Node3D
class_name CreatureSpotPoint

## The creature that will be spotted when this spot point is seen.
@export var target: Node3D

func _ready():
	assert("spot_points" in target)
	var spot_points := target.spot_points as Array[CreatureSpotPoint]
	spot_points.append(self)
