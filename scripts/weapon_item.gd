extends Node

@onready var item := $".."

@onready var hitbox := $"../Hitbox"
@onready var original_hitbox_position: Vector3 = hitbox.position

var user: Mercenary

var swinging := false
var swing_damaging := false
var previous_hitbox_position: Vector3

func _ready() -> void:
	item.holder_changed.connect(_holder_changed)


func _holder_changed():
	if user and is_multiplayer_authority():
		try_stop_swing()
		hitbox.clear_exceptions()
	
		if is_instance_valid(user):
			user.anim_swing_over.disconnect(try_stop_swing)
			user.anim_swing_damaging.disconnect(start_swing_damaging)
	
	var new := $/root/world/Mercenaries.get_node_or_null(item.holder_name)
	if new == null:
		user = null
		set_multiplayer_authority(1)
		return
	
	user = new
	set_multiplayer_authority(int(new.name))
	hitbox.add_exception(user)
	
	if is_multiplayer_authority():
		user.anim_swing_over.connect(try_stop_swing)
		user.anim_swing_damaging.connect(start_swing_damaging)


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority() or !user: return
	
	if !swinging and Input.is_action_just_pressed("primary"):
		try_swing()
	
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
	user.get_node("AnimationTree").get("parameters/Right hand/playback").start("swing_recoil")
	$"../Clash".play()


func try_stop_swing():
	assert(is_multiplayer_authority())
	if !swinging: return
	swinging = false
	swing_damaging = false


func try_swing():
	if swinging: return
	swinging = true
	swing_effects.rpc()


@rpc("authority", "call_local", "reliable")
func swing_effects():
	user.get_node("AnimationTree").get("parameters/Right hand/playback").start("swing")


func start_swing_damaging():
	assert(is_multiplayer_authority())
	swing_damaging = true
	
	start_swing_damaging_effects.rpc()

@rpc("authority", "call_local", "reliable")
func start_swing_damaging_effects():
	$"../Swing".play()
