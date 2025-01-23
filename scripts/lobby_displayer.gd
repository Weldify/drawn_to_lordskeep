extends Node

func _on_body_entered(body: Node3D) -> void:
	if !OS.has_feature("steam"): return
	
	# Check if OUR mercenary entered this and not something else.
	if body is not Mercenary or !body.is_multiplayer_authority(): return
	
	$/root/world/SteamFriendLobbies.query_and_show()
