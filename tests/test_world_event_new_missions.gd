extends Node

## Madde 496: 4 yeni görev (Yuvaları Kapat / Ritüeli Boz / Kaçan Hazine / Gezici Işık) + zindan haritalarında görev konumları.
## Tek oyunculu akış (host yolu), zindan kipinde tür süzgeci + ulaşılabilir konum + rota, görev hedefinin yaratık API'si eşliği.

const WEM: GDScript = preload("res://scripts/world_event_manager.gd")
const SpotsScript: GDScript = preload("res://scripts/mission_spots.gd")
const DungeonWorldScript: GDScript = preload("res://scripts/dungeon/dungeon_world.gd")
const DungeonDataScript: GDScript = preload("res://scripts/dungeon/dungeon_data.gd")
const TargetScript: GDScript = preload("res://scripts/mission_target.gd")
const NestScript: GDScript = preload("res://scripts/mission_nest.gd")
const CopyScript: GDScript = preload("res://scripts/mission_player_copy.gd")
const LightScript: GDScript = preload("res://scripts/mission_light.gd")
const RunnerScript: GDScript = preload("res://scripts/mission_treasure_runner.gd")
const DUNGEON_MAP := "batik_nekropol"

var _spawned: Array[Node] = []
var _completed: Array = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var in_limbo: bool = false
	var max_health: float = 100.0
	var taken: Array = []
	func take_damage(amount: float, _source: Node2D = null) -> void:
		taken.append(amount)
	func get_base_move_speed() -> float:
		return 252.0


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for n: Node in get_tree().get_nodes_in_group("mission_targets"):
		if is_instance_valid(n):
			n.free()
	for n: Node in get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("gold_drop.gd"):
			n.free()
	_completed.clear()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _on_completed(mid: int, kind: String, success: bool) -> void:
	_completed.append([mid, kind, success])


func _wem() -> Node:
	var w: Node = _track(WEM.new())
	add_child(w)
	if not NetworkManager.world_event_completed.is_connected(_on_completed):
		NetworkManager.world_event_completed.connect(_on_completed)
	return w


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	_track(p)
	p.global_position = pos
	return p


func _targets_of(mid: int) -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group("mission_targets"):
		if is_instance_valid(n) and int(n.get("mission_id")) == mid and n.get("is_dead") != true:
			out.append(n)
	return out


func _active_slot(w: Node, kind_name: String) -> Dictionary:
	for s: Dictionary in w.get("_slots"):
		if str(s.get("state", "")) == "active" and WEM.MISSION_KIND_NAMES.get(s.get("kind"), "") == kind_name:
			return s
	return {}


func _start(w: Node, kind_name: String, pos: Vector2) -> Dictionary:
	assert(w.call("debug_force_start_mission", kind_name, pos), "görev başladı: " + kind_name)
	await _frames(3)
	var s: Dictionary = _active_slot(w, kind_name)
	assert(not s.is_empty(), "aktif slot: " + kind_name)
	return s


## ------------------------------------------------------------------ zindan kipi
func _enter_dungeon_mode(map_id: String = DUNGEON_MAP) -> String:
	var prev: String = str(GameManager.selected_map)
	GameManager.selected_map = map_id
	DungeonWorldScript.reset()
	DungeonWorld.test_origin_px = Vector2.ZERO
	SpotsScript.reset()
	return prev


func _leave_dungeon_mode(prev: String) -> void:
	GameManager.selected_map = prev
	DungeonWorld.test_origin_px = null
	DungeonWorldScript.reset()
	SpotsScript.reset()


func test_dungeon_spots_are_reachable_open_floor() -> void:
	var prev: String = _enter_dungeon_mode()
	assert(SpotsScript.active(), "zindan biçimli harita kipi")
	var data: Resource = load("res://scenes/zindan/%s_data.tres" % DUNGEON_MAP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n_ok: int = 0
	for i in range(40):
		var p: Vector2 = SpotsScript.pick(rng, 64.0)
		assert(p != Vector2.ZERO, "konum bulundu")
		assert(SpotsScript.is_area_open(p, 64.0), "çevresi açık")
		for off: Vector2 in [Vector2.ZERO, Vector2(48, 0), Vector2(-48, 0), Vector2(0, 48), Vector2(0, -48)]:
			var c: Vector2i = DungeonWorldScript.cell_of(p + off)
			var code: int = data.call("cell_at", c)
			assert(code == DungeonDataScript.CELL_EMPTY or code == DungeonDataScript.CELL_HIDE, "zemin hücresi, kod %d @ %s" % [code, c])
		n_ok += 1
	assert(n_ok == 40)
	## doğuş hücresi ulaşılabilir, haritanın (0,0) köşesi (kaya) değil
	var sp: Vector2 = preload("res://scripts/map_profiles.gd").spawn_position()
	assert(SpotsScript.is_reachable_world(sp), "doğuş ulaşılabilir")
	assert(not SpotsScript.is_reachable_world(Vector2(2, 2)), "köşe kaya ulaşılamaz")
	_leave_dungeon_mode(prev)


func test_dungeon_route_stays_on_reachable_floor() -> void:
	var prev: String = _enter_dungeon_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var found: int = 0
	for k in range(6):
		var start: Vector2 = SpotsScript.pick(rng, 48.0)
		var t0: int = Time.get_ticks_msec()
		var route: PackedVector2Array = SpotsScript.route_from(rng, start, 1300.0, 2100.0)
		var ms: int = Time.get_ticks_msec() - t0
		assert(ms < 150, "rota bulma süresi makul (oyunda bir kez, görev başında): %d ms" % ms)
		if route.size() < 2:
			continue
		found += 1
		var length: float = 0.0
		for j in range(route.size() - 1):
			length += route[j].distance_to(route[j + 1])
			for s in range(21):
				var q: Vector2 = route[j].lerp(route[j + 1], float(s) / 20.0)
				assert(SpotsScript.is_reachable_world(q), "rota parçası zeminde: %s" % q)
		assert(length >= 1300.0 * 0.45, "rota yeterince uzun: %.0f" % length)
	assert(found >= 4, "rotaların çoğu bulundu: %d/6" % found)
	_leave_dungeon_mode(prev)


func test_dungeon_mode_skips_van_and_tree() -> void:
	var prev: String = _enter_dungeon_mode()
	var w: Node = _wem()
	var kinds: Array = w.call("_available_kinds")
	assert(not kinds.has(WEM.MissionKind.ESCORT_VAN) and not kinds.has(WEM.MissionKind.DEFEND_TREE), "zindanda konvoy/ağaç yok")
	for k in [WEM.MissionKind.CAPTURE_POINT, WEM.MissionKind.SECURE_AREA, WEM.MissionKind.COLLECT, WEM.MissionKind.KILL_YOUR_COPY,
			WEM.MissionKind.CLOSE_NESTS, WEM.MissionKind.BREAK_RITUAL, WEM.MissionKind.TREASURE_RUNNER, WEM.MissionKind.WANDERING_LIGHT]:
		assert(kinds.has(k), "zindanda var: %d" % k)
	assert(not w.call("debug_force_start_mission", "escort_van", Vector2(100, 100)), "zindanda debug konvoy reddedilir")
	## salon isteyen tür geniş zemin alır
	var p: Vector2 = w.call("_pick_mission_position", WEM.MissionKind.CAPTURE_POINT)
	assert(p != Vector2.ZERO and SpotsScript.is_area_open(p, 64.0), "bayrak salon/oda zemininde")
	## konum seçimi ucuz (kaçan hazine her karede soruyor)
	var rng := RandomNumberGenerator.new()
	var t0: int = Time.get_ticks_usec()
	for i in range(200):
		SpotsScript.pick(rng, 112.0)
		SpotsScript.is_reachable_world(p + Vector2(i, 0))
	var us: int = Time.get_ticks_usec() - t0
	assert(us < 60000, "200 seçim + yoklama: %d us" % us)
	_cleanup()
	_leave_dungeon_mode(prev)
	var w2: Node = _wem()
	assert((w2.call("_available_kinds") as Array).size() == 10, "ana haritada 10 tür")
	_cleanup()


## Üç seçilebilir zindan haritasında yuva / kristal yerleşimi: yürüme mesafesiyle (dar tünelli Lağım Ağı dahil) neredeyse hep tam sayı,
## her nokta ulaşılabilir açık zemin ve merkezden yürüme mesafesi sınırın içinde.
func test_dungeon_rings_fit_on_every_dungeon_map() -> void:
	for map_id: String in ["batik_nekropol", "taskin_hisar", "lagim_agi"]:
		var prev: String = _enter_dungeon_mode(map_id)
		var w: Node = _wem()
		var full_nests: int = 0
		var full_crystals: int = 0
		for k in range(12):
			var c: Vector2 = w.call("_pick_mission_position", WEM.MissionKind.CLOSE_NESTS)
			assert(c != Vector2.ZERO, "%s: merkez bulundu" % map_id)
			var ring: PackedVector2Array = w.call("_place_ring", c, WEM.NEST_COUNT, WEM.NEST_RING_MIN, WEM.NEST_RING_MAX, WEM.NEST_CLEARANCE, WEM.NEST_MIN_SPACING)
			if ring.size() >= WEM.NEST_COUNT:
				full_nests += 1
			for q: Vector2 in ring:
				assert(SpotsScript.is_area_open(q, WEM.NEST_CLEARANCE), "%s: yuva açık zeminde" % map_id)
			var c2: Vector2 = w.call("_pick_mission_position", WEM.MissionKind.BREAK_RITUAL)
			var cr: PackedVector2Array = w.call("_place_ring", c2, WEM.RITUAL_CRYSTALS, WEM.RITUAL_RING * 0.85, WEM.RITUAL_RING * 1.15, WEM.RITUAL_CRYSTAL_CLEARANCE, WEM.RITUAL_RING * 0.9)
			if cr.size() >= WEM.RITUAL_CRYSTALS:
				full_crystals += 1
		assert(full_nests >= 11, "%s: 3 yuva sığdı %d/12" % [map_id, full_nests])
		assert(full_crystals >= 11, "%s: 3 kristal sığdı %d/12" % [map_id, full_crystals])
		_cleanup()
		_leave_dungeon_mode(prev)


## ------------------------------------------------------------------ görev akışları (tek oyuncu, host yolu)
func test_close_nests_solo_success() -> void:
	var w: Node = _wem()
	_player(Vector2(20000, 20000))
	var s: Dictionary = await _start(w, "close_nests", Vector2(20000, 20000))
	var nests: Array = _targets_of(int(s["id"]))
	assert(nests.size() == WEM.NEST_COUNT, "3 yuva: %d" % nests.size())
	for n: Node2D in nests:
		var d: float = n.global_position.distance_to(Vector2(20000, 20000))
		assert(d >= WEM.NEST_RING_MIN * 0.5 and d <= WEM.NEST_RING_MAX + 1.0, "halkada: %.0f" % d)
		assert(n.is_in_group("enemies") and n.is_in_group("mission_copies"), "silahların vurduğu gruplarda")
		assert(float(n.get("max_health")) == WEM.NEST_FALLBACK_HP, "yaratık yokken yedek can")
	(nests[0] as Node).call("take_damage", 99999.0)
	await _frames(3)
	assert(_targets_of(int(s["id"])).size() == 2, "biri yıkıldı")
	assert(_completed.is_empty(), "henüz bitmedi")
	for n: Node in _targets_of(int(s["id"])):
		n.call("take_damage", 99999.0)
	await _frames(4)
	assert(_completed.size() == 1 and _completed[0][1] == "close_nests" and _completed[0][2] == true, "başarı: %s" % [_completed])
	_cleanup()


func test_break_ritual_fail_vanishes_crystals_and_success_path() -> void:
	var w: Node = _wem()
	_player(Vector2(24000, 24000))
	var s: Dictionary = await _start(w, "break_ritual", Vector2(24000, 24000))
	var crystals: Array = _targets_of(int(s["id"]))
	assert(crystals.size() == WEM.RITUAL_CRYSTALS, "3 kristal")
	assert(float(s["timer"]) <= WEM.RITUAL_DURATION, "ritüel süresi")
	## süre dolsun -> başarısız, kristaller söner (ölüm sayılmadan)
	for sl: Dictionary in w.get("_slots"):
		if sl.get("id") == s["id"]:
			sl["timer"] = 0.01
	await _frames(4)
	assert(_completed.size() == 1 and _completed[0][2] == false, "süre doldu = başarısız")
	await _frames(2)
	assert(_targets_of(int(s["id"])).is_empty(), "kristaller söndü")
	_completed.clear()
	var s2: Dictionary = await _start(w, "break_ritual", Vector2(26000, 24000))
	for c: Node in _targets_of(int(s2["id"])):
		c.call("take_damage", 99999.0)
	await _frames(4)
	assert(_completed.size() == 1 and _completed[0][2] == true, "kristaller kırıldı = başarı")
	_cleanup()


func test_treasure_runner_flees_drops_gold_and_escapes() -> void:
	var w: Node = _wem()
	var center := Vector2(30000, 30000)
	var p: FakePlayer = _player(center + Vector2(-150, 0))
	var s: Dictionary = await _start(w, "treasure_runner", center)
	var runners: Array = _targets_of(int(s["id"]))
	assert(runners.size() == 1, "tek hazine")
	var r: Node2D = runners[0]
	assert(float(r.get("base_speed")) == 252.0, "oyuncu taban hızı ölçüldü")
	var d0: float = r.global_position.distance_to(p.global_position)
	await get_tree().create_timer(0.6).timeout
	var d1: float = r.global_position.distance_to(p.global_position)
	assert(d1 > d0 + 40.0, "oyuncudan kaçıyor: %.0f -> %.0f" % [d0, d1])
	## canının yarısı -> 4 yığın altın
	r.call("take_damage", float(r.get("max_health")) * 0.5 + 0.1)
	assert(int(r.call("dropped_gold_total")) == 4 * RunnerScript.DROP_GOLD, "yarı can = 4 yığın: %d" % int(r.call("dropped_gold_total")))
	## süre dolunca kaçar (başarısız), saçılan altın yerde kalır
	for sl: Dictionary in w.get("_slots"):
		if sl.get("id") == s["id"]:
			sl["timer"] = 0.01
	await _frames(4)
	assert(_completed.size() == 1 and _completed[0][2] == false, "kaçtı = başarısız")
	var gold_drops: int = 0
	for n: Node in get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("gold_drop.gd"):
			gold_drops += 1
	assert(gold_drops >= 4, "yerde altın: %d" % gold_drops)
	_cleanup()


func test_treasure_runner_rests_so_solo_can_catch_it() -> void:
	var r: Node2D = _track(RunnerScript.new())
	add_child(r)
	r.global_position = Vector2(34000, 34000)
	r.call("setup", 1, 0, 500.0, 0.0, true)
	var p: FakePlayer = _player(Vector2(34000 - 120, 34000))
	## oyuncu peşinden koşsun: RUN_TIME sonra REST_TIME boyunca durmalı
	var rested: bool = false
	var t: float = 0.0
	while t < RunnerScript.RUN_TIME + RunnerScript.REST_TIME + 0.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		p.global_position = p.global_position.move_toward(r.global_position, 200.0 * get_physics_process_delta_time())
		if float(r.get("_rest_left")) > 0.0:
			rested = true
	assert(rested, "koştuktan sonra soluklanır")
	_cleanup()


func test_wandering_light_moves_only_with_player_inside() -> void:
	var w: Node = _wem()
	var start := Vector2(40000, 40000)
	var s: Dictionary = await _start(w, "wandering_light", start)
	assert((s["route"] as PackedVector2Array).size() >= 2, "rota var")
	await get_tree().create_timer(0.4).timeout
	var sl: Dictionary = _active_slot(w, "wandering_light")
	assert(float(sl["progress"]) == 0.0, "içinde kimse yokken durur")
	var pl: FakePlayer = _player(start)
	pl.in_limbo = true ## level/pazar menüsündeki oyuncu (madde 438) ışığı yürütmez
	await get_tree().create_timer(0.4).timeout
	sl = _active_slot(w, "wandering_light")
	assert(float(sl["progress"]) == 0.0, "menüdeki oyuncu sayılmaz")
	pl.in_limbo = false
	await get_tree().create_timer(0.5).timeout
	sl = _active_slot(w, "wandering_light")
	assert(float(sl["progress"]) > 5.0, "içinde oyuncu varken ilerler: %.1f" % float(sl["progress"]))
	_cleanup()


func test_light_darkness_spares_merchant_safe_zone() -> void:
	var l: Node2D = _track(LightScript.new())
	add_child(l)
	l.call("setup", 1, PackedVector2Array([Vector2(60000, 60000), Vector2(61000, 60000)]), 150.0, 620.0)
	var p: FakePlayer = _player(Vector2(60000 + 300, 60000))
	var was_active: bool = GameManager.merchant_zone_active
	var was_pos: Vector2 = GameManager.merchant_zone_pos
	GameManager.merchant_zone_active = true
	GameManager.merchant_zone_pos = p.global_position
	await get_tree().create_timer(LightScript.DARK_GRACE + LightScript.DARK_TICK + 0.4).timeout
	GameManager.merchant_zone_active = was_active
	GameManager.merchant_zone_pos = was_pos
	assert(p.taken.is_empty(), "güvenli alanda karanlık hasarı yok")
	_cleanup()


## Ritüel cezası eliti garanti elit sandık düşürmez (yoksa ritüeli bilerek kaybedip sandık kasılırdı); aynı rastgele tohumla meta'sız elitle farkı tam 1.
func test_ritual_punish_elite_has_no_guaranteed_chest() -> void:
	var queued: Array[int] = []
	for with_meta: bool in [false, true]:
		var e: Node2D = _track(preload("res://scenes/creatures/enemy_slime1.tscn").instantiate()) as Node2D
		add_child(e)
		e.global_position = Vector2(70000, 70000)
		await _frames(1)
		e.call("make_elite")
		if with_meta:
			e.set_meta(&"mission_elite", true)
		var before: int = Enemy._drop_spawn_queue.size()
		seed(4242)
		e.call("_drop_chest")
		queued.append(Enemy._drop_spawn_queue.size() - before)
		Enemy._drop_spawn_queue.clear()
	assert(queued[0] == queued[1] + 1, "ceza elitinde garanti sandık yok: %s" % [queued])
	assert(Enemy.weapon_shard_count(false, true, 0.0) >= Enemy.weapon_shard_count(false, false, 0.0), "elit parçacığı normalden az değil (kontrol)")
	_cleanup()


func test_light_darkness_damages_only_local_player_in_ring() -> void:
	var l: Node2D = _track(LightScript.new())
	add_child(l)
	l.call("setup", 1, PackedVector2Array([Vector2(50000, 50000), Vector2(51000, 50000)]), 150.0, 620.0)
	var p: FakePlayer = _player(Vector2(50000 + 300, 50000))
	await get_tree().create_timer(LightScript.DARK_GRACE + LightScript.DARK_TICK * 2.0 + 0.2).timeout
	assert(not p.taken.is_empty(), "karanlıkta hasar")
	assert(is_equal_approx(float(p.taken[0]), 100.0 * LightScript.DARK_DPS_RATIO * LightScript.DARK_TICK), "tik hasarı %s" % p.taken[0])
	p.taken.clear()
	p.global_position = Vector2(50000 + 60, 50000) ## ışığın içinde
	await get_tree().create_timer(LightScript.DARK_GRACE + 0.8).timeout
	assert(p.taken.is_empty(), "ışıkta hasar yok")
	p.global_position = Vector2(50000 + 900, 50000) ## halkanın dışında (görevden uzak)
	await get_tree().create_timer(LightScript.DARK_GRACE + 0.8).timeout
	assert(p.taken.is_empty(), "uzaktakine hasar yok")
	_cleanup()


## Madde 534: karanlık halka zemin sprite'ı değil EKRAN DÜZEYİNDE (dünyanın üstündeki CanvasLayer): halkadaki yaratık/oyuncu/efekt de kararır.
## Halka ekrandayken dörtgen görünür ve kameradan çözdüğü parametreleri alır; ekran dışındayken gizlenir (çizim yok).
func test_light_darkness_is_screen_level_and_follows_camera() -> void:
	var l: Node2D = _track(LightScript.new())
	add_child(l)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var near: Vector2 = vp_size * 0.5
	l.call("setup", 1, PackedVector2Array([near, near + Vector2(1000, 0)]), 150.0, 620.0)
	l.set("damage_enabled", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var layer: CanvasLayer = l.get("_dark_layer")
	var rect: ColorRect = l.get("_dark_rect")
	assert(layer != null and rect != null, "halka ekran katmanında")
	assert(layer.layer >= 1, "dünyanın (layer 0) üstünde: yaratık/oyuncu da kararır, layer %d" % layer.layer)
	assert(rect.visible, "halka ekrandayken çizilir")
	assert(rect.size.x >= 1.0 and rect.size.y >= 1.0, "dörtgen boş değil")
	assert(Rect2(Vector2.ZERO, vp_size).encloses(Rect2(rect.position, rect.size)), "dörtgen görünür alanın içinde (taşma yok)")
	var mat: ShaderMaterial = l.get("_ring_mat")
	assert((mat.get_shader_parameter("light_pos") as Vector2).is_equal_approx(l.global_position), "shader ışığın dünya konumunu alır")
	assert(is_equal_approx(float(mat.get_shader_parameter("view_zoom")), 1.0), "kamera ölçeği shader'a gider")
	## kamera kayarsa dörtgen ışıkla birlikte kayar (ekran konumu = dünya x kamera)
	var before: Vector2 = rect.position + rect.size * 0.5
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(-40.0, 0.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var after: Vector2 = rect.position + rect.size * 0.5
	get_viewport().canvas_transform = Transform2D.IDENTITY
	assert(absf((after.x - before.x) + 40.0) < 3.0, "dörtgen kamerayla kayar: %s -> %s" % [before, after])
	## ışık ekran dışına çıkınca (halka da dışarıda) dörtgen gizlenir
	l.call("setup", 1, PackedVector2Array([Vector2(60000, 60000), Vector2(61000, 60000)]), 150.0, 620.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not rect.visible, "halka ekran dışındayken çizilmez")
	_cleanup()


## ------------------------------------------------------------------ API eşliği
func test_mission_target_has_creature_api_of_copy() -> void:
	var have: Dictionary = {}
	for m: Dictionary in NestScript.get_script_method_list():
		have[str(m["name"])] = true
	var missing: Array = []
	for m: Dictionary in CopyScript.get_script_method_list():
		var nm: String = str(m["name"])
		if nm.begins_with("apply_") or nm.begins_with("is_") or nm in ["take_damage", "take_damage_host", "get_mark_damage_mult",
				"try_shaman_weapon_burn", "set_ability_invisible", "get_overhead_bar_offset"]:
			if not have.has(nm):
				missing.append(nm)
	assert(missing.is_empty(), "eksik yaratık API'si: %s" % [missing])
	var n: Node2D = _track(NestScript.new())
	add_child(n)
	n.call("setup", 3, 0, 100.0, 40.0, true)
	n.call("take_damage", 50.0)
	assert(float(n.get("shield")) < 40.0 and float(n.get("health")) < 100.0, "kalkan %80 emer, %20 cana")
	n.call("apply_element", "burn", {"tick": 5.0, "dur": 3.0})
	assert(n.call("is_burning"), "yanma işler")
	_cleanup()
