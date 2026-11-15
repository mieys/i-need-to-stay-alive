extends Node

## Madde 672: Kalkan silahı "siper duruşu" - bakılan yönden gelen menzilli yaratık atışı TAMAMEN söner (hasar yok), arkadan/yandan gelen
## vurur, bayat (süresi dolmuş) koruma bloklamaz; menzilde düşman yokken üstüne gelen atış "tehdit" sayılır (kalkanın dönüp korunacağı yön).
## Geometri ve tehdit seçimi tek kaynak scripts/kalkan_guard.gd; gerçek mermi (enemy_projectile) fizik karelerinde sınanır.

const KalkanGuard := preload("res://scripts/kalkan_guard.gd")
const EnemyProjectileScene: PackedScene = preload("res://scenes/enemy_projectile.tscn")

## Ölçüt: tüm atış betikleri derlenip yüklenebiliyor (grup + hook eklenen 7 dosya).
const SHOT_SCRIPTS := [
	"res://scripts/enemy_projectile.gd", "res://scripts/enemy_fireball.gd", "res://scripts/enemy_bone.gd", "res://scripts/creature_shot.gd",
	"res://scripts/demon_fireball.gd", "res://scripts/boss_spell.gd", "res://scripts/worm_acid.gd",
]


class FakeBody extends CharacterBody2D:
	var hits: int = 0
	var last: float = 0.0

	func take_damage(amount: float, _source: Node = null) -> void:
		hits += 1
		last = amount


class FakeShot extends Node2D:
	var _dir: Vector2 = Vector2.RIGHT


var _spawned: Array = []


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func _make_body(pos: Vector2, group: String = "player") -> FakeBody:
	var b := FakeBody.new()
	b.collision_layer = 2
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	cs.shape = shape
	b.add_child(cs)
	b.add_to_group(group)
	add_child(b)
	b.global_position = pos
	_spawned.append(b)
	return b


func _fire(from: Vector2, dir: Vector2) -> Node2D:
	var p: Node2D = EnemyProjectileScene.instantiate()
	p.direction = dir
	p.damage = 7.0
	add_child(p)
	p.global_position = from
	_spawned.append(p)
	return p


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func test_all_shot_scripts_load() -> void:
	for path: String in SHOT_SCRIPTS:
		var s: Script = load(path) as Script
		assert(s != null and s.can_instantiate(), "atış betiği derlenemedi: " + path)


func test_sector_dir_matches_sector_of() -> void:
	const KalkanBashMath := preload("res://scripts/kalkan_bash_math.gd")
	for sector in range(8):
		assert(KalkanBashMath.sector_of(KalkanGuard.sector_dir(sector)) == sector, "sector_dir/sector_of tutarsız: %d" % sector)


func test_blocks_geometry() -> void:
	var body := _make_body(Vector2(100, 100))
	KalkanGuard.publish(body, Vector2.RIGHT)
	assert(KalkanGuard.blocks(body, Vector2(130, 100)), "önden, yarıçap içinden gelen atış bloklanmalı")
	assert(KalkanGuard.blocks(body, Vector2(100 + 30 * cos(deg_to_rad(60.0)), 100 + 30 * sin(deg_to_rad(60.0)))), "yay içindeki (60 derece) atış bloklanmalı")
	assert(not KalkanGuard.blocks(body, Vector2(70, 100)), "arkadan gelen atış bloklanmamalı")
	assert(not KalkanGuard.blocks(body, Vector2(100, 130)), "yandan (90 derece) gelen atış bloklanmamalı")
	assert(not KalkanGuard.blocks(body, Vector2(100 + KalkanGuard.RADIUS + 5.0, 100)), "yarıçap dışındaki atış bloklanmamalı")
	_cleanup()


func test_stale_or_missing_guard_does_not_block() -> void:
	var body := _make_body(Vector2.ZERO)
	assert(not KalkanGuard.blocks(body, Vector2(20, 0)), "koruma yayınlanmadıysa blok yok")
	body.set_meta(KalkanGuard.META, [Vector2.RIGHT, Time.get_ticks_msec() - 1])
	assert(not KalkanGuard.blocks(body, Vector2(20, 0)), "süresi dolan koruma bloklamamalı")
	KalkanGuard.publish(body, Vector2.RIGHT)
	assert(KalkanGuard.blocks(body, Vector2(20, 0)), "taze koruma bloklamalı")
	KalkanGuard.clear(body)
	assert(not KalkanGuard.blocks(body, Vector2(20, 0)), "clear sonrası blok yok")
	_cleanup()


## Madde 705: önden gelen atış DURMAZ, hasarı %30 azalmış vurur (bir kez); arkadan gelen tam vurur; Sağlam Siper (4. eleman) %50.
func test_real_projectile_from_front_is_reduced_from_behind_hits() -> void:
	var front := _make_body(Vector2(1000, 1000))
	front.set_meta(KalkanGuard.META, [Vector2.LEFT, Time.get_ticks_msec() + 60000]) ## kalkan sola bakıyor
	_fire(Vector2(900, 1000), Vector2.RIGHT) ## soldan geliyor -> kalkanın önü
	await _physics_frames(60)
	assert(front.hits == 1 and absf(front.last - 7.0 * (1.0 - KalkanGuard.DAMAGE_REDUCTION)) < 0.01, "önden gelen atış %%30 az vurmalı: %d / %s" % [front.hits, front.last])
	_cleanup()
	await get_tree().process_frame
	var strong := _make_body(Vector2(1500, 1000))
	strong.set_meta(KalkanGuard.META, [Vector2.LEFT, Time.get_ticks_msec() + 60000, Callable(), 0.5])
	_fire(Vector2(1400, 1000), Vector2.RIGHT)
	await _physics_frames(60)
	assert(strong.hits == 1 and absf(strong.last - 3.5) < 0.01, "Sağlam Siper %%50: %s" % strong.last)
	_cleanup() ## mermi yalnız İLK "player" grubu üyesini hedef alır (get_first_node_in_group) - ikinci gövde için ilki kalkmalı
	await get_tree().process_frame
	var back := _make_body(Vector2(2000, 1000))
	back.set_meta(KalkanGuard.META, [Vector2.RIGHT, Time.get_ticks_msec() + 60000]) ## kalkan sağa bakıyor
	_fire(Vector2(1900, 1000), Vector2.RIGHT) ## soldan geliyor -> kalkanın ARKASI
	await _physics_frames(60)
	assert(back.hits == 1 and absf(back.last - 7.0) < 0.01, "kalkanın arkasından gelen atış tam vurmalı: %d / %s" % [back.hits, back.last])
	_cleanup()


func test_remote_puppet_guard_reduces_authoritative_shot() -> void:
	var puppet := _make_body(Vector2(3000, 1000), "remote_players")
	puppet.set_meta(KalkanGuard.META, [Vector2.LEFT, Time.get_ticks_msec() + 60000])
	_fire(Vector2(2900, 1000), Vector2.RIGHT)
	await _physics_frames(60)
	assert(puppet.hits == 1 and absf(puppet.last - 7.0 * (1.0 - KalkanGuard.DAMAGE_REDUCTION)) < 0.01, "uzak kuklanın kalkanı da (host'ta) hasarı azaltmalı: %d / %s" % [puppet.hits, puppet.last])
	_cleanup()


func test_threat_dir_picks_incoming_shot_only() -> void:
	var body := _make_body(Vector2(0, 0))
	var coming := FakeShot.new()
	coming._dir = Vector2.LEFT ## sağdan bize geliyor
	coming.add_to_group(KalkanGuard.GROUP)
	add_child(coming)
	coming.global_position = Vector2(150, 0)
	_spawned.append(coming)
	var t: Vector2 = KalkanGuard.threat_dir(body)
	assert(t.distance_to(Vector2.RIGHT) < 0.01, "gelen atışın yönü sahibten atışa doğru olmalı: %s" % str(t))
	coming._dir = Vector2.RIGHT ## uzaklaşıyor
	assert(KalkanGuard.threat_dir(body) == Vector2.ZERO, "uzaklaşan atış tehdit sayılmamalı")
	coming._dir = Vector2.LEFT
	coming.global_position = Vector2(150, 80) ## 80 px yandan geçecek -> vurmaz
	assert(KalkanGuard.threat_dir(body) == Vector2.ZERO, "yan geçen atış tehdit sayılmamalı")
	coming.global_position = Vector2(KalkanGuard.THREAT_RANGE + 50.0, 0) ## çok uzak
	assert(KalkanGuard.threat_dir(body) == Vector2.ZERO, "menzil dışı atış tehdit sayılmamalı")
	_cleanup()


## ---------------------------------------------------------------- blok tepkisi + hizalama (madde 687)
const K := preload("res://scripts/kalkan_bash_math.gd")


class ReactProbe extends RefCounted:
	var got: Vector2 = Vector2.ZERO
	var calls: int = 0

	func on_block(to_shot: Vector2) -> void:
		got = to_shot
		calls += 1


func _region_x(icon: Sprite2D) -> float:
	return (icon.texture as AtlasTexture).region.position.x if icon.texture is AtlasTexture else -1.0


## Blok: yayınlanan tepki çağrılır (atışa doğru yönle); bloklanmayan atışta çağrılmaz; tepkisiz (eski 2 elemanlı) yayın çökmez.
func test_block_calls_react_with_direction_to_shot() -> void:
	var body := _make_body(Vector2(100, 100))
	var probe := ReactProbe.new()
	KalkanGuard.publish(body, Vector2.RIGHT, Callable(probe, "on_block"))
	assert(KalkanGuard.try_block(body, Vector2(130, 100)), "önden gelen atış bloklanmalı")
	assert(probe.calls == 1 and probe.got.distance_to(Vector2(30, 0)) < 0.01, "tepki atışa doğru yönle çağrılmalı: %s" % str(probe.got))
	assert(not KalkanGuard.try_block(body, Vector2(70, 100)), "arkadan gelen atış bloklanmaz")
	assert(probe.calls == 1, "bloklanmayan atış tepkiyi çağırmamalı")
	body.set_meta(KalkanGuard.META, [Vector2.RIGHT, Time.get_ticks_msec() + 60000]) ## eski biçim: tepki yok
	assert(KalkanGuard.try_block(body, Vector2(130, 100)), "tepkisiz yayında da blok çalışır")
	_cleanup()


## Geri tepme: ikon atıştan UZAĞA (yerel birimde dünya px / kök ölçeği) kayar + ezilir, sonra tam dinlenme konumuna/ölçeğine döner.
func test_recoil_kicks_away_from_the_shot_and_returns() -> void:
	var parent := Node2D.new()
	parent.scale = Vector2(0.5, 0.5)
	add_child(parent)
	var icon := Sprite2D.new()
	parent.add_child(icon)
	_spawned.append(parent)
	var tw: Tween = KalkanGuard.recoil(parent, icon, Vector2.RIGHT, Vector2.ZERO, Vector2.ONE) ## atış sağdan
	assert(tw != null and tw.is_valid(), "geri tepme tween'i")
	tw.pause()
	tw.custom_step(KalkanGuard.RECOIL_IN)
	assert(absf(icon.position.x - (-KalkanGuard.RECOIL_WORLD_PX / 0.5)) < 0.2 and absf(icon.position.y) < 0.01, "atışın tersine RECOIL_WORLD_PX / 0,5 yerel birim: %s" % str(icon.position))
	assert(absf(icon.scale.x - KalkanGuard.RECOIL_SQUASH) < 0.03, "tok ezilme: %s" % str(icon.scale))
	assert(icon.self_modulate.r > 1.2, "blokta beyaz parlama: %s" % str(icon.self_modulate))
	tw.custom_step(KalkanGuard.RECOIL_OUT + 0.01)
	assert(icon.position.is_equal_approx(Vector2.ZERO) and icon.scale.is_equal_approx(Vector2.ONE), "dinlenme yerine döner: %s / %s" % [str(icon.position), str(icon.scale)])
	_cleanup()


## Yerel kalkan: gelen atış (tehdit) saldırı hedefinin önüne geçer - menzilde düşman olsa da yüz atışa döner; tehdit yokken önceki kural.
func test_weapon_face_prefers_the_incoming_shot() -> void:
	var owner_node := Node2D.new()
	add_child(owner_node)
	_spawned.append(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_kalkan.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var icon: Sprite2D = weapon.get("icon_sprite")
	weapon.call("_kalkan_face", Vector2.RIGHT)
	assert(int(icon.get_meta(K.META_SECTOR)) == 2, "tehdit yokken yüz hedefe (sağ = dilim 2)")
	weapon.set("_kalkan_threat", Vector2.DOWN)
	weapon.call("_kalkan_face", Vector2.RIGHT)
	assert(int(icon.get_meta(K.META_SECTOR)) == 0, "tehdit varken yüz atışa (aşağı = dilim 0), hedefe değil")
	_cleanup()


## Yerel kalkan: blokta ikon geri tepmesi; darbe ikonu yönetirken karışmaz; darbe oturduktan sonra tehdit beklemeyi böler (öncesinde bölmez).
func test_weapon_block_recoil_and_threat_breaks_the_bash_wait() -> void:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	_spawned.append(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_kalkan.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	weapon.scale = owner_node.scale
	var icon: Sprite2D = weapon.get("icon_sprite")
	weapon.call("_kalkan_block_react", Vector2.RIGHT)
	var rt: Tween = weapon.get("_kalkan_recoil_tween")
	assert(rt != null and rt.is_valid(), "blokta geri tepme tween'i")
	rt.pause()
	rt.custom_step(KalkanGuard.RECOIL_IN)
	assert(icon.position.x < -1.0, "ikon atışın tersine çekilir: %s" % str(icon.position))
	rt.kill()
	icon.position = Vector2.ZERO
	icon.scale = weapon.call("_kalkan_rest_scale")
	weapon.call("_start_kalkan_bash", Vector2.RIGHT, owner_node.global_position + Vector2(90.0, 0.0))
	assert(bool(weapon.call("_kalkan_bash_running")), "darbe sürüyor")
	assert(int(weapon.get("_kalkan_release_msec")) > Time.get_ticks_msec(), "oturma anı gelecekte")
	weapon.call("_kalkan_block_react", Vector2.RIGHT)
	var after_bash: Tween = weapon.get("_kalkan_recoil_tween")
	assert(after_bash == null or not after_bash.is_valid(), "darbe ikonu yönetirken geri tepme karışmaz")
	weapon.set("_kalkan_threat", Vector2.DOWN)
	weapon.call("_kalkan_threat_break_bash")
	assert(bool(weapon.call("_kalkan_bash_running")), "darbe oturmadan tehdit bölmez (hasar/itme zamanı bozulmasın)")
	weapon.set("_kalkan_release_msec", 0)
	weapon.call("_kalkan_threat_break_bash")
	assert(not bool(weapon.call("_kalkan_bash_running")), "darbe oturduktan sonra tehdit beklemeyi böler")
	weapon.call("_kalkan_face", Vector2.RIGHT)
	assert(int(icon.get_meta(K.META_SECTOR)) == 0, "bölününce yüz atışa döner")
	_cleanup()


## MP kukla: aynı hizalama + geri tepme; host'ta aynı bloğu hem kendi mermisi hem ağ bildirir -> ikinci tepki yutulur.
func test_puppet_aligns_recoils_and_dedupes_the_net_block() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(78, 5, "Dost")
	puppet.global_position = Vector2(4000.0, 4000.0)
	puppet.call("update_weapon_visuals", ["kalkan"])
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	puppet.set("_kalkan_threat", Vector2.DOWN)
	puppet.call("_wf_face", 0, icon, Vector2.RIGHT, 1.0)
	assert(int(icon.get_meta(K.META_SECTOR)) == 0, "kukla da gelen atışa hizalanır")
	puppet.call("kalkan_block_react", Vector2.RIGHT)
	var rt: Tween = puppet.get("_kalkan_recoil_tween")
	assert(rt != null and rt.is_valid(), "kukla kalkanı blokta geri tepmeli")
	rt.kill()
	var stamp: int = int(puppet.get("_kalkan_react_msec"))
	puppet.call("kalkan_block_remote", Vector2(4040.0, 4000.0), Vector2.RIGHT)
	assert(int(puppet.get("_kalkan_react_msec")) == stamp, "host kendi kopyasıyla bloklamışsa ağdan gelen aynı blok yutulur")
	puppet.free()
	get_tree().current_scene = prev_scene
	_cleanup()


## ---------------------------------------------------------------- siper alma (madde 701)
## Durum makinesi: tehditte ~0,2 sn içinde tam siper (yön = atış), tehdit bitince COVER_HOLD boyunca siperde kalır, sonra yuvaya döner.
func test_cover_state_machine_moves_in_holds_and_returns() -> void:
	var st: Dictionary = {}
	for i in range(12):
		KalkanGuard.cover_step(st, Vector2.DOWN, 1.0 / 60.0)
	assert(is_equal_approx(KalkanGuard.cover_blend(st), 1.0), "0,2 sn'de tam siper: %s" % str(st))
	assert((st["dir"] as Vector2).distance_to(Vector2.DOWN) < 0.01, "siper yönü atış")
	assert(KalkanGuard.cover_world(st).distance_to(Vector2(0.0, KalkanGuard.COVER_WORLD_PX)) < 0.01, "siper noktası gövdenin atış tarafında")
	for i in range(int(KalkanGuard.COVER_HOLD * 60.0) - 2):
		KalkanGuard.cover_step(st, Vector2.ZERO, 1.0 / 60.0)
	assert(is_equal_approx(KalkanGuard.cover_blend(st), 1.0), "tehdit bitince bir süre siperde kalır")
	for i in range(90):
		KalkanGuard.cover_step(st, Vector2.ZERO, 1.0 / 60.0)
	assert(KalkanGuard.cover_blend(st) == 0.0, "sonra yuvasına döner")
	KalkanGuard.cover_hit(st, Vector2(-30.0, 0.0))
	KalkanGuard.cover_step(st, Vector2.ZERO, 1.0 / 60.0)
	assert(KalkanGuard.cover_blend(st) > 0.0 and (st["dir"] as Vector2).distance_to(Vector2.LEFT) < 0.01, "blok anı siperi o tarafa açar")
	var sp: Vector2 = KalkanGuard.spark_pos(Vector2(100, 100), Vector2(40, 0))
	assert(sp.distance_to(Vector2(100.0 + KalkanGuard.SPARK_WORLD_PX, 100.0)) < 0.01, "kıvılcım kalkanın yüzünde: %s" % str(sp))


## Yerel kalkan: tehditte yuvadan (başın üstü) gövdenin atış tarafına kayar; darbe sürerken donar; yakın atışta darbe ertelenir (sınırlı).
func test_weapon_takes_cover_and_postpones_bash() -> void:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	_spawned.append(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_kalkan.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var slot := Vector2(0.0, -125.0)
	weapon.set("_kalkan_threat", Vector2.DOWN)
	var h: Vector2 = slot
	for i in range(20):
		h = weapon.call("_kalkan_cover_home", slot, owner_node, 1.0 / 60.0)
	var want := Vector2(0.0, KalkanGuard.COVER_WORLD_PX / 0.5)
	assert(h.distance_to(want) < 0.5, "siperde: yerel %s (beklenen %s)" % [str(h), str(want)])
	weapon.set("_kalkan_threat", Vector2.ZERO)
	for i in range(120):
		h = weapon.call("_kalkan_cover_home", slot, owner_node, 1.0 / 60.0)
	assert(h.is_equal_approx(slot), "tehdit bitince yuvaya döner: %s" % str(h))
	weapon.set("_kalkan_threat_d", 60.0)
	assert(bool(weapon.call("_kalkan_postpone_bash")), "yakın atışta darbe ertelenir")
	var ft: Timer = weapon.get("fire_timer")
	assert(ft.time_left <= 0.09 and ft.wait_time > 0.5, "kısa sonra yeniden dener, sonraki turlar tam aralık: %s / %s" % [ft.time_left, ft.wait_time])
	weapon.set("_kalkan_postpone_msec", Time.get_ticks_msec() - KalkanGuard.POSTPONE_MAX_MSEC - 10)
	assert(not bool(weapon.call("_kalkan_postpone_bash")), "erteleme sınırlı (yağmurda saldırı kesilmez)")
	weapon.set("_kalkan_threat_d", KalkanGuard.IMMINENT_DIST + 50.0)
	assert(not bool(weapon.call("_kalkan_postpone_bash")), "uzak atış ertelemez")
	_cleanup()


## MP kukla: aynı siper kuralı (pivotun ebeveyn biriminde) - diğer oyuncu da kalkanın atışa girdiğini görür.
func test_puppet_takes_cover_too() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(79, 5, "Dost")
	puppet.global_position = Vector2(4000.0, 4000.0)
	puppet.call("update_weapon_visuals", ["kalkan"])
	var pv: Node2D = (puppet.get("_wf_pivots") as Array)[0]
	var slot := Vector2(0.0, -125.0)
	puppet.set("_kalkan_threat", Vector2.RIGHT)
	var h: Vector2 = slot
	for i in range(20):
		h = puppet.call("_wf_kalkan_cover_home", 0, slot, pv, 1.0 / 60.0)
	var parent := pv.get_parent() as Node2D
	var world: Vector2 = parent.global_transform.basis_xform(h)
	assert(world.distance_to(Vector2(KalkanGuard.COVER_WORLD_PX, 0.0)) < 0.5, "kukla kalkanı da atış tarafında: dünya ofseti %s" % str(world))
	puppet.free()
	get_tree().current_scene = prev_scene
	_cleanup()
