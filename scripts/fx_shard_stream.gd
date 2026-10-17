extends Node2D
class_name FxShardStream

## Uçan kırıntılar: kaynaktan kopan kırıntılar yay çizerek hedefe uçar, yolda renk değiştirir, hedefte halka + artıyla emilir.
## Kaynak: Şovalye E prototipi A "Hasar Kırıntıları" (tools/proto_20261014/sovalye_e_emilim_proto.py FamA). Kullanıcı
## 2026-10-14: "A hasar kırıntılarındaki uçarak giden parçacıkları Melek'in kalkan bağı için kullan" -> Melek E (Kalkan
## Yenileme) bağının görseli: eskiden her tikte fx_wave_beam.gd "shield" dalga ışını, artık Melek'in altın ışığından kopup
## yolda mana kalkanı mavisine dönen kırıntılar (player.gd _spawn_wave_beam_to_ally "shield" dalı).
## Kırıntılar kalkıştan sonra kaynaktan KOPUKTUR (başlangıç noktası sabit), uç kısmı her karede hedefi takip eder.
## Ağ: kaster yerelde kurar + broadcast_wave_fx; alıcı (network_manager.gd) aynı setup()'la kurar.

const FPD := preload("res://scripts/fine_pixel_draw.gd")
const T := FPD.TEXEL

const SCALE := 2.0 ## sanat pikseli büyütme (1 = prototip boyu, oyunda çok küçük kalıyordu)
const STAGGER := 0.03
const TRAIL := 10
const TRAIL_STEP := 0.024
const ARRIVE_LIFE := 0.3

## ramp: kalkıştan varışa renk; hi: baş pikselinin parlaması (ilk yarı, ikinci yarı beyaz); out: kontur; ring: varış halkası.
const PALETTES := {
	"melek_shield": {
		"ramp": [Color8(255, 226, 140), Color8(190, 228, 255), Color8(64, 173, 255), Color8(224, 247, 255), Color8(245, 252, 255)],
		"hi": Color8(255, 246, 214),
		"white": Color8(245, 252, 255),
		"out": Color8(15, 51, 153),
		"ring_a": Color8(224, 247, 255),
		"ring_b": Color8(110, 190, 255),
	},
}

var target: Node2D = null
var count: int = 7
var big: bool = false
var _pal: Dictionary = PALETTES["melek_shield"]
var _p0: Vector2 = Vector2.ZERO
var _launch: Vector2 = Vector2.UP
var _tp: Vector2 = Vector2.ZERO
var _fl: float = 0.5
var _life: float = 1.0
var _t: float = 0.0
var _lut: PackedColorArray = PackedColorArray()


func setup(p_from: Vector2, p_target: Node2D, p_palette: String = "melek_shield", p_count: int = 7, p_big: bool = false) -> void:
	_p0 = p_from
	target = p_target
	count = maxi(1, p_count)
	big = p_big
	_pal = PALETTES.get(p_palette, PALETTES["melek_shield"])
	_tp = target.global_position if target != null and is_instance_valid(target) else p_from
	var dir: Vector2 = (_tp - _p0).normalized() if _tp.distance_to(_p0) > 1.0 else Vector2.RIGHT
	## Kalkış: kaynaktan yukarı ve biraz geriye fırlar, sonra hedefe döner (prototipte "yaradan kopma" yönü).
	_launch = (Vector2.UP * 0.8 - dir * 0.6).normalized()
	## Uçuş süresi mesafeyle biraz uzar (prototip: ~85 dünya = 0,5 sn).
	_fl = clampf(0.4 + _tp.distance_to(_p0) / 800.0, 0.45, 0.75)
	_life = float(count - 1) * STAGGER + _fl + ARRIVE_LIFE


func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST ## elmas maskeleri (FPD.diamond) piksel net çizilsin
	global_position = Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		_tp = target.global_position
	queue_redraw()


## Gece ışığı (night_glow.gd): kalkıştan hedefe.
func get_glow_segment() -> Array:
	return [_p0, _tp]


## Kullanıcı 2026-10-15: "melekin kalkan verme efekti neredeyse hiç görünmüyor, çok ufak" -> efekt 2 kat piksel (SCALE)
## ve daha geniş yaylarla çizilir; konumlar büyük ızgaraya (T * SCALE) oturur. FPS (2026-10-15): eskiden her iz noktası için
## draw_set_transform + FPD.px zinciri vardı (7 kırıntı x 10 iz x 1-3 piksel, saniyelerce); artık büyük piksel doğrudan
## draw_rect, elmaslar önbellekli doku, sadece geçerli iz aralığı dolaşılır (bkz. _draw).
const CELL := T * SCALE


func _snap(pos: Vector2) -> Vector2:
	return Vector2(roundf(pos.x / CELL) * CELL, roundf(pos.y / CELL) * CELL)


## İz noktası alfaları (k = izdeki sıra): ham alfa (1 - k / TRAIL) * 0.95 -> pixel diline yuvarlanmış; ana + iki yan piksel.
static var _trail_q: Array = []
const RAMP_STEPS := 32


static func _trail_alpha(k: int, mult: float) -> float:
	return FPD.q_alpha((1.0 - float(k) / float(TRAIL)) * 0.95 * mult)


## Kare başı iz noktası başına yüzlerce GDScript işlemi vardı (bez3 + ramp + q_alpha çağrıları; ~270 us/akış): kübik bezier
## katsayıları kırıntı başına bir kez, palet arama tablosu ve iz alfaları önceden hesaplı (2026-10-15 FPS).
func _ramp_lut() -> PackedColorArray:
	var out := PackedColorArray()
	var ramp: Array = _pal["ramp"]
	for i in range(RAMP_STEPS + 1):
		out.append(FPD.ramp(ramp, float(i) / float(RAMP_STEPS)))
	return out


func _draw() -> void:
	if _trail_q.is_empty():
		for k in range(TRAIL):
			_trail_q.append([_trail_alpha(k, 1.0), _trail_alpha(k, 0.8), _trail_alpha(k, 0.6)])
	if _lut.is_empty():
		_lut = _ramp_lut()
	var lut: PackedColorArray = _lut
	var dir: Vector2 = (_tp - _p0).normalized() if _tp.distance_to(_p0) > 1.0 else Vector2.RIGHT
	var perp := Vector2(-_launch.y, _launch.x)
	var half: float = maxf(1.0, float(count - 1) * 0.5)
	var wide: float = T * SCALE
	var out_col: Color = _pal["out"]
	var no_col := Color(0, 0, 0, 0)
	var quad := Vector2(CELL, CELL)
	var inv_cell: float = 1.0 / CELL
	for i in range(count):
		var t0: float = float(i) * STAGGER
		var age: float = _t - t0
		var spread: float = (float(i) - float(count - 1) * 0.5) / half
		var p1: Vector2 = _p0 + (_launch * 16.0 + perp * spread * 12.0) * wide
		var p2: Vector2 = _tp + (-dir * 18.0 + Vector2(0.0, -24.0 + spread * 10.0)) * wide
		var c1: Vector2 = (p1 - _p0) * 3.0
		var c2: Vector2 = (_p0 - p1 * 2.0 + p2) * 3.0
		var c3: Vector2 = _tp - _p0 + (p1 - p2) * 3.0
		## geçerli iz noktaları: 0 <= age - k * TRAIL_STEP <= _fl
		var k_lo: int = maxi(0, ceili((age - _fl) / TRAIL_STEP))
		var k_hi: int = mini(TRAIL - 1, floori(age / TRAIL_STEP))
		for k in range(k_lo, k_hi + 1):
			var u: float = (age - float(k) * TRAIL_STEP) / _fl
			if u < 0.0 or u > 1.0:
				continue
			var sm: float = u * u * (3.0 - 2.0 * u)
			var raw: Vector2 = _p0 + sm * (c1 + sm * (c2 + sm * c3))
			var pos := Vector2(roundf(raw.x * inv_cell) * CELL, roundf(raw.y * inv_cell) * CELL)
			var col: Color = lut[int(u * float(RAMP_STEPS) + 0.5)]
			if k == 0:
				if u > 0.97:
					continue
				var r: int = 3 if big and i % 2 == 0 else 2
				FPD.diamond(self, pos, r, col, 1.0, out_col, SCALE)
				FPD.diamond(self, pos, r - 1, col.lerp(_pal["white"] if u > 0.45 else _pal["hi"], 0.7), 1.0, no_col, SCALE)
			else:
				var q: Array = _trail_q[k]
				var base: Vector2 = pos - quad * 0.5
				if q[0] > 0.0:
					draw_rect(Rect2(base, quad), Color(col, q[0]))
				if k < 5:
					if q[1] > 0.0:
						draw_rect(Rect2(base + Vector2(0.0, CELL), quad), Color(col, q[1]))
					if q[2] > 0.0:
						draw_rect(Rect2(base + Vector2(CELL, 0.0), quad), Color(col, q[2]))
		## varış: halka + artı (son kırıntı büyük darbede daha geniş)
		var arr: float = age - _fl
		if arr >= 0.0 and arr < ARRIVE_LIFE:
			var p: float = arr / ARRIVE_LIFE
			var last_big: bool = big and i == count - 1
			_at(_tp)
			FPD.ring(self, Vector2.ZERO, 3.0 + (12.0 if last_big else 8.5) * p, _pal["ring_a"] if p < 0.4 else _pal["ring_b"], 1.0 - p)
			if p < 0.45:
				FPD.plus(self, Vector2.ZERO, _pal["white"], _pal["ring_a"], 1.0, 3 if last_big else 2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Varış halkası/artısı için: konumu büyük ızgaraya oturtup piksel çarpanıyla çizmek üzere dönüşümü kurar.
func _at(pos: Vector2) -> void:
	draw_set_transform(_snap(pos), 0.0, Vector2(SCALE, SCALE))
