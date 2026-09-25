extends "res://scripts/enchant_behavior.gd"

## Kanlı Kılıç (EnchantDefs "kilic_kanli"): kanama / kanayana bonus / vuruş sıklığı (orbit_cd_mult) / ölüm patlaması temel
## sınıfta + host'ta. Final (Hasat Çantası) Kan Yemini: kanayan düşman ölümleri (host -> "bleed_kill" olayı) 20'ye
## ulaşınca 10 sn kan öfkesi - kılıcın vuruş alanı x1,5 ve kılıç hasarının %5'i can.

const OATH_KILLS := 20
const OATH_DUR_MSEC := 10000

var _oath_until_msec: int = 0


func _oath() -> bool:
	return Time.get_ticks_msec() < _oath_until_msec


func on_event(event: String, _data: Dictionary) -> void:
	if event != "bleed_kill" or not flag("blood_oath"):
		return
	var c: int = int(keep_get("oath_kills", 0)) + 1
	if c >= OATH_KILLS:
		c = 0
		_oath_until_msec = Time.get_ticks_msec() + OATH_DUR_MSEC
		var p: Node = owner_player()
		if p:
			fx("text", p.global_position, {"text": "Kan Yemini", "color": Color(0.95, 0.25, 0.3)})
			fx("ring", p.global_position, {"radius": 90.0, "color": Color(0.9, 0.2, 0.25), "duration": 0.5})
	keep_set("oath_kills", c)


func aoe_extra() -> float:
	return 1.5 if _oath() else 1.0


func hit_extra(_t: Node, dmg: float, _is_primary: bool, _proj: Node2D) -> void:
	if _oath() and dmg > 0.0:
		heal_owner(dmg * 0.05)
