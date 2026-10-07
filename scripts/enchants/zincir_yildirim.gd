extends "res://scripts/enchant_behavior.gd"

## Zincir Yıldırım (Yıldırım Asası, kalıcı özellik) - bkz. EnchantDefs "zincir_yildirim". Sıçramanın kendisi weapon.gd
## _apply_chain_jumps'ta (chain_add / chain_pct / chain_range ortak anahtarları, enchant_behavior.gd chain_bonus/chain_pct/
## chain_range_mult); burada sadece "Çarpılma" geliştirmesi: atlayan şimşeğin vurduğu düşmanlar kısa süre yavaşlar.

const SLOW_TIME := 1.0


func on_chain(_primary: Node, targets: Array, _dmg: float) -> void:
	if f("chain_slow") <= 0.0:
		return
	for e in targets:
		if is_enemy(e):
			e.apply_element("slow", {"pct": f("chain_slow"), "dur": SLOW_TIME})
