extends "res://tools/proto_20261116/esya_tetik/esya_proto_base.gd"

## TETİKLENEN EŞYA efekt PROTOTİPLERİ (2026-11-16, OYUNA BAĞLI DEĞİL; kullanıcı: "aktif yeteneği olan eşyaların efektleri için yeni
## efekt prototipleri hazırla (pazardaki birşey olunca tetiklenen itemler)"). Bekleme süreli 6 eşya x 2 varyant:
##   zaman  Gündüz ve Gece   A Tutulma        : güneş + ay göğüsten başın üstüne dolanıp tutulma olur, yerde gece dalgası; donan yaratıkta hilal
##                           B Gece Kubbesi   : karakterin üstüne yıldızlı gece kubbesi iner, güneş kubbe kenarında batar, kubbe patlar,
##                                              yıldızlar donan yaratıklara uçup üstlerinde kalır
##   olum   Ölüm Eşiği       A Kum Saati      : başın üstünde kum saati (kum bitmek üzere) ters döner, mavi kum karaktere akar, halka ayağa iner
##                           B Boynuz Kemeri  : yerde mor eşik halkası, iki yandan hayalet boynuzlar büyüyüp başın üstünde birleşir,
##                                              arası mavi kalkan ışığıyla dolar, boynuzlar kırılıp düşer
##   gunes  Güneşin İradesi  A Güneş Halesi   : başın arkasında ışınlı güneş açar, sonra başın üstünde küçük güneş olarak iyileşme boyunca kalır
##                           B Gün Işığı      : gökten sıcak ışık sütunu iner, yerde ışık havuzu + halkalar; iyileşme boyunca ayakta küçük havuz
##   anka   Tanrının Eli     A Işık Eli       : gökten ışıktan bir el iner, parmak ucu başa dokunur, yerde dalga, başta hale kalır
##                           B Diriliş Halkası: ayaktan başa üç halka yükselir, başın üstünde haleye dönüşür, ışık çizgileri yükselir
##   urkek  Ürkek Yürek      A Çarpan Kalp    : başın üstünde kalp iki kez hızla çarpar; hız sürdükçe arkada rüzgâr çizgileri (hızla azalır)
##                           B Kaçış İzi      : korku çizgileri + ter damlası; hız sürdükçe arkada kırmızı düz siluet izleri (hızla azalır)
##   kemik  Kemik Kolye      A Diş Halkası    : 6 kemik diş belde döner (önü karakterin önünde, arkası arkasında); her güçlü saldırı bir dişi koparır
##                           B Çene Mührü     : göğüs önünde kemik çene kapanır, dişler başın üstünde taç olur; her güçlü saldırı bir dişi düşürür
## Ürkek Yürek ve Kemik Kolye GERÇEK oyun değerini okur (_item_urkek_timer / _item_kemik_charges) - sönme ve diş sayısı oyunla aynı.

var _mobs: Array = []          ## zaman: {n, arrive, star}
var _rng := RandomNumberGenerator.new()
var _streaks: Array = []       ## urkek A: {p, d, len, t0}
var _streak_acc: float = 0.0
var _ghosts: Array = []        ## urkek B: {tex, xf, rect, t0}
var _ghost_acc: float = 0.0
var _prev_n: int = 0
var _pop_t: float = -10.0
var _flying: Array = []        ## kemik: {p, d, t0, rot}
var _chips: Array = []         ## olum B: {a, b, v, t0}


func _setup() -> void:
	_rng.seed = 11
	match item:
		"zaman":
			_life = 2.7
			_collect_mobs()
		"olum":
			_life = 1.3 if variant == "A" else 1.2
		"gunes":
			_life = 3.0
		"anka":
			_life = 1.5
		"urkek":
			_life = 3.2
		"kemik":
			_life = 3.8
			_prev_n = 0


func _render(L: int, ci: CanvasItem) -> void:
	match item + variant:
		"zamanA":
			_zaman_a(L, ci)
		"zamanB":
			_zaman_b(L, ci)
		"olumA":
			_olum_a(L, ci)
		"olumB":
			_olum_b(L, ci)
		"gunesA":
			_gunes_a(L, ci)
		"gunesB":
			_gunes_b(L, ci)
		"ankaA":
			_anka_a(L, ci)
		"ankaB":
			_anka_b(L, ci)
		"urkekA":
			_urkek_a(L, ci)
		"urkekB":
			_urkek_b(L, ci)
		"kemikA":
			_kemik_a(L, ci)
		"kemikB":
			_kemik_b(L, ci)


func _step(delta: float) -> void:
	match item:
		"zaman":
			for m in _mobs:
				var n: Node = m["n"]
				if is_instance_valid(n):
					var fx: Variant = n.get("_freeze_status_fx")
					if fx is CanvasItem and is_instance_valid(fx):
						(fx as CanvasItem).visible = false ## buz kütlesi yerine zaman durması işareti
		"urkek":
			_urkek_step(delta)
		"kemik":
			_kemik_step()
		"olum":
			pass


# ============================================================================ GÜNDÜZ VE GECE
const Z_WAVE_T0 := 0.45
const Z_WAVE_DUR := 1.0
const Z_WAVE_R := 340.0
const Z_MOB_HEAD := Vector2(0, -24)
const Z_MOB_FEET := Vector2(0, 7)


func _collect_mobs() -> void:
	var i: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or e.get("is_dead") == true:
			continue
		var d: float = (e as Node2D).global_position.distance_to(_o + FEET)
		if d > 330.0:
			continue
		var arrive: float
		if variant == "A":
			## dalga yarıçapı eout(k) * R: d'ye ulaştığı an
			var k: float = 1.0 - sqrt(maxf(0.0, 1.0 - d / Z_WAVE_R))
			arrive = Z_WAVE_T0 + k * Z_WAVE_DUR
		else:
			arrive = 1.42
		_mobs.append({"n": e, "arrive": arrive, "i": i})
		i += 1


func _moon(center: Vector2, r: float, tone: int) -> void:
	_disc(center, r, tone, false)
	var cut: Vector2 = center / PX + Vector2(r * 0.55, -r * 0.35)
	for c in _cells.keys():
		if (Vector2(c) + Vector2(0.5, 0.5) - cut).length() < r * 0.9:
			_cells.erase(c)


func _za_orbit(tt: float) -> Array:
	var k: float = _eout(tt / 0.44)
	var c: Vector2 = (_o + CHEST).lerp(_o + Vector2(0, -44), k)
	var rad: float = lerpf(20.0, 0.0, k)
	var ang: float = PI + k * PI * 1.25
	return [c + Vector2(cos(ang), sin(ang) * 0.45) * rad, c + Vector2(cos(ang + PI), sin(ang + PI) * 0.45) * rad]


func _zaman_a(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	if L == BACK:
		var kw: float = _k(t, Z_WAVE_T0, Z_WAVE_T0 + Z_WAVE_DUR)
		if t >= Z_WAVE_T0 and kw < 1.0:
			var r: float = maxf(1.0, _eout(kw) * Z_WAVE_R / PX)
			var a: float = _band(1.0 - _k(kw, 0.5, 1.0))
			_ell(ci, _o + FEET, r, r * 0.5, NIGHT[1], a * 0.2)
			_ring(ci, _o + FEET, r - 1.0, NIGHT[3], a * 0.85, 0.5, 2)
			_ring(ci, _o + FEET, r, GOLD[4], a, 0.5, 1)
		_mob_marks(L, ci)
		return
	## ÜST
	if t < 0.44:
		var cur: Array = _za_orbit(t)
		for j in 3:
			var tt: float = maxf(0.0, t - 0.03 * float(j + 1))
			var prv: Array = _za_orbit(tt)
			var nxt: Array = _za_orbit(maxf(0.0, t - 0.03 * float(j)))
			_seg(nxt[0], prv[0], lerpf(1.4, 0.6, float(j) / 2.0), lerpf(1.1, 0.4, float(j) / 2.0), 3)
		_disc(cur[0], 3.0, 3)
		_flush(ci, GOLD)
		for j in 3:
			var prv2: Array = _za_orbit(maxf(0.0, t - 0.03 * float(j + 1)))
			var nxt2: Array = _za_orbit(maxf(0.0, t - 0.03 * float(j)))
			_seg(nxt2[1], prv2[1], lerpf(1.3, 0.6, float(j) / 2.0), lerpf(1.0, 0.4, float(j) / 2.0), 3)
		_flush(ci, NIGHT)
		_moon(cur[1], 3.0, 3)
		_flush(ci, NIGHT)
	elif t < 1.55:
		var e: Vector2 = _o + Vector2(0, -44)
		var s: float = 1.0 - _ein(_k(t, 1.3, 1.55))
		if s <= 0.05:
			return
		var ka: float = _k(t, 0.44, 0.62)
		_halo(ci, e, 9.0 * s, GOLD, _band(lerpf(1.0, 0.75, ka)), 1.0)
		for i in 4:
			var ang: float = (t - 0.44) * 1.4 + float(i) * PI * 0.5
			var dir := Vector2(cos(ang), sin(ang))
			_line(ci, e + dir * 6.8 * s * PX, e + dir * 9.6 * s * PX, GOLD[4], 1.0)
		_ring(ci, e, 5.6 * s, GOLD[3], 1.0)
		_ring(ci, e, 6.6 * s, GOLD[2], 0.55)
		_disc(e, 4.6 * s, 1, false)
		_flush(ci, NIGHT)
		if t < 0.62:
			_spark(ci, e, lerpf(10.0, 3.0, ka), GOLD[5], GOLD[3], 1.0)
	_mob_marks(L, ci)


func _mob_marks(L: int, ci: CanvasItem) -> void:
	for m in _mobs:
		var n: Node = m["n"]
		if not is_instance_valid(n):
			continue
		var at: float = float(m["arrive"])
		if _t < at:
			continue
		var p: Vector2 = (n as Node2D).global_position
		var a: float = _band(minf(_k(_t, at, at + 0.08), 1.0 - _k(_t, _life - 0.2, _life)))
		if L == BACK:
			_ell(ci, p + Z_MOB_FEET, 9.0, 3.6, NIGHT[1], a * 0.3)
			_ring(ci, p + Z_MOB_FEET, 9.0, NIGHT[3], a * 0.85, 0.4, 1)
			continue
		var pop: float = _eout(_k(_t, at, at + 0.12))
		if variant == "A":
			_moon(p + Z_MOB_HEAD, 3.4 * lerpf(0.4, 1.0, pop), 3)
			_flush(ci, NIGHT, a)
			_spark(ci, p + Z_MOB_HEAD + Vector2(5, -3) * PX, 1.0, NIGHT[5], NIGHT[4], a)
		else:
			_spark(ci, p + Z_MOB_HEAD, lerpf(4.0, 2.0, pop), NIGHT[5], NIGHT[3], a)
			_spark(ci, p + Z_MOB_HEAD + Vector2(-5, 2) * PX, 1.0, NIGHT[5], NIGHT[4], a * 0.7)


const ZB_RX := 22.0
const ZB_H := 50.0
const ZB_STARS: Array = [Vector2(-10, -14), Vector2(8, -24), Vector2(12, -8), Vector2(-5, -45), Vector2(3, -6), Vector2(-14, -30)]


## Üst yarım elips dolgusu (taban center'da), satır satır.
func _dome(ci: CanvasItem, base: Vector2, rx: float, h: float, col: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var cc: Vector2 = base / PX
	var rxp: float = rx / PX
	var hp: float = h / PX
	col.a *= alpha
	for y in range(floori(cc.y - hp), floori(cc.y)):
		var fy: float = (cc.y - (float(y) + 0.5)) / hp
		if fy > 1.0 or fy < 0.0:
			continue
		var hw: float = rxp * sqrt(1.0 - fy * fy)
		var x0: int = floori(cc.x - hw + 0.5)
		var x1: int = floori(cc.x + hw - 0.5)
		if x1 >= x0:
			ci.draw_rect(Rect2(Vector2(x0, y) * PX, Vector2(x1 - x0 + 1, 1) * PX), col)


func _zb_star_pos(i: int, g: float) -> Vector2:
	return _o + FEET + (ZB_STARS[i] as Vector2) * g


func _zaman_b(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	var g: float = _eout(_k(t, 0.0, 0.2))
	var kp: float = _k(t, 1.0, 1.16)
	var sc: float = g * (1.0 + 0.35 * kp)
	var da: float = _band(1.0 - kp)
	var base: Vector2 = _o + FEET
	if L == BACK:
		if t < 1.16:
			_ring(ci, base, ZB_RX * sc / PX, NIGHT[3], da * 0.9, 0.34, 1)
			_ell(ci, base, ZB_RX * sc / PX, ZB_RX * sc / PX * 0.34, NIGHT[1], da * 0.3)
		var kr: float = _k(t, 1.0, 1.4)
		if t >= 1.0 and kr < 1.0:
			var rr: float = lerpf(ZB_RX, 48.0, _eout(kr)) / PX
			_ring(ci, base, rr, NIGHT[3], _band(1.0 - kr), 0.4, 2)
		_mob_marks(L, ci)
		return
	if t < 1.16:
		_dome(ci, base, ZB_RX * sc, ZB_H * sc, NIGHT[1], da * 0.38)
		_dome(ci, base, ZB_RX * sc * 0.78, ZB_H * sc * 0.82, NIGHT[2], da * 0.22)
		_ring(ci, base, ZB_RX * sc / PX, NIGHT[4], da * 0.9, ZB_H / ZB_RX, 1, PI, TAU)
		## yıldızlar (kubbe içinde, sırayla yanıp söner: kol 1 <-> 2)
		if t < 1.0:
			for i in ZB_STARS.size():
				var arm: float = 2.0 if fmod(t * 2.2 + float(i) * 0.37, 1.0) < 0.5 else 1.0
				_spark(ci, _zb_star_pos(i, g), arm, NIGHT[5], NIGHT[4], _band(_k(t, 0.08 + 0.03 * float(i), 0.16 + 0.03 * float(i))))
		## güneş kubbenin kenarında batar
		var u: float = _sstep(_k(t, 0.15, 0.98))
		if t >= 0.15 and u < 1.0:
			for j in 3:
				var uj: float = maxf(0.0, u - 0.035 * float(j + 1))
				var ui: float = maxf(0.0, u - 0.035 * float(j))
				_seg(_zb_sun(ui, sc), _zb_sun(uj, sc), lerpf(1.3, 0.6, float(j) / 2.0), lerpf(1.0, 0.4, float(j) / 2.0), 3)
			_disc(_zb_sun(u, sc), 2.8, 3)
			_flush(ci, GOLD, _band(1.0 - _k(u, 0.88, 1.0)))
	## yıldızlar donan yaratıklara uçar
	if t >= 1.0:
		var ku: float = _k(t, 1.0, 1.42)
		for i in ZB_STARS.size():
			var a0: Vector2 = _zb_star_pos(i, 1.0)
			if i < _mobs.size() and is_instance_valid(_mobs[i]["n"]):
				if ku >= 1.0:
					continue
				var tgt: Vector2 = (_mobs[i]["n"] as Node2D).global_position + Z_MOB_HEAD
				var c: Vector2 = (a0 + tgt) * 0.5 + Vector2(0, -26)
				var e: float = _sstep(ku)
				var p: Vector2 = _bez(a0, c, tgt, e)
				var q: Vector2 = _bez(a0, c, tgt, maxf(0.0, e - 0.12))
				_line(ci, q, p, NIGHT[4], 0.7)
				_spark(ci, p, 2.0, NIGHT[5], NIGHT[3], 1.0)
			else:
				var up: Vector2 = a0 + Vector2(0, -24) * _eout(ku)
				_spark(ci, up, 2.0 - ku, NIGHT[5], NIGHT[4], _band(1.0 - ku))
	_mob_marks(L, ci)


func _zb_sun(u: float, sc: float) -> Vector2:
	var a: float = PI + u * PI
	return _o + FEET + Vector2(cos(a) * ZB_RX, sin(a) * ZB_H) * sc


static func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


# ============================================================================ ÖLÜM EŞİĞİ
## Kum saati (sanat pikseli): cam yarı genişlikleri y = -6..6
const HG_HW: Array = [3, 3, 3, 2, 1, 0, 0, 0, 1, 2, 3, 3, 3]


func _hg_cell(h: Vector2, x: float, y: float, s: float, fy: float) -> Vector2i:
	return _cellv(h + Vector2((x + 0.5) * s, (y + 0.5) * s * fy) * PX)


func _olum_a(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	var h: Vector2 = _o + Vector2(0, -45)
	var s: float
	if t < 0.1:
		s = 1.15 * _eout(t / 0.1)
	elif t < 0.16:
		s = lerpf(1.15, 1.0, _k(t, 0.1, 0.16))
	else:
		s = 1.0 - _ein(_k(t, 0.86, 1.05))
	var fy: float = cos(PI * _sstep(_k(t, 0.35, 0.5)))
	var flipped: bool = t >= 0.5
	## iniş halkası + ayak sıçraması
	var kr: float = _k(t, 0.6, 0.9)
	if t >= 0.6 and kr < 1.0:
		var y: float = lerpf(HEAD.y + 2.0, FEET.y, _sstep(kr))
		var c: Vector2 = _o + Vector2(0, y)
		var a: float = _band(1.0 - _k(kr, 0.8, 1.0))
		_ring_half(ci, c, 12.0, BLUE[4], a, 0.34, L == BACK, 1)
		_ring_half(ci, c, 11.0, BLUE[3], a * 0.7, 0.34, L == BACK, 1)
		if L == TOP:
			_ell(ci, c + Vector2(0, -3), 11.5, 5.0, BLUE[3], a * 0.22)
	var ks: float = _k(t, 0.88, 1.2)
	if L == BACK and t >= 0.88 and ks < 1.0:
		_ring(ci, _o + FEET, lerpf(12.0, 26.0, _eout(ks)), BLUE[3], _band(1.0 - ks), 0.4, 2)
		_ell(ci, _o + FEET, lerpf(12.0, 22.0, _eout(ks)), lerpf(12.0, 22.0, _eout(ks)) * 0.4, BLUE[2], _band(1.0 - ks) * 0.25)
	if L != TOP or s <= 0.05:
		return
	## kum akışı kafaya (dönüşten sonra)
	if flipped and t < 0.84:
		var kk: float = _k(t, 0.52, 0.62)
		var top: Vector2 = h + Vector2(0.5, 7.5) * PX
		var bot: Vector2 = top.lerp(_o + HEAD, kk)
		_line(ci, top, bot, BLUE[4], 1.0)
		_line(ci, top + Vector2(PX, 0), bot + Vector2(PX, 0), BLUE[3], 0.55)
	## cam (soluk pembe) + çerçeve kenarları + kemik kapaklar; tek ortak kontur
	for yi in range(-6, 7):
		var hw: int = int(HG_HW[yi + 6])
		for x in range(-hw, hw + 1):
			_put(_hg_cell(h, x, yi, s, fy), 4)
		_put(_hg_cell(h, -hw - 1, yi, s, fy), 2)
		_put(_hg_cell(h, hw + 1, yi, s, fy), 3)
	var glass: Dictionary = _cells.duplicate()
	_cells.clear()
	for yi in [-7, 7]:
		for x in range(-5, 6):
			_put(_hg_cell(h, x, yi, s, fy), 3 if yi < 0 else 2)
	var caps: Dictionary = _cells.duplicate()
	_cells.clear()
	_flush_union(ci, [[glass, PLUM], [caps, BONE]], 1.0, PLUM[0])
	## kum (mavi = kalkan): dönüşten önce alt hazne dolu, üstte son tane; sonra üst hazne boşalır, kum dışarı akar
	var rows: Array = []
	if not flipped:
		if t < 0.22:
			rows.append(-1)
		for yi in range(2, 7):
			rows.append(yi)
		if t < 0.22:
			for yi in range(0, 2):
				_cell(ci, _hg_cell(h, 0, yi, s, fy), BLUE[4], 1.0)
	else:
		var left: int = int(round(lerpf(5.0, 0.0, _k(t, 0.5, 0.8))))
		for j in left:
			rows.append(-1 - j)
		if left > 0:
			for yi in range(0, 7):
				_cell(ci, _hg_cell(h, 0, yi, s, fy), BLUE[4], 1.0)
	for yi in rows:
		var hw2: int = int(HG_HW[int(yi) + 6])
		for x in range(-hw2, hw2 + 1):
			_cell(ci, _hg_cell(h, x, yi, s, fy), BLUE[3] if x < hw2 else BLUE[2], 1.0)
	if t >= 0.48 and t < 0.6:
		_spark(ci, h, lerpf(7.0, 2.0, _k(t, 0.48, 0.6)), BLUE[5], BLUE[3], 1.0)


func _olum_b_beam(side: float, u: float) -> Vector2:
	var b: Vector2 = _o + FEET + Vector2(15.0 * side, -1.0)
	var c: Vector2 = _o + Vector2(25.0 * side, -12.0)
	var e: Vector2 = _o + Vector2(0.0, -40.0)
	return _bez(b, c, e, u)


const OB_TINES: Array = [[0.4, 7.0, -4.0], [0.66, 6.0, -6.0], [0.86, 3.5, -4.0]]


func _olum_b(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	## yer eşiği halkası
	if L == BACK:
		var kin: float = _eout(_k(t, 0.0, 0.12))
		var a: float = _band(1.0 - _k(t, 0.7, 0.95))
		var r: float = lerpf(26.0, 16.0, kin) / PX
		_ell(ci, _o + FEET, r, r * 0.38, PLUM[1], a * 0.3)
		_ring(ci, _o + FEET, r, PLUM[3], a, 0.38, 1)
		_ring(ci, _o + FEET, r - 2.0, PLUM[2], a * 0.7, 0.38, 1)
		return
	var grow: float = _eout(_k(t, 0.08, 0.38))
	## kalkan ışığı dolgusu (iki boynuz arası)
	var kf: float = _k(t, 0.38, 0.9)
	if t >= 0.38 and kf < 1.0:
		var pts := PackedVector2Array()
		var piv: Vector2 = _o + CHEST
		var shrink: float = lerpf(1.0, 0.45, _ein(_k(t, 0.55, 0.9)))
		for i in 13:
			pts.append(piv + (_olum_b_beam(-1.0, float(i) / 12.0) - piv) * shrink)
		for i in range(12, -1, -1):
			pts.append(piv + (_olum_b_beam(1.0, float(i) / 12.0) - piv) * shrink)
		_poly(pts, 3, false)
		var fa: float = 0.85 if t < 0.46 else _band(1.0 - _k(t, 0.6, 0.9)) * 0.75
		_flush_glow(ci, BLUE, fa, 0.6, -1000000000, 1.0, 0.4)
		if t < 0.56:
			_spark(ci, _olum_b_beam(1.0, 1.0), lerpf(8.0, 2.0, _k(t, 0.38, 0.56)), BLUE[5], BLUE[3], 1.0)
	## boynuzlar (büyür, sonra kırılıp parçalar düşer)
	if t < 0.52:
		for side in [-1.0, 1.0]:
			var n: int = 14
			for i in n:
				var u0: float = float(i) / float(n)
				var u1: float = float(i + 1) / float(n)
				if u0 >= grow:
					break
				u1 = minf(u1, grow)
				_seg(_olum_b_beam(side, u0), _olum_b_beam(side, u1), lerpf(1.8, 1.0, u0), lerpf(1.8, 1.0, u1), 2)
			for tn in OB_TINES:
				var tu: float = float(tn[0])
				var kt: float = _eout(_k(grow, tu + 0.05, minf(tu + 0.3, 1.0)))
				if kt <= 0.0:
					continue
				var p0: Vector2 = _olum_b_beam(side, tu)
				var tip: Vector2 = p0 + Vector2(float(tn[1]) * side, float(tn[2])) * kt
				_seg(p0, tip, 1.1, 0.6, 2)
		_flush(ci, BONE)
	else:
		if _chips.is_empty():
			for side in [-1.0, 1.0]:
				for j in 4:
					var u0b: float = float(j) * 0.25
					var a2: Vector2 = _olum_b_beam(side, u0b)
					var b2: Vector2 = _olum_b_beam(side, u0b + 0.2)
					_chips.append({"a": a2 - _o, "b": b2 - _o, "v": Vector2(side * _rng.randf_range(10, 34), _rng.randf_range(-40, -10)), "r": lerpf(1.6, 1.0, u0b)})
		var age: float = t - 0.52
		for ch in _chips:
			var off: Vector2 = (ch["v"] as Vector2) * age + Vector2(0, 260.0) * age * age * 0.5
			var rr: float = float(ch["r"]) * (1.0 - _k(age, 0.25, 0.5))
			if rr < 0.5:
				continue
			var mid: Vector2 = ((ch["a"] as Vector2) + (ch["b"] as Vector2)) * 0.5
			var half: Vector2 = ((ch["b"] as Vector2) - (ch["a"] as Vector2)) * 0.5 * (1.0 - _k(age, 0.15, 0.5) * 0.6)
			_seg(_o + mid + off - half, _o + mid + off + half, rr, rr * 0.7, 2)
		_flush(ci, BONE)


# ============================================================================ GÜNEŞİN İRADESİ
func _sun(center: Vector2, r: float, ray_len: float, rays: int, rot: float, tone: int = 3) -> void:
	for i in rays:
		var ang: float = rot + float(i) * TAU / float(rays)
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var ln: float = ray_len * (1.0 if i % 2 == 0 else 0.62)
		if ln < 0.6:
			continue
		var bw: float = clampf(r * 0.32, 0.9, 1.8)
		var pts := PackedVector2Array([center + (dir * (r - 0.5) + perp * bw) * PX, center + dir * (r + ln) * PX,
			center + (dir * (r - 0.5) - perp * bw) * PX])
		_poly(pts, tone + 1, false)
	_disc(center, r, tone)


func _gunes_a(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	var km: float = _sstep(_k(t, 1.0, 1.35))
	var c: Vector2 = (_o + Vector2(0, -10)).lerp(_o + Vector2(0, -42), km)
	var r: float = lerpf(7.0 * _eout(_k(t, 0.0, 0.18)), 2.6, km)
	var rl: float = lerpf(7.5 * _eout(_k(t, 0.12, 0.4)), 2.6, km)
	var rays: int = 8 if km < 0.5 else 4
	var rot: float = t * 0.55
	var behind: bool = km < 0.5
	var fin: float = 1.0 - _k(t, 2.75, 3.0)
	if (L == BACK) == behind and r > 0.3:
		_halo(ci, c, lerpf(17.0, 6.0, km) * minf(1.0, r / 4.0), GOLD, _band(fin))
		_sun(c, r, rl, rays, rot)
		_flush(ci, GOLD, _band(fin))
		if t >= 0.08 and t < 0.3:
			_spark(ci, c, lerpf(10.0, 3.0, _k(t, 0.08, 0.3)), GOLD[5], GOLD[3], 1.0)
	## iyileşme boyunca yükselen sıcak kıvılcımlar
	if L == TOP:
		for j in 8:
			var born: float = 1.25 + float(j) * 0.42
			var age: float = t - born
			if age < 0.0 or age > 0.7:
				continue
			var x: float = sin(float(j) * 2.3) * 8.0
			var p: Vector2 = _o + Vector2(x, CHEST.y + 6.0 - 15.0 * _eout(age / 0.7))
			_spark(ci, p, 2.0 if age < 0.35 else 1.0, GOLD[5], GOLD[3], _band(1.0 - _k(age, 0.45, 0.7)))


func _gunes_b(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	var feet: Vector2 = _o + FEET
	var w: float = 26.0 * _eout(_k(t, 0.0, 0.15)) * lerpf(1.0, 0.35, _ein(_k(t, 0.55, 0.82)))
	var top_y: float = _o.y - 150.0
	var bot_y: float = lerpf(feet.y, top_y, _ein(_k(t, 0.58, 0.85)))
	if L == BACK:
		if t < 0.85 and w > 0.5:
			for b in [[1.0, GOLD[3], 0.3], [0.62, GOLD[4], 0.38], [0.26, GOLD[5], 0.6]]:
				var hw: float = w * float(b[0]) * 0.5
				var x0: int = floori((_o.x - hw) / PX + 0.5)
				var x1: int = floori((_o.x + hw) / PX - 0.5)
				var y0: int = floori(top_y / PX)
				var y1: int = floori(bot_y / PX)
				if x1 >= x0 and y1 > y0:
					var col: Color = b[1]
					col.a *= float(b[2])
					ci.draw_rect(Rect2(Vector2(x0, y0) * PX, Vector2(x1 - x0 + 1, y1 - y0) * PX), col)
		## yerde ışık havuzu + halkalar
		var pool_a: float = _band(minf(_k(t, 0.04, 0.12), 1.0 - _k(t, 0.7, 0.9)))
		_halo(ci, feet, 18.0, GOLD, pool_a, 0.4)
		for i in 3:
			var kr: float = _k(t, 0.1 + 0.16 * float(i), 0.6 + 0.16 * float(i))
			if kr <= 0.0 or kr >= 1.0:
				continue
			_ring(ci, feet, lerpf(8.0, 28.0, _eout(kr)), GOLD[4], _band(1.0 - kr), 0.4, 1)
		## iyileşme boyunca ayakta küçük ışık havuzu
		var hp_a: float = _band(minf(_k(t, 0.8, 0.95), 1.0 - _k(t, 2.75, 3.0)))
		_halo(ci, feet, 11.0, GOLD, hp_a * 0.8, 0.4)
		return
	## ÜST: ışık sütununda inen pırıltılar
	for i in 3:
		var kd: float = _k(t, 0.04 + 0.07 * float(i), 0.42 + 0.07 * float(i))
		if kd <= 0.0 or kd >= 1.0:
			continue
		var x: float = [-5.0, 4.0, 8.0][i]
		var p: Vector2 = Vector2(_o.x + x, lerpf(_o.y - 90.0, feet.y - 4.0, _ein(kd)))
		_line(ci, p + Vector2(0, -6), p, GOLD[4], 0.55)
		_spark(ci, p, 2.0, GOLD[5], GOLD[3], 1.0)
	## iyileşme: havuzdan yükselen pırıltılar
	for j in 7:
		var born: float = 0.95 + float(j) * 0.3
		var age: float = t - born
		if age < 0.0 or age > 0.6:
			continue
		var xx: float = sin(float(j) * 1.9) * 9.0
		var q: Vector2 = Vector2(_o.x + xx, feet.y - 2.0 - 20.0 * _eout(age / 0.6))
		_spark(ci, q, 2.0 if age < 0.3 else 1.0, GOLD[5], GOLD[3], _band(1.0 - _k(age, 0.4, 0.6)))


# ============================================================================ TANRININ ELİ
const HAND_PALM: Array = [Vector2(-6, -5), Vector2(6, -5), Vector2(7, -2), Vector2(7, 4), Vector2(5, 6), Vector2(-5, 6), Vector2(-7, 4), Vector2(-7, -2)]
const HAND_FINGERS: Array = [[-5.0, 13.0], [-1.7, 15.5], [1.7, 15.0], [5.0, 12.0]]


func _hand(hc: Vector2) -> void:
	var pts := PackedVector2Array()
	for p in HAND_PALM:
		pts.append(hc + (p as Vector2) * PX)
	_poly(pts, 3, false)
	for f in HAND_FINGERS:
		_seg(hc + Vector2(float(f[0]), 4.0) * PX, hc + Vector2(float(f[0]), float(f[1])) * PX, 1.6, 1.4, 3)
	_seg(hc + Vector2(6.0, -1.0) * PX, hc + Vector2(10.0, 6.0) * PX, 1.7, 1.4, 3)
	_seg(hc + Vector2(0, -4) * PX, hc + Vector2(0, -34) * PX, 4.6, 5.6, 3)


func _anka_a(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	var y: float
	if t < 0.32:
		y = lerpf(-86.0, -28.0, _eout(t / 0.32))
	elif t < 0.55:
		y = -28.0
	else:
		y = lerpf(-28.0, -70.0, _ein(_k(t, 0.55, 0.95)))
	var hc: Vector2 = _o + Vector2(0, y)
	var a: float = _band(minf(_k(t, 0.0, 0.12) * 0.6 + 0.4, 1.0 - _k(t, 0.62, 0.95)))
	var touch: float = _k(t, 0.32, 0.8)
	if L == BACK:
		if t >= 0.32 and touch < 1.0:
			_ring(ci, _o + FEET, lerpf(6.0, 40.0, _eout(touch)), TEAL[3], _band(1.0 - touch), 0.42, 2)
			_ell(ci, _o + FEET, lerpf(6.0, 30.0, _eout(touch)), lerpf(6.0, 30.0, _eout(touch)) * 0.42, TEAL[2], _band(1.0 - touch) * 0.22)
		return
	if t < 0.95 and a > 0.0:
		_hand(hc)
		_flush_glow(ci, TEAL, a, 0.55, floori((hc.y - 8.0 * PX) / PX), 16.0)
	if t >= 0.32 and t < 0.52:
		_spark(ci, _o + HEAD, lerpf(10.0, 3.0, _k(t, 0.32, 0.52)), TEAL[5], TEAL[3], 1.0)
	if t >= 0.32 and t < 0.75:
		_halo(ci, _o + CHEST, 14.0, TEAL, _band(1.0 - _k(t, 0.4, 0.75)) * 0.7, 1.3)
	## başta kalan hale
	var ha: float = _band(minf(_k(t, 0.4, 0.5), 1.0 - _k(t, 1.25, 1.5)))
	_ring(ci, _o + Vector2(0, -36), 6.0, TEAL[3], ha, 0.36, 1)
	_ring(ci, _o + Vector2(0, -36), 5.0, TEAL[5], ha, 0.36, 1)


func _anka_b(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	var feet: Vector2 = _o + FEET
	if L == BACK:
		var fa: float = _band(1.0 - _k(t, 0.05, 0.25))
		_halo(ci, feet, 20.0, TEAL, fa, 0.4)
	## yükselen halkalar (arka yarısı karakterin arkasında)
	for i in 3:
		var b: float = float(i) * 0.1
		var k: float = _eout(_k(t, b, b + 0.5))
		if t < b or t > 0.64 + 0.05:
			continue
		var yy: float = lerpf(FEET.y, -36.0, k)
		var rx: float = lerpf(17.0, 6.5, k) / PX
		var a: float = _band(1.0 - _k(t, 0.58, 0.68)) if i < 2 else 1.0
		var c: Vector2 = _o + Vector2(0, yy)
		_ring_half(ci, c, rx, TEAL[3], a, 0.36, L == BACK, 2)
		_ring_half(ci, c, rx - 1.0, TEAL[5], a * 0.8, 0.36, L == BACK, 1)
	if L != TOP:
		return
	var hc: Vector2 = _o + Vector2(0, -36)
	var ha: float = _band(minf(_k(t, 0.58, 0.64), 1.0 - _k(t, 1.25, 1.5)))
	_ring(ci, hc, 6.5, TEAL[3], ha, 0.36, 2)
	_ring(ci, hc, 5.5, TEAL[5], ha, 0.36, 1)
	if t >= 0.6 and t < 0.8:
		_spark(ci, hc + Vector2(0, -2), lerpf(9.0, 3.0, _k(t, 0.6, 0.8)), TEAL[5], TEAL[3], 1.0)
	for i in 4:
		var born: float = 0.62 + float(i) * 0.08
		var age: float = t - born
		if age < 0.0 or age > 0.45:
			continue
		var x: float = [-9.0, -3.0, 4.0, 10.0][i]
		var p: Vector2 = _o + Vector2(x, CHEST.y + 8.0 - 22.0 * _eout(age / 0.45))
		var aa: float = _band(1.0 - _k(age, 0.3, 0.45))
		_line(ci, p, p + Vector2(0, 5.0 * PX), TEAL[3], aa * 0.8)
		_cell(ci, _cellv(p), TEAL[5], aa)


# ============================================================================ ÜRKEK YÜREK
func _urkek_frac() -> float:
	if owner_node == null or not is_instance_valid(owner_node):
		return 0.0
	return clampf(float(owner_node.get("_item_urkek_timer")) / 6.0, 0.0, 1.0)


func _move_dir() -> Vector2:
	if owner_node != null and is_instance_valid(owner_node) and "velocity" in owner_node:
		var v: Vector2 = owner_node.get("velocity")
		if v.length() > 5.0:
			return v.normalized()
	return Vector2.RIGHT


func _urkek_step(delta: float) -> void:
	var f: float = _urkek_frac()
	var d: Vector2 = _move_dir()
	if variant == "A":
		_streak_acc += delta * 26.0 * f
		while _streak_acc >= 1.0:
			_streak_acc -= 1.0
			var side := Vector2(-d.y, d.x)
			var p: Vector2 = _o + Vector2(0, -2) - d * _rng.randf_range(6.0, 11.0) + side * _rng.randf_range(-13.0, 12.0)
			_streaks.append({"p": p, "d": d, "len": _rng.randf_range(5.0, 10.0), "t0": _t})
	else:
		_ghost_acc += delta
		var interval: float = lerpf(0.16, 0.06, f)
		if f > 0.04 and _ghost_acc >= interval:
			_ghost_acc = 0.0
			var spr: AnimatedSprite2D = owner_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if spr != null and spr.sprite_frames != null:
				var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
				if tex != null:
					var sz: Vector2 = tex.get_size()
					var ofs: Vector2 = spr.offset - (sz * 0.5 if spr.centered else Vector2.ZERO)
					var rect := Rect2(ofs, sz)
					if spr.flip_h:
						rect = Rect2(Vector2(ofs.x + sz.x, ofs.y), Vector2(-sz.x, sz.y))
					_ghosts.append({"tex": tex, "xf": spr.get_global_transform(), "rect": rect, "t0": _t})


func _heart(center: Vector2, r: float) -> void:
	var cc: Vector2 = center / PX
	for y in range(floori(cc.y - r * 1.2), floori(cc.y + r * 1.2) + 1):
		for x in range(floori(cc.x - r * 1.3), floori(cc.x + r * 1.3) + 1):
			var nx: float = (float(x) + 0.5 - cc.x) / r
			var ny: float = -(float(y) + 0.5 - cc.y) / r + 0.15
			var q: float = nx * nx + ny * ny - 1.0
			if q * q * q - nx * nx * ny * ny * ny > 0.0:
				continue
			var tone: int = 2
			if ny > 0.35 and nx < 0.1:
				tone = 3
			if ny < -0.45:
				tone = 1
			if r >= 3.0 and Vector2(nx + 0.5, ny - 0.55).length() < 0.28:
				tone = 4
			_put(Vector2i(x, y), tone)


func _urkek_a(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		return
	if L == BACK:
		for st in _streaks:
			var age: float = t - float(st["t0"])
			if age < 0.0 or age > 0.24:
				continue
			var ln: float = float(st["len"]) * (1.0 - _k(age, 0.06, 0.24))
			var p: Vector2 = st["p"]
			var d: Vector2 = st["d"]
			_line(ci, p, p - d * ln * 0.5 * PX, DUST[5], 0.85)
			_line(ci, p - d * ln * 0.5 * PX, p - d * ln * PX, DUST[4], 0.45)
		return
	var s: float
	if t < 0.08:
		s = 1.15 * _eout(t / 0.08)
	else:
		s = 1.0
		for tb in [0.14, 0.38]:
			var kb: float = _k(t, tb, tb + 0.13)
			if kb > 0.0 and kb < 1.0:
				s += 0.34 * sin(PI * kb)
		s *= 1.0 - _ein(_k(t, 0.6, 0.76))
	var c: Vector2 = _o + Vector2(0, -42)
	if s > 0.12:
		_heart(c, 4.2 * s)
		_flush(ci, CRIM)
	for tb2 in [0.14, 0.38]:
		var ka: float = _k(t, tb2, tb2 + 0.16)
		if ka <= 0.0 or ka >= 1.0:
			continue
		var rr: float = lerpf(6.5, 9.5, _eout(ka))
		var aa: float = _band(1.0 - _k(ka, 0.5, 1.0))
		_ring(ci, c, rr, CRIM[3], aa, 1.0, 1, -0.5, 0.5)
		_ring(ci, c, rr, CRIM[3], aa, 1.0, 1, PI - 0.5, PI + 0.5)


func _urkek_b(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == GHOST:
		for g in _ghosts:
			var age: float = t - float(g["t0"])
			if age < 0.0 or age > 0.3:
				continue
			var a: float = 0.5 * _band(1.0 - age / 0.3)
			if a <= 0.0:
				continue
			var col: Color = CRIM[3]
			col.a = a
			ci.draw_set_transform_matrix(g["xf"])
			ci.draw_texture_rect(g["tex"], g["rect"], false, col)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if L == BACK:
		## kalkış tozu
		for i in 2:
			var kd: float = _k(t, 0.02 + 0.06 * float(i), 0.4 + 0.06 * float(i))
			if kd <= 0.0 or kd >= 1.0:
				continue
			var d: Vector2 = _move_dir()
			var p: Vector2 = _o + FEET + Vector2(0, -1) - d * (6.0 + 8.0 * _eout(kd) + 4.0 * float(i)) + Vector2(0, -4.0 * _eout(kd))
			_disc(p, lerpf(2.4, 0.8, kd), 3, false)
		_flush(ci, DUST)
		return
	## korku çizgileri
	var hc: Vector2 = _o + Vector2(0, -10)
	var kf: float = _k(t, 0.0, 0.4)
	if kf < 1.0:
		var aa: float = _band(1.0 - _k(kf, 0.6, 1.0))
		var push: float = 2.0 * _eout(_k(kf, 0.0, 0.3))
		for ang in [-2.85, -2.35, -0.79, -0.29]:
			var dir := Vector2(cos(ang), sin(ang))
			var r0: float = 9.5 + push
			_line(ci, hc + dir * r0 * PX, hc + dir * (r0 + 3.0) * PX, CRIM[3], aa)
			_line(ci, hc + dir * r0 * PX + Vector2(PX, 0), hc + dir * (r0 + 3.0) * PX + Vector2(PX, 0), CRIM[2], aa * 0.8)
	## ter damlası
	var kw: float = _k(t, 0.05, 0.6)
	if kw > 0.0 and kw < 1.0:
		var sp: Vector2 = _o + Vector2(-9, -12 + 5.0 * _ein(kw))
		var sz: float = 1.0 - _k(kw, 0.75, 1.0) * 0.5
		_disc(sp, 1.5 * sz, 3, false)
		_seg(sp, sp + Vector2(0, -3.2 * sz) * PX, 1.1 * sz, 0.6, 3)
		_flush(ci, BLUE)


# ============================================================================ KEMİK KOLYE
func _kemik_n() -> int:
	if owner_node == null or not is_instance_valid(owner_node):
		return 0
	return int(owner_node.get("_item_kemik_charges"))


func _kemik_step() -> void:
	var n: int = _kemik_n()
	if n > _prev_n:
		_pop_t = _t
	elif n < _prev_n:
		for i in range(n, _prev_n):
			if variant == "A":
				var ang: float = _ka_angle(i)
				var d := Vector2(cos(ang), sin(ang) * 0.37).normalized()
				_flying.append({"p": _ka_pos(i) - _o, "d": d, "t0": _t, "back": sin(ang) < 0.0})
			else:
				_flying.append({"p": _kb_pos(i) - _o, "d": Vector2(cos(_kb_phi(i)), sin(_kb_phi(i))), "t0": _t, "back": false})
	_prev_n = n


func _fang(at: Vector2, s: float, rot: float, tone: int = 3) -> void:
	if s < 0.35:
		_put(_cellv(at), tone)
		return
	var shape: Array = [Vector2(-1.6, -0.6), Vector2(1.6, -0.6), Vector2(1.3, 1.6), Vector2(0.3, 4.4), Vector2(-0.7, 2.2)]
	var pts := PackedVector2Array()
	for v in shape:
		pts.append(at + (v as Vector2).rotated(rot) * s * PX)
	_poly(pts, tone, true)


func _ka_angle(i: int) -> float:
	return _t * 1.8 + float(i) * TAU / 6.0


func _ka_pos(i: int) -> Vector2:
	var a: float = _ka_angle(i)
	return _o + Vector2(0, 3) + Vector2(cos(a) * 15.0, sin(a) * 5.5)


func _kemik_a(L: int, ci: CanvasItem) -> void:
	if L == GHOST:
		return
	var n: int = _kemik_n()
	var kp: float = _k(_t, _pop_t, _pop_t + 0.28)
	if kp > 0.0 and kp < 1.0:
		_ring_half(ci, _o + Vector2(0, 3), lerpf(10.0, 22.0, _eout(kp)), BONE[4], _band(1.0 - kp), 0.37, L == BACK, 1)
	for i in n:
		var a: float = _ka_angle(i)
		if (sin(a) < 0.0) != (L == BACK):
			continue
		var s: float = _eout(_k(_t, _pop_t + float(i) * 0.05, _pop_t + float(i) * 0.05 + 0.12))
		_fang(_ka_pos(i), s, 0.0, 3 if L == TOP else 2)
	_flush(ci, BONE)
	_draw_flying(L, ci)


func _draw_flying(L: int, ci: CanvasItem) -> void:
	for f in _flying:
		var age: float = _t - float(f["t0"])
		if age < 0.0 or age > 0.5:
			continue
		var on_back: bool = bool(f["back"]) and age < 0.12
		if on_back != (L == BACK):
			continue
		var d: Vector2 = f["d"]
		var p: Vector2 = _o + (f["p"] as Vector2) + d * 12.0 * _eout(minf(age, 0.16) / 0.16)
		if age < 0.16:
			_fang(p, 1.0, 0.0 if variant == "A" else (atan2(d.y, d.x) - PI * 0.5), 3)
		else:
			var a2: float = age - 0.16
			var perp := Vector2(-d.y, d.x)
			for sgn in [-1.0, 1.0]:
				var q: Vector2 = p + perp * sgn * 16.0 * a2 + Vector2(0, 240.0) * a2 * a2 * 0.5 + Vector2(0, -10.0 * a2)
				_disc(q, lerpf(1.2, 0.5, _k(a2, 0.0, 0.3)), 3, false)
	_flush(ci, BONE)
	if L == TOP:
		for f2 in _flying:
			var age2: float = _t - float(f2["t0"])
			if age2 >= 0.14 and age2 < 0.26:
				var d2: Vector2 = f2["d"]
				_spark(ci, _o + (f2["p"] as Vector2) + d2 * 12.0, lerpf(3.0, 1.0, _k(age2, 0.14, 0.26)), BONE[5], BONE[3], 1.0)


const KB_CROWN := Vector2(0, -30)
const KB_R := 9.0


func _kb_phi(i: int) -> float:
	return -PI * 0.5 + (float(i) - 2.5) * 0.4


func _kb_pos(i: int) -> Vector2:
	return _o + KB_CROWN + Vector2(cos(_kb_phi(i)), sin(_kb_phi(i))) * KB_R


func _kb_jaw_pos(i: int, gap: float) -> Vector2:
	var j: Vector2 = _o + Vector2(0, -3)
	var col: int = i % 3
	var x: float = (float(col) - 1.0) * 3.6
	if i < 3:
		return j + Vector2(x, -gap * 0.5 - 2.0) * PX
	return j + Vector2(x, gap * 0.5 + 2.0) * PX


func _kemik_b(L: int, ci: CanvasItem) -> void:
	if L != TOP:
		return
	var n: int = _kemik_n()
	var tp: float = _t - _pop_t
	if tp >= 0.0 and tp < 0.5:
		var gap: float = lerpf(8.0, 0.0, _ein(_k(tp, 0.0, 0.16)))
		var jaw_a: float = _band(1.0 - _k(tp, 0.24, 0.3))
		if tp < 0.3:
			## diş etleri (kemik çubuk) + 3 üst (uç aşağı) + 3 alt (uç yukarı) diş
			var j: Vector2 = _o + Vector2(0, -3)
			_seg(j + Vector2(-6, -gap * 0.5 - 2.6) * PX, j + Vector2(6, -gap * 0.5 - 2.6) * PX, 1.1, 1.1, 1)
			_seg(j + Vector2(-6, gap * 0.5 + 2.6) * PX, j + Vector2(6, gap * 0.5 + 2.6) * PX, 1.1, 1.1, 1)
			for i in 6:
				_fang(_kb_jaw_pos(i, gap), 0.8, 0.0 if i < 3 else PI, 3)
			_flush(ci, BONE, jaw_a)
		if tp >= 0.16 and tp < 0.32:
			var kk: float = _k(tp, 0.16, 0.32)
			var j2: Vector2 = _o + Vector2(0, -3)
			_spark(ci, j2, lerpf(6.0, 2.0, kk), BONE[5], BONE[3], 1.0)
			for sgn in [-1.0, 1.0]:
				var x0: float = sgn * (8.0 + 4.0 * _eout(kk))
				_line(ci, j2 + Vector2(x0, 0) * PX, j2 + Vector2(x0 + sgn * 3.0, 0) * PX, BONE[4], _band(1.0 - kk))
	## taç: dişler çeneden yerine uçar
	for i in n:
		var kt: float = _sstep(_k(tp, 0.24 + float(i) * 0.03, 0.46 + float(i) * 0.03))
		if tp < 0.24:
			continue
		var src: Vector2 = _kb_jaw_pos(i, 0.0)
		var dst: Vector2 = _kb_pos(i)
		var c: Vector2 = (src + dst) * 0.5 + Vector2((float(i) - 2.5) * 3.0, -8.0)
		var p: Vector2 = _bez(src, c, dst, kt)
		var rot: float = lerpf(0.0 if i < 3 else PI, _kb_phi(i) - PI * 0.5, kt)
		_fang(p, lerpf(0.8, 1.0, kt), rot, 3)
	_flush(ci, BONE)
	_draw_flying(L, ci)
