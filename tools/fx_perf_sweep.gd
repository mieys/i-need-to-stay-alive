extends SceneTree

## Tüm scenes/fx_*.tscn efektlerini N'şer kopya aynı anda oynatıp ortalama ekstra kare süresini ölçer (madde 215).
## Sonuç: FXS <ad> extra_ms_per_instance (ortalama, ilk 1,2 sn) + peak. Kullanım:
##   FXS_N=10 Godot --path . --windowed --resolution 960x540 -s tools/fx_perf_sweep.gd   (FXS_ONLY=alt-dize ile süz)

var _n: int = int(OS.get_environment("FXS_N")) if OS.get_environment("FXS_N") != "" else 10
var _only: String = OS.get_environment("FXS_ONLY")
var _scene: Node2D = null
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _frames(sec: float) -> Array:
	var t0 := Time.get_ticks_usec()
	var last := t0
	var out: Array = []
	while float(Time.get_ticks_usec() - t0) / 1e6 < sec:
		await process_frame
		var now := Time.get_ticks_usec()
		out.append(float(now - last) / 1000.0)
		last = now
	return out


func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, float(a.size()))


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 10
	gm.selected_character = 1
	_scene = Node2D.new()
	root.add_child(_scene)
	current_scene = _scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	_scene.add_child(bg)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	_scene.add_child(cam)
	cam.global_position = _player.global_position
	cam.make_current()
	if OS.get_environment("FXS_WARM") != "":
		(load("res://scripts/fx_warmup.gd") as GDScript).run(_scene)
	await _frames(1.0)
	var base: Array = await _frames(1.0)
	var base_ms: float = _mean(base)
	print("FXS BASE %.3f" % base_ms)
	var dir := DirAccess.open("res://scenes")
	var names: Array = []
	for f in dir.get_files():
		if f.begins_with("fx_") and f.ends_with(".tscn") and (_only == "" or f.contains(_only)):
			names.append(f)
	names.sort()
	for f in names:
		var ps: PackedScene = load("res://scenes/" + f)
		if ps == null:
			continue
		var made: Array = []
		for i in range(_n):
			var inst: Node = ps.instantiate()
			if inst is Node2D:
				_scene.add_child(inst)
				(inst as Node2D).global_position = _player.global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
				made.append(inst)
			else:
				inst.queue_free()
		var fr: Array = await _frames(1.2)
		var peak := 0.0
		for v in fr:
			peak = maxf(peak, float(v))
		var extra: float = (_mean(fr) - base_ms) / float(_n)
		print("FXS %-34s per_inst=%.3f ms  mean_frame=%.2f peak=%.1f" % [f, extra, _mean(fr), peak])
		for m in made:
			if is_instance_valid(m):
				m.queue_free()
		await _frames(0.3)
	print("FXS DONE")
	quit()
