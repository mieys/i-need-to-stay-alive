extends Node

## Madde 637: oynayış profili öneri ağırlığı (scripts/build_affinity.gd). Kullanıcı: "bir oyuncu bir stata çok abanıyorsa o stata odaklı
## şeylerin çıkma ihtimali biraz daha fazla olmalı, aynı şey silah türleri için de geçerli". Kilitler: boş profil = düz rastgele, abanılan
## stat öne çıkar ama tavan x1,6 (garanti yok), neredeyse her eşyadaki Saldırı Gücü profili "saldırıcı"ya kaydırmaz, silah ailesi + en
## çok hasar veren silahın geliştirmesi öne çıkar, pazarda yine de çeşitlilik var.

const Affinity := preload("res://scripts/build_affinity.gd")
const Market := preload("res://scripts/level_market.gd")
const MetaProgressTestScript := preload("res://scripts/meta_progress.gd")


class FakePlayer extends Node2D:
	var level: int = 12
	var luck: float = 0.0
	var upgrade_log: Array = []

	func get_max_owned_weapons() -> int:
		return 3

	func get_max_item_slots() -> int:
		return 9


var _saved: Dictionary = {}


func _save_state() -> void:
	_saved = {"weapons": GameManager.owned_weapons.duplicate(true), "items": GameManager.owned_items.duplicate(true),
		"enchant": GameManager.shield_enchant, "msaved": GameManager.market_saved.duplicate(true),
		"mbanned": GameManager.market_banned.duplicate()}
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("fire_staff", 1, 0)]
	GameManager.owned_items = []
	GameManager.shield_enchant = ""
	GameManager.market_saved = []
	GameManager.market_banned = []
	MetaProgressTestScript.unlock_all_override = true


func _restore_state() -> void:
	MetaProgressTestScript.unlock_all_override = false
	GameManager.owned_weapons = _saved["weapons"]
	GameManager.owned_items = _saved["items"]
	GameManager.shield_enchant = str(_saved["enchant"])
	GameManager.market_saved = _saved["msaved"]
	GameManager.market_banned = _saved["mbanned"]


func test_empty_profile_is_neutral() -> void:
	_save_state()
	var p := FakePlayer.new()
	var prof: Dictionary = Affinity.profile(p)
	assert((prof["stat"] as Dictionary).is_empty() and float(prof["conf"]) == 0.0, "kart/eşya yokken stat profili boş olmalı: %s" % prof)
	for id in Affinity.AXES:
		assert(is_equal_approx(Affinity.card_weight(prof, str(id)), 1.0), "boş profilde kart ağırlığı 1: %s" % id)
	p.free()
	_restore_state()


func test_heavy_stat_raises_its_weight_capped() -> void:
	_save_state()
	var p := FakePlayer.new()
	for i in 8:
		p.upgrade_log.append(["lifesteal", 1])
	p.upgrade_log.append(["max_health", 1])
	var prof: Dictionary = Affinity.profile(p)
	var w_ls: float = Affinity.card_weight(prof, "lifesteal")
	var w_hp: float = Affinity.card_weight(prof, "max_health")
	var w_luck: float = Affinity.card_weight(prof, "luck")
	assert(w_ls > 1.3, "abanılan Can Çalma kartı belirgin daha sık: %.2f" % w_ls)
	assert(w_ls <= 1.0 + Affinity.MAX_BOOST + 0.0001, "tavan x1,6 (\"biraz daha fazla\", garanti değil): %.2f" % w_ls)
	assert(is_equal_approx(w_luck, 1.0) and w_hp <= 1.0001, "abanılmayan stat ağırlığı 1: şans %.2f can %.2f" % [w_luck, w_hp])
	## Can çalma eşyası öne çıkar, ilgisiz eşya çıkmaz
	var ls_item: String = ""
	var other: String = ""
	for key: String in Items.KEYS:
		var axes: Array = Affinity.item_axes(key)
		if ls_item == "" and axes.has("lifesteal"):
			ls_item = key
		if other == "" and not axes.has("lifesteal") and str(Items.get_def(key).get("weapon_class", "")) == "" and not axes.is_empty():
			other = key
	assert(ls_item != "" and other != "", "eşya havuzu bekleneni içermiyor")
	assert(Affinity.offer_fit(prof, {"type": "item", "key": ls_item}) > 0.5, "can çalma eşyası uyumlu: %s" % ls_item)
	assert(is_zero_approx(Affinity.offer_fit(prof, {"type": "item", "key": other})), "ilgisiz eşya uyumsuz: %s" % other)
	p.free()
	_restore_state()


## Neredeyse her eşyada Saldırı Gücü var: yalnız düz saldırı eşyaları almak "abanma" sayılmamalı (beklenen paya bölünür).
func test_common_damage_items_do_not_skew_profile() -> void:
	_save_state()
	var p := FakePlayer.new()
	var n: int = 0
	for key: String in Items.KEYS:
		if Items.kademe(key) == 1 and Affinity.item_axes(key).size() >= 2 and Affinity.item_axes(key).has("damage"):
			GameManager.owned_items.append({"key": key})
			n += 1
		if n >= 6:
			break
	var prof: Dictionary = Affinity.profile(p)
	assert(float((prof["stat"] as Dictionary).get("damage", 0.0)) < 0.5, "karışık saldırılı eşyalar Saldırı Gücüne abanma değil: %s" % prof["stat"])
	p.free()
	_restore_state()


func test_weapon_family_and_main_weapon_upgrade() -> void:
	_save_state()
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("fire_staff", 1, 0), EnchantDefs.new_weapon_entry("buz_asasi", 1, 1)]
	var p := FakePlayer.new()
	var prof: Dictionary = Affinity.profile(p)
	var staff: float = Affinity.offer_fit(prof, {"type": "weapon", "key": "arcane"})
	var melee: float = Affinity.offer_fit(prof, {"type": "weapon", "key": "topuz"})
	var gun: float = Affinity.offer_fit(prof, {"type": "weapon", "key": "tabanca"})
	assert(staff > gun and gun > melee, "asa kurgusunda: asa > menzilli > yakın dövüş: %.2f %.2f %.2f" % [staff, gun, melee])
	assert(is_zero_approx(melee), "yakın dövüş silahı asacıya önerilmez: %.2f" % melee)
	## en çok hasar veren silahın geliştirmesi öne çıkar
	prof["weapon_share"] = {"fire_staff": 0.8, "buz_asasi": 0.2}
	var main: float = Affinity.offer_fit(prof, {"type": "wupgrade", "wkey": "fire_staff", "index": 0})
	var side: float = Affinity.offer_fit(prof, {"type": "wupgrade", "wkey": "buz_asasi", "index": 0})
	assert(main > 0.5 and is_zero_approx(side), "ana silah geliştirmesi uyumlu, yan silah değil: %.2f %.2f" % [main, side])
	p.free()
	_restore_state()


## Pazarda profil gerçekten dağılımı kaydırır ama çeşitlilik kalır (keşif yuvası + tavan).
func test_market_draws_shift_but_stay_varied() -> void:
	_save_state()
	var p := FakePlayer.new()
	for i in 10:
		p.upgrade_log.append(["crit_chance", 2])
	var crit_keys: Array = Items.KEYS.filter(func(k: String) -> bool: return Affinity.item_axes(k).has("crit_chance"))
	var biased: int = 0
	var neutral: int = 0
	var seen: Dictionary = {}
	for run in 300:
		for e: Dictionary in Market.roll_section(p, "items"):
			if str(e.get("type", "")) == "item":
				seen[str(e["key"])] = true
				if crit_keys.has(str(e["key"])):
					biased += 1
	var q := FakePlayer.new()
	for run in 300:
		for e: Dictionary in Market.roll_section(q, "items"):
			if str(e.get("type", "")) == "item" and crit_keys.has(str(e["key"])):
				neutral += 1
	assert(biased > neutral, "kritik kurgusunda kritik eşyası daha sık: %d vs %d" % [biased, neutral])
	assert(float(biased) < float(neutral) * 2.0, "artış ılımlı (garanti değil): %d vs %d" % [biased, neutral])
	assert(seen.size() > crit_keys.size() + 10, "profil havuzu daraltmaz, diğer eşyalar da çıkar: %d" % seen.size())
	p.free()
	q.free()
	_restore_state()
