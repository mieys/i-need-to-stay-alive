extends Node2D

## Minik Cadı (iyi slime) büyü efekti (kullanıcı 2026-11-09: "slime için sihirli pixel art efekt tasarla", madde 509; madde 523'te
## "oyuncuya doğru giden sihir efekti pek dikkat çekici değil" -> baştan). ~1,4 sn, tek seferlik, kare başı çizim (her nokta sahibin sanat
## pikseli ızgarasında, u):
##  1. Kulaklarda çıkış parlaması (4 kollu yıldız).
##  2. Kulaklardan sahibin göğsüne ÖRGÜLÜ ÜÇ KÜRE: ortada iri pembe küre (krem çekirdek, pembe iç, koyu pembe dış bant), iki yanında
##     birbirini ortada kesen küçük küreler; arkalarında incelerek biten dolu iz (3 düz bant, dither yok) + iri kürenin bıraktığı, süzülüp
##     sönen yıldız kıvılcımları.
##  3. İri küre varınca göğüste patlama (krem disk + 8 ışın, içten dışa çekilir) + ayakta pembe büyü çemberi (karakterin ALTINDA, sahibin
##     z -1 çocuğu) + gövdede yükselen oklar (pişmiş sayfalar, tools/gen_slime_pet.py) + slime_buff_fx.gd başlar (buff süresince karakterin
##     pembe dış hattı / okları, iki ekranda).
## Sahibin (karakter kökü) çocuğu: karakterle birlikte hareket eder; noktalar ebeveynin YEREL uzayında. Sahibin ekranında da kuklada da
## slime_pet.gd _release kurar - ağ olayı zaten NetworkManager.broadcast_slime (ayrı RPC yok).

const SlimeBuffFxScript: GDScript = preload("res://scripts/slime_buff_fx.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const RING_TEX: Texture2D = preload("res://assets/pets/slime/slime_buyu_halka.png")
const RISE_TEX: Texture2D = preload("res://assets/pets/slime/slime_buyu_yukselis.png")
const RING_FRAMES := 12
const RISE_FRAMES := 12
const RING_FPS := 14.0
const RISE_FPS := 12.0
const RISE_FOOT := Vector2(20.0, 56.0) ## yükseliş sayfasında ayak noktası (gen_slime_pet.py RISE_FOOT)
const BOLT_TIME := 0.42 ## kürenin kulaktan göğse uçuşu
## Küreler: gecikme (sn), yan sapma yönü (örgü: ikisi ortada iri küreyi keser), baş yarıçapı (sanat pikseli).
const BOLTS := [[0.0, 0.0, 2], [0.04, 1.0, 1], [0.08, -1.0, 1]]
const SIDE_AMP := 7.0 ## örgünün yan genliği (sanat pikseli)
const ARC_LIFT := 22.0 ## yayın tepesi (sanat pikseli)
const TRAIL_SPAN := 0.34 ## iz uzunluğu (yolun oranı)
const TRAIL_STEPS := 16
const LAND := BOLT_TIME ## iri kürenin varışı: patlama + çember + oklar + buff görünüşü buradan sonra
const LAUNCH_TIME := 0.2
const BURST_TIME := 0.36
const SPARK_INTERVAL := 0.022
const SPARK_LIFE := 0.45
const C_CREAM := Color(1.0, 0.957, 0.98)
const C_PINK := Color(1.0, 0.44, 0.73)
const C_PINK_L := Color(1.0, 0.67, 0.85)
const C_DEEP := Color(0.8, 0.2, 0.56)

var _t: float = 0.0
var _from := Vector2.ZERO
var _feet := Vector2.ZERO
var _chest := Vector2(0.0, -20.0)
var _u: float = 1.2
var _ring: Sprite2D = null
var _rise: Sprite2D = null
var _life: float = 0.0
var _sparks: Array[Dictionary] = [] ## {p (yerel), v, age}
var _spark_timer: float = 0.0
var _landed: bool = false


func setup(from: Vector2, feet: Vector2, chest: Vector2, u: float) -> void:
	_from = from
	_feet = feet
	_chest = chest
	_u = maxf(0.5, u)


func _ready() -> void:
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_life = LAND + maxf(RING_FRAMES / RING_FPS, RISE_FRAMES / RISE_FPS) + 0.05
	_rise = _sheet_sprite(RISE_TEX, RISE_FRAMES)
	_rise.centered = false
	_rise.offset = -RISE_FOOT
	_rise.position = _feet
	_rise.visible = false
	add_child(_rise)
	## Çember karakterin altında: sahibin z -1 çocuğu (bu düğüm z 60'ta; çocuğu olsaydı üstte kalırdı).
	_ring = _sheet_sprite(RING_TEX, RING_FRAMES)
	_ring.position = _feet
	_ring.z_index = -1
	_ring.visible = false
	var host: Node = get_parent()
	if host != null:
		host.add_child.call_deferred(_ring)


func _sheet_sprite(tex: Texture2D, frames: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = frames
	s.scale = Vector2(_u, _u)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _exit_tree() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	var k: float = _t - LAND
	if k >= 0.0:
		if not _landed:
			_landed = true
			_start_buff_look()
		_step_sheet(_ring, k, RING_FPS, RING_FRAMES)
		_step_sheet(_rise, k, RISE_FPS, RISE_FRAMES)
	_step_sparks(delta)
	queue_redraw()


## İri küre göğse vardı: buff süresince karakterin görünüşü (slime_buff_fx.gd) - sahibin ekranında süre buffın kendisinden, kuklada
## büyü süresinden (uçuş kadar eksik). İki ekranda da buradan: ek ağ olayı yok.
func _start_buff_look() -> void:
	var host: Node = get_parent()
	if host == null or host.get("is_dead") == true or host.get("is_downed") == true:
		return
	var dur: float = PetCatalog.SLIME_BUFF_TIME - LAND
	if host.has_method("slime_buff_active"):
		if not host.slime_buff_active():
			return
		dur = float(host.get("_slime_buff_timer"))
	start_on(host, dur)


## Gövdedeki "SlimeBuffFx" düğümünü kurar ya da yeniler (testler de çağırır).
static func start_on(body: Node, duration: float) -> Node2D:
	if body == null or not is_instance_valid(body):
		return null
	var fx: Node2D = body.get_node_or_null(SlimeBuffFxScript.NODE_NAME) as Node2D
	if fx == null or fx.is_ending():
		fx = SlimeBuffFxScript.new()
		fx.name = SlimeBuffFxScript.NODE_NAME
		body.add_child(fx)
	fx.refresh(duration)
	return fx


func _step_sheet(s: Sprite2D, k: float, fps: float, frames: int) -> void:
	if not is_instance_valid(s):
		return
	var f: int = int(k * fps)
	s.visible = f < frames
	if s.visible:
		s.frame = f


## Küre i'nin t anındaki yolu: 0..1 (0 çıkış, 1 göğüs); dışında görünmez.
static func bolt_progress(t: float, i: int) -> float:
	return (t - float(BOLTS[i][0])) / BOLT_TIME


func _path(q: float, side: float) -> Vector2:
	var ctrl: Vector2 = (_from + _chest) * 0.5 + Vector2(0.0, -ARC_LIFT * _u)
	var a: Vector2 = _from.lerp(ctrl, q)
	var b: Vector2 = ctrl.lerp(_chest, q)
	var p: Vector2 = a.lerp(b, q)
	if side != 0.0:
		var perp: Vector2 = (_chest - _from).orthogonal().normalized()
		p += perp * side * SIDE_AMP * _u * sin(TAU * q) * (1.0 - 0.35 * q)
	return p


func _px(p: Vector2, col: Color) -> void:
	draw_rect(Rect2((p / _u).floor() * _u, Vector2(_u, _u)), col)


## Yuvarlatılmış dolu blok: yarıçap h sanat pikseli (h 0 = tek piksel; köşeler kırpık artı).
func _blk(p: Vector2, h: int, col: Color) -> void:
	var c: Vector2 = (p / _u).floor() * _u
	if h <= 0:
		draw_rect(Rect2(c, Vector2(_u, _u)), col)
		return
	var n: float = float(2 * h + 1)
	draw_rect(Rect2(c - Vector2(h, h - 1) * _u, Vector2(n, n - 2.0) * _u), col)
	draw_rect(Rect2(c - Vector2(h - 1, h) * _u, Vector2(n - 2.0, n) * _u), col)


func _ease(q: float) -> float:
	return q * q * 0.45 + q * 0.55 ## hafif hızlanarak varış


func _step_sparks(delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp["age"] = float(sp["age"]) + delta
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
		if float(sp["age"]) >= SPARK_LIFE:
			_sparks.remove_at(i)
	var q: float = bolt_progress(_t, 0)
	if q <= 0.05 or q >= 1.0:
		return
	_spark_timer -= delta
	while _spark_timer <= 0.0:
		_spark_timer += SPARK_INTERVAL
		var head: Vector2 = _path(_ease(q), 0.0)
		var jitter := Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)) * _u
		var vel := Vector2.from_angle(randf() * TAU) * randf_range(4.0, 9.0) * _u + Vector2(0.0, 5.0 * _u)
		_sparks.append({"p": head + jitter, "v": vel, "age": 0.0})


func _draw() -> void:
	_draw_launch()
	_draw_sparks()
	## izler: önce tüm dış bantlar, sonra iç, sonra çekirdek (bantlar temiz üst üste biner)
	for layer in range(3):
		for i in range(BOLTS.size()):
			_draw_bolt_trail(i, layer)
	for i in range(BOLTS.size()):
		_draw_bolt_head(i)
	_draw_burst()


func _draw_launch() -> void:
	if _t >= LAUNCH_TIME:
		return
	var k: float = _t / LAUNCH_TIME
	var l: int = int(round(4.0 * sin(PI * k)))
	_blk(_from, 1, C_PINK)
	_px(_from, C_CREAM)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for j in range(2, l + 2):
			_px(_from + d * float(j) * _u, C_CREAM if j <= 2 else C_PINK)


func _draw_sparks() -> void:
	for sp: Dictionary in _sparks:
		var k: float = float(sp["age"]) / SPARK_LIFE
		var a: float = 1.0 if k < 0.6 else (1.0 - k) / 0.4
		var p: Vector2 = sp["p"]
		if k < 0.45:
			_px(p, Color(C_CREAM.r, C_CREAM.g, C_CREAM.b, a))
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_px(p + d * _u, Color(C_PINK.r, C_PINK.g, C_PINK.b, a))
		else:
			_px(p, Color(C_PINK_L.r, C_PINK_L.g, C_PINK_L.b, a))


func _draw_bolt_trail(i: int, layer: int) -> void:
	var q: float = bolt_progress(_t, i)
	if q <= 0.0 or q >= 1.0:
		return
	var side: float = float(BOLTS[i][1])
	var r: int = int(BOLTS[i][2])
	var e: float = _ease(q)
	var col: Color = [C_DEEP, C_PINK, C_CREAM][layer]
	for st in range(1, TRAIL_STEPS + 1):
		var f: float = float(st) / float(TRAIL_STEPS) ## 0 baş, 1 kuyruk ucu
		var tq: float = e - TRAIL_SPAN * f
		if tq <= 0.0:
			break
		if layer == 2 and f > 0.4:
			break
		var h: int = int(round(float(r) * (1.0 - f))) + 1 - layer ## incelerek biter
		if h < 0:
			continue
		_blk(_path(tq, side), h, col)


func _draw_bolt_head(i: int) -> void:
	var q: float = bolt_progress(_t, i)
	if q <= 0.0 or q >= 1.0:
		return
	var side: float = float(BOLTS[i][1])
	var r: int = int(BOLTS[i][2])
	var p: Vector2 = _path(_ease(q), side)
	_blk(p, r + 1, C_DEEP)
	_blk(p, r, C_PINK)
	_blk(p, r - 1, C_CREAM)
	if i == 0 and int(_t * 20.0) % 2 == 0: ## iri kürede yanıp sönen dört kollu parıltı
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			_px(p + d * float(r + 2) * _u, C_CREAM)
			_px(p + d * float(r + 3) * _u, C_PINK_L)


## Göğüste patlama: krem disk küçülür, 8 ışın önce uzar sonra içten dışa çekilir.
func _draw_burst() -> void:
	var k: float = (_t - LAND) / BURST_TIME
	if k < 0.0 or k >= 1.0:
		return
	var disc: int = int(round(5.0 * pow(1.0 - k, 1.5)))
	_blk(_chest, disc + 1, C_PINK)
	_blk(_chest, disc, C_CREAM)
	for n in range(8):
		var dir: Vector2 = Vector2.from_angle(TAU * float(n) / 8.0 - PI * 0.5)
		var cardinal: bool = n % 2 == 0
		var lmax: float = 12.0 if cardinal else 8.0
		var outer: float = lerpf(3.0, lmax, minf(1.0, k / 0.4))
		var inner: float = 3.0 if k < 0.4 else lerpf(3.0, lmax, (k - 0.4) / 0.6)
		var j: float = inner
		while j <= outer:
			var mid: bool = j < (inner + outer) * 0.5
			_px(_chest + dir * j * _u, C_CREAM if (cardinal and mid) else C_PINK)
			j += 1.0
