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
	assert(Special.gain_text("trade_trigger", 1) == "+%12", "yüzde metni: %s" % Special.gain_text("trade_trigger", 1))
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
				## Madde 379: düz kartın alt satırı da kartın bedeli ("artar" yok).
				var plain_tier: int = int(screen._card_tiers[i])
				var plain_verb: Label = screen.cards[i].get_node("RowVerb") as Label
				assert(plain_verb.text == Special.cost_text(id, plain_tier) and plain_verb.text != "", "düz kartın alt satırı bedel olmalı: %s / %s" % [id, plain_verb.text])
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
	}
	for id: String in Special.ORDER:
		if not Special.is_trade(id):
			continue
		var stat: String = Special.gain_stat(id)
		for t in range(1, 5):
			var base: float = float((plain[stat] as Callable).call(t))
			var gain: float = Special.gain_value(id, t)
			assert(gain >= base * 1.5 - 0.0001, "%s kademe %d: kazanç %s düz karttan (%s) en az 1,5 kat olmalı" % [id, t, gain, base])


func test_blood_and_bulwark_follow_the_plain_card_tables() -> void:
	var want_blood: Array = [0.06, 0.12, 0.18, 0.24] ## Can Çalma tablosu %2/4/6/8 x 3
	var want_hp: Array = [40.0, 70.0, 100.0, 140.0] ## Can tablosu 20/35/50/70 x 2
	for t in range(1, 5):
		assert(is_equal_approx(Special.gain_value("trade_blood", t), want_blood[t - 1]), "Kan Anlaşması kademe %d: %s" % [t, Special.gain_value("trade_blood", t)])
		assert(is_equal_approx(Special.gain_value("trade_bulwark", t), want_hp[t - 1]), "Demir Kabuk kademe %d: %s" % [t, Special.gain_value("trade_bulwark", t)])
	assert(Special.gain_text("trade_blood", 1) == "+%6", "kart metni: %s" % Special.gain_text("trade_blood", 1))


## ---- Madde 379: düz stat kartlarının da bedeli var ----

const LevelUpScript := preload("res://scripts/level_up_screen.gd")


## Havuzdaki (UPGRADES) HER kartın bedeli tanımlı, bedel statı kazanç statından farklı ve zeminli bir stat; kademe 1-4 metni dolu.
func test_every_plain_card_has_a_cost_on_a_floored_stat() -> void:
	var floored: Array = ["max_health", "speed", "shield", "fire_rate"]
	for u: Dictionary in LevelUpScript.UPGRADES:
		var id: String = str(u["id"])
		assert(Special.is_plain(id) and Special.has_cost(id), "%s: düz kartın bedeli tanımlı olmalı" % id)
		var cs: String = Special.cost_stat(id)
		assert(floored.has(cs), "%s: bedel statı zeminli olmalı (%s)" % [id, cs])
		assert(cs != id and cs != Special.plain_gain_stat(id), "%s: kazanç ve bedel aynı stat olmamalı (%s)" % [id, cs])
		var prev: float = 0.0
		for t in range(1, 5):
			var v: float = Special.cost_value(id, t)
			assert(v > 0.0 and v >= prev, "%s kademe %d bedel artmalı/azalmamalı: %s" % [id, t, v])
			assert(Special.cost_text(id, t).begins_with("-"), "%s kademe %d bedel metni '-' ile başlar: %s" % [id, t, Special.cost_text(id, t)])
			prev = v
	assert(Special.cost_text("max_health", 1) == "-%1.5 Hareket Hızı", "Can kartı bedeli: %s" % Special.cost_text("max_health", 1))
	assert(Special.cost_text("fire_rate", 1) == "-6 Azami Can", "Saldırı Hızı kartı bedeli: %s" % Special.cost_text("fire_rate", 1))


## Kazanç eskisi gibi, bedel kartta yazan kadar düşer (iki-yer hatası olmasın).
func test_plain_card_applies_its_gain_and_exactly_the_written_cost() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.max_health = 200.0
	player.health = 200.0
	var spd0: float = player.speed_card_percent
	player.apply_upgrade("max_health", 2) ## +35 can, -%1.5 hız
	assert(is_equal_approx(player.max_health, 200.0 + TierSystem.health_card_for_tier(2)), "Can kartı kazancı eskisi gibi: %s" % player.max_health)
	assert(is_equal_approx(spd0 - player.speed_card_percent, Special.cost_value("max_health", 2)), "hız bedeli kartta yazan kadar: %s" % (spd0 - player.speed_card_percent))
	var hp1: float = player.max_health
	var f0: float = player.fire_rate_mult
	player.apply_upgrade("fire_rate", 1) ## +%6 saldırı hızı, -6 can
	assert(is_equal_approx(player.max_health, hp1 - 6.0), "Saldırı Hızı kartı 6 can öder: %s" % player.max_health)
	assert(player.fire_rate_mult < f0, "saldırı hızı kazancı (aralık kısalır): %s" % player.fire_rate_mult)
	var f1: float = player.fire_rate_mult
	player.apply_upgrade("damage", 1) ## +6 SG, -%2 saldırı hızı
	assert(is_equal_approx(player.fire_rate_mult, f1 / (1.0 - 0.02)), "Saldırı Gücü kartı saldırı hızından öder: %s" % player.fire_rate_mult)
	player.queue_free()


## Bedeli ödenemeyen oyuncuya düz kart çıkmaz; yine de uygulanırsa zemin delinmez.
func test_plain_card_is_withheld_at_the_floor() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.speed_card_percent = Special.MIN_SPEED_CARD
	assert(not Special.can_pay("max_health", player), "hız zeminde: bedeli hız olan Can kartı çıkmamalı")
	assert(not Special.can_pay("exp_gain", player) and not Special.can_pay("lifesteal", player), "hız bedelli diğer düz kartlar da çıkmamalı")
	assert(Special.can_pay("fire_rate", player), "bedeli can olan kart yine çıkabilmeli")
	player.apply_upgrade("max_health", 4)
	assert(player.speed_card_percent >= Special.MIN_SPEED_CARD - 0.0001, "hız bedeli zeminin altına inmemeli: %s" % player.speed_card_percent)
	player.max_health = 44.0
	player.health = 44.0
	assert(not Special.can_pay("luck", player) and not Special.can_pay("crit_chance", player), "azami can zemine yakın: can bedelli kartlar çıkmamalı")
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


## Düz kartların satırı da (alt satır = bedel) kutuya sığmalı - tüm düz kartlar x tüm kademeler.
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
			assert(verb.text == Special.cost_text(str(u["id"]), tier), "%s k%d alt satır bedel olmalı: '%s'" % [u["id"], tier, verb.text])
			assert(verb.get_minimum_size().x <= 300.0, "%s k%d bedel sığmıyor: '%s' %.0f px" % [u["id"], tier, verb.text, verb.get_minimum_size().x])
			var val: Label = card.get_node("RowValue") as Label
			assert(val.get_minimum_size().x <= 300.0, "%s k%d değer sığmıyor: '%s' %.0f px" % [u["id"], tier, val.text, val.get_minimum_size().x])
			var nm: Label = card.get_node("RowName") as Label
			assert(nm.get_minimum_size().x <= 430.0, "%s ad sığmıyor: '%s' %.0f px" % [u["id"], nm.text, nm.get_minimum_size().x])
			var sub: RichTextLabel = card.get_node("RowSub") as RichTextLabel
			assert(sub.get_content_width() <= sub.size.x, "%s k%d RowSub taşıyor" % [u["id"], tier])
	screen.free()
	fake.free()


## Otomatik seçim bedelli düz kartları da puanlar (özel kartlarla kıyaslanabilir).
func test_auto_pick_scores_plain_cards_with_a_discount() -> void:
	var AutoPick := preload("res://scripts/auto_pick.gd")
	var s: float = AutoPick.upgrade_score("damage", 2, null)
	assert(is_equal_approx(s, AutoPick.BASE_VALUE["damage"] * AutoPick.PLAIN_COST_DISCOUNT * 2.0), "düz kart puanı: %s" % s)


## ---- Madde 380: Kalkan Yenilenmesi + İyileştirme Gücü kartları ----

func test_new_stat_cards_are_in_the_pool_with_their_costs() -> void:
	var ids: Array = []
	for u: Dictionary in LevelUpScript.UPGRADES:
		ids.append(str(u["id"]))
	assert(ids.has("shield_regen") and ids.has("heal_power"), "iki yeni kart havuzda olmalı: %s" % [ids])
	assert(Special.cost_text("shield_regen", 1) == "-%1.5 Hareket Hızı", "Kalkan Yenilenmesi bedeli: %s" % Special.cost_text("shield_regen", 1))
	assert(Special.cost_text("heal_power", 1) == "-%2 Saldırı Hızı", "İyileştirme Gücü bedeli: %s" % Special.cost_text("heal_power", 1))


## Kazanç eşya/Ruh Mağazası ile aynı birikime gider, kademe merdiveni TierSystem'de; bedel kartta yazan kadar.
func test_new_stat_cards_apply_gain_and_written_cost() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	var regen0: float = player.item_shield_regen_flat
	var spd0: float = player.speed_card_percent
	player.apply_upgrade("shield_regen", 3)
	assert(is_equal_approx(player.item_shield_regen_flat - regen0, 1.6), "Kalkan Yenilenmesi kademe 3 = +1,6/sn: %s" % (player.item_shield_regen_flat - regen0))
	assert(is_equal_approx(spd0 - player.speed_card_percent, Special.cost_value("shield_regen", 3)), "hız bedeli kartta yazan kadar: %s" % (spd0 - player.speed_card_percent))
	var heal0: float = player.get_heal_shield_power()
	var f0: float = player.fire_rate_mult
	player.apply_upgrade("heal_power", 2)
	assert(is_equal_approx(player.get_heal_shield_power() - heal0, 0.03), "İyileştirme Gücü kademe 2 = +%%3: %s" % (player.get_heal_shield_power() - heal0))
	assert(is_equal_approx(player.heal_power_mult(), 1.0 + player.get_heal_shield_power()), "iyileştirme çarpanı yeni gücü okur")
	assert(is_equal_approx(player.fire_rate_mult, f0 / (1.0 - Special.cost_value("heal_power", 2))), "saldırı hızı bedeli: %s" % player.fire_rate_mult)
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
