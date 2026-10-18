extends Node2D

## Görev ağacının SİHİRLİ ATIŞI (2026-10-18, kullanıcı: "ağaç parıltılı mavi taşından sihirli bir atış yapsın, düşmanlara hasar verip uzaklaştırsın;
## boss varsa bossa odaklansın, onu da itebilsin"). mission_tree.gd BLAST_INTERVAL'da bir kurar (hedef: menzildeki boss öncelikli, yoksa en yakın yaratık).
## Önce kristalde CHARGE_TIME şarj (büyüyen parıltı), sonra hedefe güdümlü küre; çarpınca BLAST_RADIUS içindeki yaratıklara hasar + AĞAÇTAN DIŞA itiş
## (apply_skill_push - C++ bosslarda x0,4 uygular, o yüzden boss'a BOSS_PUSH_DISTANCE büyük verilir: ~60 px).
## Ağ: kristal mermisiyle (mission_tree_bolt.gd) aynı desen - HER istemcide yerel doğar, hasar ve itişi SADECE damage > 0 olan kopya (host / tek oyunculu)
## uygular. İstemcide apply_skill_push host'a RPC atardı (çift itiş), bu yüzden istemci kopyası hiç çağırmaz; itilen konum host'un konum yayınıyla gelir.

const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

const CHARGE_TIME := 0.45
const SPEED := 360.0
const MAX_FLY := 2.0
const HIT_RADIUS := 12.0
const BLAST_RADIUS := 56.0
const BOSS_HIT_SLACK := 24.0 ## boss gövdesi büyük: merkezine bu kadar fazla mesafe de isabet sayılır
const PUSH_DISTANCE := 90.0
const BOSS_PUSH_DISTANCE := 150.0 ## C++ SKILL_PUSH_BOSS_MULT 0,4 -> ~60 px
const BURST_TIME := 0.4
const TRAIL_LEN := 8
const AIM_UP := Vector2(0.0, -10.0) ## gövde ortası (kristal mermisiyle aynı)

const CORE := Color(0.82, 0.98, 1.0)
const MID := Color(0.45, 0.85, 1.0)
const EDGE := Color(0.22, 0.55, 0.9)
const GLOW := Color(0.45, 0.8, 1.0, 0.22)

enum Phase { CHARGE, FLY, BURST }

var target: Node2D = null
var damage: float = 0.0
var push_origin: Vector2 = Vector2.ZERO
var _phase: int = Phase.CHARGE
var _t: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _aim: Vector2 = Vector2.ZERO
var _trail: PackedVector2Array = PackedVector2Array()


func setup(p_target: Node2D, p_damage: float, p_push_origin: Vector2) -> void:
	target = p_target
	damage = p_damage
	push_origin = p_push_origin
	if p_target != null:
		_aim = p_target.global_position + AIM_UP


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _target_alive() -> bool:
	return target != null and is_instance_valid(target) and target.get("is_dead") != true


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.CHARGE:
			if _target_alive():
				_aim = target.global_position + AIM_UP
			if _t >= CHARGE_TIME:
				_phase = Phase.FLY
				_t = 0.0
		Phase.FLY:
			if _target_alive():
				_aim = target.global_position + AIM_UP
			var to: Vector2 = _aim - global_position
			if to.length() <= HIT_RADIUS + SPEED * delta or _t > MAX_FLY:
				_explode()
				return
			_dir = to.normalized()
			_trail.append(global_position)
			if _trail.size() > TRAIL_LEN:
				_trail.remove_at(0)
			global_position += _dir * SPEED * delta
		Phase.BURST:
			if _t >= BURST_TIME:
				queue_free()
				return
	queue_redraw()


func _explode() -> void:
	_phase = Phase.BURST
	_t = 0.0
	_trail.clear()
	if damage > 0.0 and is_inside_tree():
		_apply_hits()
	queue_redraw()


## Alan hasarı + ağaçtan dışa itiş (sadece host / tek oyunculu kopya).
func _apply_hits() -> void:
	var center: Vector2 = global_position - AIM_UP
	var hit: Array = EnemyQueryScript.candidates(get_tree(), center, BLAST_RADIUS + BOSS_HIT_SLACK + 1.0)
	if _target_alive() and not hit.has(target):
		hit.append(target)
	for e: Node in hit:
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true:
			continue
		var is_boss: bool = e.is_in_group("boss") or e.get("is_boss") == true
		var pos: Vector2 = (e as Node2D).global_position
		if e != target and pos.distance_to(center) > BLAST_RADIUS + (BOSS_HIT_SLACK if is_boss else 0.0):
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", damage, false, 0.0, true)
		if e.has_method("apply_skill_push"):
			var away: Vector2 = pos - push_origin
			e.call("apply_skill_push", away.normalized() if away.length() > 0.5 else _dir, BOSS_PUSH_DISTANCE if is_boss else PUSH_DISTANCE)


## --- çizim (dünya pikseli ızgarasında; yuvarlak hatlar satır satır dikdörtgen) ---

func _disc(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	var ri: int = int(ceil(r))
	var cx: float = roundf(c.x)
	var cy: float = roundf(c.y)
	for y in range(-ri, ri + 1):
		var w: int = int(roundf(sqrt(maxf(r * r - float(y * y), 0.0))))
		if w <= 0 and absi(y) == ri:
			continue
		draw_rect(Rect2(cx - w, cy + y, w * 2 + 1, 1), col)


func _ring(c: Vector2, r: float, col: Color, px: float) -> void:
	var n: int = maxi(8, int(TAU * r / 2.0))
	for i in range(n):
		var p: Vector2 = (c + Vector2.from_angle(TAU * float(i) / float(n)) * r).round()
		draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)), col)


func _crystal(c: Vector2, s: float) -> void:
	## dikey eşkenar dörtgen kristal (kristal mermisinin büyük hâli)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6) * s, c + Vector2(4, 0) * s, c + Vector2(0, 6) * s, c + Vector2(-4, 0) * s]), EDGE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4) * s, c + Vector2(2, 0) * s, c + Vector2(0, 4) * s, c + Vector2(-2, 0) * s]), MID)
	draw_rect(Rect2((c + Vector2(-1, -2) * s).round(), Vector2(1, 2) * maxf(s, 1.0)), CORE)


func _draw() -> void:
	match _phase:
		Phase.CHARGE:
			var k: float = clampf(_t / CHARGE_TIME, 0.0, 1.0)
			_disc(Vector2.ZERO, 3.0 + 9.0 * k, Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * (0.5 + k)))
			## içe çekilen 4 zerre
			for i in range(4):
				var a: float = TAU * float(i) / 4.0 + k * 2.2
				var p: Vector2 = (Vector2.from_angle(a) * (16.0 * (1.0 - k) + 4.0)).round()
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(CORE.r, CORE.g, CORE.b, 0.5 + 0.5 * k))
			_crystal(Vector2.ZERO, 0.5 + 0.6 * k)
		Phase.FLY:
			for i in range(_trail.size()):
				var lp: Vector2 = to_local(_trail[i])
				var a: float = float(i + 1) / float(_trail.size() + 1)
				_disc(lp, 1.0 + 3.0 * a, Color(MID.r, MID.g, MID.b, 0.45 * a))
			_disc(Vector2.ZERO, 9.0, GLOW)
			_disc(Vector2.ZERO, 5.0, EDGE)
			_disc(Vector2.ZERO, 3.0, MID)
			_disc(Vector2(-1, -1), 1.0, CORE)
		Phase.BURST:
			var k: float = clampf(_t / BURST_TIME, 0.0, 1.0)
			var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
			var fade: float = 1.0 - k
			if k < 0.35:
				_disc(Vector2.ZERO, 6.0 + 10.0 * (k / 0.35), Color(CORE.r, CORE.g, CORE.b, 0.55 * (1.0 - k / 0.35)))
			_ring(Vector2.ZERO, 6.0 + (BLAST_RADIUS - 6.0) * ease_k, Color(MID.r, MID.g, MID.b, 0.9 * fade), 2.0)
			_ring(Vector2.ZERO, (BLAST_RADIUS - 10.0) * ease_k, Color(EDGE.r, EDGE.g, EDGE.b, 0.5 * fade), 1.0)
			for i in range(8):
				var p: Vector2 = (Vector2.from_angle(TAU * float(i) / 8.0 + 0.4) * (4.0 + (BLAST_RADIUS + 8.0) * ease_k)).round()
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(CORE.r, CORE.g, CORE.b, fade))
