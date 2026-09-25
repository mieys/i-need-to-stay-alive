extends Label

## Kullanıcı isteği: "birisi düştüğünde diğerleri onu canlandırmak için bir
## süre var ama o süre görünmüyor hem düşen oyuncuda hem hayatta olan
## oyuncularda solda karakterin yanında yazsa iyi olabilir" - kalıcı ölüme
## kadar kalan saniyeyi (bkz. player.gd get_downed_remaining_seconds)
## karakterin SOLUNDA gösterir. Yerde yatma süresi artık sınırsız olduğu için
## (bkz. player.gd is_downed üstündeki DÜZELTME notu) bu sayaç SADECE
## diriltebilecek hayatta kimse kalmadığında (DOWNED_NO_RESCUER_GRACE) görünür.
##
## Hem player.gd (kendi düşme durumu, _process_downed içinde her karede) hem
## remote_player.gd (ağdan gelen extra.downed_remaining ile, bkz. main.gd
## state_snapshot) AYNI bu script/konum/formatı kullanır - iki ayrı yerde
## aynı formül/konum TEKRARLANMASIN diye (bkz. proje CLAUDE.md üstündeki
## tekrar eden hata sınıfı notu).
##
## overhead_bar.gd'nin karakter can çubuğuyla (CHARACTER_Y_OFFSET, WIDTH=44.0) AYNI
## yükseklikte ama karakterin SOLUNDA duruyor (remote_player_name.gd'nin
## isim etiketi gibi sabit bir offset, bkz. orada). 2026-09-25: çubuk -62 -> -76
## yükseldi (şapkalar örtülmesin), bu etiket de 14 px yukarı (-76 -> -90).

## Kullanıcı isteği (2026-09-25): "diriltme zaman sayacı karakterin içinde değil can ve kalkan barının olduğu yerde
## çıksın ve can ve kalkan barı ölünce gizlensin" - artık karakterin solunda değil, gizlenen can çubuğunun TAM yerinde
## (overhead_bar.gd CHARACTER_Y_OFFSET, çubuğun ortası) ortalanmış duruyor.
const OverheadBarScript := preload("res://scripts/overhead_bar.gd")
const LABEL_SIZE := Vector2(120.0, 34.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = LABEL_SIZE
	position = Vector2(-LABEL_SIZE.x * 0.5, OverheadBarScript.CHARACTER_Y_OFFSET + OverheadBarScript.HEIGHT * 0.5 - LABEL_SIZE.y * 0.5)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	visible = false


func set_remaining_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		visible = false
		return
	visible = true
	text = "%ds" % int(ceil(seconds))
