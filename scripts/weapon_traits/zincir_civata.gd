extends "res://scripts/enchant_behavior.gd"

## Zincir Cıvata (Arbalet, kalıcı özellik) - bkz. EnchantDefs "zincir_civata". Delme ortak "pierce" anahtarıyla (cıvata ilk
## düşmanı delip arkasındakilere çarpar); burada: delinen (ikincil) düşmanı cv_stun sn sersemletme. Ağır Cıvata: sersemleyen
## yavaşlar; Şok Dalgası: sersemleyenin 60 birim çevresine cıvata hasarının cv_splash'ı. Final (cv_all_stun): ilk hedef dahil
## vurulan HER düşman sersemler.

const SLOW_TIME := 1.5
const SPLASH_RADIUS := 60.0
## 2026-10-20 denge turu (BALANCE_REV 94): sersemlik kilidi kırıcı. Final (1 sn sersemlik, vurulan HERKES) ~0,86-1,14 sn atış aralığıyla art arda uygulanınca
## sıradan yaratıklar (boss hariç) sonsuza dek sersemde kalıyordu; Arbalet'in 5 düşmanlık delme hattıyla birleşince oyunun en güçlü kontrolüydü. Artık bir yaratık
## sersemliği bittikten sonra sersemlik süresi kadar (1 sn) bu özellikle yeniden sersemletilemez -> en çok %50 sersem kalma süresi. Temel 0,4 sn / geliştirme
## 0,7 sn sersemlik atış aralığından kısa olduğu için pratikte etkilenmez. Yavaşlatma ve şok dalgası hasarı bu kapıdan bağımsız, her isabette işler.
const STUN_FREE_META := &"cv_stun_free_at"


func hit_extra(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	if proj == null or not is_enemy(t) or not can_act():
		return
	if is_primary and not flag("cv_all_stun"):
		return
	var stun_dur: float = f("cv_stun", 0.4)
	var now: int = Time.get_ticks_msec()
	if now >= int(t.get_meta(STUN_FREE_META, 0)):
		t.set_meta(STUN_FREE_META, now + int(stun_dur * 2000.0)) ## sersemlik + eşit süre bağışıklık
		el(t, "stun", {"dur": stun_dur})
	if f("cv_slow") > 0.0:
		el(t, "slow", {"pct": f("cv_slow"), "dur": SLOW_TIME})
	if f("cv_splash") > 0.0:
		var at: Vector2 = (t as Node2D).global_position
		fx("ring", at, {"radius": SPLASH_RADIUS, "color": Color(0.85, 0.8, 0.65), "duration": 0.3})
		for e in enemies_near(at, SPLASH_RADIUS, t):
			hit(e, dmg * f("cv_splash"))
