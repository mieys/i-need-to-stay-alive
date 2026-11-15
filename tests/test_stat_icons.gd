extends Node

## Stat ikonları tek klasörde (assets/ui/stat_icons/, Raven 16x16 x3 = 48x48, kullanıcı seçimi 2026-11-13).
## Her ekranın stat ikonu bu klasörden gelmeli ve dosyası olmalı; eski klasörlere (stat_mini, stat_mini_lol,
## level_up_icons, menu/stat_*) geri dönen bir referans yakalanır.

const StatIcon := preload("res://scripts/stat_icon.gd")
const HudStatPanel := preload("res://scripts/hud_stat_panel.gd")
const Inventory := preload("res://scripts/inventory_panel.gd")
const Merchant := preload("res://scripts/merchant_shop_screen.gd")
const MenuKit := preload("res://scripts/menu_kit.gd")
const DIR := "res://assets/ui/stat_icons/"


func _check(path: String, who: String) -> void:
	assert(path.begins_with(DIR), "%s: stat ikonu %s altında olmalı (%s)" % [who, DIR, path])
	var tex: Texture2D = load(path) as Texture2D
	assert(tex != null, "%s: ikon yüklenmeli (%s)" % [who, path])
	assert(tex.get_size() == Vector2(48, 48), "%s: ikon 48x48 olmalı (%s)" % [who, path])


func test_stat_icon_paths_all_load() -> void:
	assert(StatIcon.ICON_DIR == DIR, "StatIcon.ICON_DIR")
	for id: String in StatIcon.ICON_PATHS:
		_check(DIR + str(StatIcon.ICON_PATHS[id]), "StatIcon " + id)


func test_soul_shop_rows_all_have_icons() -> void:
	## Ruh dükkanının her satırı (İndirim / Ücretsiz Karıştırma / Evrim Karıştırma / Dirilme dahil) set ikonunu göstermeli, kod glifi değil.
	var Meta: GDScript = load("res://scripts/meta_upgrades.gd") as GDScript
	for d: Dictionary in Meta.get_script_constant_map()["LIST"]:
		var key: String = str(d.get("icon", ""))
		assert(StatIcon.ICON_PATHS.has(key), "ruh dükkanı %s: ICON_PATHS anahtarı olmalı ('%s')" % [d["id"], key])
		_check(DIR + str(StatIcon.ICON_PATHS[key]), "ruh dükkanı " + str(d["id"]))


func test_hud_panel_and_inventory_icons() -> void:
	assert(HudStatPanel.ICON_DIR == DIR, "HudStatPanel.ICON_DIR")
	for s: Array in HudStatPanel.STATS:
		_check(DIR + str(s[0]) + ".png", "HUD " + str(s[0]))
	for k: String in Inventory.CH_STAT_ICON:
		_check(DIR + str(Inventory.CH_STAT_ICON[k]) + ".png", "envanter " + k)


func test_merchant_menu_and_tooltip_icons() -> void:
	for k: String in Merchant.STAT_ICONS:
		_check(str(Merchant.STAT_ICONS[k]), "satıcı " + k)
	for r: Dictionary in MenuKit.STAT_ROWS:
		_check(DIR + str(r["icon"]) + ".png", "karakter seçimi " + str(r["key"]))
	## Yetenek ipucu / ruh dükkanı / oyun sonu: preload'lar derlenmeli ve yeni klasörü göstermeli.
	_check((load("res://scripts/skill_icon.gd") as GDScript).get_script_constant_map()["COOLDOWN_ICON"].resource_path, "skill_icon")
	_check((load("res://scripts/soul_shop_screen.gd") as GDScript).get_script_constant_map()["SK_CD_ICON"].resource_path, "ruh dükkanı")
	var go: Dictionary = (load("res://scripts/game_over_board.gd") as GDScript).get_script_constant_map()
	_check(go["ICON_DMG"].resource_path, "oyun sonu hasar")
	_check(go["ICON_SHIELD"].resource_path, "oyun sonu kalkan")
