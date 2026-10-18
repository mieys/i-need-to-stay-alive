extends Node

## Süzülen silahların HÜCUM takibi (madde 247; prototip madde 245 E v2): WeaponFollowMath kuralları + yerel
## weapon.gd (gizlen/çık, uç yönü, hücum ofseti, en üst kademe parıltısı, iz YOK) + uzak kukla remote_player.gd pivotları.

const TabancaScene: PackedScene = preload("res://scenes/weapon_tabanca.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const FollowFx := preload("res://scripts/weapon_follow_fx.gd")

var _spawned: Array[Node] = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


class FakeOwner extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false


class FakeEnemy extends Node2D:
	var is_dead: bool = false


func _make_owner(pos: Vector2) -> FakeOwner:
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5) ## main.tscn Player kökü
	add_child(o)
	o.global_position = pos
	_track(o)
	return o


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_track(e)
	return e


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## ---------- saf kurallar ----------
func test_charge_offset_pushes_forward_and_lowers_the_top_only_sideways() -> void:
	assert(WeaponFollowMath.slot_kind(Vector2(0, -125)) == 0 and WeaponFollowMath.slot_kind(Vector2(62, -70)) == 1 \
			and WeaponFollowMath.slot_kind(Vector2(-62, -70)) == 2, "slot türleri: tepe / sağ / sol")
	var right := Vector2(1.0, 0.0)
	assert(WeaponFollowMath.charge_offset(0, right).is_equal_approx(Vector2(WeaponFollowMath.PUSH_TOP, WeaponFollowMath.LOW_TOP)),
			"sağa: tepe 18 öne + 12 alçalır")
	assert(WeaponFollowMath.charge_offset(1, right).is_equal_approx(Vector2(WeaponFollowMath.PUSH_SIDE, 0.0)), "yan 10 öne")
	assert(WeaponFollowMath.charge_offset(0, Vector2(0.0, -1.0)).is_equal_approx(Vector2(0.0, -WeaponFollowMath.PUSH_TOP)),
			"yukarı yürürken tepe alçalmaz")
	assert(WeaponFollowMath.charge_offset(0, Vector2.ZERO) == Vector2.ZERO, "dururken ofset yok")
	assert(WeaponFollowMath.move_target(Vector2(82.0, 0.0)).is_equal_approx(Vector2(1.0, 0.0)), "yürüyüş hızı -> tam hücum")
	assert(WeaponFollowMath.move_target(Vector2(30.0, 0.0)).is_equal_approx(Vector2(0.5, 0.0)), "yavaş -> orantılı")


func test_spring_settles_and_kicks_back_when_stopping() -> void:
	var x := Vector2.ZERO
	var v := Vector2.ZERO
	for i in 120:
		var r: Array = WeaponFollowMath.spring_step(x, v, Vector2(1.0, 0.0), 11.0, WeaponFollowMath.SPRING_ZETA, 1.0 / 60.0)
		x = r[0]
		v = r[1]
	assert(x.distance_to(Vector2(1.0, 0.0)) < 0.01, "yürürken hedefe oturur: %s" % x)
	var min_x: float = 1.0
	for i in 120:
		var r2: Array = WeaponFollowMath.spring_step(x, v, Vector2.ZERO, 11.0, WeaponFollowMath.SPRING_ZETA, 1.0 / 60.0)
		x = r2[0]
		v = r2[1]
		min_x = minf(min_x, x.x)
	assert(min_x < -0.05, "durunca geri teper (fren): en az %f" % min_x)
	assert(absf(x.x) < 0.01, "sonra oturur")
	var big: Array = WeaponFollowMath.spring_step(Vector2.ZERO, Vector2.ZERO, Vector2(1.0, 0.0), 13.0, 0.45, 0.5)
	assert((big[0] as Vector2).length() < 3.0, "takılma karesinde patlamaz: %s" % str(big[0]))


func test_visibility_reveals_waits_out_the_grace_then_retracts() -> void:
	var st: Dictionary = {}
	WeaponFollowMath.step_visibility(st, false, false, 0.0, 1)
	assert(st["s"] == WeaponFollowMath.HIDDEN, "düşman yokken gizli")
	WeaponFollowMath.step_visibility(st, true, false, 1.0, 1)
	assert(st["s"] == WeaponFollowMath.REVEAL, "görünce çıkış")
	var end: float = 1.0 + WeaponFollowMath.reveal_stagger(1) + WeaponFollowMath.REVEAL_T
	WeaponFollowMath.step_visibility(st, true, false, end - 0.01, 1)
	assert(st["s"] == WeaponFollowMath.REVEAL, "çıkış sürüyor")
	WeaponFollowMath.step_visibility(st, true, false, end + 0.01, 1)
	assert(st["s"] == WeaponFollowMath.SHOWN, "çıkış bitti")
	WeaponFollowMath.step_visibility(st, false, false, end + 0.3, 1)
	assert(st["s"] == WeaponFollowMath.SHOWN, "HIDE_GRACE dolmadan çekilmez (kenarda gidip gelen yaratık titretmesin)")
	var t_ret: float = end + 0.01 + WeaponFollowMath.HIDE_GRACE + 0.01
	WeaponFollowMath.step_visibility(st, false, false, t_ret, 1)
	assert(st["s"] == WeaponFollowMath.RETRACT, "grace sonunda içe çekilir")
	WeaponFollowMath.step_visibility(st, false, false, t_ret + WeaponFollowMath.RETRACT_T + 0.2, 1)
	assert(st["s"] == WeaponFollowMath.HIDDEN, "çekilme bitti")
	WeaponFollowMath.step_visibility(st, false, true, t_ret + 2.0, 1)
	assert(st["s"] == WeaponFollowMath.SHOWN, "başka sistem yönetiyorsa (kubbe/ölüm) doğrudan görünür")


func test_reveal_and_retract_poses_start_and_end_in_the_right_place() -> void:
	var home := Vector2(62.0, -70.0)
	var st: Dictionary = {"s": WeaponFollowMath.REVEAL, "t": 0.0}
	var p0: Dictionary = WeaponFollowMath.pose(st, WeaponFollowMath.reveal_stagger(1) + 0.001, 1, home)
	assert((p0["pos"] as Vector2).distance_to(WeaponFollowMath.CHEST) < 2.0 and float(p0["scale"]) < 0.3, "göğüsten küçük çıkar")
	assert(absf(float(p0["spin"])) > 6.0, "başta ~1 tur dönüş payı")
	var p1: Dictionary = WeaponFollowMath.pose(st, WeaponFollowMath.reveal_stagger(1) + WeaponFollowMath.REVEAL_T, 1, home)
	assert((p1["pos"] as Vector2).is_equal_approx(home) and is_equal_approx(float(p1["scale"]), 1.0) and absf(float(p1["spin"])) < 0.001,
			"çıkış sonu: yerinde, tam boy, dönmüyor")
	var pl: Dictionary = WeaponFollowMath.pose({"s": WeaponFollowMath.REVEAL, "t": 0.0}, 0.2, 2, Vector2(-62.0, -70.0))
	assert(float(pl["spin"]) < 0.0, "sol silah ters yöne döner")
	var r: Dictionary = WeaponFollowMath.pose({"s": WeaponFollowMath.RETRACT, "t": 0.0}, 1.0, 0, Vector2(0.0, -125.0))
	assert((r["pos"] as Vector2).distance_to(WeaponFollowMath.CHEST) < 0.5 and is_zero_approx(float(r["alpha"])), "çekilme sonu: göğüste, görünmez")
	var h: Dictionary = WeaponFollowMath.pose({"s": WeaponFollowMath.HIDDEN}, 5.0, 0, Vector2(0.0, -125.0))
	assert((h["pos"] as Vector2).is_equal_approx(Vector2(0.0, -125.0)) and is_zero_approx(float(h["alpha"])),
			"gizli silah yerinde bekler (atış/menzil merkezi değişmez)")


func test_facing_rule_and_mirror_match_the_old_aim_formula() -> void:
	var fwd: float = 0.0
	var right: Array = WeaponFollowMath.face_rotation(Vector2(1.0, 0.0), fwd, true)
	assert(not right[1] and is_equal_approx(float(right[0]), 0.0), "sağa: aynasız 0")
	var left: Array = WeaponFollowMath.face_rotation(Vector2(-1.0, 0.0), fwd, true)
	assert(left[1] and is_equal_approx(wrapf(float(left[0]), -PI, PI), 0.0), "sola: aynalı, açı PI - PI = 0")
	var staff: Array = WeaponFollowMath.face_rotation(Vector2(0.0, -1.0), deg_to_rad(-45.0), false)
	assert(is_equal_approx(float(staff[0]), -PI / 2.0 + PI / 4.0), "çapraz sanat (-45) yukarı bakar")
	assert(WeaponFollowMath.idle_facing_dir(Vector2(-80.0, 0.0), Vector2(1.0, 0.0)).is_equal_approx(Vector2(-1.0, 0.0)),
			"yürürken gidiş yönü (görüşteki düşman arkada olsa da)")
	assert(WeaponFollowMath.idle_facing_dir(Vector2.ZERO, Vector2(0.0, 5.0)).is_equal_approx(Vector2(0.0, 1.0)), "dururken düşmana (hazır)")
	assert(WeaponFollowMath.idle_facing_dir(Vector2.ZERO, Vector2.ZERO) == Vector2.ZERO, "ikisi de yoksa son açısında kalır")
	assert(WeaponFollowMath.has_glint(5) and not WeaponFollowMath.has_glint(4), "uç parıltısı sadece en üst kademe")


func test_scan_sees_only_enemies_inside_the_own_vision_ellipse() -> void:
	var o: FakeOwner = _make_owner(Vector2(5000.0, 5000.0))
	var sc: Dictionary = WeaponFollowMath.scan(o)
	assert(not sc["seen"], "düşman yok")
	o.remove_meta(WeaponFollowMath.META_SCAN)
	var far: FakeEnemy = _make_enemy(Vector2(5000.0 + 340.0, 5000.0 + 200.0)) ## elipsin dışında (350 x 250)
	sc = WeaponFollowMath.scan(o)
	assert(not sc["seen"], "elips dışı görülmez")
	o.remove_meta(WeaponFollowMath.META_SCAN)
	var near: FakeEnemy = _make_enemy(Vector2(5000.0 + 300.0, 5000.0)) ## yatayda 350'ye kadar görülür
	sc = WeaponFollowMath.scan(o)
	assert(sc["seen"] and (sc["focus"] as Vector2).is_equal_approx(near.global_position), "elips içi görülür, en yakın odak")
	near.is_dead = true
	o.remove_meta(WeaponFollowMath.META_SCAN)
	assert(not WeaponFollowMath.scan(o)["seen"], "ölü sayılmaz")
	far.free()
	_cleanup()


## ---------- yerel silah ----------
func test_local_weapon_hides_without_enemies_and_bursts_out_when_one_is_seen() -> void:
	var o: FakeOwner = _make_owner(Vector2(6000.0, 6000.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	await _frames(4)
	assert(w.modulate.a < 0.01, "görüşte düşman yok -> görünmez: %f" % w.modulate.a)
	var sh: CanvasItem = w.get("shadow_sprite")
	assert(sh == null or sh.modulate.a < 0.01, "gölgesi de")
	_make_enemy(o.global_position + Vector2(300.0, 0.0)) ## görüşte ama Tabanca menzili (210) dışında
	await _wait(0.2)
	assert(int((w.get("_wf_vis") as Dictionary)["s"]) == WeaponFollowMath.REVEAL, "görünce çıkış başladı")
	await _wait(0.6)
	assert(w.modulate.a > 0.99 and is_equal_approx(w.rotation, 0.0), "çıkış bitti: görünür, kök dönmüyor")
	var home: Vector2 = o.global_position + (w.get("_target_local_offset") as Vector2) * 0.5
	assert(w.global_position.distance_to(home) < 3.0, "dururken slotunda: %s / %s" % [w.global_position, home])
	## hazır: dururken ucu görüşteki düşmana (Tabanca sağa -> aynasız, ~0 rad)
	await _wait(0.4)
	var icon: Sprite2D = w.get("icon_sprite")
	assert(not icon.flip_h and absf(wrapf(icon.rotation, -PI, PI)) < 0.3, "hazır: düşmana bakar (%f)" % icon.rotation)
	## sola yürü: menzilde hedef yok -> uç gidiş yönüne (aynalı), silah öne (sola) çıkar
	for i in 50:
		o.global_position += Vector2(-82.0 / 60.0, 0.0)
		await get_tree().physics_frame
	await get_tree().process_frame
	assert(icon.flip_h, "sola koşarken Tabanca aynalı (namlu gidiş yönüne)")
	var home2: Vector2 = o.global_position + (w.get("_target_local_offset") as Vector2) * 0.5
	assert(w.global_position.x < home2.x - 3.0, "hücum: silah gidiş yönüne öne çıkar (%f < %f)" % [w.global_position.x, home2.x])
	_cleanup()


## Silahların arkasında iz / ardıl görüntü YOK (kullanıcı 2026-10-18: "silahların arkasından gelen izi kaldır", madde 255): yürürken
## ve çok hızlı koşarken bile silah kökünde ikon + gölge dışında görünür sprite olmaz.
func test_fast_running_leaves_no_trail_behind_weapons() -> void:
	var o: FakeOwner = _make_owner(Vector2(7000.0, 7000.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	_make_enemy(o.global_position + Vector2(0.0, 240.0)) ## görüşte ama Tabanca menzili (210) dışında -> silah görünür, ateş etmez
	await _wait(0.8)
	var icon: Node = w.get("icon_sprite")
	var shadow: Node = w.get("shadow_sprite")
	assert(w.modulate.a > 0.99, "silah çıkmış olmalı (yoksa test bir şey ölçmez): %f" % w.modulate.a)
	for speed: float in [82.0, 220.0]:
		for i in 40:
			o.global_position += Vector2(speed / 60.0, 0.0)
			await get_tree().physics_frame
		await get_tree().process_frame
		for c in w.get_children():
			if c == icon or c == shadow or not (c is Sprite2D or c is AnimatedSprite2D):
				continue
			assert(not (c as CanvasItem).visible, "%.0f px/sn koşarken silahın arkasında iz sprite'ı olmamalı: %s" % [speed, c.name])
	_cleanup()


func test_tip_glint_only_on_top_tier() -> void:
	var o: FakeOwner = _make_owner(Vector2(8000.0, 8000.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	await _frames(2)
	_make_enemy(o.global_position + Vector2(260.0, 0.0))
	await _wait(0.7)
	var glints: int = 0
	for c in w.get_children():
		if c.get_script() == FollowFx.GlintScript:
			glints += 1
	assert(glints == 0, "kademe 1: çıkışta parıltı yok")
	_cleanup()
	var o2: FakeOwner = _make_owner(Vector2(9000.0, 9000.0))
	var w2: Node2D = TabancaScene.instantiate()
	o2.add_child(w2)
	w2.set("enchant_glow_tier", 5)
	await _frames(2)
	_make_enemy(o2.global_position + Vector2(260.0, 0.0))
	var seen_glint: bool = false
	for i in 50:
		await get_tree().physics_frame
		for c in w2.get_children():
			if c.get_script() == FollowFx.GlintScript:
				seen_glint = true
	assert(seen_glint, "kademe 5: çıkışın sonunda uçta parıltı")
	_cleanup()


## ---------- uzak kukla ----------
func test_puppet_icons_ride_pivots_and_hide_without_enemies() -> void:
	var puppet: Node2D = RemotePlayerScene.instantiate() as Node2D
	add_child(puppet)
	_track(puppet)
	puppet.setup(78, 5, "Dost")
	puppet.call("snap_to_network_position", Vector2(10000.0, 10000.0)) ## ağ hedefi de burası (yoksa kukla 0,0'a kayar)
	puppet.call("update_weapon_visuals", ["tabanca", "uzunkilic"])
	var icons: Array = puppet.get("_weapon_icons")
	var pivots: Array = puppet.get("_wf_pivots")
	assert(icons.size() == 2 and pivots.size() == 2, "ikon başına pivot")
	assert((icons[0] as Node).get_parent() == pivots[0], "ikon pivotun çocuğu")
	assert((icons[0] as Node2D).position.is_equal_approx(puppet.WEAPON_ICON_SLOTS[0]), "ikon kendi konumu slot tabanlı kalır")
	await _frames(4)
	assert((pivots[0] as CanvasItem).modulate.a < 0.01, "kuklada da düşman yokken gizli")
	_make_enemy(puppet.global_position + Vector2(300.0, 0.0))
	await _wait(0.8)
	assert((pivots[0] as CanvasItem).modulate.a > 0.99, "görünce çıktı")
	var slot: Vector2 = puppet.WEAPON_ICON_SLOTS[0]
	var expect: Vector2 = puppet.to_global(slot)
	assert((icons[0] as Node2D).global_position.distance_to(expect) < 3.0, "dururken slotunda: %s / %s" % [(icons[0] as Node2D).global_position, expect])
	puppet.set("is_dead", true)
	await _frames(2)
	assert((pivots[0] as Node2D).transform.is_equal_approx(Transform2D.IDENTITY), "ölünce pivot kimlik (ölüm düşüşü ikonu yönetir)")
	_cleanup()
