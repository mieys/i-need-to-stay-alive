extends Control

## OYUN İÇİ BİLDİRİM LEVHALARI - "A Ahşap Levha" (kullanıcı seçimi 2026-10-18, madde 264; prototip
## tools/proto_20261018/bildirim_proto.gd, madde 260). Eski bej kit levhaları (UIKit "window_tight") yerine HUD'un Kısık Ahşap
## levhası (party_panel._plaque_style, grup paneliyle aynı doku) + piksel çizim:
##  - toast(): sağ sütundaki küçük bildirim - solda tür renkli simge kuyusu, başlık (tür rengi) + sarılan gövde, altta tükenen
##    fitil (hold sürede biter; hold <= 0 = fitil yok). countdown >= 0: başlık satırının sağında geri sayan "N sn".
##  - banner(): üst ortadaki duyuru (kademe / sonsuz mod / debug uyarısı) - levha + kumaş kurdele + gövde; tier > 0 ise gerçek
##    kuru kafa satırı (tier_display.gd) çocuk olarak.
##  - complete(): "Görev Tamamlandı" penceresinin gövdesi (mission_complete_window.gd) - altın kurdele, tikli görev adı, ödül
##    kuyuları; altın kuyusunun merkezi coin_center() (paralar oradan altın paneline uçar).
## Yerleşim/yığma/solma çağıranda (main.gd _present_notice); bu düğüm yalnız kendi boyunu (size = custom_minimum_size) bilir,
## çizer ve girişte sağdan kayar. Tıklamayı yutmaz. Yazı m5x7 24 (telefonda 32) - 8'in katları keskin.

const HT := preload("res://scripts/hud_theme.gd")
const PartyPanelScript := preload("res://scripts/party_panel.gd")
const TierDisplayScript := preload("res://scripts/tier_display.gd")
const FONT := preload("res://assets/fonts/m5x7.ttf")
const MEDAL_TEX := preload("res://assets/items/lutuf_madalyonu.png")
const MERCHANT_SHEET := preload("res://assets/npc/seyyar_satici/sheets/idle.png")
const COIN_TEX := preload("res://assets/ui/newui/icon_gold_coin.png")
const SHARD_TEX := preload("res://assets/pickups/weapon_shard/shard_icon.png")

## Tür renkleri: görev uyarısı/başlangıcı minimap işaretleriyle aynı aile (uyarı açık mavi "?", aktif kırmızı-turuncu "!").
const KIND_COLOR := {
	"ok": Color("#f0c070"),
	"warn": Color("#a8d0f0"),
	"start": Color("#f0a060"),
	"fail": Color("#e8735e"),
	"merchant": Color("#9fd4b4"),
	"ach": Color("#c9a2f0"),
	"left": Color("#b8ac96"),
	"info": Color("#ecd9b0"),
	"tier": Color("#e0604c"),
}
const RIB_GOLD := {"fill": Color("#d9a54a"), "hi": Color("#f2cd7c"), "dk": Color("#8a5a20"), "text": Color("#2a1a0c"), "shadow": false}
const RIB_RED := {"fill": Color("#a8403a"), "hi": Color("#cf6a58"), "dk": Color("#5e1c16"), "text": Color("#f6e6cc"), "shadow": true}

const TOAST_W := 400.0
const TOAST_W_PHONE := 640.0
const PAD := 12.0
const WELL := 54.0
const RIBBON_H := 54.0
const PLAQUE_TOP := 30.0 ## kurdele levhanın üst kenarına biner
const SLIDE_PX := 40.0
const SLIDE_TIME := 0.22

## Piksel simgeler (3 px hücre; büyük pencerede 6 px).
const CHECK := [
	"  OOOOO  ",
	" OGGGGGO ",
	"OGGGGGWGO",
	"OGGGGWWGO",
	"OGWGWWGGO",
	"OGWWWGGGO",
	"OGGWGGGGO",
	" OGGGGGO ",
	"  OOOOO  ",
]
const XMARK := [
	"OOO   OOO",
	"ORRO ORRO",
	"OORRORROO",
	" OORRROO ",
	"  ORRRO  ",
	" OORRROO ",
	"OORRORROO",
	"ORRO ORRO",
	"OOO   OOO",
]
const FLAG := [
	"OO         ",
	"OWOOOOOOOO ",
	"OWORRRRRRRO",
	"OWORRRRRRO ",
	"OWORRRRRO  ",
	"OWORRRRRRO ",
	"OWORRRRRRRO",
	"OWOOOOOOOO ",
	"OWO        ",
	"OWO        ",
	"OWO        ",
	"OOO        ",
]
const HOURGLASS := [
	"OOOOOOOOO",
	"OWWWWWWWO",
	"OOOOOOOOO",
	" OSSSSSO ",
	"  OSSSO  ",
	"   OSO   ",
	"   OgO   ",
	"  OgSgO  ",
	" OgSSSgO ",
	"OOOOOOOOO",
	"OWWWWWWWO",
	"OOOOOOOOO",
]
const INFO := [
	"  OOOOO  ",
	" OIIIIIO ",
	"OIIIWIIIO",
	"OIIIIIIIO",
	"OIIIWIIIO",
	"OIIIWIIIO",
	"OIIIWIIIO",
	" OIIIIIO ",
	"  OOOOO  ",
]
const DOOR := [
	"OOOOOOO  ",
	"OBBBBBO  ",
	"OBOOOBO  ",
	"OBO OBO  ",
	"OBO OBO O",
	"OBO OBOOWO",
	"OBO OBWWWWO",
	"OBO OBOOWO",
	"OBO OBO O",
	"OBOOOBO  ",
	"OBBBBBO  ",
	"OOOOOOO  ",
]

var variant: String = "toast" ## toast / banner / complete
var kind: String = "info"
var title: String = ""
var body: String = ""
var hold: float = 2.4
var countdown: float = -1.0
var portrait: Texture2D = null
var fs: int = 24
var tier: int = 0
var gold: int = 0
var shards: int = 0

var _lines: PackedStringArray = PackedStringArray()
var _title_lines: PackedStringArray = PackedStringArray() ## toast: uzun başlık da sarılır (kesilmez)
var _t: float = 0.0
var _cd_t0: float = 0.0
var _plaque: StyleBox = null
var _coin_center: Vector2 = Vector2(-1, -1)
var _merchant_tex: AtlasTexture = null
var _slide_done: bool = false


## Sağ sütun bildirimi. kind: KIND_COLOR anahtarı. phone = telefon yerleşimi (geniş + 32 px yazı).
static func toast(kind_: String, title_: String, body_: String = "", hold_: float = 2.4, phone: bool = false) -> Control:
	var n: Control = (load("res://scripts/game_notice.gd") as GDScript).new()
	n.set("variant", "toast")
	n.set("kind", kind_)
	n.set("title", title_)
	n.set("body", body_)
	n.set("hold", hold_)
	n.set("fs", 32 if phone else 24)
	n.call("_layout")
	return n


## Üst orta duyuru: kurdele yazısı + gövde (sarılır) + tier > 0 ise kuru kafa satırı. kind "tier"/"fail" kırmızı, diğerleri altın.
static func banner(kind_: String, ribbon_text: String, body_: String = "", hold_: float = 4.0, tier_: int = 0) -> Control:
	var n: Control = (load("res://scripts/game_notice.gd") as GDScript).new()
	n.set("variant", "banner")
	n.set("kind", kind_)
	n.set("title", ribbon_text)
	n.set("body", body_)
	n.set("hold", hold_)
	n.set("tier", tier_)
	n.call("_layout")
	return n


## "Görev Tamamlandı" gövdesi. gold 0 ise altın kuyusu çıkmaz (oyuncu görev bölgesinde değildi).
static func complete(mission_label: String, gold_: int, shards_: int, hold_: float) -> Control:
	var n: Control = (load("res://scripts/game_notice.gd") as GDScript).new()
	n.set("variant", "complete")
	n.set("kind", "ok")
	n.set("title", "GÖREV TAMAMLANDI")
	n.set("body", mission_label)
	n.set("gold", gold_)
	n.set("shards", shards_)
	n.set("hold", hold_)
	n.call("_layout")
	return n


## Görev uyarısının canlı geri sayımı (ağdan gelen yeni değerle yeniden kurulabilir).
func set_countdown(seconds: float) -> void:
	var first: bool = countdown < 0.0
	countdown = seconds
	_cd_t0 = _t
	if first and variant == "toast":
		_layout() ## başlığın ilk satırında sayaca yer aç
	queue_redraw()


## complete: altın kuyusunun YEREL merkezi (yoksa -1,-1).
func coin_center() -> Vector2:
	return _coin_center


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if not _slide_done:
		var k: float = clampf(_t / SLIDE_TIME, 0.0, 1.0)
		modulate.a = k
		if k >= 1.0:
			_slide_done = true
	queue_redraw()


func _layout() -> void:
	_plaque = PartyPanelScript._plaque_style(14.0, 8.0)
	## "complete" kendi penceresinin (mission_complete_window.gd) zıplama/solmasıyla gelir - burada ayrıca solmaz.
	_slide_done = variant == "complete"
	match variant:
		"toast":
			var w: float = TOAST_W_PHONE if fs > 24 else TOAST_W
			var tx: float = PAD + WELL + 14.0
			var cd_w: float = (_tw("99 sn", fs) + 12.0) if countdown >= 0.0 else 0.0
			_title_lines = _wrap(title, fs, w - 16.0 - tx - cd_w)
			_lines = _wrap(body, fs, w - 16.0 - tx)
			var text_h: float = maxf(1.0, _title_lines.size()) * fs + (3.0 + _lines.size() * fs if _lines.size() > 0 else 0.0)
			var h: float = maxf(PAD + WELL + 18.0, 14.0 + text_h + 20.0)
			size = Vector2(w, h)
		"banner":
			var rw: float = maxf(330.0, _tw(title, 32) + 80.0)
			_lines = _wrap(body, fs, 560.0)
			var text_w: float = 0.0
			for l in _lines:
				text_w = maxf(text_w, _tw(l, fs))
			var content_h: float = 0.0
			if tier > 0:
				content_h += TierDisplayScript.SKULL_H * 4.0
			if _lines.size() > 0:
				content_h += (8.0 if tier > 0 else 0.0) + _lines.size() * fs
			var pw: float = maxf(maxf(420.0, text_w + 64.0), rw + 96.0)
			var ph: float = 40.0 + content_h + 22.0
			size = Vector2(pw, PLAQUE_TOP + ph)
			if tier > 0:
				var row := Control.new()
				row.set_script(TierDisplayScript)
				add_child(row)
				row.call("set_tier", tier, 4)
				row.position = Vector2(roundf((pw - row.size.x) * 0.5), PLAQUE_TOP + 40.0)
		"complete":
			size = Vector2(600.0, PLAQUE_TOP + 182.0)
			for p in _rewards():
				if p[5]:
					_coin_center = (p[6] as Vector2) + Vector2(27.0, 27.0)
	custom_minimum_size = size
	pivot_offset = size * 0.5


# ------------------------------------------------------------ çizim
func _draw() -> void:
	var slide: float = 0.0
	if variant == "toast" and not _slide_done:
		var k: float = clampf(_t / SLIDE_TIME, 0.0, 1.0)
		slide = roundf(pow(1.0 - k, 3.0) * SLIDE_PX / 3.0) * 3.0 ## sağdan kayarak gelir (3 px adım)
	draw_set_transform(Vector2(slide, 0.0))
	match variant:
		"toast":
			_draw_toast()
		"banner":
			_draw_banner()
		"complete":
			_draw_complete()
	draw_set_transform(Vector2.ZERO)


func _remaining() -> float:
	if hold <= 0.0:
		return -1.0
	return clampf(1.0 - _t / hold, 0.0, 1.0)


func _draw_fuse(x: float, y: float, w: float, col: Color) -> void:
	var rem: float = _remaining()
	if rem < 0.0:
		return
	_r(x, y, w, 3, Color(HT.INSET, 0.9))
	_r(x, y, roundf(w * rem / 3.0) * 3.0, 3, col)


func _draw_toast() -> void:
	var col: Color = KIND_COLOR.get(kind, KIND_COLOR["info"])
	var w: float = size.x
	var h: float = size.y
	_plaque.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var well := Rect2(Vector2(PAD, roundf((h - 6.0 - WELL) * 0.5)), Vector2(WELL, WELL))
	_frame(well, HT.INSET, col.darkened(0.3))
	_icon(kind, well.get_center(), false)
	var tx: float = PAD + WELL + 14.0
	var text_h: float = _title_lines.size() * fs + (3.0 + _lines.size() * fs if _lines.size() > 0 else 0.0)
	var ty: float = roundf(maxf(13.0, (h - 6.0 - text_h) * 0.5 - fs * 0.12))
	if countdown >= 0.0:
		var left: float = maxf(0.0, countdown - (_t - _cd_t0))
		_txt_r("%d sn" % int(ceil(left)), w - 16.0, ty, fs, HT.PRICE)
	for i in _title_lines.size():
		_txt(_title_lines[i], Vector2(tx, ty + i * fs), fs, col)
	var by: float = ty + _title_lines.size() * fs + 3.0
	for i in _lines.size():
		_txt(_lines[i], Vector2(tx, by + i * fs), fs, HT.DIM)
	_draw_fuse(PAD, h - 12.0, w - 2.0 * PAD, col)


func _draw_banner() -> void:
	var red: bool = kind == "tier" or kind == "fail"
	var pal: Dictionary = RIB_RED if red else RIB_GOLD
	var w: float = size.x
	var cx: float = roundf(w * 0.5)
	var prc := Rect2(0, PLAQUE_TOP, w, size.y - PLAQUE_TOP)
	_plaque.draw(get_canvas_item(), prc)
	var rw: float = maxf(330.0, _tw(title, 32) + 80.0)
	_ribbon(cx, 0.0, rw, RIBBON_H, pal)
	_txt_c(title, cx, 12.0, 32, pal["text"], pal["shadow"])
	var y: float = PLAQUE_TOP + 40.0
	if tier > 0:
		y += TierDisplayScript.SKULL_H * 4.0 + 8.0
	for i in _lines.size():
		_txt_c(_lines[i], cx, y + i * fs, fs, HT.TEXT)
	_draw_fuse(16.0, size.y - 14.0, w - 32.0, KIND_COLOR["tier"] if red else KIND_COLOR["ok"])


func _draw_complete() -> void:
	var w: float = size.x
	var cx: float = roundf(w * 0.5)
	var prc := Rect2(0, PLAQUE_TOP, w, size.y - PLAQUE_TOP)
	_plaque.draw(get_canvas_item(), prc)
	_ribbon(cx, 0.0, 470.0, RIBBON_H, RIB_GOLD)
	_txt_c(title, cx, 12.0, 32, RIB_GOLD["text"], false)
	var y0: float = PLAQUE_TOP + 38.0
	var name_w: float = 27.0 + 12.0 + _tw(body, 32)
	var nx: float = roundf(cx - name_w * 0.5)
	_icon("ok", Vector2(nx + 13.0, y0 + 16.0), false)
	_txt(body, Vector2(nx + 39.0, y0), 32, HT.TEXT)
	var dy: float = y0 + 46.0
	_r(24, dy, w - 48, 3, HT.RIM_LO)
	_r(24, dy + 3, w - 48, 3, Color(HT.RIM_HI, 0.35))
	for p in _rewards():
		var o: Vector2 = p[6]
		_frame(Rect2(o, Vector2(54, 54)), HT.INSET, HT.RIM_LO)
		_tex_c(p[0], o + Vector2(27.0, 27.0), p[1])
		_txt(p[2], o + Vector2(66.0, 10.0), 32, p[3])
		_txt(p[4], o + Vector2(66.0 + _tw(p[2], 32) + 8.0, 17.0), 24, HT.DIM)
	_draw_fuse(16.0, size.y - 14.0, w - 32.0, KIND_COLOR["ok"])


## complete: ödül kuyuları [doku, boyut, sayı, renk, etiket, altın mı, kuyu sol üstü], ortalı tek satır.
func _rewards() -> Array:
	var parts: Array = []
	if gold > 0:
		parts.append([COIN_TEX, 32.0, "+%d" % gold, HT.PRICE, "altın", true])
	if shards > 0:
		parts.append([SHARD_TEX, 44.0, "+%d" % shards, HT.SHARD, "Silah Parçacığı", false])
	var widths: Array = []
	var total: float = 0.0
	for p in parts:
		var pw: float = 54.0 + 12.0 + _tw(p[2], 32) + 8.0 + _tw(p[4], 24)
		widths.append(pw)
		total += pw
	total += 44.0 * maxf(0.0, parts.size() - 1.0)
	var x: float = roundf(size.x * 0.5 - total * 0.5)
	var ry: float = PLAQUE_TOP + 38.0 + 46.0 + 18.0
	for i in parts.size():
		(parts[i] as Array).append(Vector2(x, ry))
		x += float(widths[i]) + 44.0
	return parts


# ------------------------------------------------------------ simgeler
func _icon(k: String, c: Vector2, big: bool) -> void:
	var s: float = 6.0 if big else 3.0
	match k:
		"ok":
			_grid(CHECK, c, s, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})
		"warn":
			_grid(HOURGLASS, c, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "S": Color("#e8b860"), "g": Color(0.55, 0.7, 0.8, 0.3)})
		"start":
			_grid(FLAG, c, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "R": KIND_COLOR["start"]})
		"fail":
			_grid(XMARK, c, s, {"O": HT.OUTLINE, "R": KIND_COLOR["fail"]})
		"merchant":
			if _merchant_tex == null:
				## idle karesinin baş-gövde kısmı (figür 48 px karenin ortasında ~14x33) - 2x
				_merchant_tex = AtlasTexture.new()
				_merchant_tex.atlas = MERCHANT_SHEET
				_merchant_tex.region = Rect2(12, 6, 24, 24)
			_tex_c(_merchant_tex, c, 96.0 if big else 48.0)
		"ach":
			_tex_c(MEDAL_TEX, c, 64.0 if big else 32.0)
		"left":
			if portrait != null:
				_tex_c(portrait, c, 96.0 if big else 48.0, Color(0.62, 0.6, 0.58, 0.85))
			else:
				_grid(DOOR, c, s, {"O": HT.OUTLINE, "B": HT.RIM_HI, "W": KIND_COLOR["left"]})
		_:
			_grid(INFO, c, s, {"O": HT.OUTLINE, "I": Color("#c9963e"), "W": Color("#f6ecd2")})


func _grid(rows: Array, c: Vector2, s: float, cols: Dictionary) -> void:
	var gw: int = 0
	for row: String in rows:
		gw = maxi(gw, row.length())
	var o := Vector2(roundf(c.x - gw * s * 0.5), roundf(c.y - rows.size() * s * 0.5))
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			var ch: String = row[i]
			if cols.has(ch):
				_r(o.x + i * s, o.y + j * s, s, s, cols[ch])


func _tex_c(t: Texture2D, c: Vector2, sz: float, mod: Color = Color.WHITE) -> void:
	if t == null:
		return
	draw_texture_rect(t, Rect2(roundf(c.x - sz * 0.5), roundf(c.y - sz * 0.5), sz, sz), false, mod)


# ------------------------------------------------------------ piksel yardımcıları
func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)


## Köşeleri bir birim kesik çerçeve (piksel yuvarlak köşe).
func _frame(rc: Rect2, fill: Color, border: Color, bw: float = 3.0) -> void:
	var x := rc.position.x
	var y := rc.position.y
	var w := rc.size.x
	var h := rc.size.y
	if fill.a > 0.0:
		_r(x + bw, y + bw, w - 2.0 * bw, h - 2.0 * bw, fill)
	_r(x + bw, y, w - 2.0 * bw, bw, border)
	_r(x + bw, y + h - bw, w - 2.0 * bw, bw, border)
	_r(x, y + bw, bw, h - 2.0 * bw, border)
	_r(x + w - bw, y + bw, bw, h - 2.0 * bw, border)


## Kırlangıç kuyruklu kurdele ucu (3 px satırlarla). notch = çentik derinliği.
func _pennant(rc: Rect2, fill: Color, edge: Color, notch: float, notch_left: bool) -> void:
	var n := int(rc.size.y / 3.0)
	for pass_ in 2:
		var g: float = 0.0 if pass_ == 0 else 3.0
		var c: Color = edge if pass_ == 0 else fill
		var skip := int(g / 3.0)
		for j in range(skip, n - skip):
			var v: float = (j + 0.5) / float(n)
			var ins: float = roundf(notch * (1.0 - absf(v - 0.5) * 2.0) / 3.0) * 3.0 + g
			var y: float = rc.position.y + j * 3.0
			if notch_left:
				_r(rc.position.x + ins, y, rc.size.x - ins - g, 3.0, c)
			else:
				_r(rc.position.x + g, y, rc.size.x - ins - g, 3.0, c)


## Kumaş kurdele: arkada çentikli iki kuyruk, önde düz şerit.
func _ribbon(cx: float, y: float, w: float, h: float, pal: Dictionary) -> void:
	var x: float = roundf(cx - w * 0.5)
	var th: float = h - 12.0
	_pennant(Rect2(x - 48.0, y + 18.0, 66.0, th), pal["dk"], HT.OUTLINE, 15.0, true)
	_pennant(Rect2(x + w - 18.0, y + 18.0, 66.0, th), pal["dk"], HT.OUTLINE, 15.0, false)
	_frame(Rect2(x, y, w, h), pal["fill"], HT.OUTLINE)
	_r(x + 3, y + 3, w - 6, 3, pal["hi"])
	_r(x + 3, y + h - 6, w - 6, 3, (pal["fill"] as Color).darkened(0.18))


func _tw(s: String, size_: int) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_).x


## pos = yazı kutusunun sol üstü; en fazla 3 px aşağı-sağ gölge.
func _txt(s: String, pos: Vector2, size_: int, c: Color, shadow: bool = true) -> void:
	var u: float = minf(size_ / 8.0, 3.0)
	var base := Vector2(roundf(pos.x), roundf(pos.y + FONT.get_ascent(size_)))
	if shadow:
		draw_string(FONT, base + Vector2(u, u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, Color(HT.OUTLINE, 0.9))
	draw_string(FONT, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, c)


func _txt_c(s: String, cx: float, y: float, size_: int, c: Color, shadow: bool = true) -> void:
	_txt(s, Vector2(roundf(cx - _tw(s, size_) * 0.5), y), size_, c, shadow)


func _txt_r(s: String, right: float, y: float, size_: int, c: Color) -> void:
	_txt(s, Vector2(roundf(right - _tw(s, size_)), y), size_, c)


func _wrap(s: String, size_: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	if s == "":
		return out
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var cand: String = word if line == "" else line + " " + word
			if line == "" or _tw(cand, size_) <= width:
				line = cand
			else:
				out.append(line)
				line = word
		if line != "":
			out.append(line)
	return out
