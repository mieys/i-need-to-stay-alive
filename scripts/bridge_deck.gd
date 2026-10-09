extends RefCounted

## KÖPRÜ KATI (2026-10-09, kullanıcı: "şurda şöyle bir köprü var buranın altından geçen insanların üstünde köprü görünmeli. ayrıca soldaki dağdan
## insanlar bu köprüden geçebilmeli"). Haritadaki vadiyi aşan köprü (Köprü/Köprü alt + üst, x 43-65, y 120-121) bir İKİ KATLI geçit: vadinin zemininde
## yürüyen biri köprünün ALTINDAN geçer (köprü onu örter), köprüye ucundan çıkan biri güvertede yürür (köprünün ÜSTÜNDE görünür). İki durum aynı
## ekran konumunda üst üste bindiği için konumdan ayırt edilemez: karakterin köprü dikdörtgenine HANGİ KENARDAN girdiği izlenir -
##   - uçtan (köprünün uzun ekseninin iki ucundan: sol/sağ yamaç) girdi -> GÜVERTEDE,
##   - yandan (kuzey/güney: vadi zemininden) girdi -> ALTINDA (zemin katı).
## Dikdörtgenden çıkınca durum sıfırlanır; içeride aynen kalır; içeride belirmek (ışınlanma/doğuş) = zemin katı. Çizim: depth_occluders.gd köprü kopyasını
## SADECE zemin katındaki karakterlere gönderir (kopya z 3'te, kökü karakterin ayağından aşağıdaysa o karakteri örter - bina/ağaçla aynı kural);
## güvertedeki karakter kopyaya verilmez, normal z 1'de köprünün üstünde kalır. Saf mantık: sahneye dokunmaz (testli).


## Hücre listesinden (dünya hücre koordinatı -> sol-üst dünya px) 8-komşu bağlı bileşenlerin dünya dikdörtgenleri.
static func component_rects(cell_origin_px: Dictionary, cell_px: float = 16.0) -> Array[Rect2]:
	var seen: Dictionary = {}
	var out: Array[Rect2] = []
	for start: Vector2i in cell_origin_px:
		if seen.has(start):
			continue
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			var p: Vector2 = cell_origin_px[c]
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x + cell_px), maxf(hi.y, p.y + cell_px))
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var n := Vector2i(c.x + dx, c.y + dy)
					if (dx != 0 or dy != 0) and cell_origin_px.has(n) and not seen.has(n):
						seen[n] = true
						stack.append(n)
		out.append(Rect2(lo, hi - lo))
	return out


## `prev` (dikdörtgenin DIŞINDAKİ önceki ayak noktası) dikdörtgene uçtan mı (uzun eksenin iki ucu) girdi? true = güverteye çıktı, false = yandan (altından).
static func entered_from_end(prev: Vector2, rect: Rect2) -> bool:
	var end_over: float
	var side_over: float
	if rect.size.x >= rect.size.y:
		end_over = maxf(rect.position.x - prev.x, prev.x - rect.end.x)
		side_over = maxf(rect.position.y - prev.y, prev.y - rect.end.y)
	else:
		end_over = maxf(rect.position.y - prev.y, prev.y - rect.end.y)
		side_over = maxf(rect.position.x - prev.x, prev.x - rect.end.x)
	return end_over > 0.0 and end_over >= side_over


## Bir karakterin durumunu bir adım ilerletir. state: {"idx": hangi köprü dikdörtgeni (-1 = hiçbiri), "deck": güvertede mi, "prev": önceki ayak}.
## İlk çağrıda state = {} ver. Dönüş: yeni durum (state'e dokunulmaz).
static func step_state(state: Dictionary, feet: Vector2, rects: Array) -> Dictionary:
	var idx: int = -1
	for i in range(rects.size()):
		if (rects[i] as Rect2).has_point(feet):
			idx = i
			break
	var deck: bool = bool(state.get("deck", false))
	var was: int = int(state.get("idx", -1))
	if idx < 0:
		deck = false
	elif idx != was:
		## Yeni girdi: önceki nokta biliniyorsa kenara bak; bilinmiyorsa (ilk görülen, ışınlanma) zemin katı.
		deck = state.has("prev") and entered_from_end(state["prev"], rects[idx])
	return {"idx": idx, "deck": deck, "prev": feet}
