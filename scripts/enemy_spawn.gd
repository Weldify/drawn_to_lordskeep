extends Node3D

func _ready() -> void:
	if !multiplayer.is_server(): return
	
	var enemy := preload("res://scenes/spearman.tscn").instantiate()
	$/root/world/Enemies.add_child(enemy, true)
	enemy.global_position = global_position
