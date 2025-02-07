extends Node

@onready var item := $".."

@onready var hitbox: ShapeCast3D = $"../Hitbox"
@onready var original_hitbox_position: Vector3 = hitbox.position

## Blunt weapons stop even on successful hits.
@export var blunt := false

@export_category("Don't touch this")

var user: Mercenary

var swinging := false
@export var swing_damaging := false
var previous_hitbox_position: Vector3

# @TODO: Convert this to a timestamp once I write time sync
@export var hitstop_time_left := 0.0

var parrying := false
var parry_timer := 0.0

func _ready() -> void:
	item.holder_changed.connect(_holder_changed)
	# _holder_changed is called when the item is first created,
	# but it won't get called for someone who joined the game later.
	_holder_changed()


func _holder_changed():
	if user and is_multiplayer_authority():
		try_stop_swing()
		try_stop_parry()
	
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
	
	if is_multiplayer_authority():
		var events := user.get_node("RightHandAnimEvents") if item.is_in_right_hand else user.get_node("LeftHandAnimEvents")
		events.swing_over.connect(try_stop_swing)
		events.swing_damaging.connect(try_start_swing_damaging)


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority() or !user: return
	
	if parrying:
		parry_timer -= delta
		if parry_timer < 0: try_stop_parry()
	
	do_hitboxes()
	
	if !G.mouse_unlockers.is_empty() or Input.is_action_pressed("drop"): return
	if Input.is_action_pressed("right_action" if item.is_in_right_hand else "left_action"):
		if Input.is_action_pressed("alt"):
			try_parry()
		else:
			try_swing()
	

func _process(delta: float) -> void:
	$"../ProtonTrail".emit = swing_damaging
	
	hitstop_time_left = max(0, hitstop_time_left - delta)
	if user:
		var timescale := 0 if hitstop_time_left > 0 else 1
		if item.is_in_right_hand:
			user.get_node("AnimationTree").set("parameters/Right hand timescale/scale", timescale)
		else:
			user.get_node("AnimationTree").set("parameters/Left hand timescale/scale", timescale)

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
	var collider: PhysicsBody3D = hitbox.get_collider(0)
	hitbox.add_exception(collider)
	
	if blunt or collider.get_collision_layer_value(1):
		try_stop_swing()
		hit_recoil_effects.rpc()
	else:
		hitstop_time_left = 0.1
	
	var hit_handler: Node = collider.get_parent()
	while hit_handler and hit_handler.get("handle_hit") == null:
		hit_handler = hit_handler.get_parent()
	
	if hit_handler and hit_handler.get("handle_hit"): 
		var result: G.HitHandleResult = hit_handler.handle_hit()
		if !result.extra_colliders_to_ignore.is_empty():
			for v in result.extra_colliders_to_ignore: hitbox.add_exception(v)
	
	hit_effects.rpc(collider.get_path(), hitbox.get_collision_point(0), hitbox.get_collision_normal(0))


@rpc("authority", "call_local", "reliable")
func hit_effects(target_path: String, position: Vector3, normal: Vector3):
	var hit_effect_handler: Node = get_node(target_path)
	while hit_effect_handler and hit_effect_handler.get("handle_hit_effect") == null:
		hit_effect_handler = hit_effect_handler.get_parent()
	
	if hit_effect_handler and hit_effect_handler.get("handle_hit_effect"): 
		hit_effect_handler.handle_hit_effect(self, position, normal)
	else:
		$"../Clash".play()


@rpc("authority", "call_local", "reliable")
func hit_recoil_effects():
	var hand_name := "Right hand" if item.is_in_right_hand else "Left hand"
	var parameter := "parameters/%s/playback" % hand_name
	user.get_node("AnimationTree").get(parameter).start("swing_recoil")


func try_stop_swing():
	assert(is_multiplayer_authority())
	if !swinging: return
	swinging = false
	swing_damaging = false


func try_swing():
	if swinging or parrying: return
	swinging = true
	swing_effects.rpc()
	
	hitbox.clear_exceptions()
	add_user_hitbox_exceptions()


func add_user_hitbox_exceptions():
	for body in user.hitboxes:
		hitbox.add_exception(body)


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
	parry_timer = 0.5
	
	parry_effects.rpc()


func try_stop_parry():
	if !parrying: return
	parrying = false


@rpc("authority", "call_local", "reliable")
func parry_effects():
	var hand_name := "Right hand" if item.is_in_right_hand else "Left hand"
	var parameter := "parameters/%s/playback" % hand_name
	user.get_node("AnimationTree").get(parameter).start("parry")
	
	$"../ParrySwing".play()
