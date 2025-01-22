extends CharacterBody3D


const SATCHEL_CAST_HEIGHT = 1.2


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


func tick_drop() -> void:
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


var saved_items_in_satchel: Array
var satchel_name := ""
var is_taking_satchel := false

func take_satchel():
	if is_taking_satchel: return
	
	var satchel := $/root/world/Items.get_node(satchel_name)
	
	var height_diff: float = satchel.global_position.y - global_position.y
	if height_diff < -0.1 or height_diff > SATCHEL_CAST_HEIGHT+0.1: return
	
	var horizontal_diff: Vector3 = (satchel.global_position - global_position) * Vector3(1, 0, 1)
	if horizontal_diff.length() > 1: return
	is_taking_satchel = true
	
	satchel.is_closing = true
	
	var area: Area3D = satchel.get_node("Area3D")
	for item in area.get_overlapping_bodies():
		assert(item.get_parent() == $/root/world/Items)
		
		var transform_relative_to_satchel: Transform3D = satchel.global_transform.inverse() * item.global_transform
		saved_items_in_satchel.append([item.scene_file_path, transform_relative_to_satchel])
		item.free()
	
	await get_tree().create_timer(0.8).timeout
	
	satchel.free()
	satchel_name = ""
	is_taking_satchel = false
	
	
func place_satchel():
	assert(multiplayer.is_server())
	
	var satchel := $/root/world/Items.get_node_or_null(satchel_name)
	if satchel:
		take_satchel()
		return
	
	# NOTE:
	# Shapecasts in Godot are fucking horrible, whoever was responsible for them
	# should be banned from working on engines until the end of their damn days.
	# (I wanted to use a shapecast here if you couldn't tell)
	var shapecast: ShapeCast3D = $Model/SatchelShapecast
	shapecast.position.y = SATCHEL_CAST_HEIGHT
	
	shapecast.target_position = Vector3.ZERO
	shapecast.force_shapecast_update()
	if shapecast.is_colliding(): return
	
	shapecast.target_position = Vector3(0, -SATCHEL_CAST_HEIGHT, 0)
	shapecast.force_shapecast_update()
	if !shapecast.is_colliding(): return
	
	var collider: PhysicsBody3D = shapecast.get_collider(0)
	
	# Only placeable on nodes that are in the World layer!
	if collider.get_collision_layer_value(1) != true: return
	
	satchel = preload("res://placed_satchel.tscn").instantiate()
	$/root/world/Items.add_child(satchel, true)
	
	satchel_name = satchel.name
	
	var pos := shapecast.global_position + shapecast.target_position * shapecast.get_closest_collision_unsafe_fraction()
	satchel.global_transform = Transform3D.IDENTITY.rotated(Vector3.UP, $Input.look_pitch + PI).translated(pos)
	
	for data in saved_items_in_satchel:
		var node: Node3D = load(data[0]).instantiate()
		$/root/world/Items.add_child(node, true)
		
		var trans: Transform3D = satchel.global_transform * data[1]
		node.global_transform = trans
	
	saved_items_in_satchel.clear()


func tick_use() -> void:
	# Physics related stuff kinda sux, so it's no use.
	if !multiplayer.is_server() or !$Input.use: return
	
	var use_ray: RayCast3D = $HeadAttachment/Viewpoint/UseRay
	use_ray.force_raycast_update()
	
	var item := use_ray.get_collider()
	if !item is Item: return
	assert(item.get_parent() == $/root/world/Items)
	
	var holder := $/root/world/Mercenaries.get_node_or_null(item.holder_name)
	if holder: return
	
	var right_hand_free := $/root/world/Items.get_node_or_null(right_hand_item_name) == null
	var left_hand_free := $/root/world/Items.get_node_or_null(left_hand_item_name) == null
	if !right_hand_free and !left_hand_free: return
	
	item.holder_name = self.name
	
	if right_hand_free:
		right_hand_item_name = item.name
		item.is_in_right_hand = true
	else:
		left_hand_item_name = item.name
		item.is_in_right_hand = false


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	# NOTE: I'm pretty sure this isn't enough to make sure the body
	# ends up in the right place during resimulation...
	_evaluate_animations()
	
	# Effectively, this is the same as running this code in on_tick
	# It's just easier to do this here temporarily!
	if multiplayer.is_server() and is_fresh:
		tick_drop()
		tick_use()
	
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


func _evaluate_animations():
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


func _process(delta: float) -> void:
	_evaluate_animations()
	
	$BackAttachment/Satchel.visible = satchel_name == ""
	
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
