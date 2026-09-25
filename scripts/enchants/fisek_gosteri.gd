extends "res://scripts/enchant_behavior.gd"

## Havai Fişek Gösterisi (EnchantDefs "fisek_gosteri"): patlama (firework_projectile.gd _explode -> on_explode) çevreye
## küçük parçacık patlamalarına ayrılır; V: her parçacık 2 mini parçacık; VI: parçacık rastgele element. Görsel tek RPC
## (EnchantFx "bursts"). Final (Şanslı Zar) Bayram Gecesi: 12 sn'de bir rastgele düşmanlara 10 fişek (+ şans / 5).

const SPARK_RADIUS := 40.0
const FEST_COOLDOWN := 12.0
const COLORS := [Color(1.0, 0.45, 0.5), Color(0.5, 0.85, 1.0), Color(1.0, 0.9, 0.4), Color(0.6, 1.0, 0.5), Color(0.85, 0.6, 1.0)]

var _fest_timer: float = FEST_COOLDOWN


func on_explode(_proj: Node2D, pos: Vector2) -> void:
	var count: int = n("sparks")
	if count <= 0:
		return
	var r: float = SPARK_RADIUS * f("spark_radius", 1.0)
	var points: Array = []
	var off: float = randf() * TAU
	for k in range(count):
		var at: Vector2 = pos + Vector2.RIGHT.rotated(off + TAU * float(k) / float(count)) * randf_range(60.0, 85.0)
		points.append(at)
		_spark(at, r, ap() * 0.3 * pw("area"))
		if flag("spark_split"):
			for s in [-1.0, 1.0]:
				var mini_at: Vector2 = at + (at - pos).normalized().rotated(0.6 * s) * 40.0
				points.append(mini_at)
				_spark(mini_at, r * 0.6, ap() * 0.15 * pw("area"))
	fx("bursts", pos, {"points": points, "palette": "spark", "count": 7, "radius": r * 0.8, "color": COLORS[randi() % COLORS.size()]})


func _spark(at: Vector2, r: float, dmg: float) -> void:
	for e in enemies_near(at, r):
		hit(e, dmg)
		if flag("spark_element"):
			match randi() % 4:
				0:
					apply_burn_to(e)
				1:
					freeze(e, 1.0)
				2:
					apply_poison_to(e)
				3:
					apply_shock_to(e)


func process_extra(delta: float) -> void:
	if not flag("festival"):
		return
	_fest_timer -= delta
	if _fest_timer > 0.0:
		return
	var p: Node = owner_player()
	var targets: Array = random_enemies(p.global_position, float(weapon.get("attack_range")) * 1.3, 10 + int(luck() / 5.0)) if can_act() else []
	if targets.is_empty():
		_fest_timer = 1.0
		return
	_fest_timer = FEST_COOLDOWN
	for i in range(targets.size()):
		weapon.fire_enchant_shot(targets[i], 0.08 * float(i), 1.0, 0.0)
