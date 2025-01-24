extends Node

enum HoldType {
	NONE,
	WEAPON
}

func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
