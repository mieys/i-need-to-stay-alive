extends RefCounted

## SOHBET EMOJİLERİ (madde 499, 2026-11-08; kullanıcı: "chate emoji butonu ve biraz emoji ekle"). Mesaj metninde düz yazı jeton ":gul:" olarak
## gider (ağ değişmez, RPC yok), her istemci ÇİZERKEN resme çevirir: masaüstü sohbet penceresi (chat_window.gd, 1 sanat px = 3 ekran px -> 27 px),
## karakter balonu (chat_bubble.gd, 1 sanat px = 1 dünya px) ve telefonun harita üstü satırı (RichTextLabel [img]). Yazarken yaygın kısaltmalar
## da emoji olur (":)" ":D" ":(" ";)" ":O" "<3"; yalnız boşlukla ayrıldığında). Sanat: tools/gen_chat_emoji.py -> assets/ui/emoji/<anahtar>.png
## (9x9). Kullanım: const ChatEmoji := preload("res://scripts/chat_emoji.gd") (class_name YOK, hud_theme.gd ile aynı sebep).

const SIZE := 9 ## sanat pikseli
const DIR := "res://assets/ui/emoji/"
## Sıra = seçici penceresi sırası (gen_chat_emoji.py EMOJI ile aynı).
const LIST: Array[String] = ["gul", "kahkaha", "uzgun", "kizgin", "saskin", "kirp", "kalp", "begen", "kafa", "ates", "kilic", "yardim"]
const SHORTCUTS := {":)": "gul", ":-)": "gul", ":D": "kahkaha", ":(": "uzgun", ":-(": "uzgun", ";)": "kirp", ":O": "saskin", ":o": "saskin",
	"<3": "kalp"}

static var _tex: Dictionary = {}


static func token(key: String) -> String:
	return ":%s:" % key


static func tex(key: String) -> Texture2D:
	if not _tex.has(key):
		var path: String = DIR + key + ".png"
		_tex[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[key]


static func is_key(key: String) -> bool:
	return LIST.has(key)


## Boşlukla ayrılmış kısaltmaları jetona çevirir (":)" -> ":gul:"). Sözcük içi (ör. "saat:D") dokunulmaz.
static func normalize(text: String) -> String:
	var words: PackedStringArray = text.split(" ")
	for i in words.size():
		if SHORTCUTS.has(words[i]):
			words[i] = token(SHORTCUTS[words[i]])
	return " ".join(words)


## Satırı parçalara böler: [["t", "yazı"], ["e", "anahtar"], ...]. Bilinmeyen ":x:" düz yazı kalır.
static func segments(line: String) -> Array:
	var out: Array = []
	var buf: String = ""
	var i: int = 0
	var n: int = line.length()
	while i < n:
		if line[i] == ":":
			var j: int = line.find(":", i + 1)
			if j > i + 1 and is_key(line.substr(i + 1, j - i - 1)):
				if buf != "":
					out.append(["t", buf])
					buf = ""
				out.append(["e", line.substr(i + 1, j - i - 1)])
				i = j + 1
				continue
		buf += line[i]
		i += 1
	if buf != "":
		out.append(["t", buf])
	return out


## Emojinin yatay yeri (resim + 1 sanat px boşluk).
static func emoji_adv(px: float) -> float:
	return (SIZE + 1) * px


static func measure(s: String, font: Font, size: int, px: float) -> float:
	var w: float = 0.0
	for seg: Array in segments(s):
		if seg[0] == "e":
			w += emoji_adv(px)
		else:
			w += font.get_string_size(seg[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return w


## chat_bubble.wrap_text'in emoji bilen hâli: sözcük korur, emoji bölünmez, sığmayan uzun düz sözcük karakter karakter bölünür, max_lines'ı aşan
## "..." ile kısalır. px = emojinin sanat pikseli (yer hesabı).
static func wrap(text: String, font: Font, size: int, max_width: float, px: float, max_lines: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: String in normalize(text).split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			var candidate: String = word if line == "" else line + " " + word
			if measure(candidate, font, size, px) <= max_width:
				line = candidate
				continue
			if line != "":
				lines.append(line)
			if measure(word, font, size, px) <= max_width or not segments(word).all(func(sg: Array) -> bool: return sg[0] == "t"):
				line = word
				continue
			var chunk: String = ""
			for ch: String in word:
				if chunk != "" and measure(chunk + ch, font, size, px) > max_width:
					lines.append(chunk)
					chunk = ""
				chunk += ch
			line = chunk
		lines.append(line)
	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
		lines[max_lines - 1] = lines[max_lines - 1].rstrip(" ") + "..."
	return lines


## Satırı çizer; base = ilk karakterin taban çizgisi, cap = büyük harf yüksekliği (emoji onun ortasına oturur). shadow.a > 0 ise yazıya 1 yazı
## pikseli gölge (shadow_off aşağı). Emoji gölgesiz (kendi dış hattı var).
static func draw_line(ci: CanvasItem, font: Font, size: int, base: Vector2, s: String, col: Color, px: float, cap: float,
		shadow: Color = Color(0, 0, 0, 0), shadow_off: float = 0.0) -> void:
	var x: float = base.x
	var ep: float = SIZE * px
	var ey: float = roundf((base.y - cap * 0.5 - ep * 0.5) / px) * px
	for seg: Array in segments(s):
		if seg[0] == "e":
			var t: Texture2D = tex(seg[1])
			if t:
				ci.draw_texture_rect(t, Rect2(Vector2(roundf(x / px) * px, ey), Vector2(ep, ep)), false)
			x += emoji_adv(px)
		else:
			var str_s: String = seg[1]
			if shadow.a > 0.0:
				ci.draw_string(font, Vector2(x, base.y + shadow_off), str_s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
			ci.draw_string(font, Vector2(x, base.y), str_s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			x += font.get_string_size(str_s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Telefonun RichTextLabel satırı için: jetonları [img] yapar (metin önceden "[" kaçışlı olmalı).
static func to_bbcode(text: String, img_px: int) -> String:
	var out: String = ""
	for seg: Array in segments(normalize(text)):
		if seg[0] == "e":
			out += "[img=%dx%d]%s%s.png[/img]" % [img_px, img_px, DIR, seg[1]]
		else:
			out += seg[1]
	return out
