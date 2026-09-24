extends Control

## Tek oyunculu karakter seçim ekranı. Kullanıcı isteği (2026-09-24): menülerin kartları/arka planları bej/cozy piksel
## kitle (MenuKit) SIFIRDAN yeniden tasarlandı; ekran tamamen KODLA kurulur (.tscn sadece kök).
## Yerleşim (1920x1080, simetrik üç sütun - çok oyunculu lobi ile AYNI ızgara):
##   sol  : Ruhani Yetenek seçici (spiritual_picker.gd)
##   orta : kurdele başlık + 6x2 karakter kartı (menu_character_roster.gd) + yetenek bilgi paneli (menu_character_details.gd)
##   sağ  : seçili karakterin animasyonlu vitrini (menu_character_showcase.gd) + BAŞLA
## Kartlar/bilgi paneli/vitrin lobby_menu.gd ile ORTAK bileşenler - eskiden iki ekranda "birebir aynı" tutulan kopyalar vardı.

const SpiritualPickerScript: GDScript = preload("res://scripts/spiritual_picker.gd")
const RosterScript: GDScript = preload("res://scripts/menu_character_roster.gd")
const DetailsScript: GDScript = preload("res://scripts/menu_character_details.gd")
const ShowcaseScript: GDScript = preload("res://scripts/menu_character_showcase.gd")

## Ortak ızgara ölçüleri (lobby_menu.gd de aynılarını kullanır): yan sütunlar 376 px, orta sütun 1104 px (6 kart = 1100).
const SCREEN := Vector2(1920, 1080)
const EDGE := 16.0
const GAP := 16.0
const SIDE := 376.0
const TOP := 108.0
const BOTTOM := 16.0

var selected_char: int = -1
var roster: GridContainer
var details: PanelContainer
var showcase: PanelContainer
var start_button: Button
var back_button: Button


func _ready() -> void:
	theme = MenuKit.theme()
	MenuKit.add_background(self)

	## NOT: her node ÖNCE ağaca eklenir (menü teması ancak o zaman geçerli - ağaç dışında projenin genel theme.tres'i,
	## 88 px yazıyla), SONRA MenuKit.place ile OFFSET olarak yerleştirilir (`size =` ataması geçici minimum boya kırpılıp
	## kalıcı büyüyordu - bkz. MenuKit.place notu).
	back_button = MenuKit.make_button("< Geri Dön", "tan", MenuKit.FS_BODY, 56)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	_place(back_button, Vector2(EDGE, 24), Vector2(200, 56))

	var banner := MenuKit.make_banner("Karakterini Seç")
	add_child(banner)
	_center_top(banner, 18.0)

	## Sol: Ruhani Yetenek (kullanıcı isteği: oyun başında karakter seçim ekranında herkes 1 tane seçer). Seçim doğrudan
	## GameManager.selected_spiritual'a yazılır.
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	add_child(spirit_picker)
	spirit_picker.setup(3)
	_place(spirit_picker, Vector2(EDGE, TOP), Vector2(SIDE, SCREEN.y - TOP - BOTTOM))

	var center_x: float = EDGE + SIDE + GAP
	var center_w: float = SCREEN.x - 2.0 * center_x
	roster = RosterScript.new()
	add_child(roster)
	roster.build()
	var grid_size: Vector2 = RosterScript.grid_size(Characters.DEFS.size())
	_place(roster, Vector2(center_x + floorf((center_w - grid_size.x) * 0.5), TOP), grid_size)
	roster.character_picked.connect(_on_character_pressed)

	details = DetailsScript.new()
	add_child(details)
	var details_y: float = TOP + grid_size.y + GAP
	_place(details, Vector2(center_x, details_y), Vector2(center_w, SCREEN.y - BOTTOM - details_y))

	showcase = ShowcaseScript.new()
	add_child(showcase)
	showcase.build(true)
	var content: VBoxContainer = showcase.get_content()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	start_button = MenuKit.make_button("BAŞLA", "sage", MenuKit.FS_HUGE, 120)
	start_button.pressed.connect(_on_start_pressed)
	content.add_child(start_button)
	_place(showcase, Vector2(SCREEN.x - EDGE - SIDE, TOP), Vector2(SIDE, SCREEN.y - TOP - BOTTOM))

	start_button.disabled = true
	_on_character_pressed(1)
	UISound.connect_all_buttons(self)
	roster.focus_card(1)


func _place(c: Control, pos: Vector2, sz: Vector2) -> void:
	MenuKit.place(c, pos, sz)


func _center_top(c: Control, y: float) -> void:
	var s: Vector2 = c.get_combined_minimum_size()
	MenuKit.place(c, Vector2(roundf((SCREEN.x - s.x) / 6.0) * 3.0, y), s)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_character_pressed(char_id: int) -> void:
	selected_char = char_id
	roster.select(char_id)
	details.show_character(char_id)
	showcase.show_character(char_id)
	start_button.disabled = false


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_start_pressed() -> void:
	if selected_char == -1:
		return
	var def: Dictionary = Characters.get_def(selected_char)
	GameManager.selected_char_id = selected_char
	GameManager.selected_character = def["skill"]
	## Kullanıcı isteği: "oyuna başla dediğimizde yükleme ekranı olsun" -
	## artık main.tscn'e doğrudan değil, önce loading_screen.gd'nin kendi
	## yüklediği (ve barını doldurduğu) yükleme ekranına geçiliyor.
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
