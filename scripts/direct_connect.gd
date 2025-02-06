extends Control


func _ready():
	visible = !OS.has_feature("steam")


func _on_join_pressed() -> void:
	var ip: String = $LineEdit.text
	
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, 1337)
	assert(peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED)
	
	$/root/world.reset_all_multiplayer_things()
	multiplayer.multiplayer_peer = peer
