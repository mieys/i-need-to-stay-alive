extends SceneTree

## Aşama 4 - içerik / durum etkileri GERÇEK oyunda (ENEMY_WORLD=0 ve 1 ile ayrı ayrı koş, CONTENT satırlarını karşılaştır).
##   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/test_world_content.gd -Env "ENEMY_WORLD=1"
## Senaryolar (sırayla, aynı oyunda): durum etkileri (donma/kök/korku/yavaşlatma/geri itme/sersemletme, kontrol yaratığına
## göre 1 sn'lik yer değiştirme), boss (ölçek -> gövde yarıçapı C++'a ulaştı mı, oyuncuya yaklaşıyor mu), elit (yarıçap/
## hız), Ağacı Koru (yaratıklar ağaca gidip ağaca vuruyor mu), Alanı Güvenceye Al dalgası, Kopyanı Öldür (silahlar kopyaya
## isabet ediyor mu). Her satır: "CONTENT <ad> <değerler>"; sonda betik hatası yoksa "CONTENT_DONE".

var _gm: Node
var _player: Node2D
var _spawner: Node
var _next_id: int = 500000


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
	for w in _player.get("owned_weapon_nodes"):
		if is_instance_valid(w):
			w.queue_free()
	_clear()
	await _wait(0.3)
	print("CONTENT yol: ", "YENİ" if bool(load("res://scripts/enemy_world/enemy_world_config.gd").call("enabled")) else "ESKİ")
	await _status_effects()
	await _boss_and_elite()
	await _defend_tree()
	await _secure_wave()
	await _copy_mission()
	await _copy_separation()
	print("CONTENT_DONE")
	quit()


# ------------------------------------------------------------------ senaryolar

func _status_effects() -> void:
	_clear()
	await _wait(0.2)
	## 7 aynı tür yaratık oyuncudan 400 px uzakta, aynı açılarda
	var es: Array = []
	for i in 7:
		var a: float = float(i) / 7.0 * TAU
		var e: Node = _spawn("zombie1", 2, _player.global_position + Vector2.from_angle(a) * 400.0)
		e.set("max_health", 1.0e12); e.set("health", 1.0e12)
		es.append(e)
	await _wait(0.6)
	es[1].call("apply_freeze_full", 3.0)
	es[2].call("apply_root", 3.0)
	es[3].call("apply_fear", _player.global_position, 3.0)
	es[4].call("apply_slow", 0.5, 3.0)
	es[5].call("apply_stun", 3.0)
	es[6].call("apply_knockback_distance", ((es[6] as Node2D).global_position - _player.global_position).normalized(), 200.0)
	var p0: Array = es.map(func(e): return (e as Node2D).global_position)
	var d0: Array = es.map(func(e): return (e as Node2D).global_position.distance_to(_player.global_position))
	await _wait(1.0)
	var moved: Array = []
	var dd: Array = []
	for i in es.size():
		moved.append(snappedf((es[i] as Node2D).global_position.distance_to(p0[i]), 0.1))
		dd.append(snappedf((es[i] as Node2D).global_position.distance_to(_player.global_position) - d0[i], 0.1))
	## kontrol (0) normal yürür; donma(1)/kök(2)/sersem(5) ~0; korku(3) uzaklaşır (+); yavaş(4) ~kontrolün yarısı;
	## geri itme(6) önce geri sonra gelir
	print("CONTENT durum_1sn_yer_degistirme kontrol=%s donma=%s kok=%s korku=%s yavas=%s sersem=%s itme=%s" % moved)
	print("CONTENT durum_1sn_mesafe_degisimi kontrol=%s donma=%s kok=%s korku=%s yavas=%s sersem=%s itme=%s" % dd)
	await _wait(3.0)
	var moved2: Array = []
	var p1: Array = es.map(func(e): return (e as Node2D).global_position)
	await _wait(0.5)
	for i in es.size():
		moved2.append(snappedf((es[i] as Node2D).global_position.distance_to(p1[i]), 0.1))
	print("CONTENT durum_bitince_0.5sn kontrol=%s donma=%s kok=%s korku=%s yavas=%s sersem=%s itme=%s" % moved2)


func _boss_and_elite() -> void:
	_clear()
	await _wait(0.2)
	_spawner.call("_spawn_boss_group", ["golem1"], 6)
	await _wait(0.5)
	var boss: Node2D = null
	for b in get_nodes_in_group("boss"):
		boss = b
	var normal: Node2D = _spawn("golem1", 6, _player.global_position + Vector2(-500, 0))
	var elite: Node2D = _spawn("golem1", 6, _player.global_position + Vector2(0, 500))
	elite.call("make_elite")
	await _wait(0.5)
	var bd0: float = boss.global_position.distance_to(_player.global_position)
	var ed0: float = elite.global_position.distance_to(_player.global_position)
	var nd0: float = normal.global_position.distance_to(_player.global_position)
	await _wait(3.0)
	print("CONTENT boss yaricap=%.1f ew_yaricap=%s 3sn_yaklasma=%.0f bar_gorunur=%s" % [float(boss.get("_body_radius")),
			str(boss.get("_ew_sent_radius")), bd0 - boss.global_position.distance_to(_player.global_position),
			str(boss.get("_overhead_bar") != null and boss.get("_overhead_bar").visible)])
	print("CONTENT elit yaricap=%.1f ew_yaricap=%s normal_yaricap=%.1f 3sn_yaklasma elit=%.0f normal=%.0f" % [
			float(elite.get("_body_radius")), str(elite.get("_ew_sent_radius")), float(normal.get("_body_radius")),
			ed0 - elite.global_position.distance_to(_player.global_position), nd0 - normal.global_position.distance_to(_player.global_position)])


func _defend_tree() -> void:
	_clear()
	await _wait(0.2)
	var wem: Node = _find_by_method(current_scene, "debug_force_start_mission")
	var tree_pos: Vector2 = _player.global_position + Vector2(500, 0)
	for i in 20:
		if not _gm.call("is_position_blocked_by_forest", tree_pos):
			break
		tree_pos += Vector2(0, 40)
	var ok: bool = wem != null and bool(wem.call("debug_force_start_mission", "defend_tree", tree_pos))
	await _wait(1.0)
	var tree: Node2D = _gm.get("defend_tree_ref")
	if not ok or tree == null or not is_instance_valid(tree):
		print("CONTENT agac HATA görev başlamadı"); return
	var es: Array = []
	for i in 12:
		var e: Node = _spawn("zombie1", 2, _player.global_position + Vector2.from_angle(float(i) / 12.0 * TAU) * 350.0)
		e.set("max_health", 1.0e12); e.set("health", 1.0e12)
		es.append(e)
	var hp0: float = float(tree.get("health")) + float(tree.get("shield")) if tree.get("shield") != null else float(tree.get("health"))
	var t0: float = _avg_dist(es, tree.global_position)
	await _wait(8.0)
	var hp1: float = float(tree.get("health")) + float(tree.get("shield")) if tree.get("shield") != null else float(tree.get("health"))
	print("CONTENT agac ort_mesafe 0sn=%.0f 8sn=%.0f agac_hasar=%.0f oyuncuya_ort=%.0f" % [t0, _avg_dist(es, tree.global_position),
			hp0 - hp1, _avg_dist(es, _player.global_position)])
	## görevi kendi yolundan bitir (ağacı silmek world_event_manager.gd:429'da tipli değişkene silinmiş nesne hatası yağdırır)
	tree.set("is_dead", true)
	await _wait(0.5)


func _secure_wave() -> void:
	_clear()
	await _wait(0.2)
	var before: int = get_nodes_in_group("enemies").size()
	var n: int = int(_spawner.call("spawn_mission_wave", _player.global_position, 400.0, 10))
	await _wait(0.5)
	var reg: int = 0
	for e in get_nodes_in_group("enemies"):
		if int(e.get("_ew_slot")) >= 0:
			reg += 1
	var es: Array = get_nodes_in_group("enemies")
	var d0: float = _avg_dist(es, _player.global_position)
	await _wait(3.0)
	print("CONTENT dalga dogan=%d grup=%d c++_kayitli=%d 3sn_yaklasma=%.0f" % [n, get_nodes_in_group("enemies").size() - before,
			reg, d0 - _avg_dist(es, _player.global_position)])


func _copy_mission() -> void:
	_clear()
	await _wait(0.2)
	for k in ["tufek", "yay"]:
		_player.call("buy_weapon_copy", k, 3)
	var wem: Node = _find_by_method(current_scene, "debug_force_start_mission")
	var ok: bool = bool(wem.call("debug_force_start_mission", "kill_your_copy", _player.global_position + Vector2(250, 0)))
	await _wait(1.0)
	var copies: Array = get_nodes_in_group("mission_copies")
	var hp0: float = 0.0
	for c in copies:
		hp0 += float(c.get("health")) + float(c.get("item_shield_hp") if c.get("item_shield_hp") != null else 0.0)
	## kopyalar arasına sıradan yaratık da koy (C++'ta - get_enemies_near kopyaları da bulmalı)
	for i in 6:
		var e: Node = _spawn("zombie1", 2, _player.global_position + Vector2.from_angle(float(i)) * 300.0)
		e.set("max_health", 1.0e12); e.set("health", 1.0e12)
	await _wait(6.0)
	var hp1: float = 0.0
	var alive: int = 0
	for c in copies:
		if is_instance_valid(c):
			hp1 += float(c.get("health")) + float(c.get("item_shield_hp") if c.get("item_shield_hp") != null else 0.0)
			alive += 1
	var near: Array = load("res://scripts/enemy.gd").call("get_enemies_near", self, _player.global_position, 2000.0)
	var copies_in_near: int = near.filter(func(n): return is_instance_valid(n) and n.is_in_group("mission_copies")).size()
	print("CONTENT kopya basladi=%s kopya=%d 6sn_kopya_hasar=%.0f yasayan=%d get_enemies_near_kopya=%d" % [str(ok), copies.size(),
			hp0 - hp1, alive, copies_in_near])


## Görev kopyası itilmesi (enemy.gd ızgarası kopyayı da içeriyordu; yeni yolda C++ set_extra_bodies): kopyanın üstüne
## doğan yaratıklar 0,6 sn sonra kopyadan ne kadar uzakta.
func _copy_separation() -> void:
	var copies: Array = get_nodes_in_group("mission_copies").filter(func(c): return is_instance_valid(c) and c.get("is_dead") != true)
	if copies.is_empty():
		print("CONTENT kopya_itilme HATA kopya yok"); return
	var cp: Node2D = copies[0]
	var es: Array = []
	for i in 10:
		var e: Node = _spawn("zombie1", 2, cp.global_position + Vector2.from_angle(float(i) * 0.63) * 4.0)
		e.set("max_health", 1.0e12); e.set("health", 1.0e12)
		es.append(e)
	await _wait(0.6)
	var dmin: float = INF
	var dsum: float = 0.0
	for e in es:
		var d: float = (e as Node2D).global_position.distance_to(cp.global_position)
		dmin = minf(dmin, d)
		dsum += d
	print("CONTENT kopya_itilme 0.6sn en_yakin=%.1f ortalama=%.1f" % [dmin, dsum / float(es.size())])


# ------------------------------------------------------------------ yardımcılar

func _spawn(id: String, tier: int, pos: Vector2) -> Node:
	_next_id += 1
	var e: Node = _spawner.call("_spawn_creature", id, pos, _next_id)
	e.set_meta("spawn_tier", tier)
	e.call("apply_tier_scaling", tier)
	_spawner.call("_apply_global_buff", e)
	return e


func _clear() -> void:
	for e in get_nodes_in_group("enemies"):
		if not e.is_in_group("mission_copies"):
			e.queue_free()


func _avg_dist(list: Array, p: Vector2) -> float:
	var s: float = 0.0
	var c: int = 0
	for e in list:
		if is_instance_valid(e) and not e.get("is_dead"):
			s += (e as Node2D).global_position.distance_to(p)
			c += 1
	return s / maxf(1.0, float(c))


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
