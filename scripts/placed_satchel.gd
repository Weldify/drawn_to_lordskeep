extends Node

var is_closing := false

func _process(delta: float) -> void:
	var anim_tree := $AnimationTree
	anim_tree.set("parameters/conditions/is_closing", is_closing)
