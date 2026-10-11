extends "res://scripts/enchant_behavior.gd"

## Wind Sword (Uzunkılıç) - bkz. EnchantDefs "wind_sword". Her savuruş temasında (weapon.gd _sword_contact -> on_revolution)
## şansa bağlı olarak ileri giden bir rüzgar dalgası (enchant_area "blade" + wind_wave sayfası): değdiğine hasar, savurma,
## (Hava Presi) yavaşlatma, (Final) orman duvarına çarptırılana ek hasar + sersemletme.

const WAVE_SPEED := 420.0


func revolution_extra(pos: Vector2) -> void:
	if not can_act():
		return
	var chance: float = maxf(f("wave_chance"), f("wave_chance_final"))
	if randf() >= chance:
		return
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	var origin: Vector2 = pl.global_position
	var dir: Vector2 = (pos - origin).normalized() if pos.distance_to(origin) > 2.0 else Vector2.RIGHT
	var width: float = f("wave_width", 40.0)
	area("blade", origin, {"dir": dir, "speed": WAVE_SPEED, "range": f("wave_range", 180.0), "width": width * 0.5 + 6.0,
		"damage": ap() * f("wave_ap"), "push": f("wave_push"), "slow": f("wave_slow"), "slow_dur": 1.5,
		"wall_slam": flag("wall_slam"), "slam_mult": 1.0, "slam_stun": 1.0,
		"sheet": "wind_wave", "sheet_rot": dir.angle(), "sheet_scale": Vector2(1.0, width / 40.0)})
