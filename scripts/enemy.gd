extends CharacterBody3D
class_name Enemy

@export var look_at_modifiers: Array[LookAtModifier3D] 
@export var eyes: Node3D
@export_flags_3d_physics var vision_spot_block_layers: int

var health := 1.0 :
	set(v):
		if v == health: return
		health = v
		
		if health <= 0:
			if is_instance_valid(active_action):
				active_action.stop()


var look_at_active: bool :
	set(v):
		if v == look_at_active: return
		look_at_active = v
		
		for modifier in look_at_modifiers: 
			modifier.active = v


var should_change_point_of_interest_at := 0.0
@onready var point_of_interest_node := $PointOfInterest

var should_change_direction_at := 0.0
var walk_direction: Vector3

var look_pitch := 0.0
var is_grounded := false

func handle_hit(weapon, pos: Vector3, normal: Vector3):
	G.flesh_hit_effects(weapon.blunt, pos, normal)
	
	if multiplayer.is_server():
		health -= 0.4


func _ready() -> void:
	$AnimationTree.callback_mode_process = AnimationTree.ANIMATION_PROCESS_MANUAL
	process_priority = G.ENEMY_PROCESS_PRIORITY
	
	$NetSynchronizer.configure()
	Net.on_tick.connect(_on_tick)
	
	if multiplayer.is_server():
		vision_block_params = PhysicsRayQueryParameters3D.new()
		vision_block_params.collision_mask = vision_spot_block_layers


var patrol_node: AIPatrolNode

##: @TODO @TODO @TODO: @TODO FUCKING
## Define fucking spot points DIRECTLY ON THE FUCKING
## PLAYER. AS AN @EXPORT.
## SO MUCH SIMPLER!
var aggro_target: Node3D


var vision_block_params: PhysicsRayQueryParameters3D

func can_see_position(pos: Vector3) -> bool:
	if !eyes: return false
	
	var dir_to := eyes.global_position.direction_to(pos)
	var forward := -eyes.global_basis.z
	if forward.dot(dir_to) < 0.5: return false
	
	var space_state := get_world_3d().direct_space_state
	
	vision_block_params.from = eyes.global_position
	vision_block_params.to = pos
	
	var block_result := space_state.intersect_ray(vision_block_params)
	return block_result.is_empty()

func _do_vision_target_detection():
	if !eyes or is_instance_valid(aggro_target): return
	
	for spot_point: CreatureSpotPoint in get_tree().get_nodes_in_group("creature_spot_point"):
		if !can_see_position(spot_point.global_position): continue
		
		aggro_target = spot_point.creature
		break


func _on_tick(delta: float) -> void:
	if !multiplayer.is_server(): return
	
	_do_vision_target_detection()
	_do_actions()
	
	look_at_active = health > 0 and (!active_action or !active_action.block_look_at)
	
	if $Navigator.is_navigation_finished() and patrol_node and patrol_node.next:
		patrol_node = patrol_node.next
		$Navigator.target_position = patrol_node.global_position
	
	
	if !$Navigator.is_navigation_finished():
		var nav_target: Vector3 = $Navigator.get_next_path_position()
		walk_direction = (nav_target - global_position * Vector3(1, 0, 1)).normalized()
	
	if !patrol_node:
		$PatrolNodeFinder.force_shapecast_update()
		if $PatrolNodeFinder.is_colliding():
			patrol_node = $PatrolNodeFinder.get_collider(0)
			print("Found patrol node!")
			$Navigator.target_position = patrol_node.global_position
	
	if !is_instance_valid(active_action) and Net.now > should_change_point_of_interest_at:
		should_change_point_of_interest_at = Net.now + randf_range(1, 4)
		
		var angle := look_pitch + randf_range(-PI/4, PI/4)
		var offset := Vector3(sin(angle), randf_range(-0.25, 0), cos(angle)) * randf_range(1, 3)
		var target := eyes.global_position + offset
		
		point_of_interest_target = target
		print("Changed poi")
	
	
	#if Net.now > should_change_direction_at:
		#should_change_direction_at = Net.now + randf_range(1, 2)
		#
		#var angle := randf_range(-PI, PI)
		#walk_direction = Vector3(cos(angle), 0, sin(angle))
	
	is_grounded = is_on_floor()
	
	if is_grounded:
		var max_speed := 0.5
		if health <= 0: max_speed = 0
		
		velocity = G.apply_friction(velocity, 3 * delta)
		velocity = G.accelerate(velocity, walk_direction, 3 * delta, max_speed)
	else:
		velocity += get_gravity() * delta
	
	move_and_slide()


var action_cooldown_ends_at := 0.0
var active_action: EnemyAction
var _next_action_index_to_try := 0
func _do_actions():
	var child_count := $Actions.get_child_count()
	if child_count == 0: return
	
	if Net.now < action_cooldown_ends_at or active_action: return
	
	if _next_action_index_to_try > child_count-1:
		_next_action_index_to_try = 0
	
	var action := $Actions.get_child(_next_action_index_to_try)
	action.try_activate()
	
	_next_action_index_to_try += 1


var point_of_interest_target: Vector3:
	set(v):
		if v == point_of_interest_target: return
		point_of_interest_target = v
		
		point_of_interest_node.global_position = point_of_interest_target
		for modifier in look_at_modifiers:
			modifier.target_node = ""
			modifier.target_node = point_of_interest_node.get_path()


var last_footstep_was_at := 0.0
func play_footstep() -> void:
	if !is_grounded or Net.now - last_footstep_was_at < 0.1: return
	last_footstep_was_at = Net.now
	
	$Footsteps.volume_linear = remap(velocity.length(), 0, 2, 0, 0.5)
	$Footsteps.play()


func _evaluate_animations(delta: float):
	var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, look_pitch)
	var hor_velocity := velocity * Vector3(1, 0, 1)
	var walk_speed := hor_velocity.length()
	var walk_dir := (hor_velocity * horizontal_look).normalized()
	
	$AnimationTree.set("parameters/regular_blendtree/horizontal speed/1/blend_position", Vector2(-walk_dir.x, walk_dir.z))
	$AnimationTree.set("parameters/regular_blendtree/horizontal speed/blend_position", walk_speed)
	
	# @TODO: Read same line in mercenary.gd 
	$AnimationTree.set("parameters/regular_blendtree/horizontal speed (movement multiplier)/scale", walk_speed * 1.1)
	
	$Model.global_transform = horizontal_look.translated(global_position)
	
	$AnimationTree.advance(delta)
	
	# @NOTE: Mercenaries are attached to this when they are grabbed.
	# If we don't update this here and don't run _process() on all the enemies
	# BEFORE the mercenaries, their screen will jitter!!!
	# @NOTE: Apparently that's not the case. I do not fucking understand.
	#$"RHold".on_skeleton_update()


func _process(delta: float) -> void:
	$Interpolator.apply()
	_evaluate_animations(delta)
	
	if health > 0:
		var goal := atan2(velocity.x, velocity.z)
		
		# Should we face the point of interest or our move direction?
		var face_poi := false
		if face_poi:
			var diff = point_of_interest_target - global_position
			goal = atan2(diff.x, diff.z)
		
		look_pitch = lerp_angle(look_pitch, goal, delta * 5)
