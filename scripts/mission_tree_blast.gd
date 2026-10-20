extends Node2D

## Görev ağacının SİHİRLİ ATIŞI (2026-10-18, kullanıcı: "ağaç parıltılı mavi taşından sihirli bir atış yapsın, düşmanlara hasar verip uzaklaştırsın;
## boss varsa bossa odaklansın, onu da itebilsin"). mission_tree.gd BLAST_INTERVAL'da bir kurar (hedef: menzildeki boss öncelikli, yoksa en yakın yaratık).
## Önce kristalde CHARGE_TIME şarj (büyüyen parıltı), sonra hedefe güdümlü küre; çarpınca BLAST_RADIUS içindeki yaratıklara hasar + AĞAÇTAN DIŞA itiş
## (apply_skill_push - C++ bosslarda x0,4 uygular, o yüzden boss'a BOSS_PUSH_DISTANCE büyük verilir: ~60 px).
## Ağ: kristal mermisiyle (mission_tree_bolt.gd) aynı desen - HER istemcide yerel doğar, hasar ve itişi SADECE damage > 0 olan kopya (host / tek oyunculu)
## uygular. İstemcide apply_skill_push host'a RPC atardı (çift itiş), bu yüzden istemci kopyası hiç çağırmaz; itilen konum host'un konum yayınıyla gelir.

const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const Fx := preload("res://scripts/mission_tree_fx_draw.gd")

const CHARGE_TIME := 0.35 ## 2026-10-19: 0,45 -> 0,35 (daha seri atış); kristal bu sürede ağaçta da parlar (mission_tree_crystal_glow.gd charge)
const SPEED := 360.0
const MAX_FLY := 2.0
const HIT_RADIUS := 12.0
const BLAST_RADIUS := 56.0
const BOSS_HIT_SLACK := 24.0 ## boss gövdesi büyük: merkezine bu kadar fazla mesafe de isabet sayılır
const PUSH_DISTANCE := 90.0
const BOSS_PUSH_DISTANCE := 150.0 ## C++ SKILL_PUSH_BOSS_MULT 0,4 -> ~60 px
const BURST_TIME := 0.4
const TRAIL_PX := 64.0 ## iz boyu (dünya px)
const AIM_UP := Vector2(0.0, -10.0) ## gövde ortası (kristal mermisiyle aynı)

## 2026-10-19 (kullanıcı: "atışlar çok ufak ve görünmüyor"; madde 317): küre yarıçapı 5 -> 10 dünya px, toplamsal hale 22 px, kalın iz + kıvılcım, büyük patlama.
const SPARK_EVERY := 0.03
const SPARK_LIFE := 0.35

enum Phase { CHARGE, FLY, BURST }

var target: Node2D = null
var damage: float = 0.0
var push_origin: Vector2 = Vector2.ZERO
var _phase: int = Phase.CHARGE
var _t: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _aim: Vector2 = Vector2.ZERO
var _trail: PackedVector2Array = PackedVector2Array()
var _sparks: Array = [] ## [dünya konumu, yaş]
var _spark_acc: float = 0.0
var _glow: Node2D = null


func setup(p_target: Node2D, p_damage: float, p_push_origin: Vector2) -> void:
	target = p_target
	damage = p_damage
	push_origin = p_push_origin
	if p_target != null:
		_aim = p_target.global_position + AIM_UP


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow = Fx.make_glow_child(self, _draw_glow)


func _target_alive() -> bool:
	return target != null and is_instance_valid(target) and target.get("is_dead") != true


func _redraw() -> void:
	queue_redraw()
	if _glow:
		_glow.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for sp: Array in _sparks:
		sp[1] = float(sp[1]) + delta
	while not _sparks.is_empty() and float(_sparks[0][1]) >= SPARK_LIFE:
		_sparks.remove_at(0)
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
			_trail = Fx.push_trail(_trail, global_position, 4.0, TRAIL_PX)
			global_position += _dir * SPEED * delta
			_spark_acc += delta
			if _spark_acc >= SPARK_EVERY:
				_spark_acc = 0.0
				_sparks.append([global_position - _dir * 8.0 + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), 0.0])
		Phase.BURST:
			if _t >= BURST_TIME:
				queue_free()
				return
	_redraw()


func _explode() -> void:
	_phase = Phase.BURST
	_t = 0.0
	_trail.clear()
	if damage > 0.0 and is_inside_tree():
		_apply_hits()
	_redraw()


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
			e.call("apply_skill_push", away.normalized() if away.length() > 0.5 else _dir, BOSS_PUSH_DISTANCE if is_boss else PUSH_DISTANCE, true) ## görev atışı oyuncu yeteneği değil: bossu iter


## --- çizim: gövde normal karışımda (_draw), hale/iz/kıvılcım/patlama toplamsal çocukta (_draw_glow) ---

func _draw() -> void:
	match _phase:
		Phase.CHARGE:
			var k: float = clampf(_t / CHARGE_TIME, 0.0, 1.0)
			Fx.disc(self, Vector2.ZERO, 2.0 + 6.0 * k, Fx.EDGE)
			Fx.disc(self, Vector2.ZERO, 1.0 + 4.5 * k, Fx.MID)
			Fx.disc(self, Vector2(-1, -1), 0.5 + 2.0 * k, Fx.CORE)
		Phase.FLY:
			Fx.disc(self, Vector2.ZERO, 10.0, Fx.EDGE)
			Fx.disc(self, Vector2.ZERO, 7.5, Fx.MID)
			Fx.disc(self, Vector2(-1, -1), 4.5, Fx.CORE)
			Fx.disc(self, Vector2(-3, -3), 1.5, Color(1, 1, 1))


func _draw_glow(ci: Node2D) -> void:
	for s: Array in _sparks:
		var sk: float = 1.0 - float(s[1]) / SPARK_LIFE
		var px: float = 2.0 if sk > 0.5 else 1.0
		ci.draw_rect(Rect2(ci.to_local(s[0]).round(), Vector2(px, px)), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.9 * sk))
	match _phase:
		Phase.CHARGE:
			var k: float = clampf(_t / CHARGE_TIME, 0.0, 1.0)
			Fx.disc(ci, Vector2.ZERO, 4.0 + 14.0 * k, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.12 + 0.12 * k))
			## içe çekilen 6 zerre
			for i in range(6):
				var a: float = TAU * float(i) / 6.0 + k * 2.6
				var p: Vector2 = (Vector2.from_angle(a) * (28.0 * (1.0 - k) + 6.0)).round()
				ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.5 + 0.5 * k))
		Phase.FLY:
			Fx.draw_trail(ci, _trail, 2.0, 14.0, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.5), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.6))
			Fx.disc(ci, Vector2.ZERO, 22.0, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.10))
			Fx.disc(ci, Vector2.ZERO, 15.0, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.16))
			## kürenin çevresinde dönen 3 kıvılcım
			for i in range(3):
				var p: Vector2 = (Vector2.from_angle(_t * 9.0 + TAU * float(i) / 3.0) * 14.0).round()
				ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Fx.CORE)
		Phase.BURST:
			var k: float = clampf(_t / BURST_TIME, 0.0, 1.0)
			var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
			var fade: float = 1.0 - k
			if k < 0.4:
				var fk: float = k / 0.4
				Fx.disc(ci, Vector2.ZERO, 10.0 + 18.0 * fk, Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.6 * (1.0 - fk)))
			Fx.disc(ci, Vector2.ZERO, BLAST_RADIUS * ease_k, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.10 * fade))
			Fx.ring(ci, Vector2.ZERO, 8.0 + (BLAST_RADIUS - 8.0) * ease_k, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.95 * fade), 3.0)
			Fx.ring(ci, Vector2.ZERO, (BLAST_RADIUS - 12.0) * ease_k, Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.5 * fade), 1.0)
			for i in range(12):
				var p: Vector2 = (Vector2.from_angle(TAU * float(i) / 12.0 + 0.4) * (6.0 + (BLAST_RADIUS + 12.0) * ease_k)).round()
				var px: float = 3.0 if k < 0.5 else 2.0
				ci.draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, fade))
