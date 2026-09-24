extends Control

## Karakter seçim kartı (tek oyunculu character_select.gd + çok oyunculu lobby_menu.gd ORTAK - bkz. menu_character_roster.gd).
## Tek parça sabit boyutlu piksel doku (tools/gen_menu_kit.py card(): ahşap çerçeve + portre penceresi + çimen tümseği +
## parşömen isim plakası), üç durum: normal / hover / selected (altın çerçeve + dış parıltı). Karakter, oyundaki
## SpriteFrames'inden 3x çizilir (menu_character_preview.gd); üstüne gelince / seçiliyken idle animasyonu oynar.
## Kartın HER yeri tıklanır (kullanıcı bildirimi 2026-09-24: "karakterin kendisine tıklamam gerekiyor karta tıklama
## seçmemi sağlamıyor"); klavye/gamepad ile odaklanıp ui_accept ile de seçilir.

signal pressed(char_id: int)

const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")

var char_id: int = -1
var selected: bool = false: set = set_selected

var _hover: bool = false
var _preview: Control = null


func setup(id: int, def: Dictionary) -> void:
	char_id = id
	custom_minimum_size = MenuKit.CARD_SIZE
	size = MenuKit.CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = ""

	_preview = PreviewScript.new()
	add_child(_preview)
	MenuKit.place(_preview, Vector2.ZERO, MenuKit.CARD_SIZE)
	_preview.setup(def, 3, MenuKit.CARD_GROUND_Y)

	## ÖNCE ağaca ekle, SONRA boyutlandır: ağaç dışındayken projenin genel teması (theme.tres, varsayılan yazı 88 px)
	## geçerli olduğu için minimum boyut ona göre hesaplanıp size yukarı kırpılıyordu (isimler plakadan taşıyordu).
	var plate: Rect2 = MenuKit.CARD_PLATE_RECT
	var name_label := MenuKit.make_label(str(def.get("name", "")), MenuKit.FS_BODY, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.name = "NameLabel"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	add_child(name_label)
	MenuKit.fit_label_font(name_label, name_label.text, MenuKit.FS_BODY, plate.size.x - 6.0)
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
	if _preview:
		_preview.playing = selected or _hover
	queue_redraw()


func _draw() -> void:
	var state: String = "selected" if selected else ("hover" if _hover else "normal")
	draw_texture(MenuKit.tex("card_%s.png" % state), Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_activate()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_activate()
		accept_event()


func _activate() -> void:
	UISound.play_click()
	pressed.emit(char_id)
