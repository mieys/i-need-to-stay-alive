extends Node2D

## YİN YANG KİTABI ak küresi (yang, madde 334) - SALT görsel. Kara küre (yinyang_projectile.gd) hem kasterde hem uzak kopyada bunu kurar
## (iki-yer kuralı: aynı script, aynı zamanlama; kalkanın kendisi kasterde isabet anında verilir - YinYangBook.resolve_hit).
## 0 yükselme: kara küreyle birlikte kitaptan sarmal çizerek çıkar (YinYangBook.rise_offsets) -> 1 uçuş: tepede ayrılıp kalkanı alana
## (kendine: kısa sıçrayıp iner; dosta: sahibinden UZAK tarafa eğik yay; Yin: düşmana) -> 2 belde bir tur -> 3 parıltıya söner.

const YinYang := preload("res://scripts/yinyang_book.gd")
const ORBIT_TIME := 0.32
const ORBIT_RX := 9.0
const ORBIT_RY := 4.5
const SPARKLE_TIME := 0.3
const SPARKLES := 6

var start: Vector2 = Vector2.ZERO
var drift: Vector2 = Vector2.RIGHT
var rcp: Node2D = null ## kalkanı alan (oyuncu / kukla); null + enemy = Yin
var enemy: Node2D = null
var owner_node: Node2D = null ## kitabın sahibi (yay yönü)
var crit: bool = false

var _t: float = 0.0
var _phase: int = 0
var _t0: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _ctrl: Vector2 = Vector2.ZERO
var _dur: float = 0.3
var _last_dest: Vector2 = Vector2.ZERO
var _spr: Sprite2D = null
var _trail: Sprite2D = null
var _stars: Array = [] ## [Sprite2D, yön]


func _ready() -> void:
	z_index = YinYang.Z_FRONT
	_spr = Sprite2D.new()
	_spr.texture = YinYang.ORB_LIGHT
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * YinYang.WORLD_PX * (1.25 if crit else 1.0)
	add_child(_spr)
	global_position = start
	_last_dest = start
	_trail = YinYang.make_trail(self, YinYang.TRAIL_LIGHT)
	get_tree().create_timer(3.0, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _dest() -> Vector2:
	if is_instance_valid(rcp):
		_last_dest = rcp.global_position + YinYang.WAIST
	elif is_instance_valid(enemy) and enemy.get("is_dead") != true:
		_last_dest = enemy.global_position
	return _last_dest


func _begin_flight() -> void:
	_phase = 1
	_from = global_position
	var dest: Vector2 = _dest()
	var d: Vector2 = dest - _from
	if is_instance_valid(rcp) and rcp == owner_node:
		_ctrl = _from + Vector2(-6.0, -12.0) ## kendine: kısa sıçrayıp iner
	elif not is_instance_valid(rcp):
		_ctrl = _from + d * 0.4 + Vector2(0.0, -8.0) ## Yin: kara kürenin ardından düşmana
	else:
		var mid: Vector2 = (_from + dest) * 0.5
		var nv: Vector2 = Vector2(-d.y, d.x).normalized()
		var bow: float = maxf(12.0, d.length() * 0.25)
		var ca: Vector2 = mid + nv * bow
		var cb: Vector2 = mid - nv * bow
		if is_instance_valid(owner_node):
			var own: Vector2 = owner_node.global_position
			_ctrl = ca if ca.distance_to(own) > cb.distance_to(own) else cb ## sahibinin üstünden geçip "kendine dönüyor" gibi okunmasın
		else:
			_ctrl = ca if ca.y < cb.y else cb
	_dur = clampf(d.length() / YinYang.LIGHT_SPEED, YinYang.LIGHT_MIN, YinYang.LIGHT_MAX)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			var o: Array = YinYang.rise_offsets(_t, drift)
			global_position = start + (o[1] as Vector2)
			z_index = YinYang.Z_FRONT + (0 if float(o[2]) > 0.0 else 1) ## kara önündeyse altta
			if _t >= YinYang.RISE:
				_begin_flight()
		1:
			var u: float = clampf((_t - YinYang.RISE) / _dur, 0.0, 1.0)
			var e: float = u * u * (3.0 - 2.0 * u)
			var dest: Vector2 = _dest()
			var a: Vector2 = _from.lerp(_ctrl, e)
			var b: Vector2 = _ctrl.lerp(dest, e)
			global_position = a.lerp(b, e)
			z_index = YinYang.Z_FRONT
			if u >= 1.0:
				if is_instance_valid(rcp):
					_phase = 2
					_t0 = _t
				else:
					_start_sparkle(dest, 3)
		2:
			var k: float = clampf((_t - _t0) / ORBIT_TIME, 0.0, 1.0)
			var th: float = -PI * 0.5 + TAU * (k * k * (3.0 - 2.0 * k))
			var c: Vector2 = _dest()
			global_position = c + Vector2(cos(th) * ORBIT_RX, 2.0 + sin(th) * ORBIT_RY)
			z_index = YinYang.Z_FRONT if sin(th) > 0.0 else -1 ## arka yarıda karakterin arkasından geçer
			if k >= 1.0:
				_start_sparkle(c + Vector2(0.0, 2.0), SPARKLES)
		3:
			var k2: float = clampf((_t - _t0) / SPARKLE_TIME, 0.0, 1.0)
			var ek: float = 1.0 - pow(1.0 - k2, 3.0)
			for s in _stars:
				var sp: Sprite2D = s[0]
				var dir: Vector2 = s[1]
				sp.position = Vector2(dir.x * (4.0 + 8.0 * ek), dir.y * (2.0 + 4.0 * ek))
				sp.modulate.a = 1.0 - k2
				sp.scale = Vector2.ONE * YinYang.WORLD_PX * (1.0 - 0.5 * k2)
			if k2 >= 1.0:
				queue_free()


## Ak küre söner, yerinde krem yıldızlar dışa açılır (kalkan geldi / Yin'de düşmanda).
func _start_sparkle(at: Vector2, n: int) -> void:
	_phase = 3
	_t0 = _t
	global_position = at
	z_index = YinYang.Z_FRONT
	if is_instance_valid(_spr):
		_spr.visible = false
	if is_instance_valid(_trail):
		_trail.queue_free()
		_trail = null
	for i in range(n):
		var a: float = float(i) * TAU / float(n) + 0.3
		var sp := Sprite2D.new()
		sp.texture = YinYang.STAR
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2.ONE * YinYang.WORLD_PX
		add_child(sp)
		_stars.append([sp, Vector2(cos(a), sin(a))])
