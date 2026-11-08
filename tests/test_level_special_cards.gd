extends Node

## Madde 367: özel level kartları (takas + silah türü). Kartta yazan = uygulanan, zeminlerde bedava kazanç yok, ekranda tam 1 özel kart.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const Special := preload("res://scripts/level_special_cards.gd")
const StatIconScript := preload("res://scripts/stat_icon.gd")


func test_defs_are_well_formed() -> void:
	assert(Special.ORDER.size() == Special.DEFS.size(), "ORDER ile DEFS aynı kartları saymalı")
	for id: String in Special.ORDER:
		var d: Dictionary = Special.DEFS[id]
		assert(Special.STATS.has(Special.gain_stat(id)), "%s: kazanç statı tanımlı olmalı" % id)
		assert(StatIconScript.ICON_PATHS.has(str(d["icon"])), "%s: simge ICON_PATHS'te olmalı (%s)" % [id, d["icon"]])
		assert(Special.has_cost(id) and Special.STATS.has(Special.cost_stat(id)), "%s: her özel kartın bedeli tanımlı olmalı (madde 379)" % id)
		assert(Special.gain_stat(id) != Special.cost_stat(id), "%s: kazanç ve bedel aynı stat olmamalı" % id)
		if str(d["kind"]) != "trade":
			assert(str(d.get("needs", "")) in ["melee", "ranged"], "%s: silah türü kartı bir tür istemeli" % id)


func test_values_scale_by_tier_and_text_matches() -> void:
	## Cam Top: kazanç x1 / x1,3 / x1,6 / x1,9 (düz kartlarla aynı eğri), bedel x1 / x1,15 / x1,3 / x1,45.
	var gains: Array = [10.0, 13.0, 16.0, 19.0]
	var costs: Array = [20.0, 23.0, 26.0, 29.0]
	for t in range(1, 5):
		assert(is_equal_approx(Special.gain_value("trade_glass", t), gains[t - 1]), "kazanç kademe %d: %s" % [t, Special.gain_value("trade_glass", t)])
		assert(is_equal_approx(Special.cost_value("trade_glass", t), costs[t - 1]), "bedel kademe %d: %s" % [t, Special.cost_value("trade_glass", t)])
	assert(Special.gain_text("trade_glass", 1) == "+10", "düz sayı metni: %s" % Special.gain_text("trade_glass", 1))
	assert(Special.cost_text("trade_glass", 1) == "-20 Azami Can", "bedel metni: %s" % Special.cost_text("trade_glass", 1))
	assert(Special.gain_text("trade_trigger", 1) == "+%9", "yüzde metni: %s" % Special.gain_text("trade_trigger", 1))
	assert(Special.cost_text("trade_trigger", 1) == "-%8 Mana Kalkanı", "yüzde bedel metni: %s" % Special.cost_text("trade_trigger", 1))
	assert(Special.restriction_text("class_melee") == "yalnız yakın dövüş", "silah türü kısıt metni")
	assert(Special.verb_text("class_melee", 1) == "-%5 Hareket Hızı", "silah türü kartının alt satırı artık bedel: %s" % Special.verb_text("class_melee", 1))
	assert(Special.verb_text("class_ranged", 1) == "-12 Azami Can", "Nişancılık bedeli: %s" % Special.verb_text("class_ranged", 1))


func test_trade_applies_exactly_what_the_card_says() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 200.0
	player.health = 200.0
	var ap0: float = player.damage_bonus
	player.apply_upgrade("trade_glass", 2)
	assert(is_equal_approx(player.damage_bonus - ap0, Special.gain_value("trade_glass", 2)), "kazanç: %s" % (player.damage_bonus - ap0))
	assert(is_equal_approx(player.max_health, 200.0 - Special.cost_value("trade_glass", 2)), "bedel: azami can %s" % player.max_health)
	assert(player.health <= player.max_health, "can yeni tavanı aşmamalı")
	assert(player.get_upgrade_count("trade_glass") == 1, "kart sayacı artmalı (geri katılım günlüğü)")
	var f0: float = player.fire_rate_mult
	player.apply_upgrade("trade_bulwark", 1) ## +40 can, -%8 saldırı hızı
	assert(is_equal_approx(player.max_health, 200.0 - 23.0 + 40.0), "Demir Kabuk kazancı: %s" % player.max_health)
	assert(is_equal_approx(player.fire_rate_mult, f0 / (1.0 - 0.08)), "saldırı hızı bedeli aralığı 1/(1-x) uzatır: %s" % player.fire_rate_mult)
	var spd0: float = player.speed_card_percent
	player.apply_upgrade("trade_boots", 1) ## +%10 hız, -15 can
	assert(is_equal_approx(player.speed_card_percent - spd0, 0.10), "Rüzgâr Ayakları hız kazancı")
	player.queue_free()


func test_cost_never_goes_below_floor_and_card_is_withheld() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 50.0 ## 50 - 20 = 30 < 40 zemin: Cam Top çıkmamalı
	player.health = 50.0
	assert(not Special.available_ids(player).has("trade_glass"), "azami can zemine yakınken Cam Top teklif edilmemeli")
	assert(not Special.available_ids(player).has("trade_boots"), "Rüzgâr Ayakları (bedel can) da teklif edilmemeli")
	assert(Special.available_ids(player).has("trade_trigger"), "bedeli can olmayan takas yine çıkabilmeli")
	## Yine de uygulanırsa zemin delinmez (kademe 4 bedeli tam ödenemeyince).
	player.apply_upgrade("trade_glass", 4)
	assert(player.max_health >= Special.MIN_MAX_HEALTH - 0.001, "azami can zeminin altına inmemeli: %s" % player.max_health)
	player.speed_card_percent = Special.MIN_SPEED_CARD
	assert(not Special.available_ids(player).has("trade_blood"), "hız kartı zeminde: Kan Anlaşması (bedel hız) çıkmamalı")
	player.queue_free()


## ---- Madde 401: 5 yeni takas kartı (Adrenalin / Sabit Nişan / Cellat / Hayalet Pelerin / Hafif Kuşanım) ----

func test_new_trade_cards_apply_exactly_gain_and_cost() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 300.0
	player.health = 300.0
	## Adrenalin: +saldırı hızı, -can
	var f1: float = player.fire_rate_mult
	var hp1: float = player.max_health
	player.apply_upgrade("trade_adrenaline", 1)
	assert(is_equal_approx(player.fire_rate_mult, f1 * (1.0 - Special.gain_value("trade_adrenaline", 1))), "Adrenalin kazancı aralığı kısaltır: %s" % player.fire_rate_mult)
	assert(is_equal_approx(player.max_health, hp1 - 20.0), "Adrenalin 20 can öder: %s" % player.max_health)
	## Sabit Nişan: +kritik oran, -hız
	var cc0: float = player.crit_chance_bonus
	var sp0: float = player.speed_card_percent
	player.apply_upgrade("trade_sight", 3)
	assert(is_equal_approx(player.crit_chance_bonus - cc0, Special.gain_value("trade_sight", 3)), "Sabit Nişan kazancı: %s" % (player.crit_chance_bonus - cc0))
	assert(is_equal_approx(sp0 - player.speed_card_percent, Special.cost_value("trade_sight", 3)), "Sabit Nişan hız öder: %s" % (sp0 - player.speed_card_percent))
	## Cellat: +kritik hasar, -mana kalkanı
	var cd0: float = player.crit_damage_bonus
	var sh0: float = player.shield_max_percent
	player.apply_upgrade("trade_executioner", 2)
	assert(is_equal_approx(player.crit_damage_bonus - cd0, Special.gain_value("trade_executioner", 2)), "Cellat kazancı: %s" % (player.crit_damage_bonus - cd0))
	assert(is_equal_approx(sh0 - player.shield_max_percent, Special.cost_value("trade_executioner", 2)), "Cellat kalkan öder: %s" % (sh0 - player.shield_max_percent))
	## Hayalet Pelerin: +sıvışma, -can
	var dg0: float = player.dodge_chance
	var hp2: float = player.max_health
	player.apply_upgrade("trade_cloak", 1)
	assert(is_equal_approx(player.dodge_chance - dg0, 0.07), "Hayalet Pelerin kazancı: %s" % (player.dodge_chance - dg0))
	assert(is_equal_approx(player.max_health, hp2 - 15.0), "Hayalet Pelerin 15 can öder: %s" % player.max_health)
	## Hafif Kuşanım: +hız, -mana kalkanı
	var sp1: float = player.speed_card_percent
	var sh1: float = player.shield_max_percent
	player.apply_upgrade("trade_light", 1)
	assert(is_equal_approx(player.speed_card_percent - sp1, 0.10), "Hafif Kuşanım hızı: %s" % (player.speed_card_percent - sp1))
	assert(is_equal_approx(sh1 - player.shield_max_percent, 0.10), "Hafif Kuşanım kalkan öder: %s" % (sh1 - player.shield_max_percent))
	for id in ["trade_adrenaline", "trade_sight", "trade_executioner", "trade_cloak", "trade_light"]:
		assert(player.get_upgrade_count(id) == 1, "%s: kart sayacı artmalı (geri katılım günlüğü)" % id)
	player.queue_free()


## Yeni kartların metinleri ve bedelli/bedelsiz kuralı: hepsi takas, hepsi bedelli, kazanç ve bedel farklı stat, ad/simge/etiket tanımlı.
func test_new_trade_cards_texts() -> void:
	assert(not Special.DEFS.has("trade_heavy"), "Ağır Darbe kaldırıldı (Cam Top zaten +SG veriyor)")
	assert(Special.gain_text("trade_adrenaline", 1) == "+%9" and Special.cost_text("trade_adrenaline", 1) == "-20 Azami Can", "Adrenalin")
	assert(Special.gain_text("trade_sight", 1) == "+%9" and Special.cost_text("trade_sight", 1) == "-%6 Hareket Hızı", "Sabit Nişan")
	assert(Special.gain_text("trade_executioner", 1) == "+%18" and Special.cost_text("trade_executioner", 1) == "-%8 Mana Kalkanı", "Cellat")
	assert(Special.gain_text("trade_cloak", 1) == "+%7" and Special.cost_text("trade_cloak", 1) == "-15 Azami Can", "Hayalet Pelerin")
	assert(Special.gain_text("trade_light", 1) == "+%10" and Special.cost_text("trade_light", 1) == "-%10 Mana Kalkanı", "Hafif Kuşanım")
	assert(Special.stat_label(Special.gain_stat("trade_sight")) == "Kritik Oran" and Special.stat_label(Special.gain_stat("trade_executioner")) == "Kritik Hasar", "yeni kazanç statı adları")
	assert(Special.stat_label(Special.gain_stat("trade_cloak")) == "Sıvışma", "Sıvışma adı")
	var trades: int = 0
	for id: String in Special.ORDER:
		if Special.is_trade(id):
			trades += 1
	assert(trades == 11, "11 takas kartı (6 eski + 5 yeni): %d" % trades)


## Zemin / sınır koruması: bedel statı zemindeyken ya da kazanç statı sınırdayken kart çıkmaz.
func test_new_trade_cards_are_withheld_at_floors_and_caps() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 50.0 ## 50 - 20 / 50 - 15 < 40 zemin
	player.health = 50.0
	var avail: Array = Special.available_ids(player)
	assert(not avail.has("trade_adrenaline") and not avail.has("trade_cloak"), "azami can zeminde: bedeli can olan yeni kartlar çıkmamalı: %s" % [avail])
	assert(avail.has("trade_executioner") and avail.has("trade_light"), "bedeli can olmayan yeni kartlar çıkabilmeli")
	player.max_health = 300.0
	player.health = 300.0
	player.speed_card_percent = Special.MIN_SPEED_CARD
	assert(not Special.available_ids(player).has("trade_sight"), "hız zeminde: Sabit Nişan (bedel hız) çıkmamalı")
	player.speed_card_percent = 0.0
	player.shield_max_percent = Special.MIN_SHIELD_PERCENT
	avail = Special.available_ids(player)
	assert(not avail.has("trade_executioner") and not avail.has("trade_light"), "kalkan zeminde: Cellat + Hafif Kuşanım çıkmamalı")
	player.shield_max_percent = 0.0
	player.dodge_chance = player.dodge_cap()
	assert(not Special.available_ids(player).has("trade_cloak"), "sıvışma sınırında: Hayalet Pelerin çıkmamalı (kazanç boşa gider)")
	player.dodge_chance = 0.0
	player.crit_chance_bonus = 1.0
	assert(not Special.available_ids(player).has("trade_sight"), "kritik oran %100: Sabit Nişan çıkmamalı")
	player.crit_chance_bonus = 0.0
	var all_ids: Array = Special.available_ids(player)
	for id in ["trade_adrenaline", "trade_sight", "trade_executioner", "trade_cloak", "trade_light"]:
		assert(all_ids.has(id), "%s: sınır/zemin yokken çıkabilmeli" % id)
	player.queue_free()


func test_class_cards_need_a_weapon_of_that_class() -> void:
	assert(not Special.available_ids(null).has("class_melee") and not Special.available_ids(null).has("class_ranged"),
		"silahı olmayan oyuncuya silah türü kartı çıkmamalı")
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	var melee_w: Node = (PlayerScene.instantiate().WEAPON_SCENES_BY_KEY["dagger"] as PackedScene).instantiate()
	player.add_child(melee_w)
	player.owned_weapon_nodes.append(melee_w)
	var avail: Array = Special.available_ids(player)
	assert(avail.has("class_melee") and not avail.has("class_ranged"), "yalnız yakın dövüş silahı varken sadece Yakın Dövüş Ustalığı: %s" % [avail])
	player._apply_weapon_bonuses() ## silah hasarı sahibin saldırı gücünden gelir (taban 0): önce oyuncunun bonusunu silaha it
	var before: float = melee_w.damage
	assert(before > 0.0, "taban hasar hesaplanmalı: %s" % before)
	player.apply_upgrade("class_melee", 1)
	assert(is_equal_approx(player.melee_card_percent, 0.15), "melee_card_percent: %s" % player.melee_card_percent)
	assert(is_equal_approx(melee_w.damage, before * 1.15), "yakın dövüş silahının hasarı x1,15: %s -> %s" % [before, melee_w.damage])
	player.apply_upgrade("class_ranged", 1)
	assert(is_equal_approx(melee_w.damage, before * 1.15), "menzilli kartı yakın dövüş silahını etkilememeli")
	player.queue_free()


func test_weapon_class_mult_scales_damage_only() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	var w: Node = (player.WEAPON_SCENES_BY_KEY["tabanca"] as PackedScene).instantiate()
	player.add_child(w)
	w.set_damage_bonus(20.0) ## silah hasarı sahibin saldırı gücünden gelir (taban 0)
	var before: float = w.damage
	assert(before > 0.0, "taban hasar hesaplanmalı: %s" % before)
	w.set_class_card_mult(1.30)
	assert(is_equal_approx(w.damage, before * 1.30), "set_class_card_mult hasarı çarpmalı: %s -> %s" % [before, w.damage])
	w.set_class_card_mult(1.0)
	assert(is_equal_approx(w.damage, before), "1.0 hasarı geri getirmeli")
	player.queue_free()


class FakeLevelPlayer extends Node2D:
	var level: int = 5
	var luck: float = 0.0
	var max_health: float = 300.0

	func get_upgrade_count(_id: String) -> int:
		return 0


## Ekranda 3 kartın TAM 1'i özel; reroll'da da 1 özel, tekrarsız; satır metni kartla aynı.
func test_level_up_screen_offers_exactly_one_special_card() -> void:
	var fake := FakeLevelPlayer.new()
	fake.add_to_group("player")
	add_child(fake)
	var scene: PackedScene = load("res://scenes/level_up_screen.tscn") as PackedScene
	var screen: CanvasLayer = scene.instantiate()
	add_child(screen)
	for round_i in 4:
		var specials: int = 0
		for i in range(3):
			var id: String = str(screen._card_ids[i])
			if Special.is_special(id):
				specials += 1
				var tier: int = int(screen._card_tiers[i])
				var value_lbl: Label = screen.cards[i].get_node("RowValue") as Label
				assert(value_lbl.text == Special.gain_text(id, tier), "satır değeri kartla aynı olmalı: %s / %s" % [value_lbl.text, Special.gain_text(id, tier)])
				var verb_lbl: Label = screen.cards[i].get_node("RowVerb") as Label
				assert(verb_lbl.text == Special.verb_text(id, tier), "alt satır bedel/kısıt: %s" % verb_lbl.text)
			else:
				## Madde 398: düz kart bedelsiz - alt satır eski "artar/azalır" (bedel yazısı yok).
				var plain_verb: Label = screen.cards[i].get_node("RowVerb") as Label
				assert(not Special.has_cost(id) and plain_verb.text == ("azalır" if id == "cooldown_reduction" else "artar"), "düz kartın alt satırı bedelsiz olmalı: %s / %s" % [id, plain_verb.text])
		assert(specials == 1, "turda tam 1 özel kart olmalı, bulunan: %d (%s)" % [specials, screen._card_ids])
		screen._populate_cards() ## reroll gibi yeniden çek
	screen.free()
	fake.free()


func test_auto_pick_scores_special_cards() -> void:
	var AutoPick := preload("res://scripts/auto_pick.gd")
	var s: float = AutoPick.upgrade_score("trade_glass", 2, null)
	assert(s > 0.0 and is_equal_approx(s, Special.auto_value("trade_glass") * 2.0), "otomatik seçim özel kartı puanlamalı: %s" % s)


## Satır yazıları kutusuna sığmalı (RowVerb 300 px, RowName 430 px, RowSub kalan genişlik) - tüm özel kartlar x tüm kademeler.
func test_special_card_texts_fit_the_row() -> void:
	var fake := FakeLevelPlayer.new()
	fake.add_to_group("player")
	add_child(fake)
	var scene: PackedScene = load("res://scenes/level_up_screen.tscn") as PackedScene
	var screen: CanvasLayer = scene.instantiate()
	add_child(screen)
	var card: Button = screen.cards[0]
	for id: String in Special.ORDER:
		for tier in range(1, 5):
			screen._fill_row(card, Special.as_card(id), tier, 3) ## 3 kez alınmış gibi: en uzun alt satır
			var verb: Label = card.get_node("RowVerb") as Label
			var value: Label = card.get_node("RowValue") as Label
			var name_lbl: Label = card.get_node("RowName") as Label
			assert(verb.get_minimum_size().x <= 300.0, "%s k%d alt satır sığmıyor: '%s' %.0f px" % [id, tier, verb.text, verb.get_minimum_size().x])
			assert(value.get_minimum_size().x <= 300.0, "%s k%d değer sığmıyor: '%s'" % [id, tier, value.text])
			assert(name_lbl.get_minimum_size().x <= 430.0, "%s ad sığmıyor: '%s' %.0f px" % [id, name_lbl.text, name_lbl.get_minimum_size().x])
			var sub: RichTextLabel = card.get_node("RowSub") as RichTextLabel
			assert(sub.get_content_width() <= sub.size.x, "%s k%d RowSub taşıyor: %d > %.0f" % [id, tier, sub.get_content_width(), sub.size.x])
	screen.free()
	fake.free()


## Takas kartı, düz kartın AYNI kademedeki değerinden belirgin büyük kazanç vermeli (bedel ödüyorsun): Kan Anlaşması %2/2,5/3/4 iken düz Can Çalma
## kartı %2/4/6/8 veriyordu (madde 370). Düz kart değerleri apply_upgrade ile aynı formüller.
func test_trade_gain_always_beats_the_plain_card_of_the_same_stat() -> void:
	var plain: Dictionary = {
		"damage": func(t: int) -> float: return 6.0 * (1.0 + (t - 1) * 0.3),
		"max_health": func(t: int) -> float: return TierSystem.health_card_for_tier(t),
		"speed": func(t: int) -> float: return 0.04 * (1.0 + (t - 1) * 0.3),
		"fire_rate": func(t: int) -> float: return 0.06 * (1.0 + (t - 1) * 0.3),
		"lifesteal": func(t: int) -> float: return TierSystem.lifesteal_percent_for_tier(t),
		"shield": func(t: int) -> float: return 0.05 * (1.0 + (t - 1) * 0.3), ## düz kartın metni +%5 (uygulanan ~%6,5)
		"crit_chance": func(t: int) -> float: return 0.035 * (1.0 + (t - 1) * 0.3), ## düz kartın metni +%2,5 (uygulanan %3,5)
		"crit_damage": func(t: int) -> float: return 0.06 * (1.0 + (t - 1) * 0.3),
		"dodge": func(t: int) -> float: return 0.035 * (1.0 + (t - 1) * 0.3),
	}
	for id: String in Special.ORDER:
		if not Special.is_trade(id):
			continue
		var stat: String = Special.gain_stat(id)
		for t in range(1, 5):
			var base: float = float((plain[stat] as Callable).call(t))
			var gain: float = Special.gain_value(id, t)
			assert(gain >= base * 1.5 - 0.0026, "%s kademe %d (tolerans = kazanç yuvarlama adımı 0,005'in yarısı: Çılgın Tetik/Adrenalin %%9, madde 436, kademe 2'de 0,117 -> 0,115 olur): kazanç %s düz karttan (%s) en az 1,5 kat olmalı" % [id, t, gain, base])


func test_blood_and_bulwark_follow_the_plain_card_tables() -> void:
	var want_blood: Array = [0.06, 0.12, 0.18, 0.24] ## Can Çalma tablosu %2/4/6/8 x 3
	var want_hp: Array = [40.0, 70.0, 100.0, 140.0] ## Can tablosu 20/35/50/70 x 2
	for t in range(1, 5):
		assert(is_equal_approx(Special.gain_value("trade_blood", t), want_blood[t - 1]), "Kan Anlaşması kademe %d: %s" % [t, Special.gain_value("trade_blood", t)])
		assert(is_equal_approx(Special.gain_value("trade_bulwark", t), want_hp[t - 1]), "Demir Kabuk kademe %d: %s" % [t, Special.gain_value("trade_bulwark", t)])
	assert(Special.gain_text("trade_blood", 1) == "+%6", "kart metni: %s" % Special.gain_text("trade_blood", 1))


## ---- Madde 398: bedel yalnız büyük avantajlı kartlarda (takas + silah türü); düz stat kartları bedelsiz ----

const LevelUpScript := preload("res://scripts/level_up_screen.gd")


## Havuzdaki (UPGRADES) HİÇBİR düz kartın bedeli yok; bedelli kartlar tam olarak özel kartlar (6 takas + 2 silah türü).
func test_plain_cards_are_cost_free_and_only_special_cards_pay() -> void:
	for u: Dictionary in LevelUpScript.UPGRADES:
		var id: String = str(u["id"])
		assert(not Special.has_cost(id) and not Special.is_plain(id), "%s: düz kartın bedeli olmamalı (madde 398)" % id)
		assert(Special.cost_stat(id) == "" and Special.cost_text(id, 1) == "" and Special.cost_value(id, 4) == 0.0, "%s: bedel metni/miktarı boş olmalı" % id)
		assert(Special.can_pay(id, null), "%s: bedelsiz kart her zaman çıkabilir" % id)
	for id: String in Special.ORDER:
		assert(Special.has_cost(id), "%s: büyük avantajlı özel kart bedelli kalmalı" % id)
	assert(Special.PLAIN_COSTS.is_empty(), "PLAIN_COSTS boş (bedel verilecek düz kart buraya eklenir)")


## Düz kart yalnız kazancını uygular: başka hiçbir stattan düşmez.
func test_plain_card_applies_only_its_gain() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 200.0
	player.health = 200.0
	var spd0: float = player.speed_card_percent
	var f0: float = player.fire_rate_mult
	player.apply_upgrade("max_health", 2) ## +35 can, bedel yok
	assert(is_equal_approx(player.max_health, 200.0 + TierSystem.health_card_for_tier(2)), "Can kartı kazancı eskisi gibi: %s" % player.max_health)
	assert(is_equal_approx(player.speed_card_percent, spd0), "Can kartı hızdan düşmemeli: %s" % player.speed_card_percent)
	var hp1: float = player.max_health
	player.apply_upgrade("fire_rate", 1) ## +%6 saldırı hızı, bedel yok
	assert(is_equal_approx(player.max_health, hp1), "Saldırı Hızı kartı can ödememeli: %s" % player.max_health)
	assert(player.fire_rate_mult < f0, "saldırı hızı kazancı (aralık kısalır): %s" % player.fire_rate_mult)
	var f1: float = player.fire_rate_mult
	player.apply_upgrade("damage", 1) ## +6 SG, bedel yok
	assert(is_equal_approx(player.fire_rate_mult, f1), "Saldırı Gücü kartı saldırı hızından düşmemeli: %s" % player.fire_rate_mult)
	assert(is_equal_approx(player.max_health, hp1), "Saldırı Gücü kartı can ödememeli")
	player.queue_free()


## Statlar zeminde olsa da bedelsiz düz kart çıkar (eskiden bedeli o stat olan kart elenirdi); bedelli özel kart yine elenir.
func test_plain_cards_stay_available_at_the_floor() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.speed_card_percent = Special.MIN_SPEED_CARD
	for id in ["max_health", "exp_gain", "lifesteal", "fire_rate", "shield_regen"]:
		assert(Special.can_pay(id, player), "%s: hız zeminde bile düz kart çıkabilmeli" % id)
	assert(not Special.can_pay("class_melee", player) and not Special.can_pay("trade_aegis", player), "hız zeminde: bedeli hız olan özel kartlar yine çıkmamalı")
	player.max_health = 44.0
	player.health = 44.0
	for id in ["luck", "crit_chance"]:
		assert(Special.can_pay(id, player), "%s: azami can zemine yakınken de düz kart çıkabilmeli" % id)
	assert(not Special.can_pay("trade_glass", player) and not Special.can_pay("class_ranged", player), "azami can zemine yakın: can bedelli özel kartlar çıkmamalı")
	player.queue_free()


## Silah türü kartları da bedel öder: Yakın Dövüş -%5 hız, Nişancılık -12 can.
func test_class_cards_pay_their_cost() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 100.0
	player.health = 100.0
	var spd0: float = player.speed_card_percent
	player.apply_upgrade("class_melee", 1)
	assert(is_equal_approx(spd0 - player.speed_card_percent, 0.05), "Yakın Dövüş Ustalığı hız öder: %s" % (spd0 - player.speed_card_percent))
	player.apply_upgrade("class_ranged", 2)
	assert(is_equal_approx(player.max_health, 100.0 - Special.cost_value("class_ranged", 2)), "Nişancılık can öder: %s" % player.max_health)
	player.queue_free()


## Düz kartların satırı da (alt satır = "artar/azalır") kutuya sığmalı - tüm düz kartlar x tüm kademeler.
func test_plain_card_texts_fit_the_row() -> void:
	var fake := FakeLevelPlayer.new()
	fake.add_to_group("player")
	add_child(fake)
	var scene: PackedScene = load("res://scenes/level_up_screen.tscn") as PackedScene
	var screen: CanvasLayer = scene.instantiate()
	add_child(screen)
	var card: Button = screen.cards[0]
	for u: Dictionary in LevelUpScript.UPGRADES:
		for tier in range(1, 5):
			screen._fill_row(card, u, tier, 3)
			var verb: Label = card.get_node("RowVerb") as Label
			assert(verb.text == ("azalır" if str(u["id"]) == "cooldown_reduction" else "artar"), "%s k%d alt satır bedelsiz olmalı: '%s'" % [u["id"], tier, verb.text])
			assert(verb.get_minimum_size().x <= 300.0, "%s k%d alt satır sığmıyor: '%s' %.0f px" % [u["id"], tier, verb.text, verb.get_minimum_size().x])
			var val: Label = card.get_node("RowValue") as Label
			assert(val.get_minimum_size().x <= 300.0, "%s k%d değer sığmıyor: '%s' %.0f px" % [u["id"], tier, val.text, val.get_minimum_size().x])
			var nm: Label = card.get_node("RowName") as Label
			assert(nm.get_minimum_size().x <= 430.0, "%s ad sığmıyor: '%s' %.0f px" % [u["id"], nm.text, nm.get_minimum_size().x])
			var sub: RichTextLabel = card.get_node("RowSub") as RichTextLabel
			assert(sub.get_content_width() <= sub.size.x, "%s k%d RowSub taşıyor" % [u["id"], tier])
	screen.free()
	fake.free()


## Otomatik seçim: bedelsiz düz kart tam puan alır (indirim yalnız PLAIN_COSTS'ta bedeli olan düz karta; tablo boş).
func test_auto_pick_scores_cost_free_plain_cards_at_full_value() -> void:
	var AutoPick := preload("res://scripts/auto_pick.gd")
	var s: float = AutoPick.upgrade_score("damage", 2, null)
	assert(is_equal_approx(s, AutoPick.BASE_VALUE["damage"] * 2.0), "bedelsiz düz kart puanı indirimsiz olmalı: %s" % s)


## ---- Madde 380: Kalkan Yenilenmesi + İyileştirme Gücü kartları (madde 398'den beri bedelsiz) ----

func test_new_stat_cards_are_in_the_pool_without_costs() -> void:
	var ids: Array = []
	for u: Dictionary in LevelUpScript.UPGRADES:
		ids.append(str(u["id"]))
	assert(ids.has("shield_regen") and ids.has("heal_power"), "iki yeni kart havuzda olmalı: %s" % [ids])
	assert(not Special.has_cost("shield_regen") and not Special.has_cost("heal_power"), "iki yeni kart da bedelsiz olmalı")


## Kazanç eşya/Ruh Mağazası ile aynı birikime gider, kademe merdiveni TierSystem'de; başka stattan düşmez.
func test_new_stat_cards_apply_gain_without_a_cost() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	var regen0: float = player.item_shield_regen_flat
	var spd0: float = player.speed_card_percent
	player.apply_upgrade("shield_regen", 3)
	assert(is_equal_approx(player.item_shield_regen_flat - regen0, 1.6), "Kalkan Yenilenmesi kademe 3 = +1,6/sn: %s" % (player.item_shield_regen_flat - regen0))
	assert(is_equal_approx(player.speed_card_percent, spd0), "Kalkan Yenilenmesi hızdan düşmemeli: %s" % player.speed_card_percent)
	var heal0: float = player.get_heal_shield_power()
	var f0: float = player.fire_rate_mult
	player.apply_upgrade("heal_power", 2)
	assert(is_equal_approx(player.get_heal_shield_power() - heal0, 0.03), "İyileştirme Gücü kademe 2 = +%%3: %s" % (player.get_heal_shield_power() - heal0))
	assert(is_equal_approx(player.heal_power_mult(), 1.0 + player.get_heal_shield_power()), "iyileştirme çarpanı yeni gücü okur")
	assert(is_equal_approx(player.fire_rate_mult, f0), "İyileştirme Gücü saldırı hızından düşmemeli: %s" % player.fire_rate_mult)
	assert(player.get_upgrade_count("shield_regen") == 1 and player.get_upgrade_count("heal_power") == 1, "kart sayaçları (geri katılım günlüğü)")
	player.queue_free()


## Kartta yazan sayı = uygulanan merdiven (kademe 1-4), birim "/sn" ve "%".
func test_new_stat_card_texts_match_the_ladders() -> void:
	var fake := FakeLevelPlayer.new()
	fake.add_to_group("player")
	add_child(fake)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	var want_regen: Array = ["+0.8/sn", "+1.2/sn", "+1.6/sn", "+2/sn"]
	var want_heal: Array = ["+%2", "+%3", "+%4", "+%5"]
	for t in range(1, 5):
		assert(screen._scaled_desc_value("+0.8/sn", t, "shield_regen") == want_regen[t - 1], "Kalkan Yenilenmesi k%d: %s" % [t, screen._scaled_desc_value("+0.8/sn", t, "shield_regen")])
		assert(screen._scaled_desc_value("+%2", t, "heal_power") == want_heal[t - 1], "İyileştirme Gücü k%d: %s" % [t, screen._scaled_desc_value("+%2", t, "heal_power")])
	screen.free()
	fake.free()
