extends "res://scripts/enchant_behavior.gd"

## Tektonik Yarık (Topuz / Uzunkılıç) - bkz. EnchantDefs "tektonik_yarik". Her ana hedef isabeti vuruş yönünde bir zemin
## yarığı açar (enchant_area "line" + rift_tile karoları): saniyede silah hasarının %30'u; Seviye 2 geniş + %40 yavaşlatma +
## "%20 fazla hasar al"; Seviye 3 her 3. vuruşta X patlaması (crack_x sayfası, %60 + 0,75 sn savrulma/sersemleme);
## Seviye 4 kapanışta içindekilere %40 (içerideki düşman başına +%15); Final kapanışı merkeze çekip ezen %400'lük fay
## patlamasına çevirir (fault_blast sayfası). Kapanışlar enchant_area.gd _line_expire'da.

const X_RADIUS := 60.0

var _hits: int = 0


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj != null or not is_enemy(t) or not can_act():
		return
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	_hits += 1
	var w: float = wdmg()
	var dir: Vector2 = dir_to(pl.global_position, t)
	var a: Vector2 = pl.global_position + dir * 20.0
	var b: Vector2 = a + dir * f("crack_len", 120.0)
	var cw: float = f("crack_width", 20.0)
	var params: Dictionary = {"to": b, "width": cw * 0.5 + 6.0, "tick": 1.0, "damage": w * f("crack_wdmg", 0.3),
		"slow": f("crack_slow"), "vuln": f("crack_vuln"), "duration": f("crack_dur", 2.0), "crowd_bonus": 0.15,
		"sheet": "rift_tile" if cw < 30.0 else "rift_tile_wide", "sheet_scale": Vector2(1.0, cw / (20.0 if cw < 30.0 else 40.0))}
	if f("fault") > 0.0:
		params["fault"] = w * f("fault")
	elif f("crack_close") > 0.0:
		params["close"] = w * f("crack_close")
	area("line", a, params)
	if n("crack_x_every") > 0 and _hits % n("crack_x_every") == 0:
		var at: Vector2 = (t as Node2D).global_position
		sprite("crack_x", at, {"z": 9})
		for e in enemies_near(at, X_RADIUS):
			hit(e, w * f("crack_x_dmg", 0.6))
			e.apply_element("stun", {"dur": f("crack_x_stun", 0.75)})
