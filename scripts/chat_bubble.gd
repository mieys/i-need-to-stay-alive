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
##  - ÇERÇEVE: koyu düz kutu yerine oyundaki ahşap butonların stili (ShopPanel._make_wood_button_style - Button.png).
##  - YAZI: font AYNI (projenin varsayılan fontu, m5x7), sadece boyut 20 -> 32. NOT: Player ve RemotePlayer kökleri 0.5 ölçekli
##    olduğu için buradaki tüm sayılar o ölçeğin YEREL birimleri (32 => dünyada 16 px; isim etiketi 28 => 14 px).
##  - ÖLÇÜM: eskiden metin uzunluğundan kaba tahmin + Label autowrap kullanılıyordu; ikisi çelişince Label'ın minimum boyutu
##    kutuyu istenenden çok daha uzun yapıyordu (kısa mesajda bile boyu birkaç katı). Artık satır kaydırma ve boyut
##    fontun gerçek ölçülerinden (wrap_text) senkron hesaplanıyor, Label'da autowrap YOK.

const DISPLAY_DURATION := 4.0
const FONT_SIZE := 32
## Bir metin satırının (kutu kenar boşlukları HARİÇ) en fazla genişliği (yerel birim).
const MAX_TEXT_WIDTH := 380.0
## Bu kadar satırı aşan çok uzun mesajlar kısaltılır (balon ekranı kaplamasın).
const MAX_LINES := 6
## Ahşap kutunun iç boşlukları: yatay boşluk kenar dokusunun (20) biraz üstünde, yazı kenara yapışmasın.
const PAD_X := 26.0
const PAD_TOP := 8.0
const PAD_BOTTOM := 10.0
## İsim etiketinin (bkz. remote_player_name.gd, y=-128, yükseklik 36) hemen
## üstünde küçük bir boşlukla dursun diye balonun ALT kenarı bu y'de sabit.
const BUBBLE_BOTTOM_Y := -136.0

var _label: Label = null
var _hide_timer: Timer = null


func _ready() -> void:
	z_index = 65 ## isim etiketinin/can-kalkan çubuğunun üstünde
	visible = false
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.03, 1.0))
	_label.add_theme_constant_override("outline_size", 4)
	var sb: StyleBoxTexture = ShopPanel._make_wood_button_style()
	sb.content_margin_left = PAD_X
	sb.content_margin_right = PAD_X
	sb.content_margin_top = PAD_TOP
	sb.content_margin_bottom = PAD_BOTTOM
	_label.add_theme_stylebox_override("normal", sb)
	add_child(_label)
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = DISPLAY_DURATION
	_hide_timer.timeout.connect(func(): visible = false)
	add_child(_hide_timer)


func show_message(text: String) -> void:
	if not _label:
		return
	var font: Font = _label.get_theme_font("font")
	_label.text = wrap_text(text, font, FONT_SIZE, MAX_TEXT_WIDTH)
	## Label autowrap'sız: minimum boyutu = metnin gerçek ölçüsü + kutu boşlukları (senkron, bir kare beklemek gerekmiyor).
	_label.size = Vector2.ZERO
	var box: Vector2 = _label.get_combined_minimum_size()
	_label.size = box
	_label.position = Vector2(-box.x * 0.5, BUBBLE_BOTTOM_Y - box.y)
	visible = true
	_hide_timer.start()


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
