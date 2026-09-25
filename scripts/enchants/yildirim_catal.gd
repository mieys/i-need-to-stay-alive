extends "res://scripts/enchant_behavior.gd"

## Çatal Işın (EnchantDefs "yildirim_catal"): her ışın tikinde menzildeki en yakın N düşmana da ek ışın (asadan onlara
## kısa ark görseli). Ek ışın yavaşlatır; final (Eldiven) Örümcek Ağı - bağlı düşmanlar arasındaki hatlar da yakınındaki
## düşmanlara vurur, saldırı hızı (tik sıklığı) temel sınıfta.

const WEB_WIDTH := 18.0
const FX_MIN_GAP_MSEC := 300

var _last_fx_msec: int = 0


func on_beam_tick(target: Node, dmg: float) -> void:
	super.on_beam_tick(target, dmg)
	if not is_enemy(target):
		return
	var origin: Vector2 = weapon.global_position
	var rng: float = float(weapon.get("attack_range"))
	var forks: Array = []
	var cands: Array = enemies_near(origin, rng, target)
	cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	for e in cands:
		if forks.size() >= n("forks", 1):
			break
		if VisionFogScript.can_target(e):
			forks.append(e)
	if forks.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var show_fx: bool = now - _last_fx_msec >= FX_MIN_GAP_MSEC
	if show_fx:
		_last_fx_msec = now
	var fork_dmg: float = dmg * f("fork_pct", 0.5)
	for e in forks:
		hit(e, fork_dmg)
		on_hit(e, fork_dmg, false, null)
		if f("fork_slow") > 0.0:
			e.apply_element("slow", {"pct": f("fork_slow"), "dur": 0.6})
		if show_fx:
			fx("chain", origin, {"to": e.global_position})
	if flag("web"):
		var linked: Array = [target] + forks
		var already: Dictionary = {}
		for x in linked:
			already[x.get_instance_id()] = true
		for i in range(linked.size() - 1):
			var a: Vector2 = linked[i].global_position
			var b: Vector2 = linked[i + 1].global_position
			if show_fx:
				fx("chain", a, {"to": b, "color": Color(1.0, 0.95, 0.6)})
			for e in enemies_near((a + b) * 0.5, a.distance_to(b) * 0.5 + WEB_WIDTH):
				if already.has(e.get_instance_id()):
					continue
				if e.global_position.distance_to(Geometry2D.get_closest_point_to_segment(e.global_position, a, b)) <= WEB_WIDTH:
					already[e.get_instance_id()] = true
					hit(e, fork_dmg * 0.6)
