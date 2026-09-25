extends RefCounted

## Gün-gece döngüsü + hava durumunun SAF (durumsuz) matematiği. Kullanıcı isteği (2026-09-25): "hava durumu ve
## gündüz-gece-gün doğumu-gün batımına uyumlu renklere sahip doğal gündönümü sistemi ... gece olunca görüş açısı %25
## azalacak (hava kararmaya doğru kademeli şekilde yavaş yavaş karanlık ve daha dar görüş açısı olacak)".
##
## NEDEN AYRI, static bir dosya (weapon_orbit_math.gd ile AYNI gerekçe, bkz. CLAUDE.md madde 3): saat ve hava durumu
## host'tan gelir ama karanlık/renk/görüş formülü HER istemcide yerel hesaplanır - formül tek yerde olmalı ki host ile
## istemciler asla farklı karanlık/görüş görmesin. atmosphere.gd (durum + ağ), atmosphere_overlay.gd (çizim),
## vision_fog.gd (görüş yarıçapı) ve testler HEPSİ buradan okur.

## Kullanıcı seçimi (2026-09-25 soru-cevap): 10 dakikalık tam gün (~25-30 dk'lık bir koşuda 2-3 gece).
const CYCLE_LENGTH := 600.0
## Evre sınırları (döngü saniyesi): gündüz 0-330 (5.5 dk), gün batımı 330-390 (1 dk), gece 390-540 (2.5 dk),
## gün doğumu 540-600 (1 dk). 600 = 0 (döngü kapanır).
const DAY_END := 330.0
const DUSK_END := 390.0
const NIGHT_END := 540.0
## Koşu sabah başlar (gün doğumu yeni bitmiş, serin sabah ışığı ~1 dk içinde tam gündüze döner).
const START_TIME := 15.0
## "Kademeli" kararma: gün batımından bu kadar saniye önce (ikindi) çok hafif başlar (altın saat).
const AFTERNOON_LEAD := 50.0
const AFTERNOON_DARKNESS := 0.12
## Gece görüş yarıçapı çarpanı (kullanıcı: "%25 azalacak" -> görüş elipsinin yarıçapı x0.75). Karanlıkla (darkness)
## orantılı: ikindi hafifçe, gün batımında kademeli daralır, gün doğumunda aynı yavaşlıkla geri açılır.
const NIGHT_VISION_MULT := 0.75

## Zaman renk anahtarları: [döngü saniyesi, ortam çarpanı (sahne rengi kanal kanal bununla çarpılır), doygunluk,
## kaldırma (karanlık bölgelere eklenen hafif renk - gece siyahlar zifiri olmasın, lacivert kalsın)].
## İki anahtar arası smoothstep ile karışır. Tam gündüz = (1,1,1)/1/0: oyunun bugünkü görünümüne HİÇ dokunulmaz.
## NOT (kullanıcı geri bildirimi, bkz. vision_fog.gd): görünmeyen yer asla zifiri olmamalı - gece yarısı ortamı ham
## anahtarda ~%41, DARKNESS_SCALE (x0.8 karartma) sonrası ~%54 parlaklıkta; üstüne sisin kendi koyulaşması biniyor.
const TIME_KEYS: Array = [
	## 2026-09-25: "gün batımı/doğumunda renk ayarı aşırı kızıllaşıyor, göz yoruyor" - sabah/ikindi/gün batımı/gün doğumu
	## anahtarlarının kırmızı-turuncu kayması ve kızıl kaldırma (lift) yaklaşık yarıya indirildi (ton aynı, daha hafif).
	[0.0, Color(0.97, 0.955, 0.975), 0.98, Color(0.012, 0.008, 0.018)], ## sabah serinliği (gün doğumunun son pembe izi)
	[70.0, Color(1.0, 1.0, 1.0), 1.0, Color(0.0, 0.0, 0.0)], ## tam gündüz
	[280.0, Color(1.0, 1.0, 1.0), 1.0, Color(0.0, 0.0, 0.0)],
	[330.0, Color(1.0, 0.94, 0.86), 1.03, Color(0.015, 0.006, 0.0)], ## altın saat (ikindi)
	[360.0, Color(0.95, 0.8, 0.72), 0.95, Color(0.028, 0.01, 0.022)], ## gün batımı: turuncu-pembe
	[390.0, Color(0.45, 0.45, 0.67), 0.72, Color(0.012, 0.01, 0.04)], ## alacakaranlık -> gece mavisi
	[465.0, Color(0.37, 0.41, 0.63), 0.64, Color(0.0, 0.012, 0.042)], ## gece yarısı
	[540.0, Color(0.41, 0.43, 0.65), 0.68, Color(0.01, 0.01, 0.045)], ## şafak öncesi
	[570.0, Color(0.9, 0.8, 0.82), 0.92, Color(0.028, 0.012, 0.026)], ## gün doğumu: pembe-şeftali
	[600.0, Color(0.97, 0.955, 0.975), 0.98, Color(0.012, 0.008, 0.018)], ## = ilk anahtar (döngü kapanır)
]

## Hava durumu. Kullanıcı seçimi (2026-09-25): "Dengeli" - %50 açık, %25 rüzgarlı, %25 yağmurlu; her hava 1.5-3 dk
## sürer, 8-10 sn'lik yumuşak geçişle başlar/biter. Fırtına (yağmur+rüzgar birlikte) seçilmedi.
## SAĞANAK (kullanıcı isteği 2026-09-25: "yeni hava durumu: sağanak yağış, bu esnada hem fırtına hem yağmur aynı anda
## olacak gibi görünmeli ve rasgele aralıklarla rasgele konumlara yıldırım düşmeli") - yağmur VE rüzgar birlikte tam
## şiddette + daha koyu gökyüzü + yıldırım (bkz. weather_storm.gd). Sıklık Claude'un seçimi: eski 50/25/25'ten orantılı
## pay alındı -> %45 açık / %20 rüzgarlı / %20 yağmurlu / %15 sağanak.
enum Weather { CLEAR, WINDY, RAINY, STORM }
const WEATHER_NAMES := ["Açık", "Rüzgarlı", "Yağmurlu", "Sağanak"]
const WEATHER_WEIGHTS := [45.0, 20.0, 20.0, 15.0]
const WEATHER_MIN_DURATION := 90.0
const WEATHER_MAX_DURATION := 180.0
const WEATHER_FADE_TIME := 9.0
## Yağmurlu hava: kapalı, gri-mavi, daha soluk bir gökyüzü. Rüzgarlı: neredeyse aynı, çok hafif serin/berrak.
const RAIN_AMBIENT := Color(0.78, 0.82, 0.9)
const RAIN_SATURATION := 0.78
const RAIN_LIFT := Color(0.012, 0.016, 0.024)
const WIND_AMBIENT := Color(0.98, 1.0, 1.03)
const WIND_SATURATION := 0.97
## Sağanak: yağmurun ÜSTÜNE ek kararma (kara bulutlar) - gündüz bile kasvetli ama oyun alanı okunur kalsın.
const STORM_AMBIENT := Color(0.8, 0.82, 0.9)
const STORM_SATURATION := 0.85
const STORM_LIFT := Color(0.006, 0.008, 0.02)
## Yıldırım flaşı (0..1, weather_storm.gd yürütür): ortam ışığı bu renge doğru açılır - kısa, soğuk beyaz bir parlama.
const FLASH_AMBIENT := Color(1.3, 1.32, 1.45)
const FLASH_LIFT := Color(0.05, 0.055, 0.08)

## Hava türünün yağmur/rüzgar/sağanak hedef şiddetleri (atmosphere.gd bunlara doğru yumuşakça ilerler).
static func weather_targets(w: int) -> Vector3:
	match w:
		Weather.WINDY:
			return Vector3(0.0, 1.0, 0.0)
		Weather.RAINY:
			return Vector3(1.0, 0.0, 0.0)
		Weather.STORM:
			return Vector3(1.0, 1.0, 1.0)
	return Vector3.ZERO

## Kullanıcı geri bildirimi (2026-09-25, ilk oynanış: "gece aşırı karanlık oluyor ve parıltılar biraz fazla oluyor, gecenin
## karanlığını %20 azaltıp parıltıları da %20 azalt"): zaman anahtarlarının KARARTMASI (1 - ortam, kanal kanal) ve
## renksizleştirmesi (1 - doygunluk) bu oranla ölçeklenir - renk tonu (gece mavisi, gün batımı turuncusu) korunur, sadece
## daha az karanlık. Işık/parıltı gücü (LIGHT_GAIN_SCALE, GLOW_GAIN_MAX) aynı turda x0.8.
## 2026-09-25 ikinci tur: "gecenin karanlığını biraz azalt, azcık daha aydınlık olsun" - 0.8 -> 0.68 (karartma ~%15 daha az).
const DARKNESS_SCALE := 0.68
## Işıkların (karakter etrafı, yetenek/silah parıltıları) karanlığı ne kadar kaldırdığı: HAM (DARKNESS_SCALE öncesi)
## ortam parlaklığı düştükçe artar - gündüz 0 (ışıklar görünmez), yağmurlu gündüz hafif, gece ~1. Ham değerden
## hesaplanıyor ki gece aydınlanınca ışıklar KENDİLİĞİNDEN de sönükleşmesin - "%20 azalt" tam olarak LIGHT_STRENGTH.
const LIGHT_GAIN_SCALE := 1.7
const LIGHT_STRENGTH := 0.8
## Parıltı (ışığın eşik üstü çekirdeğine eklenen renkli "bloom", bkz. atmosphere_grade.gdshader bloom_threshold) gücü.
## Eşikli/normalize formülde ilk sürümün (L^2 x 0.32) güçlü çekirdeklerdeki parlaklığının ~%80'ine denk gelir.
## 2026-09-25: "tüm parıltı efektlerinin gücünü %30 azalt" - 1.1 -> 0.77 (x0.7), bkz. atmosphere_overlay.gd GLOW_ENERGY_SCALE.
## 2026-09-25 ikinci tur ("hala çok kamaştırıcı"): 0.77 -> 0.5 - parlama (bloom) çekirdeği daha sönük.
const GLOW_GAIN_MAX := 0.5


static func wrap_time(t: float) -> float:
	return fposmod(t, CYCLE_LENGTH)


## 0 = tam gündüz, 1 = tam gece. İkindi hafif başlar, gün batımında kademeli artar, gün doğumunda kademeli söner.
static func darkness(t: float) -> float:
	t = wrap_time(t)
	if t < DAY_END - AFTERNOON_LEAD:
		return 0.0
	if t < DAY_END:
		return AFTERNOON_DARKNESS * smoothstep(DAY_END - AFTERNOON_LEAD, DAY_END, t)
	if t < DUSK_END:
		return lerpf(AFTERNOON_DARKNESS, 1.0, smoothstep(DAY_END, DUSK_END, t))
	if t < NIGHT_END:
		return 1.0
	return 1.0 - smoothstep(NIGHT_END, CYCLE_LENGTH, t)


## Görüş elipsinin yarıçap çarpanı (1.0 gündüz -> 0.75 gece), bkz. vision_fog.gd.
static func vision_multiplier(t: float) -> float:
	return lerpf(1.0, NIGHT_VISION_MULT, darkness(t))


## Debug menüsü/test için evre adı.
static func phase_name(t: float) -> String:
	t = wrap_time(t)
	if t < DAY_END:
		return "Gündüz"
	if t < DUSK_END:
		return "Gün batımı"
	if t < NIGHT_END:
		return "Gece"
	return "Gün doğumu"


## roll [0,1) -> Weather (WEATHER_WEIGHTS ağırlıklı).
static func pick_weather(roll: float) -> int:
	var total: float = 0.0
	for w in WEATHER_WEIGHTS:
		total += float(w)
	var acc: float = 0.0
	for i in range(WEATHER_WEIGHTS.size()):
		acc += float(WEATHER_WEIGHTS[i]) / total
		if roll < acc:
			return i
	return Weather.CLEAR


static func luminance(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## Zaman anahtarlarından HAM [ambient, saturation, lift] (DARKNESS_SCALE uygulanmamış).
static func raw_time_grade(t: float) -> Array:
	t = wrap_time(t)
	for i in range(TIME_KEYS.size() - 1):
		var a: Array = TIME_KEYS[i]
		var b: Array = TIME_KEYS[i + 1]
		if t <= float(b[0]):
			var span: float = maxf(float(b[0]) - float(a[0]), 0.001)
			var k: float = smoothstep(0.0, 1.0, (t - float(a[0])) / span)
			return [(a[1] as Color).lerp(b[1], k), lerpf(float(a[2]), float(b[2]), k), (a[3] as Color).lerp(b[3], k)]
	var last: Array = TIME_KEYS[TIME_KEYS.size() - 1]
	return [last[1], last[2], last[3]]


## Zaman anahtarlarından [ambient, saturation, lift] (DARKNESS_SCALE uygulanmış).
static func time_grade(t: float) -> Array:
	var raw: Array = raw_time_grade(t)
	var amb: Color = raw[0]
	var white := Color(1.0, 1.0, 1.0)
	amb = white - (white - amb) * DARKNESS_SCALE
	var sat: float = float(raw[1])
	if sat < 1.0:
		sat = 1.0 - (1.0 - sat) * DARKNESS_SCALE
	return [Color(amb.r, amb.g, amb.b, 1.0), sat, raw[2]]


## Ekranın son renk ayarı: zaman + hava (yağmur/rüzgar şiddeti 0..1). atmosphere_grade.gdshader'ın uniform'ları.
## storm: sağanak şiddeti (0..1, ek kararma), flash: yıldırım flaşı (0..1).
static func grade(t: float, rain: float, wind: float, storm: float = 0.0, flash: float = 0.0) -> Dictionary:
	var tg: Array = time_grade(t)
	var white := Color(1.0, 1.0, 1.0)
	storm = clampf(storm, 0.0, 1.0)
	flash = clampf(flash, 0.0, 1.0)
	var weather_mul: Color = white.lerp(RAIN_AMBIENT, clampf(rain, 0.0, 1.0)) * white.lerp(WIND_AMBIENT, clampf(wind, 0.0, 1.0)) 			* white.lerp(STORM_AMBIENT, storm)
	var ambient: Color = (tg[0] as Color) * weather_mul
	var saturation: float = float(tg[1]) * lerpf(1.0, RAIN_SATURATION, clampf(rain, 0.0, 1.0)) * lerpf(1.0, WIND_SATURATION, clampf(wind, 0.0, 1.0)) 			* lerpf(1.0, STORM_SATURATION, storm)
	var lift: Color = (tg[2] as Color) + RAIN_LIFT * clampf(rain, 0.0, 1.0) + STORM_LIFT * storm
	if flash > 0.0:
		ambient = ambient.lerp(FLASH_AMBIENT, flash)
		lift = lift + FLASH_LIFT * flash
		saturation = lerpf(saturation, 0.8, flash)
	## Işık gücü HAM karanlıktan (bkz. LIGHT_GAIN_SCALE notu), sonra kullanıcının "%20 azalt"ı (LIGHT_STRENGTH).
	var raw_ambient: Color = (raw_time_grade(t)[0] as Color) * weather_mul
	var light_raw: float = clampf((1.0 - luminance(raw_ambient)) * LIGHT_GAIN_SCALE, 0.0, 1.0)
	return {
		"ambient": Color(ambient.r, ambient.g, ambient.b, 1.0),
		"saturation": saturation,
		"lift": Color(lift.r, lift.g, lift.b, 1.0),
		"light_gain": light_raw * LIGHT_STRENGTH,
		"glow_gain": GLOW_GAIN_MAX * light_raw * LIGHT_STRENGTH,
	}


## Renk ayarı hiçbir şey değiştirmiyor mu (tam gündüz + açık hava)? O zaman ekran geçişi HİÇ çizilmez (sıfır maliyet).
static func is_identity(g: Dictionary) -> bool:
	var a: Color = g["ambient"]
	var l: Color = g["lift"]
	return a.r > 0.997 and a.g > 0.997 and a.b > 0.997 and a.r < 1.003 and a.g < 1.003 and a.b < 1.003 \
			and absf(float(g["saturation"]) - 1.0) < 0.003 and l.r + l.g + l.b < 0.003
