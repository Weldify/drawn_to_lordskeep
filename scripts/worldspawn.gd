@tool
extends Node3D


func _func_godot_build_complete():
	var ai_patrol_node_map: Dictionary[StringName, AIPatrolNode]
	
	for child in get_parent().get_children():
		if child is AIPatrolNode:
			ai_patrol_node_map[child.func_godot_properties.targetname] = child
		elif child.name.ends_with("_geo_convex"):
			child.add_to_group(&"navigation_mesh_source_group")
		elif child.name.ends_with("_func_district_border"):
			owner.district_border = child
	
	for targetname in ai_patrol_node_map:
		var node := ai_patrol_node_map[targetname]
		if node.func_godot_properties.target:
			node.next = ai_patrol_node_map[node.func_godot_properties.target]
	
	for targetname in ai_patrol_node_map:
		var node := ai_patrol_node_map[targetname]
		node.func_godot_properties.clear()
	
	# @TODO: Add a separate navmesh entity for this	
	#owner.get_node("Navmesh").bake_navigation_mesh()

@export_tool_button("Fucking NUKE this")
var fucking_nuke_thiss = fucking_nuke_This

func fucking_nuke_This():
	get_parent().queue_free()
