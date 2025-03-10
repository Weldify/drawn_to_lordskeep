extends Node


func _ready():
	$WakeScreen.visible = true


func start_cutscene() -> void:
	$WakeScreen.visible = false
	$AnimationPlayer.play(&"cutscene", 0)


func on_animation_finished(anim_name: StringName):
	assert(anim_name == &"cutscene")
	
	print("Gay")
	
	queue_free()
