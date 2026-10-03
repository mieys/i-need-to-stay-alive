extends SceneTree

## Aşama 2 "grup taramaları" doğrulaması - scripts/enemy_world/enemy_query.gd (EnemyQuery.candidates) GERÇEK oyunda.
##   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/test_enemy_query.gd -Env "ENEMY_WORLD=1"
## Ortam: QUERY_N (800) yaratık (karışık aileler + 2 boss + 6 elit golem), 2 sn yürürler, bir kısmı öldürülür (ölüm animasyonu).
## Kontroller (her biri "QUERY <ad> ..." satırı, sonda "QUERY_RESULT PASS|FAIL"):
##  1) üst küme: 500 rastgele (merkez, yarıçap) için eski tam taramanın bulduğu HER canlı yaratık (merkezi yarıçap içinde,
##     is_dead değil) candidates() sonucunda da var mı (çağıranlar süzgeçlerini aynen uyguladığı için yeterli koşul),
##  2) en büyük canlı gövde yarıçapı < EnemyQuery.BODY_PAD (gövdeyi hesaba katan çağıranların payı),
##  3) görev kopyası sorguda dönüyor mu (Kopyanı Öldür görevi açılırsa),
##  4) süre: "en yakın, R içinde" seçicisi tam tarama vs candidates (1000 çağrı).
## ENEMY_WORLD=0'da candidates() tüm grubu döner -> üst küme kontrolü kendiliğinden geçer (eski yol değişmedi kontrolü).

## preload DEĞİL: -s betiği autoload'lardan önce derlenir, köprü (GameManager kullanır) o an derlenemez -> _run'da load().
var EnemyQuery: Variant
const IDS := ["zombie1", "rat2", "ork3", "golem1", "slime4", "vampire2", "hayalet1", "iblis2", "demon1", "agac1", "lich2", "mantar3"]

var _gm: Node
var _player: Node2D
var _spawner: Node
var _next_id: int = 600000
var _fail: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	current_scene.call("_on_character_pressed", 9)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	await _wait(1.0)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(0.5)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.0)
	_player = current_scene.get_node_or_null("Player") as Node2D
	_spawner = current_scene.get_node_or_null("EnemySpawner")
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	EnemyQuery = load("res://scripts/enemy_world/enemy_query.gd")
	var on_new: bool = bool(load("res://scripts/enemy_world/enemy_world_config.gd").call("enabled"))
	print("QUERY yol: ", "YENİ" if on_new else "ESKİ")

	seed(4242)
	var n: int = int(OS.get_environment("QUERY_N")) if OS.get_environment("QUERY_N") != "" else 800
	for i in n:
		var pos: Vector2 = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(150.0, 1600.0)
		var e: Node = _spawn(IDS[i % IDS.size()], 1 + i % 8, pos)
		e.set("max_health", 1.0e12); e.set("health", 1.0e12)
	_spawner.call("_spawn_boss_group", ["golem1"], 6)
	_spawner.call("_spawn_boss_group", ["ork3"], 8)
	for i in 6:
		var el: Node = _spawn("golem1", 8, _player.global_position + Vector2.from_angle(float(i)) * 700.0)
		el.call("make_elite")
	await _wait(2.0)
	## bir kısmını öldür -> ölüm animasyonu sırasında grupta is_dead olarak kalırlar
	var killed: int = 0
	for e in get_nodes_in_group("enemies"):
		if killed >= 40:
			break
		e.set("health", 1.0)
		e.call("take_damage", 1.0e9)
		killed += 1
	await _wait(0.1)

	## 1) üst küme
	var all: Array = get_nodes_in_group("enemies")
	var alive: Array = all.filter(func(e): return is_instance_valid(e) and e.get("is_dead") != true)
	var dying: int = all.size() - alive.size()
	var missing: int = 0
	var checked: int = 0
	var sum_cand: int = 0
	var sum_true: int = 0
	for k in 500:
		var c: Vector2 = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 1500.0)
		var r: float = [24.0, 60.0, 140.0, 300.0, 600.0, 1300.0][k % 6] * randf_range(0.8, 1.2)
		var cand: Array = EnemyQuery.candidates(self, c, r)
		sum_cand += cand.size()
		for e in alive:
			if (e as Node2D).global_position.distance_to(c) <= r:
				sum_true += 1
				checked += 1
				if not cand.has(e):
					missing += 1
	print("QUERY ust_kume canli=%d olen=%d kontrol=%d eksik=%d ort_aday=%.1f ort_gercek=%.1f" % [alive.size(), dying, checked,
			missing, float(sum_cand) / 500.0, float(sum_true) / 500.0])
	if missing > 0:
		_fail += 1

	## 2) gövde payı
	var max_r: float = 0.0
	for e in alive:
		max_r = maxf(max_r, float(e.get("_body_radius")))
	print("QUERY govde_payi en_buyuk_govde=%.1f pay=%.1f" % [max_r, EnemyQuery.BODY_PAD])
	if max_r >= EnemyQuery.BODY_PAD:
		_fail += 1

	## 4) süre: "R içinde en yakın" (silah/evcil hayvan seçicilerinin kalıbı)
	var origins: Array = []
	for k in 1000:
		origins.append(_player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 900.0))
	var t0: int = Time.get_ticks_usec()
	var a1: Array = []
	for o in origins:
		a1.append(_nearest_in(get_nodes_in_group("enemies"), o, 400.0))
	var t1: int = Time.get_ticks_usec()
	var a2: Array = []
	for o in origins:
		a2.append(_nearest_in(EnemyQuery.candidates(self, o, 401.0), o, 400.0))
	var t2: int = Time.get_ticks_usec()
	var same: int = 0
	for k in origins.size():
		if a1[k] == a2[k]:
			same += 1
	print("QUERY sure_1000_cagri tam_tarama=%.2f ms aday=%.2f ms ayni_sonuc=%d/1000" % [float(t1 - t0) / 1000.0,
			float(t2 - t1) / 1000.0, same])
	if same != origins.size():
		_fail += 1

	## 3) görev kopyası
	var wem: Node = _find_by_method(current_scene, "debug_force_start_mission")
	if wem != null and bool(wem.call("debug_force_start_mission", "kill_your_copy", _player.global_position + Vector2(300, 0))):
		await _wait(1.5)
		var copies: Array = get_nodes_in_group("mission_copies")
		var found: int = 0
		for cp in copies:
			if EnemyQuery.candidates(self, (cp as Node2D).global_position, 50.0).has(cp):
				found += 1
		print("QUERY gorev_kopyasi kopya=%d sorguda=%d" % [copies.size(), found])
		if found != copies.size():
			_fail += 1
	else:
		print("QUERY gorev_kopyasi görev başlatılamadı (atlandı)")

	print("QUERY_RESULT ", "PASS" if _fail == 0 else "FAIL (%d)" % _fail)
	quit()


func _nearest_in(list: Array, o: Vector2, r: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = r
	for e in list:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = o.distance_to((e as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _spawn(id: String, tier: int, pos: Vector2) -> Node:
	_next_id += 1
	var e: Node = _spawner.call("_spawn_creature", id, pos, _next_id)
	e.set_meta("spawn_tier", tier)
	e.call("apply_tier_scaling", tier)
	_spawner.call("_apply_global_buff", e)
	return e


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		paused = false
		await process_frame


func _find_by_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method)
		if r:
			return r
	return null
