extends "res://scripts/enchant_behavior.gd"

## Loaded Chamber (Arbalet / Tüfek) - bkz. EnchantDefs "loaded_chamber". Her N. gerçek atış güçlendirilmiş mermi: hasar
## charged_mult x (1 + charged_bonus), boyut charged_scale (mermi görünümü "scale" - kasterde ve uzak kopyada aynı), Kinetik
## Boyut ile ilk düşmanı deler. Final: çarptığı an şok dalgası (charged_shock sayfası) - ilk hedef 1 sn sersem, 100 birim %200.

const SHOCK_RADIUS := 100.0
const SHEET_RX := 82.0

var _shots: int = 0
var _charged: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	if is_extra:
		_charged = false
		return
	_shots += 1
	_charged = _shots % maxi(1, n("charged_every", 7)) == 0


func damage_extra(dmg: float, _t: Node2D) -> float:
	if _charged:
		return dmg * f("charged_mult", 2.5) * (1.0 + f("charged_bonus"))
	return dmg


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if not _charged:
		return
	proj.set_meta("charged_shot", true)
	if n("charged_pierce") > 0 and "pierce_count" in proj:
		proj.set("pierce_count", int(proj.get("pierce_count")) + n("charged_pierce"))
		proj.set("pierce_damage_percent", 1.0)


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	if _charged:
		d["scale"] = f("charged_scale", 1.5)
		d["tint"] = Color(1.0, 0.92, 0.7)
	return d


func fire_extra(_target: Node2D, _is_extra: bool) -> void:
	_charged = false


func hit_extra(t: Node, _dmg: float, _is_primary: bool, proj: Node2D) -> void:
	if f("charged_shock") <= 0.0 or proj == null or not is_instance_valid(proj) or not proj.has_meta("charged_shot"):
		return
	proj.remove_meta("charged_shot") ## dalga mermi başına bir kez (delip geçse bile)
	var at: Vector2 = (t as Node2D).global_position
	sprite("charged_shock", at, {"scale": SHOCK_RADIUS / (SHEET_RX * 1.212), "z": 9})
	if is_enemy(t):
		t.apply_element("stun", {"dur": 1.0})
	for e in enemies_near(at, SHOCK_RADIUS):
		hit(e, ap() * f("charged_shock"))
