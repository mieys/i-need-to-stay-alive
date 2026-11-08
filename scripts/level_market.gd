extends RefCounted
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## LEVEL ATLAMA PAZARI (kullanıcı isteği 2026-10-27, madde 386 prototipleri -> 2026-10-28 "D'yi oyuna al", madde 388): her level
## atlamada level kartlarının yanında 6 rastgele seçenek - silah alma / silah geliştirme (final sonrası güçlendirme dahil) / mana
## kalkanı türü / kalkan geliştirmesi / seyyar satıcının eşyaları. "diğer seçenekler tıpkı mevcut fiyatlarındaki bedellerindeki
## gibi çalışacak": fiyat, parçacık, indirim, tarif ve engel kuralları demircininkiyle (weapon_shop_logic.gd) ve satıcınınkiyle
## (items.gd, merchant_shop_screen.gd _on_buy_pressed) AYNI fonksiyonlardan gelir; satın alma da onlardan geçer (çift kural yok).
## Bu dosya kural + metin; görünüş level_market_view.gd.
## Seçenek: {"type": "weapon"|"wupgrade"|"wplus"|"shield"|"upgrade"|"item", "key", "slot", "index", "wkey", "stype", "sold"}
## (demirci girdileriyle aynı adlar; "upgrade" = kalkan geliştirmesi; "wkey" = geliştirilen silahın anahtarı, "stype" = kalkan
## geliştirmesinin türü - yuva sırası değişse de KAYDET/YASAKLA kimliği aynı kalsın).
##
## Madde 432 (kullanıcı 2026-11-06: "geliştirmelerin de pazarda ayrı bir bölmesi olsun ... 6 eşya ve 3 geliştirme önerilsin her
## rerollda. ayrıca eşya kaydetme ve yasaklama özelliği ekle (3 yasak kaydetme ise istediğin kadar) ... kaydetmeye basınca
## rerollamak veya sonraki seviyeye geçmek o eşyayı geliştirme seçeneğini v.s yok etmemeli"): pazar artık kart ekranından ayrı,
## seviye kuyruğunun SONUNDA bir kez açılan ekran (level_market_screen.gd). İki bölüm: EŞYALAR (6: silah, mana kalkanı türü, eşya)
## + GELİŞTİRMELER (3: silah geliştirme / güçlendirme, kalkan geliştirmesi); tek KARIŞTIR ikisini birden yeniler. KAYDET'lenen
## seçenek karıştırmada yerinde kalır, sonraki pazarda yeniden gelir (GameManager.market_saved); YASAKLA'nan koşu boyu bir daha
## çıkmaz (GameManager.market_banned, en çok BAN_LIMIT).

const Logic := preload("res://scripts/weapon_shop_logic.gd")
const MerchantShopScript := preload("res://scripts/merchant_shop_screen.gd")
const WeaponScript := preload("res://scripts/weapon.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")

const ITEM_COUNT := 6
const UPGRADE_COUNT := 3
const BAN_LIMIT := 3
## Çok oyunculuda pazarın kendi süresi: kart akışının ortak 25 sn'si (network_manager.gd SHARED_WAIT_SECONDS) pazar açılınca en az
## buna uzar (extend_level_up_countdown) - kartlara harcanan süre alışverişten yemesin.
const MARKET_SECONDS := 25.0
const SECTIONS := ["items", "upgrades"]
const SECTION_KINDS := {"items": ["weapon", "shield", "part", "epic", "legendary"], "upgrades": ["wupgrade", "upgrade"]}
const SECTION_SIZE := {"items": ITEM_COUNT, "upgrades": UPGRADE_COUNT}
## Tür başına seçilme ağırlığı (benim seçimim; kullanıcı vermedi). Bir tür seçilince ağırlığı yarıya iner - yuvalar tek türe
## yığılmasın (eşya havuzu silahlardan çok büyük). Havuzu boş türler hiç çekilmez.
const KIND_WEIGHTS := {"weapon": 1.0, "shield": 0.6, "part": 1.2, "epic": 1.0, "legendary": 0.7, "wupgrade": 1.5, "upgrade": 1.0}
const KIND_REPEAT_MULT := 0.5
## Yuva sırası: silah, silah geliştirme, mana kalkanı, kalkan geliştirmesi, eşya (parça -> epik -> efsanevi).
const SORT_ORDER := {"weapon": 0, "wupgrade": 1, "wplus": 1, "shield": 2, "upgrade": 3, "item": 4}

const TAG_WEAPON := Color("#e8a05a")
const TAG_SHIELD := Color("#8ecdf0")
const ROMAN := ["I", "II", "III", "IV", "V"]


## Pazarın karıştırma bedeli: seyyar satıcının formülü (kademe/zaman ölçekli), sayaç level kartlarınınkinden AYRI.
static func reroll_cost(rerolls_done: int) -> int:
	return MerchantShopScript.reroll_cost(rerolls_done)


## Seçeneğin kalıcı kimliği (karıştırma dışlaması, KAYDET, YASAKLA): geliştirmeler yuva yerine silah anahtarıyla.
static func offer_id(e: Dictionary) -> String:
	match str(e.get("type", "")):
		"wupgrade":
			return "wupgrade|%s|%d" % [_wkey(e), int(e.get("index", -1))]
		"wplus":
			return "wplus|%s" % _wkey(e)
		"upgrade":
			return "upgrade|%s|%d" % [str(e.get("stype", GameManager.shield_enchant)), int(e.get("index", -1))]
	return "%s|%s" % [e.get("type", ""), e.get("key", "")]


static func _wkey(e: Dictionary) -> String:
	if e.has("wkey"):
		return str(e["wkey"])
	var slot: int = int(e.get("slot", -1))
	if slot >= 0 and slot < GameManager.owned_weapons.size():
		return str((GameManager.owned_weapons[slot] as Dictionary).get("key", ""))
	return ""


static func _slot_of(wkey: String) -> int:
	for i in GameManager.owned_weapons.size():
		if str((GameManager.owned_weapons[i] as Dictionary).get("key", "")) == wkey:
			return i
	return -1


static func section_of(e: Dictionary) -> String:
	return "upgrades" if str(e.get("type", "")) in ["wupgrade", "wplus", "upgrade"] else "items"


## ---------------------------------------------------------------- kaydet / yasakla (GameManager'da, koşu boyu)
static func is_banned(e: Dictionary) -> bool:
	return GameManager.market_banned.has(offer_id(e))


static func bans_left() -> int:
	return maxi(0, BAN_LIMIT - GameManager.market_banned.size())


## Yasaklar (hak varsa): koşu boyu bir daha çekilmez; kayıtlıysa kaydı da düşer.
static func ban(e: Dictionary) -> bool:
	if bans_left() <= 0 or is_banned(e) or bool(e.get("sold", false)):
		return false
	GameManager.market_banned.append(offer_id(e))
	set_saved(e, false)
	return true


static func is_saved(e: Dictionary) -> bool:
	var id: String = offer_id(e)
	return GameManager.market_saved.any(func(s: Dictionary) -> bool: return offer_id(s) == id)


## Kayıt kopyası yuvadan bağımsızdır ("wkey"/"stype" ile); alınan seçenek kaydedilemez.
static func set_saved(e: Dictionary, on: bool) -> void:
	var id: String = offer_id(e)
	GameManager.market_saved = GameManager.market_saved.filter(func(s: Dictionary) -> bool: return offer_id(s) != id)
	if on and not bool(e.get("sold", false)):
		var c: Dictionary = e.duplicate(true)
		c.erase("sold")
		if c["type"] in ["wupgrade", "wplus"]:
			c["wkey"] = _wkey(e)
		elif c["type"] == "upgrade":
			c["stype"] = str(e.get("stype", GameManager.shield_enchant))
		GameManager.market_saved.append(c)


## Kayıtlı seçenek hâlâ var mı (KALICI olarak alınamaz hâle geldiyse düşer: silah başka yoldan alındı, geliştirme alındı, tür
## seçildi, tekil eşya sende). Altın / yuva doluluğu geçici - kayıt kalır, yuvada sebep yazar. Geliştirmenin yuvasını tazeler.
static func still_valid(e: Dictionary) -> bool:
	match str(e.get("type", "")):
		"weapon":
			return not GameManager.owns_weapon(str(e["key"]))
		"shield":
			return GameManager.shield_enchant == ""
		"wupgrade", "wplus":
			var slot: int = _slot_of(_wkey(e))
			if slot < 0:
				return false
			e["slot"] = slot
			var done: bool = EnchantDefs.is_complete(Logic.slot_enchant(slot))
			if e["type"] == "wplus":
				return done
			return not done and not Logic.wupgrade_taken(slot, int(e["index"]))
		"upgrade":
			if str(e.get("stype", "")) != GameManager.shield_enchant:
				return false
			var lim: int = Logic.upgrade_limit(int(e["index"]))
			return lim <= 0 or Logic.upgrade_count(int(e["index"])) < lim
		"item":
			var key: String = str(e["key"])
			if not Items.DEFS.has(key):
				return false
			if Items.kademe(key) >= Items.KADEME_EPIK:
				return not Items.owns(GameManager.owned_items, key)
			return Items.part_copies(key, GameManager.owned_items) < Items.PART_MAX_COPIES
	return false


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
		var wkey: String = str((GameManager.owned_weapons[slot] as Dictionary).get("key", ""))
		if EnchantDefs.is_complete(Logic.slot_enchant(slot)):
			(out["wupgrade"] as Array).append({"type": "wplus", "slot": slot, "wkey": wkey})
			continue
		for row: Dictionary in rows:
			var idx: int = int(row["index"])
			if Logic.wupgrade_taken(slot, idx):
				continue
			if bool(row["final"]) and Logic.wupgrade_taken_count(slot) < rows.size() - 1:
				continue
			(out["wupgrade"] as Array).append({"type": "wupgrade", "slot": slot, "index": idx, "wkey": wkey})
	## mana kalkanı: tür yalnız Standart'tayken; geliştirme yalnız tür alınınca
	if GameManager.shield_enchant == "":
		for key: String in Logic.shield_keys():
			(out["shield"] as Array).append({"type": "shield", "key": key})
	else:
		for i in Logic.upgrade_lines().size():
			var lim: int = Logic.upgrade_limit(i)
			if lim <= 0 or Logic.upgrade_count(i) < lim:
				(out["upgrade"] as Array).append({"type": "upgrade", "index": i, "stype": GameManager.shield_enchant})
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


## Bir bölümü doldurur. keep: yerinde kalacak seçenekler (dizin -> seçenek; kaydedilenler / yasaklanan dışındakiler), exclude:
## önceki çekilişin kimlikleri (yeterli seçenek varsa geri gelmez). Yasaklılar hiç çekilmez. Havuz yetmezse bölüm kısa kalır.
static func roll_section(player: Node, section: String, keep: Dictionary = {}, exclude: Array = []) -> Array:
	var size: int = int(SECTION_SIZE[section])
	var all: Dictionary = candidates(player)
	var kept_ids: Array = keep.values().map(func(e: Dictionary) -> String: return offer_id(e))
	var pools: Dictionary = {}
	var total: int = 0
	var excluded: int = 0
	for k: String in SECTION_KINDS[section]:
		pools[k] = (all[k] as Array).filter(func(e: Dictionary) -> bool: return not is_banned(e) and not kept_ids.has(offer_id(e)))
		total += (pools[k] as Array).size()
		excluded += (pools[k] as Array).filter(func(e: Dictionary) -> bool: return exclude.has(offer_id(e))).size()
	var need: int = maxi(0, size - keep.size())
	## Önceki çekilişi dışarıda bırak - kalan yetmiyorsa bırakma (az seçenekli geç oyunda pazar boş kalmasın).
	if total - excluded >= need:
		for k: String in pools:
			pools[k] = (pools[k] as Array).filter(func(e: Dictionary) -> bool: return not exclude.has(offer_id(e)))
	var picked: Array = _weighted_pick(pools, need, keep.values())
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _offer_less(a, b))
	var out: Array = []
	for i in size:
		if keep.has(i):
			out.append(keep[i])
		elif not picked.is_empty():
			out.append(picked.pop_front())
	return out


## Ağırlıklı çekiliş; bir tür seçilince ağırlığı yarıya iner. Silah başına tek geliştirme önceliklidir (aynı silahın iki satırı
## tekrar gibi okunuyordu) ama bölüm boş kalacaksa aynı silahın başka satırı da gelir (tek silahlı erken oyunda 3 yuva dolsun).
static func _weighted_pick(pools: Dictionary, count: int, kept: Array) -> Array:
	var weights: Dictionary = KIND_WEIGHTS.duplicate()
	var used_w: Array = kept.filter(func(e: Dictionary) -> bool: return e.has("wkey")).map(func(e: Dictionary) -> String: return str(e["wkey"]))
	var deferred: Array = []
	if pools.has("wupgrade"):
		var wp: Array = pools["wupgrade"]
		deferred = wp.filter(func(e: Dictionary) -> bool: return used_w.has(str(e.get("wkey", ""))))
		pools["wupgrade"] = wp.filter(func(e: Dictionary) -> bool: return not used_w.has(str(e.get("wkey", ""))))
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
			deferred.append_array(pool.filter(func(e: Dictionary) -> bool: return str(e.get("wkey", "")) == str(got.get("wkey", ""))))
			pools[kind] = pool.filter(func(e: Dictionary) -> bool: return str(e.get("wkey", "")) != str(got.get("wkey", "")))
	deferred.shuffle()
	while picked.size() < count and not deferred.is_empty():
		picked.append(deferred.pop_back())
	return picked


## Pazar açılışı: kayıtlılar (hâlâ geçerliyse) bölümlerinin başında, kalan yuvalar yeni çekiliş. {"items": [...], "upgrades": [...]}
static func open_offers(player: Node) -> Dictionary:
	GameManager.market_saved = GameManager.market_saved.filter(func(s: Dictionary) -> bool: return still_valid(s))
	var out: Dictionary = {}
	for section: String in SECTIONS:
		var keep: Dictionary = {}
		for s: Dictionary in GameManager.market_saved:
			if section_of(s) == section and keep.size() < int(SECTION_SIZE[section]):
				var e: Dictionary = s.duplicate(true)
				still_valid(e) ## yuvayı tazeler
				keep[keep.size()] = e
		out[section] = roll_section(player, section, keep)
	return out


## Tek KARIŞTIR iki bölümü birden yeniler: kayıtlı (alınmamış) seçenekler yerinde kalır, gerisi yeni çekiliş.
static func reroll(player: Node, cur: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for section: String in SECTIONS:
		var keep: Dictionary = {}
		var old: Array = cur.get(section, [])
		for i in old.size():
			var e: Dictionary = old[i]
			if is_saved(e) and not bool(e.get("sold", false)):
				keep[i] = e
		out[section] = roll_section(player, section, keep, old.map(func(e: Dictionary) -> String: return offer_id(e)))
	return out


## Yasaklanan yuvanın yerine (ücretsiz) yeni seçenek; diğer yuvalar yerinde.
static func replace_at(player: Node, cur: Dictionary, section: String, index: int) -> Array:
	var old: Array = cur.get(section, [])
	var keep: Dictionary = {}
	for i in old.size():
		if i != index:
			keep[i] = old[i]
	return roll_section(player, section, keep, old.map(func(e: Dictionary) -> String: return offer_id(e)))


## Şu an alınabilen (altın + parçacık + kural) en az bir seçenek var mı (pazar artık bundan bağımsız açılır, madde 432 ek 2; çağıran yok).
static func any_buyable(player: Node, offers: Dictionary) -> bool:
	for section: String in SECTIONS:
		for e: Dictionary in offers.get(section, []):
			if block_reason(player, e) == "":
				return true
	return false


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
		r = Loc.t("%d altın eksik") % (price(e) - GameManager.gold)
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
		set_saved(e, false) ## alınan kayıt düşer (önce: "sold" kopyayı kaydetmeyi engeller)
		e["sold"] = true
	return ok


## ---------------------------------------------------------------- görünen metin
## {tag, kind (yuva üstü: SİLAH / EŞYA / MANA KALKANI), tag_col, name, sub, lines, tex, wtier (0 = silah değil)} + geliştirmelerde row_sub (satırın 2. yazısı) / row_badge (simge altı)
static func describe(e: Dictionary, player: Node = null) -> Dictionary:
	var d: Dictionary = {"tag": "", "tag_col": Color.WHITE, "name": "", "sub": "", "lines": [], "tex": null, "wtier": 0}
	match str(e.get("type", "")):
		"weapon":
			var key: String = str(e["key"])
			d["tag"] = "SİLAH"
			d["kind"] = "SİLAH"
			d["tag_col"] = TAG_WEAPON
			d["name"] = WeaponCatalog.display_name(key)
			## tür yazısı yok (kullanıcı 2026-11-06); "tag" yalnız kenar rengi / testler için
			d["sub"] = Loc.t("Silah yuvası %d/%d") % [GameManager.owned_weapons.size() + 1, Logic.max_weapons(player)]
			d["lines"] = _trait_lines(key)
			d["tex"] = WeaponCatalog.icon(key)
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
				d["sub"] = Loc.t("Güçlendirme +%d") % (Logic.wplus_count(slot) + 1)
				lines.append(_tier_gain_text(p0, p0 + 1))
				d["row_sub"] = lines[0]
				d["row_badge"] = "+%d" % (Logic.wplus_count(slot) + 1)
				next_t = 5
			else:
				var rows: Array = Logic.slot_upgrade_rows(slot)
				var row: Dictionary = rows[int(e["index"])]
				next_t = 5 if bool(row["final"]) else mini(4, now_t + 1)
				d["sub"] = Loc.t("Kademe %s → %s · %s") % [ROMAN[now_t - 1], ROMAN[next_t - 1], Loc.t(str(row["name"]))]
				## geliştirme satırı: geliştirmenin ADI (aynı silahın iki satırı ayırt edilsin) + simge altında kademe rozeti
				d["row_sub"] = str(row["name"])
				d["row_badge"] = "%s → %s" % [ROMAN[now_t - 1], ROMAN[next_t - 1]]
				lines.append(str(row["text"]))
				if next_t != now_t:
					lines.append(_tier_gain_text(now_t, next_t))
			d["tag"] = "SİLAH GELİŞTİRME"
			d["tag_col"] = TAG_WEAPON ## eskiden yeşil (#9fd27e); pazarda yeşil kenar yalnız "kayıtlı" demek (madde 433)
			d["name"] = WeaponCatalog.display_name(key)
			d["lines"] = lines
			d["tex"] = WeaponCatalog.icon(key) ## görünüş kademeyle değişmez (madde 402); kademe "wtier" kontürüyle
			d["wtier"] = next_t
		"shield":
			var key: String = str(e["key"])
			d["tag"] = "MANA KALKANI"
			d["kind"] = "MANA KALKANI"
			d["tag_col"] = TAG_SHIELD
			d["name"] = ShieldEnchantDefs.type_name(key)
			d["sub"] = "Standart kalkanın yerine geçer"
			d["lines"] = [Logic.shield_summary(key), str((ShieldEnchantDefs.TYPES.get(key, {}) as Dictionary).get("desc", ""))]
			d["tex"] = load(str(ShieldEnchantDefs.ICONS.get(key, "")))
		"upgrade":
			var st: String = GameManager.shield_enchant
			var i: int = int(e["index"])
			var lim: int = Logic.upgrade_limit(i)
			d["tag"] = "KALKAN GELİŞTİRME"
			d["tag_col"] = TAG_SHIELD
			d["name"] = ShieldEnchantDefs.type_name(st)
			d["sub"] = Loc.t("Geliştirme %d · %s") % [i + 1, (Loc.t("%d/%d alındı") % [Logic.upgrade_count(i), lim]) if lim > 0 else (Loc.t("%d kez alındı") % Logic.upgrade_count(i))]
			d["lines"] = Array(Logic.upgrade_effect_text(i).split("\n"))
			d["row_sub"] = ", ".join(d["lines"])
			d["row_badge"] = ("%d/%d" % [Logic.upgrade_count(i) + 1, lim]) if lim > 0 else ("%d." % (Logic.upgrade_count(i) + 1))
			d["tex"] = load(str(ShieldEnchantDefs.ICONS.get(st, "")))
		"item":
			var key: String = str(e["key"])
			var kd: int = Items.kademe(key)
			d["tag"] = ["PARÇA", "EPİK", "EFSANEVİ"][kd - 1]
			d["kind"] = "EŞYA" ## yuva üstünde yalnız tür (nadirlik yazısı yok, kenar renginde; madde 433 ek 4)
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
	return Loc.t("+%%%d hasar, +%%%d saldırı hızı") % [dmg, spd]


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
		return Loc.t("Tarif: %s sende") % ", ".join(names)
	if Items.kademe(key) == Items.KADEME_PARCA and Items.part_copies(key, GameManager.owned_items) > 0:
		return Loc.t("%d. kopya · fiyat +%%%d") % [Items.part_copies(key, GameManager.owned_items) + 1,
			roundi((Items.repeat_mult(key, GameManager.owned_items) - 1.0) * 100.0)]
	return "" ## "Eşya" / "Tarifli eşya" tür yazısı yok (kullanıcı 2026-11-06)


## Stat satırları + pasif (Items.describe ile aynı metin; pasif bir stat satırının tekrarıysa yazılmaz - Kabuk Delen).
static func _item_lines(key: String) -> Array:
	var lines: Array = []
	for ln in Items.describe(key).split("\n"):
		if ln.strip_edges() != "" and not ln.begins_with(Loc.t("Pasif:")): ## describe artık seçili dilde (madde 446)
			lines.append(ln.strip_edges())
	var passive: String = str(Items.get_def(key).get("passive", "")).strip_edges()
	if passive != "" and not lines.any(func(l: String) -> bool: return l.replace("+", "").trim_suffix(".") == passive.trim_suffix(".")):
		lines.append(Loc.t("Pasif:") + " " + passive)
	return lines
