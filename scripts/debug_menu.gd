extends Control
class_name DebugMenu

## Debug modu (kullanıcı isteği, 2026-09-24): chate "baykusseverim" yazılınca (bkz. hud.gd _on_chat_input_submitted) ya da
## ana menüden "Debug Modu" ile başlayınca (bkz. main_menu.gd, GameManager.debug_mode_unlocked) HUD'da "DEBUG" butonu
## belirir (bkz. hud.gd _setup_debug_mode) - bu Node o butona basılınca açılan asıl menü. TAMAMEN kod içinde kurulu.
##
## YENİDEN TASARIM (kullanıcı bildirimi 2026-09-25: "debugmode çok karmaşık tasarıma sahip ve yazılar ufak kullanımı çok
## zor herşeyin yeniden elden geçirilmesi gerekiyor"). Eskiden tek, uzun bir kaydırmalı sütunda 16-22 px yazılı açılır
## listeler + küçük sayı kutuları vardı. Artık:
##  - Solda büyük SEKME butonları (Yaratık / Eşya / Oyuncu / Görev / Hava) - aynı anda tek sayfa görünür.
##  - Açılır liste YOK: her şey tıklanabilir büyük buton ızgarası. Eşya/görev tek tıkla verilir/başlar; yaratıkta tür +
##    kademe (-/+) + hızlı adet butonları, sonra büyük "SPAWNLA".
##  - Yazılar 22-34 px, altta büyük bir durum satırı (ne olduğu/neden olmadığı).
## KAPSAM aynı: yaratık spawnlama, silah/pasif eşya verme, ölümsüzlük, spawn aç/kapa, görev başlatma, saat/hava/yıldırım.
##
## ÇOK OYUNCULU: yaratık spawnlama/görev başlatma/atmosfer host-authoritative (host DEĞİLSEN hiçbir şey yapmaz, durum
## satırı söyler). Ölümsüzlük/eşya verme SADECE bu istemcinin kendi oyuncusunu etkiler.

## Oyunun piksel fontu (m5x7) 16'nın katlarında net ve okunur (bkz. ui_kit.gd FS_BODY=32) - ilk yeni sürümün 22-34 px'i
## gerçek ekranda hâlâ küçük kalıyordu (ekran görüntüsüyle kontrol edildi).
const FS_TITLE := 64
const FS_TAB := 48
const FS_LABEL := 32
const FS_BTN := 48
const FS_STATUS := 32
const TAB_W := 260.0
const MAX_PANEL := Vector2(1780.0, 1000.0)
const TABS := ["Yaratık", "Eşya", "Oyuncu", "Görev", "Hava"]
const COUNT_PRESETS := [1, 5, 10, 25, 50]
const ATMO_TIME_PRESETS := [["Sabah", 20.0], ["Öğle", 150.0], ["İkindi", 290.0], ["Gün batımı", 350.0], ["Gece", 450.0], ["Gün doğumu", 560.0]]
const ATMO_WEATHERS := ["Açık", "Rüzgarlı", "Yağmurlu", "Sağanak"]
const ATMO_FAST_TIME_SCALE := 20.0
const ChestMenuScript := preload("res://scripts/chest_menu.gd")

var _dim: ColorRect = null
var _panel: PanelContainer = null
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _status_label: Label = null

var _creature_buttons: Dictionary = {} ## id -> Button
var _selected_creature: String = ""
var _tier: int = 1
var _tier_label: Label = null
var _count: int = 1
var _count_buttons: Array[Button] = []
var _item_mode: int = 0 ## 0 silah, 1 pasif eşya
var _item_mode_buttons: Array[Button] = []
var _item_grid: GridContainer = null
var _immortal_btn: Button = null
var _spawns_btn: Button = null
var _atmosphere_label: Label = null
var _fast_time_btn: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	## bkz. world_event_banner.gd dosya başı notu - CanvasLayer çocuğu; rect elle kurulur.
	top_level = true

	_dim = ColorRect.new()
	_dim.color = Color(0.1, 0.06, 0.03, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	_panel.theme = UIKit.theme()
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	## Başlık + kapat
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "DEBUG MENÜSÜ"
	UIKit.style_label(title, FS_TITLE, UIKit.C_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := _button("Kapat  X", "red", Vector2(240, 76), FS_TAB)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	## Gövde: solda sekmeler, sağda sayfa
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(TAB_W, 0)
	tabs.add_theme_constant_override("separation", 10)
	body.add_child(tabs)
	var page_holder := PanelContainer.new()
	page_holder.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(page_holder)

	for i in range(TABS.size()):
		var tb := _button(TABS[i], "wood", Vector2(TAB_W, 84), FS_TAB)
		var idx: int = i
		tb.pressed.connect(func() -> void: _show_page(idx))
		tabs.add_child(tb)
		_tab_buttons.append(tb)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page_holder.add_child(scroll)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 16)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		_pages.append(scroll)
		match i:
			0: _build_creature_page(page)
			1: _build_item_page(page)
			2: _build_player_page(page)
			3: _build_mission_page(page)
			4: _build_atmosphere_page(page)

	## Durum satırı
	_status_label = Label.new()
	UIKit.style_label(_status_label, FS_STATUS, UIKit.C_TEXT_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.custom_minimum_size = Vector2(0, 34)
	_status_label.text = "Bir sekme seç."
	root.add_child(_status_label)

	UISound.connect_all_buttons(self)
	_show_page(0)


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp: Vector2 = get_viewport_rect().size
	_dim.size = vp
	var want := Vector2(minf(MAX_PANEL.x, vp.x - 60.0), minf(MAX_PANEL.y, vp.y - 60.0))
	_panel.custom_minimum_size = want
	_panel.size = want
	_panel.position = ((vp - want) * 0.5).floor()
	if Engine.get_process_frames() % 15 == 0:
		_refresh_atmosphere_label()


func open() -> void:
	visible = true
	## HUD'daki DEBUG butonu (kardeş düğüm, sonra eklendiği için) menünün üstüne çiziliyordu - açılınca en öne geç.
	if get_parent():
		get_parent().move_child(self, -1)
	_refresh_toggles()
	_refresh_atmosphere_label()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## ------------------------------------------------------------------ ortak yardımcılar
func _button(text: String, variant: String, min_size: Vector2, font_size: int = FS_BTN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.clip_text = true
	UIKit.style_button(b, variant, false, font_size)
	return b


func _header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	UIKit.style_label(l, FS_LABEL, UIKit.C_ACCENT)
	parent.add_child(l)


func _grid(parent: Control, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g


func _set_status(text: String, good: bool = true) -> void:
	if _status_label:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", UIKit.C_GOOD if good else UIKit.C_BAD)


func _is_client() -> bool:
	return NetworkManager.is_multiplayer_active and not NetworkManager.is_host


func _show_page(idx: int) -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == idx
		UIKit.style_button(_tab_buttons[i], "green" if i == idx else "wood", false, FS_TAB)


static func _pretty(key: String) -> String:
	return key.replace("_", " ").capitalize()


## ------------------------------------------------------------------ Yaratık
func _build_creature_page(page: VBoxContainer) -> void:
	## Üstte ayarlar + büyük SPAWNLA (kaydırmadan hep görünür), altta yaratık ızgarası.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	page.add_child(top)
	var tier_box := VBoxContainer.new()
	top.add_child(tier_box)
	_header(tier_box, "Kademe")
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 10)
	tier_box.add_child(tier_row)
	var minus := _button("-", "dark", Vector2(72, 72), FS_TAB)
	minus.pressed.connect(func() -> void: _set_tier(_tier - 1))
	tier_row.add_child(minus)
	_tier_label = Label.new()
	_tier_label.custom_minimum_size = Vector2(80, 0)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(_tier_label, FS_TITLE, UIKit.C_TEXT)
	tier_row.add_child(_tier_label)
	var plus := _button("+", "dark", Vector2(72, 72), FS_TAB)
	plus.pressed.connect(func() -> void: _set_tier(_tier + 1))
	tier_row.add_child(plus)
	_set_tier(1)

	var count_box := VBoxContainer.new()
	top.add_child(count_box)
	_header(count_box, "Adet")
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	count_box.add_child(count_row)
	for c in COUNT_PRESETS:
		var cb := _button(str(c), "wood", Vector2(84, 72), FS_TAB)
		var n: int = c
		cb.pressed.connect(func() -> void: _set_count(n))
		count_row.add_child(cb)
		_count_buttons.append(cb)
	_set_count(1)

	var spawn := _button("SPAWNLA", "green", Vector2(260, 110), FS_TAB)
	spawn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn.size_flags_vertical = Control.SIZE_SHRINK_END
	spawn.pressed.connect(_on_spawn_pressed)
	top.add_child(spawn)

	_header(page, "Yaratık seç (seçili = yeşil)")
	var grid := _grid(page, 5)
	var spawner: Node = _find_enemy_spawner()
	var ids: Array = spawner.call("get_debug_creature_ids") if spawner else []
	ids.sort()
	for id in ids:
		var b2 := _button(_pretty(String(id)), "wood", Vector2(255, 76))
		var sid: String = String(id)
		b2.pressed.connect(func() -> void: _select_creature(sid))
		grid.add_child(b2)
		_creature_buttons[sid] = b2
	if not ids.is_empty():
		_select_creature(String(ids[0]))


func _select_creature(id: String) -> void:
	_selected_creature = id
	for k in _creature_buttons:
		UIKit.style_button(_creature_buttons[k], "green" if k == id else "wood", false, FS_BTN)


func _set_tier(v: int) -> void:
	_tier = clampi(v, 1, 15)
	if _tier_label:
		_tier_label.text = str(_tier)


func _set_count(v: int) -> void:
	_count = v
	for i in range(_count_buttons.size()):
		UIKit.style_button(_count_buttons[i], "green" if COUNT_PRESETS[i] == v else "wood", false, FS_TAB)


func _find_enemy_spawner() -> Node:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("EnemySpawner") if scene else null


func _find_world_event_manager() -> Node:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("WorldEventManager") if scene else null


func _local_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _on_spawn_pressed() -> void:
	var spawner: Node = _find_enemy_spawner()
	var player: Node2D = _local_player()
	if not spawner or not player or _selected_creature.is_empty():
		return
	if _is_client():
		_set_status("Sadece host yaratık spawnlayabilir.", false)
		return
	var spawned: int = spawner.call("debug_spawn_creature", _selected_creature, _tier, _count, player.global_position)
	_set_status("%d/%d %s spawnlandı (Kademe %d)." % [spawned, _count, _pretty(_selected_creature), _tier], spawned > 0)


## ------------------------------------------------------------------ Eşya / silah
func _build_item_page(page: VBoxContainer) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	page.add_child(mode_row)
	for i in range(2):
		var mb := _button(["Silahlar", "Pasif Eşyalar"][i], "wood", Vector2(340, 76), FS_TAB)
		var m: int = i
		mb.pressed.connect(func() -> void: _set_item_mode(m))
		mode_row.add_child(mb)
		_item_mode_buttons.append(mb)
	_header(page, "Tıkla = anında al")
	_item_grid = _grid(page, 3)
	_set_item_mode(0)


func _set_item_mode(m: int) -> void:
	_item_mode = m
	for i in range(_item_mode_buttons.size()):
		UIKit.style_button(_item_mode_buttons[i], "green" if i == m else "wood", false, FS_TAB)
	for c in _item_grid.get_children():
		c.queue_free()
	var player: Node2D = _local_player()
	var keys: Array = []
	if m == 0:
		keys = player.WEAPON_SCENES_BY_KEY.keys() if player else []
	else:
		keys = Items.DEFS.keys()
	keys.sort()
	for k in keys:
		var key: String = String(k)
		var label: String = ChestMenuScript.WEAPON_NAMES.get(key, _pretty(key)) if m == 0 else String(Items.DEFS[key].get("name", _pretty(key)))
		var b := _button(label, "wood", Vector2(420, 76))
		b.pressed.connect(func() -> void: _give(key))
		_item_grid.add_child(b)
	UISound.connect_all_buttons(_item_grid)


func _give(key: String) -> void:
	var player: Node2D = _local_player()
	if not player:
		return
	if _item_mode == 0:
		## Sahiplik kaydı (GameManager.owned_weapons) silah düğümüyle AYNI sırada tutulmalı (satıcı/sandık akışlarıyla
		## aynı: önce deftere, sonra düğüm) - eskiden debug verilen silah deftere hiç girmiyordu, envanterde görünmüyor
		## ve efsun havuzuna (bkz. enchant_pool.gd) hiç gelmiyordu.
		GameManager.owned_weapons.append({"key": key, "level": 1, "spent": 0})
		var ok: bool = player.call("buy_weapon_copy", key, 1)
		if not ok:
			GameManager.owned_weapons.pop_back()
		_set_status(("'%s' verildi." % ChestMenuScript.WEAPON_NAMES.get(key, key)) if ok else "Silah envanteri dolu (en fazla 5).", ok)
	else:
		## player.buy_item() SADECE stat etkisini uygular - sahiplik kaydı (GameManager.owned_items) çağıran tarafça
		## eklenir (shop_panel.gd::_on_buy_item ile aynı sıra); atlanırsa eşya envanterde görünmez/satılamaz.
		var ok2: bool = player.call("buy_item", key)
		if ok2:
			GameManager.owned_items.append({"key": key, "spent": 0})
		_set_status(("'%s' verildi." % String(Items.DEFS[key].get("name", key))) if ok2 else "Eşya slotu dolu.", ok2)


## ------------------------------------------------------------------ Oyuncu
func _build_player_page(page: VBoxContainer) -> void:
	_header(page, "Sadece bu oyuncu")
	_immortal_btn = _button("", "wood", Vector2(0, 96), FS_TAB)
	_immortal_btn.pressed.connect(func() -> void:
		GameManager.debug_immortal = not GameManager.debug_immortal
		_refresh_toggles())
	page.add_child(_immortal_btn)
	_header(page, "Dünya")
	_spawns_btn = _button("", "wood", Vector2(0, 96), FS_TAB)
	_spawns_btn.pressed.connect(func() -> void:
		GameManager.debug_enemy_spawns_enabled = not GameManager.debug_enemy_spawns_enabled
		_refresh_toggles())
	page.add_child(_spawns_btn)
	## Efsun prototipi testi (2026-09-25): 5 level beklemeden efsun ekranını açmak ve finallerin katalizörlerini almak için.
	_header(page, "Sandık / Efsun (efsun prototipi: Tüftüf, Yay, Topuz)")
	var ench_grid := _grid(page, 2)
	var open_btn := _button("Efsun ekranı aç", "green", Vector2(420, 76))
	open_btn.pressed.connect(func() -> void:
		var main: Node = get_tree().current_scene
		if main and main.has_method("debug_open_enchant_screen"):
			close()
			main.debug_open_enchant_screen())
	ench_grid.add_child(open_btn)
	var cat_btn := _button("Katalizörleri ver", "wood", Vector2(420, 76))
	cat_btn.pressed.connect(_give_enchant_catalysts)
	ench_grid.add_child(cat_btn)
	## Sandık açılış animasyonunu level beklemeden görmek için (2026-09-25): normal = eşya kartı, elit = efsun ekranı.
	for pair: Array in [["Sandık aç", false], ["Elit sandık aç", true]]:
		var chest_btn := _button(str(pair[0]), "wood", Vector2(420, 76))
		var elite: bool = bool(pair[1])
		chest_btn.pressed.connect(func() -> void:
			var m: Node = get_tree().current_scene
			if m and m.has_method("debug_open_chest"):
				close()
				m.debug_open_chest(elite))
		ench_grid.add_child(chest_btn)
	UISound.connect_all_buttons(ench_grid)
	_refresh_toggles()


## Sahip olunan efsunların finalleri için gereken katalizör eşyaları (her birinden 1, zaten varsa verilmez).
func _give_enchant_catalysts() -> void:
	var player: Node2D = _local_player()
	if not player:
		return
	var given: Array = []
	for entry in GameManager.owned_weapons:
		var ench: Dictionary = entry.get("enchant", {})
		if ench.is_empty():
			continue
		var cat: String = str(EnchantDefs.get_def(str(ench.get("id", ""))).get("catalyst", ""))
		if cat == "" or given.has(cat):
			continue
		var owned: bool = false
		for it in GameManager.owned_items:
			if str(it.get("key", "")) == cat:
				owned = true
		if owned:
			continue
		if player.call("buy_item", cat):
			GameManager.owned_items.append({"key": cat, "spent": 0})
			given.append(cat)
	_set_status("Katalizör verildi: %s" % (", ".join(given) if not given.is_empty() else "yok (efsun yok ya da zaten var)"), not given.is_empty())


func _refresh_toggles() -> void:
	if _immortal_btn:
		var on: bool = GameManager.debug_immortal
		_immortal_btn.text = "Ölümsüzlük: %s" % ("AÇIK" if on else "KAPALI")
		UIKit.style_button(_immortal_btn, "green" if on else "wood", false, FS_TAB)
	if _spawns_btn:
		var on2: bool = GameManager.debug_enemy_spawns_enabled
		_spawns_btn.text = "Yaratık spawnları: %s" % ("AÇIK" if on2 else "KAPALI")
		UIKit.style_button(_spawns_btn, "green" if on2 else "red", false, FS_TAB)


## ------------------------------------------------------------------ Görev
func _build_mission_page(page: VBoxContainer) -> void:
	_header(page, "Tıkla = görevi hemen başlat (yanında)")
	var grid := _grid(page, 2)
	var wem: Node = _find_world_event_manager()
	if wem == null:
		return
	var labels: Dictionary = wem.get("MISSION_LABELS")
	var names: Dictionary = wem.get("MISSION_KIND_NAMES")
	for kind in names.keys():
		var kind_name: String = String(names[kind])
		var b := _button(String(labels.get(kind, kind_name)), "wood", Vector2(560, 80), FS_LABEL)
		b.pressed.connect(func() -> void: _start_mission(kind_name))
		grid.add_child(b)


func _start_mission(kind_name: String) -> void:
	var wem: Node = _find_world_event_manager()
	var player: Node2D = _local_player()
	if not wem or not player:
		return
	if _is_client():
		_set_status("Sadece host görev başlatabilir.", false)
		return
	var ok: bool = wem.call("debug_force_start_mission", kind_name, player.global_position)
	_set_status(("Görev başlatıldı: %s" % kind_name) if ok else "Görev başlatılamadı (harita hazır değil?).", ok)


## ------------------------------------------------------------------ Hava (gün-gece + hava durumu, bkz. atmosphere.gd)
func _find_atmosphere() -> Node:
	return get_tree().get_first_node_in_group("atmosphere")


func _build_atmosphere_page(page: VBoxContainer) -> void:
	_atmosphere_label = Label.new()
	UIKit.style_label(_atmosphere_label, FS_LABEL, UIKit.C_TEXT)
	page.add_child(_atmosphere_label)

	_header(page, "Saat")
	var tg := _grid(page, 3)
	for preset in ATMO_TIME_PRESETS:
		var b := _button(String(preset[0]), "wood", Vector2(300, 70), FS_LABEL)
		var t: float = float(preset[1])
		b.pressed.connect(func() -> void: _atmosphere_call("debug_set_time", t))
		tg.add_child(b)

	_header(page, "Hava")
	var wg := _grid(page, 3)
	for i in range(ATMO_WEATHERS.size()):
		var wb := _button(ATMO_WEATHERS[i], "wood", Vector2(300, 70), FS_LABEL)
		var kind: int = i
		wb.pressed.connect(func() -> void: _atmosphere_call("debug_set_weather", kind))
		wg.add_child(wb)
	var sb := _button("Yıldırım düşür", "red", Vector2(300, 70), FS_LABEL)
	sb.pressed.connect(func() -> void: _atmosphere_call("debug_force_strike", null))
	wg.add_child(sb)

	_fast_time_btn = _button("", "wood", Vector2(0, 76), FS_LABEL)
	_fast_time_btn.pressed.connect(func() -> void:
		var atmo: Node = _find_atmosphere()
		var fast: bool = atmo != null and float(atmo.get("debug_time_scale")) > 1.0
		_atmosphere_call("debug_set_time_scale", 1.0 if fast else ATMO_FAST_TIME_SCALE))
	page.add_child(_fast_time_btn)


func _atmosphere_call(method: String, arg: Variant) -> void:
	var atmo: Node = _find_atmosphere()
	if atmo == null:
		_set_status("Atmosfer yok (ana menü / ev içi?).", false)
		return
	var ok: bool = bool(atmo.call(method, arg))
	if not ok:
		_set_status("Sadece host saati/havayı değiştirebilir.", false)
	else:
		_set_status("Tamam.")
	_refresh_atmosphere_label()


func _refresh_atmosphere_label() -> void:
	var atmo: Node = _find_atmosphere()
	if _atmosphere_label:
		_atmosphere_label.text = ("Şu an: " + String(atmo.call("debug_describe"))) if atmo else "Atmosfer yok (ana menü/ev içi test?)"
	if _fast_time_btn:
		var fast: bool = atmo != null and float(atmo.get("debug_time_scale")) > 1.0
		_fast_time_btn.text = "Gün döngüsü x%d hızlı: %s" % [int(ATMO_FAST_TIME_SCALE), "AÇIK" if fast else "KAPALI"]
		UIKit.style_button(_fast_time_btn, "green" if fast else "wood", false, FS_LABEL)
