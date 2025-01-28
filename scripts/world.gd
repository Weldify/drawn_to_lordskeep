extends Node


var my_steam_id: int
var is_hosting := false


func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	if OS.has_feature("steam"):
		var steam_result := Steam.steamInitEx(true, 3493740)
		if steam_result.status != 0:
			OS.alert("Where the FUCK is steam", "We need steam")
			OS.kill(OS.get_process_id())
			
		my_steam_id = Steam.getSteamID()
		
		Steam.lobby_joined.connect(func(lobby_id, _perms, _locked, status):
			assert(status == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
			var host_id := Steam.getLobbyOwner(lobby_id)
			if host_id == my_steam_id: return
			
			var peer := SteamMultiplayerPeer.new()
			peer.create_client(host_id, 0)
	
			multiplayer.multiplayer_peer = peer
			reset_all_multiplayer_things()
		)
	
	_spawn_mercenary_for_peer(1)
	
	var mace := preload("res://mace.tscn").instantiate()
	$/root/world/Items.add_child(mace, true)
	mace.global_position = Vector3(0, 2, 0)
	
	var arming_sword := preload("res://arming_sword.tscn").instantiate()
	$/root/world/Items.add_child(arming_sword, true)
	arming_sword.global_position = Vector3(0, 2, 0)
	
	for i in 20:
		var can := preload("res://pepsi_max.tscn").instantiate()
		$/root/world/Items.add_child(can, true)
		can.global_position = Vector3(0, 2, 0)
	
	var booze := preload("res://booze.tscn").instantiate()
	$/root/world/Items.add_child(booze, true)
	booze.global_position = Vector3(0, 2, 0)
	
	DiscordRPC.app_id = 1324092717873106974
	DiscordRPC.details = "Don't think too hard on it."
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	DiscordRPC.refresh()


## Call this AFTER setting the multiplayer peer to the new thing!
func reset_all_multiplayer_things():
	for merc in $Mercenaries.get_children(): merc.free()
	for item in $Items.get_children(): item.free()
	
	NetworkTime.restart()


func _spawn_mercenary_for_peer(peer_id: int) -> void:
	var mercenary := preload("res://mercenary.tscn").instantiate()
	
	var node_name := str(peer_id)
	assert($Mercenaries.get_node_or_null(node_name) == null)
	
	mercenary.name = str(node_name)
	
	$Mercenaries.add_child(mercenary)
	
	var editor_spawnpoint := $/root/world.get_node_or_null("EditorSpawnpoint")
	if editor_spawnpoint and OS.has_feature("editor"):
		mercenary.global_position = editor_spawnpoint.global_position
	else:
		mercenary.global_position = get_tree().get_nodes_in_group("spawnpoint").pick_random().global_position


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_mercenary_for_peer(peer_id)


func _process(delta: float) -> void:
	if OS.has_feature("steam"):
		Steam.run_callbacks()
	
	
	G.clear_freed_mouse_unlockers()
	var mouse_mode := Input.MOUSE_MODE_CAPTURED
	if !G.mouse_unlockers.is_empty():
		mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode != mouse_mode:
		Input.mouse_mode = mouse_mode


func start_hosting() -> void:
	assert(multiplayer.is_server(), "We are connected to someone else... Not good!")
	
	if is_hosting: return
	is_hosting = true
	
	if OS.has_feature("steam"):
		Steam.lobby_created.connect(func(status, lobby_id):
			assert(status == 1)
		
			Steam.setLobbyJoinable(lobby_id, true)
			Steam.setLobbyData(lobby_id, "name", "Test")
			Steam.setLobbyData(lobby_id, "mode", "Drawn to Lordskeep")
			
			var peer := SteamMultiplayerPeer.new()
			peer.create_host(0)
		
			multiplayer.multiplayer_peer = peer
		)
		
		Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)
	else:
		var peer := ENetMultiplayerPeer.new()
		peer.create_server(1337, 2)
		assert(peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
		
		multiplayer.multiplayer_peer = peer
