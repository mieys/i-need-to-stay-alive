extends "res://scripts/enchant_behavior.gd"

## Blade of Valerius (Bıçak / Pençe) - bkz. EnchantDefs "valerius". Her N. saldırıda en yakın düşmanlara shuriken atar.
## Shuriken'in tüm yaşamı (uçuş, saplanma, saniyede hasar, dönüş, dönüşte delme, sahibine varınca can) enchant_area.gd
## "shuriken" türünde: yetkili kopya burada kurulur (hedef düğümü doğrudan verilir), diğer oyuncular aynı türü hedefin ağ
## kimliğinden kurar. Can emme = shurikenin verdiği hasar x oran (kullanıcı seçimi).

const THROW_RANGE := 260.0

var _count: int = 0


func fire_start(_target: Node2D, is_extra: bool) -> void:
	if is_extra or not can_act():
		return
	_count += 1
	if _count % maxi(1, n("shuriken_every", 3)) != 0:
		return
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	var origin: Vector2 = pl.global_position
	var cands: Array = []
	for e in enemies_near(origin, THROW_RANGE):
		if VisionFogScript.can_target(e):
			cands.append(e)
	cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	var mult: float = f("shuriken_dmg_mult", 1.0)
	for i in range(mini(n("shuriken_count", 2), cands.size())):
		var e: Node2D = cands[i]
		var a: Node2D = area("shuriken", origin, {"target_id": int(e.get_meta("network_enemy_id", 0)), "tpos": e.global_position,
			"hit": ap() * f("shuriken_hit") * mult, "dot": ap() * f("shuriken_dot") * mult, "stick": f("shuriken_stick", 5.0),
			"leech": f("shuriken_leech", 0.01), "return_pierce": flag("return_pierce"), "return_hit": ap() * f("return_hit") * mult,
			"kill_leech": f("kill_leech"), "sheet": "shuriken", "safety": 14.0})
		if a:
			a.set("target_node", e)
