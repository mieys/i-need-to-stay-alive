extends Node

## Kenar bekçileri (2026-10-09): bkz. scripts/guard_camps.gd + C++ EnemyWorld.set_dormant/set_goal. Gerçek C++ yaratık + sahte oyuncu.
## Kural: uykuda kampta gezinir (oyuncuyu hedeflemez); oyuncuyu GÖRÜNCE kovalar (ve kampındakileri uyandırır); göremeyince MEMORY sn sonra son görülen yeri arar,
## sonra kampına döner ve uykuya yatar; çalıda saklı oyuncuyu göremez.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const GuardScript: GDScript = preload("res://scripts/guard_camps.gd")
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const DT := 1.0 / 30.0

var _spawned: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var brush_state: int = 0


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_track(p)
	return p


func _guard(pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.speed = 90.0
	_track(e)
	return e


func _mgr() -> Node:
	var m: Node = GuardScript.new()
	add_child(m)
	m.set_physics_process(false)
	m._inited = true
	_track(m)
	return m


## `seconds` sn dünyayı adımlar; her 0,2 sn yönetici kararı çalışır. on_tick(t) her kararda çağrılır.
func _run(mgr: Node, seconds: float, on_tick: Callable = Callable()) -> void:
	var b: Node = EnemyWorldBridgeScript._instance
	assert(b != null, "EnemyWorld köprüsü yok")
	b.set_physics_process(false)
	var t: float = 0.0
	var since: float = 0.0
	while t < seconds:
		b._physics_process(DT)
		t += DT
		since += DT
		if since >= 0.2:
			since = 0.0
			mgr.tick(0.2)
			if on_tick.is_valid():
				on_tick.call(t)
	b.set_physics_process(true)


func test_idle_guard_ignores_far_players_but_chases_one_in_sight() -> void:
	var player: FakePlayer = _player(Vector2(2000.0, 2000.0))
	var home := Vector2(1000.0, 1000.0)
	var g: Node2D = _guard(home)
	await get_tree().process_frame
	var mgr: Node = _mgr()
	var camp := {"def": {}}
	mgr.register_guard(g, camp)
	_run(mgr, 8.0)
	assert(mgr.state_of(g) == GuardScript.S.IDLE, "Uzak oyuncu bekçiyi uyandırmamalı: %d" % mgr.state_of(g))
	assert(g.global_position.distance_to(home) < GuardScript.PATROL_RADIUS + 60.0, "Uykudaki bekçi kampında gezinir: %.0f" % g.global_position.distance_to(home))
	assert(g.global_position.distance_to(player.global_position) > 1000.0, "Uyku: oyuncuya gitmemeli")
	player.global_position = g.global_position + Vector2(250.0, 0.0)
	_run(mgr, 0.6)
	assert(mgr.state_of(g) == GuardScript.S.CHASE, "Görüş içindeki oyuncuyu görünce kovalamalı: %d" % mgr.state_of(g))
	_run(mgr, 6.0)
	assert(g.global_position.distance_to(player.global_position) < 100.0, "Kovalayan bekçi oyuncuya ulaşmalı: %.0f" % g.global_position.distance_to(player.global_position))
	_cleanup()


func test_lost_player_is_searched_then_guard_returns_home_and_sleeps() -> void:
	var home := Vector2(1000.0, 1000.0)
	var g: Node2D = _guard(home)
	var player: FakePlayer = _player(home + Vector2(250.0, 0.0))
	await get_tree().process_frame
	var mgr: Node = _mgr()
	mgr.register_guard(g, {"def": {}})
	_run(mgr, 1.0)
	assert(mgr.state_of(g) == GuardScript.S.CHASE, "uyandı")
	player.global_position = Vector2(3000.0, 3000.0) ## görüşten çıktı
	var seen: Dictionary = {}
	_run(mgr, 40.0, func(_t: float) -> void: seen[mgr.state_of(g)] = true)
	assert(seen.has(GuardScript.S.CHASE), "Görüşten çıkınca bir süre takip sürmeli")
	assert(seen.has(GuardScript.S.SEARCH), "Takipten sonra son görülen yeri aramalı")
	assert(seen.has(GuardScript.S.RETURN), "Aramadan sonra kampına dönmeli")
	assert(mgr.state_of(g) == GuardScript.S.IDLE, "Sonunda uykuya dönmeli: %d" % mgr.state_of(g))
	assert(g.global_position.distance_to(home) < 160.0, "Kampında olmalı: %.0f" % g.global_position.distance_to(home))
	_cleanup()


func test_waking_guard_alerts_its_camp_mates_and_hidden_players_are_not_seen() -> void:
	var home := Vector2(1000.0, 1000.0)
	var a: Node2D = _guard(home)
	var b: Node2D = _guard(home + Vector2(-120.0, 0.0)) ## oyuncuyu görmez (uzak) ama aynı kamp
	var player: FakePlayer = _player(home + Vector2(250.0, 0.0))
	await get_tree().process_frame
	var mgr: Node = _mgr()
	var camp := {"def": {}}
	mgr.register_guard(a, camp)
	mgr.register_guard(b, camp)
	player.brush_state = 1 ## çalıda SAKLI
	_run(mgr, 1.0)
	assert(mgr.state_of(a) == GuardScript.S.IDLE and mgr.state_of(b) == GuardScript.S.IDLE, "Saklı oyuncuyu bekçi göremez")
	player.brush_state = 0
	_run(mgr, 0.8)
	assert(mgr.state_of(a) == GuardScript.S.CHASE, "a oyuncuyu gördü")
	assert(mgr.state_of(b) == GuardScript.S.CHASE, "Aynı kamptaki arkadaş da uyanmalı (b: %d)" % mgr.state_of(b))
	_cleanup()


## Sağ alt tehlikeli bölge (2026-10-14): "alert" 0 olan kampta uyanan bekçi arkadaşlarını ÇAĞIRMAZ - yalnız oyuncuyu kendi gören bekçiler kovalar.
func test_alert_zero_camp_wakes_only_the_guards_that_see_the_player() -> void:
	var home := Vector2(1000.0, 1000.0)
	var a: Node2D = _guard(home)
	var b: Node2D = _guard(home + Vector2(-250.0, 0.0)) ## oyuncuyu görmez (500 px; gezinme payı 85 -> en az 415 > SIGHT 340) ama aynı kamp
	var c: Node2D = _guard(home + Vector2(60.0, 40.0)) ## oyuncuyu görür (190 px)
	var player: FakePlayer = _player(home + Vector2(250.0, 0.0))
	await get_tree().process_frame
	var mgr: Node = _mgr()
	var camp := {"def": {"alert": 0.0}}
	mgr.register_guard(a, camp)
	mgr.register_guard(b, camp)
	mgr.register_guard(c, camp)
	_run(mgr, 1.0)
	assert(mgr.state_of(a) == GuardScript.S.CHASE and mgr.state_of(c) == GuardScript.S.CHASE, "Oyuncuyu gören bekçiler kovalamalı")
	assert(mgr.state_of(b) == GuardScript.S.IDLE, "Görmeyen arkadaş uyanmamalı (alert 0): %d" % mgr.state_of(b))
	player.global_position = home + Vector2(-100.0, 0.0) ## b artık görür (150 px)
	_run(mgr, 0.6)
	assert(mgr.state_of(b) == GuardScript.S.CHASE, "b oyuncuyu görünce kendisi kovalamalı")
	_cleanup()


## Kampın "ahead" tablosu: olasılıklar doğru dağılır; tablo yoksa hep 0 (kenar kampları aynı kademeden).
func test_roll_ahead_follows_camp_table() -> void:
	var mgr: Node = _mgr()
	assert(mgr._roll_ahead({}) == 0, "tablosu olmayan kamp aynı kademeden doğar")
	var counts: Dictionary = {0: 0, 1: 0, 2: 0}
	var def := {"ahead": [0.4, 0.2]}
	for i in range(4000):
		counts[mgr._roll_ahead(def)] += 1
	assert(absf(float(counts[2]) / 4000.0 - 0.2) < 0.04, "+2 kademe oranı ~%20: %s" % str(counts))
	assert(absf(float(counts[1]) / 4000.0 - 0.4) < 0.04, "+1 kademe oranı ~%40: %s" % str(counts))
	assert(mgr._roll_ahead({"ahead": [0.0, 0.0]}) == 0, "sıfır olasılık hep 0")
	_cleanup()


## Sağ alt kamplar tabloda: hepsi alert 0 + ahead tanımlı, bekçi sayısı eskisinden (29) çok fazla; kenar kamplarında ikisi de yok.
func test_south_east_camps_are_dangerous_and_edge_camps_unchanged() -> void:
	var se_total: int = 0
	for def: Dictionary in GuardScript.CAMPS:
		if String(def["name"]).begins_with("GD-"):
			se_total += int(def["count"])
			assert(float(def.get("alert", -1.0)) == 0.0 and (def.get("ahead", []) as Array).size() == 2, "%s: alert 0 + ahead tablosu olmalı" % def["name"])
		else:
			assert(not def.has("alert") and not def.has("ahead"), "%s: kenar kampı değişmemeli" % def["name"])
	assert(se_total >= 90, "sağ alt bekçi sayısı çok olmalı: %d" % se_total)


## spawn_guard(pos, tiers_ahead): bekçi o anki kademenin tiers_ahead ötesinin rosterinden doğar (15'te kısılır); 0 = eskisi gibi.
func test_spawn_guard_draws_from_tiers_ahead() -> void:
	var spawner: Node = preload("res://scripts/enemy_spawner.gd").new()
	add_child(spawner)
	_track(spawner)
	var base: int = spawner._resolve_spawn_tier()
	if base <= 0:
		base = spawner._current_tier()
	for ahead in [0, 1, 2]:
		var want_tier: int = mini(base + ahead, 15)
		var roster: Array = spawner._spawnable_roster(want_tier)
		assert(not roster.is_empty(), "roster boş: kademe %d" % want_tier)
		for i in range(12):
			var g: Node = spawner.spawn_guard(Vector2(500.0 + float(i) * 20.0, 500.0), ahead)
			assert(g != null, "bekçi doğmadı (ahead %d)" % ahead)
			_track(g)
			assert(roster.has(String(g.get_meta("creature_id", ""))), "ahead %d: %s kademe %d rosterinde değil" % [ahead, g.get_meta("creature_id", ""), want_tier])
			assert(g.is_in_group("guards"), "bekçi 'guards' grubunda olmalı")
	_cleanup()
