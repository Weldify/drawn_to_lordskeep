extends Node

func _on_body_entered(body: Node3D) -> void:
	# Check if OUR mercenary entered this and not something else.
	if body is not Mercenary or !body.is_multiplayer_authority(): return
	
	if !OS.has_feature("steam"): 
		$/root/world/SubtitleUI.display("Dude, you're NOT playing the Steam version.")
		return
	
	$/root/world/SteamFriendLobbies.query_and_show()
