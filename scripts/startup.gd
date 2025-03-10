extends Node

func _ready():
	if true:
		var world := preload("res://scenes/world.tscn").instantiate()
		$/root.add_child.call_deferred(world)
		return
	
	var intro := preload("res://scenes/intro_sequence.tscn").instantiate()
	$/root.add_child.call_deferred(intro)
