extends Node2D

## Peri'nin can basma büyüsü efekti (2026-10-13, kullanıcı: "peri'nin iyileştirme animasyonu yok ve efekti de yok" - eskiden sadece
## Melek pasifinin iki küçük artısı çıkıyordu, oyunda fark edilmiyordu). Üç parça, ~1,3 sn, tek seferlik, kozmetik:
##  1. Asanın yıldızından sahibin göğsüne yay çizerek uçan yeşil-beyaz ışık taneleri (kuyruklu).
##  2. Taneler varınca göğüste küçük parıltı + ayaklardan başa yükselen, dönen noktalı elips halka.
##  3. Gövdenin çevresinde yükselip sönen artılar (iki boy).
## Sahibin (karakter kökü) çocuğu: karakterle birlikte hareket eder. Bütün noktalar ebeveynin YEREL uzayında; piksel boyu `u`
## perinin kendi pikseliyle aynı (peri_pet.gd verir). Sahibin ekranında da kuklada da peri_pet.gd _play_cast kurar - ağ olayı
## zaten NetworkManager.broadcast_peri (ayrı RPC gerekmez).

const LIFE := 1.3
const MOTES := 6
const MOTE_GAP := 0.045
const MOTE_TIME := 0.32
const LAND := 0.28 ## ilk tanenin varışı: halka + artılar buradan sonra
const RING_TIME := 0.75
const RING_DOTS := 10
const PLUS_TIME := 0.8
const PLUSES := [[-9.0, 0.0, 2], [8.0, 0.12, 2], [-3.0, 0.24, 1], [11.0, 0.3, 1], [-12.0, 0.38, 1], [3.0, 0.44, 2]] ## [x, gecikme, kol boyu]
const C_ARM := Color(0.47, 0.92, 0.55)
const C_DARK := Color(0.22, 0.63, 0.28)
const C_CORE := Color(0.94, 1.0, 0.94)

var _t: float = 0.0
var _from := Vector2.ZERO
var _feet := Vector2.ZERO
var _head := Vector2(0.0, -40.0)
var _u: float = 1.5


func setup(from: Vector2, feet: Vector2, head: Vector2, u: float) -> void:
	_from = from
	_feet = feet
	_head = head
	_u = maxf(0.5, u)


func _ready() -> void:
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _dot(p: Vector2, n: int, col: Color) -> void:
	var s: float = float(n) * _u
	draw_rect(Rect2((p / _u).round() * _u - Vector2(s, s) * 0.5, Vector2(s, s)), col)


func _plus(c: Vector2, arm: int, a: float) -> void:
	var col := Color(C_ARM.r, C_ARM.g, C_ARM.b, a)
	for k in range(1, arm + 1):
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			_dot(c + d * float(k) * _u, 1, col)
	_dot(c, 1, Color(C_CORE.r, C_CORE.g, C_CORE.b, a))


func _draw() -> void:
	var chest: Vector2 = _feet.lerp(_head, 0.5)
	## 1. asadan göğse uçan taneler
	for i in MOTES:
		var tt: float = (_t - float(i) * MOTE_GAP) / MOTE_TIME
		if tt <= 0.0 or tt >= 1.0:
			continue
		var ctrl: Vector2 = _from.lerp(chest, 0.5) + Vector2(0.0, -(10.0 + float(i % 3) * 4.0) * _u)
		for k in 3: ## baş + iki kuyruk
			var q: float = tt - float(k) * 0.07
			if q <= 0.0:
				continue
			var p: Vector2 = _from.lerp(ctrl, q).lerp(ctrl.lerp(chest, q), q)
			_dot(p, 2 if k == 0 else 1, C_CORE if k == 0 else (C_ARM if k == 1 else Color(C_DARK.r, C_DARK.g, C_DARK.b, 0.7)))
	## 2a. varış parıltısı
	var ft: float = (_t - LAND) / 0.2
	if ft > 0.0 and ft < 1.0:
		_plus(chest, 2 + int(ft * 3.0), 1.0 - ft)
	## 2b. yükselen halka
	var rt: float = (_t - LAND) / RING_TIME
	if rt > 0.0 and rt < 1.0:
		var c: Vector2 = _feet.lerp(_head, rt)
		var a: float = sin(rt * PI)
		for i in RING_DOTS:
			var ang: float = TAU * float(i) / float(RING_DOTS) + _t * 5.0
			var front: bool = sin(ang) > 0.0
			var col: Color = C_ARM if front else C_DARK
			_dot(c + Vector2(cos(ang) * 10.0, sin(ang) * 3.5) * _u, 1, Color(col.r, col.g, col.b, a * (1.0 if front else 0.6)))
	## 3. yükselen artılar
	for p: Array in PLUSES:
		var pt: float = (_t - LAND - float(p[1])) / PLUS_TIME
		if pt <= 0.0 or pt >= 1.0:
			continue
		_plus(chest + Vector2(float(p[0]), 6.0 - pt * 20.0) * _u, int(p[2]), sin(pt * PI))
