extends Node

## Kullanıcı isteği (2026-10-04): "yay, crossbow, tabanca, ateş asası, buz asası, tüfek, tüftüf silahları ateşlendiğinde biraz geri tepsin.
## Yıldırım asası aktif olduğunda hafif titresin." - WeaponJuice.ranged_recoil / tremor_offset (weapon.gd ve remote_player.gd ortak).

const KEYS := ["yay", "crossbow", "tabanca", "fire_staff", "buz_asasi", "tufek", "tuftuf"]

var _made: Array[Node] = []


func _icon(pos: Vector2, scale_v: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.scale = scale_v
	add_child(n)
	_made.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func test_table_covers_the_requested_weapons_and_not_the_lightning_staff() -> void:
	for k: String in KEYS:
		assert(WeaponJuice.has_ranged_recoil(k), "%s geri tepme tablosunda olmalı" % k)
	assert(not WeaponJuice.has_ranged_recoil("lightning_staff"), "Yıldırım asasının geri tepmesi yok (sürekli ışın - titrer)")
	assert(not WeaponJuice.has_ranged_recoil("boomerang"), "Fırlatılan silahlar eski yolda kalmalı")


func test_normal_recoil_is_never_harder_than_the_crit_animation() -> void:
	for k: String in KEYS:
		var normal: float = float(WeaponJuice.RANGED_RECOIL[k]["kick"])
		var crit: float = float(WeaponCritAnim.STYLES[k]["kick"])
		assert(normal <= crit, "%s: normal tepme (%.1f) kritikten (%.1f) sert olmamalı" % [k, normal, crit])
		assert(normal > 1.0, "%s: eski düz tepmeden (1.0x) daha belirgin olmalı" % k)


## Tween'i kare kare izler (süre sn): en sol/sağ konum ve rotasyonun uç değerleri.
func _watch(icon: Node2D, seconds: float) -> Dictionary:
	var out := {"min_x": icon.position.x, "max_x": icon.position.x, "min_rot": icon.rotation, "max_rot": icon.rotation}
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().process_frame
		out["min_x"] = minf(float(out["min_x"]), icon.position.x)
		out["max_x"] = maxf(float(out["max_x"]), icon.position.x)
		out["min_rot"] = minf(float(out["min_rot"]), icon.rotation)
		out["max_rot"] = maxf(float(out["max_rot"]), icon.rotation)
	return out


func test_recoil_kicks_away_from_the_target_then_settles_back() -> void:
	var base_scale := Vector2(0.3, 0.3)
	var icon: Node2D = _icon(Vector2.ZERO, base_scale)
	WeaponJuice.ranged_recoil(self, icon, "tufek", Vector2.RIGHT, Vector2.ZERO, base_scale, 10.0)
	var w: Dictionary = await _watch(icon, 0.2)
	assert(float(w["min_x"]) < -12.0, "Hedef sağdaysa ikon sola (tersine) en az 12 px tepmeli: %s" % str(w))
	assert(float(w["min_rot"]) < -0.05, "Namlu kalkmalı (sağa bakan ikonda saat yönünün tersi): %s" % str(w))
	await get_tree().create_timer(0.7).timeout
	assert(icon.position.length() < 0.2, "İkon dinlenme konumuna dönmeli: %s" % str(icon.position))
	assert(icon.scale.is_equal_approx(base_scale), "Ölçek tabana oturmalı: %s" % str(icon.scale))
	assert(absf(icon.rotation) < 0.01, "Net dönüş sıfır olmalı: %f" % icon.rotation)
	_cleanup()


func test_recoil_respects_a_non_zero_rest_position_and_a_leftward_target() -> void:
	var rest := Vector2(20.0, -8.0)
	var icon: Node2D = _icon(rest, Vector2.ONE)
	WeaponJuice.ranged_recoil(self, icon, "tabanca", Vector2.LEFT, rest, Vector2.ONE, 10.0)
	var w: Dictionary = await _watch(icon, 0.2)
	assert(float(w["max_x"]) > rest.x + 10.0, "Hedef solda: ikon sağa tepmeli: %s" % str(w))
	assert(float(w["max_rot"]) > 0.05, "Sola bakan ikonda namlu saat yönünde kalkar: %s" % str(w))
	await get_tree().create_timer(0.7).timeout
	assert(icon.position.distance_to(rest) < 0.2, "Yuvaya dönmeli: %s" % str(icon.position))
	_cleanup()


func test_rapid_fire_does_not_accumulate_drift() -> void:
	var base_scale := Vector2(0.5, 0.5)
	var icon: Node2D = _icon(Vector2.ZERO, base_scale)
	var tw: Tween = null
	for _i in range(6):
		if tw and tw.is_valid():
			tw.kill()
		tw = WeaponJuice.ranged_recoil(self, icon, "yay", Vector2(1.0, 0.5), Vector2.ZERO, base_scale, 10.0)
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.8).timeout
	assert(icon.position.length() < 0.3, "Seri atışta konum kaymamalı: %s" % str(icon.position))
	assert(icon.scale.is_equal_approx(base_scale), "Seri atışta ölçek büyümemeli: %s" % str(icon.scale))
	_cleanup()


func test_tremor_is_small_steady_within_a_step_and_changes_between_steps() -> void:
	var seen: Dictionary = {}
	for i in range(40):
		var t: float = float(i) / WeaponJuice.TREMOR_HZ
		var o: Vector2 = WeaponJuice.tremor_offset(t + 0.001)
		assert(o.length() <= WeaponJuice.TREMOR_AMP * 1.5, "Titreme küçük kalmalı: %s" % str(o))
		seen[snappedf(o.x, 0.001)] = true
	assert(seen.size() > 10, "Titreme adımdan adıma değişmeli (farklı nokta sayısı: %d)" % seen.size())
	var a: Vector2 = WeaponJuice.tremor_offset(1.0 / WeaponJuice.TREMOR_HZ * 5.0 + 0.002)
	var b: Vector2 = WeaponJuice.tremor_offset(1.0 / WeaponJuice.TREMOR_HZ * 5.0 + 0.02)
	assert(a.is_equal_approx(b), "Aynı adım içinde nokta sabit olmalı")
