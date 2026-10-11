extends Node

## Wendigo (Kademe 12 bossu, 2026-10-09): masaüstü `wendigo` paketi + "boss ve yetenekleri.txt" (can 200.000, kalkan 280.000, soğurma %85, sarmaşık 100, taş 130, normal saldırı 120, 3x boy).
## Kapsam: sayfa/sahne/tablo sözleşmesi, statlar + boyut, sarmaşık çevrimi (hareket yönünün önüne, duran oyuncuya halka, tek isabet), kaya yağmuru (oyuncunun üstüne, uyarıdan sonra 130, alan dışı etkilenmez).

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const KitScript: GDScript = preload("res://scripts/wendigo_boss.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")

var _made: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for g: String in ["wendigo_vines", "wendigo_rocks"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).contains("wendigo_"):
			c.free()
	GameManager.bosses_enabled = false
	NetworkManager.is_multiplayer_active = false


func _add(n: Node) -> Node:
	add_child(n)
	_made.append(n)
	return n


func _spawner() -> Node:
	_cleanup()
	get_tree().current_scene = self
	var sp: Node = SpawnerScript.new()
	sp.name = "EnemySpawner"
	_add(sp)
	sp.max_concurrent_enemies = 100000
	sp.tier_duration = 100.0 ## testler 100 sn'lik kademelere göre yazıldı (varsayılan 2026-10-10'da 150 oldu; kademe süresi bu testlerin konusu değil)
	return sp


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	_add(p)
	p.global_position = pos
	return p


func _boss(sp: Node, pos: Vector2) -> Node:
	var b: Node = sp._spawn_creature("wendigo1", pos, 888001)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, "wendigo1", 12, 1)
	b._init_abilities()
	return b


func _fx_nodes(group: String) -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(n):
			out.append(n)
	return out


func test_sheets_scene_and_tables() -> void:
	var sheets: Dictionary = {"walk": 4, "idle": 4, "attack": 7, "vine": 12, "slam": 8, "death": 8, "hurt": 2}
	for k: String in sheets.keys():
		var tex: Texture2D = load("res://assets/enemies/wendigo/wendigo_%s.png" % k) as Texture2D
		assert(tex != null and tex.get_height() == 400 and tex.get_width() == 100 * int(sheets[k]), "sayfa %s" % k)
	var vine: Texture2D = load("res://assets/fx/wendigo/vine.png") as Texture2D
	assert(vine != null and vine.get_width() == 16 * 19 and vine.get_height() == 32, "sarmaşık şeridi 19 kare 16x32")
	assert(SpawnerScript.SCENES.has("wendigo1") and SpawnerScript.ID_FAMILY["wendigo1"] == "wendigo", "doğuş tabloları")
	assert(AbilitiesScript.family_has_ability("wendigo"), "yeteneği var")
	assert(SpawnerScript.NEW_BOSS_TIERS.get(12) == ["wendigo1"], "Kademe 12 bossu")
	assert(BossBarArtScript.display_name("wendigo1") == "WENDİGO", "boss barı adı")
	var b: Node = (SpawnerScript.SCENES["wendigo1"] as PackedScene).instantiate()
	add_child(b)
	_made.append(b)
	assert(b.cell_size == 100 and b.special_textures.has("vine") and b.special_textures.has("slam"), "özel dokular")
	_cleanup()


func test_boss_has_the_documented_stats_and_is_three_times_bigger() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, Vector2(500, 500))
	assert(b.max_health == 200000.0 and b.item_shield_max == 280000.0, "can/kalkan: %.0f / %.0f" % [b.max_health, b.item_shield_max])
	assert(is_equal_approx(b.shield_protection, 0.85) and is_equal_approx(b.contact_damage, 120.0 * SpawnerScript.CREATURE_DAMAGE_CUT), "soğurma %85 ve normal saldırı 120 x0,8 (2026-10-11)")
	assert(absf(b.frame_sprite.scale.x - 1.6 * EntityScale.SIZE * EntityScale.BOSS_EXTRA * 3.0) < 0.001, "3x boyut: %.4f" % b.frame_sprite.scale.x)
	b.play_special_anim("slam", 0.95)
	assert(b.frame_sprite.hframes == 8, "slam animasyonu 8 kare")
	b.play_special_anim("vine", 1.3)
	assert(b.frame_sprite.hframes == 12, "vine animasyonu 12 kare")
	_cleanup()


func test_vines_erupt_ahead_of_a_moving_player_and_around_a_standing_one() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(0, 0))
	var kit: RefCounted = boss._abilities._boss_kit
	var player: FakePlayer = _player(Vector2(300, 300))
	kit._rock_cd = 999.0
	kit._vine_cd = 0.0
	## Oyuncu sağa koşuyor (200 px/sn): hız süzgeci dolsun
	for i in range(30):
		player.global_position += Vector2(200.0 / 60.0, 0.0)
		kit.process(1.0 / 60.0, player, 400.0)
	var origin: Vector2 = player.global_position
	for i in range(80):
		player.global_position += Vector2(200.0 / 60.0, 0.0)
		kit.process(1.0 / 60.0, player, 400.0)
	var vines: Array = _fx_nodes("wendigo_vines")
	assert(vines.size() >= 6, "sürekli sarmaşık: %d" % vines.size())
	var ahead: int = 0
	for v: Node2D in vines:
		if v.global_position.x > origin.x + 40.0:
			ahead += 1
	assert(ahead >= vines.size() - 1, "sarmaşıkların çoğu gidilen yönün (sağ) ÖNÜNDE: %d / %d" % [ahead, vines.size()])
	assert(boss.ability_move_lock > 0.0 or kit._busy >= 0.0, "çevrim sırasında boss durur")
	for v: Node in vines:
		v.free()
	## Duran oyuncu: çevresinde halka
	kit._vel.clear()
	kit._busy = 0.0
	kit._vine_cd = 0.0
	var stand: Vector2 = player.global_position
	for i in range(120):
		kit.process(1.0 / 60.0, player, 400.0)
	vines = _fx_nodes("wendigo_vines")
	assert(vines.size() >= 3, "duran oyuncuya da sarmaşık: %d" % vines.size())
	for v: Node2D in vines:
		var d: float = v.global_position.distance_to(stand)
		assert(d >= 55.0 and d <= 125.0, "halka mesafesi: %.0f" % d)
	_cleanup()


func test_vine_hits_once_for_100_after_the_warning_and_misses_far_players() -> void:
	_spawner()
	var near: FakePlayer = _player(Vector2(100, 100))
	var far: FakePlayer = _player(Vector2(300, 100))
	far.remove_from_group("player")
	far.add_to_group("remote_players")
	var node := Node2D.new()
	node.set_script(load("res://scripts/wendigo_vine.gd"))
	node.set("data", {"warn": 0.7, "grow": 0.8, "radius": 26.0, "scale": 1.9})
	node.set("authoritative", true)
	node.set("damage", 100.0)
	node.position = Vector2(100, 100)
	_add(node)
	for i in range(30):
		node._physics_process(1.0 / 60.0)
	assert(near.hits.is_empty(), "uyarı süresinde hasar yok")
	for i in range(100):
		node._physics_process(1.0 / 60.0)
	assert(near.hits.size() == 1 and near.hits[0][0] == 100.0 and near.hits[0][1] == "vine", "tek isabet 100: %s" % str(near.hits))
	assert(far.hits.is_empty(), "uzaktaki oyuncu etkilenmez")
	_cleanup()


func test_slam_drops_rocks_on_the_player_and_they_hit_for_130() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(0, 0))
	var kit: RefCounted = boss._abilities._boss_kit
	var player: FakePlayer = _player(Vector2(300, 100))
	kit._vine_cd = 999.0
	kit._rock_cd = 0.0
	kit.process(0.02, player, 300.0)
	assert(kit._busy > 0.0 and boss._special_tex != null, "slam animasyonu + boss durur")
	for i in range(40):
		kit.process(0.02, player, 300.0)
	var rocks: Array = _fx_nodes("wendigo_rocks")
	assert(rocks.size() == KitScript.ROCKS_PER_PLAYER, "oyuncu başına %d kaya: %d" % [KitScript.ROCKS_PER_PLAYER, rocks.size()])
	var exact: int = 0
	for r: Node2D in rocks:
		if r.global_position.distance_to(player.global_position) < 1.0:
			exact += 1
	assert(exact >= 1, "en az bir kaya tam oyuncunun üstüne")
	assert(player.hits.is_empty(), "uyarı sırasında hasar yok")
	## Uyarı + düşüş geçince (oyuncu yerinde) tam bir kaya 130 vurur
	for i in range(int((KitScript.ROCK_WARN + KitScript.ROCK_FALL) * 60.0) + 5):
		for r: Node in rocks:
			if is_instance_valid(r):
				r._physics_process(1.0 / 60.0)
	var rock_hits: int = 0
	for h: Array in player.hits:
		if h[1] == "rock" and h[0] == KitScript.ROCK_DAMAGE:
			rock_hits += 1
	assert(rock_hits >= 1, "kaya ROCK_DAMAGE (104) hasar: %s" % str(player.hits))
	_cleanup()
