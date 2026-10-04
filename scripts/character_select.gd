extends Control

## Tek oyunculu karakter seçim ekranı. Kullanıcı isteği (2026-09-24): menülerin kartları/arka planları bej/cozy piksel
## kitle (MenuKit) SIFIRDAN yeniden tasarlandı; ekran tamamen KODLA kurulur (.tscn sadece kök).
## Yerleşim (1920x1080, simetrik üç sütun - çok oyunculu lobi ile AYNI ızgara):
##   sol  : Ruhani Yetenek seçici (spiritual_picker.gd)
##   orta : kurdele başlık + 6 sütunlu karakter kartları (menu_character_roster.gd; 13 karakterle 3 satır) + yetenek bilgi
##          paneli (menu_character_details.gd)
##   sağ  : seçili karakterin animasyonlu vitrini (menu_character_showcase.gd) + BAŞLA
## Kartlar/bilgi paneli/vitrin lobby_menu.gd ile ORTAK bileşenler - eskiden iki ekranda "birebir aynı" tutulan kopyalar vardı.

const SpiritualPickerScript: GDScript = preload("res://scripts/spiritual_picker.gd")
const RosterScript: GDScript = preload("res://scripts/menu_character_roster.gd")
const DetailsScript: GDScript = preload("res://scripts/menu_character_details.gd")
const ShowcaseScript: GDScript = preload("res://scripts/menu_character_showcase.gd")
const WeaponPickerScript: GDScript = preload("res://scripts/menu_weapon_picker.gd")
const WEAPON_PICKER_H := 300.0

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
var weapon_picker: PanelContainer


func _ready() -> void:
	theme = MenuKit.theme()
	MenuKit.add_background(self)
	if MobileUIScript.enabled:
		_build_mobile()
		return

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
	## Sol sütunun altı: başlangıç silahı (kullanıcı isteği 2026-10-03 - oyun başındaki silah kartı ekranı kaldırıldı,
	## bkz. menu_weapon_picker.gd). Ruhani yetenek seçici kalan yüksekliği kullanır (açıklaması gerekirse kayar).
	var col_h: float = SCREEN.y - TOP - BOTTOM
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	add_child(spirit_picker)
	spirit_picker.setup(3)
	_place(spirit_picker, Vector2(EDGE, TOP), Vector2(SIDE, col_h - WEAPON_PICKER_H - GAP))
	weapon_picker = WeaponPickerScript.new()
	add_child(weapon_picker)
	weapon_picker.setup(false)
	_place(weapon_picker, Vector2(EDGE, TOP + col_h - WEAPON_PICKER_H), Vector2(SIDE, WEAPON_PICKER_H))

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
	if details:
		details.show_character(char_id)
	if showcase:
		showcase.show_character(char_id)
	_mobile_show_character(char_id)
	start_button.disabled = false


## ---------------------------------------------------------------- TELEFON (prototip P1 "Büyütülmüş Klasik", 2026-10-03)
## Kullanıcı seçimi: masaüstü düzeni korunur, her şey telefon boyunda. Kök tam ekran (mobile_menu_fit.gd RootFitter bu ekranı
## artık 1920 tasarımına sıkıştırmaz). Sol: ruhani yetenek + başlangıç silahı (telefon boyu); orta: karakter kartları 4/3
## (240x288 = 4x sanat px), sütun sayısı ekran genişliğinden; sağ: vitrin (6x sahne) + yetenek ikonları (dokununca
## açıklaması altta) + BAŞLA. Masaüstünde bu fonksiyonlar çalışmaz.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")
const M_SKILL_KEYS := [["skill_icon", "skill_name", "skill_desc", "Q"], ["skill2_icon", "skill2_name", "skill2_desc", "E"],
		["skill3_icon", "skill3_name", "skill3_desc", "R"], ["passive_icon", "", "passive", "Pasif"]]
var _m_name: Label = null
var _m_preview: Control = null
var _m_skill_icons: Array = []
var _m_skill_frames: Array = []
var _m_skill_desc: Label = null
var _m_skill_index: int = 0


## TAM EKRAN (kullanıcı isteği 2026-10-04: "karakter seçme ekranları ... dükkan ekranı v.b bir pencere değil direk ekranı
## komple kaplayan bir arayüz olsun, gereksiz boş alanlar kalıyor çevrede her alanın değerlendirilmesini istiyorum" +
## "arayüz galaxy s22 ye göre değil tüm telefonlarla uyumlu olsun"): üst şerit + kenardan kenara üç panel, aralarında boşluk
## yok. Ölçüler ekran boyutundan ORANSAL (mantıksal tuval her telefonda en az 1920x1080 - geniş telefonlarda yana, tabletlerde
## aşağı uzar). Kart ölçeği orta sütunu doldurur, piksel sanatı bozulmasın diye 1/3'ün katına yuvarlanır (kitin dokuları 3x),
## artan genişlik kart aralarına dağıtılır. Yan sütun oranları M_LEFT_FRAC / M_RIGHT_FRAC.
const M_TOPBAR_FRAC := 0.11
const M_LEFT_FRAC := 0.26
const M_RIGHT_FRAC := 0.30
const M_COLUMNS := 3


static func mobile_card_k(avail_w: float, cols: int, min_sep: float) -> float:
	var k: float = (avail_w - (cols - 1) * min_sep) / (cols * MenuKit.CARD_SIZE.x)
	return clampf(floorf(k * 3.0) / 3.0, 1.0, 7.0 / 3.0)


func _build_mobile() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	var x0: float = safe.position.x
	var x1: float = view.x - safe.size.x
	var y0: float = safe.position.y
	var y1: float = view.y - safe.size.y
	var w: float = x1 - x0
	var topbar_h: float = clampf(roundf(view.y * M_TOPBAR_FRAC), 96.0, 150.0)

	## Üst şerit: Geri (sol) + başlık (orta), tam genişlik.
	var bar := MenuKit.make_panel("panel_tight")
	add_child(bar)
	_place(bar, Vector2(x0, y0), Vector2(w, topbar_h))
	back_button = MenuKit.make_button("< Geri", "tan", 40, topbar_h - 24.0)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	_place(back_button, Vector2(x0 + 12.0, y0 + 12.0), Vector2(240.0, topbar_h - 24.0))
	var title := MenuKit.make_label("Karakterini Seç", 48, MenuKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)
	_place(title, Vector2(x0, y0), Vector2(w, topbar_h))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body_y: float = y0 + topbar_h
	var body_h: float = y1 - body_y
	var left_w: float = roundf(w * M_LEFT_FRAC)
	var right_w: float = roundf(w * M_RIGHT_FRAC)
	var center_w: float = w - left_w - right_w

	## Sol: ruhani yetenek (üst) + başlangıç silahı (alt).
	var weapon_h: float = roundf(body_h * 0.42)
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	add_child(spirit_picker)
	spirit_picker.setup(3)
	_place(spirit_picker, Vector2(x0, body_y), Vector2(left_w, body_h - weapon_h))
	weapon_picker = WeaponPickerScript.new()
	add_child(weapon_picker)
	weapon_picker.setup(true)
	_place(weapon_picker, Vector2(x0, body_y + body_h - weapon_h), Vector2(left_w, weapon_h))

	## Orta: kart ızgarası (3 sütun, kaydırılır) bir panelin içinde - panel tüm sütunu kaplar.
	var center := MenuKit.make_panel("panel_tight")
	add_child(center)
	_place(center, Vector2(x0 + left_w, body_y), Vector2(center_w, body_h))
	var pad: float = 28.0 ## panel çerçevesi + kaydırma çubuğu payı
	var avail: float = center_w - 2.0 * pad - 16.0
	var k: float = mobile_card_k(avail, M_COLUMNS, 8.0)
	var card: Vector2 = (MenuKit.CARD_SIZE * k).floor()
	var sep: int = int(floorf((avail - M_COLUMNS * card.x) / (M_COLUMNS - 1)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	roster = RosterScript.new()
	roster.build(M_COLUMNS, k)
	roster.add_theme_constant_override("h_separation", sep)
	roster.add_theme_constant_override("v_separation", 8)
	roster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roster.character_picked.connect(_on_character_pressed)
	scroll.add_child(roster)

	## Sağ: ad + vitrin + yetenek ikonları (dokununca açıklama) + BAŞLA.
	var panel := MenuKit.make_panel("panel_tight")
	add_child(panel)
	_place(panel, Vector2(x1 - right_w, body_y), Vector2(right_w, body_h))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_m_name = MenuKit.make_label("", 48, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_m_name)
	var st: Dictionary = MenuKit.STAGE_BIG
	var stage := TextureRect.new()
	stage.texture = MenuKit.tex(str(st["file"]))
	stage.stretch_mode = TextureRect.STRETCH_KEEP
	stage.custom_minimum_size = st["size"]
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	col.add_child(stage)
	_m_preview = PreviewScript.new()
	stage.add_child(_m_preview)
	MenuKit.place(_m_preview, Vector2.ZERO, st["size"])
	_m_preview.set_meta("stage", st)
	var skills := HBoxContainer.new()
	skills.alignment = BoxContainer.ALIGNMENT_CENTER
	skills.add_theme_constant_override("separation", 14)
	col.add_child(skills)
	for i in M_SKILL_KEYS.size():
		var frame := MenuKit.make_panel("slot_normal")
		frame.custom_minimum_size = Vector2(104, 104)
		var btn := TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.pressed.connect(_mobile_select_skill.bind(i))
		frame.add_child(btn)
		skills.add_child(frame)
		_m_skill_frames.append(frame)
		_m_skill_icons.append(btn)
	_m_skill_desc = MenuKit.make_label("", 32, MenuKit.C_TEXT_DIM)
	_m_skill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_m_skill_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_m_skill_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_m_skill_desc.clip_text = true
	col.add_child(_m_skill_desc)
	start_button = MenuKit.make_button("BAŞLA", "sage", 80, clampf(roundf(body_h * 0.14), 112.0, 150.0))
	start_button.pressed.connect(_on_start_pressed)
	col.add_child(start_button)

	start_button.disabled = true
	var first: int = GameManager.selected_char_id if Characters.DEFS.has(GameManager.selected_char_id) else 1
	_on_character_pressed(first)
	UISound.connect_all_buttons(self)


func _mobile_show_character(char_id: int) -> void:
	if _m_name == null:
		return
	var def: Dictionary = Characters.get_def(char_id)
	_m_name.text = str(def.get("name", ""))
	var st: Dictionary = _m_preview.get_meta("stage")
	_m_preview.call("setup", def, int(st["scale"]), float(st["ground_y"]))
	_m_preview.set("playing", true)
	for i in M_SKILL_KEYS.size():
		var path: String = str(def.get(M_SKILL_KEYS[i][0], ""))
		(_m_skill_icons[i] as TextureButton).texture_normal = load(path) if path != "" and ResourceLoader.exists(path) else null
	_mobile_select_skill(0)


## Yetenek ikonuna dokununca açıklaması altta ("Q · Patlat: ..."); seçili ikonun çerçevesi altın.
func _mobile_select_skill(i: int) -> void:
	_m_skill_index = i
	for j in _m_skill_frames.size():
		(_m_skill_frames[j] as PanelContainer).add_theme_stylebox_override("panel", MenuKit.style("slot_selected" if j == i else "slot_normal"))
	if selected_char < 0:
		return
	var def: Dictionary = Characters.get_def(selected_char)
	var keys: Array = M_SKILL_KEYS[i]
	var desc: String = str(def.get(keys[2], ""))
	var colon: int = desc.find(": ")
	if colon >= 0 and colon < 12:
		desc = desc.substr(colon + 2) ## "ULTİ: ..." / "TEMEL: ..." ön eki
	var title: String = str(def.get(keys[1], "")) if keys[1] != "" else desc.split(":")[0]
	if keys[1] == "":
		desc = desc.substr(desc.find(":") + 1).strip_edges() if desc.find(":") >= 0 else desc
	_m_skill_desc.text = "%s  ·  %s\n%s" % [keys[3], title, desc]


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
