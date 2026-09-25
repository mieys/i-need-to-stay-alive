extends "res://scripts/enchant_behavior.gd"

## Düello (EnchantDefs "tabanca_duello"): tabanca menzildeki en yüksek canlı düşmanı hedefler (weapon.gd
## target_highest_health - efsun kalkınca geri yüklenir) ve ona bonus vurur. Aynı hedefe her N. isabet sersemletir,
## hedef ölünce sonraki 3 atış kesin kritik; boss bonusu / kalkan delme temel sınıfta. Final (Hasat Çantası) Kelle
## Avcısı: öldürdüğün her boss kalıcı +%3 (silah meta'sında - kart alınca sıfırlanmaz).

var _duel_id: int = 0
var _duel_node: Node2D = null
var _duel_hits: int = 0
var _sure_crits: int = 0


func _on_setup() -> void:
	weapon.set_enchant_prop("target_highest_health", true)


func fire_start(target: Node2D, is_extra: bool) -> void:
	if not is_extra and _sure_crits > 0:
		_sure_crits -= 1
	if is_instance_valid(target) and target.get_instance_id() != _duel_id:
		_duel_id = target.get_instance_id()
		_duel_node = target
		_duel_hits = 0


func crit_extra(_t: Node2D) -> float:
	return 1.0 if _sure_crits > 0 else 0.0


func damage_extra(dmg: float, t: Node2D) -> float:
	var m: float = 1.0
	if is_instance_valid(t) and t.get_instance_id() == _duel_id:
		m += f("duel_bonus", 0.2)
	if flag("headhunter"):
		m *= 1.0 + 0.03 * float(int(keep_get("headhunter", 0)))
	return dmg * m


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t) or n("duel_stun") <= 0 or t.get_instance_id() != _duel_id:
		return
	_duel_hits += 1
	if _duel_hits % n("duel_stun") == 0:
		t.apply_element("stun", {"dur": 1.0})


func process_extra(_delta: float) -> void:
	if _duel_id != 0 and (not is_instance_valid(_duel_node) or _duel_node.get("is_dead") == true):
		if n("duel_kill_crit") > 0 and _duel_hits > 0:
			_sure_crits = n("duel_kill_crit") + 1 ## fire_start bir sonraki atışta 1 düşürür
		_duel_id = 0
		_duel_node = null


func on_event(event: String, data: Dictionary) -> void:
	if event == "kill" and flag("headhunter") and bool(data.get("boss", false)):
		var c: int = int(keep_get("headhunter", 0)) + 1
		keep_set("headhunter", c)
		var p: Node = owner_player()
		if p:
			fx("text", p.global_position, {"text": "Kelle Avcısı +%%%d" % (c * 3), "color": Color(1.0, 0.85, 0.4)})
