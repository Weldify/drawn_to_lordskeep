extends Node

const MERCENARY_PROCESS_PRIORITY = 0
const ENEMY_PROCESS_PRIORITY = MERCENARY_PROCESS_PRIORITY - 1

enum HoldType {
	NONE,
	WEAPON,
	HORN
}

class HitHandleResult:
	pass


var my_mercenary: Mercenary

## Whose eyes are we using to view the world?
## Uses this guys' health for the damage overlay, etc.
## Makes spectating easy
var viewer_mercenary: Mercenary


func dir_to_pitch(dir: Vector3) -> float:
	var pitch := atan2(dir.x, dir.z)
	return pitch


func accelerate(velocity: Vector3, direction: Vector3, acceleration: float, max_speed: float) -> Vector3:
	var projected_speed := velocity.dot(direction)
	return velocity + direction * clamp(max_speed - projected_speed, 0, acceleration)


func apply_friction(velocity: Vector3, amount: float) -> Vector3:
	var speed := velocity.length()
	if speed == 0: return Vector3.ZERO
	var drop := speed * amount
	
	return velocity * max(0, speed - drop) / speed


## The nodes in this array are not guaranteed to always be valid.
var mouse_unlockers: Array[Control]

func clear_freed_mouse_unlockers():
	mouse_unlockers = mouse_unlockers.filter(is_instance_valid)

func ui_affecting_mouse_set_visible(node: Control, visible: bool):
	if node.visible == visible: return
	node.visible = visible
	
	if visible and !mouse_unlockers.has(node):
		mouse_unlockers.append(node)
	else:
		mouse_unlockers.erase(node)


func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func send_dialogue_in_range(origin: Vector3, distance: float, text: String):
	for mercenary in $/root/world/Mercenaries.get_children():
		if mercenary.global_position.distance_to(origin) < distance:
			display_dialogue.rpc_id(mercenary.get_multiplayer_authority(), text)


func flesh_hit_effects(blunt: bool, position: Vector3, normal: Vector3):
	if blunt:
		var damage_blunt := preload("res://scenes/damage_blunt.tscn").instantiate()
		$"/root".add_child(damage_blunt, true)
		
		damage_blunt.look_at_from_position(position, position + normal)
		damage_blunt.restart()
		damage_blunt.finished.connect(damage_blunt.queue_free)
	else:
		var damage_sharp := preload("res://scenes/damage_sharp.tscn").instantiate()
		$"/root".add_child(damage_sharp, true)
		
		damage_sharp.look_at_from_position(position, position + normal)
		damage_sharp.restart()
		damage_sharp.finished.connect(damage_sharp.queue_free)


@rpc("authority", "call_local", "reliable")
func display_dialogue(text: String):
	$/root/world/SubtitlesUI.display(text)
