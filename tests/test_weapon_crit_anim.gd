extends Node

## Kritik atış animasyonları (2026-09-29, bkz. scripts/weapon_crit_anim.gd, sword_swing_math.gd make_stab_plan).

const EnchantPool := preload("res://scripts/enchant_pool.gd")
const SwordSwingMath := preload("res://scripts/sword_swing_math.gd")


func test_every_weapon_has_a_crit_style() -> void:
	for key in EnchantPool.WEAPON_ICONS:
		assert(WeaponCritAnim.kind_of(str(key)) != "", "%s silahının kritik animasyonu yok (STYLES'a ekle)" % key)


func test_melee_kinds_only_for_melee_weapons() -> void:
	for key in ["dagger", "pence", "topuz"]:
		assert(WeaponCritAnim.is_melee_kind(key), "%s yakın dövüş kritik türü olmalı" % key)
	for key in ["yay", "tabanca", "fire_staff", "lightning_staff", "boomerang", "uzunkilic"]:
		assert(not WeaponCritAnim.is_melee_kind(key), "%s yakın dövüş kritik türü olmamalı" % key)
	assert(WeaponCritAnim.kind_of("tabanca") == "twirl", "Tabanca kritikte dönmeli (kullanıcı isteği)")
	assert(WeaponCritAnim.kind_of("lightning_staff") == "jitter", "Yıldırım asası kritikte titremeli")


func test_sword_stab_tip_enters_the_target() -> void:
	var target := Vector2(200.0, 120.0)
	var dir := Vector2(1.0, 0.5).normalized()
	var plan: Dictionary = SwordSwingMath.make_stab_plan(dir, target, 1.0, SwordSwingMath.REF_OWNER_SCALE)
	var k: float = float(plan["k"])
	## Saplama anında ikon merkezi + (uç - ikon yarıçapı) = uç; uç hedefi STAB_OVER kadar geçmeli.
	var tip: Vector2 = (plan["hit"] as Vector2) + dir * (SwordSwingMath.TIP_RADIUS - SwordSwingMath.ICON_RADIUS) * k
	assert(tip.distance_to(target + dir * SwordSwingMath.STAB_OVER * k) < 0.01, "Kılıç ucu hedefe saplanmıyor: %s" % str(tip))
	assert((plan["wind"] as Vector2).distance_to(target) > (plan["hit"] as Vector2).distance_to(target), "Geri çekilme hedeften daha uzakta olmalı")
