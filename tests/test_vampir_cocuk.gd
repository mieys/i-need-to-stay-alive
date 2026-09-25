extends Node

## Kullanıcı isteği (2026-09-21): yeni karakter "Vampir Çocuk" (roster id 13) - yetenekleri kalkan yerine can harcar
## (Q/E maks. canın %4'ü, R açıkken saniyede %5'i), pasif %1 can emme + her 1 saldırı gücü için 1 can.
##   Q: yakındaki 3 düşmana %130 hasar + kalıcı +1 maks. can (6sn)
##   E: 5sn yarasa formu: %60 hız, %80 hasar azaltma, temas hasarı %80, silahlar gövdeye çekilir (22sn)
##   R: 6 küçük yarasa, %60 hasar, dönünce saldırı gücünün %5'i kadar can, hız saldırı hızıyla artar
## Bu test oyun mantığını (player.gd), paylaşılan formülleri (vampir_math.gd) ve diğer istemcideki kozmetik kopyayı
## (remote_player.gd) doğrular - kaster görür ama diğerleri görmez hata sınıfı için (bkz. CLAUDE.md).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const VampirMath: GDScript = preload("res://scripts/vampir_math.gd")
const SwarmScript: GDScript = preload("res://scripts/vampir_bat_swarm.gd")
const CharAnim: GDScript = preload("res://scripts/char_anim.gd")
const ReadingUiWatcher: GDScript = preload("res://scripts/reading_ui_watcher.gd")
const FoodScene: PackedScene = preload("res://scenes/food_drop.tscn")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var _body_radius: float = 20.0
	var hits: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)


## player.gd'nin silah listesinden okuduğu alanlar (weapon.gd'nin ilgili yüzeyi).
class FakeWeapon extends Node2D:
	var icon_sprite: Node2D = Node2D.new()
	var shadow_sprite: Sprite2D = Sprite2D.new()
	var _is_uzunkilic: bool = false
	var _floaty_global_pos: Vector2 = Vector2(5.0, 5.0)
	var continuous_beam: bool = false
	var is_reloading: bool = false
	var last_offset: Vector2 = Vector2.ZERO

	func set_icon_offset(offset: Vector2) -> void:
		last_offset = offset

	func _update_icon_shadow() -> void:
		pass


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 13
	GameManager.selected_character = 40
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	player._last_damage_taken_at_msec = -999999
	return player


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Tam sağlık + bilinen saldırı gücü ile başlatır (pasif maks. can senkronu ilk karede çalışsın).
func _ready_player(player: Node) -> void:
	player._process_vampir(0.016)
	player.health = player.max_health


# ------------------------------------------------------------------ katalog / dosyalar

func test_roster_entry_and_files() -> void:
	var def: Dictionary = Characters.DEFS[13]
	assert(str(def["name"]) == "Vampir Çocuk", "isim: %s" % str(def["name"]))
	assert(int(def["skill"]) == 40 and int(def["skill2"]) == 41 and int(def["skill3"]) == 42, "skill id'leri 40/41/42 olmalı")
	assert(not bool(def.get("always_walk", false)), "yeni sette run_* var: always_walk olmamalı (yoksa koşma klibi hiç oynamaz)")
	## Kullanıcı isteği (2026-09-22): Vampir %30, sonra %10, sonra %15 daha büyütüldü (scale 1.27575 x 1.3 x 1.1 x 1.15) -> ayaklar aynı
	## zemin çizgisinde kalsın diye offset.y = 0 ((41 - 24) x 1.993 ~ 34 px), ayrıca piksel elips ayak gölgesi (ground_shadow.gd) tanımlı olmalı.
	## NOT: sonraki "%25 daha büyüt" isteği Vampir için GERİ ALINDI (kullanıcı: "Vampir çocuğa yaptığın büyüklük değişimini
	## geri al, diğerlerine dokunma") - ölçek/offset/gölge yeniden eski değerlerinde.
	assert(def["offset"] == Vector2(0, 0), "büyütülmüş Vampir'in ayaklarını zemin çizgisine oturtmak için offset.y = 0 ister")
	assert(absf(def["scale"].x - 1.27575 * 1.3 * 1.1 * 1.15) < 0.001, "Vampir ölçeği varsayılanın x1.6445'i olmalı")
	assert(def.has("ground_shadow") and def.has("ground_shadow_y"), "Vampir'in ayak gölgesi tanımlı olmalı")
	assert(is_equal_approx(float(def["run_speed_ratio"]), 1.15), "koşma: hareket hızı bonusu %15'i geçince (talimat 2026-09-22)")
	for key in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon", "frames", "portrait"]:
		assert(ResourceLoader.exists(str(def[key])), "dosya yok: %s" % str(def[key]))
	for txt in ["skill_desc", "skill2_desc", "skill3_desc", "passive"]:
		assert(not str(def[txt]).is_empty(), "%s boş" % txt)


func test_sprite_frames_have_every_animation_the_game_asks_for() -> void:
	var frames: SpriteFrames = load(str(Characters.DEFS[13]["frames"]))
	assert(frames != null, "vampir_frames.tres yüklenemedi")
	## (klip, kare sayısı, döngü) - sayfalar 48x48 hücre, satırlar aşağı/sol/sağ/yukarı (tools/gen_vampir_frames.py).
	var expected: Array = [
		["idle_", 4, true], ["walk_", 6, true], ["run_", 6, true], ["eat_", 3, false], ["hurt_", 2, false],
		["read_", 4, true], ["shrug_", 4, false], ["downed_", 2, false], ["death_", 3, false],
		["strike_", 4, false], ["chop_", 4, false], ["pickup_", 4, false], ["bat_", 4, true],
	]
	for dir in ["up", "left", "down", "right"]:
		for e in expected:
			var clip: String = str(e[0]) + dir
			assert(frames.has_animation(clip), "eksik animasyon: %s" % clip)
			assert(frames.get_frame_count(clip) == int(e[1]), "%s %d kare olmalı: %d" % [clip, int(e[1]), frames.get_frame_count(clip)])
			assert(frames.get_animation_loop(clip) == bool(e[2]), "%s döngü=%s olmalı" % [clip, str(e[2])])
		## Kullanıcı isteği: eat ~0.5 sn sürmeli.
		var eat_secs: float = float(frames.get_frame_count("eat_" + dir)) / frames.get_animation_speed("eat_" + dir)
		assert(is_equal_approx(eat_secs, 0.5), "eat_%s süresi 0.5 sn olmalı: %s" % [dir, str(eat_secs)])
		assert(frames.get_frame_texture("idle_" + dir, 0).get_size() == Vector2(48, 48), "karakter kareleri 48x48")
		assert(frames.get_frame_texture("bat_" + dir, 0).get_size() == Vector2(96, 112), "yarasa kareleri 96x112 (offset'e göre kaydırılmış tuval)")
	## Eski (LPC) yönsüz "hurt" yok: hasar klibi hurt_<yön>, yere düşme downed_<yön>.
	assert(not frames.has_animation("hurt"))


func test_timing_tables() -> void:
	var P: GDScript = load("res://scripts/player.gd")
	assert(float(P.SKILL_TIMING[40]["cooldown"]) == 6.0, "Q 6sn")
	assert(float(P.SKILL2_TIMING[41]["duration"]) == 5.0 and float(P.SKILL2_TIMING[41]["cooldown"]) == 22.0, "E 5sn süre / 22sn bekleme")
	assert(float(P.SKILL3_TIMING[42]["cooldown"]) == 0.0, "R toggle: bekleme yok")
	assert(P.VAMPIR_SKILL_COST_PERCENT == 0.04 and P.VAMPIR_ULTI_COST_PERCENT_PER_SEC == 0.05)
	assert(P.VAMPIR_Q_DAMAGE_RATIO == 1.3 and P.VAMPIR_BAT_CONTACT_DAMAGE_RATIO == 0.8)
	assert(P.VAMPIR_R_DAMAGE_RATIO == 0.6 and P.VAMPIR_R_HEAL_RATIO == 0.05)
	assert(P.VAMPIR_BAT_SPEED_MULT == 1.6 and P.VAMPIR_BAT_DAMAGE_TAKEN_MULT == 0.2)


func test_shared_pull_math() -> void:
	var slot := Vector2(62, -70)
	assert(VampirMath.icon_offset(slot, 0.0).is_equal_approx(slot), "pull 0 = slot")
	assert(VampirMath.icon_offset(slot, 1.0).is_equal_approx(VampirMath.BODY_CENTER), "pull 1 = gövde merkezi")
	assert(is_equal_approx(VampirMath.icon_alpha(0.0), 1.0) and is_equal_approx(VampirMath.icon_alpha(1.0), 0.0), "alpha 1 -> 0")
	var p: float = 0.0
	for i in range(100):
		p = VampirMath.step_pull(p, true, VampirMath.PULL_TIME / 10.0)
	assert(is_equal_approx(p, 1.0), "PULL_TIME sürede tam çekilir")
	assert(VampirMath.is_bat_anim("bat_left") and not VampirMath.is_bat_anim("walk_left"))


# ------------------------------------------------------------------ pasif

func test_passive_max_health_follows_attack_power_and_lifesteal_is_two_percent() -> void:
	var player: Node = _make_player()
	var before: float = player.max_health
	var ap: float = player.damage_bonus
	player._process_vampir(0.016)
	assert(is_equal_approx(player.max_health, before + floorf(ap)), "her 1 saldırı gücü = 1 maks. can: %s -> %s (AP %s)" % [before, player.max_health, ap])
	## Saldırı gücü artınca fark eklenir (yeniden yazılmaz), düşünce çıkarılır.
	var mid: float = player.max_health
	player.damage_bonus += 7.0
	player._process_vampir(0.016)
	assert(is_equal_approx(player.max_health, mid + 7.0), "AP +7 -> maks. can +7")
	player.damage_bonus -= 7.0
	player._process_vampir(0.016)
	assert(is_equal_approx(player.max_health, mid), "AP geri düşünce maks. can geri düşer")
	## Can emme: hasarın %1'i (kullanıcı isteği: %4 -> %2 -> 2026-09-24 %1).
	player.health = player.max_health - 50.0
	var h0: float = player.health
	player.on_dealer_hit(100.0)
	assert(is_equal_approx(player.health, h0 + 1.0), "100 hasar -> 1 can emme (%%1), bulunan +%s" % str(player.health - h0))
	_cleanup()


func test_passive_does_nothing_for_other_characters() -> void:
	var player: Node = _make_player()
	GameManager.selected_char_id = 1
	var before: float = player.max_health
	player._process_vampir(0.016)
	player.health = player.max_health - 10.0
	var h0: float = player.health
	player.on_dealer_hit(100.0)
	assert(is_equal_approx(player.max_health, before) and is_equal_approx(player.health, h0), "Vampir değilse hiçbir etki olmamalı")
	_cleanup()


# ------------------------------------------------------------------ Q

func test_q_hits_nearest_three_pays_health_and_grants_permanent_max_health() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	var e1: FakeEnemy = _make_enemy(Vector2(1050, 1000))
	var e2: FakeEnemy = _make_enemy(Vector2(1000, 1100))
	var e3: FakeEnemy = _make_enemy(Vector2(1200, 1000))
	var e4: FakeEnemy = _make_enemy(Vector2(1000, 1300)) ## menzil içinde ama 4. yakın
	var far: FakeEnemy = _make_enemy(Vector2(3000, 3000))
	var max0: float = player.max_health
	var cost: float = max0 * 0.04
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE ## kritik yok (taban %5 de sıfırlanır)
	player._activate_skill()
	assert(player.skill_state == "active", "Q tetiklenmeli")
	var expected: float = player.damage_bonus * 1.3
	for e in [e1, e2, e3]:
		assert(e.hits.size() == 1 and is_equal_approx(e.hits[0], expected), "en yakın 3 düşman %%130 alır: %s" % str(e.hits))
	assert(e4.hits.is_empty() and far.hits.is_empty(), "4. yakın ve uzak düşman vurulmamalı")
	assert(is_equal_approx(player.max_health, max0 + 1.0), "kalıcı +1 maks. can (cast başına)")
	assert(is_equal_approx(player.health, max0 - cost + 1.0), "bedel: maks. canın %%4'ü, +1 yeni can: %s" % str(player.health))
	assert(is_equal_approx(player.item_shield_hp, 0.0), "kalkan harcanmaz")
	_cleanup()


func test_q_without_target_or_with_too_little_health_does_not_fire() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	var h0: float = player.health
	player._activate_skill()
	assert(player.skill_state == "ready" and is_equal_approx(player.health, h0), "hedef yokken can harcanmaz/bekleme başlamaz: state=%s hp=%s h0=%s enemies=%d" % [player.skill_state, player.health, h0, get_tree().get_nodes_in_group("enemies").size()])
	var e: FakeEnemy = _make_enemy(Vector2(1050, 1000))
	player.health = 3.0 ## bedel (~%4 max) üstünde: kendini ÖLDÜRMEMELİ
	player._activate_skill()
	assert(player.skill_state == "ready" and is_equal_approx(player.health, 3.0) and e.hits.is_empty(), "can yetersizse tetiklenmez")
	_cleanup()


# ------------------------------------------------------------------ E

func test_e_bat_form_speed_damage_reduction_and_contact_damage() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE ## kritik yok (taban %5 de sıfırlanır)
	## Formsuz: 50 hasar tam işler.
	var h0: float = player.health
	player.take_damage(50.0)
	var normal_loss: float = h0 - player.health
	player.health = player.max_health
	player._last_damage_taken_at_msec = -999999
	var cost: float = player.max_health * 0.04
	player._activate_skill2()
	assert(player._vampir_bat_form_active and player.skill2_state == "active", "form aktif")
	assert(is_equal_approx(player.skill2_speed_multiplier, 1.6), "%%60 hareket hızı")
	assert(is_equal_approx(player.health, player.max_health - cost), "E de maks. canın %%4'ünü harcar")
	var h1: float = player.health
	player.take_damage(50.0)
	var form_loss: float = h1 - player.health
	assert(is_equal_approx(form_loss, normal_loss * 0.2), "form aktifken hasar %%80 azalır: normal %s, formda %s" % [normal_loss, form_loss])
	## Temas hasarı: değdiği yaratığa %80, aynı yaratığa aralıklı.
	var touching: FakeEnemy = _make_enemy(player.global_position + Vector2(20, 0))
	var away: FakeEnemy = _make_enemy(player.global_position + Vector2(400, 0))
	player._vampir_process_contact(0.016)
	assert(touching.hits.size() == 1 and is_equal_approx(touching.hits[0], player.damage_bonus * 0.8), "temas: %%80 - %s" % str(touching.hits))
	assert(away.hits.is_empty(), "uzaktaki yaratığa vurmaz")
	player._vampir_process_contact(0.016)
	assert(touching.hits.size() == 1, "aynı yaratığa hemen tekrar vurmaz")
	player._vampir_process_contact(player.VAMPIR_BAT_CONTACT_INTERVAL + 0.05)
	assert(touching.hits.size() == 2, "aralık dolunca tekrar vurur")
	## Form biter: hız/hasar normale döner.
	player._end_skill2_effects()
	assert(not player._vampir_bat_form_active and is_equal_approx(player.skill2_speed_multiplier, 1.0), "form bitince normal")
	_cleanup()


func test_e_animation_name_is_bat_and_returns_to_normal_after() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player._activate_skill2()
	player.facing = "left"
	player._update_animation(false)
	assert(str(player.anim.animation) == "bat_left", "yarasa formunda bat_<yön> oynar: %s" % str(player.anim.animation))
	assert(VampirMath.is_bat_anim(str(player.anim.animation)), "uzak istemci bu adı tanıyor (ağdan giden tek bilgi)")
	player._end_skill2_effects()
	player._update_animation(false)
	assert(str(player.anim.animation) == "idle_left", "form bitince idle: %s" % str(player.anim.animation))
	_cleanup()


func test_e_pulls_weapons_into_the_body_and_brings_them_back() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	var w := FakeWeapon.new()
	player.add_child(w)
	player.owned_weapon_nodes.append(w)
	w.global_position = player.global_position + Vector2(0, -125)
	player._activate_skill2()
	assert(w.process_mode == Node.PROCESS_MODE_DISABLED, "form başlar başlamaz silah ateş edemez (process kapalı)")
	for i in range(60): ## 0.96sn > PULL_TIME
		player._process_vampir(0.016)
	assert(is_equal_approx(player._vampir_pull, 1.0), "tamamen çekilmiş")
	assert(is_equal_approx(w.modulate.a, 0.0), "kaybolmuş (alpha 0)")
	assert(w.global_position.distance_to(player.global_position + VampirMath.BODY_CENTER * player.scale) < 1.0, "gövdenin içinde")
	player._end_skill2_effects()
	for i in range(3):
		player._process_vampir(0.016)
	assert(w.process_mode == Node.PROCESS_MODE_DISABLED and w.modulate.a < 1.0, "geri çıkarken hâlâ ateş yok")
	for i in range(60):
		player._process_vampir(0.016)
	assert(w.process_mode == Node.PROCESS_MODE_INHERIT, "form bitip animasyon tamamlanınca silah tekrar çalışır")
	assert(is_equal_approx(w.modulate.a, 1.0), "tam görünür")
	assert(w.last_offset.is_equal_approx(player.WEAPON_ICON_SLOTS[0]), "normal slotuna geri oturur: %s" % str(w.last_offset))
	_cleanup()


# ------------------------------------------------------------------ R

func test_r_toggle_pays_per_second_and_bats_attack_and_heal() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE ## kritik yok (taban %5 de sıfırlanır)
	var enemy: FakeEnemy = _make_enemy(player.global_position + Vector2(140, 0))
	var per_sec: float = player.max_health * 0.05
	player._vampir_toggle_bats()
	assert(player._vampir_bats_active and player.is_skill3_active(), "R açık")
	assert(is_equal_approx(player.health, player.max_health - per_sec), "aktivasyonda ilk saniyenin bedeli")
	assert(is_instance_valid(player._vampir_swarm) and player._vampir_swarm.authoritative, "yetkili sürü doğdu")
	assert(is_equal_approx(player.get_skill3_progress(), 1.0), "toggle: bekleme çubuğu dolmaz/boşalmaz")
	## 1 saniye geç -> bir bedel daha. (Sürüyü elle simüle ediyoruz.)
	var hp_after_first: float = player.health
	for i in range(60):
		player._process_vampir(0.0167)
		player._vampir_swarm._physics_process(0.0167)
	assert(player.health < hp_after_first + 3.0, "sürekli bedel ödenir")
	## Birkaç saniye simüle et: yarasalar vurup dönmeli.
	for i in range(240):
		player._process_vampir(0.0167)
		player._vampir_swarm._physics_process(0.0167)
	assert(enemy.hits.size() >= 3, "yarasalar defalarca vurmalı, vuruş sayısı: %d" % enemy.hits.size())
	assert(is_equal_approx(enemy.hits[0], player.damage_bonus * 0.6), "yarasa vuruşu %%60 saldırı gücü: %s" % str(enemy.hits[0]))
	assert(player.health < player.max_health, "bedel > geri dönüş iyileşmesi olabilir; en azından yenileme birikmeli")
	_cleanup()


func test_r_bat_return_heals_five_percent_of_attack_power_and_speed_scales_with_attack_speed() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.health = player.max_health - 40.0
	var h0: float = player.health
	player.vampir_bat_returned(Vector2.ZERO)
	assert(is_equal_approx(player.health, h0 + player.damage_bonus * 0.05), "dönüş: AP'nin %%5'i kadar can")
	player.fire_rate_mult = 1.0
	assert(is_equal_approx(player._vampir_attack_speed_mult(), 1.0))
	player.fire_rate_mult = 0.5 ## yarı bekleme = 2x saldırı hızı
	assert(is_equal_approx(player._vampir_attack_speed_mult(), 2.0), "saldırı hızı 2x -> yarasa hızı 2x")
	_cleanup()


func test_r_refuses_when_it_would_kill_and_stops_itself_when_health_runs_out() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.health = 2.0
	player._vampir_toggle_bats()
	assert(not player._vampir_bats_active, "can yetmiyorsa açılmaz (kendini öldürmez)")
	player.health = player.max_health * 0.055 ## ilk saniyeyi (%5) öder, ikincisine yetmez
	player._vampir_toggle_bats()
	assert(player._vampir_bats_active, "açılır")
	for i in range(200):
		player._process_vampir(0.0167)
	assert(not player._vampir_bats_active, "can bitince kendiliğinden kapanır")
	assert(player.health > 0.0 and not player.is_dead, "asla ölmez")
	_cleanup()


func test_r_swarm_retires_and_frees_itself_after_toggle_off() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player._vampir_toggle_bats()
	var swarm: Node2D = player._vampir_swarm
	player._vampir_toggle_bats()
	assert(not player._vampir_bats_active, "kapandı")
	for i in range(30):
		swarm._physics_process(0.0167)
	await get_tree().process_frame
	assert(not is_instance_valid(swarm), "hedef yokken yarasalar dağılıp sürü kendini siler")
	assert(player.get_vampir_swarm_net_positions().is_empty(), "kapalıyken ağ paketi boş")
	_cleanup()


func test_dying_ends_form_and_bats() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player._activate_skill2()
	player._vampir_toggle_bats()
	player.is_downed = true
	player._process_vampir(0.016)
	assert(not player._vampir_bat_form_active and not player._vampir_bats_active, "yere düşünce form/yarasalar kapanır")
	assert(is_equal_approx(player.skill2_speed_multiplier, 1.0))
	_cleanup()


# ------------------------------------------------------------------ diğer istemcideki kozmetik kopya

func test_remote_puppet_pulls_weapons_and_shows_bats_from_the_network() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(99, 13, "Vamp")
	rp.update_weapon_visuals(["dagger", "pence"], {})
	assert(rp._weapon_icons.size() == 2, "kukla silah ikonları oluştu")
	var rest0: Vector2 = rp._weapon_icons[0].position
	## Ağdan "bat_down" anim adı gelir.
	rp.update_position_and_anim_from_net(Vector2(500, 500), "bat_down")
	assert(rp.anim.animation == &"bat_down", "kukla bat_down oynatır (SpriteFrames'te var, sessizce yok sayılmaz): %s" % str(rp.anim.animation))
	for i in range(40):
		rp._process_vampir_remote(0.016)
	assert(is_equal_approx(rp._vampir_pull, 1.0), "kukla silahları çekti")
	assert(is_equal_approx(rp._weapon_icons[0].modulate.a, 0.0) and rp._weapon_icons[0].position.distance_to(VampirMath.BODY_CENTER) < 0.5, "silah gövdenin içinde/görünmez")
	## Form biter: normal animasyon adı gelir -> silahlar geri çıkar.
	rp.update_position_and_anim_from_net(Vector2(500, 500), "idle_down")
	for i in range(40):
		rp._process_vampir_remote(0.016)
	assert(is_equal_approx(rp._vampir_pull, 0.0), "geri çıktı")
	assert(is_equal_approx(rp._weapon_icons[0].modulate.a, 1.0) and rp._weapon_icons[0].position.is_equal_approx(rest0), "silah eski konumunda tam görünür")
	## R yarasaları: konum paketi -> kozmetik sürü; boş paket -> silinir.
	var pos := PackedVector2Array()
	for i in range(6):
		pos.append(Vector2(500 + i * 10, 450))
	rp.update_vampir_bats_from_net(pos)
	assert(is_instance_valid(rp._vampir_swarm) and not rp._vampir_swarm.authoritative, "kozmetik sürü (oyun mantığı yok)")
	rp.update_vampir_bats_from_net(PackedVector2Array())
	await get_tree().process_frame
	assert(rp._vampir_swarm == null, "boş paket sürüyü siler")
	_cleanup()


func test_cosmetic_swarm_follows_net_positions_and_hides_hidden_bats() -> void:
	var caster := Node2D.new()
	add_child(caster)
	_spawned.append(caster)
	var swarm := Node2D.new()
	swarm.set_script(SwarmScript)
	swarm.set("authoritative", false)
	swarm.set("caster", caster)
	add_child(swarm)
	_spawned.append(swarm)
	var pkt := PackedVector2Array()
	for i in range(6):
		pkt.append(Vector2(300, 300) if i < 5 else SwarmScript.HIDDEN)
	swarm.apply_net_positions(pkt)
	for i in range(60):
		swarm._physics_process(0.016)
	assert(swarm._pos[0].distance_to(Vector2(300, 300)) < 2.0, "konuma yakınsar: %s" % str(swarm._pos[0]))
	assert(swarm._active[0] and not swarm._active[5], "HIDDEN işaretli yarasa çizilmez")
	_cleanup()


func test_vfx_nodes_spawn_and_free_themselves() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var host := Node2D.new()
	add_child(host)
	_spawned.append(host)
	var sink := Node2D.new()
	host.add_child(sink)
	sink.global_position = Vector2(100, 100)
	var pts := PackedVector2Array([Vector2(300, 100), Vector2(300, 200)])
	var fx_list: Array = [
		VampirMath.spawn_fx(host, "hit", Vector2(50, 50)),
		VampirMath.spawn_fx(host, "puff", Vector2(60, 60)),
		VampirMath.spawn_fx(host, "drain", Vector2(70, 70), {"points": pts, "sink": sink}),
	]
	for fx in fx_list:
		assert(fx != null and fx.global_position.is_equal_approx(fx.global_position), "fx doğdu")
	for i in range(80): ## ~1.3sn
		for fx in fx_list:
			if is_instance_valid(fx):
				fx._process(0.016)
	await get_tree().process_frame
	for fx in fx_list:
		assert(not is_instance_valid(fx), "efektler kendi kendini silmeli")
	_cleanup()


# ------------------------------------------------------------------ animasyon talimatı (Animasyon talimatlar.txt)
# hurt / eat / walk-run / read / shrug / downed - ve klip ADI ağdan gittiği için diğer istemcideki kukla.

func test_char_anim_helpers() -> void:
	for n in ["attack_down", "spellcast_left", "shrug_up", "hurt_right", "eat_down"]:
		assert(CharAnim.is_action_anim(n), "%s aksiyon klibi (bitene kadar ezilmez)" % n)
	for n in ["idle_down", "walk_left", "run_up", "read_right", "bat_down", "downed_down", "death_left"]:
		assert(not CharAnim.is_action_anim(n), "%s aksiyon klibi DEĞİL (döngü/kalıcı poz)" % n)
	assert(CharAnim.is_cast_anim("shrug_down") and CharAnim.is_cast_anim("spellcast_down") and not CharAnim.is_cast_anim("hurt_down"))
	assert(CharAnim.dir_of("walk_left") == "left" and CharAnim.dir_of("death") == "down")


func test_hurt_plays_without_shield_at_most_once_per_two_seconds() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.facing = "left"
	player.take_damage(5.0)
	assert(str(player.anim.animation) == "hurt_left", "kalkansız hasarda hurt_<yön>: %s" % str(player.anim.animation))
	## 2 sn dolmadan ikinci hasar: klip TEKRAR oynamaz (150 ms'lik dokunulmazlık penceresi bu testin konusu değil).
	player.anim.play("idle_left")
	player._last_damage_taken_at_msec = -999999
	player.take_damage(5.0)
	assert(str(player.anim.animation) == "idle_left", "2 sn dolmadan tekrar oynamamalı: %s" % str(player.anim.animation))
	## 2 sn geçti: yine oynar.
	player._last_hurt_anim_msec -= 2001
	player._last_damage_taken_at_msec = -999999
	player.take_damage(5.0)
	assert(str(player.anim.animation) == "hurt_left", "2 sn sonra yine oynar")
	## Bitene kadar yürüme/bekleme ezmez.
	player._update_animation(true)
	assert(str(player.anim.animation) == "hurt_left", "hurt bitmeden walk/idle ezmemeli")
	_cleanup()


func test_hurt_does_not_play_when_the_shield_absorbs_the_hit() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.item_shield_max = 200.0
	player.item_shield_hp = 200.0
	player.shield_protection = 0.6
	player.take_damage(10.0)
	assert(player.item_shield_hp < 200.0, "kalkan hasarı emdi")
	assert(not str(player.anim.animation).begins_with("hurt_"), "kalkan varken hurt oynamaz: %s" % str(player.anim.animation))
	_cleanup()


func test_eat_plays_when_food_is_picked_up_and_lasts_half_a_second() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.facing = "up"
	var food: Node = FoodScene.instantiate()
	add_child(food)
	_spawned.append(food)
	food._on_body_entered(player) ## yerden yemek alma anı (food_drop.gd)
	assert(str(player.anim.animation) == "eat_up", "yemek alınınca eat_<yön>: %s" % str(player.anim.animation))
	var frames: SpriteFrames = player.anim.sprite_frames
	assert(is_equal_approx(float(frames.get_frame_count("eat_up")) / frames.get_animation_speed("eat_up"), 0.5), "eat ~0.5 sn")
	assert(is_equal_approx(player.anim.speed_scale, 1.0), "süre yürüme hız çarpanından etkilenmemeli")
	player._update_animation(true)
	assert(str(player.anim.animation) == "eat_up", "eat bitene kadar yürüme ezmemeli")
	_cleanup()


func test_walk_at_normal_speed_and_run_when_speed_bonus_exceeds_twenty_percent() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.facing = "down"
	player._update_animation(true)
	assert(str(player.anim.animation) == "walk_down", "standart hızda walk: %s" % str(player.anim.animation))
	player.item_speed_percent = 0.19
	player._update_animation(true)
	assert(str(player.anim.animation) == "walk_down", "%%19 bonus hâlâ walk")
	player.item_speed_percent = 0.21
	player._update_animation(true)
	assert(str(player.anim.animation) == "run_down", "%%21 bonus (stat) run: %s" % str(player.anim.animation))
	player.item_speed_percent = 0.0
	player.skill_speed_multiplier = 1.3 ## yetenek kaynaklı bonus
	player._update_animation(true)
	assert(str(player.anim.animation) == "run_down", "yetenek hız bonusu da sayılır")
	player.skill_speed_multiplier = 1.0
	player.spirit_speed_bonus = 0.3 ## geçici hız bonusu (Taktiksel ruhani yetenek)
	player._update_animation(true)
	assert(str(player.anim.animation) == "run_down", "geçici hız bonusu da sayılır")
	player.spirit_speed_bonus = 0.0
	player._update_animation(false)
	assert(str(player.anim.animation) == "idle_down", "durunca idle")
	_cleanup()


func test_shrug_plays_on_q_and_r_but_not_on_e() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	var target: FakeEnemy = _make_enemy(Vector2(1050, 1000))
	assert(target != null)
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE
	player._activate_skill()
	assert(player.skill_state == "active", "Q tetiklenmeli")
	assert(str(player.anim.animation) == "shrug_down", "Q: shrug_<yön>: %s" % str(player.anim.animation))
	player._update_animation(true)
	assert(str(player.anim.animation) == "shrug_down", "shrug bitene kadar yürüme ezmemeli")
	## R: standart _activate_skill3'ü bypass eden toggle - shrug elle oynatılıyor.
	player.anim.play("idle_down")
	player._vampir_toggle_bats()
	assert(str(player.anim.animation) == "shrug_down", "R: shrug_<yön>: %s" % str(player.anim.animation))
	player._vampir_stop_bats()
	## E: yarasaya dönüşüm kendi bat_* klibini oynatır, shrug oynamaz.
	player.anim.play("idle_down")
	player._activate_skill2()
	assert(str(player.anim.animation) == "idle_down", "E'de shrug yok: %s" % str(player.anim.animation))
	_cleanup()


func test_read_pose_while_a_shop_or_card_screen_is_open_and_ends_when_it_closes() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	assert(player.has_node("ReadingUiWatcher"), "read_ klibi olan karakterde izleyici kurulur")
	var watcher: Node = player.get_node("ReadingUiWatcher")
	watcher._process(0.016)
	assert(not player._reading_ui_active, "ekran yokken okumaz")
	var screen := CanvasLayer.new()
	screen.add_to_group(ReadingUiWatcher.GROUP)
	add_child(screen)
	_spawned.append(screen)
	watcher._process(0.016)
	assert(player._reading_ui_active and str(player.anim.animation) == "read_down", "ekran açılınca read_<yön>: %s" % str(player.anim.animation))
	assert(player.anim.process_mode == Node.PROCESS_MODE_ALWAYS, "level/sandık ekranları oyunu duraklatır: sprite duraklamada da oynamalı")
	player._update_animation(false)
	assert(str(player.anim.animation) == "read_down", "ayaktayken okumaya devam")
	player._update_animation(true) ## dükkan oyunu duraklatmaz: yürüyünce normal klip
	assert(str(player.anim.animation) == "walk_down")
	player._update_animation(false)
	assert(str(player.anim.animation) == "read_down", "durunca tekrar okuma")
	## Ekran kapanınca (görünmez YA DA silinmiş) biter.
	screen.visible = false
	watcher._process(0.016)
	assert(not player._reading_ui_active, "ekran kapanınca okuma biter")
	assert(player.anim.process_mode == Node.PROCESS_MODE_INHERIT, "sprite duraklama muafiyeti kalkar")
	assert(str(player.anim.animation) == "idle_down", "okuma klibi ekranda takılı kalmamalı: %s" % str(player.anim.animation))
	screen.visible = true
	watcher._process(0.016)
	assert(player._reading_ui_active)
	screen.queue_free() ## is_queued_for_deletion(): silinmeyi beklerken de "açık" sayılmaz
	watcher._process(0.016)
	assert(not player._reading_ui_active, "silinen ekran okumayı bitirir")
	_cleanup()


func test_every_shop_and_card_screen_registers_for_the_read_pose() -> void:
	for path in ["res://scripts/level_up_screen.gd", "res://scripts/chest_menu.gd", "res://scripts/weapon_select_screen.gd", "res://scripts/merchant_shop_screen.gd", "res://scripts/shop_panel.gd"]:
		var src: String = (load(path) as GDScript).source_code
		assert(src.contains("add_to_group(ReadingUiWatcher.GROUP)"), "%s okuma grubuna eklenmiyor" % path)


func test_downed_pose_and_remote_death_direction() -> void:
	var player: Node = _make_player()
	_ready_player(player)
	player.facing = "right"
	player._go_down()
	## 2026-09-25 kullanıcı isteği: "karakterler öldüğünde death animasyonunu kullansın downed yerine".
	assert(str(player.anim.animation) == "death_right", "yere düşünce death_<yön>: %s" % str(player.anim.animation))
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(99, 13, "Vamp")
	rp.update_position_and_anim_from_net(Vector2(500, 500), "walk_left")
	rp._play_death_animation()
	assert(str(rp.anim.animation) == "death_left", "kukla ölümü son yönde oynatır: %s" % str(rp.anim.animation))
	_cleanup()


func test_remote_puppet_plays_the_new_clip_names_and_keeps_shrug_looping() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(99, 13, "Vamp")
	## Klip adı transform kanalıyla gelir (CLAUDE.md: SpriteFrames'te yoksa sessizce yok sayılırdı).
	for clip in ["eat_down", "hurt_left", "read_up", "run_right", "shrug_down", "downed_down"]:
		rp.update_position_and_anim_from_net(Vector2(500, 500), clip)
		assert(str(rp.anim.animation) == clip, "kukla %s oynatmalı: %s" % [clip, str(rp.anim.animation)])
	## Kanal yeteneği: ad değişmeden klip biterse yeniden başlar (bkz. player.gd _play_cast_animation döngüsü).
	rp.update_position_and_anim_from_net(Vector2(500, 500), "shrug_down")
	rp.anim.stop()
	rp.update_position_and_anim_from_net(Vector2(500, 500), "shrug_down")
	assert(rp.anim.is_playing(), "bitmiş shrug klibi aynı adla gelince yeniden başlamalı")
	_cleanup()
