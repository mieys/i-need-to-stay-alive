extends Control

## TELEFON HIZLI SOHBET penceresi (kullanıcı onayı 2026-10-18, madde 253/273; prototip tools/proto_20261018/mobil_proto.gd
## _ml_quickchat): sohbet düğmesinin altında ahşap levha - son iki mesaj (kuyu), oyuna özgü 6 hazır mesaj (ahşap düğme,
## dokununca gönderir) ve "Mesaj yaz" alanı (dokununca HUD'un sohbet kutusu + ekran klavyesi açılır; yazma kutusunun
## kilitlenmeme kuralları orada, bkz. hud.gd _input). Sadece telefonda; hud.gd ChatLayer'a ekler ve konumlar.

signal quick_message(text: String)
signal write_requested
signal close_requested

const HudTheme := preload("res://scripts/hud_theme.gd")
## Kullanıcı (2026-10-18, "yapay zekâ gibi" turu): MOBA kopyası "Saldırın / Geri çekilin" yerine bu oyuna özgü mesajlar.
const QUICK: Array[String] = ["Buraya gelin!", "Can lazım!", "Sandık burada!", "Elit burada!", "Bekleyin!", "Sağ olun!"]
const W := 700.0
const H := 452.0
const FS := 32 ## m5x7 4x (keskin)
const RECENT := 2

var _recent_rows: Array = [] ## [[ad Label, metin Label], ...]


func _ready() -> void:
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.panel_style("hud_plaque"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(bg, Rect2(0, 0, W, H))
	_put(_label("Sohbet", HudTheme.ACCENT), Rect2(26, 12, 300, 44))
	var close := _button("x", true)
	close.tooltip_text = "Kapat"
	close.pressed.connect(func() -> void: close_requested.emit())
	_put(close, Rect2(W - 66.0, 14, 48, 48))
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", UIKit.panel_style("hud_inset_tight"))
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(well, Rect2(18, 66, W - 36.0, 84))
	for i in RECENT:
		var n := _label("", HudTheme.PRICE)
		var t := _label("", HudTheme.TEXT)
		t.clip_text = true
		_put(n, Rect2(34, 72 + i * 36, 240, 36))
		_put(t, Rect2(34, 72 + i * 36, W - 68.0, 36))
		_recent_rows.append([n, t])
	var cw: float = floorf((W - 36.0 - 12.0) / 2.0)
	for i in QUICK.size():
		var b := _button(QUICK[i], false)
		var msg: String = QUICK[i]
		b.pressed.connect(func() -> void: quick_message.emit(msg))
		@warning_ignore("integer_division")
		_put(b, Rect2(18.0 + (i % 2) * (cw + 12.0), 162.0 + (i / 2) * 66.0, cw, 58))
	## Yazma alanı: kuyu görünüşünde düğme - asıl yazma kutusu HUD'unki (ekran klavyesi, kilitlenmeme kuralları orada).
	var field := Button.new()
	field.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		field.add_theme_stylebox_override(st, UIKit.panel_style("hud_inset_tight"))
	field.pressed.connect(func() -> void: write_requested.emit())
	_put(field, Rect2(18, H - 76.0, W - 36.0, 58))
	var hint := _label("Mesaj yaz", HudTheme.DIM)
	_put(hint, Rect2(36, H - 76.0, 300, 58))


## Son mesajlar ([[ad, metin], ...], eskiden yeniye) - kuyuda en yeni RECENT tanesi.
func set_recent(entries: Array) -> void:
	for i in _recent_rows.size():
		var row: Array = _recent_rows[i]
		var n: Label = row[0]
		var t: Label = row[1]
		var idx: int = entries.size() - _recent_rows.size() + i
		if idx < 0:
			n.text = ""
			t.text = ""
			continue
		var e: Array = entries[idx]
		n.text = str(e[0]) + ":"
		t.text = str(e[1])
		var f: Font = n.get_theme_font(&"font")
		var nw: float = f.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x if f else 120.0
		t.position.x = n.position.x + nw + 10.0
		t.size.x = W - 34.0 - t.position.x


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(l, FS, color, 0)
	return l


func _button(text: String, mini: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIKit.style_button(b, "hud", mini, FS)
	return b


func _put(c: Control, r: Rect2) -> void:
	add_child(c)
	c.position = r.position
	c.size = r.size
