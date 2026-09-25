extends "res://scripts/enchant_behavior.gd"

## Şimşek Çekici (EnchantDefs "topuz_simsek"): şok / şoklu bonus / ölüm yıldırımı temel sınıfta. II: her vuruş rastgele
## yakın düşmanlara yıldırım dalları. Final (Steroid): her 8 sn'de topuz fırlatılıp döner, yolunda yıldırım bırakır
## (enchant_area.gd "hammer"), boyutu maks canla büyür.

const BRANCH_RADIUS := 150.0
const THROW_COOLDOWN := 8.0

var _last_pos: Vector2 = Vector2.ZERO
var _throw_timer: float = THROW_COOLDOWN


func fire_start(target: Node2D, _is_extra: bool) -> void:
	if is_instance_valid(target):
		_last_pos = target.global_position


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra or n("branches") <= 0:
		return
	for e in random_enemies(_last_pos, BRANCH_RADIUS, n("branches")):
		hit(e, ap() * 0.35 * power)
		fx("chain", _last_pos, {"to": e.global_position})


func process_extra(delta: float) -> void:
	if not flag("hammer_throw"):
		return
	_throw_timer -= delta
	if _throw_timer > 0.0:
		return
	var p: Node = owner_player()
	var e: Node = nearest_enemy(p.global_position, 400.0) if can_act() else null
	if e == null:
		_throw_timer = 1.0
		return
	_throw_timer = THROW_COOLDOWN
	var size_mult: float = clampf(1.0 + max_hp() / 1000.0, 1.0, 2.0)
	var icon_path: String = ""
	var icon_scale: float = 1.0
	var icon: Node = weapon.get("icon_sprite")
	if icon is Sprite2D and (icon as Sprite2D).texture:
		icon_path = (icon as Sprite2D).texture.resource_path
		icon_scale = absf((icon as Sprite2D).scale.x) * 1.8 * size_mult
	area("hammer", p.global_position, {"dir": dir_to(p.global_position, e), "range": 220.0, "duration": 1.6,
		"damage": ap() * 0.8 * power, "branch": ap() * 0.3 * power, "icon": icon_path, "icon_scale": icon_scale,
		"scale": size_mult, "shock": shock_params()})
