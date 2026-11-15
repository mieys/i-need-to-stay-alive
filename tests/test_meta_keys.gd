extends Node

## HARİTA ANAHTARLARI (madde 605, plan docs/harita_icerik/PLAN.md Aşama 4): kayıt (keys bölümü), anahtarlı satın alma, K5/K10 bossu ödülü,
## debug / sonsuz koruması, görseller, Ruh Mağazası ANAHTARLAR bölümü. Hepsi GEÇİCİ dosyada (path_override) - gerçek user://meta.cfg'ye DOKUNMAZ.

const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const KeyIcon := preload("res://scripts/key_icon.gd")
const KeyIconBox := preload("res://scripts/key_icon_box.gd")
const SoulShopScript: GDScript = preload("res://scripts/soul_shop_screen.gd")
const MapProfiles := preload("res://scripts/map_profiles.gd")
const BossScene: PackedScene = preload("res://scenes/creatures/enemy_minotaur1.tscn")

var _tmp: String = ""
var _prev_map: String = ""


func _begin() -> void:
	_tmp = "user://test_keys_%d.cfg" % Time.get_ticks_usec()
	MetaProgressScript.set_path_override(_tmp)
	MetaProgressScript.set_unlock_all(false)
	_prev_map = str(GameManager.selected_map)
	GameManager.selected_map = "ana"
	_reset_run()


func _end() -> void:
	_reset_run()
	GameManager.selected_map = _prev_map
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	MetaProgressScript.set_path_override("")
	_tmp = ""


## Koşu durumu (GameManager.reset() çok şeye dokunur; yalnız anahtar alanları).
func _reset_run() -> void:
	GameManager.run_keys.clear()
	GameManager._key_tiers_given.clear()
	GameManager.run_debug_used = false
	GameManager.debug_mode_unlocked = false
	GameManager.run_debug_used = false


func _give_shards(n: int) -> void:
	var d: Dictionary = MetaProgressScript.load_all()
	d["shards"] = n
	MetaProgressScript.commit(d)


## --------------------------------------------------------------- kayıt
func test_old_save_without_keys_section_loads_with_zero_keys() -> void:
	_begin()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 321)
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("unlocked", "char", [3])
	cfg.save(_tmp)
	MetaProgressScript.set_path_override(_tmp) ## önbelleği boşalt
	assert(MetaProgressScript.shards() == 321 and MetaProgressScript.is_unlocked("char", 3), "eski kayıt aynen açılır")
	for id: String in MetaProgressScript.KEY_MAPS:
		assert(MetaProgressScript.keys(id) == 0, "bölümü olmayan eski kayıtta %s anahtarı 0" % id)
	_end()


func test_keys_are_saved_loaded_and_survive_other_saves() -> void:
	_begin()
	assert(MetaProgressScript.grant_keys("bataklik", 2) == 2 and MetaProgressScript.keys("bataklik") == 2)
	MetaProgressScript.grant_keys("bataklik", 1)
	MetaProgressScript.grant_keys("col", 1)
	MetaProgressScript.set_path_override(_tmp) ## önbelleği boşalt: gerçekten DOSYADAN okunsun
	assert(MetaProgressScript.keys("bataklik") == 3 and MetaProgressScript.keys("col") == 1, "dosyadan okundu")
	## TUZAK: başka bir kayıt (kıymık / satın alma) anahtarları silmemeli (_save yalnız bildiği bölümleri yazar)
	MetaProgressScript.grant_victory()
	_give_shards(500)
	assert(MetaProgressScript.buy("pet", "papagan"), "anahtarsız evcil kıymıkla alınır")
	MetaProgressScript.set_path_override(_tmp)
	assert(MetaProgressScript.keys("bataklik") == 3 and MetaProgressScript.keys("col") == 1, "başka kayıt anahtarları silmedi")
	_end()


func test_grant_keys_ignores_unknown_maps_and_non_positive_counts_and_caps() -> void:
	_begin()
	assert(MetaProgressScript.grant_keys("yok_boyle_harita", 3) == 0 and MetaProgressScript.keys("yok_boyle_harita") == 0, "bilinmeyen tür yazılmaz")
	assert(MetaProgressScript.grant_keys("ana", 0) == 0 and MetaProgressScript.grant_keys("ana", -4) == 0, "0 / negatif adet yok sayılır")
	MetaProgressScript.grant_keys("ana", MetaProgressScript.KEY_CAP + 50)
	assert(MetaProgressScript.keys("ana") == MetaProgressScript.KEY_CAP, "üst sınır")
	_end()


## --------------------------------------------------------------- anahtarlı satın alma
func test_key_cost_table_is_consistent() -> void:
	assert(KeyIcon.IDS == MetaProgressScript.KEY_MAPS, "görsel listesi = kayıt listesi")
	var seen: Dictionary = {}
	for kind: String in MetaProgressScript.KEY_COSTS.keys():
		for key in (MetaProgressScript.KEY_COSTS[kind] as Dictionary).keys():
			assert((MetaProgressScript.COSTS[kind] as Dictionary).has(key), "%s:%s anahtar istiyor ama kıymık fiyatı yok" % [kind, str(key)])
			var kc: Dictionary = MetaProgressScript.key_cost(kind, key)
			assert(MetaProgressScript.KEY_MAPS.has(str(kc["map"])) and int(kc["count"]) >= 1, "geçerli anahtar türü + adet: %s:%s" % [kind, str(key)])
			seen[str(kc["map"])] = int(seen.get(str(kc["map"]), 0)) + 1
	for id: String in MetaProgressScript.KEY_MAPS:
		assert(int(seen.get(id, 0)) == 2, "her anahtarı 1 karakter + 1 evcil ister: %s = %d" % [id, int(seen.get(id, 0))])
		assert(MapProfiles.is_selectable(id), "anahtar türü seçilebilir bir harita olmalı: " + id)


func test_matthew_assasin_elara_korsan_melek_pets_and_weapons_need_no_key() -> void:
	for id in [3, 5, 8, 9, 10]:
		assert(MetaProgressScript.key_cost("char", id).is_empty(), "karakter %d yalnız kıymıkla" % id)
	assert(MetaProgressScript.key_cost("pet", "papagan").is_empty(), "papağan yalnız kıymıkla")
	assert(MetaProgressScript.key_cost("weapon", "buz_asasi").is_empty() and MetaProgressScript.key_cost("spirit", "taktik").is_empty())
	assert(MetaProgressScript.key_cost("char", 1).is_empty(), "başlangıç öğesi anahtar istemez")


func test_key_item_needs_shards_and_keys_and_pays_both() -> void:
	_begin()
	_give_shards(450) ## Cadı (15) = 450 kıymık + 3 Bataklık Anahtarı
	assert(MetaProgressScript.key_cost("char", 15) == {"map": "bataklik", "count": 3})
	assert(not MetaProgressScript.can_buy("char", 15) and not MetaProgressScript.buy("char", 15), "kıymık yeter, anahtar yok: alınamaz")
	assert(MetaProgressScript.shards() == 450 and not MetaProgressScript.is_unlocked("char", 15), "reddedilen alımda kıymık yanmaz")
	MetaProgressScript.grant_keys("bataklik", 2)
	assert(not MetaProgressScript.buy("char", 15), "2 / 3 anahtar yetmez")
	MetaProgressScript.grant_keys("ana", 5) ## YANLIŞ tür anahtar yerine geçmez
	assert(not MetaProgressScript.buy("char", 15), "başka haritanın anahtarı sayılmaz")
	MetaProgressScript.grant_keys("bataklik", 1)
	_give_shards(449)
	assert(not MetaProgressScript.can_buy("char", 15), "anahtar yeter, kıymık 1 eksik: alınamaz")
	_give_shards(450)
	assert(MetaProgressScript.can_buy("char", 15) and MetaProgressScript.buy("char", 15), "ikisi de yeterli: alınır")
	assert(MetaProgressScript.shards() == 0 and MetaProgressScript.keys("bataklik") == 0, "kıymık VE anahtar birlikte düştü")
	assert(MetaProgressScript.keys("ana") == 5, "diğer anahtarlara dokunulmadı")
	assert(MetaProgressScript.is_unlocked("char", 15) and not MetaProgressScript.buy("char", 15), "açık olan tekrar alınmaz")
	MetaProgressScript.set_path_override(_tmp)
	assert(MetaProgressScript.is_unlocked("char", 15) and MetaProgressScript.keys("bataklik") == 0, "kayıttan da doğru")
	_end()


func test_pet_key_item_costs_one_key() -> void:
	_begin()
	_give_shards(180)
	assert(MetaProgressScript.key_cost("pet", "peri") == {"map": "ana", "count": 1})
	assert(not MetaProgressScript.buy("pet", "peri"), "anahtarsız Peri alınamaz")
	MetaProgressScript.grant_keys("ana", 1)
	assert(MetaProgressScript.buy("pet", "peri") and MetaProgressScript.keys("ana") == 0 and MetaProgressScript.shards() == 0, "1 anahtar + 180 kıymık")
	_end()


func test_already_unlocked_items_stay_open_without_keys() -> void:
	_begin()
	var d: Dictionary = MetaProgressScript.load_all()
	((d["unlocked"] as Dictionary)["char"] as Array).append(12)
	((d["unlocked"] as Dictionary)["pet"] as Array).append("kirpi")
	MetaProgressScript.commit(d)
	assert(MetaProgressScript.is_unlocked("char", 12) and MetaProgressScript.is_unlocked("pet", "kirpi"), "eskiden açılmış olan açık kalır")
	assert(MetaProgressScript.keys("ana") == 0 and MetaProgressScript.keys("col") == 0)
	_end()


func test_debug_open_ignores_keys_for_unlock() -> void:
	_begin()
	MetaProgressScript.set_debug_open(true)
	assert(MetaProgressScript.is_unlocked("char", 11) and MetaProgressScript.is_unlocked("pet", "hayalet"), "debug: her şey açık")
	MetaProgressScript.set_debug_open(false)
	assert(not MetaProgressScript.is_unlocked("char", 11))
	_end()


func test_lock_text_names_the_key_only_when_one_is_needed() -> void:
	var plain: String = MetaProgressScript.lock_text("char", 3)
	assert(plain.contains("250") and not plain.contains("Anahtar"), "anahtarsız: eski metin: " + plain)
	var keyed: String = MetaProgressScript.lock_text("char", 15)
	assert(keyed.contains("450") and keyed.contains("3 Bataklık Anahtarı"), "anahtarlı: " + keyed)
	assert(MetaProgressScript.lock_text("pet", "hayalet").contains("1 Nekropol Anahtarı"), "evcil: " + MetaProgressScript.lock_text("pet", "hayalet"))


func test_locked_items_carry_key_fields() -> void:
	var with_key: int = 0
	for it: Dictionary in MetaProgressScript.locked_items():
		assert(it.has("key_map") and it.has("key_count"), "her satır anahtar alanı taşır")
		if str(it["key_map"]) != "":
			with_key += 1
			assert(int(it["key_count"]) >= 1)
	assert(with_key == 10, "5 karakter + 5 evcil anahtar istiyor: %d" % with_key)


## --------------------------------------------------------------- görseller
func test_every_key_has_a_32px_texture_and_name() -> void:
	for id: String in KeyIcon.IDS:
		var t: Texture2D = KeyIcon.texture(id)
		assert(t != null, "%s anahtarının dokusu yüklenmedi (assets/ui/anahtar/%s.png)" % [id, id])
		assert(t.get_size() == Vector2(32, 32), "%s: 32x32 olmalı" % id)
		assert(KeyIcon.display_name(id).ends_with("Anahtarı"), "ad: " + KeyIcon.display_name(id))
		assert(KeyIcon.map_name(id) != "", "harita adı")
	assert(KeyIcon.texture("yok") == null and KeyIcon.side_for(24.0) == 32.0 and KeyIcon.side_for(70.0) == 64.0, "tam katlar")
	var box: Control = KeyIconBox.new(44.0, "ana")
	assert(box.custom_minimum_size == Vector2(32, 32), "kutu tam kat")
	box.free()


## --------------------------------------------------------------- koşu ödülü
func test_boss_keys_k5_gives_1_and_k10_gives_2_once_per_tier() -> void:
	_begin()
	GameManager.award_boss_keys(4)
	GameManager.award_boss_keys(11) ## sonsuz mod boss dalgası kademeleri (> LAST_TIER) vermez
	assert(MetaProgressScript.keys("ana") == 0 and GameManager.run_keys.is_empty(), "K5 / K10 dışı boss anahtar vermez")
	GameManager.award_boss_keys(5)
	assert(MetaProgressScript.keys("ana") == 1 and int(GameManager.run_keys.get("ana", 0)) == 1, "K5 bossu = 1")
	GameManager.award_boss_keys(5)
	assert(MetaProgressScript.keys("ana") == 1, "aynı kademede ikinci kez verilmez")
	GameManager.award_boss_keys(10)
	assert(MetaProgressScript.keys("ana") == 3 and int(GameManager.run_keys.get("ana", 0)) == 3, "K10 bossu = 2 daha")
	_end()


func test_boss_keys_go_to_the_current_maps_key() -> void:
	_begin()
	GameManager.selected_map = "col"
	GameManager.award_boss_keys(5)
	assert(MetaProgressScript.keys("col") == 1 and MetaProgressScript.keys("ana") == 0, "anahtar türü = oynanan harita")
	_end()


func test_debug_run_gives_no_keys_even_if_debug_is_closed_again() -> void:
	_begin()
	GameManager.debug_mode_unlocked = true
	GameManager.award_boss_keys(5)
	assert(MetaProgressScript.keys("ana") == 0, "debug açıkken anahtar yok")
	GameManager.debug_mode_unlocked = false ## kapatılsa da koşu işaretli
	GameManager.award_boss_keys(10)
	assert(MetaProgressScript.keys("ana") == 0 and GameManager.run_debug_used, "koşuda bir kez açıldıysa anahtar yok")
	_end()


func test_receiver_refuses_when_its_own_debug_is_on_or_input_is_bad() -> void:
	_begin()
	GameManager.grant_boss_keys("yok", 2)
	GameManager.grant_boss_keys("ana", 0)
	assert(MetaProgressScript.keys("ana") == 0, "bilinmeyen tür / 0 adet yok sayılır")
	GameManager.run_debug_used = true ## başka biri debug açtı (NetworkManager.broadcast_debug_action)
	GameManager.grant_boss_keys("ana", 2)
	assert(MetaProgressScript.keys("ana") == 0, "debug işaretli koşu alıcıda da vermez")
	_end()


func test_keys_granted_signal_fires_for_the_notice() -> void:
	_begin()
	var got: Array = []
	var cb := func(map_id: String, n: int) -> void: got.append([map_id, n])
	GameManager.keys_granted.connect(cb)
	GameManager.award_boss_keys(5)
	GameManager.keys_granted.disconnect(cb)
	assert(got == [["ana", 1]], "bildirim sinyali: " + str(got))
	_end()


func test_a_boss_dying_at_tier_5_awards_the_key() -> void:
	_begin()
	var b: Node = BossScene.instantiate()
	add_child(b)
	await get_tree().process_frame
	b.apply_boss_stats(1000.0, 10.0, 1.0, 5)
	assert(b.is_boss and b._current_tier == 5)
	b.die()
	assert(MetaProgressScript.keys("ana") == 1, "boss ölümü (enemy.gd die) K5 anahtarını verdi")
	b.die() ## çift die() güvenli
	assert(MetaProgressScript.keys("ana") == 1)
	if is_instance_valid(b):
		b.queue_free()
	_end()


func test_a_sub_boss_enemy_death_gives_no_key() -> void:
	_begin()
	var e: Node = BossScene.instantiate() ## boss sahnesi ama apply_boss_stats çağrılmadı = sıradan yaratık sayılır
	add_child(e)
	await get_tree().process_frame
	assert(not e.is_boss)
	e.die()
	assert(MetaProgressScript.keys("ana") == 0, "boss olmayan ölüm anahtar vermez")
	if is_instance_valid(e):
		e.queue_free()
	_end()


## --------------------------------------------------------------- Ruh Mağazası
func test_soul_shop_has_a_keys_section_and_shows_key_prices() -> void:
	_begin()
	_give_shards(1000)
	MetaProgressScript.grant_keys("bataklik", 1) ## Cadı için 3 gerek: 1 / 3
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	await get_tree().process_frame
	assert("keys" in SoulShopScript.SECTIONS, "ANAHTARLAR bölümü sol listede")
	var items: Array = shop.call("_items")
	var witch: Dictionary = {}
	var peri: Dictionary = {}
	var plain: Dictionary = {}
	for it: Dictionary in items:
		if it["kind"] == "char" and int(it["key"]) == 15:
			witch = it
		if it["kind"] == "pet" and str(it["key"]) == "peri":
			peri = it
		if it["kind"] == "char" and int(it["key"]) == 3:
			plain = it
	assert(str(witch["key_map"]) == "bataklik" and int(witch["key_count"]) == 3 and int(witch["key_have"]) == 1, "Cadı satırı anahtar alanları")
	assert(not witch["can"] and not witch["open"], "1000 kıymık var ama anahtar eksik: alınamaz grubunda")
	assert(str(plain["key_map"]) == "" and plain["can"], "anahtarsız karakter yalnız kıymıkla alınabilir")
	assert(not peri["can"], "Peri anahtarsız alınamaz")
	## fiyat satırında anahtar simgesi + x3 var, anahtarsızda yok
	var price: Control = shop.call("_price", witch)
	assert(price.find_children("*", "Control", true, false).any(func(c: Node) -> bool: return c is KeyIconBox), "fiyatta anahtar simgesi")
	var price_plain: Control = shop.call("_price", plain)
	assert(not price_plain.find_children("*", "Control", true, false).any(func(c: Node) -> bool: return c is KeyIconBox), "anahtarsız fiyatta simge yok")
	price.free()
	price_plain.free()
	## ANAHTARLAR sayfası kurulur, 5 satır + ayrıntı
	shop.call("_on_tab_pressed", "keys")
	await get_tree().process_frame
	var rows: int = 0
	for b: Node in shop.find_children("*", "Button", true, false):
		if b.has_meta("sid") and str(b.get_meta("sid")).begins_with("row:key:"):
			rows += 1
	assert(rows == 5, "5 anahtar satırı: %d" % rows)
	shop.call("_select_key", "bataklik")
	await get_tree().process_frame
	assert(shop.call("_key_selected") == "bataklik" and shop.call("_keys_total") == 1)
	var unlocks: Array = shop.call("_key_unlocks", "bataklik")
	assert(unlocks.size() == 2 and int(unlocks[0]["count"]) == 3 and int(unlocks[1]["count"]) == 1, "Bataklık: Cadı (3) + Minik Cadı (1)")
	shop.queue_free()
	_end()


func test_soul_shop_buys_a_keyed_item_only_with_keys() -> void:
	_begin()
	_give_shards(180)
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	await get_tree().process_frame
	shop.call("_on_buy_pressed", "pet", "peri") ## 1. basış: ONAYLA? (alınamaz: anahtar yok -> düğme zaten pasif, doğrudan çağrı yine reddedilir)
	shop.call("_on_buy_pressed", "pet", "peri")
	assert(not MetaProgressScript.is_unlocked("pet", "peri") and MetaProgressScript.shards() == 180, "anahtarsız alım olmadı, kıymık yanmadı")
	MetaProgressScript.grant_keys("ana", 1)
	shop.call("_on_buy_pressed", "pet", "peri")
	shop.call("_on_buy_pressed", "pet", "peri")
	assert(MetaProgressScript.is_unlocked("pet", "peri") and MetaProgressScript.shards() == 0 and MetaProgressScript.keys("ana") == 0, "anahtarla alındı")
	shop.queue_free()
	_end()


func test_game_over_and_victory_lines_show_the_run_keys() -> void:
	_begin()
	GameManager.award_boss_keys(5)
	GameManager.award_boss_keys(10)
	var box: Control = preload("res://scripts/run_summary_ui.gd").extras_box({}, {})
	assert(box != null, "yalnız anahtar kazanıldıysa da kazanım kutusu çıkar")
	var texts: Array = []
	for l: Node in box.get_children():
		texts.append((l as Label).text)
	assert(texts.size() == 1 and texts[0] == "+3 Orman Anahtarı", "zafer penceresi satırı: " + str(texts))
	box.free()
	var board: Control = preload("res://scripts/game_over_board.gd").new()
	add_child(board)
	var lines: Array = board.call("_reward_lines")
	var found: bool = false
	for ln: Array in lines:
		if str(ln[0]) == "key:ana" and str(ln[1]) == "+3 Orman Anahtarı":
			found = true
	assert(found, "oyun bitti kazanımlar satırı: " + str(lines))
	board.queue_free()
	_end()
