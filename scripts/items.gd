class_name Items

## EŞYA SİSTEMİ (kullanıcının tasarımı, 2026-10-02 - "İtem sistemi yeni.zip": item.txt + iem fiyatlandırmaları.txt).
## Üç kademe: 1 = Parça (temel malzeme), 2 = Epik, 3 = Efsanevi. Epik/efsanevi eşyalar TARİFLE (alt kademe parçalarından)
## üretilir; eşyanın fiyatı tarifindeki parçaların fiyatlarının TOPLAMIDIR ve sahip olunan parçalar (tarifin içindeki
## epiklerin parçaları dahil, özyinelemeli) satın alırken TÜKETİLİP fiyattan düşülür (bkz. plan_purchase).
## Soru-cevapla netleşenler (hafıza: project-new-item-system-2026-10-02):
##  - Slotlar ayrı havuzlar: parça = seviye başına 1 (player.get_max_item_slots), epik en fazla 10, efsanevi en fazla 5.
##  - Efsaneviler tekil (aynısından ikincisi alınamaz). Sandıklardan sadece parça çıkar, eski Tier1-4 güç çarpanı yok.
##  - Fiyatlar belgedeki gibi (seyyar satıcının zaman ölçeklemesi kaldırıldı).
##
## "stats" anahtarları player.gd'deki AYNI isimli değişkenlere eklenir (player.gd _apply_item_stats - dodge_chance /
## max_health / shield_pen_percent özel, gerisi genel set/get). Pasif metni "passive"; pasiflerin kodu player.gd
## ITEM PASİFLERİ bloğunda ve weapon.gd'de has_item(<anahtar>) ile.
## Yeni stat: heal_shield_power (İyileştirme ve Kalkan Gücü) - oyuncunun sağladığı tüm can/kalkanı güçlendirir.
## item_shield_regen_flat = saniyede kalkan (Savaş Kalkanı yarısını alır), item_health_regen = 5 saniyede can.

const KADEME_PARCA := 1
const KADEME_EPIK := 2
const KADEME_EFSANEVI := 3
const KADEME_NAMES := ["Parça", "Epik", "Efsanevi"]
const EPIC_SLOT_LIMIT := 10
const LEGENDARY_SLOT_LIMIT := 5
const SELL_REFUND_RATIO := 0.7
const ICON_DIR := "res://assets/items/"

## Arkadaşlarına can/kalkan verebilen karakterler (roster id) - Işığın Muhafızı Parşomeni yalnız bunlara çıkar:
## Oakley (Q/E müttefik iyileştirme + kalkan), Melek (Q iyileştirme + pasif), Shaman (Kalkan Totemi).
const ALLY_SUPPORT_CHARS := [2, 10, 12]

const DEFS := {
	## ------------------------------------------------------------------ 1. kademe: Parçalar
	"kanli_yakut": {"name": "Kanlı Yakut", "kademe": 1, "cost": 330, "recipe": [],
		"stats": {"max_health": 50.0, "damage_bonus": 5.0}},
	"yasam_kristali": {"name": "Yaşam Kristali", "kademe": 1, "cost": 270, "recipe": [],
		"stats": {"max_health": 80.0, "item_health_regen": 1.0}},
	"ceviklik_yuzugu": {"name": "Çeviklik Yüzüğü", "kademe": 1, "cost": 300, "recipe": [],
		"stats": {"item_fire_rate_percent": 0.10}},
	"kutsal_tilsim": {"name": "Kutsal Tılsım", "kademe": 1, "cost": 250, "recipe": [],
		"stats": {"heal_shield_power": 0.05}},
	"bile_tasi": {"name": "Bile Taşı", "kademe": 1, "cost": 350, "recipe": [],
		"stats": {"damage_bonus": 10.0}},
	"isik_parcacigi": {"name": "Işık Parçacığı", "kademe": 1, "cost": 250, "recipe": [],
		"stats": {"item_shield_power_flat": 40.0, "item_shield_regen_flat": 0.5}},
	"kan_disi": {"name": "Kan Dişi", "kademe": 1, "cost": 280, "recipe": [],
		"stats": {"damage_bonus": 3.0, "lifesteal_percent": 0.03}},
	"tecrube_kitabi": {"name": "Tecrübe Kitabı", "kademe": 1, "cost": 290, "recipe": [],
		"stats": {"luck": 1.0, "exp_gain_percent": 0.05}},
	"ayakkabi_bagcigi": {"name": "Ayakkabı Bağcığı", "kademe": 1, "cost": 260, "recipe": [],
		"stats": {"item_speed_percent": 0.04, "dodge_chance": 0.04}},
	"kol_saati": {"name": "Kol Saati", "kademe": 1, "cost": 280, "recipe": [],
		"stats": {"cooldown_reduction_percent": 0.05}},
	"tornavida": {"name": "Tornavida", "kademe": 1, "cost": 320, "recipe": [],
		"stats": {"damage_bonus": 5.0, "shield_pen_percent": 0.05}},

	## ------------------------------------------------------------------ 2. kademe: Epik eşyalar
	"kemik_kolye": {"name": "Kemik Kolye", "kademe": 2, "cost": 600,
		"recipe": ["kanli_yakut", "yasam_kristali"],
		"stats": {"max_health": 80.0, "damage_bonus": 5.0}},
	"suikastci_kamasi": {"name": "Suikastçı Kaması", "kademe": 2, "cost": 630,
		"recipe": ["bile_tasi", "kol_saati"],
		"stats": {"damage_bonus": 10.0, "cooldown_reduction_percent": 0.06}},
	"ruh_emici": {"name": "Ruh Emici", "kademe": 2, "cost": 630,
		"recipe": ["bile_tasi", "kan_disi"],
		"stats": {"damage_bonus": 8.0, "lifesteal_percent": 0.06},
		"passive": "Her 10 öldürmede 1 can yenilersin."},
	"keskin_goz_hanceri": {"name": "Keskin Göz Hançeri", "kademe": 2, "cost": 650,
		"recipe": ["ceviklik_yuzugu", "bile_tasi"],
		"stats": {"damage_bonus": 8.0, "crit_chance_bonus": 0.08}},
	"ruzgar_eldiveni": {"name": "Rüzgar Eldiveni", "kademe": 2, "cost": 650,
		"recipe": ["ceviklik_yuzugu", "bile_tasi"],
		"stats": {"item_fire_rate_percent": 0.10, "item_flat_hit_damage": 5.0},
		"passive": "Saldırıların fazladan 5 hasar verir."},
	"zirh_soken_hancer": {"name": "Zırh Söken Hançer", "kademe": 2, "cost": 670,
		"recipe": ["tornavida", "bile_tasi"],
		"stats": {"damage_bonus": 10.0, "shield_pen_percent": 0.08},
		"passive": "%8 Kalkan Delme."},
	"savascinin_kilici": {"name": "Savaşçının Kılıcı", "kademe": 2, "cost": 700,
		"recipe": ["bile_tasi", "bile_tasi"],
		"stats": {"damage_bonus": 15.0, "item_damage_mult_bonus": 0.04},
		"passive": "%4 hasar kazandırır."},
	"sarsilmaz_kabuk": {"name": "Sarsılmaz Kabuk", "kademe": 2, "cost": 750,
		"recipe": ["isik_parcacigi", "isik_parcacigi", "kutsal_tilsim"],
		"stats": {"item_shield_power_flat": 60.0, "item_shield_regen_flat": 1.0, "item_shield_regen_percent": 0.10},
		"passive": "Kalkan yenilenme hızı %10 artar."},
	"kirilmaz_irade": {"name": "Kırılmaz İrade", "kademe": 2, "cost": 770,
		"recipe": ["isik_parcacigi", "isik_parcacigi", "yasam_kristali"],
		"stats": {"item_shield_regen_flat": 1.0, "item_shield_regen_percent": 0.10},
		"passive": "Her hasar aldığında 2 kalkan yenilersin."},
	"aura_kristali": {"name": "Aura Kristali", "kademe": 2, "cost": 780,
		"recipe": ["isik_parcacigi", "kol_saati", "kutsal_tilsim"],
		"stats": {"item_shield_power_flat": 20.0, "item_shield_regen_flat": 1.0, "item_shield_delay_reduction": 0.5},
		"passive": "Kalkan yenilenme bekleme süresi 0.5 saniye azalır."},
	"lutuf_madalyonu": {"name": "Lütuf Madalyonu", "kademe": 2, "cost": 780,
		"recipe": ["kutsal_tilsim", "kutsal_tilsim", "kol_saati"],
		"stats": {"heal_shield_power": 0.08, "cooldown_reduction_percent": 0.05}},
	"yenilenme_ozutu": {"name": "Yenilenme Özütü", "kademe": 2, "cost": 790,
		"recipe": ["yasam_kristali", "yasam_kristali", "kutsal_tilsim"],
		"stats": {"max_health": 110.0, "item_health_regen": 1.0, "item_vitamin_regen_bonus": 2.0},
		"passive": "Hasar almak 6 saniye boyunca 2 can yenilenmesi kazandırır."},
	"olum_esigi": {"name": "Ölüm Eşiği", "kademe": 2, "cost": 830,
		"recipe": ["isik_parcacigi", "isik_parcacigi", "kanli_yakut"],
		"stats": {"item_shield_power_flat": 90.0},
		"passive": "Canın %30'un altına düştüğünde anında maksimum kalkanının %20'sini yenilersin. (120 sn bekleme süresi)"},
	"kizil_hasat": {"name": "Kızıl Hasat", "kademe": 2, "cost": 840,
		"recipe": ["kan_disi", "yasam_kristali", "tecrube_kitabi"],
		"stats": {"lifesteal_percent": 0.05},
		"passive": "Bir birimi katlettiğinde %10 şansla eksik canının %1'ini yenilersin."},
	"ruhlarin_akisi": {"name": "Ruhların Akışı", "kademe": 2, "cost": 850,
		"recipe": ["tecrube_kitabi", "ayakkabi_bagcigi", "ceviklik_yuzugu"],
		"stats": {"exp_gain_percent": 0.10},
		"passive": "Topladığın her EXP orbı %1 hareket hızı kazandırır, 4 saniyede azalarak kaybolur. Birikir; her yeni orb süreyi baştan başlatır."},

	## ------------------------------------------------------------------ 3. kademe: Efsanevi eşyalar
	"anka_kusunun_kalbi": {"name": "Anka Kuşunun Kalbi", "kademe": 3, "cost": 1850,
		"recipe": ["yenilenme_ozutu", "yenilenme_ozutu", "yasam_kristali"],
		"stats": {"max_health": 200.0, "item_health_regen": 5.0},
		"passive": "Canın %40'ın altına düştüğünde can yenilenmen 2 katına çıkar."},
	"ilidaricin_kilici": {"name": "Ilıdaric'in Kılıcı", "kademe": 3, "cost": 1950,
		"recipe": ["ruzgar_eldiveni", "savascinin_kilici", "ceviklik_yuzugu", "ceviklik_yuzugu"],
		"stats": {"item_fire_rate_percent": 0.25, "damage_bonus": 15.0},
		"passive": "Her silahının 8. saldırısı 2 kez tetiklenir (2 kez ateş eder)."},
	"canavarlastirma_ozutu": {"name": "Canavarlaştırma Özütü", "kademe": 3, "cost": 1970,
		"recipe": ["ruzgar_eldiveni", "savascinin_kilici", "ceviklik_yuzugu", "tornavida"],
		"stats": {"damage_bonus": 10.0, "item_fire_rate_percent": 0.15},
		"passive": "Saldırıların hedefin mevcut canının %2'si kadar fazladan hasar verir (bosslara en fazla 40)."},
	"son_felaket_pencesi": {"name": "Son Felaket Pençesi", "kademe": 3, "cost": 2000,
		"recipe": ["keskin_goz_hanceri", "keskin_goz_hanceri", "savascinin_kilici"],
		"stats": {"damage_bonus": 35.0, "crit_chance_bonus": 0.20, "item_crit_damage_bonus": 0.5},
		"passive": "Kritik hasarını %50 arttırır (kritik hasar sınırını aşabilir)."},
	"kabuk_delen": {"name": "Kabuk Delen", "kademe": 3, "cost": 2010,
		"recipe": ["zirh_soken_hancer", "savascinin_kilici", "tornavida", "tornavida"],
		"stats": {"damage_bonus": 25.0, "shield_pen_percent": 0.20},
		"passive": "%20 Kalkan Delme."},
	"kralin_kadehi": {"name": "Kral'ın Kadehi", "kademe": 3, "cost": 2010,
		"recipe": ["kemik_kolye", "yenilenme_ozutu", "tecrube_kitabi", "kanli_yakut"],
		"stats": {"max_health": 220.0, "damage_bonus": 10.0},
		"passive": "Çevrende ölen her 40 düşman başına kalıcı olarak 1 can kazanırsın."},
	"ninjanin_el_kitabi": {"name": "Ninja'nın El Kitabı", "kademe": 3, "cost": 2020,
		"recipe": ["ruzgar_eldiveni", "ruhlarin_akisi", "ayakkabi_bagcigi", "ayakkabi_bagcigi"],
		"stats": {"item_fire_rate_percent": 0.30, "item_speed_percent": 0.10, "dodge_chance": 0.05},
		"passive": "Yaratıkların içinden geçebilirsin."},
	"zamanbukenin_eldiveni": {"name": "Zamanbükenin Eldiveni", "kademe": 3, "cost": 2060,
		"recipe": ["ruzgar_eldiveni", "suikastci_kamasi", "lutuf_madalyonu"],
		"stats": {"damage_bonus": 10.0, "item_fire_rate_percent": 0.15, "cooldown_reduction_percent": 0.10},
		"passive": "Her saldırı temel yeteneklerinin (Q, E) kalan bekleme süresini %3 azaltır."},
	"isigin_muhafizi": {"name": "Işığın Muhafızı Parşomeni", "kademe": 3, "cost": 2060,
		"recipe": ["lutuf_madalyonu", "savascinin_kilici", "kutsal_tilsim", "kanli_yakut"],
		"stats": {"damage_bonus": 15.0, "heal_shield_power": 0.10},
		"passive": "İyileştirme ve kalkan sağladığın arkadaşın 6 saniyeliğine %15 saldırı hızı ve 5 saldırı gücü kazanır.",
		"support_only": true},
	"zaman_kiran": {"name": "Zaman Kıran", "kademe": 3, "cost": 2060,
		"recipe": ["savascinin_kilici", "olum_esigi", "kol_saati", "isik_parcacigi"],
		"stats": {"damage_bonus": 25.0, "item_shield_power_flat": 50.0},
		"passive": "Canın 10'un altına düştüğünde 1 saniyeliğine ölümsüz olursun ve görüş alanındaki tüm yaratıklar (bosslar dahil) 5 saniye donar. (120 sn bekleme süresi)"},
	"astral_zirh_ozu": {"name": "Astral Zırh Özü", "kademe": 3, "cost": 2080,
		"recipe": ["aura_kristali", "kirilmaz_irade", "kol_saati", "kutsal_tilsim"],
		"stats": {"item_shield_power_flat": 120.0, "item_shield_regen_flat": 2.0, "cooldown_reduction_percent": 0.10,
			"item_shield_delay_reduction": 1.0},
		"passive": "Kalkan yenilenme bekleme süresi 1 saniye azalır."},
	"kan_aglayan": {"name": "Kan Ağlayan", "kademe": 3, "cost": 2080,
		"recipe": ["ruh_emici", "savascinin_kilici", "sarsilmaz_kabuk"],
		"stats": {"damage_bonus": 30.0, "lifesteal_percent": 0.08},
		"passive": "Canın doluyken can çalmadan gelen canlar kalkana eklenir."},
	"gunesin_iradesi": {"name": "Güneşin İradesi", "kademe": 3, "cost": 2130,
		"recipe": ["savascinin_kilici", "olum_esigi", "kemik_kolye"],
		"stats": {"max_health": 100.0, "damage_bonus": 20.0},
		"passive": "Canın %20'nin altına düştüğünde anında saldırı gücünün %250'si kadar kalkan ve 6 saniyede yenilenen %25 can kazanırsın. (120 sn bekleme süresi)"},
	"son_sans": {"name": "Son Şans", "kademe": 3, "cost": 2130,
		"recipe": ["ruhlarin_akisi", "savascinin_kilici", "tecrube_kitabi", "tecrube_kitabi"],
		"stats": {"damage_bonus": 25.0, "luck": 10.0},
		"passive": "Her 1 şans başına 1 saldırı gücü kazanırsın."},
	"azrailin_gozu": {"name": "Azrail'in Gözü", "kademe": 3, "cost": 2330,
		"recipe": ["keskin_goz_hanceri", "savascinin_kilici", "suikastci_kamasi", "bile_tasi"],
		"stats": {"damage_bonus": 35.0},
		"passive": "Her yaratığa ilk vuruşun garanti kritik vurur ve fazladan saldırı gücünün %20'si kadar hasar verir."},
	"aegisin_muhafizi": {"name": "Aegis'in Sonsuz Muhafızı", "kademe": 3, "cost": 2360,
		"recipe": ["sarsilmaz_kabuk", "olum_esigi", "aura_kristali"],
		"stats": {"item_shield_power_flat": 250.0, "item_shield_regen_flat": 1.5},
		"passive": "Kalkanın %40'ın altına düştüğünde (savaştayken de) her saniye maksimum kalkanının %0.5'ini kazanırsın."},
}

## Dükkanda/envanterde sabit sıra: kademe, sonra fiyat.
const KEYS: Array = [
	"kutsal_tilsim", "isik_parcacigi", "ayakkabi_bagcigi", "yasam_kristali", "kol_saati", "kan_disi", "tecrube_kitabi",
	"ceviklik_yuzugu", "tornavida", "kanli_yakut", "bile_tasi",
	"kemik_kolye", "suikastci_kamasi", "ruh_emici", "keskin_goz_hanceri", "ruzgar_eldiveni", "zirh_soken_hancer",
	"savascinin_kilici", "sarsilmaz_kabuk", "kirilmaz_irade", "aura_kristali", "lutuf_madalyonu", "yenilenme_ozutu",
	"olum_esigi", "kizil_hasat", "ruhlarin_akisi",
	"anka_kusunun_kalbi", "ilidaricin_kilici", "canavarlastirma_ozutu", "son_felaket_pencesi", "kabuk_delen",
	"kralin_kadehi", "ninjanin_el_kitabi", "zamanbukenin_eldiveni", "isigin_muhafizi", "zaman_kiran", "astral_zirh_ozu",
	"kan_aglayan", "gunesin_iradesi", "son_sans", "azrailin_gozu", "aegisin_muhafizi",
]

## Stat etiketleri (açıklama metni + ipuçları). percent=true: değer kesir, "%X" yazılır.
const STAT_LABELS := {
	"max_health": ["Can", false], "damage_bonus": ["Saldırı Gücü", false],
	"item_fire_rate_percent": ["Saldırı Hızı", true], "heal_shield_power": ["İyileştirme ve Kalkan Gücü", true],
	"item_shield_power_flat": ["Kalkan", false], "item_shield_regen_flat": ["Kalkan Yenilenmesi", false],
	"item_shield_regen_percent": ["Kalkan Yenilenme Hızı", true], "item_health_regen": ["Can Yenilenmesi", false],
	"lifesteal_percent": ["Can Çalma", true], "luck": ["Şans", false], "exp_gain_percent": ["EXP Kazanımı", true],
	"item_speed_percent": ["Hareket Hızı", true], "dodge_chance": ["Sıvışma", true],
	"cooldown_reduction_percent": ["Bekleme Süresinde Azalma", true], "shield_pen_percent": ["Kalkan Delme", true],
	"crit_chance_bonus": ["Kritik Şansı", true],
}
## Pasifin kendisi olan (açıklamada stat satırı olarak tekrar yazılmayan) statlar.
const PASSIVE_ONLY_STATS := ["item_flat_hit_damage", "item_damage_mult_bonus", "item_crit_damage_bonus",
	"item_vitamin_regen_bonus", "item_shield_delay_reduction"]


static func get_def(key: String) -> Dictionary:
	return DEFS.get(key, {})


static func kademe(key: String) -> int:
	return int(get_def(key).get("kademe", 1))


static func cost(key: String) -> int:
	return int(get_def(key).get("cost", 0))


static func recipe(key: String) -> Array:
	return get_def(key).get("recipe", [])


static func item_name(key: String) -> String:
	return str(get_def(key).get("name", key.capitalize()))


static func icon_path(key: String) -> String:
	return ICON_DIR + key + ".png"


static func icon(key: String) -> Texture2D:
	var p: String = icon_path(key)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


static func is_support_only(key: String) -> bool:
	return bool(get_def(key).get("support_only", false))


static func is_ally_support_char(char_id: int) -> bool:
	return ALLY_SUPPORT_CHARS.has(char_id)


## Bu eşyanın içine girdiği (bir üst kademe) eşyalar - "Yükseltmeleri" satırı için.
static func builds_into(key: String) -> Array:
	var out: Array = []
	for k in KEYS:
		if (recipe(k) as Array).has(key) and not out.has(k):
			out.append(k)
	return out


## Stat satırları + pasif: "+50 Can\n+5 Saldırı Gücü\n\nPasif: ..."
static func describe(key: String) -> String:
	var def: Dictionary = get_def(key)
	var lines: Array = []
	var stats: Dictionary = def.get("stats", {})
	for s in stats:
		if not STAT_LABELS.has(s):
			continue
		var label: String = STAT_LABELS[s][0]
		var v: float = float(stats[s])
		if bool(STAT_LABELS[s][1]):
			lines.append("+%%%s %s" % [_num(v * 100.0), label])
		else:
			lines.append("+%s %s" % [_num(v), label])
	var text: String = "\n".join(lines)
	if def.has("passive"):
		text += ("\n\n" if text != "" else "") + "Pasif: " + str(def["passive"])
	return text


static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v)


## ------------------------------------------------------------------ satın alma planı (tarif + indirim + slot)
## owned: GameManager.owned_items ([{key, ...}]). Döner: {"cost": ödenecek altın, "consume": [owned indeksleri],
## "full": tam fiyat}. Sahip olunan bir alt parça (ya da alt parçanın da alt parçası) tüketilir ve fiyatı düşülür.
static func plan_purchase(key: String, owned: Array) -> Dictionary:
	var avail: Array = []
	for i in range(owned.size()):
		avail.append(i)
	var consume: Array = []
	var paid: int = 0
	var rec: Array = recipe(key)
	if rec.is_empty():
		paid = cost(key)
	else:
		for comp in rec:
			paid += _obtain(str(comp), owned, avail, consume)
	return {"cost": paid, "consume": consume, "full": cost(key)}


static func _obtain(comp: String, owned: Array, avail: Array, consume: Array) -> int:
	for i in avail:
		if str((owned[i] as Dictionary).get("key", "")) == comp:
			avail.erase(i)
			consume.append(i)
			return 0
	var rec: Array = recipe(comp)
	if rec.is_empty():
		return cost(comp)
	var sum: int = 0
	for sub in rec:
		sum += _obtain(str(sub), owned, avail, consume)
	return sum


## Kademe başına sahip olunan sayı (consume: bu satın almada tüketilecek indeksler hariç tutulur).
static func count_kademe(owned: Array, k: int, exclude: Array = []) -> int:
	var n: int = 0
	for i in range(owned.size()):
		if exclude.has(i):
			continue
		if kademe(str((owned[i] as Dictionary).get("key", ""))) == k:
			n += 1
	return n


static func slot_limit(k: int, part_slots: int) -> int:
	match k:
		KADEME_EPIK:
			return EPIC_SLOT_LIMIT
		KADEME_EFSANEVI:
			return LEGENDARY_SLOT_LIMIT
	return part_slots


static func owns(owned: Array, key: String) -> bool:
	for e in owned:
		if str((e as Dictionary).get("key", "")) == key:
			return true
	return false


## Satın alınabilir mi (altın hariç): "" = evet, değilse kullanıcıya gösterilecek sebep.
static func purchase_block_reason(key: String, owned: Array, part_slots: int, plan: Dictionary = {}) -> String:
	if not DEFS.has(key):
		return "Bilinmeyen eşya"
	if plan.is_empty():
		plan = plan_purchase(key, owned)
	var k: int = kademe(key)
	if k == KADEME_EFSANEVI and owns(owned, key):
		return "Zaten sende var"
	var have: int = count_kademe(owned, k, plan.get("consume", []))
	if have >= slot_limit(k, part_slots):
		return "%s slotları dolu" % KADEME_NAMES[k - 1]
	return ""


static func sell_refund(key: String) -> int:
	return int(round(float(cost(key)) * SELL_REFUND_RATIO))
