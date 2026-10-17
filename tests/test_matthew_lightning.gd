extends Node

## MATTHEW REWORK (2026-10-12, madde 98): köpek gitti, kit şimşek oldu.
##   Pasif Yıldırım Hızı (hareketle %1/sn, en çok %30 hareket + saldırı hızı, dururken 5 sn'de söner; tam hızda iz sersemletir + %80 AP)
##   Q Şimşek Hücumu (köpek gerekmez), E Elektrik Topu (dokunulmaz, silahlar içeride, %200 AP + bilardo), R Yıldırım Kalkanı (parıltı).
## Kapsam: tek kaynaktaki formüller (matthew_lightning.gd), sprite sayfası sözleşmesi, player.gd mekanikleri, kukla (remote_player.gd).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const BoltScene: PackedScene = preload("res://scenes/fx_matthew_bolt.tscn")
const ML: GDScript = preload("res://scripts/matthew_lightning.gd")
const TrailScript: GDScript = preload("res://scripts/fx_matthew_trail.gd")
const MATTHEW := 3

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = MATTHEW
	GameManager.selected_character = int(Characters.DEFS[MATTHEW]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(3000.0, 3000.0)
	player.damage_bonus = 100.0
	player.crit_chance_bonus = -10.0 ## yetenek kritiği kapalı: hasar miktarları tam ölçülsün
	return player


func _enemy(pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	_spawned.append(e)
	return e


func _lost(e: Node2D) -> float:
	return 600000.0 - float(e.health)


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _phys(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame


# ------------------------------------------------------------------ formüller

func test_momentum_formulas() -> void:
	var m: float = 0.0
	for _i in range(100):
		m = ML.step_momentum(m, true, 0.1) ## 10 sn hareket
	assert(is_equal_approx(m, 0.10), "10 sn harekette %%10: %s" % m)
	for _i in range(400):
		m = ML.step_momentum(m, true, 0.1)
	assert(is_equal_approx(m, ML.MOMENTUM_MAX), "tavan %%15: %s" % m)
	assert(ML.is_empowered(m) and ML.trail_level(m, true) == 2 and ML.trail_level(m, false) == 0, "tam hızda iz güçlenir, dururken iz yok")
	assert(ML.trail_level(0.12, true) == 1, "tavanın altında normal iz")
	var half: float = ML.step_momentum(m, false, 2.5)
	assert(is_equal_approx(half, ML.MOMENTUM_MAX * 0.5), "dururken 2,5 sn'de yarısı: %s" % half)
	assert(is_zero_approx(ML.step_momentum(m, false, 5.0)), "dururken tam bonus 5 sn'de biter")
	assert(is_equal_approx(ML.MOMENTUM_MAX, 0.15), "pasif tavanı %15 (2026-10-14)")
	assert(is_equal_approx(ML.fire_interval_mult(30), 1.0 / 1.15) and is_equal_approx(ML.fire_interval_mult(0), 1.0), "her %1 hareket hızı = %0,5 saldırı hızı")
	assert(is_equal_approx(ML.fire_interval_mult(100), 1.0 / 1.5), "%100 hareket hızı = %50 saldırı hızı")


func test_ball_and_shield_formulas() -> void:
	assert(is_equal_approx(ML.ball_damage_mult(252.0, false), 1.0), "evrimsiz hız hasarı etkilemez")
	assert(is_equal_approx(ML.ball_damage_mult(252.0, true), 1.25), "her 10 hareket hızı = +%%1: %s" % ML.ball_damage_mult(252.0, true))
	## Bilardo: fırlayanın yolundaki İLK yaratık; yolun dışındaki / arkadaki sayılmaz.
	var others: Array = [[Vector2(120, 0), 20.0, "uzak"], [Vector2(70, 4), 20.0, "yakin"], [Vector2(60, 90), 20.0, "yanda"], [Vector2(-50, 0), 20.0, "arkada"]]
	var found: Array = ML.first_on_path(Vector2.ZERO, Vector2.RIGHT, 140.0, 20.0, others)
	assert(found.size() == 2 and str(found[0]) == "yakin", "yoldaki ilk yaratık: %s" % str(found))
	assert(ML.first_on_path(Vector2.ZERO, Vector2.UP, 140.0, 20.0, others).is_empty(), "boş yolda çarpışma yok")
	assert(ML.first_on_path(Vector2.ZERO, Vector2.RIGHT, 10.0, 20.0, [[Vector2(120, 0), 20.0, "uzak"]]).is_empty(), "menzilin ötesi sayılmaz")
	var t_full: float = ML.push_travel_time(140.0, 140.0)
	var t_part: float = ML.push_travel_time(140.0, 34.0)
	assert(t_part > 0.0 and t_part < t_full and t_full < 0.6, "fırlayan yaratık yakındakine daha çabuk varır: %s / %s" % [t_part, t_full])
	assert(is_zero_approx(ML.glow_level(1000.0, 1000.0)) and is_equal_approx(ML.glow_level(200.0, 1000.0), 0.8), "parıltı = yıpranma oranı")
	assert(ML.glow_step(0.84) == 8 and ML.glow_step(1.0) == 10 and ML.glow_step(0.0) == 0, "ağ basamağı 0..10")
	assert(ML.pack_state(2, true, 7) == [2, 1, 7], "ağ paketi [top, güçlenmiş, parıltı]")


func test_sheets_match_the_table() -> void:
	for kind: String in ML.SHEETS:
		var cfg: Dictionary = ML.SHEETS[kind]
		var tex: Texture2D = ML.sheet_texture(kind)
		assert(tex != null, "sayfa yok: " + kind)
		var cols: int = int(cfg.get("cols", cfg["n"]))
		@warning_ignore("integer_division")
		var rows: int = (int(cfg["n"]) + cols - 1) / cols
		assert(tex.get_size() == Vector2(int(cfg["fw"]) * cols, int(cfg["fh"]) * rows), "%s sayfa boyutu tabloyla uyuşmuyor: %s" % [kind, str(tex.get_size())])
		var sf: SpriteFrames = ML.frames(kind)
		assert(sf != null and sf.get_frame_count(&"fx") == int(cfg["n"]), kind + " kare sayısı")
		assert(sf.get_animation_loop(&"fx") == bool(cfg.get("loop", false)), kind + " döngü ayarı")
	for kind: String in ["trail", "trail_max"]:
		var tex: Texture2D = ML.sheet_texture(kind)
		assert(tex != null and tex.get_size() == Vector2(ML.TRAIL_TILE.x * ML.TRAIL_STAGES, ML.TRAIL_TILE.y * ML.TRAIL_VARIANTS), kind + " iz sayfası 8 evre x 3 varyant")
	for icon: String in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon"]:
		assert(ResourceLoader.exists(str(Characters.DEFS[MATTHEW][icon])), "ikon yok: " + str(Characters.DEFS[MATTHEW][icon]))


func test_bolt_fx_is_baked_tiles_laid_toward_the_target_and_frees_itself() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var bolt: Node2D = BoltScene.instantiate()
	bolt.rotation = 0.6
	add_child(bolt)
	bolt.global_position = Vector2(500.3, 400.7)
	bolt.call("setup", 180.0, Color.WHITE)
	assert(is_zero_approx(bolt.rotation), "düğüm döndürülmez, parçalar döner")
	var snapped_pos: Vector2 = (bolt.global_position / ML.WORLD_TEXEL).round() * ML.WORLD_TEXEL
	assert(bolt.global_position.distance_to(snapped_pos) < 0.01, "başlangıç texel ızgarasına oturur")
	var tiles: Array = (bolt.get("_tiles") as Array).duplicate()
	var expect_n: int = maxi(2, roundi(180.0 / ML.WORLD_TEXEL / float(ML.BOLT_TILE_LEN)))
	assert(tiles.size() == expect_n, "parça sayısı uzunluğa göre: %d / %d" % [tiles.size(), expect_n])
	assert(int(tiles[0][1]) < ML.BOLT_ROW_MID and int(tiles[tiles.size() - 1][1]) >= ML.BOLT_ROW_END, "baş ve son parça doğru satırdan")
	## Parçalar hedef doğrultusunda ve son parçanın ucu hedefe varıyor (uzunluk 180, açı 0,6 rad).
	var dir: Vector2 = Vector2.RIGHT.rotated(0.6)
	var last: Sprite2D = tiles[tiles.size() - 1][0]
	assert(is_equal_approx(last.rotation, dir.angle()), "parçalar hedefe dönük")
	var tip: Vector2 = last.position + dir * (float(ML.BOLT_TILE_LEN) * last.scale.x)
	assert(tip.distance_to(dir * 180.0) < 2.0, "şimşek hedefe varıyor: uç %s" % tip)
	var rect0: Rect2 = (tiles[0][0] as Sprite2D).region_rect
	await get_tree().create_timer(0.12).timeout
	assert(is_instance_valid(bolt) and (tiles[0][0] as Sprite2D).region_rect.position.x > rect0.position.x, "evre ilerleyince sayfada sağ sütuna kayar")
	await get_tree().create_timer(0.4).timeout
	assert(not is_instance_valid(bolt), "şimşek 6 evreden sonra kendini siler")


## Aynı konum + uzunluk iki ekranda AYNI parça dizisini seçer (ağda yalnız konum/uzunluk/açı gider).
func test_bolt_tile_choice_is_deterministic_for_remote_copies() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rows: Array = []
	for _i in range(2):
		var bolt: Node2D = BoltScene.instantiate()
		bolt.rotation = 1.1
		add_child(bolt)
		bolt.global_position = Vector2(900.0, 700.0)
		bolt.call("setup", 260.0, Color.WHITE)
		var r: Array = []
		for t: Array in bolt.get("_tiles"):
			r.append(int(t[1]))
		rows.append(r)
		bolt.queue_free()
	assert(rows[0] == rows[1], "aynı tohum aynı parçalar: %s / %s" % [rows[0], rows[1]])


## Oyuncu kökü sahnede 0,5 ölçekli (main.tscn): dünya ofsetleri ve temas yarıçapı buna göre olmalı (testlerin geri kalanı ölçek 1 ile kurar).
func test_world_sizes_follow_the_half_scaled_player_root() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	player.scale = Vector2(0.5, 0.5)
	assert(player._matthew_body_center().is_equal_approx(player.global_position + ML.BODY_CENTER * 0.5), "gövde ortası kök ölçeğiyle çarpılır")
	## Top sayfası 17 px yarıçap, karaktere bağlı (TEXEL yerel x 0,5): temas yarıçapı görselle aynı.
	assert(absf(ML.BALL_REACH - 17.0 * ML.TEXEL * 0.5) < 0.5, "topun temas yarıçapı görsel yarıçapıyla aynı: %s" % ML.BALL_REACH)
	## Dünyada duran efektlerin pikseli = Matthew'in pikselinin dünyadaki boyu.
	var char_px: float = float(Characters.DEFS[MATTHEW]["scale"].x) * EntityScale.SIZE * 0.5
	assert(absf(ML.WORLD_TEXEL - char_px) < 0.005, "WORLD_TEXEL = Matthew pikseli: %s / %s" % [ML.WORLD_TEXEL, char_px])
	assert(is_equal_approx(ML.TRAIL_STEP, ML.TRAIL_TILE.x * ML.WORLD_TEXEL), "iz damgaları uç uca gelir")
	var spark: Node2D = (load("res://scenes/fx_matthew_spark.tscn") as PackedScene).instantiate()
	add_child(spark)
	_spawned.append(spark)
	assert(is_equal_approx((spark.get_child(0) as Node2D).scale.x, ML.WORLD_TEXEL), "isabet kıvılcımı dünya pikseliyle çizilir")
	_cleanup()


# ------------------------------------------------------------------ kit / pasif

func test_kit_has_no_dog_and_new_skill_ids() -> void:
	var def: Dictionary = Characters.DEFS[MATTHEW]
	assert(int(def["skill"]) == ML.Q_SKILL_ID and int(def["skill2"]) == ML.E_SKILL_ID and int(def["skill3"]) == ML.R_SKILL_ID, "Q 43 / E 50 / R 9")
	var player: Node = _make_player()
	await _phys(6)
	assert(player.get("_matthew_pet") == null and not bool(player.get("_matthew_pet_alive")), "köpek artık doğmuyor")
	assert(get_tree().get_nodes_in_group("player_ally").is_empty(), "sahnede evcil hayvan yok")
	assert(is_equal_approx(float(player._skill2_timing_for(ML.E_SKILL_ID)["duration"]), ML.BALL_DURATION), "E 3 sn")
	assert(is_equal_approx(float(player._skill2_timing_for(ML.E_SKILL_ID)["cooldown"]), ML.BALL_COOLDOWN), "E 20 sn bekleme")
	_cleanup()


func test_passive_gives_move_and_attack_speed() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	var move0: float = player.get_effective_move_speed()
	var iv0: float = player.get_attack_interval_mult()
	var over0: float = player.get_attack_speed_overflow_percent()
	## 10 sn kesintisiz hareket: %10
	player.velocity = Vector2(200.0, 0.0)
	for _i in range(100):
		player._process_matthew_lightning(0.1)
	assert(is_equal_approx(float(player._matthew_momentum), 0.10) and int(player._matthew_move_percent) == 10, "10 sn'de %%10: %s" % player._matthew_momentum)
	assert(is_equal_approx(player.get_effective_move_speed(), move0 * 1.10), "hareket hızı +%10")
	assert(is_equal_approx(player.get_attack_interval_mult(), iv0 / 1.05), "hareket hızı +%10 -> saldırı hızı +%5")
	for _i in range(300):
		player._process_matthew_lightning(0.1)
	assert(is_equal_approx(float(player._matthew_momentum), 0.15), "pasif tavanı %15")
	assert(is_equal_approx(player.get_effective_move_speed(), move0 * 1.15), "tavan: hareket hızı +%15")
	assert(is_equal_approx(player.get_attack_interval_mult(), iv0 / 1.075), "tavan: saldırı hızı +%7,5")
	assert(is_equal_approx(player.get_attack_speed_overflow_percent(), over0), "pasif saldırı hızı taşma->saldırı gücü dönüşümüne girmez")
	assert(int(player.matthew_net_state()[1]) == 1, "tam hız ağa 'güçlenmiş' gider")
	## Durunca 5 sn'de söner.
	player.velocity = Vector2.ZERO
	for _i in range(25):
		player._process_matthew_lightning(0.1)
	assert(is_equal_approx(float(player._matthew_momentum), 0.075), "2,5 sn duruşta yarıya iner: %s" % player._matthew_momentum)
	for _i in range(26):
		player._process_matthew_lightning(0.1)
	assert(is_zero_approx(float(player._matthew_momentum)) and is_equal_approx(player.get_effective_move_speed(), move0), "5 sn duruşta bonus biter")
	assert(is_equal_approx(player.get_attack_interval_mult(), iv0), "saldırı hızı da geri döner")
	_cleanup()


func test_trail_stamps_follow_the_owner_and_fade() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var owner_node := Node2D.new()
	add_child(owner_node)
	_spawned.append(owner_node)
	owner_node.global_position = Vector2(2000.0, 2000.0)
	var trail := Node.new()
	trail.set_script(TrailScript)
	owner_node.add_child(trail)
	trail.set("level", 1)
	for _i in range(12):
		owner_node.global_position.x += 10.0
		await get_tree().process_frame
	var stamps: Array = trail.get("_stamps")
	assert(stamps.size() >= 4, "120 birim yolda en az 4 damga: %d" % stamps.size())
	assert((trail.get("points") as Array).is_empty(), "normal iz vuruş noktası bırakmaz")
	var first: Sprite2D = stamps[0][0]
	assert(first.get_parent() == get_tree().current_scene and is_zero_approx(first.rotation), "damga dünyada kalır, sağa giderken döndürülmez")
	assert(first.texture == ML.sheet_texture("trail"), "normal iz sayfası")
	## Güçlenmiş iz: ayrı sayfa + vuruş noktaları.
	trail.set("level", 2)
	for _i in range(6):
		owner_node.global_position.y += 10.0
		await get_tree().process_frame
	var pts: PackedVector2Array = trail.call("live_points")
	assert(pts.size() >= 2, "güçlenmiş iz noktaları: %d" % pts.size())
	var last: Sprite2D = (trail.get("_stamps") as Array).back()[0]
	assert(last.texture == ML.sheet_texture("trail_max") and absf(last.rotation - PI / 2.0) < 0.01, "güçlenmiş sayfa, aşağı giderken 90 derece")
	## Dururken yeni damga yok; 1 sn sonra hepsi söner.
	trail.set("level", 0)
	await get_tree().create_timer(ML.TRAIL_LIFE + 0.15).timeout
	assert((trail.get("_stamps") as Array).is_empty() and (trail.call("live_points") as PackedVector2Array).is_empty(), "iz 1 sn'de söner")
	assert(not is_instance_valid(first), "sönen damga silinir")
	_cleanup()


func test_empowered_trail_stuns_and_damages_once_per_three_seconds() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	player._process_matthew_lightning(0.016) ## iz düğümünü kurar
	var trail: Node = player.get("_matthew_trail")
	assert(is_instance_valid(trail), "iz düğümü kuruldu")
	var e: Node2D = _enemy(player.global_position + Vector2(200.0, 0.0))
	var far: Node2D = _enemy(player.global_position + Vector2(200.0, 300.0))
	(trail.get("points") as Array).append([e.global_position + Vector2(6.0, 0.0), float(trail.get("_clock"))])
	player._matthew_trail_scan(1.0)
	assert(is_equal_approx(_lost(e), 80.0), "güçlenmiş iz %%80 AP verir: %s" % _lost(e))
	assert(bool(e.is_stunned), "güçlenmiş iz sersemletir")
	assert(is_zero_approx(_lost(far)), "ize değmeyen yaratık etkilenmez")
	player._matthew_trail_scan(1.0)
	assert(is_equal_approx(_lost(e), 80.0), "aynı yaratık 3 sn içinde ikinci kez vurulmaz")
	_cleanup()


# ------------------------------------------------------------------ Q

func test_q_strikes_nearest_targets_without_a_pet() -> void:
	var player: Node = _make_player()
	var a: Node2D = _enemy(player.global_position + Vector2(90.0, 0.0))
	var b: Node2D = _enemy(player.global_position + Vector2(0.0, 140.0))
	player._skill_matthew_lightning_strike()
	assert(is_equal_approx(_lost(a), 110.0), "ilk şimşek en yakına, %%110 AP: %s" % _lost(a))
	assert(is_zero_approx(_lost(b)), "ikinci hedef sırasını bekler")
	var bolts: int = 0
	for n: Node in get_tree().current_scene.get_children():
		if n.scene_file_path == BoltScene.resource_path:
			bolts += 1
	assert(bolts == 1, "şimşek efekti doğdu: %d" % bolts)
	await get_tree().create_timer(0.4).timeout
	assert(is_equal_approx(_lost(a), 110.0) and is_equal_approx(_lost(b), 110.0), "her hedef bir kez vurulur: %s / %s" % [_lost(a), _lost(b)])
	_cleanup()


# ------------------------------------------------------------------ E

func test_ball_form_is_invulnerable_and_pulls_weapons_in() -> void:
	var player: Node = _make_player()
	await _phys(2)
	var hp0: float = player.health
	var move0: float = player.get_effective_move_speed()
	player._skill_matthew_ball()
	assert(bool(player._matthew_ball_active) and not player.anim.visible, "top formunda karakter sprite'ı gizli")
	assert(is_instance_valid(player.get("_matthew_ball_fx")), "top görseli kuruldu")
	assert(player.is_ghost_now() and player._vampir_weapons_absorbed(), "yaratıkların içinden geçer, silahlar içeride")
	assert(is_equal_approx(player.get_effective_move_speed(), move0 * ML.BALL_SPEED_MULT), "%20 toplam hareket hızı")
	player.take_damage(500.0)
	assert(is_equal_approx(player.health, hp0), "top formunda dokunulmaz")
	assert(int(player.matthew_net_state()[0]) == 1, "ağ durumu: top açık")
	player._end_matthew_ball()
	assert(not bool(player._matthew_ball_active) and player.anim.visible, "form bitince karakter geri görünür")
	assert(not player.is_ghost_now() and not player._vampir_weapons_absorbed(), "form bitince silahlar geri çıkar")
	assert(is_equal_approx(player.get_effective_move_speed(), move0), "hız bonusu biter")
	## Geliştirmeler: hız %30, final büyük top.
	player.apply_skill_evolution("matthew_e4", true)
	player.apply_skill_evolution("matthew_ef", true)
	player._skill_matthew_ball()
	assert(is_equal_approx(player.get_effective_move_speed(), move0 * ML.EVO_BALL_SPEED_MULT), "Aşırı Yük: %30")
	assert(bool(player.get("_matthew_ball_fx").get("big")) and int(player.matthew_net_state()[0]) == 2, "Dev Küre: büyük sayfa + ağda 2")
	assert(is_equal_approx(player._matthew_ball_radius(), ML.BALL_REACH * ML.BALL_BIG_MULT), "Dev Küre: temas %50 geniş")
	player._end_matthew_ball()
	_cleanup()


func test_ball_hits_fling_and_the_flung_creature_burns_the_next() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	var center: Vector2 = player.global_position + ML.BODY_CENTER
	var a: Node2D = _enemy(center + Vector2(25.0, 0.0))
	var b: Node2D = _enemy(center + Vector2(115.0, 0.0))
	var side: Node2D = _enemy(center + Vector2(30.0, 220.0))
	player._skill_matthew_ball()
	player.velocity = Vector2(250.0, 0.0)
	var a_x0: float = a.global_position.x
	player._process_matthew_ball(0.016)
	assert(is_equal_approx(_lost(a), 200.0), "topun değdiği yaratık %%200 AP alır: %s" % _lost(a))
	assert(is_zero_approx(_lost(b)), "ikinci yaratık çarpışma ANINDA yanar, hemen değil")
	player._process_matthew_ball(0.016)
	assert(is_equal_approx(_lost(a), 200.0), "aynı yaratık 0,5 sn dolmadan tekrar vurulmaz")
	await _phys(20)
	assert(a.global_position.x > a_x0 + 20.0, "değdiği yaratık ileri fırlar: %s" % (a.global_position.x - a_x0))
	assert(is_equal_approx(_lost(b), 200.0), "fırlayanın çarptığı yaratık da %%200 AP alır: %s" % _lost(b))
	assert(is_zero_approx(_lost(side)), "yolun dışındaki yaratık etkilenmez")
	## 0,5 sn sonra aynı yaratık yeniden vurulabilir (hâlâ topa değiyorsa).
	a.global_position = center + Vector2(25.0, 0.0)
	player._process_matthew_ball(0.6)
	player._process_matthew_ball(0.016)
	assert(is_equal_approx(_lost(a), 400.0), "0,5 sn sonra tekrar vurur: %s" % _lost(a))
	player._end_matthew_ball()
	_cleanup()


func test_ball_evolutions_scale_damage_and_heal() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	player.apply_skill_evolution("matthew_e1", true)
	player.apply_skill_evolution("matthew_e3", true)
	player.max_health = 1000.0
	player.health = 400.0
	var e: Node2D = _enemy(player.global_position + ML.BODY_CENTER + Vector2(25.0, 0.0))
	player._skill_matthew_ball()
	var mult: float = ML.ball_damage_mult(player.get_effective_move_speed(), true)
	## Sayı = o anki gerçek hareket hızı (top formunun %20'si dahil); taban ~82 -> formda ~98 -> +%9.
	assert(mult > 1.0 and mult > ML.ball_damage_mult(player.get_base_move_speed() * 0.5, true), "top formundaki hızla çarpan büyür: %s" % mult)
	player._process_matthew_ball(0.016)
	assert(is_equal_approx(_lost(e), 200.0 * mult), "Hız Akımı: hasar hareket hızıyla artar: %s" % _lost(e))
	assert(player.health > 400.0, "Geri Besleme: verilen hasarın bir kısmı can olur: %s" % player.health)
	player._end_matthew_ball()
	_cleanup()


# ------------------------------------------------------------------ R

func test_shield_needs_no_pet_and_glows_as_it_wears() -> void:
	var player: Node = _make_player()
	await _phys(2)
	player._skill_shield_dome()
	assert(bool(player.matthew_dome_active), "köpek olmadan da kalkan açılır")
	assert(is_equal_approx(float(player.matthew_dome_hp), 1000.0) and is_equal_approx(float(player.matthew_dome_max), 1000.0), "kapasite %1000 AP")
	var fx: Node = player.get("_matthew_fox_shield_fx")
	assert(is_instance_valid(fx) and fx.scene_file_path == "res://scenes/fx_matthew_lightning_shield.tscn", "yıldırım kalkanı sahnesi")
	player._matthew_update_glow()
	assert(player.anim.material == null, "kalkan doluyken parıltı yok")
	var hp0: float = player.health
	player.take_damage(800.0)
	assert(is_equal_approx(player.health, hp0) and is_equal_approx(float(player.matthew_dome_hp), 200.0), "kalkan hasarı emer")
	player._matthew_update_glow()
	var mat: ShaderMaterial = player.anim.material as ShaderMaterial
	assert(mat != null and is_equal_approx(float(mat.get_shader_parameter("level")), 0.8), "kalkan %80 yıpranınca parıltı 0,8")
	assert(int(player.matthew_net_state()[2]) == 8, "ağ parıltı basamağı 8")
	## Kalkan açıkken Q çalışır (eskiden köpek kalkana dönüştüğü için çalışmıyordu).
	var e: Node2D = _enemy(player.global_position + Vector2(80.0, 0.0))
	player._skill_matthew_lightning_strike()
	assert(is_equal_approx(_lost(e), 110.0), "kalkan açıkken Şimşek Hücumu vurur: %s" % _lost(e))
	player._pop_matthew_dome(false)
	player._matthew_update_glow()
	assert(not bool(player.matthew_dome_active) and player.anim.material == null, "kalkan kapanınca parıltı söner")
	await get_tree().create_timer(0.3).timeout
	_cleanup()


## Tuş akışı: yetenekler standart skill/skill2/skill3 makinelerinden geçer (bedel, süre, bekleme, bitiş temizliği).
func test_skills_run_through_the_standard_state_machines() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	player.item_shield_max = 1000.0
	player.item_shield_hp = 1000.0
	## Q: hedef yokken de çökmez, bekleme süresine girer.
	player._activate_skill()
	assert(player.skill_state != "ready", "Q kullanıldı: %s" % player.skill_state)
	## E: 3 sn top, sonra insan formu + 20 sn bekleme.
	player._activate_skill2()
	assert(player.skill2_state == "active" and bool(player._matthew_ball_active), "E top formunu açar: %s" % player.skill2_state)
	player._process_skill2(ML.BALL_DURATION - 0.1)
	assert(bool(player._matthew_ball_active), "süre dolmadan form sürer")
	player._process_skill2(0.2)
	assert(not bool(player._matthew_ball_active) and player.anim.visible, "3 sn sonunda form biter")
	assert(player.skill2_state == "cooldown" and is_equal_approx(float(player._skill2_cooldown), ML.BALL_COOLDOWN), "E 20 sn beklemeye girer")
	## Yere düşünce form hemen kapanır (silahlar geri çıkabilsin).
	player.skill2_state = "ready"
	player._activate_skill2()
	assert(bool(player._matthew_ball_active), "E yeniden açıldı")
	player.is_downed = true
	player._process_matthew_form(0.016)
	assert(not bool(player._matthew_ball_active) and player.skill2_state == "cooldown", "düşünce top formu kapanır, bekleme başlar")
	player.is_downed = false
	## R: 15 sn kalkan, süre dolunca kapanır.
	player._activate_skill3()
	assert(player.skill3_state == "active" and bool(player.matthew_dome_active), "R kalkanı açar: %s" % player.skill3_state)
	player._process_skill3(15.1)
	assert(not bool(player.matthew_dome_active), "15 sn sonunda kalkan kapanır")
	await get_tree().create_timer(0.3).timeout
	_cleanup()


# ------------------------------------------------------------------ kukla (diğer oyuncuların ekranı)

func test_remote_copy_builds_ball_trail_and_glow_from_net_state() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.global_position = Vector2(4000.0, 4000.0)
	rp.set_physics_process(false) ## kukla ağ hedefine doğru çekilmesin - hareketi test sürüyor
	rp._apply_matthew_net_state(null)
	assert(not bool(rp.get("_matthew_has_mt")), "Matthew olmayan kuklada hiçbir şey kurulmaz")
	rp._apply_matthew_net_state(ML.pack_state(2, true, 6))
	assert(int(rp.get("_matthew_ball")) == 2 and not rp.anim.visible, "kuklada top formu: sprite gizli")
	var ball: Node = rp.get("_matthew_ball_fx")
	assert(is_instance_valid(ball) and bool(ball.get("big")), "kuklada büyük top görseli")
	assert(rp.is_ghost_now(), "host'taki yaratıklar toptaki kuklanın içinden geçer")
	var mat: ShaderMaterial = rp.anim.material as ShaderMaterial
	assert(mat != null and is_equal_approx(float(mat.get_shader_parameter("level")), 0.6), "kuklada kalkan parıltısı")
	## Kukla hareket ettikçe kendi izini bırakır (güçlenmiş).
	for _i in range(10):
		rp.global_position.x += 8.0
		rp._process_matthew_remote(1.0 / 60.0)
		await get_tree().process_frame
	var trail: Node = rp.get("_matthew_trail")
	assert(is_instance_valid(trail) and int(trail.get("level")) == 2, "kuklada güçlenmiş iz seviyesi")
	assert((trail.get("_stamps") as Array).size() >= 2, "kukla iz damgası bırakır: %d" % (trail.get("_stamps") as Array).size())
	rp._apply_matthew_net_state(ML.pack_state(0, false, 0))
	assert(int(rp.get("_matthew_ball")) == 0 and rp.anim.visible and rp.anim.material == null, "durum kapanınca kukla normale döner")
	assert(not rp.is_ghost_now(), "top bitince kukla yeniden katı")
	_cleanup()


## 2026-10-14: saldırı hızı TOPLAM hareket hızından gelir (her kaynak): kart/eşya hızı da sayılır, her %1 = %0,5; Matthew dışında etki yok; %600 sınırı korunur.
func test_attack_speed_follows_total_move_speed_from_any_source() -> void:
	var player: Node = _make_player()
	player.set_physics_process(false)
	var iv0: float = player.get_attack_interval_mult()
	var over0: float = player.get_attack_speed_overflow_percent()
	player.speed_card_percent = 0.40 ## hız kartları +%40
	player.item_speed_percent = 0.20 ## eşya +%20
	player._matthew_refresh_move_percent()
	assert(int(player._matthew_move_percent) == 60, "toplam %%60: %d" % player._matthew_move_percent)
	assert(is_equal_approx(player.get_attack_interval_mult(), iv0 / 1.30), "%%60 hareket hızı -> %%30 saldırı hızı: %s" % (iv0 / player.get_attack_interval_mult()))
	assert(is_equal_approx(player.get_attack_speed_overflow_percent(), over0), "pasifin saldırı hızı taşma->saldırı gücü dönüşümüne girmez")
	## Çok büyük hız: saldırı hızı genel sınırda (%600) durur.
	player.speed_card_percent = 20.0
	player._matthew_refresh_move_percent()
	assert(is_equal_approx(1.0 / player.get_attack_interval_mult() - 1.0, GameManager.ATTACK_SPEED_CAP_PERCENT / 100.0), "toplam saldırı hızı %%600'ü aşmaz")
	player.speed_card_percent = 0.0
	player.item_speed_percent = 0.0
	player._matthew_refresh_move_percent()
	assert(int(player._matthew_move_percent) == 0 and is_equal_approx(player.get_attack_interval_mult(), iv0), "bonus kalkınca saldırı hızı geri döner")
	_cleanup()
