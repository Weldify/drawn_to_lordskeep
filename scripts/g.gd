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
