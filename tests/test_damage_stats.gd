extends Node

## Silah / yetenek hasar istatistiği (scripts/damage_stats.gd): balans sayaçlarından silah satırları, slot toplamları, yetenek
## satırları, can/kalkan sayacı, Shift ipucu metni ve oyun sonu tablosunun yeni bölümü.

const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const DamageStats: GDScript = preload("res://scripts/damage_stats.gd")
const BoardScript: GDScript = preload("res://scripts/game_over_board.gd")


func _begin() -> void:
	BalanceLogScript.reset()


func _end() -> void:
	BalanceLogScript.reset()


func test_weapon_rows_sorted_and_share() -> void:
	_begin()
	BalanceLogScript.on_hit("w:yay", 100.0, false)
	BalanceLogScript.on_hit("w:yay", 300.0, true)
	BalanceLogScript.on_hit("w:tabanca", 200.0, false)
	BalanceLogScript.on_hit("s:talon_dash", 400.0, false)
	var rows: Array = DamageStats.weapon_rows()
	assert(rows.size() == 2, "yalnız w: kaynakları silah satırı olmalı")
	assert(rows[0]["key"] == "yay" and absf(float(rows[0]["dmg"]) - 400.0) < 0.01, "çoktan aza sıralı")
	assert(int(rows[0]["crit"]) == 1 and int(rows[0]["hits"]) == 2)
	assert(absf(float(rows[0]["share"]) - 0.4) < 0.001, "pay = silah / TÜM hasar (1000)")
	_end()


func test_weapon_damage_lookup() -> void:
	_begin()
	assert(float(DamageStats.weapon_damage("yay")["dmg"]) == 0.0, "vurmayan silah 0")
	BalanceLogScript.on_hit("w:yay", 50.0, false)
	assert(absf(float(DamageStats.weapon_damage("yay")["dmg"]) - 50.0) < 0.01)
	_end()


func test_slot_totals_group_sources_and_exclude_weapons() -> void:
	_begin()
	BalanceLogScript.on_hit("s:buyucu_kasirga", 100.0, false)
	BalanceLogScript.on_hit("s:buyucu_sekme", 50.0, true)
	BalanceLogScript.on_hit("s:buyucu_meteor", 900.0, false)
	BalanceLogScript.on_hit("w:arcane", 5000.0, false)
	var e: Dictionary = DamageStats.slot_totals("e")
	assert(absf(float(e["dmg"]) - 150.0) < 0.01 and int(e["hits"]) == 2 and int(e["crit"]) == 1)
	assert((e["parts"] as Array).size() == 2 and (e["parts"] as Array)[0]["name"] == "Hortum", "büyük kaynak üstte")
	var r: Dictionary = DamageStats.slot_totals("r")
	assert(absf(float(r["dmg"]) - 900.0) < 0.01)
	var other: Dictionary = DamageStats.slot_totals("diger")
	assert(float(other["dmg"]) == 0.0, "silah hasarı 'diğer'e girmez")
	_end()


func test_unknown_tags_fall_to_other() -> void:
	_begin()
	BalanceLogScript.on_hit("dot:yanma", 10.0, false)
	BalanceLogScript.on_hit("s:evo_x", 20.0, false)
	BalanceLogScript.on_hit("s:bilinmeyen_yetenek", 30.0, false)
	BalanceLogScript.on_hit("", 40.0, false) ## etiketsiz -> "diger"
	assert(absf(float(DamageStats.slot_totals("diger")["dmg"]) - 100.0) < 0.01)
	assert(DamageStats.slot_of("dot:ari_zehri") == "q", "arı zehri Oakley Q")
	_end()


func test_gain_counted_per_source_and_ignores_unsourced() -> void:
	_begin()
	BalanceLogScript.on_gain("s:melek_can", 40.0, 0.0)
	BalanceLogScript.on_gain("s:melek_can", 10.0, 0.0)
	BalanceLogScript.on_gain("s:melek_kalkan", 0.0, 25.0)
	BalanceLogScript.on_gain("", 99.0, 99.0) ## kaynaksız kaydedilmez
	BalanceLogScript.on_gain("s:melek_can", 0.0, 0.0)
	var q: Dictionary = DamageStats.slot_totals("q")
	assert(absf(float(q["heal"]) - 50.0) < 0.01 and float(q["shield"]) == 0.0)
	var e: Dictionary = DamageStats.slot_totals("e")
	assert(absf(float(e["shield"]) - 25.0) < 0.01)
	assert(BalanceLogScript.gain_snapshot().size() == 2)
	_end()


func test_skill_rows_use_character_skill_names_and_skip_empty_slots() -> void:
	_begin()
	BalanceLogScript.on_hit("s:talon_dash", 700.0, false)
	BalanceLogScript.on_hit("s:talon_spin", 300.0, false)
	var rows: Array = DamageStats.skill_rows(0) ## Talon
	var def: Dictionary = Characters.get_def(0)
	assert(rows.size() == 2, "yalnız bir şey yapmış slotlar (Q, E)")
	assert(rows[0]["label"] == "Q" and rows[0]["name"] == str(def.get("skill_name", "")), "Q satırı karakterin Q adıyla")
	assert(rows[1]["label"] == "E" and rows[1]["name"] == str(def.get("skill2_name", "")))
	assert(absf(float(rows[0]["share"]) - 0.7) < 0.001)
	_end()


func test_reset_clears_gain_and_damage() -> void:
	BalanceLogScript.on_hit("w:yay", 5.0, false)
	BalanceLogScript.on_gain("s:melek_can", 5.0, 5.0)
	BalanceLogScript.reset()
	assert(DamageStats.weapon_rows().is_empty() and BalanceLogScript.gain_snapshot().is_empty())


func test_tooltip_text_shows_damage_heal_shield_or_empty_note() -> void:
	_begin()
	var ink: Dictionary = UIKit.INK
	assert(DamageStats.tooltip_bbcode("q", ink).contains("henüz"), "hiçbir şey yapmadıysa not")
	BalanceLogScript.on_hit("s:talon_dash", 1234.0, true)
	BalanceLogScript.on_gain("s:talon_dash", 0.0, 77.0)
	var t: String = DamageStats.tooltip_bbcode("q", ink)
	assert(t.contains("Hasar") and t.contains("1.234") and t.contains("Kalkan") and t.contains("77"), t)
	assert(not t.contains("Can:"), "can yoksa can satırı yok")
	_end()


func test_pet_totals_per_pet_and_dog_not_in_matthew_r() -> void:
	_begin()
	var ink: Dictionary = UIKit.INK
	assert(DamageStats.pet_tooltip_bbcode("kirpi", ink).contains("henüz"), "hiçbir şey yapmadıysa not")
	BalanceLogScript.on_hit("s:matthew_kopek", 500.0, false)
	BalanceLogScript.on_hit("s:matthew_kopek", 250.0, true)
	BalanceLogScript.on_hit("s:evcil_kirpi", 40.0, false)
	BalanceLogScript.on_prevented("s:evcil_kirpi", 12.0)
	BalanceLogScript.on_gain("s:evcil_peri", 90.0, 0.0)
	BalanceLogScript.on_pet_drop()
	BalanceLogScript.on_pet_drop()
	var dog: Dictionary = DamageStats.pet_totals("kopek")
	assert(is_equal_approx(float(dog["dmg"]), 750.0) and int(dog["hits"]) == 2, str(dog))
	assert(float(DamageStats.slot_totals("r")["dmg"]) == 0.0, "evcil köpek Matthew R'ye sayılmamalı")
	var k: String = DamageStats.pet_tooltip_bbcode("kirpi", ink)
	assert(k.contains("Hasar") and k.contains("40") and k.contains("Engellenen") and k.contains("12"), k)
	var p: String = DamageStats.pet_tooltip_bbcode("peri", ink)
	assert(p.contains("İyileştirme") and p.contains("90") and not p.contains("Hasar"), p)
	assert(DamageStats.pet_tooltip_bbcode("papagan", ink).contains("düşürülen eşya: [color=%s][b]2" % str(ink.get("value", "#9a6a10"))), "papağan eşya sayısı")
	assert(DamageStats.pet_tooltip_bbcode("kelebek", ink).contains("henüz"), "kelebek bir şey yapmadı")
	BalanceLogScript.reset()
	assert(BalanceLogScript.prevented_snapshot().is_empty() and BalanceLogScript.pet_drops() == 0, "reset evcil sayaçlarını da silmeli")
	_end()


func test_pet_slot_tooltip_shows_live_stats() -> void:
	_begin()
	var host := Control.new()
	add_child(host)
	var slot: Control = (load("res://scripts/hud_pet_slot.gd") as GDScript).new()
	slot.size = Vector2(36, 36)
	slot.position = Vector2(400, 600)
	host.add_child(slot)
	slot.call("set_pet", "kirpi")
	assert(slot.tooltip_text == "", "motorun düz ipucu kapalı olmalı (kendi levhası)")
	slot.call("_open_tooltip")
	var tip: Control = slot.get("tooltip_panel") as Control
	assert(tip != null and tip.get_parent() == host, "ipucu levhası HUD katmanına eklenmeli")
	var lbl: RichTextLabel = slot.get("_stats_label") as RichTextLabel
	assert(lbl.text.contains("BU OYUNDA") and lbl.text.contains("henüz"), lbl.text)
	BalanceLogScript.on_prevented("s:evcil_kirpi", 33.0)
	slot.call("_process", 1.0)
	assert(lbl.text.contains("Engellenen") and lbl.text.contains("33"), "açıkken canlı yenilenmeli: " + lbl.text)
	slot.call("_close_tooltip")
	assert(slot.get("tooltip_panel") == null)
	host.queue_free()
	_end()


## Madde 287: hasar dışı fayda - engellenen hasar, dosttan üstlenilen hasar, kontrol sayısı, etki penceresi, sayılar.
func test_utility_metrics_in_slot_and_tooltip() -> void:
	_begin()
	var ink: Dictionary = UIKit.INK
	BalanceLogScript.on_prevented("s:sovalye_pasif", 120.0)
	BalanceLogScript.on_util("s:sovalye_bariyer", "ally", 300.0)
	BalanceLogScript.on_prevented("s:sovalye_kubbe", 950.0)
	BalanceLogScript.on_gain("s:sovalye_kiskirtma", 0.0, 40.0)
	assert(absf(float(DamageStats.slot_totals("p")["prevented"]) - 120.0) < 0.01, "Şovalye pasifi P slotunda")
	assert(absf(float((DamageStats.slot_totals("e")["util"] as Dictionary).get("ally", 0.0)) - 300.0) < 0.01, "Şovalye E dosttan üstlenilen")
	var te: String = DamageStats.tooltip_bbcode("e", ink)
	assert(te.contains("Dostlardan üstlenilen hasar") and te.contains("300"), te)
	var tr: String = DamageStats.tooltip_bbcode("r", ink)
	assert(tr.contains("Engellenen hasar") and tr.contains("950"), tr)
	assert(DamageStats.tooltip_bbcode("q", ink).contains("40"), "Şovalye Q temel yenilemesi kalkan sayılır")
	_end()


func test_cc_counted_once_per_application_and_not_on_boss() -> void:
	_begin()
	var e := Node2D.new()
	e.set_meta("x", 1)
	add_child(e)
	BalanceLogScript.on_cc("s:oakley_sarmasik", "root", e, 4.0)
	BalanceLogScript.on_cc("s:oakley_sarmasik", "root", e, 4.0) ## süre dolmadan tazeleme: sayılmaz
	var util: Dictionary = DamageStats.slot_totals("e")["util"]
	assert(int(util.get("root", 0.0)) == 1, "aynı yaratığa tazeleme bir kez: %s" % str(util))
	var boss_script := GDScript.new()
	boss_script.source_code = "extends Node2D\nvar is_boss: bool = true\n"
	boss_script.reload()
	var boss := Node2D.new()
	boss.set_script(boss_script)
	add_child(boss)
	assert(boss.get("is_boss") == true)
	BalanceLogScript.on_cc("s:melek_korku", "fear", boss, 5.0)
	assert(not (DamageStats.slot_totals("r")["util"] as Dictionary).has("fear"), "boss korkmaz -> sayılmaz")
	BalanceLogScript.on_cc("s:melek_korku", "slow", boss, 5.0)
	assert(int((DamageStats.slot_totals("r")["util"] as Dictionary).get("slow", 0.0)) == 1, "boss yavaşlaması sayılır")
	assert(DamageStats.tooltip_bbcode("e", UIKit.INK).contains("Sabitlenen yaratık"))
	e.queue_free()
	boss.queue_free()
	_end()


func test_buff_window_counts_weapon_damage_only_while_open() -> void:
	_begin()
	BalanceLogScript.on_hit("w:yay", 100.0, false) ## pencere kapalı
	BalanceLogScript.set_window("s:elara_gercek_hasar", true, true)
	BalanceLogScript.on_hit("w:yay", 250.0, false)
	BalanceLogScript.on_hit("s:talon_dash", 999.0, false) ## silah değil: sadece-silah penceresine girmez
	BalanceLogScript.set_window("s:elara_gercek_hasar", false, true)
	BalanceLogScript.on_hit("w:yay", 70.0, false)
	var util: Dictionary = DamageStats.slot_totals("e")["util"]
	assert(absf(float(util.get("during_w", 0.0)) - 250.0) < 0.01, "pencere açıkken silah hasarı: %s" % str(util))
	BalanceLogScript.set_window("s:assasin_pasif", true, false)
	BalanceLogScript.on_hit("s:assasin_dash2", 40.0, true)
	BalanceLogScript.set_window("s:assasin_pasif", false, false)
	assert(absf(float((DamageStats.slot_totals("p")["util"] as Dictionary).get("during", 0.0)) - 40.0) < 0.01, "Assasin pasifi tüm isabetler")
	BalanceLogScript.reset()
	assert(BalanceLogScript.util_snapshot().is_empty(), "reset ölçüleri siler")
	_end()


func test_assasin_slots_match_keys() -> void:
	## Q = Şahin Hamlesi (dash2), E = Gölge Adımı (görünmezlik), R = Gölge Hücumu (dash) - eskiden R hasarı Q'ya yazılıyordu.
	assert(DamageStats.slot_of("s:assasin_dash2") == "q")
	assert(DamageStats.slot_of("s:assasin_gorunmez") == "e")
	assert(DamageStats.slot_of("s:assasin_dash") == "r")
	assert(DamageStats.slot_of("s:oakley_agac") == "r", "Hayat Ağacı R (eskiden Diğer'e düşüyordu)")
	assert(DamageStats.slot_of("s:shaman_kalkan_totemi") == "e" and DamageStats.slot_of("s:shaman_kalkan_alan") == "e")


func test_fmt() -> void:
	assert(DamageStats.fmt(0.0) == "0" and DamageStats.fmt(999.4) == "999" and DamageStats.fmt(12345.0) == "12.345")
	assert(DamageStats.fmt(25_000_000.0) == "25.0 Mn")


func test_game_over_board_grows_with_damage_section() -> void:
	_begin()
	var board: Control = BoardScript.new()
	add_child(board)
	board.set_summary({"time": 100.0, "tier": 2, "kills": 5, "layer": 0, "level": 3}, {})
	var h0: float = board.custom_minimum_size.y
	BalanceLogScript.on_hit("w:yay", 100.0, false)
	BalanceLogScript.on_hit("s:talon_dash", 100.0, false)
	board.set_summary({"time": 100.0, "tier": 2, "kills": 5, "layer": 0, "level": 3}, {})
	assert(board.custom_minimum_size.y > h0 + 60.0, "silah/yetenek bölümü yer açmalı")
	board.queue_redraw()
	await get_tree().process_frame ## _draw hatasız çalışmalı
	board.queue_free()
	_end()
