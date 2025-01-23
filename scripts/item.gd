extends RigidBody3D
class_name Item

@export var holdtype := G.HoldType.WEAPON

@export var transform_mirror: Transform3D :
	set(v):
		global_transform = v
	get(): return global_transform

@export var holder_name: String
@export var is_in_right_hand := true

func _ready() -> void:
	assert(get_parent() == $/root/world/Items, "DO NOT SPAWN ITEMS OUTSIDE OF ITEMS IDIOT!")
	
	# Only item layer
	collision_layer = 0
	set_collision_layer_value(3, true)
	
	if !multiplayer.is_server():
		freeze = true


func _physics_process(delta: float) -> void:
	if $/root/world/Mercenaries.get_node_or_null(holder_name):
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
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
