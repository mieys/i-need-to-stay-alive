extends Node

## Kalıcı ilerleme: Ruh Kıymığı + kilitler (scripts/meta_progress.gd, soul_shop_screen.gd, lock_badge.gd; kullanıcı isteği 2026-10-13).
## Hepsi GEÇİCİ bir dosyada (path_override) - kullanıcının gerçek user://meta.cfg'sine DOKUNMAZ.

const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SoulShopScript: GDScript = preload("res://scripts/soul_shop_screen.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

var _tmp: String = ""


func _begin() -> void:
	_tmp = "user://test_meta_%d.cfg" % Time.get_ticks_usec()
	MetaProgressScript.set_path_override(_tmp)
	MetaProgressScript.set_unlock_all(false)


func _end() -> void:
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	MetaProgressScript.set_path_override("")
	_tmp = ""


func _run(time: float, tier: int, layer: int = 0) -> Dictionary:
	return {"time": time, "tier": tier, "layer": layer}


func test_fresh_player_has_only_starters() -> void:
	_begin()
	assert(MetaProgressScript.shards() == 0, "yeni oyuncu: bakiye 0")
	for id in [1, 2, 4, 7]:
		assert(MetaProgressScript.is_unlocked("char", id), "başlangıç karakteri %d açık olmalı" % id)
	for id in [3, 5, 8, 9, 10, 11, 12, 13, 14, 15]:
		assert(not MetaProgressScript.is_unlocked("char", id), "karakter %d kilitli başlamalı" % id)
	assert(MetaProgressScript.is_unlocked("weapon", "dagger") and not MetaProgressScript.is_unlocked("weapon", "buz_asasi"))
	assert(MetaProgressScript.is_unlocked("pet", "kopek") and not MetaProgressScript.is_unlocked("pet", "peri"))
	assert(MetaProgressScript.is_unlocked("spirit", "para") and not MetaProgressScript.is_unlocked("spirit", "kalkan_bagi"))
	_end()


func test_catalog_covers_every_real_item() -> void:
	## Kilit tablosu gerçek içerikle uyumlu olmalı: kilitli ya da başlangıç, ikisinden BİRİ (hiçbiri değil = unutulmuş yeni içerik).
	_begin()
	for id: int in Characters.DEFS.keys():
		var starter: bool = MetaProgressScript.is_starter("char", id)
		var priced: bool = MetaProgressScript.cost("char", id) > 0
		assert(starter != priced, "karakter %d: başlangıç XOR fiyatlı olmalı" % id)
	for key: String in WeaponCatalog.KEYS:
		assert(MetaProgressScript.is_starter("weapon", key) != (MetaProgressScript.cost("weapon", key) > 0), "silah %s" % key)
	for key: String in PetCatalog.KEYS:
		assert(MetaProgressScript.is_starter("pet", key) != (MetaProgressScript.cost("pet", key) > 0), "evcil %s" % key)
	for key: String in SpiritualSkillsScript.ORDER:
		assert(MetaProgressScript.is_starter("spirit", key) != (MetaProgressScript.cost("spirit", key) > 0), "ruhani %s" % key)
	_end()


func test_run_payout_formula() -> void:
	_begin()
	assert(MetaProgressScript.shards_for_run(_run(20.0, 3)) == 0, "30 sn altı koşu puan vermez")
	## kademe puanı 5-6-7-8-9: kademe 5'e kadar 35
	assert(MetaProgressScript.tier_shards(1) == 5 and MetaProgressScript.tier_shards(2) == 11 and MetaProgressScript.tier_shards(5) == 35)
	## 16 dk, kademe 5: 35 + 16*2 = 67
	assert(MetaProgressScript.shards_for_run(_run(16.0 * 60.0 + 10.0, 5)) == 67, "67 bekleniyordu: %d" % MetaProgressScript.shards_for_run(_run(970.0, 5)))
	## sonsuz kat: +10/kat (kademe 16 = 5..20 toplamı 200)
	assert(MetaProgressScript.shards_for_run(_run(600.0, 16, 3)) == 200 + 10 * 2 + 30)
	_end()


func test_bank_is_incremental_and_idempotent() -> void:
	## Düşen oyuncu puanı kaybetmesin: her çağrıda sadece FARK yazılır, aynı özeti tekrar bankalamak çift saymaz.
	_begin()
	var banked: int = MetaProgressScript.bank_run(_run(120.0, 2), 0) ## (5+6) + 2*2 = 15
	assert(banked == 15 and MetaProgressScript.shards() == 15, "ilk banka: %d / %d" % [banked, MetaProgressScript.shards()])
	assert(MetaProgressScript.bank_run(_run(120.0, 2), banked) == 15 and MetaProgressScript.shards() == 15, "aynı özet çift saymaz")
	banked = MetaProgressScript.bank_run(_run(300.0, 4), banked) ## (5+6+7+8) + 5*2 = 36 -> fark 21
	assert(banked == 36 and MetaProgressScript.shards() == 36, "fark eklenir: %d" % MetaProgressScript.shards())
	assert(MetaProgressScript.bank_run(_run(100.0, 1), banked) == 36 and MetaProgressScript.shards() == 36, "geriye giden özet puan düşürmez")
	_end()


func test_bank_survives_reload_like_a_crash() -> void:
	## "Çökme": bellekteki önbellek atılıp dosyadan yeniden okunur - puan diskte olmalı.
	_begin()
	MetaProgressScript.bank_run(_run(600.0, 5), 0)
	var expected: int = MetaProgressScript.shards()
	MetaProgressScript.set_path_override(_tmp) ## önbelleği temizler
	assert(MetaProgressScript.shards() == expected and expected > 0, "diskten okunan bakiye aynı olmalı")
	_end()


func test_buy_spends_and_unlocks() -> void:
	_begin()
	assert(not MetaProgressScript.buy("char", 3), "bakiyesiz satın alma reddedilmeli")
	MetaProgressScript.grant_victory() ## 150
	MetaProgressScript.grant_achievements(4) ## +100 = 250
	assert(MetaProgressScript.shards() == 250)
	assert(MetaProgressScript.can_buy("char", 3) and MetaProgressScript.cost("char", 3) == 250)
	assert(MetaProgressScript.buy("char", 3), "250 kıymıkla 250'lik karakter alınmalı")
	assert(MetaProgressScript.shards() == 0 and MetaProgressScript.is_unlocked("char", 3), "bakiye düştü, karakter açıldı")
	assert(not MetaProgressScript.buy("char", 3), "açık olan tekrar alınamaz (para yanmaz)")
	assert(not MetaProgressScript.buy("char", 1), "başlangıç öğesi satın alınamaz")
	## Açılan şey yeniden yüklemede de açık kalır.
	MetaProgressScript.set_path_override(_tmp)
	assert(MetaProgressScript.is_unlocked("char", 3))
	_end()


func test_unlock_all_override_opens_everything_without_saving() -> void:
	_begin()
	MetaProgressScript.set_unlock_all(true)
	assert(MetaProgressScript.is_unlocked("char", 15) and MetaProgressScript.is_unlocked("weapon", "fisek"))
	MetaProgressScript.set_unlock_all(false)
	assert(not MetaProgressScript.is_unlocked("char", 15), "geliştirici kısayolu kayda yazılmaz")
	_end()


func test_debug_mode_opens_everything_via_game_manager_flag() -> void:
	_begin()
	var gm: Node = Engine.get_main_loop().root.get_node("GameManager")
	gm.debug_mode_unlocked = true
	assert(MetaProgressScript.is_unlocked("char", 15) and MetaProgressScript.is_unlocked("pet", "peri"), "debug modunda kilitler açık")
	assert(Characters.skill_unlock_level(1, "skill3") == 1, "debug modunda R baştan açık")
	gm.debug_mode_unlocked = false
	assert(not MetaProgressScript.is_unlocked("char", 15), "debug kapanınca kilitler geri gelir")
	assert(Characters.skill_unlock_level(1, "skill3") == 10)
	_end()


func test_corrupt_file_does_not_crash() -> void:
	_begin()
	var cfg := ConfigFile.new()
	cfg.set_value("unlocked", "char", "bozuk")
	cfg.set_value("meta", "shards", -50)
	cfg.save(_tmp)
	MetaProgressScript.set_path_override(_tmp)
	assert(MetaProgressScript.shards() == 0, "negatif bakiye 0'a çekilir")
	assert(not MetaProgressScript.is_unlocked("char", 3))
	_end()


func test_locked_items_listing_is_sorted_by_cost() -> void:
	var items: Array = MetaProgressScript.locked_items()
	## silah sayısı katalogla büyür (Gökkuşağı/Mızrak 2026-10-19) - kilitli silah adedi COSTS tablosundan
	assert(items.size() == 10 + (MetaProgressScript.COSTS[MetaProgressScript.WEAPON] as Dictionary).size() + 4 + 4, "kilitli toplam: %d" % items.size())
	var last_by_kind: Dictionary = {}
	for it: Dictionary in items:
		var k: String = str(it["kind"])
		assert(int(it["cost"]) >= int(last_by_kind.get(k, 0)), "her tür ucuzdan pahalıya sıralı olmalı")
		last_by_kind[k] = int(it["cost"])


func test_soul_shop_builds_and_buys_with_confirmation() -> void:
	_begin()
	MetaProgressScript.grant_victory() ## 150
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	assert(shop.get_child_count() > 0, "ekran kuruldu")
	## Onay iki adımlı: ilk basış sadece "ONAYLA?" yapar, para harcamaz.
	shop.call("_on_buy_pressed", "pet", "papagan")
	assert(MetaProgressScript.shards() == 150 and not MetaProgressScript.is_unlocked("pet", "papagan"), "ilk basış satın almaz")
	shop.call("_on_buy_pressed", "pet", "papagan")
	assert(MetaProgressScript.is_unlocked("pet", "papagan") and MetaProgressScript.shards() == 150 - 120, "ikinci basış alır")
	shop.queue_free()
	_end()


func test_locked_weapon_is_coerced_to_default() -> void:
	_begin()
	var picker: PanelContainer = preload("res://scripts/menu_weapon_picker.gd").new()
	add_child(picker)
	picker.setup(false)
	picker.select("buz_asasi", false)
	assert(GameManager.selected_start_weapon == WeaponCatalog.DEFAULT_KEY, "kilitli silah seçilemez: %s" % GameManager.selected_start_weapon)
	picker.select("tabanca", false)
	assert(GameManager.selected_start_weapon == "tabanca", "açık silah seçilir")
	picker.queue_free()
	GameManager.selected_start_weapon = ""
	_end()


func test_starter_gift_is_granted_once() -> void:
	_begin()
	MetaProgressScript.set_starter_shards_override(1000)
	assert(MetaProgressScript.shards() == 1000, "yeni kayıt 1000 ile başlar")
	assert(int(MetaProgressScript.load_all()["total_earned"]) == 0, "hediye kazanılmış puana yazılmaz")
	MetaProgressScript.set_path_override(_tmp) ## önbelleği at, diskten oku
	assert(MetaProgressScript.shards() == 1000, "ikinci yüklemede tekrar verilmez")
	MetaProgressScript.set_starter_shards_override(-1)
	_end()
