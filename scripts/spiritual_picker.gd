extends PanelContainer

## Ruhani Yetenek seçici (kullanıcı isteği, 2026-09-21): karakter seçim ekranında (character_select.gd) ve çok oyunculu lobide
## (lobby_menu.gd) HER oyuncu, karakterinden bağımsız olarak ruhani yeteneklerden birini seçer (bkz. spiritual_skills.gd).
## Tamamen kodla kurulur (.tscn düzenlemesi yok). Seçim doğrudan GameManager.selected_spiritual'a yazılır; oyun başlayınca
## player.gd get_spirit_id() oradan okur, HUD (hud.gd) ikonu oradan gösterir.
## Görünüm (kullanıcı isteği 2026-09-24, menülerin bej/cozy yeniden tasarımı): MenuKit paneli + süslü bölüm başlığı, ikonlar
## ahşap slot çerçevelerinde (seçili = altın), ikonlar 144 px'lik (48 sanat px x3) PNG'lerden TAM 2x (96 px) çizilir -
## eski 76 px (1.58x) ölçek her sanat pikselini eşit olmayan boyutta çiziyordu.

const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

signal picked(id: String)

const ICON_SIZE := 96

var _frames: Dictionary = {}
var _buttons: Dictionary = {} ## id -> TextureButton
var _rings: Dictionary = {} ## id -> seçili halkası (Panel)

## Kullanıcı bildirimi (2026-09-24): "ruhani yetenekler seçildiğinde seçildiği belli olmuyor butonlarında" - tek ipucu
## çerçevenin slot_selected dokusuydu, ama o dokunun altın kenarı 96 px'lik ikonun altında kalan ~6 px'lik ince bir
## şerit ve slot_normal'ın açık kahvesine çok yakın tonda (ekran görüntüsünde ayırt edilemiyordu). Artık karakter
## kartlarının seçili dili (card_selected.png'nin dış parlak altın kenarı) tekrarlanıyor: seçili ikonun ÜSTÜNE kalın altın
## bir halka çizilir ve seçili OLMAYAN ikonlar soluklaşır.
## İlk deneme card_selected'ın açık altınıydı (255, 227, 154) - bej panel üstünde yine soluk kaldı (ekran görüntüsüyle
## kontrol edildi); daha doygun altın + iki yanında koyu kahve kontur.
const SELECT_RING_COLOR := Color(1.0, 0.78, 0.22)
const SELECT_RING_SHADOW := Color(0.35, 0.21, 0.06) ## card_selected.png koyu kenarı (90, 55, 16)
const UNSELECTED_MODULATE := Color(0.62, 0.6, 0.58)
const HOVER_MODULATE := Color(0.88, 0.87, 0.85)
var _hover_id: String = ""
var _name_label: Label = null
var _desc_label: Label = null
var _columns: int = 3


## columns: ikon ızgarasının sütun sayısı (yan panel için 3).
func setup(columns: int = 3) -> void:
	_columns = columns
	_build()
	select(GameManager.selected_spiritual if SpiritualSkillsScript.is_valid(GameManager.selected_spiritual) else SpiritualSkillsScript.DEFAULT_ID)


func _build() -> void:
	add_theme_stylebox_override("panel", MenuKit.style("panel_tight"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	vbox.add_child(MenuKit.make_section_header("Ruhani Yetenek (%s)" % GameManager.get_action_key_label("skill4")))

	var grid := GridContainer.new()
	grid.columns = _columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for id: String in SpiritualSkillsScript.ORDER:
		var def: Dictionary = SpiritualSkillsScript.get_def(id)
		var frame := MenuKit.make_panel("slot_normal")
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tex_path: String = str(def.get("icon", ""))
		if ResourceLoader.exists(tex_path):
			btn.texture_normal = load(tex_path)
		btn.tooltip_text = str(def.get("name", ""))
		btn.pressed.connect(_on_icon_pressed.bind(id))
		btn.mouse_entered.connect(_set_hover.bind(id))
		btn.mouse_exited.connect(_set_hover.bind(""))
		btn.focus_entered.connect(_set_hover.bind(id))
		btn.focus_exited.connect(_set_hover.bind(""))
		frame.add_child(btn)
		frame.add_child(_make_select_ring())
		grid.add_child(frame)
		_frames[id] = frame
		_buttons[id] = btn
		_rings[id] = frame.get_child(frame.get_child_count() - 1)

	_name_label = MenuKit.make_label("", MenuKit.FS_BODY, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_name_label)

	var desc_box := MenuKit.make_panel("inset")
	desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_box)
	_desc_label = MenuKit.make_label("", MenuKit.FS_BODY, MenuKit.C_TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Label'ın Godot 4 varsayılanı SHRINK_CENTER - açıklama kutunun ortasında yüzmesin, üstten başlasın.
	_desc_label.size_flags_vertical = Control.SIZE_FILL
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_box.add_child(_desc_label)


func _on_icon_pressed(id: String) -> void:
	select(id)
	picked.emit(id)


func _set_hover(id: String) -> void:
	_hover_id = id
	_refresh_frames()


## İkonun üstüne (çerçevenin kenarına taşarak) çizilen kalın altın halka - sadece seçili ikonda görünür.
func _make_select_ring() -> Panel:
	## Katmanlar (içerik kenarından dışa, px): 0..-2 koyu, -2..-7 altın, -7..-9 koyu. Izgara boşluğu 6 px - dış kontur
	## komşu çerçeveye en fazla 3 px taşar, seçili olanı zaten öne çıkarması istenen şey.
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", _ring_style(9.0, 2, SELECT_RING_SHADOW))
	for layer: Array in [[7.0, 5, SELECT_RING_COLOR], [2.0, 2, SELECT_RING_SHADOW]]:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", _ring_style(float(layer[0]), int(layer[1]), layer[2]))
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.add_child(p)
	ring.visible = false
	return ring


static func _ring_style(expand: float, width: int, col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(width)
	sb.border_color = col
	sb.set_expand_margin_all(expand) ## PanelContainer içerik alanından çerçevenin dış kenarına taşsın
	sb.anti_aliasing = false
	return sb


func _refresh_frames() -> void:
	for k: String in _frames.keys():
		var selected: bool = k == GameManager.selected_spiritual
		var kind: String = "slot_selected" if selected else ("slot_hover" if k == _hover_id else "slot_normal")
		(_frames[k] as PanelContainer).add_theme_stylebox_override("panel", MenuKit.style(kind))
		if _rings.has(k):
			(_rings[k] as Control).visible = selected
		if _buttons.has(k):
			(_buttons[k] as CanvasItem).modulate = Color.WHITE if selected else (HOVER_MODULATE if k == _hover_id else UNSELECTED_MODULATE)


func select(id: String) -> void:
	if not SpiritualSkillsScript.is_valid(id):
		return
	GameManager.selected_spiritual = id
	_refresh_frames()
	var def: Dictionary = SpiritualSkillsScript.get_def(id)
	if _name_label:
		_name_label.text = "%s%s" % [str(def.get("name", "")), "" if bool(def.get("active", false)) else " (Pasif)"]
	if _desc_label:
		_desc_label.text = str(def.get("desc", ""))
