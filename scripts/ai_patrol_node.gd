extends StaticBody3D
class_name AIPatrolNode

## Set by worldspawn.gd when building is completed
@export var next: AIPatrolNode

# Populated and cleared during map build by worldspawn.gd
@export var func_godot_properties: Dictionary
