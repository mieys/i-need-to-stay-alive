extends "res://scripts/enchant_behavior.gd"

## Zincir Cıvata (Arbalet, kalıcı özellik) - bkz. EnchantDefs "zincir_civata". Delme ortak "pierce" anahtarıyla (cıvata ilk
## düşmanı delip arkasındakilere çarpar); burada: delinen (ikincil) düşmanı cv_stun sn sersemletme. Ağır Cıvata: sersemleyen
## yavaşlar; Şok Dalgası: sersemleyenin 60 birim çevresine cıvata hasarının cv_splash'ı. Final (cv_all_stun): ilk hedef dahil
## vurulan HER düşman sersemler.

const SLOW_TIME := 1.5
const SPLASH_RADIUS := 60.0


func hit_extra(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	if proj == null or not is_enemy(t) or not can_act():
		return
	if is_primary and not flag("cv_all_stun"):
		return
	t.apply_element("stun", {"dur": f("cv_stun", 0.4)})
	if f("cv_slow") > 0.0:
		t.apply_element("slow", {"pct": f("cv_slow"), "dur": SLOW_TIME})
	if f("cv_splash") > 0.0:
		var at: Vector2 = (t as Node2D).global_position
		fx("ring", at, {"radius": SPLASH_RADIUS, "color": Color(0.85, 0.8, 0.65), "duration": 0.3})
		for e in enemies_near(at, SPLASH_RADIUS, t):
			hit(e, dmg * f("cv_splash"))
