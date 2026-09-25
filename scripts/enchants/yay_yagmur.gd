extends "res://scripts/enchant_behavior.gd"

## Ok Yağmuru (EnchantDefs "yay_yagmur"): yayın saf "her 3. atışta +1 ok" davranışının yerini alır (overrides_multishot)
## - ek oklar temel sınıfın seri atışı (volley_*). Final (Eldiven): her 5 sn'de en yakın düşmanın olduğu alana 2 sn
## sonra 20 ok yağar (enchant_area.gd "arrow_rain").

const RAIN_COOLDOWN := 5.0
const RAIN_SEARCH_RADIUS := 420.0

var _rain_timer: float = RAIN_COOLDOWN


func overrides_multishot() -> bool:
	return true


func process_extra(delta: float) -> void:
	if not flag("rain"):
		return
	_rain_timer -= delta
	if _rain_timer > 0.0:
		return
	var p: Node = owner_player()
	var e: Node = nearest_enemy(p.global_position, RAIN_SEARCH_RADIUS) if can_act() else null
	if e == null:
		_rain_timer = 1.0
		return
	_rain_timer = RAIN_COOLDOWN
	area("arrow_rain", e.global_position, {"delay": 2.0, "radius": 110.0, "count": 20, "damage": ap() * 0.6 * power})
