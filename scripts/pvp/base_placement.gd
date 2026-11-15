extends RefCounted

## TAKIM ÜSSÜ YERLEŞİMİ (PvPvE, madde 607; kullanıcı 2026-11-12: "her haritanın birbirinden uzak rasgele noktalarında kamp oluşmasını sağla").
## Saf algoritma (harita sorguları çağırana ait, test edilir):
## 1. Oyun alanı `step` birimlik ızgaraya bölünür; hücre ortası `blocked` (hareket engeli) değilse yürünür.
## 2. Başlangıç noktasından (haritanın doğuşu) yürünür hücreler taşınır: ULAŞILABİLİR küme (kapalı cep / duvar ardı / dış çerçeve elenir).
## 3. Kamp için uygun = ulaşılabilir + `unsuitable` değil (su / bina / orman) + kaçınılacak noktalara uzak. Her uygun hücrenin en yakın
##    uygun-olmayan hücreye uzaklığı (8-komşulu, çok kaynaklı yayılım) = boş yarıçap.
## 4. ÖNCE UZAKLIK: boşluk eşiği büyükten küçüğe denenir; her eşikte rastgele aday çiftleri örneklenir. En uzak çift ulaşılabilir alanın
##    köşegeninin SEP_FRACTION'ı kadar uzaksa o eşikte kalınır (en uzak çiftin %85'i kadar uzak olanlardan biri RASTGELE seçilir: her oyunda
##    farklı, hep uzak); değilse eşik düşer (dar zindan: kamp küçülür, team_camp.gd kamp yarıçapı). Hiçbir eşik yetmezse en uzak çift.
##    (2026-11-12 duman: tam kamp eşiğinde zindan haritalarında tek büyük salon kalıyor, üsler 195-517 birim yakın düşüyordu.)

const SAMPLE_PAIRS := 900
const FAR_KEEP := 0.85
## Küçük kamp merkezden ~150 birim yana, ~100 yukarı taşar (kamp_yerlesim.gd KAPSAM); önce tam boşluk aranır, yoksa daralır.
const CLEAR_STEPS: Array[float] = [152.0, 128.0, 104.0, 80.0, 64.0]
## İki üs arası en az: ulaşılabilir alanın sınır kutusu köşegeninin bu oranı.
const SEP_FRACTION := 0.42
## Küçük kampın TAMAMININ sığdığı boşluk (team_camp.gd fits: 128'de bütün parçalar kurulur). Hiçbir eşik uzaklığı tutturamazsa önce bu boşluğu
## sağlayan en uzak çift seçilir; yalnız o da yoksa daha dar (kırpılmış kamp).
const FULL_CAMP_CLEAR := 128.0


## blocked(pos) / unsuitable(pos): Callable(Vector2) -> bool. avoid: [[merkez: Vector2, yarıçap: float], ...].
## Dönüş: {"bases": [üs0, üs1] (dünya), "clear": kampın sığdığı boş yarıçap} ya da bulunamazsa {}.
static func pick(blocked: Callable, unsuitable: Callable, origin: Vector2, play_rect: Rect2, step: float, rng: RandomNumberGenerator,
		avoid: Array = []) -> Dictionary:
	var cols: int = maxi(1, int(play_rect.size.x / step))
	var rows: int = maxi(1, int(play_rect.size.y / step))
	var n: int = cols * rows
	var walk := PackedByteArray()
	walk.resize(n)
	var good := PackedByteArray()
	good.resize(n)
	for r in range(rows):
		for c in range(cols):
			var p: Vector2 = _center(play_rect, step, c, r)
			var i: int = r * cols + c
			if not bool(blocked.call(p)):
				walk[i] = 1
				good[i] = 0 if bool(unsuitable.call(p)) else 1
	## 2. ulaşılabilirlik
	var start: int = _nearest_walk(walk, cols, rows, play_rect, step, origin)
	if start < 0:
		return {}
	var reach := PackedByteArray()
	reach.resize(n)
	var stack: Array[int] = [start]
	reach[start] = 1
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var c: int = i % cols
		var r: int = i / cols
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: int = c + d.x
			var nr: int = r + d.y
			if nc < 0 or nr < 0 or nc >= cols or nr >= rows:
				continue
			var j: int = nr * cols + nc
			if walk[j] == 1 and reach[j] == 0:
				reach[j] = 1
				stack.push_back(j)
	var rmin := Vector2i(cols, rows)
	var rmax := Vector2i(-1, -1)
	for i in range(n):
		if reach[i] == 1:
			rmin = Vector2i(mini(rmin.x, i % cols), mini(rmin.y, i / cols))
			rmax = Vector2i(maxi(rmax.x, i % cols), maxi(rmax.y, i / cols))
	var need_sep: float = Vector2(rmax - rmin).length() * step * SEP_FRACTION
	## 3. uygunluk + boş yarıçap
	var free := PackedByteArray()
	free.resize(n)
	for i in range(n):
		if reach[i] == 1 and good[i] == 1:
			var p: Vector2 = _center(play_rect, step, i % cols, i / cols)
			var ok: bool = true
			for a: Array in avoid:
				if p.distance_to(a[0]) < float(a[1]):
					ok = false
					break
			free[i] = 1 if ok else 0
	var dist: PackedInt32Array = _clearance(free, cols, rows)
	var fallback: Dictionary = {}
	var fallback_d: float = -1.0
	var fallback_full: bool = false
	for need: float in CLEAR_STEPS:
		var cands: Array[int] = []
		var need_cells: int = int(ceil(need / step))
		for i in range(n):
			if free[i] == 1 and dist[i] >= need_cells:
				cands.append(i)
		if cands.size() < 2:
			continue
		var res: Array = _far_pair(cands, cols, play_rect, step, rng)
		if res.is_empty():
			continue
		var best: float = float(res[2])
		var out: Dictionary = {"bases": [res[0], res[1]], "clear": need}
		## Tam küçük kampın sığdığı son eşikte uzaklık şartı %30 gevşer: dar zindanda çadırsız kamp yerine biraz daha yakın ama tam kamp.
		if best >= need_sep or (is_equal_approx(need, FULL_CAMP_CLEAR) and best >= need_sep * 0.7):
			return out
		var full: bool = need >= FULL_CAMP_CLEAR
		if (full and not fallback_full) or (full == fallback_full and best > fallback_d):
			fallback_d = best
			fallback = out
			fallback_full = full
	return fallback


## Rastgele çiftlerden en uzağın %85'i kadar uzak olanlardan biri: [a, b, en_uzak_mesafe] (sıra rastgele) ya da [].
static func _far_pair(cands: Array[int], cols: int, play_rect: Rect2, step: float, rng: RandomNumberGenerator) -> Array:
	var pairs: Array = []
	var best: float = 0.0
	for k in range(SAMPLE_PAIRS):
		var a: int = cands[rng.randi() % cands.size()]
		var b: int = cands[rng.randi() % cands.size()]
		if a == b:
			continue
		var pa: Vector2 = _center(play_rect, step, a % cols, a / cols)
		var pb: Vector2 = _center(play_rect, step, b % cols, b / cols)
		var d: float = pa.distance_to(pb)
		pairs.append([pa, pb, d])
		best = maxf(best, d)
	var far: Array = []
	for pr: Array in pairs:
		if float(pr[2]) >= best * FAR_KEEP:
			far.append(pr)
	if far.is_empty():
		return []
	var pick_pair: Array = far[rng.randi() % far.size()]
	if rng.randf() < 0.5:
		return [pick_pair[0], pick_pair[1], best]
	return [pick_pair[1], pick_pair[0], best]


static func _center(rect: Rect2, step: float, c: int, r: int) -> Vector2:
	return rect.position + Vector2((float(c) + 0.5) * step, (float(r) + 0.5) * step)


static func _nearest_walk(walk: PackedByteArray, cols: int, rows: int, rect: Rect2, step: float, origin: Vector2) -> int:
	var oc: int = clampi(int((origin.x - rect.position.x) / step), 0, cols - 1)
	var orr: int = clampi(int((origin.y - rect.position.y) / step), 0, rows - 1)
	for rad in range(0, maxi(cols, rows)):
		for r in range(orr - rad, orr + rad + 1):
			for c in range(oc - rad, oc + rad + 1):
				if c < 0 or r < 0 or c >= cols or r >= rows:
					continue
				if maxi(absi(c - oc), absi(r - orr)) != rad:
					continue
				if walk[r * cols + c] == 1:
					return r * cols + c
	return -1


## Her serbest hücrenin en yakın serbest-olmayan hücreye (ya da ızgara dışına) 8-komşulu uzaklığı (hücre).
static func _clearance(free: PackedByteArray, cols: int, rows: int) -> PackedInt32Array:
	var n: int = cols * rows
	var dist := PackedInt32Array()
	dist.resize(n)
	var queue: Array[int] = []
	for i in range(n):
		var c: int = i % cols
		var r: int = i / cols
		if free[i] == 0:
			dist[i] = 0
			queue.append(i)
		elif c == 0 or r == 0 or c == cols - 1 or r == rows - 1:
			dist[i] = 1
			queue.append(i)
		else:
			dist[i] = -1
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var c: int = i % cols
		var r: int = i / cols
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				if dr == 0 and dc == 0:
					continue
				var nc: int = c + dc
				var nr: int = r + dr
				if nc < 0 or nr < 0 or nc >= cols or nr >= rows:
					continue
				var j: int = nr * cols + nc
				if dist[j] == -1:
					dist[j] = dist[i] + 1
					queue.append(j)
	return dist
