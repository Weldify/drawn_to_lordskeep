extends Node3D

var talking := false
var talked := false


func _on_area_3d_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server(): return
	if body is not Mercenary: return
	
	if talking or talked: return
	talking = true
	talked = true
	
	var district := get_parent()
	assert(district is District)
	district.advance()
	
	G.send_dialogue_in_range(global_position, 4, "Yo dude")
	await get_tree().create_timer(6).timeout
	G.send_dialogue_in_range(global_position, 4, "I KEEP a secret passage to the LORDS yo")
	await get_tree().create_timer(6).timeout
	
	G.send_dialogue_in_range(global_position, 4, "Go go go man its behind me and to the left")
	await get_tree().create_timer(8).timeout
	
	talking = false
