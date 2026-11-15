extends "res://scripts/enchant_behavior.gd"

## Kızışan Namlu (Makineli, kalıcı özellik) - bkz. weapon_traits.gd "kizisan_namlu" (madde 652). Hızlanma + şarjör boyu + sıcak başlangıç
## + tavan hızı weapon.gd'de (_mag_next_gap / _mag_capacity: "mag_add", "hot_start", "ramp_floor_mult" bu özelliğin istatistiklerinden
## okunur). Burada yalnız en yüksek hızdaki merminin ekleri: Kızgın Mermiler (+hot_dmg hasar) ve final Kurşun Fırtınası (1 delme, tam
## hasar). Sadece kasterde çalışır; uzak oyuncular mermiyi broadcast_projectile ile görür (delme host'ta/kasterde işler).

func _at_top() -> bool:
	return is_instance_valid(weapon) and weapon.has_method("ramp_at_top") and bool(weapon.call("ramp_at_top"))


func damage_extra(dmg: float, _t: Node2D) -> float:
	if f("hot_dmg") > 0.0 and _at_top():
		return dmg * (1.0 + f("hot_dmg"))
	return dmg


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if not flag("hot_pierce") or proj == null or not _at_top():
		return
	if "pierce_count" in proj:
		proj.set("pierce_count", int(proj.get("pierce_count")) + 1)
		proj.set("pierce_damage_percent", 1.0)
