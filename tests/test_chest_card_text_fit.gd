extends Node

## Sandık ödül kartı (kullanıcı bildirimi 2026-09-21: "kart ufakken yazılar kocaman kalıyor"): HER eşya için kart 300x480'de
## kalmalı (uzun açıklama kartı uzatmamalı), açıklama ayrılan alana SIĞMALI, isim kart iç genişliğini aşmamalı.

const ChestMenuScene: PackedScene = preload("res://scenes/chest_menu.tscn")


func test_every_item_card_keeps_size_and_text_fits() -> void:
	var menu: CanvasLayer = ChestMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	## setup() açılış animasyonunu başlatır; kartı doğrudan kuruyoruz (kart alanını hazırla).
	menu.cards_container = menu.get_node("CenterContainer/VBox/CardsContainer")
	menu.cards_container.visible = true
	var items_script: GDScript = load("res://scripts/items.gd")
	var worst_desc_font: int = 99
	for key in items_script.KEYS:
		for c in menu.cards_container.get_children():
			menu.cards_container.remove_child(c)
			c.queue_free()
		menu._reward_tier = 1
		var card: Control = menu._build_card({"type": "item", "key": key})
		menu.cards_container.add_child(card)
		await get_tree().process_frame
		await get_tree().process_frame
		menu._fit_card_texts(card)
		await get_tree().process_frame
		assert(is_equal_approx(card.size.x, 300.0) and is_equal_approx(card.size.y, 480.0), "kart buyudu (%s): %s" % [key, card.size])
		var desc: RichTextLabel = card.get_meta("desc_label")
		assert(float(desc.get_content_height()) <= desc.size.y + 0.5, "aciklama sigmiyor (%s): %s > %s" % [key, desc.get_content_height(), desc.size.y])
		var fs: int = desc.get_theme_font_size("normal_font_size")
		assert(fs >= menu.CARD_DESC_MIN_FONT_SIZE)
		worst_desc_font = mini(worst_desc_font, fs)
		var name_lbl: Label = card.get_meta("name_label")
		var font: Font = name_lbl.get_theme_font("font")
		var nfs: int = name_lbl.get_theme_font_size("font_size")
		var nw: float = font.get_string_size(name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		assert(nw <= name_lbl.size.x + 0.5 or name_lbl.autowrap_mode != TextServer.AUTOWRAP_OFF, "isim tasiyor (%s)" % key)
		## butonlar kartin icinde
		for b in card.find_children("*", "Button", true, false):
			var r: Rect2 = (b as Control).get_global_rect()
			assert(card.get_global_rect().grow(0.5).encloses(r), "buton kart disina tasiyor (%s)" % key)
	print("worst desc font: ", worst_desc_font)
	menu.queue_free()


func test_short_desc_keeps_full_font_size() -> void:
	var menu: CanvasLayer = ChestMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.cards_container = menu.get_node("CenterContainer/VBox/CardsContainer")
	menu.cards_container.visible = true
	menu._reward_tier = 1
	var card: Control = menu._build_card({"type": "weapon", "key": "dagger"})
	menu.cards_container.add_child(card)
	await get_tree().process_frame
	await get_tree().process_frame
	menu._fit_card_texts(card)
	var desc: RichTextLabel = card.get_meta("desc_label")
	assert(desc.get_theme_font_size("normal_font_size") == menu.CARD_DESC_FONT_SIZE, "kisa metin kucultulmemeli")
	menu.queue_free()
