extends RefCounted

## POMPALI TÜFEK saçma düzeni (madde 448) - kaster (weapon_traits/dip_atis.gd) ve testler AYNI hesabı kullanır.
## Salvo = `count` saçma, koninin içine eşit aralıkla dizilir. Asıl atış (weapon.gd _fire_at) zaten hedefe doğrudur ve koninin
## ortasındaki saçmadır: extra_angles() ona en yakın açıyı atar, kalanı döndürür. Dip Atış mesafeye göre kendiliğinden çıkar:
## koni uzakta genişler (açı sabit, sapma = mesafe x tan(açı)), saçmaların çoğu hedefi ıskalar; dibinde hepsi vurur.

const CONE_DEG := 14.0 ## toplam koni açısı (her yana 7°)
## Saçmalar ortaya yoğun dizilir (eşit aralık yerine t -> |t|^WARP): uç saçmalar koninin kenarında, iç saçmalar merkeze yakın ->
## orta mesafede de 4 saçma isabet eder (kullanıcı 2026-11-07: "çok az vuruyor").
const WARP := 1.5
const JITTER_DEG := 0.8 ## saçma başına küçük rastgele sapma (düzen "cetvel gibi" görünmesin)


## Koninin içindeki TÜM saçmaların asıl atıştan sapması (radyan, artan sırada).
static func angles(count: int, cone_deg: float) -> Array:
	var out: Array = []
	if count <= 1:
		out.append(0.0)
		return out
	var half: float = deg_to_rad(cone_deg) * 0.5
	for i in count:
		var t: float = lerpf(-1.0, 1.0, float(i) / float(count - 1))
		out.append(signf(t) * pow(absf(t), WARP) * half)
	return out


## Asıl atış dışındaki saçmalar: angles()'tan 0'a en yakın açı (asıl atış) çıkarılır, kalanlara +-jitter_deg sapma eklenir.
static func extra_angles(count: int, cone_deg: float, jitter_deg: float = 0.0) -> Array:
	var all: Array = angles(count, cone_deg)
	if all.size() <= 1:
		return []
	var best: int = 0
	for i in all.size():
		if absf(float(all[i])) < absf(float(all[best])):
			best = i
	all.remove_at(best)
	if jitter_deg > 0.0:
		var j: float = deg_to_rad(jitter_deg)
		for i in all.size():
			all[i] = float(all[i]) + randf_range(-j, j)
	return all


## Hedefin `radius` yarıçaplı gövdesine `dist` mesafeden kaç saçma (asıl atış dahil) isabet eder? (denge ölçümü + test)
static func pellets_on_target(count: int, cone_deg: float, dist: float, radius: float) -> int:
	var hits: int = 0
	for a in angles(count, cone_deg):
		if absf(dist * tan(float(a))) <= radius:
			hits += 1
	return hits
