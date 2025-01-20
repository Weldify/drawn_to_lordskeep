extends Node

var move: Vector2
var look_pitch: float
var look_yaw: float
var crouch := false

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)


func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		look_pitch = fmod(look_pitch - event.relative.x * 0.002, PI*2)
		look_yaw = clamp(look_yaw - event.relative.y * 0.002, -PI/2, PI/2)


func _gather() -> void:
	if !is_multiplayer_authority(): return
	
	move = Input.get_vector("right", "left", "back", "forward")
	crouch = Input.is_action_pressed("crouch")
