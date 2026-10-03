extends SceneTree

## Aşama 1 - GERÇEK oyunda eski yol / EnemyWorld A/B davranış karşılaştırması (aynı tohum, aynı senaryo).
## Gerçek menü akışı -> Main (Korsan), silah AÇIK (yaratıklar ölür), oyuncunun canı çok yüksek (ölmez ama hasar alır),
## doğal doğurma kapalı, BENCH_N yaratık (kademe BENCH_TIER rosteri, menzilliler dahil) 300-700 px halkada doğar.
## İlk yarı oyuncu durur, ikinci yarı kare çizerek yürür (duvar dolanma). Ölçülenler: yaklaşma, oyuncunun aldığı toplam
## hasar (yakın + menzilli), düşman mermisi sayısı, öldürme, orman duvarı içinde kalan yaratık, yürüme karesi ilerliyor
## mu, betik hatası (stderr'de "SCRIPT ERROR" ara).
##
##   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/test_world_ingame.gd -Env "ENEMY_WORLD=1"
##   (ENEMY_WORLD=0 ile aynı komut = eski yol; iki INGAME_RESULT satırını karşılaştır)
## Ortam: BENCH_N (150), BENCH_TIER (3), BENCH_SECS (20), BENCH_CHAR (9), BENCH_IDS (virgüllü yaratık id listesi - verilirse
## kademe rosteri yerine bunlar; ör. yetenekli aileler: hayalet1,vampire1,rontgen1,iblis1,agac1,zombie1)

var _n: int = int(OS.get_environment("BENCH_N")) if OS.get_environment("BENCH_N") != "" else 150
var _tier: int = int(OS.get_environment("BENCH_TIER")) if OS.get_environment("BENCH_TIER") != "" else 3
var _secs: float = float(OS.get_environment("BENCH_SECS")) if OS.get_environment("BENCH_SECS") != "" else 20.0
var _char: int = int(OS.get_environment("BENCH_CHAR")) if OS.get_environment("BENCH_CHAR") != "" else 9

var _kills: int = 0
var _projectiles: int = 0
var _damage_taken: float = 0.0
var _player_path: float = 0.0 ## oyuncunun yürüdüğü toplam yol (yaratıklar onu farklı engelliyor mu)
var _hit_area_entries: int = 0 ## eski yolda yaratık HitArea'sına oyuncu girişleri (temas zamanlayıcısı sıfırlaması; yeni yolda C++ sayar)
var _tick_start_us: int = 0
var _ticks := PackedFloat64Array()


## Fizik adımı süresi (bench_current.gd ile aynı yöntem): en düşük ve en yüksek öncelikli iki prob arası duvar saati.
class Probe extends Node:
	var bench: Object
	var is_start: bool = false
	func _physics_process(_d: float) -> void:
		if is_start:
			bench.set("_tick_start_us", Time.get_ticks_usec())
		else:
			var arr: PackedFloat64Array = bench.get("_ticks")
			arr.append(float(Time.get_ticks_usec() - int(bench.get("_tick_start_us"))) / 1000.0)
			bench.set("_ticks", arr)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float, walk: bool, player: Node2D = null) -> void:
	var t0: int = Time.get_ticks_msec()
	var dirs: Array[String] = ["move_right", "move_down", "move_left", "move_up"]
	var cur: String = ""
	var last_hp: float = float(player.get("health")) if player else 0.0
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		if walk and player:
			## Headless'ta Input.action_press oyuncuyu YÜRÜTMÜYOR (2026-10-03 ölçüldü: yol 0 px) - doğrudan taşı (150 px/sn,
			## orman duvarına girmeden), 2 sn'de bir yön değiştirerek kare çiz.
			var dv: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int((Time.get_ticks_msec() - t0) / 2000) % 4]
			var np: Vector2 = player.global_position + dv * 150.0 * minf(get_root().get_process_delta_time(), 0.1) ## gerçek zaman: FPS'ten bağımsız 150 px/sn
			if not root.get_node("GameManager").call("is_position_blocked_by_forest", np):
				player.global_position = np
		if player:
			_player_path += player.global_position.distance_to(player.get_meta("_t_last", player.global_position))
			player.set_meta("_t_last", player.global_position)
			var hp: float = float(player.get("health"))
			if hp < last_hp:
				_damage_taken += last_hp - hp
			last_hp = hp
		await process_frame
	if cur != "":
		Input.action_release(cur)


func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	current_scene.call("_on_character_pressed", _char)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	await _wait(1.0, false)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(0.5, false)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.0, false)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		print("INGAME HATA: Player yok"); quit(1); return
	for k in ["tufek", "yay", "tabanca"]:
		player.call("buy_weapon_copy", k, 3)
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	var gm: Node = root.get_node("GameManager")
	gm.connect("enemy_died", func(_p: Vector2) -> void: _kills += 1)
	current_scene.child_entered_tree.connect(func(c: Node) -> void:
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("enemy_projectile.gd"):
			_projectiles += 1)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3, false)
	var roster: Array = spawner.call("_spawnable_roster", _tier)
	if OS.get_environment("BENCH_IDS") != "":
		roster = Array(OS.get_environment("BENCH_IDS").split(","))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	seed(4242)
	var spawned: Array = []
	var ranged: int = 0
	for i in _n:
		var id: String = roster[rng.randi() % roster.size()]
		var pos: Vector2 = player.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 700.0)
		if gm.call("is_position_blocked_by_forest", pos):
			continue
		var e: Node = spawner.call("_spawn_creature", id, pos, 200000 + i)
		if e == null:
			continue
		e.set_meta("spawn_tier", _tier)
		e.call("apply_tier_scaling", _tier)
		spawner.call("_apply_global_buff", e)
		spawned.append(e)
		var ha: Area2D = e.get_node_or_null("HitArea") as Area2D
		if ha:
			ha.body_entered.connect(func(b: Node) -> void:
				if b.is_in_group("player"):
					_hit_area_entries += 1)
		if e.get("is_ranged"):
			ranged += 1
	await process_frame
	var bridge: Node = current_scene.get_node_or_null("EnemyWorldBridge")
	var weapons = player.get("owned_weapon_nodes")
	print("INGAME yaratık: %d (menzilli %d)  EnemyWorld: %s  silah: %d" % [spawned.size(), ranged, str(bridge != null), weapons.size() if weapons != null else -1])
	var d0: float = _avg_dist(spawned, player)
	var pa := Probe.new(); pa.bench = self; pa.is_start = true; pa.process_physics_priority = -1000000
	var pb := Probe.new(); pb.bench = self; pb.process_physics_priority = 1000000
	root.add_child(pa); root.add_child(pb)
	# yürüme karesi örnekleri (Sprite2D tabanlılar)
	var samples: Array = []
	for e in spawned:
		if samples.size() >= 20:
			break
		if e.get("frame_sprite") != null:
			samples.append(e)
	var frames0: Array = samples.map(func(e): return int(e.frame_sprite.frame))
	await _wait(_secs * 0.25, false, player)
	var frames1: Array = samples.map(func(e): return int(e.frame_sprite.frame) if is_instance_valid(e) else -1)
	var changed: int = 0
	for k in samples.size():
		if frames0[k] != frames1[k]:
			changed += 1
	var d1: float = _avg_dist(spawned, player)
	await _wait(_secs * 0.25, false, player)
	await _wait(_secs * 0.5, true, player)
	var alive: Array = spawned.filter(func(e): return is_instance_valid(e) and not e.get("is_dead"))
	var in_wall: int = 0
	for e in alive:
		if gm.call("is_position_blocked_by_forest", e.global_position):
			in_wall += 1
	var d2: float = _avg_dist(alive, player)
	var ev: String = str(bridge.get("event_counts")) if bridge != null else "-"
	print("INGAME ort. mesafe: başta %.0f  %.0f sn sonra %.0f  sonda %.0f | kare değişen %d/%d | olaylar %s" % [
		d0, _secs * 0.25, d1, d2, changed, samples.size(), ev])
	var tick_avg: float = 0.0
	for v in _ticks:
		tick_avg += v
	tick_avg /= maxf(1.0, float(_ticks.size()))
	var ew_enters: int = int(bridge.world.call("get_hit_enter_total")) if bridge != null else -1
	print("INGAME HitArea oyuncu girişi: eski yol (sinyal) %d, EnemyWorld (C++) %d  oyuncu collision_layer: %d" % [_hit_area_entries, ew_enters, int(player.get("collision_layer"))])
	## görüş sisi: yaratığın vision_fog_vis metası (yeni yolda C++ yazar) sisin GDScript kuralıyla aynı mı?
	var fog: Node = _find_by_method(current_scene, "_target_visibility")
	if fog != null and bool(fog.call("is_active")):
		var checked: int = 0
		var bad: int = 0
		var vis_bad: int = 0
		var no_meta: int = 0
		for e in get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.get("is_dead"):
				continue
			var gd: float = float(fog.call("_target_visibility", (e as Node2D).global_position))
			if not e.has_meta("vision_fog_vis"):
				if gd > 0.0:
					no_meta += 1
				continue
			checked += 1
			if absf(float(e.get_meta("vision_fog_vis")) - gd) > 0.15:
				bad += 1
			if (float(e.get_meta("vision_fog_vis")) > 0.02) != (e as Node2D).visible:
				vis_bad += 1
		## silah hedeflemesi: C++ query_nearest == eski GDScript algoritması (weapon.gd _get_nearest_enemy eski gövdesi)?
		if bridge != null:
			var vf: GDScript = load("res://scripts/vision_fog.gd")
			var rng2 := RandomNumberGenerator.new(); rng2.seed = 5
			var same: int = 0
			var diff: int = 0
			for k in 60:
				var o: Vector2 = player.global_position + Vector2(rng2.randf_range(-500, 500), rng2.randf_range(-400, 400))
				var old_best: Node2D = null
				var old_d: float = INF
				for e in get_nodes_in_group("enemies"):
					if not is_instance_valid(e) or e.get("is_dead") == true or not bool(vf.call("can_target", e)):
						continue
					var d: float = o.distance_to((e as Node2D).global_position)
					if d < old_d:
						old_d = d
						old_best = e
				var nb: Node2D = bridge.world.call("query_nearest", o, 0.5) as Node2D
				var nd: float = o.distance_to(nb.global_position) if nb != null else INF
				if nb == old_best or absf(nd - old_d) < 0.01:
					same += 1
				else:
					diff += 1
			print("INGAME hedefleme kontrol: aynı %d, farklı %d" % [same, diff])
		print("INGAME sis kontrol: %d yaratık, değer farkı>0.15: %d, görünürlük tutarsız: %d, görünmesi gereken ama metası yok: %d" % [checked, bad, vis_bad, no_meta])
	print("INGAME oyuncu yolu %.0f px, son konum %s" % [_player_path, str(player.global_position.round())])
	print("INGAME fizik adımı ort. %.2f ms (%d tik, silahlar + yaratıklar + oyuncu)" % [tick_avg, _ticks.size()])
	print("INGAME_RESULT ew=%d n=%d kills=%d damage_taken=%.0f projectiles=%d in_wall=%d alive=%d dist0=%.0f dist1=%.0f dist2=%.0f frames_changed=%d/%d" % [
		1 if bridge != null else 0, spawned.size(), _kills, _damage_taken, _projectiles, in_wall, alive.size(), d0, d1, d2,
		changed, samples.size()])
	quit()


func _avg_dist(list: Array, player: Node2D) -> float:
	var s: float = 0.0
	var c: int = 0
	for e in list:
		if is_instance_valid(e) and not e.get("is_dead"):
			s += (e as Node2D).global_position.distance_to(player.global_position)
			c += 1
	return s / maxf(1.0, float(c))


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
