extends Node

func _on_body_entered(body: Node3D) -> void:
	if !OS.has_feature("steam"): return
	
	# Check if OUR mercenary entered this and not something else.
	var input := body.get_node_or_null("Input")
	if !input or !input.is_multiplayer_authority(): return
	
	$/root/world/SteamFriendLobbies.query_and_show()
