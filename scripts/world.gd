extends Node


var my_steam_id: int
var is_hosting := false


func _init_steam():
	if Steam.restartAppIfNecessary(3493740): OS.kill(OS.get_process_id())
		
	var steam_result := Steam.steamInitEx(true, 3493740)
	if steam_result.status != 0:
		push_error("Failed to initialize steam because ", steam_result.verbal)
		OS.kill(OS.get_process_id())
		
	my_steam_id = Steam.getSteamID()
	
	Steam.lobby_joined.connect(func(lobby_id, _perms, _locked, status):
		assert(status == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
		var host_id := Steam.getLobbyOwner(lobby_id)
		if host_id == my_steam_id: return
		
		var peer := SteamMultiplayerPeer.new()
		peer.create_client(host_id, 0)

		reset_all_multiplayer_things()
		multiplayer.multiplayer_peer = peer
	)
	
	Steam.join_requested.connect(func(lobby_id, friend_id):
		# @NOTE: I'm assuming an id of 0 is invalid...
		assert(friend_id != 0, "We don't allow joining non-friends yet!")
		Steam.joinLobby(lobby_id)
	)


func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	if OS.has_feature("steam"):
		_init_steam()
		
	
	var outskirts := preload("res://scenes/outskirts_district.tscn").instantiate()
	$/root/world/Districts.add_child(outskirts, true)
	
	outskirts.generate_next_district()
	
	_spawn_mercenary_for_peer(1)
	
	DiscordRPC.app_id = 1324092717873106974
	DiscordRPC.details = "Don't think too hard on it."
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	DiscordRPC.refresh()
	

	var args := OS.get_cmdline_args()
	for i in args.size():
		var argument := args[i]
		if argument == "+connect_lobby":
			## Steam starts us with this when we click Join Game
			var lobby_id := int(args[i + 1])
			Steam.joinLobby(lobby_id)
		elif argument == "+quickjoin":
			join_by_ip("127.0.0.1")
		elif argument == "+quickhost":
			start_hosting()


## Call this BEFORE setting the multiplayer peer to the new thing!
func reset_all_multiplayer_things():
	for district in $Districts.get_children(): district.free()
	for merc in $Mercenaries.get_children(): merc.free()
	for item in $Items.get_children(): item.free()
	
	NetworkTime.restart()


func _spawn_mercenary_for_peer(peer_id: int) -> void:
	var mercenary := preload("res://scenes/mercenary.tscn").instantiate()
	
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


func _process(_delta: float) -> void:
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


func join_by_ip(ip: String):
	if OS.has_feature("steam"): 
		push_error("Can't direct connect with steam version!")
		return
	
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, 1337)
	assert(peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED)
	
	$/root/world.reset_all_multiplayer_things()
	multiplayer.multiplayer_peer = peer
