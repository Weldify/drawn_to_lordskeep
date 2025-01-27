extends Node3D

var talking := false


func _on_area_3d_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server(): return
	if body is not Mercenary: return
	
	if talking: return
	talking = true
	
	G.send_dialogue_in_range(global_position, 4, "Ah, I see you've awoken.")
	await get_tree().create_timer(6).timeout
	G.send_dialogue_in_range(global_position, 4, "Just in time, too.")
	await get_tree().create_timer(6).timeout
	G.send_dialogue_in_range(global_position, 4, "Your stuff? It's all in the satchel. I've no use for it.")
	await get_tree().create_timer(8).timeout
	G.send_dialogue_in_range(global_position, 4, "No matter.")
	await get_tree().create_timer(3).timeout
	G.send_dialogue_in_range(global_position, 4, "Gather up swiftly.")
	await get_tree().create_timer(6).timeout
	G.send_dialogue_in_range(global_position, 4, "The night will fall soon.")
	
	await get_tree().create_timer(8).timeout
	talking = false
