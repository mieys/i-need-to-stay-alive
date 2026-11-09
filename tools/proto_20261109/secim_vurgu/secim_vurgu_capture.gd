extends SceneTree

## SEÇİM VURGUSU prototipleri (2026-11-09, madde 538; oyuna bağlı DEĞİL). Kullanıcı: "seçecekkenki dış çerçeveyi sevmiyorum onun yerine
## başka bişey olamaz mı". Gerçek karakter seçim ekranı açılır; kartlar yerinde yeniden stillenir (oyun koduna dokunmaz), ilk satır yakalanır.
## Durumlar: Oakley SEÇİLİ, Matthew ÜSTÜNDE (fare/odak), gerisi normal. Kart kenarı her seçenekte nötr (dış altın çerçeve yok).
##   SU_AN  bugünkü: seçili = altın kart kenarı, üstünde = altın odak halkası
##   A Büyüme      : üstündeki / seçili kart %5 büyür (evrim kartı gibi, madde 461), seçili portre halkası altın
##   B Halka Yanar : kart hiç değişmez; seçili portre halkası altın + ad altın, üstündeki halka açık ahşap
##   C Köşebentler : kartın dört köşesinde piksel köşebent (seçili altın, üstündeki açık ahşap)
##   D Ad Levhası  : seçili kartın adı altın levhada (koyu yazı, OYUNU BAŞLAT gibi), üstündekinin adı açık ahşap levhada
##   (ilk denenen "Yükselen Kart" koyu zeminde okunmadı -> yerine bu)
## Çıktı: BT_OUT/<ad>.png (ilk satır), birleştirme secim_vurgu_ozet.py.

const DK := preload("res://scripts/menu_dark_kit.gd")
const HT := preload("res://scripts/hud_theme.gd")

const SEL := 2 ## Oakley
var HOV_RING: Color = HT.RIM.lerp(HT.ACCENT, 0.5) ## üstündeki: ahşapla altın arası
const HOV := 3 ## Matthew
var _out: String = OS.get_environment("BT_OUT")


class Brackets extends Control:
	var col: Color = Color.WHITE
	var t: float = 3.0 ## 1 sanat px = 3 ekran px

	func _draw() -> void:
		var arm: float = 5.0 * t
		var w: float = size.x
		var h: float = size.y
		var ins: float = 2.0 * t ## kart kenarının içinde
		for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var x0: float = ins if c.x == 0 else w - ins - arm
			var y0: float = ins if c.y == 0 else h - ins - arm
			var hx: float = x0
			var vy: float = y0
			var hy: float = y0 if c.y == 0 else y0 + arm - t
			var vx: float = x0 if c.x == 0 else x0 + arm - t
			## koyu dış hat (1 px her yana) + renk
			draw_rect(Rect2(hx - 1, hy - 1, arm + 2, t + 2), HT.OUTLINE)
			draw_rect(Rect2(vx - 1, vy - 1, t + 2, arm + 2), HT.OUTLINE)
			draw_rect(Rect2(hx, hy, arm, t), col)
			draw_rect(Rect2(vx, vy, t, arm), col)


class Plate extends Control:
	var fill: Color = Color.WHITE

	func _draw() -> void:
		## 1 sanat px (3 px) koyu hat, köşe pikselleri kesik
		var r := Rect2(Vector2.ZERO, size)
		var t: float = 3.0
		draw_rect(Rect2(t, 0, size.x - 2 * t, size.y), HT.OUTLINE)
		draw_rect(Rect2(0, t, size.x, size.y - 2 * t), HT.OUTLINE)
		draw_rect(r.grow(-t), fill)
		draw_rect(Rect2(t, t, size.x - 2 * t, t), fill.lightened(0.18)) ## üst ışık
		draw_rect(Rect2(t, size.y - 2 * t, size.x - 2 * t, t), fill.darkened(0.18)) ## alt gölge


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(_out)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var desk: Object = current_scene.get("_desk")
	if desk == null:
		print("SV FAIL _desk yok")
		quit()
		return
	desk.call("show_character", SEL, false)
	await _wait(1.0)
	var cards: Dictionary = desk.get("_cards")
	if not cards.has(SEL) or not cards.has(HOV):
		print("SV FAIL kart yok")
		quit()
		return
	## İlk satırın dikdörtgeni (büyüme/kalkma payıyla)
	var row: Rect2 = Rect2()
	var first: bool = true
	for id in cards:
		var r: Rect2 = (cards[id]["btn"] as Button).get_global_rect()
		if absf(r.position.y - (cards[SEL]["btn"] as Button).get_global_rect().position.y) > 2.0:
			continue
		row = r if first else row.merge(r)
		first = false
	var shot := Rect2i(row.grow(14).position.floor(), row.grow(14).size.ceil())
	for v: String in ["SU_AN", "A", "B", "C", "D"]:
		_reset(cards)
		await process_frame
		_apply(v, cards)
		await _wait(0.4)
		if v == "D":
			_plates(cards)
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		## Pencere pikseli != tuval birimi (gizli masaüstünde içerik ölçeği): dikdörtgeni ölçekle, sonra tuval boyuna geri indir.
		var k: Vector2 = Vector2(img.get_size()) / root.get_visible_rect().size
		var px := Rect2i((Vector2(shot.position) * k).floor(), (Vector2(shot.size) * k).ceil())
		img = img.get_region(px.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		## Küçültülmez: gizli masaüstü 2560x1440 = kullanıcının ekranı (madde 508), görüntü birebir onun gördüğü.
		print("SV k=%s" % str(k))
		img.save_png(_out.path_join(v + ".png"))
		print("SV SHOT %s" % v)
	print("SV DONE")
	quit()


func _reset(cards: Dictionary) -> void:
	for id in cards:
		var b: Button = cards[id]["btn"]
		b.scale = Vector2.ONE
		for ch in b.get_children():
			if str(ch.name).begins_with("Proto"):
				ch.queue_free()
		b.release_focus()
		var face: Object = cards[id].get("face")
		if face:
			face.call("set_accent", Color(0, 0, 0, 0))
		var nl: Label = cards[id]["name"]
		if nl:
			nl.add_theme_color_override("font_color", DK.C_TEXT)


## Nötr kart: kenar hep C_LINE, odak halkası yok. sel = biraz açık dolgu (çerçeve değil).
func _neutral(b: Button, sel: bool, hov: bool) -> void:
	var fill: Color = DK.C_PANEL3 if sel else DK.C_PANEL2
	if hov and not sel:
		fill = DK.C_PANEL2.lightened(0.06)
	DK.style_button_colors(b, fill, DK.C_LINE, DK.C_TEXT, Color(0, 0, 0, 0), 2, 4, 6.0)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))


func _apply(v: String, cards: Dictionary) -> void:
	var sel_b: Button = cards[SEL]["btn"]
	var hov_b: Button = cards[HOV]["btn"]
	if v == "SU_AN":
		for id in cards:
			DK.style_button(cards[id]["btn"], "tile_on" if id == SEL else "tile", 4, 6.0)
		(cards[SEL]["face"] as Object).call("set_accent", DK.C_ACCENT)
		(cards[SEL]["name"] as Label).add_theme_color_override("font_color", DK.C_ACCENT)
		hov_b.add_theme_stylebox_override("normal", hov_b.get_theme_stylebox("hover"))
		hov_b.grab_focus()
		return
	for id in cards:
		_neutral(cards[id]["btn"], id == SEL, id == HOV)
	(cards[SEL]["face"] as Object).call("set_accent", DK.C_ACCENT)
	(cards[SEL]["name"] as Label).add_theme_color_override("font_color", DK.C_ACCENT)
	match v:
		"A":
			for b: Button in [sel_b, hov_b]:
				b.pivot_offset = b.size * 0.5
				b.scale = Vector2.ONE * 1.05
		"B":
			(cards[HOV]["face"] as Object).call("set_accent", HOV_RING)
		"C":
			for pair: Array in [[sel_b, DK.C_ACCENT], [hov_b, HOV_RING]]:
				var br := Brackets.new()
				br.name = "ProtoBrackets"
				br.col = pair[1]
				br.set_anchors_preset(Control.PRESET_FULL_RECT)
				br.mouse_filter = Control.MOUSE_FILTER_IGNORE
				(pair[0] as Button).add_child(br)


func _plates(cards: Dictionary) -> void:
	for pair: Array in [[SEL, DK.C_ACCENT, DK.C_ACCENT_TEXT], [HOV, HT.RIM_HI, DK.C_TEXT]]:
		var b: Button = cards[pair[0]]["btn"]
		var nl: Label = cards[pair[0]]["name"]
		var lr: Rect2 = nl.get_global_rect()
		var br: Rect2 = b.get_global_rect()
		var pl := Plate.new()
		pl.name = "ProtoPlate"
		pl.fill = pair[1]
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.position = Vector2(9, lr.position.y - br.position.y - 3).floor()
		pl.size = Vector2(br.size.x - 18, lr.size.y + 3).floor()
		b.add_child(pl)
		b.move_child(pl, 0)
		nl.add_theme_color_override("font_color", pair[2])
