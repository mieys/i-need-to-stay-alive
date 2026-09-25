extends "res://scripts/enchant_behavior.gd"

## Hayvan Hücumu (EnchantDefs "pence_hucum"): N sn'de bir 200 px içindeki bir düşmana atılma (player.gd enchant_dash -
## Talon Q ile aynı hareket kilidi); yolundaki düşmanlara bir kez vurur. Sonrası saldırı hızı, sersemletme, ikinci atılma,
## atılırken yenilmezlik (player.enchant_invuln). Final (Deri Çizme) Sürü Lideri: her atılmada 5 sn'lik 2 hayalet kurt
## (enchant_area.gd "wolf").

const DASH_RANGE := 200.0
const DASH_TIME := 0.18
const HIT_RADIUS := 42.0

var _timer: float = 2.0
var _dash_hit: Dictionary = {}


func process_extra(delta: float) -> void:
	if f("dash_cd") <= 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var p: Node = owner_player()
	var e: Node = nearest_enemy(p.global_position, DASH_RANGE) if can_act() else null
	if e == null or bool(p.get("_talon_dashing")):
		_timer = 0.3
		return
	_timer = f("dash_cd")
	_dash_sequence(e)


func _dash_sequence(first: Node) -> void:
	var p: Node = owner_player()
	_dash_hit.clear()
	var target: Node = first
	for i in range(maxi(1, n("dash_chain", 1))):
		if not is_enemy(target) or not is_instance_valid(p):
			break
		var from: Vector2 = p.global_position
		var to: Vector2 = (target as Node2D).global_position
		var stop: Vector2 = to - (to - from).normalized() * 18.0 if from.distance_to(to) > 20.0 else from
		if flag("dash_invuln") and p.has_method("enchant_invuln"):
			p.enchant_invuln(DASH_TIME + 0.1)
		p.enchant_dash(stop, DASH_TIME, _dash_hits)
		fx("burst", from, {"palette": "dust", "count": 8, "speed": 80.0, "life": 0.3})
		if flag("pack_leader"):
			for k in range(2):
				area("wolf", from + Vector2(0.0, 18.0 * (1.0 if k == 0 else -1.0)), {"duration": 5.0, "damage": ap() * 0.4 * power})
		await get_tree().create_timer(DASH_TIME + 0.05).timeout
		if not is_instance_valid(self):
			return
		target = nearest_enemy(p.global_position, DASH_RANGE, [target])
	if f("dash_haste") > 0.0:
		haste(f("dash_haste"), 2.0)


func _dash_hits(_t: float) -> void:
	var p: Node = owner_player()
	if p == null:
		return
	for e in enemies_near(p.global_position, HIT_RADIUS):
		var id: int = e.get_instance_id()
		if _dash_hit.has(id):
			continue
		_dash_hit[id] = true
		hit(e, ap() * 0.6 * pw("area"))
		if f("dash_stun") > 0.0:
			e.apply_element("stun", {"dur": f("dash_stun")})
