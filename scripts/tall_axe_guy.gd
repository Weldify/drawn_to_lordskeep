extends CharacterBody3D
class_name Enemy

@warning_ignore("unused_signal") signal anim_attack_swing_start
@warning_ignore("unused_signal") signal anim_attack_swing_finish

@export_category("DO NOT TOUCH THIS")
@export var velocity_mirror: Vector3:
	get(): return velocity
	set(v): velocity = v

var should_change_point_of_interest_at := 0.0
@onready var point_of_interest_node := $PointOfInterest

var should_change_direction_at := 0.0
var walk_direction: Vector3

var look_pitch := 0.0
var is_grounded := false

var look_at_modifiers: Array[LookAtModifier3D]

func handle_hit_effect(weapon, pos: Vector3, normal: Vector3):
	G.flesh_hit_effects(weapon.blunt, pos, normal)

func _ready() -> void:
	look_at_modifiers.append_array(find_children("LookAt*", "LookAtModifier3D"))


func _physics_process(delta: float) -> void:
	if !multiplayer.is_server(): return
	
	if NetworkTime.now > should_change_point_of_interest_at:
		should_change_point_of_interest_at = NetworkTime.now + randf_range(2, 6)
		
		var angle := randf_range(-PI, PI)
		var distance := randf_range(2, 5)
		var target := global_position + Vector3(cos(angle), 0, sin(angle))
		target *= distance
		target.y += randf_range(-1, 1)
		
		point_of_interest_target = target
	
	
	if NetworkTime.now > should_change_direction_at:
		should_change_direction_at = NetworkTime.now + randf_range(1, 2)
		
		var angle := randf_range(-PI, PI)
		walk_direction = Vector3(cos(angle), 0, sin(angle))
	
	is_grounded = is_on_floor()
	
	if is_grounded:
		var max_speed := 0.5
		
		velocity = G.apply_friction(velocity, 1 * delta)
		velocity = G.accelerate(velocity, walk_direction, 1 * delta, max_speed)
	else:
		velocity += get_gravity() * delta
	
	move_and_slide()

@export var point_of_interest_target: Vector3:
	set(v):
		point_of_interest_target = v
		
		point_of_interest_node.position = point_of_interest_target
		for modifier in look_at_modifiers:
			modifier.target_node = ""
			modifier.target_node = point_of_interest_node.get_path()


var last_footstep_was_at := 0.0
func play_footstep() -> void:
	if !is_grounded or NetworkTime.now - last_footstep_was_at < 0.1: return
	last_footstep_was_at = NetworkTime.now
	
	$Footsteps.volume_linear = remap(velocity.length(), 0, 2, 0, 0.5)
	$Footsteps.play()


func _evaluate_animations():
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch)
	var hor_velocity := velocity * Vector3(1, 0, 1)
	var walk_speed := hor_velocity.length()
	var walk_dir := (hor_velocity * horizontal_look).normalized()
	
	$AnimationTree.set("parameters/horizontal speed/1/blend_position", Vector2(-walk_dir.x, walk_dir.z))
	$AnimationTree.set("parameters/horizontal speed/blend_position", walk_speed)
	
	# @TODO: Read same line in mercenary.gd 
	$AnimationTree.set("parameters/horizontal speed (movement multiplier)/scale", walk_speed * 1.1)
	
	
	$Model.transform = horizontal_look


func _process(delta: float) -> void:
	$Interpolator.apply()
	_evaluate_animations()
	
	var goal := atan2(velocity.x, velocity.z)
	
	# Should we face the point of interest or our move direction?
	var face_poi := true
	if face_poi:
		var diff = point_of_interest_target - global_position
		goal = atan2(diff.x, diff.z)
	
	look_pitch = lerp_angle(look_pitch, goal, delta * 5)
