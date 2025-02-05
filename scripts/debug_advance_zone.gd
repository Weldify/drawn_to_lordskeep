extends Area3D

var advanced := false

func _on_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server() or advanced: return
	if body is not Mercenary: return
	
	advanced = true
	get_parent().advance()
