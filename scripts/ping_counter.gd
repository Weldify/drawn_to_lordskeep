extends Label

func _process(delta: float) -> void:
	text = "Ping: %d" % (NetworkTime.ping * 1000)
