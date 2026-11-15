extends RefCounted

## OYNAYIŞ PROFİLİ / ÖNERİ AĞIRLIĞI (madde 637, kullanıcı isteği 2026-11-13: "oyuncuların oynayışına göre işine yarayacak item öneri
## yapay zekasına ihtiyacım var. Bir oyuncu bir stata çok abanıyorsa o stata odaklı şeylerin çıkma ihtimali biraz daha fazla olmalı,
## aynı şey silah türleri için de geçerli").
##
## Öğrenen model DEĞİL, uyarlanan ağırlık: oyuncunun seçtiği level kartları + sahip olduğu eşyalar bir "stat profili", silahları +
## silah başına verdiği hasar bir "silah profili" çıkarır. Teklif çekilişleri (level pazarı + level kartları) bu profile uyan seçeneği
## en çok MAX_BOOST kadar daha sık çeker - garanti değil, "biraz daha fazla". Her çekilişte EXPLORE_PICKS seçenek profilsiz (düz
## rastgele) kalır, build tek yöne kilitlenmesin.
##
## "Abanmak" = rastgeleden BEKLENENDEN belirgin fazla yatırım (havuzun o stata ayırdığı beklenen puana göre sapma, bkz. Z_START). Neredeyse
## her eşyada Saldırı Gücü olduğu için ham sayım hep "saldırıcı" derdi; beklenen puandan sapma bunu nötrler.
##
## Yalnız YEREL oyuncu için, yerel çekilişlerde (ağ alanı yok). Seyyar satıcı HARİÇ: stoğu host'ta bir kez üretilip herkese aynı gider
## (traveling_merchant.gd _generate_stock) - host'un profili herkesin dükkanını eğmesin.

const LevelSpecialCardsScript := preload("res://scripts/level_special_cards.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const DamageStats := preload("res://scripts/damage_stats.gd")

## Uyumlu seçenek en çok x(1 + MAX_BOOST) ağırlık alır.
const MAX_BOOST := 0.6
## Abanma ölçüsü z = (puan - beklenen puan) / sqrt(beklenen) (en az 1): Z_START altı 0, Z_FULL'da tam (fazlalık 0..1). Örnek: 15 kartın
## 4'ü Saldırı Gücü -> z 2,4 -> %69; tek seçim hiçbir zaman sayılmaz.
const Z_START := 1.0
const Z_FULL := 3.0
## Profil puanı bu değere ulaşmadan güven azalır (ilk seviyelerde etkisiz); MIN_POINTS altında profil hiç yok.
const MIN_POINTS := 3.0
const FULL_POINTS := 10.0
## Her çekilişte profile bakılmadan çekilen seçenek sayısı (keşif).
const EXPLORE_PICKS := 1
## Puanlar: level kartı kademe başına artar; eşya kademesine göre (parça / epik / efsanevi).
const CARD_POINTS_PER_TIER := 0.25
const ITEM_POINTS := {1: 1.0, 2: 2.0, 3: 3.0}

## Eksenler = düz level kartlarının kimlikleri (level_up_screen.gd UPGRADES).
const AXES := ["speed", "max_health", "damage", "fire_rate", "health_regen", "crit_chance", "crit_damage", "exp_gain", "luck", "dodge",
	"shield_amount", "cooldown_reduction", "lifesteal", "shield_regen", "heal_power"]
## Level kartı havuzunun kart başına ağırlığı (level_up_screen.gd _weighted_sample: Saldırı x1,5). Beklenen pay buradan.
const ATTACK_AXES := ["damage", "fire_rate", "crit_chance", "crit_damage", "lifesteal"]
const ATTACK_CARD_WEIGHT := 1.5

## Eşya stat anahtarı (items.gd "stats", player.gd değişken adları) -> eksen. Burada olmayan stat profili etkilemez.
const ITEM_STAT_AXIS := {
	"damage_bonus": "damage", "item_ap_percent": "damage", "item_damage_mult_bonus": "damage", "item_flat_hit_damage": "damage",
	"shield_pen_percent": "damage", "item_melee_mult_bonus": "damage", "item_ranged_mult_bonus": "damage",
	"item_fire_rate_percent": "fire_rate",
	"crit_chance_bonus": "crit_chance", "item_crit_damage_bonus": "crit_damage",
	"max_health": "max_health", "item_health_regen": "health_regen", "item_vitamin_regen_bonus": "health_regen",
	"lifesteal_percent": "lifesteal", "item_extra_lifesteal": "lifesteal",
	"dodge_chance": "dodge", "item_speed_percent": "speed",
	"exp_gain_percent": "exp_gain", "item_pickup_range_percent": "exp_gain", "luck": "luck",
	"cooldown_reduction_percent": "cooldown_reduction", "heal_shield_power": "heal_power",
	"item_shield_power_flat": "shield_amount", "shield_protection_bonus": "shield_amount",
	"item_shield_regen_flat": "shield_regen", "item_shield_regen_percent": "shield_regen", "item_shield_delay_reduction": "shield_regen",
}

## Silah aileleri (aynı aileden silah en güçlü eşleşme, aynı sınıf - yakın dövüş / menzilli - daha zayıf).
const FAMILY := {
	"dagger": "yakin", "pence": "yakin", "topuz": "yakin", "uzunkilic": "yakin", "mizrak": "yakin", "kalkan": "yakin",
	"fire_staff": "asa", "lightning_staff": "asa", "tuftuf": "asa", "arcane": "asa", "buz_asasi": "asa", "gokkusagi": "asa", "yinyang": "asa",
	"tabanca": "atesli", "tufek": "atesli", "pompali": "atesli", "makineli": "atesli", "fisek": "atesli",
	"yay": "ok", "crossbow": "ok", "boomerang": "ok",
}
const FAMILY_MATCH := 1.0
const CLASS_MATCH := 0.5


## ---------------------------------------------------------------- profil
## {"stat": {eksen: fazlalık 0..1}, "conf": 0..1, "family": {aile: pay}, "melee": pay 0..1, "weapon_share": {silah: hasar payı},
##  "points": toplam}. Boş profil = her şey 1x.
static func profile(player: Node) -> Dictionary:
	var card_pts: Dictionary = {}
	var item_pts: Dictionary = {}
	var card_total: float = 0.0
	var item_total: float = 0.0
	if player != null and is_instance_valid(player) and "upgrade_log" in player:
		for e in (player.get("upgrade_log") as Array):
			if not (e is Array) or (e as Array).size() < 2:
				continue
			var axis: String = card_axis(str(e[0]))
			if axis == "":
				continue
			var pts: float = 1.0 + CARD_POINTS_PER_TIER * float(clampi(int(e[1]), 1, 4) - 1)
			card_pts[axis] = float(card_pts.get(axis, 0.0)) + pts
			card_total += pts
	for e in GameManager.owned_items:
		var key: String = str((e as Dictionary).get("key", ""))
		var axes: Array = item_axes(key)
		if axes.is_empty():
			continue
		var pts: float = float(ITEM_POINTS.get(Items.kademe(key), 1.0))
		for a in axes:
			item_pts[a] = float(item_pts.get(a, 0.0)) + pts / float(axes.size())
		item_total += pts
	var total: float = card_total + item_total
	var stat: Dictionary = {}
	if total >= MIN_POINTS:
		var card_base: Dictionary = _card_baseline()
		var item_base: Dictionary = _item_baseline()
		for a: String in AXES:
			var seen: float = float(card_pts.get(a, 0.0)) + float(item_pts.get(a, 0.0))
			var expect: float = card_total * float(card_base.get(a, 0.0)) + item_total * float(item_base.get(a, 0.0))
			if seen <= expect:
				continue
			## Sapma / beklenen gürültü (sqrt): 15 eksende tek kart bile "beklenenin 2 katı" olurdu - tek seçim abanma sayılmasın.
			var z: float = (seen - expect) / maxf(1.0, sqrt(expect))
			var ex: float = clampf((z - Z_START) / (Z_FULL - Z_START), 0.0, 1.0)
			if ex > 0.0:
				stat[a] = ex
	var conf: float = clampf((total - MIN_POINTS) / (FULL_POINTS - MIN_POINTS), 0.0, 1.0) if total >= MIN_POINTS else 0.0
	## silah profili: sahip olunan silahlar, her biri 1 + 2 x hasar payı (en çok kullandığın daha ağır)
	var shares: Dictionary = {}
	for r: Dictionary in DamageStats.weapon_rows():
		shares[str(r["key"])] = float(r["dmg"])
	var dmg_sum: float = 0.0
	for k in shares:
		dmg_sum += float(shares[k])
	var fam: Dictionary = {}
	var fam_total: float = 0.0
	var melee_w: float = 0.0
	var owned_shares: Dictionary = {}
	for w in GameManager.owned_weapons:
		var key: String = str((w as Dictionary).get("key", ""))
		if key == "":
			continue
		var share: float = float(shares.get(key, 0.0)) / dmg_sum if dmg_sum > 0.0 else 0.0
		owned_shares[key] = share
		var wt: float = 1.0 + 2.0 * share
		var f: String = str(FAMILY.get(key, "yakin" if WeaponCatalog.MELEE_KEYS.has(key) else "ok"))
		fam[f] = float(fam.get(f, 0.0)) + wt
		fam_total += wt
		if WeaponCatalog.MELEE_KEYS.has(key):
			melee_w += wt
	for f in fam:
		fam[f] = float(fam[f]) / fam_total
	return {"stat": stat, "conf": conf, "family": fam, "melee": melee_w / fam_total if fam_total > 0.0 else 0.5,
		"weapon_share": owned_shares, "points": total, "weapons": GameManager.owned_weapons.size()}


## Level kartı kimliğinin ekseni: düz kart = kendisi, takas kartı = kazandırdığı statın simgesi (level_special_cards.gd "icon").
static func card_axis(id: String) -> String:
	if AXES.has(id):
		return id
	var d: Dictionary = LevelSpecialCardsScript.DEFS.get(id, {})
	if str(d.get("kind", "")) == "trade" and AXES.has(str(d.get("icon", ""))):
		return str(d["icon"])
	return ""


static func item_axes(key: String) -> Array:
	var out: Array = []
	for s in (Items.get_def(key).get("stats", {}) as Dictionary):
		var a: String = str(ITEM_STAT_AXIS.get(str(s), ""))
		if a != "" and not out.has(a):
			out.append(a)
	return out


static func _card_baseline() -> Dictionary:
	var out: Dictionary = {}
	var sum: float = 0.0
	for a: String in AXES:
		var w: float = ATTACK_CARD_WEIGHT if ATTACK_AXES.has(a) else 1.0
		out[a] = w
		sum += w
	for a in out:
		out[a] = float(out[a]) / sum
	return out


## Eşya havuzunun eksenlere beklenen payı (her eşya kademe puanını eksenlerine böler - profildeki sayımla aynı kural).
static func _item_baseline() -> Dictionary:
	var out: Dictionary = {}
	var sum: float = 0.0
	for key: String in Items.KEYS:
		var axes: Array = item_axes(key)
		if axes.is_empty():
			continue
		var pts: float = float(ITEM_POINTS.get(Items.kademe(key), 1.0))
		for a in axes:
			out[a] = float(out.get(a, 0.0)) + pts / float(axes.size())
		sum += pts
	if sum > 0.0:
		for a in out:
			out[a] = float(out[a]) / sum
	return out


## ---------------------------------------------------------------- uyum (0..1) ve ağırlık (1..1+MAX_BOOST)
static func stat_fit(prof: Dictionary, axes: Array) -> float:
	if axes.is_empty() or prof.is_empty():
		return 0.0
	var st: Dictionary = prof.get("stat", {})
	var best: float = 0.0
	var sum: float = 0.0
	for a in axes:
		var v: float = float(st.get(a, 0.0))
		best = maxf(best, v)
		sum += v
	## Bir eksen tam eşleşirse güçlü; birden çok eşleşen eksen küçük ek.
	return clampf(best + 0.25 * (sum - best), 0.0, 1.0) * float(prof.get("conf", 0.0))


## Silah anahtarının profile uyumu: aynı aile tam, aynı sınıf yarım (silah sayısına göre güven: tek başlangıç silahında yarı güç).
static func weapon_fit(prof: Dictionary, key: String) -> float:
	if prof.is_empty() or int(prof.get("weapons", 0)) <= 0:
		return 0.0
	var f: String = str(FAMILY.get(key, ""))
	var fam_share: float = float((prof.get("family", {}) as Dictionary).get(f, 0.0))
	var melee: float = float(prof.get("melee", 0.5))
	var cls_share: float = melee if WeaponCatalog.MELEE_KEYS.has(key) else 1.0 - melee
	var fit: float = maxf(FAMILY_MATCH * fam_share, CLASS_MATCH * cls_share)
	return clampf(fit, 0.0, 1.0) * clampf(float(prof.get("weapons", 0)) / 2.0, 0.0, 1.0)


## Pazar seçeneğinin uyumu (level_market.gd seçenek sözlüğü).
static func offer_fit(prof: Dictionary, e: Dictionary) -> float:
	match str(e.get("type", "")):
		"weapon":
			return weapon_fit(prof, str(e.get("key", "")))
		"wupgrade", "wplus":
			## En çok hasar veren silahın geliştirmesi: payı eşit bölüşümün iki katına çıkınca tam.
			var ws: Dictionary = prof.get("weapon_share", {})
			var n: int = maxi(1, ws.size())
			if n <= 1:
				return 0.0
			var share: float = float(ws.get(str(e.get("wkey", "")), 0.0))
			return clampf(share * float(n) - 1.0, 0.0, 1.0)
		"shield", "upgrade":
			return stat_fit(prof, ["shield_amount", "shield_regen"])
		"item":
			var key: String = str(e.get("key", ""))
			var fit: float = stat_fit(prof, item_axes(key))
			var cls: String = str(Items.get_def(key).get("weapon_class", ""))
			if cls != "":
				fit = maxf(fit, 1.0) ## silah türü koşullu eşya zaten yalnız o türe adanmış kurguda çıkar (Items.weapon_gate_ok)
			var stats: Dictionary = Items.get_def(key).get("stats", {})
			if stats.has("item_melee_mult_bonus"):
				fit = maxf(fit, float(prof.get("melee", 0.5)) * clampf(float(prof.get("weapons", 0)) / 2.0, 0.0, 1.0))
			if stats.has("item_ranged_mult_bonus"):
				fit = maxf(fit, (1.0 - float(prof.get("melee", 0.5))) * clampf(float(prof.get("weapons", 0)) / 2.0, 0.0, 1.0))
			return clampf(fit, 0.0, 1.0)
	return 0.0


static func weight_of(fit: float) -> float:
	return 1.0 + MAX_BOOST * clampf(fit, 0.0, 1.0)


## Level kartının ağırlık çarpanı (düz kart = kendi ekseni; takas = kazanç ekseni; silah türü kartı = o türe adanmışlık zaten şart).
static func card_weight(prof: Dictionary, id: String) -> float:
	var d: Dictionary = LevelSpecialCardsScript.DEFS.get(id, {})
	if str(d.get("kind", "")) == "class":
		return weight_of(0.5)
	var a: String = card_axis(id)
	return weight_of(stat_fit(prof, [a])) if a != "" else 1.0


## Ağırlıklı tek çekiliş: dizideki seçeneklerden birinin dizinini döner (weights aynı boyda).
static func pick_index(weights: Array) -> int:
	var sum: float = 0.0
	for w in weights:
		sum += float(w)
	if weights.is_empty():
		return -1
	if sum <= 0.0:
		return randi() % weights.size()
	var r: float = randf() * sum
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1


## Balans kaydı için kısa özet: en çok abanılan 3 stat + silah ailesi payları.
static func summary(prof: Dictionary) -> Dictionary:
	var st: Dictionary = prof.get("stat", {})
	var keys: Array = st.keys()
	keys.sort_custom(func(a, b): return float(st[a]) > float(st[b]))
	var top: Dictionary = {}
	for k in keys.slice(0, 3):
		top[str(k)] = snappedf(float(st[k]), 0.01)
	var fam: Dictionary = {}
	for f in (prof.get("family", {}) as Dictionary):
		fam[str(f)] = snappedf(float(prof["family"][f]), 0.01)
	return {"stat": top, "conf": snappedf(float(prof.get("conf", 0.0)), 0.01), "family": fam}
