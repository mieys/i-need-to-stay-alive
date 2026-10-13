extends Node2D

## Talon'un Silah Salvosu (E): karakter ile HER silahı arasında pixel-art zincir.
## YENİDEN ÜRETİM (kullanıcı 2026-10-12: "zincirler daha uyumlu ve oval kıvrılabilecek şekilde olacak silahlar dönerken" -> prototip A · Oval yay,
## tools/proto_20261012/gen_talon_form_zincir.py):
##  - İP FİZİĞİ: her zincir 10 parçalı bir Verlet ipi (iki ucu sabit: bel halkası + silahın iç ucu, parçalar uzamaz, hız sönümü = hava direnci).
##    İp kirişten %10 uzun olduğu için silah döndükçe arkasında oval bir yay çizer; karakter yürür/atılırsa zincir gerçek zincir gibi salınır.
##    Halkalar düğümlerden geçen Catmull-Rom eğrisine eşit aralıkla dizilir ve eğrinin o noktadaki yönüne döner.
##  - HALKALAR: 1 halka pikseli = 0,5 dünya pikseli (= 1080p'de 1 ekran pikseli, silah ikonlarının yoğunluğu), 180 derece üzerinde 32 yön için önceden pişirilmiş
##    (assets/fx/talon_chain/links.png, tools/gen_talon_chain_links.py): dönüşümlü yüzü dönük oval / kenardan görünen halka. Bir katmandaki TÜM
##    halkaların önce alt katmanı (kontur + yer gölgesi), sonra gövdeleri çizilir -> zincirin bütünü tek koyu konturla çevrilir.
##  - RENK: çelik gri + merkezden silaha akan turuncu akkor nabız; Ayna Formu (R) açıkken kızıl gövde + beyaz akkor nabız.
##  - KATMAN: silahı belin kuzeyinde kalan zincirler karakterin ARKASINDA (bu düğüm, show_behind_parent), güneydekiler ÖNÜNDE (_front, top_level -
##    eski tek katman gibi her şeyin üstünde). Zincirler beldeki basık oval halkaya bağlanır (arka yarısı arkada, ön yarısı önde).
## Player (yetkili) ve RemotePlayer (kozmetik kopya) ikisi de bu sahnenin ebeveyni olabilir: silah konumları player.owned_weapon_nodes /
## remote._weapon_icons'tan okunur, fizik + çizim iki tarafta AYNI koddur, her istemci kendi yerelinde simüle eder (bkz. CLAUDE.md).
## Ömür salvo bayrağını izler (yerel: _talon_weapon_salvo_active, uzak: _talon_formation == "salvo") - "Uzun Girdap" evrimiyle uzayan salvoda
## zincir de sürer; bitince RETRACT_TIME'da son şekli üzerinden bele toplanır.
##
## PERF (bkz. git geçmişi: 2026-09-24 "talon oyunu çok kastırıyor"): halka başına 2 draw_texture_rect_region (eskiden 3-4), zincir başına
## kare başına 1 fizik adımı (10 parça x 4 tur).

const TalonMath := preload("res://scripts/talon_formation_math.gd")
const LinkAtlas: Texture2D = preload("res://assets/fx/talon_chain/links.png")

const GROW_TIME := 0.2
const RETRACT_TIME := 0.25
const NO_FLAG_GRACE := 1.5 ## uzak kopyada durum paketi gecikirse salvo bayrağı henüz gelmemiş olabilir
const MAX_LIFE := 12.0 ## emniyet: bayrak hiç düşmezse
## Dünya pikseli / halka pikseli. Prototipte halka = karakter sanat pikseli (0,903) idi ama orada silah çemberi yanlışlıkla 2 kat geniş
## çizilmişti (130 YEREL birim = 65 dünya pikseli, weapon.gd ofseti kök ölçeğiyle çarpar): gerçek ölçekte o boyda zincir 11 kalın halkada
## kalıyor, yay okunmuyordu. 0,5 = kamera yakınlığı 2 iken tam 1 ekran pikseli (silah ikonlarıyla aynı yoğunluk) -> ~22 halka, prototipteki oran.
const LINK_PX := 0.5
const LINK_PITCH := 4.8 ## halka pikseli: iki halka merkezi arası (links.png ile aynı ölçü)
const LINK_DIRS := 32
const LINK_CELL := 16
const LINK_CENTER := Vector2(7, 6) ## hücrede halkanın merkez pikseli
const ROPE_SEGS := 10
const ROPE_ITERS := 4
const ROPE_SLACK := 0.10 ## ip kirişten bu kadar uzun (prototip A; 0.28 = "girdap")
const ROPE_DAMP := 9.0 ## 1/sn hız sönümü
const MIN_CHORD := 30.0 ## dünya pikseli: silah bundan yakınsa (dizilime henüz geçmemiş) zincir bağlanmaz (salvo yarıçapı 130 yerel = 65 dünya)
const BELT_OFFSET := Vector2(0, 1) ## dünya pikseli: zincirlerin bağlandığı bel noktası (karakter kökü bel hizasında; eski -6 göğüs/boyundu)
const BELT_RX := 7.5 ## bel halkası (yukarıdan bakış -> basık oval)
const BELT_RY := 3.6
const BELT_POINTS := 20 ## yarım halka başına
const TIP_INSET := 10.0 ## zincir silah merkezinin bu kadar içinde biter

## [gövde, nabız ortası, nabız tepesi, kontur]
const SCHEME_STEEL: Array[Color] = [Color8(150, 154, 172), Color8(255, 150, 50), Color8(255, 244, 204), Color8(26, 22, 30)]
const SCHEME_FORM: Array[Color] = [Color8(182, 20, 28), Color8(255, 128, 118), Color8(255, 255, 255), Color8(18, 4, 8)]

var _host: Node2D = null
var _front: Node2D = null
var _t: float = 0.0
var _seen_on: bool = false
var _closing: float = 0.0 ## 0 = açık, >0 = toplanıyor (sn)
var _link_px: float = LINK_PX
var _prev_dt: float = 1.0 / 60.0
var _last_host_pos: Vector2 = Vector2.ZERO
## İpler (silah sırasıyla): düğümler dünya koordinatında. Boş dizi = henüz bağlanmamış.
var _rope_x: Array[PackedVector2Array] = []
var _rope_prev: Array[PackedVector2Array] = []
var _rope_len: PackedFloat32Array = PackedFloat32Array()
var _rope_born: PackedFloat32Array = PackedFloat32Array()
## Çizim listeleri [arka, ön]: halka hücresinin sol üst köşesi (dünya), yön + tür * 64, gövde rengi; bloklar = [merkez, yarıçap, renk]
var _l_pos: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var _l_meta: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _l_col: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray()]
var _l_blocks: Array = [[], []]
var _scheme: Array[Color] = SCHEME_STEEL
var _belt_on: bool = false


func _ready() -> void:
	show_behind_parent = true ## arka katman: karakterin arkasında
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	if _host != null:
		_last_host_pos = _host.global_position
	_front = Node2D.new()
	_front.top_level = true
	_front.z_index = 0
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.draw.connect(_draw_front)
	add_child(_front)
	_front.global_position = Vector2.ZERO


## Gece ışığı (bkz. night_glow.gd): zincirlerin ışığı Talon'un üstünde.
func get_glow_segment() -> Array:
	if _host == null or not is_instance_valid(_host):
		return []
	return [_host.global_position, _host.global_position]


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


func _salvo_on() -> bool:
	if "_talon_weapon_salvo_active" in _host:
		return bool(_host._talon_weapon_salvo_active)
	if "_talon_formation" in _host:
		return str(_host._talon_formation) == "salvo"
	return _t < TalonMath.SALVO_DURATION


func _form_on() -> bool:
	if "_talon_mirror_form_active" in _host:
		return bool(_host._talon_mirror_form_active)
	if "_talon_form_active" in _host:
		return bool(_host._talon_form_active)
	return false


func _origin() -> Vector2:
	return _host.global_position + BELT_OFFSET


## Zincirin iki ucu: bel halkasının silaha bakan noktası + silahın iç ucu.
func _anchor_belt(origin: Vector2, dir: Vector2) -> Vector2:
	return origin + Vector2(dir.x * BELT_RX, dir.y * BELT_RY)


func _process(delta: float) -> void:
	_t += delta
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	if _salvo_on():
		_seen_on = true
	elif _closing <= 0.0 and (_seen_on or _t > NO_FLAG_GRACE):
		_closing = 0.0001
	if _closing <= 0.0 and _t > MAX_LIFE:
		_closing = 0.0001
	var host_pos: Vector2 = _host.global_position
	if _closing > 0.0:
		_closing += delta
		if _closing >= RETRACT_TIME:
			queue_free()
			return
		## Toplanırken fizik durur (silahlar yerine döndü): son şekil karakterle birlikte taşınır.
		var shift: Vector2 = host_pos - _last_host_pos
		if shift != Vector2.ZERO:
			for j in range(_rope_x.size()):
				var xs: PackedVector2Array = _rope_x[j]
				for i in range(xs.size()):
					xs[i] += shift
				_rope_x[j] = xs
	else:
		_simulate(clampf(delta, 1.0 / 240.0, 1.0 / 30.0))
	_last_host_pos = host_pos
	_build_links()
	queue_redraw()
	_front.queue_redraw()


func _simulate(dt: float) -> void:
	var pts: Array = _weapon_points()
	if pts.size() != _rope_x.size(): ## silah sayısı değişti (Ayna Formu açıldı/kapandı): hepsi yeniden bağlanır
		_rope_x.clear()
		_rope_prev.clear()
		_rope_len.clear()
		_rope_born.clear()
		for _j in range(pts.size()):
			_rope_x.append(PackedVector2Array())
			_rope_prev.append(PackedVector2Array())
			_rope_len.append(0.0)
			_rope_born.append(0.0)
	var origin: Vector2 = _origin()
	var keep: float = exp(-ROPE_DAMP * dt) * (dt / _prev_dt)
	for j in range(pts.size()):
		var wp: Vector2 = pts[j]
		var v: Vector2 = wp - origin
		var dist: float = v.length()
		if dist < MIN_CHORD:
			_rope_x[j] = PackedVector2Array()
			continue
		var dir: Vector2 = v / dist
		var p0: Vector2 = _anchor_belt(origin, dir)
		var p1: Vector2 = wp - dir * TIP_INSET
		var chord: float = p0.distance_to(p1)
		var x: PackedVector2Array = _rope_x[j]
		if x.is_empty():
			## İlk bağlanış: dönüşün tersine (TalonMath.SALVO_SPIN_DIR yönünde döner) sarkan yay - geçici titreme olmadan başlasın.
			_rope_len[j] = chord * (1.0 + ROPE_SLACK)
			_rope_born[j] = _t
			var bow: Vector2 = Vector2(dir.y, -dir.x) * TalonMath.SALVO_SPIN_DIR * (chord * sqrt(0.375 * ROPE_SLACK))
			x.resize(ROPE_SEGS + 1)
			for i in range(ROPE_SEGS + 1):
				var f: float = float(i) / float(ROPE_SEGS)
				x[i] = p0.lerp(p1, f) + bow * (4.0 * f * (1.0 - f))
			x = _solve(x, p0, p1, _rope_len[j] / float(ROPE_SEGS), 12)
			_rope_x[j] = x
			_rope_prev[j] = x.duplicate()
			continue
		var prev: PackedVector2Array = _rope_prev[j]
		for i in range(1, ROPE_SEGS):
			var cur: Vector2 = x[i]
			x[i] = cur + (cur - prev[i]) * keep
			prev[i] = cur
		## Silah normalden uzağa savrulursa (ateş tepmesi) ip kopmasın: boy en az kiriş kadar.
		x = _solve(x, p0, p1, maxf(_rope_len[j], chord * 1.02) / float(ROPE_SEGS), ROPE_ITERS)
		_rope_x[j] = x
		_rope_prev[j] = prev
	_prev_dt = dt


## Uzunluk kısıtı: uçlar sabit, her parça `seg` boyuna çekilir. Sonucu DÖNDÜRÜR: tipli Packed*Array değer gibi davranır (yazınca kopyalanır,
## bkz. hafıza "Packed*Array gotcha") - çağıran geri atamalı.
static func _solve(x: PackedVector2Array, p0: Vector2, p1: Vector2, seg: float, iters: int) -> PackedVector2Array:
	var last: int = x.size() - 1
	x[0] = p0
	x[last] = p1
	for _it in range(iters):
		for i in range(last):
			var d: Vector2 = x[i + 1] - x[i]
			var corr: Vector2 = d * (1.0 - seg / maxf(d.length(), 0.001))
			if i == 0:
				x[1] -= corr
			elif i == last - 1:
				x[i] += corr
			else:
				x[i] += corr * 0.5
				x[i + 1] -= corr * 0.5
	return x


func _cell(center: Vector2) -> Vector2:
	return Vector2(floorf(center.x / _link_px), floorf(center.y / _link_px))


func _build_links() -> void:
	_scheme = SCHEME_FORM if _form_on() else SCHEME_STEEL
	_belt_on = false
	for li in range(2):
		_build_layer(li)


## Bir katmanın (0 arka, 1 ön) çizim listeleri. Yerel dizilere yazılıp sonda atanır (Packed*Array'e kap içinden ekleme kaybolabilir).
func _build_layer(li: int) -> void:
	var l_pos := PackedVector2Array()
	var l_meta := PackedInt32Array()
	var l_col := PackedColorArray()
	var l_blocks: Array = []
	var origin: Vector2 = _origin()
	var pitch: float = LINK_PITCH * _link_px
	var retract: float = clampf(1.0 - _closing / RETRACT_TIME, 0.0, 1.0) if _closing > 0.0 else 1.0
	var body: Color = _scheme[0]
	for j in range(_rope_x.size()):
		var x: PackedVector2Array = _rope_x[j]
		if x.size() != ROPE_SEGS + 1:
			continue
		if (1 if x[ROPE_SEGS].y > origin.y else 0) != li:
			continue
		var extent: float = minf(clampf((_t - _rope_born[j]) / GROW_TIME, 0.0, 1.0), retract)
		if extent <= 0.0:
			continue
		_belt_on = true
		var seg: float = x[0].distance_to(x[1])
		var total: float = seg * float(ROPE_SEGS)
		var count: int = int(total * extent / pitch)
		var pulse_f: float = fmod(_t * 1.5 + float(j) * 0.27, 1.0)
		var tip: Vector2 = x[0]
		for i in range(count):
			var sd: float = (float(i) + 0.5) * pitch
			var s: float = sd / maxf(seg, 0.001)
			var idx: int = mini(int(s), ROPE_SEGS - 1)
			var u: float = s - float(idx)
			var q1: Vector2 = x[idx]
			var q2: Vector2 = x[idx + 1]
			var q0: Vector2 = x[idx - 1] if idx > 0 else q1 * 2.0 - q2
			var q3: Vector2 = x[idx + 2] if idx + 2 <= ROPE_SEGS else q2 * 2.0 - q1
			## Catmull-Rom noktası + türevi (teğet)
			var a1: Vector2 = q2 - q0
			var a2: Vector2 = q0 * 2.0 - q1 * 5.0 + q2 * 4.0 - q3
			var a3: Vector2 = q1 * 3.0 - q0 - q2 * 3.0 + q3
			var c: Vector2 = (q1 * 2.0 + a1 * u + a2 * (u * u) + a3 * (u * u * u)) * 0.5
			var tan: Vector2 = a1 + a2 * (2.0 * u) + a3 * (3.0 * u * u)
			var d_i: int = posmod(roundi(tan.angle() / (PI / float(LINK_DIRS))), LINK_DIRS)
			## Akkor nabız: merkezden silaha akar
			var dp: float = absf(sd / maxf(total, 1.0) - pulse_f)
			var heat: float = maxf(0.0, 1.0 - minf(dp, 1.0 - dp) / 0.1)
			var col: Color = body
			if heat > 0.0:
				col = col.lerp(_scheme[1], minf(1.0, heat * 2.0))
				if heat > 0.5:
					col = col.lerp(_scheme[2], heat * 2.0 - 1.0)
			l_pos.append((_cell(c) - LINK_CENTER) * _link_px)
			l_meta.append(d_i + (i % 2) * 64)
			l_col.append(col)
			tip = c
		if extent >= 0.999: ## silah ucundaki kelepçe
			l_blocks.append([x[ROPE_SEGS], 2, body])
			l_blocks.append([x[ROPE_SEGS], 0, _scheme[2]])
		elif count > 0: ## uzarken/toplanırken uçta akkor nokta
			l_blocks.append([tip, 1, _scheme[2]])
	_l_pos[li] = l_pos
	_l_meta[li] = l_meta
	_l_col[li] = l_col
	_l_blocks[li] = l_blocks


## Kontur karesi (2r+1) + içinde gövde karesi (2r-1); r = 0 -> tek piksel.
func _block(ci: CanvasItem, center: Vector2, r: int, col: Color) -> void:
	var o: Vector2 = (_cell(center) - Vector2(r, r)) * _link_px
	if r <= 0:
		ci.draw_rect(Rect2(o, Vector2(_link_px, _link_px)), col)
		return
	ci.draw_rect(Rect2(o, Vector2(2 * r + 1, 2 * r + 1) * _link_px), _scheme[3])
	ci.draw_rect(Rect2(o + Vector2(_link_px, _link_px), Vector2(2 * r - 1, 2 * r - 1) * _link_px), col)


func _draw_layer(ci: CanvasItem, li: int) -> void:
	var pos: PackedVector2Array = _l_pos[li]
	var meta: PackedInt32Array = _l_meta[li]
	var col: PackedColorArray = _l_col[li]
	var size := Vector2(LINK_CELL, LINK_CELL) * _link_px
	var cell := float(LINK_CELL)
	## 1) alt katman: tüm halkaların konturu (+ ovallerin yer gölgesi)
	for i in range(pos.size()):
		var m: int = meta[i]
		ci.draw_texture_rect_region(LinkAtlas, Rect2(pos[i], size), Rect2(float(m & 63) * cell, float(m >> 6) * 2.0 * cell, cell, cell), _scheme[3])
	## 2) gövdeler: önce yüzü dönük ovaller, üstüne kenardan görünen halkalar (deliklerden geçer)
	for kind in range(2):
		for i in range(pos.size()):
			var m: int = meta[i]
			if (m >> 6) == kind:
				ci.draw_texture_rect_region(LinkAtlas, Rect2(pos[i], size), Rect2(float(m & 63) * cell, float(kind * 2 + 1) * cell, cell, cell), col[i])
	## 3) bel halkasının bu katmandaki yarısı (arka yarı koyu)
	if _belt_on:
		var origin: Vector2 = _origin()
		var arc := PackedVector2Array()
		for k in range(BELT_POINTS + 1):
			var a: float = PI * float(k) / float(BELT_POINTS) + (0.0 if li == 1 else PI)
			arc.append(origin + Vector2(cos(a) * BELT_RX, sin(a) * BELT_RY))
		ci.draw_polyline(arc, _scheme[3], _link_px * 3.0)
		ci.draw_polyline(arc, _scheme[0] if li == 1 else _scheme[0].darkened(0.4), _link_px)
	for b in (_l_blocks[li] as Array):
		_block(ci, b[0], int(b[1]), b[2])


## Arka katman bu düğümün kendisi (ebeveynin çocuğu -> ebeveyn yerelinde çizer): listeler dünya koordinatında olduğu için dönüşüm geri alınır.
func _draw() -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	_draw_layer(self, 0)


func _draw_front() -> void:
	_draw_layer(_front, 1)
