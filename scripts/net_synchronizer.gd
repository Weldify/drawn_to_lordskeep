extends Node
class_name NetSynchronizer


# @NOTE: Using non DELAYED properties with Interpolator looks broken,
# but it's actually just unsupported. Keep that in mind!

# @NOTE: You MUST call configure() after changing the authority of this node!
# @NOTE: configure() MUST be called at the same time on all peers!

# @NOTE: Make sure to update your networked properties during .on_tick instead of _physics_process
# Otherwise you might delay replication by 1 tick.

@export var networked_properties: Array[StringName]


## If you're doing interpolation and call this,
## the properties will snap to the correct values when the first snapshot is received,
## instead of "floating" toward them from default values.
signal reset_your_interpolation()

const _DELAYED_SNAPSHOTS_NEEDED_FOR_APPLYING := 2

## If there are more than this amount of  snapshots in the delayed queue, process all of them.
const _TOO_MANY_DELAYED_SNAPSHOTS := 3

class PropertyInfo:
	var path: NodePath
	var reliable := true
	var delayed := false


class DelayedSnapshot:
	var tick: int
	var changes: Array


var _root: Node
var _properties: Array[PropertyInfo]
var _should_send_full_snapshot := false
var _last_state: Array

var _last_tick := 0
var _delayed_snapshots: Array[DelayedSnapshot]
var _applied_at_least_one_delayed_snapshot := false


func snap(property: NodePath, value):
	# So that you can run this in shared code without thinking!
	if is_multiplayer_authority(): return
	
	var property_index := -1
	for i in _properties.size():
		if _properties[i].path == property:
			property_index = i
			break
	
	assert(property_index != -1)
	
	for snapshot in _delayed_snapshots:
		for change_index in snapshot.changes.size():
			var change: Array = snapshot.changes[change_index]
			var prop_index = change[0]
			if prop_index == property_index:
				snapshot.changes.remove_at(change_index)
				break
	
	_set_value(property, value)


func configure():
	_root = get_parent()
	_last_tick = 0
	_should_send_full_snapshot = true
	_last_state.clear()
	_properties.clear()
	
	for info in networked_properties:
		var args := info.split(" ")
		var path := NodePath(args[0])
		
		var property := PropertyInfo.new()
		property.path = NodePath(args[0])
		
		args.remove_at(0) # Index 0 is path, everything else is args
		for arg in args:
			if arg == "UNRELIABLE":
				property.reliable = false
			elif arg == "DELAYED":
				property.delayed = true
			else: assert(false, "What the fuck did you give me?")
		
		_properties.append(property)
		_last_state.append(_get_value(property.path))


func _ready():
	Net.before_tick.connect(_before_tick)
	Net.after_tick.connect(_after_tick)
	
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(_peer: int):
	## For simplicity's sake, we only keep deltas globally, not per peer.
	_should_send_full_snapshot = true


func _before_tick():
	if !is_multiplayer_authority(): 
		_apply_delayed_changes()


func _apply_delayed_changes():
	if _delayed_snapshots.size() < _DELAYED_SNAPSHOTS_NEEDED_FOR_APPLYING: return

	var ticks_to_process := 1
	
	## We received too many ticks, so we probably lagged out?
	## Process all the etxra ones.
	if _delayed_snapshots.size() > _TOO_MANY_DELAYED_SNAPSHOTS: 
		push_warning("Received too many snapshots. Processing all extra ones.")
		ticks_to_process = _delayed_snapshots.size()

	for i in ticks_to_process:
		var snapshot: DelayedSnapshot = _delayed_snapshots.pop_front()
		_last_tick = snapshot.tick
		
		
		for change in snapshot.changes:
			var index: int = change[0]
			var value = change[1]
			
			var info := _properties[index]
			_set_value(info.path, value)
	
	_applied_at_least_one_delayed_snapshot = true


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
	
	_send_snapshot.rpc(_last_tick, reliable_changes)
	if !unreliable_changes.is_empty(): _send_unreliable_extra.rpc(_last_tick, unreliable_changes)

	_should_send_full_snapshot = false


# Multiple changes received for the same tick are added together
# that way we can send unreliable changes separately to the main snapshot!
func _receive_changes(tick: int, changes: Array[Array]):
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		push_warning("Ignoring property snapshot from non-authority.")
		return
	
	## On the receiving end, _last_tick refers to the last ALREADY applied tick,
	## so this information is irrelevant to us.
	if tick <= _last_tick: return
	
	var snapshot: DelayedSnapshot
	var insertion_index := 0
	
	for i in _delayed_snapshots.size():
		var pending := _delayed_snapshots[i]
		
		if pending.tick == tick:
			snapshot = pending
			break
		elif pending.tick < tick:
			## This is only used when the current tick doesn't exist,
			## So there is effectively a missing tick at this index.
			## We use this to insert ticks in chronological order.
			insertion_index = i + 1
	
	if !snapshot:
		snapshot = DelayedSnapshot.new()
		snapshot.tick = tick
		_delayed_snapshots.insert(insertion_index, snapshot)
	
	for change in changes:
		var property_index: int = change[0]
		var info := _properties[property_index]
		
		# @NOTE: _last_tick == 0 means this is the first snapshot we are receiving,
		# we don't delay it because otherwise the properties will be stuck with default
		# values until it is processed, which is worse than being stuck with relevant values.
		if info.delayed and _last_tick != 0:
			snapshot.changes.append(change)
		else:
			_set_value(info.path, change[1])
	
	# These changes are for the first snapshot, either from the
	# reliable rpc or unreliable extra, we want to reset interpolation
	# regardless since these are meant to arrive more or less at the same time.
	if _last_tick == 0 and !_applied_at_least_one_delayed_snapshot:
		reset_your_interpolation.emit()


func _get_value(path: NodePath):
	var node := _root.get_node(path)
	return node.get_indexed(path.get_as_property_path())


func _set_value(path: NodePath, value):
	var node := _root.get_node(path)
	node.set_indexed(path.get_as_property_path(), value)


@rpc("authority", "call_remote", "reliable")
func _send_snapshot(tick: int, changes: Array[Array]): 
	_receive_changes(tick, changes)


@rpc("authority", "call_remote", "unreliable")
func _send_unreliable_extra(tick: int, changes: Array[Array]): 
	_receive_changes(tick, changes)
