extends Node

## Ağaç görevi yeni hâli (2026-10-10): bkz. scripts/mission_tree.gd, mission_tree_bolt.gd, mission_van.gd, player.gd _block_movement_into_blockers.
## Büyüme -> aktif döngü, kademeye göre can/kalkan/vuruş (yaşayan yaratıklardan), kristal mermisi gerçek yaratığa hasar verir (istemci kopyası vermez),
## derinlik (oyuncu arkadayken ağaç üstte), "move_blockers" çarpışması, konvoy hızının oyuncu sayısıyla artması.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const TreeScript: GDScript = preload("res://scripts/mission_tree.gd")
const BoltScript: GDScript = preload("res://scripts/mission_tree_bolt.gd")
const BlastScript: GDScript = preload("res://scripts/mission_tree_blast.gd")
const VanScript: GDScript = preload("res://scripts/mission_van.gd")
const WEM: GDScript = preload("res://scripts/world_event_manager.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false


## Sihirli atış testleri için: hasarı ve itişi kaydeder (gerçek itiş C++ EnemyWorld'de, testte yok).
class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var max_health: float = 100.0
	var hits: Array = []
	var pushes: Array = []
	func take_damage(amount: float, _crit: bool = false, _pen: float = 0.0, _area: bool = false) -> void:
		hits.append(amount)
	func apply_skill_push(dir: Vector2, distance: float, _ult: bool = false) -> void:
		pushes.append([dir, distance])


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _enemy(pos: Vector2) -> Node2D:
	var e: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(e)
	e.global_position = pos
	return e


func _fake(pos: Vector2, boss: bool = false) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	e.add_to_group("mission_copies") ## C++ köprüsü varken EnemyQuery.candidates sadece kayıtlı yaratıkları + bu grubu döndürür
	if boss:
		e.is_boss = true
		e.add_to_group("boss")
	add_child(e)
	_track(e)
	e.global_position = pos
	return e


func _tree(pos: Vector2, simulated: bool = true) -> Node2D:
	var t: Node2D = _track(TreeScript.new()) as Node2D
	add_child(t)
	t.global_position = pos
	t.call("setup", 1, simulated)
	return t


func test_tree_grows_then_loops_active_art() -> void:
	var t: Node2D = _tree(Vector2(5000, 5000))
	var anim: AnimatedSprite2D = t.get("_anim")
	assert(anim.animation == &"grow" and anim.sprite_frames.get_frame_count(&"grow") == 3, "önce 3 karelik büyüme")
	assert(anim.sprite_frames.get_frame_count(&"active") == 6 and anim.sprite_frames.get_animation_loop(&"active"), "aktif hâl 6 kare döngü")
	assert(not anim.sprite_frames.get_animation_loop(&"grow"), "büyüme bir kez")
	await get_tree().create_timer(1.6).timeout
	assert(anim.animation == &"active", "büyüme bitince aktif döngü: %s" % anim.animation)
	_cleanup()


func test_stats_follow_the_living_creatures() -> void:
	var e1: Node2D = _enemy(Vector2(7000, 7000))
	var e2: Node2D = _enemy(Vector2(7100, 7000))
	await _frames(2)
	var hp: float = (float(e1.get("max_health")) + float(e2.get("max_health"))) * 0.5
	var dmg: float = (float(e1.get("contact_damage")) + float(e2.get("contact_damage"))) * 0.5
	var t: Node2D = _tree(Vector2(7050, 7400))
	assert(is_equal_approx(float(t.get("max_health")), dmg * TreeScript.HP_PER_ENEMY_HIT), "can = ort. yaratık hasarı x %d" % TreeScript.HP_PER_ENEMY_HIT)
	assert(is_equal_approx(float(t.get("max_shield")), dmg * TreeScript.SHIELD_PER_ENEMY_HIT), "kalkan ölçekli")
	assert(is_equal_approx(float(t.get("bolt_damage")), hp * TreeScript.BOLT_HP_RATIO), "kristal vuruşu = yaratık canının %%34'ü")
	## yaratık yokken eski sabitler
	e1.free(); e2.free()
	var t2: Node2D = _tree(Vector2(9000, 9000))
	assert(is_equal_approx(float(t2.get("max_health")), TreeScript.FALLBACK_MAX_HEALTH), "yaratık yoksa yedek can")
	_cleanup()


func test_crystal_bolt_damages_a_real_creature_and_client_copy_does_not() -> void:
	var e: Node2D = _enemy(Vector2(11000, 11000))
	await _frames(2)
	var hp0: float = float(e.get("health"))
	var b: Node2D = BoltScript.new()
	b.call("setup", e, 40.0)
	add_child(b)
	b.global_position = e.global_position + Vector2(-120, 0)
	await get_tree().create_timer(0.6).timeout
	assert(float(e.get("health")) < hp0, "host mermisi vurdu: %.1f -> %.1f" % [hp0, float(e.get("health"))])
	var hp1: float = float(e.get("health"))
	var c: Node2D = BoltScript.new()
	c.call("setup", e, 0.0)
	add_child(c)
	c.global_position = e.global_position + Vector2(-120, 0)
	await get_tree().create_timer(0.6).timeout
	assert(is_equal_approx(float(e.get("health")), hp1), "istemci (kozmetik) mermisi hasar vermez")
	_cleanup()


func test_tree_draws_over_a_player_behind_it_and_under_one_in_front() -> void:
	var t: Node2D = _tree(Vector2(13000, 13000))
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	_track(p)
	p.global_position = t.global_position + Vector2(10, -40)
	await _frames(2)
	assert(int((t.get("_anim") as Node2D).z_index) == 2, "oyuncu arkada: ağaç üstte")
	p.global_position = t.global_position + Vector2(10, 20)
	await _frames(2)
	assert(int((t.get("_anim") as Node2D).z_index) == 0, "oyuncu önde: ağaç altta")
	_cleanup()


func test_player_cannot_walk_into_the_trunk() -> void:
	var t: Node2D = _tree(Vector2(15000, 15000))
	assert(t.is_in_group("move_blockers"), "ağaç move_blockers grubunda")
	var pl: CharacterBody2D = _track(PlayerScene.instantiate()) as CharacterBody2D
	add_child(pl)
	pl.global_position = t.call("block_center") - Vector2(0.0, 12.75) + Vector2(-20, 0)
	pl.velocity = Vector2(200, 0)
	pl.call("_block_movement_into_blockers")
	assert(pl.velocity.x <= 0.01, "gövdeye doğru hız iptal: %s" % str(pl.velocity))
	pl.velocity = Vector2(-200, 0)
	pl.call("_block_movement_into_blockers")
	assert(pl.velocity.x < -199.0, "uzaklaşmak serbest")
	_cleanup()


func test_escort_speeds_up_noticeably_with_more_pushers() -> void:
	var one: float = 1.0
	var two: float = minf(WEM.ESCORT_MAX_SPEED_MULT, 1.0 + 1.0 * WEM.ESCORT_SPEED_PER_EXTRA_PLAYER)
	var four: float = minf(WEM.ESCORT_MAX_SPEED_MULT, 1.0 + 3.0 * WEM.ESCORT_SPEED_PER_EXTRA_PLAYER)
	assert(two >= one * 1.3 and four >= 2.0, "2 oyuncu >= x1,3, 4 oyuncu >= x2: %.2f / %.2f" % [two, four])
	var v: Node2D = _track(VanScript.new()) as Node2D
	add_child(v)
	assert(v.is_in_group("move_blockers") and v.has_method("block_center"), "konvoy arabası da engel")
	_cleanup()


func _fire_blast(target: Node2D, dmg: float, origin: Vector2) -> void:
	var b: Node2D = BlastScript.new()
	b.call("setup", target, dmg, origin)
	add_child(b)
	_track(b)
	b.global_position = target.global_position + Vector2(-100, -10)
	await get_tree().create_timer(BlastScript.CHARGE_TIME + 0.6).timeout


## 2026-10-18: sihirli atış - hedef + BLAST_RADIUS içindekiler hasar alır ve AĞAÇTAN DIŞA itilir; uzaktaki etkilenmez; istemci kopyası (hasar 0) hiçbir şey yapmaz.
func test_magic_blast_damages_area_and_pushes_away_from_tree() -> void:
	var tp := Vector2(17000, 17000)
	var e1: FakeEnemy = _fake(tp + Vector2(200, 0))
	var e2: FakeEnemy = _fake(tp + Vector2(230, 25))
	var e3: FakeEnemy = _fake(tp + Vector2(200, 220))
	await _fire_blast(e1, 40.0, tp)
	assert(e1.hits == [40.0], "hedef vuruldu: %s" % str(e1.hits))
	assert(e2.hits.size() == 1 and e2.pushes.size() == 1, "alan içindeki yan yaratık da")
	assert(e3.hits.is_empty() and e3.pushes.is_empty(), "alan dışı etkilenmez")
	var p: Array = e1.pushes[0]
	assert((p[0] as Vector2).x > 0.95 and is_equal_approx(float(p[1]), BlastScript.PUSH_DISTANCE), "ağaçtan dışa itiş: %s" % str(p))
	var c: FakeEnemy = _fake(tp + Vector2(-300, 0))
	await _fire_blast(c, 0.0, tp)
	assert(c.hits.is_empty() and c.pushes.is_empty(), "istemci (kozmetik) kopyası hasar/itiş uygulamaz")
	_cleanup()


func test_magic_blast_focuses_bosses_and_pushes_them() -> void:
	var t: Node2D = _tree(Vector2(19000, 19000), false) ## kozmetik: kendi atışları sahteleri itmesin
	var near: FakeEnemy = _fake(t.global_position + Vector2(90, 0))
	assert(t.call("pick_blast_target") == near, "boss yokken en yakın yaratık")
	var boss: FakeEnemy = _fake(t.global_position + Vector2(0, 460), true)
	assert(t.call("pick_blast_target") == boss, "boss varsa (daha uzakta olsa da) boss")
	boss.set_meta(&"untargetable", true)
	assert(t.call("pick_blast_target") == near, "vurulamaz boss (Yeraltı havuzu) seçilmez")
	boss.remove_meta(&"untargetable")
	await _fire_blast(boss, 40.0, t.global_position)
	assert(boss.pushes.size() == 1 and is_equal_approx(float(boss.pushes[0][1]), BlastScript.BOSS_PUSH_DISTANCE), "boss da itilir (C++ x0,4 öncesi büyük mesafe)")
	assert(((boss.pushes[0][0]) as Vector2).y > 0.95, "boss ağaçtan dışa")
	_cleanup()


## 2026-10-19 (madde 316): kristal atışta parlar - taş maskesi sayfadan çıkar, kristal mermisi atınca pulse, sihirli atışta şarj sonunda tam parlama.
func test_crystal_glows_when_the_tree_fires() -> void:
	var t: Node2D = _tree(Vector2(21000, 21000), false)
	var glow: Node2D = t.get("_glow")
	var masks: Array = glow.get("_masks")
	assert(masks.size() == TreeScript.ACTIVE_FRAMES, "her aktif kare için taş maskesi")
	var img: Image = (masks[0] as Texture2D).get_image()
	var lit: int = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				lit += 1
	assert(lit > 400 and lit < 1300, "maske sadece kristal taşı (~700 px): %d" % lit)
	await get_tree().create_timer(1.6).timeout
	assert(float(glow.get("intensity")) < 0.2, "atış yokken sadece hafif nefes")
	var e: FakeEnemy = _fake(t.global_position + Vector2(120, 0))
	t.call("_try_fire_at_nearest_enemy")
	await _frames(2)
	assert(float(glow.get("intensity")) > 0.45, "kristal mermisi atınca parlar: %.2f" % float(glow.get("intensity")))
	assert(bool(t.call("_try_fire_blast")), "sihirli atış hedef buldu")
	var peak: float = 0.0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await get_tree().process_frame
		peak = maxf(peak, float(glow.get("intensity")))
	assert(peak > 0.9, "şarj sonunda tam parlama: %.2f" % peak)
	e.is_dead = true
	_cleanup()
