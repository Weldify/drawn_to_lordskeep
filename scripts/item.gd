extends RigidBody3D
class_name Item

## Careful because this signal doesn't guarantee .is_in_right_hand is set properly
signal holder_changed()

@export var holdtype := G.HoldType.WEAPON

@export var transform_mirror: Transform3D :
	set(v):
		global_transform = v
	get(): return global_transform

var holder_name: String : 
	get(): return holder_info[0]

var is_in_right_hand: bool : 
	get(): return holder_info[1]
	
var last_recorded_speed: float

@export var spin_speed: float :
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
@export var holder_info: Array = ["", true] :
	set(v):
		if holder_info == v: return
		holder_info = v
		holder_changed.emit()
	get(): return holder_info


func _ready() -> void:
	assert(get_parent() == $/root/world/Items, "DO NOT SPAWN ITEMS OUTSIDE OF ITEMS IDIOT!")
	
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
	spin_speed = 0 if holder_name != "" or sleeping else abs((quaternion.inverse() * angular_velocity).x)


func _physics_process(delta: float) -> void:
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


func _process(delta: float) -> void:
	var holder: CharacterBody3D = $/root/world/Mercenaries.get_node_or_null(holder_name)
	if !is_instance_valid(holder): return
	
	var attachment: BoneAttachment3D = holder.get_node("RightHandAttachment" if is_in_right_hand else "LeftHandAttachment")
	attachment.on_skeleton_update()
	
	var offset: Transform3D = $HandleOffset.transform
	if !is_in_right_hand:
		offset = offset.rotated_local(-Vector3.RIGHT, PI).rotated_local(Vector3.UP, PI)
	
	global_transform = attachment.global_transform * offset
