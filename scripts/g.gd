extends Node

enum HoldType {
	NONE,
	WEAPON,
	HORN
}

class HitHandleResult:
	var extra_colliders_to_ignore: Array[CollisionObject3D]


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


func flesh_hit_effects(weapon, position: Vector3, normal: Vector3):
	if weapon.blunt:
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
