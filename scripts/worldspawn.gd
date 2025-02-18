@tool
extends Node3D

func _func_godot_build_complete():
	for child in get_parent().get_children():
		if child.name.contains("geo_convex"):
			child.add_to_group("navigation_mesh_source_group")
		elif child.name.ends_with("_func_district_border"):
			owner.district_border = child
	
	# @TODO: Add a separate navmesh entity for this	
	#owner.get_node("Navmesh").bake_navigation_mesh()
