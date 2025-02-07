extends Node

@export_category("DO NOT TOUCH THIS")
var is_active := false
@export var is_damaging := false
var cooldown_ends_at := 0.0

func _ready():
	get_parent().anim_attack_swing_start.connect(try_start_swing_damage)
	get_parent().anim_attack_swing_finish.connect(try_stop_swing)

func try_start_swing_damage():
	if !is_active or is_damaging: return
	is_damaging = true
	damage_start_effects.rpc()


@rpc("authority", "call_local", "unreliable")
func damage_start_effects():
	$"../RHold/Swing".play()


func _physics_process(delta: float):
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
