extends Control
class_name DebugMenu

## Debug modu (kullanıcı isteği, 2026-09-24): chate "baykusseverim" yazılınca (bkz. hud.gd
## _on_chat_input_submitted) ya da ana menüden "Debug Modu" ile başlayınca (bkz. main_menu.gd,
## GameManager.debug_mode_unlocked) HUD'da küçük bir "DEBUG" butonu belirir (bkz. hud.gd
## _create_debug_button) - bu Node o butona basılınca açılan asıl menü. TAMAMEN kod içinde
## kurulu (bu oturumdaki world_event_banner.gd gibi diğer script-yapımı panellerle AYNI
## yaklaşım), yeni bir .tscn YOK.
##
## KAPSAM (kullanıcı isteği): (1) istediğimiz yaratığı istediğimiz kadar spawnlama, (2) istediğimiz
## itemi (silah/pasif eşya) alma, (3) ölümsüzlük, (4) istediğimiz görevi başlatma, (5) yaratık
## spawnlarını aç/kapa. Kalkan verme BİLEREK yok (seviye/mod sistemi bu debug aracına göre
## orantısız karmaşık - istenirse ayrı bir görev olarak eklenir).
##
## ÇOK OYUNCULU: yaratık spawnlama/görev başlatma host-authoritative (bkz. enemy_spawner.gd
## debug_spawn_creature/world_event_manager.gd debug_force_start_mission notları - host
## DEĞİLSEN bu ikisi sessizce hiçbir şey yapmaz). Ölümsüzlük/item verme SADECE bu istemcinin
## KENDİ oyuncusunu etkiler - bu bilerek böyle, "hile" başka oyunculara sızmıyor.

const PANEL_W := 520.0
## DÜZELTME: proje genelindeki varsayılan tema fontu UIKit.FS_BODY=32 - bu menüdeki
## HER kontrol (Label/Button/OptionButton/CheckBox) bunu override ETMEDEN kullanınca
## her satır ~90-140px'e çıkıp panel 1300px+ yükseklikte bile taşıyordu (bkz.
## debug_menu.png - "Item / Silah Ver" panelin dışına taşmıştı). keybind_menu.gd'nin
## AYNI (satır etiketi 20/buton 18) deseniyle kompakt tut.
const FONT_ROW := 20
const FONT_CTRL := 18
const FONT_HEADER := 22


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	## bkz. world_event_banner.gd dosya başı notu - main.gd'de kurulan bir CanvasLayer'ın
	## çocuğu olacağı için anchor/preset'e güvenmiyoruz, kendi rect'imizi elle kuruyoruz.
	top_level = true

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_dim = dim

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	## 2026-09-24: oyun içi bej kit teması (koyu yazı, kit butonları/giriş kutuları/açılır liste).
	panel.theme = UIKit.theme()
	add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 22)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_W, 460.0)
	scroll.clip_contents = true ## içerik bu yüksekliği aşarsa GÖRÜNMEZ TAŞMAK yerine kaydırılsın
	margin.add_child(scroll)
	_scroll = scroll

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG MENÜSÜ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIKit.C_TEXT)
	vbox.add_child(title)

	_build_spawn_section(vbox)
	vbox.add_child(HSeparator.new())
	_build_item_section(vbox)
	vbox.add_child(HSeparator.new())
	_build_toggle_section(vbox)
	vbox.add_child(HSeparator.new())
	_build_mission_section(vbox)

	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.add_theme_font_size_override("font_size", FONT_HEADER)
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self)


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp: Vector2 = get_viewport_rect().size
	_dim.size = vp
	## DÜZELTME: sabit 460px yükseklik 2560x1440'ta bile içeriğin (spawn + item + toggle +
	## görev bölümleri) tamamını sığdırmıyordu, "İtem / Silah Ver" başlığı panelin ALT
	## kenarının DIŞINA taşıp harita zemininin üstüne çiziliyordu (bkz. debug_menu.png).
	## Ekran boyu ne olursa olsun MÜMKÜN OLDUĞUNCA kaydırma GEREKMESİN diye scroll alanını
	## viewport'a göre dinamik büyüt; küçük ekranlarda güvenlik ağı olarak yine de kayar.
	if _scroll:
		_scroll.custom_minimum_size.y = max(vp.y - 200.0, 300.0)
	_panel.position = (vp - _panel.size) * 0.5


var _dim: ColorRect = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _creature_option: OptionButton = null
var _tier_spin: SpinBox = null
var _count_spin: SpinBox = null
var _give_type_option: OptionButton = null
var _give_key_option: OptionButton = null
var _immortal_check: CheckBox = null
var _spawns_check: CheckBox = null
var _mission_option: OptionButton = null
var _status_label: Label = null


func open() -> void:
	visible = true
	if _spawns_check:
		_spawns_check.button_pressed = GameManager.debug_enemy_spawns_enabled
	if _immortal_check:
		_immortal_check.button_pressed = GameManager.debug_immortal


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## DÜZELTME (kullanıcı bildirimi, gerçek ekran görüntüsü: "açılan seçenekler de çok
## kötü kocamanlar") - OptionButton'ın kendi metnine font_size override etmek sadece
## KAPALI haldeki görünümünü küçültüyor, tıklayınca açılan PopupMenu AYRI bir kontrol
## ve varsayılan (32px) tema fontunu kullanmaya devam ediyordu. Her OptionButton için
## popup'ı da ayrıca küçült.
func _style_dropdown(ob: OptionButton) -> void:
	ob.clip_text = true ## uzun metin (görev adı/silah anahtarı) satırı/butonu dışarı İTMESİN, "…" ile kessin
	ob.get_popup().add_theme_font_size_override("font_size", FONT_CTRL)


func _row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.add_theme_color_override("font_color", UIKit.C_TEXT)
	lbl.add_theme_font_size_override("font_size", FONT_ROW)
	row.add_child(lbl)
	return row


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


## ------------------------------------------------------------------ Yaratık spawnlama
func _build_spawn_section(vbox: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Yaratık Spawnla"
	header.add_theme_color_override("font_color", UIKit.C_ACCENT)
	header.add_theme_font_size_override("font_size", FONT_HEADER)
	vbox.add_child(header)

	var row := _row(vbox, "Tür")
	_creature_option = OptionButton.new()
	_creature_option.custom_minimum_size = Vector2(200, 40)
	_creature_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creature_option.add_theme_font_size_override("font_size", FONT_CTRL)
	var spawner: Node = _find_enemy_spawner()
	var ids: Array = spawner.call("get_debug_creature_ids") if spawner else []
	ids.sort()
	for id in ids:
		_creature_option.add_item(String(id))
	_style_dropdown(_creature_option)
	row.add_child(_creature_option)

	## DÜZELTME (kullanıcı bildirimi): "Kademe / Adet" TEK satırda İKİ etiketsiz
	## SpinBox olunca hangisinin hangisi olduğu ANLAŞILMIYORDU - artık her biri kendi
	## etiketli satırında (bkz. dosya başındaki _row() deseni, menüdeki HER ALAN AYNI kural).
	var row_tier := _row(vbox, "Kademe")
	_tier_spin = SpinBox.new()
	_tier_spin.min_value = 1
	_tier_spin.max_value = 15
	_tier_spin.value = 1
	_tier_spin.custom_minimum_size = Vector2(90, 40)
	_tier_spin.get_line_edit().add_theme_font_size_override("font_size", FONT_CTRL)
	row_tier.add_child(_tier_spin)

	var row_count := _row(vbox, "Adet")
	_count_spin = SpinBox.new()
	_count_spin.min_value = 1
	_count_spin.max_value = 100
	_count_spin.value = 1
	_count_spin.custom_minimum_size = Vector2(90, 40)
	_count_spin.get_line_edit().add_theme_font_size_override("font_size", FONT_CTRL)
	row_count.add_child(_count_spin)
	var spawn_btn := Button.new()
	spawn_btn.text = "Spawnla"
	spawn_btn.custom_minimum_size = Vector2(120, 40)
	spawn_btn.add_theme_font_size_override("font_size", FONT_CTRL)
	spawn_btn.pressed.connect(_on_spawn_pressed)
	row_count.add_child(spawn_btn)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(UIKit.INK["shield"]))
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)


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
	if not spawner or not player or _creature_option.item_count == 0:
		return
	var id: String = _creature_option.get_item_text(_creature_option.selected)
	var tier: int = int(_tier_spin.value)
	var count: int = int(_count_spin.value)
	var spawned: int = spawner.call("debug_spawn_creature", id, tier, count, player.global_position)
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_set_status("Sadece host yaratık spawnlayabilir.")
	else:
		_set_status("%d/%d %s spawnlandı (Kademe %d)." % [spawned, count, id, tier])


## ------------------------------------------------------------------ Item/silah verme
func _build_item_section(vbox: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Item / Silah Ver"
	header.add_theme_color_override("font_color", UIKit.C_ACCENT)
	header.add_theme_font_size_override("font_size", FONT_HEADER)
	vbox.add_child(header)

	var row := _row(vbox, "Tür")
	_give_type_option = OptionButton.new()
	_give_type_option.custom_minimum_size = Vector2(0, 40)
	_give_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_give_type_option.add_theme_font_size_override("font_size", FONT_CTRL)
	_give_type_option.add_item("Silah")
	_give_type_option.add_item("Pasif Eşya")
	_give_type_option.item_selected.connect(_on_give_type_selected)
	_style_dropdown(_give_type_option)
	row.add_child(_give_type_option)

	## DÜZELTME (kullanıcı bildirimi: "silah alma butonu da yok sadece seçilebiliyor") -
	## bazı silah anahtarları ("lightning_staff" gibi) OptionButton'ın doğal genişliğini
	## satırın TAMAMINI kaplayacak kadar büyütüp "Ver" butonunu panel dışına/kırpılan
	## alana itiyordu. size_flags_horizontal=EXPAND_FILL + clip_text (bkz. _style_dropdown)
	## OptionButton'ın metni "…" ile KISALTMASINI sağlıyor, butona her zaman sabit yer kalıyor.
	var row2 := _row(vbox, "Anahtar")
	_give_key_option = OptionButton.new()
	_give_key_option.custom_minimum_size = Vector2(180, 40)
	_give_key_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_give_key_option.add_theme_font_size_override("font_size", FONT_CTRL)
	_style_dropdown(_give_key_option)
	row2.add_child(_give_key_option)
	var give_btn := Button.new()
	give_btn.text = "Ver"
	give_btn.custom_minimum_size = Vector2(90, 40)
	give_btn.add_theme_font_size_override("font_size", FONT_CTRL)
	give_btn.pressed.connect(_on_give_pressed)
	row2.add_child(give_btn)

	_populate_give_keys(0)


func _on_give_type_selected(index: int) -> void:
	_populate_give_keys(index)


func _populate_give_keys(type_index: int) -> void:
	_give_key_option.clear()
	var player: Node2D = _local_player()
	if type_index == 0:
		var keys: Array = player.WEAPON_SCENES_BY_KEY.keys() if player else []
		keys.sort()
		for k in keys:
			_give_key_option.add_item(String(k))
	else:
		var keys: Array = Items.DEFS.keys()
		keys.sort()
		for k in keys:
			_give_key_option.add_item(String(k))


func _on_give_pressed() -> void:
	var player: Node2D = _local_player()
	if not player or _give_key_option.item_count == 0:
		return
	var key: String = _give_key_option.get_item_text(_give_key_option.selected)
	if _give_type_option.selected == 0:
		var ok: bool = player.call("buy_weapon_copy", key, 1)
		_set_status(("'%s' silahı verildi." % key) if ok else "Silah envanteri dolu (en fazla 5).")
	else:
		## DÜZELTME: player.buy_item() SADECE stat etkisini uygular - "sahiplik" kaydı
		## (GameManager.owned_items) shop_panel.gd::_on_buy_item'da AYRICA, çağıran tarafından
		## eklenir (bkz. o dosyadaki BİREBİR AYNI sıra). Bunu atlarsam eşya GERÇEKTEN
		## uygulanır ama envanterde hiç görünmez/sonradan satılamaz - headless testte
		## "items after=0" olarak yakalandı.
		var ok2: bool = player.call("buy_item", key)
		if ok2:
			GameManager.owned_items.append({"key": key, "spent": 0})
		_set_status(("'%s' eşyası verildi." % key) if ok2 else "Eşya slotu dolu.")


## ------------------------------------------------------------------ Ölümsüzlük / spawn aç-kapa
func _build_toggle_section(vbox: VBoxContainer) -> void:
	_immortal_check = CheckBox.new()
	_immortal_check.text = "Ölümsüzlük (sadece bu oyuncu)"
	_immortal_check.add_theme_color_override("font_color", UIKit.C_TEXT)
	_immortal_check.add_theme_font_size_override("font_size", FONT_CTRL)
	_immortal_check.toggled.connect(func(v: bool) -> void: GameManager.debug_immortal = v)
	vbox.add_child(_immortal_check)

	_spawns_check = CheckBox.new()
	_spawns_check.text = "Yaratık spawnları açık"
	_spawns_check.add_theme_color_override("font_color", UIKit.C_TEXT)
	_spawns_check.add_theme_font_size_override("font_size", FONT_CTRL)
	_spawns_check.toggled.connect(func(v: bool) -> void: GameManager.debug_enemy_spawns_enabled = v)
	vbox.add_child(_spawns_check)


## ------------------------------------------------------------------ Görev başlatma
func _build_mission_section(vbox: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Görev Başlat"
	header.add_theme_color_override("font_color", UIKit.C_ACCENT)
	header.add_theme_font_size_override("font_size", FONT_HEADER)
	vbox.add_child(header)

	var row := _row(vbox, "Görev")
	_mission_option = OptionButton.new()
	_mission_option.custom_minimum_size = Vector2(150, 40)
	_mission_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_option.add_theme_font_size_override("font_size", FONT_CTRL)
	var wem: Node = _find_world_event_manager()
	if wem:
		var labels: Dictionary = wem.get("MISSION_LABELS")
		var names: Dictionary = wem.get("MISSION_KIND_NAMES")
		for kind in names.keys():
			_mission_option.add_item(String(labels.get(kind, names[kind])))
			_mission_option.set_item_metadata(_mission_option.item_count - 1, names[kind])
	_style_dropdown(_mission_option)
	row.add_child(_mission_option)
	var start_btn := Button.new()
	start_btn.text = "Başlat"
	start_btn.custom_minimum_size = Vector2(110, 40)
	start_btn.add_theme_font_size_override("font_size", FONT_CTRL)
	start_btn.pressed.connect(_on_start_mission_pressed)
	row.add_child(start_btn)


func _on_start_mission_pressed() -> void:
	var wem: Node = _find_world_event_manager()
	var player: Node2D = _local_player()
	if not wem or not player or _mission_option.item_count == 0:
		return
	var kind_name: String = String(_mission_option.get_item_metadata(_mission_option.selected))
	var ok: bool = wem.call("debug_force_start_mission", kind_name, player.global_position)
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_set_status("Sadece host görev başlatabilir.")
	else:
		_set_status(("Görev başlatıldı: %s" % kind_name) if ok else "Görev başlatılamadı (harita hazır değil?).")
