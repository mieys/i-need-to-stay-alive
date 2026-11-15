extends CanvasLayer
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## RUH MAĞAZASI (kullanıcı isteği 2026-10-13, bkz. meta_progress.gd): koşularda kazanılan Ruh Kıymığı ile kilitli karakter / başlangıç silahı /
## evcil hayvan / ruhani yetenek açılır + kalıcı GELİŞTİRMELER (meta_upgrades.gd). Ana menüdeki "RUH MAĞAZASI" düğmesi açar.
## Yanlışlıkla harcamaya karşı iki adım: ilk basış "ONAYLA?" yapar, ikinci basış satın alır (başka bir şeye basınca ilk adım geri alınır).
##
## MASAÜSTÜ TASARIM "C - Ocak Başı Defteri" (2026-10-24, madde 383; prototip tools/proto_20261024/ruh_komple/, madde 382): ana menü / ayarlar /
## rekorlar ekranlarının "Ateş Işığı" dili (fire_menu_kit.gd) ana menünün Ocak Başı sahnesinin (menu_hearth_bg.gd) üstünde. ANA SAYFA YOK: açılınca
## Karakterler. Solda bölümler (ana menü öğeleri gibi: ikon + başlık + "x/y açık, N alınabilir"; en altta Geri), ortada sade yazı listesi
## (ikon + ad + fiyat, fiyat sırasında - alınca yer değiştirmez), sağda seçilenin ayrıntısı (spot sahne + altın ad + yetenekler/açıklama + büyük AÇ).
## Geliştirmeler aynı kalıp: liste satırında seviye pipsi, ayrıntıda "Şu an -> Sonraki" + YÜKSELT + küçük "Hepsini sıfırla" (iki adımlı).
## Önceki tasarım F (madde 173: ana sayfa + kahraman seçimi sahnesi + kart dizisi) bu dosyanın git geçmişinde. Telefon (_ph_*, madde 279) AYRI, değişmedi.
## ANİMASYON (2026-10-19, madde 323; madde 200 ilkeleri: kısa, tek seferlik, sonunda TAM eski hâl): sayfa girişi sıralı belirme, satır üstüne
## gelince nefes, seçim değişince figür yandan kayar + ayrıntı belirir, satın almada parlama + bakiye sayacı + kristal sesi. Sayfa her değişimde baştan
## kurulduğu için ne olduğu `_anim_*` bayraklarında tutulur, kurulum sonunda `_play_anims` oynatır.

signal closed

const UiAnim := preload("res://scripts/ui_anim.gd")
const PixelBox := preload("res://scripts/pixel_box.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const MetaUpgradesScript: GDScript = preload("res://scripts/meta_upgrades.gd")
const KeyIcon := preload("res://scripts/key_icon.gd") ## harita anahtarları: doku + ad (madde 605)
const KeyIconBox := preload("res://scripts/key_icon_box.gd")
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
const PAGE_KEYS := "keys" ## ANAHTARLAR bölümü (madde 605): 5 harita anahtarı - kaç tane var, nereden düşer, neyi açar

## "Ateş Işığı" paleti (fire_menu_kit.gd masaüstü değerleriyle aynı tonlar).
const C_PANEL := Color(0.06, 0.04, 0.03, 0.82) ## ayrıntı zemini (sahne arkadan sezilir)
const HT := preload("res://scripts/hud_theme.gd") ## tek arayüz paleti (stil rehberi, madde 403)
const C_PANEL2 := HT.WIN_PANEL2
const C_PANEL3 := HT.WIN_PANEL3
const C_INSET := HT.DEEP
const C_LINE := HT.WIN_LINE
const C_LINE_HI := HT.WIN_LINE_HI
const C_TEXT := HT.TEXT
const C_DIM := HT.DIM
const C_ACCENT := HT.ACCENT
const C_ACCENT_DK := HT.ACCENT_DK
const C_ACCENT_TEXT := HT.ACCENT_TEXT
const C_GOOD := HT.GOOD
const C_BAD := HT.BAD
const C_PRICE := HT.PRICE
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
const SECTIONS := ["char", "weapon", "pet", "spirit", "upgrades", "keys"] ## soldaki bölüm sütunu (geliştirmeler + anahtarlar dahil)

const COL_LIST_W := 600.0 ## orta sütun (yazı listesi)
const DETAIL_TEXT_W := 470.0 ## ayrıntıdaki açıklama genişliği
const STAGE_H := 280.0 ## ayrıntının spot sahnesi
const STAGE_FLOOR := 50.0 ## karakter figürünün ayağının sahne altından uzaklığı (zemin halkası 2026-11-13 kalktı)

var _close_btn: Button = null
var _balance_label: Label = null
var _list: Container = null ## orta sütunun satırları (geliştirmelerde 20 satır - test sayar)
var _scroll: ScrollContainer = null
var _page_box: VBoxContainer = null
var _confirm_id: String = "" ## "<tür>:<anahtar>" - onay bekleyen alım ("reset" = geliştirmeleri sıfırla)
var _page: String = "char" ## ana sayfa yok: "char" / "weapon" / "pet" / "spirit" / "upgrades"
var _sel: Dictionary = {} ## tür -> seçili anahtar
var _sel_upg: String = "" ## seçili geliştirme (boşsa alınabilir en ucuzu)
var _sel_key: String = "" ## seçili anahtar (harita kimliği; boşsa ilki)
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
	if focus_sid.begins_with("sk:"):
		## Yetenek sekmesinde odak HER ZAMAN seçili sekmeye gider: eski sekmeye geri verilirse focus_entered onu yeniden seçer, fare
		## altındaki sekme mouse_entered ile geri alır -> kare başı sonsuz yeniden kurulum (donma/lag).
		focus_sid = "sk:%d" % _sk_sel
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
					"icon": WeaponCatalog.menu_icon(wk)}
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
		var key_map: String = str(it.get("key_map", ""))
		out.append({"kind": it["kind"], "key": it["key"], "cost": int(it["cost"]), "name": str(info.get("name", it["key"])),
				"desc": str(info.get("desc", "")), "icon": info.get("icon", null),
				"key_map": key_map, "key_count": int(it.get("key_count", 0)), ## anahtar da isteyen içerik (madde 605); key_map "" = yalnız kıymık
				"key_have": MetaProgressScript.keys(key_map) if key_map != "" else 0,
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


## Telefon düğmesi alt yazısı: eksik olan ne (kıymık mı anahtar mı).
func _need_text(it: Dictionary) -> String:
	if _need(it) > 0:
		return Loc.t("%d kıymık eksik") % _need(it)
	return Loc.t("%d anahtar eksik") % _key_short(it)


## Anahtar da isteyen öğe mi? (madde 605)
func _needs_key(it: Dictionary) -> bool:
	return str(it.get("key_map", "")) != ""


## Eksik anahtar adedi (anahtar istemeyen öğede 0).
func _key_short(it: Dictionary) -> int:
	return maxi(0, int(it.get("key_count", 0)) - int(it.get("key_have", 0))) if _needs_key(it) else 0


## Fiyat satırına anahtar parçası: [anahtar simgesi] x3 (yetmiyorsa soluk simge + kırmızı sayı).
func _add_key_price(h: Container, it: Dictionary, fs: int) -> void:
	if not _needs_key(it) or _state(it) == "open":
		return
	var ok: bool = _key_short(it) == 0
	h.add_child(_sp(6))
	h.add_child(KeyIconBox.new(float(fs), str(it["key_map"]), not ok))
	h.add_child(_lbl("x%d" % int(it["key_count"]), fs, C_PRICE if ok else C_BAD))


## Ayrıntıda anahtar notu (açık olmayan, anahtar isteyen öğede), TEK satır: "[simge] 1 / 3 Bataklık Anahtarı". Dikey yer dar (karakter ayrıntısı
## ekranı doldurur, test_soul_shop_passive); "nereden düşer" ANAHTARLAR bölümünde (ve fiyat düğmesinde kırmızı eksik parça).
func _key_note(it: Dictionary, fs: int = 24) -> Control:
	if not _needs_key(it) or it["open"]:
		return null
	var map_id: String = str(it["key_map"])
	var ok: bool = _key_short(it) == 0
	var h := _h(12)
	h.add_child(KeyIconBox.new(32.0, map_id, not ok))
	h.add_child(_lbl("%d / %d %s" % [int(it["key_have"]), int(it["key_count"]), KeyIcon.display_name(map_id)], fs, C_GOOD if ok else C_BAD))
	return h


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
	var fig := n.get("figure") as Control
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
	var fig := n.get("figure") as Control
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
func _sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, r: int = 6, pad: float = -1.0) -> PixelBox:
	var s := PixelBox.new() ## piksel kenar + kabartma (madde 417; StyleBoxFlat ile aynı özellikler)
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
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
	## Yedek: ikonu olmayan geliştirme (2026-11-13'ten beri hepsinin stat_icons'ta ikonu var, madde 661): kodla çizilen simge
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
		_:
			## "no" artık yalnız kıymıktan değil ANAHTARdan da olabilir (madde 605): kırmızı olan eksik olan parça
			var shard_ok: bool = MetaProgressScript.shards() >= int(it["cost"])
			h.add_child(DK.ShardIcon.new(fs * 0.75, not shard_ok))
			h.add_child(_lbl(str(it["cost"]), fs, C_PRICE if shard_ok else C_BAD))
			_add_key_price(h, it, fs)
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
## Anahtar da isteniyorsa (key_map != "") kıymığın yanında [anahtar] x3; kind "off" iken kırmızı olan EKSİK olan parça (shard_ok / key_ok), tamam olan parça sönük.
func _price_btn(prefix: String, cost: int, kind: String = "primary", fs: int = 32, h: float = 64.0, w: float = 0.0,
		key_map: String = "", key_count: int = 0, key_ok: bool = true, shard_ok: bool = true) -> Button:
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
	row.add_child(DK.ShardIcon.new(fs * 0.75, kind == "off" and not shard_ok))
	var cl := _lbl(str(cost), fs, tc if (kind != "off" or not shard_ok) else C_DIM) ## "off" + kıymık yetiyor: eksik olan anahtar, kıymık sönük nötr
	cl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, shadow))
	row.add_child(cl)
	if key_map != "":
		row.add_child(_sp(4))
		row.add_child(KeyIconBox.new(float(fs), key_map, kind == "off" and not key_ok))
		var kl := _lbl("x%d" % key_count, fs, (C_BAD if not key_ok else C_DIM) if kind == "off" else tc)
		kl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, shadow))
		row.add_child(kl)
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
				b = _price_btn("AÇ", int(it["cost"]), "primary", fs, h, 0.0, str(it["key_map"]), int(it["key_count"]))
			b.pressed.connect(_on_buy_pressed.bind(str(it["kind"]), it["key"]))
		_:
			b = _price_btn("AÇ", int(it["cost"]), "off", fs, h, 0.0, str(it["key_map"]), int(it["key_count"]), _key_short(it) == 0,
					MetaProgressScript.shards() >= int(it["cost"]))
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


## Sahne/vitrin içine figür: karakterde tam boy kare (ayağı sahnenin altına yakın durur), diğerlerinde ortada çıplak ikon (eski spot ışığı +
## zemin halkası kalktı, çerçeve de istenmedi - kullanıcı 2026-11-13, madde 656).
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
	if not is_char:
		spr.custom_minimum_size = Vector2(sw, shh)
		_center_in(hold, spr)
		return spr
	var lift: float = floor_off - 8.0
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
	if _page == PAGE_UPGRADES:
		det.add_child(_upg_detail(_upg_selected()))
	elif _page == PAGE_KEYS:
		det.add_child(_key_detail(_key_selected()))
	else:
		det.add_child(_detail(_selected(items, _page)))
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


## Sol sütun: bölümler ana menü öğeleri gibi (FM.item: ikon + başlık + alt yazı), seçili = altın; en altta Geri.
func _section_column(items: Array) -> Control:
	var c := _v(0)
	c.custom_minimum_size.x = FM.COL_W
	for k: String in SECTIONS:
		var n: Vector2i = _counts(items, k)
		var can: int = _can_n(items, k)
		var sub: String = ("%d/%d seviye" if k == PAGE_UPGRADES else "%d/%d açık") % [n.x, n.y]
		if k == PAGE_KEYS:
			sub = Loc.t("%d anahtar") % _keys_total() ## madde 605: kaç anahtar elde (açık/toplam sayılmaz)
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
	var count_text: String = ("%d / %d seviye" if _page == PAGE_UPGRADES else "%d / %d açık") % [n.x, n.y]
	if _page == PAGE_KEYS:
		count_text = Loc.t("%d anahtar") % _keys_total()
	th.add_child(_lbl(count_text, 24, C_DIM))
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
	elif _page == PAGE_KEYS:
		var sel_key: String = _key_selected()
		for id: String in KeyIcon.IDS:
			rows.add_child(_key_row(id, id == sel_key))
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


## Sağ: seçilenin ayrıntısı (spot sahne + altın ad + açıklama + büyük AÇ). Karakterin kendi düzeni var: _char_detail (madde 604).
func _detail(it: Dictionary) -> Control:
	if not it.is_empty() and it["kind"] == MetaProgressScript.CHAR:
		return _char_detail(it)
	var v := _v(14)
	if it.is_empty():
		return v
	v.add_child(_detail_stage(it))
	v.add_child(_gold_title(str(it["name"])))
	v.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, C_DIM))
	v.add_child(_wrap(str(it["desc"]), 32, C_DIM, DETAIL_TEXT_W, 5))
	v.add_child(_sp(0, 0, false, true))
	var key_note: Control = _key_note(it) ## anahtar isteyen kilitli içerik: kaç tane var / nereden düşer (madde 605)
	if key_note != null:
		v.add_child(key_note)
	v.add_child(_buy_btn(it, 40, 76))
	return v


## ---------------------------------------------------------------- KARAKTER AYRINTISI (madde 604, tasarım "A - Yetenek Sekmeleri")
## Kullanıcı (2026-11-12): "dükkanda karakter açıklamaları uzun olduğu için hepsi okunamıyor" - eski düzende yetenek açıklamaları 2-3 satırda
## "..." ile kesiliyordu (en uzunları 400-550 harf). Şimdi: küçük sahne + ad + statlar; altında P Q E R ikon sekmeleri (fare üstü / tık /
## gamepad odağı seçer); seçilenin TAM açıklaması tek koyu kuyuda (m5x7 32). Tür etiketi oyundaki yetenek ipucunun `HudTooltip.make_tag`'i,
## metnin sonundaki "(22sn bekleme)" saat simgesi + süreye, "TEMEL (not):" notu ayrı soluk satıra ayrılır; boyama ve bekleme notu ayıklama
## oyundaki ipucunun kendi fonksiyonları (skill_icon.gd, kopya değil). Sığmazsa kuyu kayar. Prototipler: tools/proto_20261112/ruh_karakter/.
const HudTooltip := preload("res://scripts/hud_tooltip.gd")
const SkillIconScript := preload("res://scripts/skill_icon.gd")
const SK_CD_ICON := preload("res://assets/ui/stat_icons/cooldown_reduction.png") ## 48x48, 24 px çizilir (ipucundaki bekleme ikonu)
const SK_FS := 32
const SK_STAGE := Vector2(210.0, 214.0) ## küçük sahne
const SK_FIGURE_H := 172.0
const SK_FLOOR := 24.0
const SK_ROWS := [["Q", "skill_name", "skill_icon", "skill_desc", "YETENEK"], ["E", "skill2_name", "skill2_icon", "skill2_desc", "TEMEL"],
		["R", "skill3_name", "skill3_icon", "skill3_desc", "ULTİ"]]

var _sk_sel: int = 0 ## seçili sekme (0 = pasif, sonra Q/E/R; pasifsiz karakterde 0 = Q)
var _sk_for: String = "" ## sekmenin ait olduğu karakter (başka karakter seçilince pasife döner)


func _char_detail(it: Dictionary) -> Control:
	var ents: Array = _sk_entries(it)
	if _sk_for != _id(it):
		_sk_for = _id(it)
		_sk_sel = 0
	_sk_sel = clampi(_sk_sel, 0, maxi(0, ents.size() - 1))
	var v := _v(14)
	v.add_child(_sk_head(it))
	var tabs := _h(10)
	for i in ents.size():
		tabs.add_child(_sk_tab(ents[i], i))
	v.add_child(tabs)
	if ents.is_empty():
		v.add_child(_sp(0, 0, false, true))
	else:
		v.add_child(_sk_well(ents[_sk_sel]))
	var key_note: Control = _key_note(it) ## anahtar isteyen kilitli karakter (madde 605)
	if key_note != null:
		v.add_child(key_note)
	v.add_child(_buy_btn(it, 40, 76))
	return v


## Sekme girdileri {key, name, icon, kind, note, cd, body}: pasif (varsa) + Q/E/R.
func _sk_entries(it: Dictionary) -> Array:
	var d: Dictionary = _char_def(it)
	var out: Array = []
	var p: String = str(d.get("passive", ""))
	if p != "":
		var pn: Array = SkillIconScript._split_passive_name(p)
		out.append({"key": "P", "name": str(pn[0]) if str(pn[0]) != "" else Loc.t("Pasif"), "icon": str(d.get("passive_icon", "")),
				"kind": Loc.t("PASİF"), "note": "", "cd": "", "body": _sk_cap_first(str(pn[1]))})
	var si: Control = SkillIconScript.new() ## ipucunun bekleme notu ayıklayıcısı (çok dilli) - ağaca girmez
	for q: Array in SK_ROWS:
		var ks: Array = _sk_kind_split(str(d.get(q[3], "")))
		var body: String = str(ks[2])
		out.append({"key": q[0], "name": str(d.get(q[1], "")), "icon": str(d.get(q[2], "")),
				"kind": str(ks[0]) if str(ks[0]) != "" else Loc.t(str(q[4])), "note": _sk_soft_case(str(ks[1])),
				"cd": _sk_cooldown(si, body), "body": str(si.call("_strip_cooldown_note", body))})
	si.free()
	return out


## "TEMEL (maksimum canının %4'ünü harcar): ..." -> ["TEMEL", "maksimum canının %4'ünü harcar", "..."]. skill_icon._split_kind'den farkı:
## not gövdeye katılmaz, boşluklu tür ("GOLEM FORMU (...)") de tanınır.
static func _sk_kind_split(desc: String) -> Array:
	var re := RegEx.new()
	re.compile("^\\s*((?:\\d+\\.\\s*)?(?:\\p{Lu}+(?: \\p{Lu}+)*|技能|基础|终极|被动|伤害|附魔|进化|特性|成就))\\s*(?:\\(([^)]*)\\))?\\s*:\\s*")
	var m: RegExMatch = re.search(desc)
	if m == null or m.get_string(1).length() <= 1:
		return ["", "", desc]
	return [m.get_string(1), m.get_string(2), desc.substr(m.get_end())]


## Gömülü bekleme notunun süresi ("(22sn bekleme)" -> "22 sn"): sayıyla başlayan parantezlerden ipucunun ayıklayıcısının TAMAMEN sildiği ilki.
func _sk_cooldown(si: Control, body: String) -> String:
	var re := RegEx.new()
	re.compile("\\(\\s*(\\d+(?:[.,]\\d+)?)[^)]*\\)")
	for m: RegExMatch in re.search_all(body):
		if str(si.call("_strip_cooldown_note", m.get_string())) == "":
			return Loc.t("%s sn") % m.get_string(1)
	return ""


## "BASILIP KAPATILABİLİR" -> "Basılıp kapatılabilir" (Türkçe İ/I); zaten küçük harfli not aynen.
static func _sk_soft_case(s: String) -> String:
	if s == "" or s != s.to_upper():
		return s
	var low: String = s.replace("İ", "i").replace("I", "ı").to_lower()
	return low.substr(0, 1).to_upper() + low.substr(1)


## Adı ayrılan pasifin gövdesi küçük harfle başlıyor ("Bıçak Uzmanlığı: yetenek kullanımından...") -> ilk harf büyük (Türkçe i -> İ).
static func _sk_cap_first(s: String) -> String:
	if s == "":
		return s
	var c: String = s.substr(0, 1)
	var up: String = "İ" if c == "i" else ("I" if c == "ı" else c.to_upper())
	return up + s.substr(1)


## Küçük sahne (figür) + sağında ad, tür, statlar.
func _sk_head(it: Dictionary) -> HBoxContainer:
	var h := _h(18)
	var st := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 8)
	st.custom_minimum_size = SK_STAGE
	st.clip_contents = true
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(hold)
	_anim_nodes["stage"] = st
	var spr: TextureRect = _stage_figure(hold, _with_tex(it), SK_FIGURE_H, SK_FLOOR)
	if spr != null:
		_anim_nodes["figure"] = spr
	h.add_child(st)
	var col := _v(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_gold_title(str(it["name"])))
	col.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 32, C_DIM))
	col.add_child(_sp(0, 6))
	col.add_child(_sk_stats(it))
	h.add_child(col)
	return h


## 2x2 stat: simge + değer (32) + altında adı (16).
func _sk_stats(it: Dictionary) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(int(it["key"]))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows: Array = [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Saldırı Gücü", str(int(bs.get("ap", 10)))]]
	var sig: Dictionary = MenuKit.signature_info(int(it["key"])) ## karaktere özel stat (madde 677) 4. hücre
	if not sig.is_empty():
		rows.append([str(sig["icon"]), str(sig["name"]), str(sig["value"])])
	for row: Array in rows:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		var v := _v(-6)
		v.add_child(_lbl(row[2], 32, C_TEXT))
		v.add_child(_lbl(row[1], 16, C_DIM))
		h.add_child(v)
		g.add_child(h)
	return g


## Sekme: ikon + tuş kapağı; seçili = altın kenar. Fare üstü / tık / gamepad odağı seçer.
func _sk_tab(e: Dictionary, i: int) -> PanelContainer:
	var on: bool = i == _sk_sel
	var card := _box(Color(C_ACCENT, 0.12) if on else Color(C_INSET, 0.55), C_ACCENT if on else C_LINE, 8, 3, 6)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ch := _h(10)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	var ip: String = str(e["icon"])
	ch.add_child(_icon(load(ip) as Texture2D if ip != "" and ResourceLoader.exists(ip) else null, 48))
	var kc: PanelContainer = HudTooltip.make_keycap(str(e["key"]))
	kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(kc)
	card.add_child(ch)
	var b: Button = _clickable(card, _on_sk_tab.bind(i), "sk:%d" % i)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new()) ## seçili sekmenin altın kenarı zaten göstergedir; beyaz odak çerçevesi gereksiz
	b.mouse_entered.connect(_on_sk_tab.bind(i))
	b.focus_entered.connect(_on_sk_tab.bind(i))
	return card


func _on_sk_tab(i: int) -> void:
	if i == _sk_sel:
		return
	_sk_sel = i
	_rebuild_list()


## Seçili yeteneğin tam açıklaması: ad + tür + bekleme, ayraç, not (soluk), metin. Sığmazsa kuyu kayar.
func _sk_well(e: Dictionary) -> PanelContainer:
	var well := _box(C_INSET, C_ACCENT_DK, 18, 3, 6)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var wv := _v(10)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hd := _h(12)
	var nm := FM.lbl(str(e["name"]), SK_FS, C_ACCENT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(nm)
	hd.add_child(HudTooltip.make_tag(str(e["kind"])))
	if str(e["cd"]) != "":
		var ic := TextureRect.new()
		ic.texture = SK_CD_ICON
		ic.custom_minimum_size = Vector2(24, 24)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hd.add_child(ic)
		hd.add_child(_lbl(str(e["cd"]), SK_FS, Color(str(HT.INK["cooldown"]))))
	wv.add_child(hd)
	wv.add_child(HudTooltip.make_divider())
	var si: Control = SkillIconScript.new() ## ipucunun boyaması (sayı / hasar / can / kalkan renkleri)
	if str(e["note"]) != "":
		wv.add_child(_sk_rich(str(si.call("_format_lol_style", str(e["note"]))), C_DIM))
	wv.add_child(_sk_rich(str(si.call("_format_lol_style", str(e["body"]))), C_TEXT))
	si.free()
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(wv)
	_tag_sid(sc, "sk_scroll")
	well.add_child(sc)
	return well


func _sk_rich(bb: String, c: Color) -> RichTextLabel:
	var r: RichTextLabel = HudTooltip.make_rich(SK_FS, c)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED ## metin zaten seçili dilde (Characters.get_def), boyalı hâli msgid değil
	r.text = bb
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


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
		v.add_child(_wrap(Loc.t("Harcanan %d kıymıktan %d ücret kesilir, %d geri gelir.") % [
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
	_center_in(hold, _upg_icon(d, box))


## İkonu sahnenin ortasına koyar (stüdyo ışığı / zemin halkası yok; çerçeve denendi, kullanıcı sevmedi - 2026-11-13, madde 656).
func _center_in(hold: Control, c: Control) -> void:
	var half: Vector2 = (c.custom_minimum_size * 0.5).floor()
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -half.x
	c.offset_right = half.x
	c.offset_top = -half.y
	c.offset_bottom = half.y
	hold.add_child(c)


## ---------------------------------------------------------------- sayfa verisi
func _sec_name(kind: String) -> String:
	if kind == PAGE_KEYS:
		return "Anahtarlar"
	return "Geliştirmeler" if kind == PAGE_UPGRADES else str(KIND_TILE.get(kind, kind))


func _sec_title(kind: String) -> String:
	if kind == PAGE_KEYS:
		return "ANAHTARLAR"
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
	if kind == PAGE_KEYS:
		return Vector2i(_keys_total(), KeyIcon.IDS.size())
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


## ---------------------------------------------------------------- ANAHTARLAR (madde 605)
## Elde toplam kaç anahtar (bölüm alt yazısı).
func _keys_total() -> int:
	var n: int = 0
	for id: String in KeyIcon.IDS:
		n += MetaProgressScript.keys(id)
	return n


func _key_selected() -> String:
	return _sel_key if KeyIcon.has_id(_sel_key) else str(KeyIcon.IDS[0])


func _select_key(id: String) -> void:
	var prev: String = _key_selected()
	if prev != id:
		_anim_prev_sel = "key:" + prev
		_anim_dir = 0
	_sel_key = id
	_confirm_id = ""
	_rebuild_list()


## Bu anahtarı isteyen içerik: [{"name", "icon", "count", "open"}] (karakter, sonra evcil; MetaProgress.KEY_COSTS'tan).
func _key_unlocks(id: String) -> Array:
	var out: Array = []
	for kind: String in MetaProgressScript.KINDS:
		for key in (MetaProgressScript.KEY_COSTS.get(kind, {}) as Dictionary).keys():
			var kc: Dictionary = MetaProgressScript.key_cost(kind, key)
			if str(kc.get("map", "")) != id:
				continue
			var info: Dictionary = _info(kind, key)
			out.append({"name": str(info.get("name", key)), "icon": info.get("icon", null), "count": int(kc["count"]),
					"open": MetaProgressScript.is_unlocked(kind, key)})
	return out


func _key_row(id: String, on: bool) -> Control:
	var have: int = MetaProgressScript.keys(id)
	var p := _row_box(on, 64)
	var h := _h(14)
	h.add_child(_marker(on))
	h.add_child(_icon(KeyIcon.texture(id), 48.0, have <= 0))
	var nl := FM.lbl(KeyIcon.display_name(id), 32, C_ACCENT if on else (C_TEXT if have > 0 else C_DIM))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	h.add_child(_lbl("x%d" % have, 32, C_PRICE if have > 0 else C_DIM))
	h.add_child(_sp(10))
	p.add_child(h)
	_clickable(p, _select_key.bind(id), "row:key:" + id)
	_anim_list("rows").append(p)
	_anim_nodes["row:key:" + id] = p
	return p


## Sağ: anahtarın ayrıntısı (spot sahne + ad + harita + elde kaç tane + nereden düşer + neyi açar). Düğme yok (harcama = içeriğin kendi AÇ düğmesi).
func _key_detail(id: String) -> Control:
	var v := _v(14)
	var have: int = MetaProgressScript.keys(id)
	v.add_child(_detail_stage({"kind": PAGE_KEYS, "icon": KeyIcon.texture(id), "open": true, "can": true}))
	v.add_child(_gold_title(KeyIcon.display_name(id)))
	v.add_child(_lbl(Loc.t("Harita: %s") % KeyIcon.map_name(id), 24, C_DIM))
	var sh := _h(12)
	sh.add_child(_lbl("SENDE", 24, C_DIM))
	sh.add_child(_sp(0, 0, true))
	sh.add_child(_lbl("x%d" % have, 40, C_PRICE if have > 0 else C_DIM))
	v.add_child(sh)
	v.add_child(_lbl("NEREDEN DÜŞER", 24, C_DIM))
	var tiers: Array = GameManager.KEYS_PER_BOSS.keys()
	tiers.sort()
	for tier in tiers:
		v.add_child(_lbl(Loc.t("Kademe %d bossu: %d anahtar") % [int(tier), int(GameManager.KEYS_PER_BOSS[tier])], 32, C_TEXT))
	v.add_child(_lbl("NEYİ AÇAR", 24, C_DIM))
	for e: Dictionary in _key_unlocks(id):
		var r := _h(12)
		r.add_child(_icon(e["icon"] as Texture2D, 32.0))
		var nm := _lbl(str(e["name"]), 32, C_GOOD if e["open"] else C_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		if e["open"]:
			r.add_child(Glyph.new(G_CHECK, C_GOOD, 3))
			r.add_child(_lbl("SENDE", 24, C_GOOD))
		else:
			r.add_child(_lbl("x%d" % int(e["count"]), 32, C_PRICE))
		v.add_child(r)
	v.add_child(_sp(0, 0, false, true))
	return v


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
	if kind == PAGE_KEYS:
		return _icon(KeyIcon.texture(KeyIcon.IDS[0]), box)
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
	var st = chip.get_theme_stylebox("panel") ## PixelBox (madde 417)
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
	head.add_child(PK.lbl(Loc.t("%d / %d açık") % [_open_count(list), list.size()], PK.FS_SMALL, DK.C_DIM))
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
		var shard_ok: bool = MetaProgressScript.shards() >= int(it["cost"]) ## "no" artık anahtardan da olabilir (madde 605)
		corner.add_child(DK.ShardIcon.new(22.0, not shard_ok))
		corner.add_child(PK.lbl(str(int(it["cost"])), 24, PK.C_SOUL if shard_ok else DK.C_BAD))
		if _needs_key(it):
			corner.add_child(KeyIconBox.new(22.0, str(it["key_map"]), _key_short(it) > 0))
			corner.add_child(PK.lbl("x%d" % int(it["key_count"]), 24, PK.C_SOUL if _key_short(it) == 0 else DK.C_BAD))
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
	var key_note: Control = _key_note(it, 24) ## anahtar isteyen kilitli içerik: kaç tane var / nereden düşer (madde 605)
	if key_note != null:
		det.add_child(key_note)
	var st: String = _state(it)
	var cost: int = int(it["cost"])
	var b: Button
	match st:
		"open":
			b = PK.big_button("AÇIK", "Seçim ekranında seçebilirsin", "disabled", PK.G_CHECK, 0.0, 144.0)
			b.disabled = true
		"can":
			var asking: bool = _confirm_id == _id(it)
			b = PK.big_button("ONAYLA?" if asking else Loc.t("KİLİDİ AÇ  %d") % cost, Loc.t("Kalan: %d") % (MetaProgressScript.shards() - cost),
					"danger" if asking else "primary", [], 0.0, 144.0)
			b.pressed.connect(_on_buy_pressed.bind(kind, it["key"]))
		_:
			b = PK.big_button(Loc.t("KİLİDİ AÇ  %d") % cost, _need_text(it), "disabled", PK.G_LOCK, 0.0, 144.0)
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
	head.add_child(PK.lbl(Loc.t("%d / %d seviye") % [lv.x, lv.y], PK.FS_SMALL, DK.C_DIM))
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
	det.add_child(PK.lbl(Loc.t("Toplam seviye %d / %d") % [lv.x, lv.y], PK.FS_BODY, DK.C_TEXT))
	var bar := Bar.new(float(lv.x) / float(maxi(1, lv.y)), DK.C_ACCENT, DK.C_INSET, 24.0, 0.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_child(bar)
	det.add_child(DK.sp(0, 0, false, true))
	var reset_info: String = "Sıfırlanacak geliştirme yok."
	if MetaUpgradesScript.can_reset():
		reset_info = Loc.t("Sıfırlarsan harcanan %d kıymıktan %d ücret kesilir, %d geri gelir.") % [
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
