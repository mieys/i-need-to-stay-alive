extends SceneTree

## Aşama 1 - gerçek EnemyWorld (gdextension/enemy_world) ölçümü + doğruluk kontrolü. bench_soa_cpp.gd ile aynı harita /
## yaratık yerleşimi; görünüm (konum + yön/kare) bu kez C++'tan yazılıyor (write_views), GDScript döngüsü yok.
##
##   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/bench_world.gd -Env @{BENCH_N='1000'}
## Ortam:
##   BENCH_MODE  perf (varsayılan): oyuncu kare çizerek yürür, step süresi ölçülür.
##               check: oyuncu durur; BENCH_SECS sonunda doğruluk ölçütleri (aşağıda) + CHECK_RESULT satırı.
##   BENCH_N (200), BENCH_SECS (12), BENCH_SEED (12345)
## Çıktı son satırı: BENCH_RESULT ... ya da CHECK_RESULT ... (+ CHECK PASS/FAIL)

var _mode: String = OS.get_environment("BENCH_MODE") if OS.get_environment("BENCH_MODE") != "" else "perf"
var _n: int = int(OS.get_environment("BENCH_N")) if OS.get_environment("BENCH_N") != "" else 200
var _secs: float = float(OS.get_environment("BENCH_SECS")) if OS.get_environment("BENCH_SECS") != "" else 12.0
var _seed: int = int(OS.get_environment("BENCH_SEED")) if OS.get_environment("BENCH_SEED") != "" else 12345

const PLAYER_BODY := 11.4


class Driver extends Node2D:
	var world: Object
	var player := Vector2.ZERO
	var walk: bool = true
	var walk_t: float = 0.0
	var recording: bool = false
	var step_ms := PackedFloat64Array()
	var view_ms := PackedFloat64Array()
	var events := {0: 0, 1: 0, 2: 0}

	func _physics_process(delta: float) -> void:
		if walk:
			walk_t += delta
			var k: int = int(walk_t / 2.0) % 4
			var d: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][k]
			var np: Vector2 = player + d * 150.0 * delta
			if not world.call("is_solid_at", np):
				player = np
		world.call("set_targets", PackedVector2Array([player]), PackedInt32Array([0]), PackedByteArray([1]),
				PackedByteArray([0]), PackedFloat32Array([PLAYER_BODY]), PackedFloat32Array([0.0]), PackedInt64Array([1]))
		world.call("step", delta)
		var ev: PackedInt32Array = world.call("pop_events")
		var j: int = 0
		while j < ev.size():
			events[ev[j]] = int(events[ev[j]]) + 1
			j += 3
		if recording:
			step_ms.append(float(world.call("get_last_step_ms")))
			view_ms.append(float(world.call("get_last_view_ms")))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if not ClassDB.class_exists("EnemyWorld"):
		print("BENCH HATA: EnemyWorld sınıfı yok - önce --import çalıştır (eklenti kaydı)")
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
	var world: Node = ClassDB.instantiate("EnemyWorld")
	world.call("set_grid", EP.get("_blocked"), EP.get("_origin"), EP.get("_size"), cw, lo)
	world.call("set_body_block_scale", 1.0)
	main.add_child(world)
	print("BENCH ızgara hücre %.1f px, boyut %s" % [cw, str(EP.get("_size"))])

	# C++ ile GDScript (enemy_pathing.gd) düz çizgi kontrolü aynı sonucu veriyor mu - rastgele 2000 çift
	var rng := RandomNumberGenerator.new(); rng.seed = _seed
	var mismatch: int = 0
	var blocked_pairs: int = 0
	for k in 2000:
		var a := Vector2(rng.randf_range(1500, 4500), rng.randf_range(800, 3000))
		var b: Vector2 = a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(50, 900)
		var g: bool = EP.call("line_blocked", a, b)
		var c: bool = world.call("is_line_blocked", a, b)
		if g:
			blocked_pairs += 1
		if g != c:
			mismatch += 1
	print("CHECK düz çizgi C++ vs GDScript: %d / 2000 farklı (%d engelli çift)" % [mismatch, blocked_pairs])

	var drv := Driver.new()
	drv.world = world; drv.walk = _mode != "check"
	drv.player = Vector2(3016, 1920)
	var tries: int = 0
	while world.call("is_solid_at", drv.player) and tries < 200:
		drv.player += Vector2(16, 0); tries += 1
	main.add_child(drv)
	var tex: Texture2D = load("res://visuals/Yaratıklar/Tüm Yaratıklar/Zombie 1/PNG/Zombie1/With_shadow/Zombie1_Walk_with_shadow.png")
	var placed: int = 0
	var start_blocked: Array[int] = []
	var start_dist := PackedFloat32Array()
	while placed < _n:
		var p: Vector2 = drv.player + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 900.0)
		if world.call("is_solid_at", p):
			continue
		var s := Sprite2D.new(); s.texture = tex; s.hframes = 6; s.vframes = 4; s.position = p
		drv.add_child(s)
		var slot: int = world.call("add_enemy", s, s, p, {"radius": rng.randf_range(12.0, 20.0),
				"speed": rng.randf_range(40.0, 70.0), "contact_interval": 1.0, "cols": 6, "fps": 8.0})
		if world.call("is_line_blocked", p, drv.player):
			start_blocked.append(slot)
		start_dist.append(p.distance_to(drv.player))
		placed += 1
	print("BENCH world yaratık: %d (başta düz çizgisi kapalı: %d)" % [int(world.call("get_count")), start_blocked.size()])

	var a_ms := Time.get_ticks_msec()
	if _mode != "check":
		while Time.get_ticks_msec() - a_ms < 2000:
			await process_frame
	drv.recording = true
	a_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - a_ms < int(_secs * 1000.0):
		await process_frame
	drv.recording = false

	var avg: float = _avg(drv.step_ms)
	print("BENCH world: step %.3f ms (p95 %.3f, en kötü %.3f)  tik %d  olay melee=%d baloncuk=%d hayalet=%d" % [
		avg, _p95(drv.step_ms), _max(drv.step_ms), drv.step_ms.size(), drv.events[0], drv.events[1], drv.events[2]])
	var vavg: float = _avg(drv.view_ms)
	print("BENCH_RESULT n=%d step_ms=%.3f step_p95=%.3f step_max=%.3f view_ms=%.3f us_per_creature=%.3f sim_us_per_creature=%.3f" % [
		placed, avg, _p95(drv.step_ms), _max(drv.step_ms), vavg, avg * 1000.0 / maxf(1.0, float(placed)),
		(avg - vavg) * 1000.0 / maxf(1.0, float(placed))])

	if _mode == "check":
		var pos: PackedVector2Array = world.call("get_positions")
		var in_wall: int = 0
		var near: int = 0
		var moved_closer: int = 0
		for i in placed:
			if world.call("is_solid_at", pos[i]):
				in_wall += 1
			var d: float = pos[i].distance_to(drv.player)
			if d < 200.0:
				near += 1
			if d < start_dist[i] - 50.0:
				moved_closer += 1
		var blk_near: int = 0
		var blk_stuck := PackedVector2Array()
		for i in start_blocked:
			if pos[i].distance_to(drv.player) < 250.0:
				blk_near += 1
			else:
				blk_stuck.append(pos[i])
		# en yakın komşu mesafesi (itilme çalışıyor mu): çok yakın (< 4 px) çift sayısı
		var tight: int = 0
		for i in placed:
			for j in range(i + 1, placed):
				if pos[i].distance_squared_to(pos[j]) < 16.0:
					tight += 1
		print("CHECK duvar içinde: %d  oyuncuya <200 px: %d/%d  yaklaşan: %d  düz çizgisi kapalı başlayıp <250 px'e ulaşan: %d/%d  <4 px çift: %d" % [
			in_wall, near, placed, moved_closer, blk_near, start_blocked.size(), tight])
		if blk_stuck.size() > 0:
			print("CHECK ulaşamayan (ilk 8): ", Array(blk_stuck).slice(0, 8))
		print("CHECK_RESULT line_mismatch=%d in_wall=%d near=%d moved_closer=%d blocked_reached=%d blocked_total=%d tight_pairs=%d melee=%d" % [
			mismatch, in_wall, near, moved_closer, blk_near, start_blocked.size(), tight, drv.events[0]])
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
