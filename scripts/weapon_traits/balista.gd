extends "res://scripts/enchant_behavior.gd"

## Balista (Arbalet, kalıcı özellik) - bkz. weapon_traits.gd "balista" (madde 553; Zincir Cıvata'nın yerine, kullanıcı eski Arrow Rain finalinin
## balista okunu seçti). Her bal_every. gerçek atışın cıvatası isabet ettiği yere gökten dev bir balista oku indirir (ballista sayfası, ağda herkes
## görür): ok yere varınca (IMPACT_DELAY) bal_radius içindekilere bal_ap x saldırı gücü hasar, Sarsıcı Düşüş (bal_stun) onları sersemletir.
## Final (bal_second): ikinci ok SECOND_DELAY sonra aynı noktaya iner. Hasar yalnız kasterde (hit/el istemcide host'a yönlenir), görsel her yerde.

const SpriteFxScript := preload("res://scripts/fx_enchant_sprite.gd")
const SHEET_RX := 38.0 ## ballista sayfasında delik + taş halkasının yarıçapı (sanat px); ölçek = bal_radius / (SHEET_RX x TEXEL)
const TEXEL := 1.212
const IMPACT_DELAY := 0.15 ## sayfa 20 fps: ok 3. karede yere varır
const SECOND_DELAY := 0.45

var drops: int = 0 ## indirilen ok sayısı (test)
var _marked: bool = false


func _on_setup() -> void:
	SpriteFxScript.frames("ballista") ## ilk okta kare takılması olmasın (kaynak önceden yüklenir)


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_marked = not is_extra and every(maxi(1, n("bal_every", 4)))


func projectile_extra(proj: Node2D, _target: Node2D, is_extra: bool) -> void:
	if _marked and not is_extra:
		proj.set_meta("balista_shot", true)


func fire_extra(_target: Node2D, _is_extra: bool) -> void:
	_marked = false


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if proj == null or not is_instance_valid(proj) or not proj.has_meta("balista_shot"):
		return
	proj.remove_meta("balista_shot") ## mermi başına bir ok
	if not is_primary or not is_enemy(t) or not can_act():
		return
	var at: Vector2 = (t as Node2D).global_position
	drops += 1
	_drop(at)
	if f("bal_second") > 0.0:
		get_tree().create_timer(SECOND_DELAY).timeout.connect(_drop.bind(at))


func _drop(at: Vector2) -> void:
	if not is_inside_tree() or not is_instance_valid(weapon):
		return
	var r: float = maxf(20.0, f("bal_radius", 70.0))
	sprite("ballista", at, {"scale": r / (SHEET_RX * TEXEL), "offset": Vector2(0.0, -40.0), "z": 9})
	get_tree().create_timer(IMPACT_DELAY).timeout.connect(_land.bind(at, r))


func _land(at: Vector2, r: float) -> void:
	if not is_inside_tree() or not is_instance_valid(weapon):
		return
	var dmg: float = ap() * f("bal_ap", 1.5)
	var stun: float = f("bal_stun")
	for e in enemies_near(at, r):
		hit(e, dmg)
		if stun > 0.0:
			el(e, "stun", {"dur": stun})
