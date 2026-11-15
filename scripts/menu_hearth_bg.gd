extends RefCounted

## ORTAK MENÜ ARKA PLANI (2026-10-16, kullanıcı: "çok oyunculu, oda kurma ve tek oyunculunun arka planı ana menüdekiyle aynı olsun"):
## ana menünün sahnesi - 2026-11-15'ten beri "Nehir Kenarı Kampı" (menu_camp_scene.gd; eskiden "Ocak Başı" şöminesi). Sahne TEK yerde,
## menu_camp_scene.gd'de: burası onu kurar, kopyalamaz. main_menu.gd bu dosyayı preload ETMESİN (döngü).
## Kullanan: character_select.gd, room_browser.gd, lobby_menu.gd, soul_shop_screen.gd (masaüstü, load() ile - preload döngüsü olmasın). Hepsi statik: const HearthBg := preload("res://scripts/menu_hearth_bg.gd").

const HT := preload("res://scripts/hud_theme.gd") ## tek arayüz paleti (stil rehberi, madde 403)
const CampScene := preload("res://scripts/menu_camp_scene.gd")
## Koyu kit panelleri (menu_dark_kit.gd) sahnenin üstünde okunur kalsın diye düz koyu örtü; kamp ateşi yine seçilir.
const DIM_COLOR := HT.DEEP ## tek palet: sıcak koyu ahşap (madde 403; eskiden Gece Sıvası mor-laciverti)
const DIM_DESKTOP := 0.3


## Tam ekran katman ("BackgroundImage", root'un İLK çocuğu olmalı - üstüne ekran kurulur); içindeki 1920x1080 sahne katmanı ÖRTECEK kadar
## ölçeklenir (KEEP_ASPECT_COVERED gibi, telefonda da ekranın tamamı) - ateş/parti arka planla hizalı kalır. dim > 0: üstüne koyu örtü.
static func add_to(root: Control, dim: float = 0.0) -> Control:
	var layer := Control.new()
	layer.name = "BackgroundImage"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	root.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stage)
	stage.size = CampScene.SCREEN
	CampScene.build(stage)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(DIM_COLOR, dim)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.resized.connect(func() -> void: _fit(layer, stage))
	_fit(layer, stage)
	return layer


static func _fit(layer: Control, stage: Control) -> void:
	if not is_instance_valid(stage) or layer.size.x < 1.0:
		return
	var s: float = maxf(layer.size.x / CampScene.SCREEN.x, layer.size.y / CampScene.SCREEN.y)
	stage.scale = Vector2(s, s)
	stage.position = ((layer.size - CampScene.SCREEN * s) * 0.5).floor()
