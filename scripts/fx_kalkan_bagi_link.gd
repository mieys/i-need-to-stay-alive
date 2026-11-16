extends Node2D

## Ruhani Yetenek "Kalkan Bağı"nın görseli. HER İKİ oyuncunun da KENDİ üstünde duran bir kopyası vardır (kaster VE partner, bkz.
## player.gd _ensure_kalkan_bagi_link_fx / remote_player.gd _refresh_kalkan_bagi_link_visual) - "kaster görür, diğerleri görmez"
## hatasına düşmemek için. Kurdeleyi YALNIZ bir kopya çizer (karşılıklı bağda peer_id'si küçük olan, bkz. _partner_local_pos);
## iki kopya da kendi göğsündeki ışığı çizer.
## Görünüm = prototip "A Ruh Işığı" (madde 730, kullanıcı seçimi 2026-11-16, madde 734) - eski kayan 1 px hat + gezen rozet +
## uç elmasları (assets/fx/kalkan_bagi/) silindi:
##  - iki göğüs arasında hafif sarkan, yavaşça dalgalanan ışık kurdelesi (3 düz bant: dış/orta soluk mavi, 1 px açık çekirdek),
##    karakterlerin ARKASINDA; bağ kurulunca 0,25 sn'de partnere uzanır
##  - iki göğüste nefes alan küçük ışık
##  - pulse_from(kaynak_peer): bağdan kalkan aktığında (yansıyan hasar/bedel/artış) kaynaktan hedefe 0,4 sn'de akan ışık boncuğu
##    (kurdele boncuğun çevresinde kalınlaşır), varışta hedefin gövdesinde açılan halka + kısa kabuk parlaması.
##    Çağıran: NetworkManager.kalkan_bagi_pulse_visual (yansımayı gönderen istemci yerelde, diğerleri RPC'yi alınca).
## Kök ayakta, 1 yerel birim = 1 dünya birimi (bkz. spirit_fx_util.gd).

const U := preload("res://scripts/spirit_fx_util.gd")
const DOT_TEX := preload("res://assets/fx/ruhani/kb_dot.png") ## 3 kare: boncuk r 4,5 / uç r 3,5 / uç r 4,1
const RING_TEX := preload("res://assets/fx/ruhani/ring_tall.png") ## 10 kare rx 5..14 (ry 1,25 rx)
const SHELL_TEX := preload("res://assets/fx/ruhani/shell_white.png")

const BODY_Y := -16.0 ## ayaktan göğüs
const SAG := 6.0
const WAVE := 0.9
const GROW := 0.25
const BEAD_TRAVEL := 0.4
const ARRIVE := 0.32
const PULSE_GAP := 0.3 ## aynı yönde iki boncuk arası en az (sık yansımalar sel olmasın)

var _owner_ref: Node2D = null
var _t: float = 0.0
var _shown_t: float = -1.0 ## kurdelenin göründüğü an (-1 = görünmüyor)
var _beads: Array = [] ## [doğuş _t, sahipten mi (bool)]
var _last_pulse: Dictionary = {true: -9.0, false: -9.0}
var _front: Node2D = null


func setup(owner_node: Node2D) -> void:
	_owner_ref = owner_node


func _ready() -> void:
	U.setup_root(self)
	show_behind_parent = true
	_front = U.front_layer(self, _draw_front)


func pulse_from(src_peer: int) -> void:
	if _partner_local_pos().length() < 4.0:
		return ## kurdeleyi bu kopya çizmiyor (ya da bağ görünmüyor)
	var from_owner: bool = src_peer == _owner_peer_id()
	if _t - float(_last_pulse[from_owner]) < PULSE_GAP:
		return
	_last_pulse[from_owner] = _t
	_beads.append([_t, from_owner])
	if _beads.size() > 4:
		_beads.pop_front()


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_owner_ref):
		queue_free()
		return
	if _partner_local_pos().length() >= 4.0:
		if _shown_t < 0.0:
			_shown_t = _t
	else:
		_shown_t = -1.0
	_beads = _beads.filter(func(b: Array) -> bool: return _t - float(b[0]) < BEAD_TRAVEL + ARRIVE)
	queue_redraw()
	_front.queue_redraw()


func _ends() -> Array:
	var to_partner: Vector2 = _partner_local_pos()
	return [Vector2(0.0, BODY_Y), to_partner + Vector2(0.0, 15.0 + BODY_Y)]


func _curve(p0: Vector2, p1: Vector2) -> PackedVector2Array:
	var span: Vector2 = p1 - p0
	var length: float = span.length()
	var n: Vector2 = Vector2(-span.y, span.x) / maxf(length, 0.001)
	var steps: int = clampi(int(length / 2.0), 8, 160)
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var s: float = float(i) / float(steps)
		var w: float = WAVE * sin(TAU * (s * length / 70.0 - _t * 0.6)) * sin(PI * s)
		pts.append(p0 + span * s + Vector2(0.0, SAG * 4.0 * s * (1.0 - s)) + n * w)
	return pts


func _sub(pts: PackedVector2Array, s0: float, s1: float) -> PackedVector2Array:
	var last: int = pts.size() - 1
	var a: int = clampi(int(floorf(s0 * last)), 0, last)
	var b: int = clampi(int(ceilf(s1 * last)), 0, last)
	return pts.slice(a, b + 1)


func _bead_s(b: Array) -> float:
	var u: float = U.ease_io((_t - float(b[0])) / BEAD_TRAVEL)
	return u if bool(b[1]) else 1.0 - u


func _draw() -> void:
	if _shown_t < 0.0:
		return
	var e: Array = _ends()
	var pts: PackedVector2Array = _curve(e[0], e[1])
	var g: float = U.ease_out((_t - _shown_t) / GROW)
	var vis: PackedVector2Array = _sub(pts, 0.0, g)
	if vis.size() < 2:
		return
	draw_polyline(vis, U.with_a(U.MANA3, 0.16), 5.2)
	draw_polyline(vis, U.with_a(U.MANA3, 0.32), 3.2)
	draw_polyline(vis, U.with_a(U.MANA4, 0.85), 1.0)
	for b in _beads:
		if _t - float(b[0]) < BEAD_TRAVEL:
			var s: float = _bead_s(b)
			var seg: PackedVector2Array = _sub(pts, maxf(0.0, s - 0.06), minf(1.0, s + 0.06))
			if seg.size() >= 2:
				draw_polyline(seg, U.with_a(U.MANA3, 0.32), 6.0)


func _draw_front() -> void:
	var pid: int = _partner_pid()
	if pid <= 0 or _find_partner(pid) == null:
		return
	var br: float = 0.5 + 0.5 * sin(TAU * 0.8 * _t)
	U.frame(_front, DOT_TEX, 3, 2 if br > 0.5 else 1, 0.0, BODY_Y, U.with_a(Color.WHITE, U.band(0.55 + 0.15 * br, 4)))
	if _shown_t < 0.0:
		return
	var e: Array = _ends()
	var pts: PackedVector2Array = _curve(e[0], e[1])
	var g: float = U.ease_out((_t - _shown_t) / GROW)
	if g < 1.0:
		var head: Vector2 = pts[clampi(int(g * (pts.size() - 1)), 0, pts.size() - 1)]
		U.frame(_front, DOT_TEX, 3, 1, head.x, head.y, U.with_a(Color.WHITE, 0.9))
	for b in _beads:
		var age: float = _t - float(b[0])
		if age < BEAD_TRAVEL:
			var p: Vector2 = pts[clampi(int(roundf(_bead_s(b) * (pts.size() - 1))), 0, pts.size() - 1)]
			U.frame(_front, DOT_TEX, 3, 0, p.x, p.y, U.with_a(Color.WHITE, 0.95))
		else:
			var k2: float = (age - BEAD_TRAVEL) / ARRIVE
			var tgt: Vector2 = e[1] if bool(b[1]) else e[0]
			var rx: float = 5.0 + 9.0 * U.ease_out(k2)
			U.frame(_front, RING_TEX, 10, int(roundf(rx)) - 5, tgt.x, tgt.y, U.with_a(U.MANA4, U.band(1.0 - k2, 4)))
			U.frame(_front, SHELL_TEX, 1, 0, tgt.x, tgt.y, U.with_a(U.MANA3, U.band(0.3 * (1.0 - k2), 4)))


func _owner_peer_id() -> int:
	if "peer_id" in _owner_ref:
		return int(_owner_ref.get("peer_id"))
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0


func _partner_pid() -> int:
	if not is_instance_valid(_owner_ref) or not ("_kalkan_bagi_partner_peer_id" in _owner_ref):
		return 0
	return int(_owner_ref.get("_kalkan_bagi_partner_peer_id"))


func _find_partner(pid: int) -> Node2D:
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == pid:
			return rp as Node2D
	if multiplayer.has_multiplayer_peer() and pid == multiplayer.get_unique_id():
		return get_tree().get_first_node_in_group("player") as Node2D
	return null


## Kurdeleyi BU kopya mı çiziyor: evetse partnerin kökü (yerel = dünya birimi, ayaktan), hayırsa ZERO.
## İki oyuncu da bağlıyken (mutual) yalnız peer_id'si küçük olan çizer - iki kat parlak kurdele olmasın.
func _partner_local_pos() -> Vector2:
	var pid: int = _partner_pid()
	if pid <= 0:
		return Vector2.ZERO
	var partner: Node2D = _find_partner(pid)
	if partner == null or not is_instance_valid(partner):
		return Vector2.ZERO
	var owner_pid: int = _owner_peer_id()
	var mutual: bool = "_kalkan_bagi_partner_peer_id" in partner and int(partner.get("_kalkan_bagi_partner_peer_id")) == owner_pid
	if mutual and owner_pid > pid:
		return Vector2.ZERO
	if not mutual and not ("peer_id" in partner):
		return Vector2.ZERO
	return to_local(partner.global_position)


func get_glow_segment() -> Array:
	if _partner_local_pos().length() < 4.0:
		return []
	var e: Array = _ends()
	return [to_global(e[0]), to_global(e[1])]
