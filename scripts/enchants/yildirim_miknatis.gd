extends "res://scripts/enchant_behavior.gd"

## Mıknatıs Asa (EnchantDefs "yildirim_miknatis"): ışının hedefinin çevresindekiler hedefe çekilir (host'ta "knock" ile -
## istemciden RPC olduğu için seyrek: 0,35 sn'de bir, bosslar çekilmez). Yavaşlatma, yığılma bonusu, 5 sn'lik patlama;
## final (Hasat Çantası) 8 sn'de bir kara delik (enchant_area.gd "black_hole" - tecrübe küresi çekimi dahil).

const PULL_INTERVAL := 0.35
const BLAST_COOLDOWN := 5.0
const HOLE_COOLDOWN := 8.0
const ARCANE := Color(0.7, 0.45, 1.0)

var _pull_timer: float = PULL_INTERVAL
var _slow_timer: float = 0.0
var _blast_timer: float = BLAST_COOLDOWN
var _hole_timer: float = HOLE_COOLDOWN


func _target() -> Node2D:
	var t: Node2D = weapon.get("_beam_target") as Node2D
	return t if is_enemy(t) else null


func process_extra(delta: float) -> void:
	_pull_timer -= delta
	_slow_timer -= delta
	_blast_timer -= delta
	_hole_timer -= delta
	var t: Node2D = _target()
	if t == null or not can_act():
		return
	var center: Vector2 = t.global_position
	if _pull_timer <= 0.0:
		_pull_timer = PULL_INTERVAL
		var do_slow: bool = f("pull_slow") > 0.0 and _slow_timer <= 0.0
		if do_slow:
			_slow_timer = 1.0
		for e in enemies_near(center, f("pull_radius", 80.0), t):
			var to_c: Vector2 = center - e.global_position
			if e.get("is_boss") != true and to_c.length() > 24.0:
				e.apply_element("knock", {"dir": to_c.normalized(), "dist": minf(to_c.length() - 20.0, 14.0 * f("pull_force", 1.0)), "quiet": true})
			if do_slow:
				e.apply_element("slow", {"pct": f("pull_slow"), "dur": 1.1})
	if flag("pull_blast") and _blast_timer <= 0.0:
		_blast_timer = BLAST_COOLDOWN
		blast(center, 100.0, ap() * 0.8 * pw("area"), ARCANE)
	if flag("black_hole") and _hole_timer <= 0.0:
		_hole_timer = HOLE_COOLDOWN
		area("black_hole", center, {"radius": 200.0, "duration": 3.0, "dps": ap() * 0.5 * pw("area"),
			"blast": ap() * 1.5 * pw("area"), "pull_xp": true})


func damage_extra(dmg: float, t: Node2D) -> float:
	if not flag("pull_bonus") or not is_instance_valid(t):
		return dmg
	var crowd: int = enemies_near(t.global_position, 80.0, t).size()
	return dmg * (1.0 + 0.10 * float(crowd / 3))
