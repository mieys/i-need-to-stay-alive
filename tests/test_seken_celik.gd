extends Node

## Seken Çelik (Çakram kalıcı özelliği, madde 591): tanım sayıları, çakramın sekmesi (en yakın vurulmamış düşman, hasar ilk isabetin
## katı - birikmez, hedef yoksa döner), uzak kopyanın kasterin mesajıyla sekmesi (kendi seçmez), final Çelik Değirmen (dönüş noktasında
## tek kopya, yarıçap içindekilere tik, atış hiçbir şeye vurmadıysa kopya yok).

const BoomerangScene: PackedScene = preload("res://scenes/boomerang_projectile.tscn")
const BoomerangScript: GDScript = preload("res://scripts/boomerang_projectile.gd")
const SekenScript: GDScript = preload("res://scripts/weapon_traits/seken_celik.gd")
const WeaponTraitsScript: GDScript = preload("res://scripts/weapon_traits/weapon_traits.gd")
const EnchantFx: GDScript = preload("res://scripts/enchant_fx.gd")
const MillScript: GDScript = preload("res://scripts/chakram_mill_fx.gd")


class FakeEnemy extends Node2D:
	var hits: int = 0
	var amounts: Array = []
	var slowed: float = 0.0

	func _init() -> void:
		add_to_group("enemies")

	func take_damage(amount: float, _crit: bool = false, _pen: float = 0.0, _area: bool = false) -> void:
		hits += 1
		amounts.append(amount)

	func apply_element(kind: String, p: Dictionary) -> void:
		if kind == "slow":
			slowed = float(p.get("pct", 0.0))


class FakeOwner extends Node2D:
	var damage_bonus: float = 100.0


var _spawned: Array = []


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _proj(at: Vector2) -> Area2D:
	var p: Area2D = BoomerangScene.instantiate() as Area2D
	add_child(p)
	p.set("impact_sounds", [] as Array[AudioStream])
	p.set("impact_scene", null)
	p.global_position = at
	_spawned.append(p)
	return p


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	for n in _scene_mills():
		n.queue_free()
	await get_tree().physics_frame


## Test koşucusunda current_scene = test düğümü (run_tests.gd) - görsel kopyalar oraya eklenir.
func _scene_mills() -> Array:
	var out: Array = []
	var sc: Node = get_tree().current_scene
	if sc == null:
		return out
	for n in sc.get_children():
		if n.get_script() == MillScript and not n.is_queued_for_deletion():
			out.append(n)
	return out


func test_definition_numbers_and_old_trait_removed() -> void:
	assert(str(WeaponTraitsScript.TRAITS["boomerang"]) == "seken_celik", "çakramın özelliği Seken Çelik")
	assert(not ResourceLoader.exists("res://scripts/weapon_traits/cifte_donus.gd"), "Çifte Dönüş davranışı silindi")
	assert(not WeaponTraitsScript.DEFS.has("cifte_donus"), "Çifte Dönüş tanımı silindi")
	var base: Dictionary = EnchantDefs.resolve({"id": "seken_celik", "ups": [], "final": false}, "boomerang")
	assert(int(base["rico_count"]) == 1 and is_equal_approx(float(base["rico_dmg"]), 0.4) and is_equal_approx(float(base["rico_range"]), 100.0), "temel: 1 sekme %40 100 birim")
	assert(is_equal_approx(float(base["rico_slow"]), 0.0) and is_equal_approx(float(base["mill_dur"]), 0.0), "temelde yavaşlatma ve kopya yok")
	var ups: Dictionary = EnchantDefs.resolve({"id": "seken_celik", "ups": [0, 1, 2, 3], "final": false}, "boomerang")
	assert(int(ups["rico_count"]) == 2 and is_equal_approx(float(ups["rico_dmg"]), 0.55) and is_equal_approx(float(ups["rico_range"]), 140.0), "geliştirmeler: 2 sekme %55 140 birim")
	assert(is_equal_approx(float(ups["rico_slow"]), 0.2) and is_equal_approx(float(ups["mill_dur"]), 0.0), "Çentik %20, kopya yalnız finalde")
	var full: Dictionary = EnchantDefs.resolve({"id": "seken_celik", "ups": [0, 1, 2, 3], "final": true}, "boomerang")
	assert(is_equal_approx(float(full["mill_dur"]), 2.5) and is_equal_approx(float(full["mill_radius"]), 32.0), "final: 2,5 sn, 32 birim")
	assert(is_equal_approx(float(full["mill_tick"]), 0.3) and is_equal_approx(float(full["mill_ap"]), 0.15), "final: 0,3 sn'de %15 SG")


func test_bounces_to_nearest_unhit_enemy_with_non_compounding_damage() -> void:
	var a: FakeEnemy = _enemy(Vector2(1000, 1000))
	var b: FakeEnemy = _enemy(Vector2(1060, 1000))
	var c: FakeEnemy = _enemy(Vector2(1090, 1000))
	var far: FakeEnemy = _enemy(Vector2(1300, 1000))
	await get_tree().physics_frame
	var p: Area2D = _proj(Vector2(1000, 1000))
	p.set("damage", 10.0)
	p.set("bounce_left", 2)
	p.set("bounce_range", 100.0)
	p.set("bounce_dmg_mult", 0.4)
	p._on_body_entered(a)
	assert(a.hits == 1 and is_equal_approx(float(a.amounts[0]), 10.0), "ilk isabet tam hasar")
	assert(p.get("_returning") == false and int(p.get("bounces_done")) == 1, "dönmez, seker")
	assert((p.get("direction") as Vector2).x > 0.99, "en yakın (b) yönüne seker: %s" % str(p.get("direction")))
	p.global_position = b.global_position
	p._on_body_entered(b)
	assert(b.hits == 1 and is_equal_approx(float(b.amounts[0]), 4.0), "sekme isabeti %%40: %s" % str(b.amounts))
	assert(p.get("_returning") == false and int(p.get("bounces_done")) == 2, "ikinci sekme")
	p.global_position = c.global_position
	p._on_body_entered(c)
	assert(c.hits == 1 and is_equal_approx(float(c.amounts[0]), 4.0), "hasar birikmez (ilk isabetin %%40'ı): %s" % str(c.amounts))
	assert(p.get("_returning") == true, "sekme hakkı bitti -> döner")
	assert(a.hits == 1 and far.hits == 0, "vurulmuşa geri sekmez, menzil dışına sekmez")
	assert(int(p.call("hit_count")) == 3, "atış 3 düşmana vurdu")
	await _cleanup()


func test_no_target_in_range_returns_like_before() -> void:
	var a: FakeEnemy = _enemy(Vector2(2000, 1000))
	var far: FakeEnemy = _enemy(Vector2(2200, 1000))
	await get_tree().physics_frame
	var p: Area2D = _proj(Vector2(2000, 1000))
	p.set("bounce_left", 1)
	p.set("bounce_range", 100.0)
	p._on_body_entered(a)
	assert(p.get("_returning") == true and int(p.get("bounces_done")) == 0, "yakında düşman yoksa eskisi gibi döner")
	assert(far.hits == 0)
	await _cleanup()


func test_bounce_leg_returns_if_target_is_missed() -> void:
	var a: FakeEnemy = _enemy(Vector2(3000, 1000))
	var b: FakeEnemy = _enemy(Vector2(3050, 1000))
	await get_tree().physics_frame
	var p: Area2D = _proj(Vector2(3000, 1000))
	p.set("bounce_left", 1)
	p.set("bounce_range", 100.0)
	p._on_body_entered(a)
	assert(p.get("_returning") == false)
	b.global_position = Vector2(3050, 1400) ## hedef kaçtı
	for i in range(30):
		p._move_physics(1.0 / 60.0)
	assert(p.get("_returning") == true, "bacak sonunda (uzaklık x1,25 + 24) döner")
	await _cleanup()


func test_network_copy_waits_and_follows_casters_leg() -> void:
	var a: FakeEnemy = _enemy(Vector2(4000, 1000))
	await get_tree().physics_frame
	var c: Area2D = _proj(Vector2(4000, 1000))
	c.set_meta("network_spawned", true)
	EnchantFx.apply_projectile_look(c, {"props": {"bounce_left": 1, "net_pid": 4242}})
	c._on_body_entered(a)
	assert(a.hits == 0, "kopya hasar vermez")
	assert(c.get("_returning") == false and float(c.get("_await_leg")) > 0.0, "kopya kendi sekme seçmez, kasterin mesajını bekler")
	EnchantFx.spawn(get_tree(), "chakram_leg", Vector2(4002, 1000), {"pid": 4242, "to": Vector2(4000, 1080)})
	assert(int(c.get("bounces_done")) == 1 and int(c.get("bounce_left")) == 0, "mesajla sekti")
	assert((c.get("direction") as Vector2).y > 0.99 and c.get("_returning") == false, "kasterin hedefine döner: %s" % str(c.get("direction")))
	## Mesajı hiç gelmeyen kopya: bekleme süresi dolunca kendisi döner.
	var c2: Area2D = _proj(Vector2(4000, 1000))
	c2.set_meta("network_spawned", true)
	EnchantFx.apply_projectile_look(c2, {"props": {"bounce_left": 1, "net_pid": 4343}})
	c2._on_body_entered(a)
	c2._move_physics(0.5)
	assert(c2.get("_returning") == true, "mesaj gelmezse döner")
	await _cleanup()
	EnchantFx.spawn(get_tree(), "chakram_leg", Vector2.ZERO, {"pid": 4242, "to": Vector2.ONE}) ## silinmiş kopya: sessiz geçer


func test_final_mill_one_at_a_time_damages_inside_radius() -> void:
	var owner_node := FakeOwner.new()
	add_child(owner_node)
	_spawned.append(owner_node)
	var w := Node2D.new()
	owner_node.add_child(w)
	var beh: Node = SekenScript.new()
	w.add_child(beh)
	beh.call("setup", w, EnchantDefs.resolve({"id": "seken_celik", "ups": [0, 1, 2, 3], "final": true}, "boomerang"))
	var at := Vector2(5000, 1000)
	var near: FakeEnemy = _enemy(at + Vector2(20, 0))
	var out: FakeEnemy = _enemy(at + Vector2(50, 0))
	await get_tree().physics_frame
	## Hiçbir şeye vurmamış atış: kopya yok.
	var miss: Area2D = _proj(at)
	beh.call("on_boomerang_apex", miss)
	assert(int(beh.get("mills")) == 0, "boşa giden atış kopya bırakmaz")
	var p: Area2D = _proj(at)
	p._on_body_entered(near)
	beh.call("on_boomerang_apex", p)
	assert(int(beh.get("mills")) == 1, "vuran atış kopya bırakır")
	assert(_scene_mills().size() == 1, "görsel kopya sahnede: %d" % _scene_mills().size())
	beh.call("on_boomerang_apex", p)
	assert(int(beh.get("mills")) == 1, "aynı anda en fazla 1 kopya")
	near.hits = 0
	beh.call("process_extra", 0.0)
	assert(near.hits == 1 and is_equal_approx(float(near.amounts[-1]), 15.0), "yarıçap içi: SG 100 x %%15: %s" % str(near.amounts))
	assert(out.hits == 0, "32 birim dışı vurulmaz")
	beh.call("process_extra", 0.31)
	assert(near.hits == 2, "0,3 sn sonra ikinci tik")
	beh.call("process_extra", 2.5)
	beh.call("on_boomerang_apex", p)
	assert(int(beh.get("mills")) == 2, "süre dolunca yeni kopya")
	await _cleanup()


func test_notch_slows_only_bounce_hits() -> void:
	var owner_node := FakeOwner.new()
	add_child(owner_node)
	_spawned.append(owner_node)
	var w := Node2D.new()
	owner_node.add_child(w)
	var beh: Node = SekenScript.new()
	w.add_child(beh)
	beh.call("setup", w, EnchantDefs.resolve({"id": "seken_celik", "ups": [3], "final": false}, "boomerang"))
	var first: FakeEnemy = _enemy(Vector2(6000, 1000))
	var second: FakeEnemy = _enemy(Vector2(6060, 1000))
	var p: Area2D = _proj(Vector2(6000, 1000))
	beh.call("hit_extra", first, 10.0, true, p)
	assert(is_equal_approx(first.slowed, 0.0), "ilk isabet yavaşlatmaz")
	p.set("bounces_done", 1)
	beh.call("hit_extra", second, 4.0, true, p)
	assert(is_equal_approx(second.slowed, 0.2), "sekme isabeti %%20 yavaşlatır")
	await _cleanup()
