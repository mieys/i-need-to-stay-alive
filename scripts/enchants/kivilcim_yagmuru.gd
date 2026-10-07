extends "res://scripts/enchant_behavior.gd"

## Kıvılcım Yağmuru (Fişek, kalıcı özellik) - bkz. EnchantDefs "kivilcim_yagmuru". Fişek patlayınca (on_explode) patlama yerinde
## spark_dur sn boyunca her spark_gap sn'de spark_count kıvılcım patlaması: spark_area yarıçaplı alanda rastgele noktalar, her biri
## spark_radius içine saldırı gücü x spark_ap x spark_mult hasar (sprite: mini_pop, herkese yayınlanır).

const POP_SCALE := 0.85


func on_explode(_proj: Node2D, pos: Vector2) -> void:
	if not can_act():
		return
	var gap: float = maxf(0.1, f("spark_gap", 0.4))
	var count: int = maxi(1, int(f("spark_dur", 3.0) / gap))
	for i in range(count):
		get_tree().create_timer(gap * float(i + 1), false).timeout.connect(_spark.bind(pos))


func _spark(center: Vector2) -> void:
	if not is_instance_valid(self) or not is_instance_valid(weapon) or not can_act():
		return
	for k in range(maxi(1, n("spark_count", 1))):
		var at: Vector2 = center + Vector2.from_angle(randf() * TAU) * (f("spark_area", 45.0) * sqrt(randf())) * Vector2(1.0, 0.8)
		sprite("mini_pop", at, {"scale": Vector2.ONE * POP_SCALE, "z": 9})
		var dmg: float = ap() * f("spark_ap", 0.25) * f("spark_mult", 1.0)
		for e in enemies_near(at, f("spark_radius", 22.0)):
			hit(e, dmg)
