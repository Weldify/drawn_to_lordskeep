@tool
extends Node3D

func _func_godot_build_complete():
	for child in get_parent().get_children():
		if child.name.ends_with("_func_geo") or child.name.ends_with("_func_detail"):
			child.add_to_group("navigation_mesh_source_group")
		elif child.name.ends_with("_func_district_border"):
			owner.border_to_next_district = child
		
	owner.get_node("Navmesh").bake_navigation_mesh()
