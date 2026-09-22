extends Node2D

## Oakley'in Sarmaşıklar (E) görseli - PIXEL tarzı DİKENLİ sarmaşık (kullanıcı isteği, 2026-09-21: "yerde pixel tarzda dikenli
## sarmaşık parçaları toprakla bütünleşecek halde looplu olacak ve düşmanlara doğru uzanıyor gibi görünecek, yetenek sürekli
## rotasyon değiştirdiği için efekt de ona uygun olmalı"). Eskiden düz yeşil bir Line2D'ydi.
##  - GÖVDE: sarmaşığın az önce geçtiği yolu (iz) izleyen, dalgalı, dikenli ve yapraklı pixel gövde - toprakla bütünleşik: her parçanın
##    altında toprak gölgesi, arada toprak parçacıkları, başın etrafında toprak yığını
##  - UZANTI: baştan hedefe doğru uzanan, dalgalanan ince dikenli filiz (hedef değiştikçe yeni yöne UZANIR / geri çekilir) ve ucunda pençe gibi iki diken
##  - Hepsi her karede geometriden çizilir (sprite yok) => sarmaşık hangi yöne dönerse dönsün (sürekli yön değiştirir) görsel ona uyar; dalgalanma
##    zamana bağlı sinüsle sonsuz döngüde (loop).
## oakley_vine.gd bu düğümü hem GERÇEK sarmaşıkta hem başka istemcilerdeki kozmetik kopyada kullanır (aynı dosya => iki taraf sapmaz).
## `points`: eski Line2D arayüzüyle uyumlu - [Vector2.ZERO, hedefin yerel konumu] ya da boş (hedef yok).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const TRAIL_LENGTH := 70.0 ## dünya birimi: baştan geriye doğru gövde uzunluğu
const TRAIL_SPACING := 3.0
const GROW_SPEED := 3.2 ## uzantının uzama/çekilme hızı (1/sn)
const SAMPLE_STEP := 0.9 ## örnekleme aralığı (texel): 1 texel'den küçük ki pixel'ler kopuk noktalar değil kesintisiz bir gövde oluştursun

const C_OUT := Color(0.07, 0.17, 0.06, 1.0)
const C_DARK := Color(0.15, 0.34, 0.11, 1.0)
const C_MID := Color(0.27, 0.55, 0.18, 1.0)
const C_LIGHT := Color(0.52, 0.82, 0.3, 1.0)
const C_THORN := Color(0.88, 0.8, 0.54, 1.0)
const C_THORN_TIP := Color(1.0, 0.95, 0.75, 1.0)
const C_SOIL := Color(0.2, 0.13, 0.08, 1.0)
const C_SOIL_L := Color(0.38, 0.26, 0.15, 1.0)

var points: PackedVector2Array = PackedVector2Array()

var _trail: Array = [] ## dünya konumları (eskiden yeniye)
var _t: float = 0.0
var _grow: float = 0.0
var _last_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0
	_trail.append(global_position)


func _process(delta: float) -> void:
	_t += delta
	var head: Vector2 = global_position
	if _trail.is_empty() or (_trail[_trail.size() - 1] as Vector2).distance_to(head) >= TRAIL_SPACING:
		_trail.append(head)
	## İzi TRAIL_LENGTH'e kısalt (baştan geriye toplam uzunluk).
	var total: float = 0.0
	var keep_from: int = 0
	for i in range(_trail.size() - 1, 0, -1):
		total += (_trail[i] as Vector2).distance_to(_trail[i - 1])
		if total > TRAIL_LENGTH:
			keep_from = i
			break
	if keep_from > 0:
		_trail = _trail.slice(keep_from)
	var has_target: bool = points.size() >= 2
	_grow = move_toward(_grow, 1.0 if has_target else 0.0, GROW_SPEED * delta)
	queue_redraw()


## Bir çoklu çizgiyi eşit aralıklı noktalara böler.
func _resample(pts: Array, spacing: float) -> Array:
	var out: Array = []
	if pts.size() < 2:
		return pts.duplicate()
	var carry: float = 0.0
	out.append(pts[0])
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg: float = a.distance_to(b)
		if seg <= 0.0001:
			continue
		var pos: float = spacing - carry
		while pos <= seg:
			out.append(a.lerp(b, pos / seg))
			pos += spacing
		carry = seg - (pos - spacing)
	if out[out.size() - 1] != pts[pts.size() - 1]:
		out.append(pts[pts.size() - 1])
	return out


func _draw() -> void:
	var texel: float = PixelDraw.TEXEL
	## --- GÖVDE (iz) ---
	var body_raw: Array = []
	for w in _trail:
		body_raw.append(to_local(w as Vector2))
	body_raw.append(Vector2.ZERO)
	var body: Array = _resample(body_raw, texel * SAMPLE_STEP)
	var head_dir: Vector2 = _last_dir
	if body.size() >= 2:
		var d: Vector2 = (body[body.size() - 1] as Vector2) - (body[maxi(body.size() - 4, 0)] as Vector2)
		if d.length() > 0.5:
			head_dir = d.normalized()
			_last_dir = head_dir
	## Toprak yatağı: gövdenin altına toprak gölgesi + rastgele toprak parçacıkları (toprakla bütünleşik görünüm)
	_draw_soil_bed(body, texel)
	_draw_strand(body, texel, true, 1.3, 0.0)
	## Baş: toprak yığını + tomurcuk
	_draw_head(Vector2.ZERO, head_dir, texel)
	## --- UZANTI (hedefe doğru) ---
	if _grow > 0.02 and points.size() >= 2:
		var end: Vector2 = (points[1] as Vector2) * _ease(_grow)
		if end.length() > 2.0:
			var ten: Array = _tendril(Vector2.ZERO, end)
			_draw_shadow_only(ten, texel)
			_draw_strand(ten, texel, false, 2.6, 4.0)
			_draw_claw(end, (end - (ten[maxi(ten.size() - 3, 0)] as Vector2)).normalized(), texel)


func _ease(v: float) -> float:
	return v * v * (3.0 - 2.0 * v)


## Baştan hedefe dalgalanan bir Bezier filizi (kontrol noktası zamanla salınır) - hedef yönü her karede yeniden hesaplandığı için
## sarmaşık hangi yöne dönerse dönsün uzantı ona uyar.
func _tendril(a: Vector2, b: Vector2) -> Array:
	var d: Vector2 = b - a
	var perp: Vector2 = Vector2(-d.y, d.x).normalized()
	var ctrl: Vector2 = a.lerp(b, 0.5) + perp * (10.0 * sin(_t * 2.2) + 5.0 * sin(_t * 3.7 + 1.0)) * clampf(d.length() / 90.0, 0.3, 1.0)
	var raw: Array = []
	var steps: int = maxi(6, int(d.length() / 6.0))
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u)
		raw.append(p)
	return _resample(raw, PixelDraw.TEXEL * SAMPLE_STEP)


func _normal_at(pts: Array, i: int) -> Vector2:
	var a: Vector2 = pts[maxi(i - 1, 0)]
	var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
	var d: Vector2 = b - a
	if d.length() < 0.001:
		return Vector2.UP
	return Vector2(-d.y, d.x).normalized()


func _wave_offset(pts: Array, i: int, u: float, amp: float, phase: float) -> Vector2:
	return _normal_at(pts, i) * sin(u * 9.0 - _t * 4.5 + phase) * amp * (0.35 + 0.65 * u)


func _draw_soil_bed(pts: Array, texel: float) -> void:
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		PixelDraw.px(self, p + Vector2(0, texel * 2.0), 1, Color(C_SOIL.r, C_SOIL.g, C_SOIL.b, 0.6))
		if i % 3 == 1:
			var side: float = -1.0 if PixelDraw.hash01(i * 17 + 3) < 0.5 else 1.0
			PixelDraw.px(self, p + Vector2(side * texel * (2.0 + PixelDraw.hash01(i * 5 + 1) * 2.0), texel * (1.0 + PixelDraw.hash01(i * 11 + 2) * 2.0)), 1, C_SOIL_L)
		if i % 7 == 4:
			PixelDraw.px(self, p + Vector2(texel * 3.0, texel * 2.0), 1, C_SOIL)


func _draw_shadow_only(pts: Array, texel: float) -> void:
	for i in range(pts.size()):
		PixelDraw.px(self, (pts[i] as Vector2) + Vector2(0, texel * 2.0), 1, Color(C_SOIL.r, C_SOIL.g, C_SOIL.b, 0.45))


## Sarmaşık gövdesi: koyu dış hat + orta ton + parlak çizgi, belirli aralıklarla diken ve yaprak. thick: gövdede 2 texel, uzantıda 1.
func _draw_strand(pts: Array, texel: float, is_body: bool, amp: float, phase: float) -> void:
	var n: int = pts.size()
	for i in range(n):
		var u: float = float(i) / float(maxi(n - 1, 1))
		var p: Vector2 = (pts[i] as Vector2) + _wave_offset(pts, i, u, amp, phase)
		if is_body:
			## Gövde: 3 texel koyu hat + 2 texel orta ton + 1 texel parlak sırt (baştan uzağa doğru incelir)
			var thick: int = 3 if u > 0.18 else 2
			PixelDraw.px(self, p + Vector2(0, texel * 0.6), thick, C_OUT)
			PixelDraw.px(self, p, thick, C_DARK)
			PixelDraw.px(self, p, thick - 1, C_MID)
			if i % 3 == 0:
				PixelDraw.px(self, p + Vector2(-texel * 0.5, -texel * 0.5), 1, C_LIGHT)
		else:
			## Uzantı: 2 texel koyu + 1 texel orta ton
			PixelDraw.px(self, p + Vector2(0, texel * 0.6), 2, C_OUT)
			PixelDraw.px(self, p, 2, C_DARK)
			PixelDraw.px(self, p, 1, C_MID)
			if i % 4 == 0:
				PixelDraw.px(self, p + Vector2(-texel * 0.5, -texel * 0.5), 1, C_LIGHT)
		## Dikenler: her 5. örnekte, iki yana sırayla, ileri doğru eğik (2 pixel: taban + uç)
		if i % 9 == 4 and i > 1:
			var side: float = 1.0 if floori(float(i) / 9.0) % 2 == 0 else -1.0
			var nrm: Vector2 = _normal_at(pts, i)
			var tng: Vector2 = ((pts[mini(i + 1, n - 1)] as Vector2) - (pts[maxi(i - 1, 0)] as Vector2)).normalized()
			var base: Vector2 = p + nrm * side * texel * (2.0 if is_body else 1.5)
			PixelDraw.px(self, base, 1, C_THORN)
			PixelDraw.px(self, base + nrm * side * texel * 1.2 + tng * texel * 0.8, 1, C_THORN_TIP)
		## Yapraklar: her 9. örnekte küçük 2 pixel yaprak
		if i % 17 == 11 and is_body:
			var lside: float = -1.0 if floori(float(i) / 17.0) % 2 == 0 else 1.0
			var lp: Vector2 = p + _normal_at(pts, i) * lside * texel * 2.5
			PixelDraw.px(self, lp, 1, C_LIGHT)
			PixelDraw.px(self, lp + _normal_at(pts, i) * lside * texel, 1, C_MID)


func _draw_head(pos: Vector2, dir: Vector2, texel: float) -> void:
	## Toprak yığını (baş çevresi, yarı gömülü görünüm)
	for k in range(9):
		var a: float = float(k) * TAU / 9.0 + 0.4
		var r: float = texel * (2.6 + PixelDraw.hash01(k * 7 + 2) * 2.2)
		PixelDraw.px(self, pos + Vector2(cos(a) * r, sin(a) * r * 0.55 + texel * 1.6), 1, C_SOIL_L if k % 2 == 0 else C_SOIL)
	## Tomurcuk: koyu hat + orta + parlak, yana bakan iki dikenli yaprak
	PixelDraw.px(self, pos, 3, C_OUT)
	PixelDraw.px(self, pos, 2, C_MID)
	PixelDraw.px(self, pos + Vector2(-texel * 0.5, -texel * 0.5), 1, C_LIGHT)
	var nrm: Vector2 = Vector2(-dir.y, dir.x)
	var bob: float = sin(_t * 5.0) * texel * 0.6
	for side in [-1.0, 1.0]:
		var leaf_base: Vector2 = pos + nrm * side * texel * 2.4 - dir * texel * 1.5
		PixelDraw.px(self, leaf_base, 1, C_MID)
		PixelDraw.px(self, leaf_base + nrm * side * texel + dir * bob, 1, C_LIGHT)
		PixelDraw.px(self, leaf_base + nrm * side * texel * 2.0 + dir * texel * 1.2, 1, C_THORN_TIP)


## Filizin ucunda "pençe": iki yana açılan diken çifti + parlak uç.
func _draw_claw(end: Vector2, dir: Vector2, texel: float) -> void:
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	var pulse: float = 0.6 + 0.4 * sin(_t * 8.0)
	for side in [-1.0, 1.0]:
		var d2: Vector2 = dir.rotated(0.6 * side)
		PixelDraw.px(self, end + d2 * texel * 1.5, 1, C_THORN)
		PixelDraw.px(self, end + d2 * texel * 3.0, 1, C_THORN_TIP)
	PixelDraw.px(self, end, 2, Color(C_LIGHT.r, C_LIGHT.g, C_LIGHT.b, pulse))
