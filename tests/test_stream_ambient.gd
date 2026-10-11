extends Node

## Akarsu sesi (scripts/stream_ambient.gd): uzaklığa göre genlik eğrisi + dikişsiz döngü dosyalarının yüklenmesi.

const StreamAmbientScript: GDScript = preload("res://scripts/stream_ambient.gd")


func _make(player_pos: Vector2, water: Array) -> Array:
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = player_pos
	var s: AudioStreamPlayer = StreamAmbientScript.new()
	add_child(s)
	s._water = PackedVector2Array(water)
	s._water_ready = true
	return [s, p]


func _done(pair: Array) -> void:
	pair[1].remove_from_group("player")
	pair[1].queue_free()
	pair[0].queue_free()


func test_full_at_shore_silent_far_and_monotonic() -> void:
	var water: Array = [Vector2(0, 0)]
	var prev: float = 2.0
	for d in [0.0, 60.0, 100.0, 200.0, 350.0, 500.0, 700.0, 2000.0]:
		var pair: Array = _make(Vector2(d, 0), water)
		var a: float = pair[0]._target_amount()
		assert(a <= prev + 0.0001, "uzaklaştıkça genlik artmamalı (d=%s)" % d)
		prev = a
		if d <= 60.0:
			assert(is_equal_approx(a, 1.0), "kıyıda tam seviye")
		if d >= 700.0:
			assert(a == 0.0, "çok uzakta tamamen sessiz")
		_done(pair)


func test_curve_is_smooth_no_big_step() -> void:
	var worst: float = 0.0
	var last: float = -1.0
	for d in range(0, 720, 8):
		var pair: Array = _make(Vector2(d, 0), [Vector2.ZERO])
		var a: float = pair[0]._target_amount()
		if last >= 0.0:
			worst = maxf(worst, absf(a - last))
		last = a
		_done(pair)
	assert(worst < 0.08, "8 px'lik adımda genlik sıçraması küçük olmalı (%f)" % worst)


func test_nearest_water_wins() -> void:
	var pair: Array = _make(Vector2(1000, 0), [Vector2(0, 0), Vector2(1010, 0)])
	assert(pair[0]._target_amount() > 0.99)
	_done(pair)


func test_loop_files_load_as_looping_ogg() -> void:
	for path in ["res://assets/audio/rain_ambience_loop.ogg", "res://assets/audio/stream_loop.ogg"]:
		var s: AudioStream = load(path) as AudioStream
		assert(s is AudioStreamOggVorbis, path + " OGG olarak yüklenmeli")
		assert(s.get_length() > 5.0)
