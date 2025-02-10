extends Node

@onready var item := $".."
var user: Mercenary

func _ready() -> void:
	item.holder_changed.connect(_holder_changed)
	# _holder_changed is called when the item is first created,
	# but it won't get called for someone who joined the game later.
	_holder_changed()


func _holder_changed():
	if user and is_multiplayer_authority():
		try_stop_blowing()
	
	var new := $/root/world/Mercenaries.get_node_or_null(item.holder_name)
	if new == null:
		user = null
		set_multiplayer_authority(1)
		return
	
	user = new
	set_multiplayer_authority(int(new.name))


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority() or !user: return
	
	if is_blowing:
		blow_timer -= delta
		if blow_timer < 0: try_stop_blowing()
	
	if !G.mouse_unlockers.is_empty() or Input.is_action_pressed("drop"): return
	if Input.is_action_pressed("right_action" if item.is_in_right_hand else "left_action"):
		try_start_blowing()

var is_blowing := false
var blow_timer := 0.0

func try_start_blowing():
	if is_blowing: return
	is_blowing = true
	blow_timer = 3
	
	blowing_effects.rpc()

func try_stop_blowing():
	is_blowing = false
	
	if blow_timer < 0 and multiplayer.is_server():
		$/root/world.start_hosting()
		$/root/world/SubtitlesUI.display("Your allies can now join you.")
		
	blow_timer = 0


@rpc("authority", "call_local", "unreliable")
func blowing_effects():
	var hand_name := "Right hand" if item.is_in_right_hand else "Left hand"
	var parameter := "parameters/regular_blendtree/%s/playback" % hand_name
	user.get_node("AnimationTree").get(parameter).start("blow_horn")
	
	$"../Blow".play()
