extends Node

var move: Vector2
var look_pitch: float
var look_yaw: float
var crouch := false
var use := false
var drop := false
var primary := false
var secondary := false

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)
	NetworkTime.on_tick.connect(_tick)


func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		look_pitch = fmod(look_pitch - event.relative.x * 0.002, PI*2)
		look_yaw = clamp(look_yaw - event.relative.y * 0.002, -PI/2, PI/2)


func _tick(delta: float, tick: int) -> void:
	if !is_multiplayer_authority: return

	if Input.is_action_just_pressed("place_satchel"):
		wants_to_place_satchel.rpc_id(1)

func _gather() -> void:
	if !is_multiplayer_authority(): return
	
	move = Input.get_vector("right", "left", "back", "forward")
	crouch = Input.is_action_pressed("crouch")
	use = Input.is_action_pressed("use")
	drop = Input.is_action_pressed("drop")
	primary = Input.is_action_pressed("primary")
	secondary = Input.is_action_pressed("secondary")


@rpc("authority", "call_local")
func wants_to_place_satchel() -> void:
	assert(multiplayer.is_server())
	get_parent().place_satchel()
