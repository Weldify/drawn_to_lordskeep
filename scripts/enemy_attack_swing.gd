extends Node

@export_category("DO NOT TOUCH THIS")
var is_active := false
var cooldown_ends_at := 0.0

# @NOTE: Yes, this looks evil, but this is the easiest way to sync this.
@export var is_damaging: bool :
	set(v):
		if v == is_damaging: return
		is_damaging = v
		
		if is_damaging:
			hit_detector.clear_exceptions()
			hit_detector.add_exception(user.get_node("Hitbox"))


@onready var user: Enemy = $".."
@onready var hit_detector := $"../RHold/SpearHitbox"
var previous_hit_detector_position: Vector3
var original_hit_detector_position: Vector3

func _ready():
	user.anim_attack_swing_start.connect(try_start_swing_damage)
	user.anim_attack_swing_finish.connect(try_stop_swing)

func try_start_swing_damage():
	if !is_active or is_damaging: return
	is_damaging = true
	damage_start_effects.rpc()


@rpc("authority", "call_local", "unreliable")
func damage_start_effects():
	$"../RHold/Swing".play()


func do_hitboxes():
	var hit_detector_position := previous_hit_detector_position
	previous_hit_detector_position = hit_detector.global_position
	
	if !is_damaging: return
	
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
		mercenary_hit_detected.rpc(collider.get_path(), hit_detector.get_collision_point(0), hit_detector.get_collision_normal(0))


## Mercenaries detect their own hits clientside

@rpc("any_peer", "call_local", "unreliable")
func mercenary_hit_detected(target_path: NodePath, position: Vector3, normal: Vector3):
	var mercenary_name := str(multiplayer.get_remote_sender_id())
	var mercenary := $/root/world/Mercenaries.get_node_or_null(mercenary_name)
	if !mercenary: return
	
	# @TODO: Assert that they sent a hit to their own mercenary.
	G.flesh_hit_effects(false, position, normal)
	
	if multiplayer.is_server():
		mercenary.health -= 0.4


func _physics_process(delta: float):
	do_hitboxes()
	
	if !multiplayer.is_server(): return
	
	if is_active or NetworkTime.now < cooldown_ends_at: return
	is_active = true
	
	swing_effects.rpc()


func _process(delta: float):
	$"../RHold/ProtonTrail".emit = is_damaging


@rpc("authority", "call_local", "unreliable")
func swing_effects():
	var playback: AnimationNodeStateMachinePlayback= $"../AnimationTree".get("parameters/upper body state/playback")
	playback.start("attack")


func try_stop_swing():
	if !is_active: return
	is_active = false
	is_damaging = false
	
	cooldown_ends_at = NetworkTime.now + 2
