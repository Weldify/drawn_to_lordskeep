extends StaticBody3D


## The animation player emits this signal.
@warning_ignore("unused_signal")
signal outro_finished


@export var transform_mirror: Transform3D :
	set(v):
		global_transform = v
	get(): return global_transform


@rpc("authority", "call_local")
func do_closing_effects() -> void:
	var anim_tree := $AnimationTree
	anim_tree.set("parameters/conditions/is_closing", true)
