extends Node

@onready var item := $".."

@onready var hitbox := $"../Hitbox"
@onready var original_hitbox_position: Vector3 = hitbox.position

var user: Mercenary

var swinging := false
var swing_damaging := false
var previous_hitbox_position: Vector3

var parrying := false

func _ready() -> void:
	item.holder_changed.connect(_holder_changed)


func _holder_changed():
	# @NOTE: I have no idea whether .is_in_right_hand is properly networked at this point.
	# It could be old. I need to investigate and make sure it is up to date by the time this is called!
	
	# @BUG: It is not. LOL
	print("Hand ", item.is_in_right_hand)
	
	if user and is_multiplayer_authority():
		try_stop_swing()
		try_stop_parry()
		hitbox.clear_exceptions()
	
		if is_instance_valid(user):
			# We don't know which hand this was in. Disconnect everything!!
			var names := ["RightHandAnimEvents", "LeftHandAnimEvents"]
			for name in names:
				var events := user.get_node(name)
				G.safe_disconnect(events.swing_over, try_stop_swing)
				G.safe_disconnect(events.swing_damaging, try_start_swing_damaging)
	
	
	var new := $/root/world/Mercenaries.get_node_or_null(item.holder_name)
	if new == null:
		user = null
		set_multiplayer_authority(1)
		return
	
	user = new
	set_multiplayer_authority(int(new.name))
	hitbox.add_exception(user)
	
	if is_multiplayer_authority():
		var events := user.get_node("RightHandAnimEvents") if item.is_in_right_hand else user.get_node("LeftHandAnimEvents")
		events.swing_over.connect(try_stop_swing)
		events.swing_damaging.connect(try_start_swing_damaging)


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority() or !user: return
	
	if Input.is_action_just_pressed("primary"):
		try_swing()
		
	if Input.is_action_just_pressed("secondary"):
		try_parry()
	
	do_hitboxes()


func do_hitboxes():
	var hitbox_position := previous_hitbox_position
	previous_hitbox_position = hitbox.global_position
	
	if !swinging or !swing_damaging: return
	
	hitbox.global_position = hitbox_position
	hitbox.target_position = -hitbox.position
	hitbox.force_shapecast_update()
	hitbox.position = original_hitbox_position
		
	if hitbox.is_colliding(): hit()


func hit():
	print(hitbox.get_collider(0))
	try_stop_swing()
	hit_effects.rpc()


@rpc("authority", "call_local", "reliable")
func hit_effects():
	var hand_name := "Right hand" if item.is_in_right_hand else "Left hand"
	var parameter := "parameters/%s/playback" % hand_name
	user.get_node("AnimationTree").get(parameter).start("swing_recoil")
	
	$"../Clash".play()


func try_stop_swing():
	assert(is_multiplayer_authority())
	if !swinging: return
	swinging = false
	swing_damaging = false


func try_swing():
	if swinging or parrying: return
	swinging = true
	swing_effects.rpc()


@rpc("authority", "call_local", "reliable")
func swing_effects():
	var hand_name := "Right hand" if item.is_in_right_hand else "Left hand"
	var parameter := "parameters/%s/playback" % hand_name
	user.get_node("AnimationTree").get(parameter).start("swing")


func try_start_swing_damaging():
	assert(is_multiplayer_authority())
	if !swinging or swing_damaging: return
	swing_damaging = true
	
	start_swing_damaging_effects.rpc()

@rpc("authority", "call_local", "reliable")
func start_swing_damaging_effects():
	$"../Swing".play()



func try_parry():
	if parrying or swinging: return
	parrying = true
	
	parry_effects()


func try_stop_parry():
	if !parrying: return
	parrying = false


@rpc("authority", "call_local", "reliable")
func parry_effects():
	var hand_name := "Right hand" if item.is_in_right_hand else "Left hand"
	var parameter := "parameters/%s/playback" % hand_name
	user.get_node("AnimationTree").get(parameter).start("parry")
