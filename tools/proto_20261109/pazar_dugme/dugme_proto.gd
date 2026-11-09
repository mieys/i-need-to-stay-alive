extends RefCounted

## PAZAR DÜĞMELERİ prototipleri (2026-11-09, kullanıcı: "satın al ve devam et butonlarının görünüşü için 4 yeni prototip hazırlar mısın.
## ikisi aynı gözükmesin birbiriyle karıştırılıyor sonra"). OYUNA BAĞLI DEĞİL.
## Bugün ikisi de kitin AYNI "primary" altın düğmesi (level_market_view.gd: SATIN AL 400x64 önizlemenin altında, DEVAM ET 300x56 pencerenin
## sağ altında) - üst üste, aynı renk, aynı biçim. Burada gerçek pazar ekranı açılır, YALNIZ bu iki düğmenin görünüşü değişir (yer aynı).
## Her varyantta iki düğme en az iki eksende ayrışır (renk / dolgu / silüet / simge):
##   A Altın Kese + Ahşap Tahta - SATIN AL altın, üstünde fiyat (para = alışveriş); DEVAM ET ahşap tahta (kenar rengi) + krem yazı + ok
##   B Altın + Ok Tabela        - SATIN AL altın + heybe; DEVAM ET sağı sivri ahşap YOL TABELASI (silüet farkı, çivi + damar)
##   C Fiyat Etiketi + Çerçeve  - SATIN AL solda kuyuda fiyat + sağda altın (bölünmüş); DEVAM ET içi koyu, ALTIN KENARLI boş çerçeve + ok
##   D Kalın Altın + Koyu Tuş   - SATIN AL alt dudaklı kalın kabartma altın blok; DEVAM ET koyu HUD levhası + ENTER tuş kapağı
## Renkler yalnız hud_theme rolleri (stil rehberi); doku 1 sanat px = 3 ekran px.

const HT := preload("res://scripts/hud_theme.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const Market := preload("res://scripts/level_market.gd")
const PX := 3
const LIP_MAX := 3 ## D: kalın altın bloğun alt dudağı (sanat px)


static func apply(variant: String, view: Control) -> void:
	var k = view.get("_k")
	var go: Button = view.get("go_button")
	var buy: Button = view.find_child("BuyButton", true, false) as Button
	var f: Array = view.get("_focus")
	var e: Dictionary = ((view.get("offers") as Dictionary).get(str(f[0]), []) as Array)[int(f[1])]
	var verb: String = buy.text if buy else "SATIN AL"
	match variant:
		"A":
			_a(k, go, buy, e, verb)
		"B":
			_b(k, go, buy, verb)
		"C":
			_c(k, go, buy, e, verb)
		"D":
			_d(k, go, buy, verb)


## ---------------------------------------------------------------- A
static func _a(k, go: Button, buy: Button, e: Dictionary, verb: String) -> void:
	if buy and not buy.disabled:
		var r: HBoxContainer = k.h(18)
		r.add_child(_l(k, verb, 32, HT.ACCENT_TEXT, false))
		r.add_child(_dot(HT.ACCENT_DK))
		_price(k, r, e, HT.ACCENT_TEXT)
		_content(buy, r)
	_boxes(go, k.sb(HT.RIM, HT.OUTLINE, 3, 6, 10.0), k.sb(HT.RIM_HI, HT.OUTLINE, 3, 6, 10.0), k.sb(HT.RIM_LO, HT.OUTLINE, 3, 6, 10.0))
	var g: HBoxContainer = k.h(18)
	g.add_child(_l(k, "DEVAM ET", 40, HT.TEXT, true))
	g.add_child(_glyph(k, DarkKit.G_ARROW, HT.TEXT))
	_content(go, g)


## ---------------------------------------------------------------- B
static func _b(k, go: Button, buy: Button, verb: String) -> void:
	if buy and not buy.disabled:
		var r: HBoxContainer = k.h(16)
		r.add_child(_glyph(k, DarkKit.G_BAG, HT.ACCENT_TEXT))
		r.add_child(_l(k, verb, 32, HT.ACCENT_TEXT, false))
		_content(buy, r)
	## tabela: 300 x 57 (19 sanat satırı: sivri uç tek pikselde ortalanır)
	var w: int = int(go.size.x) / PX
	var h: int = 19
	go.custom_minimum_size = Vector2(w * PX, h * PX)
	go.size = go.custom_minimum_size
	var tip: int = (h - 1) / 2
	_boxes(go, _tex_box(_sign_img(w, h, HT.RIM)), _tex_box(_sign_img(w, h, HT.RIM_HI)), _tex_box(_sign_img(w, h, HT.RIM_LO)))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_right", tip * PX)
	m.add_theme_constant_override("margin_bottom", PX)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(cc)
	cc.add_child(_l(k, "DEVAM ET", 40, HT.TEXT, true))
	go.text = ""
	go.add_child(m)


## Sağı sivri ahşap tabela (sanat pikselinde): sol köşeler 1 px yuvarlak, 1 px OUTLINE kenar (4 komşu), üst/sol iç ışık, alt iç gölge,
## iki tahta damarı + solda iki çivi başı.
static func _sign_img(w: int, h: int, fill: Color) -> Image:
	var tip: int = (h - 1) / 2
	var body_end: int = w - 1 - tip
	var inside := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		if x <= body_end:
			return not (x == 0 and (y == 0 or y == h - 1))
		return absi(y - tip) <= tip - (x - body_end)
	var hi: Color = fill.lerp(HT.ACCENT_SOFT, 0.28)
	var lo: Color = fill.lerp(HT.OUTLINE, 0.45)
	var grain: Color = fill.lerp(HT.OUTLINE, 0.22)
	## damarlar (yazının üstünü/altını kesmeyen kısa çizgiler): [x0, y, x1)
	var segs: Array = [[7, 4, 22], [30, 15, 52], [60, 4, 78], [12, 14, 20]]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if not inside.call(x, y):
				continue
			var edge: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
			var col: Color = fill
			if edge:
				col = HT.OUTLINE
			elif not inside.call(x, y - 2) or not inside.call(x - 2, y):
				col = hi
			elif not inside.call(x, y + 2):
				col = lo
			else:
				for s: Array in segs:
					if y == int(s[1]) and x >= int(s[0]) and x < mini(int(s[2]), body_end - 2):
						col = grain
			img.set_pixel(x, y, col)
	## çiviler
	for ny: int in [4, h - 5]:
		img.set_pixel(3, ny, HT.OUTLINE)
		img.set_pixel(3, ny - 1, hi)
	return img


## ---------------------------------------------------------------- C
static func _c(k, go: Button, buy: Button, e: Dictionary, verb: String) -> void:
	if buy and not buy.disabled:
		_boxes(buy, k.sb(HT.ACCENT, HT.ACCENT_DK, 3, 6, 0.0), k.sb(HT.ACCENT.lightened(0.08), HT.ACCENT_DK, 3, 6, 0.0),
			k.sb(HT.ACCENT.darkened(0.12), HT.ACCENT_DK, 3, 6, 0.0))
		buy.text = ""
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for s: String in ["margin_left", "margin_top", "margin_bottom"]:
			m.add_theme_constant_override(s, 9)
		m.add_theme_constant_override("margin_right", 6)
		var r: HBoxContainer = k.h(0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(r)
		var tag: PanelContainer = k.box(HT.WIN_INSET, HT.ACCENT_DK, 0.0, 3, 3)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.custom_minimum_size.x = 162
		var tc := CenterContainer.new()
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pr: HBoxContainer = k.h(14)
		_price(k, pr, e, HT.PRICE, true)
		tc.add_child(pr)
		tag.add_child(tc)
		r.add_child(tag)
		var lc := CenterContainer.new()
		lc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lc.add_child(_l(k, verb, 32, HT.ACCENT_TEXT, false))
		r.add_child(lc)
		buy.add_child(m)
	var deep := Color(HT.DEEP, 0.86)
	_boxes(go, k.sb(deep, HT.ACCENT, 3, 6, 10.0), k.sb(Color(HT.PLATE_ON, 0.92), HT.ACCENT, 3, 6, 10.0), k.sb(HT.DEEP, HT.ACCENT_DK, 3, 6, 10.0))
	var g: HBoxContainer = k.h(18)
	g.add_child(_l(k, "DEVAM ET", 40, HT.ACCENT, true))
	g.add_child(_glyph(k, DarkKit.G_ARROW, HT.ACCENT))
	_content(go, g)


## ---------------------------------------------------------------- D
static func _d(k, go: Button, buy: Button, verb: String) -> void:
	if buy and not buy.disabled:
		var lip_h: int = 3
		buy.custom_minimum_size.y = 69
		buy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST ## 9 dilimin esneyen orta bandı süzülmesin
		_boxes(buy, _chunky(HT.ACCENT, lip_h), _chunky(HT.ACCENT.lightened(0.08), lip_h), _chunky(HT.ACCENT.darkened(0.1), 0))
		var r: HBoxContainer = k.h(16)
		r.add_child(_glyph(k, DarkKit.G_CHECK, HT.ACCENT_TEXT))
		r.add_child(_l(k, verb, 32, HT.ACCENT_TEXT, false))
		_content(buy, r)
	_boxes(go, k.sb(HT.DOCK_INSET, HT.RIM, 3, 6, 8.0), k.sb(HT.DOCK_PLATE_ON, HT.RIM_HI, 3, 6, 8.0), k.sb(HT.DEEP, HT.RIM, 3, 6, 8.0))
	var g: HBoxContainer = k.h(16)
	## tuş kapağı: HUD levhası rengi, alt kenar kalın (basılabilir tuş), yazı kenarlara değmesin diye paylı
	var cs = k.sb(HT.PLATE_ON, HT.RIM_HI, 3, 3)
	cs.border_width_bottom = 6
	cs.content_margin_left = 12
	cs.content_margin_right = 12
	cs.content_margin_top = 0
	cs.content_margin_bottom = 6
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", cs)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(_l(k, "ENTER", 32, HT.TEXT, false))
	g.add_child(cap)
	g.add_child(_l(k, "DEVAM ET", 40, HT.TEXT, true))
	_content(go, g)


## Kalın altın blok (9 dilim): 1 px ACCENT_DK kenar, köşe 1 px, üstte 1 px ışık, altta lip_h sanat satırı koyu altın dudak.
## lip 0 = basılı (yüz aşağı iner).
static func _chunky(fill: Color, lip_h: int) -> StyleBoxTexture:
	var w: int = 12
	var top: int = 2 + (LIP_MAX - lip_h) ## basılıyken yüz dudak kadar aşağı iner, toplam boy aynı
	var h: int = top + 6 + lip_h + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var lip: Color = fill.lerp(HT.ACCENT_DK, 0.7)
	var hi: Color = fill.lerp(HT.TEXT, 0.45)
	var y0: int = top - 2
	for y in range(y0, h):
		for x in w:
			var corner: bool = (x == 0 or x == w - 1) and (y == y0 or y == h - 1)
			if corner:
				continue
			var col: Color = fill
			if x == 0 or x == w - 1 or y == y0 or y == h - 1:
				col = HT.ACCENT_DK
			elif y >= h - 1 - lip_h:
				col = lip
			elif y == y0 + 1:
				col = hi
			img.set_pixel(x, y, col)
	img.resize(w * PX, h * PX, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 3 * PX
	sb.texture_margin_right = 3 * PX
	sb.texture_margin_top = (top + 1) * PX
	sb.texture_margin_bottom = (lip_h + 2) * PX
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = float(top) * PX
	sb.content_margin_bottom = float(lip_h + 1) * PX
	return sb


## ---------------------------------------------------------------- ortak
static func _l(k, t: String, fs: int, col: Color, shadow: bool) -> Label:
	var l: Label = k.lbl(t, fs, col)
	if not shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


static func _glyph(k, pat: Array, col: Color) -> Control:
	var g: Control = k.glyph(pat, col, 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return g


static func _dot(col: Color) -> Control:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(6, 6)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## shadow false: altın zemin üstünde (kitin Label gölgesi yazıyı kalın/çift gösteriyordu).
static func _price(k, r: HBoxContainer, e: Dictionary, col: Color, shadow: bool = false) -> void:
	var rows: Array = [k.amt(Market.price(e), 32, col)]
	var sh: int = Market.shards(e)
	if sh > 0:
		rows.append(k.amt(sh, 32, col, "shard"))
	for a: HBoxContainer in rows:
		if not shadow:
			(a.get_meta("label") as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		r.add_child(a)


static func _content(b: Button, row: Control) -> void:
	b.text = ""
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(row)
	b.add_child(cc)


static func _boxes(b: Button, normal: StyleBox, hover: StyleBox, pressed: StyleBox) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _tex_box(img: Image) -> StyleBoxTexture:
	var big: Image = img.duplicate()
	big.resize(img.get_width() * PX, img.get_height() * PX, Image.INTERPOLATE_NEAREST)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(big)
	for s: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(s, 0.0)
	return sb
