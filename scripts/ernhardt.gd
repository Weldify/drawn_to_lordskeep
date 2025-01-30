extends Node3D


var talking := false


func _on_dialogue_area_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server(): return
	if body is not Mercenary: return
	
	if talking: return
	talking = true
	
	G.send_dialogue_in_range(global_position, 4, "They will try to attack the manor tonight.")
	await get_tree().create_timer(8).timeout
	G.send_dialogue_in_range(global_position, 4, "Giv me uoyr medallion bro")
	await get_tree().create_timer(6).timeout
	
	talking = false


func _on_medallion_take_area_body_entered(medallion: Node3D) -> void:
	if !multiplayer.is_server(): return
	if !medallion is Item or medallion.scene_file_path != "res://scenes/mercenary_medallion.tscn": return
	
	medallion.free()
