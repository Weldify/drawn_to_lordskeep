extends Control

func _process(delta: float) -> void:
	if !is_instance_valid(G.viewer_mercenary): return
	
	# We need to do manual layout because Godot doesn't have an option for int snapping
	# So the glyph might look blurry if the resolution isnt an even number
	
	
	var viewport_size: Vector2i = get_viewport().size
	size.y = viewport_size.y/3
	size.x = viewport_size.y/3
	position = Vector2i(viewport_size.x/2 - size.x/2, viewport_size.y - size.y - 16)
	
	var skeleton: Skeleton3D = G.viewer_mercenary.get_node("Model/Skeleton3D")
	var bone_idx := skeleton.find_bone("root")
	var bone_pos := skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
	
	$ViewportContainer/SubViewport/Camera3D.global_position = bone_pos.origin + Vector3(0, 0.9, 5)
