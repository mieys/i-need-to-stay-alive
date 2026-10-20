extends Node

## COZY EV + BABAANNE (2026-10-19, madde 310): pişmiş iç mekan (harita/cozy_ev.tmx -> scenes/ev_ici_baked.tscn) oyunda, çarpışma
## yalnız dolu karolarda (+ şöminenin 3 karoluk tabanı), yatak odası kapıları yaklaşınca açılır, pencere camı gün/gece değişir;
## babaanne eşya noktalarını karolardan bulur, gün saatine göre iş yapar, içeri gireni selamlar, canı eksikse çorba getirir (bekleme),
## konuşur, uyurken uykulu cevap verir.

const HouseInteriorScript: GDScript = preload("res://scripts/house_interior.gd")
const BabaanneScript: GDScript = preload("res://scripts/babaanne_npc.gd")
const DIRS: Array[String] = ["down", "left", "right", "up"]


## Oyuncu yerine geçen düğüm: house_interior.gd ve babaanne'nin okuduğu alanlar + heal/on_food_picked_up.
class FakePlayer extends CharacterBody2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var is_chat_typing: bool = false
	var health: float = 100.0
	var max_health: float = 100.0
	var ate: int = 0
	var heal_src: StringName = &""

	func heal(amount: float, _boost: bool = true, src: StringName = &"") -> void:
		health = minf(max_health, health + amount)
		heal_src = src

	func on_food_picked_up() -> void:
		ate += 1

	func is_indoors_now() -> bool:
		return is_indoors


class FakeAtmo extends Node:
	var cycle_time: float = 60.0


var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _make_house() -> Dictionary:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	_track(p)
	var house: Node2D = HouseInteriorScript.new()
	add_child(house)
	_track(house)
	return {"house": house, "player": p}


func _step(npc: Node, seconds: float, dt: float = 0.1) -> void:
	var t: float = 0.0
	while t < seconds:
		npc._process(dt)
		t += dt


# ------------------------------------------------------------------ kareler + program

func test_frames_have_all_grandma_clips() -> void:
	var sf: SpriteFrames = load("res://assets/npc/babaanne/babaanne_frames.tres")
	assert(sf != null, "babaanne_frames.tres yüklenemedi")
	for base in ["idle", "walk", "sit", "seated", "sitread", "read", "wave", "laugh", "think", "shrug", "eat", "sleep"]:
		for d in DIRS:
			assert(sf.has_animation("%s_%s" % [base, d]), "%s_%s yok" % [base, d])
	for d in ["left", "right"]:
		assert(sf.has_animation("wipe_" + d) and sf.has_animation("stir_" + d), "wipe/stir_%s yok" % d)
	assert(sf.get_frame_count("walk_down") == 6 and sf.get_frame_count("idle_left") == 4, "kare sayıları")
	assert(not sf.get_animation_loop("sit_left"), "sit = ayaktan oturmaya GEÇİŞ, döngü olmamalı")
	assert(sf.get_frame_texture("idle_down", 0).get_size() == Vector2(48, 48), "kareler 48x48")


func test_schedule_cooks_mornings_reads_and_sleeps_some_nights() -> void:
	const A = BabaanneScript
	assert(A.activity_at(15.0, 0) == A.Act.COOK, "koşu sabah başlar: kahvaltı pişirir")
	assert(A.activity_at(60.0, 0) == A.Act.WIPE, "sabah toz alır")
	assert(A.activity_at(120.0, 0) == A.Act.READ, "öğleden önce okur")
	assert(A.activity_at(350.0, 0) == A.Act.COOK, "akşam yemeği")
	var sleeps: int = 0
	for day in 3:
		if A.activity_at(480.0, day) == A.Act.SLEEP:
			sleeps += 1
	assert(sleeps == 2, "3 gecenin 2'sinde uyur (bazen), biri şömine başında: %d" % sleeps)
	assert(A.activity_at(480.0, 2) == A.Act.FIRE_READ, "uyumadığı gece şöminenin başında okur")


# ------------------------------------------------------------------ iç mekan

func test_cozy_interior_collision_walkable_and_doors() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var walk: Dictionary = house.walkable_cells()
	assert(walk.size() > 250, "cozy ev geniş yürünebilir zemin: %d" % walk.size())
	var spawn_cell := Vector2i(floori(house.INTERIOR_SPAWN_POS.x / 16.0), floori(house.INTERIOR_SPAWN_POS.y / 16.0))
	assert(walk.has(spawn_cell), "doğma noktası açık zeminde")
	var blocked: Dictionary = house._collision_cells()
	for x in [24, 25, 26]:
		assert(blocked.has(Vector2i(x, 6)), "şöminenin tabanı (%d,6) çarpışmalı (48x64 karo)" % x)
	for x in [24, 25, 26]:
		assert(not walk.has(Vector2i(x, 20)), "çıkış kapısı karoları yürünebilir sayılmaz (NPC kaçmasın)")
	assert(house._room_doors.size() == 2, "iki yatak odası kapısı: %d" % house._room_doors.size())
	assert(house._windows.size() >= 5, "pencereler bulundu: %d" % house._windows.size())
	## kapı aralığı yürünebilir (kapı çarpışmasız)
	assert(walk.has(Vector2i(17, 12)) and walk.has(Vector2i(31, 12)), "kapı aralıkları geçilebilir")
	_cleanup()


func test_room_door_opens_when_someone_is_near_and_closes_after() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var p: FakePlayer = w["player"]
	var d: Dictionary = house._room_doors[0]
	var layer: TileMapLayer = d["layer"]
	var bottom: Vector2 = layer.to_global(layer.map_to_local(d["origin"]) + Vector2(8.0, 40.0))
	var bab: Node2D = house.get_babaanne()
	bab.set_process(false)
	bab.global_position = house.INTERIOR_OFFSET + Vector2(40.0, 300.0) ## kapılardan uzak
	p.global_position = bottom + Vector2(0.0, 6.0)
	for i in 10:
		house._process_room_doors(0.08)
	assert(int(d["frame"]) == 3, "yaklaşınca kapı tam açılır: %d" % int(d["frame"]))
	assert(layer.get_cell_atlas_coords(d["origin"]) == Vector2i(6, 0), "açık kare atlas sütunu 6")
	p.global_position = bottom + Vector2(0.0, 120.0)
	for i in 10:
		house._process_room_doors(0.08)
	assert(int(d["frame"]) == 0, "uzaklaşınca kapanır")
	_cleanup()


func test_windows_switch_between_day_and_night_glass() -> void:
	var atmo := FakeAtmo.new()
	atmo.add_to_group("atmosphere")
	add_child(atmo)
	_track(atmo)
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var win: Dictionary = house._windows[0]
	atmo.cycle_time = 60.0
	house._window_check = 0.0
	house._process_windows(0.1)
	assert((win["layer"] as TileMapLayer).get_cell_atlas_coords(win["cell"]) == Vector2i(1, 0), "gündüz parlak cam (kare 1)")
	atmo.cycle_time = 450.0
	house._window_check = 0.0
	house._process_windows(0.1)
	assert((win["layer"] as TileMapLayer).get_cell_atlas_coords(win["cell"]) == Vector2i(0, 0), "gece eski cam (kare 0)")
	_cleanup()


# ------------------------------------------------------------------ babaanne

func test_grandma_finds_furniture_spots_on_open_floor() -> void:
	var w: Dictionary = _make_house()
	var bab = w["house"].get_babaanne()
	assert(bab != null, "babaanne kuruldu")
	assert(not bab.stir_spot.is_empty(), "kazan bulundu")
	## madde 313: kazanın ve tezgahın ÖNÜNDE (aşağısında) durur
	var sf: Vector2 = bab.stir_spot["feet"]
	## kazana/tezgaha yaslanır: ayak eşyanın alt kenarında, birkaç piksel aşağısı açık zemin (oraya yürüyüp kayar)
	assert(bab.is_open(sf + Vector2(0.0, 6.0)), "kazanın önü (karıştırma yeri) açık zemine bitişik: %s" % sf)
	assert(not bab.chop_spot.is_empty() and bab.is_open(bab.chop_spot["feet"] + Vector2(0.0, 6.0)), "tezgahın önü açık zemine bitişik")
	assert(bab.bed_origin.is_finite(), "çift kişilik yatak bulundu")
	assert(bab.seats.size() == 3, "üç koltuk (2 şömine + okuma): %d" % bab.seats.size())
	var kinds: Array = bab.seats.map(func(s: Dictionary) -> String: return s["kind"])
	assert(kinds.count("fire") == 2 and kinds.count("read") == 1, "koltuk türleri: %s" % [kinds])
	for s: Dictionary in bab.seats:
		assert(bab.is_open(s["approach"]), "koltuğa yanaşma noktası açık zeminde")
	assert(bab.wipe_spots.size() >= 3, "silinecek raf/masa noktaları: %d" % bab.wipe_spots.size())
	for s: Dictionary in bab.wipe_spots:
		assert(bab.is_open(s["feet"]), "silme noktası açık zeminde")
	_cleanup()


func test_grandma_paths_stay_on_walkable_cells() -> void:
	var w: Dictionary = _make_house()
	var bab = w["house"].get_babaanne()
	var walk: Dictionary = w["house"].walkable_cells()
	var targets: Array[Vector2] = [bab.stir_spot["feet"]]
	for s: Dictionary in bab.seats:
		targets.append(s["approach"])
	for s: Dictionary in bab.wipe_spots:
		targets.append(s["feet"])
	targets.append(bab._target_for(BabaanneScript.Act.SLEEP)["approach"])
	for t: Vector2 in targets:
		var path: PackedVector2Array = bab.path_to(t)
		assert(path.size() >= 1 and path[path.size() - 1].distance_to(t) < 0.6, "yol hedefe varır")
		for i in range(0, path.size() - 1):
			assert(walk.has(bab.cell_of(path[i])), "yol yürünebilir hücrelerden geçer: %s" % [path[i]])
		bab.set_feet(t)
	_cleanup()


func test_grandma_greets_and_brings_soup_to_hurt_player_once_per_cooldown() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var p: FakePlayer = w["player"]
	var bab = house.get_babaanne()
	bab.set_process(false)
	house.set_process(false)
	bab._clock_override = 60.0
	## evin içi zaten "girilmiş" sayılsın diye önce bir adım: oyuncu tam canlı -> selam, çorba yok
	bab._step_walk(0.0)
	_step(bab, 0.2)
	assert(bab.mode == BabaanneScript.Mode.GREET, "içeri gireni selamlar")
	_step(bab, 2.0)
	assert(bab.mode == BabaanneScript.Mode.ACTIVITY, "tam canlıya çorba getirmez, işine döner")
	## canı azalmış oyuncu yeniden girer
	p.health = 40.0
	p.global_position = Vector2(-9000.0, -9000.0) ## çıktı
	_step(bab, 0.2)
	p.global_position = house.INTERIOR_OFFSET + house.INTERIOR_SPAWN_POS
	_step(bab, 2.0)
	assert(bab.mode == BabaanneScript.Mode.FEED_WALK or bab.mode == BabaanneScript.Mode.FEED_GIVE, "canı eksik oyuncuya çorba götürür: %d" % bab.mode)
	_step(bab, 12.0, 0.05)
	await get_tree().create_timer(0.7).timeout
	assert(p.ate == 1 and is_equal_approx(p.health, 70.0), "çorba = azami canın %%30'u: can %s, yedi %d" % [p.health, p.ate])
	assert(p.heal_src == &"babaanne", "can kaynağı balans kaydında 'babaanne'")
	assert(not bab.feed_ready(p), "aynı oyuncuya bekleme dolmadan yine getirmez")
	_cleanup()


## 2026-10-20 "büyükanne her karakteri için 1 cümle kuruyor, cümleler ortak olmalıydı" (madde 328): birlikte ya da selamdan GREET_GROUP_WINDOW sn
## içinde giren herkes TEK çoğul cümleyle karşılanır; veda da kapıya yakın herkes için tek cümle.
func test_grandma_greets_and_bids_farewell_to_a_group_with_one_common_sentence() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var p: FakePlayer = w["player"]
	var bab = house.get_babaanne()
	bab.set_process(false)
	house.set_process(false)
	bab._clock_override = 60.0
	var inside_pos: Vector2 = house.INTERIOR_OFFSET + house.INTERIOR_SPAWN_POS
	var mates: Array = []
	for i in 3:
		var m := FakePlayer.new()
		m.add_to_group("remote_players")
		add_child(m)
		_track(m)
		m.global_position = inside_pos + Vector2(8.0 * float(i + 1), 0.0)
		mates.append(m)
	var before: int = bab.said_count
	_step(bab, 0.2)
	assert(bab.mode == BabaanneScript.Mode.GREET, "içeri gireni selamlar")
	assert(bab.said_count == before + 1, "4 kişi için TEK selam cümlesi: %d" % (bab.said_count - before))
	var group_pool: Array = BabaanneScript.GREETINGS_GROUP + BabaanneScript.GREETINGS_GROUP_WAR
	assert(group_pool.has(bab.last_said), "çoğul hitaplı ortak cümle: %s" % bab.last_said)
	assert(bab._greet_queue.is_empty(), "kuyrukta kimse kalmadı (hepsi aynı cümleyle karşılandı)")
	_step(bab, 6.0)
	assert(bab.said_count == before + 1, "selamdan sonra kimseye ayrı cümle yok: %d" % (bab.said_count - before))
	## selamdan kısa süre sonra giren dördüncü kişi aynı selamla karşılanmış sayılır (ayrı cümle yok)
	var late := FakePlayer.new()
	late.add_to_group("remote_players")
	add_child(late)
	_track(late)
	late.global_position = Vector2(-9000.0, -9000.0)
	_step(bab, 0.2)
	late.global_position = inside_pos + Vector2(-8.0, 0.0)
	var said_before: int = bab.said_count
	_step(bab, 3.0)
	assert(bab.said_count == said_before, "geç girene ayrı selam cümlesi yok")
	assert(not bab._greet_due(late), "geç giren de selamlanmış sayıldı")
	## tek başına giren: tekil hitap (yeni ev; öncekinin oyuncuları temizlenir, yoksa aynı iç mekana sayılırlar)
	_cleanup()
	var solo: Dictionary = _make_house()
	var sbab = solo["house"].get_babaanne()
	sbab.set_process(false)
	solo["house"].set_process(false)
	sbab._clock_override = 60.0
	_step(sbab, 0.2)
	var single_pool: Array = BabaanneScript.GREETINGS + BabaanneScript.GREETINGS_WAR
	assert(single_pool.has(sbab.last_said), "tek kişiye tekil cümle: %s" % sbab.last_said)
	_cleanup()


## 2026-10-19 "hiç yemek vermiyor": mutfaktan (kazan) kapıdaki oyuncuya yol ~400 px, yürüyüş 46 px/sn -> 9 sn'lik vazgeçme süresi
## dolmadan varamıyordu; ayrıca yalnız GİRİŞTE bakıyordu (o an meşgul / uykuda / canı doluysa bir daha getirmiyordu).
func test_grandma_brings_soup_from_the_kitchen_and_to_players_already_inside() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var p: FakePlayer = w["player"]
	var bab = house.get_babaanne()
	bab.set_process(false)
	house.set_process(false)
	bab._clock_override = 15.0 ## kahvaltı: kazan başında
	p.global_position = Vector2(-9000.0, -9000.0)
	_step(bab, 0.2)
	bab._switch_activity(BabaanneScript.Act.COOK, true)
	assert(bab.feet().distance_to(bab.stir_spot["feet"]) < 1.0, "kazan başında")
	## yaralı oyuncu kapıdan girer ve kapının önünde durur
	p.health = 40.0
	p.global_position = house.INTERIOR_OFFSET + house.INTERIOR_SPAWN_POS
	_step(bab, 25.0, 0.05)
	await get_tree().create_timer(0.7).timeout
	assert(p.ate == 1, "mutfaktan kapıya çorba getirdi (yedi %d, kip %d)" % [p.ate, bab.mode])
	## içeride kalan oyuncu: bekleme dolunca (yeniden girmeden) yine getirir
	p.health = 40.0
	bab._fed_at[p.get_instance_id()] = GameManager.game_time - BabaanneScript.FEED_COOLDOWN - 1.0
	_step(bab, 25.0, 0.05)
	await get_tree().create_timer(0.7).timeout
	assert(p.ate == 2, "içerideki yaralıya bekleme dolunca getirir (yedi %d)" % p.ate)
	_cleanup()


## 2026-10-19 "çok fazla konuşuyor": kendiliğinden sözler arasında en az CHAT_GAP; içeride kalan oyuncuya kuşatma endişesi + iş
## mırıltısı + uyku mırıltısı dahil 3 dakikada en fazla 180 / CHAT_GAP + 1 söz. Oyuncunun konuşturması (talk) her zaman cevaplanır.
func test_grandma_does_not_chatter() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var p: FakePlayer = w["player"]
	var bab = house.get_babaanne()
	bab.set_process(false)
	house.set_process(false)
	var siege: Node = house.get_siege()
	siege.set_process(false)
	siege.under_attack = true ## kuşatma endişe anları açık
	for clock: float in [15.0, 480.0]: ## mutfak, sonra uyku gecesi
		bab._clock_override = clock
		bab._day_override = 0
		bab._resume()
		var before: int = bab.said_count
		_step(bab, 180.0, 0.1)
		var said: int = bab.said_count - before
		assert(said <= int(180.0 / BabaanneScript.CHAT_GAP) + 1, "saat %s: 3 dakikada %d söz (sınır %d)" % [clock, said, int(180.0 / BabaanneScript.CHAT_GAP) + 1])
	p.global_position = bab.global_position + Vector2(10.0, 0.0)
	var n: int = bab.said_count
	bab.talk(p)
	assert(bab.said_count == n + 1, "konuşturulunca hemen cevap verir")
	_cleanup()


func test_grandma_talks_and_answers_sleepily_when_in_bed() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var p: FakePlayer = w["player"]
	var bab = house.get_babaanne()
	bab.set_process(false)
	house.set_process(false)
	p.global_position = bab.global_position + Vector2(10.0, 0.0)
	assert(bab.can_talk(p), "yakındaki oyuncu konuşabilir")
	var line: String = bab.talk(p)
	assert(line != "", "bir cümle söyler")
	var line2: String = bab.talk(p)
	assert(line2 != line, "sıradaki cümle farklı")
	## gece yarısı (uyuduğu gün) yatağa geçer
	bab._clock_override = 480.0
	bab._day_override = 0
	bab._resume()
	bab._switch_activity(BabaanneScript.Act.SLEEP, true)
	assert(bab.is_sleeping(), "uyuyor")
	assert(bab._blanket.visible, "yorgan üstüne çizilir")
	var sleepy: String = bab.talk(p)
	assert(BabaanneScript.SLEEP_TALK.has(sleepy), "uyurken uykulu cevap: %s" % sleepy)
	bab._switch_activity(BabaanneScript.Act.COOK, true)
	assert(not bab.is_sleeping() and not bab._blanket.visible, "kalkınca yorgan kaybolur")
	_cleanup()
