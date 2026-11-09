extends Control

## SOHBET PENCERESİ "C - Portreli Mesajlar" (madde 499, 2026-11-08; MASAÜSTÜ - telefonun harita üstü yazısı / hızlı sohbeti hud.gd'de, değişmedi).
## Kullanıcı madde 495 prototiplerinden "C" + "ama okunur olmasını sağla" + "biri birine altın gönderince chatte gözüksün kimin kime altın gönderdiği".
## Sol altta, kutu yok: mesaj başına grup paneli yüz yuvası (PortraitFace 16, 3x = 48, karakterin bulanık arka planı + Gömme Tepsi çerçevesi) + sola
## kuyruklu koyu kutu, üstte ad (oyuncu renginde), altında mesaj (krem). OKUNURLUK: her görünen kutu tam opak (prototipteki yaşa göre solma YOK),
## koyu kutuda krem m5x7 32. Okurken son 4 mesaj, LIFETIME sn sonra 1 sn'de söner; yazarken (hud.gd _open_chat_input -> set_typing) son 6 mesaj tam,
## altlarında hud.gd'nin LineEdit'i (gömme kuyu + kabarık "Enter" levhası). Altın hediyesi: yüz yerine altın + pirinç halka, "Gönderen » Alan" +
## "N altın gönderdi". DEBUG satırı: kırmızı "!". EMOJİ (kullanıcı: "chate emoji butonu ve biraz emoji ekle"): yazı kutusunun sağında emoji yuvası
## (HUD yetenek yuvası gibi kuyu + Gömme Tepsi çerçevesi), tıklayınca üstünde 6x2 seçici tepsi; seçilen ":anahtar:" jetonu imlece yazılır,
## mesajda/balonda resim olarak çizilir (chat_emoji.gd). Düğmeler odak ALMAZ (yazı kutusu odağı bırakınca sohbet kapanıyor).
## Kutular ayrı Block düğümü: sönen kutu yüz dokusu ve çerçevesiyle birlikte modulate'le söner. hud.gd UI saydamlığı (register_ui_opacity) bu
## düğümün modulate'ini kullanır. Malzeme/renkler: hud_theme.gd, hud_tray_frame.gd; prototip tools/proto_20261108/sohbet/sohbet_proto.gd.
## Kullanım (hud.gd): add_message(ad, metin, char_id, renk) / add_gift(gönderen, renk, alan, renk, miktar) / add_system(ad, metin) / set_typing(b) /
## attach_input(LineEdit) (yazı kutusu SLOT + 6 px sağdan kısaltılmış olmalı).

const HudTheme := preload("res://scripts/hud_theme.gd")
const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
const PortraitFace := preload("res://scripts/portrait_face.gd")
const ChatBubbleScript := preload("res://scripts/chat_bubble.gd")
const ChatEmoji := preload("res://scripts/chat_emoji.gd")
const HudTrayKit := preload("res://scripts/hud_tray_kit.gd")
const Loc := preload("res://scripts/localization.gd")
const F: Font = preload("res://assets/fonts/m5x7.ttf")
const GOLD_TEX: Texture2D = preload("res://assets/ui/newui/icon_gold_coin.png")

const P := 3.0 ## 1 sanat pikseli
const FS := 32
const LP := 30.0 ## satır aralığı
const CAP := 14.0 ## m5x7 32'de büyük harf yüksekliği (7 yazı pikseli x 2)
const W := 480.0
const FACE := 48.0
const BOX_X := FACE + 12.0 ## kutunun solu (aradaki 12 px'te kuyruk)
const TEXT_PAD := 15.0
const MAX_TEXT := W - BOX_X - 2.0 * TEXT_PAD
const NAME_Y := 12.0 ## kutunun üstünden ad satırının büyük harf üstüne
const GAP := 9.0
const INPUT_H := 45.0
const INPUT_GAP := 12.0
const BLOCKS_MAX_H := 560.0
const HEIGHT := BLOCKS_MAX_H + INPUT_GAP + INPUT_H
const SHOW_IDLE := 4
const SHOW_TYPING := 6
const LIFETIME := 30.0 ## okurken mesaj bu kadar sn tam görünür
const FADE := 1.0
const MAX_ENTRIES := 50
const SLOT := 45.0 ## emoji yuvası (yazı kutusuyla aynı boy)
const PICK_COLS := 6
const PICK_GAP := 6.0
const PICK_PAD := 15.0

const TAIL := ["..oo", ".oSS", "oSSS", ".oSS", "..oo"]
const ALERT := ["oo", "oo", "oo", "..", "oo"]
const PROF := {1: [1], 2: [2, 1]}

var entries: Array = [] ## {kind, name, color, char_id, lines, t} / gift: {from, from_col, to, to_col, amount}
var typing: bool = false
var _blocks: Array = []
var _input: LineEdit = null
var _emoji_btn: Button = null
var _picker: Control = null


class Block extends Control:
	var e: Dictionary
	var win: Object
	func _draw() -> void:
		win.call("_draw_block", self, e)


## Emoji yuvası (HUD yetenek yuvası dili): koyu kuyu + emoji 3x + Gömme Tepsi çerçevesi; üstündeyken / açıkken çerçevenin ahşabı altın.
class EmojiSlot extends Button:
	var key: String = ""
	var lit: bool = false
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, HudTheme.DOCK_INSET)
		var t: Texture2D = ChatEmoji.tex(key)
		if t:
			var ep: float = ChatEmoji.SIZE * 3.0
			draw_texture_rect(t, Rect2(((size - Vector2(ep, ep)) * 0.5).floor(), Vector2(ep, ep)), false)
		var accent: Color = HudTheme.ACCENT if lit else (HudTheme.ACCENT_SOFT if is_hovered() else Color(0, 0, 0, 0))
		HudTrayFrame.draw(self, r, 1.0, accent)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func add_message(sender_name: String, text: String, char_id: int, color: Color) -> void:
	_push({"kind": "msg", "name": sender_name, "color": color, "char_id": char_id,
		"lines": wrap_lines(text)})


## Sistem satırı (DEBUG uyarısı): yüz yerine kırmızı "!".
func add_system(title: String, text: String) -> void:
	_push({"kind": "sys", "name": title, "color": HudTheme.BAD, "char_id": -1, "lines": wrap_lines(text)})


func add_gift(from_name: String, from_col: Color, to_name: String, to_col: Color, amount: int) -> void:
	_push({"kind": "gift", "from": from_name, "from_col": from_col, "to": to_name, "to_col": to_col, "amount": amount,
		"lines": PackedStringArray([Loc.t("%d altın gönderdi") % amount])})


func set_typing(on: bool) -> void:
	if typing == on:
		return
	typing = on
	if _emoji_btn:
		_emoji_btn.visible = on
	_set_picker(false)
	_relayout()


## hud.gd yazı kutusunu verir: sağında emoji yuvası + üstünde seçici kurulur.
func attach_input(le: LineEdit) -> void:
	_input = le
	var eb := EmojiSlot.new()
	eb.name = "EmojiButton"
	eb.key = "gul"
	eb.position = Vector2(W - SLOT, HEIGHT - SLOT)
	eb.size = Vector2(SLOT, SLOT)
	eb.tooltip_text = "Emoji"
	eb.visible = typing
	eb.pressed.connect(func() -> void: _set_picker(not is_picker_open()))
	add_child(eb)
	_emoji_btn = eb
	_picker = Control.new()
	_picker.name = "EmojiPicker"
	_picker.z_index = 1 ## mesaj kutuları (sonradan eklenen Block'lar) seçicinin üstüne çıkmasın
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows: int = ceili(float(ChatEmoji.LIST.size()) / PICK_COLS)
	var pw: float = PICK_COLS * SLOT + (PICK_COLS - 1) * PICK_GAP + 2.0 * PICK_PAD
	var ph: float = rows * SLOT + (rows - 1) * PICK_GAP + 2.0 * PICK_PAD
	_picker.size = Vector2(pw, ph)
	_picker.position = Vector2(W - pw, HEIGHT - INPUT_H - INPUT_GAP - ph)
	_picker.visible = false
	_picker.draw.connect(func() -> void: _picker.draw_style_box(HudTrayKit.tray(0.0, 0.0), Rect2(Vector2.ZERO, _picker.size)))
	add_child(_picker)
	for i in ChatEmoji.LIST.size():
		var b := EmojiSlot.new()
		b.key = ChatEmoji.LIST[i]
		b.tooltip_text = ChatEmoji.token(b.key)
		b.position = Vector2(PICK_PAD + (i % PICK_COLS) * (SLOT + PICK_GAP), PICK_PAD + floorf(float(i) / PICK_COLS) * (SLOT + PICK_GAP))
		b.size = Vector2(SLOT, SLOT)
		b.pressed.connect(_pick_emoji.bind(b.key))
		_picker.add_child(b)


func _set_picker(on: bool) -> void:
	if _picker == null:
		return
	_picker.visible = on and typing
	if _emoji_btn:
		(_emoji_btn as EmojiSlot).lit = _picker.visible
		_emoji_btn.queue_redraw()


func is_picker_open() -> bool:
	return _picker != null and _picker.visible


## Seçilen emojinin jetonu imlece yazılır (önünde boşluk yoksa eklenir), seçici kapanır; odak yazı kutusunda kalır.
func _pick_emoji(key: String) -> void:
	if _input == null or not is_instance_valid(_input):
		return
	var before: String = _input.text.substr(0, _input.caret_column)
	var ins: String = ChatEmoji.token(key) + " "
	if before != "" and not before.ends_with(" "):
		ins = " " + ins
	_input.insert_text_at_caret(ins)
	_set_picker(false)
	if not _input.has_focus():
		_input.grab_focus()


static func wrap_lines(text: String) -> PackedStringArray:
	return ChatEmoji.wrap(text, F, FS, MAX_TEXT, P, ChatBubbleScript.MAX_LINES)


## Emoji jetonları resim genişliğiyle ölçülür.
static func text_w(s: String) -> float:
	return ChatEmoji.measure(s, F, FS, P)


static func s3(v: float) -> float:
	return ceilf(v / P) * P


func _push(e: Dictionary) -> void:
	e["t"] = Time.get_ticks_msec()
	entries.append(e)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	_relayout()


## İlk satır (ad / "Gönderen » Alan") genişliği.
static func head_w(e: Dictionary) -> float:
	if e["kind"] == "gift":
		return text_w(str(e["from"]) + " » " + str(e["to"]))
	return text_w(str(e["name"]))


static func block_h(e: Dictionary) -> float:
	return s3((e["lines"] as PackedStringArray).size() * LP + 39.0)


static func box_w(e: Dictionary) -> float:
	var w: float = head_w(e)
	for li: String in e["lines"]:
		w = maxf(w, text_w(li))
	return s3(minf(w, MAX_TEXT) + 2.0 * TEXT_PAD)


func _age(e: Dictionary) -> float:
	return float(Time.get_ticks_msec() - int(e["t"])) / 1000.0


## Görünecek kutular (en yeni sonda): yazarken son 6, okurken süresi dolmamış son 4; yükseklik sınırına sığanlar.
func visible_entries() -> Array:
	var out: Array = []
	var n_max: int = SHOW_TYPING if typing else SHOW_IDLE
	var h: float = 0.0
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		if not typing and _age(e) >= LIFETIME + FADE:
			break
		var bh: float = block_h(e)
		if out.size() >= n_max or (not out.is_empty() and h + GAP + bh > BLOCKS_MAX_H):
			break
		h += bh + (GAP if not out.is_empty() else 0.0)
		out.push_front(e)
	return out


func _relayout() -> void:
	for b in _blocks:
		(b as Node).queue_free()
	_blocks.clear()
	var vis: Array = visible_entries()
	var y: float = HEIGHT - ((INPUT_H + INPUT_GAP) if typing else 0.0)
	for i in range(vis.size() - 1, -1, -1):
		var e: Dictionary = vis[i]
		var bh: float = block_h(e)
		y -= bh
		var b := Block.new()
		b.e = e
		b.win = self
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = Vector2(0.0, y)
		b.size = Vector2(W, bh)
		add_child(b)
		_blocks.append(b)
		y -= GAP
	_update_fade()
	set_process(not typing and not _blocks.is_empty())


func _process(_delta: float) -> void:
	if _update_fade():
		_relayout()


## Okurken süresi dolan kutuyu söndürür; tamamen sönen varsa true (yeniden yerleşim).
func _update_fade() -> bool:
	var gone: bool = false
	for b in _blocks:
		var a: float = 1.0
		if not typing:
			var age: float = _age((b as Block).e)
			a = clampf(1.0 - (age - LIFETIME) / FADE, 0.0, 1.0)
			gone = gone or a <= 0.0
		(b as Block).modulate.a = a
	return gone


# --- çizim -------------------------------------------------------------------------------------------------------------------------

func rr(ci: CanvasItem, r: Rect2, c: Color, k: int) -> void:
	var prof: Array = PROF[k]
	var n: int = prof.size()
	for i in n:
		var ins: float = float(prof[i]) * P
		ci.draw_rect(Rect2(r.position.x + ins, r.position.y + i * P, r.size.x - 2.0 * ins, P), c)
		ci.draw_rect(Rect2(r.position.x + ins, r.end.y - (i + 1) * P, r.size.x - 2.0 * ins, P), c)
	ci.draw_rect(Rect2(r.position.x, r.position.y + n * P, r.size.x, r.size.y - 2.0 * n * P), c)


func pix(ci: CanvasItem, rows: Array, pos: Vector2, pal: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if pal.has(row[x]):
				ci.draw_rect(Rect2(pos + Vector2(x, y) * P, Vector2(P, P)), pal[row[x]])


## pos = büyük harfin sol üstü; emoji jetonları resim olarak.
func txt(ci: CanvasItem, pos: Vector2, s: String, col: Color) -> void:
	ChatEmoji.draw_line(ci, F, FS, Vector2(roundf(pos.x), roundf(pos.y) + CAP), s, col, P, CAP)


func _draw_block(ci: CanvasItem, e: Dictionary) -> void:
	var fr := Rect2(0.0, 0.0, FACE, FACE)
	ci.draw_rect(fr, HudTheme.DOCK_INSET)
	match str(e["kind"]):
		"msg":
			var cid: int = int(e["char_id"])
			if cid > 0:
				var bg: Texture2D = PortraitFace.background(cid, PortraitFace.PARTY_N)
				if bg:
					ci.draw_texture_rect(bg, fr, false)
				var face: Texture2D = PortraitFace.face(cid, PortraitFace.PARTY_N)
				if face:
					ci.draw_texture_rect(face, fr, false)
			HudTrayFrame.draw(ci, fr, 1.0)
		"gift":
			ci.draw_texture_rect(GOLD_TEX, Rect2(fr.get_center() - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), false)
			HudTrayFrame.draw(ci, fr, 1.0, HudTheme.SPOT)
		_:
			pix(ci, ALERT, fr.get_center() - Vector2(P, 2.5 * P).floor(), {"o": HudTheme.BAD})
			HudTrayFrame.draw(ci, fr, 1.0)
	var bx := Rect2(BOX_X, 0.0, box_w(e), (ci as Control).size.y)
	rr(ci, bx, HudTheme.OUTLINE, 2)
	var inner: Rect2 = bx.grow(-P)
	rr(ci, inner, HudTheme.STRIPE, 1)
	ci.draw_rect(Rect2(inner.position.x + P, inner.position.y, inner.size.x - 2.0 * P, P), HudTheme.RIM_LO)
	ci.draw_rect(Rect2(inner.position.x + P, inner.end.y - P, inner.size.x - 2.0 * P, P), HudTheme.DOCK_INSET)
	pix(ci, TAIL, Vector2(BOX_X - 3.0 * P, 3.0 * P), {"o": HudTheme.OUTLINE, "S": HudTheme.STRIPE})
	var tx: float = BOX_X + TEXT_PAD
	if e["kind"] == "gift":
		var from_s: String = str(e["from"])
		var sep: String = " » "
		txt(ci, Vector2(tx, NAME_Y), from_s, e["from_col"])
		txt(ci, Vector2(tx + text_w(from_s), NAME_Y), sep, HudTheme.DIM)
		txt(ci, Vector2(tx + text_w(from_s + sep), NAME_Y), str(e["to"]), e["to_col"])
	else:
		txt(ci, Vector2(tx, NAME_Y), str(e["name"]), e["color"])
	var line_col: Color = HudTheme.PRICE if e["kind"] == "gift" else HudTheme.TEXT
	var lines: PackedStringArray = e["lines"]
	for j in lines.size():
		txt(ci, Vector2(tx, NAME_Y + (j + 1) * LP), lines[j], line_col)
