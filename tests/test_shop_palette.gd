extends Node

## Dükkan panelinin arkaplan/kenarlık renklerinin envanter & istatistik
## panelleriyle BİREBİR aynı palete çekildiğini doğrular (kullanıcı isteği).
## Paletin kaynağı: inventory_panel.tscn / stats_panel.tscn StyleBoxFlat'leri.

const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)
const PAL_WINDOW_BORDER := Color(0.25, 0.15, 0.08, 1.0)
const PAL_HEADER_BG := Color(0.42, 0.28, 0.16, 1.0)
const PAL_HEADER_BORDER := Color(0.28, 0.17, 0.09, 1.0)
const PAL_CONTENT_BG := Color(0.23921569, 0.2, 0.14901961, 1.0)
const PAL_CONTENT_BORDER := Color(0.16862746, 0.13725491, 0.101960786, 1.0)


func _make_panel() -> Control:
	var scene: PackedScene = load("res://scenes/shop_panel.tscn")
	var panel: Control = scene.instantiate()
	add_child(panel)
	return panel


func _style_of(node: Control, name: String) -> StyleBoxFlat:
	return node.get_theme_stylebox(name) as StyleBoxFlat


func test_window_backgrounds_use_inventory_palette() -> void:
	var panel: Control = _make_panel()
	for path: String in ["Frame/ContentBG", "PreviewPanel/PreviewBG"]:
		var bg: Panel = panel.get_node(path)
		var sb: StyleBoxFlat = _style_of(bg, "panel")
		assert(sb != null, "%s icin StyleBoxFlat bekleniyordu" % path)
		assert(sb.bg_color.is_equal_approx(PAL_WINDOW_BG),
			"%s arkaplani envanter paletiyle ayni degil: %s" % [path, sb.bg_color])
		assert(sb.border_color.is_equal_approx(PAL_WINDOW_BORDER),
			"%s kenarligi envanter paletiyle ayni degil: %s" % [path, sb.border_color])
		## Eski doku stilinden kalan renk çarpanı nötrlenmiş olmalı.
		assert(bg.self_modulate.is_equal_approx(Color(1, 1, 1, 1)),
			"%s self_modulate notr olmali" % path)
	panel.queue_free()


func test_headers_use_inventory_palette() -> void:
	var panel: Control = _make_panel()
	for path: String in ["Frame/HeaderBG", "PreviewPanel/PreviewHeaderBG"]:
		var header: Panel = panel.get_node(path)
		var sb: StyleBoxFlat = _style_of(header, "panel")
		assert(sb != null, "%s icin StyleBoxFlat bekleniyordu" % path)
		assert(sb.bg_color.is_equal_approx(PAL_HEADER_BG),
			"%s baslik rengi yanlis: %s" % [path, sb.bg_color])
		assert(sb.border_color.is_equal_approx(PAL_HEADER_BORDER),
			"%s baslik kenarligi yanlis: %s" % [path, sb.border_color])
	panel.queue_free()


func test_sidebar_and_desc_scroll_use_content_palette() -> void:
	var panel: Control = _make_panel()
	var sidebar: Panel = panel.get_node("Frame/SidebarBG")
	var sb: StyleBoxFlat = _style_of(sidebar, "panel")
	assert(sb != null and sb.bg_color.is_equal_approx(PAL_CONTENT_BG),
		"Sidebar koyu icerik tonunda olmali")

	## Önizlemedeki açıklama kutusu eskiden hiç stili olmadığı için temanın
	## açık krem varsayılanına düşüyordu - artık koyu içerik kutusu olmalı.
	var desc: ScrollContainer = panel.get_node("PreviewPanel/PreviewMargin/PreviewVBox/DescScroll")
	var dsb: StyleBoxFlat = _style_of(desc, "panel")
	assert(dsb != null, "DescScroll icin StyleBoxFlat bekleniyordu")
	assert(dsb.bg_color.is_equal_approx(PAL_CONTENT_BG),
		"DescScroll koyu icerik tonunda olmali: %s" % dsb.bg_color)
	panel.queue_free()


func test_no_texture_styleboxes_remain_on_backgrounds() -> void:
	## Asıl şikayet buydu: arkaplanlar shop_redesign/*.png dokularından
	## geliyordu ve envanter paletiyle uyumsuzdu. Hiçbiri kalmamalı.
	var panel: Control = _make_panel()
	var paths: Array = [
		"Frame/ContentBG", "Frame/SidebarBG", "Frame/HeaderBG",
		"PreviewPanel/PreviewBG", "PreviewPanel/PreviewHeaderBG",
	]
	for path: String in paths:
		var node: Control = panel.get_node(path)
		var sb: StyleBox = node.get_theme_stylebox("panel")
		assert(not (sb is StyleBoxTexture),
			"%s hala doku tabanli StyleBoxTexture kullaniyor" % path)
	panel.queue_free()


## NOT - SORUMLULUK PAYLAŞIMI:
## Dükkandaki 39 ürün kartı ve 6 satın alma/yükseltme butonu, stillerini
## SAHNEDEN değil shop_panel.gd'den (çalışma zamanında) alıyor:
##   - kartlar        -> _refresh_selection_highlight() (_card_normal_style /
##                       _selected_row_style)
##   - butonlar       -> _apply_inventory_palette()
## Bunun sebebi: Godot editörü alt-kaynakları "sahne_yolu::id" ile
## önbelleğe alıyor; sahne açıkken bir alt-kaynağın TÜRÜNÜ değiştirsem
## (StyleBoxTexture -> StyleBoxFlat) editör kendi önbellekteki eski nesnesini
## diske geri yazıp değişikliği geri alıyor. Bu yüzden tür değişimi gereken
## yerler koda taşındı; sahnede sadece YENİ id'li (önbellekte karşılığı
## olmayan) düz stiller bırakıldı.
##
## Bu test dosyası da bu ayrımı takip ediyor: aşağıdaki testler sahnenin
## kendi garanti ettiği stilleri doğruluyor. Script'e bağlı stiller burada
## doğrulanamıyor çünkü test ortamında autoload'lar (UISound/GameManager)
## olmadığı için shop_panel.gd hiç yüklenemiyor.
func test_item_card_scene_default_is_not_the_old_dark_theme_fallback() -> void:
	## Kartların çalışma zamanı stili script'te; burada sadece sahnedeki
	## kartın hâlâ bir "panel" stili TAŞIDIĞINI doğruluyoruz. Eski kodda
	## seçili olmayan kartlarda override tamamen KALDIRILIYOR ve tema'nın
	## neredeyse siyah varsayılanına düşülüyordu - regresyon olursa
	## _refresh_selection_highlight()'taki add_theme_stylebox_override
	## çağrısı kaybolur ve kartlar yine kararır.
	var src: String = FileAccess.get_file_as_string("res://scripts/shop_panel.gd")
	assert(not src.contains("remove_theme_stylebox_override(\"panel\")"),
		"Kartlarda stylebox override'i KALDIRAN eski kod geri gelmis - " +
		"kartlar temanin siyah varsayilanina duser")
	assert(src.contains("_card_normal_style"),
		"Kartlara paletten stil uygulayan _card_normal_style kaybolmus")
	assert(not src.contains("Color(1.55, 1.42, 1.22, 1)"),
		"Eski 1.55x aydinlatma carpani geri gelmis")
