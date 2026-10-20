extends Node

## EV KUŞATMASI + AÇILIŞ (2026-10-19, madde 313): ev canı süreyle (evde 10 sn'den uzun kalınca sn'de 1, 5 dk), dışarıda savaşırken onarım,
## yıkılış/açılış, babaanne canı + kalıcı ölüm, çatlak aşamaları, açılış evreleri (huzur -> geri sayım -> saldırı; yaratık/saat kapısı),
## babaannenin evreye göre işi (endişe / pencere / kuşatmada endişe), oyuncunun açılış yeri.

const HouseInteriorScript: GDScript = preload("res://scripts/house_interior.gd")
const SiegeScript: GDScript = preload("res://scripts/house_siege.gd")
const IntroScript: GDScript = preload("res://scripts/house_intro.gd")
const DamageFxScript: GDScript = preload("res://scripts/house_damage_fx.gd")
const BabaanneScript: GDScript = preload("res://scripts/babaanne_npc.gd")
const FakePlayerScript = preload("res://tests/test_babaanne.gd").FakePlayer

var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	GameManager.invasion_pending = false
	GameManager.babaanne_target = null
	GameManager.babaanne_dead = false


func _siege() -> HouseSiege:
	var s: HouseSiege = _track(SiegeScript.new())
	add_child(s)
	s.set_process(false)
	return s


func _run(s: HouseSiege, seconds: float, inside: Array, outside: Array = []) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		s.step(1.0, inside, outside)
		t += 1.0


# ------------------------------------------------------------------ ev canı

func test_drain_starts_after_10s_inside_and_lasts_5_minutes() -> void:
	var s: HouseSiege = _siege()
	var p: Node = _track(Node.new())
	_run(s, 9.0, [p])
	assert(is_equal_approx(s.hp, SiegeScript.MAX_HP) and not s.under_attack, "ilk 10 sn ev canı azalmaz: %s" % s.hp)
	_run(s, 2.0, [p])
	assert(s.under_attack and s.hp < SiegeScript.MAX_HP, "10 sn'yi geçince saldırı başlar")
	var collapsed_at: float = -1.0
	var hits: Array = []
	s.collapsed_changed.connect(func(c: bool) -> void: hits.append(c))
	for i in 400:
		s.step(1.0, [p], [])
		if s.collapsed:
			collapsed_at = 11.0 + float(i + 1)
			break
	assert(collapsed_at > 0.0, "ev sonunda yıkılır")
	assert(absf(collapsed_at - 310.0) <= 2.0, "evde beklemeyle 5 dk (10 sn + 300 sn) dayanır: %s" % collapsed_at)
	assert(hits == [true], "yıkılış sinyali bir kez: %s" % [hits])
	assert(not s.under_attack and s.hp == 0.0, "yıkılınca saldırı durumu biter")
	_cleanup()


func test_drain_rate_is_independent_of_player_count_and_timer_resets_on_exit() -> void:
	var s: HouseSiege = _siege()
	var a: Node = _track(Node.new())
	var b: Node = _track(Node.new())
	_run(s, 20.0, [a, b])
	var two: float = SiegeScript.MAX_HP - s.hp
	var s2: HouseSiege = _siege()
	_run(s2, 20.0, [a])
	assert(is_equal_approx(two, SiegeScript.MAX_HP - s2.hp), "iki oyuncu bir oyuncuyla aynı hızda yıpratır")
	## çıkıp tekrar giren: süre sıfırdan
	var s3: HouseSiege = _siege()
	_run(s3, 8.0, [a])
	_run(s3, 1.0, [])
	_run(s3, 8.0, [a])
	assert(is_equal_approx(s3.hp, SiegeScript.MAX_HP), "kısa girip çıkmak saldırı başlatmaz (kesintisiz 10 sn)")
	_cleanup()


func test_regen_only_when_nobody_inside_and_fighting_outside_then_reopens() -> void:
	var s: HouseSiege = _siege()
	var p: Node = _track(Node.new())
	s.hp = 50.0
	s.test_combat = 0
	_run(s, 10.0, [], [p])
	assert(is_equal_approx(s.hp, 50.0), "dışarıda savaş yokken onarılmaz")
	s.test_combat = 1
	_run(s, 10.0, [], [p])
	assert(is_equal_approx(s.hp, 50.0 + 10.0 * SiegeScript.REGEN_PER_SEC), "savaşırken yavaşça onarılır: %s" % s.hp)
	_run(s, 3.0, [p], [p])
	assert(is_equal_approx(s.hp, 50.0 + 10.0 * SiegeScript.REGEN_PER_SEC), "biri içerideyken onarım yok")
	## yıkık ev %40'ta açılır
	s.hp = 0.0
	s._apply_collapsed(true)
	var opened: Array = []
	s.collapsed_changed.connect(func(c: bool) -> void: opened.append(c))
	var secs: int = 0
	while s.collapsed and secs < 1000:
		s.step(1.0, [], [p])
		secs += 1
	assert(not s.collapsed and opened == [false], "onarılınca kapı açılır")
	assert(absf(float(secs) - SiegeScript.MAX_HP * SiegeScript.REOPEN_RATIO / SiegeScript.REGEN_PER_SEC) <= 2.0,
			"sıfırdan açılış ~8 dk savaş: %d sn" % secs)
	_cleanup()


func test_smithy_interior_is_not_the_house() -> void:
	var s: HouseSiege = _siege()
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.is_indoors = true
	p.add_to_group("player")
	add_child(p)
	p.global_position = HouseInterior.INTERIOR_OFFSET
	assert(HouseSiege.in_house(p), "ev iç mekanındaki oyuncu evde sayılır")
	p.global_position = HouseSiege.SMITHY_INTERIOR_OFFSET
	assert(not HouseSiege.in_house(p) and HouseSiege.in_smithy(p), "demircideki oyuncu evde sayılmaz")
	assert(not s._living_players(true).has(p) and not s._living_players(false).has(p), "demirci iki listeye de girmez")
	for i in 30:
		s.step(1.0, s._living_players(true), s._living_players(false))
	assert(not s.under_attack and is_equal_approx(s.hp, SiegeScript.MAX_HP), "demircide ev canı azalmaz")
	_cleanup()


func test_invasion_pending_freezes_siege_and_game_clock() -> void:
	var s: HouseSiege = _siege()
	GameManager.invasion_pending = true
	s.set_process(true)
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.is_indoors = true
	p.add_to_group("player")
	add_child(p)
	for i in 30:
		s._process(1.0)
	assert(is_equal_approx(s.hp, SiegeScript.MAX_HP), "açılışta ev yıpranmaz")
	var t0: float = GameManager.game_time
	GameManager._process(5.0)
	assert(is_equal_approx(GameManager.game_time, t0), "açılış sürerken oyun saati işlemez")
	GameManager.invasion_pending = false
	GameManager._process(5.0)
	assert(GameManager.game_time > t0, "saldırı başlayınca saat işler")
	GameManager.game_time = t0
	_cleanup()


func test_client_applies_host_state_and_collapse_event() -> void:
	var s: HouseSiege = _siege()
	var got: Array = []
	s.collapsed_changed.connect(func(c: bool) -> void: got.append(c))
	var attacks: Array = []
	s.attack_started.connect(func() -> void: attacks.append(1))
	s.apply_state(120.0, SiegeScript.F_ATTACK)
	assert(is_equal_approx(s.hp, 120.0) and s.under_attack and attacks.size() == 1, "durum paketi uygulanır")
	s.apply_state(0.0, SiegeScript.F_COLLAPSED)
	assert(s.collapsed and got == [true], "yıkılış bayrağı olay olarak işlenir")
	s.apply_state(130.0, 0)
	assert(not s.collapsed and got == [true, false], "açılış")
	_cleanup()


# ------------------------------------------------------------------ babaanne canı

func test_granny_damage_and_permanent_death() -> void:
	var s: HouseSiege = _siege()
	var seen: Array = []
	s.granny_hp_changed.connect(func(h: float, d: bool) -> void: seen.append([h, d]))
	s.granny_damage(30.0)
	assert(is_equal_approx(s.granny_hp, 70.0) and not s.granny_dead, "can 100'den düşer")
	s.granny_damage(80.0)
	assert(s.granny_dead and s.granny_hp == 0.0 and GameManager.babaanne_dead, "ölüm kalıcı (GameManager'a da)")
	s.granny_damage(10.0)
	s._set_granny(100.0, false)
	assert(s.granny_dead and s.granny_hp == 0.0, "ölmüş babaanne dirilmez / iyileşmez")
	assert(seen.size() == 2 and seen[1] == [0.0, true], "sinyaller: %s" % [seen])
	_cleanup()


func test_grandma_goes_outside_is_targetable_takes_damage_and_dies() -> void:
	var w: Node2D = _track(Node2D.new())
	add_child(w)
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var bab: BabaanneNpc = house.get_babaanne()
	var siege: HouseSiege = house.get_siege()
	assert(bab != null and siege != null and house.get_intro() != null and house.get_damage_fx() != null, "kuşatma düğümleri kuruldu")
	assert(siege.name == "HouseSiege" and house.get_intro().name == "HouseIntro", "RPC yolları sabit adlarla")
	bab.go_outside(w, Vector2(1000.0, 1000.0))
	assert(bab.outside and bab.get_parent() == w and GameManager.babaanne_target == bab, "dışarıda, yaratıklar hedefler")
	assert((bab.feet() - Vector2(1000.0, 1000.0)).length() < 0.5, "kapının yanında durur")
	bab.take_damage(40.0, null)
	assert(is_equal_approx(siege.granny_hp, 60.0), "vuruş babaanne canından düşer: %s" % siege.granny_hp)
	bab.take_damage(70.0, null)
	assert(bab.is_dead and GameManager.babaanne_target == null and GameManager.babaanne_dead, "öldü, hedef değil")
	assert(bab.current_clip().begins_with("death_"), "ölüm klibi: %s" % bab.current_clip())
	assert(not bab.can_talk(p), "ölüyle konuşulmaz")
	## eve dönüş: yaşayan babaanne
	_cleanup()


func test_grandma_comes_home_when_house_reopens() -> void:
	var w: Node2D = _track(Node2D.new())
	add_child(w)
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var bab: BabaanneNpc = house.get_babaanne()
	bab.go_outside(w, Vector2(500.0, 500.0))
	bab.come_home(Vector2(520.0, 480.0))
	assert(GameManager.babaanne_target == null, "eve yönelince hedef olmaktan çıkar")
	for i in 80:
		bab._process(0.1)
	assert(not bab.outside and bab.get_parent() == house._interior_instance, "kapıya varınca içeri girer")
	_cleanup()


# ------------------------------------------------------------------ görseller

func test_cracks_appear_in_order_and_grow_as_hp_drops() -> void:
	const F = DamageFxScript
	for i in F.CRACK_AT.size():
		assert(F.crack_stage(i, 1.0) == -1, "tam canda çatlak yok")
		assert(F.crack_stage(i, 0.0) == 2, "yıkıkken hepsi tam boy")
	var prev: int = 0
	for k in range(100, -1, -5):
		var n: int = 0
		for i in F.CRACK_AT.size():
			if F.crack_stage(i, k / 100.0) >= 0:
				n += 1
		assert(n >= prev, "can düştükçe çatlak sayısı azalmaz")
		prev = n
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var fx: HouseDamageFx = house.get_damage_fx()
	var slots: Array[Vector2] = fx.crack_slots()
	assert(slots.size() >= 6, "duvar yüzünde çatlak yeri bulundu: %d" % slots.size())
	for q: Vector2 in slots:
		assert(q.y >= 32.0 and q.y < 240.0, "çatlak duvarda (zemin değil): %s" % q)
	house.get_siege().hp = 0.3 * SiegeScript.MAX_HP
	fx._process(0.3)
	assert(fx.visible_crack_count() >= 5, "can %%30'da çatlaklar görünür: %d" % fx.visible_crack_count())
	fx.debris_burst(Vector2(300.0, 250.0), 4, true)
	for i in 30:
		fx._process(0.05)
	assert(fx.debris_count() == 4, "döküntü yere düşüp kalır")
	_cleanup()


# ------------------------------------------------------------------ açılış

func test_intro_phases_gate_invasion() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var intro: HouseIntro = house.get_intro()
	intro.set_process(false)
	intro.begin()
	assert(GameManager.invasion_pending and intro.phase == IntroScript.Phase.PEACE, "huzur: yaratık kapısı kapalı")
	for i in 10:
		intro._process(1.0)
	assert(intro.phase == IntroScript.Phase.COUNTDOWN and GameManager.invasion_pending, "deprem + geri sayım başladı")
	assert(intro.countdown_left() > 25.0, "30 sn geri sayım: %s" % intro.countdown_left())
	for i in 31:
		intro._process(1.0)
	assert(intro.phase == IntroScript.Phase.DONE and not GameManager.invasion_pending, "geri sayım bitti: saldırı")
	_cleanup()


func test_grandma_worries_then_looks_out_of_window_then_worries_on_siege() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var bab: BabaanneNpc = house.get_babaanne()
	var intro: HouseIntro = house.get_intro()
	assert(bab.window_feet.is_finite(), "pencerenin önü bulundu")
	assert(not bab.chop_spot.is_empty(), "tezgah bulundu (doğrama yeri)")
	var kazan_x: float = bab.stir_spot["feet"].x
	assert(bab.chop_spot["feet"].x - kazan_x > 20.0 and bab.chop_spot["feet"].x - kazan_x < 80.0, "tezgah kazanın sağında")
	assert(bab.stir_spot["face"] == "up" and bab.chop_spot["face"] == "up", "kazanın ve tezgahın önünde, yukarı dönük (madde 313)")
	intro.set_process(false)
	intro.begin()
	assert(bab.current_activity() == BabaanneScript.Act.COOK, "huzurda mutfakta")
	intro._set_phase(IntroScript.Phase.COUNTDOWN, 1.0)
	assert(bab.current_activity() == BabaanneScript.Act.WORRY, "deprem: endişe")
	intro._set_phase(IntroScript.Phase.COUNTDOWN, 5.0)
	assert(bab.current_activity() == BabaanneScript.Act.WINDOW, "pencereden bakar")
	intro._set_phase(IntroScript.Phase.DONE, 0.0)
	house.get_siege().under_attack = true
	assert(bab.current_activity() != BabaanneScript.Act.WORRY, "kuşatmada çoğunlukla işinin başında")
	var worried: float = 0.0
	for i in 600: ## 60 sn kuşatma
		bab._tick_siege_worry(0.1)
		if bab.current_activity() == BabaanneScript.Act.WORRY:
			worried += 0.1
	assert(worried > 3.0 and worried < 20.0, "arada kısa endişe anları (60 sn'de %.1f sn)" % worried)
	house.get_siege().under_attack = false
	assert(bab.at_war(), "saldırıdan sonra savaşın farkında")
	_cleanup()


func test_intro_spots_seat_first_player_and_spread_others() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var walk: Dictionary = house.walkable_cells()
	var feet_seen: Array = []
	var seated: int = 0
	for i in 8:
		var sp: Dictionary = house.intro_spot(i)
		var f: Vector2 = sp["feet"]
		for q in feet_seen:
			assert((q as Vector2).distance_to(f) > 20.0, "açılış yerleri üst üste değil (%d)" % i)
		feet_seen.append(f)
		if sp["seat"]:
			seated += 1
		else:
			assert(walk.has(Vector2i(floori(f.x / 16.0), floori(f.y / 16.0))), "ayakta duran açık zeminde (%d: %s)" % [i, f])
	assert(house.intro_spot(0)["seat"], "ilk oyuncu koltukta oturur")
	assert(not house.intro_spot(1)["seat"], "ikinci şöminenin yanında ayakta")
	assert(seated == 3, "3 koltuk (2 şömine + okuma): %d" % seated)
	_cleanup()


func _outside_granny() -> Dictionary:
	var w: Node2D = _track(Node2D.new())
	add_child(w)
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var bab: BabaanneNpc = house.get_babaanne()
	p.global_position = Vector2(-9000.0, -9000.0) ## oyuncu uzakta (çekim yok)
	bab.go_outside(w, Vector2(1000.0, 1000.0))
	return {"w": w, "bab": bab, "house": house, "player": p}


func test_grandma_flees_walking_from_creatures_then_returns_home() -> void:
	var g: Dictionary = _outside_granny()
	var bab: BabaanneNpc = g["bab"]
	var foe := Node2D.new()
	foe.add_to_group("enemies")
	g["w"].add_child(foe)
	_track(foe)
	foe.global_position = Vector2(1040.0, 1000.0)
	var d0: float = bab.feet_world().distance_to(foe.global_position)
	var walked: bool = false
	for i in 30:
		bab._process(0.1)
		walked = walked or bab.current_clip().begins_with("walk_")
	var d1: float = bab.feet_world().distance_to(foe.global_position)
	assert(walked, "yürüyerek kaçar (walk klibi)")
	assert(d1 > d0 + 80.0, "yaratıktan uzaklaştı: %.0f -> %.0f" % [d0, d1])
	assert(bab.feet_world().x < 1000.0, "yaratığın tersine (sola) kaçtı: %s" % bab.feet_world())
	assert(GameManager.babaanne_target == bab, "kaçarken de hedef (yaratıklar saldırabilir)")
	foe.queue_free()
	await get_tree().process_frame
	var far: float = bab.feet_world().distance_to(Vector2(1000.0, 1000.0))
	for i in 140:
		bab._process(0.1)
	assert(bab.feet_world().distance_to(Vector2(1000.0, 1000.0)) < far - 40.0, "sakinleşince evin önüne döner")
	_cleanup()


func test_grandma_flees_toward_nearest_outdoor_player() -> void:
	var g: Dictionary = _outside_granny()
	var bab: BabaanneNpc = g["bab"]
	g["player"].global_position = Vector2(1000.0, 1400.0) ## aşağıda, DIŞARIDA bir oyuncu (ev _ready'de içeri almıştı)
	g["player"].is_indoors = false
	var foe := Node2D.new()
	foe.add_to_group("enemies")
	g["w"].add_child(foe)
	_track(foe)
	foe.global_position = Vector2(1060.0, 1000.0)
	for i in 20:
		bab._process(0.1)
	var f: Vector2 = bab.feet_world()
	assert(f.y > 1020.0 and f.x < 1000.0, "yaratıktan uzağa VE oyuncuya doğru (sol-aşağı): %s" % f)
	_cleanup()


func test_client_grandma_follows_host_position() -> void:
	var g: Dictionary = _outside_granny()
	var bab: BabaanneNpc = g["bab"]
	var siege: HouseSiege = g["house"].get_siege()
	siege.granny_net_pos = Vector2(1300.0, 1000.0)
	bab._follow_net(0.1, siege)
	assert(bab.feet_world().distance_to(Vector2(1300.0, 1000.0)) < 0.5, "çok uzaksa ışınlanır")
	siege.granny_net_pos = Vector2(1330.0, 1000.0)
	for i in 20:
		bab._follow_net(0.05, siege)
		bab._step_walk(0.05)
	assert(bab.feet_world().distance_to(Vector2(1330.0, 1000.0)) < 2.0, "yakınsa yürüyerek yetişir: %s" % bab.feet_world())
	_cleanup()


func test_grandma_pauses_for_breath_while_fleeing() -> void:
	var g: Dictionary = _outside_granny()
	var bab: BabaanneNpc = g["bab"]
	var foe := Node2D.new()
	foe.add_to_group("enemies")
	g["w"].add_child(foe)
	_track(foe)
	var rested: bool = false
	var walked_after: bool = false
	for i in 70:
		foe.global_position = bab.feet_world() + Vector2(50.0, 0.0) ## yaratık peşinde
		bab._process(0.1)
		if bab._rest_t > 0.0 and not bab.is_walking():
			rested = true
		elif rested and bab.is_walking():
			walked_after = true
	assert(rested, "kaçarken soluklanır (yaratıklar yetişebilsin)")
	assert(walked_after, "soluklandıktan sonra yine kaçar")
	_cleanup()


# ------------------------------------------------------------------ iç mekan çarpışma v2 + derinlik (madde 313)

func _blocked(rects: Array, p: Vector2) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


func test_interior_walls_are_continuous_doors_open_furniture_only_footprint() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var rects: Array = house.collision_rects()
	## odaları ayıran dikey duvarlar boydan boya (eskiden kesik kesik: içinden geçiliyordu)
	for wall_x: Array in [[168.0, 200.0], [312.0, 340.0], [478.0, 504.0]]:
		for y in range(100, 172, 4):
			var hit: bool = false
			var x: float = wall_x[0]
			while x <= wall_x[1] and not hit:
				hit = _blocked(rects, Vector2(x, float(y)))
				x += 1.0
			assert(hit, "dikey duvar %s y=%d kesintisiz" % [str(wall_x), y])
	## sol yatak odası ön duvarı: kapı dışında geçilmez, kapı aralığı açık
	for x in range(200, 268, 4):
		var hit: bool = false
		for y in range(188, 224):
			hit = hit or _blocked(rects, Vector2(float(x), float(y)))
		assert(hit, "ön duvar x=%d kapalı" % x)
	for x in range(280, 298, 2):
		for y in range(180, 230, 2):
			assert(not _blocked(rects, Vector2(float(x), float(y))), "kapı aralığı açık (%d,%d)" % [x, y])
	## koltuk: yalnız taban izi engel, sırtın arkası yürünebilir (oyuncu koltuğun arkasına geçer, koltuk onu örter)
	assert(not _blocked(rects, Vector2(361.0, 168.0)), "koltuk sırtının arkası açık")
	assert(_blocked(rects, Vector2(361.0, 176.0)), "koltuğun tabanı engel")
	## eşya/duvar ön kopyaları kuruldu; yatak odası kapısı da var ama yalnız SABİT çerçevesiyle (aşağıdaki test)
	var occ: Node = house._interior_instance.get_node_or_null("DepthOccluders")
	assert(occ != null, "derinlik ön kopyaları kuruldu")
	var names: Array = []
	for f in occ.fronts:
		names.append(String(f["layer"].name))
	assert(names.has("Duvarlar") and names.has("ekstra") and names.has("Oda kapıları"), "ön kopya katmanları: %s" % str(names))
	_cleanup()


## 2026-10-20 "kapılardan geçerken kapının üstü üstümüzde görünmüyor, duvar da aynı şekilde" (madde 328): kapı kirişi + yan sütunlar karakteri örter,
## açılan aralık (kapı kanadı + arkasındaki zemin pikseli) ÖRTMEZ (kare tamamen opak: tümü öne alınsaydı aralıktaki karakter de gizlenirdi).
func test_room_door_frame_front_covers_lintel_but_not_the_opening() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var occ: Node = house._interior_instance.get_node_or_null("DepthOccluders")
	assert(occ != null, "derinlik ön kopyaları kuruldu")
	var door_front: Dictionary = {}
	for f: Dictionary in occ.fronts:
		if String(f["layer"].name) == HouseInteriorScript.ROOM_DOOR_LAYER:
			door_front = f
	assert(not door_front.is_empty(), "kapı katmanının ön kopyası var")
	var front: TileMapLayer = door_front["front"]
	assert(front.get_used_cells().size() == 12, "iki kapı x 6 karo: %d" % front.get_used_cells().size())
	## ön kopyanın dokusu maskeli: kiriş/sütun opak, açılan aralık saydam (her açılma karesinde aynı)
	var cell: Vector2i = Vector2i(17, 11) ## sol kapının sol üst karosu (cozy_ev.tmx)
	assert(front.get_cell_source_id(cell) >= 0, "kapı hücresi ön kopyada")
	var src := front.tile_set.get_source(front.get_cell_source_id(cell)) as TileSetAtlasSource
	var img: Image = src.texture.get_image()
	for k in HouseInteriorScript.ROOM_DOOR_FRAMES:
		var ox: int = k * 32
		assert(img.get_pixel(ox + 5, 5).a > 0.99, "kare %d: üst kiriş opak" % k)
		assert(img.get_pixel(ox + 3, 24).a > 0.99 and img.get_pixel(ox + 28, 24).a > 0.99, "kare %d: yan sütunlar opak" % k)
		assert(img.get_pixel(ox + 16, 28).a < 0.01, "kare %d: kapı aralığı saydam (karakter görünür kalır)" % k)
	## kök: kapının tabanı (yerel y ~221) - kapı aralığında duran (ayağı ~216) karakterin ARKASINDA kalan nesne sayılır, önünde duran (ayağı > kök) örtülmez
	var base: float = float((door_front["bases"] as Dictionary)[cell]) - house.INTERIOR_OFFSET.y
	assert(base > 216.0 and base <= 224.0, "kapı kökü kapı tabanında: %.1f" % base)
	## maske yardımcısı: kareler arasında değişen piksel saydam, değişmeyen aynen kalır
	var sheet := Image.create(64, 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.RED)
	sheet.set_pixel(40, 1, Color.BLUE) ## 2. karenin (x 32..63) yerel (8, 1) pikseli farklı
	var masked: Image = HouseInteriorScript.door_frame_image(sheet, 2)
	assert(masked.get_pixel(0, 0).a == 1.0 and masked.get_pixel(40, 0).a == 1.0, "aynı piksel kalır")
	assert(masked.get_pixel(8, 1).a == 0.0 and masked.get_pixel(40, 1).a == 0.0, "değişen piksel her karede saydam")
	_cleanup()


func test_indoor_collider_moves_to_feet_and_restores_outside() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	p.scale = Vector2(0.5, 0.5)
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	cs.shape = circle
	cs.position = Vector2(0.0, 2.0)
	p.add_child(cs)
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	## ev _ready'de oyuncuyu içeri aldı
	var r: float = (cs.shape as CircleShape2D).radius * 0.5
	assert(absf(r - HouseInteriorScript.INDOOR_FOOT_RADIUS) < 0.01, "içeride küçük ayak dairesi: %s" % r)
	var center_y: float = cs.position.y * 0.5
	assert(absf(center_y - (HouseInteriorScript.PLAYER_FEET_OFFSET - HouseInteriorScript.INDOOR_FOOT_RADIUS)) < 0.01, "daire ayakta: %s" % center_y)
	house._do_exit_house()
	assert(cs.shape == circle and cs.position == Vector2(0.0, 2.0), "dışarıda eski daire")
	_cleanup()


func test_sleeping_grandma_not_occluded_by_bed() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var bab: BabaanneNpc = house.get_babaanne()
	bab._switch_activity(BabaanneScript.Act.SLEEP, true)
	assert(bab.is_sleeping() and not bab.is_in_group(NpcActor.GROUP), "uyurken derinlik listesinde değil (yatak onu örtmesin)")
	bab._switch_activity(BabaanneScript.Act.COOK, true)
	assert(bab.is_in_group(NpcActor.GROUP), "kalkınca yine derinlikte")
	_cleanup()


## 2026-10-19 "kazan büyükannenin üstünde duruyor": ışıksız eşya karolarının malzemesi (cozy_ev_light.gd) ön kopyanın derinlik shader'ını
## eziyordu - kazan/mum/fener herkesin üstüne çiziliyordu. Artık hiçbir ön kopyada karo malzemesi yok; ışıksız eşyalar ayrı, ışıksız
## derinlik kopyasında; karıştıran babaannenin ayağı kazanın kökünün önünde (örtülmez).
func test_unlit_furniture_front_copies_keep_depth_and_grandma_stirs_in_front() -> void:
	var p: FakePlayerScript = _track(FakePlayerScript.new())
	p.add_to_group("player")
	add_child(p)
	var house: Node2D = _track(HouseInteriorScript.new())
	add_child(house)
	var occ: Node = house._interior_instance.get_node_or_null("DepthOccluders")
	assert(occ != null, "derinlik ön kopyaları kuruldu")
	var kazan_base: float = -INF
	for f: Dictionary in occ.fronts:
		for key: String in ["front", "front_unlit"]:
			if not f.has(key):
				continue
			var fl: TileMapLayer = f[key]
			assert(fl.material is ShaderMaterial, "%s derinlik malzemeli" % fl.name)
			for cell: Vector2i in fl.get_used_cells():
				var td: TileData = fl.get_cell_tile_data(cell)
				assert(td == null or td.material == null, "%s %s karo malzemesi derinliği ezmez" % [fl.name, str(cell)])
				var src := fl.tile_set.get_source(fl.get_cell_source_id(cell)) as TileSetAtlasSource
				if key == "front_unlit" and src.texture.resource_path.get_file() == "Kazan_ocak.png":
					kazan_base = maxf(kazan_base, float(f["bases"][cell]))
		if f.has("front_unlit"):
			var code: String = ((f["front_unlit"] as TileMapLayer).material as ShaderMaterial).shader.code
			assert(code.contains("render_mode unshaded"), "ışıksız kopya ışıksız çizilir (asıl karo gibi)")
	assert(kazan_base > -INF, "kazan ışıksız derinlik kopyasında")
	var bab: BabaanneNpc = house.get_babaanne()
	assert(not bab.stir_spot.is_empty(), "kazan noktası bulundu")
	var feet_y: float = house._interior_instance.to_global(bab.stir_spot["feet"]).y
	assert(feet_y >= kazan_base, "karıştırırken kazanın önünde: ayak %.1f, kazan kökü %.1f" % [feet_y, kazan_base])
	_cleanup()
