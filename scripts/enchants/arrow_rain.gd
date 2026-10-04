extends "res://scripts/enchant_behavior.gd"

## Arrow Rain (Arbalet / Yay) - bkz. EnchantDefs "arrow_rain". Her isabet şansa bağlı olarak hedefin üstüne ok yağmuru
## (enchant_area "rain" + arrow_rain sayfası): alandakilere tik hasarı; Final'de şans %35, alandakilerin kalkan koruması
## -%30 (enemy.gd "shield_break") ve yağmur bitince balista oku (ballista sayfası). rain_pity isabet üst üste tutmazsa
## sonraki kesin (roll_pity).

const MIN_GAP := 0.4 ## aynı anda üst üste yağmur yığılmasın (çoklu ok isabetleri)
const SHEET_RX := 58.0 ## sayfadaki zemin halkasının yarıçapı (sanat px) - 70 birimde ölçek ~1 (oklar texel yoğunluğunda)
const SHEET_GROUND_Y := 20.0 ## sayfada zemin merkezi tuval merkezinin bu kadar altında (sanat px)

var _last_msec: int = -100000


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t) or not can_act():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_msec < int(MIN_GAP * 1000.0):
		return
	if not roll_pity("rain", maxf(f("rain_chance"), f("rain_chance_final")), n("rain_pity")):
		return
	_last_msec = now
	var r: float = f("rain_radius", 70.0)
	var sc: float = r / (SHEET_RX * 1.212)
	var params: Dictionary = {"radius": r, "duration": f("rain_dur", 3.0), "tick": maxf(0.1, f("rain_tick", 0.5)),
		"damage": ap() * f("rain_ap"), "sheet": "arrow_rain", "sheet_scale": sc, "sheet_pos": Vector2(0.0, -SHEET_GROUND_Y * 1.212 * sc)}
	if f("rain_shield_break") > 0.0:
		params["shield_break"] = f("rain_shield_break")
	if f("ballista") > 0.0:
		params["ballista"] = ap() * f("ballista")
	area("rain", (t as Node2D).global_position, params)
