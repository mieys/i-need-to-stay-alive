extends Node

## Madde 428 -> 461: masaüstü YETENEK EVRİMİ kartı (461 "ahşap efsun kartı"; level_up_screen.gd _layout_evolution_boxes). Kartlar pencerelerin piksel
## kutusu (pixel_box.gd), 480 genişlik, ölçeksiz; normal evrim mor / final kırmızı kenar (hud_theme EVO_EDGE / EVO_FINAL_EDGE); yazılar
## m5x7 32/48; bütün karakterlerin bütün evrimleri (en uzun açıklama dahil) kartta ve ekranda sığar; seçim hale/ölçek oynatmadan "evo:<id>"
## yayar.

const SE := preload("res://scripts/skill_evolutions.gd")
const HT := preload("res://scripts/hud_theme.gd")
const PixelBoxScript := preload("res://scripts/pixel_box.gd")
const MATTHEW := 3
const OWNED := ["matthew_q1", "matthew_q3", "matthew_e2", "matthew_r1", "matthew_r2"]


class FakePlayer extends Node2D:
	var level: int = 20
	var is_chat_typing: bool = false
	var skill_evolutions: Dictionary = {}

	func get_upgrade_count(_id: String) -> int:
		return 0


var _saved_char: int = 0


func _open(owned: Array) -> Array:
	_saved_char = GameManager.selected_char_id
	GameManager.selected_char_id = MATTHEW
	var p := FakePlayer.new()
	for id: String in owned:
		p.skill_evolutions[id] = true
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	screen.set("screen_level", 20)
	screen.set("force_evolution", true)
	add_child(screen)
	for i in 4:
		await get_tree().process_frame
	return [screen, p]


func _close(pair: Array) -> void:
	(pair[0] as Node).free()
	(pair[1] as Node).free()
	GameManager.selected_char_id = _saved_char


## Teklif: Q 4. evrim + E + R FİNAL (R'nin normal evrimleri alınmış).
func _fixed_offer(screen: Node) -> void:
	var offer: Array = [SE.find("matthew_q4"), SE.find("matthew_e3"), SE.find("matthew_rf")]
	screen.set("_evo_offers", offer)
	screen.call("_populate_evolution_rows")
	for i in 4:
		await get_tree().process_frame


func test_desktop_cards_are_pixel_boxes_with_tier_edges() -> void:
	var pair: Array = await _open(OWNED)
	var screen: Node = pair[0]
	await _fixed_offer(screen)
	assert(bool(screen.get("_evo_mode")), "evrim ekranı açılmalı")
	assert(bool(screen.get("_evo_box")), "masaüstünde yeni kutu kart")
	var cards: Array = screen.cards
	var tiers: Array = screen.get("_card_tiers")
	var top: float = 1.0e9
	var bottom: float = 0.0
	for i in 3:
		var card: Button = cards[i]
		assert(card.visible, "kart %d görünmeli" % i)
		## madde 461 "ahşap efsun kartı": 390 genişlik, en az 480 boy, ölçeksiz (üstüne gelinmedikçe)
		assert(is_equal_approx(card.size.x, 390.0), "kart 390 genişlik: %s" % card.size)
		assert(card.size.y >= 480.0, "kart en az 480 boy (eski efsun kartı oranı): %s" % card.size)
		assert(card.scale == Vector2.ONE, "üstüne gelinmeyen kart ölçeklenmez")
		var sb: StyleBox = card.get_theme_stylebox("normal")
		assert(sb.get_script() == PixelBoxScript, "kart kutusu piksel kutu olmalı")
		var fin: bool = int(tiers[i]) == 4
		var want: Color = Color(HT.EVO_FINAL_EDGE if fin else HT.EVO_EDGE, 0.8)
		assert((sb.get("border_color") as Color).is_equal_approx(want), "kart %d kenarı kısık kademe rengi" % i)
		assert(sb.get("bg_color") == (HT.EVO_FINAL_FILL if fin else HT.EVO_FILL), "gövde eski efsun kartının rengi")
		assert(int(sb.get("border_width_left")) == 3, "kenar diğer pencereler gibi 1 sanat px")
		assert(int(sb.get("corner_radius_top_left")) == 15, "hafif oval köşe")
		for st: String in ["hover", "pressed", "hover_pressed"]:
			assert(card.get_theme_stylebox(st) == sb, "%s kutusu normalle aynı (altın kenar yok)" % st)
		assert(card.get_theme_stylebox("focus") is StyleBoxEmpty, "odak çerçevesi yok (odak da büyütür)")
		assert(card.find_child("EvoWell", true, false) == null, "simgenin çevresinde çerçeve yok")
		var well: PanelContainer = card.find_child("EvoWellBox", true, false) as PanelContainer
		assert(well != null and well.get_theme_stylebox("panel").get("bg_color") == HT.WIN_INSET, "ad + açıklama envanter kuyusunda")
		var body: Control = card.get_node("EvoBody")
		assert(body.get_combined_minimum_size().y <= card.size.y - 41.0, "içerik kartın içinde")
		assert((card.find_child("EvoKey", true, false) as Control).get("key") in ["Q", "E", "R"], "tuş kapağı dolu")
		assert((card.find_child("EvoIcon", true, false) as TextureRect).texture != null, "yetenek simgesi")
		for lbl in body.find_children("*", "Label", true, false):
			var fs: int = (lbl as Label).get_theme_font_size("font_size")
			## 24 yalnız yetenek adı satırında (eski efsun / envanter kartı gövdesi boyu, onaylı prototip)
			assert(fs in [16, 32, 48] or (fs == 24 and lbl.name == "EvoSkill"), "%s yazı boyu %d stil rehberinde yok" % [lbl.name, fs])
		top = minf(top, card.get_global_rect().position.y)
		bottom = maxf(bottom, card.get_global_rect().end.y)
	assert(tiers[2] == 4 and (cards[2].find_child("EvoTier", true, false) as Label).text == "FİNAL EVRİM", "R final evrim")
	assert((cards[0].find_child("EvoTier", true, false) as Label).text == "EVRİM 3/5", "Q 3/5")
	assert(top >= 140.0, "başlığın altında: %.0f" % top)
	print("kartlar y %.0f..%.0f (boy %.0f)" % [top, bottom, (cards[0] as Control).size.y])
	## Üstüne gelince ortasından %5 büyür, ayrılınca geri döner (ease-in-out 0,22 sn); renk / kenar değişmez.
	var c0: Button = cards[0]
	screen.call("_on_card_hover", c0, true)
	await get_tree().create_timer(0.35).timeout
	assert(c0.scale.is_equal_approx(Vector2.ONE * 1.05), "üstündeki kart %5 büyür: %s" % c0.scale)
	assert(c0.pivot_offset.is_equal_approx((c0.size * 0.5).round()), "kartın ortasından büyür")
	screen.call("_on_card_hover", c0, false)
	await get_tree().create_timer(0.35).timeout
	assert(c0.scale.is_equal_approx(Vector2.ONE), "ayrılınca eski boyuna döner: %s" % c0.scale)
	_close(pair)


## Bütün karakterlerin bütün evrimleri: kart + altındaki geri sayım 1080 ekrana sığar (açıklama 32 boyda kalır, küçültme yok).
func test_every_evolution_fits_on_screen() -> void:
	var pair: Array = await _open(OWNED)
	var screen: Node = pair[0]
	var cards: Array = screen.cards
	var all: Array = []
	for cid in SE.DEFS:
		for slot: String in SE.SLOTS:
			for e: Dictionary in SE.slot_list(int(cid), slot):
				var d: Dictionary = SE.find(str(e["id"]))
				d["char"] = int(cid)
				all.append(d)
	var worst: float = 0.0
	var worst_id: String = ""
	var i: int = 0
	while i < all.size():
		var batch: Array = all.slice(i, i + 3)
		for j in batch.size():
			var d: Dictionary = batch[j]
			GameManager.selected_char_id = int(d["char"])
			screen.call("_fill_evolution_card", cards[j], d, 4 if bool(d.get("final", false)) else 3, pair[1])
		await get_tree().process_frame
		await get_tree().process_frame
		for j in batch.size():
			var h: float = (cards[j].get_node("EvoBody") as Control).get_combined_minimum_size().y
			if h > worst:
				worst = h
				worst_id = str(batch[j]["id"])
		i += 3
	var card_h: float = worst + 2.0 * float(screen.get("EVO_BOX_PAD"))
	var end: float = float(screen.get("EVO_BOX_TOP")) + card_h + float(screen.get("EVO_COUNTDOWN_GAP")) + 74.0
	print("%d evrim, en uzun kart %s: %.0f px, geri sayım sonu y %.0f" % [all.size(), worst_id, card_h, end])
	assert(all.size() > 150, "evrim listesi okunmalı")
	assert(end <= 1080.0, "en uzun evrim kartı + geri sayım ekrana sığmalı: %.0f" % end)
	_close(pair)


## Seçim: hale/ölçek yok, seçilen kart altın kenarda, diğerleri söner, "evo:<id>" yayılır.
func test_pick_keeps_pixel_card_and_emits_choice() -> void:
	var pair: Array = await _open(OWNED)
	var screen: Node = pair[0]
	await _fixed_offer(screen)
	var got: Array = []
	screen.connect("upgrade_chosen", func(id: String, tier: int) -> void: got.append([id, tier]))
	var cards: Array = screen.cards
	(cards[1] as Button).pressed.emit()
	assert((cards[1] as Button).get_theme_stylebox("normal").get("border_color") != HT.ACCENT, "seçilen kartta altın kenar yok (madde 461)")
	await get_tree().create_timer(0.8).timeout
	assert(got.size() == 1 and str(got[0][0]) == "evo:matthew_e3", "seçim evo:<id> olarak yayılır: %s" % str(got))
	for i in cards.size():
		var c: Control = cards[i]
		var want_scale: Vector2 = Vector2.ONE * 1.05 if i == 1 else Vector2.ONE
		assert(c.scale.is_equal_approx(want_scale), "seçilen kart büyük kalır, diğerleri ölçeklenmez: %d %s" % [i, c.scale])
		assert(c.find_child("PickGlow", true, false) == null and c.find_child("HoverGlow", true, false) == null, "hale yok")
	assert((cards[0] as Control).modulate.a < 0.6, "seçilmeyen kart söner")
	_close(pair)
