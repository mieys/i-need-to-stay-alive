extends Button

const GOLD_PER_TICK := {"mine": 5, "gold_collector": 1}
const DISPLAY_NAME := {"mine": "MADEN", "gold_collector": "ALTIN TOPL."}

var item_key: String = ""

var _title_label: Label
var _level_label: Label
var _fill_bar: Control
var _cost_label: Label


func setup(key: String) -> void:
	item_key = key
	text = ""
	clip_text = true
	## DÜZELTME (kullanıcı isteği: "altın üretim panelindekilerin fontu
	## güncel fontla aynı değil ve çok ufak görünüyorlar, ayrıca butonlarla
	## aynı boyutta değiller") - kutu artık ENVANTER/DÜKKAN butonlarıyla
	## AYNI genişlikte (168), yükseklik de büyütülmüş fontlara sığacak
	## şekilde artırıldı.
	## DÜZELTME (kullanıcı isteği: "maden ve altın toplayıcı butonunu alttan
	## üste doğru %35 kısalt") - dış kutu 128 -> 83.2 (hud.gd BTN_H ile
	## BİREBİR aynı kalmalı). Yükseklik küçülünce içerik (ikon+2 etiket+
	## doluluk çubuğu+fiyat etiketi) eskisi gibi sığmazdı, bu yüzden kenar
	## boşlukları/aralıklar/font boyutları/ikon boyutu da AYNI orantıda
	## (~%35) küçültüldü - hiçbir metin/ikon kutunun dışına taşmıyor.
	custom_minimum_size = Vector2(168, 83.2)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE

	## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni
	## istiyorum" - eski düz renkli StyleBoxFlat yerine oyundaki HER buton
	## gibi ShopPanel'in paylaşılan ahşap plaka stiline sahip.
	ShopPanel._apply_wood_button_style(self)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(title_hbox)

	var icon_rect: TextureRect = TextureRect.new()
	var icon_path: String = "res://assets/ui/newui/icon_gem_big.png" if key == "mine" else "res://assets/ui/newui/icon_ingot.png"
	icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_hbox.add_child(icon_rect)

	## DÜZELTME (kullanıcı isteği: "altın üretim panelindekilerin fontu
	## güncel fontla aynı değil ve çok ufak görünüyorlar, ayrıca butonlarla
	## aynı boyutta değiller") - ENVANTER/DÜKKAN butonlarıyla (font_size 45)
	## aynı görsel ağırlıkta görünmeleri için fontlar belirgin şekilde
	## büyütüldü (18/15/16 -> 24/20/22). Fontun kendisi zaten proje geneli
	## temadan (m5x7, bkz. assets/fonts/theme.tres) miras alınıyor, burada
	## SADECE boyut değişiyor - _make_label açıkça bir font override
	## yapmıyor, bu yüzden ENVANTER/DÜKKAN ile TAM AYNI font ailesini kullanır.
	var display_name: String = DISPLAY_NAME.get(key, key)
	_title_label = _make_label(display_name, 16, Color(0.96, 0.89, 0.74, 1))
	title_hbox.add_child(_title_label)

	_level_label = _make_label("", 14, Color(1, 0.9, 0.3, 1))
	vbox.add_child(_level_label)

	_fill_bar = Control.new()
	_fill_bar.custom_minimum_size = Vector2(0, 8)
	_fill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_bar.set_script(preload("res://scripts/mine_fill_bar.gd"))
	vbox.add_child(_fill_bar)

	_cost_label = _make_label("", 16, Color(1.0, 0.85, 0.35, 1.0))
	vbox.add_child(_cost_label)


func _make_label(txt: String, font_size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func refresh(level: int, max_level: int, cost: int, fill_progress: float, can_afford: bool) -> void:
	var title_str: String = "Maden" if item_key == "mine" else "Altın Toplayıcı"
	var gold_per_tick: int = 5 if item_key == "mine" else 1
	var fill_base: float = 8.0 if item_key == "mine" else 6.0
	
	var duration: float = fill_base
	if level > 0:
		duration = fill_base / sqrt(float(level))
	
	duration = round(duration * 10.0) / 10.0
	var income_str: String = "%s saniyede +%d Altın" % [str(duration), gold_per_tick]

	if level >= max_level:
		_level_label.text = "Seviye %d/%d" % [level, max_level]
		_cost_label.text = "MAX"
		_fill_bar.visible = false
		disabled = true
		tooltip_text = "%s\nSeviye: %d/%d (Son Seviye)\nGelir: %s" % [title_str, level, max_level, income_str]
	else:
		_level_label.text = "Seviye %d/%d" % [level, max_level]
		_cost_label.text = "%d Altın" % cost
		_fill_bar.visible = level > 0
		if _fill_bar.visible:
			_fill_bar.progress = fill_progress
			_fill_bar.queue_redraw()
		disabled = not can_afford
		var cost_str: String = "%d Altın" % cost
		tooltip_text = "%s\nSeviye: %d/%d\nGelir: %s\nYükseltme Maliyeti: %s" % [title_str, level, max_level, income_str, cost_str]
