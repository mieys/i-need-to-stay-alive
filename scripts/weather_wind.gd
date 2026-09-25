extends Node2D

## Rüzgarlı hava görseli (kullanıcı isteği 2026-09-25: "rüzgar etrafta pixel hava geçişleri bırakacak", "pixel tarzda
## cozy"). atmosphere.gd'nin çocuğu; şiddet (0..1) ve rüzgar açısı set_wind() ile gelir.
##
## İki öğe, ikisi de DÜNYA uzayında (haritaya yapışık, kamerayla kaymaz):
##  - Hava akıntıları: rüzgar yönünde süzülen, hafif dalgalanan tek piksel kalınlığında beyaz çizgiler; bir kısmı yolun
##    ortasında küçük bir halka çizip (klasik "cozy" rüzgar kıvrımı) yoluna devam eder. Kuyruk şeffaflaşarak iner.
##  - Savrulan yapraklar: 2 piksellik yeşil/kahve yapraklar, takla atarak (yatay/dikey kare değişimi) rüzgarla uçar.
## Rüzgarlı havada bitkilerin sallanma shader'ı (sallantı.gdshader) da güçlenir (bkz. atmosphere.gd).
##
## PASİF ESİNTİ (kullanıcı isteği 2026-09-25: "haritadaki canvaslayer'a eklediğim colorrect'teki rüzgar shaderını silip
## eklediğin rüzgar efektinin lite versiyonu olarak değiştir; her hava durumunda aktif olsun ama daha sakin ve oyuncu
## hareketini etkilemeyecek şekilde, pasif bir esinti gibi (fırtına rüzgarları değişmeyecek)"). Eski ekran kaplaması
## (harita_baked.tscn "CanvasLayer/ColorRect", rüzgar efekti.gdshader) haritadan kaldırıldı; yerine burada, dışarıdayken
## HER havada birkaç tane (BREEZE_GUSTS) daha şeffaf, daha yavaş, daha kısa ve daha az kıvrılan akıntı + ara sıra tek
## bir yaprak. Rüzgarlı havanın kendi akıntıları (MAX_GUSTS) aynen ayrıca gelir. Esinti hızı ETKİLEMEZ (hız etkisi
## player.gd _wind_move_mult - sadece atmosphere.gd wind_intensity'ye bakar).
##
## PERF: parçacık başına Node YOK, tek _draw (weather_rain.gd ile aynı desen). PERF DÜZELTMESİ (kullanıcı bildirimi
## 2026-09-25: "oyundaki hava durumları fpsi düşürüyor gibi görünüyor"): akıntı pikselleri ve yapraklar eskiden TEK TEK
## draw_rect ile çiziliyordu (akıntı başına ~50-70, rüzgarlı/sağanakta ekranda ~20-40 akıntı -> karede 1000-2500 çizim
## komutu). Artık bütün pikseller 1 birimlik yatay çizgi parçaları olarak TEK draw_multiline_colors çağrısında - görünüm
## birebir aynı (1x1 dünya birimi hücre), komut sayısı 1.
##
## SAĞANAK (kullanıcı bildirimi 2026-09-25: "hava durumunda fırtına hiç belli olmuyor rüzgarlar yapraklar vb yeterince
## belirgin ve hızlı değil"): set_wind'in storm (0..1) parametresi akıntıları daha çok/hızlı/uzun/parlak ve daha az
## kıvrılan, yaprakları iki katından fazla ve çok daha hızlı yapar (STORM_* çarpanları).

const MAX_GUSTS := 11 ## şiddet 1'de, 1920x1080 görünümde aynı anda
const MAX_LEAVES := 16
## DÜZELTME (kullanıcı geri bildirimi 2026-09-25: "pasif rüzgar neredeyse hiç yok gibi, yaprak düşüşünden hoşlandım ama
## rüzgar ve yaprak neredeyse hiç yok"): ilk sürümde aynı anda en fazla 4 soluk (x0.5) akıntı + 2 yaprak vardı, akıntılar
## saniyede ~1 şansla doğuyordu ve yaprakların %65'i ekranın DIŞINDA (rüzgar üstünde) doğup çoğu hiç görünmüyordu.
## Artık 9 akıntı (x0.75 opaklık, fırtınayla aynı doğma sıklığı), 8 yaprak; esinti yaprakları çoğunlukla görünür alanın
## İÇİNDE belirip (yumuşak belirme) daha yavaş, hafifçe aşağı süzülerek düşer. Fırtına (rüzgarlı hava) değerleri aynı.
const BREEZE_GUSTS := 9
const BREEZE_LEAVES := 8
const BREEZE_ALPHA_MULT := 0.75
const REFERENCE_AREA := 960.0 * 540.0
const GUST_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const LEAF_COLORS: Array[Color] = [Color(0.45, 0.62, 0.25), Color(0.36, 0.52, 0.2), Color(0.66, 0.54, 0.24), Color(0.55, 0.36, 0.18)]
const VIEW_MARGIN := 60.0
## Sağanak çarpanları (storm = 1'de).
const STORM_GUST_COUNT_MULT := 2.2
const STORM_GUST_SPEED_MULT := 1.9
const STORM_GUST_TRAIL_MULT := 1.6
const STORM_LEAF_COUNT_MULT := 2.5
const STORM_LEAF_SPEED_MULT := 2.2
const STORM_ALPHA := 0.85 ## sağanakta akıntı rengi opaklığı (normal GUST_COLOR 0.55)

var intensity: float = 0.0
## Pasif esinti (0 = ev içi, 1 = dışarıda) - bkz. dosya başı "PASİF ESİNTİ".
var breeze: float = 0.0
var wind_dir: Vector2 = Vector2.RIGHT
## Sağanak şiddeti 0..1 (bkz. dosya başı "SAĞANAK").
var storm: float = 0.0

var _gusts: Array = [] ## her biri Dictionary (bkz. _spawn_gust)
var _leaves: Array = []
var _view := Rect2()
var _pts := PackedVector2Array()
var _cols := PackedColorArray()


func _ready() -> void:
	z_index = 99 ## yağmurun hemen altı, dünyadaki her şeyin üstü
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_wind(value: float, angle: float, p_breeze: float = 0.0, p_storm: float = 0.0) -> void:
	intensity = clampf(value, 0.0, 1.0)
	breeze = clampf(p_breeze, 0.0, 1.0)
	storm = clampf(p_storm, 0.0, 1.0)
	wind_dir = Vector2.from_angle(angle)


func _process(delta: float) -> void:
	if intensity <= 0.001 and breeze <= 0.001 and _gusts.is_empty() and _leaves.is_empty():
		if visible:
			visible = false
		return
	visible = true
	_view = _visible_world_rect()
	var area_k: float = clampf(_view.get_area() / REFERENCE_AREA, 0.5, 2.5)
	var gust_target: int = int(round(MAX_GUSTS * intensity * lerpf(1.0, STORM_GUST_COUNT_MULT, storm) * area_k))
	var breeze_target: int = int(round(BREEZE_GUSTS * breeze * area_k))
	var leaf_target: int = int(round((MAX_LEAVES * intensity * lerpf(1.0, STORM_LEAF_COUNT_MULT, storm) + BREEZE_LEAVES * breeze) * area_k))

	var storm_count: int = 0
	var i: int = _gusts.size() - 1
	while i >= 0:
		var g: Dictionary = _gusts[i]
		g["head"] = float(g["head"]) + float(g["speed"]) * delta
		if float(g["head"]) - float(g["trail"]) > float(g["total"]):
			_gusts.remove_at(i)
		elif not bool(g["lite"]):
			storm_count += 1
		i -= 1
	var lite_count: int = _gusts.size() - storm_count
	## Yeni akıntılar tek tek, rastgele aralıklarla doğsun (hepsi aynı anda başlayıp aynı anda bitmesin).
	if storm_count < gust_target and randf() < delta * 3.0 * lerpf(1.0, 3.0, storm):
		_spawn_gust(false)
	if lite_count < breeze_target and randf() < delta * 3.0:
		_spawn_gust(true)

	var expanded: Rect2 = _view.grow(VIEW_MARGIN * 2.0)
	var j: int = _leaves.size() - 1
	while j >= 0:
		var leaf: Dictionary = _leaves[j]
		leaf["t"] = float(leaf["t"]) + delta
		var t: float = float(leaf["t"])
		## Rüzgar yönünde ilerle + dik yönde yavaş bir süzülme salınımı (yaprak havada "yüzer").
		var perp := Vector2(-wind_dir.y, wind_dir.x)
		var vel: Vector2 = wind_dir * float(leaf["speed"]) + perp * sin(t * float(leaf["wobble"]) + float(leaf["phase"])) * 26.0 \
				+ Vector2(0.0, float(leaf["fall"]))
		leaf["pos"] = (leaf["pos"] as Vector2) + vel * delta
		## Rüzgar dinerken fazla yapraklar yok edilmez: yenileri doğmaz, eskiler şeffaflaşarak (bkz. _draw) ekrandan uçar.
		## Görünür alanın dışındayken ondan UZAKLAŞIYORSA silinir (rüzgar üstünde doğup içeri giren yaprak değil; aşağı
		## süzülerek alttan çıkan esinti yaprağı da artık yer kaplayıp yenilerini engellemez).
		var rel: Vector2 = (leaf["pos"] as Vector2) - _view.get_center()
		if (not expanded.has_point(leaf["pos"]) and rel.dot(vel) > 0.0) or t > 25.0:
			_leaves.remove_at(j)
		j -= 1
	if _leaves.size() < leaf_target and randf() < delta * 4.0 * lerpf(1.0, 3.0, storm):
		_spawn_leaf()
	queue_redraw()


func _visible_world_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * size
	return Rect2(a, b - a).abs()


## Rüzgarın geldiği taraftan (ekranın rüzgar üstü kenarının biraz dışından ya da ekranın içinden) bir nokta.
func _upwind_point(inside_chance: float) -> Vector2:
	var p := Vector2(randf_range(_view.position.x, _view.end.x), randf_range(_view.position.y, _view.end.y))
	if randf() >= inside_chance:
		p -= wind_dir * randf_range(_view.size.x * 0.1, _view.size.x * 0.35)
	return p


## lite = pasif esinti akıntısı (daha şeffaf/yavaş/kısa, nadiren kıvrılır) - bkz. dosya başı "PASİF ESİNTİ".
func _spawn_gust(lite: bool) -> void:
	var dir: Vector2 = wind_dir.rotated(randf_range(-0.12, 0.12))
	var st: float = 0.0 if lite else storm
	var curl: bool = randf() < (0.2 if lite else lerpf(0.45, 0.15, st))
	var k: float = 0.6 if lite else 1.0
	_gusts.append({
		"lite": lite,
		"origin": _upwind_point(0.7 if lite else 0.55),
		"dir": dir,
		"perp": Vector2(-dir.y, dir.x),
		"speed": randf_range(150.0, 230.0) * (0.7 if lite else lerpf(1.0, STORM_GUST_SPEED_MULT, st)),
		"trail": randf_range(34.0, 62.0) * (0.85 if lite else lerpf(1.0, STORM_GUST_TRAIL_MULT, st)),
		"head": 0.0,
		"total": randf_range(220.0, 380.0) * (0.9 if lite else lerpf(1.0, 1.5, st)),
		"amp": randf_range(1.2, 3.2) * (0.7 if lite else 1.0),
		"freq": randf_range(0.045, 0.085),
		"phase": randf() * TAU,
		"curl_at": randf_range(60.0, 150.0) * k if curl else -1.0,
		"curl_r": randf_range(4.0, 7.0),
		"curl_side": -1.0 if randf() < 0.5 else 1.0,
		"alpha": randf_range(0.6, 1.0) * (BREEZE_ALPHA_MULT if lite else 1.0),
		"base_a": GUST_COLOR.a if lite else lerpf(GUST_COLOR.a, STORM_ALPHA, st),
	})


## Rüzgarlı havada yaprak hızlı savrulur; sadece esinti varken (lite) yavaş, hafifçe aşağı süzülerek "düşer" ve
## çoğunlukla görünür alanın içinde belirir (bkz. BREEZE_LEAVES notu). Karışık havada oran rüzgar şiddetine göre.
func _spawn_leaf() -> void:
	var lite: bool = randf() >= intensity
	_leaves.append({
		"pos": _upwind_point(0.75 if lite else 0.35),
		"speed": randf_range(38.0, 72.0) if lite else randf_range(70.0, 125.0) * lerpf(1.0, STORM_LEAF_SPEED_MULT, storm),
		"fall": randf_range(8.0, 18.0) if lite else 0.0,
		"wobble": randf_range(1.2, 2.4) if lite else randf_range(1.6, 3.2),
		"phase": randf() * TAU,
		"spin": randf_range(3.5, 7.0) if lite else randf_range(5.0, 11.0),
		"fade_in": 0.9 if lite else 0.4,
		"color": LEAF_COLORS[randi() % LEAF_COLORS.size()],
		"t": 0.0,
	})


## Akıntının yol parametresi s'deki (akıntı boyunca kat edilen mesafe) dünya konumu. Kıvrım: curl_at noktasında yola
## teğet bir çember - bu aralıkta ileri gidiş durur, çizgi yerinde tam bir halka çizer, sonra kaldığı yerden devam eder.
func _gust_point(g: Dictionary, s: float) -> Vector2:
	var along: float = s
	var lateral: float = float(g["amp"]) * sin(s * float(g["freq"]) + float(g["phase"]))
	var c0: float = float(g["curl_at"])
	if c0 >= 0.0 and s > c0:
		var r: float = float(g["curl_r"])
		var loop_len: float = TAU * r
		if s < c0 + loop_len:
			var th: float = (s - c0) / r
			along = c0 + r * sin(th)
			lateral += r * (1.0 - cos(th)) * float(g["curl_side"])
		else:
			along = s - loop_len
	return (g["origin"] as Vector2) + (g["dir"] as Vector2) * along + (g["perp"] as Vector2) * lateral


## 1x1 dünya birimi hücre = (x, y+0.5)'ten (x+1, y+0.5)'e 1 birim kalınlıkta çizgi parçası (tek draw çağrısında birleşir).
func _cell(p: Vector2, c: Color) -> void:
	_pts.append(Vector2(p.x, p.y + 0.5))
	_pts.append(Vector2(p.x + 1.0, p.y + 0.5))
	_cols.append(c)


func _draw() -> void:
	_pts.clear()
	_cols.clear()
	for g: Dictionary in _gusts:
		var head: float = float(g["head"])
		var trail: float = float(g["trail"])
		var total: float = float(g["total"])
		## Doğarken ve yolun sonunda yumuşakça belir/sön.
		var env: float = clampf(head / 24.0, 0.0, 1.0) * clampf((total - (head - trail)) / 40.0, 0.0, 1.0)
		if env <= 0.0:
			continue
		var base: Color = GUST_COLOR
		base.a = float(g.get("base_a", GUST_COLOR.a))
		var tail: float = maxf(0.0, head - trail)
		var last := Vector2i(-999999, -999999)
		var s: float = tail
		while s <= head:
			var p: Vector2 = _gust_point(g, s)
			var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
			if cell != last:
				last = cell
				var u: float = (s - tail) / maxf(trail, 1.0) ## 0 kuyruk -> 1 baş
				var c: Color = base
				c.a *= env * float(g["alpha"]) * u * u * (3.0 - 2.0 * u)
				if c.a > 0.03:
					_cell(Vector2(cell), c)
			s += 0.8
	for leaf: Dictionary in _leaves:
		var p2: Vector2 = (leaf["pos"] as Vector2).floor()
		var col: Color = leaf["color"]
		var fade: float = clampf(float(leaf["t"]) / float(leaf["fade_in"]), 0.0, 1.0)
		col.a = 0.9 * fade * clampf(maxf(intensity * 1.5, breeze), 0.0, 1.0)
		## Takla: yaprak dönerken yatay (2x1) ve dikey (1x2) görünüm arasında gidip gelir, arada tek piksel.
		var spin: float = sin(float(leaf["t"]) * float(leaf["spin"]) + float(leaf["phase"]))
		var dark := Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a)
		if spin > 0.35:
			_cell(p2, col)
			_cell(p2 + Vector2(1.0, 0.0), col)
			_cell(p2 + Vector2(1.0, 1.0), dark)
		elif spin < -0.35:
			_cell(p2, col)
			_cell(p2 + Vector2(0.0, 1.0), col)
			_cell(p2 + Vector2(1.0, 0.0), dark)
		else:
			_cell(p2, col)
	if not _cols.is_empty():
		draw_multiline_colors(_pts, _cols, 1.0)
