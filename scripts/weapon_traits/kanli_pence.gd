extends "res://scripts/enchant_behavior.gd"

## Kanlı Pençe (Pençe, kalıcı özellik) - bkz. EnchantDefs "kanli_pence". Her pençe tek yüklük (süresi tazelenen) süreli kanama
## bırakır (enchant_behavior.gd dot_*); her pençe darbesinde verilen hasarın kp_leech'i kadar can (alan payında %33). "Yırtıcı Darbe" =
## ortak bleeding_bonus (modify_damage, status "bleeding" bu kaydı da sayar). Final: kanayan düşmanı öldürünce kısa saldırı hızı
## + can (öldürme = mark_kill olayı ya da kendi kanama tikimizin öldürmesi).

const KILL_HASTE_TIME := 3.0


## Hasardan ÖNCE (modify_damage -> damage_extra): kanayan hedef bu vuruş sırasında ölürse host bize "kp_kill" olayını yollar.
func damage_extra(dmg: float, t: Node2D) -> float:
	if (f("kp_kill_haste") > 0.0 or f("kp_kill_heal") > 0.0) and dot_stacks(t) > 0:
		mark_kill(t, "kp_kill", 0.8)
	return dmg


func hit_extra(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	if proj != null or not is_enemy(t) or not can_act():
		return
	## Önce kanama, sonra can (2026-10-17): eskiden can "zaten kanıyor mu" kontrolüyle kanamadan ÖNCE veriliyordu -> yeni hedefe ilk
	## vuruş hiç can basmıyordu (kalabalıkta çoğu vuruş). Tek yük (cap 1): kanama birikmez, süresi tazelenir.
	dot_add(t, ap() * f("kp_ap", 0.20), f("kp_dur", 3.0), 1)
	if f("kp_leech") > 0.0: ## alan payı vuruşlarında can emme %33 (kullanıcı kuralı, GameManager.LIFESTEAL_EFFECTIVENESS)
		heal_owner(dmg * f("kp_leech") * (1.0 if is_primary else GameManager.LIFESTEAL_EFFECTIVENESS))


func on_event(event: String, _data: Dictionary) -> void:
	if event == "kp_kill":
		_kill_bonus()


func on_dot_victim_died(_rec: Dictionary) -> void:
	_kill_bonus()


func _kill_bonus() -> void:
	if not can_act():
		return
	if f("kp_kill_haste") > 0.0:
		haste(f("kp_kill_haste"), KILL_HASTE_TIME)
	if f("kp_kill_heal") > 0.0:
		heal_owner(max_hp() * f("kp_kill_heal"))
