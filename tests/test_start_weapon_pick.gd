extends Node

## Başlangıç silahı karakter seçiminde (kullanıcı isteği 2026-10-03): katalog tutarlılığı, seçicinin GameManager'a yazması,
## ızgaranın 15 silahı göstermesi, karakter seçim ekranında seçicinin bulunması. Gerçek akış (menüden seçip oyuna girince o
## silahın envantere gelmesi) tools/mobile_ui/capture_screens.gd ile SHOT_WEAPON ortam değişkeniyle görülür.

const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const PlayerScript: GDScript = preload("res://scripts/player.gd")


func test_catalog_has_every_weapon_with_icon_name_and_text() -> void:
	## Sayı sabit değil (yeni silahlar eklendi: Mızrak madde 305, ...): katalogdaki her silahın sahnesi olmalı, sahnesi olan her silah katalogda.
	assert(WeaponCatalog.KEYS.size() >= 15 and WeaponCatalog.KEYS.size() == PlayerScript.WEAPON_SCENES_BY_KEY.size(),
		"katalog %d silah, sahne tablosu %d" % [WeaponCatalog.KEYS.size(), PlayerScript.WEAPON_SCENES_BY_KEY.size()])
	for key: String in WeaponCatalog.KEYS:
		assert(WeaponCatalog.NAMES.has(key), "%s adı yok" % key)
		assert(WeaponCatalog.DESCRIPTIONS.has(key), "%s açıklaması yok" % key)
		assert(WeaponCatalog.icon(key) != null, "%s ikonu yüklenmiyor" % key)
	assert(WeaponCatalog.is_valid(WeaponCatalog.DEFAULT_KEY))


func test_every_weapon_has_unique_stat_bars() -> void:
	var seen: Dictionary = {}
	for key: String in WeaponCatalog.KEYS:
		assert(WeaponCatalog.STAT_BARS.has(key), "%s stat çubuğu değerleri yok" % key)
		var v: Array = WeaponCatalog.stat_bars(key)
		assert(v.size() == 4, "%s: 4 değer bekleniyordu" % key)
		for n in v:
			assert(int(n) >= 1 and int(n) <= WeaponCatalog.STAT_BAR_MAX, "%s: değer 1..%d dışında" % [key, WeaponCatalog.STAT_BAR_MAX])
		assert(not seen.has(str(v)), "%s ile %s aynı stat çubuklarına sahip" % [key, seen.get(str(v), "")])
		seen[str(v)] = key


func test_every_character_has_stat_bars() -> void:
	for cid in Characters.DEFS:
		assert(Characters.STAT_BARS.has(cid), "%s karakter stat çubuğu değerleri yok" % cid)
		var v: Array = Characters.stat_bars(int(cid))
		assert(v.size() == 4, "%s: 4 değer bekleniyordu" % cid)
		for n in v:
			assert(int(n) >= 1 and int(n) <= WeaponCatalog.STAT_BAR_MAX, "%s: değer 1..%d dışında" % [cid, WeaponCatalog.STAT_BAR_MAX])


func test_invalid_selection_falls_back_to_default() -> void:
	var old: String = GameManager.selected_start_weapon
	GameManager.selected_start_weapon = "yok_boyle_silah"
	assert(WeaponCatalog.selected() == WeaponCatalog.DEFAULT_KEY)
	GameManager.selected_start_weapon = ""
	assert(WeaponCatalog.selected() == WeaponCatalog.DEFAULT_KEY)
	GameManager.selected_start_weapon = old


func test_picker_writes_selection_and_grid_lists_all() -> void:
	var old: String = GameManager.selected_start_weapon
	MetaProgressScript.set_unlock_all(true) ## Ruh Mağazası kilitleri bu testin konusu değil (bkz. test_meta_progress.gd)
	var picker: PanelContainer = load("res://scripts/menu_weapon_picker.gd").new()
	add_child(picker)
	picker.setup(false)
	picker.select("tufek")
	assert(GameManager.selected_start_weapon == "tufek")
	picker.call("_open_grid")
	await get_tree().process_frame
	var popup: CanvasLayer = picker.get("_popup")
	assert(is_instance_valid(popup), "silah ızgarası açılmadı")
	var buttons: Array = popup.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "")
	assert(buttons.size() == WeaponCatalog.KEYS.size(), "ızgarada %d silah düğmesi bekleniyordu: %d" % [WeaponCatalog.KEYS.size(), buttons.size()])
	(buttons[1] as Button).pressed.emit() ## 2. sıradaki = Ateş Asası
	assert(GameManager.selected_start_weapon == WeaponCatalog.KEYS[1], "ızgaradan seçim yazılmadı")
	assert(not is_instance_valid(picker.get("_popup")) or (picker.get("_popup") as Node).is_queued_for_deletion(), "seçince ızgara kapanmadı")
	picker.queue_free()
	GameManager.selected_start_weapon = old
	MetaProgressScript.set_unlock_all(false)


func test_character_select_has_weapon_picker() -> void:
	var scene: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	## 2026-10-16: masaüstü tek oyunculu ekran çok oyunculu "SEÇİM D" düzeninde (lobby_select_desktop.gd solo) - silah SİLAH sekmesinde.
	var desk: Node = scene.get("_desk")
	assert(desk != null and bool(desk.get("solo")), "tek oyunculu masaüstü ekranı SEÇİM D'nin tek oyunculu kipi olmalı")
	assert((desk.get("_tab_btns") as Dictionary).has("weapon"), "karakter seçim ekranında başlangıç silahı sekmesi yok")
	var old: String = GameManager.selected_start_weapon
	MetaProgressScript.set_unlock_all(true)
	desk.call("_set_tab", "weapon")
	var other: String = ""
	for k: String in WeaponCatalog.KEYS:
		if k != old:
			other = k
			break
	desk.call("_on_option_pressed", other)
	assert(GameManager.selected_start_weapon == other, "SİLAH sekmesinde seçilen silah başlangıç silahı olmalı")
	## 2026-11-13: seçilen silahın stat çubukları ayrıntı kutusunda; silah değişince değerler de değişir.
	var bars: Control = desk.get("_detail_bars")
	assert(bars != null and bars.visible, "SİLAH sekmesinde stat çubukları görünmüyor")
	assert(bars.call("values") == WeaponCatalog.stat_bars(other), "çubuklar seçilen silahın değerlerini göstermiyor")
	var third: String = WeaponCatalog.KEYS[0] if other != WeaponCatalog.KEYS[0] else WeaponCatalog.KEYS[1]
	desk.call("_on_option_pressed", third)
	assert(bars.call("values") == WeaponCatalog.stat_bars(third), "silah değişince çubuklar güncellenmedi")
	desk.call("_set_tab", "pet")
	assert(not bars.visible, "EVCİL sekmesinde silah çubukları görünmemeli")
	desk.call("_set_tab", "weapon")
	## 2026-11-16 (madde 748): seçili karakterin Hasar/Savunma/Çeviklik/Destek çubukları orta panelde, yeteneklerin üstünde.
	var cbars: Control = desk.get("_char_bars")
	assert(cbars != null, "orta panelde karakter stat çubukları yok")
	var sel_char: int = int(desk.get("_sel_char"))
	assert(cbars.call("values") == Characters.stat_bars(sel_char), "karakter çubukları seçili karakterin değerlerini göstermiyor")
	## 2026-10-19: 17 silahla ızgara 4 satıra çıkınca sağ panel OYUNU BAŞLAT'ın altına taşıyordu.
	await get_tree().process_frame
	var panel: Control = desk.get("_tab_grid")
	while panel.get_parent() != desk:
		panel = panel.get_parent()
	var start: Control = desk.get("_start_btn")
	print("sağ panel alt=%.0f  başlat üst=%.0f  ızgara=%s" % [panel.get_global_rect().end.y, start.get_global_rect().position.y, (desk.get("_tab_grid") as Control).size])
	assert(panel.get_global_rect().end.y <= start.get_global_rect().position.y + 0.5,
		"sağ panel (alt %.0f) OYUNU BAŞLAT düğmesinin (üst %.0f) üstüne taşıyor" % [panel.get_global_rect().end.y, start.get_global_rect().position.y])
	## Madde 759: sağ panel HER sekmede kendi kutusunda kalmalı - boyu değişirse PixelBox damar dokusu kayar (grain_offset kutu boyuna bağlı),
	## sekme değiştirince pencerenin arka planı "değişiyor" görünür (silah sekmesi ok payıyla 908 -> 910 olmuştu).
	var right_rect: Rect2 = desk.get("RIGHT")
	for tab: String in ["weapon", "pet", "spirit"]:
		desk.call("_set_tab", tab)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(absf(panel.size.y - right_rect.size.y) < 0.5, "%s sekmesinde sağ panel boyu değişti (%.0f != %.0f): damar dokusu kayar" % [tab, panel.size.y, right_rect.size.y])
	desk.call("_set_tab", "weapon")
	await get_tree().process_frame
	assert(panel.get_global_rect().end.x <= start.get_global_rect().end.x + 0.5,
		"karakter çubukları sağ paneli genişletiyor (sağ %.0f > %.0f)" % [panel.get_global_rect().end.x, start.get_global_rect().end.x])
	## Orta panel (ad + statlar + çubuklar + 4 yetenek) kendi kutusunu aşıp büyümemeli.
	var midp: Control = desk.get("_skills")
	while midp.get_parent() != desk:
		midp = midp.get_parent()
	var mid_rect: Rect2 = desk.get("MID")
	print("orta panel boyu=%.0f  hedef=%.0f" % [midp.size.y, mid_rect.size.y])
	assert(midp.size.y <= mid_rect.size.y + 0.5, "orta panel çubuklarla taştı (%.0f > %.0f)" % [midp.size.y, mid_rect.size.y])
	assert(cbars.get_global_rect().end.x <= midp.get_global_rect().end.x, "karakter çubukları orta panelin dışına taşıyor")
	## Çubuklar ad ile temel statların arasında (madde 748): HER karakterde ad satırı orta panelin iç genişliğine sığmalı.
	var nh: Control = (desk.get("_stats") as Control).get_parent()
	for cid in Characters.DEFS:
		desk.call("show_character", int(cid), false)
		var used: float = 0.0
		for c in nh.get_children():
			used += (c as Control).get_combined_minimum_size().x
		assert(used <= mid_rect.size.x - 32.0 + 0.5, "%s: ad satırı sığmıyor (%.0f > %.0f)" % [cid, used, mid_rect.size.x - 32.0])
	assert(midp.size.x <= mid_rect.size.x + 0.5, "orta panel genişledi (%.0f)" % midp.size.x)
	desk.call("show_character", sel_char, false)
	GameManager.selected_start_weapon = old
	MetaProgressScript.set_unlock_all(false)
	scene.queue_free()
