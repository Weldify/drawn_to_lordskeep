extends Node


func _on_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server(): return
	
	# Check if OUR mercenary entered this and not something else.
	if body is not Mercenary or !body.is_multiplayer_authority(): return
	
	$/root/world.start_hosting()
	$/root/world/SubtitlesUI.display("Your allies can now join you.")
