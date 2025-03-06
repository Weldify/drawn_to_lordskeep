extends CharacterBody3D
class_name Mercenary

# @BUG: PITCH AND YAW ARE SWAPPED. IM stupid. Let's change this sometime!

const SATCHEL_CAST_HEIGHT = 1.2
const STANDING_HEIGHT = 1.75
const CROUCHING_HEIGHT = 1.0

var is_grounded := false

# Client owned
var look_pitch: float
var look_yaw: float
var trying_to_use := false

var crouchness: float :
	set(v):
		crouchness = v
		
		var height := CROUCHING_HEIGHT if v == 1 else STANDING_HEIGHT
		$Collider.shape.height = height
		$Collider.position.y = height/2


# Serverside
var grab_point_path: NodePath :
	set(v):
		if grab_point_path == v: return
		grab_point_path = v
		
		if !v:
			var pos: Vector3 = $Model.global_position
			position = pos
			$Interpolator.snap(":position", pos)
			$ClientSynchronizer.snap(":position", pos)
			
			if _grab_throw_after_finish: _try_apply_grab_throw(_grab_throw_velocity, _grab_throw_pitch)


var right_hand_item_name: String
var left_hand_item_name: String
var satchel_name := ""
var health := 1.0

var saved_items_in_satchel := [
	["res://scenes/arming_sword.tscn", Transform3D(
		Vector3(0.481379, -0.05948, -0.874492), 
		Vector3(-0.84991, 0.21226, -0.482284), 
		Vector3(0.214306, 0.975401, 0.051625), 
		Vector3(0.119419, 0.171125, 0.08344))
	],
	
	["res://scenes/multiplayer_horn.tscn", Transform3D(
		Vector3(0.003882, -0.999797, -0.019781), 
		Vector3(0.16124, 0.020148, -0.986709), 
		Vector3(0.986907, 0.000641, 0.161286), 
		Vector3(-0.027571, 0.05907, -0.03157))
	]
]

var is_taking_satchel := false


var right_throw_power := 0.0
var left_throw_power := 0.0


func handle_hit(weapon, pos: Vector3, normal: Vector3):
	G.flesh_hit_effects(weapon.blunt, pos, normal)


func _enter_tree() -> void:
	var peer_id := int(name)
	set_multiplayer_authority(peer_id, false)
	
	$ServerSynchronizer.configure()
	
	$ClientSynchronizer.set_multiplayer_authority(peer_id)
	$ClientSynchronizer.configure()
	
	if is_multiplayer_authority():
		$Interpolator.active = true
	else:
		$Interpolator.properties.append(":look_pitch ANGLE")
		$Interpolator.properties.append(":look_yaw ANGLE")
		$Interpolator.reconfigure()
		$ClientSynchronizer.reset_your_interpolation.connect($Interpolator.restart)


func _ready() -> void:
	$AnimationTree.callback_mode_process = AnimationTree.ANIMATION_PROCESS_MANUAL
	process_priority = G.MERCENARY_PROCESS_PRIORITY
	
	Net.on_tick.connect(_on_tick)
	
	if !is_multiplayer_authority(): return
	crouchness = 0
	
	global_position = Vector3(0, 4, 0)
	G.my_mercenary = self
	G.viewer_mercenary = self


func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	
	if event is not InputEventMouseMotion: return 
	if !G.mouse_unlockers.is_empty() or health <= 0: return
	
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
	
	item.linear_velocity = velocity - $HeadAttachment/Eyes.global_basis.z * throw_power * 10
	item.angular_velocity = item.quaternion * item.spin_axis * throw_power * 20


@rpc("authority", "call_local")
func throw_effects(right_hand: bool, power: float):
	if power < 0.2: return
	power = remap(power, 0.2, 1, 0, 0.8)
	
	if right_hand:
		$RHandAttachment/Throw.volume_linear = power
		$RHandAttachment/Throw.play()
	else:
		$LHandAttachment/Throw.volume_linear = power
		$LHandAttachment/Throw.play()


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
	
	var use_ray: RayCast3D = $HeadAttachment/Eyes/UseRay
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
		$RHandAttachment/Take.play()
	else:
		$LHandAttachment/Take.play()


var mantle_goal: Vector3
var is_mantling := false
var mantle_started_at: float
func try_mantle():
	if is_mantling: return
	is_mantling = true
	mantle_started_at = Net.now
	
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch)
	mantle_goal = global_position + horizontal_look * Vector3.MODEL_FRONT * 0.5 + Vector3.UP * 1
	
	mantle_effects.rpc()


@rpc("authority", "call_local", "unreliable")
func mantle_effects():
	var playback: AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/playback")
	playback.travel("mantle_medium")


@rpc("authority", "call_local", "unreliable")
func mantle_stop_effects():
	position = $Model.global_position
	$Interpolator.snap(":position", position)
	$ClientSynchronizer.snap(":position", position)


func _on_tick(delta: float) -> void:
	if multiplayer.is_server():
		if trying_to_use:
			use()
	
	if !is_multiplayer_authority(): return
	
	trying_to_use = G.mouse_unlockers.is_empty() and Input.is_action_pressed("use")
	
	if Input.is_action_just_pressed("mobility"):
		try_mantle()
	
	## @NOTE @IMPORTANT: For animations where rootmotion matters, make sure
	## that no rootmotion is applied while it is blending!!!
	## The root motion won't be fully applied otherwise!!
	
	## @NOTE: The timing here is hardcoded to match
	## With the end pose of the root bone which affects root motion
	if is_mantling and Net.now - mantle_started_at > 1.2667:
		is_mantling = false
		mantle_stop_effects.rpc()
	
	
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
	
	_do_movement(delta)


var _grab_throw_after_finish := false
var _grab_throw_velocity: Vector3
var _grab_throw_pitch: float

@rpc("any_peer", "call_local", "unreliable")
func grab_throw(power: Vector3, pitch: float):
	if multiplayer.get_remote_sender_id() != 1: return
	_try_apply_grab_throw(power, pitch)


func _try_apply_grab_throw(power: Vector3, pitch: float):
	print("Jaking it ")
	var grab_point := get_node_or_null(grab_point_path)
	if grab_point:
		_grab_throw_after_finish = true
		_grab_throw_velocity = power
		_grab_throw_pitch = pitch
		return
	
	_grab_throw_after_finish = false
	
	look_pitch = pitch
	$ClientSynchronizer.snap(":look_pitch", look_pitch)
	if !is_multiplayer_authority(): $Interpolator.snap(":look_pitch", look_pitch)
	
	velocity = power
	print("Applied")
	$ClientSynchronizer.snap(":velocity", velocity)
	$Interpolator.snap(":velocity", velocity)


func _do_movement(delta: float):
	if is_mantling: return
	
	var grab_point: Node3D = get_node_or_null(grab_point_path)
	if grab_point: return
	
	if _grab_throw_after_finish:
		_try_apply_grab_throw(_grab_throw_velocity, _grab_throw_pitch)
	
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
		if health <= 0: max_speed = 0
		
		velocity = G.apply_friction(velocity, 5 * delta)
		velocity = G.accelerate(velocity, move_direction, 10 * delta, max_speed)
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


var last_footstep_was_at := 0.0
func play_footstep() -> void:
	if !is_grounded or Net.now - last_footstep_was_at < 0.1: return
	last_footstep_was_at = Net.now
	
	$Footsteps.volume_linear = remap(velocity.length(), 0, 2, 0, 0.5)
	$Footsteps.play()


var model_offset: Vector3
func evaluate_animations(delta: float):
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch)
	
	var hor_velocity := velocity * Vector3(1, 0, 1)
	var walk_speed := hor_velocity.length()
	var walk_dir := (hor_velocity * horizontal_look).normalized()
	
	$AnimationTree.set_multiparam("vertical_look", remap(look_yaw, -PI/2, PI/2, -1, 1))
	$AnimationTree.set_multiparam("horizontal_speed", walk_speed)
	$AnimationTree.set_multiparam("horizontal_direction", Vector2(-walk_dir.x, walk_dir.z))
	$AnimationTree.set_multiparam("crouchness", crouchness)
	
	var right_holdtype := G.HoldType.NONE
	var right_item := $/root/world/Items.get_node_or_null(right_hand_item_name)
	if right_item: right_holdtype = right_item.holdtype
	
	var left_holdtype := G.HoldType.NONE
	var left_item := $/root/world/Items.get_node_or_null(left_hand_item_name)
	if left_item: left_holdtype = left_item.holdtype
	
	$AnimationTree.set_multiparam("right_holdtype", right_holdtype)
	$AnimationTree.set_multiparam("left_holdtype", left_holdtype)
	
	
	if is_mantling:
		model_offset += $AnimationTree.get_root_motion_position()
	else:
		model_offset = Vector3.ZERO
	
	
	var grab_point: Node3D = get_node_or_null(grab_point_path)
	if grab_point:
		var bone_idx: int = $Model/Skeleton3D.find_bone("torso2")
		var bone_trans: Transform3D = $Model/Skeleton3D.get_bone_global_pose(bone_idx)
		$Model.global_transform = grab_point.global_transform * bone_trans.inverse()
	else:
		$Model.transform = horizontal_look.translated_local(model_offset)
	
	$AnimationTree.advance(delta)


func _process(delta: float) -> void:
	$Interpolator.apply()
	evaluate_animations(delta)
	
	$Back1Attachment/Satchel.visible = satchel_name == ""
	
	if !is_multiplayer_authority(): return
	
	# We manually stepped the animation tree above, so this will be out of sync.
	# Re-sync it!
	$HeadAttachment.on_skeleton_update()
	
	var camera := get_viewport().get_camera_3d()
	camera.global_transform = $HeadAttachment/Eyes.global_transform
