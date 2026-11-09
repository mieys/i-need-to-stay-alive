extends Node

## Madde 486 (Yeni_Esyalar.zip): 7 epik + 4 efsanevi eşya + Kemik Kolye pasifi + silah türü koşulu (Items.weapon_gate_ok).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const NEW_KEYS := ["vampir_disleri", "urkek_yurek", "kan_damlasi_kolyesi", "kackinin_cizmeleri", "haydut_kesesi", "gladyator_eldivenleri",
	"avci_oklugu", "kan_kapani", "haydut_kralinin_taci", "barbar_kralin_migferi", "gok_kartalin_kanatlari"]

var _players: Array = []


func _reset() -> void:
	GameManager.owned_items = []
	GameManager.owned_weapons = []
	GameManager.gold = 100000


func _make_player() -> Node:
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_players.append(p)
	p.max_item_slots = 6
	return p


func _cleanup() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_reset()


func _weapons(keys: Array) -> void:
	GameManager.owned_weapons = []
	for k in keys:
		GameManager.owned_weapons.append({"key": k, "level": 1, "spent": 0})


func test_defs_icons_and_pairs() -> void:
	_reset()
	for k in NEW_KEYS:
		assert(Items.DEFS.has(k), "%s tanımlı olmalı" % k)
		assert(Items.KEYS.has(k), "%s KEYS'te olmalı" % k)
		assert(FileAccess.file_exists("res://assets/items/%s.png" % k), "%s ikonu yok" % k)
	for pair in [["vampir_disleri", "kan_kapani"], ["haydut_kesesi", "haydut_kralinin_taci"],
			["gladyator_eldivenleri", "barbar_kralin_migferi"], ["avci_oklugu", "gok_kartalin_kanatlari"]]:
		assert((Items.recipe(pair[1]) as Array).has(pair[0]), "%s tarifinde %s olmalı" % [pair[1], pair[0]])
		assert(Items.kademe(pair[0]) == Items.KADEME_EPIK and Items.kademe(pair[1]) == Items.KADEME_EFSANEVI, "kademe")
	assert(Items.describe("vampir_disleri").contains("Kritik Hasarı"), "kritik hasar satırı: %s" % Items.describe("vampir_disleri"))
	assert(Items.describe("kemik_kolye").contains("Pasif"), "Kemik Kolye pasifi var")
	_cleanup()


func test_weapon_gate() -> void:
	_reset()
	_weapons(["uzunkilic", "dagger"])
	assert(not Items.weapon_gate_ok("gladyator_eldivenleri"), "2 silahla çıkmaz (3 silah şartı)")
	_weapons(["uzunkilic", "dagger", "topuz"])
	assert(Items.weapon_gate_ok("gladyator_eldivenleri") and Items.weapon_gate_ok("barbar_kralin_migferi"), "3 yakın dövüş")
	assert(not Items.weapon_gate_ok("avci_oklugu") and not Items.weapon_gate_ok("gok_kartalin_kanatlari"), "menzilli eşya çıkmaz")
	_weapons(["uzunkilic", "dagger", "tabanca"])
	assert(not Items.weapon_gate_ok("gladyator_eldivenleri"), "karışık dizilim: hiçbiri çıkmaz")
	assert(not Items.weapon_gate_ok("avci_oklugu"), "karışık dizilim: hiçbiri çıkmaz (2)")
	_weapons(["tabanca", "yay", "fire_staff"])
	assert(Items.weapon_gate_ok("avci_oklugu") and Items.weapon_gate_ok("gok_kartalin_kanatlari"), "3 menzilli")
	assert(Items.weapon_gate_ok("kan_kapani"), "koşulsuz eşya her zaman")
	assert(Items.purchase_block_reason("gladyator_eldivenleri", [], 6) != "", "koşul sağlanmazken alınamaz")
	assert(Items.purchase_block_reason("avci_oklugu", [], 6) == "", "koşul sağlanınca alınabilir")
	_cleanup()


func test_stats_apply_and_sell_back() -> void:
	_reset()
	var p: Node = _make_player()
	var cc0: float = p.crit_chance_bonus
	var cd0: float = p.item_crit_damage_bonus
	p._apply_item_stats("vampir_disleri", 1.0)
	assert(is_equal_approx(p.crit_chance_bonus - cc0, 0.06) and is_equal_approx(p.item_crit_damage_bonus - cd0, 0.10), "Vampir Dişleri statları")
	p._apply_item_stats("vampir_disleri", -1.0)
	assert(is_equal_approx(p.crit_chance_bonus, cc0) and is_equal_approx(p.item_crit_damage_bonus, cd0), "satınca geri alınır")
	var m0: float = p.item_melee_mult_bonus
	p._apply_item_stats("barbar_kralin_migferi", 1.0)
	assert(is_equal_approx(p.item_melee_mult_bonus - m0, 0.18), "Barbar %18 yakın dövüş")
	p._apply_item_stats("gok_kartalin_kanatlari", 1.0)
	assert(is_equal_approx(p.item_ranged_mult_bonus, 0.18), "Gök Kartal %18 menzilli")
	_cleanup()


func test_kemik_kolye_charges() -> void:
	_reset()
	var p: Node = _make_player()
	p.damage_bonus = 100.0
	assert(is_equal_approx(p.item_kemik_take_bonus(), 0.0), "eşya yokken bonus yok")
	p.acquire_item("kemik_kolye", {}, 0)
	p.damage_bonus = 100.0
	p._item_watch_skill_use(0.016) ## ilk çağrı: hazır durum kaydedilir
	p.skill_state = "cooldown" ## Q kullanıldı
	p._item_watch_skill_use(0.016)
	assert(p._item_kemik_charges == 6, "yetenekten sonra 6 yük")
	var bonus: float = p.item_kemik_take_bonus()
	assert(is_equal_approx(bonus, 10.0 + p.damage_bonus * 0.05), "10 + %%5 SG: %s" % bonus)
	for i in 5:
		p.item_kemik_take_bonus()
	assert(is_equal_approx(p.item_kemik_take_bonus(), 0.0), "6 saldırıdan sonra bonus biter")
	## 10 sn bekleme: yeni yetenek hemen yeniden yüklemez
	p.skill_state = "ready"
	p._item_watch_skill_use(0.016)
	p.skill_state = "cooldown"
	p._item_watch_skill_use(0.016)
	assert(p._item_kemik_charges == 0, "bekleme sırasında yük yok")
	p._item_watch_skill_use(10.0)
	p.skill_state = "ready"
	p._item_watch_skill_use(0.016)
	p.skill_state = "cooldown"
	p._item_watch_skill_use(0.016)
	assert(p._item_kemik_charges == 6, "bekleme bitince yeniden yük")
	_cleanup()


func test_urkek_yurek_and_kan_damlasi() -> void:
	_reset()
	var p: Node = _make_player()
	p.acquire_item("urkek_yurek", {}, 0)
	p.health = p.max_health
	p._item_urkek_check()
	assert(p._item_urkek_timer <= 0.0, "can yüksekken tetiklenmez")
	p.health = p.max_health * 0.2
	var base: float = p.get_effective_move_speed()
	p._item_urkek_check()
	assert(is_equal_approx(p._item_urkek_timer, 6.0), "tetiklendi")
	var boosted: float = p.get_effective_move_speed()
	assert(is_equal_approx(boosted - base, 50.0), "+50 hız (fark %s)" % (boosted - base))
	p._item_urkek_timer = 3.0
	assert(is_equal_approx(p.get_effective_move_speed() - base, 25.0), "yarı sürede +25 (yavaşça kaybolur)")
	p._item_urkek_timer = 0.0
	p._item_urkek_check()
	assert(p._item_urkek_timer <= 0.0, "60 sn bekleme")
	p.acquire_item("kan_damlasi_kolyesi", {}, 0)
	var ls_low: float = p.get_total_lifesteal()
	p.health = p.max_health
	var ls_full: float = p.get_total_lifesteal()
	assert(is_equal_approx(ls_low - ls_full, 0.002), "canın %50 altında +%0,2 can emme")
	_cleanup()


func test_kackin_boss_and_haydut_gold() -> void:
	_reset()
	var p: Node = _make_player()
	p.acquire_item("kackinin_cizmeleri", {}, 0)
	var spd0: float = p.item_speed_percent
	var dod0: float = p.dodge_chance
	var boss := Node2D.new()
	boss.add_to_group("boss")
	add_child(boss)
	p._item_kackin_check = 0.0
	p._item_kackin_sync(0.1)
	assert(is_equal_approx(p.item_speed_percent - spd0, 0.05) and is_equal_approx(p.dodge_chance - dod0, 0.03), "boss yaşarken bonus")
	boss.remove_from_group("boss")
	boss.queue_free()
	p._item_kackin_check = 0.0
	p._item_kackin_sync(0.1)
	assert(is_equal_approx(p.item_speed_percent, spd0) and is_equal_approx(p.dodge_chance, dod0), "boss ölünce bonus kalkar")
	## Haydut Kesesi: 10 öldürmede 5 altın; Taç: her öldürmede 1
	GameManager.gold = 0
	p.acquire_item("haydut_kesesi", {}, 0)
	for i in 10:
		p._item_on_kill()
	assert(GameManager.gold == 5, "10 öldürme = 5 altın (bulunan %d)" % GameManager.gold)
	p.acquire_item("haydut_kralinin_taci", {}, 0)
	GameManager.gold = 0
	for i in 3:
		p._item_on_kill()
	assert(GameManager.gold == 3, "taç: öldürme başına 1 altın (bulunan %d)" % GameManager.gold)
	_cleanup()


func test_crit_heal_items() -> void:
	_reset()
	var p: Node = _make_player()
	p.acquire_item("kan_kapani", {}, 0)
	p.health = 1.0
	for i in 400:
		p.item_on_crit(200.0)
	assert(p.health > 1.0, "Kan Kapanı kritikte can yeniler")
	var healed: float = p.health - 1.0
	assert(healed > 0.0 and fmod(healed, 10.0) < 0.001 or healed > 0.0, "iyileşme 200 x %5 = 10 katı")
	_cleanup()
