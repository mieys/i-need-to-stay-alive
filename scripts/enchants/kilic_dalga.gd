extends "res://scripts/enchant_behavior.gd"

## Kılıç Dalgası (EnchantDefs "kilic_dalga"): Uzunkılıç sahibinin etrafında DÖNEN bir kılıç - "savuruş" = çeyrek tur, temel
## hızda ~1 sn (weapon.gd _process_uzunkilic_orbit -> on_revolution; kartta "her N sn"). Her N savuruşta en yakın düşmana doğru ilerleyen enerji dalgası
## (enchant_area.gd "blade"); IV: ters yöne de. Final (Keskin Uçlar) Göğü Yaran: dalga ekranı geçer ve geçtiği yerde 1 sn
## sonra ikinci kez vuran bir kesik kalır (enchant_area.gd "line" second_cut).

const WAVE_RANGE := 220.0
const SKY_RANGE := 1300.0
const WAVE_SPEED := 750.0
const WAVE_COLOR := Color(0.85, 0.95, 1.0)


func revolution_extra(_pos: Vector2) -> void:
	if n("wave_every_rev") <= 0 or not every(n("wave_every_rev")) or not can_act():
		return
	var p: Node = owner_player()
	var from: Vector2 = p.global_position
	var e: Node = nearest_enemy(from, 600.0)
	var dir: Vector2 = dir_to(from, e) if e else Vector2.RIGHT.rotated(randf() * TAU)
	_wave(from, dir)
	if flag("wave_double"):
		_wave(from, -dir)


func _wave(from: Vector2, dir: Vector2) -> void:
	var dmg: float = ap() * f("wave_pct", 0.6) * pw("area")
	var rng: float = SKY_RANGE if flag("sky_split") else WAVE_RANGE
	area("blade", from, {"dir": dir, "speed": WAVE_SPEED * (2.0 if flag("sky_split") else 1.0), "range": rng,
		"width": 26.0 * f("wave_width", 1.0), "damage": dmg, "color": WAVE_COLOR})
	if flag("sky_split"):
		area("line", from, {"to": from + dir * rng, "width": 20.0 * f("wave_width", 1.0), "duration": 1.2,
			"second_cut": dmg, "color": Color(0.7, 0.85, 1.0)})
