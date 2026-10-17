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

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])


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
