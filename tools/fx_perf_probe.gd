extends SceneTree

## FPS yoklaması (madde 215): FXP_KIND + FXP_N ortam değişkenleriyle bir efekt türünden N tane aynı anda çalıştırır,
## kare süresini (ortanca / p95 ms) ve betik süresini (TIME_PROCESS ms) basar. Boş sahne = "none".
## Kullanım: FXP_KIND=proj FXP_N=40 Godot --path . --windowed --resolution 960x540 -s tools/fx_perf_probe.gd

var _kind: String = OS.get_environment("FXP_KIND")
var _n: int = int(OS.get_environment("FXP_N")) if OS.get_environment("FXP_N") != "" else 10
var _scene: Node2D = null
var _player: Node2D = null
var _ally: Node2D = null
const PROJ := ["tabanca_projectile", "tufek_projectile", "dart_projectile", "arrow_projectile", "arcane_projectile", "ice_bolt_projectile", "firework_projectile"]


func _initialize() -> void:
	_run.call_deferred()


func _fire_proj(scene_name: String, at: Vector2) -> void:
	var p: Node2D = (load("res://scenes/%s.tscn" % scene_name) as PackedScene).instantiate()
	p.set("impact_sounds", [] as Array[AudioStream])
	_scene.add_child(p)
	var dir := Vector2.RIGHT.rotated(randf_range(-0.2, 0.2))
	p.global_position = at
	p.set("direction", dir)
	if scene_name == "firework_projectile":
		p.set("target_position", at + Vector2(170, 0))
	else:
		p.rotation = dir.angle()
	p.scale *= 0.5


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
	_ally = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	_scene.add_child(_ally)
	_ally.setup(77, 7, "Dost")
	_ally.global_position = _player.global_position + Vector2(100, 8)
	_ally.set("_target_position", _ally.global_position)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	_scene.add_child(cam)
	cam.global_position = _player.global_position + Vector2(60, 0)
	cam.make_current()
	await _wait_frames(30)
	var spawn_cd := 0.0
	var times: Array = []
	var procs: Array = []
	var frames := 0
	var last := Time.get_ticks_usec()
	while frames < 300:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000.0
		last = now
		spawn_cd -= dt / 1000.0
		if _kind.begins_with("proj") and spawn_cd <= 0.0:
			spawn_cd = 0.6
			var names: Array = PROJ if _kind == "proj" else [_kind.substr(5)]
			for i in range(_n):
				_fire_proj(names[i % names.size()], _player.global_position + Vector2(20, -80 + (i % 12) * 14))
		elif _kind == "totembolt" and spawn_cd <= 0.0:
			spawn_cd = 0.4
			var tgt := Node2D.new()
			_scene.add_child(tgt)
			tgt.global_position = _player.global_position + Vector2(160, 0)
			for i in range(_n):
				var b = load("res://scripts/fx_totem_fire_bolt.gd")
				b.spawn(_scene, _player.global_position + Vector2(0, -40 + i * 6), tgt, Color(1.0, 0.55, 0.25), 0.0)
			get_root_timer(tgt)
		elif _kind == "melek" and frames == 0:
			_player.skill_state = "active"
			_player.skill_timer = 6.0
			_player._skill_heal()
		if frames > 20:
			times.append(dt)
			procs.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		frames += 1
	times.sort()
	procs.sort()
	print("RESULT kind=%s n=%d  frame median=%.2f p95=%.2f  process median=%.2f p95=%.2f" % [_kind, _n, times[times.size() / 2], times[int(times.size() * 0.95)], procs[procs.size() / 2], procs[int(procs.size() * 0.95)]])
	quit()


func get_root_timer(n: Node) -> void:
	create_timer(0.8).timeout.connect(func(): if is_instance_valid(n): n.queue_free())


func _wait_frames(n: int) -> void:
	for i in range(n):
		await process_frame
