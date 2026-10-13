extends PanelContainer

## Evcil hayvan seçici (kullanıcı isteği 2026-10-12: "petler karakter seçim ekranında silah seçer gibi seçilecek"). Tek oyunculu karakter
## seçimi (character_select.gd) ve çok oyunculu lobi (lobby_menu.gd) ORTAK bileşeni - ruhani yetenek / başlangıç silahı seçicilerinin
## yanında, aynı menü kitiyle. Az hayvan olduğu için silah seçicideki açılır ızgara yok: yuvalar yan yana, birine basmak seçer;
## altında seçilenin açıklaması. Seçim GameManager.selected_pet'e yazılır (yerel tercih, ağdan gitmez). Veriler pet_catalog.gd'de.
## İkiden fazla hayvan (Kelebek Ruhu ile 3 oldu): yuvaya ad sığmıyor ("Kelebek Ruhu" 376 px sütunda üçte bir yuvadan geniş) -> yuvalar
## SADECE ikon, seçilenin adı başlıkta ("Evcil: Kelebek Ruhu"); boşalan yükseklik açıklamaya kalır.
## mobile = true: telefon boyları (yazılar 40/48, yuva yüksekliği büyük).

signal picked(key: String)

const PetCatalog := preload("res://scripts/pet_catalog.gd")

## Çağıranların yerleşim için bildiği asgari yükseklik (başlık + yuvalar + 2 satır açıklama + kenar boşlukları).
const DESKTOP_HEIGHT := 250.0
## Kompakt (lobi sağ sütunu - orada ruhani yetenek paneline yer kalsın): yuva yatay (ikon solda, ad sağda).
const COMPACT_HEIGHT := 190.0

var mobile: bool = false
var compact: bool = false
var _slots: Dictionary = {} ## anahtar -> Button
var _desc_label: Label = null
var _header_label: Label = null
var _icon_only: bool = false


func setup(is_mobile: bool = false, is_compact: bool = false) -> void:
	mobile = is_mobile
	compact = is_compact
	_build()
	select(PetCatalog.selected(), false)


func _fs(desktop: int, phone: int) -> int:
	return phone if mobile else desktop


func _build() -> void:
	add_theme_stylebox_override("panel", MenuKit.style("panel_tight"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_icon_only = PetCatalog.KEYS.size() > 2
	var header: HBoxContainer = MenuKit.make_section_header("Evcil Hayvan", _fs(MenuKit.FS_BODY, 40))
	_header_label = header.get_node_or_null("Text") as Label
	v.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var icon_px: float = 80.0 if mobile else (52.0 if compact else 72.0)
	for key: String in PetCatalog.KEYS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, icon_px + 12.0) if (compact or _icon_only) else Vector2(0, icon_px + (60.0 if mobile else 40.0))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%s\n%s" % [PetCatalog.display_name(key), PetCatalog.description(key)]
		b.pressed.connect(select.bind(key))
		var col: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 2)
		b.add_child(col)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ic := TextureRect.new()
		ic.texture = PetCatalog.icon(key)
		ic.custom_minimum_size = Vector2(icon_px if compact else 0.0, icon_px)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ic)
		if not _icon_only:
			col.add_child(MenuKit.make_label(PetCatalog.display_name(key), _fs(MenuKit.FS_SMALL, 40), MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(b)
		_slots[key] = b

	_desc_label = MenuKit.make_label("", _fs(MenuKit.FS_SMALL, 32), MenuKit.C_TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc_label.clip_text = true
	_desc_label.custom_minimum_size = Vector2(0, 100.0 if mobile else (50.0 if compact else 56.0))
	v.add_child(_desc_label)


func select(key: String, emit: bool = true) -> void:
	if not PetCatalog.is_valid(key):
		key = PetCatalog.DEFAULT_KEY
	GameManager.selected_pet = key
	for k: String in _slots:
		var b: Button = _slots[k]
		var style: StyleBox = MenuKit.style("slot_selected" if k == key else "slot_normal")
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, MenuKit.style("slot_hover") if st == "hover" and k != key else style)
	if _desc_label:
		_desc_label.text = PetCatalog.description(key)
	if _icon_only and _header_label:
		_header_label.text = "Evcil: %s" % PetCatalog.display_name(key)
	if emit:
		picked.emit(key)
