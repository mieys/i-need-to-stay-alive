extends Node

## Kullanıcı isteği (2026-10-05):
##  1) "kademe atlamaları önceki kademenin yaratıkları tamamen öldüğünde başlamalı" -> bildirim, o kademenin bossu ve Final,
##     önceki kademenin sağ kalan yaratıkları ölene kadar (enemy_spawner.gd KADEME KAPISI) BAŞLAMAZ.
##  2) "kademelerin numaralarını da romen rakamlarıyla yaz" ve "sadece KADEME <NUMARA> + altında zorluğu gösteren 6 kuru kafa
##     (yarım yarım da artabilir)" -> scripts/tier_display.gd.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const TierDisplay: GDScript = preload("res://scripts/tier_display.gd")
const MainScript: GDScript = preload("res://scripts/main.gd")
const TIER_SECONDS := 100.0


## Boss/Final tetiklerinin kaç kez bakıldığını sayan, geri kalan akışı etkisizleştiren spawner (bkz. test_boss_and_final_triggers_are_polled).
class CountingSpawner extends "res://scripts/enemy_spawner.gd":
	var boss_checks: int = 0

	func _any_living_player_outdoors() -> bool:
		return true

	func _spawn_regular_enemy() -> void:
		pass

	func _check_tier_announcement() -> void:
		pass

	func _check_victory() -> void:
		pass

	func _process_endless() -> void:
		pass

	func _check_boss_tiers() -> void:
		boss_checks += 1

	func _check_final_tier() -> void:
		pass

	func _check_endless_boss_wave() -> void:
		pass


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


## Kapıyı tutan "sağ kalan" yaratık taklidi (sadece is_dead + spawn_tier meta okunuyor).
class FakeEnemy extends Node2D:
	var is_dead: bool = false


var _made: Array[Node] = []
var _heard: Array = []


func _on_tier(tier: int) -> void:
	_heard.append(tier)


func _cleanup() -> void:
	if NetworkManager.creature_tier_reached.is_connected(_on_tier):
		NetworkManager.creature_tier_reached.disconnect(_on_tier)
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for e: Node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.bosses_enabled = false
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false


## 2026-10-08: boss sistemi varsayılan KAPALI (GameManager.bosses_enabled, bkz. CLAUDE.md madde 39) - bu dosya boss/Final akışını sınar, bu yüzden geçici açar
func _spawner() -> Node:
	_cleanup()
	GameManager.bosses_enabled = true
	_heard.clear()
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	sp.max_concurrent_enemies = 100000
	get_tree().current_scene = self ## _spawn_creature current_scene'e ekliyor
	_made.append(sp)
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(500.0, 500.0)
	_made.append(p)
	NetworkManager.creature_tier_reached.connect(_on_tier)
	return sp


func _survivor(spawn_tier: int) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	e.set_meta("spawn_tier", spawn_tier)
	add_child(e)
	e.global_position = Vector2(520.0, 500.0) ## oyuncunun yanında: kapıyı tutar
	_made.append(e)
	return e


# ---------------------------------------------------------------- kapı: bildirim
func test_tier_is_announced_only_after_the_older_creatures_are_dead() -> void:
	var sp: Node = _spawner()
	var old: FakeEnemy = _survivor(1)
	GameManager.game_time = TIER_SECONDS + 1.0 ## saat kademe 2'ye geçti
	sp._check_tier_announcement()
	assert(_heard.is_empty(), "Eski kademeden yaratık sağken Kademe II BAŞLAMAMALI: %s" % str(_heard))
	GameManager.game_time = TIER_SECONDS + 60.0
	sp._check_tier_announcement()
	assert(_heard.is_empty(), "Saat ilerlese de yaratık sağ olduğu sürece başlamamalı: %s" % str(_heard))
	old.is_dead = true
	sp._announce_poll_msec = 0 ## test: 250 ms'lik sayım aralığını bekleme
	sp._check_tier_announcement()
	assert(_heard == [2], "Son eski yaratık ölünce Kademe 2 başlamalı (TEK bildirim): %s" % str(_heard))
	sp._check_tier_announcement()
	assert(_heard == [2], "Aynı kademe tekrar bildirilmemeli: %s" % str(_heard))
	_cleanup()


func test_tier_with_no_survivors_starts_immediately() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	assert(_heard == [2], "Sağ kalan yoksa kademe saatinde hemen başlamalı: %s" % str(_heard))
	_cleanup()


func test_creatures_far_from_every_player_do_not_hold_the_tier() -> void:
	var sp: Node = _spawner()
	var stuck: FakeEnemy = _survivor(1)
	stuck.global_position = Vector2(500.0 + sp.GATE_SURVIVOR_RADIUS + 400.0, 500.0) ## çok uzakta takılı kalmış
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	assert(_heard == [2], "Uzaktaki/ulaşılamaz yaratık kademeyi sonsuza dek bekletmemeli: %s" % str(_heard))
	_cleanup()


func test_wait_limit_still_starts_the_tier_if_a_creature_never_dies() -> void:
	var sp: Node = _spawner()
	_survivor(1)
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	assert(_heard.is_empty(), "süre dolmadan başlamamalı")
	assert(sp.GATE_MAX_WAIT_MSEC >= 60000, "tamamen ölmesini beklemek için bekleme sınırı kısa olmamalı (en az 60 sn)")
	sp._gate_wait_started_msec = Time.get_ticks_msec() - sp.GATE_MAX_WAIT_MSEC - 10
	sp._announce_poll_msec = 0
	sp._check_tier_announcement()
	assert(_heard == [2], "Sınır dolunca (hiç ölmese de) kademe başlamalı: %s" % str(_heard))
	_cleanup()


# ---------------------------------------------------------------- kapı: boss
func test_tier_boss_does_not_spawn_before_its_tier_has_started() -> void:
	var sp: Node = _spawner()
	var old: FakeEnemy = _survivor(1)
	GameManager.game_time = 2.0 * TIER_SECONDS + 76.0 ## kademe 3'ün %75'i: boss zamanı
	sp._check_boss_tiers()
	assert(not sp._tier_bosses.has(3) and not sp._boss_tiers_spawned.has(3), "Eski kademeden yaratık sağken 3. kademenin bossu doğmamalı")
	old.is_dead = true
	sp._check_boss_tiers()
	assert(sp._tier_bosses.has(3) and sp._boss_tiers_spawned.has(3), "Kademe başlayınca (eskiler ölünce) boss doğmalı")
	_cleanup()


# ---------------------------------------------------------------- kapı: Final
func test_final_waits_for_every_older_creature_and_stops_new_spawns() -> void:
	var sp: Node = _spawner()
	var last: FakeEnemy = _survivor(15)
	GameManager.game_time = TIER_SECONDS * 15.0 + 1.0 ## Final zamanı
	sp._check_tier_announcement()
	sp._check_final_tier()
	assert(not sp._final_spawned, "15. kademenin yaratığı sağken Final başlamamalı")
	assert(not _heard.has(16), "Final bildirilmemeli: %s" % str(_heard))
	assert(sp._resolve_spawn_tier() == 0, "Final beklerken yeni yaratık doğmamalı (yoksa sayım hiç bitmezdi)")
	last.is_dead = true
	sp._announce_poll_msec = 0
	sp._check_tier_announcement()
	sp._check_final_tier()
	assert(_heard.has(16) and _heard.count(16) == 1, "Son yaratık ölünce Final TEK bildirimle başlamalı: %s" % str(_heard))
	assert(sp._final_spawned, "Final bosslar doğmalı")
	_cleanup()


func test_final_gate_has_the_same_wait_limit() -> void:
	var sp: Node = _spawner()
	_survivor(15)
	GameManager.game_time = TIER_SECONDS * 15.0 + 1.0
	assert(not sp._final_gate_open(), "yaratık sağken kapı kapalı")
	sp._final_gate_wait_started_msec = Time.get_ticks_msec() - sp.GATE_MAX_WAIT_MSEC - 10
	assert(sp._final_gate_open(), "bekleme sınırı dolunca Final kapısı açılmalı")
	assert(sp._final_gate_open(), "bir kez açılınca kapalı kalmamalı")
	_cleanup()


func test_new_game_resets_the_started_tier() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = TIER_SECONDS * 3.0 + 1.0
	sp._check_tier_announcement()
	assert(_heard == [4], "Kademe 4 başlamalı: %s" % str(_heard))
	GameManager.game_time = 0.0 ## yeni oyun
	sp._check_tier_announcement()
	assert(sp._announced_tier == 1 and sp._spawn_tier == 1, "Yeni oyunda başlayan kademe 1'e dönmeli (%d / %d)" % [sp._announced_tier, sp._spawn_tier])
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	assert(_heard == [4, 2], "Yeni oyunda kademe 2 tekrar başlamalı: %s" % str(_heard))
	_cleanup()


# ---------------------------------------------------------------- Romen rakamları + kafa satırı
func test_roman_numerals() -> void:
	var want := {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V", 6: "VI", 7: "VII", 8: "VIII", 9: "IX", 10: "X", 11: "XI",
			12: "XII", 13: "XIII", 14: "XIV", 15: "XV", 16: "XVI", 19: "XIX", 40: "XL", 49: "XLIX", 90: "XC", 1994: "MCMXCIV"}
	for n: int in want.keys():
		assert(TierDisplay.to_roman(n) == want[n], "%d -> %s olmalı (bulunan %s)" % [n, want[n], TierDisplay.to_roman(n)])
	assert(TierDisplay.to_roman(0) == "-" and TierDisplay.to_roman(-3) == "-", "0 ve eksi değerler tire")
	assert(TierDisplay.to_roman(5000) == "5000", "çok büyük değer düz sayı kalır")


func test_titles_and_ordinals() -> void:
	assert(TierDisplay.title(4) == "KADEME IV", "başlık sadece KADEME + Romen rakamı: %s" % TierDisplay.title(4))
	assert(TierDisplay.title(1) == "KADEME I")
	assert(TierDisplay.title(15) == "KADEME XV")
	assert(TierDisplay.title(16) == "FİNAL KADEMESİ", "Final kendi adıyla")
	assert(TierDisplay.ordinal(5) == "V. Kademe" and TierDisplay.ordinal(10) == "X. Kademe")


func test_skull_steps_grow_with_the_tier_from_half_a_skull_to_six() -> void:
	assert(TierDisplay.skull_steps(1) == 1, "Kademe I: yarım kafa")
	assert(TierDisplay.skull_steps(8) == 6, "Kademe VIII: tam 3 kafa")
	assert(TierDisplay.skull_steps(15) == 11, "Kademe XV: 5.5 kafa")
	assert(TierDisplay.skull_steps(16) == 12, "Final: 6 kafa")
	assert(TierDisplay.skull_steps(40) == 12 and TierDisplay.skull_steps(0) == 0, "sınırlar")
	var prev: int = 0
	for t in range(1, 17):
		var s: int = TierDisplay.skull_steps(t)
		assert(s >= prev, "kafa sayısı azalmamalı (kademe %d: %d < %d)" % [t, s, prev])
		prev = s
	assert(TierDisplay.skull_steps(15) < TierDisplay.skull_steps(16), "Final, XV'ten belirgin biçimde ayrı olmalı")
	assert(TierDisplay.skull_steps(16) > TierDisplay.skull_steps(1), "ilk ve son aynı olmamalı")


func test_skull_fills_are_full_half_empty_per_skull() -> void:
	assert(TierDisplay.skull_fills(1) == [1, 0, 0, 0, 0, 0], "I: ilk kafa yarım: %s" % str(TierDisplay.skull_fills(1)))
	assert(TierDisplay.skull_fills(8) == [2, 2, 2, 0, 0, 0], "VIII: 3 tam: %s" % str(TierDisplay.skull_fills(8)))
	assert(TierDisplay.skull_fills(6) == [2, 2, 1, 0, 0, 0], "VI: 2.5 kafa: %s" % str(TierDisplay.skull_fills(6)))
	assert(TierDisplay.skull_fills(16) == [2, 2, 2, 2, 2, 2], "Final: 6 tam kafa")
	assert(TierDisplay.skull_fills(15) == [2, 2, 2, 2, 2, 1], "XV: son kafa yarım: %s" % str(TierDisplay.skull_fills(15)))
	for t in range(1, 17):
		var total: int = 0
		for f: int in TierDisplay.skull_fills(t):
			total += f
		assert(total == TierDisplay.skull_steps(t), "kafa dolulukları adım sayısıyla uyuşmalı (kademe %d)" % t)


func test_skull_row_control_sizes_and_draws_every_tier_without_errors() -> void:
	_cleanup()
	var row := Control.new()
	row.set_script(TierDisplay)
	add_child(row)
	_made.append(row)
	for t in range(1, 17):
		row.call("set_tier", t, 3)
		await get_tree().process_frame ## _draw bu karede çalışır (hata varsa test çıktısında görünür)
		assert(row.custom_minimum_size == Vector2(TierDisplay.ROW_ART_W, TierDisplay.SKULL_H) * 3.0, "satır boyutu 69x9 sanat pikseli x3")
		assert(int(row.call("get_tier")) == t)
	_cleanup()


func test_left_half_keeps_only_the_left_columns_of_the_skull() -> void:
	var full: Array[String] = ["XWWWWWWWX", "..XXXXX.."]
	var half: Array[String] = TierDisplay._left_half(full)
	assert(half[0] == "XWWWW....", "orta sütun dahil sol 5 sütun kalmalı: %s" % half[0])
	assert(half[1] == "..XXX....", "sağ yarı saydam: %s" % half[1])


func test_tier_banner_has_the_roman_title_and_the_skull_row() -> void:
	var m: Node = MainScript.new() ## ağaca eklenmez: _ready çalışmaz, sadece _tier_banner kurulur
	var banner: Control = m.call("_tier_banner", TierDisplay.title(7), 7)
	var label: Label = null
	var row: Control = null
	for c: Node in banner.get_children():
		if c is Label:
			label = c
		elif c.get_script() == TierDisplay:
			row = c
	assert(label != null and label.text == "KADEME VII", "başlık 'KADEME VII' olmalı: %s" % (label.text if label else "yok"))
	assert(row != null and int(row.call("get_tier")) == 7, "altında kademe VII'nin kuru kafa satırı olmalı")
	var texts: Array[String] = []
	for c: Node in banner.get_children():
		if c is Label:
			texts.append((c as Label).text)
	assert(texts.size() == 1, "başlıktan başka yazı olmamalı (eski 'BAŞLADI - güçlendi' yok): %s" % str(texts))
	banner.free()
	m.free()


## 2026-10-05: kapı kapalıyken _check_boss_tiers -> _resolve_spawn_tier "enemies" grubunu her karede tarıyordu (CLAUDE.md #9b) - tetikler
## artık çeyrek saniyede bir bakılır; ilk karede hemen bakılır.
func test_boss_and_final_triggers_are_polled_not_every_frame() -> void:
	_cleanup()
	var sp := CountingSpawner.new()
	add_child(sp)
	_made.append(sp)
	sp._process(0.016)
	assert(sp.boss_checks == 1, "ilk karede hemen bakmalı: %d" % sp.boss_checks)
	for i in 40: ## ~0.64 sn
		sp._process(0.016)
	assert(sp.boss_checks >= 2 and sp.boss_checks <= 4, "çeyrek saniyede bir bakmalı (41 karede %d kez)" % sp.boss_checks)
