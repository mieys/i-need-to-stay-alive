extends Node

## ZEHİRLİ GONCA (madde 682, 2026-11-14, Kara Bataklık K5) + harita boss dağıtımı. Kapsam: sayfa/sahne/tablo sözleşmesi, harita profillerinin boss tabloları,
## yuva statları, tohum saçma -> filizlenme, tohumun düştüğü yerdeki oyuncuya hasar (filizlenmez), yerdeki tohumu ezme, Filiz tavanı, Filiz ölümünde
## bossun can + kalkan kesintisi (Kök Göçü'nde içine çekilen Filiz kesmez), Filiz ısırığı + zehir, Diken Halkası, Kök Göçü, boss ölünce Filizlerin dağılması.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const BossKitScript: GDScript = preload("res://scripts/gonca_boss.gd")
const FilizKitScript: GDScript = preload("res://scripts/gonca_filiz.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const MapProfilesScript: GDScript = preload("res://scripts/map_profiles.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _made: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])

	func take_damage(amount: float, _source: Node2D = null) -> void:
		hits.append([amount, "plain"])


func _cleanup() -> void:
	for g: String in ["enemies", "summons", "guards"]:
		for e: Node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(e):
				e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).get_file().begins_with("gonca_"):
			c.free()
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false


func _add(n: Node) -> Node:
	add_child(n)
	_made.append(n)
	return n


func _spawner() -> Node:
	_cleanup()
	get_tree().current_scene = self
	var sp: Node = SpawnerScript.new()
	sp.name = "EnemySpawner" ## gonca_seed.gd sahnede bu adla arar
	_add(sp)
	sp.max_concurrent_enemies = 100000
	sp.tier_duration = 100.0
	return sp


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	_add(p)
	p.global_position = pos
	return p


func _boss(sp: Node, pos: Vector2 = Vector2(500, 500)) -> Node:
	var b: Node = sp._spawn_creature("gonca1", pos, 778001)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, "gonca1", 5, 1)
	b._init_abilities()
	return b


func _fx(name_prefix: String) -> Array:
	var out: Array = []
	for c: Node in get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c.get_script() != null and str(c.get_script().resource_path).get_file().begins_with(name_prefix):
			out.append(c)
	return out


func _filizler(boss: Node) -> Array:
	var out: Array = []
	for m: Node in get_tree().get_nodes_in_group("summons"):
		if is_instance_valid(m) and m.get("is_dead") != true and str(m.get_meta("creature_id", "")) == "filiz1" and m.get_meta("summoner", null) == boss:
			out.append(m)
	return out


## Elle bir tohum (yetkili): `to`ya düşer.
func _seed(boss: Node, from: Vector2, to: Vector2) -> Node2D:
	var node := Node2D.new()
	node.set_script(load("res://scripts/gonca_seed.gd"))
	node.set("data", {"to": to, "flight": 0.5, "sprout": 0.5, "arc": 40.0, "sid": BossKitScript.next_seed_id()})
	node.set("authoritative", true)
	node.set("source", boss)
	node.set("damage", 60.0)
	node.position = from
	add_child(node)
	node.global_position = from
	return node


func _step(node: Node, seconds: float) -> void:
	var n: int = int(ceil(seconds * 60.0))
	for i in n:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			return
		node._physics_process(1.0 / 60.0)


func test_sheets_scenes_tables_and_map_boss_assignment() -> void:
	var sheets: Dictionary = {"gonca_idle": 4, "gonca_walk": 4, "gonca_attack": 7, "gonca_spit": 8, "gonca_grow": 4, "gonca_hurt": 2, "gonca_death": 4}
	for k: String in sheets.keys():
		var tex: Texture2D = load("res://assets/enemies/gonca/%s.png" % k) as Texture2D
		assert(tex != null and tex.get_height() == 512 and tex.get_width() == 128 * int(sheets[k]), "sayfa %s" % k)
	for k: String in ["seed_loop", "seed_end"]:
		var t2: Texture2D = load("res://assets/fx/gonca/%s.png" % k) as Texture2D
		assert(t2 != null and t2.get_height() == 40 and t2.get_width() == 108, "tohum sayfası %s" % k)
	for id: String in ["gonca1", "filiz1"]:
		assert(SpawnerScript.SCENES.has(id) and SpawnerScript.ID_FAMILY.has(id), "doğuş tablolarında: " + id)
		assert(AbilitiesScript.family_has_ability(SpawnerScript.ID_FAMILY[id]), "yeteneği var: " + id)
	assert(SpawnerScript.FIXED_BOSS_STATS.has("gonca1") and SpawnerScript.BOSS_HOME_TIER["gonca1"] == 5, "nihai statlı boss, kendi yuvası K5")
	assert(SpawnerScript.SUMMON_STATS.has("filiz1") and float(SpawnerScript.SUMMON_STATS["filiz1"]["speed"]) == 0.0, "Filiz minyon, kıpırdamaz")
	for tier: int in SpawnerScript.TIER_ROSTER.keys():
		assert(not SpawnerScript.TIER_ROSTER[tier].has("filiz1"), "Filiz sıradan doğuşta çıkmaz")
	assert(BossBarArtScript.display_name("gonca1") == "ZEHİRLİ GONCA" and BossBarArtScript.display_name("filiz1") == "FİLİZ", "boss barı adları")
	## Harita boss dağıtımı (kullanıcı 2026-11-14)
	assert(SpawnerScript.boss_tiers_for_map("bataklik") == {5: ["gonca1"], 10: ["banshee1"]}, "Bataklık: K5 Gonca, K10 Banshee")
	assert(SpawnerScript.boss_tiers_for_map("col") == {5: ["underground1"], 10: ["medusa1"]}, "Çöl: K5 Yeraltı, K10 (son) Medusa")
	assert(SpawnerScript.boss_tiers_for_map("batik_nekropol") == {5: ["balkabagi1"], 10: ["ucansetan1"]}, "Nekropol: yeri değişen Balkabağı + Uçan Şeytan")
	assert(SpawnerScript.boss_tiers_for_map("kis") == {5: ["minotaur1"], 10: ["wendigo1"]}, "Ayaz Dağı: yeri değişen Wendigo (K10)")
	assert(SpawnerScript.boss_tiers_for_map("ana") == SpawnerScript.NEW_BOSS_TIERS and SpawnerScript.boss_tiers_for_map("yok_boyle_harita") == SpawnerScript.NEW_BOSS_TIERS, "tablosu olmayan harita = ana")
	for map_id: String in MapProfilesScript.selectable_ids():
		for tier in SpawnerScript.boss_tiers_for_map(map_id).keys():
			for id in SpawnerScript.boss_tiers_for_map(map_id)[tier]:
				assert(SpawnerScript.SCENES.has(id) and SpawnerScript.FIXED_BOSS_STATS.has(id), "%s K%d bossu tanımlı: %s" % [map_id, tier, id])
	## Yuvası değişen bossların özel saldırısı yuvaya göre küçülür
	assert(SpawnerScript.boss_slot_damage_mult("balkabagi1", 5) < 1.0 and SpawnerScript.boss_slot_damage_mult("ucansetan1", 10) < 1.0, "Balkabağı / Uçan Şeytan çarpanı < 1")
	assert(is_equal_approx(SpawnerScript.boss_slot_damage_mult("gonca1", 5), 1.0), "Gonca kendi yuvasında x1")
	_cleanup()


func test_boss_stats_are_the_k5_slot_and_it_never_moves() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp)
	assert(b.max_health == 50000.0 and b.item_shield_max == 60000.0, "K5 yuvası: %.0f / %.0f" % [b.max_health, b.item_shield_max])
	assert(is_equal_approx(b.shield_protection, 0.92) and is_equal_approx(b.contact_damage, 90.0), "soğurma %92, ısırık 90")
	assert(b.speed == 0.0, "yerinden kıpırdamaz")
	assert(b.special_textures.has("spit") and b.special_textures.has("grow") and b.special_textures.has("ring"), "özel klipler")
	b.play_special_anim("spit", 0.9)
	assert(b.frame_sprite.hframes == 8, "tükürme klibi 8 kare")
	_cleanup()


func test_seed_volley_throws_seed_count_seeds() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp)
	var player: FakePlayer = _player(Vector2(500, 760))
	var kit: RefCounted = boss._abilities._boss_kit
	assert(kit != null and kit.get_script() == BossKitScript, "boss kiti")
	kit._ring_cd = 999.0
	kit._migrate_cd = 999.0
	kit._seed_cd = 0.0
	kit.process(0.05, player, 260.0)
	assert(kit._busy > 0.0 and boss._special_tex != null, "tükürme klibi başladı")
	for i in range(60):
		kit.process(0.02, player, 260.0)
	assert(_fx("gonca_seed").size() == BossKitScript.SEED_COUNT, "%d tohum: %d" % [BossKitScript.SEED_COUNT, _fx("gonca_seed").size()])
	_cleanup()


func test_a_landed_seed_sprouts_into_a_rooted_filiz() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	_player(Vector2(100, 100))
	var s: Node2D = _seed(boss, Vector2(400, 400), Vector2(600, 400))
	_step(s, 0.6)
	assert(s.global_position.distance_to(Vector2(600, 400)) < 1.0, "tohum hedefe düştü")
	assert(_filizler(boss).is_empty(), "henüz filizlenmedi")
	_step(s, 0.6)
	var f: Array = _filizler(boss)
	assert(f.size() == 1, "tohum Filiz oldu: %d" % f.size())
	assert((f[0] as Node2D).global_position.distance_to(Vector2(600, 400)) < 1.0 and float(f[0].speed) == 0.0, "yerinde, kıpırdamaz")
	assert(f[0].is_in_group("summons") and not f[0].has_meta("spawn_tier"), "minyon: kademe kapısını tutmaz")
	_cleanup()


func test_a_seed_landing_on_a_player_hits_and_does_not_sprout() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	var p: FakePlayer = _player(Vector2(600, 400))
	var s: Node2D = _seed(boss, Vector2(400, 400), Vector2(605, 400))
	_step(s, 1.5)
	assert(p.hits.size() == 1 and p.hits[0][1] == "gonca_seed" and p.hits[0][0] == 60.0, "düştüğü yerdeki oyuncuya 60 + zehir: %s" % str(p.hits))
	assert(_filizler(boss).is_empty(), "isabet eden tohum filizlenmez")
	_cleanup()


func test_stepping_on_a_landed_seed_crushes_it() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	var p: FakePlayer = _player(Vector2(100, 100))
	var s: Node2D = _seed(boss, Vector2(400, 400), Vector2(600, 400))
	_step(s, 0.6) ## yere düştü (oyuncu uzakta: isabet yok)
	p.global_position = Vector2(605, 402) ## üstüne bas
	_step(s, 1.0)
	assert(p.hits.is_empty(), "ezmek hasar vermez")
	assert(_filizler(boss).is_empty(), "ezilen tohum filizlenmez")
	_cleanup()


func test_killing_a_filiz_cuts_the_boss_health_and_shield() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	var f: Node = sp.spawn_summon("filiz1", Vector2(600, 400), boss)
	f._init_abilities()
	var h0: float = boss.health
	var s0: float = boss.item_shield_hp
	f.die()
	var cut: float = BossKitScript.DRAIN_FRACTION
	assert(is_equal_approx(boss.health, h0 - boss.max_health * cut), "can %%%d azaldı: %.0f -> %.0f" % [int(cut * 100.0), h0, boss.health])
	assert(is_equal_approx(boss.item_shield_hp, s0 - boss.item_shield_max * cut), "kalkan da azaldı: %.0f -> %.0f" % [s0, boss.item_shield_hp])
	## Boss canı bitince kan bağı onu öldürür
	boss.health = boss.max_health * cut * 0.5
	var f2: Node = sp.spawn_summon("filiz1", Vector2(620, 400), boss)
	f2._init_abilities()
	f2.die()
	assert(boss.is_dead, "son kesinti bossu öldürür")
	_cleanup()


func test_filiz_bite_is_a_poison_hit_and_filizler_vanish_with_the_boss() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	var p: FakePlayer = _player(Vector2(500, 500))
	var f: Node = sp.spawn_summon("filiz1", Vector2(520, 500), boss)
	f._init_abilities()
	assert(f._abilities.handle_melee_hit(p), "ısırık özel işlenir")
	assert(p.hits.size() == 1 and p.hits[0][1] == "gonca_bite" and p.hits[0][0] == f.contact_damage, "gonca_bite: %s" % str(p.hits))
	boss.is_dead = true
	f._abilities._boss_kit._grown = true
	f._abilities._boss_kit._owner_t = 1.0
	f._abilities.process(0.1, null, INF)
	assert(f.is_dead, "boss ölünce Filiz ödülsüz dağılır")
	_cleanup()


func test_the_filiz_cap_stops_sprouting() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	_player(Vector2(100, 100))
	var kit: RefCounted = boss._abilities._boss_kit
	var cap: int = kit.filiz_cap()
	assert(cap == BossKitScript.FILIZ_MAX_ALIVE, "tek oyuncu tavanı %d" % cap)
	for i in cap:
		sp.spawn_summon("filiz1", Vector2(300 + i * 30, 300), boss)
	var s: Node2D = _seed(boss, Vector2(400, 400), Vector2(600, 600))
	_step(s, 1.5)
	assert(_filizler(boss).size() == cap, "tavan dolu: yeni Filiz yok (%d)" % _filizler(boss).size())
	_cleanup()


func test_thorn_ring_hits_players_close_to_the_boss() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var near: FakePlayer = _player(Vector2(600, 500))
	var far: FakePlayer = _player(Vector2(800, 500))
	far.remove_from_group("player")
	far.add_to_group("remote_players")
	var kit: RefCounted = boss._abilities._boss_kit
	kit._seed_cd = 999.0
	kit._migrate_cd = 999.0
	kit._ring_cd = 0.0
	kit.process(0.05, near, 100.0)
	var rings: Array = _fx("gonca_ring")
	assert(rings.size() == 1, "Diken Halkası uyarısı")
	_step(rings[0], 1.0)
	assert(near.hits.size() == 1 and near.hits[0][1] == "gonca_ring", "yakındaki oyuncu: %s" % str(near.hits))
	assert(far.hits.is_empty(), "halka dışı etkilenmez")
	_cleanup()


func test_root_migration_moves_the_boss_onto_its_farthest_filiz() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var p: FakePlayer = _player(Vector2(560, 500))
	var near_f: Node = sp.spawn_summon("filiz1", Vector2(650, 500), boss)
	var far_f: Node = sp.spawn_summon("filiz1", Vector2(760, 640), boss) ## ~300 px içinde: göç menzili
	var too_far: Node = sp.spawn_summon("filiz1", Vector2(1400, 900), boss) ## menzil dışı: ekran dışına kaçış yok
	near_f._init_abilities()
	far_f._init_abilities()
	too_far._init_abilities()
	var kit: RefCounted = boss._abilities._boss_kit
	kit._seed_cd = 999.0
	kit._ring_cd = 999.0
	kit._migrate_cd = 0.0
	kit._count_t = 0.0
	var h0: float = boss.health
	kit.process(0.05, p, 60.0)
	assert(kit._busy > 0.0, "göç başladı")
	for i in range(60):
		kit.process(0.02, p, 60.0)
	assert((boss as Node2D).global_position.distance_to(Vector2(760, 640)) < 2.0, "boss menzildeki en uzak Filiz'in yerinde: %s" % str((boss as Node2D).global_position))
	assert(far_f.is_dead and not near_f.is_dead and not too_far.is_dead, "içine çekilen Filiz kayboldu, menzil dışındakine dokunulmadı")
	assert(boss.health >= h0, "içine çekilen Filiz kan bağı kesintisi yapmaz")
	_cleanup()


func test_player_poison_ticks_for_four_seconds() -> void:
	_spawner()
	var real: Node = PlayerScene.instantiate()
	_add(real)
	await get_tree().process_frame
	var hp0: float = real.health + real.item_shield_hp
	real.apply_enemy_poison(10.0)
	assert(real.get_status_effects().any(func(d: Dictionary) -> bool: return d["kind"] == "poison"), "zehir rozeti")
	for i in range(60 * 5):
		real._process_enemy_poison(1.0 / 60.0)
	var lost: float = hp0 - (real.health + real.item_shield_hp)
	assert(absf(lost - 40.0) < 7.0, "4 sn x 10 = ~40 zehir hasarı: %.1f" % lost)
	assert(real._enemy_poison_timer <= 0.0, "zehir 4 sn sonra biter")
	_cleanup()
