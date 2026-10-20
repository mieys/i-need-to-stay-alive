extends Node

## CADI (roster id 15, 2026-10-13): Pasif Şans Tılsımı, Q Zehirli Duman (aç/kapa), E Uçan Süpürge (yolcu taşır), R İksir Çantası
## (5 yük, rastgele iksir). Kapsam: tek kaynaktaki sabit/formüller (cadi_math.gd), sprite sayfası sözleşmesi, player.gd
## mekanikleri + evrimler, yaratık deliliği (enemy.gd), kukla (remote_player.gd) ve süpürge koltukları.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const CM: GDScript = preload("res://scripts/cadi_math.gd")
const Evo: GDScript = preload("res://scripts/skill_evolutions.gd")
const CADI := 15
const HP := 600000.0

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = CADI
	GameManager.selected_character = int(Characters.DEFS[CADI]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(3000.0, 3000.0)
	player.damage_bonus = 100.0
	player.crit_chance_bonus = -10.0 ## yetenek kritiği kapalı: hasar miktarları tam ölçülsün
	player.item_shield_max = 1000.0
	player.item_shield_hp = 1000.0
	return player


func _enemy(pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = HP
	e.health = HP
	_spawned.append(e)
	return e


func _lost(e: Node2D) -> float:
	return HP - float(e.health)


func _remote(peer: int, char_id: int, pos: Vector2) -> Node:
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.set_physics_process(false) ## kukla ağ hedefine çekilmesin - konumu test sürüyor
	rp.peer_id = peer
	rp.char_id = char_id
	rp.global_position = pos
	return rp


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for g: String in ["cadi_smokes", "cadi_zones"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.free()
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _phys(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame


func _group_count(g: String) -> int:
	var c: int = 0
	for n: Node in get_tree().get_nodes_in_group(g):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			c += 1
	return c


# ------------------------------------------------------------------ tanımlar / sayfalar

func test_definitions_and_evolution_cards() -> void:
	var def: Dictionary = Characters.DEFS[CADI]
	assert(str(def["name"]) == "Cadı" and int(def["skill"]) == CM.Q_SKILL_ID and int(def["skill2"]) == CM.E_SKILL_ID and int(def["skill3"]) == CM.R_SKILL_ID, "yetenek kimlikleri 51/52/53")
	for key: String in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon", "frames", "portrait"]:
		assert(ResourceLoader.exists(str(def[key])), "kaynak var: %s" % str(def[key]))
	for path: String in CM.R_ICONS:
		assert(ResourceLoader.exists(path), "sıradaki iksir ikonu var: %s" % path)
	assert(CM.R_ICONS.size() == CM.POTION_COUNT and CM.POTION_NAMES.size() == CM.POTION_COUNT and CM.POTION_DESCS.size() == CM.POTION_COUNT, "6 iksir: ikon + ad + açıklama")
	assert(CM.POTION_COUNT == 6 and str(CM.POTION_NAMES[CM.POTION_SHIELD]) == "Kalkan İksiri" and CM.POTION_SHIELD == 5, "Kalkan İksiri 6. iksir (indeks 5)")
	assert(is_equal_approx(CM.SHIELD_RATIO, 0.25) and is_equal_approx(CM.HEAL_TICK, 1.0), "kalkan %25 AP, saniyede bir")
	## Evrim kartları: Q 5, E 5, R 3 - final her zaman sonda; her kartın etkisi player.gd'de okunuyor.
	var want: Dictionary = {"skill": 5, "skill2": 5, "skill3": 3}
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	for slot: String in want:
		var cards: Array = Evo.slot_list(CADI, slot)
		assert(cards.size() == int(want[slot]), "%s kart sayısı: %d" % [slot, cards.size()])
		assert(bool((cards[cards.size() - 1] as Dictionary).get("final", false)), "%s finali listenin sonunda" % slot)
		for c: Dictionary in cards:
			assert(src.contains('"%s"' % str(c["id"])), "evrim player.gd'de okunuyor: %s" % str(c["id"]))


func test_sheets_match_the_contract() -> void:
	var table: Dictionary = {
		"potion": ["loop", "down"], "stream": ["loop", "down"], "smoke": ["intro", "loop", "outro", "intro_v", "loop_v", "outro_v"], "poof": ["default"], "spark": ["gold", "lilac"],
		"broom_vert": ["down", "up"], "boom": ["default"], "mad_status": ["loop"],
		"zone_mad": ["intro", "loop", "outro"], "zone_ice": ["intro", "loop", "outro"], "zone_heal": ["intro", "loop", "outro"], "zone_fear": ["intro", "loop", "outro"],
		"zone_shield": ["intro", "loop", "outro"],
	}
	for sheet: String in table:
		var fr: SpriteFrames = CM.frames(sheet)
		assert(fr != null, "sayfa yüklendi: %s" % sheet)
		for a: String in table[sheet]:
			assert(fr.has_animation(a) and fr.get_frame_count(a) > 0, "%s / %s" % [sheet, a])
	for n in range(CM.MAX_PASSENGERS + 1):
		assert(CM.frames("broom_side").has_animation("side_%d" % n), "yolcu sayısına göre süpürge: side_%d" % n)
	for i in range(CM.POTION_COUNT):
		assert(CM.frames("bottles").has_animation("b%d" % (i + 1)) and CM.frames("shatter").has_animation("s%d" % (i + 1)), "şişe + kırılma %d" % (i + 1))
	for p: int in CM.ZONE_SHEETS:
		assert(p != CM.POTION_BOOM, "patlama alan açmaz")
	## Süpürge oturuşu: ride_<yön> klibi Cadı'da ve yolcu olabilecek karakterlerde (tools/add_ride_clips.py).
	for cid: int in [CADI, 14, 9, 1]:
		var cf: SpriteFrames = load(str(Characters.DEFS[cid]["frames"])) as SpriteFrames
		for d: String in ["down", "left", "right", "up"]:
			assert(cf.has_animation(CM.RIDE_ANIM_PREFIX + d) and cf.get_frame_count(CM.RIDE_ANIM_PREFIX + d) == 1, "karakter %d ride_%s (tek kare)" % [cid, d])


func test_shared_formulas() -> void:
	assert(is_equal_approx(CM.WORLD_TEXEL, 2.2368375 * EntityScale.SIZE * 0.5), "efekt pikseli = karakter pikseli")
	## Şişe ve dumanın indiği nokta HER yönde cadının tam arkasında (ayağa göre: sağa bakarken solda, yukarı bakarken altta...).
	var feet: Vector2 = CM.FEET_LOCAL * 0.5
	var land_r: Vector2 = CM.smoke_land_offset("right") - feet
	var land_l: Vector2 = CM.smoke_land_offset("left") - feet
	assert(land_r.x < 0.0 and is_equal_approx(land_r.x, -land_l.x) and is_equal_approx(land_r.y, land_l.y), "dumanın indiği nokta iki yanda simetrik")
	assert(absf(land_r.x) < CM.SMOKE_RX and absf(land_r.y) < 2.0, "yanda duman topuğun hemen arkasına iner (cadı bulutun izinde): %s" % land_r)
	var land_u: Vector2 = CM.smoke_land_offset("up") - feet
	var land_d: Vector2 = CM.smoke_land_offset("down") - feet
	assert(is_zero_approx(land_u.x) and land_u.y > 0.0 and is_zero_approx(land_d.x) and land_d.y < 0.0, "yukarı bakarken altına, aşağı bakarken üstüne iner: %s %s" % [land_u, land_d])
	assert(CM.potion_body_offset("right").x < 0.0 and CM.potion_body_offset("left").x > 0.0, "şişe gövdesi yanda bakılan yönün tersinde")
	assert(is_zero_approx(CM.potion_body_offset("up").x) and is_zero_approx(CM.potion_body_offset("down").x), "dikeyde şişe yanda DEĞİL, tam arkada")
	## Süpürgedeyken şişe süpürgenin ARKASINDA: yolcu başına sap uzar, şişe kayar; duman yine yere iner.
	for f: String in ["left", "right", "up", "down"]:
		var d0: Vector2 = CM.potion_body_art(f, 0)
		var d3: Vector2 = CM.potion_body_art(f, 3)
		assert(not d0.is_equal_approx(CM.potion_body_art(f)), "süpürgede şişe yeri değişir: %s" % f)
		assert(is_equal_approx((d3 - d0).length(), 3.0 * (CM.SEAT_ART if f == "left" or f == "right" else CM.SEAT_VERT_ART)), "yolcu başına sap boyu kadar kayar: %s" % f)
		assert(is_equal_approx(CM.smoke_land_offset(f, 0).y - CM.smoke_land_offset(f).y, 0.0), "duman süpürgedeyken de yere iner: %s" % f)
	assert(CM.potion_body_art("right", 2).x < CM.potion_body_art("right", 0).x and CM.potion_body_art("left", 2).x > CM.potion_body_art("left", 0).x, "yolcu arttıkça şişe arkaya kayar")
	for f: String in ["left", "right", "up"]:
		assert(is_equal_approx(CM.potion_drop_art(f).y, 26.0), "şişe inişin 26 px üstünde süzülür: %s" % f)
	for f: String in ["up", "down", "left", "right"]:
		assert(CM.smoke_is_vertical(f), "her yöne yürürken dikey bulut: %s" % f)
	assert(CM.SMOKE_V_RX < CM.SMOKE_RX and CM.SMOKE_V_RY > CM.SMOKE_RY and CM.SMOKE_V_RY * 2.0 > 82.0 * CM.SMOKE_V_DROP_INTERVAL, "dikey bulut dar + derin: izler yürüme yönünde üst üste biner")
	assert(CM.SMOKE_MAX_GAP < CM.SMOKE_V_RX * 2.0 and CM.SMOKE_MAX_GAP < CM.SMOKE_V_RY * 2.0, "iki bulut arası en çok SMOKE_MAX_GAP: bulut genişliğinden/derinliğinden az, boşluk kalmaz")
	assert(82.0 * CM.SMOKE_V_DROP_INTERVAL <= CM.SMOKE_MAX_GAP, "normal hızda boşluk kuralı devreye girmez (görünüş aynı)")
	assert(absf(CM.SMOKE_V_RX * CM.SMOKE_V_RY - CM.SMOKE_RX * CM.SMOKE_RY) < 0.05 * CM.SMOKE_RX * CM.SMOKE_RY, "dikey bulutun alanı yatayla aynı (%5 içinde)")
	assert(CM.seat_offset(0, "left") == Vector2.ZERO, "cadı koltuk 0")
	assert(CM.seat_offset(2, "left").x > 0.0 and CM.seat_offset(2, "right").x < 0.0, "yan görünümde yolcular cadının ARKASINDA")
	assert(CM.seat_offset(1, "down").y < 0.0 and CM.seat_offset(1, "up").y > 0.0, "aşağı/yukarı bakarken yolcular derinlikte arkada")
	assert(is_equal_approx(CM.seat_offset(3, "left").x, CM.SEAT_ART * 3.0 * CM.WORLD_TEXEL), "koltuk aralığı sayfadaki sap uzamasıyla aynı")
	assert(is_equal_approx(CM.ride_lift(0.0) - CM.rider_lift(0.0), CM.RIDE_SIT_DROP_ART), "binen süpürgeden 2 piksel aşağıda oturur")
	assert(CM.in_ellipse(Vector2(10, 0), Vector2.ZERO, 20.0, 5.0) and not CM.in_ellipse(Vector2(0, 10), Vector2.ZERO, 20.0, 5.0), "elips içi")
	assert(CM.facing_from_anim("ride_left") == "left" and CM.facing_from_anim("idle") == "down", "yön klip adından")
	for _i in range(200):
		var p: int = CM.roll_potion(2)
		assert(p >= 0 and p < CM.POTION_COUNT and p != 2, "rastgele iksir: aralıkta ve az önce atılanla aynı değil")


# ------------------------------------------------------------------ pasif

func test_passive_gives_luck_per_missing_five_percent() -> void:
	var player: Node = _make_player()
	var base_luck: float = player.luck
	player.max_health = 200.0
	player.health = 200.0
	player._process_cadi_passive()
	assert(is_equal_approx(player.luck, base_luck) and player.get_cadi_passive_luck() == 0, "can doluyken şans yok")
	player.health = 100.0
	player._process_cadi_passive()
	assert(is_equal_approx(player.luck, base_luck + 10.0), "%%50 eksik can = 10 şans: %s" % (player.luck - base_luck))
	player.health = 189.0 ## %5,5 eksik -> 1 basamak
	player._process_cadi_passive()
	assert(player.get_cadi_passive_luck() == 1, "%%5,5 eksik can = 1 şans")
	player.health = 200.0
	player._process_cadi_passive()
	assert(is_equal_approx(player.luck, base_luck), "can dolunca şans geri gider (birikmez)")
	_cleanup()


# ------------------------------------------------------------------ Q

func test_q_toggles_drops_smoke_and_pays_per_second() -> void:
	var player: Node = _make_player()
	player.facing = "right"
	player.skill_state = "ready"
	var shield0: float = player.item_shield_hp
	player._cadi_toggle_q()
	assert(player._cadi_q_active and player.skill_state == "active", "Q açıldı")
	var cost: float = player._cadi_q_cost()
	assert(is_equal_approx(shield0 - player.item_shield_hp, cost), "açılışta ilk saniyenin bedeli")
	assert(player.item_shield_ability_slow_timer == 0.0, "Q kalkan yenilenmesini yavaşlatmaz (diğer Q'lar gibi)")
	assert(is_equal_approx(cost, 1000.0 * CM.Q_COST_PERCENT_OF_MAX + CM.Q_COST_FLAT), "bedel = azami kalkanın %%0,5'i + 5: %s" % cost)
	player._cadi_toggle_q()
	assert(player._cadi_q_active, "açıldıktan sonraki 1 sn'de basış kapatmaz (spam koruması)")
	player._process_cadi_visuals(0.016)
	assert(player.get_node_or_null(CM.POTION_NODE) != null, "şişe görseli kuruldu")
	player._process_cadi_q(0.05)
	assert(_group_count("cadi_smokes") == 1, "ilk bulut hemen düşer: %d" % _group_count("cadi_smokes"))
	var smoke: Node2D = get_tree().get_nodes_in_group("cadi_smokes")[0]
	assert(smoke.global_position.distance_to(player.global_position + CM.smoke_land_offset(player.facing)) < 0.5, "bulut dumanın indiği noktada doğar")
	## Katman: yaratıkların (z 0) üstünde, oyuncunun (aynı z, ağaç sırasında sonra) altında.
	smoke._place_under_players()
	assert(smoke.z_index == CM.SMOKE_Z and CM.SMOKE_Z == 1, "bulut z 1: yaratıkların üstünde (main.tscn'de Player da z 1)")
	assert(smoke.get_parent() != player.get_parent() or smoke.get_index() < player.get_index(), "bulut ağaçta oyuncudan önce: oyuncu dumanın üstünde çizilir")
	## Yerinde dururken bulut yığılmaz: bir sonraki SMOKE_IDLE_INTERVAL sonra...
	player._process_cadi_q(CM.SMOKE_V_DROP_INTERVAL + 0.05)
	assert(_group_count("cadi_smokes") == 1, "dururken sık bulut yok")
	## ...ve o zaman da yeni bulut açılmaz, aynı bulutun ömrü baştan başlar (%50 saydam bulutlar üst üste yığılmasın).
	smoke._t = 3.0
	player._process_cadi_q(CM.SMOKE_IDLE_INTERVAL)
	assert(_group_count("cadi_smokes") == 1 and smoke._t < 0.5, "dururken aynı bulut yenilenir: %d bulut, t=%s" % [_group_count("cadi_smokes"), smoke._t])
	## Yürürken SMOKE_V_DROP_INTERVAL'de bir; yan yürüyüşte de DİKEY bulut (dar + derin iz, kendi klipleri).
	player.global_position.x += 60.0
	player._process_cadi_q(CM.SMOKE_V_DROP_INTERVAL + 0.05)
	assert(_group_count("cadi_smokes") == 2, "yürürken yeni bulut: %d" % _group_count("cadi_smokes"))
	var vsmoke: Node2D = null
	for n: Node in get_tree().get_nodes_in_group("cadi_smokes"):
		if n != smoke:
			vsmoke = n
	assert(vsmoke != null and vsmoke.vert and vsmoke._sprite.animation == &"intro_v", "yan yürürken de dikey bulut kendi klibiyle açılır")
	assert(vsmoke.contains(vsmoke.global_position + Vector2(0, CM.SMOKE_V_RY - 1.0)) and not vsmoke.contains(vsmoke.global_position + Vector2(CM.SMOKE_V_RX + 1.0, 0)), "dikey iz dar + derin")
	## Hızlanınca süre beklenmez: son buluttan SMOKE_MAX_GAP uzaklaşıldı + SMOKE_MIN_DROP_TIME geçti -> yeni bulut (boşluk kalmaz).
	player.global_position.x += CM.SMOKE_MAX_GAP + 2.0
	player._process_cadi_q(CM.SMOKE_MIN_DROP_TIME + 0.01)
	assert(_group_count("cadi_smokes") == 3, "hızlı koşuda süre dolmadan yeni bulut: %d" % _group_count("cadi_smokes"))
	## ...ama çok kısa sürede (SMOKE_MIN_DROP_TIME'dan az) ışınlansa bile bulut yağmuru olmaz.
	player.global_position.x += CM.SMOKE_MAX_GAP * 3.0
	player._process_cadi_q(CM.SMOKE_MIN_DROP_TIME * 0.5)
	assert(_group_count("cadi_smokes") == 3, "bulut sıklığı SMOKE_MIN_DROP_TIME ile sınırlı: %d" % _group_count("cadi_smokes"))
	player.facing = "up"
	player.global_position.y -= 60.0
	player._process_cadi_q(CM.SMOKE_V_DROP_INTERVAL + 0.05)
	assert(_group_count("cadi_smokes") == 4, "yukarı yürürken yeni bulut: %d" % _group_count("cadi_smokes"))
	player.facing = "down"
	## Saniyelik bedel.
	var before: float = player.item_shield_hp
	player._process_cadi_q(1.0)
	assert(is_equal_approx(before - player.item_shield_hp, cost), "her saniye bedel")
	## Kalkan yetmeyince kapanır ve beklemeye girer.
	player.item_shield_hp = 0.0
	player._process_cadi_q(1.0)
	assert(not player._cadi_q_active and player.skill_state == "cooldown" and is_equal_approx(player.skill_timer, CM.Q_COOLDOWN), "kalkan bitince kapanır, 8 sn bekleme")
	player._process_cadi_visuals(0.016)
	var potion: Node = player.get_node_or_null(CM.POTION_NODE)
	assert(potion == null or potion.is_queued_for_deletion(), "kapanınca şişe gider")
	_cleanup()


func test_smoke_damages_once_per_second_regardless_of_overlap() -> void:
	var player: Node = _make_player()
	var pos: Vector2 = player.global_position + Vector2(300, 0)
	## Üst üste binen üç bulut (aynı noktadakiler tek buluta birleşir, o yüzden SMOKE_MIN_STEP'ten uzak): yaratık yine saniyede BİR hasar alır.
	for i in range(3):
		CM.spawn_smoke(self, pos + Vector2((i - 1) * (CM.SMOKE_MIN_STEP + 2.0), 0), true, {})
	assert(_group_count("cadi_smokes") == 3, "üç ayrı bulut")
	var inside: Node2D = _enemy(pos + Vector2(10, 4))
	var outside: Node2D = _enemy(pos + Vector2(0, 90))
	player._cadi_smoke_scan = 0.0
	player._process_cadi_smoke(0.01)
	assert(is_equal_approx(_lost(inside), 120.0), "dumandaki yaratık %%120: %s" % _lost(inside))
	assert(is_zero_approx(_lost(outside)), "dumanın dışındaki hasar almaz")
	player._cadi_smoke_scan = 0.0
	player._process_cadi_smoke(0.01)
	assert(is_equal_approx(_lost(inside), 120.0), "1 sn dolmadan ikinci hasar yok")
	player._cadi_smoke_next_hit[inside.get_instance_id()] = 0
	player._cadi_smoke_scan = 0.0
	player._process_cadi_smoke(0.01)
	assert(is_equal_approx(_lost(inside), 240.0), "1 sn sonra tekrar: %s" % _lost(inside))
	## Yetkili olmayan (başka oyuncunun) bulut hasar vermez.
	for n: Node in get_tree().get_nodes_in_group("cadi_smokes"):
		n.free()
	CM.spawn_smoke(self, pos, false, {})
	player._cadi_smoke_next_hit.clear()
	player._cadi_smoke_scan = 0.0
	player._process_cadi_smoke(0.01)
	assert(is_equal_approx(_lost(inside), 240.0), "kozmetik kopya hasar vermez")
	_cleanup()


func test_q_evolutions() -> void:
	var player: Node = _make_player()
	var base_cost: float = player._cadi_q_cost()
	player.apply_skill_evolution("cadi_q3", true)
	assert(is_equal_approx(player._cadi_q_cost(), base_cost * 0.5), "Tutumlu Karışım: bedel yarı")
	player.apply_skill_evolution("cadi_q2", true)
	player.apply_skill_evolution("cadi_q4", true)
	player._cadi_drop_smoke(player.global_position + Vector2(200, 0))
	var smoke: Node2D = get_tree().get_nodes_in_group("cadi_smokes")[0]
	assert(is_equal_approx(float(smoke.life), CM.SMOKE_LIFE + 3.0) and is_equal_approx(float(smoke.size_mult), 1.3), "Kalıcı Duman +3 sn, Yoğun Duman +%30")
	## Büyük bulut daha geniş alanı kapsar.
	var edge: Vector2 = smoke.global_position + Vector2(CM.SMOKE_RX * 1.2, 0)
	assert(smoke.contains(edge), "büyüyen bulutun izi de büyür")
	## Yapışkan Duman: hasar tikiyle yavaşlatır.
	player.apply_skill_evolution("cadi_q1", true)
	var e: Node2D = _enemy(smoke.global_position)
	player._cadi_smoke_scan = 0.0
	player._process_cadi_smoke(0.01)
	assert(is_equal_approx(float(e.get("_slow_percent")), CM.EVO_SMOKE_SLOW), "dumandaki yaratık %%30 yavaş: %s" % str(e.get("_slow_percent")))
	_cleanup()


# ------------------------------------------------------------------ E

func test_broom_speed_regen_and_ride_clip() -> void:
	var player: Node = _make_player()
	player.skill2_state = "ready"
	player.level = 20
	player._activate_skill2()
	assert(player._cadi_broom_active and player.skill2_state == "active", "süpürgeye bindi (standart skill2 makinesi)")
	assert(is_equal_approx(player.skill2_speed_multiplier, CM.E_SPEED_MULT) and is_equal_approx(player._skill2_duration, CM.E_DURATION), "+%20 hız, 8 sn")
	player._update_animation(true)
	assert(str(player.anim.animation) == CM.RIDE_ANIM_PREFIX + str(player.facing), "oturuş klibi: %s" % str(player.anim.animation))
	player._process_cadi_visuals(0.1)
	assert(player.anim.offset.y < player.cadi_base_offset.y, "süpürgedeyken sprite yükselir")
	var broom: Node = player.anim.get_node_or_null(CM.BROOM_NODE)
	assert(broom != null, "süpürge görseli karakter sprite'ının altında kuruldu")
	## Saniyede saldırı gücünün %10'u can + kalkan.
	player.max_health = 500.0
	player.health = 100.0
	player.item_shield_hp = 100.0
	var mult: float = player.heal_power_mult()
	player._process_cadi_broom(CM.E_REGEN_TICK + 0.01)
	assert(is_equal_approx(player.health, 100.0 + 10.0 * mult), "can +%%10 AP: %s" % player.health)
	assert(player.item_shield_hp > 100.0, "kalkan da yenilenir: %s" % player.item_shield_hp)
	## Süre dolunca iner.
	player._end_skill2_effects()
	assert(not player._cadi_broom_active and is_equal_approx(player.skill2_speed_multiplier, 1.0), "inince hız normale döner")
	player._process_cadi_visuals(0.1)
	assert(player.anim.offset == player.cadi_base_offset, "inince sprite ofseti tabana döner")
	var gone: Node = player.anim.get_node_or_null(CM.BROOM_NODE)
	assert(gone == null or gone.is_queued_for_deletion(), "süpürge görseli kalkar")
	_cleanup()


func test_broom_evolutions() -> void:
	var player: Node = _make_player()
	var knock0: float = player.knockback_force
	player.apply_skill_evolution("cadi_e2", true)
	player.apply_skill_evolution("cadi_e3", true)
	player.apply_skill_evolution("cadi_e4", true)
	assert(is_zero_approx(player._cadi_ride_dodge()), "süpürgede değilken sıvışma bonusu yok")
	player._skill_cadi_broom()
	assert(is_equal_approx(player.skill2_speed_multiplier, CM.EVO_E_SPEED_MULT), "Rüzgâr Süpürgesi: +%50")
	assert(is_equal_approx(player._cadi_ride_dodge(), CM.EVO_E_DODGE), "Kıvrak Süpürge: %25 sıvışma")
	assert(is_equal_approx(player.knockback_force, knock0 + CM.EVO_E_KNOCKBACK), "Süpüren Darbe: silah itişi eklenir")
	## Pike (final): değdiği yaratığa %100 + 2 sn sabitleme; aynı yaratığa aralık dolmadan tekrar vurmaz.
	player.apply_skill_evolution("cadi_ef", true)
	var e: Node2D = _enemy(player.global_position + Vector2(12, 0))
	player._process_cadi_broom(0.05)
	assert(is_equal_approx(_lost(e), 100.0) and bool(e.get("is_rooted")), "temas: %%100 + sabitleme (%s)" % _lost(e))
	player._process_cadi_broom(0.05)
	assert(is_equal_approx(_lost(e), 100.0), "aynı yaratığa hemen tekrar vurmaz")
	player._end_cadi_broom()
	assert(is_equal_approx(player.knockback_force, knock0), "inince silah itişi geri alınır")
	_cleanup()


func test_passenger_seats_are_the_same_on_every_client() -> void:
	var player: Node = _make_player()
	NetworkManager.is_multiplayer_active = true
	var my_peer: int = CM.local_peer(get_tree())
	var witch: Node = _remote(77, CADI, Vector2(3200.0, 3000.0))
	witch._apply_cadi_net_state([0, 1], 0)
	assert(CM.is_broom_rider(witch), "kukla cadı süpürgede")
	var other: Node = _remote(90, 14, Vector2(3300.0, 3000.0))
	other._apply_cadi_net_state(null, 77)
	## Yerel oyuncu cadıya değince biner.
	player.global_position = witch.global_position + Vector2(8, 0)
	var riding: bool = player._cadi_passenger_follow(Vector2.ZERO, 0.016)
	assert(riding and player.cadi_ride_host_peer == 77, "değince biner")
	var riders: Array = CM.riders_of(get_tree(), 77)
	assert(riders.size() == 2 and riders == [mini(my_peer, 90), maxi(my_peer, 90)], "yolcular peer sırasına göre: %s" % str(riders))
	var seat: int = CM.seat_index(get_tree(), 77, my_peer)
	assert(player.global_position.distance_to(witch.global_position + CM.seat_offset(seat, CM.facing_of(witch))) < 0.5, "yolcu koltuğunda")
	## Kukla yolcu da AYNI formülle oturtulur.
	other._cadi_snap_to_seat()
	assert(other.global_position.distance_to(witch.global_position + CM.seat_offset(CM.seat_index(get_tree(), 77, 90), CM.facing_of(witch))) < 0.5, "kukla yolcu koltuğunda")
	assert(player.global_position.distance_to(other.global_position) > 5.0, "iki yolcu aynı koltukta değil")
	## İlk 1 sn hareket indirmez; sonra indirir.
	assert(player._cadi_passenger_follow(Vector2.RIGHT, 0.2), "ilk 1 sn inilemez")
	## Kilit bitince bile kısa dokunuş (0,5 sn'den az) indirmez; kesintisiz 0,5 sn basılı tutmak indirir.
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.9), "kilit bitti, girdi yok")
	assert(player._cadi_passenger_follow(Vector2.RIGHT, 0.3), "0,3 sn dokunuş indirmez")
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.1), "girdi bırakılınca sayaç sıfırlanır")
	assert(player._cadi_passenger_follow(Vector2.RIGHT, 0.3), "ikinci kısa dokunuş da indirmez")
	assert(not player._cadi_passenger_follow(Vector2.RIGHT, 0.3) and player.cadi_ride_host_peer == 0, "0,5 sn kesintisiz basılı tutunca iner")
	assert(is_zero_approx(player._cadi_autorun_left), "basılı girdiyle inince otomatik koşu yok")
	## Cadı süpürgeden inince (girdi yok) yolcu cadının baktığı yöne otomatik koşarak başlar.
	player._cadi_remount_lock = 0.0
	player.global_position = witch.global_position
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.016), "yeniden bindi (otomatik koşu sınaması)")
	witch._apply_cadi_net_state([0, 0], 0)
	assert(not player._cadi_passenger_follow(Vector2.ZERO, 0.016) and player._cadi_autorun_left > 0.0 and player._cadi_autorun_dir.length() > 0.9, "süpürge bitince otomatik koşu başlar")
	witch._apply_cadi_net_state([0, 1], 0)
	player._cadi_autorun_left = 0.0
	## İner inmez yeniden binmez (kilit).
	assert(not player._cadi_passenger_follow(Vector2.ZERO, 0.1), "inince hemen yeniden binmez")
	## Cadı süpürgeden inince yolcu da iner.
	player._cadi_remount_lock = 0.0
	player.global_position = witch.global_position
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.016), "yeniden bindi")
	witch._apply_cadi_net_state([0, 0], 0)
	assert(not player._cadi_passenger_follow(Vector2.ZERO, 0.016) and player.cadi_ride_host_peer == 0, "süpürge bitince yolcu iner")
	## Cadı Demirci/ev içine girince (başka köşeye ışınlanır, is_indoors=true) yolcu peşinden ışınlanmaz, olduğu yerde iner.
	witch._apply_cadi_net_state([0, 1], 0)
	player._cadi_remount_lock = 0.0
	player.global_position = witch.global_position
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.016), "yeniden bindi (iç mekan sınaması)")
	var door_pos: Vector2 = player.global_position
	witch.is_indoors = true
	witch.global_position = Vector2(90000.0, 90000.0)
	assert(not player._cadi_passenger_follow(Vector2.ZERO, 0.016) and player.cadi_ride_host_peer == 0, "cadı içeri girince yolcu iner")
	assert(player.global_position.distance_to(door_pos) < 0.5, "yolcu cadının peşinden ışınlanmamalı: %s" % str(player.global_position))
	## Bayrak gecikse bile (ağda konum bayraktan önce gelir) ani büyük sıçrama da indirir, kukla yolcu da oturtmaz.
	witch.is_indoors = false
	player._cadi_remount_lock = 0.0
	witch.global_position = door_pos
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.016), "yeniden bindi (sıçrama sınaması)")
	witch.global_position = door_pos + Vector2(5000.0, 0.0)
	assert(not player._cadi_passenger_follow(Vector2.ZERO, 0.016), "büyük sıçrama yolcuyu indirir")
	var puppet_before: Vector2 = other.global_position
	other._cadi_snap_to_seat()
	assert(other.global_position == puppet_before, "kukla yolcu uzağa sıçrayan cadıya oturtulmaz")
	_cleanup()


func test_passenger_gets_the_witch_evolution_dodge() -> void:
	var player: Node = _make_player()
	NetworkManager.is_multiplayer_active = true
	var witch: Node = _remote(77, CADI, player.global_position + Vector2(6, 0))
	witch._apply_cadi_net_state([0, 1], 0)
	assert(player._cadi_passenger_follow(Vector2.ZERO, 0.016), "bindi")
	assert(is_zero_approx(player._cadi_ride_dodge()), "cadının evrimi yokken bonus yok")
	witch._evolutions = {"cadi_e2": true} if "_evolutions" in witch else {}
	if witch.has_evo("cadi_e2"):
		assert(is_equal_approx(player._cadi_ride_dodge(), CM.EVO_E_DODGE), "yolcu cadının Kıvrak Süpürge evrimini alır")
	_cleanup()


# ------------------------------------------------------------------ R

func test_r_charges_lock_recharge_and_next_potion() -> void:
	var player: Node = _make_player()
	player._process_cadi_r(0.0)
	var hud: Dictionary = player.get_cadi_r_hud_state()
	assert(int(hud["charges"]) == CM.R_MAX_CHARGES and int(hud["max"]) == 5, "5 yükle başlar")
	var next: int = player._cadi_next_potion
	assert(str(hud["icon"]) == CM.R_ICONS[next] and str(hud["name"]).contains(CM.POTION_NAMES[next]), "ikon SIRADAKİ iksiri gösterir")
	var shield0: float = player.item_shield_hp
	player._cadi_try_throw()
	assert(player.cadi_r_charges == 4 and player._cadi_last_potion == next, "atış bir yük harcar, sıradaki iksiri atar")
	assert(player._cadi_next_potion != next, "yeni sıradaki iksir farklı")
	var cost: float = (1000.0 * player.SKILL_SHIELD_COST_PERCENT_OF_MAX + player.SKILL_SHIELD_COST_FLAT) * CM.R_COST_SHARE
	assert(is_equal_approx(shield0 - player.item_shield_hp, cost), "atış bedeli = ulti bedelinin 1/5'i: %s" % (shield0 - player.item_shield_hp))
	player._cadi_try_throw()
	assert(player.cadi_r_charges == 4, "0,5 sn içinde ikinci atış yok (spam koruması)")
	player._process_cadi_r(CM.R_THROW_LOCK + 0.01)
	player._cadi_try_throw()
	assert(player.cadi_r_charges == 3, "kilit bitince atılır")
	## Dolum: yük başına 8 sn, sırayla.
	assert(is_equal_approx(player._cadi_r_recharge_time(), CM.R_RECHARGE), "8 sn")
	player._process_cadi_r(CM.R_RECHARGE)
	assert(player.cadi_r_charges == 4, "8 sn'de bir yük dolar: %d" % player.cadi_r_charges)
	player.apply_skill_evolution("cadi_r2", true)
	assert(is_equal_approx(player._cadi_r_recharge_time(), CM.R_RECHARGE / 1.25), "Hızlı Demleme: %%25 hızlı dolum = 6,4 sn")
	## Yük bitince atılmaz.
	player.cadi_r_charges = 0
	player._cadi_r_lock = 0.0
	player._cadi_try_throw()
	assert(player.cadi_r_charges == 0, "yük yokken atış yok")
	_cleanup()


func test_r_targets_the_densest_cluster_and_the_weakest_ally() -> void:
	var player: Node = _make_player()
	var lone: Node2D = _enemy(player.global_position + Vector2(60, 0))
	var pack: Array = []
	for i in range(4):
		pack.append(_enemy(player.global_position + Vector2(-150 + i * 8, 30)))
	var target: Vector2 = player._cadi_pick_throw_target(CM.POTION_ICE, 1.0)
	assert(target.distance_to(lone.global_position) > 100.0 and target.distance_to((pack[1] as Node2D).global_position) < 40.0, "saldırı iksiri kalabalığa: %s" % str(target))
	## Yaratık yoksa baktığı yöne.
	for e: Node in pack + [lone]:
		e.free()
	player.facing = "right"
	var fallback: Vector2 = player._cadi_pick_throw_target(CM.POTION_FEAR, 1.0)
	assert(fallback.x > player.global_position.x + 50.0, "hedef yokken baktığı yöne")
	## Şifa: canı (oran) en az müttefike; herkes tamsa cadının kendisine.
	player.max_health = 100.0
	player.health = 100.0
	var ally: Node = _remote(90, 14, player.global_position + Vector2(80, -40))
	ally.max_health = 200.0
	ally.health = 200.0
	assert(player._cadi_pick_throw_target(CM.POTION_HEAL, 1.0).distance_to(player._cadi_feet()) < 0.5, "herkes tamken kendine")
	ally.health = 50.0
	assert(player._cadi_pick_throw_target(CM.POTION_HEAL, 1.0).distance_to(ally.global_position) < 20.0, "canı az müttefike")
	## Kalkan: mana kalkanı oranı en az müttefike; kalkanı olmayan aday değil, herkes tamsa cadının kendisine.
	assert(player._cadi_pick_throw_target(CM.POTION_SHIELD, 1.0).distance_to(player._cadi_feet()) < 0.5, "kalkanı olmayan müttefik aday değil -> kendine")
	ally.item_shield_max = 200.0
	ally.item_shield_hp = 200.0
	assert(player._cadi_pick_throw_target(CM.POTION_SHIELD, 1.0).distance_to(player._cadi_feet()) < 0.5, "herkesin kalkanı tamken kendine")
	ally.item_shield_hp = 40.0
	assert(player._cadi_pick_throw_target(CM.POTION_SHIELD, 1.0).distance_to(ally.global_position) < 20.0, "kalkanı en az müttefike")
	_cleanup()


func test_potions_apply_their_effects() -> void:
	var player: Node = _make_player()
	var opts: Dictionary = {"duration": CM.ZONE_DURATION, "size": 1.0}
	## 3 Patlama: alan açmaz, %200.
	var p_boom: Vector2 = player.global_position + Vector2(400, 0)
	var e_boom: Node2D = _enemy(p_boom + Vector2(20, 0))
	var e_far: Node2D = _enemy(p_boom + Vector2(CM.BOOM_RADIUS + 60.0, 0))
	player._on_cadi_bottle_land(CM.POTION_BOOM, p_boom, opts)
	assert(is_equal_approx(_lost(e_boom), 200.0) and is_zero_approx(_lost(e_far)), "patlama %%200, menzil dışına yok: %s" % _lost(e_boom))
	assert(_group_count("cadi_zones") == 0, "patlama alan açmaz")
	## 2 Don: bir kez dondurur + %100.
	var p_ice: Vector2 = player.global_position + Vector2(0, 400)
	var e_ice: Node2D = _enemy(p_ice + Vector2(10, 0))
	player._on_cadi_bottle_land(CM.POTION_ICE, p_ice, opts)
	var zone: Node2D = get_tree().get_nodes_in_group("cadi_zones")[0]
	assert(bool(zone.authoritative) and int(zone.potion) == CM.POTION_ICE and is_equal_approx(float(zone.duration), CM.ZONE_DURATION), "don alanı açıldı")
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(_lost(e_ice), 100.0) and bool(e_ice.get("is_frozen")), "don: %%100 + donma (%s)" % _lost(e_ice))
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(_lost(e_ice), 100.0), "aynı yaratık aynı alandan bir kez etkilenir")
	zone.free()
	## 5 Korku: bir kez korkutur + %100.
	var p_fear: Vector2 = player.global_position + Vector2(-400, 0)
	var e_fear: Node2D = _enemy(p_fear)
	player._on_cadi_bottle_land(CM.POTION_FEAR, p_fear, opts)
	zone = get_tree().get_nodes_in_group("cadi_zones")[0]
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(_lost(e_fear), 100.0) and bool(e_fear.get("is_feared")), "korku: %%100 + korku")
	zone.free()
	## 1 Delilik: normal yaratık delirir; boss ve elit delirmez.
	var p_mad: Vector2 = player.global_position + Vector2(0, -400)
	var e_mad: Node2D = _enemy(p_mad)
	var e_boss: Node2D = _enemy(p_mad + Vector2(14, 0))
	e_boss.is_boss = true
	var e_elite: Node2D = _enemy(p_mad + Vector2(-14, 0))
	e_elite.is_elite = true
	player._on_cadi_bottle_land(CM.POTION_MAD, p_mad, opts)
	zone = get_tree().get_nodes_in_group("cadi_zones")[0]
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(bool(e_mad.is_mad) and not bool(e_boss.is_mad) and not bool(e_elite.is_mad), "delilik: boss ve elit hariç")
	assert(is_zero_approx(_lost(e_mad)), "delilik iksiri kendi başına hasar vermez")
	zone.free()
	## 4 Şifa: üstündeki cadı saniyede %20.
	player.max_health = 1000.0
	player.health = 100.0
	var mult: float = player.heal_power_mult()
	player._on_cadi_bottle_land(CM.POTION_HEAL, player._cadi_feet(), opts)
	zone = get_tree().get_nodes_in_group("cadi_zones")[0]
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.health, 100.0 + 20.0 * mult), "şifa %%20 AP: %s" % player.health)
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.health, 100.0 + 20.0 * mult), "saniyede bir (0,2 sn sonra tekrar yok)")
	player.global_position += Vector2(300, 0)
	zone.heal_timer = 0.0
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.health, 100.0 + 20.0 * mult), "alanın dışındayken şifa yok")
	zone.free()
	## 6 Kalkan: şifa ile aynı mantık - üstündeki cadı + müttefik saniyede saldırı gücünün %25'i kadar mana kalkanı (can DEĞİL).
	player.global_position = Vector2(3000.0, 3000.0)
	player.health = 500.0
	player.max_health = 1000.0
	player.item_shield_max = 1000.0
	player.item_shield_hp = 100.0
	var ally_s: Node = _remote(91, 14, player.global_position + Vector2(20, -10))
	ally_s.item_shield_max = 400.0
	ally_s.item_shield_hp = 0.0
	var ally_none: Node = _remote(92, 14, player.global_position + Vector2(-20, -10)) ## kalkanı yok: dokunulmaz
	var none_hp: float = float(ally_none.health)
	player._on_cadi_bottle_land(CM.POTION_SHIELD, player._cadi_feet(), opts)
	zone = get_tree().get_nodes_in_group("cadi_zones")[0]
	assert(int(zone.potion) == CM.POTION_SHIELD and bool(zone.authoritative), "kalkan alanı açıldı")
	var mult_s: float = player.heal_power_mult()
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.item_shield_hp, 100.0 + 25.0 * mult_s), "kalkan iksiri cadıya %%25 AP kalkan: %s" % player.item_shield_hp)
	assert(is_equal_approx(player.health, 500.0), "kalkan iksiri can basmaz")
	assert(is_equal_approx(float(ally_s.item_shield_hp), 25.0 * mult_s), "müttefike %%25 AP kalkan: %s" % ally_s.item_shield_hp)
	assert(is_zero_approx(float(ally_none.item_shield_hp)) and is_equal_approx(float(ally_none.health), none_hp), "kalkanı olmayan müttefik etkilenmez")
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.item_shield_hp, 100.0 + 25.0 * mult_s), "saniyede bir (0,2 sn sonra tekrar yok)")
	zone.heal_timer = 0.0
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.item_shield_hp, 100.0 + 50.0 * mult_s), "ikinci saniye ikinci tik")
	player.global_position += Vector2(300, 0)
	zone.heal_timer = 0.0
	player._on_cadi_zone_scan(zone, CM.ZONE_SCAN_INTERVAL)
	assert(is_equal_approx(player.item_shield_hp, 100.0 + 50.0 * mult_s), "alanın dışındayken kalkan yok")
	_cleanup()


func test_r_evolutions_reach_the_zone_and_the_bottle() -> void:
	var player: Node = _make_player()
	player.apply_skill_evolution("cadi_r1", true)
	player.apply_skill_evolution("cadi_rf", true)
	player._process_cadi_r(0.0)
	player._cadi_next_potion = CM.POTION_ICE
	player._cadi_try_throw()
	var bottle: Node2D = null
	for c: Node in get_children():
		if c.get("zone_opts") != null and c.get("potion") != null:
			bottle = c as Node2D
	assert(bottle != null and int(bottle.potion) == CM.POTION_ICE, "şişe fırlatıldı")
	_spawned.append(bottle)
	assert(is_equal_approx(float(bottle.zone_opts["duration"]), CM.ZONE_DURATION + 1.5) and is_equal_approx(float(bottle.zone_opts["size"]), 1.4), "Uzun Etki +1,5 sn, Geniş Karışım +%40")
	## Şişe yere değince alan AYNI seçeneklerle açılır.
	bottle._land()
	var zone: Node2D = get_tree().get_nodes_in_group("cadi_zones")[0]
	assert(is_equal_approx(float(zone.duration), CM.ZONE_DURATION + 1.5) and is_equal_approx(float(zone.size_mult), 1.4), "alan evrimli süre/boyutla")
	assert(zone.contains(zone.global_position + Vector2(CM.ZONE_RX * 1.3, 0)) and not zone.contains(zone.global_position + Vector2(CM.ZONE_RX * 1.5, 0)), "alanın izi %40 büyür")
	## Diğer oyunculardaki kopya (on_land yok): aynı alanı sadece görsel olarak açar.
	zone.free()
	var copy: Node2D = CM.spawn_bottle(self, CM.POTION_FEAR, Vector2(100, 100), Vector2(200, 100), Callable(), {"duration": 5.5, "size": 1.4})
	copy._land()
	zone = get_tree().get_nodes_in_group("cadi_zones")[0]
	assert(not bool(zone.authoritative) and int(zone.potion) == CM.POTION_FEAR and is_equal_approx(float(zone.duration), 5.5), "kopya alan kozmetik")
	_cleanup()


# ------------------------------------------------------------------ yaratık deliliği

func test_mad_creature_attacks_its_neighbour_and_recovers() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var a: Node2D = _enemy(Vector2(5000, 5000))
	var b: Node2D = _enemy(Vector2(5020, 5000))
	a.contact_damage = 37.0
	a.apply_madness(CM.MAD_DURATION)
	assert(bool(a.is_mad) and is_instance_valid(a.get("_mad_status_fx")), "delirdi + gösterge")
	for _i in range(6):
		a._process_madness(0.1)
	assert(a.get("_mad_victim") == b, "en yakın yaratığı hedef alır")
	assert(is_equal_approx(_lost(b), 37.0), "kendi temas hasarını vurur: %s" % _lost(b))
	assert(is_zero_approx(_lost(a)), "kurban delirmediği için karşılık vermez")
	for _i in range(60):
		a._process_madness(0.1)
	assert(not bool(a.is_mad), "4 sn sonra düzelir")
	assert(_lost(b) >= 37.0 * 3.0, "delilik boyunca saniyede bir vurur: %s" % _lost(b))
	## Boss ve elit delirmez.
	b.is_boss = true
	b.apply_madness(4.0)
	assert(not bool(b.is_mad), "boss delirmez")
	_cleanup()


# ------------------------------------------------------------------ kukla (diğer oyuncunun ekranı)

func test_remote_copy_builds_potion_and_broom_from_net_state() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = _remote(77, CADI, Vector2(4000.0, 4000.0))
	rp.setup(77, CADI, "cadi")
	rp.set_physics_process(false)
	rp._apply_cadi_net_state([1, 1], 0)
	rp._process_cadi_remote(0.1)
	assert(rp.get_node_or_null(CM.POTION_NODE) != null, "kuklada şişe")
	assert(rp.anim.get_node_or_null(CM.BROOM_NODE) != null and rp.is_cadi_broom_active(), "kuklada süpürge")
	assert(rp.anim.offset.y < rp.cadi_base_offset.y, "kukla süpürgede yükselir")
	rp._apply_cadi_net_state([0, 0], 0)
	rp._process_cadi_remote(0.1)
	var potion: Node = rp.get_node_or_null(CM.POTION_NODE)
	var broom: Node = rp.anim.get_node_or_null(CM.BROOM_NODE)
	assert((potion == null or potion.is_queued_for_deletion()) and (broom == null or broom.is_queued_for_deletion()), "durum kapanınca görseller gider")
	assert(rp.anim.offset == rp.cadi_base_offset, "kukla ofseti tabana döner")
	## Cadı olmayan kukla: sadece yolculuk alanı işlenir.
	var other: Node = _remote(90, 14, Vector2(4100.0, 4000.0))
	other._apply_cadi_net_state([1, 1], 77)
	assert(other.cadi_ride_host_peer == 77 and not other.is_cadi_broom_active(), "başka karakter süpürge sürmez ama yolcu olabilir")
	_cleanup()
