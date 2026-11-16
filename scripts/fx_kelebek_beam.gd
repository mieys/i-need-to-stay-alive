extends Node2D

## Kelebek Ruhu'nun IŞINI (2026-11-15, kullanıcı: "ışınla değiştir", 2026-10-12 prototipindeki "1 Işın: anında ince pembe çizgi, 3 karede
## söner" seçeneği - tools/proto_20261012/gen_peri_pet_v2.py orb_scene mode 'isin', birebir). Eskiden hedefe uçan "ruh kıvılcımı" mermisiydi.
## Ağızdan hedefe 1 sanat pikseli kalınlığında düz çizgi (piksel ızgarasında, Bresenham yuvarlaması), FRAME sn'lik 3 kare:
##  0: çekirdek renk (beyaz-pembe) çizgi + büyük yıldız (kollar 2 px)   1: pembe çizgi + küçük yıldız (kollar 1 px)
##  2: her 3. piksel koyu pembe (sönen iz)
## Düğüm DÖNMEZ: ölçeği 1 sanat pikseli (sahibin karakter pikseli); iki uç her karede izlenir (kelebek ağzı + canlı hedef).
## Hasar BURADA DEĞİL: ilk karede on_hit çağrılır (kelebek_ruhu.gd _deal; kukla ekranında boş). API eski mermiyle aynı (launch).

const FRAME := 0.08 ## prototip GIF'inin kare süresi
const FRAMES := 3
const LASER: Array[Color] = [Color8(255, 248, 252), Color8(255, 132, 192), Color8(196, 62, 134)] ## çekirdek, pembe, koyu pembe
const ARMS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]

var source: Node2D = null ## ağzı izlenen düğüm (muzzle() yöntemi); yoksa başlangıç noktası sabit
var _target: Node2D = null
var _dest: Vector2 = Vector2.ZERO
var _on_hit: Callable = Callable()
var _hit_done: bool = false
var _t: float = 0.0
var _end: Vector2 = Vector2.ZERO ## hedef ucu, yerel sanat pikseli (yuvarlanmış)
var _frame: int = 0
var _key: Array = []


func _ready() -> void:
	top_level = true
	z_index = 60 ## eski mermiyle / fx_matthew_bolt.gd ile aynı katman (yaratıkların üstünde)


## px = 1 sanat pikselinin dünya boyu (sahibin karakter pikseli).
func launch(from: Vector2, target: Node2D, dest: Vector2, px: float, on_hit: Callable) -> void:
	_target = target
	_dest = dest
	_on_hit = on_hit
	global_position = from
	scale = Vector2(px, px)
	_update_end()


func _process(delta: float) -> void:
	if not _hit_done:
		## "Anında": ilk işlenen karede (silah vuruşu canı düşürdükten sonra) hasar.
		_hit_done = true
		if _on_hit.is_valid():
			_on_hit.call(_target if is_instance_valid(_target) else null)
	else:
		_t += delta
	_frame = int(_t / FRAME)
	if _frame >= FRAMES:
		queue_free()
		return
	if is_instance_valid(source) and source.has_method("muzzle"):
		global_position = source.muzzle()
	if is_instance_valid(_target) and _target.get("is_dead") != true:
		_dest = _target.global_position
	_update_end()
	var key: Array = [_end, _frame]
	if key != _key:
		_key = key
		queue_redraw()


func _update_end() -> void:
	_end = ((_dest - global_position) / maxf(0.001, absf(scale.x))).round()


func _px(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p.x - 0.5, p.y - 0.5, 1.0, 1.0), col)


func _draw() -> void:
	if _frame < 0 or _frame >= FRAMES:
		return ## süre doldu (queue_free bekliyor), sıradaki çizim boş
	var n: int = int(maxf(absf(_end.x), absf(_end.y)))
	var x_major: bool = absf(_end.x) >= absf(_end.y)
	if _frame == 2:
		for i in range(0, n + 1, 3):
			_px((_end * (float(i) / maxf(1.0, float(n)))).round(), LASER[2])
		return
	## Düz çizgi: ana eksen boyunca aynı yan koordinattaki pikseller tek dikdörtgen (Bresenham koşuları).
	var col: Color = LASER[_frame]
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = a
	for i in range(1, n + 2):
		var p: Vector2 = (_end * (float(i) / float(n))).round() if i <= n else Vector2(INF, INF)
		if i <= n and ((p.y == a.y) if x_major else (p.x == a.x)):
			b = p
			continue
		if x_major:
			draw_rect(Rect2(minf(a.x, b.x) - 0.5, a.y - 0.5, absf(b.x - a.x) + 1.0, 1.0), col)
		else:
			draw_rect(Rect2(a.x - 0.5, minf(a.y, b.y) - 0.5, 1.0, absf(b.y - a.y) + 1.0), col)
		a = p
		b = p
	## İsabet yıldızı (prototip spark): 1. halka pembe, 2. halka koyu pembe (yalnız büyükte), merkez çekirdek.
	for d: Vector2 in ARMS:
		_px(_end + d, LASER[1])
		if _frame == 0:
			_px(_end + d * 2.0, LASER[2])
	_px(_end, LASER[0])
