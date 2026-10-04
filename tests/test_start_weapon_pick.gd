extends Node

## Başlangıç silahı karakter seçiminde (kullanıcı isteği 2026-10-03): katalog tutarlılığı, seçicinin GameManager'a yazması,
## ızgaranın 15 silahı göstermesi, karakter seçim ekranında seçicinin bulunması. Gerçek akış (menüden seçip oyuna girince o
## silahın envantere gelmesi) tools/mobile_ui/capture_screens.gd ile SHOT_WEAPON ortam değişkeniyle görülür.

const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")


func test_catalog_has_every_weapon_with_icon_name_and_text() -> void:
	assert(WeaponCatalog.KEYS.size() == 15, "15 silah bekleniyordu: %d" % WeaponCatalog.KEYS.size())
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
	assert(buttons.size() == 15, "ızgarada 15 silah düğmesi bekleniyordu: %d" % buttons.size())
	(buttons[1] as Button).pressed.emit() ## 2. sıradaki = Ateş Asası
	assert(GameManager.selected_start_weapon == WeaponCatalog.KEYS[1], "ızgaradan seçim yazılmadı")
	assert(not is_instance_valid(picker.get("_popup")) or (picker.get("_popup") as Node).is_queued_for_deletion(), "seçince ızgara kapanmadı")
	picker.queue_free()
	GameManager.selected_start_weapon = old


func test_character_select_has_weapon_picker() -> void:
	var scene: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var wp: Node = scene.get("weapon_picker")
	assert(wp != null and is_instance_valid(wp), "karakter seçim ekranında başlangıç silahı seçicisi yok")
	scene.queue_free()
