extends Node

## Kara Bataklık tehlikeleri (scripts/bataklik_tehlike.gd): BATMA (suda 1,5 sn kıpırdamayan gömülür, yürümeye kalkınca 0,6 sn kıpırdayamaz) +
## SUDAN PUSU (host: 3 sn kesintisiz suda kalanın yakınındaki suda kabarcık uyarısı -> 2-3 yaratık). Yalnız profilinde "bataklik_tehlike" olan haritada.

const T := preload("res://scripts/bataklik_tehlike.gd")
const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const Badge := preload("res://scripts/status_effect_badge.gd")
const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const FxScript: GDScript = preload("res://scripts/fx_su_pusu.gd")
const DT := 1.0 / 60.0


## Sahte su: x >= 0 su (derinlik 0,5), solu kara; is_wading = ayak suda + "airborne" meta yok.
class FakeWade extends Node:
	func water_at(p: Vector2) -> float:
		return 0.5 if p.x >= 0.0 else 0.0

	func is_wading(n: Node2D) -> bool:
		return water_at(n.global_position) > 0.0


func _sink(still: float, pull: float, seconds: float, wants: bool, moved: float = 0.0) -> Vector2:
	var s := Vector2(still, pull)
	var t := 0.0
	while t < seconds - 0.0001:
		s = T.sink_step(s.x, s.y, DT, wants, moved)
		t += DT
	return s


func test_sink_timing_pull_and_reset() -> void:
	var s: Vector2 = _sink(0.0, 0.0, 1.45, false)
	assert(not T.is_sunk(s.x), "1,45 sn: henüz gömülmedi (%.2f)" % s.x)
	s = _sink(s.x, s.y, 0.1, false)
	assert(T.is_sunk(s.x) and s.y == 0.0, "1,5 sn kıpırdamayan gömülür")
	assert(T.sink_mult(s.y) == 1.0, "gömülü ama yürümeye kalkmamış: çarpan 1")
	s = T.sink_step(s.x, s.y, DT, true, 0.0)
	assert(is_equal_approx(s.y, T.PULL_TIME) and T.sink_mult(s.y) == 0.0, "yürümeye kalkınca çekilme başlar, hız 0")
	s = _sink(s.x, s.y, 0.55, false)
	assert(s.y > 0.0, "girdi bırakılsa da çekilme sürer (%.2f)" % s.y)
	s = _sink(s.x, s.y, 0.1, true)
	assert(s == Vector2.ZERO, "0,6 sn sonra serbest, sayaç sıfır")
	## yürümek / itilmek sayacı sıfırlar
	s = _sink(0.0, 0.0, 1.0, false)
	assert(T.sink_step(s.x, s.y, DT, true, 0.0) == Vector2.ZERO, "yürüyen gömülmez")
	assert(T.sink_step(s.x, s.y, DT, false, 2.0) == Vector2.ZERO, "itilen gömülmez")
	## gömülüyken küçük itilme gömülmeyi bozmaz, dash (büyük sıçrama) bozar
	s = _sink(0.0, 0.0, 2.0, false)
	assert(T.is_sunk(T.sink_step(s.x, s.y, DT, false, 3.0).x), "küçük itilme gömülmeyi bozmaz")
	assert(T.sink_step(s.x, s.y, DT, false, 20.0) == Vector2.ZERO, "dash / ışınlanma gömülmeyi bozar")


func test_sink_depth_pixels_and_badge() -> void:
	assert(T.sink_px(0.0, 0.0) == 0 and T.sink_px(T.SINK_SHOW_FROM, 0.0) == 0, "durur durmaz derinleşmez")
	assert(T.sink_px(T.SINK_DELAY, 0.0) == T.SINK_EXTRA_PX, "gömülünce en derin")
	assert(T.sink_px(T.SINK_DELAY, T.PULL_TIME) == T.SINK_EXTRA_PX and T.sink_px(T.SINK_DELAY, 0.01) == 0, "çekilirken geri iner")
	var seen: Dictionary = {}
	var s := Vector2.ZERO
	while not T.is_sunk(s.x):
		s = T.sink_step(s.x, s.y, DT, false, 0.0)
		seen[T.sink_px(s.x, s.y)] = true
	assert(seen.size() <= T.SINK_EXTRA_PX + 1, "tam piksel adımları (ağ paketi her karede değişmez)")
	assert(T.status_entry(1.0, 0.0).is_empty(), "gömülmeden rozet yok")
	assert(T.status_entry(T.SINK_DELAY, 0.0)["kind"] == "sink" and T.status_entry(0.0, 0.3)["kind"] == "sink", "gömülü / çekilirken rozet")
	assert(Badge.INFO.has("sink"), "rozet açıklaması")
	assert(load(Badge.ICON_DIR + "sink.png") is Texture2D, "rozet ikonu")
	assert(str(Badge.INFO["sink"][1]).contains("1,5") and str(Badge.INFO["sink"][1]).contains("0,6"), "açıklama sayıları sabitlerle aynı")


func test_only_swamp_profile_has_hazards() -> void:
	if OS.get_environment("HARITA") != "":
		return
	var keep: String = GameManager.selected_map
	for id: String in MapProfiles.PROFILES:
		GameManager.selected_map = id
		assert(MapProfiles.swamp_hazards() == (id == "bataklik"), "bataklık tehlikeleri yalnız Kara Bataklık'ta: " + id)
	GameManager.selected_map = keep


func test_ambush_rules() -> void:
	assert(not T.pusu_ready(T.PUSU_WADE_MIN - 0.1, 0.0), "eşikten önce yok")
	assert(T.pusu_ready(T.PUSU_WADE_MIN, 0.0) and not T.pusu_ready(10.0, 1.0), "eşik + bekleme")
	for id: String in ["hayalet1", "rontgen3", "yarasa1", "kabak1", "banshee1", "underground1", "sandworm1"]:
		assert(not T.pusu_id_ok(id), "uçan / minyon sudan çıkmaz: " + id)
	for id: String in ["ork3", "zombie1", "slime7", "iskelet2", "bitki1"]:
		assert(T.pusu_id_ok(id), "yürüyen sudan çıkar: " + id)


func test_player_sinks_roots_and_resets() -> void:
	var player: Node2D = (preload("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(5000.0, 5000.0)
	var full: float = player.get_effective_move_speed()
	player._swamp_hazards = 1
	player.wade_slow_active = true
	for i in range(int(T.SINK_DELAY / DT) + 2):
		player._process_wade_sink(DT)
	assert(player.wade_sink_px == T.SINK_EXTRA_PX, "gömülü: su çizgisi en derin")
	var kinds: Array = []
	for e: Dictionary in player.get_status_effects():
		kinds.append(e["kind"])
	assert(kinds.has("sink"), "HUD durum satırında gömülme rozeti")
	assert(is_equal_approx(player.get_effective_move_speed(), full * player.WADE_MOVE_MULT), "gömülü ama durgun: yalnız su yavaşlatması")
	Input.action_press("move_right")
	player._process_wade_sink(DT)
	assert(player.get_effective_move_speed() == 0.0, "yürümeye kalkınca kıpırdayamaz")
	for i in range(int(T.PULL_TIME / DT) + 2):
		player._process_wade_sink(DT)
	Input.action_release("move_right")
	assert(is_equal_approx(player.get_effective_move_speed(), full * player.WADE_MOVE_MULT), "çekilme bitti: yine yalnız su yavaşlatması")
	assert(player.wade_sink_px == 0, "su çizgisi normal")
	## yerde yatan / sudan çıkan sıfırlanır
	for i in range(int(T.SINK_DELAY / DT) + 2):
		player._process_wade_sink(DT)
	player.is_downed = true
	player._process_wade_sink(DT)
	assert(player.wade_sink_px == 0 and player._sink_still == 0.0, "yerde yatan sıfırlanır")
	player.is_downed = false
	player._swamp_hazards = 0
	player.wade_slow_active = false
	player.free()


func test_ambush_spots_fx_and_spawn() -> void:
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	var wade := FakeWade.new()
	add_child(wade)
	var center := Vector2(400.0, 3000.0) ## ana haritanın bu bölgesinde engel yok (test sahnesi haritasız)
	for _k in range(20):
		var spots: PackedVector2Array = sp._water_ambush_spots(center, 3, wade)
		assert(spots.size() >= 1, "suda nokta bulunur")
		for i in range(spots.size()):
			var p: Vector2 = spots[i]
			var d: float = p.distance_to(center)
			assert(d >= T.PUSU_DIST_MIN - 1.5 and d <= T.PUSU_DIST_MAX + 1.5, "oyuncuya yakın: %.1f" % d)
			assert(wade.water_at(p) > 0.0, "suyun içinde: %s" % str(p))
			for j in range(i):
				assert(spots[j].distance_to(p) >= 16.0, "üyeler üst üste değil")
	assert(sp._water_ambush_spots(Vector2(-5000.0, 3000.0), 3, wade).is_empty(), "çevrede su yoksa pusu yok")
	## görsel: uyarı + sıçrama süresi sonunda kendini siler
	var fx: Node2D = FxScript.new()
	add_child(fx)
	fx._process(T.PUSU_WARN * 0.5)
	assert(is_instance_valid(fx) and not fx.is_queued_for_deletion(), "uyarı sürerken duruyor")
	fx._process(T.PUSU_WARN + 1.0)
	assert(fx.is_queued_for_deletion(), "sıçrama bitince silinir")
	## doğuş: noktalarda, işaretli, uçan yok
	var spots2 := PackedVector2Array([center + Vector2(60.0, 0.0), center + Vector2(0.0, 70.0)])
	var before: int = get_tree().get_nodes_in_group("enemies").size()
	sp._finish_water_ambush(spots2, ["ork1", "zombie1"], 1)
	var made: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("water_ambush"):
			made.append(e)
	assert(made.size() == 2 and get_tree().get_nodes_in_group("enemies").size() == before + 2, "iki yaratık sudan çıktı")
	for e: Node in made:
		assert(spots2.has((e as Node2D).global_position), "pusu noktasında doğdu")
		assert(int(e.get_meta("spawn_tier", 0)) == 1, "kademe işaretli")
		e.free()
	wade.free()
	sp.free()
