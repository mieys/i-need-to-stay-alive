extends Node

## Kullanıcı isteği doğrulaması: "dükkan butonunu silip altın göstergesine
## tıklandığında dükkan açılsın" + "envanter ve dükkan (altın göstergesi)
## aynı renkte olsun".
##
## NOT: Bu test ortamında instantiate edilen node'lar canlı SceneTree'ye
## girmediği için Godot _ready()'yi OTOMATİK çağırmıyor (bkz. hata ayıklama:
## $ShopPanel get_node ile buluyor ama @onready var'lar hep null kalıyordu).
## Bu yüzden add_child()'dan sonra hud._ready() burada ELLE çağrılıyor -
## chest_menu.gd testlerindeki menu.setup() paterniyle aynı fikir.

const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)


## Bu test ortamında instantiate edilen hud gerçek (canlı) bir SceneTree'ye
## girmiyor, bu yüzden motor _ready()'yi otomatik çağırmıyor - burada elle
## tetikleniyor. hud.gd artık tüm sinyal bağlantılarını _connect_once() ile
## yaptığı için (bkz. hud.gd) bu birden fazla kez çağrılsa bile güvenli.
func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	## (2026-10-03) add_child zaten _ready'yi çalıştırıyor; Godot 4.7'de elle _ready() @onready'leri yeniden çözüyor ve
	## _ready'de başka katmana taşınan InventoryPanelInstance'ı null yapıyordu - ikinci çağrı kaldırıldı.
	return hud


func test_gold_indicator_children_pass_clicks_through() -> void:
	var hud: Node = _make_hud()
	var gold_indicator: PanelContainer = hud.get_node("GoldIndicator")
	for child in gold_indicator.get_children():
		_assert_all_ignore(child)
	hud.queue_free()


func _assert_all_ignore(node: Node) -> void:
	if node is Control:
		assert((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s mouse_filter IGNORE olmali (yoksa tiklama GoldIndicator'a ulasmaz)" % node.name)
	for child in node.get_children():
		_assert_all_ignore(child)


## Kullanıcı isteği (2026-11-06): FPS göstergesi sadece "FPS: N" yazsın (eski " | C++ yaratık" eki yok), sol sütundaki
## ENVANTER düğmesinin yanında simetrik (aynı yükseklik, dikey ortalı) ve fazla dikkat çekmeyecek kadar küçük/sönük dursun.
func test_fps_label_sits_beside_envanter_button_and_is_subtle() -> void:
	var hud: Node = _make_hud()
	if MobileUIScript_enabled():
		hud.queue_free()
		return
	var fps: Label = hud.get_node("FpsLabel")
	var env: Button = hud.get_node("EnvanterToggleButton")
	assert(fps.offset_left >= env.offset_right, "FPS etiketi ENVANTER düğmesinin SAĞINDA olmalı (solu %.1f, düğme sağı %.1f)" % [fps.offset_left, env.offset_right])
	assert(fps.offset_left - env.offset_right <= 24.0, "FPS etiketi düğmeye yakın durmalı")
	assert(is_equal_approx(fps.offset_top, env.offset_top) and is_equal_approx(fps.offset_bottom, env.offset_bottom),
		"FPS etiketi ENVANTER düğmesiyle aynı yükseklikte (dikey simetrik) olmalı")
	assert(fps.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Yazı dikey ortalı olmalı")
	assert(fps.get_theme_font_size("font_size") <= 16, "FPS yazısı küçük (<=16) olmalı")
	assert(fps.get_theme_color("font_color").a < 1.0, "FPS yazısı sönük (saydam) olmalı")
	## Metin: sadece FPS (yaratık sistemi ekinin olmaması)
	UISound.show_fps = true
	hud._process(1.0)
	assert(fps.text.begins_with("FPS: "), "FPS metni 'FPS: N' ile başlamalı: %s" % fps.text)
	assert(fps.text.find("C++") == -1 and fps.text.find("|") == -1, "FPS metninde başka bilgi olmamalı: %s" % fps.text)
	UISound.show_fps = false
	hud.queue_free()


func MobileUIScript_enabled() -> bool:
	return load("res://scripts/mobile_ui.gd").enabled


func test_shop_toggle_button_is_hidden() -> void:
	var hud: Node = _make_hud()
	var shop_btn: Button = hud.get_node("ShopToggleButton")
	assert(shop_btn.visible == false, "ShopToggleButton hala görünür olmamalı")
	hud.queue_free()


func test_gold_indicator_click_opens_shop() -> void:
	var hud: Node = _make_hud()
	## Kullanıcı kararı: dükkan şimdilik TAMAMEN kapalı (GameManager.SHOP_ENABLED = false, "dükkan asla açılmayacak sonraki bir
	## değişikliğe kadar") - kapalıyken hiçbir yoldan açılmamalı; açılırsa aşağıdaki kural sınanır (2026-10-03 test güncellemesi).
	if not GameManager.SHOP_ENABLED:
		hud._on_shop_toggle()
		assert(not hud.shop_panel.visible, "Dükkan kapalıyken açıldı")
		hud.queue_free()
		return
	var shop_panel: Control = hud.get_node("ShopPanel")
	assert(shop_panel.visible == false, "Dükkan başta kapalı olmalı")
	hud._on_gold_indicator_gui_input(
		InputEventMouseButton.new()
	)
	## Sahte event pressed=false olduğu için henüz açılmamalı.
	assert(shop_panel.visible == false, "pressed=false event dükkanı açmamalı")

	var press_event := InputEventMouseButton.new()
	press_event.pressed = true
	press_event.button_index = MOUSE_BUTTON_LEFT
	hud._on_gold_indicator_gui_input(press_event)
	assert(shop_panel.visible == true, "Sol tık dükkanı açmalı")

	hud._on_gold_indicator_gui_input(press_event)
	assert(shop_panel.visible == false, "İkinci sol tık dükkanı kapatmalı")
	hud.queue_free()


func test_envanter_button_matches_gold_indicator_palette() -> void:
	## Kullanıcı isteği (2026-09-21): ENVANTER butonu ve altın göstergesi artık aynı piksel UI kitinden geliyor - buton ahşap
	## plaka dokusu, gösterge başlık levhası (plaque) dokusu; ikisi de StyleBoxTexture. 2026-09-24: oyun içi kit
	## assets/ui/game'e taşındı (menülerle aynı bej/ahşap dil, tools/gen_menu_kit.py build_game).
	var hud: Node = _make_hud()
	var envanter_btn: Button = hud.get_node("EnvanterToggleButton")
	var gold_indicator: PanelContainer = hud.get_node("GoldIndicator")

	var envanter_style: StyleBoxTexture = envanter_btn.get_theme_stylebox("normal") as StyleBoxTexture
	var gold_style: StyleBoxTexture = gold_indicator.get_theme_stylebox("panel") as StyleBoxTexture

	assert(envanter_style != null, "ENVANTER butonu icin normal stil (StyleBoxTexture) bekleniyordu")
	assert(gold_style != null, "Altin gostergesi icin panel stili (StyleBoxTexture) bekleniyordu")
	## madde 483: masaüstünde ikisi de sol üst konsolun Gömme Tepsi kit dokuları (assets/ui/kit: kabarık levha + koyu kuyu)
	for st: StyleBoxTexture in [envanter_style, gold_style]:
		var path: String = st.texture.resource_path
		assert(path.begins_with("res://assets/ui/game/") or path.begins_with("res://assets/ui/kit/"), "kit dokusu degil: %s" % path)
	hud.queue_free()
