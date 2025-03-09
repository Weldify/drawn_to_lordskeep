extends Node


func _ready():
	$WakeScreen.visible = true


func start_cutscene() -> void:
	$WakeScreen.visible = false
	$AnimationPlayer.play(&"cutscene", 0)
