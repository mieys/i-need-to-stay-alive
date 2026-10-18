extends Node

## Telefon ekranları (madde 276+; kullanıcı onayı 2026-10-18, prototip tools/proto_20261018/mobil_proto.gd S seti): onaylı
## yerleşimlerin ölçüleri. Masaüstü yolları ayrı testlerde.

const MobileUIPath := "res://scripts/mobile_ui.gd"
const W := 2400
const H := 1080


class FakePlayer extends Node2D:
	var level: int = 12
	var luck: float = 0.0
	var max_health: float = 520.0

	func get_upgrade_count(_id: String) -> int:
		return 2


func _phone(on: bool) -> void:
	(load(MobileUIPath) as GDScript).set(&"enabled", on)
	load("res://scripts/fire_menu_kit.gd").use_phone_palette(on)
	if on:
		DisplayServer.window_set_size(Vector2i(W, H))
		get_tree().root.size = Vector2i(W, H)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _settle(sec: float = 0.8) -> void:
	await get_tree().create_timer(sec).timeout
	await get_tree().process_frame


func test_level_up_phone_cards() -> void:
	_phone(true)
	await get_tree().process_frame
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var s: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(s)
	await _settle()
	var cards: Array = s.cards
	var ok_size: bool = true
	var xs: Array = []
	for c: Control in cards:
		var r: Rect2 = c.get_global_rect()
		ok_size = ok_size and absf(r.size.x - 640.0) < 2.0 and absf(r.size.y - 600.0) < 2.0
		xs.append(r.position.x)
	var title_text: String = (s.get_node("Title") as Label).text
	var tier_text: String = (cards[0].get_node("PhTier") as Label).text
	var count_text: String = (cards[0].get_node("PhCount") as Label).text
	var reroll: Rect2 = s.reroll_button.get_global_rect()
	s.queue_free()
	p.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(ok_size, "telefon kartları 640x600 olmalı")
	assert(xs[0] < xs[1] and xs[1] < xs[2], "kartlar yan yana dizilmeli: %s" % str(xs))
	assert(title_text == "SEVİYE 12!", "başlık seviyeyi göstermeli: %s" % title_text)
	assert(tier_text in ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"], "kart şeridinde nadirlik adı: %s" % tier_text)
	assert(count_text == "x2", "kaç kez alındığı şeritte: %s" % count_text)
	## 2026-10-19 (kullanıcı: asimetrileri düzelt): alttaki tek düğme kartların ekseninde ortalı.
	assert(absf(reroll.get_center().x - W * 0.5) < 2.0 and reroll.position.y > 800.0, "Karıştır altta ortada olmalı: %s" % reroll)


func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)


func test_chest_phone_card_shows_own_stats_and_passive() -> void:
	_phone(true)
	await get_tree().process_frame
	var key: String = ""
	for k in Items.KEYS:
		if Items.kademe(str(k)) == Items.KADEME_EPIK and Items.get_def(str(k)).has("passive"):
			key = str(k)
			break
	var c: CanvasLayer = (load("res://scenes/chest_menu.tscn") as PackedScene).instantiate()
	add_child(c)
	c.set("_k", 5.0 / 3.0)
	var col: Control = c.call("_build_phone_card", {"type": "item", "key": key})
	add_child(col)
	await get_tree().process_frame
	var texts: Array = []
	_labels(col, texts)
	var side: Array = []
	_labels(c, side)
	var card: Control = col.get_child(0) as Control
	var w: float = card.custom_minimum_size.x
	col.queue_free()
	c.queue_free()
	_phone(false)
	await get_tree().process_frame
	var passive: String = str(Items.get_def(key)["passive"])
	assert(key != "", "pasifli bir epik eşya bulunmalı")
	assert(texts.has("PASİF") and texts.has(passive), "pasif ayrı kutuda tam metniyle: %s" % str(texts))
	assert(texts.has("EPİK"), "kart şeridinde kademe adı: %s" % str(texts))
	for ln: String in Items.describe(key).split("\n"):
		if ln.strip_edges() != "" and not ln.begins_with("Pasif:"):
			assert(texts.has(ln), "eşyanın kendi stat satırı kartta olmalı: %s" % ln)
	assert(absf(w - 880.0) < 1.0, "telefon kartı 880 px genişliğinde")
	assert(side.has("AL") and side.has("SAT"), "AL / SAT kartın yanında: %s" % str(side))


func _row_ids(s: Control) -> Array:
	var out: Array = []
	for r: Dictionary in s.get("_rows"):
		out.append(r["id"])
	return out


## Ayarlar telefonda: üstte geri + başlık, altta GENEL / GRAFİK / DOKUNMATİK / SES sekmeleri, 120 px satırlar; DOKUNMATİK satırları
## UISound dokunmatik ayarlarına bağlı (değer denenip geri yazılır).
func test_settings_phone_tabs_and_touch_rows() -> void:
	_phone(true)
	await get_tree().process_frame
	var s: Control = (load("res://scripts/settings_screen.gd") as GDScript).new("Geri dön", 0.8)
	add_child(s)
	await _settle(0.3)
	var genel: Array = _row_ids(s)
	var tab: Button = s.find_child("TabDOKUNMATİK", true, false)
	tab.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var touch: Array = _row_ids(s)
	var row_r: Rect2 = (s.find_child("Row_joystick", true, false) as Control).get_global_rect()
	var tab_r: Rect2 = tab.get_global_rect()
	var back: Control = s.find_child("PhoneBack", true, false)
	var back_x: float = back.get_global_rect().position.x if back else 9999.0
	var before: bool = UISound.touch_joystick_fixed
	s.find_child("JoystickChoice", true, false).call("step", 1)
	var after: bool = UISound.touch_joystick_fixed
	UISound.set_touch_joystick_fixed(before)
	var has_keys_tab: bool = s.find_child("TabTUŞLAR", true, false) != null
	s.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(genel == ["shake", "ui_anim", "fps"], "telefon GENEL: %s" % str(genel))
	assert(touch == ["joystick", "button_size", "ui_opacity", "vibration"], "DOKUNMATİK: %s" % str(touch))
	assert(absf(row_r.size.y - 120.0) < 1.0, "satır 120 px: %s" % row_r)
	assert(absf(tab_r.end.y - 1052.0) < 1.0 and tab_r.size.y > 130.0, "sekmeler altta 136 px: %s" % tab_r)
	assert(back_x < 120.0, "sol üstte geri düğmesi: %s" % back_x)
	assert(after != before, "Joystick seçici ayarı değiştirmeli")
	assert(not has_keys_tab, "TUŞLAR telefonda yok")


## Duraklatma telefonda: solda 900x148 öğeler, sağ kenarda KOŞU/TAKIM levhası; Ayarlar telefon kabuğunu açar.
func test_pause_phone_layout() -> void:
	_phone(true)
	await get_tree().process_frame
	var pm: Node = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pm)
	await _settle(0.3)
	var rr: Rect2 = (pm.find_child("ResumeButton", true, false) as Control).get_global_rect()
	var pr: Rect2 = (pm.find_child("RunPanel", true, false) as Control).get_global_rect()
	var title: String = (pm.find_child("Title", true, false) as Label).text
	var stats: Array = []
	for n: String in ["StatSüre", "StatKademe", "StatSeviye", "StatÖldürme", "StatAltın"]:
		stats.append(pm.find_child(n, true, false) != null)
	pm.call("_on_settings_pressed")
	await get_tree().process_frame
	var st: Control = pm.call("get_settings_screen")
	var tabs: bool = st != null and st.find_child("CategoryTabs", true, false) != null
	pm.queue_free()
	get_tree().paused = false
	_phone(false)
	await get_tree().process_frame
	assert(absf(rr.size.x - 900.0) < 1.0 and absf(rr.size.y - 148.0) < 1.0, "öğe 900x148: %s" % rr)
	assert(absf(rr.position.x - 96.0) < 1.0, "öğeler sol kenardan 96")
	assert(absf(pr.end.x - (W - 96.0)) < 1.0 and pr.position.x > rr.end.x, "KOŞU levhası sağda: %s" % pr)
	assert(title == "DURAKLATILDI", "başlık: %s" % title)
	assert(not stats.has(false), "KOŞU satırları: %s" % str(stats))
	assert(tabs, "Ayarlar telefon kabuğuyla açılmalı")


## Oyun bitti telefonda: masaüstü penceresinin (gizli) panosundan okur, düğmeleri onun düğmelerine basar; HASAR SIRASI dolu,
## sekmeler sayfayı değiştirir.
func test_phone_game_over_reads_board_and_presses_pc_buttons() -> void:
	_phone(true)
	await get_tree().process_frame
	var win := Control.new()
	win.name = "Window"
	var vb := VBoxContainer.new()
	vb.name = "VBox"
	win.add_child(vb)
	for n: String in ["Title", "Subtitle"]:
		var l := Label.new()
		l.name = n
		l.text = "OYUN BİTTİ" if n == "Title" else "Tüm takım elendi."
		vb.add_child(l)
	var sb := VBoxContainer.new()
	sb.name = "StatsBox"
	vb.add_child(sb)
	var board: Control = (load("res://scripts/game_over_board.gd") as GDScript).new()
	board.name = "Board"
	sb.add_child(board)
	var row := HBoxContainer.new()
	row.name = "DeathButtonRow"
	vb.add_child(row)
	var pressed: Array = []
	for n: String in ["RestartButton", "BackToMenuButton"]:
		var b := Button.new()
		b.name = n
		var nn: String = n
		b.pressed.connect(func() -> void: pressed.append(nn))
		row.add_child(b)
	add_child(win)
	board.call("set_summary", {"time": 754.0, "tier": 6, "kills": 400, "layer": 0, "level": 14}, {"shards": 42})
	board.call("set_team", {1: {"name": "Sen", "dealt": 9000.0, "taken": 800.0, "kills": 200},
			7: {"name": "Mira", "dealt": 12000.0, "taken": 300.0, "kills": 150}}, {1: 2, 7: 10}, 1)
	var ph: Control = (load("res://scripts/phone_game_over.gd") as GDScript).new()
	ph.set("pc_window", win)
	add_child(ph)
	ph.call("set_final", true)
	await _settle(0.2)
	var ranks: int = (ph.find_child("Ranking", true, false) as Node).get_child_count()
	var mid_texts: Array = []
	_labels(ph.find_child("Content", true, false), mid_texts)
	ph.set("_tab", 1)
	ph.set("_sig", "")
	ph.call("_refresh")
	await get_tree().process_frame
	var dmg_texts: Array = []
	_labels(ph.find_child("Content", true, false), dmg_texts)
	(ph.find_child("PhoneMenu", true, false) as Button).pressed.emit()
	(ph.find_child("PhoneRestart", true, false) as Button).pressed.emit()
	ph.queue_free()
	win.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(ranks == 2, "hasar sırası iki oyuncu: %d" % ranks)
	assert(mid_texts.has("OYUN BİTTİ") and mid_texts.has("Tüm takım elendi.") and mid_texts.has("+42"), "ÖZET: %s" % str(mid_texts))
	assert(mid_texts.has("12:34") and mid_texts.has("VI"), "süre / kademe karoları: %s" % str(mid_texts))
	assert(dmg_texts.has("Mira") and dmg_texts.has("12.000"), "HASAR tablosu: %s" % str(dmg_texts))
	assert(pressed == ["BackToMenuButton", "RestartButton"], "telefon düğmeleri masaüstü düğmelerine basmalı: %s" % str(pressed))


## ------------------------------------------------------------------ menüler (madde 279)
## Ana menü telefonda: 5 öğe (ÇIKIŞ yok), sağ altta Son seçim + HIZLI BAŞLA, sağ üstte kıymık; masaüstü tabelası kurulmaz.
func test_main_menu_phone_layout() -> void:
	_phone(true)
	await get_tree().process_frame
	var mm: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(mm)
	await _settle(0.3)
	## Not: serbest bırakılan nesne == null sayılır - sonuçlar queue_free'den ÖNCE değere çevrilir.
	var root: Control = mm.find_child("PhoneMenu", true, false)
	var has_root: bool = root != null
	var items: int = (root.find_child("MenuPanel", true, false) as Node).get_child_count() if root else 0
	var quick: Control = mm.find_child("QuickStart", true, false)
	var qr: Rect2 = quick.get_global_rect() if quick else Rect2()
	var card: bool = mm.find_child("LastPick", true, false) != null
	var chip: bool = mm.find_child("ShardChip", true, false) != null
	mm.call("_on_settings_pressed")
	await get_tree().process_frame
	var hidden: bool = has_root and not root.visible
	mm.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(has_root, "telefon menüsü kurulmalı")
	assert(items == 5, "5 öğe (ÇIKIŞ yok): %d" % items)
	assert(absf(qr.end.x - (W - 96.0)) < 2.0 and absf(qr.end.y - 1052.0) < 2.0, "HIZLI BAŞLA sağ altta: %s" % qr)
	assert(card and chip, "Son seçim kartı + kıymık çipi")
	assert(hidden, "ayarlar açılınca telefon menüsü gizlenmeli")


func test_records_phone_layout() -> void:
	_phone(true)
	await get_tree().process_frame
	var rs: Control = (load("res://scripts/records_screen.gd") as GDScript).new()
	add_child(rs)
	await _settle(0.2)
	var rows: int = 0
	for k: String in ["time", "tier", "kills", "layer", "victory_time"]:
		if rs.find_child("Rec_" + k, true, false) != null:
			rows += 1
	var tabs: Array = (rs.get("_ph") as Dictionary).get("tabs", [])
	(tabs[1] as Button).pressed.emit()
	await get_tree().process_frame
	var ach_page: bool = rs.find_child("Rec_time", true, false) == null
	rs.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(rows == 5, "EN İYİ: 5 rekor satırı: %d" % rows)
	assert(tabs.size() == 2 and ach_page, "BAŞARIM sekmesi sayfayı değiştirmeli")


func test_room_browser_phone_rows_and_password() -> void:
	_phone(true)
	await get_tree().process_frame
	var rb: Control = (load("res://scenes/room_browser.tscn") as PackedScene).instantiate()
	add_child(rb)
	await get_tree().process_frame
	rb.set("_online_rooms", [
		{"host_id": "h1", "host_name": "Ali", "room_name": "Gece avı", "players": 2, "max_players": 4, "locked": true, "in_game": false},
		{"host_id": "h2", "host_name": "Veli", "room_name": "Dolu oda", "players": 3, "max_players": 3, "locked": false, "in_game": false},
	])
	rb.set("_ph_tab_online", true)
	rb.call("_rebuild_list")
	var list: VBoxContainer = rb.get("_list")
	var n_rows: int = list.get_child_count()
	var full_closed: bool = false
	for c in list.get_children():
		if str((c as Control).tooltip_text).begins_with("Dolu oda"):
			var fj: Button = c.find_child("Join", true, false)
			full_closed = fj != null and fj.disabled
	var locked: Dictionary = {}
	for r in rb.call("_rooms"):
		if r["room_name"] == "Gece avı":
			locked = r
	rb.call("_on_room_pressed", locked)
	var with_pw: int = list.get_child_count()
	var pw: LineEdit = rb.get("_pw_input")
	var pw_secret: bool = pw != null and pw.secret
	var actions: bool = rb.find_child("QuickJoin", true, false) != null and rb.find_child("CreateRoom", true, false) != null
	rb.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(n_rows == 2, "iki oda satırı: %d" % n_rows)
	assert(full_closed, "dolu odanın KATIL'ı kapalı")
	assert(with_pw == 3 and pw_secret, "şifreli odaya basınca altına gizli şifre satırı")
	assert(actions, "HIZLI KATIL + ODA KUR")


func test_character_select_phone_faces_and_tabs() -> void:
	_phone(true)
	await get_tree().process_frame
	var cs: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(cs)
	await _settle(0.3)
	var desk: Control = cs.get("_desk")
	var cards: Dictionary = desk.get("_cards")
	var face_ok: bool = true
	for id in cards:
		var b: Button = cards[id]["btn"]
		face_ok = face_ok and absf(b.custom_minimum_size.x - 196.0) < 1.0
	var preview: Control = desk.get("_preview")
	var prev_k: int = int(preview.get("pixel_scale")) if preview else 0
	var tabs: Array = (desk.get("_ph") as Dictionary).get("tabs", [])
	(tabs[2] as Button).pressed.emit() ## SİLAH
	await get_tree().process_frame
	var opts: int = (desk.get("_tab_grid") as GridContainer).get_child_count()
	var start: Button = desk.get("_start_btn")
	var start_h: float = start.custom_minimum_size.y if start else 0.0
	cs.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(cards.size() == Characters.DEFS.size() and face_ok, "her karakterin 196 px yüz kartı")
	assert(prev_k == 6, "sağda boydan önizleme (6x): %d" % prev_k)
	assert(tabs.size() == 4 and opts > 0, "ray 4 sekme (tek oyunculu), SİLAH ızgarası dolu: %d" % opts)
	assert(start_h >= 144.0, "BAŞLAT altta iri")


func test_multiplayer_select_phone_has_team_tab() -> void:
	_phone(true)
	await get_tree().process_frame
	var d: Control = (load("res://scripts/lobby_select_desktop.gd") as GDScript).new()
	add_child(d)
	d.call("build")
	await get_tree().process_frame
	var tabs: Array = (d.get("_ph") as Dictionary).get("tabs", [])
	var has_team: bool = (d.get("_ph_pages") as Dictionary).get("team") != null
	var has_chat: bool = d.get("_chat_input") != null
	var n_tabs: int = tabs.size()
	d.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(n_tabs == 5 and has_team, "çok oyunculu: TAKIM + 4 sekme")
	assert(has_chat, "takım sayfasında sohbet")


func test_soul_shop_phone_pages() -> void:
	_phone(true)
	await get_tree().process_frame
	var ss: CanvasLayer = (load("res://scripts/soul_shop_screen.gd") as GDScript).new()
	add_child(ss)
	await _settle(0.2)
	var has_buy: bool = ss.find_child("BuyButton", true, false) != null
	var tabs: Array = (ss.get("_ph") as Dictionary).get("tabs", [])
	var n_tabs: int = tabs.size()
	(tabs[4] as Button).pressed.emit() ## GELİŞTİR
	await get_tree().process_frame
	var has_reset: bool = ss.find_child("ResetButton", true, false) != null
	var page: String = str(ss.get("_page"))
	ss.queue_free()
	_phone(false)
	await get_tree().process_frame
	assert(n_tabs == 5, "ray 5 sekme")
	assert(has_buy, "kategori sayfasında KİLİDİ AÇ / AÇIK düğmesi")
	assert(page == "upgrades" and has_reset, "GELİŞTİR sayfası + sıfırlama")
