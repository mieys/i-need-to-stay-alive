extends "res://scripts/enchant_behavior.gd"

## Şimşek Fişeği (EnchantDefs "fisek_simsek"): patlamanın vurdukları şoklanır / ölüm yıldırımı temel sınıfta. Patlama
## çevreye yıldırım dalları saçar; final (Yetenek Kitabı) Elektrik Fırtınası - patlama noktasında 4 sn'lik elektrik
## bulutu (enchant_area.gd "electric_cloud", saniyede 3 yıldırım).

const BRANCH_RADIUS := 150.0


func on_explode(_proj: Node2D, pos: Vector2) -> void:
	for e in random_enemies(pos, BRANCH_RADIUS, n("branches")):
		hit(e, ap() * 0.35 * pw("area"))
		fx("chain", pos, {"to": e.global_position})
	if flag("storm_cloud"):
		area("electric_cloud", pos, {"radius": 120.0, "duration": 4.0, "damage": ap() * 0.3 * pw("area")})
