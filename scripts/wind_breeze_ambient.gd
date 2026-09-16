extends AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stream_res: AudioStreamMP3 = load("res://assets/audio/forest_ambient.mp3") as AudioStreamMP3
	if stream_res:
		stream_res.loop = true
		stream = stream_res
	volume_db = -12.0
	play()
