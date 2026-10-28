extends CanvasLayer

## RUH MAĞAZASI (kullanıcı isteği 2026-10-13, bkz. meta_progress.gd): koşularda kazanılan Ruh Kıymığı ile kilitli karakter / başlangıç silahı /
## evcil hayvan / ruhani yetenek açılır + kalıcı GELİŞTİRMELER (meta_upgrades.gd). Ana menüdeki "RUH MAĞAZASI" düğmesi açar.
## Yanlışlıkla harcamaya karşı iki adım: ilk basış "ONAYLA?" yapar, ikinci basış satın alır (başka bir şeye basınca ilk adım geri alınır).
##
## MASAÜSTÜ TASARIM "C - Ocak Başı Defteri" (2026-10-24, madde 383; prototip tools/proto_20261024/ruh_komple/, madde 382): ana menü / ayarlar /
## rekorlar ekranlarının "Ateş Işığı" dili (fire_menu_kit.gd) ana menünün Ocak Başı sahnesinin (menu_hearth_bg.gd) üstünde. ANA SAYFA YOK: açılınca
## Karakterler. Solda bölümler (ana menü öğeleri gibi: mum + ikon + başlık + "x/y açık, N alınabilir"; en altta Geri), ortada sade yazı listesi
## (ikon + ad + fiyat, fiyat sırasında - alınca yer değiştirmez), sağda seçilenin ayrıntısı (spot sahne + altın ad + yetenekler/açıklama + büyük AÇ).
## Geliştirmeler aynı kalıp: liste satırında seviye pipsi, ayrıntıda "Şu an -> Sonraki" + YÜKSELT + küçük "Hepsini sıfırla" (iki adımlı).
## Önceki tasarım F (madde 173: ana sayfa + kahraman seçimi sahnesi + kart dizisi) bu dosyanın git geçmişinde. Telefon (_ph_*, madde 279) AYRI, değişmedi.
## ANİMASYON (2026-10-19, madde 323; madde 200 ilkeleri: kısa, tek seferlik, sonunda TAM eski hâl): sayfa girişi sıralı belirme, satır üstüne
## gelince nefes, seçim değişince figür yandan kayar + ayrıntı belirir, satın almada parlama + bakiye sayacı + kristal sesi. Sayfa her değişimde baştan
## kurulduğu için ne olduğu `_anim_*` bayraklarında tutulur, kurulum sonunda `_play_anims` oynatır.

signal closed

const UiAnim := preload("res://scripts/ui_anim.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")
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
const FM := preload("res://scripts/fire_menu_kit.gd")
## menu_hearth_bg.gd main_menu.gd'yi preload eder, main_menu.gd de bu dosyayı -> döngü olmasın diye çalışma anında yüklenir.
const HEARTH_BG := "res://scripts/menu_hearth_bg.gd"
const BG_TEXTURE := "res://assets/ui/ruh_magaza/bg_ruh_magaza.png" ## telefonun arka planı (gece dükkanı)

const PAGE_UPGRADES := "upgrades"
const TAB_UNLOCKS := "unlocks" ## eski API (testler/çağıranlar): eskiden ana sayfa, şimdi Karakterler
const TAB_UPGRADES := "upgrades"

## "Ateş Işığı" paleti (fire_menu_kit.gd masaüstü değerleriyle aynı tonlar).
const C_PANEL := Color(0.06, 0.04, 0.03, 0.82) ## ayrıntı zemini (sahne arkadan sezilir)
const C_PANEL2 := Color("#2a1d12")
const C_PANEL3 := Color("#3a2a1a")
const C_INSET := Color("#140e09")
const C_LINE := Color("#3b2a1a")
const C_LINE_HI := Color("#5a4128")
const C_TEXT := Color("#efe2c6")
const C_DIM := Color("#b09878")
const C_ACCENT := Color("#f4c56e")
const C_ACCENT_DK := Color("#6a4416")
const C_ACCENT_TEXT := Color("#24160a")
const C_GOOD := Color("#a9c96e")
const C_BAD := Color("#dc7f60")
const C_PRICE := Color("#f2c674")
const C_SPOT := Color("#c0803a")
const SHADE_COLOR := Color(0.05, 0.035, 0.025, 0.88) ## sol karartma (liste sütunlarının okunurluğu)
const SHADE_X0 := 1220.0

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const G_PCT := ["##...#", "##..#.", "...#..", "..#...", ".#..##", "#...##"]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_LEFT := ["..#", ".##", "###", ".##", "..#"]
const G_RIGHT := ["#..", "##.", "###", "##.", "#.."]

const KIND_NAMES := {"char": "KARAKTERLER", "weapon": "SİLAHLAR", "pet": "EVCİL HAYVANLAR", "spirit": "RUHANİ YETENEKLER"}
const KIND_TILE := {"char": "Karakterler", "weapon": "Silahlar", "pet": "Evcil Hayvanlar", "spirit": "Ruhani Yetenekler"}
const KIND_ONE := {"char": "KARAKTER", "weapon": "BAŞLANGIÇ SİLAHI", "pet": "EVCİL HAYVAN", "spirit": "RUHANİ YETENEK"}
const KIND_LOWER := {"char": "Karakter", "weapon": "Başlangıç silahı", "pet": "Evcil hayvan", "spirit": "Ruhani yetenek"}
const SECTIONS := ["char", "weapon", "pet", "spirit", "upgrades"] ## soldaki bölüm sütunu (geliştirmeler dahil)

const COL_LIST_W := 600.0 ## orta sütun (yazı listesi)
const DETAIL_TEXT_W := 470.0 ## ayrıntıdaki açıklama genişliği
const STAGE_H := 280.0 ## ayrıntının spot sahnesi
const STAGE_FLOOR := 50.0 ## sahne zemin halkasının alttan uzaklığı (figürün ayağı buraya basar)

var _close_btn: Button = null
var _balance_label: Label = null
var _list: Container = null ## orta sütunun satırları (geliştirmelerde 20 satır - test sayar)
var _scroll: ScrollContainer = null
var _page_box: VBoxContainer = null
var _confirm_id: String = "" ## "<tür>:<anahtar>" - onay bekleyen alım ("reset" = geliştirmeleri sıfırla)
var _page: String = "char" ## ana sayfa yok: "char" / "weapon" / "pet" / "spirit" / "upgrades"
var _sel: Dictionary = {} ## tür -> seçili anahtar
var _sel_upg: String = "" ## seçili geliştirme (boşsa alınabilir en ucuzu)
var _body_cache: Dictionary = {}
var _crop_cache: Dictionary = {} ## silah ikonu -> boş kenarı kırpılmış doku

const ANIM_IN_TIME := 0.18 ## sayfa girişinde öğe belirmesi
const ANIM_IN_SPAN := 0.3 ## uzun listede (17 silah, 20 geliştirme) son öğenin en geç başlaması
const ANIM_SLIDE_PX := 36.0 ## seçim değişince figürün geldiği yan uzaklık
const ANIM_SLIDE_TIME := 0.2
const ANIM_FLASH_TIME := 0.34 ## satın almada parlama sönmesi
const ANIM_COUNT_TIME := 0.45 ## bakiye sayacı
var _anim_page_in: bool = true ## sonraki kurulum bir sayfa girişi mi (açılış / sayfa değişimi); seçim ve satın almada false
var _anim_prev_sel: String = "" ## seçim değişti: önceki seçilinin id'si
var _anim_dir: int = 0 ## seçim yönü (-1 sol / 1 sağ): figür o yandan gelir
var _anim_bought: String = "" ## az önce alınan: "<tür>:<anahtar>", "up:<id>" ya da "reset"
var _anim_shards_from: int = -1 ## alımdan önceki bakiye (sayaç eskisinden yeniye akar)
var _anim_nodes: Dictionary = {} ## kurulumda işaretlenen düğümler (bkz. _play_anims)


## ---------------------------------------------------------------- çizim sınıfları (sanat dosyası yok)
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


## ---------------------------------------------------------------- yaşam döngüsü
func _ready() -> void:
	add_to_group(&"gamepad_modal")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_ui()
	if _close_btn:
		_close_btn.grab_focus()
	UiAnim.window_in(self)
	EventSfx.play(get_tree(), &"shop_open")


func _build_ui() -> void:
	if MobileUIScript.enabled:
		_build_phone()
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP ## alttaki ana menüye tıklama geçmesin
	add_child(root)
	(load(HEARTH_BG) as GDScript).call("add_to", root, 0.0) ## ana menünün Ocak Başı sahnesi (ayarlar / rekorlar ekranlarıyla aynı)
	var shade := FM.StepShade.new()
	shade.col = SHADE_COLOR
	shade.x0 = SHADE_X0
	shade.step_w = 40.0
	shade.steps = 6
	root.add_child(shade)
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
	_build_page()
	UISound.connect_all_buttons(self)
	_play_anims()
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


## Eski API: "unlocks"/"home" = Karakterler (ana sayfa yok), "upgrades" = geliştirmeler, tür adı ("char"/"weapon"/"pet"/"spirit") = o bölüm.
func _on_tab_pressed(tab: String) -> void:
	var page: String = MetaProgressScript.CHAR if tab == TAB_UNLOCKS or tab == "home" else tab
	if page == _page:
		return
	_page = page
	_confirm_id = ""
	_anim_page_in = true
	_rebuild_list(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): ## ana sayfa yok: geri = kapat (telefonda da)
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


func _selected(items: Array, kind: String) -> Dictionary:
	var list: Array = _of_kind(items, kind)
	if list.is_empty():
		return {}
	if _sel.has(kind):
		for i: Dictionary in list:
			if str(i["key"]) == str(_sel[kind]):
				return i
	return list[0]


## `dir` (oklar): figürün geleceği yan; 0 = kart sırasından bulunur.
func _select(it: Dictionary, dir: int = 0) -> void:
	var kind: String = str(it["kind"])
	var items: Array = _items()
	var prev: Dictionary = _selected(items, kind)
	if not prev.is_empty() and _id(prev) != _id(it):
		_anim_prev_sel = _id(prev)
		if dir == 0:
			var list: Array = _of_kind(items, kind)
			dir = 1 if _index_of(list, it) > _index_of(list, prev) else -1
		_anim_dir = dir
	_sel[kind] = it["key"]
	_confirm_id = ""
	_rebuild_list()


func _index_of(list: Array, it: Dictionary) -> int:
	for i in list.size():
		if _id(list[i]) == _id(it):
			return i
	return -1


func _on_buy_pressed(kind: String, key: Variant) -> void:
	var id: String = "%s:%s" % [kind, str(key)]
	if _confirm_id != id:
		_confirm_id = id
		_rebuild_list()
		return
	_confirm_id = ""
	var before: int = MetaProgressScript.shards()
	if MetaProgressScript.buy(kind, key):
		_mark_bought(id, before)
	_rebuild_list()


func _on_upgrade_pressed(id: String) -> void:
	_confirm_id = ""
	var before: int = MetaProgressScript.shards()
	if MetaUpgradesScript.buy(id):
		_mark_bought("up:" + id, before)
	_rebuild_list()


func _on_reset_pressed() -> void:
	if _confirm_id != "reset":
		_confirm_id = "reset"
		_rebuild_list()
		return
	_confirm_id = ""
	var before: int = MetaProgressScript.shards()
	if MetaUpgradesScript.reset_all() >= 0:
		_mark_bought("reset", before)
	_rebuild_list()


func _mark_bought(id: String, shards_before: int) -> void:
	_anim_bought = id
	_anim_shards_from = shards_before
	EventSfx.play(get_tree(), &"crystal_collect")


## ---------------------------------------------------------------- ANİMASYON (madde 323)
func _anim_list(key: String) -> Array:
	if not _anim_nodes.has(key):
		_anim_nodes[key] = []
	return _anim_nodes[key]


## Kurulum sonunda bayraklara göre BİR kez oynar ve bayrakları sıfırlar. Arayüz animasyonları kapalıysa (Grafik) her şey anında.
func _play_anims() -> void:
	var n: Dictionary = _anim_nodes
	var page_in: bool = _anim_page_in
	var prev_sel: String = _anim_prev_sel
	var dir: int = _anim_dir
	var bought: String = _anim_bought
	var from: int = _anim_shards_from
	_anim_nodes = {}
	_anim_page_in = false
	_anim_prev_sel = ""
	_anim_dir = 0
	_anim_bought = ""
	_anim_shards_from = -1
	if not is_inside_tree() or not UiAnim.is_enabled():
		return
	if page_in:
		_anim_page_enter(n)
		return
	if prev_sel != "":
		_anim_selection(n, prev_sel, dir)
	if bought != "":
		_anim_purchase(n, bought, from)


## Sayfa girişi: üst şerit, ana bloklar, sonra kutular/kartlar/satırlar sırayla belirir (uzun listede toplam ANIM_IN_SPAN'a sıkışır).
func _anim_page_enter(n: Dictionary) -> void:
	var t: float = 0.0
	for k: String in ["topbar", "stage", "info", "center"]:
		if n.get(k) is CanvasItem:
			UiAnim.reveal(n[k], 0.0, ANIM_IN_TIME, t)
			t += 0.04
	if _phone and is_instance_valid(_ph.get("det")):
		UiAnim.reveal(_ph["det"], 0.0, ANIM_IN_TIME, 0.06)
	var list: Array = []
	for k: String in ["tiles", "cards", "rows"]:
		list.append_array(n.get(k, []))
	if n.get("ph_grid") is Node:
		list.append_array((n["ph_grid"] as Node).get_children())
	var step: float = minf(0.05, ANIM_IN_SPAN / maxf(1.0, float(list.size())))
	for i in list.size():
		UiAnim.reveal(list[i], 0.0, ANIM_IN_TIME, t + step * i)


## Seçim değişti: figür seçim yönünden kayarak gelir, ayrıntı belirir.
func _anim_selection(n: Dictionary, prev_sel: String, dir: int) -> void:
	if _phone:
		if is_instance_valid(_ph.get("det")):
			UiAnim.reveal(_ph["det"], 0.3, 0.16)
		return
	var fig := n.get("figure") as TextureRect
	if fig:
		_anim_slide_in(fig, float(dir) * ANIM_SLIDE_PX)
	if n.get("info") is CanvasItem:
		UiAnim.reveal(n["info"], 0.3, 0.16)


## Satın alma / sıfırlama: bakiye eskisinden yeniye sayar + kıymık çipi nefes alır; alınan şey parlar (figür ayrıca hafif zıplar).
func _anim_purchase(n: Dictionary, bought: String, from: int) -> void:
	if is_instance_valid(_balance_label) and from >= 0:
		_anim_count(_balance_label, from, MetaProgressScript.shards())
	if n.get("chip") is Control:
		_pop_later(n["chip"])
	if _phone:
		if is_instance_valid(_ph.get("det")):
			_anim_flash(_ph["det"])
		return
	if bought == "reset":
		var rows: Array = n.get("rows", [])
		for i in rows.size():
			UiAnim.reveal(rows[i], 0.4, 0.16, minf(0.015 * i, 0.3))
		return
	for k: String in ["row:" + bought, "figure"]:
		if n.get(k) is CanvasItem:
			_anim_flash(n[k])
	var fig := n.get("figure") as TextureRect
	if fig:
		_anim_bounce(fig)


func _anim_tween(node: Node) -> Tween:
	var tw: Tween = node.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	return tw


## Yeni kurulan düğümün boyutu yerleşimden sonra belli olur: nefes birkaç kare sonra (UiAnim.pop pivotu/genliği boyuttan alır).
func _pop_later(c: Control) -> void:
	_anim_tween(self).tween_callback(_pop_now.bind(c)).set_delay(0.05)


func _pop_now(c: Variant) -> void:
	if is_instance_valid(c):
		UiAnim.pop(c)


## Figür ofsetle kayar (çapa sabit, ebeveyn boyutundan bağımsız); tam piksel adımlar, sonunda tam eski ofset.
func _anim_slide_in(c: Control, dx: float) -> void:
	var l0: float = c.offset_left
	var r0: float = c.offset_right
	var a0: float = c.modulate.a
	_set_shift(dx, c, l0, r0)
	c.modulate.a = 0.0
	var tw := _anim_tween(c)
	tw.tween_method(_set_shift.bind(c, l0, r0), dx, 0.0, ANIM_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate:a", a0, ANIM_SLIDE_TIME * 0.75)


func _set_shift(x: float, c: Variant, l0: float, r0: float) -> void:
	if is_instance_valid(c):
		var o: float = roundf(x)
		(c as Control).offset_left = l0 + o
		(c as Control).offset_right = r0 + o


func _anim_flash(ci: CanvasItem) -> void:
	var base: Color = ci.modulate
	ci.modulate = Color(base.r * 1.7, base.g * 1.55, base.b * 1.3, base.a)
	_anim_tween(ci).tween_property(ci, "modulate", base, ANIM_FLASH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Ayak noktası etrafında küçük zıplama (pivot ayakta; sonunda ölçek tam 1).
func _anim_bounce(c: Control) -> void:
	c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y)
	var tw := _anim_tween(c)
	tw.tween_property(c, "scale", Vector2(1.04, 1.07), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _anim_count(l: Label, from: int, to: int) -> void:
	if from == to:
		return
	_set_count(float(from), l)
	_anim_tween(l).tween_method(_set_count.bind(l), float(from), float(to), ANIM_COUNT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_count(v: float, l: Variant) -> void:
	if is_instance_valid(l):
		(l as Label).text = str(roundi(v))


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


## Fiyat / durum satırı: kristal + sayı (yetmiyorsa kırmızımsı), ya da onay + SENDE.
func _price(it: Dictionary, fs: int = 32, center: bool = true) -> HBoxContainer:
	var h := _h(8)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	match _state(it):
		"open":
			h.add_child(Glyph.new(G_CHECK, C_GOOD, 3 if fs < 32 else 4))
			h.add_child(_lbl("SENDE", fs, C_GOOD))
		"can":
			h.add_child(DK.ShardIcon.new(fs * 0.75))
			h.add_child(_lbl(str(it["cost"]), fs, C_PRICE))
		_:
			h.add_child(DK.ShardIcon.new(fs * 0.75, true))
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
	row.add_child(DK.ShardIcon.new(fs * 0.75, kind == "off"))
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
	## Nefesi şeffaf katman değil altındaki kutu alır (katmanın kendi otomatik animasyonu görünmezdi). Yeniden kurulumda odak
	## yerleşimden önce gelebilir -> _pop_later.
	UiAnim.skip(b)
	b.mouse_entered.connect(_pop_later.bind(p))
	b.focus_entered.connect(_pop_later.bind(p))
	p.add_child(b)
	return b


## Yetenek satırları: kendi ikonu + köşesinde tuş harfi (ikonu olmayan yetenekte sadece büyük harf), desc_w > 0 ise altında açıklama.
func _skill_rows(it: Dictionary, fs: int = 32, desc_w: float = 0.0, box: float = 48.0, desc_lines: int = 2) -> VBoxContainer:
	var d: Dictionary = _char_def(it)
	var v := _v(10)
	for trio: Array in [["Q", "skill_name", "skill_icon", "skill_desc"], ["E", "skill2_name", "skill2_icon", "skill2_desc"],
			["R", "skill3_name", "skill3_icon", "skill3_desc"]]:
		var h := _h(14)
		var ip: String = str(d.get(trio[2], ""))
		var slot := _box(C_INSET, C_LINE_HI, 0, 3, 4)
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if ip != "" and ResourceLoader.exists(ip):
			slot.add_child(_icon(load(ip) as Texture2D, box))
			var key := _lbl(trio[0], 24, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
			key.size_flags_horizontal = Control.SIZE_SHRINK_END
			key.size_flags_vertical = Control.SIZE_SHRINK_END
			key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			slot.add_child(key)
		else:
			var key2 := _lbl(trio[0], 32, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
			key2.custom_minimum_size = Vector2(box, box)
			slot.add_child(key2)
		h.add_child(slot)
		var tv := _v(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(_lbl(str(d.get(trio[1], "")), fs))
		if desc_w > 0.0:
			var ds: String = str(d.get(trio[3], ""))
			for pre: String in ["YETENEK: ", "TEMEL: ", "ULTİ: ", "ULTI: "]:
				ds = ds.trim_prefix(pre)
			tv.add_child(_wrap(ds, 24, C_DIM, desc_w, desc_lines))
		h.add_child(tv)
		v.add_child(h)
	return v


func _stat_rows(it: Dictionary, fs: int = 24, cols: int = 2) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(int(it["key"]))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 6)
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Saldırı Gücü", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "0"]]:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		h.add_child(_lbl(row[1], fs, C_DIM))
		h.add_child(_lbl(row[2], fs))
		g.add_child(h)
	return g


## Sahne/vitrin içine figür: karakterde tam boy kare (ayağı zemin halkasına basar), diğerlerinde ikon (halkanın biraz üstünde süzülür).
func _stage_figure(hold: Control, it: Dictionary, max_h: float, floor_off: float) -> TextureRect:
	var is_char: bool = it["kind"] == MetaProgressScript.CHAR
	var tex: Texture2D = _char_body(it) if is_char else it["icon"]
	if tex == null:
		return null
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
	return spr


## ---------------------------------------------------------------- SAYFA (tasarım C "Ocak Başı Defteri")
## Tek sayfa: başlık + bakiye; solda bölümler, ortada liste, sağda ayrıntı. Her bölüm (geliştirmeler dahil) aynı kalıp.
func _build_page() -> void:
	var items: Array = _items()
	_page_box.add_child(_header())
	var body := _h(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	body.add_child(_section_column(items))
	body.add_child(_list_column(items))
	var det := _box(C_PANEL, Color(0, 0, 0, 0), 32, 0, 10)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anim_nodes["info"] = det
	det.add_child(_upg_detail(_upg_selected()) if _page == PAGE_UPGRADES else _detail(_selected(items, _page)))
	body.add_child(det)


func _header() -> Control:
	var hd := _h(16)
	hd.custom_minimum_size.y = 96
	hd.add_child(_sp(16))
	var t := _lbl("RUH MAĞAZASI", 64, C_ACCENT)
	t.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 1))
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 5)
	hd.add_child(t)
	hd.add_child(_sp(0, 0, true))
	var bal := _h(12)
	bal.add_child(DK.ShardIcon.new(44))
	_balance_label = FM.lbl(str(MetaProgressScript.shards()), 56, C_PRICE)
	bal.add_child(_balance_label)
	_anim_nodes["chip"] = bal
	hd.add_child(bal)
	hd.add_child(_sp(16))
	_anim_nodes["topbar"] = hd
	return hd


## Sol sütun: bölümler ana menü öğeleri gibi (FM.item: mum + ikon + başlık + alt yazı), seçili = altın + yanan mum; en altta Geri.
func _section_column(items: Array) -> Control:
	var c := _v(0)
	c.custom_minimum_size.x = FM.COL_W
	for k: String in SECTIONS:
		var n: Vector2i = _counts(items, k)
		var can: int = _can_n(items, k)
		var sub: String = ("%d/%d seviye" if k == PAGE_UPGRADES else "%d/%d açık") % [n.x, n.y]
		if can > 0:
			sub += ", %d %s" % [can, "yükseltilebilir" if k == PAGE_UPGRADES else "alınabilir"]
		var b: Button = FM.item(_sec_name(k), sub, _section_icon(items, k, 48), false, false)
		_fm_focus_frame(b)
		FM.set_selected(b, k == _page) ## ağaca girmeden: kayma animasyonu her yeniden kurulumda oynamasın
		b.pressed.connect(_on_tab_pressed.bind(k))
		_tag_sid(b, "tab:" + k)
		c.add_child(b)
	c.add_child(_sp(0, 0, false, true))
	var back: Button = FM.item("Geri", "Ana menüye dön", Glyph.new(G_LEFT, C_DIM, 5), false, false)
	_fm_focus_frame(back)
	back.pressed.connect(_on_close_pressed)
	_tag_sid(back, "back")
	_close_btn = back
	c.add_child(back)
	return c


## FM.item'in odak çerçevesi boş (seçili görünüm elle verilir) -> gamepad için ince çerçeve.
func _fm_focus_frame(b: Button) -> void:
	b.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), C_LINE_HI, 3, 6))


## Orta sütun: başlık + sayaç, altında satırlar (öğeler fiyat sırasında; uzun listede kayar).
func _list_column(items: Array) -> Control:
	var c := _v(6)
	c.custom_minimum_size.x = COL_LIST_W
	_anim_nodes["center"] = c
	var th := _h(12)
	th.add_child(FM.lbl(_sec_title(_page), 40, C_TEXT))
	th.add_child(_sp(0, 0, true))
	var n: Vector2i = _counts(items, _page)
	th.add_child(_lbl(("%d / %d seviye" if _page == PAGE_UPGRADES else "%d / %d açık") % [n.x, n.y], 24, C_DIM))
	c.add_child(th)
	var ln := ColorRect.new()
	ln.color = C_LINE_HI
	ln.custom_minimum_size.y = 3
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ln)
	c.add_child(_sp(0, 4))
	var rows := _v(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list = rows
	if _page == PAGE_UPGRADES:
		var sel: String = str(_upg_selected()["id"])
		for d: Dictionary in MetaUpgradesScript.LIST:
			rows.add_child(_upg_row(d, str(d["id"]) == sel))
	else:
		var sel_it: Dictionary = _selected(items, _page)
		var list: Array = _by_cost(items, _page)
		if list.is_empty():
			rows.add_child(_lbl("Bu bölümde açılacak bir şey yok.", 32, C_DIM))
		var row_h: float = clampf(floorf(800.0 / maxf(1.0, float(list.size()))) - 6.0, 44.0, 72.0)
		for it: Dictionary in list:
			rows.add_child(_row(it, _id(it) == _id(sel_it), row_h))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	_scroll = sc
	c.add_child(sc)
	return c


func _row_box(on: bool, h: float) -> PanelContainer:
	var p := _box(Color(C_ACCENT, 0.10) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
	p.custom_minimum_size.y = h
	return p


## Seçili satırın solundaki altın şerit.
func _marker(on: bool) -> ColorRect:
	var mk := ColorRect.new()
	mk.color = C_ACCENT if on else Color(0, 0, 0, 0)
	mk.custom_minimum_size.x = 5
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mk


func _row(it: Dictionary, on: bool, row_h: float) -> Control:
	var st: String = _state(it)
	var p := _row_box(on, row_h)
	var h := _h(14)
	h.add_child(_marker(on))
	h.add_child(_icon(_small_tex(it), minf(48.0, row_h - 8.0), st == "no"))
	var nl := FM.lbl(str(it["name"]), 32, C_ACCENT if on else (C_DIM if st == "no" else C_TEXT))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	h.add_child(_price(it, 32, false))
	h.add_child(_sp(10))
	p.add_child(h)
	_clickable(p, _select.bind(it), "row:" + _id(it))
	_anim_list("rows").append(p)
	_anim_nodes["row:" + _id(it)] = p
	return p


func _upg_row(d: Dictionary, on: bool) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var p := _row_box(on, 34)
	var h := _h(12)
	h.add_child(_marker(on))
	h.add_child(_upg_icon(d, 32))
	var nl := FM.lbl(str(d["name"]), 24, C_ACCENT if on else C_TEXT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	var pp := Pips.new(mx, lv, C_ACCENT if lv < mx else C_GOOD, C_INSET, 8.0)
	pp.custom_minimum_size.x = 150
	pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pp)
	var lvl := _lbl("%d/%d" % [lv, mx], 24, C_GOOD if lv >= mx else C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	lvl.custom_minimum_size.x = 60
	h.add_child(lvl)
	h.add_child(_sp(8))
	p.add_child(h)
	_clickable(p, _select_upg.bind(id), "row:up:" + id)
	_anim_list("rows").append(p)
	_anim_nodes["row:up:" + id] = p
	return p


## Sağ: seçilenin ayrıntısı (spot sahne + altın ad + yetenekler/açıklama + büyük AÇ).
func _detail(it: Dictionary) -> Control:
	var v := _v(14)
	if it.is_empty():
		return v
	v.add_child(_detail_stage(it))
	v.add_child(_gold_title(str(it["name"])))
	v.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, C_DIM))
	if it["kind"] == MetaProgressScript.CHAR:
		v.add_child(_skill_rows(it, 32, DETAIL_TEXT_W))
		v.add_child(_stat_rows(it, 24, 2))
	else:
		v.add_child(_wrap(str(it["desc"]), 32, C_DIM, DETAIL_TEXT_W, 5))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_buy_btn(it, 40, 76))
	return v


func _upg_detail(d: Dictionary) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var v := _v(16)
	v.add_child(_detail_stage(d))
	v.add_child(_gold_title(str(d["name"])))
	v.add_child(_wrap(str(d["desc"]), 32, C_DIM, DETAIL_TEXT_W, 3))
	var lh := _h(12)
	lh.add_child(_lbl("SEVİYE", 24, C_DIM))
	lh.add_child(_sp(0, 0, true))
	lh.add_child(_lbl("%d / %d" % [lv, mx], 32, C_ACCENT))
	v.add_child(lh)
	v.add_child(Pips.new(mx, lv, C_ACCENT, C_INSET, 14.0))
	v.add_child(_upg_values(d))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_upgrade_btn(id, 40, 76))
	var asking: bool = _confirm_id == "reset"
	if asking:
		v.add_child(_wrap("Harcanan %d kıymıktan %d ücret kesilir, %d geri gelir." % [
				MetaUpgradesScript.total_spent(), MetaUpgradesScript.reset_fee(), MetaUpgradesScript.reset_refund()], 24, C_DIM, DETAIL_TEXT_W, 2))
	var can_reset: bool = MetaUpgradesScript.can_reset()
	var rb: Button = _btn("ONAYLA?" if asking else "Hepsini sıfırla", "danger" if asking else ("ghost" if can_reset else "off"), 24, 44)
	rb.disabled = not can_reset
	rb.pressed.connect(_on_reset_pressed)
	_tag_sid(rb, "reset")
	v.add_child(rb)
	return v


## "Şu an +%24  >  Sonraki +%32"
func _upg_values(d: Dictionary) -> HBoxContainer:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var per: float = float(d.get("per", 0.0))
	var h := _h(12)
	h.add_child(_lbl("Şu an", 24, C_DIM))
	h.add_child(_lbl(MetaUpgradesScript.format_value(id, per * lv) if lv > 0 else "-", 32))
	if lv < mx:
		h.add_child(_sp(10))
		h.add_child(Glyph.new(G_RIGHT, C_ACCENT, 4))
		h.add_child(_sp(10))
		h.add_child(_lbl("Sonraki", 24, C_DIM))
		h.add_child(_lbl(MetaUpgradesScript.format_value(id, per * (lv + 1)), 32, C_GOOD))
	return h


## Geliştirme düğmesi: YÜKSELT <fiyat> (tek basış), yetmiyor = pasif kırmızı fiyat, en üstte = pasif.
func _upgrade_btn(id: String, fs: int = 40, h: float = 76.0) -> Button:
	var b: Button
	if MetaUpgradesScript.level(id) >= MetaUpgradesScript.max_level(id):
		b = _btn("EN ÜST SEVİYE", "off", fs, h)
		b.disabled = true
	elif MetaUpgradesScript.can_buy(id):
		b = _price_btn("YÜKSELT", MetaUpgradesScript.next_cost(id), "primary", fs, h)
		b.pressed.connect(_on_upgrade_pressed.bind(id))
	else:
		b = _price_btn("YÜKSELT", MetaUpgradesScript.next_cost(id), "off", fs, h)
		b.disabled = true
	_tag_sid(b, "upg_buy")
	return b


func _gold_title(t: String) -> Label:
	var nl := FM.lbl(t, 56, C_ACCENT)
	nl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
	nl.add_theme_constant_override("outline_size", 6)
	return nl


## Ayrıntının spot sahnesi: karakter tam boy, diğerleri büyük ikon; geliştirme tanımı ("max" anahtarı) gelirse ikonu.
func _detail_stage(it: Dictionary) -> Control:
	var st := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 8)
	st.custom_minimum_size.y = STAGE_H
	st.clip_contents = true
	st.add_child(StageBg.new(C_SPOT, C_ACCENT, STAGE_FLOOR))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(hold)
	_anim_nodes["stage"] = st
	if it.has("max"):
		_stage_upgrade(hold, it, 160.0)
	else:
		var spr: TextureRect = _stage_figure(hold, _with_tex(it), 250.0 if it["kind"] == MetaProgressScript.CHAR else 137.0, STAGE_FLOOR)
		if spr != null:
			_anim_nodes["figure"] = spr
	return st


func _stage_upgrade(hold: Control, d: Dictionary, box: float) -> void:
	var ic: Control = _upg_icon(d, box)
	ic.anchor_left = 0.5
	ic.anchor_right = 0.5
	ic.anchor_top = 1.0
	ic.anchor_bottom = 1.0
	ic.offset_left = -floorf(box * 0.5)
	ic.offset_right = floorf(box * 0.5)
	ic.offset_top = -STAGE_FLOOR - 24.0 - box
	ic.offset_bottom = -STAGE_FLOOR - 24.0
	hold.add_child(ic)


## ---------------------------------------------------------------- sayfa verisi
func _sec_name(kind: String) -> String:
	return "Geliştirmeler" if kind == PAGE_UPGRADES else str(KIND_TILE.get(kind, kind))


func _sec_title(kind: String) -> String:
	return "GELİŞTİRMELER" if kind == PAGE_UPGRADES else str(KIND_NAMES.get(kind, kind))


## Bir türün öğeleri DURUMDAN BAĞIMSIZ fiyat sırasında (liste satın alınca yer değiştirmesin).
func _by_cost(items: Array, kind: String) -> Array:
	var a: Array = items.filter(func(i: Dictionary) -> bool: return i["kind"] == kind)
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["cost"]) < int(y["cost"]))
	return a


## (açık, toplam) - geliştirmelerde (seviye, azami seviye).
func _counts(items: Array, kind: String) -> Vector2i:
	if kind == PAGE_UPGRADES:
		return _upg_levels()
	var list: Array = _of_kind(items, kind)
	return Vector2i(_open_count(list), list.size())


## Şimdi alınabilecek / yükseltilebilecek sayısı.
func _can_n(items: Array, kind: String) -> int:
	var n: int = 0
	if kind == PAGE_UPGRADES:
		for d: Dictionary in MetaUpgradesScript.LIST:
			if MetaUpgradesScript.can_buy(str(d["id"])):
				n += 1
		return n
	for it: Dictionary in _of_kind(items, kind):
		if _state(it) == "can":
			n += 1
	return n


func _upg_levels() -> Vector2i:
	var a: int = 0
	var b: int = 0
	for d: Dictionary in MetaUpgradesScript.LIST:
		a += MetaUpgradesScript.level(str(d["id"]))
		b += int(d["max"])
	return Vector2i(a, b)


## Seçili geliştirme; seçilmemişse alınabilir en ucuzu (yoksa ilki).
func _upg_selected() -> Dictionary:
	if _sel_upg != "":
		return MetaUpgradesScript.def(_sel_upg)
	var best: Dictionary = {}
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		if MetaUpgradesScript.can_buy(id) and (best.is_empty() or MetaUpgradesScript.next_cost(id) < MetaUpgradesScript.next_cost(str(best["id"]))):
			best = d
	return best if not best.is_empty() else MetaUpgradesScript.LIST[0]


func _select_upg(id: String) -> void:
	var prev: String = str(_upg_selected()["id"])
	if prev != id:
		_anim_prev_sel = "up:" + prev
		_anim_dir = 0
	_sel_upg = id
	_confirm_id = ""
	_rebuild_list()


## Ayrıntıdaki büyük görsel: karakterde tam boy kare, silahta boş kenarı kırpılmış ikon (silah ikonları tuvalin ortasında küçük çizili).
func _tex_of(it: Dictionary) -> Texture2D:
	if it["kind"] == MetaProgressScript.CHAR:
		return _char_body(it)
	var tex: Texture2D = it.get("icon", null)
	if tex == null or it["kind"] != MetaProgressScript.WEAPON:
		return tex
	if _crop_cache.has(tex):
		return _crop_cache[tex]
	var out: Texture2D = tex
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0:
			out = ImageTexture.create_from_image(img.get_region(used))
	_crop_cache[tex] = out
	return out


## Liste ikonu: karakterde yüz portresi, silahta kırpılmış ikon.
func _small_tex(it: Dictionary) -> Texture2D:
	return _tex_of(it) if it["kind"] == MetaProgressScript.WEAPON else it.get("icon", null)


func _with_tex(it: Dictionary) -> Dictionary:
	var d: Dictionary = it.duplicate()
	d["icon"] = _tex_of(it)
	return d


## Bölüm simgesi: bölümün en ucuz öğesi (geliştirmelerde saldırı gücü simgesi).
func _section_icon(items: Array, kind: String, box: float) -> Control:
	if kind == PAGE_UPGRADES:
		return _icon(_stat_tex("damage"), box)
	var list: Array = _by_cost(items, kind)
	return _icon(_small_tex(list[0]) if not list.is_empty() else null, box)


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
	_play_anims()


func _ph_shard_chip() -> PanelContainer:
	var chip := PK.inset(0.9, 0.0, DK.C_LINE)
	var st: StyleBoxFlat = chip.get_theme_stylebox("panel")
	st.content_margin_left = 16
	st.content_margin_right = 20
	var h := DK.h(12)
	h.add_child(DK.ShardIcon.new(32.0))
	var sl := PK.lbl(str(MetaProgressScript.shards()), PK.FS_BODY, PK.C_SOUL)
	h.add_child(sl)
	_balance_label = sl
	_anim_nodes["chip"] = chip
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
	_anim_nodes["ph_grid"] = grid
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
	_anim_nodes["ph_grid"] = grid
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
