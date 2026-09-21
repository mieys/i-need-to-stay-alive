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
const LABEL_COLOR := Color(0.96, 0.89, 0.74, 1.0)  ## satır adı - dükkanın krem yazısı
const VALUE_COLOR := Color(1.0, 0.85, 0.35, 1.0)   ## değer - altın sarısı, kolay seçilsin

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
	for stat_id in _icon_nodes:
		_icon_nodes[stat_id].setup(stat_id, ICON_ROW_COLOR)
	_apply_text_colors()
	_setup_stat_tooltips()
	pivot_offset = size * 0.5
	_refresh()


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
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

	speed_value.text = str(int(player.speed))
	var w = player.get_primary_weapon()
	if w:
		damage_value.text = str(int(w.damage))
		fire_rate_value.text = "%.2f/sn" % (1.0 / w.fire_rate)
		crit_value.text = "%%%d (x%.2f)" % [int(w.crit_chance * 100), w.crit_damage]
	else:
		damage_value.text = "0"
		fire_rate_value.text = "-"
		crit_value.text = "-"
	shield_protection_value.text = "%%%d" % int(round(player.shield_protection * 100))

	shield_pen_percent_value.text = "%%%d" % int(round(player.shield_pen_percent * 100))
	exp_gain_value.text = "%%%d" % int(round(player.exp_gain_percent * 100))
	luck_value.text = format_luck(player.luck)
	range_value.text = "+%d" % int(player.weapon_range_bonus)
	dodge_value.text = "%%%d" % int(round(player.dodge_chance * 100))
	knockback_value.text = str(int(player.knockback_stat))
	shield_amount_value.text = "+%%%d" % int(round(player.shield_max_percent * 100))


## KULLANICI BİLDİRİMİ (2026-09-21): "şans buga girmiş veya çok bozuk %1500lere kadar ulaşılabiliyor, çok şans alınmamasına
## rağmen". KÖK NEDEN: Şans bir PUAN sayacı (kart +1.5 puan, Şanslı Zar +2 puan; oyuncu.luck = toplam puan) ama panel onu yüzdeymiş
## gibi x100 yazıyordu - 15 puan "%1500" görünüyordu, oysa gerçek etkisi puan başına %0.2 düşme şansı (bkz. enemy.gd
## _player_luck_drop_bonus). Etki değerlerine dokunulmadı; gösterge kartlardaki/eşyalardaki birimle (puan) aynı olacak şekilde düzeltildi.
static func format_luck(points: float) -> String:
	if is_equal_approx(points, round(points)):
		return "%d" % int(round(points))
	return "%.1f" % points


func _setup_stat_tooltips() -> void:
	var descriptions: Dictionary = {
		"speed": "Hız: Karakterin hareket hızını arttırır.",
		"damage": "Saldırı Gücü: Tüm silahların verdiği hasarı arttırır.",
		"fire_rate": "Ateş Hızı: Tüm silahların saldırı sıklığını/hızını arttırır.",
		"shield_protection": "Kalkan Soğurma: Kalkanın hasar emme oranını arttırır.",
		"crit_chance": "Kritik Oran/Hasar: Kritik vuruş yapma şansını ve kritik hasar çarpanını arttırır.",
		"shield_pen_percent": "Kalkan Delme: Düşmanların kalkan soğurmasını yüzde olarak yok sayar.",
		"exp_gain": "Tecrübe Kazanımı: Kazanılan tecrübe puanını (XP) arttırır.",
		"luck": "Şans (puan): Her 1 puan altın/yemek/mıknatıs düşme ihtimalini %0.2, sandık düşme ihtimalini %0.04, kartlarda üst kademe çıkma ağırlığını %1.5 arttırır.",
		"range": "Menzil: Silahların vuruş ve menzil uzaklığını arttırır.",
		"dodge": "Sıvışma: Saldırılardan kaçınma şansı verir (Maks %60, fazlası boşa gider).",
		"knockback": "Geri Tepme: Silahların düşmanları geri itme gücünü arttırır.",
		"shield_amount": "Kalkan Miktarı: Maksimum kalkan kapasitesini arttırır."
	}
	
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
