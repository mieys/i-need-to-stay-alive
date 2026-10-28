extends RefCounted

## LEVEL ATLAMA PAZARI (kullanıcı isteği 2026-10-27, madde 386 prototipleri -> 2026-10-28 "D'yi oyuna al", madde 388): her level
## atlamada level kartlarının yanında 6 rastgele seçenek - silah alma / silah geliştirme (final sonrası güçlendirme dahil) / mana
## kalkanı türü / kalkan geliştirmesi / seyyar satıcının eşyaları. "diğer seçenekler tıpkı mevcut fiyatlarındaki bedellerindeki
## gibi çalışacak": fiyat, parçacık, indirim, tarif ve engel kuralları demircininkiyle (weapon_shop_logic.gd) ve satıcınınkiyle
## (items.gd, merchant_shop_screen.gd _on_buy_pressed) AYNI fonksiyonlardan gelir; satın alma da onlardan geçer (çift kural yok).
## Bu dosya kural + metin; görünüş level_market_view.gd.
## Seçenek: {"type": "weapon"|"wupgrade"|"wplus"|"shield"|"upgrade"|"item", "key", "slot", "index", "sold"} (demirci girdileriyle
## aynı adlar; "upgrade" = kalkan geliştirmesi).

const Logic := preload("res://scripts/weapon_shop_logic.gd")
const MerchantShopScript := preload("res://scripts/merchant_shop_screen.gd")
const WeaponScript := preload("res://scripts/weapon.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")

const OFFER_COUNT := 6
## Tür başına seçilme ağırlığı (benim seçimim; kullanıcı vermedi). Bir tür seçilince ağırlığı yarıya iner - 6 yuva tek türe
## yığılmasın (eşya havuzu silahlardan çok büyük). Havuzu boş türler hiç çekilmez.
const KIND_WEIGHTS := {"weapon": 1.0, "wupgrade": 1.5, "shield": 0.6, "upgrade": 1.0, "part": 1.2, "epic": 1.0, "legendary": 0.7}
const KIND_REPEAT_MULT := 0.5
## Yuva sırası: silah, silah geliştirme, mana kalkanı, kalkan geliştirmesi, eşya (parça -> epik -> efsanevi).
const SORT_ORDER := {"weapon": 0, "wupgrade": 1, "wplus": 1, "shield": 2, "upgrade": 3, "item": 4}

const TAG_WEAPON := Color("#e8a05a")
const TAG_WUP := Color("#9fd27e")
const TAG_SHIELD := Color("#8ecdf0")
const ROMAN := ["I", "II", "III", "IV", "V"]


## Pazarın karıştırma bedeli: seyyar satıcının formülü (kademe/zaman ölçekli), sayaç level kartlarınınkinden AYRI.
static func reroll_cost(rerolls_done: int) -> int:
	return MerchantShopScript.reroll_cost(rerolls_done)


static func offer_id(e: Dictionary) -> String:
	return "%s|%s|%d|%d" % [e.get("type", ""), e.get("key", ""), int(e.get("slot", -1)), int(e.get("index", -1))]


## ---------------------------------------------------------------- havuz
## Yapısal olarak alınabilen her seçenek (altın / parçacık yetmese de görünür, sebebi yazar). exclude: bir önceki çekilişin
## offer_id'leri - yeterli seçenek varsa karıştırma aynı seçenekleri geri getirmez.
static func candidates(player: Node) -> Dictionary:
	var out: Dictionary = {}
	for k: String in KIND_WEIGHTS:
		out[k] = []
	## silah: açılmış, sahip olunmayan, yuva boşsa (parçacık eksikliği engel değil, sebep olarak görünür)
	if GameManager.owned_weapons.size() < Logic.max_weapons(player):
		for key: String in Logic.weapon_keys():
			if not GameManager.owns_weapon(key):
				(out["weapon"] as Array).append({"type": "weapon", "key": key})
	## silah geliştirme: her silah için sıradaki alınabilir geliştirmeler (final 4'ü bitince, sonra sınırsız güçlendirme)
	for slot in GameManager.owned_weapons.size():
		var rows: Array = Logic.slot_upgrade_rows(slot)
		if rows.is_empty():
			continue
		if EnchantDefs.is_complete(Logic.slot_enchant(slot)):
			(out["wupgrade"] as Array).append({"type": "wplus", "slot": slot})
			continue
		for row: Dictionary in rows:
			var idx: int = int(row["index"])
			if Logic.wupgrade_taken(slot, idx):
				continue
			if bool(row["final"]) and Logic.wupgrade_taken_count(slot) < rows.size() - 1:
				continue
			(out["wupgrade"] as Array).append({"type": "wupgrade", "slot": slot, "index": idx})
	## mana kalkanı: tür yalnız Standart'tayken; geliştirme yalnız tür alınınca
	if GameManager.shield_enchant == "":
		for key: String in Logic.shield_keys():
			(out["shield"] as Array).append({"type": "shield", "key": key})
	else:
		for i in Logic.upgrade_lines().size():
			var lim: int = Logic.upgrade_limit(i)
			if lim <= 0 or Logic.upgrade_count(i) < lim:
				(out["upgrade"] as Array).append({"type": "upgrade", "index": i})
	## eşya: satıcının havuz kuralı (traveling_merchant.gd _generate_stock) + slot/tekil/kopya sınırı
	var slots: int = int(player.call("get_max_item_slots")) if player and player.has_method("get_max_item_slots") else 1
	for key: String in Items.KEYS:
		if Items.is_support_only(key) and not Items.is_ally_support_char(GameManager.selected_char_id):
			continue
		if Items.purchase_block_reason(key, GameManager.owned_items, slots) != "":
			continue
		var bucket: String = ["part", "epic", "legendary"][Items.kademe(key) - 1]
		(out[bucket] as Array).append({"type": "item", "key": key})
	return out


static func roll_offers(player: Node, exclude: Array = [], count: int = OFFER_COUNT) -> Array:
	var pools: Dictionary = candidates(player)
	var total: int = 0
	for k: String in pools:
		total += (pools[k] as Array).size()
	## Önceki çekilişi dışarıda bırak - kalan yetmiyorsa bırakma (az seçenekli geç oyunda pazar boş kalmasın).
	if total - exclude.size() >= count:
		for k: String in pools:
			pools[k] = (pools[k] as Array).filter(func(e: Dictionary) -> bool: return not exclude.has(offer_id(e)))
	var weights: Dictionary = KIND_WEIGHTS.duplicate()
	var picked: Array = []
	while picked.size() < count:
		var sum: float = 0.0
		for k: String in pools:
			if not (pools[k] as Array).is_empty():
				sum += float(weights[k])
		if sum <= 0.0:
			break
		var r: float = randf() * sum
		var kind: String = ""
		for k: String in pools:
			if (pools[k] as Array).is_empty():
				continue
			r -= float(weights[k])
			kind = k
			if r <= 0.0:
				break
		var pool: Array = pools[kind]
		var got: Dictionary = pool.pop_at(randi() % pool.size())
		picked.append(got)
		weights[kind] = float(weights[kind]) * KIND_REPEAT_MULT
		if kind == "wupgrade":
			## Silah başına tek geliştirme: aynı silahın iki satırı aynı pazarda tekrar gibi okunuyordu.
			pools[kind] = pool.filter(func(e: Dictionary) -> bool: return int(e["slot"]) != int(got["slot"]))
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _offer_less(a, b))
	return picked


static func _offer_less(a: Dictionary, b: Dictionary) -> bool:
	var oa: int = int(SORT_ORDER.get(a["type"], 9))
	var ob: int = int(SORT_ORDER.get(b["type"], 9))
	if oa != ob:
		return oa < ob
	if a["type"] == "item":
		var ka: int = Items.kademe(str(a["key"]))
		var kb: int = Items.kademe(str(b["key"]))
		if ka != kb:
			return ka < kb
		return price(a) < price(b)
	return int(a.get("slot", 0)) < int(b.get("slot", 0))


## ---------------------------------------------------------------- fiyat / engel / satın alma
static func price(e: Dictionary) -> int:
	match str(e.get("type", "")):
		"weapon":
			return Logic.weapon_price(GameManager.owned_weapons.size())
		"wupgrade":
			return Logic.wupgrade_price(int(e["slot"]), int(e["index"]))
		"wplus":
			return Logic.wplus_price(int(e["slot"]))
		"shield":
			return Logic.shield_price()
		"upgrade":
			return Logic.upgrade_price(int(e["index"]))
		"item":
			return GameManager.apply_shop_discount(int(Items.plan_purchase(str(e["key"]), GameManager.owned_items).get("cost", 0)))
	return 0


## Tarif indirimi varsa indirimsiz fiyat (üstü çizili gösterilir), yoksa 0.
static func full_price(e: Dictionary) -> int:
	if str(e.get("type", "")) != "item":
		return 0
	var plan: Dictionary = Items.plan_purchase(str(e["key"]), GameManager.owned_items)
	var full: int = GameManager.apply_shop_discount(int(plan.get("full", 0)))
	return full if full > price(e) else 0


static func shards(e: Dictionary) -> int:
	match str(e.get("type", "")):
		"weapon":
			return Logic.weapon_shard_cost()
		"wupgrade":
			return Logic.wupgrade_shard_cost(int(e["slot"]), int(e["index"]))
		"wplus":
			return Logic.SHARD_COST_WPLUS
		"upgrade":
			return Logic.SHARD_COST_UPGRADE
	return 0


## "" = alınabilir; değilse oyuncuya gösterilecek sebep (alındı / sınır / parçacık / altın).
static func block_reason(player: Node, e: Dictionary) -> String:
	if bool(e.get("sold", false)):
		return "Alındı"
	var r: String = ""
	match str(e.get("type", "")):
		"weapon":
			r = Logic.weapon_block_reason(player, str(e["key"]))
		"wupgrade":
			r = Logic.wupgrade_block_reason(int(e["slot"]), int(e["index"]))
		"wplus":
			r = Logic.wplus_block_reason(int(e["slot"]))
		"shield":
			r = Logic.shield_block_reason(str(e["key"]))
		"upgrade":
			r = Logic.upgrade_block_reason(int(e["index"]))
		"item":
			var slots: int = int(player.call("get_max_item_slots")) if player and player.has_method("get_max_item_slots") else 1
			r = Items.purchase_block_reason(str(e["key"]), GameManager.owned_items, slots)
	if r == "" and GameManager.gold < price(e):
		r = "%d altın eksik" % (price(e) - GameManager.gold)
	return r


## Satın alır (demirci / satıcı yollarıyla AYNI); başarılıysa seçenek "sold" olur.
static func buy(player: Node, e: Dictionary) -> bool:
	if block_reason(player, e) != "":
		return false
	var ok: bool = false
	match str(e.get("type", "")):
		"weapon":
			ok = Logic.buy_weapon(player, str(e["key"]))
		"wupgrade":
			ok = Logic.buy_wupgrade(player, int(e["slot"]), int(e["index"]))
		"wplus":
			ok = Logic.buy_wplus(player, int(e["slot"]))
		"shield":
			ok = Logic.buy_shield(player, str(e["key"]))
		"upgrade":
			ok = Logic.buy_upgrade(player, int(e["index"]))
		"item":
			## merchant_shop_screen.gd _on_buy_pressed ile aynı sıra: tarif planı, acquire_item, sonra altın.
			var key: String = str(e["key"])
			var cost: int = price(e)
			var plan: Dictionary = Items.plan_purchase(key, GameManager.owned_items)
			if player and player.has_method("acquire_item") and player.acquire_item(key, plan, cost):
				GameManager.gold -= cost
				ok = true
	if ok:
		e["sold"] = true
	return ok


## ---------------------------------------------------------------- görünen metin
## {tag, tag_col, name, sub, lines, tex, wtier (0 = silah değil)}
static func describe(e: Dictionary, player: Node = null) -> Dictionary:
	var d: Dictionary = {"tag": "", "tag_col": Color.WHITE, "name": "", "sub": "", "lines": [], "tex": null, "wtier": 0}
	match str(e.get("type", "")):
		"weapon":
			var key: String = str(e["key"])
			d["tag"] = "SİLAH"
			d["tag_col"] = TAG_WEAPON
			d["name"] = WeaponCatalog.display_name(key)
			d["sub"] = "Yeni silah · %s · yuva %d/%d" % [WeaponCatalog.category_label(key), GameManager.owned_weapons.size() + 1,
				Logic.max_weapons(player)]
			d["lines"] = _trait_lines(key)
			d["tex"] = WeaponTierArt.texture(key, 1)
			d["wtier"] = 1
		"wupgrade", "wplus":
			var slot: int = int(e["slot"])
			var key: String = str((GameManager.owned_weapons[slot] as Dictionary).get("key", "")) if slot < GameManager.owned_weapons.size() else ""
			var plus: bool = e["type"] == "wplus"
			var now_t: int = _slot_tier(slot)
			var lines: Array = []
			var next_t: int = now_t
			if plus:
				var p0: int = 5 + Logic.wplus_count(slot)
				d["sub"] = "Güçlendirme +%d" % (Logic.wplus_count(slot) + 1)
				lines.append(_tier_gain_text(p0, p0 + 1))
				next_t = 5
			else:
				var rows: Array = Logic.slot_upgrade_rows(slot)
				var row: Dictionary = rows[int(e["index"])]
				next_t = 5 if bool(row["final"]) else mini(4, now_t + 1)
				d["sub"] = "Kademe %s → %s · %s" % [ROMAN[now_t - 1], ROMAN[next_t - 1], row["name"]]
				lines.append(str(row["text"]))
				if next_t != now_t:
					lines.append(_tier_gain_text(now_t, next_t))
			d["tag"] = "SİLAH GELİŞTİRME"
			d["tag_col"] = TAG_WUP
			d["name"] = WeaponCatalog.display_name(key)
			d["lines"] = lines
			d["tex"] = WeaponTierArt.texture(key, next_t)
			d["wtier"] = next_t
		"shield":
			var key: String = str(e["key"])
			d["tag"] = "MANA KALKANI"
			d["tag_col"] = TAG_SHIELD
			d["name"] = ShieldEnchantDefs.type_name(key)
			d["sub"] = "Kalkan türü · Standart'ın yerine"
			d["lines"] = [Logic.shield_summary(key), str((ShieldEnchantDefs.TYPES.get(key, {}) as Dictionary).get("desc", ""))]
			d["tex"] = load(str(ShieldEnchantDefs.ICONS.get(key, "")))
		"upgrade":
			var st: String = GameManager.shield_enchant
			var i: int = int(e["index"])
			var lim: int = Logic.upgrade_limit(i)
			d["tag"] = "KALKAN GELİŞTİRME"
			d["tag_col"] = TAG_SHIELD
			d["name"] = ShieldEnchantDefs.type_name(st)
			d["sub"] = "Geliştirme %d · %s" % [i + 1, ("%d/%d alındı" % [Logic.upgrade_count(i), lim]) if lim > 0 else ("%d kez alındı" % Logic.upgrade_count(i))]
			d["lines"] = Array(Logic.upgrade_effect_text(i).split("\n"))
			d["tex"] = load(str(ShieldEnchantDefs.ICONS.get(st, "")))
		"item":
			var key: String = str(e["key"])
			var kd: int = Items.kademe(key)
			d["tag"] = ["PARÇA", "EPİK", "EFSANEVİ"][kd - 1]
			d["tag_col"] = [Color("#c39a64"), Color("#6f9df2"), Color("#b98af2")][kd - 1] ## shop_dark_kit.gd TIER_COL
			d["name"] = Items.item_name(key)
			d["sub"] = _item_sub(key)
			d["lines"] = _item_lines(key)
			d["tex"] = Items.icon(key)
	return d


static func _slot_tier(slot: int) -> int:
	var ench: Dictionary = Logic.slot_enchant(slot)
	if ench.is_empty():
		return 1
	if EnchantDefs.is_complete(ench):
		return 5
	return mini(4, 1 + (EnchantDefs.upgrades_taken(ench) as Array).size())


## Demirci ayrıntısındaki satırla aynı hesap (weapon_shop_screen.gd): kademe statı farkı.
static func _tier_gain_text(t0: int, t1: int) -> String:
	var dmg: int = roundi((WeaponScript.tier_damage_mult(t1) / WeaponScript.tier_damage_mult(t0) - 1.0) * 100.0)
	var spd: int = roundi((WeaponScript.tier_fire_rate_mult(t0) / WeaponScript.tier_fire_rate_mult(t1) - 1.0) * 100.0)
	return "+%%%d hasar, +%%%d saldırı hızı" % [dmg, spd]


## WeaponCatalog.trait_text: "<Özellik>: ..." ya da "HASAR: ... · ... · ..." - parçalar ayrı satır.
static func _trait_lines(key: String) -> Array:
	var out: Array = []
	for part in WeaponCatalog.trait_text(key).split(" · "):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	return out


static func _item_sub(key: String) -> String:
	var plan: Dictionary = Items.plan_purchase(key, GameManager.owned_items)
	var cons: Array = plan.get("consume", [])
	if not cons.is_empty():
		var names: Array = []
		for idx in cons:
			var n: String = Items.item_name(str((GameManager.owned_items[int(idx)] as Dictionary).get("key", "")))
			if not names.has(n):
				names.append(n)
		return "Tarif: %s sende" % ", ".join(names)
	if Items.kademe(key) == Items.KADEME_PARCA and Items.part_copies(key, GameManager.owned_items) > 0:
		return "%d. kopya · fiyat +%%%d" % [Items.part_copies(key, GameManager.owned_items) + 1,
			roundi((Items.repeat_mult(key, GameManager.owned_items) - 1.0) * 100.0)]
	return "Tarifli eşya" if not Items.recipe(key).is_empty() else "Eşya"


## Stat satırları + pasif (Items.describe ile aynı metin; pasif bir stat satırının tekrarıysa yazılmaz - Kabuk Delen).
static func _item_lines(key: String) -> Array:
	var lines: Array = []
	for ln in Items.describe(key).split("\n"):
		if ln.strip_edges() != "" and not ln.begins_with("Pasif:"):
			lines.append(ln.strip_edges())
	var passive: String = str(Items.get_def(key).get("passive", "")).strip_edges()
	if passive != "" and not lines.any(func(l: String) -> bool: return l.replace("+", "").trim_suffix(".") == passive.trim_suffix(".")):
		lines.append("Pasif: " + passive)
	return lines
