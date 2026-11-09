extends Control

## ALTIN HEDİYESİ BİLDİRİMİ (madde 493, 2026-11-08; kullanıcı: "biri birine altın hediye edince altın hediye edilen kişiye daha görünür ve
## daha dikkat çekici bir bildirim gitsin"). Eskiden alıcıda yalnız ses + gönderenden uçan paralar + kalp + karakterin üstünde küçük yazı
## vardı; sağ sütun bildirimleri madde 404'ten beri bilerek küçük. Bu levha ÜST ORTADA (main.gd show_gift_notice -> _present_notice
## top_center; boss barı varken onun altı, telefonda da üst orta):
##   Gömme Tepsi (HudTrayKit.tray, grup paneli / bildirimlerle aynı doku) | solda GÖNDERENİN portresi (grup satırıyla aynı: koyu kuyu +
##   karakter bulanık arka planı + 16x16 yakın yüz 3x + HudTrayFrame) | "ALTIN HEDİYESİ" (PRICE, m5x7 32) + "<ad> sana altın gönderdi"
##   (ad ACCENT) | sağda "+N" PixeloidSans 27 PRICE (artı elle 5x5 piksel: yazı tipinin artısı nokta gibi kalıyor) + oyundaki altın para 3x.
##   Diğer bildirimlerden ayrışsın diye tepsinin içinde 3 px altın kenar (parıltı geçerken parlar).
## Dikkat çeken kısım (ölçek animasyonu YOK - stil rehberi 3): yukarıdan 3 px adımlarla kayarak gelir, miktar 0'dan sayarak artar, levhanın
## içinden iki kez eğik altın parıltı geçer, para simgesi parıltı geçerken bir kare parlar. Solma + silme main.gd _present_notice'te.
## Çizim _Body çocuğunda: kayma çocuğun konumuyla yapılır (HudTrayFrame global dönüşümle çizer, draw_set_transform'u görmez).

const HT := preload("res://scripts/hud_theme.gd")
const HudTrayKit := preload("res://scripts/hud_tray_kit.gd")
const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
const PortraitFace := preload("res://scripts/portrait_face.gd")
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
const NUM_FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const COIN_TEX: Texture2D = preload("res://assets/ui/newui/icon_gold_coin.png")
const AVATAR_BG: Texture2D = preload("res://assets/ui/kit/hud_avatar_bg.png")

const P := 3.0 ## 1 sanat px = 3 ekran px
const H := 102.0
const PAD := 21.0 ## tepsi çerçevesi 12 + 9
const FACE := 48.0
const FS := 32
const NUM_FS := 27
const COIN := 48.0 ## 16 x 3
const GAP := 15.0
const SLIDE_PX := 30.0
const SLIDE_TIME := 0.25
const COUNT_TIME := 0.7
const SHINES: Array[float] = [0.35, 1.5] ## parıltı geçişlerinin başladığı an (sn)
const SHINE_TIME := 0.6
const SHINE_W := 24.0
const PLUS: Array[String] = ["..X..", "..X..", "XXXXX", "..X..", "..X.."] ## dil:yok (piksel deseni)
const EDGE_A := 0.45 ## iç altın kenarın saydamlığı (parıltıda 0,9'a çıkar)

var from_name: String = ""
var amount: int = 0
var char_id: int = 0
var _t: float = 0.0
var _body: Control = null
var _title: String = ""
var _pre: String = ""
var _post: String = ""
var _name_shown: String = ""
var _text_w: float = 0.0
var _num_w: float = 0.0


static func make(p_from: String, p_amount: int, p_char: int) -> Control:
	var n: Control = (load("res://scripts/gift_notice.gd") as GDScript).new()
	n.set("from_name", p_from)
	n.set("amount", p_amount)
	n.set("char_id", p_char)
	n.call("_layout")
	return n


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _layout() -> void:
	_title = tr("ALTIN HEDİYESİ")
	var tpl: String = tr("%s sana altın gönderdi")
	var i: int = tpl.find("%s")
	_pre = tpl.substr(0, i) if i >= 0 else ""
	_post = tpl.substr(i + 2) if i >= 0 else " " + tpl
	_name_shown = from_name
	var name_max: float = 330.0 - _tw(_pre, FS) - _tw(_post, FS)
	while _name_shown.length() > 1 and _tw(_name_shown, FS) > name_max:
		_name_shown = _name_shown.substr(0, _name_shown.length() - 1)
	if _name_shown != from_name:
		_name_shown += "..."
	_text_w = maxf(_tw(_title, FS), _tw(_pre + _name_shown + _post, FS))
	_num_w = 5.0 * P + P + NUM_FONT.get_string_size("%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_FS).x
	var w: float = PAD + FACE + 8.0 + GAP + _text_w + 24.0 + _num_w + 6.0 + COIN + PAD
	w = ceilf(w / P) * P
	size = Vector2(w, H)
	custom_minimum_size = size
	if _body == null:
		_body = Control.new()
		_body.name = "Body"
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_body.draw.connect(_draw_body)
		add_child(_body)
	_body.size = size
	_place_body()


func _process(delta: float) -> void:
	_t += delta
	_place_body()
	if _body:
		_body.queue_redraw()


func _place_body() -> void:
	if _body == null:
		return
	var k: float = clampf(_t / SLIDE_TIME, 0.0, 1.0)
	modulate.a = minf(modulate.a, 1.0) if k >= 1.0 else k ## giriş saydamlığı (çıkıştaki solma main.gd'de modulate'ı ezer)
	_body.position = Vector2(0.0, -roundf(pow(1.0 - k, 3.0) * SLIDE_PX / P) * P)


## Ekranda görünen sayı (0'dan sayarak artar).
func shown_amount() -> int:
	var k: float = clampf(_t / COUNT_TIME, 0.0, 1.0)
	return int(round(float(amount) * (1.0 - pow(1.0 - k, 2.0))))


func _shine_phase() -> float:
	for s: float in SHINES:
		if _t >= s and _t < s + SHINE_TIME:
			return (_t - s) / SHINE_TIME
	return -1.0


func _draw_body() -> void:
	var ci: Control = _body
	var r := Rect2(Vector2.ZERO, size)
	ci.draw_style_box(HudTrayKit.tray(0.0, 0.0), r)
	## Portre
	var fp := Vector2(PAD + 4.0, roundf((H - FACE) * 0.5))
	ci.draw_rect(Rect2(fp, Vector2(FACE, FACE)), HT.DOCK_INSET)
	var bg: Texture2D = PortraitFace.background(char_id, PortraitFace.PARTY_N) if char_id > 0 else null
	var face: Texture2D = PortraitFace.face(char_id, PortraitFace.PARTY_N) if char_id > 0 else null
	ci.draw_texture_rect(bg if bg else AVATAR_BG, Rect2(fp, Vector2(FACE, FACE)), false)
	if face:
		ci.draw_texture_rect(face, Rect2(fp, Vector2(FACE, FACE)), false)
	HudTrayFrame.draw(ci, Rect2(fp - Vector2(4.0, 4.0), Vector2(FACE + 8.0, FACE + 8.0)), 1.0)
	## Yazı: başlık + "<ad> sana altın gönderdi"
	var tx: float = PAD + FACE + 8.0 + GAP
	var ty: float = roundf((H - 2.0 * FS) * 0.5) - 3.0
	_txt(ci, _title, Vector2(tx, ty), FS, HT.PRICE)
	var x: float = tx
	for part: Array in [[_pre, HT.TEXT], [_name_shown, HT.ACCENT], [_post, HT.TEXT]]:
		var s: String = str(part[0])
		if s == "":
			continue
		_txt(ci, s, Vector2(x, ty + FS), FS, part[1])
		x += _tw(s, FS)
	## Miktar + para
	var shine: float = _shine_phase()
	var coin_p := Vector2(size.x - PAD - COIN, roundf((H - COIN) * 0.5))
	ci.draw_texture_rect(COIN_TEX, Rect2(coin_p, Vector2(COIN, COIN)), false,
			Color(1.35, 1.3, 1.15) if shine > 0.55 and shine < 0.85 else Color.WHITE)
	var num: String = "%d" % shown_amount()
	var nw: float = NUM_FONT.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_FS).x
	var base := Vector2(roundf(coin_p.x - 6.0 - nw), roundf((H - NUM_FONT.get_height(NUM_FS)) * 0.5 + NUM_FONT.get_ascent(NUM_FS)))
	ci.draw_string(NUM_FONT, base + Vector2(P, P), num, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_FS, Color(HT.OUTLINE, 0.9)) ## dil:yok
	ci.draw_string(NUM_FONT, base, num, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_FS, HT.PRICE) ## dil:yok
	## Artı: rakamların ortasına hizalı (rakam boyu 7 sanat px)
	var cap: float = 7.0 * P
	var plus_p := Vector2(base.x - P - 5.0 * P, roundf((base.y - cap + (cap - 5.0 * P) * 0.5) / P) * P)
	_pix(ci, PLUS, plus_p + Vector2(P, P), Color(HT.OUTLINE, 0.9))
	_pix(ci, PLUS, plus_p, HT.PRICE)
	## İç altın kenar (tepsi çerçevesinin hemen içi)
	var edge_a: float = EDGE_A
	if shine >= 0.0:
		edge_a = lerpf(EDGE_A, 0.9, sin(shine * PI))
	var ir: Rect2 = r.grow(-12.0)
	var ec := Color(HT.PRICE, edge_a)
	ci.draw_rect(Rect2(ir.position, Vector2(ir.size.x, P)), ec)
	ci.draw_rect(Rect2(ir.position + Vector2(0.0, ir.size.y - P), Vector2(ir.size.x, P)), ec)
	ci.draw_rect(Rect2(ir.position + Vector2(0.0, P), Vector2(P, ir.size.y - 2.0 * P)), ec)
	ci.draw_rect(Rect2(ir.position + Vector2(ir.size.x - P, P), Vector2(P, ir.size.y - 2.0 * P)), ec)
	## Eğik altın parıltı (3 px satırlar, tepsinin iç kenarında kırpılır)
	if shine >= 0.0:
		var x0: float = 12.0
		var x1: float = size.x - 12.0
		var head: float = lerpf(x0 - SHINE_W - H * 0.5, x1, shine)
		var y: float = 12.0
		while y < H - 12.0:
			var sx: float = roundf((head + (H - y) * 0.5) / P) * P
			for band: Array in [[0.0, SHINE_W, 0.14], [P * 2.0, SHINE_W - P * 4.0, 0.24]]:
				var a: float = maxf(x0, sx + float(band[0]))
				var b: float = minf(x1, sx + float(band[0]) + float(band[1]))
				if b > a:
					ci.draw_rect(Rect2(a, y, b - a, P), Color(HT.ACCENT, float(band[2])))
			y += P


func _pix(ci: CanvasItem, rows: Array[String], pos: Vector2, c: Color) -> void:
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "X":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * P, Vector2(P, P)), c)


func _tw(s: String, fs: int) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Bildirim levhalarıyla aynı: 3 px aşağı-sağ koyu gölge.
func _txt(ci: CanvasItem, s: String, pos: Vector2, fs: int, c: Color) -> void:
	var base := Vector2(roundf(pos.x), roundf(pos.y + FONT.get_ascent(fs)))
	ci.draw_string(FONT, base + Vector2(P, P), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(HT.OUTLINE, 0.9)) ## dil:yok (metin _layout'ta çevrildi)
	ci.draw_string(FONT, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c) ## dil:yok
