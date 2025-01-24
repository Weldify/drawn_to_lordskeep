extends Label

func display(new_text: String):
	text = new_text
	$AnimationPlayer.play("RESET")
	$AnimationPlayer.play("in")
