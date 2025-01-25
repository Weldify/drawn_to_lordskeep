extends Label


func _ready():
	$AnimationPlayer.play("RESET")


func display(new_text: String):
	text = new_text
	$AnimationPlayer.play("RESET")
	$AnimationPlayer.advance(0)
	$AnimationPlayer.play("in")
