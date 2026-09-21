extends Node2D

## Talon'un Ayna Formu (R): anime "öfke/süper form" tarzı dönüşüm. Turuncu-kırmızı pixel-art alev aurası + parıltı:
##  - dönüşüm anı: yukarı fırlayan ışık sütunu, genişleyen pixel şok halkası, dışa saçılan ışınlar, kısa beyaz parlama
##  - form boyunca: karakterin ARKASINDA yukarı yalayan sivri pixel alev sütunları (ortadakiler daha uzun), dither
##    ışıma ve yükselen kor; ÖNÜNDE gövdede/silahlarda rastgele beliren pixel "+" parıltıları
## Boyut %10 artışı (karakter + silahlar) player.gd/remote_player.gd'de (TalonFormationMath.FORM_SCALE_MULT);
## bu FX sadece görseldir. Player ya da RemotePlayer'ın ÇOCUĞU olarak doğar; ömrü ebeveynin form bayrağını izler
## (yerel: _talon_mirror_form_active, uzak: _talon_form_active - bkz. main.gd extra["talon_form"]).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const INTRO_TIME := 0.7
const FADE_OUT := 0.35
const NO_FLAG_GRACE := 2.0 ## uzak kopyada durum paketi gecikirse bayrak henüz true olmayabilir
const FLAME_COLUMNS := 13
const BODY_CENTER := Vector2(0, -4)

var _host: Node2D = null
var _t: float = 0.0
var _seen_on: bool = false
var _off_time: float = 0.0
var _closing: float = 0.0 ## 0 = açık, >0 = kapanıyor (sn)
var _embers: Array = [] ## [pos, vel, age, size]
var _sparks: Array = [] ## [pos, age, life, is_weapon]
var _spawn_acc: float = 0.0
var _front: Node2D = null


func _ready() -> void:
	show_behind_parent = true ## alev karakterin ARKASINDA (siblings: anim/silahlar sonra çizilir)
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	## Ön katman: parıltılar karakterin/silahların ÖNÜNDE. show_behind_parent'lı bu düğümün çocuğu olsaydı o da arkada
	## kalırdı - bu yüzden ebeveynin (karakterin) KARDEŞİ olarak eklenir (doğum anında ebeveyn meşgul: call_deferred).
	_front = Node2D.new()
	_front.z_index = 0
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.draw.connect(_draw_front)
	if _host != null:
		_host.add_child.call_deferred(_front)


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _flag_on() -> bool:
	if _host == null or not is_instance_valid(_host):
		return false
	if "_talon_mirror_form_active" in _host:
		return bool(_host._talon_mirror_form_active)
	if "_talon_form_active" in _host:
		return bool(_host._talon_form_active)
	return true


func _weapon_points() -> Array:
	var pts: Array = []
	if _host == null or not is_instance_valid(_host):
		return pts
	if "owned_weapon_nodes" in _host:
		for w in _host.owned_weapon_nodes:
			if is_instance_valid(w) and w.has_method("set_icon_offset"):
				pts.append((w as Node2D).global_position)
	elif "_weapon_icons" in _host:
		for ic in _host._weapon_icons:
			if is_instance_valid(ic):
				pts.append((ic as Node2D).global_position)
	return pts


func _process(delta: float) -> void:
	_t += delta
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	var on: bool = _flag_on()
	if on:
		_seen_on = true
		_off_time = 0.0
	else:
		_off_time += delta
	var should_close: bool = (_seen_on and _off_time > 0.4) or ((not _seen_on) and _t > NO_FLAG_GRACE)
	if should_close and _closing <= 0.0:
		_closing = 0.0001
	if _closing > 0.0:
		_closing += delta
		if _closing >= FADE_OUT:
			queue_free()
			return
	## Yükselen kor + parıltı üretimi
	if _closing <= 0.0:
		_spawn_acc += delta
		while _spawn_acc > 0.03:
			_spawn_acc -= 0.03
			var ex: float = randf_range(-24.0, 24.0)
			_embers.append([BODY_CENTER + Vector2(ex, randf_range(6.0, 28.0)), Vector2(randf_range(-14.0, 14.0), randf_range(-120.0, -60.0)), 0.0, randi_range(1, 2)])
		if randf() < delta * 14.0:
			_sparks.append([BODY_CENTER + Vector2(randf_range(-18.0, 18.0), randf_range(-26.0, 22.0)), 0.0, randf_range(0.25, 0.4), false])
		if randf() < delta * 10.0:
			var wp: Array = _weapon_points()
			if not wp.is_empty():
				var w: Vector2 = wp[randi() % wp.size()]
				_sparks.append([w - _host.global_position + Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)), 0.0, randf_range(0.25, 0.4), true])
	for e in _embers:
		e[2] += delta
		e[0] += e[1] * delta
	_embers = _embers.filter(func(e): return float(e[2]) < 0.75)
	for s in _sparks:
		s[1] += delta
	_sparks = _sparks.filter(func(s): return float(s[1]) < float(s[2]))
	queue_redraw()
	_front.queue_redraw()


func _open_factor() -> float:
	if _closing > 0.0:
		return clampf(1.0 - _closing / FADE_OUT, 0.0, 1.0)
	return clampf(_t / 0.25, 0.0, 1.0)


## --- ARKA KATMAN: ışık sütunu, dither ışıma, alev sütunları, kor ---
func _draw() -> void:
	var open: float = _open_factor()
	if open <= 0.0:
		return
	var texel: float = PixelDraw.TEXEL
	## Dönüşüm sütunu: ilk INTRO_TIME'da yukarı fırlar (dither sarı-beyaz)
	if _t < INTRO_TIME:
		var pk: float = _t / INTRO_TIME
		var col_h: float = 130.0 * minf(1.0, pk * 3.0)
		var half_w: int = int(6.0 * (1.0 - pk) + 2.0)
		for iy in range(0, int(col_h / texel)):
			var y: float = 26.0 - float(iy) * texel
			for ix in range(-half_w, half_w + 1):
				if ((ix + iy + int(_t * 30.0)) & 1) == 0:
					PixelDraw.px(self, Vector2(float(ix) * texel, y) + Vector2(0, BODY_CENTER.y), 1, Color(1.0, 0.92, 0.55, 1.0 - pk))
	## Dither ışıma (iki halka)
	var flick: int = int(_t * 12.0)
	PixelDraw.disc_dither(self, BODY_CENTER, 50.0 * open, Color(1.0, 0.42, 0.06, 0.55), flick, 2)
	PixelDraw.disc_dither(self, BODY_CENTER, 32.0 * open, Color(1.0, 0.8, 0.25, 0.6), flick + 1, 2)
	## Alev sütunları (Süper form aurası: gövdeden geniş, başın üstünde sivri "saç" alevleri). Karakterin ARKASINDA çizildiği
	## için gövdeyi aşan geniş yayılım ve yükseklik şart (orta sütunlar sadece kafanın üstünde görünür).
	for layer in range(2):
		var cols: int = FLAME_COLUMNS * 2 - 1 if layer == 0 else FLAME_COLUMNS
		for i in range(cols):
			var u: float = (float(i) / float(cols - 1)) * 2.0 - 1.0 ## -1..1
			var x0: float = u * 40.0
			var centre_boost: float = 1.0 - pow(absf(u), 1.6)
			var shrink: float = 1.0 if layer == 0 else 0.62
			var h: float = (26.0 + 46.0 * centre_boost + 10.0 * sin(_t * 9.0 + float(i) * 1.7) + 7.0 * sin(_t * 15.0 + float(i) * 0.9)) * open * shrink
			var rows: int = int(h / texel)
			for r in range(rows):
				var k: float = float(r) / maxf(float(rows), 1.0)
				var width: int = maxi(1, int(round(4.0 * (1.0 - k) + 0.5)))
				var sway: float = sin(_t * 8.0 + float(i) + float(r) * 0.22) * k * texel * 3.0
				var pos := Vector2(x0 + sway - u * k * 12.0, 26.0 - float(r) * texel)
				var heat: float = k * 0.85 if layer == 0 else 0.02 + k * 0.5 ## iç katman sarı-beyaz çekirdek
				PixelDraw.px(self, pos, width if layer == 0 else maxi(1, width - 1), PixelDraw.fire_color(heat))
	for e in _embers:
		var k2: float = float(e[2]) / 0.75
		PixelDraw.px(self, e[0], int(e[3]) if k2 < 0.6 else 1, PixelDraw.fire_color(0.05 + k2 * 0.85))


## --- ÖN KATMAN: dönüşüm şok halkası + ışınlar + beyaz parlama + pixel "+" parıltılar ---
func _draw_front() -> void:
	var open: float = _open_factor()
	var texel: float = PixelDraw.TEXEL
	if _t < INTRO_TIME:
		var pk: float = _t / INTRO_TIME
		## şok halkası (turuncu -> kırmızı)
		PixelDraw.ring(_front, BODY_CENTER, 8.0 + pk * 96.0, PixelDraw.fire_color(pk), 2, 0, 0, 0.0)
		PixelDraw.ring(_front, BODY_CENTER, 4.0 + pk * 70.0, PixelDraw.fire_color(pk * 0.6), 1, 3, 3, _t * 20.0)
		## dışa saçılan 12 ışın
		for k in range(12):
			var a: float = float(k) * TAU / 12.0 + 0.2
			var r0: float = 20.0 + pk * 40.0
			var r1: float = r0 + 26.0 * (1.0 - pk)
			PixelDraw.line(_front, BODY_CENTER + Vector2(cos(a), sin(a)) * r0, BODY_CENTER + Vector2(cos(a), sin(a)) * r1, PixelDraw.fire_color(0.15 + pk * 0.5), 1)
		## ilk 0.12sn beyaz parlama (dither)
		if _t < 0.12:
			PixelDraw.disc_dither(_front, BODY_CENTER, 46.0, Color(1.0, 0.97, 0.8, 0.85), int(_t * 60.0), 2)
	for s in _sparks:
		var k: float = float(s[1]) / float(s[2])
		## + biçimli parıltı: ortada 1, kollar 1 -> büyüyüp söner
		var big: bool = k > 0.25 and k < 0.75
		var col: Color = Color(1.0, 0.97, 0.75) if not bool(s[3]) else Color(1.0, 0.85, 0.4)
		var p: Vector2 = s[0]
		PixelDraw.px(_front, p, 1, col)
		if big:
			PixelDraw.px(_front, p + Vector2(texel * 2.0, 0), 1, col)
			PixelDraw.px(_front, p - Vector2(texel * 2.0, 0), 1, col)
			PixelDraw.px(_front, p + Vector2(0, texel * 2.0), 1, col)
			PixelDraw.px(_front, p - Vector2(0, texel * 2.0), 1, col)
	## Elektrik: gövdenin iki yanında kısa sarı zikzaklar (0.09sn'de bir yeniden çıkar)
	if open > 0.5 and _t > 0.3:
		var seed_i: int = int(_t * 11.0)
		for z in range(2):
			var side: float = -1.0 if z == 0 else 1.0
			var base := BODY_CENTER + Vector2(side * (16.0 + PixelDraw.hash01(seed_i * 3 + z) * 8.0), PixelDraw.hash01(seed_i * 5 + z + 9) * 40.0 - 22.0)
			var prev: Vector2 = base
			for step in range(4):
				var nxt := prev + Vector2((PixelDraw.hash01(seed_i * 7 + z * 13 + step) - 0.5) * 12.0 * side + side * 3.0, -7.0 - PixelDraw.hash01(seed_i + step * 5 + z) * 5.0)
				PixelDraw.line(_front, prev, nxt, Color(1.0, 0.96, 0.55), 1)
				prev = nxt
	## Gövde kenarında dönen 4 parlak piksel (sürekli "parıldıyor" hissi)
	if open > 0.5:
		for k in range(4):
			var a2: float = _t * 2.2 + float(k) * TAU / 4.0
			PixelDraw.px(_front, BODY_CENTER + Vector2(cos(a2) * 20.0, sin(a2) * 30.0), 1, Color(1.0, 0.85, 0.4))
