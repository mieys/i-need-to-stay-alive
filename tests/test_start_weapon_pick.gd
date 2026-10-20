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
	## 2026-10-19: 17 silahla ızgara 4 satıra çıkınca sağ panel OYUNU BAŞLAT'ın altına taşıyordu.
	await get_tree().process_frame
	var panel: Control = desk.get("_tab_grid")
	while panel.get_parent() != desk:
		panel = panel.get_parent()
	var start: Control = desk.get("_start_btn")
	print("sağ panel alt=%.0f  başlat üst=%.0f  ızgara=%s" % [panel.get_global_rect().end.y, start.get_global_rect().position.y, (desk.get("_tab_grid") as Control).size])
	assert(panel.get_global_rect().end.y <= start.get_global_rect().position.y + 0.5,
		"sağ panel (alt %.0f) OYUNU BAŞLAT düğmesinin (üst %.0f) üstüne taşıyor" % [panel.get_global_rect().end.y, start.get_global_rect().position.y])
	GameManager.selected_start_weapon = old
	MetaProgressScript.set_unlock_all(false)
	scene.queue_free()
