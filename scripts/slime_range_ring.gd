extends Node2D

## Minik Cadı büyüsü sürerken karakterin menzili ince bir çizgi olarak görünür (kullanıcı 2026-11-09, madde 509). Silahların hedef arama menzili
## düz daire (weapon.gd: _attack_origin().distance_to(hedef) <= attack_range, merkez = sahibin y'si); en GENİŞ sonlu silah menzili çizilir
## (büyüyle +%15 olmuş hâli). Sınırsız menzilli silah (attack_range 0) sayılmaz. Yalnız SAHİBİN ekranında (savaş karmaşası, madde 425).
## Sahibin z -1 çocuğu (karakterin altında); ince pembe çizgi + çevresinde yavaşça dönen parlak bir yay, açılış/kapanışta yumuşak geçiş.
## player.gd apply_slime_buff kurar, _end_slime_buff finish() ile söndürür.

const FADE_TIME := 0.3
const WIDTH := 2.0 ## sahibin yerel birimi (~1 ekran pikseli 1080p'de, kamera x2 + kök x0,5)
const C_LINE := Color(1.0, 0.62, 0.84, 0.55)
const C_SHINE := Color(1.0, 0.9, 0.96, 0.9)
const SHINE_LEN := 0.45 ## radyan
const SHINE_SPEED := 1.6 ## radyan/sn

var owner_body: Node2D = null
var _t: float = 0.0
var _fade: float = 0.0
var _ending: bool = false
var _radius: float = 0.0 ## sahibin yerel uzayında


func setup(body: Node2D) -> void:
	owner_body = body
	name = "SlimeRangeRing"
	z_index = -1


func finish() -> void:
	_ending = true


func is_ending() -> bool:
	return _ending


## En geniş sonlu silah menzili (dünya birimi); silah yoksa 0.
static func max_weapon_range(body: Node) -> float:
	var best: float = 0.0
	var ws: Variant = body.get("owned_weapon_nodes") if body != null else null
	if ws is Array:
		for w in ws:
			if is_instance_valid(w) and "attack_range" in w:
				best = maxf(best, float(w.attack_range))
	return best


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body):
		queue_free()
		return
	_t += delta
	_fade = clampf(_fade + (delta if not _ending else -delta) / FADE_TIME, 0.0, 1.0)
	if _ending and _fade <= 0.0:
		queue_free()
		return
	var gs: float = absf(owner_body.global_scale.x)
	_radius = max_weapon_range(owner_body) / maxf(0.01, gs)
	queue_redraw()


func _draw() -> void:
	if _radius <= 1.0 or _fade <= 0.0:
		return
	var seg: int = clampi(int(_radius / 6.0), 48, 160)
	var c := Color(C_LINE.r, C_LINE.g, C_LINE.b, C_LINE.a * _fade)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, seg, c, WIDTH, false)
	var a0: float = _t * SHINE_SPEED
	var s := Color(C_SHINE.r, C_SHINE.g, C_SHINE.b, C_SHINE.a * _fade)
	draw_arc(Vector2.ZERO, _radius, a0, a0 + SHINE_LEN, maxi(6, int(seg * SHINE_LEN / TAU) + 2), s, WIDTH, false)
