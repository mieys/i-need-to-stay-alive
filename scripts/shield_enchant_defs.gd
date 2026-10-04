class_name ShieldEnchantDefs
extends RefCounted

## KALKAN TÜRLERİ + KALKAN EFSUNLARI - tek kaynak (kullanıcı isteği 2026-09-29).
## Herkes Standart Kalkanla başlar (bkz. main.gd _grant_starting_shield). Efsun ekranında (elit sandık) silah
## efsunlarının arasına 3 kalkan efsunu karışır (bkz. enchant_pool.gd build). BİRİ seçilince Standart'ın yerine geçer,
## diğer ikisi o oyunda bir daha çıkmaz; onun yerine seçilen efsunun geliştirmeleri havuza girer.
## Değerler SABİT: kart nadirliği sayıları büyütmez, kalkan kartları hep Epik (mor) görünür (kullanıcı tercihi).
##   power       kalkan miktarı                 absorption  hasar soğurma (0..1, oyuncu tavanı %92 - player.gd)
##   regen       yenilenme (kalkan/sn)          delay       hasar alınca yenilenmeden önceki bekleme (sn)
##   always_regen  true = savaşta da yenilenir, hiç beklemez
## Geliştirme "limit": 0 = sınırsız, N = en fazla N kez alınır, sonra havuzdan çıkar. Değer alanları yukarıdakilerin
## aynısı ve üstüne EKLENİR (delay negatif = bekleme kısalır; oyuncu tabanı SHIELD_REGEN_DELAY_FLOOR).
## Kalkan Yüzüğü / "Kalkan Soğurma" kartı / maksimum kalkan kartları bunların üstüne ayrıca biner (player.gd).
## Anahtarlar (shield_*) görsel tarafta da kullanılıyor: shield_visual.gd baloncuk rengi, shop_item_icon.gd ikonu.

const STANDART := "shield_standart"
const ENCHANT_KEYS := ["shield_savas", "shield_enerji", "shield_kale"]
const CARD_TIER := 3 ## Epik (mor) - sadece kart rengi

const TYPES := {
	"shield_standart": {
		"name": "Standart Kalkan",
		"power": 150.0, "absorption": 0.65, "regen": 10.0, "delay": 8.0, "always_regen": false,
	},
	"shield_savas": {
		"name": "Savaş Kalkanı",
		"power": 160.0, "absorption": 0.60, "regen": 4.0, "delay": 0.0, "always_regen": true,
		"desc": "Savaştayken bile yenilenir, hasar alınca beklemez.",
		"color": Color(0.95, 0.3, 0.3),
		"upgrades": [
			{"limit": 0, "power": 60.0, "regen": 2.0},
			{"limit": 8, "power": 60.0, "absorption": 0.03},
		],
	},
	"shield_enerji": {
		"name": "Enerji Kalkanı",
		"power": 110.0, "absorption": 0.55, "regen": 9.0, "delay": 6.0, "always_regen": false,
		"desc": "Hasar alınca kısa bir süre bekler, sonra çok hızlı dolar.",
		"color": Color(0.66, 0.96, 0.3),
		"upgrades": [
			{"limit": 0, "power": 50.0, "regen": 4.0},
			{"limit": 5, "power": 50.0, "absorption": 0.03},
			{"limit": 8, "power": 50.0, "delay": -0.5},
		],
	},
	"shield_kale": {
		"name": "Kale Kalkanı",
		"power": 200.0, "absorption": 0.75, "regen": 7.0, "delay": 8.0, "always_regen": false,
		"desc": "En çok kalkan ve en yüksek soğurma, ama yavaş dolar.",
		"color": Color(0.26, 0.86, 0.66),
		"upgrades": [
			{"limit": 0, "power": 100.0, "regen": 3.5},
			{"limit": 5, "power": 100.0, "absorption": 0.04},
			{"limit": 8, "power": 100.0, "delay": -0.5},
		],
	},
}

const ICONS := {
	"shield_standart": "res://assets/ui/shields/type_standart.png",
	"shield_savas": "res://assets/ui/shields/type_savas.png",
	"shield_enerji": "res://assets/ui/shields/type_enerji.png",
	"shield_kale": "res://assets/ui/shields/type_kale.png",
}


## Sahip olunan kalkan: seçilmiş kalkan efsunu, yoksa Standart (başlangıçta verildiyse), hiç yoksa "".
static func owned_type() -> String:
	if GameManager.shield_enchant != "":
		return GameManager.shield_enchant
	return STANDART if GameManager.shield_standart_level > 0 else ""


static func type_name(key: String) -> String:
	return str(TYPES.get(key, {}).get("name", key))


static func upgrade_count(index: int) -> int:
	var ups: Array = GameManager.shield_enchant_ups
	return int(ups[index]) if index >= 0 and index < ups.size() else 0


## Sahip olunan kalkanın taban + alınan geliştirmelerin toplamı. Kalkan yoksa boş sözlük.
static func stats() -> Dictionary:
	var key: String = owned_type()
	if key == "":
		return {}
	var def: Dictionary = TYPES[key]
	var out: Dictionary = {"key": key, "name": def["name"], "power": float(def["power"]),
		"absorption": float(def["absorption"]), "regen": float(def["regen"]), "delay": float(def["delay"]),
		"always_regen": bool(def["always_regen"])}
	if key == GameManager.shield_enchant:
		var ups: Array = def.get("upgrades", [])
		for i in range(ups.size()):
			var n: int = upgrade_count(i)
			for stat in ["power", "absorption", "regen", "delay"]:
				out[stat] = float(out[stat]) + float(ups[i].get(stat, 0.0)) * n
	return out


## Efsun havuzuna giren kalkan kartları (bkz. enchant_pool.gd build): kalkan efsunu yoksa 3 efsunun başlangıç kartı,
## varsa onun limiti dolmamış geliştirmeleri. slot = -1 (silah kopyasına bağlı değil).
static func pool_cards() -> Array:
	var cards: Array = []
	if GameManager.shield_enchant == "":
		for key in ENCHANT_KEYS:
			cards.append({"type": "shield_pick", "slot": -1, "id": key})
		return cards
	var ups: Array = TYPES[GameManager.shield_enchant].get("upgrades", [])
	for i in range(ups.size()):
		var limit: int = int(ups[i].get("limit", 0))
		if limit > 0 and upgrade_count(i) >= limit:
			continue
		cards.append({"type": "shield_up", "slot": -1, "id": "%s#%d" % [GameManager.shield_enchant, i], "index": i})
	return cards


## Kartı GameManager durumuna işler; oyuncunun kalkan statlarını yenilemek çağırana kalır (player.gd apply_enchant_choice).
static func apply(card: Dictionary) -> void:
	match str(card.get("type", "")):
		"shield_pick":
			var key: String = str(card.get("id", ""))
			if not ENCHANT_KEYS.has(key) or GameManager.shield_enchant != "":
				return
			GameManager.shield_enchant = key
			var counts: Array = []
			counts.resize((TYPES[key].get("upgrades", []) as Array).size())
			counts.fill(0)
			GameManager.shield_enchant_ups = counts
		"shield_up":
			var i: int = int(card.get("index", -1))
			if i < 0 or i >= GameManager.shield_enchant_ups.size():
				return
			GameManager.shield_enchant_ups[i] = upgrade_count(i) + 1


## Efsun kartı metni (enchant_pool.gd describe ile aynı alanlar). Önce -> sonra değerleri kalkanın TABAN değerleri
## (eşya/kart bonusları hariç) - kart ne değiştirdiğini net göstersin.
static func describe(card: Dictionary, out: Dictionary) -> void:
	var kind: String = str(card.get("type", ""))
	var now: Dictionary = stats()
	var tier_name: String = str(TierSystem.NAMES[CARD_TIER - 1])
	out["category"] = "Kalkan efsunu"
	out["banishable"] = false
	if kind == "shield_pick":
		var key: String = str(card.get("id", ""))
		var def: Dictionary = TYPES.get(key, {})
		out["title"] = str(def.get("name", key))
		out["icon"] = str(ICONS.get(key, ""))
		out["color"] = def.get("color", Color.WHITE)
		out["tier_line"] = "%s · Kalkan" % tier_name
		## Sade kart (2026-10-03, bkz. enchant_pool.gd describe notu): başlangıç kartı sadece kalkanın nasıl çalıştığını anlatır.
		out["body"] = str(def.get("desc", ""))
		return
	var i: int = int(card.get("index", 0))
	var def2: Dictionary = TYPES.get(GameManager.shield_enchant, {})
	var up: Dictionary = (def2.get("upgrades", []) as Array)[i]
	out["title"] = "%s · Geliştirme %d" % [str(def2.get("name", "")), i + 1]
	out["icon"] = str(ICONS.get(GameManager.shield_enchant, ""))
	out["color"] = def2.get("color", Color.WHITE)
	out["tier_line"] = "%s · Kalkan geliştirmesi" % tier_name
	var after2: Dictionary = now.duplicate()
	for stat in ["power", "absorption", "regen", "delay"]:
		after2[stat] = float(now.get(stat, 0.0)) + float(up.get(stat, 0.0))
	## Geliştirme kartı sadece değişen statları yazar (bkz. enchant_pool.gd describe notu).
	out["body"] = _compare_lines(now, after2, false)


## "Kalkan: 150 → 210" satırları. all_lines: kalkan değişiminde her satır, geliştirmede sadece değişenler.
static func _compare_lines(before: Dictionary, after: Dictionary, all_lines: bool) -> String:
	var lines: Array = []
	var b_pow: float = float(before.get("power", 0.0))
	var a_pow: float = float(after.get("power", 0.0))
	if all_lines or not is_equal_approx(b_pow, a_pow):
		lines.append("Kalkan: %d → %d" % [int(round(b_pow)), int(round(a_pow))])
	var b_abs: float = float(before.get("absorption", 0.0))
	var a_abs: float = float(after.get("absorption", 0.0))
	if all_lines or not is_equal_approx(b_abs, a_abs):
		lines.append("Hasar soğurma: %%%d → %%%d" % [int(round(b_abs * 100.0)), int(round(a_abs * 100.0))])
	var b_reg: float = float(before.get("regen", 0.0))
	var a_reg: float = float(after.get("regen", 0.0))
	if all_lines or not is_equal_approx(b_reg, a_reg):
		lines.append("Yenilenme: %s/sn → %s/sn" % [_num(b_reg), _num(a_reg)])
	var b_del: float = float(before.get("delay", 0.0))
	var a_del: float = float(after.get("delay", 0.0))
	if all_lines or not is_equal_approx(b_del, a_del):
		lines.append("Bekleme: %s → %s" % [_delay_text(before), _delay_text(after)])
	return "\n".join(lines)


static func _delay_text(s: Dictionary) -> String:
	if s.is_empty():
		return "-"
	if bool(s.get("always_regen", false)):
		return "yok (savaşta da dolar)"
	return "%s sn" % _num(float(s.get("delay", 0.0)))


static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else "%.1f" % v


## Efsun ekranının üstündeki "sahip olduğun efsunlar" satırı için (bkz. enchant_pool.gd owned_summary).
static func summary() -> String:
	if GameManager.shield_enchant == "":
		return ""
	var total: int = 0
	for n in GameManager.shield_enchant_ups:
		total += int(n)
	return "Kalkan: %s (%d geliştirme)" % [type_name(GameManager.shield_enchant), total]
