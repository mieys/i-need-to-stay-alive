extends PanelContainer

## Seçili karakterin vitrini (tek/çok oyunculu ekranların ORTAK bileşeni): isim + küçük piksel "sahne" (sıcak gökyüzü,
## uzak tepeler, çiçekli çimen tümseği - tools/gen_menu_kit.py stage()) üstünde karakterin idle animasyonu, tam sayı
## ölçekte (büyük sahne 6x, küçük 4x) + 2x2 temel istatistik kutusu. Ekran, get_content() ile panelin altına kendi öğelerini (ör. BAŞLA) ekleyebilir.

const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")

var _name_label: Label
var _stage: TextureRect
var _preview: Control
var _content: VBoxContainer
var _stage_def: Dictionary


## big=true: tek oyunculu sağ sütun (336x420 sahne, 6x); false: lobi sağ sütunu (336x186, 4x).
func build(big: bool) -> void:
	_stage_def = MenuKit.STAGE_BIG if big else MenuKit.STAGE_SMALL
	add_theme_stylebox_override("panel", MenuKit.style("panel_tight"))
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	add_child(_content)

	_name_label = MenuKit.make_label("", MenuKit.FS_TITLE, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_name_label)

	_stage = TextureRect.new()
	_stage.texture = MenuKit.tex(str(_stage_def["file"]))
	_stage.stretch_mode = TextureRect.STRETCH_KEEP
	_stage.custom_minimum_size = _stage_def["size"]
	_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	_content.add_child(_stage)
	_preview = PreviewScript.new()
	_stage.add_child(_preview)
	MenuKit.place(_preview, Vector2.ZERO, _stage_def["size"])
	## Temel istatistikler (herkes aynı değerlerle başlıyor - bkz. MenuKit.BASE_STATS).
	_content.add_child(MenuKit.make_stats_grid())


func get_content() -> VBoxContainer:
	return _content


func show_character(char_id: int) -> void:
	var def: Dictionary = Characters.get_def(char_id)
	_name_label.text = str(def.get("name", ""))
	_preview.setup(def, int(_stage_def["scale"]), float(_stage_def["ground_y"]))
	_preview.playing = true
