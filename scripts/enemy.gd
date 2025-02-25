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
@onready var point_of_interest_node: Node3D :
	set(v):
		if point_of_interest_node == v: return
		point_of_interest_node = v
		
		for modifier in look_at_modifiers:
			modifier.target_node = v.get_path() if v else ^""


var should_change_direction_at := 0.0
var walk_direction: Vector3

var look_pitch := 0.0
var is_grounded := false

func handle_hit(weapon, pos: Vector3, normal: Vector3):
	G.flesh_hit_effects(weapon.blunt, pos, normal)
	
	if multiplayer.is_server():
		health -= 0.4


func _ready() -> void:
	point_of_interest_node = $LookInterest
	
	$AnimationTree.callback_mode_process = AnimationTree.ANIMATION_PROCESS_MANUAL
	process_priority = G.ENEMY_PROCESS_PRIORITY
	
	$NetSynchronizer.configure()
	Net.on_tick.connect(_on_tick)
	
	if multiplayer.is_server():
		vision_block_params = PhysicsRayQueryParameters3D.new()
		vision_block_params.collision_mask = vision_spot_block_layers


var patrol_node: AIPatrolNode
var aggro_target_path: NodePath

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


func can_see_any_spot_points(targetable: EnemyTargetable) -> bool:
	for spot_point in targetable.spot_points:
		if can_see_position(spot_point.global_position): return true
		
	return false


func _do_vision_target_detection():
	if !eyes or get_node_or_null(aggro_target_path): return
	
	var found := false
	for enemy_targetable: EnemyTargetable in get_tree().get_nodes_in_group("enemy_targetable"):
		if can_see_any_spot_points(enemy_targetable):
			aggro_target_path = enemy_targetable.get_path()
			break


func figure_out_target_position() -> Vector3:
	var aggro_target: EnemyTargetable = get_node_or_null(aggro_target_path)
	if aggro_target:
		return aggro_target.get_parent().global_position
	
	if is_instance_valid(patrol_node):
		return patrol_node.global_position
	
	return global_position


func _try_take_over_nearest_patrol_route():
	assert(!is_instance_valid(patrol_node) and !get_node_or_null(aggro_target_path))
	
	$PatrolNodeFinder.force_shapecast_update()
	if $PatrolNodeFinder.is_colliding():
		patrol_node = $PatrolNodeFinder.get_collider(0)
		print("Found patrol node!")
		$Navigator.target_position = patrol_node.global_position


var look_interest: Vector3 :
	set(v):
		if look_interest == v: return
		look_interest = v
		$LookInterest.global_position = v
		
		## @NOTE: Crutch to make look interest changes smooth
		if point_of_interest_node == $LookInterest:
			point_of_interest_node = null
			point_of_interest_node = $LookInterest


func _before_nav_target_figured_out():
	var aggro_target: EnemyTargetable = get_node_or_null(aggro_target_path)
	
	if aggro_target and !can_see_any_spot_points(aggro_target):
		aggro_target_path = ^""
		aggro_target = null
	
	if is_instance_valid(aggro_target):
		patrol_node = null
	
	if !is_instance_valid(patrol_node) and !aggro_target:
		_try_take_over_nearest_patrol_route()


func _after_nav_target_figured_out():
	if !$Navigator.is_navigation_finished():
		var nav_target: Vector3 = $Navigator.get_next_path_position()
		walk_direction = (nav_target - global_position * Vector3(1, 0, 1)).normalized()
	
	if is_instance_valid(patrol_node) and $Navigator.is_navigation_finished() and is_instance_valid(patrol_node.next):
		patrol_node = patrol_node.next
		$Navigator.target_position = patrol_node.global_position


func _do_movement(delta: float):
	is_grounded = is_on_floor()
	
	if is_grounded:
		var max_speed := 0.5
		if health <= 0: max_speed = 0
		
		velocity = G.apply_friction(velocity, 3 * delta)
		velocity = G.accelerate(velocity, walk_direction, 3 * delta, max_speed)
	else:
		velocity += get_gravity() * delta
	
	move_and_slide()


func _on_tick(delta: float) -> void:
	if !multiplayer.is_server(): return
	
	_do_vision_target_detection()
	_do_actions()
	
	look_at_active = health > 0 and (!active_action or !active_action.block_look_at)
	
	if health > 0:
		_before_nav_target_figured_out()
		$Navigator.target_position = figure_out_target_position()
		_after_nav_target_figured_out()
	
		if !is_instance_valid(active_action) and Net.now > should_change_point_of_interest_at:
			should_change_point_of_interest_at = Net.now + randf_range(1, 4)
			
			var angle := look_pitch + randf_range(-PI/4, PI/4)
			var offset := Vector3(sin(angle), randf_range(-0.25, 0), cos(angle)) * randf_range(1, 3)
			var target := eyes.global_position + offset
			
			look_interest = target
			print("Changed poi")
	
	_do_movement(delta)


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


var last_footstep_was_at := 0.0
func play_footstep() -> void:
	if !is_grounded or Net.now - last_footstep_was_at < 0.1: return
	last_footstep_was_at = Net.now
	
	$Footsteps.volume_linear = remap(velocity.length(), 0, 2, 0, 0.5)
	$Footsteps.play()


func _evaluate_animations(delta: float):
	var aggro_target: EnemyTargetable = get_node_or_null(aggro_target_path)
	if aggro_target:
		point_of_interest_node = aggro_target.look_at_point
	else:
		point_of_interest_node = $LookInterest
	
	if health > 0:
		var goal: float
		
		# Should we face the point of interest or our move direction?
		var face_look_interest := aggro_target != null
		if face_look_interest:
			var diff = point_of_interest_node.global_position - global_position
			goal = atan2(diff.x, diff.z)
		else:
			goal = atan2(velocity.x, velocity.z)
		
		look_pitch = lerp_angle(look_pitch, goal, delta * 5)
	
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
