extends "res://scripts/enchant_behavior.gd"

## Hunter's Eye (Tüfek / Arbalet) - bkz. EnchantDefs "hunters_eye".
##  - Avcı içgüdüsü (2026-10-04 denge turu): canı low_hp_line altındaki her düşmana (bosslar dahil) low_hp_bonus ek hasar.
##    Eski tek kaynak olan %15 şanslı infaz pratikte boşa çıkıyordu: %30 canın altındaki normal yaratığı mermi zaten
##    öldürüyordu, yüksek canlılar (boss/elit) kapsam dışıydı.
##  - İnfaz: canı exec_hp altındaki normal yaratığa isabet exec_chance ihtimalle (artık 1.0 = kesin) onu anında öldürür
##    (bosslar hiç; Kademe 7+ yaratıklar sadece Final'de, canı exec_elite_hp altındayken exec_elite ihtimalle - elit sandık
##    eşiği enemy.gd ELITE_CHEST_MIN_TIER ile aynı tanım).
##  - Avcı işareti: her isabet 1; marks_per_ap'ta kalıcı +1 saldırı gücü (player.gd enchant_add_attack_power). Sayaç silah
##    meta'sında (kart alınınca sıfırlanmaz).
##  - Avcının Ganimeti: infazda şansla sahibine uçan can küresi (enchant_area "heal_orb", maks. canın %5'i).
##  - Final: infazdan sonra 3 sn bu silahın tüm atışları kritik.

const ELITE_TIER := 7
const ORB_HEAL := 0.05

var _crit_until_msec: int = 0


func crit_extra(_t: Node2D) -> float:
	return 1.0 if Time.get_ticks_msec() < _crit_until_msec else 0.0


func damage_extra(dmg: float, t: Node2D) -> float:
	if f("low_hp_bonus") <= 0.0 or not is_instance_valid(t):
		return dmg
	var mx: float = float(t.get("max_health")) if t.get("max_health") != null else 0.0
	var hp: float = float(t.get("health")) if t.get("health") != null else 0.0
	if mx > 0.0 and hp > 0.0 and hp / mx < f("low_hp_line", 0.5):
		return dmg * (1.0 + f("low_hp_bonus"))
	return dmg


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t):
		return
	var marks: int = int(keep_get("marks", 0)) + 1
	var need: int = maxi(1, n("marks_per_ap", 100))
	if marks >= need:
		marks -= need
		var pl: Node = owner_player()
		if pl and pl.has_method("enchant_add_attack_power"):
			pl.enchant_add_attack_power(1.0)
	keep_set("marks", marks)
	_try_execute(t)


func _try_execute(t: Node) -> void:
	if t.get("is_boss") == true:
		return
	var mx: float = float(t.get("max_health"))
	var hp: float = float(t.get("health"))
	if mx <= 0.0 or hp <= 0.0:
		return
	var elite: bool = int(t.get("_current_tier") if t.get("_current_tier") != null else 0) >= ELITE_TIER
	if hp / mx >= (f("exec_elite_hp") if elite else f("exec_hp", 0.2)):
		return
	var chance: float = f("exec_elite") if elite else f("exec_chance")
	if chance <= 0.0 or randf() >= chance:
		return
	var at: Vector2 = (t as Node2D).global_position
	sprite("execute_mark", at, {"z": 9})
	t.take_damage(hp * 10.0 + 100000.0, true, 1.0, false)
	if f("exec_crit_time") > 0.0:
		_crit_until_msec = Time.get_ticks_msec() + int(f("exec_crit_time") * 1000.0)
	if f("exec_orb") > 0.0 and randf() < f("exec_orb"):
		area("heal_orb", at, {"heal": max_hp() * ORB_HEAL, "sheet": "heal_orb", "safety": 6.0})
