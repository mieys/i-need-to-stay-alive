extends Node2D

## Melek'in R'si (Kutsal Korku, skill3 id 32) parıltısı: karakterin (ve can/kalkan bağı kurduğu dostun) etrafında güçlü, sarı,
## pixel-art kutsal ışık. Katmanlar (hepsi pixel_draw.gd ızgarasında):
##   ARKA : dönen/nabız atan 14 altın ışık ışını + dither ışıma (iki halka)
##   ÖN   : ilk 0.12sn beyaz-altın parlama, korku yarıçapına genişleyen kesikli pixel şok halkası (MELEK_FEAR_RADIUS ile aynı),
##          başın üstünde parlayan pixel halo, yükselen altın "+" parıltılar
## Karakterin (Player) ya da diğer istemcideki kuklanın (RemotePlayer) ÇOCUĞU olarak doğar: Melek'te _play_and_broadcast_skill_fx,
## bağlı dostta _set_ally_aura(ally, "holy") ile (yerel + ağ). Tek seferliktir, kendini siler.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

## player.gd MELEK_FEAR_RADIUS bunu okur (tek kaynak): korkunun etki yarıçapı = şok halkasının yarıçapı.
const RADIUS := 260.0
const LIFE := 1.5
const BODY_CENTER := Vector2(0, -4)

const GOLD := Color(1.0, 0.82, 0.22)
const GOLD_LIGHT := Color(1.0, 0.95, 0.6)
const GOLD_DEEP := Color(0.95, 0.6, 0.1)
const WHITE_GOLD := Color(1.0, 0.99, 0.85)

var _host: Node2D = null
var _t: float = 0.0
var _front: Node2D = null
var _sparkles: Array = [] ## [pos, age, life]
var _spawn_acc: float = 0.0


func _ready() -> void:
	show_behind_parent = true
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_front = Node2D.new()
	_front.z_index = 0
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.draw.connect(_draw_front)
	if _host != null:
		_host.add_child.call_deferred(_front) ## ön katman ebeveynin KARDEŞİ (bkz. fx_talon_form.gd aynı gerekçe)


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _envelope() -> float:
	## 0->1 (0.15sn), sonra 1, son 0.4sn'de 1->0
	return clampf(minf(_t / 0.15, (LIFE - _t) / 0.4), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE or _host == null or not is_instance_valid(_host):
		queue_free()
		return
	_spawn_acc += delta
	while _spawn_acc > 0.035 and _t < LIFE - 0.4:
		_spawn_acc -= 0.035
		_sparkles.append([BODY_CENTER + Vector2(randf_range(-38.0, 38.0), randf_range(-34.0, 30.0)), 0.0, randf_range(0.4, 0.75)])
	for s in _sparkles:
		s[1] += delta
		s[0] += Vector2(0, -22.0) * delta
	_sparkles = _sparkles.filter(func(s): return float(s[1]) < float(s[2]))
	queue_redraw()
	if _front != null:
		_front.queue_redraw()


func _draw() -> void:
	var env: float = _envelope()
	if env <= 0.0:
		return
	var texel: float = PixelDraw.TEXEL
	## Dither ışıma: dıştaki altın, içteki beyaz-altın; her 0.08sn'de dama deseni yer değiştirir (parıldama)
	var flick: int = int(_t * 12.0)
	PixelDraw.disc_dither(self, BODY_CENTER, 44.0 * env, Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, 0.6), flick, 2)
	PixelDraw.disc_dither(self, BODY_CENTER, 28.0 * env, Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.7), flick + 1, 2)
	## 14 ışın: dönerken uzunlukları nabız atar
	for k in range(14):
		var a: float = float(k) * TAU / 14.0 + _t * 0.7
		var d: Vector2 = Vector2(cos(a), sin(a))
		var pulse: float = 0.5 + 0.5 * sin(_t * 9.0 + float(k) * 1.3)
		var length: float = (34.0 + 40.0 * pulse) * env
		var thick: int = 2 if k % 2 == 0 else 1
		PixelDraw.line(self, BODY_CENTER + d * 20.0, BODY_CENTER + d * (20.0 + length * 0.5), WHITE_GOLD if k % 2 == 0 else GOLD_LIGHT, thick)
		PixelDraw.line(self, BODY_CENTER + d * (20.0 + length * 0.5), BODY_CENTER + d * (20.0 + length), GOLD if k % 2 == 0 else GOLD_DEEP, 1)


func _draw_front() -> void:
	var env: float = _envelope()
	var texel: float = PixelDraw.TEXEL
	## İlk anda güçlü beyaz-altın parlama (dither)
	if _t < 0.12:
		PixelDraw.disc_dither(_front, BODY_CENTER, 54.0, Color(1.0, 0.98, 0.8, 0.9), int(_t * 60.0), 2)
	## Korku yarıçapına genişleyen kesikli şok halkası (+ silik yankısı)
	var rk: float = _t / 0.65
	if rk < 1.0:
		var e: float = 1.0 - (1.0 - rk) * (1.0 - rk)
		var dash_off: int = 3 + int(rk * 16.0)
		PixelDraw.ring(_front, BODY_CENTER, RADIUS * e, GOLD, 2, 8, dash_off, _t * 24.0)
		PixelDraw.ring(_front, BODY_CENTER, RADIUS * e * 0.86, GOLD_LIGHT, 1, 3, dash_off + 3, -_t * 30.0)
	## Halo: başın üstünde parlayan pixel elips (Melek = melek)
	if env > 0.0:
		var hp: Vector2 = BODY_CENTER + Vector2(0, -36.0)
		for i in range(28):
			var ha: float = float(i) * TAU / 28.0
			var col: Color = WHITE_GOLD if (i + int(_t * 14.0)) % 5 == 0 else GOLD
			PixelDraw.px(_front, hp + Vector2(cos(ha) * 15.0, sin(ha) * 5.0), 1, col)
	## Yükselen altın "+" parıltılar
	for s in _sparkles:
		var k: float = float(s[1]) / float(s[2])
		var p: Vector2 = s[0]
		var col2: Color = WHITE_GOLD if k < 0.5 else GOLD
		PixelDraw.px(_front, p, 1, col2)
		if k > 0.15 and k < 0.8:
			for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				PixelDraw.px(_front, p + o * texel, 1, col2)
