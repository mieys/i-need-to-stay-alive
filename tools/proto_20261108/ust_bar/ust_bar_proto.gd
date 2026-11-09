extends "res://scripts/overhead_bar.gd"

## KARAKTER ÜSTÜ CAN / KALKAN ÇUBUĞU görünüş prototipleri (2026-11-08, oyuna bağlı DEĞİL).
## Kullanıcı: "karakterin üstündeki can-kalkan barının tasarımını v.s bozmadan görünüşü için 4 yeni pixel art prototip".
## overhead_bar.gd'den türer, YALNIZ _draw ezilir: can dikdörtgeni (44 x 7), 2 boşluk, kalkan şeridi (44 x 5), CHARACTER_Y_OFFSET,
## 40 canda bir bölme çizgisi (_segment_line_offsets, en çok 20) ve "kalkan yoksa şerit yok" kuralı AYNI. Dış ayak izi en çok
## eskisi kadar (2 birimlik çerçeve). Hepsi draw_rect ile tam birimde (oyuncu kökü 0,5 x kamera 2 = 1 birim = 1080p'de 1 ekran px).
## Renkler hud_theme.gd rolleri: can yeşili = HudTheme.hp_color (dock çubuğuyla aynı, düşük canda amber/kırmızı), kalkan SHIELD_BAR.
##   A Pirinç Kapaklı : dock çubuğunun (madde 470) küçük eşi - iki uçta perçinli pirinç kapak, koyu kanal, 3 bantlı dolgu + sıvı yüzeyi.
##   B Ahşap Levha    : iki çubuk TEK ahşap levhada (Kısık Ahşap kenar, basamaklı köşe, aradaki boşluk ahşap ayraç).
##   C İnce Hat       : sade - 1 birim sıcak kontur, kesik köşe, yarı saydam boş kısım, çubuklar arası nefes (savaş karmaşası az).
##   D Kabartma Bölme : her 40 can bir kabartma taş/karo, boşlar oyuk yuva; kalkan tek kabartma plaka.

## HudTheme taban sınıftan (overhead_bar.gd, madde 502) gelir.

var proto_style: String = "A"


func _draw() -> void:
	var half_w: float = WIDTH * 0.5
	var hr := Rect2i(int(round(-half_w)), int(round(y_offset)), int(WIDTH), int(HEIGHT))
	var sr := Rect2i(hr.position.x, hr.position.y + int(HEIGHT + GAP), hr.size.x, int(round(HEIGHT * 0.72)))
	var hc: Color = _hp_col()
	var sc: Color = HudTheme.SHIELD_BAR
	match proto_style:
		"A":
			_a_bar(hr, health_ratio, hc, true)
			if show_shield:
				_a_bar(sr, shield_ratio, sc, false)
		"B":
			_b_plaque(hr, sr, hc, sc)
		"C":
			_c_bar(hr, health_ratio, hc, true)
			if show_shield:
				_c_bar(sr, shield_ratio, sc, false)
		"D":
			_d_bar(hr, health_ratio, hc, true)
			if show_shield:
				_d_bar(sr, shield_ratio, sc, false)


func _hp_col() -> Color:
	if health_color.is_equal_approx(HEALTH_COLOR_DEFAULT):
		return HudTheme.hp_color(health_ratio)
	return health_color


func _px(x: int, y: int, w: int, h: int, c: Color) -> void:
	if w > 0 and h > 0:
		draw_rect(Rect2(x, y, w, h), c)


func _fill_w(inner_w: int, ratio: float) -> int:
	if ratio <= 0.0:
		return 0
	return clampi(int(round(float(inner_w) * ratio)), 1, inner_w)


## Bölme çizgilerinin dolgu sol kenarına göre konumları (eski kuralın kendisi; genişlik prototipin iç dolgusu).
## Dar iç dolguda (A: 40 birim) 20 çizgi 1 birim arayla yapışıp düz blok olur -> aralık en az 2 birim kalacak kadar çizgi.
func _seg_offsets(inner_w: int) -> Array[float]:
	var n: int = mini(_segment_line_count(health_max), maxi(0, inner_w / 2 - 1))
	return _segment_line_offsets(float(inner_w), n)


# ---------------------------------------------------------------------------------------------------------------------------
# A - PİRİNÇ KAPAKLI: dock çubuğunun küçük eşi. Kapak 4 birim (kanadın taşan 2 birimi + iç 2 birim), kanal 1 birim kontur.
func _a_bar(r: Rect2i, ratio: float, col: Color, is_hp: bool) -> void:
	var x0: int = r.position.x
	var y0: int = r.position.y
	var w: int = r.size.x
	var h: int = r.size.y
	var cap: int = 4
	var ix: int = x0 + cap - 2 ## iç dolgu: kapakların arası
	var iw: int = w - (cap - 2) * 2
	# gölge (eski SHADOW_OFFSET gibi 1 birim sağ-alt)
	_px(x0 - 1, y0 + h + 1, w + 2, 1, Color(0, 0, 0, 0.35))
	# kanal: üst/alt 1 birim kontur + koyu kuyu
	_px(x0, y0 - 1, w, 1, HudTheme.OUTLINE)
	_px(x0, y0 + h, w, 1, HudTheme.OUTLINE)
	_px(ix, y0, iw, h, HudTheme.DOCK_INSET)
	_px(ix, y0, iw, 1, HudTheme.DEEP) ## kuyu içi üst gölge
	var fw: int = _fill_w(iw, ratio)
	if fw > 0:
		var hi: Color = col.lightened(0.32)
		var lo: Color = col.darkened(0.32)
		var band_hi: int = 1 if h <= 5 else 2
		_px(ix, y0, fw, h, col)
		_px(ix, y0, fw, band_hi, hi)
		_px(ix, y0 + h - 2, fw, 2 if h > 5 else 1, lo)
		if fw >= 3:
			_px(ix + fw - 1, y0, 1, h, col.lightened(0.5)) ## sıvı yüzeyi
	if is_hp:
		for off: float in _seg_offsets(iw):
			var sx: int = ix + int(off)
			var in_fill: bool = sx < ix + fw - 1
			_px(sx, y0 + 1, 1, h - 1, col.darkened(0.55) if in_fill else HudTheme.DOCK_MARK)
	# kapaklar: 4 birim geniş, çubuktan 1 birim taşar; kontur + pirinç tonları + perçin
	for side in [0, 1]:
		var cx: int = x0 - 2 if side == 0 else x0 + w - 2
		var cy: int = y0 - 1
		var ch: int = h + 2
		_px(cx, cy, cap, ch, HudTheme.OUTLINE)
		_px(cx + 1, cy + 1, cap - 2, ch - 2, HudTheme.SPOT)
		_px(cx + 1, cy + 1, cap - 2, 1, HudTheme.ACCENT) ## üst ışık
		_px(cx + 1, cy + ch - 2, cap - 2, 1, HudTheme.ACCENT_DK) ## alt gölge
		var lit_x: int = cx + 1 if side == 0 else cx + cap - 2
		_px(lit_x, cy + 2, 1, ch - 4, HudTheme.ACCENT) ## dış yüz ışığı
		var rv_x: int = cx + 2 if side == 0 else cx + 1
		_px(rv_x, cy + (ch >> 1), 1, 1, HudTheme.TEXT) ## perçin


# ---------------------------------------------------------------------------------------------------------------------------
# B - AHŞAP LEVHA: iki çubuk tek ahşap levhada. Levha = eski 2 birimlik çerçevenin yeri (1 kontur + 1 ahşap kenar), köşe basamaklı.
func _b_plaque(hr: Rect2i, sr: Rect2i, hc: Color, sc: Color) -> void:
	var x0: int = hr.position.x - 2
	var y0: int = hr.position.y - 2
	var w: int = hr.size.x + 4
	var bottom: int = (sr.end.y if show_shield else hr.end.y) + 2
	var h: int = bottom - y0
	# gölge
	_px(x0 + 2, y0 + h, w - 3, 1, Color(0, 0, 0, 0.35))
	_px(x0 + w, y0 + 2, 1, h - 2, Color(0, 0, 0, 0.35))
	# kontur (köşe pikseli boş = basamaklı köşe)
	_px(x0 + 1, y0, w - 2, h, HudTheme.OUTLINE)
	_px(x0, y0 + 1, w, h - 2, HudTheme.OUTLINE)
	# ahşap kenar: üst açık, yanlar orta, alt koyu
	_px(x0 + 1, y0 + 1, w - 2, h - 2, HudTheme.RIM)
	_px(x0 + 2, y0 + 1, w - 4, 1, HudTheme.RIM_HI)
	_px(x0 + 2, y0 + h - 2, w - 4, 1, HudTheme.RIM_LO)
	_b_well(hr, health_ratio, hc, true)
	if show_shield:
		# aradaki ahşap ayraç (2 birim): üst satır koyu oyuk gölgesi, alt satır açık
		_px(hr.position.x, hr.end.y, hr.size.x, 1, HudTheme.RIM_LO)
		_px(hr.position.x, hr.end.y + 1, hr.size.x, 1, HudTheme.RIM_HI)
		_b_well(sr, shield_ratio, sc, false)


func _b_well(r: Rect2i, ratio: float, col: Color, is_hp: bool) -> void:
	var x0: int = r.position.x
	var y0: int = r.position.y
	var w: int = r.size.x
	var h: int = r.size.y
	_px(x0, y0, w, h, HudTheme.INSET)
	_px(x0, y0, w, 1, HudTheme.DEEP) ## oyuk: üst kenar gölgede
	var fw: int = _fill_w(w, ratio)
	if fw > 0:
		_px(x0, y0, fw, h, col)
		_px(x0, y0, fw, 1, col.lightened(0.38))
		_px(x0, y0 + h - 1, fw, 1, col.darkened(0.3))
	if is_hp:
		for off: float in _seg_offsets(w):
			var sx: int = x0 + int(off)
			if sx < x0 + fw:
				_px(sx, y0 + 1, 1, h - 1, col.darkened(0.5))
			else:
				_px(sx, y0 + 1, 1, h - 1, HudTheme.STRIPE)


# ---------------------------------------------------------------------------------------------------------------------------
# C - İNCE HAT: 1 birim sıcak kontur (kesik köşe), boş kısım yarı saydam koyu, iki çubuk arasında 1 birim boşluk.
func _c_bar(r: Rect2i, ratio: float, col: Color, is_hp: bool) -> void:
	var x0: int = r.position.x
	var y0: int = r.position.y
	var w: int = r.size.x
	var h: int = r.size.y
	var out := Color(HudTheme.OUTLINE, 0.92)
	# 1 birim gölge yalnız altta
	_px(x0, y0 + h + 1, w, 1, Color(0, 0, 0, 0.28))
	# kontur, köşe pikselleri yok
	_px(x0, y0 - 1, w, 1, out)
	_px(x0, y0 + h, w, 1, out)
	_px(x0 - 1, y0, 1, h, out)
	_px(x0 + w, y0, 1, h, out)
	_px(x0, y0, w, h, Color(0.05, 0.03, 0.02, 0.74)) ## 0,55'te ağaç/çimen fazla sızıp boş kısım dolguyla karışıyordu
	var fw: int = _fill_w(w, ratio)
	if fw > 0:
		_px(x0, y0, fw, h, col)
		_px(x0, y0, fw, 1, col.lightened(0.3))
	if is_hp:
		for off: float in _seg_offsets(w):
			var sx: int = x0 + int(off)
			if sx < x0 + fw:
				_px(sx, y0 + 2, 1, h - 2, Color(col.darkened(0.6), 0.75)) ## LoL gibi: üstten kısa, yalnız dolguda


# ---------------------------------------------------------------------------------------------------------------------------
# D - KABARTMA BÖLME: 2 birimlik çerçeve (dış kontur + iç koyu), köşe yuvarlak pikselli; her 40 can = kabartma karo
# (sol/üst açık, sağ/alt koyu), aralar 1 birim derz; boş karolar oyuk yuva. Kalkan = tek kabartma plaka.
func _d_bar(r: Rect2i, ratio: float, col: Color, is_hp: bool) -> void:
	var x0: int = r.position.x
	var y0: int = r.position.y
	var w: int = r.size.x
	var h: int = r.size.y
	# gölge
	_px(x0 - 1, y0 + h + 2, w + 2, 1, Color(0, 0, 0, 0.35))
	# çerçeve: dış kontur köşesiz, iç DEEP
	_px(x0 - 1, y0 - 2, w + 2, h + 4, HudTheme.OUTLINE)
	_px(x0 - 2, y0 - 1, w + 4, h + 2, HudTheme.OUTLINE)
	_px(x0, y0, w, h, HudTheme.DEEP)
	# karolar: [başlangıç, bitiş) dolgu koordinatında
	var cuts: Array[int] = [0]
	if is_hp:
		for off: float in _seg_offsets(w):
			cuts.append(int(off))
	cuts.append(w)
	var fw: int = _fill_w(w, ratio)
	var hi: Color = col.lightened(0.35)
	var lo: Color = col.darkened(0.35)
	for i in range(cuts.size() - 1):
		var a: int = cuts[i] + (1 if i > 0 else 0) ## derz 1 birim (bölme çizgisinin yeri)
		var b: int = cuts[i + 1]
		var tw: int = b - a
		if tw <= 0:
			continue
		var tx: int = x0 + a
		var bevel_x: bool = tw >= 4 ## çok dar karoda yan kabartma gürültü olur -> yalnız üst/alt
		# boş yuva (oyuk): üst satır en koyu, alt satır hafif ışık
		_px(tx, y0, tw, h, HudTheme.INSET)
		_px(tx, y0, tw, 1, HudTheme.DEEP)
		_px(tx, y0 + h - 1, tw, 1, HudTheme.PLATE_ON)
		var fill_end: int = mini(b, fw)
		var fl: int = fill_end - a
		if fl <= 0:
			continue
		_px(tx, y0, fl, h, col)
		_px(tx, y0, fl, 1, hi)
		_px(tx, y0 + h - 1, fl, 1, lo)
		if bevel_x:
			_px(tx, y0 + 1, 1, h - 2, hi)
			if fill_end == b:
				_px(tx + tw - 1, y0 + 1, 1, h - 1, lo)
		if fill_end < b and fl >= 2:
			_px(tx + fl - 1, y0 + 1, 1, h - 2, col.lightened(0.5)) ## kırık karonun ucu: açık kesit
