extends SceneTree

## Aşama 0 - VERİ ODAKLI prototip, saf GDScript (docs/yaratik_yeniden_yazim/PLAN.md §4, §5).
## bench_current.gd ile AYNI iş yükünü düz dizilerle tek döngüde yapar; sonuçları kıyaslanır.
##
##   Godot --headless --path <proje> -s res://tools/enemy_rewrite/bench_soa_gd.gd
## Ortam: BENCH_N (200), BENCH_SECS (12), BENCH_WALK (1).
##
## Gerçek harita (scenes/harita_baked.tscn) yüklenir, EnemyPathing'in orman duvarı ızgarası okunur. Oyuncu bir kare çizerek
## yürür (bench_current ile aynı: 2 sn'de bir yön, ~150 px/sn). Her fizik tikinde, HER yaratık için:
##   - akış alanından yön (oyuncudan BFS; oyuncu hücre değiştirince yeniden, kare başına bütçeli, çift tampon)
##   - yakınsa doğrudan oyuncuya; saldırı menzilinde dur + bekleme sayacı
##   - itilme: uzamsal ızgara (32 px), 3x3 komşu kova
##   - duvar çarpışması: hedef hücre duvarsa eksen eksen kayma
##   - yavaşlatma sayacı, hız çarpanı
##   - görünüm: kendi Sprite2D'sinin konumu + yürüme karesi
## Ölçülen: simülasyon döngüsü (µs/yaratık), akış alanı güncellemesi (ms), görünüm güncellemesi dahil toplam tik.
##
## Çıktı son satırı: BENCH_RESULT n= sim_ms= sim_p95= view_ms= flow_ms= tick_ms= us_per_creature= (görünüm dahil)

const SEP_CELL := 32.0
const SEP_DIST := 22.0
const ATTACK_RANGE := 40.0
const FLOW_RADIUS_CELLS := 70 ## ~1100 dünya birimi (MAX_ROUTE_DISTANCE 1600'ün içinde)
const FLOW_BUDGET_CELLS := 2000 ## kare başına en fazla bu kadar hücre genişlet

var _n: int = int(OS.get_environment("BENCH_N")) if OS.get_environment("BENCH_N") != "" else 200
var _secs: float = float(OS.get_environment("BENCH_SECS")) if OS.get_environment("BENCH_SECS") != "" else 12.0
var _walk: bool = OS.get_environment("BENCH_WALK") != "0"


class Sim extends Node2D:
	# --- yaratık dizileri (SoA)
	var n: int = 0
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var speed := PackedFloat32Array()
	var radius := PackedFloat32Array()
	var slow_t := PackedFloat32Array()
	var atk_cd := PackedFloat32Array()
	var frame_t := PackedFloat32Array()
	var views: Array[Sprite2D] = []
	# --- oyuncu
	var player := Vector2.ZERO
	var walk: bool = true
	var walk_t: float = 0.0
	# --- harita ızgarası (EnemyPathing'den)
	var blocked := PackedByteArray()
	var g_origin := Vector2i.ZERO
	var g_size := Vector2i.ZERO
	var cell_world: float = 16.0
	var layer_origin := Vector2.ZERO
	# --- akış alanı (çift tampon): dist[i] = oyuncuya adım sayısı, 65535 = ulaşılmaz
	var flow_dist := PackedInt32Array()
	var flow_work := PackedInt32Array()
	## Nesil damgası: dizi her yeniden hesaplamada doldurulmaz; değer sadece damgası güncel nesle eşitse geçerli.
	var dist_stamp := PackedInt32Array()
	var work_stamp := PackedInt32Array()
	var dist_gen: int = 0
	var work_gen: int = 0
	var queue := PackedInt32Array()
	var q_head: int = 0
	var flow_center := Vector2i(-99999, -99999)
	var flow_building: bool = false
	var flow_target := Vector2i.ZERO
	# --- uzamsal ızgara
	var bucket_head := PackedInt32Array()
	var bucket_next := PackedInt32Array()
	var b_w: int = 0
	var b_h: int = 0
	var b_origin := Vector2.ZERO
	var used_buckets := PackedInt32Array()
	# --- ölçüm
	var recording: bool = false
	var sim_ms := PackedFloat64Array()
	var view_ms := PackedFloat64Array()
	var flow_ms := PackedFloat64Array()

	func setup_grid(bl: PackedByteArray, origin: Vector2i, size: Vector2i, cw: float, lo: Vector2) -> void:
		blocked = bl; g_origin = origin; g_size = size; cell_world = cw; layer_origin = lo
		flow_dist.resize(size.x * size.y); flow_work.resize(size.x * size.y)
		dist_stamp.resize(size.x * size.y); work_stamp.resize(size.x * size.y)
		queue.resize(size.x * size.y)
		b_w = int(ceil(float(size.x) * cw / SEP_CELL)) + 2
		b_h = int(ceil(float(size.y) * cw / SEP_CELL)) + 2
		b_origin = lo + Vector2(origin) * cw - Vector2(SEP_CELL, SEP_CELL)
		bucket_head.resize(b_w * b_h); bucket_head.fill(-1)

	func add(p: Vector2, tex: Texture2D, hf: int) -> void:
		pos.append(p); vel.append(Vector2.ZERO); speed.append(randf_range(40.0, 70.0)); radius.append(12.0)
		slow_t.append(0.0); atk_cd.append(0.0); frame_t.append(randf() * 6.0)
		bucket_next.append(-1)
		var s := Sprite2D.new(); s.texture = tex; s.hframes = hf; s.vframes = 4; s.position = p
		add_child(s); views.append(s)
		n += 1

	func cell_of(p: Vector2) -> Vector2i:
		var c := Vector2i(int(floor((p.x - layer_origin.x) / cell_world)), int(floor((p.y - layer_origin.y) / cell_world)))
		return c

	func solid(c: Vector2i) -> bool:
		var x: int = c.x - g_origin.x; var y: int = c.y - g_origin.y
		if x < 0 or y < 0 or x >= g_size.x or y >= g_size.y:
			return true
		return blocked[y * g_size.x + x] != 0

	# Akış alanı: oyuncu hücre değiştirince BFS baştan; kare başına FLOW_BUDGET_CELLS hücre; bitince tamponlar değişir.
	func step_flow() -> void:
		var pc: Vector2i = cell_of(player)
		if not flow_building and pc != flow_center:
			flow_building = true; flow_target = pc
			work_gen += 1
			q_head = 0
			var qi: int = 0
			var tx: int = pc.x - g_origin.x; var ty: int = pc.y - g_origin.y
			if tx >= 0 and ty >= 0 and tx < g_size.x and ty < g_size.y:
				var idx0: int = ty * g_size.x + tx
				flow_work[idx0] = 0; work_stamp[idx0] = work_gen; queue[0] = idx0; qi = 1
			queue.resize(maxi(queue.size(), 1))
			set_meta("q_tail", qi)
		if not flow_building:
			return
		var q_tail: int = int(get_meta("q_tail"))
		var w: int = g_size.x
		var budget: int = FLOW_BUDGET_CELLS
		var wg: int = work_gen
		while q_head < q_tail and budget > 0:
			var idx: int = queue[q_head]; q_head += 1; budget -= 1
			var d: int = flow_work[idx] + 1
			if d > FLOW_RADIUS_CELLS:
				continue
			var x: int = idx % w; var y: int = idx / w
			for k in 4:
				var nx: int = x + (1 if k == 0 else (-1 if k == 1 else 0))
				var ny: int = y + (1 if k == 2 else (-1 if k == 3 else 0))
				if nx < 0 or ny < 0 or nx >= w or ny >= g_size.y:
					continue
				var ni: int = ny * w + nx
				if blocked[ni] != 0 or (work_stamp[ni] == wg and flow_work[ni] <= d):
					continue
				flow_work[ni] = d; work_stamp[ni] = wg; queue[q_tail] = ni; q_tail += 1
		set_meta("q_tail", q_tail)
		if q_head >= q_tail:
			var t := flow_dist; flow_dist = flow_work; flow_work = t
			var ts := dist_stamp; dist_stamp = work_stamp; work_stamp = ts
			var tg: int = dist_gen; dist_gen = work_gen; work_gen = maxi(tg, dist_gen)
			flow_center = flow_target; flow_building = false

	func flow_dir(p: Vector2) -> Vector2:
		var c: Vector2i = cell_of(p)
		var x: int = c.x - g_origin.x; var y: int = c.y - g_origin.y
		if x < 1 or y < 1 or x >= g_size.x - 1 or y >= g_size.y - 1:
			return Vector2.ZERO
		var w: int = g_size.x
		var i: int = y * w + x
		var g: int = dist_gen
		if dist_stamp[i] != g:
			return Vector2.ZERO
		var best: int = flow_dist[i]
		var dir := Vector2.ZERO
		var j: int = i + 1
		if dist_stamp[j] == g and flow_dist[j] < best:
			best = flow_dist[j]
			dir = Vector2(1, 0)
		j = i - 1
		if dist_stamp[j] == g and flow_dist[j] < best:
			best = flow_dist[j]
			dir = Vector2(-1, 0)
		j = i + w
		if dist_stamp[j] == g and flow_dist[j] < best:
			best = flow_dist[j]
			dir = Vector2(0, 1)
		j = i - w
		if dist_stamp[j] == g and flow_dist[j] < best:
			dir = Vector2(0, -1)
		return dir

	func _physics_process(delta: float) -> void:
		# oyuncu yürüyüşü (bench_current ile aynı kare)
		if walk:
			walk_t += delta
			var k: int = int(walk_t / 2.0) % 4
			var d: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][k]
			var np: Vector2 = player + d * 150.0 * delta
			if not solid(cell_of(np)):
				player = np
		var t0: int = Time.get_ticks_usec()
		step_flow()
		var t1: int = Time.get_ticks_usec()
		# uzamsal ızgarayı kur
		for b in used_buckets:
			bucket_head[b] = -1
		used_buckets.resize(0)
		for i in n:
			var bp: Vector2 = pos[i] - b_origin
			var bx: int = clampi(int(bp.x / SEP_CELL), 0, b_w - 1); var by: int = clampi(int(bp.y / SEP_CELL), 0, b_h - 1)
			var bi: int = by * b_w + bx
			if bucket_head[bi] == -1:
				used_buckets.append(bi)
			bucket_next[i] = bucket_head[bi]; bucket_head[bi] = i
		# yaratık döngüsü
		var sep2: float = SEP_DIST * SEP_DIST
		var lox: float = layer_origin.x; var loy: float = layer_origin.y; var cw: float = cell_world
		var gox: int = g_origin.x; var goy: int = g_origin.y; var gw: int = g_size.x; var gh: int = g_size.y
		for i in n:
			var p: Vector2 = pos[i]
			var to_p: Vector2 = player - p
			var dist: float = to_p.length()
			var want := Vector2.ZERO
			if dist < ATTACK_RANGE:
				atk_cd[i] = maxf(0.0, atk_cd[i] - delta)
				if atk_cd[i] <= 0.0:
					atk_cd[i] = 1.2
			elif dist < 120.0:
				want = to_p / dist
			else:
				want = flow_dir(p)
				if want == Vector2.ZERO:
					want = to_p / dist
			# itilme
			var push := Vector2.ZERO
			var bp2: Vector2 = p - b_origin
			var bx2: int = int(bp2.x / SEP_CELL); var by2: int = int(bp2.y / SEP_CELL)
			for oy in range(-1, 2):
				var yy: int = by2 + oy
				if yy < 0 or yy >= b_h:
					continue
				for ox in range(-1, 2):
					var xx: int = bx2 + ox
					if xx < 0 or xx >= b_w:
						continue
					var j: int = bucket_head[yy * b_w + xx]
					while j != -1:
						if j != i:
							var dv: Vector2 = p - pos[j]
							var d2: float = dv.length_squared()
							if d2 < sep2 and d2 > 0.0001:
								push += dv / sqrt(d2) * (1.0 - sqrt(d2) / SEP_DIST)
						j = bucket_next[j]
			var sp: float = speed[i] * (0.5 if slow_t[i] > 0.0 else 1.0)
			slow_t[i] = maxf(0.0, slow_t[i] - delta)
			var v: Vector2 = want * sp + push * 60.0
			# duvar: eksen eksen (satır içi - GDScript'te fonksiyon çağrısı pahalı)
			var np2: Vector2 = p + v * delta
			var cx: int = int(floor((np2.x - lox) / cw)) - gox
			var cy: int = int(floor((p.y - loy) / cw)) - goy
			if cx < 0 or cy < 0 or cx >= gw or cy >= gh or blocked[cy * gw + cx] != 0:
				np2.x = p.x
				cx = int(floor((np2.x - lox) / cw)) - gox
			cy = int(floor((np2.y - loy) / cw)) - goy
			if cx < 0 or cy < 0 or cx >= gw or cy >= gh or blocked[cy * gw + cx] != 0:
				np2.y = p.y
			pos[i] = np2
			vel[i] = v
			frame_t[i] += delta * 8.0
		var t2: int = Time.get_ticks_usec()
		# görünüm
		for i in n:
			var s: Sprite2D = views[i]
			s.position = pos[i]
			var vv: Vector2 = vel[i]
			var row: int = (0 if vv.y > 0.0 else 1) if absf(vv.y) > absf(vv.x) else (3 if vv.x > 0.0 else 2)
			s.frame = row * s.hframes + int(frame_t[i]) % s.hframes
		var t3: int = Time.get_ticks_usec()
		if recording:
			flow_ms.append(float(t1 - t0) / 1000.0)
			sim_ms.append(float(t2 - t1) / 1000.0)
			view_ms.append(float(t3 - t2) / 1000.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
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
	var sim := Sim.new()
	sim.walk = _walk
	sim.setup_grid(EP.get("_blocked"), EP.get("_origin"), EP.get("_size"), cw, lo)
	main.add_child(sim)
	# oyuncuyu açık bir yere koy (bench_current'teki ev çıkışına yakın: Player main.tscn konumu)
	sim.player = Vector2(3016, 1920)
	var tries: int = 0
	while sim.solid(sim.cell_of(sim.player)) and tries < 200:
		sim.player += Vector2(16, 0); tries += 1
	var tex: Texture2D = load("res://visuals/Yaratıklar/Tüm Yaratıklar/Zombie 1/PNG/Zombie1/With_shadow/Zombie1_Walk_with_shadow.png")
	var rng := RandomNumberGenerator.new(); rng.seed = 12345
	var placed: int = 0
	while placed < _n:
		var p: Vector2 = sim.player + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 900.0)
		if sim.solid(sim.cell_of(p)):
			continue
		sim.add(p, tex, 6)
		placed += 1
	print("BENCH soa_gd yaratık: ", sim.n, "  hücre: ", cw, " dünya  ızgara: ", sim.g_size)
	var a := Time.get_ticks_msec()
	while Time.get_ticks_msec() - a < 2000:
		await process_frame
	sim.recording = true
	a = Time.get_ticks_msec()
	while Time.get_ticks_msec() - a < int(_secs * 1000.0):
		await process_frame
	sim.recording = false
	var s_avg: float = _avg(sim.sim_ms); var v_avg: float = _avg(sim.view_ms); var f_avg: float = _avg(sim.flow_ms)
	var tick: float = s_avg + v_avg + f_avg
	print("BENCH soa_gd: sim %.3f ms (p95 %.3f)  görünüm %.3f ms  akış %.3f ms (en kötü %.3f)  tik %d" % [
		s_avg, _p95(sim.sim_ms), v_avg, f_avg, _max(sim.flow_ms), sim.sim_ms.size()])
	print("BENCH_RESULT n=%d sim_ms=%.3f sim_p95=%.3f view_ms=%.3f flow_ms=%.3f flow_max=%.3f tick_ms=%.3f us_per_creature=%.2f" % [
		sim.n, s_avg, _p95(sim.sim_ms), v_avg, f_avg, _max(sim.flow_ms), tick, (s_avg + v_avg) * 1000.0 / maxf(1.0, float(sim.n))])
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
