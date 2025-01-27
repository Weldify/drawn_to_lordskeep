extends Node

enum HoldType {
	NONE,
	WEAPON
}

class HitHandleResult:
	var extra_colliders_to_ignore: Array[CollisionObject3D]


func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func send_dialogue_in_range(origin: Vector3, distance: float, text: String):
	for mercenary in $/root/world/Mercenaries.get_children():
		if mercenary.global_position.distance_to(origin) < distance:
			display_dialogue.rpc_id(mercenary.get_multiplayer_authority(), text)


@rpc("authority", "call_local", "reliable")
func display_dialogue(text: String):
	$/root/world/SubtitlesUI.display(text)
