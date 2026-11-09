extends "res://tools/proto_20261108/sol_grup/sol_grup_proto.gd"

## SOHBET PENCERESİ + KONUŞMA BALONU prototipleri (2026-11-08, oyuna bağlı DEĞİL). Kullanıcı: "oyunun chat ekranına ve chat baloncuğunu
## yeniden tasarlar mısın diğer arayüzlerle uyumlu şekilde pixel art" + "tasarımı için 4 prototip hazırla sol altta görünecek".
## hud_capture.gd SOHBET=<A..D> gerçek oyunu açar, gerçek ChatLayer'ı gizler, bu betiği sol alta kurar ve oyuncunun + bir müttefik
## sprite'ının başına make_bubble() balonlarını takar. İki çekim: okuma (yazı kutusu kapalı) + yazma (Enter'a basılmış).
## Malzeme oyuncu panelinin kendisi (Gömme Tepsi, madde 454/483): yan kutu dokusu, gömme kuyu, kabarık levha, çubuk kapağı pirinci,
## yuva çerçevesi; renkler yalnız hud_theme.gd rolleri + oyuncu renkleri (menu_dark_kit PLAYER_COLORS, "sohbet adı").
## Pencere: 1 sanat pikseli = 3 ekran pikseli, yazı m5x7 32. Balon DÜNYADA çizilir (oyuncunun 0,5 ölçekli kökü altında, bugünkü balonla aynı
## yer): 1 sanat pikseli = 1 dünya pikseli (= harita pikseli, 2 yerel birim), yazı m5x7 32 yerel = 1 yazı pikseli 1 dünya pikseli.
##   A Tepsi Pencere     - hep açık Gömme Tepsi kutusu: başlık (simge + SOHBET), ayraç, satırlar, altta gömme kuyu giriş; balon = tepsi kutusu + ortada ahşap kuyruk
##   B Serbest Şeritler  - kutu yok: her mesaj yazıya oturan koyu şerit + solda oyuncu rengi çizgisi, eskiler söner; giriş = pirinç kapaklı kuyu (can çubuğu gibi); balon = pirinç kapaklı koyu şerit + pirinç uç
##   C Portreli Mesajlar - mesaj başına yüz yuvası (grup paneli portresi) + kuyruklu mesaj kutusu, ad üstte; giriş = gömme kuyu + kabarık "Enter" levhası; balon = kabarık ahşap levha, kuyruk solda
##   D Gölge Perdesi     - kutu/çerçeve yok: soldan sönen koyu perde, oyuncu renginde elmas madde imi; giriş = gömme kuyu + "»"; balon = çerçevesiz koyu perde

const ChatBubbleScript := preload("res://scripts/chat_bubble.gd")

const X0 := 18.0
const BOT := 1062.0
const W := 480.0
const FS := 32
const LP := 30.0 ## satır aralığı (büyük harf 14 px + alt uzantı + boşluk)
const CAP := 14.0
## Balon (yerel birim; oyuncu kökü 0,5 ölçekli -> 2 yerel = 1 dünya px = 1 sanat px)
const BT := 2.0
const B_LP := 24.0 ## balon satır aralığı (12 yazı pikseli)
const B_MAX_W := 360.0
const B_TIP_Y := -136.0 ## kuyruğun ucu = bugünkü balonun alt kenarı (isim etiketinin hemen üstü)

const ICON_CHAT := [".ooooooo.", "o1111111o", "o1d1d1d1o", "o1111111o", ".oo1ooooo", "..o1o....", "..oo....."]
const GLYPH_PROMPT := ["o..o..", "oo.oo.", ".oo.oo", "oo.oo.", "o..o.."]

var data: Dictionary = {}
var typing: bool = false
var _layers: Array = []


class Bubble extends Node2D:
	var ui: Object
	var lines: PackedStringArray
	func _draw() -> void:
		ui.call("draw_bubble", self, lines)


func setup_chat(st: String, dt: Dictionary) -> void:
	style = st
	data = dt
	d = {}
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tray_sb = StyleBoxTexture.new()
	_tray_sb.texture = TRAY_TEX
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_tray_sb.set_texture_margin(side, 18.0)
	typing = bool(dt.get("typing", false))
	_rebuild()


func set_typing(on: bool) -> void:
	typing = on
	_rebuild()


func _draw() -> void:
	pass


## Her parça ayrı Layer: eski mesajlar modulate.a ile söner (yüz dokusu dahil).
func _add_layer(fn_name: String, arg: Variant = null, alpha: float = 1.0) -> void:
	var ly := Layer.new()
	ly.size = size
	ly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ly.fn = Callable(self, fn_name) if arg == null else Callable(self, fn_name).bind(arg)
	ly.modulate.a = alpha
	add_child(ly)
	_layers.append(ly)


func _rebuild() -> void:
	for ly in _layers:
		(ly as Node).queue_free()
	_layers.clear()
	L = {}
	match style:
		"A": _lay_a()
		"B": _lay_b()
		"C": _lay_c()
		"D": _lay_d()


# --- ortak ------------------------------------------------------------------------------------------------------------------------

func s3(v: float) -> float:
	return roundf(v / P) * P


## "Ad: mesaj" satırlara bölünür (bugünkü balonun kaydırıcısı: sözcük korur, sığmayan sözcüğü böler); ilk satır "Ad:" ile başlar.
func wrap_msg(m: Dictionary, width: float, with_name: bool = true) -> PackedStringArray:
	var full: String = ("%s: %s" % [m["name"], m["text"]]) if with_name else str(m["text"])
	return ChatBubbleScript.wrap_text(full, F, FS, width).split("\n")


## Mesaj satırı: ilk satırda "Ad:" oyuncu renginde, kalanı krem.
func msg_line(ci: CanvasItem, pos: Vector2, line: String, first: bool, m: Dictionary, text_col: Color, sh: Color = Color(0, 0, 0, 0)) -> void:
	var prefix: String = str(m["name"]) + ":"
	if first and line.begins_with(prefix):
		txt(ci, pos, prefix, FS, m["col"], F, sh)
		txt(ci, pos + Vector2(tw(prefix + " ", FS), 0), line.substr(prefix.length()).strip_edges(), FS, text_col, F, sh)
	else:
		txt(ci, pos, line, FS, text_col, F, sh)


func cursor(ci: CanvasItem, x: float, cap_top: float) -> void:
	ci.draw_rect(Rect2(s3(x + 3.0), cap_top - 3.0, P, 21.0), HudTheme.ACCENT)


## Yazı kutusu içeriği: yazarken metin + imleç, değilse soluk ipucu.
func input_text(ci: CanvasItem, x: float, r: Rect2, hint: String) -> void:
	var cap_top: float = s3(r.position.y + (r.size.y - CAP) * 0.5)
	if typing:
		var s: String = str(data.get("typed", ""))
		txt(ci, Vector2(x, cap_top), s, FS, HudTheme.TEXT)
		cursor(ci, x + tw(s, FS), cap_top)
	else:
		txt(ci, Vector2(x, cap_top), hint, FS, HudTheme.DIM)


## Eski mesaj sönmesi (okuma hâlinde): en yeni 2 tam, sonra azalır. Yazarken hepsi tam.
func fade_for(idx_from_newest: int, table: Array) -> float:
	if typing:
		return 1.0
	return float(table[mini(idx_from_newest, table.size() - 1)])


func msgs_last(n: int) -> Array:
	var all: Array = data.get("msgs", [])
	return all.slice(maxi(0, all.size() - n))


# ==================================================================================================================================
# A - Tepsi Pencere
# ==================================================================================================================================

func _lay_a() -> void:
	var inner_x: float = X0 + 18.0
	var inner_w: float = W - 36.0
	var msgs: Array = msgs_last(5)
	var wrapped: Array = []
	var n_lines: int = 0
	for m in msgs:
		var ls: PackedStringArray = wrap_msg(m, inner_w)
		wrapped.append(ls)
		n_lines += ls.size()
	var input_r := Rect2(X0 + 15.0, BOT - 18.0 - 42.0, W - 30.0, 42.0)
	var log_bot: float = input_r.position.y - 12.0
	var log_top: float = log_bot - n_lines * LP
	var div_y: float = log_top - 12.0
	var head_y: float = div_y - 9.0 - CAP
	var top: float = s3(head_y - 18.0)
	L["tray"] = Rect2(X0, top, W, BOT - top)
	L["head"] = Vector2(inner_x, head_y)
	L["div"] = Vector2(div_y, 0)
	L["input"] = input_r
	L["msgs"] = msgs
	L["wrapped"] = wrapped
	L["log_top"] = log_top
	L["inner_x"] = inner_x
	_add_layer("_draw_a")


func _draw_a(ci: CanvasItem) -> void:
	var tr: Rect2 = L["tray"]
	tray(ci, tr)
	var hp: Vector2 = L["head"]
	var isz: Vector2 = pix_size(ICON_CHAT)
	pix(ci, ICON_CHAT, Vector2(hp.x, hp.y + s3((CAP - isz.y) * 0.5)), {"o": HudTheme.OUTLINE, "1": HudTheme.ACCENT_SOFT, "d": HudTheme.ACCENT_DK})
	txt(ci, Vector2(hp.x + isz.x + 9.0, hp.y), "SOHBET", FS, HudTheme.ACCENT, F, HudTheme.OUTLINE)
	hdivider(ci, tr.position.x + 15.0, tr.end.x - 15.0, (L["div"] as Vector2).x)
	var y: float = L["log_top"]
	var msgs: Array = L["msgs"]
	for i in msgs.size():
		var ls: PackedStringArray = L["wrapped"][i]
		for j in ls.size():
			msg_line(ci, Vector2(L["inner_x"], y + 6.0), ls[j], j == 0, msgs[i], HudTheme.TEXT)
			y += LP
	var ir: Rect2 = L["input"]
	well(ci, ir)
	input_text(ci, ir.position.x + 15.0, ir, "Yazmak için Enter")


# ==================================================================================================================================
# B - Serbest Şeritler
# ==================================================================================================================================

func _lay_b() -> void:
	var msgs: Array = msgs_last(5)
	var bottom: float = BOT
	if typing:
		L["input"] = Rect2(X0, BOT - 42.0, W, 42.0)
		bottom = BOT - 42.0 - 9.0
	var y: float = bottom
	var strips: Array = []
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		var ls: PackedStringArray = wrap_msg(m, W - 27.0)
		var wmax: float = 0.0
		for li in ls:
			wmax = maxf(wmax, tw(li, FS))
		var h: float = ls.size() * LP + 3.0
		y -= h
		strips.append({"r": Rect2(X0, y, s3(wmax + 27.0 + 2.0), h), "lines": ls, "m": m, "age": msgs.size() - 1 - i})
		y -= 3.0
	for st in strips:
		_add_layer("_draw_b_strip", st, fade_for(int(st["age"]), [1.0, 1.0, 0.82, 0.55, 0.32]))
	if typing:
		_add_layer("_draw_b_input")


func _draw_b_strip(ci: CanvasItem, st: Dictionary) -> void:
	var r: Rect2 = st["r"]
	var m: Dictionary = st["m"]
	rr(ci, r, Color(HudTheme.DOCK_INSET, 0.84), 1)
	ci.draw_rect(Rect2(r.position.x + P, r.position.y + P, P, r.size.y - 2 * P), m["col"])
	var ls: PackedStringArray = st["lines"]
	for j in ls.size():
		msg_line(ci, Vector2(r.position.x + 15.0, r.position.y + 8.0 + j * LP), ls[j], j == 0, m, HudTheme.TEXT)


func _draw_b_input(ci: CanvasItem) -> void:
	var ir: Rect2 = L["input"]
	brass_well(ci, ir)
	input_text(ci, ir.position.x + 21.0, ir, "")


# ==================================================================================================================================
# C - Portreli Mesajlar
# ==================================================================================================================================

const C_FACE := 48.0
const C_TAIL := ["..oo", ".oSS", "oSSS", ".oSS", "..oo"]

func _lay_c() -> void:
	var msgs: Array = msgs_last(4)
	var box_x: float = X0 + C_FACE + 12.0
	var max_text: float = W - (box_x - X0) - 30.0
	var bottom: float = BOT
	if typing:
		L["input"] = Rect2(X0, BOT - 45.0, W, 45.0)
		bottom = BOT - 45.0 - 12.0
	var y: float = bottom
	var blocks: Array = []
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		var ls: PackedStringArray = wrap_msg(m, max_text, false)
		var wmax: float = tw(str(m["name"]), FS)
		for li in ls:
			wmax = maxf(wmax, tw(li, FS))
		var h: float = s3((ls.size()) * LP + 39.0)
		y -= h
		blocks.append({"box": Rect2(box_x, y, s3(wmax + 30.0), h), "face": Rect2(X0, y, C_FACE, C_FACE), "lines": ls, "m": m,
			"age": msgs.size() - 1 - i})
		y -= 9.0
	for b in blocks:
		_add_layer("_draw_c_block", b, fade_for(int(b["age"]), [1.0, 1.0, 0.7, 0.45]))
	if typing:
		_add_layer("_draw_c_input")


func _draw_c_block(ci: CanvasItem, b: Dictionary) -> void:
	var m: Dictionary = b["m"]
	var fr: Rect2 = b["face"]
	ci.draw_rect(fr, HudTheme.DOCK_INSET)
	var bg: Texture2D = m.get("bg")
	if bg:
		ci.draw_texture_rect(bg, fr, false)
	var face: Texture2D = m.get("face")
	if face:
		ci.draw_texture_rect(face, fr, false)
	HudTrayFrame.draw(ci, fr, 1.0)
	var bx: Rect2 = b["box"]
	rr(ci, bx, HudTheme.OUTLINE, 2)
	var inner: Rect2 = bx.grow(-P)
	rr(ci, inner, HudTheme.STRIPE, 1)
	ci.draw_rect(Rect2(inner.position.x + P, inner.position.y, inner.size.x - 2 * P, P), HudTheme.RIM_LO)
	ci.draw_rect(Rect2(inner.position.x + P, inner.end.y - P, inner.size.x - 2 * P, P), HudTheme.DOCK_INSET)
	pix(ci, C_TAIL, Vector2(bx.position.x - 3 * P, bx.position.y + 3 * P), {"o": HudTheme.OUTLINE, "S": HudTheme.STRIPE})
	var tx: float = bx.position.x + 15.0
	txt(ci, Vector2(tx, bx.position.y + 12.0), str(m["name"]), FS, m["col"])
	var ls: PackedStringArray = b["lines"]
	for j in ls.size():
		txt(ci, Vector2(tx, bx.position.y + 12.0 + (j + 1) * LP), ls[j], FS, HudTheme.TEXT)


func _draw_c_input(ci: CanvasItem) -> void:
	var ir: Rect2 = L["input"]
	well(ci, ir)
	var s: String = "Enter"
	var pw: float = s3(tw(s, FS) + 24.0)
	var pr := Rect2(ir.end.x - 6.0 - pw, ir.position.y + 6.0, pw, ir.size.y - 12.0)
	plate(ci, pr)
	txt_c(ci, pr, s, FS, HudTheme.TEXT, F, HudTheme.OUTLINE)
	input_text(ci, ir.position.x + 15.0, ir, "")


# ==================================================================================================================================
# D - Gölge Perdesi
# ==================================================================================================================================

func _lay_d() -> void:
	var msgs: Array = msgs_last(5)
	var text_x: float = X0 + 24.0
	var bottom: float = BOT - 6.0
	if typing:
		L["input"] = Rect2(X0, BOT - 42.0, W, 42.0)
		bottom = BOT - 42.0 - 12.0
	var y: float = bottom
	var items: Array = []
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		var ls: PackedStringArray = wrap_msg(m, W - 24.0)
		y -= ls.size() * LP
		items.append({"y": y, "lines": ls, "m": m, "x": text_x, "age": msgs.size() - 1 - i})
	L["top"] = y
	_add_layer("_draw_d_back")
	for it in items:
		_add_layer("_draw_d_item", it, fade_for(int(it["age"]), [1.0, 1.0, 0.8, 0.55, 0.3]))
	if typing:
		_add_layer("_draw_d_input")


func _draw_d_back(ci: CanvasItem) -> void:
	var a: float = 0.82 if typing else 0.6
	var top: float = float(L["top"]) - 24.0
	var right: float = X0 + W + 150.0
	var fade_h: float = 60.0
	var c_in := Color(HudTheme.DEEP, a)
	var c_mid := Color(HudTheme.DEEP, a * 0.55)
	var c_out := Color(HudTheme.DEEP, 0.0)
	var xm: float = X0 + W * 0.7
	## Gövde: solda koyu, ortada yarı, sağda saydam (iki parça -> daha uzun koyu bölge)
	ci.draw_polygon(PackedVector2Array([Vector2(0, top + fade_h), Vector2(xm, top + fade_h), Vector2(xm, 1080), Vector2(0, 1080)]),
		PackedColorArray([c_in, c_mid, c_mid, c_in]))
	ci.draw_polygon(PackedVector2Array([Vector2(xm, top + fade_h), Vector2(right, top + fade_h), Vector2(right, 1080), Vector2(xm, 1080)]),
		PackedColorArray([c_mid, c_out, c_out, c_mid]))
	## Üst sönüş
	ci.draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(xm, top), Vector2(xm, top + fade_h), Vector2(0, top + fade_h)]),
		PackedColorArray([c_out, c_out, c_mid, c_in]))
	ci.draw_polygon(PackedVector2Array([Vector2(xm, top), Vector2(right, top), Vector2(right, top + fade_h), Vector2(xm, top + fade_h)]),
		PackedColorArray([c_out, c_out, c_out, c_mid]))


func _draw_d_item(ci: CanvasItem, it: Dictionary) -> void:
	var m: Dictionary = it["m"]
	var ls: PackedStringArray = it["lines"]
	var y: float = it["y"]
	pix(ci, DIAMOND, Vector2(X0 + 3.0, y + 6.0 + s3((CAP - 15.0) * 0.5)), {"o": HudTheme.OUTLINE, "1": m["col"], "2": (m["col"] as Color).lightened(0.4)})
	for j in ls.size():
		msg_line(ci, Vector2(it["x"], y + 6.0 + j * LP), ls[j], j == 0, m, HudTheme.TEXT, HudTheme.DEEP)


func _draw_d_input(ci: CanvasItem) -> void:
	var ir: Rect2 = L["input"]
	well(ci, ir)
	var gs: Vector2 = pix_size(GLYPH_PROMPT)
	pix(ci, GLYPH_PROMPT, Vector2(ir.position.x + 15.0, s3(ir.position.y + (ir.size.y - gs.y) * 0.5)), {"o": HudTheme.ACCENT})
	input_text(ci, ir.position.x + 15.0 + gs.x + 12.0, ir, "")


# ==================================================================================================================================
# BALON (dünyada; yerel birim, BT = 1 sanat px)
# ==================================================================================================================================

func make_bubble(text: String) -> Node2D:
	var b := Bubble.new()
	b.ui = self
	b.z_index = 65
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.lines = ChatBubbleScript.wrap_text(text, F, FS, B_MAX_W).split("\n")
	return b


## Basamaklı köşeli dolu dikdörtgen, adım = t (rr'nin yerel birim hâli).
func rrt(ci: CanvasItem, r: Rect2, c: Color, k: int, t: float) -> void:
	var prof: Array = PROF[clampi(k, 0, 4)]
	var n: int = prof.size()
	if n == 0:
		ci.draw_rect(r, c)
		return
	for i in n:
		var ins: float = float(prof[i]) * t
		ci.draw_rect(Rect2(r.position.x + ins, r.position.y + i * t, r.size.x - 2.0 * ins, t), c)
		ci.draw_rect(Rect2(r.position.x + ins, r.end.y - (i + 1) * t, r.size.x - 2.0 * ins, t), c)
	ci.draw_rect(Rect2(r.position.x, r.position.y + n * t, r.size.x, r.size.y - 2.0 * n * t), c)


## Gömme Tepsi çerçevesi (hud_tray_frame.gd kalıbı) yerel birimde, dönüşüm geri alınmadan (dünyada çizilir).
func tray_frame_local(ci: CanvasItem, r: Rect2, t: float) -> void:
	var aw: int = int(r.size.x / t)
	var ah: int = int(r.size.y / t)
	var o: Vector2 = r.position
	HudTrayFrame._tile(ci, HudTrayFrame.TL, o, t, Color(0, 0, 0, 0))
	HudTrayFrame._tile(ci, HudTrayFrame.TR, o + Vector2((aw - 6) * t, 0.0), t, Color(0, 0, 0, 0))
	HudTrayFrame._tile(ci, HudTrayFrame.BL, o + Vector2(0.0, (ah - 6) * t), t, Color(0, 0, 0, 0))
	HudTrayFrame._tile(ci, HudTrayFrame.BR, o + Vector2((aw - 6) * t, (ah - 6) * t), t, Color(0, 0, 0, 0))
	for k in 4:
		var c_tl: Color = HudTrayFrame._col(HudTrayFrame.EDGE_TL[k], Color(0, 0, 0, 0))
		var c_br: Color = HudTrayFrame._col(HudTrayFrame.EDGE_BR[k], Color(0, 0, 0, 0))
		ci.draw_rect(Rect2(o.x + 6.0 * t, o.y + k * t, (aw - 12) * t, t), c_tl)
		ci.draw_rect(Rect2(o.x + 6.0 * t, o.y + (ah - 1 - k) * t, (aw - 12) * t, t), c_br)
		ci.draw_rect(Rect2(o.x + k * t, o.y + 6.0 * t, t, (ah - 12) * t), c_tl)
		ci.draw_rect(Rect2(o.x + (aw - 1 - k) * t, o.y + 6.0 * t, t, (ah - 12) * t), c_br)


func pix_t(ci: CanvasItem, rows: Array, pos: Vector2, pal: Dictionary, t: float) -> void:
	pix(ci, rows, pos, pal, t)


func draw_bubble(ci: CanvasItem, lines: PackedStringArray) -> void:
	var wmax: float = 0.0
	for li in lines:
		wmax = maxf(wmax, tw(li, FS))
	var n: int = lines.size()
	var text_h: float = CAP + (n - 1) * B_LP
	var pad_x: float
	var pad_top: float
	var pad_bot: float
	var tail_h: float
	match style:
		"A":
			pad_x = 9.0 * BT
			pad_top = 7.0 * BT
			pad_bot = 9.0 * BT
			tail_h = 4.0 * BT
		"B":
			pad_x = 9.0 * BT
			pad_top = 4.0 * BT
			pad_bot = 6.0 * BT
			tail_h = 3.0 * BT
		"C":
			pad_x = 7.0 * BT
			pad_top = 5.0 * BT
			pad_bot = 7.0 * BT
			tail_h = 4.0 * BT
		_:
			pad_x = 6.0 * BT
			pad_top = 4.0 * BT
			pad_bot = 6.0 * BT
			tail_h = 3.0 * BT
	var bw: float = ceilf((wmax + 2.0 * pad_x) / (2.0 * BT)) * 2.0 * BT
	var bh: float = ceilf((text_h + pad_top + pad_bot) / BT) * BT
	var box := Rect2(-bw * 0.5, B_TIP_Y - tail_h - bh, bw, bh)
	match style:
		"A":
			rrt(ci, box.grow(-BT), Color(HudTheme.DOCK_INSET, 0.95), 2, BT)
			tray_frame_local(ci, box, BT)
			## Kuyruk: çerçevenin ahşabı aşağı akar (dış hat yerine ahşap, 4 sanat px).
			var tail := ["oAAAAAAAAo", ".oAAAAAAo.", "..oAAAAo..", "...oAAo...", "....oo...."]
			pix_t(ci, tail, Vector2(-5.0 * BT, box.end.y - BT), {"o": HudTheme.OUTLINE, "A": HudTheme.RIM}, BT)
		"B":
			var cw: float = 4.0 * BT
			rrt(ci, Rect2(box.position.x + cw - BT, box.position.y, box.size.x - 2.0 * cw + 2.0 * BT, box.size.y), HudTheme.OUTLINE, 0, BT)
			ci.draw_rect(Rect2(box.position.x + cw, box.position.y + BT, box.size.x - 2.0 * cw, box.size.y - 2.0 * BT), Color(HudTheme.DOCK_INSET, 0.92))
			ci.draw_rect(Rect2(box.position.x + cw, box.end.y - 2.0 * BT, box.size.x - 2.0 * cw, BT), Color(HudTheme.RIM_HI, 0.35))
			for side in [0, 1]:
				var cx: float = box.position.x if side == 0 else box.end.x - cw
				var cap := Rect2(cx, box.position.y, cw, box.size.y)
				rrt(ci, cap, HudTheme.ACCENT_DK, 1, BT)
				var c2: Rect2 = cap.grow(-BT)
				ci.draw_rect(c2, HudTheme.SPOT)
				ci.draw_rect(Rect2(c2.position, Vector2(c2.size.x, BT)), HudTheme.ACCENT)
				ci.draw_rect(Rect2(c2.position.x, c2.end.y - BT, c2.size.x, BT), HudTheme.SPOT.darkened(0.3))
				ci.draw_rect(Rect2(c2.position.x + floorf(c2.size.x * 0.5 / BT) * BT - (BT if side == 0 else 0.0),
					c2.position.y + floorf((c2.size.y - BT) * 0.5 / BT) * BT, BT, BT), HudTheme.ACCENT_DK)
			## Pirinç uç (çubuk kapağının küçüğü)
			var tip := ["oSSSSo", "oASSAo", ".oSSo.", "..oo.."]
			pix_t(ci, tip, Vector2(-3.0 * BT, box.end.y - BT), {"o": HudTheme.ACCENT_DK, "S": HudTheme.SPOT, "A": HudTheme.ACCENT}, BT)
		"C":
			rrt(ci, box, HudTheme.OUTLINE, 2, BT)
			var i2: Rect2 = box.grow(-BT)
			rrt(ci, i2, HudTheme.RIM, 1, BT)
			ci.draw_rect(Rect2(i2.position.x + BT, i2.position.y, i2.size.x - 2.0 * BT, BT), HudTheme.RIM_HI)
			ci.draw_rect(Rect2(i2.position.x, i2.position.y + BT, BT, i2.size.y - 3.0 * BT), HudTheme.RIM_HI)
			ci.draw_rect(Rect2(i2.position.x + BT, i2.end.y - BT, i2.size.x - 2.0 * BT, BT), HudTheme.RIM_LO)
			## Kuyruk solda, sola eğik (konuşan karaktere doğru aşağı)
			var tl := ["oLAAAo", "oLAAo.", "oLAo..", "oAo...", "oo...."]
			pix_t(ci, tl, Vector2(box.position.x + 6.0 * BT, box.end.y - BT), {"o": HudTheme.OUTLINE, "A": HudTheme.RIM, "L": HudTheme.RIM_HI}, BT)
		_:
			rrt(ci, box, Color(HudTheme.DEEP, 0.74), 1, BT)
			var td := ["dddddd", ".dddd.", "..dd.."]
			pix_t(ci, td, Vector2(-3.0 * BT, box.end.y), {"d": Color(HudTheme.DEEP, 0.74)}, BT)
	var sh: Color = HudTheme.OUTLINE if style == "C" else (HudTheme.DEEP if style == "D" else Color(0, 0, 0, 0))
	for j in n:
		var lw: float = tw(lines[j], FS)
		var x: float = roundf(-lw * 0.5 / BT) * BT
		txt(ci, Vector2(x, box.position.y + pad_top + j * B_LP), lines[j], FS, HudTheme.TEXT, F, sh)
