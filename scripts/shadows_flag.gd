extends RefCounted

## ÇEVRE GÖLGELERİ KAPALI - kullanıcı isteği (2026-11-08, madde 484): gölge açık/kapalı örneklerini (madde 468) gördükten sonra "gölgeleri kapat";
## ilk uygulamada karakter/obje gölgeleri de kapanmıştı, kullanıcı: "karakter yaratık v.s gölgelerini kaldırmanı istememiştim" -> `entities` geri açık.
## Kapalı olan yalnız harita (ağaç/bina/uçurum) + bulut gölgesi.
## TEK yer; geri açmak = ilgili satırı true yap (başka değişiklik gerekmez, pişmiş doku yerinde duruyor).
##   map      : pişmiş harita gölgeleri (ağaç/bina/uçurum, `map_shadows.gd attach` düğüm kurmaz)
##   clouds   : bulut gölgesi (`sun_clouds.gd`; güneş huzmesi de kapalıyken Ayarlar > Grafik "Güneş Işığı / Bulut Gölgesi" satırı gizlenir)
##   entities : karakter/evcil ayak gölgesi + yerdeki efsun nesneleri (`PixelDraw.ground_shadow`), yerdeki obje gölgesi (`drop_shadow.gd`
##              sandık/altın/yemek/mıknatıs/kalkan orbu), silah gölgesi (`shadow_blob.gd`, yerel + kukla)
## KAPANMAYANLAR: yaratık gölgeleri sprite sayfalarına çizili (yalnız With_shadow sayfaları var); yetenek/boss iniş-düşüş uyarı gölgeleri
## (Korsan güllesi vb. kendi çizimleri) oyun bilgisi taşıdığı için bu bayrağa bağlı değil.
## Bu dosya autoload kullanmaz (`-s` araçları da ön yükleyebilir). Sabit olarak ön yüklenen betikten yazmak ayrıştırıcı hatası verir: set_all.
static var map: bool = false
static var clouds: bool = false
static var entities: bool = true ## karakter/evcil/obje/silah gölgeleri AÇIK (madde 484)


static func set_all(value: bool) -> void:
	map = value
	clouds = value
	entities = value
