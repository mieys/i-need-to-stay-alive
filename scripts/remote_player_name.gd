extends Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## #43 DÜZELTME (kullanıcı isteği: "İsim etiketi kalkan/can barının üstüne
	## taşınsın (~20px yukarı)"): eskiden y=-82 idi - etiketin yüksekliği 20
	## olduğu için alt kenarı tam y=-62'de bitiyordu, yani OverheadBar'ın
	## varsayılan y_offset'iyle (-62.0, bkz. overhead_bar.gd) BİREBİR aynı
	## hizada, aralarında hiç boşluk yoktu (isim can/kalkan çubuğuna
	## yapışık görünüyordu). Artık 20px daha yukarı (y=-102.0) çekilip
	## çubukla arasında net bir boşluk bırakılıyor. Sonradan kullanıcı isteği
	## üzerine 10px daha yukarı (y=-112.0) çekildi.
	## Kullanıcı isteği: "multiplayerda oyun içinde karakterlerin üstündeki
	## isim fontlarını 2 kat büyüt" - font 14 -> 28, kutu da (kırpılmasın diye)
	## orantılı büyütüldü; alt kenarı eskisiyle AYNI yerde kalsın diye (can/
	## kalkan çubuğuna değmesin) konum yukarı kaydırıldı.
	position = Vector2(-110.0, -128.0)
	size = Vector2(220.0, 36.0)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))

