extends Node2D
class_name FxSovalyeEcho

## Şovalye Adam E (Koruma Bariyeri, id 29) - "YANKI DARBESİ": bariyerli dost hasar aldığında, aktarılan payın Şovalye'ye
## gittiği AN (kullanıcı 2026-10-14: "hiç hasarlarını emiyormuş gibi hissettirmiyor" -> prototip D seçildi,
## tools/proto_20261014/sovalye_e_emilim_proto.py FamD). Eskiden E'nin iki görseli (dosttaki guard_bubble, Şovalye'deki
## guard_absorb) sürekli döngüydü - darbe gelse de gelmese de aynı oynuyordu, aktarım anında hiçbir şey görünmüyordu.
##   1) dostun baloncuğu darbe tarafında parlar,
##   2) baloncuğun Şovalye'ye bakan ÜST kenarından Şovalye'ye yukarı kavisli anlık enerji yayı çakar (kalın beyaz -> ince ->
##      iki uçtan içeri ufalanır),
##   3) AYNI darbe Şovalye'nin üstünde de (aynı yönden) mor tonlu patlar + halka.
## Dünyaya konan kısa ömürlü efekt (sahne kökünün çocuğu); iki ucu her karede dostu/Şovalye'yi takip eder.
## Ağ: hasarı alan DOST üretir (player.gd _sovalye_echo_fx, take_damage aktarım dalı) ve "sovalye_echo" türüyle yayınlar
## (network_manager.gd broadcast_player_vfx) - her istemci aynı setup()'la kurar.

const FPD := preload("res://scripts/fine_pixel_draw.gd")
const T := FPD.TEXEL

## fx_paladin_barrier_link.gd baloncuğu: 34 sanat px x TEXEL 1,212 x oyuncu kökü ölçeği 0,5 = 20,6 dünya.
const BUBBLE_R := 20.6
const ARC_LIFE := 0.32
const FLASH_LIFE := 0.2
const IMPACT_DELAY := 0.02
const BURST_LIFE := 0.18
const RING_LIFE := 0.28
const LIFE := 0.33

const C_LAV := Color8(170, 140, 255)
const C_PALE := Color8(206, 216, 255)
const C_WHITE := Color8(242, 244, 255)

var ally: Node2D = null
var knight: Node2D = null
var hit_angle: float = PI
var big: bool = false
var _a: Vector2 = Vector2.ZERO
var _k: Vector2 = Vector2.ZERO
var _t: float = 0.0


## p_angle: darbenin dosta geldiği yön (dosttan saldırgana, ekran açısı). p_big: büyük darbe (kalın çekirdek, geniş halka).
func setup(p_ally: Node2D, p_knight: Node2D, p_angle: float, p_big: bool) -> void:
	ally = p_ally
	knight = p_knight
	hit_angle = p_angle
	big = p_big
	_follow()


func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST ## FPD.ring maske dokusu piksel net çizilsin
	global_position = Vector2.ZERO


func _follow() -> void:
	if ally != null and is_instance_valid(ally):
		_a = ally.global_position
	if knight != null and is_instance_valid(knight):
		_k = knight.global_position


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	_follow()
	queue_redraw()


## Gece ışığı (night_glow.gd): dosttan Şovalye'ye yay boyunca.
func get_glow_segment() -> Array:
	return [_a, _k]


func _draw() -> void:
	if _a.distance_to(_k) < 4.0:
		return
	_draw_bubble_flash()
	_draw_arc()
	_draw_knight_impact()


func _draw_bubble_flash() -> void:
	if _t >= FLASH_LIFE:
		return
	var a: float = 1.0 - _t / FLASH_LIFE
	for i in range(-12, 13):
		var g: float = hit_angle + 0.7 * float(i) / 12.0
		var dir := Vector2(cos(g), sin(g))
		FPD.px(self, _a + dir * BUBBLE_R, C_WHITE if absi(i) < 5 else C_PALE, a * (1.0 if absi(i) < 8 else 0.6))
		FPD.px(self, _a + dir * (BUBBLE_R - T), C_LAV, a * 0.55)


## Baloncuğun Şovalye'ye bakan iki kenar noktasından (±0,6 rad) yukarıdaki - yay dostun gövdesini kesmez.
func _arc_start() -> Vector2:
	var to_k: float = (_k - _a).angle()
	var s1 := Vector2.from_angle(to_k - 0.6)
	var s2 := Vector2.from_angle(to_k + 0.6)
	return _a + (s1 if s1.y <= s2.y else s2) * BUBBLE_R


func _draw_arc() -> void:
	var p: float = _t / ARC_LIFE
	if p >= 1.0:
		return
	var start: Vector2 = _arc_start()
	var dv: Vector2 = _k - start
	var length: float = dv.length()
	if length < 4.0:
		return
	var perp := Vector2(dv.y, -dv.x) / length
	if perp.y > 0.0:
		perp = -perp ## yay hep yukarı kavisli
	var ctrl: Vector2 = (start + _k) * 0.5 + perp * 16.0 * T
	var len_px: float = length / T
	var n: int = maxi(24, int(len_px * 1.6))
	var lo: float = 0.5 * maxf(0.0, (p - 0.35) / 0.65) ## son evrede iki uçtan içeri ufalanır
	var wob_amp: float = 1.0 if p < 0.4 else 0.5
	for i in range(n + 1):
		var u: float = float(i) / float(n)
		if u < lo or u > 1.0 - lo:
			continue
		var q: Vector2 = FPD.bez2(start, ctrl, _k, u) + perp * sin(u * len_px * 0.22 - _t * 40.0) * wob_amp * T
		var e: float = minf(1.0, minf((u - lo) * 14.0, (1.0 - lo - u) * 14.0))
		if p < 0.18:
			FPD.px(self, q + perp * 2.0 * T, C_LAV, e * 0.3)
			FPD.px(self, q - perp * 2.0 * T, C_LAV, e * 0.3)
			FPD.px(self, q + perp * T, C_PALE, e)
			FPD.px(self, q - perp * T, C_PALE, e)
			FPD.px(self, q, C_WHITE, e)
		elif p < 0.45:
			FPD.px(self, q, C_PALE, e * 0.95)
			if (i / 3) % 2 == 0:
				FPD.px(self, q + perp * T, C_LAV, e * 0.55)
		elif ((i + int(p * 30.0)) / 4) % 3 != 2:
			FPD.px(self, q, C_LAV, e * (1.0 - p) * 1.6)
	## yay boyunca savrulan kıvılcımlar
	for k in range(5):
		var u2: float = (float(k) + 0.5) / 5.0
		var side: float = 1.0 if k % 2 == 1 else -1.0
		FPD.px(self, FPD.bez2(start, ctrl, _k, u2) + perp * (2.0 + 6.0 * p) * side * T, C_PALE, 1.0 - p)


## Aynı darbe Şovalye'de de patlar: dostu vuran yönden, mor tonlu ışın patlaması + artı + dışa açılan halka.
func _draw_knight_impact() -> void:
	var age: float = _t - IMPACT_DELAY
	if age < 0.0:
		return
	var c: Vector2 = _k + Vector2(cos(hit_angle), sin(hit_angle)) * 7.0 * T
	if age < BURST_LIFE:
		var p: float = age / BURST_LIFE
		var reach: float = 2.0 + (3.0 if big else 2.0) * p
		for k in range(8):
			var ang: float = TAU * float(k) / 8.0 + 0.4
			var ln: float = reach if k % 2 == 0 else reach * 0.6
			var dir := Vector2(cos(ang), sin(ang))
			var r: float = 1.0
			while r <= ln + 0.01:
				FPD.px(self, c + dir * r * T, C_LAV, 1.0 - p)
				r += 1.0
		if p < 0.5:
			FPD.plus(self, c, C_WHITE, C_LAV, 1.0, 2 if big else 1)
	if age < RING_LIFE:
		var p2: float = age / RING_LIFE
		FPD.ring(self, c, 2.0 + (8.0 if big else 6.0) * p2, C_PALE if p2 < 0.4 else C_LAV, 1.0 - p2)
