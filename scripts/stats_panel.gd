extends Control

@onready var speed_value: Label = $Frame/Margin/VBox/GridScroll/Grid/SpeedValue
@onready var damage_value: Label = $Frame/Margin/VBox/GridScroll/Grid/DamageValue
@onready var fire_rate_value: Label = $Frame/Margin/VBox/GridScroll/Grid/FireRateValue
@onready var shield_protection_value: Label = $Frame/Margin/VBox/GridScroll/Grid/ShieldProtectionValue
@onready var crit_value: Label = $Frame/Margin/VBox/GridScroll/Grid/CritValue

## DÜZELTME (kullanıcı isteği: "zırh kaldırıldı, zırh delme yerini kalkan
## delme alacak") - eskiden ArmorValue (düz zırh) ve ArmorPenPercentValue
## (zırh delme) ayrı ayrı vardı; zırh tamamen kaldırıldı, zırh delmenin
## gösterdiği .tscn node'u (ArmorPenPercentValue) artık shield_pen_percent
## (kalkan delme) verisini gösteriyor - node adı .tscn'de değişmedi, sadece
## etiket metni "Kalkan Delme" oldu (bkz. scenes/stats_panel.tscn).
@onready var shield_pen_percent_value: Label = $Frame/Margin/VBox/GridScroll/Grid/ArmorPenPercentValue
@onready var exp_gain_value: Label = $Frame/Margin/VBox/GridScroll/Grid/ExpGainValue
@onready var luck_value: Label = $Frame/Margin/VBox/GridScroll/Grid/LuckValue
@onready var range_value: Label = $Frame/Margin/VBox/GridScroll/Grid/RangeValue
@onready var dodge_value: Label = $Frame/Margin/VBox/GridScroll/Grid/DodgeValue
@onready var knockback_value: Label = $Frame/Margin/VBox/GridScroll/Grid/KnockbackValue
@onready var shield_amount_value: Label = $Frame/Margin/VBox/GridScroll/Grid/ShieldAmountValue
## 2026-10-02: sahnede olmayan iki satır kodla eklenir (bkz. _add_runtime_rows) - yeni eşya sistemi statı "İyileştirme ve
## Kalkan Gücü" ve 5 saniyede bir işleyen Can Yenilenmesi.
var heal_power_value: Label = null
var regen_value: Label = null
## 2026-10-11 (kullanıcı: "envanterdeki stat penceresinde bazı eksik statlar var, örneğin can çalma gözükmüyor"): kodla eklenen diğer satırlar.
var _extra_values: Dictionary = {} ## satır id -> değer Label'ı

## Her satırın başındaki küçük ikon (bkz. stat_icon.gd - level atlama
## kartlarıyla AYNI script/AYNI PNG'ler, res://assets/ui/level_up_icons/,
## bkz. kullanıcı isteği "hem kartlarda hem istatistiklerde kullanır mısın").
## Renk parametresi burada önemsiz - stat_icon.gd artık gerçek bir doku
## bulduğunda onu boyamadan olduğu gibi çiziyor, renk sadece dokusu eksik
## kalan (olmayan) bir id için soluk bir yedek halka çizerken kullanılıyor.
const ICON_ROW_COLOR := Color(0.85, 0.78, 0.65, 1.0)

@onready var _icon_nodes: Dictionary = {
	"speed": $Frame/Margin/VBox/GridScroll/Grid/SpeedIcon,
	"damage": $Frame/Margin/VBox/GridScroll/Grid/DamageIcon,
	"fire_rate": $Frame/Margin/VBox/GridScroll/Grid/FireRateIcon,
	"shield_protection": $Frame/Margin/VBox/GridScroll/Grid/ShieldProtectionIcon,
	"crit_chance": $Frame/Margin/VBox/GridScroll/Grid/CritIcon,
	"shield_pen_percent": $Frame/Margin/VBox/GridScroll/Grid/ArmorPenPercentIcon,
	"exp_gain": $Frame/Margin/VBox/GridScroll/Grid/ExpGainIcon,
	"luck": $Frame/Margin/VBox/GridScroll/Grid/LuckIcon,
	"range": $Frame/Margin/VBox/GridScroll/Grid/RangeIcon,
	"dodge": $Frame/Margin/VBox/GridScroll/Grid/DodgeIcon,
	"knockback": $Frame/Margin/VBox/GridScroll/Grid/KnockbackIcon,
	"shield_amount": $Frame/Margin/VBox/GridScroll/Grid/ShieldAmountIcon,
}

## Satır listesi, dükkandaki ürün kartlarıyla AYNI koyu çikolata zemine
## (bkz. stats_panel.tscn -> SBF_content_dark, Color(0.24, 0.2, 0.15))
## oturuyor; dükkanda da bu koyu zeminlerin üstündeki yazılar krem.
## Renkler burada tek merkezden veriliyor - 13 satırın .tscn içinde tek
## tek renklendirilmesi hem tekrar hem de bakımı zor olurdu.
## 2026-09-24: satırlar artık bej çukur alanda (oyun içi kit, menülerle aynı dil) - koyu kahve ad + koyu altın değer.
const LABEL_COLOR := UIKit.C_TEXT   ## satır adı
const VALUE_COLOR := UIKit.C_GOLD   ## değer - koyu altın, kolay seçilsin

var player: Node = null

## Açılış animasyonu (bkz. _play_open_animation) - inventory_panel.gd'deki
## AYNI mantık/AYNI süre, kullanıcı isteği: "istatistik penceresi de
## animasyonla açılsın, ease ease olmalı ve yorucu olmamalı." hud.gd bu
## paneli sadece "visible = true" yaparak açıyor, davranışı değiştirmeden
## NOTIFICATION_VISIBILITY_CHANGED dinleniyor.
const OPEN_ANIM_DURATION := 0.2
const OPEN_ANIM_START_SCALE := 0.9
var _open_tween: Tween = null


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("stats_changed"):
		player.stats_changed.connect(_refresh)
	_add_runtime_rows()
	for stat_id in _icon_nodes:
		_icon_nodes[stat_id].setup(stat_id, ICON_ROW_COLOR)
	_apply_kit_style()
	_apply_text_colors()
	_setup_stat_tooltips()
	## Kullanıcı isteği (2026-09-26): geri tepme artık bir stat değil (kartlardan/eşyalardan kaldırıldı, ileride efsun
	## özelliği olacak) - istatistik ızgarasındaki satırı gizlenir (düğümler sahnede duruyor).
	for n in ["KnockbackIcon", "KnockbackLabel", "KnockbackValue"]:
		var row_node: Control = get_node_or_null("Frame/Margin/VBox/GridScroll/Grid/" + n) as Control
		if row_node:
			row_node.visible = false
	pivot_offset = size * 0.5
	_refresh()


## Kullanıcı isteği (2026-09-22): "stat arayüzü dahil, envanteri seyyar satıcı gibi pixel tarzda yap" - pencere/başlık/satır zemini UIKit
## ile, yazılar m5x7 için 16'nın katı boyutlarda (38/50 -> 32/48), Grid'in eski offset_transform ölçeği kaldırıldı.
func _apply_kit_style() -> void:
	theme = UIKit.theme()
	var frame: PanelContainer = $Frame as PanelContainer
	frame.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	var margin: MarginContainer = $Frame/Margin as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	var title: Label = $Frame/Margin/VBox/Title as Label
	title.add_theme_stylebox_override("normal", UIKit.panel_style("plaque"))
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_TEXT, 4)
	title.text = "ÖZELLİKLER"
	var hint: Label = get_node_or_null("Frame/Margin/VBox/CloseHint") as Label
	if hint:
		UIKit.style_label(hint, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
	var scroll: ScrollContainer = $Frame/Margin/VBox/GridScroll as ScrollContainer
	scroll.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	var grid: GridContainer = $Frame/Margin/VBox/GridScroll/Grid as GridContainer
	grid.offset_transform_enabled = false
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 5) ## 2026-10-02: 12 -> 5, iki yeni satır kaydırmasız sığsın
	var kids: Array[Node] = grid.get_children()
	for i in range(0, kids.size(), 3):
		if i + 2 >= kids.size():
			break
		var icon_node: Control = kids[i] as Control
		if icon_node:
			icon_node.custom_minimum_size = Vector2(40, 40)
		for j in [1, 2]:
			var lbl: Label = kids[i + j] as Label
			if lbl:
				lbl.add_theme_font_size_override("font_size", UIKit.FS_BODY)
				lbl.add_theme_constant_override("outline_size", 0)
				if j == 2:
					lbl.custom_minimum_size = Vector2(120, 0)


## Grid'deki her satırın adını/değerini krem zemine göre okunur renklere
## boyar. Grid sırası her zaman [Icon, Label, Value] üçlüsü halinde -
## bkz. stats_panel.tscn, bu yüzden 3'er adımla ilerleniyor.
func _apply_text_colors() -> void:
	var grid: GridContainer = $Frame/Margin/VBox/GridScroll/Grid
	var kids: Array[Node] = grid.get_children()
	for i in range(0, kids.size(), 3):
		if i + 2 >= kids.size():
			break
		var label_node: Node = kids[i + 1]
		var value_node: Node = kids[i + 2]
		if label_node is Label:
			(label_node as Label).add_theme_color_override("font_color", LABEL_COLOR)
		if value_node is Label:
			var val_lbl := value_node as Label
			val_lbl.add_theme_color_override("font_color", VALUE_COLOR)
			var sb := StyleBoxEmpty.new()
			sb.content_margin_right = 16.0
			val_lbl.add_theme_stylebox_override("normal", sb)


## Sahnede olmayan, kodla eklenen satırlar: [id (ikon = stat_icon.gd), ad, ipucu].
const EXTRA_ROWS := [
	["max_health", "Can", "Can: şimdiki / en fazla can."],
	["shield_max", "Mana Kalkanı", "Mana Kalkanı: şimdiki / en fazla mana kalkanı (eşyalardan)."],
	["lifesteal", "Can Çalma", "Can Çalma: her isabette bu ihtimalle 2 can yenilersin (alan hasarında etkisi %33)."],
	["health_regen", "Can Yenilenmesi", "Can Yenilenmesi: 5 saniyede bir yenilenen can (kartlar ve eşyalardan; İyileştirme Gücü ile büyür)."],
	["shield_regen", "Mana Kalkanı Yenilenmesi", "Mana Kalkanı Yenilenmesi: saniyede yenilenen mana kalkanı (eşyalardan)."],
	["heal_power", "İyileştirme Gücü", "İyileştirme ve Mana Kalkanı Gücü: yaptığın bütün iyileştirmeleri, can yenilenmesini, can çalmayı ve mana kalkanı doldurmayı yüzde olarak arttırır."],
	["cooldown_reduction", "Bekleme Azaltma", "Bekleme Süresi Azaltma: yeteneklerin bekleme süreleri bu oranda kısalır."],
	["pickup_range", "Toplama Menzili", "Toplama Menzili: XP, altın ve eşyaları bu uzaklıktan çekersin."],
]


## [ikon, ad, değer] üçlüsü - sahnedeki satırlarla aynı düzen; stil/renk _apply_kit_style ve _apply_text_colors'tan gelir.
func _add_runtime_rows() -> void:
	var grid: GridContainer = $Frame/Margin/VBox/GridScroll/Grid as GridContainer
	for row in EXTRA_ROWS:
		var icon_node := Control.new()
		icon_node.set_script(preload("res://scripts/stat_icon.gd"))
		icon_node.name = "Runtime_%s_Icon" % row[0]
		icon_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_lbl := Label.new()
		name_lbl.text = row[1]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		var val_lbl := Label.new()
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.clip_text = true
		for n in [icon_node, name_lbl, val_lbl]:
			grid.add_child(n)
		_icon_nodes[row[0]] = icon_node
		name_lbl.tooltip_text = str(row[2])
		if row[0] == "health_regen":
			regen_value = val_lbl
		elif row[0] == "heal_power":
			heal_power_value = val_lbl
		else:
			_extra_values[row[0]] = val_lbl
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()
		_play_open_animation()


## Kısa, tek seferlik bir ease-out büyüme+belirme - zıplama/elastik yok,
## göz yormasın diye hızlı (bkz. OPEN_ANIM_DURATION).
func _play_open_animation() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	scale = Vector2(OPEN_ANIM_START_SCALE, OPEN_ANIM_START_SCALE)
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.set_trans(Tween.TRANS_CUBIC)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_ANIM_DURATION)
	_open_tween.tween_property(self, "scale", Vector2.ONE, OPEN_ANIM_DURATION)


func _refresh() -> void:
	if not player or not is_instance_valid(player):
		return

	## Hareket hızı = KALICI hız: taban x (1 + eşya + "Hız" kartları). Eskiden ham `player.speed` (taban x 0.9) yazılıyordu - kart/eşya
	## alsan da sayı hiç değişmiyordu (2026-10-12). Geçici etkiler (yetenek/ruhani/evrim buff'ları) bilerek katılmaz, sayı titremesin.
	speed_value.text = str(int(round(player.get_base_move_speed()))) if player.has_method("get_base_move_speed") else str(int(player.speed))
	var w = player.get_primary_weapon()
	if w:
		damage_value.text = str(int(w.damage))
		## bkz. player.gd get_attack_speed_bonus_percent - ilk silahın atış/sn'si DEĞİL, oyuncunun toplam saldırı hızı bonusu.
		fire_rate_value.text = "+%%%d" % int(round(player.get_attack_speed_bonus_percent()))
		crit_value.text = "%%%d (x%.2f)" % [int(w.crit_chance * 100), w.crit_damage]
	else:
		damage_value.text = "0"
		fire_rate_value.text = "+%%%d" % int(round(player.get_attack_speed_bonus_percent()))
		crit_value.text = "-"
	shield_protection_value.text = "%%%d" % int(round(player.shield_protection * 100))

	shield_pen_percent_value.text = "%%%d" % int(round(player.shield_pen_percent * 100))
	exp_gain_value.text = "%%%d" % int(round(GameManager.effective_exp_gain(player.exp_gain_percent) * 100)) ## etkin değer (üst sınır +%100, madde 269)
	luck_value.text = format_luck(player.luck)
	range_value.text = "+%%%d" % int(round(player.weapon_range_bonus * 100.0))
	dodge_value.text = "%%%d" % int(round(player.dodge_chance * 100))
	knockback_value.text = str(int(player.knockback_stat))
	shield_amount_value.text = "+%%%d" % int(round(player.shield_max_percent * 100))
	if regen_value and "heal_regen_card_bonus" in player:
		var regen: float = float(player.heal_regen_card_bonus) + float(player.get("item_health_regen") if "item_health_regen" in player else 0.0)
		regen_value.text = "%s/5sn" % format_luck(snappedf(regen, 0.1))
	if heal_power_value and player.has_method("get_heal_shield_power"):
		heal_power_value.text = "+%%%d" % int(round(float(player.get_heal_shield_power()) * 100.0))
	_refresh_extra_rows()


func _refresh_extra_rows() -> void:
	var t: Dictionary = {
		"max_health": "%d/%d" % [int(player.health), int(player.max_health)],
		"shield_max": "%d/%d" % [int(player.get("item_shield_hp")), int(player.get("item_shield_max"))] if "item_shield_max" in player else "-",
		"lifesteal": format_percent(float(player.call("get_total_lifesteal"))) if player.has_method("get_total_lifesteal") else "-",
		"shield_regen": ("%s/sn" % format_luck(snappedf(float(player.get("item_shield_regen_flat")), 0.1))) if "item_shield_regen_flat" in player else "-",
		"cooldown_reduction": format_percent(float(player.call("get_cooldown_reduction")) if player.has_method("get_cooldown_reduction") else float(player.get("cooldown_reduction_percent"))) if "cooldown_reduction_percent" in player else "-",
		"pickup_range": str(int(round(float(player.call("get_pickup_range"))))) if player.has_method("get_pickup_range") else "-",
	}
	for id in _extra_values:
		(_extra_values[id] as Label).text = str(t.get(id, "-"))


## Kesir -> "%X" (küçük değerlerde bir ondalık: %2,5).
static func format_percent(v: float) -> String:
	var pct: float = v * 100.0
	return ("%%%d" % int(round(pct))) if is_equal_approx(pct, round(pct)) else ("%%%.1f" % pct)


## Telefon (kullanıcı bildirimi 2026-10-03: "envanter paneli çok kötü mobile uyumlu değil"): hud.gd bu paneli küçültüp
## sığdırmak yerine bunu çağırır - pencere ekranın sol yarısında, satırlar 40 px yazı + 48 px ikon (masaüstü 32/40).
func apply_mobile_layout(rect: Rect2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	scale = Vector2.ONE
	position = rect.position
	size = rect.size
	pivot_offset = size * 0.5
	var margin: MarginContainer = $Frame/Margin as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var hint: Control = get_node_or_null("Frame/Margin/VBox/CloseHint") as Control
	if hint:
		hint.visible = false ## "ENVANTER'e tekrar bas" - telefonda kapatma rayın geri düğmesi
	_ph_build_cards()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a1a2c")
	sb.border_color = Color("#5f5c86")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	($Frame as Control).add_theme_stylebox_override("panel", sb)
	var title: Label = $Frame/Margin/VBox/Title as Label
	title.text = "ÖZELLİKLER"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	title.add_theme_color_override("font_color", Color("#f4c56e"))
	title.add_theme_constant_override("outline_size", 0)
	var well := StyleBoxEmpty.new()
	well.content_margin_top = 12
	($Frame/Margin/VBox/GridScroll as Control).add_theme_stylebox_override("panel", well)


## Telefon (kullanıcı 2026-10-19: "özellikler kısmında ... sayılar arasında çok gereksiz boşluk var kullanışlı değil"): geniş ekranda
## [simge | ad ........ değer] satırları ad ile değeri ekranın iki ucuna ayırıyordu. Her özellik kendi karosunda: simge + büyük değer,
## hemen altında adı; 3 sütun, kaydırmadan sığar. Sahnedeki üçlüler (simge, ad, değer) karolara taşınır - değer etiketlerine tutulan
## başvurular aynı kalır; Grid tek sütunlu kabuğa döner (üçlü gezen eski kod boş geçer). Bir kez kurulur.
const PH_COLS := 3
var _ph_cards: GridContainer = null


func _ph_build_cards() -> void:
	if _ph_cards != null:
		return
	var grid: GridContainer = $Frame/Margin/VBox/GridScroll/Grid as GridContainer
	_ph_cards = GridContainer.new()
	_ph_cards.name = "PhoneCards"
	_ph_cards.columns = PH_COLS
	_ph_cards.add_theme_constant_override("h_separation", 16)
	_ph_cards.add_theme_constant_override("v_separation", 14)
	_ph_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kids: Array[Node] = grid.get_children()
	for i in range(0, kids.size() - 2, 3):
		var icon_node := kids[i] as Control
		var name_lbl := kids[i + 1] as Label
		var val_lbl := kids[i + 2] as Label
		if icon_node == null or name_lbl == null or val_lbl == null:
			continue
		var card := PanelContainer.new()
		card.name = "Card_" + str(name_lbl.name)
		card.visible = name_lbl.visible ## gizli satır (geri tepme) gizli karo
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = name_lbl.tooltip_text
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color("#23233a")
		cs.border_color = Color("#3b3a5a")
		cs.set_border_width_all(2)
		cs.set_corner_radius_all(10)
		cs.content_margin_left = 20
		cs.content_margin_right = 20
		cs.content_margin_top = 12
		cs.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", cs)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -6)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for n: Node in [icon_node, name_lbl, val_lbl]:
			n.get_parent().remove_child(n)
		icon_node.custom_minimum_size = Vector2(56, 56)
		icon_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_node)
		val_lbl.add_theme_font_size_override("font_size", 48)
		val_lbl.add_theme_color_override("font_color", Color("#f0da94"))
		val_lbl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		val_lbl.custom_minimum_size = Vector2.ZERO
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.clip_text = true
		val_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_size_override("font_size", 32)
		name_lbl.add_theme_color_override("font_color", Color("#a7a2c0"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2.ZERO
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(val_lbl)
		col.add_child(name_lbl)
		row.add_child(col)
		card.add_child(row)
		_ph_cards.add_child(card)
	grid.columns = 1
	grid.add_child(_ph_cards)


## KULLANICI BİLDİRİMİ (2026-09-21): "şans buga girmiş veya çok bozuk %1500lere kadar ulaşılabiliyor, çok şans alınmamasına
## rağmen". KÖK NEDEN: Şans bir PUAN sayacı (kart +1.5 puan, Şanslı Zar +2 puan; oyuncu.luck = toplam puan) ama panel onu yüzdeymiş
## gibi x100 yazıyordu - 15 puan "%1500" görünüyordu, oysa gerçek etkisi puan başına %0.2 düşme şansı (bkz. enemy.gd
## _player_luck_drop_bonus). Etki değerlerine dokunulmadı; gösterge kartlardaki/eşyalardaki birimle (puan) aynı olacak şekilde düzeltildi.
static func format_luck(points: float) -> String:
	if is_equal_approx(points, round(points)):
		return "%d" % int(round(points))
	return "%.1f" % points


## Satır ipuçları - hud_stat_panel.gd (mini stat paneli) de buradan okur (tek kaynak).
const STAT_TIPS: Dictionary = {
	"speed": "Hız: Karakterin hareket hızını arttırır.",
	"damage": "Saldırı Gücü: Tüm silahların verdiği hasarı arttırır.",
	"fire_rate": "Saldırı Hızı: Tüm silahların saldırı sıklığını arttırır. Seviye kartları, eşyalar ve pasiflerden gelen toplam bonus. En çok %600; aşan her %1, anlık olarak 0.5 saldırı gücü verir.",
	"shield_protection": "Mana Kalkanı Soğurma: Mana kalkanının hasar emme oranını arttırır.",
	"crit_chance": "Kritik Oran/Hasar: Kritik vuruş yapma şansını ve kritik hasar çarpanını arttırır.",
	"shield_pen_percent": "Kalkan Delme: Düşmanların kalkan soğurmasını yüzde olarak yok sayar.",
	"exp_gain": "Tecrübe Kazanımı: Kazanılan tecrübe puanını (XP) arttırır.",
	"luck": "Şans (puan): Her 1 puan öldürdüğün yaratıkların yemek/mıknatıs/sandık düşürme ihtimalini %5 (20 puan = 2 kat), altın düşürme ihtimalini %1 arttırır; seviye kartlarında, sandık ödüllerinde ve satıcı eşyalarında üst kademe çıkma ağırlığını %1.5 arttırır.",
	"range": "Menzil: Silahların vuruş ve menzil uzaklığını arttırır.",
	"dodge": "Sıvışma: Saldırılardan kaçınma şansı verir (Maks %40, Rüzgâr Yürüyen Çizmeleri ile %50; fazlası boşa gider).",
	"knockback": "Geri Tepme: Silahların düşmanları geri itme gücünü arttırır.",
	"shield_amount": "Mana Kalkanı Miktarı: Maksimum mana kalkanı kapasitesini arttırır."
}


func _setup_stat_tooltips() -> void:
	var descriptions: Dictionary = STAT_TIPS
	
	var grid: GridContainer = $Frame/Margin/VBox/GridScroll/Grid as GridContainer
	if not grid:
		return
	var kids: Array[Node] = grid.get_children()
	
	for child in kids:
		if child is Control:
			var c: Control = child as Control
			var name_lower: String = c.name.to_lower()
			var stat_key: String = ""
			if "speed" in name_lower:
				stat_key = "speed"
			elif "armorpen" in name_lower or "pen" in name_lower:
				stat_key = "shield_pen_percent"
			elif "damage" in name_lower:
				stat_key = "damage"
			elif "firerate" in name_lower or "fire_rate" in name_lower:
				stat_key = "fire_rate"
			elif "shieldprotection" in name_lower or "protection" in name_lower:
				stat_key = "shield_protection"
			elif "crit" in name_lower:
				stat_key = "crit_chance"
			elif "expgain" in name_lower or "exp" in name_lower:
				stat_key = "exp_gain"
			elif "luck" in name_lower:
				stat_key = "luck"
			elif "range" in name_lower:
				stat_key = "range"
			elif "dodge" in name_lower:
				stat_key = "dodge"
			elif "knockback" in name_lower:
				stat_key = "knockback"
			elif "shieldamount" in name_lower or "amount" in name_lower:
				stat_key = "shield_amount"
				
			if stat_key != "" and descriptions.has(stat_key):
				c.tooltip_text = descriptions[stat_key] as String
				c.mouse_filter = Control.MOUSE_FILTER_PASS
