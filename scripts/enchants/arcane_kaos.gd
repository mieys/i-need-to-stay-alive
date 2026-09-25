extends "res://scripts/enchant_behavior.gd"

## Kaos Büyüsü (EnchantDefs "arcane_kaos"): her atış (ana hedef) rastgele N farklı element taşır. II: hedefte tepkime
## çıkaracak (hedefte OLMAYAN) elementleri tercih eder - 5 elementin her ikilisi bir tepkime (element_reactions.gd).
## Tepkime gücü temel sınıfta; IV: her tepkime (host -> "reaction" olayı) 10 sn +%5 (en fazla +%50). Final (Yetenek
## Kitabı): yetenek kullanınca 5 sn her atış beş elementin hepsini taşır. Efsun gücü element hasarlarını çarpar.

const ELEMENTS := ["burn", "freeze", "poison", "bleed", "shock"]
const STATUS_OF := {"burn": "burning", "freeze": "frozen", "poison": "poisoned", "bleed": "bleeding", "shock": "shocked"}
const RAMP_PER := 0.05
const RAMP_MAX := 10
const RAMP_DUR_MSEC := 10000
const ALL_DUR_MSEC := 5000

var _ramp_stacks: int = 0
var _ramp_until_msec: int = 0
var _all_until_msec: int = 0


## Kaos elementleri efsun gücüyle büyür (power_on "area" ama zehir/yanma/kanama/şok hasarları da bu efsunun) - asanın
## kendi vuruşu ("hit") değil.
func pw(kind: String) -> float:
	return 1.0 if kind == "hit" else power


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t):
		return
	var picks: Array = []
	if Time.get_ticks_msec() < _all_until_msec:
		picks = ELEMENTS.duplicate()
	else:
		var pool: Array = ELEMENTS.duplicate()
		pool.shuffle()
		if flag("chaos_smart"):
			pool.sort_custom(func(a, b): return int(status(t, STATUS_OF[a])) < int(status(t, STATUS_OF[b])))
		picks = pool.slice(0, clampi(n("chaos", 1), 1, 5))
	for el in picks:
		match el:
			"burn":
				apply_burn_to(t)
			"freeze":
				freeze(t, 1.0)
			"poison":
				apply_poison_to(t)
			"bleed":
				apply_bleed_to(t)
			"shock":
				apply_shock_to(t)


func damage_extra(dmg: float, _t: Node2D) -> float:
	if _ramp_stacks > 0 and Time.get_ticks_msec() >= _ramp_until_msec:
		_ramp_stacks = 0
	return dmg * (1.0 + RAMP_PER * float(_ramp_stacks))


func on_event(event: String, _data: Dictionary) -> void:
	if event == "reaction" and flag("chaos_ramp"):
		_ramp_stacks = mini(RAMP_MAX, _ramp_stacks + 1)
		_ramp_until_msec = Time.get_ticks_msec() + RAMP_DUR_MSEC


func on_skill_used() -> void:
	if not flag("chaos_all"):
		return
	_all_until_msec = Time.get_ticks_msec() + ALL_DUR_MSEC
	var p: Node = owner_player()
	if p:
		fx("text", p.global_position, {"text": "Element Fırtınası", "color": Color(0.9, 0.6, 1.0)})


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	var palette: Array = [Color(1.0, 0.6, 0.3), Color(0.6, 0.85, 1.0), Color(0.6, 1.0, 0.45), Color(1.0, 0.45, 0.5), Color(1.0, 0.95, 0.5)]
	d["tint"] = Color(palette[randi() % palette.size()]).lerp(Color.WHITE, 0.35)
	return d
