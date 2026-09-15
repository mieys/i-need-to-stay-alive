extends Node

## Kullanıcı isteği doğrulaması:
## 1) "Dükkanı açınca sağında stat penceresinin de açılmasını istiyorum"
## 2) "bundan sonra mini dükkan aralarında mini dükkan yerine direk dükkan
##    açılsın"

func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	hud._ready()
	return hud


func test_open_shop_panel_shows_stats_panel_to_its_right() -> void:
	var hud: Node = _make_hud()
	assert(not hud.shop_panel.visible, "Dükkan başta kapalı olmalı")
	assert(not hud.stats_panel_instance.visible, "İstatistik paneli başta kapalı olmalı")
	var stats_default_x: float = hud.stats_panel_instance.global_position.x
	hud.open_shop_panel()
	assert(hud.shop_panel.visible, "open_shop_panel() dükkanı açmalı")
	assert(hud.stats_panel_instance.visible, "open_shop_panel() istatistik panelini de açmalı")
	## NOT: Bu senkron test ortamında bir Control ilk kez visible=true
	## olduğunda Godot'un iç layout/sıralama geçişi (henüz hiç frame
	## işlenmemiş olduğu için) shop_panel'in KENDİ (hiç dokunmadığımız)
	## global_position'ını bile kaydırabiliyor - o yüzden burada MUTLAK
	## piksel eşitliği yerine anlamlı/sağlam bir yön kontrolü yapılıyor:
	## istatistik paneli artık eski (envanterle eşleşen, SOLDAKİ) varsayılan
	## konumunda DEĞİL ve dükkanın SOL kenarından daha sağda duruyor.
	assert(not is_equal_approx(hud.stats_panel_instance.global_position.x, stats_default_x),
		"İstatistik paneli eski (envanter-eşleşmeli) konumunda kalmış, yeniden konumlanmamış")
	assert(hud.stats_panel_instance.global_position.x > hud.shop_panel.global_position.x,
		"İstatistik paneli dükkanın SAĞINDA olmalı (shop_x=%s, stats_x=%s)" % [hud.shop_panel.global_position.x, hud.stats_panel_instance.global_position.x])
	hud.queue_free()


func test_close_shop_panel_hides_stats_panel_too() -> void:
	var hud: Node = _make_hud()
	hud.open_shop_panel()
	assert(hud.shop_panel.visible and hud.stats_panel_instance.visible)
	hud.close_shop_panel()
	assert(not hud.shop_panel.visible, "close_shop_panel() dükkanı kapatmalı")
	assert(not hud.stats_panel_instance.visible, "close_shop_panel() istatistik panelini de kapatmalı")
	hud.queue_free()


func test_shop_toggle_pairs_stats_panel() -> void:
	var hud: Node = _make_hud()
	hud._on_shop_toggle()
	assert(hud.shop_panel.visible and hud.stats_panel_instance.visible,
		"_on_shop_toggle() ilk tıklamada ikisini de açmalı")
	hud._on_shop_toggle()
	assert(not hud.shop_panel.visible and not hud.stats_panel_instance.visible,
		"_on_shop_toggle() ikinci tıklamada ikisini de kapatmalı")
	hud.queue_free()


func test_shop_panel_has_closed_signal_that_hud_reacts_to() -> void:
	var hud: Node = _make_hud()
	hud.open_shop_panel()
	assert(hud.shop_panel.has_signal("closed"), "shop_panel.gd 'closed' sinyali tanımlamalı")
	hud.shop_panel.closed.emit()
	assert(not hud.stats_panel_instance.visible,
		"shop_panel 'closed' yayınlayınca hud eşleşen istatistik panelini kapatmalı")
	hud.queue_free()


## main.gd artık MiniShopScreen ÜRETMİYOR, hud.open_shop_panel() çağırıyor -
## main.tscn'i player'la birlikte ayağa kaldırmak pahalı/kırılgan olduğu için
## (bkz. diğer main.gd testlerinin bunu hep atlaması) kaynak metin üzerinden
## doğrulanıyor - test_shop_palette.gd'deki AYNI desen.
func test_main_gd_no_longer_creates_mini_shop_screen_instance() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(not src.contains("MiniShopScreen.new()"),
		"main.gd hala eski MiniShopScreen.new() ile ekran yaratiyor - periyodik molada artik tam dukkan acilmali")
	assert(src.contains("hud.open_shop_panel()"),
		"main.gd periyodik molada hud.open_shop_panel() cagirmiyor")
	assert(src.contains("_mini_shop_pause_active"),
		"main.gd'de periyodik mola durumunu takip eden bayrak bulunamadi")
