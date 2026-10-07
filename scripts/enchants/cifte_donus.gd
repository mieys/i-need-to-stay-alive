extends "res://scripts/enchant_behavior.gd"

## Çifte Dönüş (Bumerang, kalıcı özellik) - bkz. EnchantDefs "cifte_donus". Her twin_every. atışta ikinci bir bumerang ters yönlü
## (hedefe göre -twin_angle derece) bir yay çizerek gider (hasar twin_dmg); Üçüncü Kol: üçüncüsü +twin_angle yönünde
## (twin_third hasar). Bumerangların gidip dönmesi weapon.gd/boomerang_projectile.gd'nin normal yolu: ek atış fire_enchant_shot ile
## aynı silahtan çıkar (ses/efekt/uzak kopya normal atışla aynı). "Geniş Yay" menzili ortak range_mult (configure_projectile).

const TWIN_DELAY := 0.12


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or not is_instance_valid(target) or not can_act() or not every(n("twin_every", 4)):
		return
	var ang: float = deg_to_rad(f("twin_angle", 40.0))
	weapon.fire_enchant_shot(target, TWIN_DELAY, f("twin_dmg", 0.7), -ang)
	if f("twin_third") > 0.0:
		weapon.fire_enchant_shot(target, TWIN_DELAY * 2.0, f("twin_third"), ang)
