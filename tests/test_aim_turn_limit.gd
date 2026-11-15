extends Node

## Menzilli silah dönüş hızı sınırı (madde 549, kullanıcı "Kademe 2" 2026-11-10): hedef değişince ikon en çok
## WeaponFollowMath.AIM_MAX_TURN_DEG (300 derece/sn) ile döner, atış yönü hedefe düz kalır. Yerel weapon.gd + uzak kukla aynı matematik.

const TabancaScene: PackedScene = preload("res://scenes/weapon_tabanca.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")

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


## ---------- saf matematik ----------
func test_turn_angle_caps_the_step_and_matches_lerp_when_unlimited() -> void:
	var cap: float = deg_to_rad(5.0)
	assert(is_equal_approx(WeaponFollowMath.turn_angle(0.0, 2.0, 0.3, cap), cap), "büyük farkta adım sınıra kırpılır")
	assert(is_equal_approx(WeaponFollowMath.turn_angle(0.0, -2.0, 0.3, cap), -cap), "ters yönde de")
	assert(is_equal_approx(WeaponFollowMath.turn_angle(0.0, 0.1, 0.3, cap), 0.03), "küçük farkta bugünkü yumuşatma aynen (sınır devreye girmez)")
	for pair: Array in [[0.0, 2.0], [3.0, -3.0], [-1.0, 0.4]]:
		assert(is_equal_approx(WeaponFollowMath.turn_angle(pair[0], pair[1], 0.25, 0.0), lerp_angle(pair[0], pair[1], 0.25)),
				"max_step 0 = sınırsız = lerp_angle")
	## en kısa yoldan: 170 derece -> -170 derece 20 derecelik yay, sınır yönü doğru seçer
	var v: float = WeaponFollowMath.turn_angle(deg_to_rad(170.0), deg_to_rad(-170.0), 1.0, deg_to_rad(5.0))
	assert(is_equal_approx(v, deg_to_rad(175.0)), "sarma noktasında kısa yaydan döner: %f" % v)
	assert(WeaponFollowMath.AIM_MAX_TURN_DEG == 300.0, "Kademe 2 = 300 derece/sn")


func test_current_aim_is_the_inverse_of_face_rotation() -> void:
	for fwd_deg: float in [0.0, -13.5, -45.0, 30.0]:
		var fwd: float = deg_to_rad(fwd_deg)
		for mirror: bool in [false, true]:
			for step in 36:
				var angle: float = -PI + TAU * (float(step) + 0.37) / 36.0
				var r: Array = WeaponFollowMath.face_rotation(Vector2.from_angle(angle), fwd, mirror)
				var back: float = WeaponFollowMath.current_aim(float(r[0]), bool(r[1]), fwd)
				assert(absf(angle_difference(back, angle)) < 0.0001, "fwd=%s mirror=%s angle=%s -> %s" % [fwd_deg, mirror, angle, back])


## ---------- yerel silah: aynalanan ikon sınırı geçerken YÖN kesintisiz ----------
func test_mirrored_weapon_turns_through_the_flip_without_jumping() -> void:
	var o: FakeOwner = _make_owner(Vector2(20000.0, 20000.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	var icon: Sprite2D = w.get("icon_sprite")
	var fwd: float = deg_to_rad(float(w.get("sprite_forward_angle_deg")))
	assert(bool(w.get("mirror_icon_when_aiming_left")), "test kurulumu: Tabanca aynalanır")
	## sağa nişanlı başla
	w.call("_face_dir", Vector2.RIGHT, 1.0)
	assert(not icon.flip_h and absf(angle_difference(WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd), 0.0)) < 0.001,
			"başlangıç: sağa bakıyor, aynasız")
	var dt: float = 1.0 / 60.0
	var max_step: float = deg_to_rad(WeaponFollowMath.AIM_MAX_TURN_DEG) * dt
	var target: Vector2 = Vector2.from_angle(deg_to_rad(172.0)) ## neredeyse tam ters (sola, hafif aşağı)
	var prev: float = WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd)
	var flips: int = 0
	var last_flip: bool = icon.flip_h
	var steps: int = 0
	var worst: float = 0.0
	while steps < 240:
		w.call("_face_dir", target, clampf(dt * 12.0, 0.0, 1.0), max_step)
		var cur: float = WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd)
		worst = maxf(worst, absf(angle_difference(prev, cur)))
		prev = cur
		if icon.flip_h != last_flip:
			flips += 1
			last_flip = icon.flip_h
		steps += 1
		if absf(angle_difference(cur, target.angle())) < deg_to_rad(2.0):
			break
	assert(worst <= max_step + 0.0001, "hiçbir karede sınırdan fazla dönmez / dönüş hedefe ATLAMAZ (aynalama dahil): %f > %f" % [worst, max_step])
	assert(flips == 1, "sağdan sola geçerken ikon tam bir kez aynalanır: %d" % flips)
	assert(icon.flip_h, "sonunda sola bakan aynalı")
	assert(steps >= 25, "172 derece 300 derece/sn ile ~0,5 sn: %d kare" % steps)
	assert(steps < 120, "yine de hedefe varır (takılmaz): %d kare" % steps)
	_cleanup()


## ---------- yerel silah: _update_aim sınırı verir, Talon E dizilimi (mermi ikonun baktığı yöne) vermez ----------
func test_update_aim_limits_the_turn_except_when_the_shot_follows_the_icon() -> void:
	var o: FakeOwner = _make_owner(Vector2(21000.0, 21000.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	var icon: Sprite2D = w.get("icon_sprite")
	var fwd: float = deg_to_rad(float(w.get("sprite_forward_angle_deg")))
	var foe: FakeEnemy = _make_enemy(w.global_position + Vector2(90.0, 0.0))
	w.call("_face_dir", Vector2.RIGHT, 1.0)
	var dt: float = 1.0 / 60.0
	assert(bool(w.call("_update_aim", dt)), "test kurulumu: düşman menzilde, hedef bulundu")
	foe.is_dead = true
	foe.remove_from_group("enemies")
	var foe2: FakeEnemy = _make_enemy(w.global_position + Vector2(-90.0, 0.0)) ## 180 derece öteye
	var prev: float = WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd)
	var total: float = 0.0
	var worst: float = 0.0
	for i in 12: ## 0,2 sn
		assert(bool(w.call("_update_aim", dt)), "yeni hedef bulundu")
		var cur: float = WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd)
		worst = maxf(worst, absf(angle_difference(prev, cur)))
		total += absf(angle_difference(prev, cur))
		prev = cur
	var cap: float = deg_to_rad(WeaponFollowMath.AIM_MAX_TURN_DEG) * dt
	assert(worst <= cap + 0.0001, "kare başına dönüş sınırı aşılmadı: %f > %f" % [worst, cap])
	assert(total < deg_to_rad(65.0), "0,2 sn'de en çok ~60 derece döndü (eskiden ~150): %f derece" % rad_to_deg(total))
	assert(total > deg_to_rad(40.0), "ama gerçekten dönüyor: %f derece" % rad_to_deg(total))
	for i in 120: ## 2 sn daha: hedefe varır
		w.call("_update_aim", dt)
	var want: float = (foe2.global_position - w.global_position).angle()
	assert(absf(angle_difference(WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd), want)) < deg_to_rad(3.0), "yeni hedefe vardı")
	## Talon E dizilimi: mermi ikonun BAKTIĞI yöne gider -> sınır yok (ıskalamasın), eski hızlı yumuşatma
	w.set("fire_in_facing_direction", true)
	foe2.is_dead = true
	foe2.remove_from_group("enemies")
	var foe3: FakeEnemy = _make_enemy(w.global_position + Vector2(90.0, 0.0))
	prev = WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd)
	w.call("_update_aim", dt)
	var one: float = absf(angle_difference(prev, WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd)))
	assert(one > cap + 0.01, "fire_in_facing_direction: sınırsız (bugünkü) dönüş: %f > %f" % [one, cap])
	foe3.is_dead = true
	_cleanup()


## ---------- atış yönü: mermi namlunun BAKTIĞI yönden çıkar (madde 549 ek) ----------
func test_shot_dir_snaps_to_the_target_inside_the_tolerance_and_wastes_outside_it() -> void:
	var tol: float = deg_to_rad(WeaponFollowMath.AIM_SHOT_TOLERANCE_DEG)
	var facing: Vector2 = Vector2.from_angle(deg_to_rad(10.0))
	var near: Vector2 = Vector2.from_angle(deg_to_rad(13.0)) ## fark 3 derece < tolerans: tam hedefe
	assert(WeaponFollowMath.shot_dir(facing, near, tol).is_equal_approx(near), "yakalamış nişan ıskalamaz")
	var far: Vector2 = Vector2.from_angle(deg_to_rad(100.0))
	var wasted: Vector2 = WeaponFollowMath.shot_dir(facing, far, tol)
	assert(is_equal_approx(rad_to_deg(wasted.angle()), 16.0), "uzak hedef: namlunun baktığı yönden yalnız tolerans kadar sapar: %f" % rad_to_deg(wasted.angle()))
	var far_neg: Vector2 = Vector2.from_angle(deg_to_rad(-100.0))
	assert(is_equal_approx(rad_to_deg(WeaponFollowMath.shot_dir(facing, far_neg, tol).angle()), 4.0), "ters yönde de (hedefe doğru sapar)")
	assert(WeaponFollowMath.shot_dir(Vector2.ZERO, near, tol).is_equal_approx(near), "yön yoksa hedefe")


func _shot_dirs(w: Node2D) -> Array:
	var dirs: Array = []
	w.connect("fired", func(d: Vector2) -> void: dirs.append(d))
	return dirs


func test_shot_leaves_along_the_barrel_while_the_icon_is_still_turning() -> void:
	var scene_root: Node = get_tree().current_scene
	var before: int = scene_root.get_child_count() if scene_root != null else 0
	var o := Node2D.new()
	add_child(o)
	_track(o)
	o.global_position = Vector2(24000.0, 24000.0)
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	var foe: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(foe)
	foe.global_position = w.global_position + Vector2(100.0, 0.0)
	var dirs: Array = _shot_dirs(w)
	var dt: float = 1.0 / 60.0
	w.call("_face_dir", Vector2.RIGHT, 1.0)
	assert(bool(w.call("_update_aim", dt)), "test kurulumu: düşman menzilde")
	w.call("_fire_at", foe)
	var to_foe: Vector2 = (foe.global_position - w.global_position).normalized()
	assert(dirs.size() == 1 and (dirs[0] as Vector2).is_equal_approx(to_foe), "nişan oturmuşken atış tam hedefe: %s" % [dirs])
	## hedef 180 derece öteye geçer: ikon yavaş döner, bu arada ateş sürer ama mermi namlunun yönünden çıkar (boşa)
	foe.global_position = w.global_position + Vector2(-100.0, 0.0)
	for i in 3: ## 0,05 sn: ~15 derece
		w.call("_update_aim", dt)
	var to_foe2: Vector2 = (foe.global_position - w.global_position).normalized()
	w.call("_fire_at", foe)
	assert(dirs.size() == 2, "dönerken de ateş eder")
	var shot: Vector2 = dirs[1]
	var fwd: float = deg_to_rad(float(w.get("sprite_forward_angle_deg")))
	var icon: Sprite2D = w.get("icon_sprite")
	var barrel: Vector2 = Vector2.from_angle(WeaponFollowMath.current_aim(icon.rotation, icon.flip_h, fwd))
	assert(absf(shot.angle_to(to_foe2)) > deg_to_rad(120.0), "mermi hedefe gitmiyor, boşa gider: hedefle %f derece" % rad_to_deg(absf(shot.angle_to(to_foe2))))
	assert(absf(shot.angle_to(barrel)) <= deg_to_rad(WeaponFollowMath.AIM_SHOT_TOLERANCE_DEG) + deg_to_rad(8.0),
			"mermi namlunun baktığı yönden çıkar (geri tepme payı dahil): %f derece" % rad_to_deg(absf(shot.angle_to(barrel))))
	## ikon hedefe varınca atış yine tam isabet
	for i in 120:
		w.call("_update_aim", dt)
	w.call("_fire_at", foe)
	assert(dirs.size() == 3 and (dirs[2] as Vector2).is_equal_approx(to_foe2), "ikon yetişince atış tam hedefe: %s" % [dirs[2]])
	## nişan bayatsa (bu karede _update_aim çalışmadı) eski kural: hedefe düz
	w.set("_aim_angle_msec", -100000)
	foe.global_position = w.global_position + Vector2(0.0, 90.0)
	w.call("_fire_at", foe)
	assert((dirs[3] as Vector2).is_equal_approx(Vector2.DOWN), "bayat nişan -> hedefe düz")
	## Talon E dizilimi (mermi zaten ikonun yönüne) ve sürekli ışın: atış yönü ikonla bağlanmaz
	assert(bool(w.call("_shot_follows_icon")), "normal menzilli silah ikonu izler")
	w.set("fire_in_facing_direction", true)
	assert(not bool(w.call("_shot_follows_icon")), "fire_in_facing_direction: eski yol")
	w.set("fire_in_facing_direction", false)
	## sürekli ışın (Yıldırım/Gökkuşağı, madde 549 ek 3): artık o da ikonu izler - ışın namlunun yönünde uzanır, dönüş sınırı ışına da geçer
	w.set("continuous_beam", true)
	assert(bool(w.call("_shot_follows_icon")), "sürekli ışın da ikonun yönünü izler")
	w.set("_aim_angle_msec", -100000)
	w.call("_face_dir", Vector2.RIGHT, 1.0)
	foe.global_position = w.global_position + Vector2(100.0, 0.0)
	w.call("_update_aim", dt)
	assert(int(w.get("_aim_angle_msec")) >= 0, "ışın silahında da temiz nişan açısı tutulur (dönüş sınırı geçerli)")
	w.set("continuous_beam", false)
	if scene_root != null:
		while scene_root.get_child_count() > before:
			scene_root.get_child(scene_root.get_child_count() - 1).free() ## atışların mermileri
	_cleanup()


func test_pellets_open_their_cone_around_the_barrel_direction() -> void:
	var scene_root: Node = get_tree().current_scene
	var before: int = scene_root.get_child_count() if scene_root != null else 0
	var o := Node2D.new()
	add_child(o)
	_track(o)
	o.global_position = Vector2(25000.0, 25000.0)
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	var foe: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(foe)
	foe.global_position = w.global_position + Vector2(100.0, 0.0)
	w.set("_last_shot_damage", 10.0)
	w.set("_last_shot_dir", Vector2.UP) ## asıl atış namlunun baktığı yöne (yukarı) çıkmıştı
	var n0: int = scene_root.get_child_count()
	w.call("fire_pellets", foe, [0.0])
	assert(scene_root.get_child_count() == n0 + 1, "saçma mermisi doğdu")
	var pellet: Node = scene_root.get_child(scene_root.get_child_count() - 1)
	assert((pellet.get("direction") as Vector2).is_equal_approx(Vector2.UP), "saçma, hedefe değil asıl atışın yönüne: %s" % [pellet.get("direction")])
	if scene_root != null:
		while scene_root.get_child_count() > before:
			scene_root.get_child(scene_root.get_child_count() - 1).free()
	_cleanup()


## ---------- uzak kukla: aynı sınır, aynı aynalama kuralı ----------
func test_puppet_wf_face_applies_the_same_cap() -> void:
	var puppet: Node2D = RemotePlayerScene.instantiate() as Node2D
	add_child(puppet)
	_track(puppet)
	puppet.setup(79, 5, "Dost")
	puppet.call("snap_to_network_position", Vector2(22000.0, 22000.0))
	puppet.call("update_weapon_visuals", ["tabanca", "fire_staff"])
	var icons: Array = puppet.get("_weapon_icons")
	var fwds: Array = puppet.get("_weapon_forward_angle_deg")
	var mirrors: Array = puppet.get("_weapon_mirror_aim")
	assert(icons.size() == 2, "iki ikon")
	var cap: float = deg_to_rad(5.0)
	for i in 2:
		var icon: Node2D = icons[i]
		var fwd: float = deg_to_rad(float(fwds[i]))
		puppet.call("_wf_face", i, icon, Vector2.RIGHT, 1.0) ## sağa nişanlı başla (sınırsız)
		var flipped0: bool = icon.get("flip_h") == true
		var a0: float = WeaponFollowMath.current_aim(icon.rotation, flipped0, fwd)
		assert(absf(angle_difference(a0, 0.0)) < 0.001, "başlangıç sağa bakıyor (silah %d)" % i)
		puppet.call("_wf_face", i, icon, Vector2.DOWN, 1.0, cap) ## t=1: sınırsız olsa tek karede 90 derece atlardı
		var a1: float = WeaponFollowMath.current_aim(icon.rotation, icon.get("flip_h") == true, fwd)
		assert(is_equal_approx(angle_difference(a0, a1), cap), "kukla silah %d: adım tam sınır (%f / %f)" % [i, angle_difference(a0, a1), cap])
	## aynalanan silah kuklada da sınırı geçerken sıçramaz
	var t: Node2D = icons[0]
	assert(bool(mirrors[0]), "test kurulumu: Tabanca kuklada aynalanır")
	var f0: float = deg_to_rad(float(fwds[0]))
	puppet.call("_wf_face", 0, t, Vector2.RIGHT, 1.0)
	var prev: float = WeaponFollowMath.current_aim(t.rotation, t.get("flip_h") == true, f0)
	var worst: float = 0.0
	var flips: int = 0
	var last: bool = t.get("flip_h") == true
	for i in 60:
		puppet.call("_wf_face", 0, t, Vector2.from_angle(deg_to_rad(176.0)), 0.2, cap)
		var cur: float = WeaponFollowMath.current_aim(t.rotation, t.get("flip_h") == true, f0)
		worst = maxf(worst, absf(angle_difference(prev, cur)))
		prev = cur
		if (t.get("flip_h") == true) != last:
			flips += 1
			last = t.get("flip_h") == true
	assert(worst <= cap + 0.0001, "kukla aynalamada atlamıyor: %f > %f" % [worst, cap])
	assert(flips == 1, "tam bir aynalama: %d" % flips)
	_cleanup()
