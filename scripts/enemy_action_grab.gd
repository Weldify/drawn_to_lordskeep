extends EnemyAction

@export_group("Swing", "swing_")
@export var swing_state_machine_parameter: StringName
@export var swing_state_name: StringName
@export var swing_damage_start_time: float
@export var swing_damage_finish_time: float
@export var swing_finish_time: float

@export_group("Grab", "grab_")
@export var grab_state_name: StringName
@export var grab_finish_time: float
@export var grab_point: Node3D
@export var grab_throw_velocity: Vector3
@export var grab_throw_look_angle: float

var activated_at := 0.0

# @NOTE: Yes, this looks evil, but this is the easiest way to sync this.
var is_damaging: bool :
	set(v):
		if v == is_damaging: return
		is_damaging = v
		
		$"../../RHold/ProtonTrail".emit = is_damaging
		
		if is_damaging:
			previous_hit_detector_position = hit_detector.global_position
			hit_detector.clear_exceptions()
			hit_detector.add_exception(user.get_node("Hitbox"))


var _finished_damaging: bool


@onready var user: Enemy = $"../.."
@onready var hit_detector := $"../../RHold/SpearHitbox"
var previous_hit_detector_position: Vector3
var original_hit_detector_position: Vector3

func _ready():
	$NetSynchronizer.configure()
	NetworkTime.on_tick.connect(_on_tick)


func try_start_swing_damage():
	if is_damaging or _finished_damaging: return
	is_damaging = true
	damage_start_effects.rpc()


@rpc("authority", "call_local", "unreliable")
func damage_start_effects():
	$"../../RHold/Swing".play()


func do_hitboxes():
	if !is_damaging or user.health <= 0: return
	
	var hit_detector_position := previous_hit_detector_position
	previous_hit_detector_position = hit_detector.global_position
	
	hit_detector.global_position = hit_detector_position
	hit_detector.target_position = -hit_detector.position
	hit_detector.force_shapecast_update()
	hit_detector.position = original_hit_detector_position
		
	if !hit_detector.is_colliding(): return
	var collider: CollisionObject3D = hit_detector.get_collider(0)
	hit_detector.add_exception(collider)
	
	var hit_handler: Node = collider.get_parent()
	while hit_handler and hit_handler.get("handle_hit") == null:
		hit_handler = hit_handler.get_parent()
	
	
	if hit_handler == G.my_mercenary:
		var parrying_wep_component: ItemWeaponComponent
		
		for item_name in [hit_handler.right_hand_item_name, hit_handler.left_hand_item_name]:
			var item := $/root/world/Items.get_node_or_null(item_name)
			if item:
				var wep_component := item.get_node_or_null("ItemWeaponComponent")
				if wep_component and wep_component.parrying: parrying_wep_component = wep_component
		
		if parrying_wep_component:
			parrying_wep_component.do_parry_success_effects.rpc()
		else:
			mercenary_hit_detected.rpc(collider.get_path(), hit_detector.get_collision_point(0), hit_detector.get_collision_normal(0))


## Mercenaries detect their own hits clientside

@rpc("any_peer", "call_local", "unreliable")
func mercenary_hit_detected(_target_path: NodePath, position: Vector3, normal: Vector3):
	var mercenary_name := str(multiplayer.get_remote_sender_id())
	var mercenary := $/root/world/Mercenaries.get_node_or_null(mercenary_name)
	if !mercenary: return
	
	# @TODO: Assert that they sent a hit to their own mercenary.
	G.flesh_hit_effects(false, position, normal)
	
	if multiplayer.is_server():
		mercenary.health -= 0.4
		_try_grab(mercenary)


var _grabbed_mercenary: Mercenary
var _grabbing := false
var _grab_started_at := 0.0
func _try_grab(mercenary: Mercenary):
	if _grabbing: return
	_grabbing = true
	_grab_started_at = NetworkTime.now
	block_look_at = true
	
	_stop_damage()
	
	_grabbed_mercenary = mercenary
	mercenary.grab_point_path = grab_point.get_path()
	
	_grab_effects.rpc()


@rpc("authority", "call_local", "unreliable")
func _grab_effects():
	var playback: AnimationNodeStateMachinePlayback= $"../../AnimationTree".get(swing_state_machine_parameter)
	playback.start(grab_state_name)


func try_activate():
	if user.active_action or user.health <= 0: return
	user.active_action = self
	_finished_damaging = false
	_grabbing = false
	_grabbed_mercenary = null
	block_look_at = false
	
	activated_at = NetworkTime.now
	swing_effects.rpc()


func stop():
	if user.active_action != self: return
	_stop_damage()
	
	if is_instance_valid(_grabbed_mercenary):
		var horizontal_look := Transform3D.IDENTITY.rotated(Vector3.UP, user.look_pitch)
		var throw_velocity := horizontal_look * grab_throw_velocity
		
		_grabbed_mercenary.grab_point_path = ^""
		_grabbed_mercenary.grab_throw.rpc_id(_grabbed_mercenary.get_multiplayer_authority(), throw_velocity, user.look_pitch + grab_throw_look_angle)
	
	user.active_action = null
	user.action_cooldown_ends_at = NetworkTime.now + 2


func _stop_damage():
	is_damaging = false
	_finished_damaging = true


func _on_tick(_delta: float):
	do_hitboxes()
	if user.active_action != self: return
	
	if _grabbing:
		var elapsed := NetworkTime.now - _grab_started_at
		if elapsed > grab_finish_time: stop()
	else:
		var elapsed := NetworkTime.now - activated_at
		if elapsed > swing_damage_start_time: try_start_swing_damage()
		if elapsed > swing_damage_finish_time: _stop_damage()
		if elapsed > swing_finish_time: stop()


@rpc("authority", "call_local", "unreliable")
func swing_effects():
	var playback: AnimationNodeStateMachinePlayback= $"../../AnimationTree".get(swing_state_machine_parameter)
	playback.start(swing_state_name)
