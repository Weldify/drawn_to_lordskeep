extends CharacterBody3D


var crouchness := 0.0

## Non-owners use this for interpolating the look direction!
var recorded_look_pitch: float
var recorded_look_yaw: float

var left_hold_type := G.HoldType.WEAPON
var right_hold_type := G.HoldType.WEAPON

func is_left_holdtype_weapon() -> bool:
	return left_hold_type == G.HoldType.WEAPON

func is_right_holdtype_weapon() -> bool:
	return right_hold_type == G.HoldType.WEAPON


func _ready() -> void:
	var peer_id := int(name)
	set_multiplayer_authority(1)
	$Input.set_multiplayer_authority(peer_id)
	$RollbackSynchronizer.process_settings()
	
	if !$Input.is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print($AnimationTree.get("parameters/Right Hand/playback"))


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if $Input.crouch:
		crouchness = move_toward(crouchness, 1.0, delta * 5)
	else:
		crouchness = move_toward(crouchness, 0.0, delta * 5)
	
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, $Input.look_pitch)
	
	var move_input: Vector2 = $Input.move
	var move_direction := Vector3(move_input.x, 0, move_input.y).normalized()
	move_direction = horizontal_look * move_direction
	
	var max_speed := 1 if crouchness != 0 else 2
	
	_apply_friction(5 * delta)
	_accelerate(move_direction, 10 * delta, max_speed)
	
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
	recorded_look_pitch = $Input.look_pitch
	recorded_look_yaw = $Input.look_yaw


func play_footstep() -> void:
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
