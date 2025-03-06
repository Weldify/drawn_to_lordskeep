extends RigidBody3D
class_name Item

## Careful because this signal doesn't guarantee .is_in_right_hand is set properly
signal holder_changed()

@export var holdtype := G.HoldType.WEAPON
@export var spin_axis := Vector3.LEFT

var holder_name: String : 
	get(): return holder_info[0]

var is_in_right_hand: bool : 
	get(): return holder_info[1]
	
var last_recorded_speed: float

var spin_speed: float :
	set(v):
		if v == spin_speed: return
		spin_speed = v
		
		var should_be_playing := spin_speed > 0.1
		if $Spin.playing != should_be_playing:
			$Spin.playing = should_be_playing
		
		$Spin.pitch_scale = max(0.01, remap(v, 0, 20, 0, 1.5))
	get(): return spin_speed


## Think of this as storing .holder_name and .is_in_right_hand in one variable.
## We have to do this so that they get networked at the same time.
## Also, this is a reference type, so please construct it from scratch
## every time you change it, otherwise the synchronizer won't pick up the change.
var holder_info: Array = ["", true] :
	set(v):
		if holder_info == v: return
		holder_info = v
		holder_changed.emit()
	get(): return holder_info


func _ready() -> void:
	assert(get_parent() == $/root/world/Items, "DO NOT SPAWN ITEMS OUTSIDE OF ITEMS IDIOT!")
	
	Net.on_tick.connect(_on_tick)
	$NetSynchronizer.configure()
	
	holder_changed.connect(_on_holder_changed)
	_on_holder_changed()
	
	# Only item layer
	collision_layer = 0
	set_collision_layer_value(3, true)


func _on_holder_changed():
	var holder := $/root/world/Mercenaries.get_node_or_null(holder_name)
	if holder:
		freeze = true
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		set_collision_layer_value(3, false)
	else:
		freeze = !multiplayer.is_server()
		set_collision_layer_value(3, true)
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		
		reset_physics_interpolation()
	
	if multiplayer.is_server():
		_recalculate_spin_speed()


func _recalculate_spin_speed():
	if holder_name != "" or sleeping:
		spin_speed = 0
		return
	
	var local_angular_velocity := quaternion.inverse() * angular_velocity
	spin_speed = (local_angular_velocity * spin_axis).length()


func _on_tick(_delta: float) -> void:
	if !multiplayer.is_server(): return
	
	_recalculate_spin_speed()
	
	if freeze or sleeping: return
	
	var speed := linear_velocity.length()
	var speed_diff := last_recorded_speed - speed
	if speed_diff > 1 and get_contact_count() > 0:
		play_collision_sound.rpc(remap(speed_diff, 1, 7, 0.01, 0.3))
		
	last_recorded_speed = speed


@rpc("authority", "call_local")
func play_collision_sound(volume: float):
	$Collision.volume_linear = volume
	$Collision.position = center_of_mass
	$Collision.play()


func _process(_delta: float) -> void:
	transform_to_holder_if_valid()


# @NOTE:
# Item :transform networking is DELAYED so we can interpolate it properly.
# However, the synchronizer never changes its authority, meaning it is 
# ALWAYS interpolated.
# Some items, like weapons, rely on the transform being up to date for their logic.
# For these items, you can call this function in .on_tick so that the item is actually
# properly positioned in your hand!
## TL;DR call this in .on_tick if you plan on using :transform in any way.
func transform_to_holder_if_valid():
	var holder: CharacterBody3D = $/root/world/Mercenaries.get_node_or_null(holder_name)
	if !is_instance_valid(holder): return
	
	var attachment: BoneAttachment3D = holder.get_node("RHandAttachment" if is_in_right_hand else "LHandAttachment")
	attachment.on_skeleton_update()
	
	var offset: Transform3D = ($RightHoldOffset if is_in_right_hand else $LeftHoldOffset).transform.inverse()
	global_transform = attachment.global_transform * offset
