extends RefCounted
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

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
## "Debug Modu" menü düğmesi (madde 614): YALNIZ menü kilitleri (karakter / başlangıç silahı / evcil / ruhani) açık. Q/E/R baştan açık DEĞİL
## (`Characters.skill_unlock_level` yalnız `debug_open`a bakar), debug menüsü yok. GameManager.content_unlock_mode ayarlayıcısı yazar; kayda yazılmaz.
static var content_open: bool = false

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
## BAŞLANGIÇ HEDİYESİ YOK (2026-11-12, kullanıcı: "herkesin ilerlemesi sıfırlansın ve bundan sonra 1000 kıymık hediyesi yok"): eski
## "herkes 1000 kıymıkla başlar" (madde 129) kaldırıldı; yeni oyuncu 0 ile başlar. Tek seferlik sıfırlama: progress_reset.gd.
const ProgressResetScript := preload("res://scripts/progress_reset.gd")
## Hile koruması (2026-11-12): kayıt MÜHÜRLÜ (şifreli + HMAC, secure_cfg.gd), ortam değişkeni kısayolları yalnız editörde (security_guard.gd).
const SecureCfgScript := preload("res://scripts/security/secure_cfg.gd")
const GuardScript := preload("res://scripts/security/security_guard.gd")

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
		"boomerang": 120, "buz_asasi": 180, "fisek": 180, "pence": 100, "topuz": 140, "gokkusagi": 180, "mizrak": 160, "kalkan": 160, "yinyang": 180, "pompali": 160, "makineli": 160},
	PET: {"papagan": 120, "kelebek": 150, "peri": 180, "kirpi": 150, "slime": 200, "hayalet": 180},
	SPIRIT: {"taktik": 150, "savas_sevki": 200, "kalkan_bagi": 200, "toplayici": 150}, ## toplayici madde 625
}

## ---------------------------------------------------------------- HARİTA ANAHTARLARI (madde 605, plan docs/harita_icerik/PLAN.md Aşama 4)
## Her haritanın TEK anahtar türü var (tür = harita kimliği; görsel/ad: key_icon.gd). O haritanın bossları her öldürmede düşürür
## (GameManager.KEYS_PER_BOSS), anında KENDİ kaydına yazılır. Anahtar tek seferlik kupa DEĞİL: harcanan bir birim. Aşağıdaki içerik Ruh Kıymığı'na
## EK OLARAK anahtar ister (anahtar fiyatın yerine geçmez, "her şey parayla çözülmesin"): [harita kimliği, adet]. BAŞLANGIÇ DEĞERLERİ (tahmin) -
## kullanıcı oynayıp ayarlar. Listede olmayan içerik yalnız kıymıkla alınır (Matthew/Assasin/Elara/Korsan/Melek, papağan, silahlar, ruhaniler).
## 3 anahtar = o haritada 1 zafer ya da 3 kez K5 bossu; 1 anahtar = 1 kez K5 bossu.
const KEY_COSTS := {
	CHAR: {12: ["ana", 3], 15: ["bataklik", 3], 14: ["col", 3], 11: ["batik_nekropol", 3], 13: ["lagim_agi", 3]},
	PET: {"peri": ["ana", 1], "slime": ["bataklik", 1], "kirpi": ["col", 1], "hayalet": ["batik_nekropol", 1], "kelebek": ["lagim_agi", 1]},
}
const KEY_MAPS := ["ana", "bataklik", "col", "batik_nekropol", "lagim_agi"] ## key_icon.gd IDS ile aynı
const KEY_CAP := 999 ## bir türün saklanabilecek en çok adedi (bozuk dosya / taşma koruması)
const KeyIcon := preload("res://scripts/key_icon.gd") ## yalnız görünen ad için (hafif: map_profiles'e tembel erişir)

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


static func set_content_open(v: bool) -> void:
	content_open = v


static func _path() -> String:
	if path_override != "":
		return path_override
	var env: String = GuardScript.dev_env(ENV_PATH) ## exportta "" (kayıt yolu değiştirilemez)
	return env if env != "" else DEFAULT_PATH


static func _all_unlocked() -> bool:
	return unlock_all_override or debug_open or content_open or GuardScript.dev_env(ENV_UNLOCK_ALL) == "1"


static func _defaults() -> Dictionary:
	## upgrades: geliştirme id -> seviye; upgrade_spent: geliştirme id -> o geliştirmeye harcanan toplam (sıfırlamada TAM bu kadar iade edilir,
	## fiyatlar sonradan ayarlansa bile haksızlık olmasın). Mantık meta_upgrades.gd'de.
	## keys: harita kimliği -> anahtar adedi (madde 605; eski kayıtta bölüm yok = hepsi 0).
	return {"shards": 0, "total_earned": 0, "unlocked": {CHAR: [], WEAPON: [], PET: [], SPIRIT: []}, "upgrades": {}, "upgrade_spent": {}, "keys": {}}


## Tüm kayıt (dosya yoksa/bozuksa sıfır: herkes baştan başlar).
static func load_all() -> Dictionary:
	var p: String = _path()
	_reset_once_if_default(p)
	if p == _cache_path and not _cache.is_empty():
		return _cache.duplicate(true)
	var data: Dictionary = _defaults()
	var real_file: bool = p == DEFAULT_PATH ## yalnız oyuncunun gerçek dosyası: .bak/.bozuk yan dosyaları + eski düz kaydı mühürlü yeniden yazma
	var res: Dictionary = SecureCfgScript.load_cfg(p, "meta", real_file)
	var status: int = int(res["status"])
	var cfg: ConfigFile = res["cfg"]
	var loaded_ok: bool = status == SecureCfgScript.Status.OK or status == SecureCfgScript.Status.LEGACY
	if loaded_ok:
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
		if cfg.has_section("keys"):
			for k: String in cfg.get_section_keys("keys"):
				if KEY_MAPS.has(k): ## bilinmeyen tür (elle bozulmuş / kaldırılmış harita) okunmaz, sonraki kayıtta düşer
					(data["keys"] as Dictionary)[k] = clampi(int(cfg.get_value("keys", k, 0)), 0, KEY_CAP)
		## Bakiye kazanılandan fazla olamaz (başlangıç hediyesi yok; iade/harcama toplamı aşmaz): şişirilmiş bakiye kırpılır.
		## Yalnız exportta (testler elle bakiye yazar: _give_shards).
		if not GuardScript.dev_allowed() and int(data["shards"]) > int(data["total_earned"]):
			GuardScript.report("kıymık bakiyesi kazanımı aşıyor (%d > %d)" % [int(data["shards"]), int(data["total_earned"])], false)
			data["shards"] = int(data["total_earned"])
	_cache = data
	_cache_path = p
	## Eski düz kayıt ya da .bak'tan dönülen kayıt: mühürlü olarak hemen yeniden yaz (taşıma / onarım).
	if real_file and loaded_ok and (status == SecureCfgScript.Status.LEGACY or bool(res.get("restored", false))):
		_save(data)
	return data.duplicate(true)


## Tek seferlik sıfırlama (progress_reset.gd): yalnız varsayılan yoldayken (testler / ortam değişkeni yolu etkilenmez).
static func _reset_once_if_default(p: String) -> void:
	if p == DEFAULT_PATH and ProgressResetScript.ensure("meta", DEFAULT_PATH):
		_cache.clear()


static func _save(data: Dictionary) -> void:
	_reset_once_if_default(_path())
	if GuardScript.tampered:
		return ## hile belirtisi görülen oturum kalıcı ilerleme yazmaz (security_guard.gd); bellek önbelleği de değişmez
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", int(data["shards"]))
	cfg.set_value("meta", "total_earned", int(data["total_earned"]))
	for kind: String in KINDS:
		cfg.set_value("unlocked", kind, (data["unlocked"] as Dictionary)[kind])
	for sec: String in ["upgrades", "upgrade_spent"]:
		for k: String in (data[sec] as Dictionary).keys():
			if int((data[sec] as Dictionary)[k]) > 0:
				cfg.set_value(sec, k, int((data[sec] as Dictionary)[k]))
	## TUZAK: _save yalnız bildiği bölümleri yazar - "keys" burada olmazsa ilk kayıtta anahtarlar SİLİNİRdi (madde 605).
	for k: String in (data.get("keys", {}) as Dictionary).keys():
		if int((data["keys"] as Dictionary)[k]) > 0:
			cfg.set_value("keys", k, int((data["keys"] as Dictionary)[k]))
	SecureCfgScript.save_cfg(cfg, _path(), "meta", _path() == DEFAULT_PATH)
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


## Anahtar da isteyen içerik için {"map": harita kimliği, "count": adet}; yalnız kıymıkla alınan içerik için {} (madde 605).
static func key_cost(kind: String, key: Variant) -> Dictionary:
	var row: Variant = (KEY_COSTS.get(kind, {}) as Dictionary).get(key, null)
	if row == null:
		return {}
	return {"map": str((row as Array)[0]), "count": int((row as Array)[1])}


## Kıymık VE (varsa) anahtar yeterli mi? (Açık olan zaten alınamaz.)
static func can_afford(kind: String, key: Variant) -> bool:
	if shards() < cost(kind, key):
		return false
	var kc: Dictionary = key_cost(kind, key)
	return kc.is_empty() or keys(str(kc["map"])) >= int(kc["count"])


static func can_buy(kind: String, key: Variant) -> bool:
	return not is_unlocked(kind, key) and can_afford(kind, key)


## Satın alır: yeterli bakiye (+ varsa anahtar) + henüz açık değilse true. Kıymık ve anahtar BİRLİKTE düşer.
static func buy(kind: String, key: Variant) -> bool:
	if is_unlocked(kind, key) or not (COSTS.get(kind, {}) as Dictionary).has(key):
		return false
	var data: Dictionary = load_all()
	var price: int = cost(kind, key)
	if int(data["shards"]) < price:
		return false
	var kc: Dictionary = key_cost(kind, key)
	if not kc.is_empty():
		var have: int = int((data["keys"] as Dictionary).get(str(kc["map"]), 0))
		if have < int(kc["count"]):
			return false
		(data["keys"] as Dictionary)[str(kc["map"])] = have - int(kc["count"])
	data["shards"] = int(data["shards"]) - price
	((data["unlocked"] as Dictionary)[kind] as Array).append(key)
	_save(data)
	return true


## Kilitliyse kısa açıklama (kart/ipucu): "Kilitli - 250 Ruh Kıymığı (Ruh Mağazası)"; anahtarlıysa
## "Kilitli - 450 Ruh Kıymığı + 3 Bataklık Anahtarı (Ruh Mağazası)".
static func lock_text(kind: String, key: Variant) -> String:
	var kc: Dictionary = key_cost(kind, key)
	if kc.is_empty():
		return Loc.t("Kilitli - %d %s (Ruh Mağazası)") % [cost(kind, key), CURRENCY_NAME]
	return Loc.t("Kilitli - %d %s + %d %s (Ruh Mağazası)") % [cost(kind, key), CURRENCY_NAME, int(kc["count"]), KeyIcon.display_name(str(kc["map"]))]


## Kilitli öğeleri ucuzdan pahalıya: [{"kind", "key", "cost", "key_map", "key_count"}] (mağaza listesi için; tür sırası KINDS).
## key_map "" = anahtar istemez.
static func locked_items() -> Array:
	var out: Array = []
	for kind: String in KINDS:
		var ids: Array = (COSTS[kind] as Dictionary).keys()
		ids.sort_custom(func(a: Variant, b: Variant) -> bool:
			return cost(kind, a) < cost(kind, b) or (cost(kind, a) == cost(kind, b) and str(a) < str(b)))
		for k in ids:
			var kc: Dictionary = key_cost(kind, k)
			out.append({"kind": kind, "key": k, "cost": cost(kind, k),
					"key_map": str(kc.get("map", "")), "key_count": int(kc.get("count", 0))})
	return out


## ---------------------------------------------------------------- ANAHTAR KAYDI (madde 605)
## Bir harita anahtarından elde kaç tane var.
static func keys(map_id: String) -> int:
	return int((load_all()["keys"] as Dictionary).get(map_id, 0))


## Anahtar ekler (anında diske yazılır: bağlantı kopsa / oyun çökse kaybolmaz). Bilinmeyen tür / n <= 0 yok sayılır. Yeni adedi döner.
static func grant_keys(map_id: String, n: int) -> int:
	if n <= 0 or not KEY_MAPS.has(map_id):
		return keys(map_id)
	var data: Dictionary = load_all()
	var now: int = mini(KEY_CAP, int((data["keys"] as Dictionary).get(map_id, 0)) + n)
	(data["keys"] as Dictionary)[map_id] = now
	_save(data)
	return now


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
