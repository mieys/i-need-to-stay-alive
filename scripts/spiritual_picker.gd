extends PanelContainer

## Ruhani Yetenek seçici (kullanıcı isteği, 2026-09-21): karakter seçim ekranında (character_select.gd) ve çok oyunculu lobide
## (lobby_menu.gd) HER oyuncu, karakterinden bağımsız olarak 6 ruhani yetenekten birini seçer (bkz. spiritual_skills.gd).
## Tamamen kodla kurulur (.tscn düzenlemesi yok). Seçim doğrudan GameManager.selected_spiritual'a yazılır; oyun başlayınca
## player.gd get_spirit_id() oradan okur, HUD (hud.gd) ikonu oradan gösterir.

const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

signal picked(id: String)

const ICON_SIZE := 76
const PAL_BG := Color(0.239, 0.2, 0.149, 1.0)
const PAL_BORDER := Color(0.168, 0.137, 0.101, 1.0)
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)
const SELECT_COLOR := Color(0.72, 0.5, 1.0, 1.0) ## mor: HUD'daki ruhani buton çerçevesiyle aynı dil

var _frames: Dictionary = {}
var _name_label: Label = null
var _desc_label: Label = null
var _columns: int = 3


## columns: ikon ızgarasının sütun sayısı (dar yan panel için 3, geniş alan için 6).
func setup(columns: int = 3) -> void:
	_columns = columns
	_build()
	select(GameManager.selected_spiritual if SpiritualSkillsScript.is_valid(GameManager.selected_spiritual) else SpiritualSkillsScript.DEFAULT_ID)


func _frame_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.07, 1.0)
	var w: int = 4 if selected else 2
	style.set_border_width_all(w)
	style.border_color = SELECT_COLOR if selected else PAL_BORDER
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	return style


func _build() -> void:
	## Kullanıcı isteği (2026-09-21): arayüz UIKit (assets/ui/kit) ile uyumlu - ahşap pencere çerçevesi.
	add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "RUHANİ YETENEK (%s)" % GameManager.get_action_key_label("skill4")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", PAL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = _columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for id: String in SpiritualSkillsScript.ORDER:
		var def: Dictionary = SpiritualSkillsScript.get_def(id)
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", _frame_style(false))
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_path: String = str(def.get("icon", ""))
		if ResourceLoader.exists(tex_path):
			btn.texture_normal = load(tex_path)
		btn.tooltip_text = str(def.get("name", ""))
		btn.pressed.connect(_on_icon_pressed.bind(id))
		frame.add_child(btn)
		grid.add_child(frame)
		_frames[id] = frame

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 44)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 30)
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.79, 0.7))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, 0)
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_desc_label)


func _on_icon_pressed(id: String) -> void:
	select(id)
	picked.emit(id)


func select(id: String) -> void:
	if not SpiritualSkillsScript.is_valid(id):
		return
	GameManager.selected_spiritual = id
	for k: String in _frames.keys():
		(_frames[k] as PanelContainer).add_theme_stylebox_override("panel", _frame_style(k == id))
	var def: Dictionary = SpiritualSkillsScript.get_def(id)
	if _name_label:
		_name_label.text = "%s%s" % [str(def.get("name", "")), "" if bool(def.get("active", false)) else " (Pasif)"]
	if _desc_label:
		_desc_label.text = str(def.get("desc", ""))
