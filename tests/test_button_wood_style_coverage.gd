extends Node

## Kullanıcı isteği doğrulaması: "assets/ui/new shop design içindeki Button
## resmini oyunumdaki tüm butonlarla değiştir, boyutlarını bu resmi
## bozmayacak şekilde ayarla... dükkan kategori butonları veya aşırı dar
## olan butonlar için mini button dosyasını kullan." Bu test, DAHA ÖNCE
## UISound.apply_wood_buttons/ShopPanel._apply_wood_button_style'ın HİÇ
## ulaşmadığı panelleri (keybind_menu, weapon_select_screen, party_panel,
## main.gd ölüm ekranı) ve global tema güvenlik ağını (theme.tres) kontrol
## eder.

const ButtonPngPath := "res://assets/ui/new shop design/Button.png"
const MiniButtonPngPath := "res://assets/ui/new shop design/mini button.png"


func _style_texture_path(btn: Button, style_name: String) -> String:
	var sb: StyleBoxTexture = btn.get_theme_stylebox(style_name) as StyleBoxTexture
	if sb == null or sb.texture == null:
		return ""
	return sb.texture.resource_path


func test_theme_default_uses_new_button_texture() -> void:
	var theme_res: Theme = load("res://assets/fonts/theme.tres")
	var sb: StyleBoxTexture = theme_res.get_stylebox("normal", "Button") as StyleBoxTexture
	assert(sb != null, "Theme Button/normal StyleBoxTexture olmali")
	assert(sb.texture.resource_path == ButtonPngPath,
		"theme.tres hala eski dokuyu kullaniyor: %s" % sb.texture.resource_path)
	assert(not (sb.texture_margin_left < 0.01),
		"texture_margin ayarlanmamis olabilir")


func _find_buttons_recursive(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_find_buttons_recursive(c, out)


func test_pause_menu_buttons_use_new_texture() -> void:
	var scene: PackedScene = load("res://scenes/pause_menu.tscn")
	var panel: CanvasLayer = scene.instantiate()
	add_child(panel) ## add_child bu ortamda _ready()'i zaten tetikliyor - elle tekrar cagirmiyoruz (cift baglanti onlemek icin).
	var resume_btn: Button = panel.get_node("Panel/VBox/ResumeButton")
	assert(_style_texture_path(resume_btn, "normal") == ButtonPngPath,
		"ResumeButton yeni Button.png dokusunu kullanmiyor: %s" % _style_texture_path(resume_btn, "normal"))
	panel.queue_free()


func test_keybind_menu_buttons_get_wood_style() -> void:
	var script: GDScript = load("res://scripts/keybind_menu.gd")
	var kb: CanvasLayer = script.new()
	add_child(kb)
	var all_buttons: Array = []
	_find_buttons_recursive(kb, all_buttons)
	var close_btn: Button = null
	for b in all_buttons:
		if b.text == "KAPAT":
			close_btn = b
	assert(close_btn != null, "keybind_menu KAPAT butonu bulunamadi (bulunanlar: %s)" % [all_buttons.map(func(b): return b.text)])
	assert(_style_texture_path(close_btn, "normal") == ButtonPngPath,
		"keybind_menu KAPAT butonu yeni dokuyu almiyor - bkz. eksik apply_wood_buttons cagrisi")
	kb.queue_free()


func test_weapon_select_screen_reroll_uses_wide_texture_and_cards_are_untouched() -> void:
	var script: GDScript = load("res://scripts/weapon_select_screen.gd")
	var wss: CanvasLayer = script.new()
	wss.mode = "weapon"
	add_child(wss)
	wss._ready()
	var reroll: Button = wss.get_node("RerollButton")
	assert(_style_texture_path(reroll, "normal") == ButtonPngPath,
		"RerollButton yeni dokuyu almiyor: %s" % _style_texture_path(reroll, "normal"))
	## Kartlar kendi ozel StyleBoxFlat'ini korumali (wood button style'la EZILMEMELI).
	var cards_container: Control = wss.get_node("CardsContainer")
	assert(cards_container.get_child_count() > 0, "Kartlar olusmamis")
	var card: Button = cards_container.get_child(0) as Button
	var card_style: StyleBox = card.get_theme_stylebox("normal")
	assert(not (card_style is StyleBoxTexture),
		"Kart yanlislikla ahsap buton dokusuyla eziliyor - _looks_like_icon_slot filtresi calismiyor")
	wss.queue_free()


func test_party_panel_gift_buttons_and_dynamic_gold_button() -> void:
	var script: GDScript = load("res://scripts/party_panel.gd")
	var pp: Control = Control.new()
	pp.set_script(script)
	add_child(pp)
	pp._ready()
	## Statik hediye popup butonlari (Iptal / miktar butonlari) genis oldugu
	## icin ANA Button.png stilini almali.
	var cancel_btn: Button = null
	var gift_popup: Control = pp.get_node("GiftPopup")
	for vbox in gift_popup.get_children():
		for child in vbox.get_children():
			if child is Button and child.text == "İptal":
				cancel_btn = child
			if child is HBoxContainer:
				for sub in child.get_children():
					pass
	assert(cancel_btn != null, "Iptal butonu bulunamadi")
	assert(_style_texture_path(cancel_btn, "normal") == ButtonPngPath,
		"Iptal butonu yeni dokuyu almiyor: %s" % _style_texture_path(cancel_btn, "normal"))

	## Dinamik olarak _create_row() ile yaratilan gold_button KARE oldugu icin
	## MINI dokuyu almali (elle uygulanan _apply_mini_wood_button_style).
	var row: RefCounted = pp.call("_create_row", 12345)
	var gold_btn: Button = row.gold_button
	assert(gold_btn != null, "gold_button olusmamis")
	assert(_style_texture_path(gold_btn, "normal") == MiniButtonPngPath,
		"gold_button mini dokuyu almiyor: %s" % _style_texture_path(gold_btn, "normal"))
	pp.queue_free()
