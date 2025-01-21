extends Node


func _on_body_entered(body: Node3D) -> void:
	# Check if OUR mercenary entered this and not something else.
	var input := body.get_node_or_null("Input")
	if !input or !input.is_multiplayer_authority(): return
	
	if !is_multiplayer_authority(): return
	
	$/root/world.start_hosting()
