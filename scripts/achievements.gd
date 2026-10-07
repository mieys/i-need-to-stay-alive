extends RefCounted

## YEREL BAŞARIMLAR (kullanıcı isteği 2026-10-05, öneri 3: "koşu sonu istatistik + rekor + başarım").
## Bilerek yerel: Epic'in HAchievements eklentisi proje autoload'unda duruyor ama başarımlar Epic geliştirici portalında
## ayrıca tanımlanmadan çalışmaz; burada hepsi tek tablo, değerlendirme saf fonksiyon (disk yok -> birim testi kolay).
##
## Her başarım "ctx[key] >= min" - tek kural, yeni başarım eklemek = tabloya bir satır. ctx'i run_records.gd kurar:
##   tier / time (sn) / kills / layer       -> BU koşunun değerleri
##   victory / victory_solo / victory_coop  -> bu koşu zaferle mi bitti (0/1)
##   victory_chars                          -> zafer kazanılan FARKLI karakter sayısı (kalıcı)
##   runs_total / total_kills               -> tüm koşuların toplamı (kalıcı)

const DEFS: Array[Dictionary] = [
	{"id": "tier_5", "name": "Ayakta Kal", "desc": "V. Kademe'ye ulaş.", "key": "tier", "min": 5},
	{"id": "tier_10", "name": "Kıdemli Avcı", "desc": "X. Kademe'ye ulaş.", "key": "tier", "min": 10},
	{"id": "tier_15", "name": "Son Perde", "desc": "XV. Kademe'ye ulaş.", "key": "tier", "min": 15},
	{"id": "final", "name": "Final Karşılaşması", "desc": "Final Kademesi'ne ulaş.", "key": "tier", "min": 16},
	{"id": "victory", "name": "Hayatta Kaldım!", "desc": "Final'in tüm bosslarını yenip zafer kazan.", "key": "victory", "min": 1},
	{"id": "victory_solo", "name": "Yalnız Kurt", "desc": "Tek oyunculu zafer kazan.", "key": "victory_solo", "min": 1},
	{"id": "victory_coop", "name": "Takım Ruhu", "desc": "Çok oyunculu zafer kazan.", "key": "victory_coop", "min": 1},
	{"id": "victory_heroes_3", "name": "Çok Yönlü", "desc": "3 farklı karakterle zafer kazan.", "key": "victory_chars", "min": 3},
	{"id": "layer_3", "name": "Bitmeyen Gece", "desc": "Sonsuz Kat 3'e ulaş.", "key": "layer", "min": 3},
	{"id": "layer_10", "name": "Sonsuzluğun Kıyısı", "desc": "Sonsuz Kat 10'a ulaş.", "key": "layer", "min": 10},
	{"id": "layer_25", "name": "Kıyamet Sonrası", "desc": "Sonsuz Kat 25'e ulaş.", "key": "layer", "min": 25},
	{"id": "kills_500", "name": "Avcı", "desc": "Tek koşuda 500 yaratık öldür.", "key": "kills", "min": 500},
	{"id": "kills_3000", "name": "Biçerdöver", "desc": "Tek koşuda 3000 yaratık öldür.", "key": "kills", "min": 3000},
	{"id": "time_15", "name": "Dayanıklı", "desc": "Bir koşuda 15 dakika hayatta kal.", "key": "time", "min": 900},
	{"id": "time_30", "name": "Maraton", "desc": "Bir koşuda 30 dakika hayatta kal.", "key": "time", "min": 1800},
	{"id": "total_kills_10000", "name": "Efsane Avcı", "desc": "Toplamda 10.000 yaratık öldür.", "key": "total_kills", "min": 10000},
	{"id": "runs_10", "name": "Azimli", "desc": "10 koşu tamamla.", "key": "runs_total", "min": 10},
]


## `ctx`i sağlayan ve `already`de (id -> zaman damgası) olmayan başarımların id'leri, tablo sırasıyla.
static func evaluate(ctx: Dictionary, already: Dictionary) -> Array:
	var out: Array = []
	for d: Dictionary in DEFS:
		var id: String = str(d["id"])
		if already.has(id):
			continue
		if float(ctx.get(str(d["key"]), 0.0)) >= float(d["min"]):
			out.append(id)
	return out


static func def_of(id: String) -> Dictionary:
	for d: Dictionary in DEFS:
		if str(d["id"]) == id:
			return d
	return {}


static func name_of(id: String) -> String:
	return str(def_of(id).get("name", id))
