extends "res://scripts/enchant_behavior.gd"

## Dönen Saldırı (Pençe / Uzunkılıç) - bkz. EnchantDefs "donen_saldiri". spin_cd sn'de bir, sıradaki ana hedef yakın dövüş
## isabeti (Pençe _melee_strike, Uzunkılıç _sword_contact aynı yoldan on_hit'e gelir) sahibin çevresinde 360° savurmaya
## dönüşür (spin_slash sayfası). 2026-10-04 denge turu: eskiden "her 6. vuruş"tu - Uzunkılıç ~0,8 isabet/sn ile 16 sn'de 2
## kez çıkıyordu, Pençe iki parçalı vuruşu yüzünden iki kat sayıyordu; zamana bağlamak iki silahı da eşitler. Final: değdiklerine 4 sn kanama + sahibin çevresindeki düşman mermilerini yok eden anlık hava dalgası (air_ring
## sayfası; player.gd set_enchant_ward -> Talon çemberiyle aynı kanal, host'ta kuklaya da sorulur).

const SHEET_RX := 74.0
const WARD_TIME := 0.4

var _ready_msec: int = 0


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj != null or not is_enemy(t) or not can_act():
		return
	var now: int = Time.get_ticks_msec()
	if now < _ready_msec:
		return
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	_ready_msec = now + int(maxf(0.5, f("spin_cd", 3.0)) * 1000.0)
	var at: Vector2 = pl.global_position
	var r: float = f("spin_radius", 90.0)
	sprite("spin_slash", at, {"scale": r / (SHEET_RX * 1.212), "z": 9})
	var victims: Array = enemies_near(at, r)
	for e in victims:
		hit(e, ap() * f("spin_ap", 1.0))
	if f("spin_bleed") > 0.0:
		timed_dot(victims, ap() * f("spin_bleed"), 4.0)
	if f("spin_ward") > 0.0:
		set_ward(f("spin_ward"), WARD_TIME)
		sprite("air_ring", at, {"scale": f("spin_ward") / (99.0 * 1.212), "z": 9})
