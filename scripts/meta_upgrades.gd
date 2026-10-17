extends RefCounted

## KALICI GELİŞTİRMELER (kullanıcı isteği 2026-10-13): Ruh Kıymığı ile alınan, her koşuda otomatik uygulanan 20 kalıcı güçlendirme.
## Kayıt meta_progress.gd'nin user://meta.cfg dosyasında ([upgrades] id=seviye, [upgrade_spent] id=harcanan). Mağaza: soul_shop_screen.gd "GELİŞTİRMELER" sekmesi.
##
## TEK TABLO `LIST` - sayıları (seviye sayısı, seviye başı etki, fiyat) buradan ayarla; başka yerde kopyası YOK
## (player.gd `_apply_meta_upgrades` etkiyi `bonus(id)` ile okur, fiyat/etki metinleri mağazada bu tablodan üretilir).
##
## FİYAT: seviye n -> n+1 bedeli = first + step * n (n = mevcut seviye). Seviye sayısı az olanların first/step'i yüksek tutuldu
## (az sayıda ama güçlü basamak), seviye atladıkça fiyat artar.
## SIFIRLAMA: tüm geliştirmeler birden; harcanan Ruh Kıymığı iade edilir ama bir ÜCRET kesilir (RESET_FEE_*) - ücret iadeden düşer,
## yani bakiye yetmese de sıfırlanabilir ama bedelsiz değildir.
##
## ÇOK OYUNCULU: her oyuncu KENDİ makinesindeki geliştirmeleri kendi oyuncusuna uygular (kilitlerle aynı güven modeli: istemci doğrulaması yok).
## Dirilme hakkı host'ta tutulduğu için başlangıçta host'a bildirilir (NetworkManager.announce_meta_revive_bonus).

const MetaProgress: GDScript = preload("res://scripts/meta_progress.gd")

const RESET_FEE_PERCENT := 0.15 ## harcananın bu kadarı sıfırlama ücreti
const RESET_FEE_MIN := 20 ## ... ama en az bu kadar (harcanandan fazla olamaz)

## Etki birimi: PCT = kesir (0.08 -> "%8"), FLAT = düz sayı, COUNT = adet.
const PCT := "pct"
const FLAT := "flat"
const COUNT := "count"

## Her satır: id, name, desc, icon (stat_icon.gd ICON_PATHS anahtarı, "" = ikonsuz), max (seviye sayısı), per (seviye başı etki), unit,
## first (1. seviye bedeli), step (her seviyede bedele eklenen).
const LIST: Array = [
	{"id": "pickup", "name": "Toplama Mesafesi", "desc": "Altın, XP ve eşyaları daha uzaktan toplarsın.", "icon": "pickup_range",
		"max": 10, "per": 0.08, "unit": PCT, "first": 10, "step": 6},
	{"id": "attack", "name": "Saldırı Gücü", "desc": "Tüm saldırı ve yetenek hasarın artar.", "icon": "damage",
		"max": 15, "per": 2.0, "unit": FLAT, "first": 15, "step": 8},
	{"id": "atk_speed", "name": "Saldırı Hızı", "desc": "Silahların daha sık vurur.", "icon": "fire_rate",
		"max": 10, "per": 0.02, "unit": PCT, "first": 20, "step": 10},
	{"id": "regen", "name": "Can Yenilenmesi", "desc": "5 saniyede bir yenilenen can artar.", "icon": "health_regen",
		"max": 10, "per": 0.5, "unit": FLAT, "first": 15, "step": 8},
	{"id": "health", "name": "Can", "desc": "Azami canın artar.", "icon": "max_health",
		"max": 15, "per": 5.0, "unit": FLAT, "first": 12, "step": 6},
	{"id": "lifesteal", "name": "Can Çalma", "desc": "Verdiğin hasarın bir kısmı sana can olarak döner.", "icon": "lifesteal",
		"max": 10, "per": 0.002, "unit": PCT, "first": 20, "step": 12},
	{"id": "speed", "name": "Hareket Hızı", "desc": "Daha hızlı koşarsın.", "icon": "speed",
		"max": 8, "per": 0.015, "unit": PCT, "first": 20, "step": 12},
	{"id": "shield_amount", "name": "Kalkan Miktarı", "desc": "Azami mana kalkanın artar.", "icon": "shield_amount",
		"max": 8, "per": 0.04, "unit": PCT, "first": 18, "step": 10},
	{"id": "shield_regen", "name": "Kalkan Yenilenmesi", "desc": "Mana kalkanın saniyede daha çok yenilenir.", "icon": "shield_regen",
		"max": 10, "per": 0.4, "unit": FLAT, "first": 15, "step": 8},
	{"id": "heal_power", "name": "İyileştirme ve Kalkan Gücü", "desc": "Sağladığın tüm can ve kalkan büyür.", "icon": "heal_power",
		"max": 8, "per": 0.025, "unit": PCT, "first": 25, "step": 14},
	{"id": "crit_chance", "name": "Kritik Oran", "desc": "Kritik vuruş şansın artar.", "icon": "crit_chance",
		"max": 10, "per": 0.01, "unit": PCT, "first": 20, "step": 11},
	{"id": "crit_damage", "name": "Kritik Hasar", "desc": "Kritik vuruşların daha çok vurur.", "icon": "crit_damage",
		"max": 10, "per": 0.03, "unit": PCT, "first": 20, "step": 11},
	{"id": "luck", "name": "Şans", "desc": "Yaratıkların bir şey düşürme ihtimali artar.", "icon": "luck",
		"max": 10, "per": 0.5, "unit": FLAT, "first": 20, "step": 10},
	{"id": "discount", "name": "Fiyat İndirimi", "desc": "Dükkan fiyatları düşer (Para ruhaniyle toplanır, en fazla %50).", "icon": "",
		"max": 5, "per": 0.02, "unit": PCT, "first": 40, "step": 30},
	{"id": "shield_protection", "name": "Kalkan Soğurma", "desc": "Mana kalkanın hasarın daha büyük kısmını emer.", "icon": "shield_protection",
		"max": 5, "per": 0.02, "unit": PCT, "first": 45, "step": 35},
	{"id": "free_reroll", "name": "Ücretsiz Karıştırma", "desc": "Her koşuda level kartı karıştırmanın ilki bedava.", "icon": "",
		"max": 1, "per": 1.0, "unit": COUNT, "first": 300, "step": 0},
	{"id": "revive", "name": "Dirilme Hakkı", "desc": "Her koşuya +1 dirilme hakkıyla başlarsın.", "icon": "",
		"max": 1, "per": 1.0, "unit": COUNT, "first": 600, "step": 0},
	{"id": "cooldown", "name": "Bekleme Süresi Azaltma", "desc": "Yeteneklerin daha çabuk yenilenir (en fazla %60).", "icon": "cooldown_reduction",
		"max": 8, "per": 0.015, "unit": PCT, "first": 25, "step": 15},
	{"id": "skill_cost", "name": "Yetenek Mana K. Bedeli", "desc": "Yetenekler daha az mana kalkanı harcar.", "icon": "shield_amount",
		"max": 5, "per": 0.04, "unit": PCT, "first": 40, "step": 30},
	{"id": "shield_pen", "name": "Kalkan Delme", "desc": "Yaratıkların kalkan soğurmasını deler.", "icon": "shield_pen_percent",
		"max": 5, "per": 0.02, "unit": PCT, "first": 50, "step": 40},
]

const DISCOUNT_CAP := 0.5
const BASE_REVIVES := 3


static func ids() -> Array:
	var out: Array = []
	for d: Dictionary in LIST:
		out.append(d["id"])
	return out


static func def(id: String) -> Dictionary:
	for d: Dictionary in LIST:
		if d["id"] == id:
			return d
	return {}


## Gelişmelerin oyuncuya uygulanıp uygulanmayacağı: başsız (headless) test koşuları geliştiricinin gerçek kaydını okumasın
## (stat testleri sayısal beklenti yazar); testler path_override ya da ortam yolu verirse AÇIK.
static func active() -> bool:
	if MetaProgress.path_override != "" or OS.get_environment(MetaProgress.ENV_PATH) != "":
		return true
	return DisplayServer.get_name() != "headless"


static func level(id: String) -> int:
	var d: Dictionary = def(id)
	if d.is_empty():
		return 0
	return clampi(int((MetaProgress.load_all()["upgrades"] as Dictionary).get(id, 0)), 0, int(d["max"]))


static func max_level(id: String) -> int:
	return int(def(id).get("max", 0))


## Toplam etki (seviye x seviye başı etki). Oyuncu/dükkan bunu okur; active() değilse 0.
static func bonus(id: String) -> float:
	if not active():
		return 0.0
	return float(level(id)) * float(def(id).get("per", 0.0))


## Bir sonraki seviyenin bedeli (en yüksek seviyedeyse 0).
static func next_cost(id: String) -> int:
	var d: Dictionary = def(id)
	if d.is_empty():
		return 0
	var lv: int = level(id)
	if lv >= int(d["max"]):
		return 0
	return int(d["first"]) + int(d["step"]) * lv


## Bir geliştirmeyi sonuna kadar almanın toplam bedeli (HTML/ayar listesi ve mağaza ipucu için).
static func total_cost(id: String) -> int:
	var d: Dictionary = def(id)
	var sum: int = 0
	for n in range(int(d.get("max", 0))):
		sum += int(d["first"]) + int(d["step"]) * n
	return sum


static func can_buy(id: String) -> bool:
	var c: int = next_cost(id)
	return c > 0 and MetaProgress.shards() >= c


static func buy(id: String) -> bool:
	var c: int = next_cost(id)
	if c <= 0:
		return false
	var data: Dictionary = MetaProgress.load_all()
	if int(data["shards"]) < c:
		return false
	data["shards"] = int(data["shards"]) - c
	var lv: Dictionary = data["upgrades"]
	var spent: Dictionary = data["upgrade_spent"]
	lv[id] = level(id) + 1
	spent[id] = int(spent.get(id, 0)) + c
	MetaProgress.commit(data)
	return true


static func total_spent() -> int:
	var sum: int = 0
	for v in (MetaProgress.load_all()["upgrade_spent"] as Dictionary).values():
		sum += int(v)
	return sum


static func total_levels() -> int:
	var sum: int = 0
	for id: String in ids():
		sum += level(id)
	return sum


## Sıfırlama ücreti: harcananın %RESET_FEE_PERCENT'i, en az RESET_FEE_MIN, harcanandan fazla değil.
static func reset_fee() -> int:
	var spent: int = total_spent()
	if spent <= 0:
		return 0
	return mini(spent, maxi(RESET_FEE_MIN, int(round(float(spent) * RESET_FEE_PERCENT))))


static func reset_refund() -> int:
	return total_spent() - reset_fee()


static func can_reset() -> bool:
	return total_spent() > 0


## Tüm geliştirmeleri sıfırlar, harcananı ücret düşülmüş iade eder. İade edilen miktarı döner (-1: sıfırlanacak bir şey yok).
static func reset_all() -> int:
	if not can_reset():
		return -1
	var refund: int = reset_refund()
	var data: Dictionary = MetaProgress.load_all()
	data["shards"] = int(data["shards"]) + refund
	data["upgrades"] = {}
	data["upgrade_spent"] = {}
	MetaProgress.commit(data)
	return refund


## Mağaza metni: "+%24" / "+10" / "+1".
static func format_value(id: String, v: float) -> String:
	var d: Dictionary = def(id)
	match str(d.get("unit", FLAT)):
		PCT:
			return "+%%%s" % _trim(v * 100.0)
		COUNT:
			return "+%d" % int(round(v))
	return "+%s" % _trim(v)


static func _trim(v: float) -> String:
	var s: String = "%.2f" % v
	while s.contains(".") and (s.ends_with("0") or s.ends_with(".")):
		s = s.substr(0, s.length() - 1)
	return s
