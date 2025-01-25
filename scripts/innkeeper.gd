extends Node3D

var talking := false

func _process(delta: float) -> void:
	var closest: Mercenary
	var closest_distance := INF
	for mercenary: Mercenary in $/root/world/Mercenaries.get_children():
		var dist := mercenary.global_position.distance_squared_to(global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest = mercenary
	
	if !closest: return
	
	var path := closest.get_node("HeadAttachment/Viewpoint").get_path()
	$Skeleton3D/LookAtModifier3D.origin_external_node = path


func _on_area_3d_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server(): return
	if body is not Mercenary: return
	
	if talking: return
	talking = true
	
	send_dialogue_in_range(4, "Ah, I see you've awoken.")
	await get_tree().create_timer(6).timeout
	send_dialogue_in_range(4, "Just in time, too.")
	await get_tree().create_timer(6).timeout
	send_dialogue_in_range(4, "Your stuff? It's all in the satchel. I've no use for it.")
	await get_tree().create_timer(8).timeout
	send_dialogue_in_range(4, "No matter.")
	await get_tree().create_timer(3).timeout
	send_dialogue_in_range(4, "Gather up swiftly.")
	await get_tree().create_timer(6).timeout
	send_dialogue_in_range(4, "The night will fall soon.")
	
	await get_tree().create_timer(8).timeout
	talking = false


func send_dialogue_in_range(distance: float, text: String):
	for mercenary in $/root/world/Mercenaries.get_children():
		if mercenary.global_position.distance_to(global_position) < distance:
			display_dialogue.rpc_id(mercenary.get_multiplayer_authority(), text)


@rpc("authority", "call_local", "reliable")
func display_dialogue(text: String):
	$/root/world/SubtitlesUI.display(text)
