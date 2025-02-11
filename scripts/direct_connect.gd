extends Control


func _ready():
	visible = !OS.has_feature("steam")


func _on_join_pressed() -> void:
	var ip: String = $LineEdit.text
	$/root/world.join_by_ip(ip)
