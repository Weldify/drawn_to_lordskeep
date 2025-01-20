extends CharacterBody3D


var crouchness := 0.0
var is_grounded := false

## Non-owners use this for interpolating the look direction!
var recorded_look_pitch: float
var recorded_look_yaw: float

var right_hand_item_name: String
var left_hand_item_name: String


func get_right_holdtype() -> G.HoldType:
	var item := $/root/world/Items.get_node_or_null(right_hand_item_name)
	return item.holdtype if item else G.HoldType.NONE


func get_left_holdtype() -> G.HoldType:
	var item := $/root/world/Items.get_node_or_null(left_hand_item_name)
	return item.holdtype if item else G.HoldType.NONE


func is_left_holdtype_weapon() -> bool:
	return get_left_holdtype() == G.HoldType.WEAPON


func is_right_holdtype_weapon() -> bool:
	return get_right_holdtype() == G.HoldType.WEAPON


func _ready() -> void:
	var peer_id := int(name)
	set_multiplayer_authority(1)
	$Input.set_multiplayer_authority(peer_id)
	
	$RollbackSynchronizer.process_settings()
	$StateSynchronizer.process_settings()
	
	if !$Input.is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Needs to be done before checking is_on_floor() in rollback tick.
func _force_update_is_on_floor() -> void:
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity


func simulate_drop() -> void:
	if !multiplayer.is_server() or !$Input.drop: return
	
	var left_item := $/root/world/Items.get_node_or_null(left_hand_item_name)
	if left_item and $Input.primary:
		left_hand_item_name = ""
		left_item.holder_name = ""
		left_item.linear_velocity = velocity
		left_item.angular_velocity = Vector3.ZERO
		return
	
	var right_item := $/root/world/Items.get_node_or_null(right_hand_item_name)
	if right_item and $Input.secondary:
		right_hand_item_name = ""
		right_item.holder_name = ""
		right_item.linear_velocity = velocity
		right_item.angular_velocity = Vector3.ZERO
		return


func simulate_use() -> void:
	# Physics related stuff kinda sux, so it's no use.
	if !multiplayer.is_server() or !$Input.use: return
	
	var viewpoint: Node3D = $HeadAttachment/Viewpoint
	
	var state := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(viewpoint.global_position, viewpoint.global_position - viewpoint.global_basis.z)
	params.exclude = [get_rid()]
	var result := state.intersect_ray(params)
	if result.is_empty(): return
	
	print(result.collider)
	if !result.collider is Item: return
	assert(result.collider.get_parent() == $/root/world/Items)
	
	var holder := $/root/world/Mercenaries.get_node_or_null(result.collider.holder_name)
	if holder: return
	
	var right_hand_free := $/root/world/Items.get_node_or_null(right_hand_item_name) == null
	var left_hand_free := $/root/world/Items.get_node_or_null(left_hand_item_name) == null
	if !right_hand_free and !left_hand_free: return
	
	result.collider.holder_name = self.name
	
	if right_hand_free:
		right_hand_item_name = result.collider.name
		result.collider.is_in_right_hand = true
	else:
		left_hand_item_name = result.collider.name
		result.collider.is_in_right_hand = false


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	simulate_drop()
	simulate_use()
	
	if $Input.crouch:
		crouchness = move_toward(crouchness, 1.0, delta * 5)
	else:
		crouchness = move_toward(crouchness, 0.0, delta * 5)
	
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, $Input.look_pitch)
	
	var move_input: Vector2 = $Input.move
	var move_direction := Vector3(move_input.x, 0, move_input.y).normalized()
	move_direction = horizontal_look * move_direction
	
	_force_update_is_on_floor()
	is_grounded = is_on_floor()
	
	if is_grounded:
		var max_speed := 1 if crouchness != 0 else 2
		
		_apply_friction(5 * delta)
		_accelerate(move_direction, 10 * delta, max_speed)
	else:
		velocity += get_gravity() * delta
	
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
	recorded_look_pitch = $Input.look_pitch
	recorded_look_yaw = $Input.look_yaw


func play_footstep() -> void:
	if !is_grounded: return
	$Footsteps.volume_linear = remap(velocity.length(), 0, 2, 0, 0.5)
	$Footsteps.play()

func _process(delta: float) -> void:
	var look_yaw := recorded_look_yaw
	var look_pitch := recorded_look_pitch
	if $Input.is_multiplayer_authority():
		look_yaw = $Input.look_yaw
		look_pitch = $Input.look_pitch
	
	$AnimationTree.set("parameters/look_alpha/blend_position", remap(look_yaw, -PI/2, PI/2, -1, 1))
	
	var speed := velocity.length()
	$AnimationTree.set("parameters/speed (crouching)/blend_position", speed)
	$AnimationTree.set("parameters/speed (standing)/blend_position", speed)
	$AnimationTree.set("parameters/speed (movement multiplier)/scale", speed)
	
	$AnimationTree.set("parameters/crouchness/blend_amount", crouchness)

	$Model.transform = Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch)
	# Otherwise it will be out of sync due to us changing the transform.
	$HeadAttachment.on_skeleton_update()
	
	if !$Input.is_multiplayer_authority(): return
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var camera := get_viewport().get_camera_3d()
	camera.global_transform = $HeadAttachment/Viewpoint.global_transform


func _accelerate(direction: Vector3, acceleration: float, max_speed: float):
	var projected_speed := velocity.dot(direction)
	velocity += direction * clamp(max_speed - projected_speed, 0, acceleration)


func _apply_friction(amount: float):
	var speed := velocity.length()
	if speed == 0: return
	var drop := speed * amount
	
	velocity *= max(0, speed - drop) / speed
