extends Node

## The purpose of this node is to
## 1. Provide a synchronized time variable synchronized across all peers
## 2. Provide ping measurements


## Current game time synchronized between all peers
## It's smooth and subtly corrects itself and never ever goes down.
## It can jump forward when the difference is too high.
var now: float

## Round trip time to reach the server and back.
var ping: float

var unsmoothed_ping: float

var _last_known_server_timestamp: float
var _last_received_server_info_at: float

var _client_needs_reliable_info := false

func restart():
	# @NOTE: This is an absolute fucking crutch.
	# I want this to run before anything else processes so it's up to date.
	process_physics_priority = -1000
	process_priority = -1000
	
	ping = 0
	unsmoothed_ping = 0
	now = 0
	
	if !multiplayer.is_server():
		_client_needs_reliable_info = true


func _physics_process(delta: float):
	if multiplayer.is_server() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return
	
	if _client_needs_reliable_info:
		_client_needs_reliable_info = false
		_send_time_request_reliable.rpc_id(1, Time.get_unix_time_from_system())
	else:
		_send_time_request.rpc_id(1, Time.get_unix_time_from_system())


func _process(delta: float):
	_update_clock(delta, false)


func _update_clock(delta: float, instant: bool):
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return
	
	if multiplayer.is_server():
		ping = 0
		unsmoothed_ping = 0
		now = max(now, Time.get_unix_time_from_system())
		return
	
	var estimated_time := _last_known_server_timestamp + Time.get_unix_time_from_system() - _last_received_server_info_at + ping/2
	
	## For first-time sync and restarting
	if instant:
		ping = unsmoothed_ping
		now = max(now, estimated_time)
		return
		
	ping = lerp(ping, unsmoothed_ping, delta)
	
	if estimated_time - now > 0.1:
		now = estimated_time
	elif estimated_time > now:
		now += delta * 1.03
	elif estimated_time < now:
		now += delta * 0.97


@rpc("any_peer", "call_remote", "unreliable")
func _send_time_request(timestamp: float):
	assert(multiplayer.is_server())
	_send_time_info.rpc_id(multiplayer.get_remote_sender_id(), timestamp, Time.get_unix_time_from_system())


@rpc("authority", "call_remote", "unreliable")
func _send_time_info(timestamp: float, server_timestamp: float):
	assert(!multiplayer.is_server())
	
	# Unreliable rpc - packet and order loss are expected.
	if _last_known_server_timestamp > server_timestamp: return
	
	unsmoothed_ping = Time.get_unix_time_from_system() - timestamp
	
	_last_known_server_timestamp = server_timestamp
	_last_received_server_info_at = Time.get_unix_time_from_system()


@rpc("any_peer", "call_remote", "reliable")
func _send_time_request_reliable(timestamp: float):
	assert(multiplayer.is_server())
	_send_time_info_reliable.rpc_id(multiplayer.get_remote_sender_id(), timestamp, Time.get_unix_time_from_system())

	

@rpc("any_peer", "call_remote", "reliable")
func _send_time_info_reliable(timestamp: float, server_timestamp: float):
	_send_time_info(timestamp, server_timestamp)
	_update_clock(0, true)
