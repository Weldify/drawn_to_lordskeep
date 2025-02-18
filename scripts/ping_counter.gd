extends Label

func _process(_delta: float) -> void:
	text = "Ping: %d" % (Net.ping * 1000)
