extends Node

@export var state_machine_parameter: StringName
@export var state_name: StringName
@export var damage_start_time: float
@export var finish_time: float

var activated_at := 0.0
var is_active := false

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


@onready var user: Enemy = $"../.."
@onready var hit_detector := $"../../RHold/SpearHitbox"
var previous_hit_detector_position: Vector3
var original_hit_detector_position: Vector3

func _ready():
	$NetSynchronizer.configure()
	NetworkTime.on_tick.connect(_on_tick)


func try_start_swing_damage():
	if !is_active or is_damaging: return
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


func try_activate():
	if user.current_action or user.health <= 0: return
	is_active = true
	activated_at = NetworkTime.now
	
	swing_effects.rpc()


func stop():
	if !is_active: return
	is_active = false
	is_damaging = false
	
	user.action_cooldown_ends_at = NetworkTime.now + 2


func _on_tick(_delta: float):
	do_hitboxes()
	if !is_active: return
	
	var elapsed := NetworkTime.now - activated_at
	if elapsed > damage_start_time: try_start_swing_damage()
	if elapsed > finish_time: stop()


@rpc("authority", "call_local", "unreliable")
func swing_effects():
	var playback: AnimationNodeStateMachinePlayback= $"../../AnimationTree".get(state_machine_parameter)
	playback.start(state_name)
