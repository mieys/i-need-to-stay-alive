extends CanvasLayer
class_name MiniShopScreen

## Kullanıcı isteği: "Oyunda her 3 dakikada bir mini dükkan açılsın (dükkan
## level atlama aralarında oyun durduğu zaman aktifleşecek). Bu mini
## dükkanda dükkandaki 'ekstralar' kategorisindeki eşyalardan rasgele 3 tane
## seçenek görünecek (kart sistemi gibi) ayrıca üstte sahip olduğumuz
## silahlar için geliştirme butonları olacak."
##
## Tetikleme: GameManager.mini_shop_due (bkz. game_manager.gd _process,
## MINI_SHOP_INTERVAL) -> main.gd _on_mini_shop_due/_show_mini_shop_screen.
## Kart görsel şablonu chest_menu.gd::_build_card ile AYNI aile - ama:
##   1) Kartlar ÜCRETSİZ DEĞİL, gerçek GameManager.gold harcar.
##   2) Üstte sahip olunan silah/kalkan için geliştirme satırları var.
##   3) Mandatory pick YOK - istediği kadar (0 dahil) alıp "Kapat"a basılabilir.
## Fiyatlandırma shop_panel.gd'nin (artık `class_name ShopPanel` + static
## fonksiyonlar, bkz. orada) AYNI _upgrade_cost/_item_cost formüllerinden -
## burada ikinci bir kopya YOK, tek kaynak.
## Multiplayer: her oyuncu KENDİ ekranında KENDİ rasgele kartlarını görür
## (para/eşya kişisel - bkz. items.gd/shop_panel.gd dosya başı notları),
## sadece "ne zaman herkes kapattı, oyun devam etsin" senkronize (bkz.
## network_manager.gd "MİNİ DÜKKAN SENKRONİZASYONU" bloğu, level_up_screen.gd
## ile AYNI desen).

signal closed
## Kullanıcı isteği: "dükkandan diriltme satın alınabilmeli, ölü oyuncular
## diriltme satın alarak canlanabilmeli" - main.gd bu sinyali dinleyip
## player.revive_from_permadeath() + kendi izleyici modu/ölüm ekranı
## temizliğini yapıyor (bkz. main.gd _revive_local_player).
signal revive_purchased

const CARD_SLOT_COUNT := 3
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)
const PAL_BG := Color(0.18, 0.13, 0.08, 0.97)
## Kalıcı ölümden dönüş - tek seferlik, ağır bir satın alma olduğu için
## diğer eşyalardan belirgin şekilde pahalı.
const REVIVE_COST := 500

## Kullanıcı isteği: "dükkanda satılan rasgele eşyalar altın karşılığında
## rerollanabilmeli (her rerollamada bedeli artacak)".
const MINI_SHOP_REROLL_BASE_COST := 20
const MINI_SHOP_REROLL_INCREMENT := 15

## Kullanıcı isteği: "bir oyuncu birşey aldıktan sonra tıpkı diğer kart
## seçim ekranlarında olduğu gibi 25 saniyelik bir geri sayım başlamalı,
## geri sayım bitince dükkan otomatik kapanmalı".
const MINI_SHOP_AUTO_CLOSE_TIME := 25.0

var _player: Node = null
var _has_closed_locally: bool = false
var _cards_container: HBoxContainer = null
var _upgrade_container: HBoxContainer = null
var _countdown_label: Label = null
var _gold_label: Label = null
var _main_vbox: VBoxContainer = null
var _waiting_label: Label = null
var _close_btn: Button = null
var _reroll_button: Button = null
var _revive_row: PanelContainer = null
var _revive_button: Button = null

## Kullanıcı isteği: "bir eşyayı geliştirince rasgele satılan eşyalar
## değişiyor" (istenmiyor) - hangi 3 anahtarın gösterildiği artık burada
## saklanıyor, satın alma/geliştirme sonrası sadece bu anahtarlardan kart
## NODE'ları yeniden kurulur (_rebuild_card_nodes), havuz TEKRAR karıştırılmaz.
## Sadece explicit reroll (_on_reroll_extras_pressed) ve ilk açılış
## (_build_cards) yeni bir karıştırma yapar.
var _current_card_keys: Array = []
var _reroll_cost: int = MINI_SHOP_REROLL_BASE_COST


## bkz. _process - ilk satın alma/geliştirmeden sonra başlayan, ağa bağımsız
## (her oyuncu zaten kendi ekranını yönetiyor) yerel 25sn sayaç.
var _local_close_timer_active: bool = false
var _local_close_remaining: float = MINI_SHOP_AUTO_CLOSE_TIME
var _local_countdown_label: Label = null


func setup(player: Node) -> void:
	_player = player
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reroll_cost = MINI_SHOP_REROLL_BASE_COST
	_build_ui()
	_refresh_upgrade_rows()
	_build_cards()
	_update_gold_label()
	_refresh_revive_row()
	if NetworkManager.is_multiplayer_active:
		NetworkManager.multiplayer_mini_shop_timer_tick.connect(_on_countdown_tick)
		NetworkManager.multiplayer_mini_shop_all_closed.connect(_on_all_closed)


func _process(delta: float) -> void:
	if not _local_close_timer_active or _has_closed_locally:
		return
	_local_close_remaining -= delta
	if _local_countdown_label:
		_local_countdown_label.visible = true
		_local_countdown_label.text = "Otomatik kapanıyor: %ds" % int(ceil(max(0.0, _local_close_remaining)))
	if _local_close_remaining <= 0.0:
		_local_close_timer_active = false
		_on_close_pressed()


func _start_local_close_timer_if_needed() -> void:
	if not _local_close_timer_active:
		_local_close_timer_active = true
		_local_close_remaining = MINI_SHOP_AUTO_CLOSE_TIME


func _build_ui() -> void:

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var outer := PanelContainer.new()
	## Kullanıcı isteği: "mini dükkan daha geniş olmalı" - sabit bir minimum
	## genişlik, içerik (kartlar/geliştirme satırları) büyüdükçe de otomatik
	## genişleyebilsin diye PanelContainer'ın kendi auto-size'ına ek olarak.
	outer.custom_minimum_size = Vector2(900, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAL_BG
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = PAL_ACCENT
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	outer.add_theme_stylebox_override("panel", sb)
	center.add_child(outer)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 14)
	outer.add_child(_main_vbox)

	var title := Label.new()
	title.text = "MİNİ DÜKKAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", PAL_ACCENT)
	_main_vbox.add_child(title)

	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 20)
	_countdown_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
	_countdown_label.visible = false
	_main_vbox.add_child(_countdown_label)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	_main_vbox.add_child(_gold_label)

	## Kullanıcı isteği: "dükkandan diriltme satın alınabilmeli" - sadece
	## oyuncu kalıcı olarak ölmüşken (bkz. _refresh_revive_row, setup()'ta
	## ve satın alma sonrası çağrılır) görünür, aksi halde gizli.
	_revive_row = PanelContainer.new()
	_revive_row.visible = false
	var revive_sb := StyleBoxFlat.new()
	revive_sb.bg_color = Color(0.35, 0.1, 0.1, 1.0)
	revive_sb.border_width_left = 3
	revive_sb.border_width_top = 3
	revive_sb.border_width_right = 3
	revive_sb.border_width_bottom = 3
	revive_sb.border_color = Color(0.9, 0.3, 0.3, 1.0)
	revive_sb.corner_radius_top_left = 10
	revive_sb.corner_radius_top_right = 10
	revive_sb.corner_radius_bottom_right = 10
	revive_sb.corner_radius_bottom_left = 10
	revive_sb.content_margin_left = 14
	revive_sb.content_margin_right = 14
	revive_sb.content_margin_top = 10
	revive_sb.content_margin_bottom = 10
	_revive_row.add_theme_stylebox_override("panel", revive_sb)
	var revive_vbox := VBoxContainer.new()
	revive_vbox.add_theme_constant_override("separation", 6)
	_revive_row.add_child(revive_vbox)
	var revive_label := Label.new()
	revive_label.text = "Düştün! Altın karşılığında geri dönebilirsin."
	revive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revive_label.add_theme_font_size_override("font_size", 20)
	revive_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85, 1.0))
	revive_vbox.add_child(revive_label)
	_revive_button = Button.new()
	_revive_button.custom_minimum_size = Vector2(0, 44)
	_revive_button.add_theme_font_size_override("font_size", 20)
	_apply_button_style(_revive_button)
	_revive_button.pressed.connect(_on_buy_revive_pressed)
	revive_vbox.add_child(_revive_button)
	_main_vbox.add_child(_revive_row)

	var upgrade_title := Label.new()
	upgrade_title.text = "GELİŞTİRMELER"
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 22)
	upgrade_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	_main_vbox.add_child(upgrade_title)

	var upgrade_scroll := ScrollContainer.new()
	upgrade_scroll.custom_minimum_size = Vector2(0, 150)
	upgrade_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	upgrade_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(upgrade_scroll)
	_upgrade_container = HBoxContainer.new()
	_upgrade_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_upgrade_container.add_theme_constant_override("separation", 10)
	upgrade_scroll.add_child(_upgrade_container)

	## Kullanıcı isteği: "dükkanda satılan rasgele eşyalar altın karşılığında
	## rerollanabilmeli" - başlığın yanına küçük bir karıştır butonu.
	var extras_row := HBoxContainer.new()
	extras_row.alignment = BoxContainer.ALIGNMENT_CENTER
	extras_row.add_theme_constant_override("separation", 14)
	_main_vbox.add_child(extras_row)

	var extras_title := Label.new()
	extras_title.text = "EKSTRALAR"
	extras_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extras_title.add_theme_font_size_override("font_size", 22)
	extras_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	extras_row.add_child(extras_title)

	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(170, 34)
	_reroll_button.add_theme_font_size_override("font_size", 16)
	_apply_button_style(_reroll_button)
	_reroll_button.pressed.connect(_on_reroll_extras_pressed)
	extras_row.add_child(_reroll_button)

	_cards_container = HBoxContainer.new()
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", 16)
	_main_vbox.add_child(_cards_container)

	_local_countdown_label = Label.new()
	_local_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_local_countdown_label.add_theme_font_size_override("font_size", 16)
	_local_countdown_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	_local_countdown_label.visible = false
	_main_vbox.add_child(_local_countdown_label)

	_waiting_label = Label.new()
	_waiting_label.text = "Diğer oyuncular bekleniyor..."
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.add_theme_font_size_override("font_size", 18)
	_waiting_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_waiting_label.visible = false
	_main_vbox.add_child(_waiting_label)

	_close_btn = Button.new()
	_close_btn.text = "Kapat / Devam Et"
	_close_btn.custom_minimum_size = Vector2(260, 48)
	_close_btn.add_theme_font_size_override("font_size", 24)
	_apply_button_style(_close_btn)
	_close_btn.pressed.connect(_on_close_pressed)
	_main_vbox.add_child(_close_btn)

	var ui_sound = get_node_or_null("/root/UISound")
	if ui_sound and ui_sound.has_method("connect_all_buttons"):
		ui_sound.connect_all_buttons(self)


## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni
## istiyorum" - mini dükkandaki HER buton (geliştirme/al/karıştır/kapat)
## artık ShopPanel'in paylaşılan ahşap plaka stilini kullanıyor (bkz.
## shop_panel.gd _apply_wood_button_style).
func _apply_button_style(btn: Button) -> void:
	ShopPanel._apply_wood_button_style(btn)


func _update_gold_label() -> void:
	if _gold_label:
		_gold_label.text = "%d Altın" % GameManager.gold
	_refresh_reroll_button()
	_refresh_revive_row()


## bkz. sınıf üstü revive_purchased notu. Sadece oyuncu KALICI olarak
## ölmüşken (is_dead - downed/kurtarma kanalı bekleyen DEĞİL, o zaten normal
## müttefik-yakınlık kanalıyla çözülüyor) görünür.
func _refresh_revive_row() -> void:
	if not _revive_row or not is_instance_valid(_player):
		return
	var is_permanently_dead: bool = bool(_player.get("is_dead")) and not bool(_player.get("is_downed"))
	_revive_row.visible = is_permanently_dead
	if not is_permanently_dead or not _revive_button:
		return
	_revive_button.text = "Diriltmeyi Satın Al (%d Altın)" % REVIVE_COST
	_revive_button.disabled = GameManager.gold < REVIVE_COST


func _on_buy_revive_pressed() -> void:
	if not is_instance_valid(_player) or not bool(_player.get("is_dead")):
		return
	if GameManager.gold < REVIVE_COST:
		return
	if not _player.has_method("revive_from_permadeath"):
		return
	GameManager.gold -= REVIVE_COST
	_player.revive_from_permadeath()
	revive_purchased.emit()
	_update_gold_label()
	_refresh_revive_row()


func _refresh_reroll_button() -> void:
	if not _reroll_button:
		return
	_reroll_button.text = "Karıştır (%d Altın)" % _reroll_cost
	_reroll_button.disabled = GameManager.gold < _reroll_cost


func _max_item_slots() -> int:
	if is_instance_valid(_player) and _player.has_method("get_max_item_slots"):
		return _player.get_max_item_slots()
	return 0


func _item_count_owned(key: String) -> int:
	var n := 0
	for entry in GameManager.owned_items:
		if entry.get("key", "") == key:
			n += 1
	return n


func _owned_shield_type() -> String:
	for key in ShopPanel.SHIELD_TYPE_KEYS:
		if int(GameManager.get(key + "_level")) > 0:
			return key
	return ""


## ---------- Geliştirme satırları (sahip olunan silahlar + aktif kalkan) ----------

func _refresh_upgrade_rows() -> void:
	if not _upgrade_container:
		return
	for child in _upgrade_container.get_children():
		child.queue_free()
	for i in range(GameManager.owned_weapons.size()):
		var entry: Dictionary = GameManager.owned_weapons[i]
		_upgrade_container.add_child(_build_upgrade_row(
			ShopPanel.UPGRADE_NAMES.get(entry.get("key", ""), str(entry.get("key", ""))),
			entry.get("key", ""), int(entry.get("level", 1)),
			_on_upgrade_weapon_pressed.bind(i)
		))
	var owned_shield: String = _owned_shield_type()
	if owned_shield != "":
		_upgrade_container.add_child(_build_upgrade_row(
			ShopPanel.UPGRADE_NAMES.get(owned_shield, owned_shield), owned_shield,
			int(GameManager.get(owned_shield + "_level")),
			_on_upgrade_shield_pressed.bind(owned_shield)
		))


func _build_upgrade_row(display_name: String, key: String, level: int, on_pressed: Callable) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(150, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.26, 0.19, 0.12, 1.0)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.35, 0.22)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", PAL_ACCENT)
	vbox.add_child(name_lbl)

	var max_level: int = int(ShopPanel.MAX_LEVELS.get(key, 100))
	var level_lbl := Label.new()
	level_lbl.text = "Seviye %d/%d" % [level, max_level]
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(level_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 16)
	_apply_button_style(btn)
	if level >= max_level:
		btn.text = "MAKS"
		btn.disabled = true
	else:
		var cost: int = ShopPanel._upgrade_cost(key, level + 1)
		btn.text = "Yükselt\n(%d Altın)" % cost
		btn.disabled = GameManager.gold < cost
		btn.pressed.connect(on_pressed)
	vbox.add_child(btn)
	return row


func _on_upgrade_weapon_pressed(index: int) -> void:
	if index < 0 or index >= GameManager.owned_weapons.size():
		return
	var entry: Dictionary = GameManager.owned_weapons[index]
	var key: String = entry.get("key", "")
	var level: int = int(entry.get("level", 1))
	var max_level: int = int(ShopPanel.MAX_LEVELS.get(key, 100))
	if level >= max_level:
		return
	var next_level: int = level + 1
	var cost: int = ShopPanel._upgrade_cost(key, next_level)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	entry["level"] = next_level
	entry["spent"] = int(entry.get("spent", 0)) + cost
	GameManager.owned_weapons[index] = entry
	if is_instance_valid(_player) and _player.has_method("set_owned_weapon_level"):
		_player.set_owned_weapon_level(index, next_level)
	_refresh_upgrade_rows()
	_update_gold_label()
	_refresh_card_afford_state()
	_start_local_close_timer_if_needed()


func _on_upgrade_shield_pressed(key: String) -> void:
	var level_prop := key + "_level"
	var current: int = int(GameManager.get(level_prop))
	var max_level: int = int(ShopPanel.MAX_LEVELS.get(key, 100))
	if current >= max_level:
		return
	var next_level: int = current + 1
	var cost: int = ShopPanel._upgrade_cost(key, next_level)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	GameManager.set(level_prop, next_level)
	if is_instance_valid(_player) and _player.has_method("refresh_shield_stats"):
		_player.refresh_shield_stats()
	_refresh_upgrade_rows()
	_update_gold_label()
	_refresh_card_afford_state()
	_start_local_close_timer_if_needed()


## ---------- Rasgele 3 "ekstra" kart (paralı - bkz. dosya başı notu) ----------

## YENİ bir havuz karıştırır (bkz. sınıf üstü _current_card_keys notu) -
## SADECE ilk açılışta (setup) ve explicit reroll'da (_on_reroll_extras_
## pressed) çağrılmalı. Satın alma/geliştirme sonrası afford durumunu
## güncellemek için _rebuild_card_nodes() kullanılır (havuzu DEĞİŞTİRMEZ).
## Kullanıcı isteği: "rerollanan şeyler rerollandığında asla önceki
## seçeneklerden birini içermemeli" - bu dükkan açıkken GÖSTERİLMİŞ (ilk
## açılış + tüm reroll'lar) tüm eşya anahtarlarını tutar, sonraki çekilişte
## havuzdan çıkarılır. Havuz tükenirse (Items.KEYS'teki benzersiz eşya
## sayısı azalırsa) son çare olarak sıfırlanır.
var _shown_item_keys: Array = []

func _build_cards() -> void:
	var available: Array = Items.KEYS.filter(func(k): return not _shown_item_keys.has(k))
	if available.size() < CARD_SLOT_COUNT:
		_shown_item_keys.clear()
		available = Items.KEYS.duplicate()
	available.shuffle()
	while available.size() < CARD_SLOT_COUNT:
		available.append_array(Items.KEYS)
	_current_card_keys = available.slice(0, CARD_SLOT_COUNT)
	for k in _current_card_keys:
		_shown_item_keys.append(k)
	_rebuild_card_nodes()


## _current_card_keys'ten (karıştırmadan) kart node'larını yeniden kurar -
## fiyat/sahiplik/yeterli-altın durumunu tazeler, hangi eşyaların teklif
## edildiğini DEĞİŞTİRMEZ.
func _rebuild_card_nodes() -> void:
	if not _cards_container:
		return
	for child in _cards_container.get_children():
		child.queue_free()
	for key in _current_card_keys:
		_cards_container.add_child(_build_extra_card(key))


func _on_reroll_extras_pressed() -> void:
	if GameManager.gold < _reroll_cost:
		return
	GameManager.gold -= _reroll_cost
	_reroll_cost += MINI_SHOP_REROLL_INCREMENT
	_update_gold_label()
	_build_cards() ## bilerek YENİDEN karıştırır - explicit reroll


func _build_extra_card(key: String) -> PanelContainer:
	var item_def: Dictionary = Items.get_def(key)
	var display_name: String = item_def.get("name", key.capitalize())
	var desc_text: String = item_def.get("desc", "")
	var icon_path: String = "res://assets/generated/item_" + key + "_frame_0.png"

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 330)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.2, 0.11, 1.0)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.6, 0.55, 0.5)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	card.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", PAL_ACCENT)
	vbox.add_child(name_lbl)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var owned_count: int = _item_count_owned(key)
	var cost: int = ShopPanel._item_cost(key, owned_count + 1)
	var has_slots: bool = GameManager.owned_items.size() < _max_item_slots()

	var al_btn := Button.new()
	al_btn.custom_minimum_size = Vector2(0, 44)
	al_btn.add_theme_font_size_override("font_size", 20)
	_apply_button_style(al_btn)
	if not has_slots:
		al_btn.text = "SLOTLAR DOLU"
		al_btn.disabled = true
	else:
		al_btn.text = "AL (%d Altın)" % cost
		al_btn.disabled = GameManager.gold < cost
		al_btn.pressed.connect(_on_buy_extra_pressed.bind(key, cost))
	vbox.add_child(al_btn)
	card.set_meta("al_button", al_btn)
	return card


## bkz. shop_panel.gd::_on_buy_item üstündeki ÖNEMLİ sıra notu - player.buy_item()
## KENDİ İÇİNDE de slot kontrolü yapıyor, GameManager.owned_items'a EKLEMEDEN
## ÖNCE çağrılmalı (aynı sıra burada da izleniyor).
func _on_buy_extra_pressed(key: String, cost: int) -> void:
	if GameManager.owned_items.size() >= _max_item_slots():
		return
	if GameManager.gold < cost:
		return
	if not is_instance_valid(_player) or not _player.has_method("buy_item") or not _player.buy_item(key):
		return
	GameManager.gold -= cost
	GameManager.owned_items.append({"key": key, "spent": cost})
	_update_gold_label()
	_rebuild_card_nodes()
	_refresh_upgrade_rows()
	_start_local_close_timer_if_needed()


## Altın harcandıktan sonra kartların/satırların "yetersiz altın" disabled
## durumunu güncellemek için - fiyatlar/sahiplik değişmedi, sadece afford
## kontrolü. BUG DÜZELTMESİ (kullanıcı bildirimi: "bir eşyayı geliştirince
## rasgele satılan eşyalar değişiyor") - eskiden burası _build_cards()
## çağırıp havuzu TEKRAR karıştırıyordu; artık _rebuild_card_nodes() ile
## SADECE var olan _current_card_keys'ten yeniden kuruluyor, teklif edilen
## eşyaların kimliği değişmiyor.
func _refresh_card_afford_state() -> void:
	_rebuild_card_nodes()


func _on_countdown_tick(remaining: float) -> void:
	if _countdown_label:
		_countdown_label.visible = true
		_countdown_label.text = "%ds" % int(ceil(remaining))
	## Kullanıcı isteği: "kimi beklediğimiz yazsın" - bkz. level_up_screen.gd
	## _refresh_waiting_label ile AYNI desen.
	if _waiting_label and _waiting_label.visible:
		var names: String = NetworkManager.get_mini_shop_pending_names()
		_waiting_label.text = ("Bekleniyor: %s" % names) if names != "" else "Diğer oyuncular bekleniyor..."


func _on_close_pressed() -> void:
	if _has_closed_locally:
		return
	_has_closed_locally = true
	if NetworkManager.is_multiplayer_active:
		## Kendi ekranımızı hemen kapatmıyoruz - level_up_screen.gd ile AYNI
		## desen: herkes kapatana kadar (ya da 30sn dolana kadar) oyun devam
		## etmemeli, yoksa dünya bu oyuncu için koşarken diğerleri hâlâ
		## alışveriş yapıyor olurdu.
		if _main_vbox:
			for child in _main_vbox.get_children():
				if child != _waiting_label and child != _countdown_label:
					child.visible = false
		if _waiting_label:
			_waiting_label.visible = true
		NetworkManager.mark_local_mini_shop_closed()
	else:
		_finish_close()


func _on_all_closed() -> void:
	_finish_close()


func _finish_close() -> void:
	if NetworkManager.is_multiplayer_active:
		if NetworkManager.multiplayer_mini_shop_timer_tick.is_connected(_on_countdown_tick):
			NetworkManager.multiplayer_mini_shop_timer_tick.disconnect(_on_countdown_tick)
		if NetworkManager.multiplayer_mini_shop_all_closed.is_connected(_on_all_closed):
			NetworkManager.multiplayer_mini_shop_all_closed.disconnect(_on_all_closed)
	get_tree().paused = false
	closed.emit()
	queue_free()
