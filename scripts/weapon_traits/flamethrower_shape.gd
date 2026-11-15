extends RefCounted

## OTOMATİK ÜRETİLDİ: tools/gen_flamethrower_fx.py (elle düzenleme - üreteci çalıştır). Madde 639.
## Ateş Asası alevinin (kullanıcının "Flamethrower Left_Right" efekti) HASAR ALANI = çizilen alevin şekli.
## Birimler SANAT pikseli, ağız (0,0), alev +x yönüne; y aşağı + (sayfadaki gibi: ateş bulutu YUKARI kabarır, y < 0).
## Sola bakarken sayfa dikey aynalanır (fx_enchant_sprite "flip_left") -> hasar alanında y işareti de döner.

const LENGTH := 177.0 ## döngü karelerinde alevin medyan boyu
const STEP := 4.0 ## PROFILE örnek aralığı
## Her STEP px dilimin [üst, alt] sınırı (döngü karelerinin medyanı)
const PROFILE := [Vector2(0.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, 0.0), Vector2(-1.0, 0.0), Vector2(-1.0, 0.0), Vector2(-1.0, 0.0), Vector2(-1.0, 0.0), Vector2(-1.0, 0.0), Vector2(-1.0, 0.0), Vector2(-2.0, 0.0), Vector2(-2.0, 0.0), Vector2(-2.0, 1.0), Vector2(-2.0, 1.0), Vector2(-2.0, 1.0), Vector2(-2.0, 1.0), Vector2(-3.0, 1.0), Vector2(-3.0, 1.0), Vector2(-3.0, 1.0), Vector2(-4.0, 2.0), Vector2(-5.0, 4.0), Vector2(-6.0, 4.0), Vector2(-6.0, 4.5), Vector2(-6.0, 4.0), Vector2(-6.0, 3.5), Vector2(-6.0, 4.0), Vector2(-6.0, 4.5), Vector2(-6.0, 4.5), Vector2(-5.0, 4.0), Vector2(-6.5, 4.0), Vector2(-7.5, 4.0), Vector2(-8.5, 4.0), Vector2(-10.0, 5.0), Vector2(-10.5, 5.5), Vector2(-13.0, 5.0), Vector2(-15.5, 4.0), Vector2(-17.0, 3.0), Vector2(-16.5, 2.5), Vector2(-26.5, 3.0), Vector2(-26.5, 3.0), Vector2(-28.0, 2.0), Vector2(-28.5, 1.5), Vector2(-27.5, 0.0), Vector2(-27.5, 0.0), Vector2(-28.5, -2.0), Vector2(-24.0, -7.0)]
## "start" animasyonunun her karesinde alevin ulaştığı boy (alan alevle birlikte uzar)
const INTRO_REACH := [21.0, 64.0, 86.0, 115.0, 142.0, 165.0]
const FPS := 16.6667
const SHEET_OFFSET := Vector2(91.5, -17.0) ## ortalı sprite ofseti: ağız düğüm noktasında


## Alevin ağızdan x uzaklığındaki [üst, alt] sınırı (sanat px; x alan dışındaysa boş aralık).
static func band_at(x: float) -> Vector2:
	if x < 0.0 or x > LENGTH:
		return Vector2(1.0, -1.0)
	var i: int = clampi(int(x / STEP), 0, PROFILE.size() - 1)
	return PROFILE[i]


## Başlangıç animasyonunda geçen süreye göre alevin ulaştığı boy (sanat px).
static func reach_at(t: float) -> float:
	var i: int = int(t * FPS)
	if i >= INTRO_REACH.size():
		return LENGTH
	return minf(LENGTH, float(INTRO_REACH[maxi(0, i)]))
