extends SceneTree

## ARAYÜZ TAŞMA YOKLAMASI (2026-11-15, kullanıcı: "oyundaki arayüz sorunlarını ve buglarını araştırıp düzelt").
## Gerçek ekranları (ana menü + ayarlar / rekorlar / ruh mağazası / karakter seçimi; oyunda HUD, duraklatma, level kartı, evrim, pazar,
## sandık, envanter) her dilde açar ve görünür metin denetimlerinde dört hata sınıfını arar:
##   EKRAN   : metin ekran (1920x1080) dışına taşıyor
##   KUTU    : metin kırpan bir atanın (clip_contents) dışında kalıyor - görünmez / yarım
##   KIRPIK  : Label/Button metni kendi genişliğine sığmıyor ve "…" ya da clip ile kesiliyor
##   SATIR   : sarılan Label / RichTextLabel'da satırların bir kısmı görünmüyor
## Başsız çalışır (yerleşim hesaplanır, çizim yok). Koşturucu `run.ps1` (APPDATA yalıtılır). Çıktı satırları "TASMA ..." ile başlar.
## Ortam: TASMA_LANGS (tr,en,...; boş = hepsi), TASMA_SKIP_GAME=1 (yalnız menüler), TASMA_SKIP_MENU=1.

const VIEW := Vector2(1920.0, 1080.0)
const TOL := 2.0

var _gm: Node = null
var _loc: GDScript = null
var _main: Node = null
var _found: Dictionary = {} ## anahtar -> {screen, kind, path, px, langs, text}
var _lang: String = "tr"
var _screens_probed: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _wait(t: float) -> void:
	await create_timer(t, true).timeout


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	_loc = load("res://scripts/localization.gd")
	root.get_node("UISound").set("show_fps", false)
	_gm.set("debug_mode_unlocked", true)
	var langs: Array = _loc.call("codes")
	var env_l: String = OS.get_environment("TASMA_LANGS")
	if env_l != "":
		langs = Array(env_l.split(","))
	if OS.get_environment("TASMA_SKIP_MENU") == "":
		for l in langs:
			_set_lang(str(l))
			await _probe_menus()
	if OS.get_environment("TASMA_SKIP_GAME") == "":
		_set_lang("tr")
		if await _boot_main():
			for l in langs:
				_set_lang(str(l))
				await _probe_game()
		else:
			print("TASMA_HATA Main açılamadı")
	_report()
	quit(0)


func _set_lang(code: String) -> void:
	_lang = code
	_loc.call("apply", code)


# ------------------------------------------------------------------ menüler

func _probe_menus() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(2.0)
	var mm: Node = current_scene
	if mm == null:
		return
	_probe("ana_menu", mm)
	if mm.has_method("_on_settings_pressed"):
		mm.call("_on_settings_pressed")
		await _wait(1.0)
		var s: Node = mm.get("_settings_screen")
		if is_instance_valid(s):
			_probe("ayarlar", s)
			await _probe_tabs("ayarlar", s)
			s.queue_free()
			mm.call("_on_settings_closed")
		await _wait(0.2)
	if mm.has_method("_on_records_pressed"):
		mm.call("_on_records_pressed")
		await _wait(1.0)
		var r: Node = mm.get("_records_screen")
		if is_instance_valid(r):
			_probe("rekorlar", r)
			await _probe_tabs("rekorlar", r)
			r.queue_free()
			mm.call("_set_menu_parts_visible", true)
		await _wait(0.2)
	if mm.has_method("_on_soul_shop_pressed"):
		var before: Array = mm.get_children()
		mm.call("_on_soul_shop_pressed")
		await _wait(1.2)
		for c in mm.get_children():
			if not before.has(c):
				_probe("ruh_magazasi", c)
				c.queue_free()
		mm.call("_set_menu_parts_visible", true)
		await _wait(0.2)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.0)
	if current_scene != null:
		_probe("karakter_secimi", current_scene)


## Sekmeli ekranlarda (ayarlar / rekorlar: `_set_category` + `_cats`) her sekmeyi sırayla aç.
func _probe_tabs(screen: String, root_node: Node) -> void:
	if not root_node.has_method("_set_category"):
		return
	var cats: Variant = root_node.get("_cats")
	if not (cats is Array):
		return
	for cat in (cats as Array).slice(1):
		root_node.call("_set_category", int(cat), false)
		await _wait(0.5)
		_probe("%s_%d" % [screen, int(cat)], root_node)


# ------------------------------------------------------------------ oyun içi

func _boot_main() -> bool:
	var nm: Node = root.get_node("NetworkManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 2)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(2).get("skill", 1))
	_gm.set("selected_start_weapon", "uzunkilic")
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var sp: Node = _main.get_node_or_null("EnemySpawner")
	if sp:
		sp.set("_spawn_timer", 1.0e9)
	return true


func _new_children(before: Array) -> Array:
	var out: Array = []
	for c in _main.get_children():
		if not before.has(c) and is_instance_valid(c) and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _close(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	_main.set("_active_level_up_screen", null)
	_main.set("_active_enchant_screen", null)
	if _main.has_method("_exit_local_limbo"):
		_main.call("_exit_local_limbo")
	paused = false
	await _wait(0.3)


func _probe_game() -> void:
	var hud: Node = _main.get("hud")
	await _wait(0.6)
	if is_instance_valid(hud):
		_probe("hud", hud)
	## Level kartları
	var b: Array = _main.get_children()
	_main.call("_show_level_up_screen", 2)
	await _wait(1.4)
	for n in _new_children(b):
		_probe("level_kartlari", n)
	await _close(_new_children(b))
	## Evrim kartları
	b = _main.get_children()
	if _main.has_method("debug_open_evolution_screen") and bool(_main.call("debug_open_evolution_screen")):
		await _wait(1.4)
		for n in _new_children(b):
			_probe("evrim", n)
	await _close(_new_children(b))
	## Level pazarı
	_gm.set("gold", 5000)
	b = _main.get_children()
	if bool(_main.call("_try_open_level_market")):
		await _wait(1.4)
		for n in _new_children(b):
			_probe("level_pazari", n)
	await _close(_new_children(b))
	## Sandık (normal + elit): kartlar açılış animasyonundan sonra gelir
	for elite: bool in [false, true]:
		b = _main.get_children()
		_main.call("debug_open_chest", elite)
		await _wait(4.0)
		for n in _new_children(b):
			_probe("elit_sandik" if elite else "sandik", n)
		await _close(_new_children(b))
	## Duraklatma
	_main.call("_toggle_pause")
	await _wait(1.0)
	var pm: Node = _main.get("pause_menu_instance")
	if is_instance_valid(pm):
		_probe("duraklatma", pm)
	_main.call("_toggle_pause")
	await _wait(0.4)
	paused = false
	## Envanter
	if is_instance_valid(hud) and hud.has_method("_on_envanter_toggle"):
		hud.call("_on_envanter_toggle")
		await _wait(1.0)
		var inv: Node = hud.get("inventory_panel_instance")
		if is_instance_valid(inv):
			_probe("envanter", inv)
		hud.call("_on_envanter_toggle")
		await _wait(0.4)


# ------------------------------------------------------------------ denetim

func _probe(screen: String, n: Node) -> void:
	if not _screens_probed.has(screen):
		_screens_probed.append(screen)
	_walk(screen, n)


func _walk(screen: String, n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is Control:
		_check(screen, n as Control)
	for c in n.get_children():
		_walk(screen, c)


func _alpha(c: CanvasItem) -> float:
	var a: float = c.self_modulate.a
	var p: Node = c
	while p != null and p is CanvasItem:
		a *= (p as CanvasItem).modulate.a
		p = p.get_parent()
	return a


func _screen_rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform_with_canvas()
	return xf * Rect2(Vector2.ZERO, c.size)


func _shown_text(c: Control) -> String:
	var s: String = ""
	if c is Label:
		s = (c as Label).text
	elif c is Button:
		s = (c as Button).text
	elif c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	else:
		return ""
	if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		s = c.atr(s)
	if c is Label and (c as Label).uppercase:
		s = s.to_upper()
	return s


func _font_of(c: Control) -> Array:
	if c is Label and (c as Label).label_settings != null:
		var ls: LabelSettings = (c as Label).label_settings
		return [ls.font if ls.font != null else c.get_theme_font("font"), ls.font_size]
	return [c.get_theme_font("font"), c.get_theme_font_size("font_size")]


func _text_w(c: Control, s: String) -> float:
	var f: Array = _font_of(c)
	var font: Font = f[0]
	if font == null:
		return 0.0
	var w: float = 0.0
	for line in s.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(f[1])).x)
	return w


func _check(screen: String, c: Control) -> void:
	if c.size.x < 1.0 or c.size.y < 1.0:
		return
	if not (c is Label or c is Button or c is RichTextLabel):
		return
	var s: String = _shown_text(c)
	if s.strip_edges() == "" or _alpha(c) < 0.05:
		return
	var r: Rect2 = _screen_rect(c)
	## Kırpan ata: içerik bunun dışında görünmez. ScrollContainer içindekiler kaydırılır -> atla.
	var clip: Control = null
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return
		if p is Control and (p as Control).clip_contents and clip == null:
			clip = p as Control
		p = p.get_parent()
	_check_font(screen, c, s, r)
	_check_untranslated(screen, c, s)
	var vr := Rect2(Vector2.ZERO, VIEW)
	var out_px: float = _outside(r, vr)
	if out_px > TOL:
		_add(screen, "EKRAN", c, out_px, s)
	elif clip != null:
		var cp: float = _outside(r, _screen_rect(clip))
		if cp > TOL:
			_add(screen, "KUTU", c, cp, s)
	## Kendi genişliğine sığmama (yalnız kırpma/üç nokta açıksa görünür kayıp olur).
	var scale_x: float = r.size.x / c.size.x
	if c is Label:
		var l := c as Label
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				var over: float = _text_w(c, s) - c.size.x
				if over > TOL:
					_add(screen, "KIRPIK", c, over * scale_x, s)
		else:
			var lc: int = l.get_line_count()
			var vis: int = l.get_visible_line_count()
			if lc > vis and vis >= 0:
				_add(screen, "SATIR", c, float(lc - vis), s)
	elif c is Button:
		var bt := c as Button
		if bt.clip_text or bt.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			var sb: StyleBox = bt.get_theme_stylebox("normal")
			var pad: float = sb.get_minimum_size().x if sb else 0.0
			var icon_w: float = bt.icon.get_width() if bt.icon != null and not bt.expand_icon else 0.0
			var over2: float = _text_w(c, s) + pad + icon_w - c.size.x
			if over2 > TOL:
				_add(screen, "KIRPIK", c, over2 * scale_x, s)
	elif c is RichTextLabel:
		var rt := c as RichTextLabel
		if not rt.fit_content and not rt.scroll_active:
			var hidden: float = float(rt.get_content_height()) - c.size.y
			if hidden > TOL + 2.0:
				_add(screen, "SATIR", c, hidden * scale_x, s)


## BOY: stil rehberi (docs/stil_rehberi.md 2) - piksel fontlar yalnız yerel boyun tam katlarında keskin: m5x7 / monogram 16-32-48,
## PixeloidSans 9-18-27. Ekrandaki etkin boy = font boyu x tuval ölçeği (RootFitter 1920x1080'de 1).
func _check_font(screen: String, c: Control, s: String, r: Rect2) -> void:
	if c is RichTextLabel:
		return
	var f: Array = _font_of(c)
	var font: Font = f[0]
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	if font == null:
		return
	var fname: String = font.resource_path.get_file().to_lower()
	var eff: float = float(f[1]) * (r.size.y / c.size.y)
	var allowed: Array = []
	if fname.begins_with("m5x7") or fname.begins_with("monogram"):
		allowed = [16.0, 32.0, 48.0, 64.0]
	elif fname.begins_with("pixeloidsans"):
		allowed = [9.0, 18.0, 27.0, 36.0]
	else:
		return
	for a: float in allowed:
		if absf(eff - a) < 0.5:
			return
	_add(screen, "BOY", c, eff, "%s %d: %s" % [fname.get_basename(), roundi(eff), s])


## TR: seçili dil Türkçe değilken ekranda Türkçeye özgü harf (çevrilmemiş metin). İngilizcede tüm Türkçe harfler; diğer dillerde
## yalnız o dillerde olmayanlar (ğ ı ş İ). Çevrilmeyecek etiketler (oyuncu adı, sohbet) AUTO_TRANSLATE_MODE_DISABLED -> atla.
func _check_untranslated(screen: String, c: Control, s: String) -> void:
	if _lang == "tr" or c.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
		return
	var marks: String = "çğıöşüÇĞİÖŞÜ" if _lang == "en" else "ğışİĞŞ"
	for ch in marks:
		if s.contains(ch):
			_add(screen, "TR", c, 0.0, s)
			return


func _outside(r: Rect2, box: Rect2) -> float:
	var o: float = 0.0
	o = maxf(o, box.position.x - r.position.x)
	o = maxf(o, box.position.y - r.position.y)
	o = maxf(o, r.end.x - box.end.x)
	o = maxf(o, r.end.y - box.end.y)
	return o


func _norm_path(c: Node) -> String:
	var parts: Array = []
	var n: Node = c
	var depth: int = 0
	while n != null and n != root and depth < 7:
		var nm: String = str(n.name)
		if nm.begins_with("@"):
			nm = n.get_class()
		parts.push_front(nm)
		n = n.get_parent()
		depth += 1
	return "/".join(parts)


func _add(screen: String, kind: String, c: Control, px: float, text: String) -> void:
	var path: String = _norm_path(c)
	var key: String = "%s|%s|%s" % [screen.get_slice("_", 0), kind, path]
	var e: Dictionary = _found.get(key, {})
	if e.is_empty():
		e = {"screen": screen, "kind": kind, "path": path, "px": px, "langs": [], "text": text}
		_found[key] = e
	if not (e["langs"] as Array).has(_lang):
		(e["langs"] as Array).append(_lang)
	if px > float(e["px"]):
		e["px"] = px
		e["text"] = text


func _report() -> void:
	print("TASMA_EKRANLAR ", ",".join(_screens_probed))
	var keys: Array = _found.keys()
	var order: Array = ["EKRAN", "KUTU", "KIRPIK", "SATIR", "TR", "BOY"]
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ea: Dictionary = _found[a]
		var eb: Dictionary = _found[b]
		var ka: int = order.find(ea["kind"])
		var kb: int = order.find(eb["kind"])
		if ka != kb:
			return ka < kb
		return float(ea["px"]) > float(eb["px"]))
	for k in keys:
		var e: Dictionary = _found[k]
		var t: String = str(e["text"]).replace("\n", " / ").left(70)
		print("TASMA %s %s %.0f [%s] %s «%s»" % [e["kind"], e["screen"], float(e["px"]), ",".join(e["langs"]), e["path"], t])
	print("TASMA_SAYI ", _found.size())
