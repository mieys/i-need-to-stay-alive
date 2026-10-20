extends RefCounted

## KALICI İLERLEME: RUH KIYMIĞI + KİLİTLER (kullanıcı isteği 2026-10-13: "bağımlılık yapıcı mekanikler" -> 1 meta para birimi, 2 kilitli içerik).
## user://meta.cfg (ConfigFile; run_records.gd ile AYNI desen, ayrı dosya - rekorlar sıfırlansa kilitler kalır). Her oyuncu KENDİ makinesinde.
##
## KAZANIM (takım sonucuna bağlı, rol-adil): hayatta kalma süresi + ulaşılan kademe + sonsuz kat + zafer + yeni başarım.
## Ham hasar/öldürme KULLANILMAZ: destek karakterler (Oakley/Melek/Shaman) hasar odaklı değil, hasar rakamı da kademeyle katlanarak
## büyüyor (kademe 1: ~7 bin, kademe 13: ~16 milyon - balans kayıtlarından) -> iki rolde de adil olan tek ölçü takımın ilerleyişi.
##
## DÜŞENE KAYIP YOK (kullanıcı isteği: "oyuncular oyundan düşünce yok olmamalı bu puanlar"): puan koşu sonunda TEK SEFERDE verilmez.
## `bank_run(özet, bankalanan)` her kademe/kat bildiriminde ve dakikada bir çağrılır: toplamdan DAHA ÖNCE verileni çıkarıp FARKI anında
## diske yazar (idempotent) -> bağlantı kopsa / pencere kapansa / oyun çökse bile o ana kadarki puan kalır.
##
## KİLİTLER: sadece MENÜDE seçilen şeyler (karakter, başlangıç silahı, evcil hayvan, ruhani yetenek). Koşu içi kart/eşya havuzuna dokunmaz
## (çok oyunculuda host ile istemci havuzu ayrışmaz). Katalog + fiyat TEK tabloda (aşağıda) - dengeyi buradan ayarla.

const DEFAULT_PATH := "user://meta.cfg"
const ENV_PATH := "LILSLAYERS_META_PATH"
## Geliştirici/test kısayolu: ortam değişkeni "1" ise her şey açık (iki süreçli MP denetimleri, elle test). Kayıt dosyasına yazılmaz.
const ENV_UNLOCK_ALL := "LILSLAYERS_UNLOCK_ALL"
static var path_override: String = ""
static var unlock_all_override: bool = false ## testler
## Debug modu açıkken her şey açık (GameManager.debug_mode_unlocked ayarlayıcısı yazar; kayda yazılmaz). Karakterlerin Q/E/R kilidi de buna bakar.
static var debug_open: bool = false

const CHAR := "char"
const WEAPON := "weapon"
const PET := "pet"
const SPIRIT := "spirit"
const KINDS := [CHAR, WEAPON, PET, SPIRIT]
const KIND_LABELS := {CHAR: "Karakter", WEAPON: "Başlangıç Silahı", PET: "Evcil Hayvan", SPIRIT: "Ruhani Yetenek"}

const CURRENCY_NAME := "Ruh Kıymığı"

## ---------------------------------------------------------------- KAZANIM (tek yer - dengeyi buradan ayarla)
const SHARDS_FIRST_TIER := 5 ## Kademe 1'e ulaşınca; sonraki her kademe bir öncekinden SHARDS_TIER_STEP fazla (5-6-7-8-...)
const SHARDS_TIER_STEP := 1
const SHARDS_PER_MINUTE := 2 ## hayatta kalınan dakika başına (tam dakika)
const SHARDS_PER_LAYER := 10 ## sonsuz mod katı başına
const SHARDS_VICTORY := 150 ## zafer (bir kez)
const SHARDS_ACHIEVEMENT := 25 ## yeni açılan başarım başına
const MIN_RUN_SECONDS := 30.0 ## main.gd _record_run_end_once ile aynı eşik: bundan kısa koşu puan vermez
## Başlangıç hediyesi (kullanıcı isteği 2026-10-14: "herkes 1000 ruh kıymığıyla başlasın"): kayıtta `meta/starter_granted` yoksa TEK SEFER
## bakiyeye eklenir (yeni oyuncu VE eski kayıtlar). total_earned'e yazılmaz (kazanılmış puan değil). Testlerde (path_override) kapalı.
const STARTING_SHARDS := 1000
static var starter_shards_override: int = -1 ## testler: >= 0 ise o kadar hediye (geçici dosyada da)

## ---------------------------------------------------------------- BAŞLANGIÇTA AÇIK OLANLAR
## 4 kolay karakter: Talon, Oakley (destek), Şovalye, Büyücü Kız. Sonrası Ruh Mağazası'ndan.
const STARTERS := {
	CHAR: [1, 2, 4, 7],
	WEAPON: ["dagger", "tabanca", "yay", "uzunkilic"],
	PET: ["kopek"],
	SPIRIT: ["para", "can", "adc", "tank"],
}

## ---------------------------------------------------------------- FİYATLAR (kilitli olanlar; listede yoksa kilitli değildir)
const COSTS := {
	CHAR: {3: 250, 5: 250, 8: 300, 9: 300, 10: 350, 11: 350, 12: 350, 13: 400, 14: 400, 15: 450},
	WEAPON: {"fire_staff": 120, "lightning_staff": 120, "tuftuf": 140, "tufek": 140, "arcane": 160, "crossbow": 160,
		"boomerang": 120, "buz_asasi": 180, "fisek": 180, "pence": 100, "topuz": 140, "gokkusagi": 180, "mizrak": 160, "kalkan": 160, "yinyang": 180},
	PET: {"papagan": 120, "kelebek": 150, "peri": 180, "kirpi": 150},
	SPIRIT: {"taktik": 150, "dukkan": 150, "savas_sevki": 200, "kalkan_bagi": 200},
}

## Test/okuma önbelleği: dosya her çağrıda okunmasın (menüde ~40 kart soruyor). Yazma/yol değişince geçersiz olur.
static var _cache: Dictionary = {}
static var _cache_path: String = ""


static func set_path_override(p: String) -> void:
	path_override = p
	_cache.clear()


## Testler için (GDScript: `const X := preload(...)` üzerinden statik değişkene atanamaz, bu yüzden ayarlayıcı).
static func set_unlock_all(v: bool) -> void:
	unlock_all_override = v


static func set_debug_open(v: bool) -> void:
	debug_open = v


static func _path() -> String:
	if path_override != "":
		return path_override
	var env: String = OS.get_environment(ENV_PATH)
	return env if env != "" else DEFAULT_PATH


static func _all_unlocked() -> bool:
	return unlock_all_override or debug_open or OS.get_environment(ENV_UNLOCK_ALL) == "1"


static func _defaults() -> Dictionary:
	## upgrades: geliştirme id -> seviye; upgrade_spent: geliştirme id -> o geliştirmeye harcanan toplam (sıfırlamada TAM bu kadar iade edilir,
	## fiyatlar sonradan ayarlansa bile haksızlık olmasın). Mantık meta_upgrades.gd'de.
	return {"shards": 0, "total_earned": 0, "unlocked": {CHAR: [], WEAPON: [], PET: [], SPIRIT: []}, "upgrades": {}, "upgrade_spent": {}}


## Tüm kayıt (dosya yoksa/bozuksa sıfır: herkes baştan başlar).
static func load_all() -> Dictionary:
	var p: String = _path()
	if p == _cache_path and not _cache.is_empty():
		return _cache.duplicate(true)
	var data: Dictionary = _defaults()
	var cfg := ConfigFile.new()
	var grant_pending: bool = true
	if cfg.load(p) == OK:
		grant_pending = not bool(cfg.get_value("meta", "starter_granted", false))
		data["shards"] = maxi(0, int(cfg.get_value("meta", "shards", 0)))
		data["total_earned"] = maxi(0, int(cfg.get_value("meta", "total_earned", 0)))
		for kind: String in KINDS:
			var raw: Variant = cfg.get_value("unlocked", kind, [])
			var list: Array = []
			if raw is Array: ## elle bozulmuş dosyada başka bir tip olabilir - çökmesin
				for v in raw:
					list.append(int(v) if kind == CHAR else str(v))
			(data["unlocked"] as Dictionary)[kind] = list
		for sec: String in ["upgrades", "upgrade_spent"]:
			if cfg.has_section(sec):
				for k: String in cfg.get_section_keys(sec):
					(data[sec] as Dictionary)[k] = maxi(0, int(cfg.get_value(sec, k, 0)))
	_cache = data
	_cache_path = p
	if grant_pending:
		var gift: int = _starter_gift()
		if gift > 0:
			data["shards"] = int(data["shards"]) + gift
			_save(data) ## bayrak da yazılır (bir daha verilmez)
	return data.duplicate(true)


static func _starter_gift() -> int:
	if starter_shards_override >= 0:
		return starter_shards_override
	return 0 if path_override != "" else STARTING_SHARDS


static func set_starter_shards_override(v: int) -> void:
	starter_shards_override = v
	_cache.clear()


static func _save(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", int(data["shards"]))
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("meta", "total_earned", int(data["total_earned"]))
	for kind: String in KINDS:
		cfg.set_value("unlocked", kind, (data["unlocked"] as Dictionary)[kind])
	for sec: String in ["upgrades", "upgrade_spent"]:
		for k: String in (data[sec] as Dictionary).keys():
			if int((data[sec] as Dictionary)[k]) > 0:
				cfg.set_value(sec, k, int((data[sec] as Dictionary)[k]))
	cfg.save(_path())
	_cache = data.duplicate(true)
	_cache_path = _path()


## Dışarıdan (meta_upgrades.gd) kayıt yazmak için: load_all() ile alınan sözlüğü değiştirip buraya ver.
static func commit(data: Dictionary) -> void:
	_save(data)


static func shards() -> int:
	return int(load_all()["shards"])


## ---------------------------------------------------------------- KİLİTLER
static func is_starter(kind: String, key: Variant) -> bool:
	return (STARTERS.get(kind, []) as Array).has(key)


## Kilitsiz mi? (başlangıç listesi, satın alınmış, ya da kataloğa hiç girmemiş yeni içerik = kilitli SAYILMAZ: unutulan öğe oyuncuyu
## sessizce dışarıda bırakmasın).
static func is_unlocked(kind: String, key: Variant) -> bool:
	if _all_unlocked() or is_starter(kind, key):
		return true
	if not (COSTS.get(kind, {}) as Dictionary).has(key):
		return true
	return ((load_all()["unlocked"] as Dictionary)[kind] as Array).has(key)


static func cost(kind: String, key: Variant) -> int:
	return int((COSTS.get(kind, {}) as Dictionary).get(key, 0))


static func can_buy(kind: String, key: Variant) -> bool:
	return not is_unlocked(kind, key) and shards() >= cost(kind, key)


## Satın alır: yeterli bakiye + henüz açık değilse true.
static func buy(kind: String, key: Variant) -> bool:
	if is_unlocked(kind, key) or not (COSTS.get(kind, {}) as Dictionary).has(key):
		return false
	var data: Dictionary = load_all()
	var price: int = cost(kind, key)
	if int(data["shards"]) < price:
		return false
	data["shards"] = int(data["shards"]) - price
	((data["unlocked"] as Dictionary)[kind] as Array).append(key)
	_save(data)
	return true


## Kilitliyse kısa açıklama (kart/ipucu): "Kilitli - 250 Ruh Kıymığı (Ruh Mağazası)".
static func lock_text(kind: String, key: Variant) -> String:
	return "Kilitli - %d %s (Ruh Mağazası)" % [cost(kind, key), CURRENCY_NAME]


## Kilitli öğeleri ucuzdan pahalıya: [{"kind", "key", "cost"}] (mağaza listesi için; tür sırası KINDS).
static func locked_items() -> Array:
	var out: Array = []
	for kind: String in KINDS:
		var keys: Array = (COSTS[kind] as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return cost(kind, a) < cost(kind, b) or (cost(kind, a) == cost(kind, b) and str(a) < str(b)))
		for k in keys:
			out.append({"kind": kind, "key": k, "cost": cost(kind, k)})
	return out


## ---------------------------------------------------------------- KAZANIM
## Kademe 1..tier arası toplam kademe puanı: kademe n tek başına FIRST + (n-1)*STEP verir (5, 6, 7, 8, ...).
static func tier_shards(tier: int) -> int:
	var t: int = maxi(0, tier)
	return t * SHARDS_FIRST_TIER + SHARDS_TIER_STEP * t * (t - 1) / 2


## Bir koşunun TOPLAM puanı (zafer ve başarım hariç) - saf fonksiyon. özet = main.gd _run_summary().
static func shards_for_run(s: Dictionary) -> int:
	if float(s.get("time", 0.0)) < MIN_RUN_SECONDS:
		return 0
	var minutes: int = int(float(s.get("time", 0.0)) / 60.0)
	return tier_shards(int(s.get("tier", 0))) + minutes * SHARDS_PER_MINUTE \
			+ maxi(0, int(s.get("layer", 0))) * SHARDS_PER_LAYER


static func _grant(amount: int) -> void:
	if amount <= 0:
		return
	var data: Dictionary = load_all()
	data["shards"] = int(data["shards"]) + amount
	data["total_earned"] = int(data["total_earned"]) + amount
	_save(data)


## Koşuyu BANKALAR (idempotent): toplam puandan daha önce bankalanan çıkarılır, fark anında diske yazılır. Yeni bankalanan toplamı döner
## (çağıran saklar; ilk çağrıda 0 ver). Koşu sonu ayrıca çağrı gerekmez, ama çağrılırsa kalan fark eklenir.
static func bank_run(summary: Dictionary, already_banked: int) -> int:
	var total: int = shards_for_run(summary)
	if total > already_banked:
		_grant(total - already_banked)
		return total
	return already_banked


static func grant_victory() -> int:
	_grant(SHARDS_VICTORY)
	return SHARDS_VICTORY


static func grant_achievements(count: int) -> int:
	var amount: int = maxi(0, count) * SHARDS_ACHIEVEMENT
	_grant(amount)
	return amount
