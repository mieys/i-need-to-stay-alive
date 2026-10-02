extends "res://scripts/enchant_behavior.gd"

## Magma Trail / Lightning Trail (Ateş / Yıldırım Asası) - bkz. EnchantDefs "trail". Ateş Asası: her atışın geçtiği hat
## (asa -> hedef, mermiler düz uçar); Yıldırım Asası: ışının tuttuğu hat, saniyede bir. Hat, enchant_area "line" olarak zeminde
## kalır (magma_tile / volt_tile karoları): üstündekilere saniyede hasar, (Köstekleyen Hat) yavaşlatma; Final'de süre dolunca
## patlar (trail_pop_*) ve yakaladıklarını 3 sn yakar (Ateş, yanma elementi) ya da çarpar (Yıldırım, "dot" alanı).

const BEAM_TRAIL_EVERY := 1.0
const SHEET_WIDTH := 20.0

var _beam_t: float = 0.0


func _volt() -> bool:
	return weapon_key() == "lightning_staff"


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if _volt() or is_extra or not is_instance_valid(target) or not can_act():
		return
	_lay(weapon.global_position, target.global_position)


func process_extra(delta: float) -> void:
	if not _volt():
		return
	_beam_t -= delta
	if _beam_t > 0.0:
		return
	var tgt: Variant = weapon.get("_beam_target")
	if tgt == null or not is_instance_valid(tgt) or (tgt as Node).get("is_dead") == true or not can_act():
		return
	_beam_t = BEAM_TRAIL_EVERY
	_lay(weapon.global_position, (tgt as Node2D).global_position)


func _lay(from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < 8.0:
		return
	var w: float = f("trail_width", 20.0)
	var params: Dictionary = {"to": to, "width": w * 0.5 + 8.0, "tick": 0.5, "damage": ap() * f("trail_dps") * 0.5,
		"slow": f("trail_slow"), "duration": f("trail_dur", 2.0), "sheet": "volt_tile" if _volt() else "magma_tile",
		"sheet_scale": Vector2(1.0, w / SHEET_WIDTH), "color": EnchantDefs.element_color(str(stats.get("element", "yanma")))}
	if f("trail_blast") > 0.0:
		params["blast"] = ap() * f("trail_blast")
		params["blast_dot"] = ap() * f("trail_blast_dot")
		params["blast_mode"] = "shock" if _volt() else "fire"
		params["blast_sheet"] = "trail_pop_volt" if _volt() else "trail_pop_fire"
	area("line", from, params)
