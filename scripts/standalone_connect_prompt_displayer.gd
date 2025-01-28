extends Node

func _on_body_entered(body: Node3D) -> void:
	# Check if OUR mercenary entered this and not something else.
	if body is not Mercenary or !body.is_multiplayer_authority(): return
	
	if OS.has_feature("steam"): 
		$/root/world/SubtitlesUI.display("Dude, you're playing the Steam version.")
		return
	
	G.ui_affecting_mouse_set_visible($/root/world/StandaloneConnectPrompt, true)
