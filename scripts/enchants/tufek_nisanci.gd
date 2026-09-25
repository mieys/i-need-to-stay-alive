extends "res://scripts/enchant_behavior.gd"

## Nişancı (EnchantDefs "tufek_nisanci"): kritik şansı/hasarı, uzak bonusu, durunca saldırı hızı temel sınıfta. Burada:
## kritik sersemletir; final (Şanslı Zar) kritiklerin %25'i iki kat daha güçlü + canı %20'nin altındaki normal düşman
## tek atışta ölür.


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if f("super_crit") > 0.0 and bool(proj.get("is_crit")) and randf() < f("super_crit"):
		proj.set("damage", float(proj.get("damage")) * 2.0)
		proj.set_meta("enchant_super", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_super"):
		d["tint"] = Color(1.0, 0.85, 0.4)
		d["trail"] = "missile"
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_enemy(t):
		return
	if proj != null and proj.has_meta("enchant_super") and is_primary:
		fx("text", t.global_position, {"text": "Süper Kritik", "color": Color(1.0, 0.85, 0.4)})
	if f("crit_stun") > 0.0 and proj != null and bool(proj.get("is_crit")):
		t.apply_element("stun", {"dur": f("crit_stun")})
	if f("execute") > 0.0 and t.get("is_boss") != true and float(t.get("max_health")) > 0.0 \
			and float(t.get("health")) / float(t.get("max_health")) < f("execute"):
		hit(t, float(t.get("health")) + 1.0)
