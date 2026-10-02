extends "res://scripts/enchant_behavior.gd"

## Seken Mermiler (Tabanca / Tüftüf) - bkz. EnchantDefs "seken_mermiler". Sekme ortak mekanik (enchant_behavior.gd
## _projectile_follow_up: "bounce" sayısı, "bounce_ramp" sekiş başı hasar artışı, "bounce_range" mesafe çarpanı,
## "bounce_pct" 1.0 = sekişte hasar düşmez). Burada: her sekişte küçük kıvılcım (bounce_spark) ve Final "Kinetik Çığ":
## mermi son hedefine vardığında biriktirdiği ek hasarı (şimdiki hasar - ilk hasar) 70 birimlik patlamayla saçar
## (kinetic_blast sayfası).

const AVALANCHE_RADIUS := 70.0


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if "damage" in proj:
		proj.set_meta("seken_base", float(proj.get("damage")))


func hit_extra(t: Node, _dmg: float, _is_primary: bool, proj: Node2D) -> void:
	if proj == null or not is_instance_valid(proj) or not proj.has_meta("enchant_bounce") or not is_enemy(t):
		return
	var at: Vector2 = (t as Node2D).global_position
	if not NetworkManager.should_throttle("seken_spark", 0.05): ## hızlı atışta her sekiş bir yayın olmasın
		sprite("bounce_spark", at, {"z": 9})
	if not flag("avalanche"):
		return
	var left: int = int(proj.get_meta("enchant_bounce"))
	if left > 0:
		return
	## Sayaç bu isabette 0'a indiyse bu son sekiş DEĞİL (bir sonraki hedefe yöneldi); zaten 0'dayken gelen isabet sonuncusu.
	if not proj.has_meta("seken_zero_seen"):
		proj.set_meta("seken_zero_seen", true)
		return
	if proj.has_meta("seken_done"):
		return
	proj.set_meta("seken_done", true)
	var bonus: float = float(proj.get("damage")) - float(proj.get_meta("seken_base", proj.get("damage")))
	if bonus <= 0.0:
		return
	sprite("kinetic_blast", at, {"scale": AVALANCHE_RADIUS / (58.0 * 1.212), "z": 9})
	for e in enemies_near(at, AVALANCHE_RADIUS):
		hit(e, bonus)
