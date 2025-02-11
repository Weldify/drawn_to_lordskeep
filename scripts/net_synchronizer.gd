extends Node
class_name NetSynchronizer


@export var networked_properties: Array[StringName] 


const _SNAPSHOT_DELAY_TICKS = 2


class PropertyInfo:
	var path: NodePath
	var reliable: bool


class PendingSnapshot:
	var tick: int
	var changes: Array


var _root: Node
var _properties: Array[PropertyInfo]
var _should_send_full_snapshot := false
var _last_state: Array

var _last_tick := 0
var _pending_snapshots: Array[PendingSnapshot]

func configure():
	_last_tick = 0
	_should_send_full_snapshot = true
	_last_state.clear()
	_properties.clear()
	
	for info in networked_properties:
		var args := info.split(" ")
		var path := NodePath(args[0])
		
		var property := PropertyInfo.new()
		property.path = NodePath(args[0])
		property.reliable = args.size() < 2 or args[1] != "UNRELIABLE"
		
		_properties.append(property)
		_last_state.append(_get_value(property.path))


func _ready():
	_root = get_parent()
	NetworkTime.before_tick.connect(_before_tick)
	NetworkTime.after_tick.connect(_after_tick)
	
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(_peer: int):
	## For simplicity's sake, we only keep deltas globally, not per peer.
	_should_send_full_snapshot = true
	print("Connected ", _peer, " we ", multiplayer.multiplayer_peer.get_unique_id())


func _before_tick():
	if is_multiplayer_authority(): return
	
	var extra_snapshots := _pending_snapshots.size() - _SNAPSHOT_DELAY_TICKS
	if extra_snapshots < 1: return

	var ticks_to_process = 1
	
	## We received too many ticks, so we probably lagged out?
	## Process all the etxra ones.
	if extra_snapshots > _SNAPSHOT_DELAY_TICKS: ticks_to_process = _SNAPSHOT_DELAY_TICKS

	for i in ticks_to_process:
		var snapshot: PendingSnapshot = _pending_snapshots.pop_front()
		_last_tick = snapshot.tick
		
		
		for change in snapshot.changes:
			var index: int = change[0]
			var value = change[1]
			
			var info := _properties[index]
			_set_value(info.path, value)


func _after_tick():
	if !is_multiplayer_authority(): return
	
	var reliable_changes: Array[Array]
	var unreliable_changes: Array[Array]
	
	for i in _properties.size():
		var info := _properties[i]
		
		var value = _get_value(info.path)
		
		if !_should_send_full_snapshot and value == _last_state[i]: continue
		_last_state[i] = value
		
		if info.reliable:
			reliable_changes.append([i, value])
		else:
			unreliable_changes.append([i, value])
	
	_last_tick += 1
	
	if !reliable_changes.is_empty(): _send_changes_reliable.rpc(_last_tick, reliable_changes)
	if !unreliable_changes.is_empty(): _send_changes_unreliable.rpc(_last_tick, unreliable_changes)

	_should_send_full_snapshot = false


func _receive_changes(tick: int, changes: Array[Array]):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		push_warning("Ignoring property snapshot from non-authority.")
		return
	
	## On the receiving end, _last_tick refers to the last ALREADY applied tick,
	## so this information is irrelevant to us.
	if tick <= _last_tick: return
	
	var snapshot: PendingSnapshot
	var insertion_index := 0
	
	for i in _pending_snapshots.size():
		var pending := _pending_snapshots[i]
		
		if pending.tick == tick:
			snapshot = pending
			break
		elif pending.tick < tick:
			## This is only used when the current tick doesn't exist,
			## So there is effectively a missing tick at this index.
			## We use this to insert ticks in chronological order.
			insertion_index = i + 1
	
	if !snapshot:
		snapshot = PendingSnapshot.new()
		snapshot.tick = tick
		_pending_snapshots.insert(insertion_index, snapshot)
	
	## Combines changes from unreliable and reliable rpcs.
	snapshot.changes.append_array(changes)


func _get_value(path: NodePath):
	var node := _root.get_node(path)
	return node.get_indexed(path.get_as_property_path())


func _set_value(path: NodePath, value):
	var node := _root.get_node(path)
	node.set_indexed(path.get_as_property_path(), value)


@rpc("authority", "call_remote", "reliable")
func _send_changes_reliable(tick: int, changes: Array[Array]): 
	_receive_changes(tick, changes)


@rpc("authority", "call_remote", "unreliable")
func _send_changes_unreliable(tick: int, changes: Array[Array]): 
	_receive_changes(tick, changes)
