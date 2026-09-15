extends Node2D

## Karakterin üstünde beliren mini konuşma balonu (kullanıcı isteği: "chat
## ekle ... karakterler konuşunca üstlerinde mini chat balonu çıkacak").
## Hem player.gd (yerel oyuncu) hem remote_player.gd (uzak oyuncular)
## tarafından _ready()'de dinamik olarak oluşturulup add_child edilir -
## .tscn'e elle eklenmedi, bu proje genelindeki "Node2D.new()+set_script()"
## deseniyle (bkz. fx_shield_hit.gd) aynı - iki tarafın da AYNI script'i
## kullanması, görünümün ikisinde de her zaman birebir aynı kalmasını
## garantiler (bkz. proje kökündeki CLAUDE.md).

const DISPLAY_DURATION := 4.0
const MAX_WIDTH := 260.0
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
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.08, 0.88)
	sb.border_color = Color(0.83, 0.56, 0.30, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_label.add_theme_stylebox_override("normal", sb)
	add_child(_label)
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = DISPLAY_DURATION
	_hide_timer.timeout.connect(func(): visible = false)
	add_child(_hide_timer)


## Metin uzunluğundan kaba bir genişlik/satır sayısı tahmini - tam piksel
## ölçümü (Label'ın gerçek autowrap sonucunu beklemek) bir kare gecikme
## gerektirirdi, arka arkaya hızlı mesajlarda yarış durumuna yol açabilirdi;
## bu tahmin yeterince yakın ve anlık/senkron çalışıyor.
func show_message(text: String) -> void:
	if not _label:
		return
	_label.text = text
	var width: float = clamp(text.length() * 9.0 + 24.0, 60.0, MAX_WIDTH)
	var chars_per_line: float = max(1.0, (width - 20.0) / 9.0)
	var line_count: int = max(1, ceili(float(text.length()) / chars_per_line))
	var height: float = 24.0 + line_count * 22.0
	_label.size = Vector2(width, height)
	_label.position = Vector2(-width * 0.5, BUBBLE_BOTTOM_Y - height)
	visible = true
	_hide_timer.start()
