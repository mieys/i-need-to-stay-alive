extends CanvasLayer

## RUH MAĞAZASI (kullanıcı isteği 2026-10-13, bkz. meta_progress.gd): koşularda kazanılan Ruh Kıymığı ile kilitli karakter / başlangıç silahı /
## evcil hayvan / ruhani yetenek açılır + kalıcı GELİŞTİRMELER (meta_upgrades.gd). Ana menüdeki "RUH MAĞAZASI" düğmesi açar.
## Yanlışlıkla harcamaya karşı iki adım: ilk basış "ONAYLA?" yapar, ikinci basış satın alır (başka bir şeye basınca ilk adım geri alınır).
##
## TASARIM "F" (2026-10-16, prototip tools/proto_20261016/ruh_magaza_proto.gd, not madde 173): herkes AYNI yerleşimi görür (eski 4 yerleşim +
## "Görünüm" çipleri kalktı, eski dosya tools/proto_20261016/yedek/). Tam ekran, koyu ahşap/kehribar palet, arka plan oyunun iç mekan sanatından
## kurulmuş gece dükkanı (assets/ui/ruh_magaza/bg_ruh_magaza.png, üretici tools/gen_ruh_magaza_bg.py - meşaleler başlığın iki yanındaki boşluklara
## göre konumlu: üst şerit yerleşimi değişirse arka plan da yeniden üretilmeli).
##   ANA SAYFA: solda "ŞİMDİ ALABİLİRSİN" kartı (+ sıradaki hedef), sağda 4 kategori kutusu + geniş Geliştirmeler kutusu; kutuya basınca sayfası açılır.
##   KATEGORİ SAYFASI ("kahraman seçimi"): üstte büyük sahne (spot ışığı + halkalı zemin) + bilgi paneli, altta çerçeveli kart dizisi.
##   GELİŞTİRMELER: iki sütun satır (ikon, şu an -> sonraki, seviye çubuğu, fiyat düğmesi), başlıkta toplam + HEPSİNİ SIFIRLA (iki adımlı).
## Yetenek önizlemeleri (karaktere basınca Q/E/R oynar) SONRAYA bırakıldı: canlı değil, oyunun motorunda kayıt olacak (madde 173 sonu).

signal closed

const UiAnim := preload("res://scripts/ui_anim.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const MetaUpgradesScript: GDScript = preload("res://scripts/meta_upgrades.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const StatIconScript: GDScript = preload("res://scripts/stat_icon.gd")
const BG_TEXTURE := "res://assets/ui/ruh_magaza/bg_ruh_magaza.png"

const PAGE_HOME := "home"
const PAGE_UPGRADES := "upgrades"
const TAB_UNLOCKS := "unlocks" ## eski API (testler/çağıranlar): ana sayfa demek
const TAB_UPGRADES := "upgrades"

## Koyu ahşap + fener: göz yormayan koyu kahve zemin, kehribar vurgu, krem yazı.
const C_PANEL := Color("#241c16")
const C_PANEL2 := Color("#2e251d")
const C_PANEL3 := Color("#3b2f24")
const C_INSET := Color("#1a140f")
const C_LINE := Color("#45372a")
const C_LINE_HI := Color("#6a5440")
const C_TEXT := Color("#efe2c6")
const C_DIM := Color("#ad9b80")
const C_ACCENT := Color("#e2a64e")
const C_ACCENT_DK := Color("#6a4416")
const C_ACCENT_TEXT := Color("#24160a")
const C_GOOD := Color("#a9c96e")
const C_BAD := Color("#dc7f60")
const C_PRICE := Color("#f2c674")
const C_SPOT := Color("#c0803a")

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const G_HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const G_PCT := ["##...#", "##..#.", "...#..", "..#...", ".#..##", "#...##"]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_ARROW := ["..#..", "...#.", "#####", "...#.", "..#.."]
const G_LEFT := ["..#", ".##", "###", ".##", "..#"]
const G_RIGHT := ["#..", "##.", "###", "##.", "#.."]

const KIND_NAMES := {"char": "KARAKTERLER", "weapon": "SİLAHLAR", "pet": "EVCİL HAYVANLAR", "spirit": "RUHANİ YETENEKLER"}
const KIND_TILE := {"char": "Karakterler", "weapon": "Silahlar", "pet": "Evcil Hayvanlar", "spirit": "Ruhani Yetenekler"}
const KIND_ONE := {"char": "KARAKTER", "weapon": "BAŞLANGIÇ SİLAHI", "pet": "EVCİL HAYVAN", "spirit": "RUHANİ YETENEK"}

const STAGE_FLOOR := 92.0 ## sahne zemin halkasının alttan uzaklığı (figürün ayağı buraya basar)

var _close_btn: Button = null
var _balance_label: Label = null
var _list: Container = null ## sadece GELİŞTİRMELER sayfasında dolu (20 satır)
var _scroll: ScrollContainer = null
var _page_box: VBoxContainer = null
var _confirm_id: String = "" ## "<tür>:<anahtar>" - onay bekleyen alım ("reset" = geliştirmeleri sıfırla)
var _page: String = PAGE_HOME
var _sel: Dictionary = {} ## tür -> seçili anahtar (kategori sayfası)
var _body_cache: Dictionary = {}


## ---------------------------------------------------------------- çizim sınıfları (sanat dosyası yok)
## Pikselli "Ruh Kıymığı" kristali.
class ShardIcon extends Control:
	var dim: bool = false

	func _init(px: float = 24.0, dimmed: bool = false) -> void:
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim = dimmed

	func _draw() -> void:
		var s: float = size.x
		var c: float = s * 0.5
		var top := Vector2(c, s * 0.04)
		var mid_y: float = s * 0.38
		var l := Vector2(s * 0.12, mid_y)
		var r := Vector2(s * 0.88, mid_y)
		var bot := Vector2(c, s * 0.96)
		var m := Vector2(c, mid_y)
		var k: float = 0.5 if dim else 1.0
		var t := Color(k, k, k, 1)
		draw_colored_polygon(PackedVector2Array([top, m, l]), Color("#b4f1f5") * t)
		draw_colored_polygon(PackedVector2Array([top, r, m]), Color("#73d2dc") * t)
		draw_colored_polygon(PackedVector2Array([l, m, bot]), Color("#3f9fb0") * t)
		draw_colored_polygon(PackedVector2Array([m, r, bot]), Color("#27707f") * t)
		draw_polyline(PackedVector2Array([top, r, bot, l, top]), Color("#0b1418"), maxf(2.0, roundf(s / 12.0)))


## Satır desenli küçük piksel simge ("#" dolu).
class Glyph extends Control:
	var rows: Array = []
	var col: Color = Color.WHITE
	var px: int = 3

	func _init(pattern: Array, c: Color, pixel: int = 3) -> void:
		rows = pattern
		col = c
		px = pixel
		custom_minimum_size = Vector2(str(rows[0]).length() * px, rows.size() * px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(off + Vector2(x * px, y * px), Vector2(px, px)), col)


class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(f: float, fc: Color, bc: Color, h: float = 10.0, w: float = 0.0) -> void:
		frac = clampf(f, 0.0, 1.0)
		fill = fc
		back = bc
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		var fw: float = floorf((size.x - 6.0) * frac)
		if fw > 0.0:
			draw_rect(Rect2(3, 3, fw, size.y - 6), fill)
			draw_rect(Rect2(3, 3, fw, 3), fill.lightened(0.3))


## Seviye kutucukları (geliştirmeler).
class Pips extends Control:
	var n: int = 10
	var on: int = 0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(count: int, filled: int, fc: Color, bc: Color, h: float = 10.0) -> void:
		n = maxi(1, count)
		on = filled
		fill = fc
		back = bc
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gap: float = 3.0 if n > 10 else 4.0
		var seg: float = floorf((size.x - gap * (n - 1)) / n)
		var x: float = 0.0
		for i in n:
			draw_rect(Rect2(x, 0, seg, size.y), fill if i < on else back)
			if i < on:
				draw_rect(Rect2(x, 0, seg, 3), fill.lightened(0.3))
			x += seg + gap


## Sahne zemini: tepeden inen spot ışığı konisi + halkalı zemin elipsi (arkadan ışık YOK - kullanıcı isteği 2026-10-16).
class StageBg extends Control:
	var col: Color = Color.WHITE
	var ring: Color = Color.WHITE
	var floor_off: float = 92.0

	func _init(c: Color, r: Color, fo: float = 92.0) -> void:
		col = c
		ring = r
		floor_off = fo
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var cx: float = floorf(w * 0.5)
		var fy: float = floorf(h - floor_off)
		var tw: float = w * 0.05
		var bw: float = w * 0.24
		draw_colored_polygon(PackedVector2Array([Vector2(cx - tw, 0), Vector2(cx + tw, 0), Vector2(cx + bw, fy), Vector2(cx - bw, fy)]), Color(col, 0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - tw * 0.5, 0), Vector2(cx + tw * 0.5, 0), Vector2(cx + bw * 0.6, fy), Vector2(cx - bw * 0.6, fy)]), Color(col, 0.05))
		for k: Array in [[1.25, 0.16], [0.95, 0.16], [0.65, 0.14]]:
			var rx: float = bw * float(k[0])
			var pts := PackedVector2Array()
			for a in 49:
				var t: float = TAU * float(a) / 48.0
				pts.append(Vector2(cx + cos(t) * rx, fy + sin(t) * rx * 0.2))
			draw_colored_polygon(pts, Color(col, float(k[1])))
		var ring_pts := PackedVector2Array()
		for a in 65:
			var t: float = TAU * float(a) / 64.0
			ring_pts.append(Vector2(cx + cos(t) * bw * 1.25, fy + sin(t) * bw * 1.25 * 0.2).floor())
		draw_polyline(ring_pts, Color(ring, 0.55), 3.0)


## Pikselli köşe süsü (L köşeler + üst ortada küçük elmas).
class CornerFrame extends Control:
	var col: Color = Color.WHITE
	var ln: float = 22.0
	var ins: float = 8.0
	var gem: bool = true

	func _init(c: Color, length: float = 22.0, inset: float = 8.0, with_gem: bool = true) -> void:
		col = c
		ln = length
		ins = inset
		gem = with_gem
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var i: float = ins
		var t: float = 3.0
		for c: Vector2 in [Vector2(i, i), Vector2(w - i - ln, i), Vector2(i, h - i - t), Vector2(w - i - ln, h - i - t)]:
			draw_rect(Rect2(c, Vector2(ln, t)), col)
		for c: Vector2 in [Vector2(i, i), Vector2(w - i - t, i), Vector2(i, h - i - ln), Vector2(w - i - t, h - i - ln)]:
			draw_rect(Rect2(c, Vector2(t, ln)), col)
		if gem:
			var g := Vector2(floorf(w * 0.5), i + 1.0)
			draw_colored_polygon(PackedVector2Array([g + Vector2(0, -6), g + Vector2(6, 0), g + Vector2(0, 6), g + Vector2(-6, 0)]), col)


## Kart zemini: yukarıdan aşağı basamaklı koyulaşan dolgu + ikon arkasında ışık lekesi.
class CardBg extends Control:
	var top: Color = Color.WHITE
	var bottom: Color = Color.BLACK
	var glow: Color = Color.WHITE

	func _init(t: Color, b: Color, g: Color) -> void:
		top = t
		bottom = b
		glow = g
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = 6
		var bh: float = ceilf(size.y / n)
		for i in n:
			draw_rect(Rect2(0, i * bh, size.x, bh), top.lerp(bottom, float(i) / float(n - 1)))
		var c := Vector2(floorf(size.x * 0.5), floorf(size.y * 0.38))
		for i in 3:
			draw_circle(c, floorf(size.x * (0.42 - i * 0.1)), Color(glow, 0.07 + i * 0.04))


## ---------------------------------------------------------------- yaşam döngüsü
func _ready() -> void:
	add_to_group(&"gamepad_modal")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_ui()
	if _close_btn:
		_close_btn.grab_focus()
	UiAnim.window_in(self)


func _build_ui() -> void:
	if MobileUIScript.enabled:
		_build_phone()
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP ## alttaki ana menüye tıklama geçmesin
	add_child(root)
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE) as Texture2D if ResourceLoader.exists(BG_TEXTURE) else null
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	if bg.texture == null:
		var fallback := ColorRect.new()
		fallback.color = Color("#1a140f")
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(fallback)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: Array in [["margin_left", 32], ["margin_top", 20], ["margin_right", 32], ["margin_bottom", 28]]:
		m.add_theme_constant_override(side[0], side[1])
	root.add_child(m)
	_page_box = _v(16)
	m.add_child(_page_box)
	_rebuild_list(true)


## Sayfayı baştan kurar (sayfa / seçim / satın alma / onay değişince). Kaydırma konumu ve odaktaki düğme korunur.
func _rebuild_list(reset_scroll: bool = false) -> void:
	if _phone:
		_ph_rebuild()
		return
	var keep: int = 0
	if not reset_scroll and is_instance_valid(_scroll):
		keep = _scroll.scroll_vertical
	var focus_sid: String = ""
	var fo: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if fo != null and fo.has_meta("sid"):
		focus_sid = str(fo.get_meta("sid"))
	_scroll = null
	_list = null
	for c in _page_box.get_children():
		_page_box.remove_child(c)
		c.queue_free()
	match _page:
		PAGE_HOME:
			_build_home()
		PAGE_UPGRADES:
			_build_upgrades()
		_:
			_build_kind_page(_page)
	UISound.connect_all_buttons(self)
	_restore_view.call_deferred(keep, focus_sid)


func _restore_view(scroll_v: int, focus_sid: String) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = scroll_v
	if focus_sid != "":
		for b: Node in find_children("*", "Button", true, false):
			if b.has_meta("sid") and str(b.get_meta("sid")) == focus_sid and not (b as Button).disabled:
				(b as Button).grab_focus()
				return
	if is_instance_valid(_close_btn) and is_inside_tree():
		_close_btn.grab_focus()


## Eski API: "unlocks"/"home" = ana sayfa, "upgrades" = geliştirmeler, tür adı ("char"/"weapon"/"pet"/"spirit") = o kategori.
func _on_tab_pressed(tab: String) -> void:
	var page: String = PAGE_HOME if tab == TAB_UNLOCKS else tab
	if page == _page:
		return
	_page = page
	_confirm_id = ""
	_rebuild_list(true)


func _go_home() -> void:
	_on_tab_pressed(PAGE_HOME)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _phone: ## telefonda ana sayfa yok: geri = kapat
			_on_close_pressed()
		elif _page != PAGE_HOME:
			_go_home()
		else:
			_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


## ---------------------------------------------------------------- VERİ
## Satır bilgisi: {"name", "desc", "icon"} - her tür kendi kataloğundan.
func _info(kind: String, key: Variant) -> Dictionary:
	match kind:
		MetaProgressScript.CHAR:
			var def: Dictionary = Characters.get_def(int(key))
			var skills: Array = []
			for pair: Array in [["skill_name", "Q"], ["skill2_name", "E"], ["skill3_name", "R"]]:
				var sn: String = str(def.get(pair[0], ""))
				if sn != "":
					skills.append("%s: %s" % [pair[1], sn])
			return {"name": str(def.get("name", key)), "desc": "  ".join(skills),
					"icon": LobbyUI.face_texture(str(def.get("portrait", "")))}
		MetaProgressScript.WEAPON:
			var wk: String = str(key)
			return {"name": WeaponCatalog.display_name(wk), "desc": "%s - %s" % [WeaponCatalog.category_label(wk), WeaponCatalog.trait_text(wk)],
					"icon": WeaponCatalog.icon(wk)}
		MetaProgressScript.PET:
			var pk: String = str(key)
			return {"name": PetCatalog.display_name(pk), "desc": PetCatalog.description(pk), "icon": PetCatalog.icon(pk)}
		MetaProgressScript.SPIRIT:
			var sd: Dictionary = SpiritualSkillsScript.get_def(str(key))
			var tex_path: String = str(sd.get("icon", ""))
			return {"name": str(sd.get("name", key)), "desc": str(sd.get("desc", "")),
					"icon": load(tex_path) as Texture2D if tex_path != "" and ResourceLoader.exists(tex_path) else null}
	return {"name": str(key)}


## Tüm kilitli/açık katalog öğeleri (tür sırası, ucuzdan pahalıya).
func _items() -> Array:
	var out: Array = []
	for it: Dictionary in MetaProgressScript.locked_items():
		var info: Dictionary = _info(it["kind"], it["key"])
		out.append({"kind": it["kind"], "key": it["key"], "cost": int(it["cost"]), "name": str(info.get("name", it["key"])),
				"desc": str(info.get("desc", "")), "icon": info.get("icon", null),
				"open": MetaProgressScript.is_unlocked(it["kind"], it["key"]), "can": MetaProgressScript.can_buy(it["kind"], it["key"])})
	return out


## Bir türün öğeleri: alınabilir -> alınamayan (ucuzdan pahalıya) -> açık olanlar.
func _of_kind(items: Array, kind: String) -> Array:
	var a: Array = items.filter(func(i: Dictionary) -> bool: return i["kind"] == kind)
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var gx: int = _group(x)
		var gy: int = _group(y)
		if gx != gy:
			return gx < gy
		return int(x["cost"]) < int(y["cost"]))
	return a


func _group(it: Dictionary) -> int:
	return 2 if it["open"] else (0 if it["can"] else 1)


func _id(it: Dictionary) -> String:
	return "%s:%s" % [str(it["kind"]), str(it["key"])]


func _state(it: Dictionary) -> String:
	return "open" if it["open"] else ("can" if it["can"] else "no")


func _need(it: Dictionary) -> int:
	return maxi(0, int(it["cost"]) - MetaProgressScript.shards())


func _open_count(items: Array) -> int:
	var n: int = 0
	for i: Dictionary in items:
		if i["open"]:
			n += 1
	return n


## Satın alınamayan en ucuz öğe (biriktirme hedefi).
func _goal(items: Array) -> Dictionary:
	var best: Dictionary = {}
	for i: Dictionary in items:
		if _state(i) == "no" and (best.is_empty() or int(i["cost"]) < int(best["cost"])):
			best = i
	return best


## Ana sayfanın önerisi: alınabilir en ucuz karakter, yoksa alınabilir en ucuz herhangi bir öğe.
func _featured(items: Array) -> Dictionary:
	for kind: String in MetaProgressScript.KINDS:
		for i: Dictionary in _of_kind(items, kind):
			if _state(i) == "can":
				return i
	return {}


func _selected(items: Array, kind: String) -> Dictionary:
	var list: Array = _of_kind(items, kind)
	if list.is_empty():
		return {}
	if _sel.has(kind):
		for i: Dictionary in list:
			if str(i["key"]) == str(_sel[kind]):
				return i
	return list[0]


func _select(it: Dictionary) -> void:
	_sel[str(it["kind"])] = it["key"]
	_confirm_id = ""
	_rebuild_list()


func _step_selection(kind: String, dir: int) -> void:
	var list: Array = _of_kind(_items(), kind)
	if list.is_empty():
		return
	var cur: Dictionary = _selected(_items(), kind)
	var idx: int = 0
	for i in list.size():
		if str(list[i]["key"]) == str(cur.get("key", "")):
			idx = i
	_select(list[posmod(idx + dir, list.size())])


func _on_buy_pressed(kind: String, key: Variant) -> void:
	var id: String = "%s:%s" % [kind, str(key)]
	if _confirm_id != id:
		_confirm_id = id
		_rebuild_list()
		return
	_confirm_id = ""
	MetaProgressScript.buy(kind, key)
	_rebuild_list()


func _on_upgrade_pressed(id: String) -> void:
	_confirm_id = ""
	MetaUpgradesScript.buy(id)
	_rebuild_list()


func _on_reset_pressed() -> void:
	if _confirm_id != "reset":
		_confirm_id = "reset"
		_rebuild_list()
		return
	_confirm_id = ""
	MetaUpgradesScript.reset_all()
	_rebuild_list()


func _char_def(it: Dictionary) -> Dictionary:
	return Characters.get_def(int(it["key"]))


## Karakterin tam boy bekleme karesi (kırpılmış).
func _char_body(it: Dictionary) -> Texture2D:
	var key: int = int(it["key"])
	if _body_cache.has(key):
		return _body_cache[key]
	var tex: Texture2D = it["icon"]
	var sf: SpriteFrames = load(str(_char_def(it).get("frames", ""))) as SpriteFrames
	if sf != null and sf.has_animation("idle_down") and sf.get_frame_count("idle_down") > 0:
		var img: Image = sf.get_frame_texture("idle_down", 0).get_image()
		if img != null:
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 0:
				tex = ImageTexture.create_from_image(img.get_region(used))
	_body_cache[key] = tex
	return tex


func _stat_tex(key: String) -> Texture2D:
	var f: String = str(StatIconScript.ICON_PATHS.get(key, ""))
	if f != "" and ResourceLoader.exists(StatIconScript.ICON_DIR + f):
		return load(StatIconScript.ICON_DIR + f) as Texture2D
	return null


## ---------------------------------------------------------------- UI yardımcıları
func _sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, r: int = 6, pad: float = -1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.corner_detail = 1 ## 45 derece pah: pikselli köşe
	s.anti_aliasing = false
	if pad >= 0.0:
		s.set_content_margin_all(pad)
	return s


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = MenuKit.font()
	th.default_font_size = 32
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	th.set_constant("shadow_offset_x", "Label", 0)
	th.set_constant("shadow_offset_y", "Label", 3)
	for sb_name: String in ["scroll"]:
		var track := _sb(C_INSET, Color(0, 0, 0, 0), 0, 3)
		track.content_margin_left = 5
		track.content_margin_right = 5
		track.content_margin_top = 5
		track.content_margin_bottom = 5
		th.set_stylebox(sb_name, "VScrollBar", track)
		th.set_stylebox(sb_name, "HScrollBar", track)
	for st: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(st, "VScrollBar", _sb(C_LINE_HI, Color(0, 0, 0, 0), 0, 3))
		th.set_stylebox(st, "HScrollBar", _sb(C_LINE_HI, Color(0, 0, 0, 0), 0, 3))
	return th


func _lbl(t: String, fs: int = 32, c: Color = C_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(t: String, fs: int, c: Color, w: float, max_lines: int = 0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := _lbl(t, fs, c, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	if max_lines > 0:
		l.max_lines_visible = max_lines
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _box(fill: Color, border: Color = Color(0, 0, 0, 0), pad: float = 16.0, bw: int = 3, r: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(fill, border, bw, r, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _h(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _v(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _sp(w: float = 0.0, h: float = 0.0, ex: bool = false, ey: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ex:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ey:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _hline() -> ColorRect:
	var r := ColorRect.new()
	r.color = C_LINE
	r.custom_minimum_size = Vector2(0, 3)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _tag_sid(b: Control, sid: String) -> void:
	b.set_meta("sid", sid)


## Tam katlı büyütme (piksel bozulmasın); kutudan büyükse küçültür.
func _icon(tex: Texture2D, box: float, dim: bool = false) -> Control:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, box)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var ts: Vector2 = tex.get_size()
	var big: float = maxf(ts.x, ts.y)
	var k: float = floorf(box / big)
	if k < 1.0:
		k = box / big
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = (ts * k).floor()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		tr.modulate = Color(0.52, 0.52, 0.58, 1.0)
	cc.add_child(tr)
	return cc


func _upg_icon(d: Dictionary, box: float) -> Control:
	var tex: Texture2D = _stat_tex(str(d.get("icon", "")))
	if tex != null:
		return _icon(tex, box)
	## ikonu olmayan geliştirmeler (fiyat indirimi / ücretsiz karıştırma / dirilme hakkı): kodla çizilen simge
	var pat: Array = {"discount": G_PCT, "free_reroll": G_REROLL, "revive": G_HEART}.get(str(d.get("id", "")), G_PCT)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, box)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(Glyph.new(pat, Color("#ef6f7a") if str(d.get("id", "")) == "revive" else C_PRICE, maxi(2, int(box / 12.0))))
	return cc


## Fiyat / durum satırı: kristal + sayı (yetmiyorsa kırmızımsı), ya da onay + AÇIK.
func _price(it: Dictionary, fs: int = 32) -> HBoxContainer:
	var h := _h(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	match _state(it):
		"open":
			h.add_child(Glyph.new(G_CHECK, C_GOOD, 3 if fs < 32 else 4))
			h.add_child(_lbl("AÇIK", fs, C_GOOD))
		"can":
			h.add_child(ShardIcon.new(fs * 0.75))
			h.add_child(_lbl(str(it["cost"]), fs, C_PRICE))
		_:
			h.add_child(ShardIcon.new(fs * 0.75, true))
			h.add_child(_lbl(str(it["cost"]), fs, C_BAD))
	return h


func _btn_style(b: Button, kind: String) -> void:
	var fill: Color = C_ACCENT
	var bd: Color = C_ACCENT_DK
	var tc: Color = C_ACCENT_TEXT
	match kind:
		"ghost":
			fill = C_PANEL2
			bd = C_LINE_HI
			tc = C_TEXT
		"off":
			fill = C_INSET
			bd = C_LINE
			tc = C_DIM
		"confirm":
			fill = C_GOOD
			bd = C_GOOD.darkened(0.55)
			tc = Color("#10200c")
		"danger":
			fill = C_BAD
			bd = C_BAD.darkened(0.55)
			tc = Color("#200c08")
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var f: Color = fill.lightened(0.08) if st == "hover" else fill
		var sb := _sb(f, bd, 3, 6, 10.0)
		if st == "focus":
			sb = _sb(Color(0, 0, 0, 0), C_TEXT, 3, 6, 10.0)
		b.add_theme_stylebox_override(st, sb)
	for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(fc, tc)


func _btn(t: String, kind: String = "primary", fs: int = 32, h: float = 60.0, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", fs)
	_btn_style(b, kind)
	return b


## İçinde [ÖNEK] <kristal> 250 yazan düğme.
func _price_btn(prefix: String, cost: int, kind: String = "primary", fs: int = 32, h: float = 64.0, w: float = 0.0) -> Button:
	var b := _btn("", kind, fs, h, w)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _h(10)
	var tc: Color = C_BAD if kind == "off" else C_ACCENT_TEXT
	var shadow: float = 0.45 if kind == "off" else 0.0
	if prefix != "":
		var pl := _lbl(prefix, fs, C_DIM if kind == "off" else C_ACCENT_TEXT)
		pl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, shadow))
		row.add_child(pl)
	row.add_child(ShardIcon.new(fs * 0.75, kind == "off"))
	var cl := _lbl(str(cost), fs, tc)
	cl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, shadow))
	row.add_child(cl)
	cc.add_child(row)
	b.add_child(cc)
	return b


## Satın alma düğmesi: açık = pasif "SENDE", alınabilir = "AÇ <fiyat>" (ikinci basışta "ONAYLA?"), yetmiyor = pasif kırmızı fiyat.
func _buy_btn(it: Dictionary, fs: int = 32, h: float = 72.0, sid: String = "buy") -> Button:
	var b: Button
	match _state(it):
		"open":
			b = _btn("SENDE", "off", fs, h)
			b.disabled = true
		"can":
			if _confirm_id == _id(it):
				b = _btn("ONAYLA?", "confirm", fs, h)
			else:
				b = _price_btn("AÇ", int(it["cost"]), "primary", fs, h)
			b.pressed.connect(_on_buy_pressed.bind(str(it["kind"]), it["key"]))
		_:
			b = _price_btn("AÇ", int(it["cost"]), "off", fs, h)
			b.disabled = true
	_tag_sid(b, sid)
	return b


## Kutuyu tıklanabilir yapar: şeffaf düğme katmanı (üzerine gelince hafif parlar, gamepad odağında açık çerçeve).
func _clickable(p: Control, cb: Callable, sid: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var hv := StyleBoxFlat.new()
	hv.bg_color = Color(1.0, 0.9, 0.7, 0.06)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), C_TEXT, 3, 6))
	b.pressed.connect(cb)
	_tag_sid(b, sid)
	p.add_child(b)
	return b


func _balance_chip() -> PanelContainer:
	var p := _box(C_INSET, C_LINE_HI, 12)
	var h := _h(12)
	h.add_child(ShardIcon.new(32))
	var v := _v(-6)
	v.add_child(_lbl("Ruh Kıymığı", 24, C_DIM))
	_balance_label = _lbl(str(MetaProgressScript.shards()), 32, C_PRICE)
	v.add_child(_balance_label)
	h.add_child(v)
	h.add_child(_sp(8))
	p.add_child(h)
	return p


## Üst şerit: [GERİ / ANA SAYFA] ..... [başlık levhası] ..... [bakiye]; iki yan eşit genişlikte (başlık tam ortada).
func _topbar(back_text: String, back_cb: Callable, title_icon: Control, title: String, count: String = "") -> Control:
	var h := _h(0)
	h.custom_minimum_size.y = 72
	var l := _h(0)
	l.custom_minimum_size.x = 300
	var bb := _btn("", "ghost", 32, 56, 200)
	bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _h(12)
	row.add_child(Glyph.new(G_LEFT, C_TEXT, 4))
	row.add_child(_lbl(back_text, 32))
	cc.add_child(row)
	bb.add_child(cc)
	bb.pressed.connect(back_cb)
	_tag_sid(bb, "back")
	_close_btn = bb
	l.add_child(bb)
	h.add_child(l)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plaque := _box(C_PANEL2, C_LINE_HI, 12, 3, 8)
	var ph := _h(14)
	ph.add_child(title_icon)
	ph.add_child(_lbl(title, 48, C_ACCENT))
	if count != "":
		ph.add_child(_lbl(count, 32, C_DIM))
	plaque.add_child(ph)
	mid.add_child(plaque)
	h.add_child(mid)
	var r := _h(0)
	r.custom_minimum_size.x = 300
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(_balance_chip())
	h.add_child(r)
	return h


func _key_badge(k: String, fs: int = 24) -> PanelContainer:
	var p := _box(C_INSET, C_LINE_HI, 2, 3, 4)
	p.custom_minimum_size = Vector2(fs * 1.5, fs * 1.5)
	p.add_child(_lbl(k, fs, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	return p


## Yetenek satırları: kendi ikonu + köşesinde tuş harfi (ikonu olmayan yetenekte sadece büyük harf), isteğe bağlı 2 satır açıklama.
func _skill_rows(it: Dictionary, fs: int = 32, desc_w: float = 0.0) -> VBoxContainer:
	var d: Dictionary = _char_def(it)
	var v := _v(10)
	for trio: Array in [["Q", "skill_name", "skill_icon", "skill_desc"], ["E", "skill2_name", "skill2_icon", "skill2_desc"],
			["R", "skill3_name", "skill3_icon", "skill3_desc"]]:
		var h := _h(12)
		var ip: String = str(d.get(trio[2], ""))
		var slot := _box(C_INSET, C_LINE_HI, 0, 3, 4)
		var has_icon: bool = ip != "" and ResourceLoader.exists(ip)
		if has_icon:
			slot.add_child(_icon(load(ip) as Texture2D, 48))
		var key := _lbl(trio[0], 24 if has_icon else 32, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		if has_icon:
			key.size_flags_horizontal = Control.SIZE_SHRINK_END
			key.size_flags_vertical = Control.SIZE_SHRINK_END
			key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		else:
			key.custom_minimum_size = Vector2(48, 48)
		slot.add_child(key)
		h.add_child(slot)
		if desc_w > 0.0:
			slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var tv := _v(0)
			tv.add_child(_lbl(str(d.get(trio[1], "")), fs))
			var ds: String = str(d.get(trio[3], ""))
			for pre: String in ["YETENEK: ", "TEMEL: ", "ULTİ: ", "ULTI: "]:
				ds = ds.trim_prefix(pre)
			tv.add_child(_wrap(ds, 24, C_DIM, desc_w, 2))
			h.add_child(tv)
		else:
			h.add_child(_lbl(str(d.get(trio[1], "")), fs))
		v.add_child(h)
	return v


func _stat_rows(it: Dictionary, fs: int = 24) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(int(it["key"]))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 4)
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Saldırı Gücü", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "0"]]:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		h.add_child(_lbl(row[1], fs, C_DIM))
		h.add_child(_lbl(row[2], fs))
		g.add_child(h)
	return g


func _goal_box(goal: Dictionary) -> PanelContainer:
	var p := _box(C_INSET, C_LINE, 14)
	var v := _v(8)
	v.add_child(_lbl("SIRADAKİ HEDEF", 24, C_ACCENT))
	var h := _h(12)
	var slot := _box(C_PANEL2, C_LINE, 4)
	slot.add_child(_icon(goal["icon"], 72))
	h.add_child(slot)
	var tv := _v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_lbl(str(goal["name"]), 32))
	tv.add_child(_expand(Bar.new(float(MetaProgressScript.shards()) / float(maxi(1, int(goal["cost"]))), C_ACCENT, C_PANEL3, 14.0)))
	var hh := _h(6)
	hh.add_child(ShardIcon.new(16))
	hh.add_child(_lbl("%d / %d" % [MetaProgressScript.shards(), int(goal["cost"])], 24, C_DIM))
	hh.add_child(_sp(0, 0, true))
	hh.add_child(_lbl("%d kaldı" % _need(goal), 24, C_PRICE))
	tv.add_child(hh)
	h.add_child(tv)
	v.add_child(h)
	p.add_child(v)
	return p


## Sahne/vitrin içine figür: karakterde tam boy kare (ayağı zemin halkasına basar), diğerlerinde ikon (halkanın biraz üstünde süzülür).
func _stage_figure(hold: Control, it: Dictionary, max_h: float, floor_off: float) -> void:
	var is_char: bool = it["kind"] == MetaProgressScript.CHAR
	var tex: Texture2D = _char_body(it) if is_char else it["icon"]
	if tex == null:
		return
	var ts: Vector2 = tex.get_size()
	var k: float = maxf(1.0, floorf(max_h / maxf(ts.x, ts.y) if not is_char else max_h / ts.y))
	var spr := TextureRect.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _state(it) == "no":
		spr.modulate = Color(0.62, 0.6, 0.64, 1.0)
	var sw: float = ts.x * k
	var shh: float = ts.y * k
	var lift: float = (floor_off - 8.0) if is_char else (floor_off + 24.0)
	spr.anchor_left = 0.5
	spr.anchor_right = 0.5
	spr.anchor_top = 1.0
	spr.anchor_bottom = 1.0
	spr.offset_left = -floorf(sw * 0.5)
	spr.offset_right = floorf(sw * 0.5)
	spr.offset_top = -lift - shh
	spr.offset_bottom = -lift
	hold.add_child(spr)


## ---------------------------------------------------------------- ANA SAYFA
func _build_home() -> void:
	_page_box.add_child(_topbar("GERİ", _on_close_pressed, ShardIcon.new(38), "RUH MAĞAZASI"))
	var items: Array = _items()
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	body.add_child(_home_featured(items))
	var right := _v(20)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 20)
	for kind: String in MetaProgressScript.KINDS:
		g.add_child(_home_tile(items, kind))
	right.add_child(g)
	right.add_child(_home_upgrades_tile())


func _home_featured(items: Array) -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 22, 3, 8)
	p.custom_minimum_size.x = 560
	var v := _v(12)
	p.add_child(v)
	var it: Dictionary = _featured(items)
	var goal: Dictionary = _goal(items)
	var title: String = "ŞİMDİ ALABİLİRSİN"
	if it.is_empty():
		it = goal
		title = "SIRADAKİ HEDEF"
	if it.is_empty():
		v.add_child(_lbl("HER ŞEY AÇIK", 48, C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(_wrap("Tüm karakterler, silahlar, evcil hayvanlar ve ruhani yetenekler sende. Kıymıklarını Geliştirmeler'de kullanabilirsin.",
				32, C_DIM, 500))
		return p
	var hh := _h(10)
	hh.add_child(_lbl(title, 24, C_ACCENT))
	hh.add_child(_sp(0, 0, true))
	hh.add_child(_lbl(str(KIND_ONE.get(it["kind"], "")), 24, C_DIM))
	v.add_child(hh)
	var sc := _box(C_INSET, C_LINE, 0)
	sc.custom_minimum_size = Vector2(512, 300)
	sc.add_child(StageBg.new(C_SPOT, C_ACCENT, 56.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(hold)
	_stage_figure(hold, it, 220.0, 56.0)
	v.add_child(sc)
	v.add_child(_lbl(str(it["name"]), 48, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if it["kind"] == MetaProgressScript.CHAR:
		v.add_child(_skill_rows(it, 32))
		v.add_child(_hline())
		v.add_child(_stat_rows(it, 24))
	else:
		v.add_child(_wrap(str(it["desc"]), 24, C_DIM, 512, 4))
	v.add_child(_sp(0, 4))
	v.add_child(_buy_btn(it, 32, 68, "feat_buy"))
	v.add_child(_sp(0, 0, false, true))
	if title != "SIRADAKİ HEDEF" and not goal.is_empty():
		v.add_child(_goal_box(goal))
	return p


func _home_tile(items: Array, kind: String) -> Control:
	var list: Array = _of_kind(items, kind)
	var p := _box(C_PANEL, C_LINE_HI, 18, 3, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := _v(12)
	var h := _h(12)
	h.add_child(_icon(list[0]["icon"] if not list.is_empty() else null, 48))
	h.add_child(_lbl(str(KIND_TILE.get(kind, kind)), 40))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d" % [_open_count(list), list.size()], 32, C_ACCENT))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(_open_count(list)) / float(maxi(1, list.size())), C_ACCENT, C_INSET, 12.0)))
	var prev := GridContainer.new()
	prev.columns = 5
	prev.add_theme_constant_override("h_separation", 8)
	prev.add_theme_constant_override("v_separation", 8)
	var can_n: int = 0
	for it: Dictionary in list:
		if _state(it) == "can":
			can_n += 1
	for i in mini(10, list.size()):
		var it: Dictionary = list[i]
		var st: String = _state(it)
		var s := _box(C_INSET, C_GOOD if st == "open" else C_LINE, 3, 3, 4)
		s.add_child(_icon(it["icon"], 96, st == "no"))
		prev.add_child(s)
	v.add_child(prev)
	v.add_child(_sp(0, 0, false, true))
	var f := _h(8)
	if can_n > 0:
		f.add_child(ShardIcon.new(20))
		f.add_child(_lbl("%d tanesini şimdi alabilirsin" % can_n, 24, C_GOOD))
	elif _open_count(list) == list.size():
		f.add_child(Glyph.new(G_CHECK, C_GOOD, 3))
		f.add_child(_lbl("Hepsi açık", 24, C_GOOD))
	else:
		f.add_child(_lbl("Kıymık biriktir", 24, C_DIM))
	f.add_child(_sp(0, 0, true))
	if list.size() > 10:
		f.add_child(_lbl("+%d daha" % (list.size() - 10), 24, C_DIM))
		f.add_child(_sp(12))
	f.add_child(_lbl("AÇ", 24, C_ACCENT))
	f.add_child(Glyph.new(G_RIGHT, C_ACCENT, 3))
	v.add_child(f)
	p.add_child(v)
	_clickable(p, _on_tab_pressed.bind(kind), "tile:" + kind)
	return p


func _home_upgrades_tile() -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 18, 3, 8)
	var v := _v(12)
	var lv: Vector2i = _upg_levels()
	var h := _h(12)
	h.add_child(_icon(_stat_tex("damage"), 48))
	h.add_child(_lbl("Geliştirmeler", 40))
	h.add_child(_lbl("Kalıcı güçlendirmeler, her koşuda geçerli", 24, C_DIM))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d seviye" % [lv.x, lv.y], 32, C_ACCENT))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(lv.x) / float(maxi(1, lv.y)), C_ACCENT, C_INSET, 12.0)))
	var row := _h(10)
	var can_n: int = 0
	for d: Dictionary in MetaUpgradesScript.LIST:
		if MetaUpgradesScript.can_buy(str(d["id"])):
			can_n += 1
	var shown: int = mini(12, MetaUpgradesScript.LIST.size())
	for i in shown:
		var s := _box(C_INSET, C_LINE, 4, 3, 4)
		s.add_child(_upg_icon(MetaUpgradesScript.LIST[i], 56))
		row.add_child(s)
	if MetaUpgradesScript.LIST.size() > shown:
		row.add_child(_lbl("+%d" % (MetaUpgradesScript.LIST.size() - shown), 32, C_DIM))
	v.add_child(row)
	var f := _h(8)
	if can_n > 0:
		f.add_child(ShardIcon.new(20))
		f.add_child(_lbl("%d geliştirmeyi şimdi yükseltebilirsin" % can_n, 24, C_GOOD))
	else:
		f.add_child(_lbl("Kıymık biriktir", 24, C_DIM))
	f.add_child(_sp(0, 0, true))
	f.add_child(_lbl("AÇ", 24, C_ACCENT))
	f.add_child(Glyph.new(G_RIGHT, C_ACCENT, 3))
	v.add_child(f)
	p.add_child(v)
	_clickable(p, _on_tab_pressed.bind(PAGE_UPGRADES), "tile:upgrades")
	return p


func _upg_levels() -> Vector2i:
	var a: int = 0
	var b: int = 0
	for d: Dictionary in MetaUpgradesScript.LIST:
		a += MetaUpgradesScript.level(str(d["id"]))
		b += int(d["max"])
	return Vector2i(a, b)


## ---------------------------------------------------------------- KATEGORİ SAYFASI ("kahraman seçimi")
func _build_kind_page(kind: String) -> void:
	var items: Array = _items()
	var list: Array = _of_kind(items, kind)
	_page_box.add_child(_topbar("ANA SAYFA", _go_home, _icon(list[0]["icon"] if not list.is_empty() else null, 48),
			str(KIND_NAMES.get(kind, kind)), "%d/%d" % [_open_count(list), list.size()]))
	if list.is_empty():
		return
	var sel: Dictionary = _selected(items, kind)
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	body.add_child(_kind_stage(sel, list.size() > 1))
	body.add_child(_kind_info(sel))
	_page_box.add_child(_kind_roster(list, sel))


func _status_badge(it: Dictionary) -> PanelContainer:
	var st: String = _state(it)
	var bd: Color = C_LINE_HI
	var txt: String = "%d KIYMIK EKSİK" % _need(it)
	var tc: Color = C_DIM
	if st == "can":
		bd = C_GOOD
		txt = "ŞİMDİ ALABİLİRSİN"
		tc = C_GOOD
	elif st == "open":
		bd = C_GOOD
		txt = "SENDE"
		tc = C_GOOD
	var p := _box(C_INSET, bd, 8, 3, 6)
	var h := _h(8)
	if st == "no":
		h.add_child(Glyph.new(G_LOCK, tc, 3))
	elif st == "open":
		h.add_child(Glyph.new(G_CHECK, tc, 3))
	else:
		h.add_child(ShardIcon.new(20))
	h.add_child(_lbl(txt, 24, tc))
	p.add_child(h)
	return p


## Büyük sahne: spot ışığının altında halkalı zemin + figür, sol üstte durum rozeti, yanlarda gezinme okları.
func _kind_stage(it: Dictionary, arrows: bool) -> Control:
	var p := _box(C_INSET, C_LINE_HI, 0, 3, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(StageBg.new(C_SPOT, C_ACCENT, STAGE_FLOOR))
	p.add_child(CornerFrame.new(C_ACCENT, 26.0, 10.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hold)
	_stage_figure(hold, it, 430.0 if it["kind"] == MetaProgressScript.CHAR else 288.0, STAGE_FLOOR)
	var badge := _status_badge(it)
	badge.position = Vector2(26, 26)
	hold.add_child(badge)
	if arrows:
		var kind: String = str(it["kind"])
		for side: Array in [[G_LEFT, 0.0, 26.0, -1], [G_RIGHT, 1.0, -98.0, 1]]:
			var ab := _btn("", "ghost", 32, 72, 72)
			var cc := CenterContainer.new()
			cc.set_anchors_preset(Control.PRESET_FULL_RECT)
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.add_child(Glyph.new(side[0], C_TEXT, 5))
			ab.add_child(cc)
			ab.anchor_left = float(side[1])
			ab.anchor_right = float(side[1])
			ab.anchor_top = 0.5
			ab.anchor_bottom = 0.5
			ab.offset_left = float(side[2])
			ab.offset_right = float(side[2]) + 72.0
			ab.offset_top = -36.0
			ab.offset_bottom = 36.0
			ab.pressed.connect(_step_selection.bind(kind, int(side[3])))
			_tag_sid(ab, "arrow:%d" % int(side[3]))
			hold.add_child(ab)
	return p


## Sağ bilgi paneli: ad, (karakterde) yetenekler + pasif + statlar / (diğerlerinde) açıklama; altta durum + satın alma.
func _kind_info(it: Dictionary) -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 24, 3, 8)
	p.custom_minimum_size.x = 660
	var v := _v(10)
	v.add_child(_lbl(str(it["name"]), 64))
	v.add_child(_hline())
	if it["kind"] == MetaProgressScript.CHAR:
		var d: Dictionary = _char_def(it)
		v.add_child(_lbl("YETENEKLER", 24, C_ACCENT))
		v.add_child(_skill_rows(it, 32, 536.0))
		var pas := _v(4)
		pas.add_child(_lbl("PASİF", 24, C_ACCENT))
		pas.add_child(_wrap(str(d.get("passive", "")), 24, C_DIM, 608, 3))
		v.add_child(pas)
		v.add_child(_hline())
		v.add_child(_stat_rows(it, 24))
	else:
		var sub: String = str(KIND_ONE.get(it["kind"], ""))
		var desc: String = str(it["desc"])
		if it["kind"] == MetaProgressScript.WEAPON:
			sub = "%s  -  %s" % [sub, WeaponCatalog.category_label(str(it["key"]))]
			desc = WeaponCatalog.trait_text(str(it["key"]))
		v.add_child(_lbl(sub, 24, C_ACCENT))
		v.add_child(_wrap(desc, 32, C_TEXT, 608, 9))
	v.add_child(_sp(0, 0, false, true))
	var br := _h(16)
	var kv := _v(-4)
	kv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	match _state(it):
		"can":
			kv.add_child(_lbl("Alınca kalan", 24, C_DIM))
			var kh := _h(6)
			kh.add_child(ShardIcon.new(20))
			kh.add_child(_lbl(str(MetaProgressScript.shards() - int(it["cost"])), 32))
			kv.add_child(kh)
		"no":
			kv.add_child(_lbl("Eksik", 24, C_DIM))
			var kh := _h(6)
			kh.add_child(ShardIcon.new(20, true))
			kh.add_child(_lbl(str(_need(it)), 32, C_BAD))
			kv.add_child(kh)
		_:
			kv.add_child(_lbl("Seçim ekranında", 24, C_DIM))
			kv.add_child(_lbl("kullanabilirsin", 24, C_DIM))
	br.add_child(kv)
	br.add_child(_expand(_buy_btn(it, 40, 80, "buy")))
	v.add_child(br)
	p.add_child(v)
	return p


## Alt sıra: çerçeveli kartlar (ikon x3, ad levhası, fiyat). Seçili kart 14 px yukarıda + vurgu kenarı + köşe süsü. Basınca seçilir.
func _kind_roster(list: Array, sel: Dictionary) -> Control:
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = 232
	var row := _h(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wide: bool = list.size() >= 8
	for it: Dictionary in list:
		var on: bool = _id(it) == _id(sel)
		var st: String = _state(it)
		var wrap := MarginContainer.new()
		wrap.add_theme_constant_override("margin_top", 0 if on else 14)
		wrap.add_theme_constant_override("margin_bottom", 14 if on else 0)
		if wide:
			wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := _box(C_PANEL, C_ACCENT if on else (C_LINE_HI if st == "can" else C_LINE), 3, 3, 6)
		card.custom_minimum_size = Vector2(150 if wide else 170, 214)
		card.add_child(CardBg.new(C_PANEL3 if on else C_PANEL2, C_INSET, C_SPOT if st != "no" else C_LINE))
		var v := _v(2)
		v.add_child(_sp(0, 4))
		v.add_child(_icon(it["icon"], 144, st == "no"))
		var plate := _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 2, 0, 0)
		var nm := _lbl(str(it["name"]), 24, C_ACCENT if on else (C_DIM if st == "open" else C_TEXT), HORIZONTAL_ALIGNMENT_CENTER)
		nm.clip_text = true
		plate.add_child(nm)
		v.add_child(plate)
		v.add_child(_price(it, 32))
		card.add_child(v)
		if on:
			card.add_child(CornerFrame.new(C_ACCENT, 16.0, 5.0))
		if st == "no":
			var gm := MarginContainer.new()
			gm.add_theme_constant_override("margin_right", 10)
			gm.add_theme_constant_override("margin_top", 10)
			gm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gm.size_flags_horizontal = Control.SIZE_SHRINK_END
			gm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			gm.add_child(Glyph.new(G_LOCK, C_DIM, 3))
			card.add_child(gm)
		_clickable(card, _select.bind(it), "card:" + _id(it))
		wrap.add_child(card)
		row.add_child(wrap)
	sc.add_child(row)
	return sc


## ---------------------------------------------------------------- GELİŞTİRMELER
func _build_upgrades() -> void:
	var lv: Vector2i = _upg_levels()
	_page_box.add_child(_topbar("ANA SAYFA", _go_home, _icon(_stat_tex("damage"), 40), "GELİŞTİRMELER", "%d/%d" % [lv.x, lv.y]))
	var center := _box(C_PANEL, C_LINE_HI, 18, 3, 8)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(center)
	var cv := _v(12)
	center.add_child(cv)
	var hdr := _h(14)
	hdr.add_child(_lbl("Kalıcı güçlendirmeler her koşuda otomatik uygulanır. Seviye atladıkça fiyat artar.", 24, C_DIM))
	hdr.add_child(_sp(0, 0, true))
	hdr.add_child(_lbl("Toplam seviye %d / %d" % [lv.x, lv.y], 24, C_DIM))
	var bar := Bar.new(float(lv.x) / float(maxi(1, lv.y)), C_ACCENT, C_INSET, 14.0, 220.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(bar)
	cv.add_child(hdr)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list = grid
	for d: Dictionary in MetaUpgradesScript.LIST:
		grid.add_child(_upgrade_row(d))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	_scroll = sc
	cv.add_child(sc)
	cv.add_child(_reset_row())


func _upgrade_row(d: Dictionary) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = int(d["max"])
	var maxed: bool = lv >= mx
	var per: float = float(d["per"])
	var p := _box(C_PANEL2, C_LINE, 6)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _h(12)
	var slot := _box(C_INSET, C_LINE, 2, 3, 4)
	slot.add_child(_upg_icon(d, 48))
	h.add_child(slot)
	var tv := _v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.tooltip_text = str(d["desc"])
	tv.mouse_filter = Control.MOUSE_FILTER_PASS
	var l1 := _h(8)
	l1.add_child(_lbl(str(d["name"]), 24))
	l1.add_child(_sp(0, 0, true))
	if maxed:
		l1.add_child(_lbl(MetaUpgradesScript.format_value(id, per * float(lv)), 24, C_GOOD))
	else:
		l1.add_child(_lbl(MetaUpgradesScript.format_value(id, per * float(lv)), 24, C_DIM))
		l1.add_child(Glyph.new(G_ARROW, C_DIM, 3))
		l1.add_child(_lbl(MetaUpgradesScript.format_value(id, per * float(lv + 1)), 24, C_GOOD))
	tv.add_child(l1)
	var l2 := _h(10)
	l2.add_child(_expand(Pips.new(mx, lv, C_ACCENT, C_INSET, 10.0)))
	l2.add_child(_lbl("%d/%d" % [lv, mx], 24, C_DIM))
	tv.add_child(l2)
	h.add_child(tv)
	var b: Control
	if maxed:
		b = _lbl("MAKS", 32, C_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
		b.custom_minimum_size.x = 150
	else:
		var can: bool = MetaUpgradesScript.can_buy(id)
		var pb := _price_btn("", MetaUpgradesScript.next_cost(id), "primary" if can else "off", 32, 56, 150)
		pb.disabled = not can
		pb.pressed.connect(_on_upgrade_pressed.bind(id))
		_tag_sid(pb, "up:" + id)
		b = pb
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	p.add_child(h)
	return p


func _reset_row() -> Control:
	var row := _h(12)
	var info: String = "Sıfırlanacak geliştirme yok."
	if MetaUpgradesScript.can_reset():
		info = "Sıfırlarsan harcanan %d kıymıktan %d ücret kesilir, %d geri gelir." % [
				MetaUpgradesScript.total_spent(), MetaUpgradesScript.reset_fee(), MetaUpgradesScript.reset_refund()]
	row.add_child(_sp(0, 0, true))
	row.add_child(_lbl(info, 24, C_DIM))
	var asking: bool = _confirm_id == "reset"
	var btn: Button = _btn("ONAYLA?" if asking else "HEPSİNİ SIFIRLA", "danger" if asking else "ghost", 24, 48, 230)
	btn.disabled = not MetaUpgradesScript.can_reset()
	btn.pressed.connect(_on_reset_pressed)
	_tag_sid(btn, "reset")
	row.add_child(btn)
	return row


## ---------------------------------------------------------------- TELEFON
## TELEFON (2026-10-19, madde 279; kullanıcı seçimi prototip S = B "Yan Ray + Detay", mobil_proto.gd B_ruh): ray KAHRAMAN / SİLAH /
## EVCİL / RUHANİ / GELİŞTİR; ortada kategorinin ızgarası (karakterde YÜZ, kilitliye kıymık fiyatı, açıkta onay) ya da geliştirme
## satırları; sağda seçilenin önizlemesi (karakter BOYDAN) + adı + yetenek simgeleri / açıklama + KİLİDİ AÇ (iki dokunuş: ONAYLA?).
## Veri / satın alma masaüstüyle aynı (_items, _selected, _select, _on_buy_pressed, _on_upgrade_pressed, _on_reset_pressed).
const PH_PAGES := ["char", "weapon", "pet", "spirit", "upgrades"]
var _phone: bool = false
var _ph: Dictionary = {}


func _build_phone() -> void:
	_phone = true
	if not PH_PAGES.has(_page):
		_page = MetaProgressScript.CHAR
	var root := Control.new()
	root.name = "PhoneSoulShop"
	root.theme = DK.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP ## alttaki ana menüye tıklama geçmesin
	add_child(root)
	PK.fit(root)
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE) as Texture2D if ResourceLoader.exists(BG_TEXTURE) else null
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var pet_ic: CenterContainer = DK.icon(PetCatalog.icon(PetCatalog.DEFAULT_KEY), 64)
	var sp_tex_path: String = str(SpiritualSkillsScript.get_def(SpiritualSkillsScript.DEFAULT_ID).get("icon", ""))
	var sp_ic: CenterContainer = DK.icon(load(sp_tex_path) as Texture2D if sp_tex_path != "" and ResourceLoader.exists(sp_tex_path) else null, 64)
	_ph = PK.b_frame(root, [["KAHRAMAN", PK.G_USER], ["SİLAH", PK.G_SWORD], ["EVCİL", pet_ic], ["RUHANİ", sp_ic], ["GELİŞTİR", PK.G_UP]],
			_on_close_pressed, 820.0, 0.62)
	var tabs: Array = _ph["tabs"]
	for i in tabs.size():
		var pg: String = PH_PAGES[i]
		(tabs[i] as Button).pressed.connect(func() -> void:
			if pg != _page:
				UISound.play_click()
				_on_tab_pressed(pg))
	_ph_rebuild()


func _ph_rebuild() -> void:
	PK.set_rail(_ph["tabs"], PH_PAGES.find(_page))
	var det: VBoxContainer = _ph["det"]
	PK.clear(det)
	if _page == PAGE_UPGRADES:
		PK.set_page(_ph["mid"], _ph_upgrades_page())
		_ph_upgrades_detail(det)
	else:
		var items: Array = _items()
		PK.set_page(_ph["mid"], _ph_kind_page(items, _page))
		_ph_kind_detail(det, _selected(items, _page))
	UISound.connect_all_buttons(self)


func _ph_shard_chip() -> PanelContainer:
	var chip := PK.inset(0.9, 0.0, DK.C_LINE)
	var st: StyleBoxFlat = chip.get_theme_stylebox("panel")
	st.content_margin_left = 16
	st.content_margin_right = 20
	var h := DK.h(12)
	h.add_child(DK.ShardIcon.new(32.0))
	h.add_child(PK.lbl(str(MetaProgressScript.shards()), PK.FS_BODY, PK.C_SOUL))
	chip.add_child(h)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


## Kategori: başlık + açık sayısı + kıymık, 5 sütun karo (seçili altın kenar; kilitliye fiyat, açıkta onay).
func _ph_kind_page(items: Array, kind: String) -> Control:
	var v := DK.v(16)
	var list: Array = _of_kind(items, kind)
	var sel: Dictionary = _selected(items, kind)
	var head := DK.h(16)
	var t := PK.lbl(str(KIND_NAMES.get(kind, kind)), PK.FS_TITLE, DK.C_ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(PK.lbl("%d / %d açık" % [_open_count(list), list.size()], PK.FS_SMALL, DK.C_DIM))
	head.add_child(_ph_shard_chip())
	v.add_child(head)
	var lst: Array = PK.scroll_list(0)
	v.add_child(lst[0])
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for it: Dictionary in list:
		grid.add_child(_ph_tile(it, str(it["key"]) == str(sel.get("key", ""))))
	if list.is_empty():
		v.add_child(PK.lbl("Bu bölümde açılacak bir şey yok.", PK.FS_BODY, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	(lst[1] as VBoxContainer).add_child(grid)
	return v


func _ph_tile(it: Dictionary, on: bool) -> Button:
	var st: String = _state(it)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(196, 232)
	DK.style_button(b, "tile_on" if on else ("tile" if st != "no" else "tile_locked"), 6, 4.0)
	var v := DK.v(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(DK.icon(it.get("icon") as Texture2D, 144.0, st == "no"))
	var nm := PK.lbl(str(it["name"]), 24, DK.C_ACCENT if on else (DK.C_DIM if st == "no" else DK.C_TEXT), HORIZONTAL_ALIGNMENT_CENTER)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	b.add_child(v)
	## Sol üst köşe: açıksa onay, değilse kıymık + fiyat (yetmiyorsa kırmızımsı).
	var corner := DK.h(6)
	corner.position = Vector2(10, 8)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if st == "open":
		corner.add_child(PK.glyph(PK.G_CHECK, DK.C_GOOD, 4))
	else:
		corner.add_child(DK.ShardIcon.new(22.0, st == "no"))
		corner.add_child(PK.lbl(str(int(it["cost"])), 24, PK.C_SOUL if st == "can" else DK.C_BAD))
	b.add_child(corner)
	b.pressed.connect(func() -> void:
		UISound.play_click()
		_select(it))
	return b


## Sağ sütun (kategori): önizleme + ad + tür + yetenekler / açıklama + KİLİDİ AÇ.
func _ph_kind_detail(det: VBoxContainer, it: Dictionary) -> void:
	if it.is_empty():
		det.add_child(PK.lbl(str(KIND_ONE.get(_page, "")), PK.FS_TITLE, DK.C_ACCENT))
		return
	var kind: String = str(it["kind"])
	var stage := PK.inset(0.8, 0.0, DK.C_LINE)
	stage.custom_minimum_size = Vector2(0, 340)
	stage.add_child(DK.Spot.new(DK.C_SPOT, 0.86))
	var cc := CenterContainer.new()
	if kind == MetaProgressScript.CHAR: ## karakter BOYDAN (kullanıcı 2026-10-19), tam katlı büyütme
		var body: Texture2D = _char_body(it)
		cc.add_child(DK.icon(body, 300.0, false, 300.0))
	else:
		cc.add_child(DK.icon(it.get("icon") as Texture2D, 240.0))
	stage.add_child(cc)
	det.add_child(stage)
	det.add_child(DK.sp(0, 12))
	var nh := DK.h(16)
	var nm := PK.lbl(str(it["name"]), PK.FS_TITLE, DK.C_ACCENT)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(nm)
	nh.add_child(PK.lbl(str(KIND_ONE.get(kind, "")), PK.FS_SMALL, DK.C_DIM))
	det.add_child(nh)
	if kind == MetaProgressScript.CHAR:
		var d: Dictionary = _char_def(it)
		var row := DK.h(20)
		for slot: Array in [["passive", "P"], ["skill", "Q"], ["skill2", "E"], ["skill3", "R"]]:
			var p := Control.new()
			p.custom_minimum_size = Vector2(96, 96)
			var sl := DK.slot(_ph_tex(str(d.get(str(slot[0]) + "_icon", ""))), 84)
			sl.set_anchors_preset(Control.PRESET_FULL_RECT)
			p.add_child(sl)
			var kb := DK.box(DK.C_INSET, DK.C_ACCENT if slot[1] == "R" else DK.C_LINE_HI, 0, 2, 3)
			kb.custom_minimum_size = Vector2(34, 34)
			kb.position = Vector2(-6, 68)
			kb.add_child(DK.lbl(str(slot[1]), 24, DK.C_ACCENT if slot[1] == "R" else DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			p.add_child(kb)
			row.add_child(p)
		det.add_child(DK.sp(0, 8))
		det.add_child(row)
	var desc := PK.lbl(str(it.get("desc", "")), PK.FS_SMALL, DK.C_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(DK.sp(0, 8))
	det.add_child(desc)
	det.add_child(DK.sp(0, 0, false, true))
	var st: String = _state(it)
	var cost: int = int(it["cost"])
	var b: Button
	match st:
		"open":
			b = PK.big_button("AÇIK", "Seçim ekranında seçebilirsin", "disabled", PK.G_CHECK, 0.0, 144.0)
			b.disabled = true
		"can":
			var asking: bool = _confirm_id == _id(it)
			b = PK.big_button("ONAYLA?" if asking else "KİLİDİ AÇ  %d" % cost, "Kalan: %d" % (MetaProgressScript.shards() - cost),
					"danger" if asking else "primary", [], 0.0, 144.0)
			b.pressed.connect(_on_buy_pressed.bind(kind, it["key"]))
		_:
			b = PK.big_button("KİLİDİ AÇ  %d" % cost, "%d kıymık eksik" % _need(it), "disabled", PK.G_LOCK, 0.0, 144.0)
			b.disabled = true
	b.name = "BuyButton"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_child(b)


func _ph_tex(path: String) -> Texture2D:
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


## GELİŞTİR: başlık + toplam seviye, 2 sütun geliştirme satırı (kaydırılır).
func _ph_upgrades_page() -> Control:
	var v := DK.v(16)
	var lv: Vector2i = _upg_levels()
	var head := DK.h(16)
	var t := PK.lbl("GELİŞTİRMELER", PK.FS_TITLE, DK.C_ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(PK.lbl("%d / %d seviye" % [lv.x, lv.y], PK.FS_SMALL, DK.C_DIM))
	head.add_child(_ph_shard_chip())
	v.add_child(head)
	var lst: Array = PK.scroll_list(0)
	v.add_child(lst[0])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d: Dictionary in MetaUpgradesScript.LIST:
		grid.add_child(_ph_upgrade_row(d))
	(lst[1] as VBoxContainer).add_child(grid)
	return v


func _ph_upgrade_row(d: Dictionary) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = int(d["max"])
	var maxed: bool = lv >= mx
	var per: float = float(d["per"])
	var p := PK.inset(0.85, 14.0, DK.C_LINE)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.tooltip_text = str(d["desc"])
	var h := DK.h(16)
	var ic := PK.inset(1.0, 6.0, DK.C_LINE_HI)
	ic.add_child(_upg_icon(d, 64))
	h.add_child(ic)
	var tv := DK.v(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l1 := DK.h(10)
	var nm := PK.lbl(str(d["name"]), PK.FS_SMALL, DK.C_TEXT)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.add_child(nm)
	l1.add_child(PK.lbl(MetaUpgradesScript.format_value(id, per * float(lv)), 24, DK.C_GOOD if maxed else DK.C_DIM))
	if not maxed:
		l1.add_child(PK.lbl(">", 24, DK.C_DIM))
		l1.add_child(PK.lbl(MetaUpgradesScript.format_value(id, per * float(lv + 1)), 24, DK.C_GOOD))
	tv.add_child(l1)
	var l2 := DK.h(10)
	var pips := Pips.new(mx, lv, DK.C_ACCENT, DK.C_INSET, 12.0)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l2.add_child(pips)
	l2.add_child(PK.lbl("%d/%d" % [lv, mx], 24, DK.C_DIM))
	tv.add_child(l2)
	h.add_child(tv)
	if maxed:
		var mxl := PK.lbl("MAKS", PK.FS_SMALL, DK.C_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
		mxl.custom_minimum_size.x = 170
		h.add_child(mxl)
	else:
		var can: bool = MetaUpgradesScript.can_buy(id)
		var pb := PK.button(str(MetaUpgradesScript.next_cost(id)), "primary" if can else "disabled", PK.FS_SMALL, [], 170.0, 84.0)
		var shard := DK.ShardIcon.new(24.0, not can)
		(pb.get_node("Row") as HBoxContainer).add_child(shard)
		(pb.get_node("Row") as HBoxContainer).move_child(shard, 0)
		pb.disabled = not can
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.pressed.connect(_on_upgrade_pressed.bind(id))
		h.add_child(pb)
	p.add_child(h)
	return p


## Sağ sütun (geliştirmeler): açıklama + toplam ilerleme + sıfırlama.
func _ph_upgrades_detail(det: VBoxContainer) -> void:
	var lv: Vector2i = _upg_levels()
	det.add_child(PK.lbl("KALICI GÜÇ", PK.FS_TITLE, DK.C_ACCENT))
	var info := PK.lbl("Kalıcı güçlendirmeler her koşuda otomatik uygulanır. Seviye atladıkça fiyat artar.", PK.FS_SMALL, DK.C_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(info)
	det.add_child(DK.sp(0, 24))
	det.add_child(PK.lbl("Toplam seviye %d / %d" % [lv.x, lv.y], PK.FS_BODY, DK.C_TEXT))
	var bar := Bar.new(float(lv.x) / float(maxi(1, lv.y)), DK.C_ACCENT, DK.C_INSET, 24.0, 0.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_child(bar)
	det.add_child(DK.sp(0, 0, false, true))
	var reset_info: String = "Sıfırlanacak geliştirme yok."
	if MetaUpgradesScript.can_reset():
		reset_info = "Sıfırlarsan harcanan %d kıymıktan %d ücret kesilir, %d geri gelir." % [
				MetaUpgradesScript.total_spent(), MetaUpgradesScript.reset_fee(), MetaUpgradesScript.reset_refund()]
	var ri := PK.lbl(reset_info, PK.FS_SMALL, DK.C_DIM)
	ri.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(ri)
	det.add_child(DK.sp(0, 12))
	var asking: bool = _confirm_id == "reset"
	var rb := PK.button("ONAYLA?" if asking else "HEPSİNİ SIFIRLA", "danger" if asking else ("ghost" if MetaUpgradesScript.can_reset() else "disabled"),
			PK.FS_BODY, [], 0.0, 120.0)
	rb.name = "ResetButton"
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.disabled = not MetaUpgradesScript.can_reset()
	rb.pressed.connect(_on_reset_pressed)
	det.add_child(rb)
