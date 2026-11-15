extends "res://scripts/enchant_behavior.gd"

## Siper (Kalkan) - bkz. weapon_traits.gd "siper" (madde 338). Kalkan darbesi (weapon.gd _kalkan_contact) HİÇ kalkan doldurmaz
## (2026-11-14, kullanıcı: "kalkan silahının kalkan yenileme özelliğini kaldır"; doldurma + Kalın Siper + Taşan Siper gitti, boşalan iki
## slot mevcut etkileri güçlendirir). Sağlam Siper (madde 705, Sert Darbe'nin yerine - kullanıcı: "hasarla ilgili geliştirmesini kaldırıp
## korumasıyla ilgili bir şey ekle"): siper duruşunun menzilli atış hasar azaltması %30 -> %(30 + siper_guard) (KalkanGuard.guard_shot;
## weapon.gd yayınlar, MP'de main.gd extra "kguard" kuklaya taşır). Ağır Kenar: kalkan %50 üstündeyken darbe x(1 + siper_heavy).
## Sert İtiş: darbenin itmesi x(1 + siper_push). Sarsıcı Darbe: vurulanlar yavaşlar. Final (siper_wall = N): her N. darbe 360°
## (KalkanBashMath.WALL_R), x1,5 hasar (%100 -> %150), 1 sn sersem. Sadece kasterde çalışır.

const KalkanGuard := preload("res://scripts/kalkan_guard.gd")
const SLOW_DUR := 1.5
const WALL_STUN := 1.0
const WALL_DAMAGE_MULT := 1.5 ## %100 -> %150
const HEAVY_AT := 0.5

var bashes: int = 0 ## gözlem/test


## Bu darbe Final mi (attacks on_fire'da arttı: 5., 10., ... darbe).
func wants_wall() -> bool:
	return can_act() and n("siper_wall") > 0 and every(n("siper_wall"))


func _shield_ratio() -> float:
	var p: Node = owner_player()
	if p == null:
		return 0.0
	var mx: float = float(p.get("item_shield_max")) if p.get("item_shield_max") != null else 0.0
	if mx <= 0.0:
		return 0.0
	return float(p.get("item_shield_hp")) / mx


## Siper duruşunun hasar azaltması (KalkanGuard.DAMAGE_REDUCTION + Sağlam Siper).
func guard_reduction() -> float:
	return KalkanGuard.DAMAGE_REDUCTION + f("siper_guard")


func bash_damage_mult(wall: bool) -> float:
	var m: float = WALL_DAMAGE_MULT if wall else 1.0
	if f("siper_heavy") > 0.0 and _shield_ratio() > HEAVY_AT:
		m *= 1.0 + f("siper_heavy")
	return m


## Darbenin itme çarpanı (weapon.gd _kalkan_hit_one; Sert İtiş).
func bash_push_mult() -> float:
	return 1.0 + f("siper_push")


func on_bash(victims: Array, wall: bool) -> void:
	if not can_act():
		return
	bashes += 1
	for v in victims:
		if wall:
			el(v, "stun", {"dur": WALL_STUN})
		if f("siper_slow") > 0.0:
			el(v, "slow", {"pct": f("siper_slow"), "dur": SLOW_DUR})
