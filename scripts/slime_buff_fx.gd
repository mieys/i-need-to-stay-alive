extends Node2D

## Minik Cadı büyüsü AKTİFKEN karakterin görünüşü (kullanıcı 2026-11-09: "yetenek aktifken karakterde hiçbir şey değişmiyor gibi
## görünüyor, bufflandığı ve güçlendiği belli olmalı", madde 523). Gövdeye (yerel Player ya da uzak kukla) eklenen TEK düğüm "SlimeBuffFx";
## fx_slime_spell.gd büyü küresi göğse varınca start_on() ile kurar / yeniler - iki ekranda da aynı yerden (ek RPC yok):
##  - Varış: karakterin dolu pembe silüeti büyüyerek söner (güç dalgası) + bir demet yükselen ok.
##  - Süre boyunca: karakterin O ANKİ karesinin kopyası + shaders/slime_buff_outline.gdshader -> pembe dış hat + soluk ikinci halka,
##    kayan krem parıltı bandı, hafif nabız; gövdenin yanlarından yükselen pembe oklar + yıldızlar (statlar arttı); ayakta PULSE_INTERVAL'de
##    bir genişleyen pembe elips (karakterin ALTINDA, z -1 çocuk).
##  - Son END_BLINK sn dış hat yanıp söner, ok çıkmaz (bitiş okunur); bitince FADE_TIME'da söner.
## Süre: sahibin ekranında player.gd slime_buff_active() / _slime_buff_timer (buff bitince, yere düşünce düğüm söner); kuklada kendi sayacı.
## Saydamlık: karakterin self_modulate alfası (çalı / Hayalet örtüsü) her karede kopyalanır - çalıda saklanan oyuncunun yeri dış hattan
## okunmasın. Görünmezlik kök modulate'te: çocuk olduğu için kendiliğinden miras.
## Pikseller karakterin sanat pikseli ızgarasında (u = |anim.scale.x|, buffın +%15 boyu dahil).

const OUTLINE_SHADER: Shader = preload("res://shaders/slime_buff_outline.gdshader")
const NODE_NAME := "SlimeBuffFx"
const END_BLINK := 1.0
const BLINK_HZ := 8.0
const FADE_TIME := 0.2
const SURGE_TIME := 0.45
const SURGE_GROW := 0.4 ## silüet bu kadar büyüyerek söner
const SURGE_ALPHA := 0.85
const BURST_MOTES := 6 ## varışta aynı anda çıkan ok/yıldız
const MOTE_INTERVAL := 0.17
const MOTE_LIFE := 0.85
const MOTE_RISE := 18.0 ## sanat pikseli
const PULSE_INTERVAL := 1.3
const PULSE_TIME := 0.6
const PULSE_R0 := 7.0
const PULSE_R1 := 18.0
const FEET_ART_Y := 40.0
const FRAME_HALF := 24.0
## Kare merkezinden gövde merkezine (karakter pikseli; assasin_passive_fx.gd ile aynı): ayak satırı 40, baş ~2.
const BODY_CENTER := Vector2(0.0, -3.0)
const C_CREAM := Color(1.0, 0.957, 0.98)
const C_PINK := Color(1.0, 0.44, 0.73)
const C_PINK_L := Color(1.0, 0.67, 0.85)
const C_DEEP := Color(0.8, 0.2, 0.56)
## Yükselen ok (5x5): c krem, p pembe, d koyu pembe kenar.
const ARROW := ["..c..", ".pcp.", "ppcpp", ".dpd.", ".dpd."]
const STAR := ["..p..", ".pcp.", "..p.."]


class Ground extends Node2D:
	var fx: Node2D = null
	func _draw() -> void:
		if fx != null:
			fx.draw_ground(self)


var _sprite: AnimatedSprite2D = null
var _outline: Sprite2D = null
var _surge: Sprite2D = null
var _ground: Ground = null
var _time_left: float = 0.0
var _t: float = 0.0 ## kurulduğundan beri
var _surge_t: float = -1.0 ## >= 0: güç dalgası oynuyor
var _mote_timer: float = 0.0
var _motes: Array[Dictionary] = [] ## {x, y0 (gövde merkezine göre sanat pikseli), age, kind (0 ok, 1 yıldız)}
var _ending: bool = false
var _fade: float = 1.0


## Gövdenin buff süresi kadar kurar / yeniler (varış anı: güç dalgası + ok demeti).
func refresh(duration: float) -> void:
	_time_left = duration
	_ending = false
	_fade = 1.0
	_ensure_parts()
	_surge_t = 0.0
	_mote_timer = MOTE_INTERVAL
	for i in range(BURST_MOTES):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_spawn_mote(side * randf_range(6.0, 13.0), randf_range(-2.0, 12.0), i % 3 == 2, -randf_range(0.0, 0.18))


func time_left() -> float:
	return _time_left


func is_ending() -> bool:
	return _ending


## Buff bitti (player.gd _end_slime_buff) ya da sahip düştü: kısa sönme, sonra silinir.
func finish() -> void:
	if _ending:
		return
	_ending = true
	name = NODE_NAME + "End" ## aynı karede yeni büyü gelirse yeni düğüm asıl adı alabilsin


func outline_texture() -> Texture2D:
	return _outline.texture if _outline != null else null


func motes_alive() -> int:
	return _motes.size()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_parts()


func _ensure_parts() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		var body: Node = get_parent()
		_sprite = body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if body != null else null
	if _outline == null:
		_outline = _copy_sprite(0.0)
		add_child(_outline)
	if _surge == null:
		_surge = _copy_sprite(1.0)
		_surge.visible = false
		add_child(_surge)
	if _ground == null:
		_ground = Ground.new()
		_ground.fx = self
		_ground.z_index = -1 ## karakterin altında (bu düğüm z 0, göreli)
		_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_ground)
	_sync_copies()


func _copy_sprite(silhouette: float) -> Sprite2D:
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("silhouette", silhouette)
	mat.set_shader_parameter("frame_half", FRAME_HALF)
	var s := Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = mat
	return s


func _u() -> float:
	return absf(_sprite.scale.x) if _sprite != null else 1.0


func _body_center() -> Vector2:
	if _sprite == null:
		return Vector2.ZERO
	return _sprite.position + (_sprite.offset + BODY_CENTER) * _sprite.scale


func _feet() -> Vector2:
	if _sprite == null:
		return Vector2.ZERO
	return _sprite.position + (_sprite.offset + Vector2(0.0, FEET_ART_Y - FRAME_HALF)) * _sprite.scale


## Karakterin sanat pikseli ızgarasının başlangıcı (yerel): noktalar buna göre yuvarlanır, karakterin pikselleriyle aynı hizada.
func _grid_origin() -> Vector2:
	if _sprite == null:
		return Vector2.ZERO
	return _sprite.position + (_sprite.offset - Vector2(FRAME_HALF, FRAME_HALF)) * _sprite.scale


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_t += delta
	var body: Node = get_parent()
	if body == null or body.get("is_dead") == true or body.get("is_downed") == true:
		finish()
	elif body.has_method("slime_buff_active"): ## sahibin ekranı: süre buffın kendisinden
		if not body.slime_buff_active():
			finish()
		else:
			_time_left = float(body.get("_slime_buff_timer"))
	else:
		_time_left -= delta
		if _time_left <= 0.0:
			finish()
	if _ending:
		_fade -= delta / FADE_TIME
		if _fade <= 0.0:
			queue_free()
			return
	if _sprite == null or not is_instance_valid(_sprite):
		_ensure_parts()
	_sync_copies()
	## görünürlük: karakterin kendi alfası (çalı / Hayalet örtüsü) x sönme
	var body_a: float = _sprite.self_modulate.a if _sprite != null else 1.0
	visible = _sprite != null and _sprite.visible and body_a > 0.01
	self_modulate.a = 1.0
	modulate.a = body_a * clampf(_fade, 0.0, 1.0)
	if _outline != null:
		var blink_on: bool = _ending or _time_left > END_BLINK or fmod(_time_left * BLINK_HZ, 1.0) < 0.5
		_outline.visible = _outline.texture != null and blink_on
		_outline.modulate.a = 0.8 + 0.2 * sin(_t * 6.0)
	_step_surge(delta)
	_step_motes(delta)
	queue_redraw()
	if _ground != null:
		_ground.queue_redraw()


func _sync_copies() -> void:
	var s: AnimatedSprite2D = _sprite
	var tex: Texture2D = null
	if s != null and is_instance_valid(s) and s.sprite_frames != null and s.sprite_frames.has_animation(s.animation):
		tex = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	for c: Sprite2D in [_outline, _surge]:
		if c == null:
			continue
		c.texture = tex
		if tex == null:
			continue
		c.rotation = s.rotation
		c.centered = s.centered
		c.flip_h = s.flip_h
		c.flip_v = s.flip_v
	if _outline != null and tex != null:
		_outline.position = s.position
		_outline.scale = s.scale
		_outline.offset = s.offset


## Güç dalgası: silüet gövde merkezinin çevresinde büyüyerek söner (kopya ölçeği büyür, gövde merkezi sabit kalır).
func _step_surge(delta: float) -> void:
	if _surge == null:
		return
	if _surge_t < 0.0 or _surge.texture == null:
		_surge.visible = false
		return
	_surge_t += delta
	var k: float = _surge_t / SURGE_TIME
	if k >= 1.0:
		_surge_t = -1.0
		_surge.visible = false
		return
	var grow: float = 1.0 + SURGE_GROW * (1.0 - (1.0 - k) * (1.0 - k))
	_surge.visible = true
	_surge.position = _body_center()
	_surge.offset = -BODY_CENTER ## gövde merkezi kopyanın orijininde: büyürken yerinde kalır
	_surge.scale = _sprite.scale * grow
	_surge.modulate = Color(1.0, 1.0, 1.0, SURGE_ALPHA * (1.0 - k))


func _spawn_mote(x: float, y0: float, star: bool, age: float = 0.0) -> void:
	_motes.append({"x": x, "y0": y0, "age": age, "kind": 1 if star else 0})


func _step_motes(delta: float) -> void:
	for i in range(_motes.size() - 1, -1, -1):
		_motes[i]["age"] = float(_motes[i]["age"]) + delta
		if float(_motes[i]["age"]) >= MOTE_LIFE:
			_motes.remove_at(i)
	if _ending or _time_left <= END_BLINK * 0.5:
		return
	_mote_timer -= delta
	if _mote_timer <= 0.0:
		_mote_timer = MOTE_INTERVAL * randf_range(0.7, 1.3)
		var side: float = -1.0 if randf() < 0.5 else 1.0
		_spawn_mote(side * randf_range(7.0, 13.0), randf_range(0.0, 14.0), randf() < 0.35)


## Sanat pikseli (yerel p) karakterin ızgarasına yuvarlanmış dolu kare.
func _px(canvas: CanvasItem, p: Vector2, col: Color, u: float, g0: Vector2) -> void:
	canvas.draw_rect(Rect2(g0 + ((p - g0) / u).floor() * u, Vector2(u, u)), col)


func _draw() -> void:
	if _sprite == null:
		return
	var u: float = _u()
	var g0: Vector2 = _grid_origin()
	var c: Vector2 = _body_center()
	for m: Dictionary in _motes:
		var age: float = float(m["age"])
		if age < 0.0:
			continue
		var k: float = age / MOTE_LIFE
		var rise: float = MOTE_RISE * (1.0 - (1.0 - k) * (1.0 - k))
		var a: float = 1.0 if k < 0.65 else (1.0 - k) / 0.35
		var base: Vector2 = c + Vector2(float(m["x"]), float(m["y0"]) - rise) * u
		var pat: Array = STAR if int(m["kind"]) == 1 else ARROW
		var half := Vector2(float(String(pat[0]).length() >> 1), float(pat.size() >> 1))
		for row in range(pat.size()):
			var line: String = pat[row]
			for col in range(line.length()):
				var ch: String = line[col]
				if ch == ".":
					continue
				var colr: Color = C_CREAM if ch == "c" else (C_DEEP if ch == "d" else C_PINK)
				colr.a = a
				_px(self, base + (Vector2(col, row) - half) * u, colr, u, g0)


## Ayakta genişleyen pembe elips (Ground çocuğu çağırır - karakterin altında).
func draw_ground(canvas: CanvasItem) -> void:
	if _sprite == null:
		return
	var since: float = fmod(_t, PULSE_INTERVAL)
	if since >= PULSE_TIME or (_ending and since > 0.0 and _t > PULSE_TIME and _fade < 1.0):
		return
	var k: float = since / PULSE_TIME
	var u: float = _u()
	var g0: Vector2 = _grid_origin()
	var r: float = lerpf(PULSE_R0, PULSE_R1, 1.0 - (1.0 - k) * (1.0 - k))
	var col := Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.85 * (1.0 - k))
	var inner := Color(C_PINK_L.r, C_PINK_L.g, C_PINK_L.b, 0.35 * (1.0 - k))
	var feet: Vector2 = _feet()
	var steps: int = maxi(16, int(r * 5.0))
	var done := {}
	for i in range(steps):
		var ang: float = TAU * float(i) / float(steps)
		for layer in range(2):
			var rr: float = r - float(layer)
			var p: Vector2 = feet + Vector2(cos(ang) * rr, sin(ang) * rr * 0.5) * u
			var key: Vector2i = Vector2i(((p - g0) / u).floor())
			if done.has(key):
				continue
			done[key] = true
			_px(canvas, p, col if layer == 0 else inner, u, g0)
