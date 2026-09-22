extends Node2D

## Oakley'in Koruyucu Büyü'sü (R, skill3 id 39) - büyüyü ALAN kişinin etrafında görünen YEŞİL KORUYUCU YAPRAK BARİYERİ (kullanıcı isteği,
## 2026-09-21: "R'si aktifken etrafında yeşil koruyucu yapraklar içeren bir koruma bariyeri görünmeli, ve bu kalkana sahip kişi her hasar
## aldığında üstünde yeşil parçalar çıkmalı"). Pixel tarzı (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - yarı saydam yeşil dither küre + kesikli dönen kenar halkası
##  - kenarda yavaşça dönen 12 pixel yaprak (teğet yönde dizili, hafifçe salınır)
##  - hasar alınca (hit()): yeşil yaprak/kırık parçaları dışa saçılır, küre kısa süre parlar
## Player'ın (büyüyü alan kişi) YA DA RemotePlayer kuklasının ÇOCUĞU: ömrü ebeveynin bayrağını izler - yerelde oakley_bond_active, uzakta
## _oakley_bond_on (bkz. main.gd extra["oakley_bond"], remote_player.gd). Uzak kuklada "hasar aldı" bilgisi sağlık+kalkan düşüşünden
## anlaşılır (yerelde player.gd take_damage hit()'i doğrudan çağırır) - iki taraf AYNI sahneyi/çizimi kullanır.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const BODY_CENTER := Vector2(0, -4)
const RADIUS := 35.0
const LEAF_COUNT := 10
const OPEN_TIME := 0.4
const CLOSE_TIME := 0.35
const NO_FLAG_GRACE := 2.0 ## uzak kopyada durum paketi gecikirse bayrak henüz true olmayabilir

const C_OUT := Color(0.07, 0.22, 0.09, 1.0)
const C_DARK := Color(0.16, 0.45, 0.16, 1.0)
const C_MID := Color(0.33, 0.72, 0.25, 1.0)
const C_LIGHT := Color(0.66, 0.95, 0.42, 1.0)

var _host: Node2D = null
var _t: float = 0.0
var _seen_on: bool = false
var _off_time: float = 0.0
var _closing: float = -1.0
var _pulse: float = 0.0
var _pieces: Array = [] ## [pos, vel, age, life, size, kind]
var _last_total: float = -1.0
var _is_puppet: bool = false


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_is_puppet = _host != null and not _host.is_in_group("player")


func _flag_on() -> bool:
	if _host == null or not is_instance_valid(_host):
		return false
	if "oakley_bond_active" in _host:
		return bool(_host.oakley_bond_active)
	if "_oakley_bond_on" in _host:
		return bool(_host._oakley_bond_on)
	return true


## Hasar alındı: yeşil parçalar saçılır (yerel: player.gd take_damage, uzak: sağlık/kalkan düşüşü).
func hit() -> void:
	_pulse = 0.3
	for i in range(14):
		var a: float = randf() * TAU
		var speed: float = randf_range(35.0, 95.0)
		_pieces.append([BODY_CENTER + Vector2(cos(a), sin(a)) * RADIUS * 0.9, Vector2(cos(a), sin(a)) * speed + Vector2(0, -20.0), 0.0, randf_range(0.35, 0.6), randi_range(1, 2), i % 3])


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta)
	var on: bool = _flag_on()
	if on:
		_seen_on = true
		_off_time = 0.0
	else:
		_off_time += delta
	var should_close: bool = (_seen_on and _off_time > 0.3) or ((not _seen_on) and _t > NO_FLAG_GRACE)
	if should_close and _closing < 0.0:
		_closing = 0.0
		for i in range(10):
			var a: float = float(i) * TAU / 10.0
			_pieces.append([BODY_CENTER + Vector2(cos(a), sin(a)) * RADIUS, Vector2(cos(a), sin(a)) * randf_range(20.0, 55.0), 0.0, randf_range(0.4, 0.7), 2, i % 3])
	if _closing >= 0.0:
		_closing += delta
		if _closing >= CLOSE_TIME and _pieces.is_empty():
			queue_free()
			return
	## Uzak kuklada hasar tespiti: sağlık + kalkan toplamı düştüyse hit().
	if _is_puppet and _host != null and is_instance_valid(_host) and "health" in _host:
		var total: float = float(_host.health) + (float(_host.item_shield_hp) if "item_shield_hp" in _host else 0.0)
		if _last_total >= 0.0 and total < _last_total - 0.01:
			hit()
		_last_total = total
	for p in _pieces:
		p[2] += delta
		p[0] += p[1] * delta
		p[1] = (p[1] as Vector2) * (1.0 - clampf(3.0 * delta, 0.0, 1.0)) + Vector2(0, 40.0) * delta
	_pieces = _pieces.filter(func(p): return float(p[2]) < float(p[3]))
	queue_redraw()


func _open_factor() -> float:
	if _closing >= 0.0:
		return clampf(1.0 - _closing / CLOSE_TIME, 0.0, 1.0)
	return clampf(_t / OPEN_TIME, 0.0, 1.0)


## Teğet yönde dizili pixel yaprak (8 texel boy, orta damarlı): koyu hat + parlak damar + orta/koyu iki yarı ton.
func _draw_leaf(pos: Vector2, tangent: Vector2, normal: Vector2, alpha: float) -> void:
	var t: float = PixelDraw.TEXEL * 0.9
	var half_widths: Array = [0, 1, 2, 2, 2, 1, 1, 0]
	for k in range(half_widths.size()):
		var w: int = half_widths[k]
		var along: Vector2 = pos + tangent * t * float(k)
		for j in range(-w, w + 1):
			var edge: bool = (absi(j) == w and w > 0) or k == 0 or k == half_widths.size() - 1
			var col: Color = C_OUT if edge else (C_LIGHT if j == 0 else (C_MID if j < 0 else C_DARK))
			PixelDraw.px(self, along + normal * t * float(j), 1, Color(col.r, col.g, col.b, alpha))


func _draw() -> void:
	var open: float = _open_factor()
	var bright: float = 1.0 + (_pulse / 0.3) * 0.9
	if open > 0.0:
		var r: float = RADIUS * open
		## Yarı saydam yeşil küre + kesikli kenar
		PixelDraw.disc_dither(self, BODY_CENTER, r * 0.96, Color(0.42, 0.9, 0.42, minf(0.3, 0.16 * bright)), int(_t * 6.0), 1)
		PixelDraw.ring(self, BODY_CENTER, r, Color(0.55, 0.98, 0.5, minf(1.0, 0.75 * bright) * open), 1, 5, 1, _t * 9.0)
		PixelDraw.ring(self, BODY_CENTER, r - 3.0, Color(0.7, 1.0, 0.6, 0.3 * open), 1, 2, 4, -_t * 12.0)
		## Dönen yapraklar (elips yörünge, sırayla hafif salınım)
		for i in range(LEAF_COUNT):
			var a: float = _t * 0.6 + float(i) * TAU / float(LEAF_COUNT)
			var bob: float = 1.0 + 0.06 * sin(_t * 2.4 + float(i) * 1.3)
			var pos: Vector2 = BODY_CENTER + Vector2(cos(a) * r * bob, sin(a) * r * 0.86 * bob)
			var tangent: Vector2 = Vector2(-sin(a), cos(a) * 0.86).normalized()
			var normal: Vector2 = Vector2(cos(a), sin(a) * 0.86).normalized()
			var front: bool = sin(a) > 0.0
			_draw_leaf(pos, tangent, normal, (1.0 if front else 0.75) * open)
	## Hasar / kapanış parçaları
	for p in _pieces:
		var k: float = float(p[2]) / float(p[3])
		var fade: float = 1.0 - k
		var col: Color = C_LIGHT if int(p[5]) == 0 else (C_MID if int(p[5]) == 1 else C_DARK)
		PixelDraw.px(self, p[0], int(p[4]), Color(col.r, col.g, col.b, 0.95 * fade))
		if int(p[5]) == 0 and k < 0.6:
			PixelDraw.px(self, (p[0] as Vector2) + Vector2(PixelDraw.TEXEL, 0), 1, Color(C_OUT.r, C_OUT.g, C_OUT.b, 0.8 * fade))
