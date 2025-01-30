extends CharacterBody3D
class_name Mercenary

const SATCHEL_CAST_HEIGHT = 1.2
const STANDING_HEIGHT = 1.75
const CROUCHING_HEIGHT = 1.0

var is_grounded := false

# Client owned
@export var look_pitch: float
@export var look_yaw: float
@export var trying_to_use := false

@export var crouchness: float :
	set(v):
		crouchness = v
		
		var height := CROUCHING_HEIGHT if v == 1 else STANDING_HEIGHT
		$Collider.shape.height = height
		$Collider.position.y = height/2


# @UGLY: Because Godot can't just network this??
@export var transform_mirror: Transform3D :
	set(v):
		global_transform = v
	get(): return global_transform
	
@export var velocity_mirror: Vector3 :
	set(v):
		velocity = v
	get(): return velocity

# Serverside
@export var right_hand_item_name: String
@export var left_hand_item_name: String

# Serverside
@export var satchel_name := ""
var saved_items_in_satchel := [["res://scenes/arming_sword.tscn", Transform3D(Vector3(0.481379, -0.05948, -0.874492), Vector3(-0.84991, 0.21226, -0.482284), Vector3(0.214306, 0.975401, 0.051625), Vector3(0.119419, 0.171125, 0.08344))]]
var is_taking_satchel := false


var right_throw_power := 0.0
var left_throw_power := 0.0


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


func _enter_tree() -> void:
	var peer_id := int(name)
	set_multiplayer_authority(peer_id)
	$ServerSynchronizer.set_multiplayer_authority(1)


func _ready() -> void:
	crouchness = 0
	if !is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and G.mouse_unlockers.is_empty():
		look_pitch = fmod(look_pitch - event.relative.x * Settings.look_sensitivity * 0.01, PI*2)
		look_yaw = clamp(look_yaw - event.relative.y * Settings.look_sensitivity * 0.01, -PI/2, PI/2)


func take_satchel():
	if is_taking_satchel: return
	
	var satchel := $/root/world/Items.get_node(satchel_name)
	
	var height_diff: float = satchel.global_position.y - global_position.y
	if height_diff < -0.1 or height_diff > SATCHEL_CAST_HEIGHT+0.1: return
	
	var horizontal_diff: Vector3 = (satchel.global_position - global_position) * Vector3(1, 0, 1)
	if horizontal_diff.length() > 1: return
	is_taking_satchel = true
	
	satchel.do_closing_effects.rpc()
	
	var area: Area3D = satchel.get_node("Area3D")
	for item in area.get_overlapping_bodies():
		assert(item.get_parent() == $/root/world/Items)
		
		var transform_relative_to_satchel: Transform3D = satchel.global_transform.inverse() * item.global_transform
		saved_items_in_satchel.append([item.scene_file_path, transform_relative_to_satchel])
		item.free()
	
	await satchel.outro_finished
	
	print(saved_items_in_satchel)
	
	satchel.queue_free()
	satchel_name = ""
	is_taking_satchel = false


@rpc("authority", "call_local")
func drop_item(is_right_hand: bool, throw_power: float):
	assert(multiplayer.is_server())
	
	var item: RigidBody3D = $/root/world/Items.get_node_or_null(right_hand_item_name if is_right_hand else left_hand_item_name)
	if !item: return
	
	if is_right_hand:
		right_hand_item_name = ""
	else:
		left_hand_item_name = ""
	
	item.holder_info = ["", true]
	
	item.linear_velocity = velocity - $HeadAttachment/Viewpoint.global_basis.z * throw_power * 10
	item.angular_velocity = -item.global_basis.x * throw_power * 20


@rpc("authority", "call_local")
func throw_effects(right_hand: bool, power: float):
	if power < 0.2: return
	power = remap(power, 0.2, 1, 0, 0.8)
	
	if right_hand:
		$RightHandAttachment/Throw.volume_linear = power
		$RightHandAttachment/Throw.play()
	else:
		$LeftHandAttachment/Throw.volume_linear = power
		$LeftHandAttachment/Throw.play()


@rpc("authority", "call_local")
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
	
	satchel = preload("res://scenes/placed_satchel.tscn").instantiate()
	$/root/world/Items.add_child(satchel, true)
	
	satchel_name = satchel.name
	
	var pos := shapecast.global_position + shapecast.target_position * shapecast.get_closest_collision_unsafe_fraction()
	pos.y -= 0.1
	
	satchel.global_transform = Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch + PI).translated(pos)
	
	for data in saved_items_in_satchel:
		var node: Node3D = load(data[0]).instantiate()
		$/root/world/Items.add_child(node, true)
		
		var trans: Transform3D = satchel.global_transform * data[1]
		node.global_transform = trans
		node.reset_physics_interpolation()
	
	saved_items_in_satchel.clear()


func use() -> void:
	assert(multiplayer.is_server())
	
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
	
	if right_hand_free:
		right_hand_item_name = item.name
		item.holder_info = [self.name, true]
		take_item_effects.rpc(true)
	else:
		left_hand_item_name = item.name
		item.holder_info = [self.name, false]
		take_item_effects.rpc(false)


@rpc("any_peer", "call_local")
func take_item_effects(right_hand: bool):
	assert(multiplayer.get_remote_sender_id() == 1)
	
	if right_hand:
		$RightHandAttachment/Take.play()
	else:
		$LeftHandAttachment/Take.play()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if trying_to_use:
			use()
	
	if !is_multiplayer_authority(): return
	
	trying_to_use = G.mouse_unlockers.is_empty() and Input.is_action_pressed("use")
	
	if Input.is_action_pressed("drop") and G.mouse_unlockers.is_empty():
		if Input.is_action_pressed("left_action"):
			left_throw_power = min(1, left_throw_power + delta)
		elif left_throw_power > 0:
			drop_item.rpc_id(1, false, left_throw_power)
			throw_effects.rpc(false, left_throw_power)
			left_throw_power = 0
		
		if Input.is_action_pressed("right_action"):
			right_throw_power = min(1, right_throw_power + delta)
		elif right_throw_power > 0:
			drop_item.rpc_id(1, true, right_throw_power)
			throw_effects.rpc(true, right_throw_power)
			right_throw_power = 0
	else:
		right_throw_power = 0
		left_throw_power = 0
	
	if Input.is_action_just_pressed("place_satchel"):
		place_satchel.rpc_id(1)
	
	if Input.is_action_pressed("crouch"):
		crouchness = move_toward(crouchness, 1.0, delta * 5)
	elif can_uncrouch():
		crouchness = move_toward(crouchness, 0.0, delta * 5)
	
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch)
	
	var move_input: Vector2 = Input.get_vector("right", "left", "back", "forward")
	var move_direction := Vector3(move_input.x, 0, move_input.y).normalized()
	move_direction = horizontal_look * move_direction
	
	is_grounded = is_on_floor()
	
	if is_grounded:
		var max_speed := 1 if crouchness != 0 else 2
		
		_apply_friction(5 * delta)
		_accelerate(move_direction, 10 * delta, max_speed)
	else:
		velocity += get_gravity() * delta
	
	move_and_slide()


func can_uncrouch() -> bool:
	# Hack to set collider size back to full
	var current_crouchness := crouchness
	crouchness = 0
	
	var hit := test_move(global_transform, Vector3.ZERO)
	crouchness = current_crouchness
	
	return !hit


func play_footstep() -> void:
	if !is_grounded: return
	
	$Footsteps.volume_linear = remap(velocity.length(), 0, 2, 0, 0.5)
	$Footsteps.play()


func evaluate_animations():
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
	$Interpolator.apply()
	evaluate_animations()
	
	$BackAttachment/Satchel.visible = satchel_name == ""
	
	if !is_multiplayer_authority(): return
	
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
