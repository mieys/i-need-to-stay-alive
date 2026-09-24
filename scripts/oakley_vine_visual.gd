extends Node2D

## Oakley'in Sarmaşıklar (E) görseli - GÖVDE (arkada bıraktığı hareket izi) hâlâ PROSEDÜREL
## çizilir (kullanıcı kararı, 2026-09-23: iz sarmaşığın GERÇEK hareket yolunu birebir takip
## ettiği için sabit bir sprite'a çevrilemez - bkz. proje kökündeki CLAUDE.md'ye eklenen not).
## Ama BAŞ (toprak yığını + tomurcuk) ve UZANTI (hedefe doğru uzanan filiz) artık BAKED:
##  - Toprak halkası: yönden BAĞIMSIZ statik bir Sprite2D (hiç dönmüyor).
##  - Tomurcuk+yapraklar: küçük bir Sprite2D, `head_dir`e göre HER karede döndürülüyor.
##  - Uzantı: bir Line2D + tekrarlanan (TILE) doku - `_tendril()`nin ürettiği nokta dizisini
##    DOĞRUDAN kullanır, yani sarmaşık hangi yöne/mesafeye uzarsa uzasın (kullanıcı isteği:
##    "yönlerini düşmanlara doğru ayarladığı için buna uygun olması lazım") Line2D otomatik
##    doğru şekilde takip eder - sabit bir sprite döndürmekten farklı olarak dalgalı eğriyi de
##    bozmadan çizer. Eskiden bu ikisi de her karede onlarca px()/line() çağrısıyla (bkz. eski
##    _draw_head/_draw_strand(is_body=false)) çiziliyordu; artık 2 sprite + 1 Line2D (birkaç
##    çizim) yeterli.
## `points`: eski Line2D arayüzüyle uyumlu - [Vector2.ZERO, hedefin yerel konumu] ya da boş (hedef yok).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SOIL_RING_TEX := preload("res://assets/fx/oakley_vine/soil_ring.png")
const BUD_TEX := preload("res://assets/fx/oakley_vine/bud.png")
const TENDRIL_TILE_TEX := preload("res://assets/fx/oakley_vine/tendril_tile.png")

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
var _body_pts: Array = [] ## _process()'te hesaplanan, _draw()'ın okuduğu gövde/iz noktaları

var _bud_sprite: Sprite2D = null
var _tendril_line: Line2D = null
var _tendril_end: Vector2 = Vector2.ZERO
var _tendril_dir: Vector2 = Vector2.RIGHT
var _tendril_active: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0
	_trail.append(global_position)

	var soil := Sprite2D.new()
	soil.texture = SOIL_RING_TEX
	soil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(soil)

	_bud_sprite = Sprite2D.new()
	_bud_sprite.texture = BUD_TEX
	_bud_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_bud_sprite)

	_tendril_line = Line2D.new()
	_tendril_line.texture = TENDRIL_TILE_TEX
	_tendril_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	_tendril_line.width = 10.0
	_tendril_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## z_index vermiyoruz: eşit z'de Godot önce PARENT'ın kendi _draw()'ını (soil_bed+body_strand,
	## bkz. aşağıdaki _draw()), SONRA çocukları EKLENME sırasıyla çizer - soil/bud/tendril bu
	## sırayla eklendiği için orijinal katman sırası (gövde altta, baş üstte, uzantı en üstte)
	## ekstra z_index gerekmeden zaten doğru çıkıyor.
	_tendril_line.visible = false
	add_child(_tendril_line)


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

	## --- GÖVDE (iz) - prosedürel çizim için body noktalarını hazırla ---
	var texel: float = PixelDraw.TEXEL
	var body_raw: Array = []
	for w in _trail:
		body_raw.append(to_local(w as Vector2))
	body_raw.append(Vector2.ZERO)
	_body_pts = _resample(body_raw, texel * SAMPLE_STEP)
	var head_dir: Vector2 = _last_dir
	if _body_pts.size() >= 2:
		var d: Vector2 = (_body_pts[_body_pts.size() - 1] as Vector2) - (_body_pts[maxi(_body_pts.size() - 4, 0)] as Vector2)
		if d.length() > 0.5:
			head_dir = d.normalized()
			_last_dir = head_dir
	_bud_sprite.rotation = head_dir.angle()

	## --- UZANTI (hedefe doğru) - Line2D noktalarını güncelle ---
	_tendril_active = false
	if _grow > 0.02 and points.size() >= 2:
		var end: Vector2 = (points[1] as Vector2) * _ease(_grow)
		if end.length() > 2.0:
			var ten: Array = _tendril(Vector2.ZERO, end)
			_tendril_line.points = PackedVector2Array(ten)
			_tendril_end = end
			_tendril_dir = (end - (ten[maxi(ten.size() - 3, 0)] as Vector2)).normalized()
			_tendril_active = true
	_tendril_line.visible = _tendril_active
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


## Sadece GÖVDE (iz) + toprak yatağı + filiz ucundaki pençe artık burada çiziliyor - baş ve
## uzantının gövdesi Sprite2D/Line2D'ye taşındı (bkz. sınıf üstü not).
func _draw() -> void:
	var texel: float = PixelDraw.TEXEL
	_draw_soil_bed(_body_pts, texel)
	_draw_strand(_body_pts, texel, 1.3, 0.0)
	if _tendril_active:
		_draw_claw(_tendril_end, _tendril_dir, texel)


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


## Sarmaşık gövdesi (iz): koyu dış hat + orta ton + parlak çizgi, belirli aralıklarla diken ve yaprak.
func _draw_strand(pts: Array, texel: float, amp: float, phase: float) -> void:
	var n: int = pts.size()
	for i in range(n):
		var u: float = float(i) / float(maxi(n - 1, 1))
		var p: Vector2 = (pts[i] as Vector2) + _wave_offset(pts, i, u, amp, phase)
		## Gövde: 3 texel koyu hat + 2 texel orta ton + 1 texel parlak sırt (baştan uzağa doğru incelir)
		var thick: int = 3 if u > 0.18 else 2
		PixelDraw.px(self, p + Vector2(0, texel * 0.6), thick, C_OUT)
		PixelDraw.px(self, p, thick, C_DARK)
		PixelDraw.px(self, p, thick - 1, C_MID)
		if i % 3 == 0:
			PixelDraw.px(self, p + Vector2(-texel * 0.5, -texel * 0.5), 1, C_LIGHT)
		## Dikenler: her 9. örnekte, iki yana sırayla, ileri doğru eğik (2 pixel: taban + uç)
		if i % 9 == 4 and i > 1:
			var side: float = 1.0 if floori(float(i) / 9.0) % 2 == 0 else -1.0
			var nrm: Vector2 = _normal_at(pts, i)
			var tng: Vector2 = ((pts[mini(i + 1, n - 1)] as Vector2) - (pts[maxi(i - 1, 0)] as Vector2)).normalized()
			var base: Vector2 = p + nrm * side * texel * 2.0
			PixelDraw.px(self, base, 1, C_THORN)
			PixelDraw.px(self, base + nrm * side * texel * 1.2 + tng * texel * 0.8, 1, C_THORN_TIP)
		## Yapraklar: her 17. örnekte küçük 2 pixel yaprak
		if i % 17 == 11:
			var lside: float = -1.0 if floori(float(i) / 17.0) % 2 == 0 else 1.0
			var lp: Vector2 = p + _normal_at(pts, i) * lside * texel * 2.5
			PixelDraw.px(self, lp, 1, C_LIGHT)
			PixelDraw.px(self, lp + _normal_at(pts, i) * lside * texel, 1, C_MID)


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
