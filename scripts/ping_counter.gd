extends Label

func _process(_delta: float) -> void:
	text = "Ping: %d" % (NetworkTime.ping * 1000)
