extends SceneTree

## TEK KUTU prototipi (2026-11-16, kullanıcı: "karakter seçim arayüzünde kutu içinde kutu var onun yerine tek kutu hale getirebilir miyiz?
## karakter ikonunun çerçevesi olsa yeter sadece kutu olarak, düzgün hizalayıp göster"). Gerçek character_select.tscn açılır; orta ızgaradaki
## karakter kartları + sağ sekme karoları BELLEKTE yeniden kurulur (oyun kodu DEĞİŞMEZ):
##   - dış kart / karo kutusu yok (düğme flat), tek kutu = portrenin Gömme Tepsi çerçevesi; ad çerçevenin altında, ortalı
##   - karakter: yüz 24 px x5 = 120 + 2x8 çerçeve = 136; 5 sütun x 136 + 4 x 12 = 728 = orta panelin iç genişliği (başlık / ayraçla aynı kenar)
##   - sağ karolar: 104 px çerçeve (silah açık ahşap kuyuda, _kind_slot gibi; ruhani / evcil kendi zemininde), sekmelerin sol kenarına hizalı
##   - seçili: çerçevenin orta halkası altın (set_accent) + çerçevenin DIŞINDA altın köşebentler + altın ad
## SS_OUT klasörüne evcil.png / silah.png (orta + sağ panel kırpıntısı) yazar; "OLC" satırları taşma ölçümü.

var _dk = null
var _ht = null
var _pf = null
var _pb = null
var _cb = null
var _desk: Node = null

## Yüz x4 = 96 (bugünkü boy) + 2x8 çerçeve = 112. x5 (136) + 32'lik adla en dolu karakterde (Matthew, 4 yetenek de 2 satır) orta panel
## 1047 > 1024 oluyordu (eski düzen 1019). 5 x 112 + 4 x 42 = 728 = orta panelin iç genişliği.
const FACE_PX := 96.0
const FRAME_T := 2.0
const CHAR_GAP := 42
const NAME_OVER := 12.0 ## ad etiketi çerçeveden iki yana 12 px taşabilir (en uzun ad 32'de < 136)
## Adlar büyüdü (kullanıcı: "isimleri biraz büyüt, çok ufak görünüyorlar"): karakter 24 -> 32, karo 16 -> 24. Etiketin üstünde yazı yüksekliğinin
## ~yarısı boş satır payı var -> NAME_GAP eksi: yazı alt köşebendin hemen altına oturur.
const CHAR_FS := 32
const TILE_FS := 24
const NAME_GAP := -6
const TILE_NAME_GAP := -4
const NAME_H := 32.0
const CHAR_VGAP := 16
const TILE_FRAME := 104.0
const TILE_GAP := 15 ## 5 x 104 + 4 x 15 = 580: sekme düğmelerinin sol kenarına hizalı, sağda kaydırma çubuğu payı 20 (madde 652)
const TILE_H := 124.0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	_dk = load("res://scripts/menu_dark_kit.gd")
	_ht = load("res://scripts/hud_theme.gd")
	_pf = load("res://scripts/portrait_face.gd")
	_pb = load("res://scripts/pet_badge.gd")
	_cb = load("res://scripts/corner_brackets.gd")
	var dir: String = OS.get_environment("SS_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	_desk = current_scene.get("_desk")
	await _measure("eski")
	_rebuild_chars()
	await _measure("yeni")
	_name_widths()
	var sel: int = int(_desk.get("_sel_char"))
	_desk.call("show_character", sel, false)
	_flatten_cards()
	for kind: String in ["pet", "weapon", "spirit"]:
		_rebuild_tab(kind)
		await _wait(0.4)
		var mid: Control = _mid_panel()
		print("OLC %s orta_min_h=%.0f orta_h=%.0f izgara=%s" % [kind, mid.get_combined_minimum_size().y, mid.size.y, str(_char_grid().size)])
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var s: float = img.get_width() / 1920.0
		img.get_region(Rect2i(int(488 * s), int(24 * s), int(1400 * s), int(1024 * s))).save_png(dir.path_join("%s.png" % kind))
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	print("BITTI")
	quit(0)


## Orta panelin en kötü (en uzun yetenek metinli) karakterdeki boyu: 1024'ü geçerse alt yetenek satırı kesilir.
func _measure(tag: String) -> void:
	var cards: Dictionary = _desk.get("_cards")
	var worst: float = 0.0
	var wid: int = 0
	for id in cards.keys():
		_desk.call("show_character", int(id), false)
		_flatten_cards()
		await process_frame
		await process_frame
		var m: float = _mid_panel().get_combined_minimum_size().y
		if m > worst:
			worst = m
			wid = int(id)
	var nl: Label = cards[cards.keys()[0]]["name"]
	print("OLC %s en_kotu=%.0f (id %d) izgara_h=%.0f ad_h=%.0f" % [tag, worst, wid, _char_grid().size.y, nl.size.y if nl else -1.0])


func _name_widths() -> void:
	for kind: String in ["weapon", "pet", "spirit"]:
		for key: String in _desk.call("_options", kind):
			var n: String = str(_desk.call("_opt_name", kind, key))
			var w: float = _dk.font().get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, TILE_FS).x
			if w > TILE_FRAME:
				print("OLC sigmayan %s '%s' %.0f" % [kind, n, w])
	var cards: Dictionary = _desk.get("_cards")
	for id in cards:
		var nl: Label = cards[id]["name"]
		var w2: float = _dk.font().get_string_size(nl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHAR_FS).x
		if w2 > 136.0:
			print("OLC sigmayan karakter '%s' %.0f" % [nl.text, w2])


func _char_grid() -> GridContainer:
	var cards: Dictionary = _desk.get("_cards")
	return (cards.values()[0]["btn"] as Control).get_parent() as GridContainer


func _mid_panel() -> Control:
	var n: Node = _char_grid()
	while n != null and not (n.get_parent() == _desk):
		n = n.get_parent()
	return n as Control


func _flat(b: Button) -> void:
	b.flat = true
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())


func _flatten_cards() -> void:
	var cards: Dictionary = _desk.get("_cards")
	for id in cards:
		_flat(cards[id]["btn"])


## Köşebentler çerçevenin DIŞINDA: kutu g kadar büyütülür, çizgi kutu kenarının 2t içinde -> iç kenar çerçeveden (g - 3t) dışarıda.
func _brackets(holder: Control, t: float) -> Control:
	var brk = _cb.new()
	brk.t = t
	var g: float = 3.0 * t + 2.0
	holder.add_child(brk)
	brk.offset_left = -g
	brk.offset_top = -g
	brk.offset_right = g
	brk.offset_bottom = g
	return brk


func _rebuild_chars() -> void:
	var cards: Dictionary = _desk.get("_cards")
	var grid: GridContainer = _char_grid()
	grid.add_theme_constant_override("h_separation", CHAR_GAP)
	grid.add_theme_constant_override("v_separation", CHAR_VGAP)
	for id in cards.keys():
		var old: Dictionary = cards[id]
		var ob: Button = old["btn"]
		var name_t: String = (old["name"] as Label).text if old["name"] != null else ""
		var b := Button.new()
		_flat(b)
		var v = _dk.v(NAME_GAP)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = -NAME_OVER
		v.offset_right = NAME_OVER
		v.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face: CenterContainer = _pf.framed_icon(int(id), FACE_PX, FRAME_T, false)
		v.add_child(face)
		var holder: Control = face.get_child(0)
		var nl = _dk.lbl(name_t, CHAR_FS, _dk.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(nl)
		b.add_child(v)
		b.custom_minimum_size = Vector2(face.custom_minimum_size.x, face.custom_minimum_size.y + NAME_GAP + NAME_H) ## ağaç dışında etiket boyu ölçülemiyor; _measure ağaçtaki boyu yazar
		if int(id) == 1:
			print("OLC ad_h=%.0f kart=%s" % [nl.get_combined_minimum_size().y, str(b.custom_minimum_size)])
		var brk: Control = _brackets(holder, 3.0)
		var marks = _dk.h(4)
		marks.position = Vector2(6, 6)
		b.add_child(marks)
		grid.add_child(b)
		grid.move_child(b, ob.get_index())
		grid.remove_child(ob)
		ob.queue_free()
		cards[id] = {"btn": b, "marks": marks, "name": nl, "locked": false, "face": holder, "brk": brk, "hov": false, "foc": false}


func _rebuild_tab(kind: String) -> void:
	_desk.call("_set_tab", kind)
	var tg: GridContainer = _desk.get("_tab_grid")
	tg.add_theme_constant_override("h_separation", TILE_GAP)
	for c in tg.get_children():
		tg.remove_child(c)
		c.queue_free()
	var cur: String = str(_desk.call("_current", kind))
	var inner: float = TILE_FRAME - 8.0 * FRAME_T
	for key: String in _desk.call("_options", kind):
		var on: bool = key == cur
		var b := Button.new()
		_flat(b)
		b.custom_minimum_size = Vector2(TILE_FRAME, TILE_H)
		var v = _dk.v(TILE_NAME_GAP)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = -float(TILE_GAP / 2)
		v.offset_right = float(TILE_GAP / 2)
		v.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fc: CenterContainer
		var icon: Texture2D = _desk.call("_opt_icon", kind, key)
		if kind == "pet" and _pb.has_background(key):
			fc = _pb.framed_icon(key, TILE_FRAME, FRAME_T)
		elif kind == "weapon":
			var well := ColorRect.new()
			well.color = _ht.ITEM_WELL
			well.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic = _dk.icon(_desk.call("_trimmed", icon), inner - 4.0)
			ic.set_anchors_preset(Control.PRESET_FULL_RECT)
			well.add_child(ic)
			fc = _pf.wrap_framed(well, Vector2(inner, inner), FRAME_T)
		else:
			var sp = _dk.icon(icon, inner)
			sp.custom_minimum_size = Vector2(inner, inner)
			fc = _pf.wrap_framed(sp, Vector2(inner, inner), FRAME_T)
		v.add_child(fc)
		var holder: Control = fc.get_child(0)
		if on:
			holder.call("set_accent", _dk.C_ACCENT)
			_brackets(holder, 2.0).call("set_color", _dk.C_ACCENT)
		var nm: String = str(_desk.call("_opt_name", kind, key))
		## 24'te sütuna (çerçeve + aralık) sığmayan uzun ad 16'ya düşer (karakter kartındaki _fs_lab / _fs_small kalıbı)
		var l = _dk.lbl(nm, TILE_FS, _dk.C_ACCENT if on else _dk.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(l)
		b.add_child(v)
		tg.add_child(b)
		## Ağaçtaki gerçek tema fontuyla yeniden ölç (DK.font() ölçümü kısa kalıyordu: "Butterfly Spirit" kırpılıyordu).
		## Sütun adımı 104 + 15 = 119; yazı ortalı olduğundan 125'e kadar komşu adla çakışmaz (yan yana iki uzun ad nadir) -> kırpma yok.
		var lw: float = TILE_FRAME + float(TILE_GAP) + 6.0
		## Etiket metni ekranda ÇEVRİLİR (kaynak Türkçe): ölçüm çevrilmiş adla.
		var shown: String = l.atr(nm)
		var real_w: float = l.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, TILE_FS).x
		l.clip_text = real_w > lw
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if real_w > lw else TextServer.OVERRUN_NO_TRIMMING
		if real_w > lw:
			l.add_theme_font_size_override("font_size", _dk.FS_SMALL)
		if real_w > lw:
			print("OLC karo 16'ya dustu '%s' %.0f > %.0f" % [shown, real_w, lw])
