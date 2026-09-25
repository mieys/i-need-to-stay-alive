extends "res://scripts/enchant_behavior.gd"

## Tam Çekiş (EnchantDefs "yay_cekis"): oyuncu hareketsiz durdukça çekiş birikir; dolunca sıradaki ok güçlü ve delici
## çıkar (silah ikonu parlayarak "hazır" olduğunu gösterir). V: tam çekiş oku isabette ikiye bölünür. Final (Şanslı
## Zar): Kartal Gözü - ok ekran boyunca uçar, her delişte kritik şansı +%10.

const READY_TINT := Color(1.35, 1.3, 1.0)

var _charge: float = 0.0
var _charged_shot: bool = false


func process_extra(delta: float) -> void:
	if is_moving():
		if f("charge_moving") > 0.0:
			_charge += delta * f("charge_moving")
		else:
			_charge = 0.0
	else:
		_charge += delta
	var icon: CanvasItem = weapon.get("icon_sprite") as CanvasItem
	if icon:
		icon.self_modulate = READY_TINT if _is_charged() else Color.WHITE


func _is_charged() -> bool:
	return _charge >= f("charge_time", 1.0)


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_charged_shot = not is_extra and _is_charged()
	if _charged_shot:
		_charge = 0.0


func crit_extra(_t: Node2D) -> float:
	return f("charge_crit") if _charged_shot else 0.0


func damage_extra(dmg: float, _t: Node2D) -> float:
	return dmg * f("charge_mult", 2.0) if _charged_shot else dmg


func projectile_extra(proj: Node2D, _target: Node2D, is_extra: bool) -> void:
	if not _charged_shot or is_extra:
		return
	proj.set("pierce_count", int(proj.get("pierce_count")) + n("charge_pierce", 2))
	proj.set("pierce_damage_percent", 1.0)
	proj.set_meta("enchant_charged", true)
	if n("charge_split") > 0:
		proj.set_meta("enchant_split", n("charge_split"))
	if flag("kartal"):
		proj.set("speed", float(proj.get("speed")) * 1.3)
		proj.set_meta("enchant_kartal", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if not proj.has_meta("enchant_charged"):
		return d
	d["scale"] = 1.4
	d["tint"] = Color(1.0, 1.0, 0.8)
	d["pierce"] = n("charge_pierce", 2)
	if flag("kartal"):
		d["life"] = 3.0
		d["trail"] = "missile"
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if proj == null:
		return
	if proj.has_meta("enchant_kartal") and not bool(proj.get("is_crit")):
		var hits: int = (proj.get("_hit_bodies") as Array).size()
		if randf() < float(weapon.get("crit_chance")) + 0.10 * float(hits):
			proj.set("is_crit", true)
			proj.set("damage", float(proj.get("damage")) * float(weapon.get("crit_damage")))
	if is_primary and proj.has_meta("enchant_split") and is_enemy(t):
		var parts: int = int(proj.get_meta("enchant_split"))
		proj.remove_meta("enchant_split")
		var base_dir: Vector2 = Vector2(proj.get("direction"))
		for k in range(parts):
			var ang: float = deg_to_rad(30.0) * (1.0 if k % 2 == 0 else -1.0) * float(k / 2 + 1)
			weapon.spawn_enchant_projectile(t.global_position, base_dir.rotated(ang), float(proj.get("damage")) * 0.5, [t])
