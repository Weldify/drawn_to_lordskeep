extends RigidBody3D
class_name Item

@export var holdtype := G.HoldType.WEAPON

var holder_name: String
var is_in_right_hand := true

func _ready() -> void:
	set_multiplayer_authority(1)
	$StateSynchronizer.process_settings()
	
	NetworkTime.on_tick.connect(_tick)
	
	# Only item layer
	collision_layer = 0
	set_collision_layer_value(3, true)
	
	#if !multiplayer.is_server():
		#freeze = true


func _tick(delta: float, tick: int) -> void:
	if $/root/world/Mercenaries.get_node_or_null(holder_name):
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		set_collision_layer_value(3, false)
	else:
		set_collision_layer_value(3, true)
		
		if physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
			physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
			reset_physics_interpolation()
		


func _process(delta: float) -> void:
	var holder: CharacterBody3D = $/root/world/Mercenaries.get_node_or_null(holder_name)
	if !is_instance_valid(holder): return
	
	var attachment: BoneAttachment3D = holder.get_node("RightHandAttachment" if is_in_right_hand else "LeftHandAttachment")
	attachment.on_skeleton_update()
	
	var offset: Transform3D = $HandleOffset.transform
	if !is_in_right_hand:
		offset = offset.rotated_local(Vector3.RIGHT, PI)
	
	global_transform = attachment.global_transform * offset
