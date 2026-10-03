extends SceneTree

## Aşama 0 - C++ prototipinin ölçümü (bench_soa_cpp/ GDExtension "EnemySimBench"). bench_soa_gd.gd ile AYNI senaryo:
## gerçek harita ızgarası, oyuncu kare çizerek yürür, her yaratık için bir Sprite2D görünümü. Simülasyon C++'ta; görünüm
## güncellemesi (konum + yön/kare) GDScript'te (gerçek EnemyWorld'de bu da C++'a / RenderingServer'a alınabilir).
##
##   Godot --headless --path <proje> -s res://tools/enemy_rewrite/bench_soa_cpp.gd     (önce --import: eklenti kaydı)
## NOT (2026-10-03): Aşama 0 bitince prototip eklentinin kaydı KAPATILDI (oyun/dışa aktarım her açılışta yüklemesin):
## tekrar koşmak için bench_soa_cpp/enemy_sim_bench.gdextension.off -> .gdextension yap, --import, sonra geri al.
## Ortam: BENCH_N (200), BENCH_SECS (12), BENCH_WALK (1).
## Çıktı son satırı: BENCH_RESULT n= sim_ms= sim_p95= view_ms= flow_ms= flow_max= tick_ms= us_per_creature= sim_us_per_creature=

var _n: int = int(OS.get_environment("BENCH_N")) if OS.get_environment("BENCH_N") != "" else 200
var _secs: float = float(OS.get_environment("BENCH_SECS")) if OS.get_environment("BENCH_SECS") != "" else 12.0
var _walk: bool = OS.get_environment("BENCH_WALK") != "0"


class Driver extends Node2D:
	var sim: Object
	var views: Array[Sprite2D] = []
	var player := Vector2.ZERO
	var walk: bool = true
	var walk_t: float = 0.0
	var frame_t: float = 0.0
	var solid_fn: Callable
	var recording: bool = false
	var sim_ms := PackedFloat64Array()
	var flow_ms := PackedFloat64Array()
	var view_ms := PackedFloat64Array()

	func _physics_process(delta: float) -> void:
		if walk:
			walk_t += delta
			var k: int = int(walk_t / 2.0) % 4
			var d: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][k]
			var np: Vector2 = player + d * 150.0 * delta
			if not solid_fn.call(np):
				player = np
		sim.call("set_player", player)
		sim.call("step", delta)
		var t2: int = Time.get_ticks_usec()
		var pos: PackedVector2Array = sim.call("get_positions")
		var vel: PackedVector2Array = sim.call("get_velocities")
		frame_t += delta * 8.0
		var f: int = int(frame_t)
		for i in views.size():
			var s: Sprite2D = views[i]
			s.position = pos[i]
			var vv: Vector2 = vel[i]
			var row: int = (0 if vv.y > 0.0 else 1) if absf(vv.y) > absf(vv.x) else (3 if vv.x > 0.0 else 2)
			s.frame = row * 6 + (f + i) % 6
		var t3: int = Time.get_ticks_usec()
		if recording:
			var ms: Dictionary = sim.call("get_last_ms")
			flow_ms.append(float(ms["flow_ms"]))
			sim_ms.append(float(ms["sim_ms"]))
			view_ms.append(float(t3 - t2) / 1000.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not ClassDB.class_exists("EnemySimBench"):
		print("BENCH HATA: EnemySimBench sınıfı yok - önce --import çalıştır (eklenti kaydı)")
		quit(1); return
	var main := Node2D.new(); main.name = "Main"; root.add_child(main); current_scene = main
	var harita: Node = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	main.add_child(harita)
	await process_frame
	var EP: GDScript = load("res://scripts/enemy_pathing.gd")
	EP.call("prepare")
	if not EP.call("_ensure_grid"):
		print("BENCH HATA: orman ızgarası kurulamadı"); quit(1); return
	var layer: TileMapLayer = EP.get("_layer")
	var cw: float = float(layer.tile_set.tile_size.x) * layer.global_scale.x
	var lo: Vector2 = layer.global_position
	var blocked: PackedByteArray = EP.get("_blocked")
	var g_origin: Vector2i = EP.get("_origin")
	var g_size: Vector2i = EP.get("_size")
	var solid := func(p: Vector2) -> bool:
		var cx: int = int(floor((p.x - lo.x) / cw)) - g_origin.x
		var cy: int = int(floor((p.y - lo.y) / cw)) - g_origin.y
		if cx < 0 or cy < 0 or cx >= g_size.x or cy >= g_size.y:
			return true
		return blocked[cy * g_size.x + cx] != 0
	var sim: Object = ClassDB.instantiate("EnemySimBench")
	sim.call("setup_grid", blocked, g_origin, g_size, cw, lo)
	main.add_child(sim as Node)
	var drv := Driver.new()
	drv.sim = sim; drv.walk = _walk; drv.solid_fn = solid
	drv.player = Vector2(3016, 1920)
	var tries: int = 0
	while solid.call(drv.player) and tries < 200:
		drv.player += Vector2(16, 0); tries += 1
	main.add_child(drv)
	var tex: Texture2D = load("res://visuals/Yaratıklar/Tüm Yaratıklar/Zombie 1/PNG/Zombie1/With_shadow/Zombie1_Walk_with_shadow.png")
	var rng := RandomNumberGenerator.new(); rng.seed = 12345
	var placed: int = 0
	while placed < _n:
		var p: Vector2 = drv.player + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 900.0)
		if solid.call(p):
			continue
		sim.call("add", p, randf_range(40.0, 70.0))
		var s := Sprite2D.new(); s.texture = tex; s.hframes = 6; s.vframes = 4; s.position = p
		drv.add_child(s); drv.views.append(s)
		placed += 1
	print("BENCH soa_cpp yaratık: ", sim.call("get_count"))
	var a := Time.get_ticks_msec()
	while Time.get_ticks_msec() - a < 2000:
		await process_frame
	drv.recording = true
	a = Time.get_ticks_msec()
	while Time.get_ticks_msec() - a < int(_secs * 1000.0):
		await process_frame
	drv.recording = false
	var s_avg: float = _avg(drv.sim_ms); var v_avg: float = _avg(drv.view_ms); var f_avg: float = _avg(drv.flow_ms)
	print("BENCH soa_cpp: sim %.3f ms (p95 %.3f)  görünüm %.3f ms  akış %.3f ms (en kötü %.3f)  tik %d" % [
		s_avg, _p95(drv.sim_ms), v_avg, f_avg, _max(drv.flow_ms), drv.sim_ms.size()])
	print("BENCH_RESULT n=%d sim_ms=%.3f sim_p95=%.3f view_ms=%.3f flow_ms=%.3f flow_max=%.3f tick_ms=%.3f us_per_creature=%.2f sim_us_per_creature=%.3f" % [
		placed, s_avg, _p95(drv.sim_ms), v_avg, f_avg, _max(drv.flow_ms), s_avg + v_avg + f_avg,
		(s_avg + v_avg) * 1000.0 / maxf(1.0, float(placed)), s_avg * 1000.0 / maxf(1.0, float(placed))])
	quit()


func _avg(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += v
	return s / a.size()


func _p95(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = Array(a)
	s.sort()
	return float(s[int(floor(0.95 * (s.size() - 1)))])


func _max(a: PackedFloat64Array) -> float:
	var m: float = 0.0
	for v in a:
		m = maxf(m, v)
	return m
