extends Control

## Karakter seçim kartı (tek oyunculu character_select.gd + çok oyunculu lobby_menu.gd ORTAK - bkz. menu_character_roster.gd).
## Tek parça sabit boyutlu piksel doku (tools/gen_menu_kit.py card(): ahşap çerçeve + portre penceresi + çimen tümseği +
## parşömen isim plakası), üç durum: normal / hover / selected (altın çerçeve + dış parıltı). Karakter, oyundaki
## SpriteFrames'inden 3x çizilir (menu_character_preview.gd) - HER ZAMAN durağan (idle'ın ilk karesi). Kullanıcı isteği
## (2026-09-24): "karakter seçim ekranlarında karakterlerin animasyonsuz görünmesini istiyorum sadece tıkladığım kişinin
## sağda karakter göstergesinden animasyonlu idle oynasın" - animasyon yalnızca vitrinde (menu_character_showcase.gd).
## Kartın HER yeri tıklanır (kullanıcı bildirimi 2026-09-24: "karakterin kendisine tıklamam gerekiyor karta tıklama
## seçmemi sağlamıyor"); klavye/gamepad ile odaklanıp ui_accept ile de seçilir.

signal pressed(char_id: int)

const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")

var char_id: int = -1
var selected: bool = false: set = set_selected

var _hover: bool = false
var _preview: Control = null


## k: ölçek (1 = masaüstü 180x216, 3x sanat px). Telefon karakter seçimi 4/3 verir (240x288 = 4x sanat px - doku ve karakter
## pikselleri keskin; isim 40 px). Bkz. character_select.gd _build_mobile.
var _k: float = 1.0


func setup(id: int, def: Dictionary, k: float = 1.0) -> void:
	char_id = id
	_k = k
	var card_size: Vector2 = MenuKit.CARD_SIZE * k
	custom_minimum_size = card_size
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = ""

	_preview = PreviewScript.new()
	add_child(_preview)
	MenuKit.place(_preview, Vector2.ZERO, card_size)
	_preview.setup(def, roundi(3.0 * k), MenuKit.CARD_GROUND_Y * k)

	## ÖNCE ağaca ekle, SONRA boyutlandır: ağaç dışındayken projenin genel teması (theme.tres, varsayılan yazı 88 px)
	## geçerli olduğu için minimum boyut ona göre hesaplanıp size yukarı kırpılıyordu (isimler plakadan taşıyordu).
	var plate := Rect2(MenuKit.CARD_PLATE_RECT.position * k, MenuKit.CARD_PLATE_RECT.size * k)
	var name_fs: int = 40 if k > 1.0 else MenuKit.FS_BODY
	var name_label := MenuKit.make_label(str(def.get("name", "")), name_fs, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.name = "NameLabel"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	add_child(name_label)
	MenuKit.fit_label_font(name_label, name_label.text, name_fs, plate.size.x - 6.0)
	MenuKit.place(name_label, plate.position, plate.size)

	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(_set_hover.bind(true))
	focus_exited.connect(_set_hover.bind(false))


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func _set_hover(value: bool) -> void:
	_hover = value
	_refresh()


func _refresh() -> void:
	## Kart portresi hiç oynamaz (bkz. dosya başı) - hover/seçim sadece çerçeve dokusunu değiştirir.
	queue_redraw()


func _draw() -> void:
	var state: String = "selected" if selected else ("hover" if _hover else "normal")
	draw_texture_rect(MenuKit.tex("card_%s.png" % state), Rect2(Vector2.ZERO, MenuKit.CARD_SIZE * _k), false)


## Parmak/fare KALKINCA (kartın üstünde) seçilir, basınca değil - kullanıcı bildirimi (2026-10-04): telefonda kart
## listesini kaydırmaya çalışınca dokunduğu kart seçiliyordu. Sürükleme başlarsa touch_scroll.gd basmayı iptal eder
## (bırakma kartın dışında gelir -> seçilmez).
var _press_armed: bool = false


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press_armed = true
		elif _press_armed:
			_press_armed = false
			if Rect2(Vector2.ZERO, size).has_point(mb.position):
				_activate()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_activate()
		accept_event()


func _activate() -> void:
	UISound.play_click()
	pressed.emit(char_id)
