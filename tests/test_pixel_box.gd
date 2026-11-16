extends Node

## Piksel kutu (madde 417, scripts/pixel_box.gd): kit kutuları StyleBoxFlat yerine piksel kenar + kabartma çizer, ama StyleBoxFlat'in
## özellik adlarını ve içerik payı davranışını korur (kutuyu sonradan değiştiren kodlar bozulmasın).

const PixelBox := preload("res://scripts/pixel_box.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const MenuDarkKit := preload("res://scripts/menu_dark_kit.gd")
const HT := preload("res://scripts/hud_theme.gd")


func _px(img: Image, x: int, y: int) -> Color:
	return img.get_pixel(x, y)


## RGBA8 yuvarlaması payıyla renk eşitliği
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006 and absf(a.a - b.a) < 0.006


func test_kits_return_pixel_box_with_flat_margins() -> void:
	var k = DarkKit.new(DarkKit.PAL_WOOD)
	var s = k.sb(k.c("panel"), k.c("line_hi"), 3, 8)
	assert(s is PixelBox, "shop_dark_kit.sb piksel kutu döndürmeli")
	## StyleBoxFlat gibi: elle pay verilmediyse içerik payı = kenar kalınlığı
	assert(is_equal_approx(s.get_margin(SIDE_LEFT), 3.0), "otomatik pay kenar kalınlığı olmalı: %s" % s.get_margin(SIDE_LEFT))
	var s2 = k.sb(k.c("panel"), k.c("line_hi"), 3, 8, 16.0)
	assert(is_equal_approx(s2.get_margin(SIDE_TOP), 16.0), "elle verilen pay ezilmemeli")
	assert(MenuDarkKit.sb(HT.WIN_PANEL, HT.WIN_LINE) is PixelBox, "menu_dark_kit.sb piksel kutu döndürmeli")


func test_mutation_emits_changed() -> void:
	var s := PixelBox.new()
	var hits := [0]
	s.changed.connect(func() -> void: hits[0] += 1)
	s.border_color = Color.RED
	s.set_corner_radius_all(6)
	assert(hits[0] >= 2, "özellik değişince changed yayılmalı")
	s.content_margin_left = 20
	s.border_width_left = 6
	assert(is_equal_approx(s.content_margin_left, 20.0), "elle verilen pay kenar değişince ezilmemeli")


func test_texture_corner_border_bevel() -> void:
	var fill := HT.WIN_PANEL
	var border := HT.WIN_LINE_HI
	## 8 px yarıçap -> 3 sanat px piksel daire [3,1,1]; 3 px kenar -> 1 sanat px; kabartma 1 sanat px
	var info: Array = PixelBox.texture_for(fill, border, [3, 3, 3, 3], [8, 8, 8, 8], false)
	var tex: Image = info[2]
	var m: Array = info[1]
	assert(m == [9, 9, 9, 9], "kenar payı 3 sanat px = 9 ekran px olmalı: %s" % str(m))
	assert(_px(tex, 1, 1).a == 0.0, "köşe kesiği saydam olmalı")
	## sanat pikseli (x, y) -> ekran (3x+1, 3y+1)
	assert(_near(_px(tex, 3 * 3 + 1, 0 * 3 + 1), border), "üst kenar kenar renginde olmalı")
	assert(_near(_px(tex, 1 * 3 + 1, 1 * 3 + 1), border), "köşe basamağı kenar renginde olmalı")
	var hi := Color(fill.lerp(border, 0.5), fill.a)
	assert(_near(_px(tex, 3 * 3 + 1, 1 * 3 + 1), hi), "kenarın altı (üst) ışık çizgisi olmalı")
	var W: int = tex.get_width() / 3
	var lo := Color(fill.darkened(0.45), fill.a)
	assert(_near(_px(tex, 3 * 3 + 1, (W - 2) * 3 + 1), lo), "alt kenarın üstü gölge çizgisi olmalı")
	assert(_near(_px(tex, 3 * 3 + 1, 3 * 3 + 1), fill), "orta dolgu rengi aynı kalmalı")


func test_open_bottom_tab_has_no_bottom_edge() -> void:
	## Pazar sekmesi gibi: altta kenar + yuvarlak köşe yok
	var info: Array = PixelBox.texture_for(HT.WIN_PANEL, HT.WIN_LINE_HI, [3, 3, 3, 0], [8, 8, 0, 0], false)
	var tex: Image = info[2]
	var H: int = tex.get_height() / 3
	assert(_px(tex, 1, (H - 1) * 3 + 1).a > 0.0, "alt köşe kesilmemeli")
	assert(_near(_px(tex, (tex.get_width() / 3 / 2) * 3 + 1, (H - 1) * 3 + 1), HT.WIN_PANEL), "altta kenar çizgisi olmamalı")


func test_draws_in_panel() -> void:
	var p := PanelContainer.new()
	p.size = Vector2(200, 120)
	p.add_theme_stylebox_override("panel", MenuDarkKit.sb(HT.WIN_PANEL, HT.WIN_LINE_HI, 3, 8))
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	p.queue_free()


## madde 662: ahşap damar dokusu yalnız pencere dolgusuna ve büyük kutuya düşer; düğme/kuyu/altın düğme/küçük kutu düz kalır.
func test_grain_only_on_window_fills() -> void:
	var big := Vector2(400, 300)
	assert(PixelBox.grain_applies(Color(HT.WIN_PANEL, 0.88), big), "pencere zemini (%88) dokulu olmalı")
	assert(PixelBox.grain_applies(HT.WIN_PANEL2, big) and PixelBox.grain_applies(HT.WIN_PANEL3, big), "iç kart / seçili kart dokulu olmalı")
	## madde 753 (kullanıcı seçimi B): kartlarda doku pencereden ZAYIF (%35) - silah/portre çizgileriyle yarışmasın
	assert(is_equal_approx(PixelBox.grain_card_alpha, 0.35), "kart dokusu %%35 olmalı: %s" % PixelBox.grain_card_alpha)
	assert(not PixelBox._is_card_fill(Color(HT.WIN_PANEL, 0.88)), "pencere zemini kart sayılmamalı (tam doku)")
	assert(not PixelBox.grain_applies(HT.WIN_INSET, big), "kuyu (yazı kutusu) düz kalmalı")
	assert(not PixelBox.grain_applies(HT.ACCENT, big), "altın düğme düz kalmalı")
	assert(not PixelBox.grain_applies(HT.DEEP, big), "karartma düz kalmalı")
	assert(not PixelBox.grain_applies(HT.WIN_PANEL, Vector2(300, 60)), "ince kutu (düğme / satır) düz kalmalı")
	assert(not PixelBox.grain_applies(Color(HT.WIN_PANEL, 0.0), big), "görünmez dolgu dokusuz")
	var s = MenuDarkKit.sb(Color(HT.WIN_PANEL, 0.88), HT.WIN_LINE)
	assert(s.grain, "kit kutusunda doku izni varsayılan açık")
	var o: Vector2 = PixelBox.grain_offset(Vector2(1400, 908))
	assert(o == PixelBox.grain_offset(Vector2(1400, 908)), "kayma boya bağlı ve kararlı olmalı (üstüne gelince kaymasın)")
	assert(int(o.x) % 3 == 0 and int(o.y) % 3 == 0, "kayma sanat pikseline (3 px) oturmalı")


## Karo: 3 px ızgarada, kenarlarda tekrar sınırını belli eden düz çizgi yok (kullanıcının gördüğü "ortadaki ince keskin çizgi").
func test_grain_tile_is_seamless_pixel_art() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/panel_doku/ahsap_damar.png"))
	assert(img != null and not img.is_empty(), "doku dosyası okunamadı")
	var W: int = img.get_width()
	var H: int = img.get_height()
	assert(W % 3 == 0 and H % 3 == 0, "karo 3'ün katı olmalı")
	for y in range(0, H, 3):
		for x in range(0, W, 3):
			var c: Color = img.get_pixel(x, y)
			assert(img.get_pixel(x + 2, y + 2) == c and img.get_pixel(x + 1, y) == c, "3x3 blok tek renk olmalı (%d, %d)" % [x, y])
	## her sanat satırının koyu kaplaması; tekrar sınırındaki satırlar iç satırlardan belirgin yüksek olmamalı
	var cov: Array = []
	for ay in H / 3:
		var n := 0
		for ax in W / 3:
			var c: Color = img.get_pixel(ax * 3, ay * 3)
			if c.a > 0.0 and c.r < 0.25:
				n += 1
		cov.append(float(n) / float(W / 3))
	var inner_max: float = 0.0
	for i in range(1, cov.size() - 1):
		inner_max = maxf(inner_max, cov[i])
	assert(cov[cov.size() - 1] <= inner_max and cov[0] <= inner_max, "karo sınırında düz koyu çizgi var: %s / %s > %s" % [cov[0], cov[cov.size() - 1], inner_max])
	assert(cov[cov.size() - 1] < 0.9, "son satır baştan sona çizgi olmamalı")
