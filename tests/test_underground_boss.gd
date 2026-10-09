extends Node

## Kullanıcı isteği (2026-10-09): Kademe 5 bossu YERALTI CANAVARI (masaüstü "solucan boss" paketi): yeraltından dev solucan UZUVLARI çıkarır - oyuncunun yakınında rastgele
## konumlarda, hep yolunu keserek, arada dümdüz sıralanarak; bazıları asit atar (110), bazıları saldırır (130); oyuncular uzuvlara vurarak bossun kendi canını azaltır
## (uzuvların hasar eşiği var: aşılınca parçalanır, bazıları deliğine geri döner); yeraltından korkutucu sesler; boss canı 50.000, kalkanı 60.000.
## Kapsam: saf hesaplar (worm_boss_math.gd), sprite/sahne sözleşmesi, boss statları + vurulamazlık + havuz + ölüm, kademe kapısı, uzuv durum makinesi (savurma/asit/eşik/geri dönüş/ömür/
## ödülsüzlük), yönetmen (yol kesme, dümdüz sıra, üst sınır), pozlar, sert gövde bloğu, ses dosyaları.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")
const MathScript: GDScript = preload("res://scripts/worm_boss_math.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const SoundScript: GDScript = preload("res://scripts/underground_sound.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const LimbScene: PackedScene = preload("res://scenes/creatures/enemy_sandworm1.tscn")
const DT := 1.0 / 60.0
const ASSASIN := 5

var _made: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1
var _died_signals: int = 0


class StubPlayer extends Node2D:
	var is_dead: bool = false
	var is_indoors: bool = false
	var is_in_merchant_zone: bool = false
	var is_downed: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])


func _on_enemy_died(_pos: Vector2) -> void:
	_died_signals += 1


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).ends_with("worm_acid.gd"):
			c.free()
	GameManager.bosses_enabled = false
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false
	if GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.disconnect(_on_enemy_died)
	EnemyScript._drop_spawn_queue.clear()


func _add(n: Node) -> Node:
	add_child(n)
	_made.append(n)
	return n


## Boss + spawner + (isteğe bağlı) oyuncular. Döner: [spawner, boss, [oyuncular]]
func _rig(player_positions: Array = [Vector2(500, 500)]) -> Array:
	_cleanup()
	get_tree().current_scene = self
	var sp: Node = SpawnerScript.new()
	_add(sp)
	sp.max_concurrent_enemies = 100000
	var players: Array = []
	for pos: Vector2 in player_positions:
		var p := StubPlayer.new()
		p.add_to_group("player" if players.is_empty() else "remote_players")
		_add(p)
		p.global_position = pos
		players.append(p)
	var boss: Node = sp._spawn_boss_group(["underground1"], 5)[0]
	return [sp, boss, players]


func _is_descending(a: Array) -> bool:
	for i in range(1, a.size()):
		if float(a[i]) > float(a[i - 1]):
			return false
	return true


func _limb_at(boss: Node, pos: Vector2, kind: int, fate: int, life: float = 30.0) -> Node:
	return boss._spawn_limb(pos, kind, fate, life)


## Uzvu ağ/C++ tiki olmadan adım adım işletir (host mantığı): cond true olunca ya da süre dolunca durur. Döner: geçen süre.
func _run_limb(limb: Node, cond: Callable, max_seconds: float) -> float:
	var t: float = 0.0
	while t < max_seconds and not bool(cond.call()) and is_instance_valid(limb) and limb.get("is_dead") != true:
		limb._limb_tick(DT)
		t += DT
	return t


# ------------------------------------------------------------------ saf hesaplar

func test_math_kinds_fates_paths_lines_and_spawn_rules() -> void:
	assert(MathScript.pick_kind(0.0) == MathScript.KIND_SPITTER and MathScript.pick_kind(0.99) == MathScript.KIND_LASHER, "tür zarı")
	assert(MathScript.pick_fate(0.0) == MathScript.FATE_RETREAT and MathScript.pick_fate(0.99) == MathScript.FATE_BURST, "kader zarı")
	## Yol kesme: hareket eden oyuncunun GİTTİĞİ yönün önüne; duran oyuncunun çevresine halka.
	var ahead: Vector2 = MathScript.path_cut_position(Vector2(100, 100), Vector2(250, 0), 200.0, 30.0, 0.0, 0.0)
	assert(is_equal_approx(ahead.x, 300.0) and is_equal_approx(ahead.y, 70.0), "hareket yönünün önünde (yan sapma Vector2.orthogonal yönünde): %s" % str(ahead))
	var still: Vector2 = MathScript.path_cut_position(Vector2(100, 100), Vector2(10, 0), 200.0, 30.0, PI * 0.5, 150.0)
	assert(still.is_equal_approx(Vector2(100, 250)), "duran oyuncunun çevresinde halka: %s" % str(still))
	## Yol kesen DAĞINIK sıra (2026-10-09: "dip dibe değil, ayrık ve rastgele"): gidiş yönüne dik eksende 4-6 uzuv, komşu aralıkları rastgele ve geniş, her biri gidiş yönünde ayrı kayık.
	var depth_values: Array = []
	var shuffled_runs: int = 0
	var counts: Dictionary = {}
	for seed_i in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + seed_i
		var spots: Array[Dictionary] = MathScript.scattered_line(Vector2(0, 0), Vector2(1, 0), rng)
		counts[spots.size()] = true
		assert(spots.size() >= MathScript.LINE_COUNT_MIN and spots.size() <= MathScript.LINE_COUNT_MAX, "4-6 uzuv: %d" % spots.size())
		var perp: Array = []
		for i in range(spots.size()):
			var p: Vector2 = spots[i]["pos"]
			depth_values.append(p.x)
			assert(p.x >= MathScript.LINE_DISTANCE_MIN - MathScript.LINE_DEPTH_JITTER - 0.01 and p.x <= MathScript.LINE_DISTANCE_MAX + MathScript.LINE_DEPTH_JITTER + 0.01, "gidiş yönünde önde: %s" % str(p))
			perp.append(p.y)
			if i == 0:
				assert(is_equal_approx(float(spots[0]["delay"]), 0.0), "ilk uzuv hemen")
			else:
				var step: float = float(spots[i]["delay"]) - float(spots[i - 1]["delay"])
				assert(step >= MathScript.LINE_STAGGER_MIN - 0.001 and step <= MathScript.LINE_STAGGER_MAX + 0.001, "çıkış gecikmesi aralıkta: %.2f" % step)
		var sorted_perp: Array = perp.duplicate()
		sorted_perp.sort()
		for i in range(1, sorted_perp.size()):
			var gap: float = float(sorted_perp[i]) - float(sorted_perp[i - 1])
			assert(gap >= MathScript.LINE_SPACING_MIN - 0.01 and gap <= MathScript.LINE_SPACING_MAX + 0.01, "komşu yan aralığı %.0f px (100-170)" % gap)
		if perp != sorted_perp and not _is_descending(perp):
			shuffled_runs += 1
		for a in range(spots.size()):
			for b in range(a + 1, spots.size()):
				assert((spots[a]["pos"] as Vector2).distance_to(spots[b]["pos"]) >= MathScript.LINE_SPACING_MIN - 0.01, "iki uzuv dip dibe değil")
	assert(counts.size() >= 2, "uzuv sayısı değişiyor: %s" % str(counts.keys()))
	assert(shuffled_runs >= 5, "çıkış sırası karışık (yan konuma göre sıralı değil): %d/40" % shuffled_runs)
	var mean_depth: float = 0.0
	for v: float in depth_values:
		mean_depth += v
	mean_depth /= float(depth_values.size())
	var var_depth: float = 0.0
	for v: float in depth_values:
		var_depth += (v - mean_depth) * (v - mean_depth)
	assert(sqrt(var_depth / float(depth_values.size())) > 20.0, "gidiş yönünde dümdüz değil, kayık")
	## Sert gövdeler arasında oyuncunun geçebileceği boşluk kalır (eskiden 10 px: duvar).
	assert(MathScript.LINE_SPACING_MIN - 2.0 * MathScript.HARD_BLOCK_RADIUS > 2.0 * 11.4 * 2.0, "boşluk en az iki oyuncu çapı: %.1f" % (MathScript.LINE_SPACING_MIN - 36.0))
	assert(MathScript.MIN_LIMB_SPACING >= 90.0, "tekil çıkışlar da dip dibe değil")
	## Çıkış uygunluğu
	var open: Callable = func(_p: Vector2) -> bool: return false
	var wall: Callable = func(p: Vector2) -> bool: return p.x > 400.0
	var players: Array = [Vector2(0, 0)]
	assert(not MathScript.spawn_ok(Vector2(60, 0), players, [], open), "oyuncunun 95 px içinde çıkmaz")
	assert(MathScript.spawn_ok(Vector2(120, 0), players, [], open), "uzakta çıkar")
	assert(not MathScript.spawn_ok(Vector2(500, 0), players, [], wall), "engele çıkmaz")
	assert(not MathScript.spawn_ok(Vector2(200, 0), players, [Vector2(230, 0)], open), "başka uzuvla çakışmaz")
	assert(MathScript.spawn_ok(Vector2(200, 0), players, [Vector2(230, 0)], open, 20.0), "gevşek aralık parametresi")
	assert(MathScript.max_active(1) == 7 and MathScript.max_active(3) == 11, "üst sınır oyuncu sayısıyla büyür")
	## Savurma isabeti: menzil + ön yarım düzlem
	assert(MathScript.lash_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(90, 20)), "önünde, menzilde")
	assert(not MathScript.lash_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(-60, 0)), "arkasında")
	assert(not MathScript.lash_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(200, 0)), "menzil dışında")
	## Hız tahmini yakınsar
	var v: Vector2 = Vector2.ZERO
	var pos := Vector2.ZERO
	for i in range(60):
		var nxt: Vector2 = pos + Vector2(250, 0) * DT
		v = MathScript.smooth_velocity(v, pos, nxt, DT)
		pos = nxt
	assert(absf(v.x - 250.0) < 5.0, "hız ~250: %s" % str(v))
	var probe: Node = LimbScene.instantiate()
	assert(is_equal_approx(MathScript.LIMB_THRESHOLD, probe.max_health), "uzuv eşiği sahne max_health'iyle aynı (tek sayı)")
	probe.free()


func test_total_limb_damage_to_empty_the_pool_matches_health_plus_shield() -> void:
	## Kalkan p oranında emer: kalkan bitene kadar S/p hasar, sonra kalan can -> toplam = can + kalkan (p ne olursa olsun).
	var r: Array = _rig()
	var boss: Node = r[1]
	var total: float = 0.0
	while boss.item_shield_hp > 0.0:
		boss.absorb_limb_damage(1000.0)
		total += 1000.0
	while not boss.is_dead and total < 200000.0:
		boss.absorb_limb_damage(1000.0)
		total += 1000.0
	assert(boss.is_dead, "havuz bitti")
	assert(absf(total - 110000.0) < 2000.0, "toplam hasar ~can + kalkan = 110.000: %.0f" % total)
	_cleanup()


# ------------------------------------------------------------------ sprite / sahne sözleşmesi

func test_sheets_scenes_ids_and_names_follow_the_project_conventions() -> void:
	var sizes: Dictionary = {"idle": 4, "emerge": 4, "lash": 7, "spit": 6, "hide": 8, "death": 7}
	for k: String in sizes.keys():
		var tex: Texture2D = load("res://assets/enemies/sandworm/sandworm_%s.png" % k) as Texture2D
		assert(tex != null, "sayfa yüklenir: %s" % k)
		assert(tex.get_width() == int(sizes[k]) * 80 and tex.get_height() == 320, "%s boyutu: %dx%d" % [k, tex.get_width(), tex.get_height()])
	for k: String in ["loop", "end"]:
		var a: Texture2D = load("res://assets/enemies/sandworm/acid_%s.png" % k) as Texture2D
		assert(a != null and a.get_width() == 60 and a.get_height() == 21, "asit sayfası %s: 3 kare 20x21" % k)
	var limb: Node = LimbScene.instantiate()
	add_child(limb)
	_made.append(limb)
	assert(limb.cell_size == 80 and limb.frame_sprite != null and limb.frame_sprite.hframes == 4, "uzuv: hücre 80, bekleme sayfası")
	assert(limb.emerge_texture != null and limb.lash_texture != null and limb.spit_texture != null and limb.hide_texture != null and limb.death_texture != null, "poz dokuları dolu")
	assert(limb.speed == 0.0 and limb.xp_value == 0.0 and limb.orb_count == 0 and limb.gold_chance == 0.0, "yerinden oynamaz, ödülsüz")
	assert(limb.hard_block_radius == MathScript.HARD_BLOCK_RADIUS, "sert gövde")
	assert(SpawnerScript.SCENES.has("underground1") and SpawnerScript.SCENES.has("sandworm1"), "doğuş tablosunda")
	assert(SpawnerScript.ID_FAMILY["underground1"] == "underground" and SpawnerScript.ID_FAMILY["sandworm1"] == "sandworm", "aileler")
	assert(SpawnerScript.LIMB_IDS == ["sandworm1"], "uzuv kimlikleri")
	assert(SpawnerScript.NEW_BOSS_TIERS[5] == ["underground1"], "Kademe 5 bossu")
	assert(BossBarArtScript.display_name("underground1") == "YERALTI CANAVARI", "üst boss barı adı: %s" % BossBarArtScript.display_name("underground1"))
	for tier: int in SpawnerScript.TIER_ROSTER.keys():
		assert(not SpawnerScript.TIER_ROSTER[tier].has("sandworm1") and not SpawnerScript.TIER_ROSTER[tier].has("underground1"), "sıradan doğuşta çıkmaz")
	assert(not SpawnerScript.ELITE_POOL.has("sandworm1") and not SpawnerScript.ELITE_POOL.has("underground1"), "elit havuzunda değil")
	_cleanup()


func test_every_underground_sound_file_exists() -> void:
	for key: StringName in SoundScript.SOUNDS.keys():
		var path: String = String(SoundScript.SOUNDS[key][0])
		assert(ResourceLoader.exists(path), "ses dosyası var: %s (%s)" % [key, path])
		var s: AudioStream = load(path) as AudioStream
		assert(s != null and s.get_length() > 0.2, "ses yüklenir ve dolu: %s" % key)
	SoundScript.play(get_tree(), &"rumble_1") ## başsızda sessiz no-op: hata vermemeli


# ------------------------------------------------------------------ boss: statlar, vurulamazlık, havuz

func test_boss_has_the_requested_pool_is_invisible_untargetable_and_immune_to_direct_hits() -> void:
	var r: Array = _rig()
	var boss: Node = r[1]
	assert(boss.is_boss and boss.is_in_group("boss"), "boss grubunda")
	assert(boss.max_health == 50000.0 and boss.health == 50000.0, "can 50.000: %.0f" % boss.max_health)
	assert(boss.item_shield_max == 60000.0 and boss.item_shield_hp == 60000.0, "kalkan 60.000: %.0f" % boss.item_shield_max)
	assert(is_equal_approx(boss.shield_protection, 0.9), "standart boss soğurması %%90: %.2f" % boss.shield_protection)
	assert(boss._current_tier == 5, "Kademe 5 bossu")
	assert(boss.has_meta(&"hide_on_minimap") and boss.has_meta(&"untargetable"), "minimapte yok, silahlar hedeflemez")
	assert(boss._ew_slot < 0, "C++ EnemyWorld'e kayıtlı DEĞİL (mermileri yutmaz)")
	assert(boss._overhead_bar == null, "üstünde kafatası plakası yok")
	## Doğrudan hasar yok sayılır (silah / alan / DOT).
	boss.take_damage(1.0e9)
	boss.take_damage_host(1.0e9, true, 0.0, 0)
	boss._take_dot_damage(1.0e9)
	assert(boss.health == 50000.0 and boss.item_shield_hp == 60000.0 and not boss.is_dead, "doğrudan hasar boss'a işlemez")
	## Uzuvlardan gelen hasar kalkana %90, cana %10 işler.
	boss.absorb_limb_damage(1000.0)
	assert(absf(boss.item_shield_hp - 59100.0) < 0.5 and absf(boss.health - 49900.0) < 0.5, "havuzdan düşer: kalkan %.1f can %.1f" % [boss.item_shield_hp, boss.health])
	## Ödül, Kademe 5'in referans bossuyla (iskelet3) aynı.
	var ref: Node = r[0]._spawn_creature("iskelet3", Vector2(900, 900), 999004)
	ref.add_to_group("boss")
	r[0]._setup_boss_enemy(ref, "iskelet3", 5, 1)
	assert(boss.xp_value == ref.xp_value and boss.gold_min == ref.gold_min and boss.gold_max == ref.gold_max, "ödül referansla aynı")
	_cleanup()


func test_the_tier_5_boss_spawns_on_time_holds_the_tier_clock_and_dies_with_all_limbs() -> void:
	var r: Array = _rig()
	var sp: Node = r[0]
	for b: Node in _boss_nodes():
		b.free() ## _rig kendi bossunu doğurdu: kademe testi için temiz başla
	sp._boss_tiers_spawned = {3: true}
	GameManager.game_time = 470.0 ## tetik: 4 x 100 + 100 x 0,75 = 475
	sp._check_boss_tiers()
	assert(_boss_nodes().is_empty(), "tetikten önce yok")
	GameManager.game_time = 480.0
	sp._check_boss_tiers()
	var bosses: Array = _boss_nodes()
	assert(bosses.size() == 1 and str(bosses[0].get_meta("creature_id", "")) == "underground1", "Kademe 5'te Yeraltı Canavarı: %s" % str(bosses))
	GameManager.game_time = 560.0
	assert(sp._tier_time() < 500.0 and sp._tier_time() > 499.9 and sp.is_tier_held_by_boss(), "boss ölmeden Kademe 6 açılmaz: %.3f" % sp._tier_time())
	## Uzuvlar + ölüm: havuz bitince hepsi dağılır.
	var boss: Node = bosses[0]
	var l1: Node = _limb_at(boss, Vector2(700, 700), MathScript.KIND_LASHER, MathScript.FATE_BURST)
	var l2: Node = _limb_at(boss, Vector2(800, 700), MathScript.KIND_SPITTER, MathScript.FATE_RETREAT)
	assert(l1 != null and l2 != null and boss._limbs.size() == 2, "iki uzuv yüzeyde")
	boss.health = 10.0
	boss.item_shield_hp = 0.0
	boss.absorb_limb_damage(50.0)
	assert(boss.is_dead, "havuz bitti: boss öldü")
	assert(l1.is_dead and l2.is_dead, "boss ölünce tüm uzuvlar parçalanır")
	assert(boss._limbs.is_empty(), "liste temiz")
	GameManager.game_time = 570.0
	assert(sp._tier_time() > 500.0 and not sp.is_tier_held_by_boss(), "boss ölünce kademe saati devam eder: %.3f" % sp._tier_time())
	_cleanup()


func _boss_nodes() -> Array:
	var out: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e.get("is_boss") == true or e.is_in_group("boss")) and e.get("is_dead") != true:
			out.append(e)
	return out


# ------------------------------------------------------------------ uzuv: saldırılar, eşik, geri dönüş

func test_lasher_strikes_a_player_in_reach_for_130_after_emerging_and_not_one_outside_it() -> void:
	var r: Array = _rig([Vector2(1000, 1000)])
	var boss: Node = r[1]
	var p: StubPlayer = r[2][0]
	var limb: Node = _limb_at(boss, Vector2(1080, 1000), MathScript.KIND_LASHER, MathScript.FATE_BURST) ## 80 px: menzilde (104)
	assert(limb != null and limb._ws == 0, "uzuv çıkış evresinde (doğunca)")
	var t: float = _run_limb(limb, func() -> bool: return not p.hits.is_empty(), 4.0)
	assert(p.hits.size() == 1 and p.hits[0][0] == 130.0 and p.hits[0][1] == "worm", "savurma 130 hasar, tür 'worm': %s" % str(p.hits))
	var expected: float = MathScript.EMERGE_TIME + MathScript.FIRST_ATTACK_DELAY + MathScript.LASH_STRIKE_AT
	assert(absf(t - expected) < 0.12, "ilk vuruş çıkış + bekleme + savurma karesinde: %.2f (beklenen %.2f)" % [t, expected])
	## Aynı savurma bir kez vurur; bekleme sonrası tekrar eder.
	_run_limb(limb, func() -> bool: return false, MathScript.LASH_ANIM + MathScript.LASH_COOLDOWN + MathScript.LASH_STRIKE_AT + 0.2)
	assert(p.hits.size() == 2, "bekleme sonrası ikinci savurma: %d" % p.hits.size())
	## Menzil dışındaki oyuncuya savurmaz.
	p.hits.clear()
	p.global_position = Vector2(1000 + 80 + 300, 1000)
	_run_limb(limb, func() -> bool: return false, 4.0)
	assert(p.hits.is_empty(), "300 px uzaktaki oyuncuya savurmaz")
	_cleanup()


func test_spitter_fires_a_dodgeable_acid_drop_for_110_and_misses_when_the_player_steps_aside() -> void:
	var r: Array = _rig([Vector2(1000, 1000)])
	var boss: Node = r[1]
	var p: StubPlayer = r[2][0]
	var limb: Node = _limb_at(boss, Vector2(1250, 1000), MathScript.KIND_SPITTER, MathScript.FATE_BURST) ## 250 px: tükürme menzilinde
	var acid: Node2D = null
	var t: float = 0.0
	while t < 5.0 and acid == null:
		limb._limb_tick(DT)
		t += DT
		for c: Node in get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("worm_acid.gd"):
				acid = c as Node2D
	assert(acid != null, "asit damlası doğdu")
	var expected: float = MathScript.EMERGE_TIME + MathScript.FIRST_ATTACK_DELAY + MathScript.SPIT_FIRE_AT
	assert(absf(t - expected) < 0.12, "tükürme atış karesinde: %.2f (beklenen %.2f)" % [t, expected])
	assert(acid.authoritative and acid._dir.x < -0.9, "hedefe doğru uçar, hasar yetkili örnekte")
	## Oyuncu hareketsiz: damla vurur (110, tür 'worm_acid').
	var guard: int = 0
	while is_instance_valid(acid) and not acid.is_queued_for_deletion() and guard < 240:
		acid._physics_process(DT)
		guard += 1
	assert(p.hits.size() == 1 and p.hits[0][0] == 110.0 and p.hits[0][1] == "worm_acid", "asit 110: %s" % str(p.hits))
	## İkinci damla: oyuncu yana kaçtı -> ıskalar (damla menzilini aşıp sönmeli, hasar yok).
	p.hits.clear()
	p.global_position = Vector2(1000, 1000 + 160)
	var acid2: Node2D = null
	t = 0.0
	while t < 6.0 and acid2 == null:
		limb._limb_tick(DT)
		t += DT
		for c: Node in get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("worm_acid.gd") and c != acid and not c.is_queued_for_deletion():
				acid2 = c as Node2D
	assert(acid2 != null, "ikinci damla")
	p.global_position = Vector2(1000, 1000 + 400) ## damla uçarken çok uzağa çekildi
	guard = 0
	while is_instance_valid(acid2) and not acid2.is_queued_for_deletion() and guard < 400:
		acid2._physics_process(DT)
		guard += 1
	assert(p.hits.is_empty(), "kaçınılan damla hasar vermez")
	_cleanup()


func test_every_hit_on_a_limb_drains_the_boss_pool_by_exactly_what_the_limb_absorbed() -> void:
	var r: Array = _rig()
	var boss: Node = r[1]
	var limb: Node = _limb_at(boss, Vector2(800, 800), MathScript.KIND_LASHER, MathScript.FATE_BURST)
	var pool_before: float = boss.item_shield_hp + boss.health
	limb.take_damage_host(500.0, false, 0.0, 0)
	assert(absf(limb.health - 1500.0) < 0.5, "uzvun eşiği düşer: %.1f" % limb.health)
	assert(absf(pool_before - (boss.item_shield_hp + boss.health) - 500.0) < 0.5, "boss havuzu tam 500 azaldı")
	assert(absf(boss.item_shield_hp - (60000.0 - 450.0)) < 0.5 and absf(boss.health - (50000.0 - 50.0)) < 0.5, "kalkana %%90, cana %%10: %.1f / %.1f" % [boss.item_shield_hp, boss.health])
	## Fazla hasar (overkill): sadece uzvun KALAN eşiği kadar düşer.
	pool_before = boss.item_shield_hp + boss.health
	limb.take_damage_host(9000.0, false, 0.0, 0)
	assert(limb.is_dead, "eşik aşıldı: parçalandı")
	assert(absf(pool_before - (boss.item_shield_hp + boss.health) - 1500.0) < 0.5, "boss yalnız uzvun kalan 1500'ünü yedi: %.1f" % (pool_before - (boss.item_shield_hp + boss.health)))
	assert(boss._limbs.is_empty(), "uzuv listeden düştü")
	_cleanup()


func test_a_burst_limb_gives_no_rewards_and_does_not_count_as_a_kill() -> void:
	var r: Array = _rig()
	var boss: Node = r[1]
	GameManager.enemy_died.connect(_on_enemy_died)
	_died_signals = 0
	var limb: Node = _limb_at(boss, Vector2(800, 800), MathScript.KIND_LASHER, MathScript.FATE_BURST)
	limb.take_damage_host(5000.0, false, 0.0, 0)
	assert(limb.is_dead and limb._state == EnemyScript.State.DEATH, "ölüm animasyonuna girdi")
	assert(EnemyScript._drop_spawn_queue.is_empty(), "XP/altın/yemek/sandık düşmedi")
	assert(_died_signals == 0, "öldürme sayılmadı (GameManager.enemy_died yok)")
	assert(limb.get_meta(&"untargetable", false) == false, "ölü, ödülsüz (gömülme değil)")
	_cleanup()


func test_retreat_fate_limb_returns_to_its_hole_at_55_percent_and_is_immune_while_hiding() -> void:
	var r: Array = _rig()
	var boss: Node = r[1]
	var limb: Node = _limb_at(boss, Vector2(800, 800), MathScript.KIND_LASHER, MathScript.FATE_RETREAT)
	limb.take_damage_host(1000.0, false, 0.0, 0) ## %50: henüz eşik değil
	assert(limb._ws != 3 and not limb.is_dead, "%%50'de hâlâ yüzeyde")
	limb.take_damage_host(150.0, false, 0.0, 0) ## toplam 1150 >= 1100
	assert(limb._ws == 3 and not limb.is_dead, "eşiğin %%55'inde deliğine döner (ölmez): ws %d" % limb._ws)
	assert(limb.get_meta(&"untargetable", false) == true and limb._pose_override == MathScript.POSE_HIDE, "gömülürken hedeflenemez, gömülme animasyonu")
	var pool: float = boss.item_shield_hp + boss.health
	limb.take_damage_host(5000.0, false, 0.0, 0)
	assert(is_equal_approx(pool, boss.item_shield_hp + boss.health) and not limb.is_dead, "gömülürken dokunulmaz: boss havuzu değişmez")
	assert(boss._limbs.is_empty(), "boss listesinden çıktı")
	await get_tree().create_timer(MathScript.HIDE_TIME + 0.5).timeout
	assert(not is_instance_valid(limb) or limb.is_queued_for_deletion(), "gömülme bitince silinir")
	_cleanup()


func test_a_limb_returns_to_its_hole_when_its_lifetime_runs_out() -> void:
	var r: Array = _rig([Vector2(5000, 5000)]) ## oyuncu çok uzakta: saldırı yok
	var boss: Node = r[1]
	var limb: Node = _limb_at(boss, Vector2(800, 800), MathScript.KIND_LASHER, MathScript.FATE_BURST, 2.0)
	_run_limb(limb, func() -> bool: return limb._ws == 3, 4.0)
	assert(limb._ws == 3 and limb._pose_override == MathScript.POSE_HIDE, "ömür dolunca gömülür")
	_cleanup()


func test_client_side_spawn_builds_a_plain_limb_without_scaling_shield_or_boss_flags() -> void:
	var r: Array = _rig()
	var sp: Node = r[0]
	sp._rpc_client_spawn_creature("sandworm1", Vector2(900, 900), 5, false, 777001, false, false, 3)
	var limb: Node = NetworkManager.find_enemy_by_net_id(777001)
	assert(limb != null and limb.max_health == 2000.0 and limb.health == 2000.0, "eşik çarpansız: %.0f" % limb.max_health)
	assert(limb.item_shield_max == 0.0 and not limb.is_boss and not limb.is_elite, "kalkan/boss/elit yok")
	assert(limb.has_method("begin_limb") and limb.get("hard_block_radius") == 18.0, "uzuv betiği")
	_cleanup()


# ------------------------------------------------------------------ yönetmen (yol kesme, dümdüz sıra, üst sınır)

func _step_director(boss: Node, player: Node2D, vel: Vector2, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		player.global_position += vel * DT
		boss._director_tick(DT)
		t += DT


func test_director_spawns_limbs_ahead_of_a_moving_player_never_near_him_and_within_the_cap() -> void:
	seed(20261009) ## rastgele tür/konum dizisi sabit: test kararlı
	var r: Array = _rig([Vector2(2000, 2000)])
	var boss: Node = r[1]
	var p: StubPlayer = r[2][0]
	boss._line_timer = 1.0e9 ## bu testte sıra olayı yok
	var seen: Array = []
	var t: float = 0.0
	var max_alive: int = 0
	var min_dist: float = INF
	while t < 25.0:
		p.global_position += Vector2(200, 0) * DT ## sağa yürüyor
		boss._director_tick(DT)
		t += DT
		for l in boss._limbs:
			if not seen.has(l):
				seen.append(l)
				min_dist = minf(min_dist, (l as Node2D).global_position.distance_to(p.global_position))
				if t > 1.5: ## hız tahmini oturduktan sonra: oyuncunun GİTTİĞİ yönün önünde
					assert(l.global_position.x > p.global_position.x + 60.0, "uzuv oyuncunun yolunun önünde: uzuv %.0f oyuncu %.0f" % [l.global_position.x, p.global_position.x])
		max_alive = maxi(max_alive, boss._limbs.size())
	assert(seen.size() >= 6, "25 sn'de çok sayıda uzuv çıktı (uzuvlar bu testte ölmez/gömülmez: üst sınıra dayanır): %d" % seen.size())
	assert(max_alive == MathScript.MAX_ACTIVE, "üst sınıra ulaşıldı: %d" % max_alive)
	assert(min_dist >= MathScript.MIN_PLAYER_DIST - 1.0, "hiçbir uzuv oyuncunun %.0f px'inde doğmadı: en yakın %.1f" % [MathScript.MIN_PLAYER_DIST, min_dist])
	assert(max_alive <= MathScript.MAX_ACTIVE, "aynı anda en çok %d: %d" % [MathScript.MAX_ACTIVE, max_alive])
	var spitters: int = seen.filter(func(l: Node) -> bool: return l.kind == MathScript.KIND_SPITTER).size()
	assert(spitters >= 1 and spitters < seen.size(), "hem asit atanlar hem yakın dövüşçüler var: %d / %d" % [spitters, seen.size()])
	assert(boss.global_position.distance_to(p.global_position) < 80.0, "boss konumu oyuncuların ortasında")
	_cleanup()


func test_director_builds_a_scattered_line_across_the_players_path_one_by_one() -> void:
	seed(7)
	var r: Array = _rig([Vector2(2000, 2000)])
	var boss: Node = r[1]
	var p: StubPlayer = r[2][0]
	boss._spawn_timer = 1.0e9 ## tekil çıkış yok
	boss._line_timer = 1.0e9
	_step_director(boss, p, Vector2(250, 0), 1.5) ## hız tahmini otursun
	var player_x: float = p.global_position.x
	var targets: Array = boss._targets()
	assert(boss._start_line(targets), "hareket eden oyuncuya sıra kuruldu")
	var total: int = boss._line_queue.size()
	assert(total >= MathScript.LINE_COUNT_MIN and total <= MathScript.LINE_COUNT_MAX, "4-6 uzuv sırada: %d" % total)
	for i in range(1, boss._line_queue.size()):
		assert(float(boss._line_queue[i]["t"]) > float(boss._line_queue[i - 1]["t"]), "sırayla (kademeli) çıkar")
	_step_director(boss, p, Vector2(0, 0), 0.15)
	var count_after_1: int = boss._limbs.size()
	assert(count_after_1 >= 1 and count_after_1 < total, "ilk 0,15 sn'de bir kısmı çıktı (hepsi aynı anda değil): %d/%d" % [count_after_1, total])
	_step_director(boss, p, Vector2(0, 0), 3.0)
	assert(boss._limbs.size() == total, "hepsi çıktı: %d/%d" % [boss._limbs.size(), total])
	var xs: Array = boss._limbs.map(func(l: Node) -> float: return l.global_position.x)
	var ys: Array = boss._limbs.map(func(l: Node) -> float: return l.global_position.y)
	assert(float(xs.max()) - float(xs.min()) > 3.0, "gidiş yönünde dümdüz çizgi değil (uzuvlar ayrı ayrı kayık)")
	ys.sort()
	for i in range(1, ys.size()):
		var gap: float = float(ys[i]) - float(ys[i - 1])
		assert(gap >= MathScript.LINE_SPACING_MIN - 1.0, "komşu uzuvlar dip dibe değil: %.0f px" % gap)
	for a in range(boss._limbs.size()):
		for b in range(a + 1, boss._limbs.size()):
			assert((boss._limbs[a] as Node2D).global_position.distance_to((boss._limbs[b] as Node2D).global_position) >= MathScript.LINE_SPACING_MIN - 1.0, "hiçbir iki uzuv dip dibe değil")
	assert(float(xs.min()) - player_x > MathScript.LINE_DISTANCE_MIN - MathScript.LINE_DEPTH_JITTER - 20.0, "oyuncunun önünde %.0f px" % (float(xs.min()) - player_x))
	for l in boss._limbs:
		assert(l.kind == MathScript.KIND_LASHER, "sıra uzuvları yakın dövüşçü")
	_cleanup()


func test_director_does_nothing_when_nobody_is_outside() -> void:
	var r: Array = _rig([Vector2(2000, 2000)])
	var boss: Node = r[1]
	var p: StubPlayer = r[2][0]
	p.is_indoors = true
	_step_director(boss, p, Vector2.ZERO, 4.0)
	assert(boss._limbs.is_empty(), "herkes evdeyse uzuv çıkmaz")
	p.is_indoors = false
	p.is_in_merchant_zone = true
	_step_director(boss, p, Vector2.ZERO, 3.0)
	assert(boss._limbs.is_empty(), "satıcı bölgesindeyken de çıkmaz")
	_cleanup()


# ------------------------------------------------------------------ pozlar / sert gövde

func _advance(limb: Node, seconds: float) -> Array:
	var cols: Array = []
	var t: float = 0.0
	while t < seconds:
		limb._advance_frame_sprite(DT)
		cols.append(limb.frame_sprite.frame % limb.frame_sprite.hframes)
		t += DT
	return cols


func test_limb_poses_swap_sheets_play_once_and_return_to_idle() -> void:
	var r: Array = _rig()
	var boss: Node = r[1]
	var limb: Node = _limb_at(boss, Vector2(800, 800), MathScript.KIND_LASHER, MathScript.FATE_BURST)
	limb._ew_unregister() ## kareleri C++ değil bu test yazsın
	var expect: Dictionary = {MathScript.POSE_EMERGE: [4, 0.6], MathScript.POSE_LASH: [7, 1.0], MathScript.POSE_SPIT: [6, 0.9], MathScript.POSE_HIDE: [8, 1.1]}
	for pose: int in expect.keys():
		limb._apply_worm_pose(pose)
		assert(limb._state == EnemyScript.State.ATTACK and limb.frame_sprite.hframes == int(expect[pose][0]), "poz %d: doğru sayfa (%d kare)" % [pose, limb.frame_sprite.hframes])
		var cols: Array = _advance(limb, float(expect[pose][1]))
		assert(cols[0] == 0 and cols[-1] == int(expect[pose][0]) - 1 and cols.all(func(c: int) -> bool: return c >= 0 and c < int(expect[pose][0])), "poz %d: 0'dan son kareye bir kez oynar ve orada kalır: %s" % [pose, str(cols.slice(0, 8))])
		for i in range(1, cols.size()):
			assert(cols[i] >= cols[i - 1], "geri sarmaz")
	limb._apply_worm_pose(MathScript.POSE_NONE)
	assert(limb._state == EnemyScript.State.WALK and limb.frame_sprite.hframes == 4 and limb._pose_override == 0, "poz bitince bekleme sayfası")
	limb._apply_worm_setup(MathScript.KIND_SPITTER)
	assert(limb.frame_sprite.self_modulate.g > limb.frame_sprite.self_modulate.r, "asit atanlar yeşilimsi")
	_cleanup()


func test_net_events_reach_the_limb_through_the_broadcast_router() -> void:
	var r: Array = _rig()
	var boss: Node = r[1]
	var limb: Node = _limb_at(boss, Vector2(800, 800), MathScript.KIND_LASHER, MathScript.FATE_BURST)
	var nid: int = int(limb.get_meta("network_enemy_id", 0))
	assert(nid > 0 and NetworkManager.find_enemy_by_net_id(nid) == limb, "ağ kimliği kayıtlı")
	limb._ew_unregister()
	NetworkManager.broadcast_enemy_vfx(nid, "worm_pose", {"pose": MathScript.POSE_SPIT}) ## RPC yönlendiricisinin yerel gövdesi
	assert(limb._pose_override == MathScript.POSE_SPIT, "worm_pose limbe ulaştı")
	NetworkManager.broadcast_enemy_vfx(nid, "worm_setup", {"kind": MathScript.KIND_SPITTER})
	assert(limb.kind == MathScript.KIND_SPITTER, "worm_setup limbe ulaştı")
	var boss_nid: int = int(boss.get_meta("network_enemy_id", 0))
	NetworkManager.broadcast_enemy_vfx(boss_nid, "worm_rumble", {"v": 2}) ## başsızda sessiz: hata vermemeli
	NetworkManager.broadcast_enemy_vfx(boss_nid, "worm_growl", {"v": 1})
	NetworkManager.broadcast_enemy_vfx(boss_nid, "worm_ambient", {})
	_cleanup()


func _make_player() -> Node:
	_cleanup()
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = ASSASIN
	GameManager.selected_character = int(Characters.DEFS[ASSASIN]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_made.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	return p


func test_real_player_cannot_walk_into_a_limb_but_can_walk_away_and_the_limb_is_never_pushed() -> void:
	var p: Node = _make_player()
	var limb: Node = LimbScene.instantiate()
	add_child(limb)
	_made.append(limb)
	limb.global_position = Vector2(1000.0 + 26.0, 1000.0) ## sert gövde: 18 + 11,4 = 29,4 px (normal yaratıkta yumuşak blok ~11 px)
	await get_tree().physics_frame
	p.velocity = Vector2(220.0, 0.0)
	p._block_movement_into_enemies()
	assert(p.velocity.x <= 0.01, "uzva doğru yürüyemez: %s" % str(p.velocity))
	assert(limb._knockback_velocity == Vector2.ZERO, "uzuv itilmez")
	p.velocity = Vector2(-220.0, 0.0)
	p._block_movement_into_enemies()
	assert(p.velocity.x < -200.0, "uzaklaşabilir (tuzak yok): %s" % str(p.velocity))
	p.velocity = Vector2(0.0, 200.0)
	p._block_movement_into_enemies()
	assert(p.velocity.y > 150.0, "yandan kayabilir: %s" % str(p.velocity))
	## Aynı yerde normal bir yaratık bu kadar yakında engellemez (kıyas): yumuşak blok yarıçapı çok küçük.
	var soft_sep: float = (20.0 + 11.4) * GameManager.BODY_BLOCK_SCALE
	assert(soft_sep < 26.0, "normal yaratığın bloğu %.1f px < 26: sert gövde gerçekten farklı" % soft_sep)
	p.free()
	_made.erase(p)
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene
	_cleanup()


# ------------------------------------------------------------------ ağ güvenliği: host'a özel RPC'ler başka göndericiyi reddeder

func test_host_only_rpcs_used_by_the_bosses_reject_other_senders() -> void:
	## 2026-10-09 denetimi: broadcast_enemy_vfx / forward_damage_to_peer / forward_special_damage_to_peer'de gönderen kontrolü yoktu (sahte death_state, sahte hasar).
	var src: String = (NetworkManager.get_script() as GDScript).source_code
	for fn: String in ["broadcast_enemy_vfx", "forward_special_damage_to_peer", "forward_damage_to_peer", "forward_player_fling_to_peer", "broadcast_enemy_ability_fx"]:
		var i: int = src.find("func %s(" % fn)
		assert(i >= 0, "RPC bulundu: %s" % fn)
		assert(src.substr(i, 700).contains("_from_host()"), "%s ilk satırlarda _from_host() korumalı" % fn)
	assert(NetworkManager._from_host(), "tekli oyunda yerel çağrı geçer")
