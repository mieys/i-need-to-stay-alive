extends Node

## Şovalye kubbesi silah halkası (2026-10-14): kubbenin içindeki herkesin silahları kubbede toplanıp oradan ateş eder
## (dome_weapon_ring.gd + weapon.gd set_rim_target + remote_player.gd set_dome_rim_targets). 2026-10-17: dış kenar yerine kubbe
## TEPESİNDEKİ eşit aralıklı taç dairesi; hedef arama merkezi eski kenar halkası (aim_point).

const WeaponScene: PackedScene = preload("res://scenes/weapon_tabanca.tscn")
const RingScript: GDScript = preload("res://scripts/dome_weapon_ring.gd")
const DomeScript: GDScript = preload("res://scripts/paladin_dome.gd")

var _spawned: Array[Node] = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Yerel oyuncu taklidi: kubbe sahibi + silah sahibi. Yönetici sadece bu üyelere bakar.
class FakeLocal extends Node2D:
	var is_dead: bool = false
	var paladin_zone_active: bool = true
	var paladin_zone_radius: float = 126.0
	var owned_weapon_nodes: Array = []

	func dome_rim_blocked() -> bool:
		return is_dead


class FakeRemote extends Node2D:
	var is_dead: bool = false
	var paladin_zone_active: bool = false
	var paladin_zone_radius: float = 126.0
	var peer_id: int = 5
	var _weapon_icons: Array[Node2D] = []
	var got: Array = []
	var got_spin: Array = []
	var got_aims: Array = []
	var talon_salvo: bool = false

	func dome_rim_blocked() -> bool:
		return is_dead

	func set_dome_rim_targets(targets: Array, spin_angles: Array = [], aims: Array = [], _fronts: Array = []) -> void:
		got = targets
		got_spin = spin_angles
		got_aims = aims

	func is_talon_salvo() -> bool:
		return talon_salvo

	func has_evo(_id: String) -> bool:
		return false


func _make_local(pos: Vector2) -> FakeLocal:
	var p := FakeLocal.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_track(p)
	var w: Node2D = WeaponScene.instantiate()
	p.add_child(w)
	p.owned_weapon_nodes = [w]
	return p


## 2026-10-19: taç (madde 218) yerine yine kubbe KENARI - görünür nokta = hedef arama noktası (aim_point), arka yarı kabuğun arkasında.
func test_rim_points_sit_on_the_dome_edge_like_before() -> void:
	var c := Vector2(100.0, 50.0)
	var r: float = 126.0
	for count: int in [1, 3, 6, 12]:
		for i in range(count):
			var p: Vector2 = RingScript.rim_point(c, r, i, count)
			assert(p.is_equal_approx(RingScript.aim_point(c, r, i, count)), "görünür nokta = kenar halkası (%d/%d)" % [i, count])
			assert(not DomeScript.contains(c, r, p), "zemin elipsinin dışında (boğuk ses yolu): %s" % str(p))
	assert(RingScript.rim_point(c, r, 0, 4).y < c.y and not RingScript.rim_in_front(c, RingScript.rim_point(c, r, 0, 4)), "ilk nokta kuzeyde, kabuğun arkasında")
	assert(RingScript.rim_in_front(c, RingScript.rim_point(c, r, 2, 4)), "güneydeki nokta kabuğun önünde")
	var right: Vector2 = RingScript.rim_point(c, r, 1, 4)
	assert(right.x > c.x, "saat yönünde ikinci nokta sağda: %s" % str(right))
	## Hedef arama noktası eski kenar halkası: kubbe elipsi + RIM_GAP, RIM_LIFT yukarıda.
	var rr: Vector2 = DomeScript.radii(r) + Vector2(RingScript.RIM_GAP, RingScript.RIM_GAP)
	for i in range(8):
		var q: Vector2 = RingScript.aim_point(c, r, i, 8) - c + Vector2(0.0, RingScript.RIM_LIFT)
		assert(is_equal_approx((q.x / rr.x) * (q.x / rr.x) + (q.y / rr.y) * (q.y / rr.y), 1.0), "hedef noktası kenar elipsinde: %d" % i)


func test_weapon_glides_to_the_rim_fires_from_there_and_returns() -> void:
	var p: FakeLocal = _make_local(Vector2(500.0, 500.0))
	var w: Node2D = p.owned_weapon_nodes[0]
	var rim := Vector2(500.0, 500.0 + 126.0 + RingScript.RIM_GAP) ## aşağıda: kafa slotundan uzak
	for i in range(3):
		await get_tree().physics_frame
	assert(not w.call("is_on_dome_rim"), "başta halkada değil")
	var aim := Vector2(500.0, 560.0)
	w.call("set_rim_target", rim, aim)
	for i in range(90):
		await get_tree().physics_frame
	assert(w.global_position.distance_to(rim) < 6.0, "silah halka noktasına indi: %s" % str(w.global_position))
	assert(w.call("is_on_dome_rim"), "halkada")
	assert((w.call("_attack_origin") as Vector2).is_equal_approx(aim), "taçtaki silah hedefi kenar halkasındaki noktasından arar")
	assert(not w.z_as_relative and w.z_index == int(w.get("RIM_Z_INDEX")), "ön yarıdaki silah kubbenin ön kabuğunun üstünde çizilir")
	w.call("set_rim_target", rim, aim, false)
	await get_tree().physics_frame
	assert(not w.z_as_relative and w.z_index == int(w.get("RIM_BACK_Z_INDEX")), "arka yarıdaki silah kabuğun altında")
	w.call("set_rim_target", rim)
	await get_tree().physics_frame
	assert((w.call("_attack_origin") as Vector2).is_equal_approx(w.global_position), "hedef noktası verilmezse kendi konumu")
	w.call("set_rim_target", null)
	for i in range(90):
		await get_tree().physics_frame
	assert(not w.call("is_on_dome_rim"), "kubbeden çıkınca halka bitti")
	assert(w.z_as_relative and w.z_index == 0, "çıkınca çizim sırası eski haline döner")
	assert(w.global_position.distance_to(rim) > 40.0, "silah halkadan ayrılıp slotuna döndü: %s" % str(w.global_position))
	assert(w.global_position.distance_to(p.global_position) < 200.0, "oyuncunun yanına geri geldi")
	_cleanup()


func test_manager_lines_up_every_weapon_inside_and_ignores_outsiders() -> void:
	var p: FakeLocal = _make_local(Vector2(0.0, 0.0))
	var w: Node2D = p.owned_weapon_nodes[0]
	var inside := FakeRemote.new()
	inside.add_to_group("remote_players")
	add_child(inside)
	inside.global_position = Vector2(40.0, 0.0)
	_track(inside)
	inside._weapon_icons.append(_track(Node2D.new()) as Node2D)
	inside._weapon_icons.append(_track(Node2D.new()) as Node2D)
	add_child(inside._weapon_icons[0])
	add_child(inside._weapon_icons[1])
	var outsider := FakeRemote.new()
	outsider.peer_id = 9
	outsider.add_to_group("remote_players")
	add_child(outsider)
	outsider.global_position = Vector2(400.0, 0.0)
	_track(outsider)
	outsider._weapon_icons.append(_track(Node2D.new()) as Node2D)
	add_child(outsider._weapon_icons[0])
	var ring: Node = _track(RingScript.new())
	add_child(ring)
	ring._physics_process(0.016)
	## 3 silah (yerel 1 + kukla 2): tepe, sağ-alt, sol-alt
	assert(bool(w.get("_rim_active")), "yerel silah halkaya atandı")
	var total: int = 3
	assert((w.get("_rim_world_pos") as Vector2).is_equal_approx(RingScript.rim_point(p.global_position, 126.0, 0, total)), "yerel (peer 1) ilk sırada")
	assert(inside.got.size() == 2, "kuklanın iki silahı da halkada: %d" % inside.got.size())
	assert((inside.got[0] as Vector2).is_equal_approx(RingScript.rim_point(p.global_position, 126.0, 1, total)), "kukla silah 1 ikinci nokta")
	assert((inside.got[1] as Vector2).is_equal_approx(RingScript.rim_point(p.global_position, 126.0, 2, total)), "kukla silah 2 üçüncü nokta")
	assert((w.get("_rim_aim_pos") as Vector2).is_equal_approx(RingScript.aim_point(p.global_position, 126.0, 0, total)), "yerel silahın hedef noktası")
	assert(inside.got_aims.size() == 2 and (inside.got_aims[1] as Vector2).is_equal_approx(RingScript.aim_point(p.global_position, 126.0, 2, total)), "kuklaya da hedef noktaları gider")
	assert(outsider.got.is_empty(), "kubbenin dışındaki oyuncunun silahları halkaya girmez")
	## kukla kubbeden çıkınca silahı normal yerine döner; yerel silah yalnız kalınca halka tek nokta
	inside.global_position = Vector2(300.0, 0.0)
	ring._physics_process(0.016)
	assert(inside.got.is_empty(), "çıkan kuklanın halkası temizlendi")
	assert((w.get("_rim_world_pos") as Vector2).is_equal_approx(RingScript.rim_point(p.global_position, 126.0, 0, 1)), "tek silah tepede")
	## kubbe kapanınca yerel silah da halkayı bırakır
	p.paladin_zone_active = false
	ring._physics_process(0.016)
	assert(not bool(w.get("_rim_active")), "kubbe bitince silah halkadan çıktı")
	_cleanup()


func test_edge_hysteresis_keeps_a_player_on_the_rim_until_clearly_outside() -> void:
	var p: FakeLocal = _make_local(Vector2.ZERO)
	var guest := FakeRemote.new()
	guest.add_to_group("remote_players")
	add_child(guest)
	_track(guest)
	guest._weapon_icons.append(_track(Node2D.new()) as Node2D)
	add_child(guest._weapon_icons[0])
	var ring: Node = _track(RingScript.new())
	add_child(ring)
	## Elips (2026-10-14): yatay kenar 126, dikey 63
	guest.global_position = Vector2(0.0, 80.0) ## eski dairenin içi ama elipsin DIŞI
	ring._physics_process(0.016)
	assert(guest.got.is_empty(), "elipsin dışındaki oyuncu (eski dairenin içi) halkaya girmez")
	guest.global_position = Vector2(124.0, 0.0) ## yarıçapın hemen içi ama girme payının dışında
	ring._physics_process(0.016)
	assert(guest.got.is_empty(), "kenara yeni gelen girme payı dolmadan halkaya girmez")
	guest.global_position = Vector2(100.0, 0.0)
	ring._physics_process(0.016)
	assert(guest.got.size() == 1, "içeri girince halkada")
	guest.global_position = Vector2(135.0, 0.0) ## yarıçapı aşmış ama çıkış payı içinde
	ring._physics_process(0.016)
	assert(guest.got.size() == 1, "kenarda gidip gelirken halkada kalır")
	guest.global_position = Vector2(160.0, 0.0)
	ring._physics_process(0.016)
	assert(guest.got.is_empty(), "net biçimde dışarı çıkınca temizlenir")
	assert(p != null)
	_cleanup()


## Kubbe girdabı (2026-10-15): kubbedeki bir Talon E'deyken halkadaki HERKESİN silahı halkayla döner, dışa bakıp baktığı yöne ateş eder;
## saldırı hızı bonusu yarı (+%400 -> +%200 = 1/3 aralık); -%40 hasar cezası yalnız Talon'un kendi silahlarında (diğerlerinde YOK). Talon E bitince her şey normale döner.
func test_talon_salvo_in_the_dome_spins_every_rim_weapon_with_half_advantage() -> void:
	var p: FakeLocal = _make_local(Vector2.ZERO)
	var w: Node2D = p.owned_weapon_nodes[0]
	var talon := FakeRemote.new()
	talon.add_to_group("remote_players")
	add_child(talon)
	_track(talon)
	talon.global_position = Vector2(30.0, 0.0)
	talon._weapon_icons.append(_track(Node2D.new()) as Node2D)
	add_child(talon._weapon_icons[0])
	var ring: Node = _track(RingScript.new())
	add_child(ring)
	ring._physics_process(0.1)
	assert(not w.call("is_rim_spinning") and talon.got_spin.is_empty(), "Talon E yokken halka dönmez")
	talon.talon_salvo = true
	ring._physics_process(0.1)
	var offset: float = TalonFormationMath.advance_salvo_angle(0.0, 0.1, TalonFormationMath.DOME_SPIN_SPEED_MULT)
	assert(w.call("is_rim_spinning"), "yerel (Talon olmayan) oyuncunun silahı da girdapta")
	assert((w.get("_rim_world_pos") as Vector2).is_equal_approx(RingScript.rim_point(Vector2.ZERO, 126.0, 0, 2, offset)), "halka döndü")
	assert(is_equal_approx(float(w.get("_rim_spin_fire_mult")), 1.0 / 3.0), "saldırı hızı bonusu yarıya: +%%200 (%f)" % float(w.get("_rim_spin_fire_mult")))
	assert(is_equal_approx(float(w.get("_rim_spin_penalty")), 0.0), "-%40 hasar cezası Talon olmayanın silahına işlemez")
	var spin_wait: float = float(w.call("_effective_fire_wait"))
	assert(talon.got_spin.size() == 1 and talon.got_spin[0] != null, "kuklanın ikonu da dışa bakış açısı aldı")
	assert(is_equal_approx(float(talon.got_spin[0]), RingScript.rim_outward_angle(126.0, 1, 2, offset)), "dışa bakış açısı halka noktasından")
	var icon: Node2D = w.get("icon_sprite")
	var pose: Dictionary = TalonFormationMath.compute_icon_pose(RingScript.rim_outward_angle(126.0, 0, 2, offset), deg_to_rad(float(w.get("sprite_forward_angle_deg"))), bool(w.get("mirror_icon_when_aiming_left")))
	assert(is_equal_approx(icon.rotation, float(pose["rotation"])), "silah ikonu dışa bakıyor")
	ring._physics_process(0.1)
	assert(not (w.get("_rim_world_pos") as Vector2).is_equal_approx(RingScript.rim_point(Vector2.ZERO, 126.0, 0, 2, offset)), "halka dönmeye devam ediyor")
	talon.talon_salvo = false
	ring._physics_process(0.1)
	assert(not w.call("is_rim_spinning") and is_equal_approx(float(w.get("_rim_spin_fire_mult")), 1.0), "E bitince girdap biter")
	assert(spin_wait < float(w.call("_effective_fire_wait")) * 0.5, "girdapta atış aralığı 1/3: %f / %f" % [spin_wait, float(w.call("_effective_fire_wait"))])
	assert(talon.got_spin.is_empty(), "kukla da normal nişana döner")
	assert((w.get("_rim_world_pos") as Vector2).is_equal_approx(RingScript.rim_point(Vector2.ZERO, 126.0, 0, 2)), "halka yerine döner")
	_cleanup()


func test_outward_angle_points_away_from_the_dome_center() -> void:
	assert(is_equal_approx(RingScript.rim_outward_angle(126.0, 0, 4), -PI * 0.5), "tepe: yukarı")
	assert(is_equal_approx(RingScript.rim_outward_angle(126.0, 1, 4), 0.0), "sağ: sağa")
	assert(is_equal_approx(absf(RingScript.rim_outward_angle(126.0, 3, 4)), PI), "sol: sola")
	var c := Vector2(10.0, 20.0)
	for i in range(6):
		var p: Vector2 = RingScript.rim_point(c, 126.0, i, 6, 0.4)
		var a: float = RingScript.rim_outward_angle(126.0, i, 6, 0.4)
		var q: Vector2 = p - c + Vector2(0.0, RingScript.RIM_LIFT)
		assert(q.dot(Vector2.from_angle(a)) > 0.0, "açı merkezden dışa: %d" % i)
