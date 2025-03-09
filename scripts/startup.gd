extends Node

func _ready():
	var intro := preload("res://scenes/intro_sequence.tscn").instantiate()
	$/root.add_child.call_deferred(intro)
