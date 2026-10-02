extends "res://scripts/enchant_behavior.gd"

## BIGerang (Bumerang) - bkz. EnchantDefs "bigerang". Bumerang gidişte düşmanlardan dönmez, delip geçer ve her delişte büyür
## (boomerang_projectile.gd enchant_* anahtarları - mermi görünümünün "props"u ile kasterde VE uzak kopyada aynı büyür).
## Kütle Kazancı = ortak "pierce_ramp" (delişte hasar artışı), Uzak Uçuş = ortak "range_mult". Final: en büyük boyuta ulaşan
## bumerang çevresini içine çeken bir burgaç yaratır (vortex sayfası) ve uç noktada küçülmez.

const VORTEX_RADIUS := 120.0
const VORTEX_EVERY := 0.3
const RETURN_SPEED_MULT := 1.4

var _projs: Array = []
var _vortex_t: float = 0.0


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	## hit_on_return: kullanıcı bildirimi (2026-10-01) "BIGerang düşmanı deldikten sonra oyuncuya dönerken hasar vermiyor" -
	## düz bumerang dönüşte bilerek vurmaz (2026-09-26 kararı), BIGerang bunu açmıyordu. Düşman başına gidişte bir, dönüşte bir.
	d["props"] = {"enchant_pierce_all": true, "enchant_grow": f("grow", 0.03), "enchant_grow_max": f("grow_max", 2.5),
		"enchant_titan": flag("titan"), "hit_on_return": true, "enchant_return_speed_mult": RETURN_SPEED_MULT}
	return d


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if flag("titan"):
		_projs.append(proj)


func process_extra(delta: float) -> void:
	if _projs.is_empty():
		return
	_vortex_t -= delta
	if _vortex_t > 0.0:
		return
	_vortex_t = VORTEX_EVERY
	var alive: Array = []
	for pr in _projs:
		## Tipsiz: bumerang yakalanınca serbest kalır (bkz. hafıza: freed == null).
		if not is_instance_valid(pr):
			continue
		alive.append(pr)
		if not pr.has_method("is_grown_max") or not pr.is_grown_max():
			continue
		var at: Vector2 = (pr as Node2D).global_position
		sprite("vortex", at, {"loop_time": VORTEX_EVERY + 0.1, "scale": VORTEX_RADIUS / (99.0 * 1.212), "z": 8})
		for e in enemies_near(at, VORTEX_RADIUS):
			if e.is_boss:
				continue
			var to_c: Vector2 = at - e.global_position
			if to_c.length() > 12.0:
				e.apply_element("knock", {"dir": to_c.normalized(), "dist": minf(30.0, to_c.length() - 10.0), "quiet": true})
	_projs = alive
