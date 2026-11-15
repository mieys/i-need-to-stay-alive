extends Node

## Şovalye Koruma Baloncuğu (R) yaratık büyülerini DIŞARIDA tutar (2026-10-10, kullanıcı: "şovalye adamın kalkanının içine yaratıkların bazı büyüleri girebiliyor").
## Kural kaynağı: enemy_abilities.gd dome_owner_at / clip_ray_to_domes / deal_special_damage / spawn_world_fx / _vampire_blink.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const VampireScene: PackedScene = preload("res://scenes/creatures/enemy_vampire1.tscn")

var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## player / remote_players grubundaki sahte oyuncu: sadece enemy_abilities.damageable_players + dome_owner_at + özel hasar sayacı için gerekenler.
class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var paladin_zone_active: bool = false
	var paladin_zone_radius: float = 126.0
	var hits: Array = []
	var dome_hits: Array = [] ## take_paladin_barrier_damage çağrıları: [miktar, saldıran]

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])

	func take_paladin_barrier_damage(amount: float, attacker: Node2D = null) -> void:
		dome_hits.append([amount, attacker])


func _make(group: String, pos: Vector2, dome: bool) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group(group)
	p.paladin_zone_active = dome
	add_child(p)
	p.global_position = pos
	_track(p)
	return p


func test_dome_owner_lookup_uses_the_radius_and_the_margin() -> void:
	var owner_p: FakePlayer = _make("player", Vector2.ZERO, true)
	var tree: SceneTree = get_tree()
	## 2026-10-14: alan ELİPS (yatay 126, dikey 63; paladin_dome.gd)
	assert(AbilitiesScript.dome_owner_at(tree, Vector2(100.0, 0.0)) == owner_p, "yatayda 126 px içinde = baloncuğun içinde")
	assert(AbilitiesScript.dome_owner_at(tree, Vector2(140.0, 0.0)) == null, "yatayda 126 px dışında")
	assert(AbilitiesScript.dome_owner_at(tree, Vector2(140.0, 0.0), 30.0) == owner_p, "pay eklenince 156 px'e kadar")
	assert(AbilitiesScript.dome_owner_at(tree, Vector2(0.0, 55.0)) == owner_p, "dikeyde 63 px içinde")
	assert(AbilitiesScript.dome_owner_at(tree, Vector2(0.0, 80.0)) == null, "dikeyde 63 px dışında (eski dairenin içi)")
	owner_p.paladin_zone_active = false
	assert(AbilitiesScript.dome_owner_at(tree, Vector2(10.0, 0.0)) == null, "baloncuk kapalıyken kimse korunmaz")
	_cleanup()


func test_special_damage_is_blocked_inside_the_dome_and_lands_outside() -> void:
	var owner_p: FakePlayer = _make("player", Vector2.ZERO, true)
	var ally: FakePlayer = _make("remote_players", Vector2(60.0, 0.0), false)
	var stranger: FakePlayer = _make("remote_players", Vector2(400.0, 0.0), false)
	for kind in ["thorns", "acid", "rock", "vine", "scream", "cosmic", "demonslash", "minotaur"]:
		AbilitiesScript.deal_special_damage(owner_p, 50.0, null, kind)
		AbilitiesScript.deal_special_damage(ally, 50.0, null, kind)
	assert(owner_p.hits.is_empty() and ally.hits.is_empty(), "baloncuğun içindekilere (sahip + dost) hiçbir özel hasar işlemez")
	AbilitiesScript.deal_special_damage(stranger, 50.0, null, "rock")
	assert(stranger.hits == [[50.0, "rock"]], "dışarıdaki oyuncu normal hasar alır: %s" % str(stranger.hits))
	owner_p.paladin_zone_active = false
	AbilitiesScript.deal_special_damage(owner_p, 50.0, null, "rock")
	assert(owner_p.hits.size() == 1, "baloncuk kapanınca hasar yine işler")
	_cleanup()


func test_ground_spells_do_not_spawn_inside_the_dome() -> void:
	_make("player", Vector2.ZERO, true)
	var tree: SceneTree = get_tree()
	var data: Dictionary = {"warn": 0.5, "radius": 40.0}
	for kind in AbilitiesScript.DOME_BLOCKED_FX_KINDS:
		var inside: Node2D = AbilitiesScript.spawn_world_fx(tree, kind, Vector2(20.0, 10.0), data, true, null, 10.0)
		assert(inside == null, "%s baloncuğun içinde doğmamalı" % kind)
	var outside: Node2D = AbilitiesScript.spawn_world_fx(tree, "thorns", Vector2(400.0, 0.0), data, true, null, 10.0)
	assert(outside != null, "dışarıda diken normal doğar")
	_track(outside)
	## istemcideki görsel kopya (authoritative=false) host'un kararına bağlıdır: host doğurmadıysa zaten yayınlamaz
	var visual: Node2D = AbilitiesScript.spawn_world_fx(tree, "thorns", Vector2(20.0, 10.0), data, false, null, 0.0)
	assert(visual != null, "görsel kopya süzülmez (yayını host süzer)")
	_track(visual)
	_cleanup()


func test_rays_end_at_the_dome_boundary() -> void:
	var tree: SceneTree = get_tree()
	assert(is_equal_approx(AbilitiesScript.clip_ray_to_domes(tree, Vector2(-500.0, 0.0), Vector2.RIGHT, 440.0), 440.0), "baloncuk yokken uzunluk aynı")
	_make("player", Vector2.ZERO, true)
	var cut: float = AbilitiesScript.clip_ray_to_domes(tree, Vector2(-500.0, 0.0), Vector2.RIGHT, 440.0)
	assert(cut < 380.0 and cut > 360.0, "lazer elipsin yatay kenarında x=-126'da (374 px) biter: %f" % cut)
	assert(is_equal_approx(AbilitiesScript.clip_ray_to_domes(tree, Vector2(-500.0, 300.0), Vector2.RIGHT, 440.0), 440.0), "baloncuğa değmeyen ışın kısalmaz")
	_cleanup()


func test_vampire_does_not_blink_into_the_dome_but_blinks_normally_otherwise() -> void:
	var owner_p: FakePlayer = _make("player", Vector2(300.0, 0.0), true)
	var e: Node2D = VampireScene.instantiate()
	e.set_meta("creature_id", "vampire1")
	add_child(e)
	_track(e)
	e.global_position = Vector2(-300.0, 0.0)
	e.call("_init_abilities")
	var kit = e.get("_abilities")
	assert(kit != null, "vampir yetenek nesnesi kurulmalı")
	var from: Vector2 = e.global_position
	## hedef = baloncuğun sahibi: 46 px'lik tüm ışınlanma noktaları baloncuğun (126 px) içinde -> ışınlanma yok
	assert(kit.call("_vampire_blink") == false, "baloncuğun içine ışınlanma olmamalı")
	assert(e.global_position == from, "ışınlanma olmadı, konum aynı")
	## baloncuk kapanınca ışınlanır (hedefin ~46 px yanına)
	owner_p.paladin_zone_active = false
	assert(kit.call("_vampire_blink") == true, "baloncuksuz ışınlanma çalışır")
	var d: float = e.global_position.distance_to(owner_p.global_position)
	assert(absf(d - AbilitiesScript.VAMPIRE_BLINK_DISTANCE) < 1.0, "hedefin yanına indi: %f" % d)
	_cleanup()


## ---- Kubbe MENZİLLİ atışları EMER (madde 542, kullanıcı: "hasar vermesi lazım kalkana, sonuçta dışarıdan gelenleri absorbe ediyor") ----
## Eskiden mermi/kemik/ateş topu/boss büyüsü/asit kenara değince hasarsız siliniyor, lazer kenarda kesiliyordu; artık kubbe sahibi
## `take_paladin_barrier_damage` ile (yakın dövüşçü vuruşuyla aynı yol) hasar alır. Yalnız yetkili kopya (host/tek oyunculu) vurur.
const PaladinDomeScript := preload("res://scripts/paladin_dome.gd")
const PlayerScript := preload("res://scripts/player.gd")


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func test_absorb_ranged_hit_forwards_the_amount_and_survives_bad_input() -> void:
	var owner_p: FakePlayer = _make("player", Vector2.ZERO, true)
	PaladinDomeScript.absorb_ranged_hit(owner_p, 12.0, null)
	assert(owner_p.dome_hits == [[12.0, null]], "hasar kubbe sahibine aynen iletilir: %s" % str(owner_p.dome_hits))
	PaladinDomeScript.absorb_ranged_hit(owner_p, 0.0, null)
	PaladinDomeScript.absorb_ranged_hit(owner_p, -3.0, null)
	assert(owner_p.dome_hits.size() == 1, "sıfır / eksi hasar çağrılmaz")
	var shooter := Node2D.new()
	add_child(shooter)
	PaladinDomeScript.absorb_ranged_hit(owner_p, 5.0, shooter)
	assert(owner_p.dome_hits[1][1] == shooter, "saldıran (Yansıtan Kubbe / hasar çarpanı için) iletilir")
	shooter.free() ## mermiyi atan yaratık uçuşta ölüp silindi: çökmemeli, hasar yine işler (saldıran null)
	var gone: Node2D = Node2D.new()
	gone.free()
	PaladinDomeScript.absorb_ranged_hit(owner_p, 6.0, gone)
	assert(owner_p.dome_hits.size() == 3 and owner_p.dome_hits[2][1] == null, "silinmiş saldıran null sayılır: %s" % str(owner_p.dome_hits))
	PaladinDomeScript.absorb_ranged_hit(null, 5.0, null)
	var plain := Node2D.new()
	add_child(plain)
	_track(plain)
	PaladinDomeScript.absorb_ranged_hit(plain, 5.0, null) ## take_paladin_barrier_damage'ı olmayan düğüm: sessizce yok sayılır
	_cleanup()


func test_ranged_attacks_hit_the_dome_shield_when_authoritative_and_only_then() -> void:
	var tree: SceneTree = get_tree()
	var owner_p: FakePlayer = _make("player", Vector2.ZERO, true)
	## [tür, veri]: hepsi soldan (-230, 0) kubbeye (kenar x=-126) doğru uçar
	var cases: Array = [
		["fireball", {"dir": Vector2.RIGHT, "speed": 230.0}],
		["bone", {"dir": Vector2.RIGHT, "speed": 190.0}],
		["boss_spell", {"dir": Vector2.RIGHT, "speed": 200.0, "life": 3.0, "radius": 9.0}],
		["worm_acid", {"dir": Vector2.RIGHT, "speed": 200.0, "range": 600.0}],
		["demon_fire", {"dir": Vector2.RIGHT, "speed": 300.0, "life": 3.0, "radius": 9.0, "blast": 44.0}],
	]
	for c in cases:
		var kind: String = c[0]
		var visual: Node2D = AbilitiesScript.spawn_world_fx(tree, kind, Vector2(-230.0, 0.0), c[1], false, null, 0.0)
		_track(visual)
		await _physics_frames(110)
		assert(owner_p.dome_hits.is_empty(), "%s: istemcideki görsel kopya kubbeye hasar vermez: %s" % [kind, str(owner_p.dome_hits)])
		var real: Node2D = AbilitiesScript.spawn_world_fx(tree, kind, Vector2(-230.0, 0.0), c[1], true, null, 9.0)
		_track(real)
		await _physics_frames(110)
		assert(owner_p.dome_hits.size() == 1 and is_equal_approx(float(owner_p.dome_hits[0][0]), 9.0),
				"%s: yetkili atış kubbeye tam 1 kez, kendi hasarıyla vurur: %s" % [kind, str(owner_p.dome_hits)])
		assert(owner_p.hits.is_empty(), "%s: kubbe sahibine 'özel hasar' (normal kalkan yolu) işlemez" % kind)
		assert(not is_instance_valid(real), "%s: kubbeye çarpan atış söner" % kind)
		owner_p.dome_hits.clear()
	_cleanup()


func test_enemy_projectile_hits_the_dome_but_the_network_copy_does_not() -> void:
	var owner_p: FakePlayer = _make("player", Vector2.ZERO, true)
	var scene: PackedScene = preload("res://scenes/enemy_projectile.tscn")
	for network_copy in [true, false]:
		var p: Node2D = scene.instantiate()
		p.direction = Vector2.RIGHT
		p.damage = 7.0
		if network_copy:
			p.set_meta("network_spawned", true)
		add_child(p)
		p.global_position = Vector2(-220.0, 0.0)
		_track(p)
		await _physics_frames(90)
		assert(not is_instance_valid(p), "kubbeye çarpan mermi söner (ağ kopyası dahil)")
		if network_copy:
			assert(owner_p.dome_hits.is_empty(), "ağ görsel kopyası hasar vermez: %s" % str(owner_p.dome_hits))
		else:
			assert(owner_p.dome_hits.size() == 1 and is_equal_approx(float(owner_p.dome_hits[0][0]), 7.0), "yetkili mermi kubbeye 7 hasar: %s" % str(owner_p.dome_hits))
	_cleanup()


func test_laser_ending_at_the_dome_edge_hits_the_dome_once_for_double() -> void:
	var tree: SceneTree = get_tree()
	var owner_p: FakePlayer = _make("player", Vector2.ZERO, true)
	var origin := Vector2(-500.0, 0.0)
	var length: float = AbilitiesScript.clip_ray_to_domes(tree, origin, Vector2.RIGHT, 440.0)
	var data: Dictionary = {"dir": Vector2.RIGHT, "length": length, "warn": 0.05, "fire": 0.4}
	var beam: Node2D = AbilitiesScript.spawn_world_fx(tree, "laser", origin, data, true, null, 10.0)
	_track(beam)
	await get_tree().create_timer(0.7).timeout
	assert(owner_p.dome_hits.size() == 1, "kubbede biten ışın kubbe sahibini BİR kez vurur: %s" % str(owner_p.dome_hits))
	assert(is_equal_approx(float(owner_p.dome_hits[0][0]), 10.0 * 2.0), "Röntgen kalkanları 2 katı yıpratır: %s" % str(owner_p.dome_hits))
	assert(owner_p.hits.is_empty(), "özel hasar yolu kullanılmaz")
	owner_p.dome_hits.clear()
	## kubbeye değmeyen ışın (kısa, kubbeye uzak bitiyor) kubbeyi vurmaz
	var short: Node2D = AbilitiesScript.spawn_world_fx(tree, "laser", origin, {"dir": Vector2.RIGHT, "length": 100.0, "warn": 0.05, "fire": 0.4}, true, null, 10.0)
	_track(short)
	await get_tree().create_timer(0.7).timeout
	assert(owner_p.dome_hits.is_empty(), "kubbeye ulaşmayan ışın kubbeyi vurmaz: %s" % str(owner_p.dome_hits))
	_cleanup()


func test_laser_dome_multiplier_matches_the_player_shield_multiplier() -> void:
	var laser_script: GDScript = load("res://scripts/enemy_laser.gd")
	assert(is_equal_approx(float(laser_script.get_script_constant_map()["DOME_SHIELD_MULT"]), PlayerScript.ENEMY_LASER_SHIELD_MULT), "lazerin kubbe çarpanı player.gd ENEMY_LASER_SHIELD_MULT ile aynı kalmalı")
