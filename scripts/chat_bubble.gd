extends Node2D

## Karakterin üstünde beliren mini konuşma balonu (kullanıcı isteği: "chat
## ekle ... karakterler konuşunca üstlerinde mini chat balonu çıkacak").
## Hem player.gd (yerel oyuncu) hem remote_player.gd (uzak oyuncular)
## tarafından _ready()'de dinamik olarak oluşturulup add_child edilir -
## .tscn'e elle eklenmedi, bu proje genelindeki "Node2D.new()+set_script()"
## deseniyle (bkz. fx_shield_hit.gd) aynı - iki tarafın da AYNI script'i
## kullanması, görünümün ikisinde de her zaman birebir aynı kalmasını
## garantiler (bkz. proje kökündeki CLAUDE.md).
##
## KULLANICI İSTEĞİ (2026-09-21): "chat baloncuğunun çerçevesi butonlara benzesin ve yazılar çok ufak görünüyor büyümesi lazım,
## fontlar aynı kalsın."
##  - YAZI: m5x7, boyut 20 -> 32. NOT: Player ve RemotePlayer kökleri 0.5 ölçekli olduğu için buradaki tüm sayılar o ölçeğin
##    YEREL birimleri (32 => dünyada 16 px; isim etiketi 28 => 14 px).
##  - ÖLÇÜM: satır kaydırma ve kutu boyu fontun gerçek ölçülerinden (wrap_text) senkron hesaplanır (eski Label autowrap'ı kısa
##    mesajda bile kutuyu birkaç kat uzatıyordu). Çerçeve 2026-11-08'de değişti (aşağı).

## 2026-11-08 (madde 499; kullanıcı madde 495 prototiplerinden "C" + "ama okunur olmasını sağla" + "karakterlerin üstünde çıkan chat baloncuğunu
## da buna uygun olarak tasarla"): Label + eski açık ahşap düğme dokusu yerine sol alttaki sohbet penceresinin (chat_window.gd) MESAJ KUTUSU:
## koyu kutu (STRIPE) + dış hat (köşe 2 sanat px basamak) + üstte koyu ahşap ışığı, altta kuyu çizgisi, solda konuşana inen kuyruk, krem yazı.
## Emoji jetonları resim (chat_emoji.gd). _draw ile, DÜNYADA: 1 sanat pikseli = BT = 2 yerel birim = 1 dünya pikseli (harita pikseli; 1440p'de tam
## 3 ekran pikseli), yazı m5x7 32 yerel = 1 yazı pikseli 1 dünya pikseli. Kuyruğun ucu eski balonun alt kenarında (BUBBLE_BOTTOM_Y).
## Oyuncu, uzak oyuncu ve NPC'ler (npc_actor.gd) aynı betik.

const HudTheme := preload("res://scripts/hud_theme.gd")
const ChatEmoji := preload("res://scripts/chat_emoji.gd")
const F: Font = preload("res://assets/fonts/m5x7.ttf")

const DISPLAY_DURATION := 4.0
const FONT_SIZE := 32
## Bir metin satırının (kutu kenar boşlukları HARİÇ) en fazla genişliği (yerel birim).
const MAX_TEXT_WIDTH := 380.0
## Bu kadar satırı aşan çok uzun mesajlar kısaltılır (balon ekranı kaplamasın).
const MAX_LINES := 6
const BT := 2.0 ## 1 sanat pikseli (yerel birim)
const LINE_H := 24.0 ## satır aralığı (12 yazı pikseli)
const CAP := 14.0 ## büyük harf yüksekliği (7 yazı pikseli)
const PAD_X := 12.0
const PAD_TOP := 10.0
const PAD_BOTTOM := 12.0
const TAIL_H := 6.0
## Kuyruğun ucu: isim etiketinin (bkz. remote_player_name.gd, y=-120, yükseklik 36) hemen üstü.
const BUBBLE_BOTTOM_Y := -136.0
## Sol kuyruk (kutunun alt dış hattından aşağı, konuşana doğru sola eğik; pencerenin kuyruğuyla aynı dil): o dış hat, S kutu
const TAIL := [".SSS.", "oSSSo", "oSSo.", "oSo..", "oo..."] ## ilk satır kutunun alt kuyu çizgisini örter

var _lines: PackedStringArray = PackedStringArray()
var _box: Rect2 = Rect2()
var _hide_timer: Timer = null


func _ready() -> void:
	z_index = 65 ## isim etiketinin/can-kalkan çubuğunun üstünde
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = DISPLAY_DURATION
	_hide_timer.timeout.connect(func(): visible = false)
	add_child(_hide_timer)


func show_message(text: String) -> void:
	if _hide_timer == null:
		return
	_lines = ChatEmoji.wrap(text, F, FONT_SIZE, MAX_TEXT_WIDTH, BT, MAX_LINES)
	var wmax: float = 0.0
	for li: String in _lines:
		wmax = maxf(wmax, ChatEmoji.measure(li, F, FONT_SIZE, BT))
	var bw: float = ceilf((wmax + 2.0 * PAD_X) / (2.0 * BT)) * 2.0 * BT
	var bh: float = ceilf((CAP + (_lines.size() - 1) * LINE_H + PAD_TOP + PAD_BOTTOM) / BT) * BT
	_box = Rect2(-bw * 0.5, BUBBLE_BOTTOM_Y - TAIL_H - bh, bw, bh)
	visible = true
	queue_redraw()
	_hide_timer.start()


func _draw() -> void:
	if _lines.is_empty():
		return
	_rr(_box, HudTheme.OUTLINE, [2, 1])
	var i2: Rect2 = _box.grow(-BT)
	_rr(i2, HudTheme.STRIPE, [1])
	draw_rect(Rect2(i2.position.x + BT, i2.position.y, i2.size.x - 2.0 * BT, BT), HudTheme.RIM_LO)
	draw_rect(Rect2(i2.position.x + BT, i2.end.y - BT, i2.size.x - 2.0 * BT, BT), HudTheme.DOCK_INSET)
	var tp := Vector2(_box.position.x + 6.0 * BT, _box.end.y - 2.0 * BT)
	var pal := {"o": HudTheme.OUTLINE, "S": HudTheme.STRIPE}
	for y in TAIL.size():
		var row: String = TAIL[y]
		for x in row.length():
			if pal.has(row[x]):
				draw_rect(Rect2(tp + Vector2(x, y) * BT, Vector2(BT, BT)), pal[row[x]])
	for j in _lines.size():
		var lw: float = ChatEmoji.measure(_lines[j], F, FONT_SIZE, BT)
		var base := Vector2(roundf(-lw * 0.5 / BT) * BT, _box.position.y + PAD_TOP + j * LINE_H + CAP)
		ChatEmoji.draw_line(self, F, FONT_SIZE, base, _lines[j], HudTheme.TEXT, BT, CAP)



## Basamaklı köşeli dolu dikdörtgen (prof = her satırın içeri girişi, sanat pikseli).
func _rr(r: Rect2, c: Color, prof: Array) -> void:
	var n: int = prof.size()
	for i in n:
		var ins: float = float(prof[i]) * BT
		draw_rect(Rect2(r.position.x + ins, r.position.y + i * BT, r.size.x - 2.0 * ins, BT), c)
		draw_rect(Rect2(r.position.x + ins, r.end.y - (i + 1) * BT, r.size.x - 2.0 * ins, BT), c)
	draw_rect(Rect2(r.position.x, r.position.y + n * BT, r.size.x, r.size.y - 2.0 * n * BT), c)


## Metni max_width'i (piksel, font_size'daki gerçek genişlik) aşmayacak satırlara böler ("\n" ile birleştirilmiş döner).
## Sözcükleri koruyarak satır kaydırır; tek başına satıra sığmayan devasa bir sözcük karakter karakter bölünür; MAX_LINES'ı
## aşan metin "..." ile kısaltılır. static: font dışında hiçbir düğüme bağlı değil (test edilebilir).
static func wrap_text(text: String, font: Font, font_size: int, max_width: float) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			var candidate: String = word if line == "" else line + " " + word
			if _text_width(font, candidate, font_size) <= max_width:
				line = candidate
				continue
			if line != "":
				lines.append(line)
			var chunk: String = ""
			for ch: String in word:
				if chunk != "" and _text_width(font, chunk + ch, font_size) > max_width:
					lines.append(chunk)
					chunk = ""
				chunk += ch
			line = chunk
		lines.append(line)
	if lines.size() > MAX_LINES:
		lines = lines.slice(0, MAX_LINES)
		lines[MAX_LINES - 1] = lines[MAX_LINES - 1].rstrip(" ") + "..."
	return "\n".join(lines)


static func _text_width(font: Font, s: String, font_size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
