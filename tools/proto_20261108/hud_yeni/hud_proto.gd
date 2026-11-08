extends Control

## OYUN İÇİ ARAYÜZ prototipleri (2026-11-08, oyuna bağlı DEĞİL). Kullanıcı: "oyun içi arayüzünü çok kalitesiz buluyorum yeni 4 prototip
## üretir misin. minimap, skill barı, altın miktarı envanter butonu v.s" + "kahverengi-bej tonlarında olması yeter" + eski arayüz
## simgelerinden (altın / çanta / elmas png) ilham alma ("bu ikonlar çok eski").
## hud_capture.gd gerçek SP oyununu açar, eski HUD'u gizler, bu Control'ü tam ekran kurar ve gerçek minimap düğümünü buraya taşır.
## Altın, parçacık, çanta, kalp, kalkan, stat simgeleri burada YENİ piksel haritası; yetenek/eşya simgeleri ve portreler oyunun içeriği.
## Her yön ayrı yerleşim + ayrı çizim eli (madde 443 dersi: küçük boyda da farklı görünmeli):
##   A Araç Çubuğu   - açık meşe, tek sıra alt araç çubuğu, sağ altta dikey can/kalkan, sağ üstte harita + rakam hücreli kese
##   B Üst Kuşak     - koyu ceviz, kutusuz yarı saydam yuvalar, her şey üstte (sol: yetenek/eşya/para, sağ: çubuklar/harita/grup)
##   C Kartlar       - parşömen bej kabartmalı kartlar: sol altta karakter kartı, ortada ayrı yetenek taşları, sağ altta harita kartı
##   D Kütük Kiriş   - ekran boyu kütük kiriş, oyuk yuvalar, sağ uçta kirişten yükselen yuvarlak harita penceresi

const PixelBox := preload("res://scripts/pixel_box.gd")
const P := 3.0
const F: Font = preload("res://assets/fonts/m5x7.ttf")
const N: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")

## --- Ortak: anlamlı renkler (çubuk dolguları) ---
const HP_COLS := [Color("#c4e69a"), Color("#86c050"), Color("#567f2e")]
const SH_COLS := [Color("#acd6f6"), Color("#5a9edc"), Color("#33689e")]
const XP_COLS := [Color("#ffe6a6"), Color("#f0c070"), Color("#b48038")]
const CREAM := Color("#f3e6cc")
const DEEP := Color("#140e09")

## --- A: açık meşe (Stardew araç çubuğu dili) ---
const A_OUT := Color("#2e1b0c")
const A_HI := Color("#dcab72")
const A_MID := Color("#b9824c")
const A_LO := Color("#8a5a30")
const A_DK := Color("#5c3a1c")
const A_WELL := Color("#efd8aa")
const A_WELL_SH := Color("#cfae7a")
const A_WELL_LIP := Color("#fbecc8")
const A_INK := Color("#4a2e16")
const A_GROOVE := Color("#3a2412")

## --- B: koyu ceviz, yarı saydam (Terraria köşe dili) ---
const B_FILL := Color(0.11, 0.075, 0.045, 0.74)
const B_FILL_SOLID := Color(0.11, 0.075, 0.045, 0.86)
const B_RIM := Color("#8d6c4a")
const B_RIM_HI := Color("#c7a67c")
const B_RIM_DK := Color("#4e3622")
const B_TEXT := Color("#f3e6cc")
const B_DIM := Color("#cdb895")
const B_GOLD := Color("#f6d27e")

## --- C: parşömen bej kart (piksel kutu kabartma) ---
const C_BG := Color("#e4cc9c")
const C_BORDER := Color("#5a3c22")
const C_WELL := Color("#c9ab78")
const C_WELL_SH := Color("#a88a5a")
const C_DARK := Color("#3a2617")
const C_INK := Color("#3a2617")
const C_INK2 := Color("#7a5a38")

## --- D: kütük kiriş ---
const D_BARK := Color("#36210f")
const D_BARK_HI := Color("#5a3a1e")
const D_WOOD := Color("#7a4e2a")
const D_WOOD_HI := Color("#94653a")
const D_GRAIN := Color("#653f20")
const D_GRAIN_HI := Color("#aa7b4a")
const D_END := Color("#d6ad78")
const D_END_RING := Color("#b08250")
const D_END_CORE := Color("#8e6238")
const D_SOCKET := Color("#21140a")
const D_SOCKET_SH := Color("#140c06")
const D_LIP := Color("#b0804e")
const D_BRASS := Color("#dcae5e")
const D_BRASS_HI := Color("#f6d68e")
const D_BRASS_DK := Color("#7a5624")
const D_INK := Color("#2a180b")

## --- Piksel simgeler (yeni; eski png'ler kullanılmaz). "." boş, "o" dış hat. ---
const COIN := ["..oooooo..", ".o1w1122o.", "o1w122223o", "o11224223o", "o12224223o", "o12224223o", "o12224233o",
	"o22222333o", ".o233333o.", "..oooooo.."]
const COIN_PAL := {"o": Color("#2e1b0c"), "w": Color("#fff4d0"), "1": Color("#ffe08a"), "2": Color("#f0b848"), "3": Color("#c07a28"),
	"4": Color("#8a5218")}
const SHARD := ["....oo..", "...o1wo.", "..o112o.", "..o1223o", ".o11223o", ".o12233o", "o112233o", "o12233o.", "o2233o..",
	".o33o...", "..oo...."]
const SHARD_PAL := {"o": Color("#2e1b0c"), "w": Color("#ffffff"), "1": Color("#d8f0fc"), "2": Color("#8cc4e8"), "3": Color("#4a7fae")}
const BAG := ["...oooooo...", "..o......o..", "..o......o..", ".oooooooooo.", "o1111111112o", "o1222222223o", "ooooo44ooooo",
	"o1222442223o", "o1222222223o", "o2333333333o", ".oooooooooo."]
const BAG_PAL := {"o": Color("#2e1b0c"), "1": Color("#e8c48c"), "2": Color("#c08a50"), "3": Color("#8a5a30"), "4": Color("#f6d27e")}
const HEART := [".oo...oo.", "o1wo.o22o", "o1222223o", "o2222223o", ".o22223o.", "..o223o..", "...o3o...", "....o...."]
const HEART_PAL := {"o": Color("#2e1b0c"), "w": Color("#fff0e0"), "1": Color("#f49a9a"), "2": Color("#d8434e"), "3": Color("#8e2230")}
const HEART_EMPTY_PAL := {"o": Color("#2e1b0c"), "w": Color("#5a4232"), "1": Color("#5a4232"), "2": Color("#46321f"), "3": Color("#372617")}
const SHIELD := ["ooooooooo", "o1w12223o", "o1112223o", "o1112223o", "o1112223o", ".o11223o.", ".o11233o.", "..o123o..", "...o3o...",
	"....o...."]
const SHIELD_PAL := {"o": Color("#2e1b0c"), "w": Color("#ffffff"), "1": Color("#a8d4f4"), "2": Color("#4f94d4"), "3": Color("#2f5f96")}
## Stat simgesi: üç yükselen sütun (kalem/parşömen yerine en okunur kısa biçim).
const STAT := ["........ooo", "........o1o", "....ooo.o1o", "....o1o.o1o", "ooo.o1o.o1o", "o1o.o1o.o1o", "o2o.o2o.o2o", "ooo.ooo.ooo"]
const STAT_PAL := {"o": Color("#2e1b0c"), "1": Color("#f0d49a"), "2": Color("#c49a5a")}
## Görev simgesi: küçük bayrak.
const FLAG := ["oo......", "o1oooo..", "o12221o.", "o122221o", "o12222o.", "o1oooo..", "o1o.....", "o1o.....", "ooo....."]
const FLAG_PAL := {"o": Color("#2e1b0c"), "1": Color("#c8a070"), "2": Color("#d8574a")}

## Köşe basamakları (sanat pikseli): satır başına içe girinti.
const PROF := {0: [], 1: [1], 2: [2, 1], 3: [3, 1, 1], 4: [4, 2, 1, 1]}


class Layer extends Control:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


var style: String = "A"
var d: Dictionary = {}
var g: Dictionary = {} ## yerleşim (build sırasında hesaplanır, çizimde okunur)
var _icons: Control
var _front: Layer


func setup(st: String, data: Dictionary) -> void:
	style = st
	d = data
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icons = Control.new()
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.size = size
	add_child(_icons)
	match style:
		"A": _build_a()
		"B": _build_b()
		"C": _build_c()
		"D": _build_d()
	_front = Layer.new()
	_front.size = size
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.fn = Callable(self, "_front_" + style.to_lower())
	add_child(_front)
	queue_redraw()


func _draw() -> void:
	call("_back_" + style.to_lower())


# ============================================================================================================================
# Ortak yardımcılar
# ============================================================================================================================

func rr(ci: CanvasItem, r: Rect2, c: Color, k: int = 1) -> void:
	var prof: Array = PROF[clampi(k, 0, 4)]
	var n: int = prof.size()
	if n == 0 or r.size.y < 2.0 * n * P:
		ci.draw_rect(r, c)
		return
	for i in n:
		var ins: float = float(prof[i]) * P
		ci.draw_rect(Rect2(r.position.x + ins, r.position.y + i * P, r.size.x - 2.0 * ins, P), c)
		ci.draw_rect(Rect2(r.position.x + ins, r.end.y - (i + 1) * P, r.size.x - 2.0 * ins, P), c)
	ci.draw_rect(Rect2(r.position.x, r.position.y + n * P, r.size.x, r.size.y - 2.0 * n * P), c)


func pix(ci: CanvasItem, rows: Array, pos: Vector2, pal: Dictionary, px: float = P) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == "." or not pal.has(ch):
				continue
			ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), pal[ch])


func pix_size(rows: Array, px: float = P) -> Vector2:
	var w: int = 0
	for row in rows:
		w = maxi(w, (row as String).length())
	return Vector2(w, rows.size()) * px


func pix_c(ci: CanvasItem, rows: Array, r: Rect2, pal: Dictionary, px: float = P) -> void:
	var s: Vector2 = pix_size(rows, px)
	pix(ci, rows, (r.position + (r.size - s) * 0.5).snapped(Vector2(px, px)), pal, px)


func tw(s: String, size: int, font: Font = F) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Yazı: pos = sol üst köşe (taban çizgisi ascent ile bulunur). sh = gölge (aşağı 1 yazı pikseli), out = 4 yönlü kontur.
func txt(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, font: Font = F, sh: Color = Color(0, 0, 0, 0),
		out: Color = Color(0, 0, 0, 0)) -> void:
	var fpx: float = maxf(1.0, round(size / 16.0)) if font == F else maxf(1.0, round(size / 9.0))
	var base: Vector2 = Vector2(round(pos.x), round(pos.y + _cap_top(size, font)))
	if out.a > 0.0:
		for o in [Vector2(-fpx, 0), Vector2(fpx, 0), Vector2(0, -fpx), Vector2(0, fpx), Vector2(-fpx, fpx), Vector2(fpx, fpx)]:
			ci.draw_string(font, base + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, out)
	if sh.a > 0.0:
		ci.draw_string(font, base + Vector2(0, fpx), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, sh)
	ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Büyük harf yüksekliği ölçümü (m5x7: 7 yazı pikseli, Pixeloid: 7) -> sol üstten taban çizgisine.
func _cap_top(size: int, font: Font) -> float:
	var fpx: float = round(size / 16.0) if font == F else round(size / 9.0)
	return 7.0 * maxf(fpx, 1.0)


func cap_h(size: int, font: Font = F) -> float:
	return _cap_top(size, font)


## Dikdörtgende ortalı yazı (büyük harf yüksekliğine göre).
func txt_c(ci: CanvasItem, r: Rect2, s: String, size: int, col: Color, font: Font = F, sh: Color = Color(0, 0, 0, 0),
		out: Color = Color(0, 0, 0, 0)) -> void:
	var w: float = tw(s, size, font)
	var h: float = cap_h(size, font)
	txt(ci, Vector2(round(r.position.x + (r.size.x - w) * 0.5), round(r.position.y + (r.size.y - h) * 0.5)), s, size, col, font, sh, out)


func txt_r(ci: CanvasItem, right_top: Vector2, s: String, size: int, col: Color, font: Font = F, sh: Color = Color(0, 0, 0, 0),
		out: Color = Color(0, 0, 0, 0)) -> void:
	txt(ci, Vector2(right_top.x - tw(s, size, font), right_top.y), s, size, col, font, sh, out)


## Yatay çubuk: dış hat + kuyu + dolgu (üstte ışık, altta gölge sanat pikseli).
func hbar(ci: CanvasItem, r: Rect2, ratio: float, cols: Array, well: Color, edge: Color, k: int = 1) -> void:
	rr(ci, r, edge, k)
	var inner: Rect2 = r.grow(-P)
	ci.draw_rect(inner, well)
	var fw: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0) / P) * P
	if fw <= 0.0:
		return
	var f := Rect2(inner.position, Vector2(fw, inner.size.y))
	ci.draw_rect(f, cols[1])
	ci.draw_rect(Rect2(f.position, Vector2(fw, P)), cols[0])
	if f.size.y >= 3.0 * P:
		ci.draw_rect(Rect2(f.position.x, f.end.y - P, fw, P), cols[2])
	ci.draw_rect(Rect2(f.end.x - P, f.position.y, P, f.size.y), cols[2])


func vbar(ci: CanvasItem, r: Rect2, ratio: float, cols: Array, well: Color, edge: Color) -> void:
	ci.draw_rect(r, edge)
	var inner: Rect2 = r.grow(-P)
	ci.draw_rect(inner, well)
	var fh: float = floorf(inner.size.y * clampf(ratio, 0.0, 1.0) / P) * P
	if fh <= 0.0:
		return
	var f := Rect2(inner.position.x, inner.end.y - fh, inner.size.x, fh)
	ci.draw_rect(f, cols[1])
	ci.draw_rect(Rect2(f.position, Vector2(P, fh)), cols[0])
	ci.draw_rect(Rect2(f.end.x - P, f.position.y, P, fh), cols[2])
	ci.draw_rect(Rect2(f.position, Vector2(f.size.x, P)), cols[0])


## Doku: küçük piksel dokular tam katla (büyütme ya da tam bölünen küçültme) en yakın komşu, büyük boyalı simgeler yumuşak.
func tex(t: Texture2D, r: Rect2, modulate_col: Color = Color.WHITE) -> void:
	if t == null:
		return
	var tr := TextureRect.new()
	tr.texture = t
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate = modulate_col
	var ts: Vector2 = t.get_size()
	var rect: Rect2 = r
	var m: float = maxf(ts.x, ts.y)
	var room: float = minf(r.size.x, r.size.y)
	if m <= room:
		var k: float = floorf(room / m)
		var sz: Vector2 = ts * k
		rect = Rect2((r.position + (r.size - sz) * 0.5).round(), sz)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		var div: float = ceilf(m / room)
		if m <= 512.0 and is_equal_approx(fmod(ts.x, div), 0.0) and is_equal_approx(fmod(ts.y, div), 0.0):
			var sz2: Vector2 = ts / div
			rect = Rect2((r.position + (r.size - sz2) * 0.5).round(), sz2)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			var f: float = room / m
			var sz3: Vector2 = (ts * f).round()
			rect = Rect2((r.position + (r.size - sz3) * 0.5).round(), sz3)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.position = rect.position
	tr.size = rect.size
	_icons.add_child(tr)


func _skills() -> Array:
	return d.get("skills", [])


func _place_minimap(pos: Vector2, scale_k: float, square: bool) -> void:
	var mm: Control = d.get("minimap") as Control
	if mm == null:
		return
	if mm.get_parent():
		mm.get_parent().remove_child(mm)
	add_child(mm)
	mm.set("square", square)
	mm.scale = Vector2(scale_k, scale_k)
	## Minimap'in haritası (2,2)'den başlar (çerçeve payı) -> ölçekle birlikte geri kaydır.
	mm.position = pos - Vector2(2, 2) * scale_k
	mm.queue_redraw()


func _cd_overlay(ci: CanvasItem, r: Rect2, s: Dictionary, col: Color, text_col: Color, size: int = 27) -> void:
	var cd: float = float(s.get("cd", 0.0))
	if cd <= 0.0:
		return
	var ratio: float = float(s.get("cd_ratio", 0.5))
	var h: float = floorf(r.size.y * ratio / P) * P
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, h)), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + h, r.size.x, r.size.y - h), Color(col, col.a * 0.45))
	txt_c(ci, r, str(int(ceil(cd))), size, text_col, N, DEEP)


func _money_str(v: int) -> String:
	var s: String = str(v)
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


# ============================================================================================================================
# A - ARAÇ ÇUBUĞU (açık meşe)
# ============================================================================================================================

func _box_a(ci: CanvasItem, r: Rect2, k: int = 2) -> void:
	rr(ci, r, A_OUT, k)
	var inner: Rect2 = r.grow(-P)
	rr(ci, inner, A_LO, k - 1)
	rr(ci, Rect2(inner.position, inner.size - Vector2(P, P)), A_HI, k - 1)
	rr(ci, Rect2(inner.position + Vector2(P, P), inner.size - Vector2(2 * P, 2 * P)), A_MID, maxi(k - 2, 0))


func _well_a(ci: CanvasItem, r: Rect2) -> void:
	rr(ci, r, A_DK, 1)
	var inner: Rect2 = r.grow(-P)
	ci.draw_rect(inner, A_WELL_LIP)
	ci.draw_rect(Rect2(inner.position, inner.size - Vector2(P, P)), A_WELL_SH)
	ci.draw_rect(Rect2(inner.position + Vector2(P, P), inner.size - Vector2(2 * P, 2 * P)), A_WELL)


func _build_a() -> void:
	var S: float = 66.0
	var GAP: float = 3.0
	var SEP: float = 15.0
	var PAD: float = 12.0
	var seq: Array = ["portrait", 0, 1, 2, 3, "sep", 4, "sep", "i0", "i1", "i2", "i3", "i4", "sep", "pet"]
	var cells: Array = []
	var seps: Array = []
	var x: float = 0.0
	var prev_slot: bool = false
	for e in seq:
		if typeof(e) == TYPE_STRING and e == "sep":
			seps.append(x + SEP * 0.5 - P * 0.5)
			x += SEP
			prev_slot = false
			continue
		if prev_slot:
			x += GAP
		cells.append({"id": e, "x": x})
		x += S
		prev_slot = true
	var w: float = x + 2.0 * PAD
	var h: float = PAD + S + 9.0 + 12.0 + PAD
	var tb := Rect2(floorf((1920.0 - w) * 0.5 / P) * P, 1080.0 - 15.0 - h, w, h)
	g["tb"] = tb
	g["S"] = S
	var rects: Array = []
	for c in cells:
		var r := Rect2(tb.position.x + PAD + float(c["x"]), tb.position.y + PAD, S, S)
		rects.append({"id": c["id"], "r": r})
	g["cells"] = rects
	var sx: Array = []
	for s in seps:
		sx.append(tb.position.x + PAD + float(s))
	g["seps"] = sx
	g["xp"] = Rect2(tb.position.x + PAD, tb.position.y + PAD + S + 9.0, w - 2.0 * PAD, 12.0)
	## Simgeler
	var sk: Array = _skills()
	var items: Array = d.get("items", [])
	for c in rects:
		var id = c["id"]
		var r: Rect2 = (c["r"] as Rect2).grow(-9.0)
		if typeof(id) == TYPE_INT:
			tex(sk[id].get("tex"), r)
		elif id == "portrait":
			tex(d.get("portrait"), Rect2(r.position - Vector2(3, 6), Vector2(54, 54)))
		elif id == "pet":
			tex(d.get("pet"), r)
		elif String(id).begins_with("i"):
			var ii: int = int(String(id).substr(1))
			if ii < items.size():
				tex(items[ii], r)
	## Sağ alt: dikey çubuklar + kalp sütunu
	g["sh_bar"] = Rect2(1920.0 - 15.0 - 48.0, 1080.0 - 15.0 - 264.0, 48.0, 264.0)
	g["hp_bar"] = Rect2(g["sh_bar"].position.x - 9.0 - 48.0, g["sh_bar"].position.y, 48.0, 264.0)
	g["hearts"] = Rect2(g["hp_bar"].position.x - 9.0 - 69.0, 1080.0 - 15.0 - 138.0, 69.0, 138.0)
	## Sağ üst: harita + kese + düğmeler
	var mf := Rect2(1920.0 - 15.0 - 186.0, 15.0, 186.0, 186.0)
	g["map"] = mf
	_place_minimap(mf.position + Vector2(13, 13), 1.0, true)
	g["purse"] = Rect2(mf.position.x, mf.end.y + 6.0, 186.0, 60.0)
	var row_y: float = mf.end.y + 6.0 + 60.0 + 6.0
	g["shard"] = Rect2(mf.position.x, row_y, 84.0, 54.0)
	g["bag"] = Rect2(mf.position.x + 84.0 + 6.0, row_y, 48.0, 54.0)
	g["stat"] = Rect2(mf.position.x + 84.0 + 6.0 + 48.0 + 6.0, row_y, 42.0, 54.0)
	## Sol üst: grup + görev
	var allies: Array = d.get("allies", [])
	var party: Array = []
	for i in allies.size():
		var r2 := Rect2(15.0, 15.0 + i * 78.0, 336.0, 72.0)
		party.append(r2)
		tex(allies[i].get("portrait"), Rect2(r2.position + Vector2(12, 12), Vector2(48, 48)))
	g["party"] = party
	var py: float = 15.0 + allies.size() * 78.0
	g["dmg_btn"] = Rect2(15.0, py, 111.0, 39.0)
	g["mission"] = Rect2(15.0, py + 45.0, 336.0, 72.0)


func _back_a() -> void:
	var tb: Rect2 = g["tb"]
	_box_a(self, tb, 3)
	for c in g["cells"]:
		_well_a(self, c["r"])
	for sx in g["seps"]:
		var top: float = tb.position.y + 12.0
		draw_rect(Rect2(sx, top, P, 66.0), A_LO)
		draw_rect(Rect2(sx + P, top, P, 66.0), A_HI)
	hbar(self, g["xp"], float(d.get("xp_ratio", 0.6)), XP_COLS, A_GROOVE, A_DK, 0)
	## dikey çubuklar
	for key in ["hp_bar", "sh_bar"]:
		var r: Rect2 = g[key]
		_box_a(self, r, 2)
		var well := Rect2(r.position.x + 12.0, r.position.y + 45.0, r.size.x - 24.0, r.size.y - 57.0)
		var ratio: float = float(d["hp"]) / float(d["hp_max"]) if key == "hp_bar" else float(d["sh"]) / float(d["sh_max"])
		vbar(self, well, ratio, HP_COLS if key == "hp_bar" else SH_COLS, A_GROOVE, A_DK)
	_box_a(self, g["hearts"], 2)
	## harita + kese
	_box_a(self, g["map"], 2)
	draw_rect((g["map"] as Rect2).grow(-10.0), A_DK)
	_box_a(self, g["purse"], 2)
	_box_a(self, g["shard"], 2)
	_box_a(self, g["bag"], 2)
	_box_a(self, g["stat"], 2)
	## grup + görev
	for r in g["party"]:
		_box_a(self, r, 2)
		_well_a(self, Rect2(r.position + Vector2(9, 9), Vector2(54, 54)))
	_box_a(self, g["dmg_btn"], 2)
	_box_a(self, g["mission"], 2)


func _front_a(ci: CanvasItem) -> void:
	var sk: Array = _skills()
	for c in g["cells"]:
		var id = c["id"]
		var r: Rect2 = c["r"]
		if typeof(id) == TYPE_INT:
			var s: Dictionary = sk[id]
			_cd_overlay(ci, r.grow(-P), s, Color(0.18, 0.11, 0.05, 0.62), CREAM)
			var key: String = str(s.get("key", ""))
			if key != "":
				var kr := Rect2(r.end.x - 24.0, r.end.y - 27.0, 24.0, 27.0)
				rr(ci, kr, A_OUT, 1)
				rr(ci, kr.grow(-P), A_DK, 0)
				txt_c(ci, kr, key, 32, A_WELL)
		elif id == "portrait":
			var lr := Rect2(r.end.x - 33.0, r.end.y - 24.0, 36.0, 27.0)
			rr(ci, lr, A_OUT, 1)
			rr(ci, lr.grow(-P), A_LO, 1)
			txt_c(ci, lr, str(d.get("level", 1)), 18, A_WELL, N, A_OUT)
		elif typeof(id) == TYPE_STRING and String(id).begins_with("i") and int(String(id).substr(1)) >= (d.get("items", []) as Array).size():
			rr(ci, Rect2(r.get_center() - Vector2(6, 6), Vector2(12, 12)), A_WELL_SH, 1)
	## çubuk başlıkları + sayılar
	for key in ["hp_bar", "sh_bar"]:
		var r: Rect2 = g[key]
		var cap := Rect2(r.position.x, r.position.y + 9.0, r.size.x, 33.0)
		if key == "hp_bar":
			pix_c(ci, HEART, cap, HEART_PAL)
		else:
			pix_c(ci, SHIELD, cap, SHIELD_PAL)
		var val: String = str(int(d["hp"])) if key == "hp_bar" else str(int(d["sh"]))
		var vr := Rect2(r.position.x - 3.0, r.position.y - 33.0, r.size.x + 6.0, 30.0)
		rr(ci, vr, A_OUT, 1)
		rr(ci, vr.grow(-P), A_DK, 1)
		txt_c(ci, vr, val, 18, CREAM, N, A_OUT)
	## kalpler
	var hr: Rect2 = g["hearts"]
	var full: int = int(d.get("hearts", 3))
	for i in 3:
		var p := Vector2(hr.position.x + 21.0, hr.position.y + 12.0 + i * 30.0)
		pix(ci, HEART, p, HEART_PAL if i < full else HEART_EMPTY_PAL)
	var tr := Rect2(hr.position.x + 6.0, hr.end.y - 39.0, hr.size.x - 12.0, 30.0)
	rr(ci, tr, A_DK, 1)
	txt_c(ci, tr, str(d.get("heart_timer", "-:--")), 32, A_WELL)
	## kese: altın simgesi + rakam hücreleri
	var pr: Rect2 = g["purse"]
	pix(ci, COIN, Vector2(pr.position.x + 12.0, pr.position.y + 15.0), COIN_PAL)
	var digits: String = str(int(d.get("gold", 0))).lpad(5, "0")
	var cw: float = 24.0
	var x0: float = pr.end.x - 12.0 - 5.0 * cw - 4.0 * 3.0
	var lead: bool = true
	for i in 5:
		var cr := Rect2(x0 + i * (cw + 3.0), pr.position.y + 12.0, cw, 36.0)
		_well_a(ci, cr)
		var ch: String = digits[i]
		if ch != "0":
			lead = false
		txt_c(ci, cr, ch, 18, A_WELL_SH if (lead and i < 4) else A_INK, N)
	## parçacık + çanta + stat
	var sr: Rect2 = g["shard"]
	pix(ci, SHARD, Vector2(sr.position.x + 12.0, sr.position.y + 9.0), SHARD_PAL)
	txt(ci, Vector2(sr.position.x + 45.0, sr.position.y + 16.0), str(d.get("shards", 0)), 27, CREAM, N, A_OUT)
	pix_c(ci, BAG, (g["bag"] as Rect2).grow(-3.0), BAG_PAL)
	var bk := Rect2((g["bag"] as Rect2).end.x - 18.0, (g["bag"] as Rect2).end.y - 21.0, 21.0, 24.0)
	rr(ci, bk, A_OUT, 1)
	rr(ci, bk.grow(-P), A_DK, 0)
	txt_c(ci, bk, "I", 32, A_WELL)
	pix_c(ci, STAT, g["stat"], STAT_PAL)
	## grup
	var allies: Array = d.get("allies", [])
	for i in allies.size():
		var r: Rect2 = g["party"][i]
		var a: Dictionary = allies[i]
		txt(ci, Vector2(r.position.x + 75.0, r.position.y + 12.0), str(a["name"]), 32, CREAM, F, A_OUT)
		hbar(ci, Rect2(r.position.x + 75.0, r.position.y + 33.0, 246.0, 18.0), float(a["hp"]) / float(a["hp_max"]), HP_COLS, A_GROOVE, A_OUT, 0)
		hbar(ci, Rect2(r.position.x + 75.0, r.position.y + 51.0, 246.0, 12.0), float(a["sh"]) / maxf(1.0, float(a["sh_max"])), SH_COLS, A_GROOVE, A_OUT, 0)
	txt_c(ci, g["dmg_btn"], "HASAR", 32, CREAM, F, A_OUT)
	var mr: Rect2 = g["mission"]
	pix(ci, FLAG, Vector2(mr.position.x + 15.0, mr.position.y + 18.0), FLAG_PAL)
	txt(ci, Vector2(mr.position.x + 54.0, mr.position.y + 12.0), str(d["mission"]["title"]), 32, CREAM, F, A_OUT)
	txt_r(ci, Vector2(mr.end.x - 15.0, mr.position.y + 12.0), "%d/%d" % [int(d["mission"]["cur"]), int(d["mission"]["max"])], 32, A_WELL, F, A_OUT)
	var segs: int = int(d["mission"]["max"])
	var sw: float = floorf((mr.size.x - 69.0 - 3.0 * (segs - 1)) / segs / P) * P
	for i in segs:
		var segr := Rect2(mr.position.x + 54.0 + i * (sw + 3.0), mr.position.y + 39.0, sw, 18.0)
		hbar(ci, segr, 1.0 if i < int(d["mission"]["cur"]) else 0.0, XP_COLS, A_GROOVE, A_OUT, 0)


# ============================================================================================================================
# B - ÜST KUŞAK (koyu ceviz, kutusuz yarı saydam yuvalar)
# ============================================================================================================================

func _slot_b(ci: CanvasItem, r: Rect2, hot: bool = false) -> void:
	rr(ci, r, B_RIM_HI if hot else B_RIM, 2)
	rr(ci, r.grow(-P), B_FILL, 1)
	ci.draw_rect(Rect2(r.position.x + 2 * P, r.end.y - 2 * P, r.size.x - 4 * P, P), Color(B_RIM_DK, 0.8))


func _build_b() -> void:
	var sk: Array = _skills()
	var slots: Array = []
	for i in sk.size():
		var r := Rect2(15.0 + i * 78.0, 54.0, 72.0, 72.0)
		slots.append(r)
		tex(sk[i].get("tex"), r.grow(-12.0))
	g["slots"] = slots
	var items: Array = d.get("items", [])
	var irs: Array = []
	for i in 5:
		var r2 := Rect2(15.0 + i * 57.0, 138.0, 54.0, 54.0)
		irs.append(r2)
		if i < items.size():
			tex(items[i], r2.grow(-3.0))
	g["items"] = irs
	g["pet"] = Rect2(15.0 + 5 * 57.0 + 12.0, 138.0, 54.0, 54.0)
	tex(d.get("pet"), (g["pet"] as Rect2).grow(-6.0))
	g["money_y"] = 207.0
	g["bag"] = Rect2(15.0, 249.0, 63.0, 54.0)
	g["stat"] = Rect2(84.0, 249.0, 54.0, 54.0)
	## sağ üst
	g["hp"] = Rect2(1920.0 - 15.0 - 375.0, 48.0, 375.0, 27.0)
	g["sh"] = Rect2(1920.0 - 15.0 - 375.0, 84.0, 375.0, 24.0)
	var mf := Rect2(1920.0 - 15.0 - 252.0, 150.0, 252.0, 252.0)
	g["map"] = mf
	_place_minimap(mf.position + Vector2(6, 6), 1.5, true)
	var allies: Array = d.get("allies", [])
	var party: Array = []
	for i in allies.size():
		var r3 := Rect2(1920.0 - 15.0 - 300.0, mf.end.y + 12.0 + i * 66.0, 300.0, 60.0)
		party.append(r3)
		tex(allies[i].get("portrait"), Rect2(r3.position + Vector2(6, 6), Vector2(48, 48)))
	g["party"] = party
	g["mission_y"] = mf.end.y + 12.0 + allies.size() * 66.0 + 6.0


func _back_b() -> void:
	for i in (g["slots"] as Array).size():
		_slot_b(self, g["slots"][i], i == 1)
	for r in g["items"]:
		_slot_b(self, r)
	_slot_b(self, g["pet"])
	_slot_b(self, g["bag"])
	_slot_b(self, g["stat"])
	rr(self, g["map"], B_RIM, 2)
	rr(self, (g["map"] as Rect2).grow(-P), B_FILL_SOLID, 1)
	for r in g["party"]:
		rr(self, r, Color(B_RIM, 0.0), 1)
		rr(self, r, B_FILL, 2)
		_slot_b(self, Rect2(r.position + Vector2(3, 3), Vector2(54, 54)))
	## ekran dibi XP şeridi (bugünkü yer, B'de seviye adın yanında)
	draw_rect(Rect2(0, 1068, 1920, 12), Color(B_FILL_SOLID, 0.9))
	var xw: float = floorf(1920.0 * float(d.get("xp_ratio", 0.6)) / P) * P
	draw_rect(Rect2(0, 1071, xw, 9), XP_COLS[1])
	draw_rect(Rect2(0, 1071, xw, 3), XP_COLS[0])


func _front_b(ci: CanvasItem) -> void:
	var sk: Array = _skills()
	## ad + seviye
	txt(ci, Vector2(18, 15), str(d.get("name", "")), 32, B_TEXT, F, Color(0, 0, 0, 0), DEEP)
	txt(ci, Vector2(24 + tw(str(d.get("name", "")), 32), 15), "Seviye %d" % int(d.get("level", 1)), 32, B_GOLD, F, Color(0, 0, 0, 0), DEEP)
	for i in sk.size():
		var r: Rect2 = g["slots"][i]
		var s: Dictionary = sk[i]
		_cd_overlay(ci, r.grow(-2 * P), s, Color(0.06, 0.04, 0.02, 0.6), B_TEXT)
		var key: String = str(s.get("key", ""))
		if key != "":
			txt(ci, r.position + Vector2(9, 6), key, 32, B_TEXT, F, Color(0, 0, 0, 0), DEEP)
	for i in (g["items"] as Array).size():
		if i >= (d.get("items", []) as Array).size():
			var r2: Rect2 = g["items"][i]
			rr(ci, Rect2(r2.get_center() - Vector2(6, 6), Vector2(12, 12)), Color(B_RIM, 0.45), 1)
	## para satırı (kutusuz, konturlu yazı)
	var my: float = g["money_y"]
	pix(ci, COIN, Vector2(18, my), COIN_PAL)
	txt(ci, Vector2(57, my + 6.0), _money_str(int(d.get("gold", 0))), 18, B_GOLD, N, Color(0, 0, 0, 0), DEEP)
	var sx: float = 57.0 + tw(_money_str(int(d.get("gold", 0))), 18, N) + 24.0
	pix(ci, SHARD, Vector2(sx, my - 3.0), SHARD_PAL)
	txt(ci, Vector2(sx + 30.0, my + 6.0), str(d.get("shards", 0)), 18, Color("#cfe9f7"), N, Color(0, 0, 0, 0), DEEP)
	pix_c(ci, BAG, Rect2((g["bag"] as Rect2).position + Vector2(0, -3), (g["bag"] as Rect2).size), BAG_PAL)
	txt(ci, (g["bag"] as Rect2).position + Vector2(45, 30), "I", 32, B_TEXT, F, Color(0, 0, 0, 0), DEEP)
	pix_c(ci, STAT, g["stat"], STAT_PAL)
	## can / kalkan
	var hp: Rect2 = g["hp"]
	var sh: Rect2 = g["sh"]
	txt_r(ci, Vector2(hp.end.x, 15), "Can %d/%d" % [int(d["hp"]), int(d["hp_max"])], 32, B_TEXT, F, Color(0, 0, 0, 0), DEEP)
	pix(ci, HEART, Vector2(hp.position.x - 36.0, hp.position.y + 3.0), HEART_PAL)
	hbar(ci, hp, float(d["hp"]) / float(d["hp_max"]), HP_COLS, B_FILL_SOLID, B_RIM, 1)
	pix(ci, SHIELD, Vector2(sh.position.x - 36.0, sh.position.y - 3.0), SHIELD_PAL)
	hbar(ci, sh, float(d["sh"]) / float(d["sh_max"]), SH_COLS, B_FILL_SOLID, B_RIM, 1)
	txt_c(ci, sh, "%d/%d" % [int(d["sh"]), int(d["sh_max"])], 18, B_TEXT, N, DEEP)
	## diriltme kalpleri + sayaç
	var full: int = int(d.get("hearts", 3))
	for i in 3:
		pix(ci, HEART, Vector2(hp.end.x - 27.0 - (2 - i) * 33.0, 120.0), HEART_PAL if i < full else HEART_EMPTY_PAL)
	txt_r(ci, Vector2(hp.end.x - 3.0 * 33.0 - 6.0, 123.0), str(d.get("heart_timer", "")), 32, B_DIM, F, Color(0, 0, 0, 0), DEEP)
	## grup
	var allies: Array = d.get("allies", [])
	for i in allies.size():
		var r: Rect2 = g["party"][i]
		var a: Dictionary = allies[i]
		txt(ci, Vector2(r.position.x + 69.0, r.position.y + 6.0), str(a["name"]), 32, B_TEXT, F, Color(0, 0, 0, 0), DEEP)
		hbar(ci, Rect2(r.position.x + 69.0, r.position.y + 27.0, 216.0, 15.0), float(a["hp"]) / float(a["hp_max"]), HP_COLS, B_FILL_SOLID, B_RIM_DK, 0)
		hbar(ci, Rect2(r.position.x + 69.0, r.position.y + 42.0, 216.0, 12.0), float(a["sh"]) / maxf(1.0, float(a["sh_max"])), SH_COLS, B_FILL_SOLID, B_RIM_DK, 0)
	## görev (kutusuz)
	var my2: float = g["mission_y"]
	var right: float = 1905.0
	txt_r(ci, Vector2(right, my2), "%s  %d/%d" % [str(d["mission"]["title"]), int(d["mission"]["cur"]), int(d["mission"]["max"])], 32, B_TEXT, F,
			Color(0, 0, 0, 0), DEEP)
	pix(ci, FLAG, Vector2(right - tw("%s  %d/%d" % [str(d["mission"]["title"]), int(d["mission"]["cur"]), int(d["mission"]["max"])], 32) - 33.0, my2 - 3.0), FLAG_PAL)
	hbar(ci, Rect2(right - 300.0, my2 + 24.0, 300.0, 12.0), float(d["mission"]["cur"]) / float(d["mission"]["max"]), XP_COLS, B_FILL_SOLID, B_RIM_DK, 0)
	txt_r(ci, Vector2(right, my2 + 45.0), "Hasar", 32, B_DIM, F, Color(0, 0, 0, 0), DEEP)


# ============================================================================================================================
# C - KARTLAR (parşömen bej, piksel kutu kabartma)
# ============================================================================================================================

var _pb_cache: Dictionary = {}

func _card(ci: CanvasItem, r: Rect2, bg: Color = C_BG, border: Color = C_BORDER, radius: int = 9) -> void:
	var key: String = "%s|%s|%d" % [bg.to_html(), border.to_html(), radius]
	var sb = _pb_cache.get(key)
	if sb == null:
		sb = PixelBox.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set("border_width_left", 3)
		sb.set("border_width_top", 3)
		sb.set("border_width_right", 3)
		sb.set("border_width_bottom", 3)
		for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
			sb.set(c, radius)
		_pb_cache[key] = sb
	(sb as StyleBox).draw(ci.get_canvas_item(), r)


func _well_c(ci: CanvasItem, r: Rect2, col: Color = C_WELL) -> void:
	rr(ci, r, C_BORDER, 1)
	var inner: Rect2 = r.grow(-P)
	ci.draw_rect(inner, col)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, P)), C_WELL_SH)
	ci.draw_rect(Rect2(inner.position, Vector2(P, inner.size.y)), C_WELL_SH)


func _build_c() -> void:
	## karakter kartı (sol alt)
	var card := Rect2(15.0, 1080.0 - 15.0 - 192.0, 501.0, 192.0)
	g["card"] = card
	var o: Vector2 = card.position
	g["portrait"] = Rect2(o + Vector2(12, 12), Vector2(102, 102))
	tex(d.get("portrait"), Rect2(o + Vector2(15, 15), Vector2(96, 96)))
	g["lvl"] = Rect2(o + Vector2(81, 90), Vector2(45, 33))
	g["hp"] = Rect2(o + Vector2(129, 45), Vector2(360, 27))
	g["sh"] = Rect2(o + Vector2(129, 75), Vector2(360, 24))
	g["xp"] = Rect2(o + Vector2(129, 105), Vector2(360, 12))
	var row_y: float = o.y + 129.0
	g["hearts_x"] = o.x + 15.0
	g["row_y"] = row_y
	var items: Array = d.get("items", [])
	var irs: Array = []
	for i in 5:
		var r := Rect2(o.x + 129.0 + i * 54.0, row_y, 48.0, 48.0)
		irs.append(r)
		if i < items.size():
			tex(items[i], r.grow(-6.0))
	g["items"] = irs
	g["pet"] = Rect2(o.x + 129.0 + 5 * 54.0 + 15.0, row_y, 48.0, 48.0)
	tex(d.get("pet"), (g["pet"] as Rect2).grow(-6.0))
	## yetenek taşları (orta alt)
	var sk: Array = _skills()
	var stones: Array = []
	var total: float = 66.0 + 4.0 * 84.0 + 4.0 * 12.0
	var x: float = floorf((1920.0 - total) * 0.5 / P) * P
	for i in sk.size():
		var big: bool = i > 0
		var sz: float = 84.0 if big else 66.0
		var r2 := Rect2(x, 1080.0 - 36.0 - sz, sz, sz)
		stones.append(r2)
		tex(sk[i].get("tex"), r2.grow(-9.0))
		x += sz + 12.0
	g["stones"] = stones
	## harita kartı (sağ alt)
	var mc := Rect2(1920.0 - 15.0 - 270.0, 1080.0 - 15.0 - 381.0, 270.0, 381.0)
	g["mapcard"] = mc
	g["money"] = Rect2(mc.position + Vector2(12, 12), Vector2(246, 45))
	g["map"] = Rect2(mc.position + Vector2(12, 63), Vector2(246, 246))
	_place_minimap(mc.position + Vector2(15, 66), 1.5, true)
	g["inv_btn"] = Rect2(mc.position + Vector2(12, 318), Vector2(180, 51))
	g["stat_btn"] = Rect2(mc.position + Vector2(198, 318), Vector2(60, 51))
	## grup (sol üst) + görev
	var allies: Array = d.get("allies", [])
	var party: Array = []
	for i in allies.size():
		var r3 := Rect2(15.0, 15.0 + i * 75.0, 300.0, 69.0)
		party.append(r3)
		tex(allies[i].get("portrait"), Rect2(r3.position + Vector2(12, 12), Vector2(48, 48)))
	g["party"] = party
	g["mission"] = Rect2(15.0, 15.0 + allies.size() * 75.0, 300.0, 66.0)


func _back_c() -> void:
	_card(self, g["card"])
	_well_c(self, g["portrait"], C_WELL)
	_well_c(self, g["pet"])
	for r in g["items"]:
		_well_c(self, r)
	for i in (g["stones"] as Array).size():
		var r: Rect2 = g["stones"][i]
		_card(self, r, C_BG if i > 0 else Color("#d8be8c"), C_BORDER, 9 if i > 0 else 6)
		_well_c(self, r.grow(-6.0))
	_card(self, g["mapcard"])
	_well_c(self, g["map"], C_DARK)
	_well_c(self, g["money"])
	_card(self, g["inv_btn"], Color("#d4b47e"), C_BORDER, 6)
	_card(self, g["stat_btn"], Color("#d4b47e"), C_BORDER, 6)
	for r in g["party"]:
		_card(self, r)
		_well_c(self, Rect2(r.position + Vector2(9, 9), Vector2(54, 54)))
	_card(self, g["mission"])


func _front_c(ci: CanvasItem) -> void:
	var card: Rect2 = g["card"]
	txt(ci, card.position + Vector2(129, 15), str(d.get("name", "")), 32, C_INK)
	txt_r(ci, Vector2(card.end.x - 15.0, card.position.y + 15.0), "XP %d%%" % int(round(float(d.get("xp_ratio", 0.6)) * 100.0)), 32, C_INK2)
	## seviye rozeti
	var lr: Rect2 = g["lvl"]
	rr(ci, lr, C_BORDER, 1)
	rr(ci, lr.grow(-P), C_DARK, 1)
	txt_c(ci, lr, str(d.get("level", 1)), 18, Color("#f6d27e"), N)
	hbar(ci, g["hp"], float(d["hp"]) / float(d["hp_max"]), HP_COLS, C_DARK, C_BORDER, 1)
	txt_c(ci, g["hp"], "%d / %d" % [int(d["hp"]), int(d["hp_max"])], 18, CREAM, N, DEEP)
	hbar(ci, g["sh"], float(d["sh"]) / float(d["sh_max"]), SH_COLS, C_DARK, C_BORDER, 1)
	txt_c(ci, g["sh"], "%d / %d" % [int(d["sh"]), int(d["sh_max"])], 18, CREAM, N, DEEP)
	hbar(ci, g["xp"], float(d.get("xp_ratio", 0.6)), XP_COLS, C_DARK, C_BORDER, 0)
	## kalpler + sayaç (portrenin altında)
	var full: int = int(d.get("hearts", 3))
	for i in 3:
		pix(ci, HEART, Vector2(float(g["hearts_x"]) + i * 33.0, float(g["row_y"]) + 0.0), HEART_PAL if i < full else HEART_EMPTY_PAL)
	txt(ci, Vector2(float(g["hearts_x"]) + 3.0, float(g["row_y"]) + 30.0), str(d.get("heart_timer", "")), 32, C_INK2)
	for i in (g["items"] as Array).size():
		if i >= (d.get("items", []) as Array).size():
			var r2: Rect2 = g["items"][i]
			rr(ci, Rect2(r2.get_center() - Vector2(6, 6), Vector2(12, 12)), C_WELL_SH, 1)
	## yetenek taşları: tuş kapağı altta
	var sk: Array = _skills()
	for i in sk.size():
		var r: Rect2 = g["stones"][i]
		var s: Dictionary = sk[i]
		_cd_overlay(ci, r.grow(-9.0), s, Color(0.23, 0.15, 0.09, 0.6), CREAM)
		var key: String = str(s.get("key", ""))
		if key != "":
			var kr := Rect2(r.get_center().x - 18.0, r.end.y - 9.0, 36.0, 30.0)
			rr(ci, kr, C_BORDER, 1)
			rr(ci, kr.grow(-P), C_DARK, 1)
			txt_c(ci, kr, key, 32, Color("#efd9ad"))
	## para satırı
	var mr: Rect2 = g["money"]
	pix(ci, COIN, Vector2(mr.position.x + 9.0, mr.position.y + 7.0), COIN_PAL)
	txt(ci, Vector2(mr.position.x + 48.0, mr.position.y + 15.0), _money_str(int(d.get("gold", 0))), 18, C_INK, N)
	pix(ci, SHARD, Vector2(mr.end.x - 78.0, mr.position.y + 6.0), SHARD_PAL)
	txt(ci, Vector2(mr.end.x - 45.0, mr.position.y + 15.0), str(d.get("shards", 0)), 18, C_INK, N)
	var ib: Rect2 = g["inv_btn"]
	pix(ci, BAG, Vector2(ib.position.x + 12.0, ib.position.y + 9.0), BAG_PAL)
	txt(ci, Vector2(ib.position.x + 54.0, ib.position.y + 18.0), "ENVANTER", 32, C_INK)
	var kb := Rect2(ib.end.x - 18.0, ib.position.y - 12.0, 24.0, 27.0)
	rr(ci, kb, C_BORDER, 1)
	rr(ci, kb.grow(-P), C_DARK, 0)
	txt_c(ci, kb, "I", 32, Color("#efd9ad"))
	pix_c(ci, STAT, g["stat_btn"], STAT_PAL)
	## grup + görev
	var allies: Array = d.get("allies", [])
	for i in allies.size():
		var r: Rect2 = g["party"][i]
		var a: Dictionary = allies[i]
		txt(ci, Vector2(r.position.x + 75.0, r.position.y + 12.0), str(a["name"]), 32, C_INK)
		hbar(ci, Rect2(r.position.x + 75.0, r.position.y + 33.0, 210.0, 15.0), float(a["hp"]) / float(a["hp_max"]), HP_COLS, C_DARK, C_BORDER, 0)
		hbar(ci, Rect2(r.position.x + 75.0, r.position.y + 48.0, 210.0, 12.0), float(a["sh"]) / maxf(1.0, float(a["sh_max"])), SH_COLS, C_DARK, C_BORDER, 0)
	var ms: Rect2 = g["mission"]
	pix(ci, FLAG, Vector2(ms.position.x + 15.0, ms.position.y + 15.0), FLAG_PAL)
	txt(ci, Vector2(ms.position.x + 51.0, ms.position.y + 12.0), str(d["mission"]["title"]), 32, C_INK)
	txt_r(ci, Vector2(ms.end.x - 15.0, ms.position.y + 12.0), "%d/%d" % [int(d["mission"]["cur"]), int(d["mission"]["max"])], 32, C_INK2)
	hbar(ci, Rect2(ms.position.x + 51.0, ms.position.y + 36.0, 234.0, 15.0), float(d["mission"]["cur"]) / float(d["mission"]["max"]), XP_COLS, C_DARK, C_BORDER, 0)


# ============================================================================================================================
# D - KÜTÜK KİRİŞ (ekran boyu kiriş, oyuk yuvalar, yükselen yuvarlak harita penceresi)
# ============================================================================================================================

const D_TOP := 966.0
const D_MAP_C := Vector2(1764.0, 939.0)
const D_MAP_R := 117.0

func _socket_d(ci: CanvasItem, r: Rect2) -> void:
	rr(ci, r.grow(P), D_BARK, 2)
	rr(ci, r, D_LIP, 1)
	rr(ci, Rect2(r.position, r.size - Vector2(0, P)), D_SOCKET_SH, 1)
	ci.draw_rect(Rect2(r.position + Vector2(P, 2 * P), r.size - Vector2(2 * P, 3 * P)), D_SOCKET)


func _brass_d(ci: CanvasItem, r: Rect2) -> void:
	rr(ci, r, D_INK, 1)
	rr(ci, r.grow(-P), D_BRASS_DK, 1)
	rr(ci, Rect2(r.position + Vector2(P, P), r.size - Vector2(2 * P, 3 * P)), D_BRASS, 1)
	ci.draw_rect(Rect2(r.position.x + 2 * P, r.position.y + P, r.size.x - 4 * P, P), D_BRASS_HI)


func _build_d() -> void:
	## sol: portre + çubuklar + kalpler
	g["portrait"] = Rect2(33.0, 975.0, 99.0, 99.0)
	tex(d.get("portrait"), Rect2(36.0, 978.0, 96.0, 96.0))
	g["hp"] = Rect2(150.0, 1005.0, 360.0, 27.0)
	g["sh"] = Rect2(150.0, 1038.0, 360.0, 24.0)
	## orta: yetenek oyukları
	var sk: Array = _skills()
	var socks: Array = []
	var total: float = 5.0 * 72.0 + 4.0 * 15.0
	var x: float = floorf((1920.0 - total) * 0.5 / P) * P
	for i in sk.size():
		var r := Rect2(x + i * 87.0, 987.0, 72.0, 72.0)
		socks.append(r)
		tex(sk[i].get("tex"), r.grow(-12.0))
	g["socks"] = socks
	## sağ: efsanevi + evcil + para + çanta
	var items: Array = d.get("items", [])
	var irs: Array = []
	var ix: float = (socks[socks.size() - 1] as Rect2).end.x + 45.0
	for i in 5:
		var r2 := Rect2(ix + i * 51.0, 987.0, 45.0, 45.0)
		irs.append(r2)
		if i < items.size():
			tex(items[i], r2.grow(-6.0))
	g["items"] = irs
	g["pet"] = Rect2(ix + 5 * 51.0 + 9.0, 987.0, 45.0, 45.0)
	tex(d.get("pet"), (g["pet"] as Rect2).grow(-4.0))
	g["money_x"] = ix
	g["bag"] = Rect2(ix + 216.0, 1038.0, 48.0, 33.0)
	_place_minimap(D_MAP_C - Vector2(100, 100), 1.25, false)
	## grup (sol üst, asılı tahta yerine kiriş parçası)
	var allies: Array = d.get("allies", [])
	var party: Array = []
	for i in allies.size():
		var r3 := Rect2(15.0, 15.0 + i * 75.0, 315.0, 66.0)
		party.append(r3)
		tex(allies[i].get("portrait"), Rect2(r3.position + Vector2(39, 9), Vector2(48, 48)))
	g["party"] = party
	g["mission"] = Rect2(15.0, 15.0 + allies.size() * 75.0, 315.0, 60.0)


func _log_d(ci: CanvasItem, r: Rect2, caps: bool = true) -> void:
	## gövde: kabuk üst/alt, damarlı ahşap
	ci.draw_rect(r, D_BARK)
	var body := Rect2(r.position.x, r.position.y + P, r.size.x, r.size.y - 2 * P)
	ci.draw_rect(body, D_WOOD)
	ci.draw_rect(Rect2(body.position, Vector2(body.size.x, P)), D_WOOD_HI)
	ci.draw_rect(Rect2(body.position.x, body.end.y - 2 * P, body.size.x, 2 * P), D_GRAIN)
	## damar çizgileri: sabit tohumlu, kısa yatay kesikler
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.position.x * 7.0 + r.position.y * 13.0 + r.size.x)
	var rows: int = int((body.size.y - 4 * P) / (3 * P))
	for row in rows:
		var y: float = body.position.y + 2 * P + row * 3 * P + float(rng.randi_range(0, 1)) * P
		var xx: float = body.position.x + float(rng.randi_range(0, 20)) * P
		while xx < body.end.x:
			var ln: float = float(rng.randi_range(8, 30)) * P
			ci.draw_rect(Rect2(xx, y, minf(ln, body.end.x - xx), P), D_GRAIN if rng.randf() < 0.7 else D_GRAIN_HI)
			xx += ln + float(rng.randi_range(6, 24)) * P
	if caps:
		for side in [0, 1]:
			var cx: float = r.position.x if side == 0 else r.end.x - 7 * P
			var cap := Rect2(cx, r.position.y, 7 * P, r.size.y)
			rr(ci, cap, D_BARK, 2)
			rr(ci, cap.grow(-P), D_END_RING, 2)
			rr(ci, cap.grow(-2 * P), D_END, 1)
			rr(ci, Rect2(cap.position + Vector2(2 * P, cap.size.y * 0.5 - 4 * P), Vector2(3 * P, 8 * P)), D_END_RING, 1)
			ci.draw_rect(Rect2(cap.position + Vector2(3 * P, cap.size.y * 0.5 - 2 * P), Vector2(P, 4 * P)), D_END_CORE)


func _back_d() -> void:
	## kiriş (harita penceresinin sağ tarafı pencerenin altında kalır)
	_log_d(self, Rect2(0, D_TOP, 1920, 1080 - D_TOP), false)
	## XP oluğu kirişin üst kenarında
	var xr := Rect2(0, D_TOP - 3.0, D_MAP_C.x - D_MAP_R, 12.0)
	draw_rect(xr, D_BARK)
	draw_rect(xr.grow(-P), D_SOCKET)
	var xw: float = floorf((xr.size.x - 2 * P) * float(d.get("xp_ratio", 0.6)) / P) * P
	draw_rect(Rect2(xr.position + Vector2(P, P), Vector2(xw, xr.size.y - 2 * P)), XP_COLS[1])
	draw_rect(Rect2(xr.position + Vector2(P, P), Vector2(xw, P)), XP_COLS[0])
	## sol uç kesiti
	var cap := Rect2(0, D_TOP, 21, 1080 - D_TOP)
	draw_rect(cap, D_BARK)
	draw_rect(cap.grow(-P), D_END_RING)
	draw_rect(Rect2(cap.position + Vector2(P, 2 * P), cap.size - Vector2(3 * P, 4 * P)), D_END)
	_socket_d(self, g["portrait"])
	for r in g["socks"]:
		_socket_d(self, r)
	for r in g["items"]:
		_socket_d(self, r)
	_socket_d(self, g["pet"])
	## grup + görev: kısa kütük parçaları
	for r in g["party"]:
		_log_d(self, r, true)
		_socket_d(self, Rect2(r.position + Vector2(36, 6), Vector2(54, 54)))
	_log_d(self, g["mission"], true)


## Piksel basamaklı halka (3 px ızgarada satır satır): r0 iç, r1 dış yarıçap (r0 = 0 -> dolu daire).
func _annulus(ci: CanvasItem, c: Vector2, r0: float, r1: float, col: Color) -> void:
	var n: int = int(ceil(r1 / P))
	for iy in range(-n, n):
		var yc: float = (iy + 0.5) * P
		var ho: float = floorf(sqrt(maxf(0.0, r1 * r1 - yc * yc)) / P) * P
		if ho <= 0.0:
			continue
		var hi: float = floorf(sqrt(maxf(0.0, r0 * r0 - yc * yc)) / P) * P if r0 > 0.0 else 0.0
		if hi <= 0.0:
			ci.draw_rect(Rect2(c.x - ho, c.y + iy * P, 2.0 * ho, P), col)
		else:
			ci.draw_rect(Rect2(c.x - ho, c.y + iy * P, ho - hi, P), col)
			ci.draw_rect(Rect2(c.x + hi, c.y + iy * P, ho - hi, P), col)


func _front_d(ci: CanvasItem) -> void:
	## harita penceresi: kütük kesiti gibi halkalar (minimap'in kendi halka dokusunu da örter) + pirinç perçinler
	var c: Vector2 = D_MAP_C
	_annulus(ci, c, 100.0, D_MAP_R + 9.0, D_BARK)
	_annulus(ci, c, 103.0, D_MAP_R + 6.0, D_END_RING)
	_annulus(ci, c, 106.0, D_MAP_R, D_END)
	_annulus(ci, c, 109.0, 112.0, D_END_RING)
	_annulus(ci, c, 103.0, 106.0, D_WOOD)
	for a in [-PI * 0.75, -PI * 0.25, PI * 0.25, PI * 0.75]:
		var pp: Vector2 = (c + Vector2(cos(a), sin(a)) * 114.0).snapped(Vector2(P, P)) - Vector2(6, 6)
		_brass_d(ci, Rect2(pp, Vector2(12, 12)))
	## kuzey levhası
	var nr := Rect2(c.x - 15.0, c.y - D_MAP_R - 12.0, 30.0, 27.0)
	_brass_d(ci, nr)
	txt_c(ci, nr, "K", 32, D_INK)
	## portre: seviye pirinç rozet
	var pr: Rect2 = g["portrait"]
	var lr := Rect2(pr.end.x - 27.0, pr.position.y - 6.0, 42.0, 30.0)
	_brass_d(ci, lr)
	txt_c(ci, lr, str(d.get("level", 1)), 18, D_INK, N)
	## ad kazıma (koyu yazı + alt ışık = oyma)
	txt(ci, Vector2(150, 978), str(d.get("name", "")), 32, D_END, F, D_INK)
	## çubuklar
	hbar(ci, g["hp"], float(d["hp"]) / float(d["hp_max"]), HP_COLS, D_SOCKET, D_BARK, 1)
	txt_c(ci, g["hp"], "%d / %d" % [int(d["hp"]), int(d["hp_max"])], 18, CREAM, N, DEEP)
	hbar(ci, g["sh"], float(d["sh"]) / float(d["sh_max"]), SH_COLS, D_SOCKET, D_BARK, 1)
	txt_c(ci, g["sh"], "%d / %d" % [int(d["sh"]), int(d["sh_max"])], 18, CREAM, N, DEEP)
	## kalpler (çubukların sağında)
	var full: int = int(d.get("hearts", 3))
	for i in 3:
		pix(ci, HEART, Vector2(528.0 + i * 30.0, 1005.0), HEART_PAL if i < full else HEART_EMPTY_PAL)
	txt(ci, Vector2(531, 1041), str(d.get("heart_timer", "")), 32, D_END, F, D_INK)
	## yetenekler: tuş = pirinç levha sağ altta
	var sk: Array = _skills()
	for i in sk.size():
		var r: Rect2 = g["socks"][i]
		var s: Dictionary = sk[i]
		_cd_overlay(ci, r.grow(-P), s, Color(0.06, 0.03, 0.01, 0.62), CREAM)
		var key: String = str(s.get("key", ""))
		if key != "":
			var kr := Rect2(r.end.x - 21.0, r.end.y - 21.0, 27.0, 27.0)
			_brass_d(ci, kr)
			txt_c(ci, kr, key, 32, D_INK)
	for i in (g["items"] as Array).size():
		if i >= (d.get("items", []) as Array).size():
			var r2: Rect2 = g["items"][i]
			rr(ci, Rect2(r2.get_center() - Vector2(6, 6), Vector2(12, 12)), D_BARK_HI, 1)
	## para + parçacık (oyma) + çanta düğmesi
	var mx: float = g["money_x"]
	pix(ci, COIN, Vector2(mx, 1041.0), COIN_PAL)
	txt(ci, Vector2(mx + 39.0, 1047.0), _money_str(int(d.get("gold", 0))), 18, Color("#ffe3a0"), N, D_INK)
	pix(ci, SHARD, Vector2(mx + 135.0, 1038.0), SHARD_PAL)
	txt(ci, Vector2(mx + 165.0, 1047.0), str(d.get("shards", 0)), 18, Color("#d8f0fc"), N, D_INK)
	var bg_r: Rect2 = g["bag"]
	_brass_d(ci, bg_r.grow(3.0))
	pix(ci, BAG, Vector2(bg_r.position.x + 6.0, bg_r.position.y + 0.0), BAG_PAL)
	## grup
	var allies: Array = d.get("allies", [])
	for i in allies.size():
		var r3: Rect2 = g["party"][i]
		var a: Dictionary = allies[i]
		txt(ci, Vector2(r3.position.x + 102.0, r3.position.y + 9.0), str(a["name"]), 32, D_END, F, D_INK)
		hbar(ci, Rect2(r3.position.x + 102.0, r3.position.y + 30.0, 186.0, 15.0), float(a["hp"]) / float(a["hp_max"]), HP_COLS, D_SOCKET, D_BARK, 0)
		hbar(ci, Rect2(r3.position.x + 102.0, r3.position.y + 45.0, 186.0, 12.0), float(a["sh"]) / maxf(1.0, float(a["sh_max"])), SH_COLS, D_SOCKET, D_BARK, 0)
	var ms: Rect2 = g["mission"]
	pix(ci, FLAG, Vector2(ms.position.x + 33.0, ms.position.y + 12.0), FLAG_PAL)
	txt(ci, Vector2(ms.position.x + 66.0, ms.position.y + 9.0), str(d["mission"]["title"]), 32, D_END, F, D_INK)
	txt_r(ci, Vector2(ms.end.x - 30.0, ms.position.y + 9.0), "%d/%d" % [int(d["mission"]["cur"]), int(d["mission"]["max"])], 32, D_END, F, D_INK)
	hbar(ci, Rect2(ms.position.x + 66.0, ms.position.y + 33.0, 219.0, 15.0), float(d["mission"]["cur"]) / float(d["mission"]["max"]), XP_COLS, D_SOCKET, D_BARK, 0)
