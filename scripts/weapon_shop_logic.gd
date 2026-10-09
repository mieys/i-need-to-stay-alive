extends RefCounted

## SİLAH SATICISI (demirci dükkanı) - satın alma kuralları, TEK kaynak (ekran: weapon_shop_screen.gd, giriş/örs: weapon_shop.gd).
## Kullanıcı isteği (2026-10-07): "bundan sonra silahlar ve kalkanlar burada satılacak. seyyar satıcıda silah satılmayacak.
## içinde tüm silahlar görünebilir ve alınabilir sınırlar dahilinde" + "kalkanlar satılsın, geliştirmeleri de geliştirme olarak
## satılsın bir kalkanı aldıktan sonra" + "silahlar aynı fiyat, kalkanlar 250".
##
## SİLAH: 15 silahın hepsi (WeaponCatalog.KEYS) satılır. Fiyat seyyar satıcının/dükkanın eski kademeli fiyatıyla AYNI
## (ShopPanel._copy_cost_raw: sahip olunan 1. silahtan sonraki ilk 30, sonrakiler 80 altın; "Para" ruhani pasifinin %10 indirimi
## GameManager.apply_shop_discount ile). Sınırlar: toplam silah slotu (player.get_max_owned_weapons, 5) ve altın. Aynı silahtan
## ikinci kopya alınabilir (her kopya bağımsız). Ziyaret başına 1 kez kuralı YOK (kalıcı bir dükkan).
##
## SİLAH PARÇACIĞI (kullanıcı isteği 2026-10-08: "blacksmithdeki silahların silah parçacığı ile alınmasını istiyorum ... silah almak 10 parçacık +
## bir miktar altın"): silah = SHARD_COST_WEAPON parçacık + yukarıdaki altın (altın fiyatları AYNEN kaldı, kullanıcı seçti). Parçacık yaratıklardan düşer
## ve herkese eşit gider (bkz. weapon_shard_drop.gd). Kalkan türü ve geliştirmeleri PARÇACIKSIZ (kullanıcı: "kalkanlar geliştirme için parçacık
## istemeyecek" ve netleştirmede "geliştirmeler de parçacıksız") - sabitler SHARD_COST_UPGRADE/SHARD_COST_SHIELD 0; ilk mesajındaki "geliştirme başına 5
## parçacık" istenirse tek satırlık değişiklikle (SHARD_COST_UPGRADE = 5) devreye girer, kod ve ekran hazır. Parçacıkta "Para" indirimi yok.
##
## KALKAN: Savaş / Enerji / Kale (ShieldEnchantDefs.ENCHANT_KEYS) 250 altın, satın alınca Standart'ın yerine geçer. Tür KALICI
## (eski efsun kuralı: bir tür seçilince diğer ikisi o oyunda bir daha alınamaz) - değiştirilebilir olsun istenirse
## shield_block_reason'daki ikinci koşul kalkar, geliştirmeler sıfırlanır. GELİŞTİRMELER (türün "upgrades" listesi, limit 0 =
## sınırsız): ancak tür alındıktan sonra; fiyat UPGRADE_BASE_PRICE + UPGRADE_PRICE_STEP x (o geliştirmeden zaten alınan sayı)
## (kullanıcı fiyat vermedi - bunlar benim seçimim, tek yerden ayarlanır). Kalkanın durum etkisi ShieldEnchantDefs.apply +
## player.apply_enchant_choice ile (eski efsun kartlarıyla birebir aynı yol).

const ShopScript := preload("res://scripts/shop_panel.gd")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")

const SHIELD_PRICE := 250
const UPGRADE_BASE_PRICE := 100
const UPGRADE_PRICE_STEP := 25
const DEFAULT_MAX_WEAPONS := 5
const SHARD_COST_WEAPON := 10
const SHARD_COST_UPGRADE := 0
const SHARD_COST_SHIELD := 0
## SİLAH EFSUNU GELİŞTİRMELERİ (kullanıcı isteği 2026-10-08: "bu efsunlı özellik olarak kendine alan silahların geliştirmeleri
## blacksmithde 5 parçacık + bir miktar altın ile alınabilecek"; final için "daha pahalı: 10 parçacık + yüksek altın"). Altın tutarlarını
## kullanıcı vermedi - benim seçimim (kalkan geliştirmesiyle aynı desen: alınan sayıya göre artar): normal geliştirme
## 100 + 30 x (o silahta zaten alınan geliştirme), final sabit 400. Geliştirmeler o silah KOPYASINA özel (kopyalar bağımsız).
const WUPGRADE_BASE_PRICE := 100
const WUPGRADE_PRICE_STEP := 30
const WFINAL_PRICE := 400
const SHARD_COST_WUPGRADE := 5
const SHARD_COST_WFINAL := 10


# ------------------------------------------------------------------ silah

static func weapon_keys() -> Array:
	return WeaponCatalogScript.KEYS


static func max_weapons(player: Node) -> int:
	if player != null and is_instance_valid(player) and player.has_method("get_max_owned_weapons"):
		return int(player.get_max_owned_weapons())
	return DEFAULT_MAX_WEAPONS


## Sıradaki (sahip olunan sayıya göre) silahın fiyatı - indirim dahil.
static func weapon_price(owned_count: int) -> int:
	return GameManager.apply_shop_discount(ShopScript._copy_cost_raw("", owned_count + 1))


static func owned_count(key: String) -> int:
	var n: int = 0
	for entry in GameManager.owned_weapons:
		if str((entry as Dictionary).get("key", "")) == key:
			n += 1
	return n


static func weapon_shard_cost() -> int:
	return SHARD_COST_WEAPON


## Satır türüne ("weapon" / "shield" / "upgrade") göre parçacık maliyeti (ekran bunu gösterir, kurallar yukarıda uygular).
static func entry_shard_cost(kind: String) -> int:
	match kind:
		"weapon":
			return SHARD_COST_WEAPON
		"shield":
			return SHARD_COST_SHIELD
		"upgrade":
			return SHARD_COST_UPGRADE
		"wupgrade":
			return SHARD_COST_WUPGRADE
		"wfinal":
			return SHARD_COST_WFINAL
	return 0


## Parçacık yetmiyorsa gösterilecek sebep ("" = yeter). cost <= 0 ise hiç sormaz.
static func shard_shortfall_reason(cost: int) -> String:
	if cost > 0 and GameManager.weapon_shards < cost:
		return "Silah parçacığı yetersiz (%d/%d)" % [GameManager.weapon_shards, cost]
	return ""


## "" = alınabilir (altın hariç), değilse oyuncuya gösterilecek sebep. Parçacık eksikliği de sebeptir (altın ayrıca denetlenir).
static func weapon_block_reason(player: Node, key: String) -> String:
	if not WeaponCatalogScript.is_valid(key):
		return "Bilinmeyen silah"
	var max_w: int = max_weapons(player)
	if GameManager.owned_weapons.size() >= max_w:
		return "Silah slotları dolu (%d/%d)" % [GameManager.owned_weapons.size(), max_w]
	return shard_shortfall_reason(weapon_shard_cost())


static func can_buy_weapon(player: Node, key: String) -> bool:
	return weapon_block_reason(player, key) == "" and GameManager.gold >= weapon_price(GameManager.owned_weapons.size())


## Silahı alır: parçacığı + altını düşer, deftere yazar, gerçek silah düğümünü oyuncuya ekler (shop_panel.gd _on_buy_copy /
## seyyar satıcıdaki eski silah satışıyla AYNI sıra). Oyuncu silahı eklemezse (slot) işlem geri alınır (parçacık ve altın iade).
static func buy_weapon(player: Node, key: String) -> bool:
	if not can_buy_weapon(player, key):
		return false
	var cost: int = weapon_price(GameManager.owned_weapons.size())
	var shards: int = weapon_shard_cost()
	GameManager.gold -= cost
	GameManager.add_weapon_shards(-shards)
	GameManager.owned_weapons.append(EnchantDefs.new_weapon_entry(key, 1, cost, shards))
	if player != null and is_instance_valid(player) and player.has_method("buy_weapon_copy"):
		if not bool(player.buy_weapon_copy(key, 1)):
			GameManager.owned_weapons.pop_back()
			GameManager.gold += cost
			GameManager.add_weapon_shards(shards)
			return false
	return true


# ------------------------------------------------------------------ silah efsunu (kalıcı özellik) geliştirmeleri

## Silah kopyasının (owned_weapons dizini) efsun kaydı ({} = özelliği yok).
static func slot_enchant(slot: int) -> Dictionary:
	if slot < 0 or slot >= GameManager.owned_weapons.size():
		return {}
	var e: Dictionary = GameManager.owned_weapons[slot]
	EnchantDefs.ensure_trait(e)
	return e.get("enchant", {})


static func slot_trait_id(slot: int) -> String:
	return str(slot_enchant(slot).get("id", ""))


## [{index, name, text, final}]: 4 normal geliştirme + final.
static func slot_upgrade_rows(slot: int) -> Array:
	return EnchantDefs.upgrade_rows(slot_trait_id(slot))


static func wupgrade_taken(slot: int, index: int) -> bool:
	var ench: Dictionary = slot_enchant(slot)
	var rows: Array = slot_upgrade_rows(slot)
	if index < 0 or index >= rows.size():
		return false
	if bool((rows[index] as Dictionary)["final"]):
		return EnchantDefs.is_complete(ench)
	return (EnchantDefs.upgrades_taken(ench) as Array).has(index)


static func wupgrade_taken_count(slot: int) -> int:
	return (EnchantDefs.upgrades_taken(slot_enchant(slot)) as Array).size()


static func wupgrade_is_final(slot: int, index: int) -> bool:
	var rows: Array = slot_upgrade_rows(slot)
	return index >= 0 and index < rows.size() and bool((rows[index] as Dictionary)["final"])


static func wupgrade_shard_cost(slot: int, index: int) -> int:
	return SHARD_COST_WFINAL if wupgrade_is_final(slot, index) else SHARD_COST_WUPGRADE


## Bir sonraki alımın altın fiyatı - indirim dahil.
static func wupgrade_price(slot: int, index: int) -> int:
	if wupgrade_is_final(slot, index):
		return GameManager.apply_shop_discount(WFINAL_PRICE)
	return GameManager.apply_shop_discount(WUPGRADE_BASE_PRICE + WUPGRADE_PRICE_STEP * wupgrade_taken_count(slot))


static func wupgrade_block_reason(slot: int, index: int) -> String:
	var rows: Array = slot_upgrade_rows(slot)
	if rows.is_empty() or index < 0 or index >= rows.size():
		return "Bu silahın geliştirmesi yok"
	if wupgrade_taken(slot, index):
		return "Bu geliştirme alındı"
	if wupgrade_is_final(slot, index):
		var need: int = rows.size() - 1
		if wupgrade_taken_count(slot) < need:
			return "Önce %d geliştirmenin hepsini al (%d/%d)" % [need, wupgrade_taken_count(slot), need]
	return shard_shortfall_reason(wupgrade_shard_cost(slot, index))


static func can_buy_wupgrade(slot: int, index: int) -> bool:
	return wupgrade_block_reason(slot, index) == "" and GameManager.gold >= wupgrade_price(slot, index)


## Satın alır: parçacığı + altını düşer, efsun kaydına işler (player.apply_enchant_choice: silah düğümünü yeniden kurar + halka efekti;
## oyuncu yoksa - test - kayda doğrudan yazılır).
static func buy_wupgrade(player: Node, slot: int, index: int) -> bool:
	if not can_buy_wupgrade(slot, index):
		return false
	var final_up: bool = wupgrade_is_final(slot, index)
	var shards: int = wupgrade_shard_cost(slot, index)
	GameManager.gold -= wupgrade_price(slot, index)
	GameManager.add_weapon_shards(-shards)
	if slot >= 0 and slot < GameManager.owned_weapons.size():
		EnchantDefs.record_shards_spent(GameManager.owned_weapons[slot], shards) ## satışta %70'i geri gelir
	var card: Dictionary = {"type": "final", "slot": slot} if final_up else {"type": "step", "slot": slot, "up": index}
	if player != null and is_instance_valid(player) and player.has_method("apply_enchant_choice"):
		player.apply_enchant_choice(card)
	else:
		var ench: Dictionary = slot_enchant(slot)
		if final_up:
			ench["final"] = true
		else:
			var ups: Array = ench.get("ups", [])
			ups.append(index)
			ench["ups"] = ups
	return true


# ------------------------------------------------------------------ kalkan türleri

static func shield_keys() -> Array:
	return ShieldEnchantDefs.ENCHANT_KEYS


static func shield_price() -> int:
	return GameManager.apply_shop_discount(SHIELD_PRICE)


static func shield_block_reason(key: String) -> String:
	if not ShieldEnchantDefs.ENCHANT_KEYS.has(key):
		return "Bilinmeyen kalkan"
	if GameManager.shield_enchant == key:
		return "Bu kalkan sende"
	if GameManager.shield_enchant != "":
		return "Başka bir kalkan türü seçildi"
	return shard_shortfall_reason(SHARD_COST_SHIELD)


static func can_buy_shield(key: String) -> bool:
	return shield_block_reason(key) == "" and GameManager.gold >= shield_price()


static func buy_shield(player: Node, key: String) -> bool:
	if not can_buy_shield(key):
		return false
	GameManager.gold -= shield_price()
	GameManager.add_weapon_shards(-SHARD_COST_SHIELD)
	_apply_card(player, {"type": "shield_pick", "slot": -1, "id": key})
	return true


# ------------------------------------------------------------------ kalkan geliştirmeleri

## Sahip olunan kalkan türünün geliştirme satırları ([] = tür henüz alınmadı).
static func upgrade_lines() -> Array:
	if GameManager.shield_enchant == "":
		return []
	return (ShieldEnchantDefs.TYPES[GameManager.shield_enchant].get("upgrades", []) as Array)


static func upgrade_limit(index: int) -> int:
	var lines: Array = upgrade_lines()
	return int(lines[index].get("limit", 0)) if index >= 0 and index < lines.size() else 0


static func upgrade_count(index: int) -> int:
	return ShieldEnchantDefs.upgrade_count(index)


## Bir sonraki alımın fiyatı (o geliştirmeden zaten alınan sayıya göre artar) - indirim dahil.
static func upgrade_price(index: int) -> int:
	return GameManager.apply_shop_discount(UPGRADE_BASE_PRICE + UPGRADE_PRICE_STEP * upgrade_count(index))


static func upgrade_block_reason(index: int) -> String:
	if GameManager.shield_enchant == "":
		return "Önce bir kalkan türü al"
	var lines: Array = upgrade_lines()
	if index < 0 or index >= lines.size() or index >= GameManager.shield_enchant_ups.size():
		return "Bilinmeyen geliştirme"
	var limit: int = upgrade_limit(index)
	if limit > 0 and upgrade_count(index) >= limit:
		return "Sınıra ulaşıldı (%d/%d)" % [upgrade_count(index), limit]
	return shard_shortfall_reason(SHARD_COST_UPGRADE)


static func can_buy_upgrade(index: int) -> bool:
	return upgrade_block_reason(index) == "" and GameManager.gold >= upgrade_price(index)


static func buy_upgrade(player: Node, index: int) -> bool:
	if not can_buy_upgrade(index):
		return false
	GameManager.gold -= upgrade_price(index)
	GameManager.add_weapon_shards(-SHARD_COST_UPGRADE)
	_apply_card(player, {"type": "shield_up", "slot": -1, "index": index})
	return true


## Geliştirmenin etkisi: "+60 Kalkan\n+2 Yenilenme/sn" (limit/yenilenme/soğurma/bekleme alanlarından).
static func upgrade_effect_text(index: int) -> String:
	var lines: Array = upgrade_lines()
	if index < 0 or index >= lines.size():
		return ""
	var up: Dictionary = lines[index]
	var parts: Array = []
	if float(up.get("power", 0.0)) != 0.0:
		parts.append("%+d Kalkan" % int(round(float(up["power"]))))
	if float(up.get("regen", 0.0)) != 0.0:
		parts.append("%s Yenilenme/sn" % _signed(float(up["regen"])))
	if float(up.get("absorption", 0.0)) != 0.0:
		parts.append("%+d%% Soğurma" % int(round(float(up["absorption"]) * 100.0)))
	if float(up.get("delay", 0.0)) != 0.0:
		parts.append("%s sn Bekleme" % _signed(float(up["delay"])))
	return "\n".join(parts)


## Kalkan türünün tek satırlık özeti (kart alt yazısı): "160 kalkan · %60 soğurma · 4/sn".
static func shield_summary(key: String) -> String:
	var d: Dictionary = ShieldEnchantDefs.TYPES.get(key, {})
	if d.is_empty():
		return ""
	return "%d kalkan · %%%d soğurma · %s/sn" % [int(round(float(d["power"]))), int(round(float(d["absorption"]) * 100.0)), _num(float(d["regen"]))]


static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v)


static func _signed(v: float) -> String:
	return ("+" if v > 0.0 else "") + _num(v)


## Kartı oyuncuya (efsun kartlarıyla AYNI yol: halka/kıvılcım efekti + kalkan statlarını yenileme) ya da oyuncu yoksa
## (test) doğrudan GameManager durumuna işler.
static func _apply_card(player: Node, card: Dictionary) -> void:
	if player != null and is_instance_valid(player) and player.has_method("apply_enchant_choice"):
		player.apply_enchant_choice(card)
	else:
		ShieldEnchantDefs.apply(card)
