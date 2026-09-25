extends "res://scripts/enchant_behavior.gd"

## Gölge Adımı (EnchantDefs "hancer_golge"): her N. saldırıda hedefe doğru uçan gölge hançer(ler) (enchant_area.gd
## "blade" - yolundaki herkese bir kez vurur, İşaret bırakabilir). Hareket halinde saldırı hızı temel sınıfta.
## Final (Deri Çizme): gölgeler 3'lü yelpaze; sıyrılınca (player.gd _notify_enchants_dodge) çevreye gölge dansı.

const BLADE_RANGE := 260.0
const BLADE_SPEED := 900.0
const SHADOW_COLOR := Color(0.55, 0.45, 0.85)


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or n("shadow_every") <= 0 or not every(n("shadow_every")) or not is_instance_valid(target):
		return
	var from: Vector2 = owner_player().global_position
	var base_dir: Vector2 = dir_to(from, target)
	var angles: Array = []
	var per: int = 3 if flag("shadow_dance") else 1
	for s in range(n("shadow_count", 1)):
		var shift: float = deg_to_rad(10.0) * float(s) * (1.0 if s % 2 == 0 else -1.0)
		for k in range(per):
			angles.append(shift + deg_to_rad(14.0) * float(k - per / 2))
	for a in angles:
		_blade(from, base_dir.rotated(a))


func _blade(from: Vector2, dir: Vector2) -> void:
	area("blade", from, {"dir": dir, "speed": BLADE_SPEED, "range": BLADE_RANGE, "width": 24.0,
		"damage": ap() * 0.8 * pw("area"), "mark": n("shadow_mark"), "color": SHADOW_COLOR})


func on_dodge() -> void:
	if not flag("shadow_dance") or not can_act():
		return
	var from: Vector2 = owner_player().global_position
	for k in range(8):
		_blade(from, Vector2.RIGHT.rotated(TAU * float(k) / 8.0))
	fx("ring", from, {"radius": 70.0, "color": SHADOW_COLOR, "duration": 0.35})
