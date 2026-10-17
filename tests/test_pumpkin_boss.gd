extends Node

## Balkabağı Kafa (Kademe 8 bossu, 2026-10-09): masaüstündeki `balkabağı herif` paketi + "boss ve yetenekleri.txt". Kapsam: sprite/sahne sözleşmesi, doğuş tabloları, boss statları + boyutu,
## özel animasyon (cast/summon), ateş topu salvosu, kabak ve yarasa dalgaları (kademe ölçekli, %70/%30 can, +%20/%30 hız, doğuş tavanını doldurmaz), kabak patlaması (alan hasarı 20, ödülsüz dağılır),
## yarasa ısırığı (5 + kanama 5/sn), boss ölünce minyonların dağılması, boss ateş topunun isabeti. Gerçek C++ yaratıklar + sahte oyuncu.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const BossKitScript: GDScript = preload("res://scripts/pumpkin_boss.gd")
const MinionsScript: GDScript = preload("res://scripts/pumpkin_minions.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")
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
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).ends_with("boss_spell.gd"):
			c.free()
	GameManager.bosses_enabled = false
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
	sp.name = "EnemySpawner" ## pumpkin_boss.gd sahnede bu adla arar
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


func _boss(sp: Node, pos: Vector2 = Vector2(500, 500)) -> Node:
	var b: Node = sp._spawn_creature("balkabagi1", pos, 777001)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, "balkabagi1", 8, 1)
	b._init_abilities()
	return b


func test_sheets_scenes_and_tables_follow_the_conventions() -> void:
	var sheets: Dictionary = {"balkabagi_walk": 4, "balkabagi_idle": 4, "balkabagi_attack": 6, "balkabagi_cast": 8, "balkabagi_summon": 10, "balkabagi_death": 7, "balkabagi_hurt": 2}
	for k: String in sheets.keys():
		var tex: Texture2D = load("res://assets/enemies/pumpkin/%s.png" % k) as Texture2D
		assert(tex != null and tex.get_height() == 800 and tex.get_width() == 200 * int(sheets[k]), "boss sayfası %s" % k)
	for k: String in ["kabak_walk", "kabak_attack", "kabak_death", "kabak_hurt", "yarasa_walk", "yarasa_death", "yarasa_hurt"]:
		var tex2: Texture2D = load("res://assets/enemies/pumpkin/%s.png" % k) as Texture2D
		assert(tex2 != null and tex2.get_height() == 256, "minyon sayfası %s" % k)
	for id: String in ["balkabagi1", "kabak1", "yarasa1"]:
		assert(SpawnerScript.SCENES.has(id) and SpawnerScript.ID_FAMILY.has(id), "doğuş tablolarında: " + id)
		assert(AbilitiesScript.family_has_ability(SpawnerScript.ID_FAMILY[id]), "yeteneği var: " + id)
	assert(SpawnerScript.NEW_BOSS_TIERS.get(8) == ["balkabagi1"], "Kademe 8 bossu")
	assert(BossBarArtScript.display_name("balkabagi1") == "BALKABAĞI KAFA", "boss barı adı")
	for tier: int in SpawnerScript.TIER_ROSTER.keys():
		assert(not SpawnerScript.TIER_ROSTER[tier].has("kabak1") and not SpawnerScript.TIER_ROSTER[tier].has("yarasa1"), "minyonlar sıradan doğuşta çıkmaz")
	var b: Node = (SpawnerScript.SCENES["balkabagi1"] as PackedScene).instantiate()
	add_child(b)
	_made.append(b)
	assert(b.cell_size == 200 and b.special_textures.has("cast") and b.special_textures.has("summon"), "boss özel dokuları")
	_cleanup()


func test_boss_stats_size_and_special_animation() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp)
	assert(b.max_health == 100000.0 and b.item_shield_max == 120000.0, "can/kalkan: %.0f / %.0f" % [b.max_health, b.item_shield_max])
	assert(is_equal_approx(b.shield_protection, 0.85) and is_equal_approx(b.contact_damage, 40.0), "soğurma %85, normal saldırı 40 (x0,8 iptal 2026-10-11)")
	## 1,4x (2026-10-10: eskiden 2x, %30 küçüldü): sahne 0,8 (= 100% sanatta 1,6) x SIZE x boss ek küçültme x boss çarpanı 1,4
	assert(absf(b.frame_sprite.scale.x - 0.8 * EntityScale.SIZE * EntityScale.BOSS_EXTRA * 1.4) < 0.001, "boyut: %.4f" % b.frame_sprite.scale.x)
	assert(is_equal_approx(float(SpawnerScript.FIXED_BOSS_STATS["balkabagi1"]["scale"]), 2.0 * BossKitScript.BODY_SCALE_REL), "kit ve tablo aynı küçülme oranını kullanır")
	b.play_special_anim("cast", 0.8)
	assert(b._state == b.State.ATTACK and b.frame_sprite.hframes == 8 and b.frame_sprite.texture == b.special_textures["cast"], "cast animasyonu 8 kare")
	b.play_special_anim("summon", 1.1)
	assert(b.frame_sprite.hframes == 10, "summon animasyonu 10 kare")
	b._enter_state(b.State.WALK)
	assert(b._special_tex == null and b.frame_sprite.hframes == 4, "özel doku silinir, yürüme sayfası döner")
	b.play_special_anim("olmayan", 1.0)
	assert(b._special_tex == null, "bilinmeyen animasyon yok sayılır")
	_cleanup()


func test_summons_use_tier_scaling_hp_ratio_speed_bonus_and_do_not_fill_the_spawn_cap() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 100.0 * 7.0 + 5.0 ## Kademe 8
	var boss: Node = _boss(sp)
	var ref: Node = sp._spawn_creature("kabak1", Vector2(700, 700), 777010)
	ref.apply_tier_scaling(8)
	sp._enable_regular_shield(ref, 8)
	sp._apply_global_buff(ref)
	var k: Node = sp.spawn_summon("kabak1", Vector2(600, 500), boss)
	var y: Node = sp.spawn_summon("yarasa1", Vector2(620, 500), boss)
	assert(k != null and y != null, "minyonlar doğdu")
	assert(is_equal_approx(k.max_health, ref.max_health * 0.7), "kabak canı = kademe yaratığının yüzde 70'i: %.1f / %.1f" % [k.max_health, ref.max_health])
	assert(is_equal_approx(y.max_health, ref.max_health * 0.3), "yarasa canı yüzde 30: %.1f" % y.max_health)
	assert(is_equal_approx(k.speed, ref.speed * 1.2) and is_equal_approx(y.speed, ref.speed * 1.3), "hız +yüzde 20 / +yüzde 30: %.1f %.1f / %.1f" % [k.speed, y.speed, ref.speed])
	assert(is_equal_approx(k.item_shield_max, ref.item_shield_max * 0.7), "kalkan da orantılı")
	assert(k.is_in_group("summons") and k.get_meta("summoner") == boss and not k.has_meta("spawn_tier"), "summons grubu, sahibi var, kademe kapısını tutmaz")
	var before: int = sp._regular_enemy_count()
	sp.spawn_summon("kabak1", Vector2(640, 500), boss)
	assert(sp._regular_enemy_count() == before, "minyonlar doğuş tavanını doldurmaz")
	_cleanup()


func test_pumpkin_explodes_for_40_area_damage_and_dissolves_without_reward() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	var player: FakePlayer = _player(Vector2(500, 500))
	var far: FakePlayer = _player(Vector2(500, 620)) ## patlama yarıçapı (58 + gövde 12) dışında
	far.remove_from_group("player")
	far.add_to_group("remote_players")
	var k: Node = sp.spawn_summon("kabak1", Vector2(530, 500), boss)
	k._init_abilities()
	var kit: RefCounted = k._abilities._boss_kit
	kit.process(0.1, player, 30.0) ## 46 px içinde: fitil
	assert(kit._fuse > 0.0, "yaklaşınca fitil yanar")
	kit.process(0.2, player, 30.0)
	assert(player.hits.is_empty(), "fitil bitmeden hasar yok")
	kit.process(0.4, player, 30.0)
	assert(player.hits.size() == 1 and player.hits[0][0] == MinionsScript.BLAST_DAMAGE and player.hits[0][1] == "blast", "patlama BLAST_DAMAGE (40) alan hasarı: %s" % str(player.hits))
	assert(far.hits.is_empty(), "yarıçap dışındaki oyuncu etkilenmez")
	assert(k.is_dead, "kabak ödülsüz dağıldı")
	_cleanup()


func test_bat_bite_is_special_damage_and_player_bleeds_ten_per_second() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(2000, 2000))
	var player: FakePlayer = _player(Vector2(500, 500))
	var y: Node = sp.spawn_summon("yarasa1", Vector2(520, 500), boss)
	y._init_abilities()
	assert(y._abilities.handle_melee_hit(player), "yarasa vuruşu özel işlenir")
	assert(player.hits.size() == 1 and player.hits[0][0] == y.contact_damage and player.hits[0][1] == "bat_bite", "ısırık bat_bite: %s" % str(player.hits))
	var k: Node = sp.spawn_summon("kabak1", Vector2(540, 500), boss)
	k._init_abilities()
	assert(not k._abilities.handle_melee_hit(player), "kabak ısırmaz, normal yol")
	## Gerçek oyuncuda kanama: 4 sn, saniyede 5.
	var real: Node = PlayerScene.instantiate()
	_add(real)
	await get_tree().process_frame
	var hp0: float = real.health + real.item_shield_hp
	assert(is_equal_approx(real.ENEMY_BLEED_DPS, 10.0), "kanama saniyede 10 (2026-10-10: x2; x0,8 iptal)")
	real.apply_enemy_bleed(real.ENEMY_BLEED_DPS)
	var status: Array = real.get_status_badges() if real.has_method("get_status_badges") else []
	for i in range(60 * 5):
		real._process_enemy_bleed(1.0 / 60.0)
	var lost: float = hp0 - (real.health + real.item_shield_hp)
	assert(absf(lost - 40.0) < 7.0, "4 sn x 10 = ~40 kanama hasarı: %.1f" % lost)
	assert(real._enemy_bleed_timer <= 0.0, "kanama 4 sn sonra biter")
	_cleanup()


func test_boss_fireball_salvo_summons_waves_and_minions_vanish_with_the_boss() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var player: FakePlayer = _player(Vector2(500, 760))
	var kit: RefCounted = boss._abilities._boss_kit
	assert(kit != null and kit.get_script() == BossKitScript, "boss yetenek kiti")
	## Ateş topu salvosu
	kit._pumpkin_cd = 999.0
	kit._bat_cd = 999.0
	kit._ring_cd = 999.0
	kit._dash_cd = 999.0
	kit._salvo_cd = 0.0
	kit.process(0.05, player, 260.0)
	assert(kit._busy > 0.0, "salvo başladı (boss durur)")
	assert(boss.ability_move_lock > 0.0 and boss._state == boss.State.ATTACK and boss._special_tex != null, "cast animasyonu + hareket kilidi")
	for i in range(60):
		kit.process(0.02, player, 260.0)
	var balls: int = 0
	for c: Node in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("boss_spell.gd"):
			balls += 1
	assert(balls == BossKitScript.SALVO_SHOTS, "salvoda %d top: %d" % [BossKitScript.SALVO_SHOTS, balls])
	## Kabak ve yarasa dalgaları AYRI zamanlayıcılarla
	kit._busy = 0.0
	kit._ring_cd = 999.0
	kit._pumpkin_cd = 0.0
	kit.process(0.05, player, 260.0)
	for i in range(80):
		kit.process(0.02, player, 260.0)
	var pumpkins: int = 0
	var bats: int = 0
	for m: Node in get_tree().get_nodes_in_group("summons"):
		if str(m.get_meta("creature_id")) == "kabak1":
			pumpkins += 1
		elif str(m.get_meta("creature_id")) == "yarasa1":
			bats += 1
	assert(pumpkins == BossKitScript.PUMPKIN_COUNT and bats == 0, "kabak dalgası: %d kabak / %d yarasa" % [pumpkins, bats])
	kit._busy = 0.0
	kit._bat_cd = 0.0
	kit.process(0.05, player, 260.0)
	for i in range(80):
		kit.process(0.02, player, 260.0)
	bats = 0
	for m: Node in get_tree().get_nodes_in_group("summons"):
		if str(m.get_meta("creature_id")) == "yarasa1":
			bats += 1
	assert(bats == BossKitScript.BAT_COUNT, "yarasa dalgası: %d" % bats)
	## Boss ölünce minyonlar dağılır
	boss.is_dead = true
	for m: Node in get_tree().get_nodes_in_group("summons"):
		m._init_abilities()
		m._abilities._boss_kit._owner_t = 1.0
		m._abilities.process(0.1, null, INF)
		assert(m.is_dead, "minyon sahibi ölünce dağılır")
	_cleanup()


func test_boss_spell_hits_a_player_once_for_10_and_stops_at_walls() -> void:
	_spawner()
	var player: FakePlayer = _player(Vector2(300, 100))
	var node := Node2D.new()
	node.set_script(load("res://scripts/boss_spell.gd"))
	node.set("data", {"dir": Vector2.RIGHT, "speed": 200.0, "life": 3.0, "radius": 9.0})
	node.set("authoritative", true)
	node.set("damage", 10.0)
	node.position = Vector2(100, 100)
	_add(node)
	node.global_position = Vector2(100, 100)
	for i in range(120):
		node._physics_process(1.0 / 60.0)
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			break
	assert(player.hits.size() == 1 and player.hits[0][0] == 10.0 and player.hits[0][1] == "bossfire", "ateş topu 10 hasar, tek isabet: %s" % str(player.hits))
	_cleanup()


## 2026-10-10 (kullanıcı: "balkabağı bossunun boyutunu %30 küçült ve daha güçlü olması gerekiyor, yeteri kadar yetenek ve yaratık spamlamıyor, hasarını 2 kat arttır").
func test_damage_numbers_are_doubled_and_the_kit_is_much_busier() -> void:
	assert(BossKitScript.FIREBALL_DAMAGE == 30.0 and MinionsScript.BLAST_DAMAGE == 40.0, "ateş topu 30, kabak patlaması 40 (x0,8 iptal 2026-10-11)")
	assert(float(SpawnerScript.FIXED_BOSS_STATS["balkabagi1"]["damage"]) == 40.0, "normal saldırı 40")
	assert(float(SpawnerScript.SUMMON_STATS["yarasa1"]["damage"]) == 2.0, "yarasa ısırığı x2")
	## eskiden: salvo 3,2-4,8 sn / 5 top, kabak 11-14 sn x6 (en çok 20), yarasa 15-19 sn x4 (en çok 12)
	assert(BossKitScript.SALVO_COOLDOWN_MAX <= 3.0 and BossKitScript.SALVO_SHOTS >= 7, "salvo daha sık ve büyük")
	assert(BossKitScript.PUMPKIN_CD_MAX <= 8.0 and BossKitScript.PUMPKIN_COUNT >= 9 and BossKitScript.PUMPKIN_MAX_ALIVE >= 30, "kabak dalgası daha sık/büyük")
	assert(BossKitScript.BAT_CD_MAX <= 11.0 and BossKitScript.BAT_COUNT >= 6 and BossKitScript.BAT_MAX_ALIVE >= 18, "yarasa dalgası daha sık/büyük")
	var sp: Node = _spawner()
	GameManager.game_time = 100.0 * 7.0 + 5.0 ## Kademe 8 (testte kademe süresi 100 sn)
	var boss: Node = _boss(sp)
	var ref: Node = sp._spawn_creature("yarasa1", Vector2(700, 700), 777020)
	ref.apply_tier_scaling(8)
	sp._enable_regular_shield(ref, 8)
	sp._apply_global_buff(ref)
	var y: Node = sp.spawn_summon("yarasa1", Vector2(620, 500), boss)
	assert(is_equal_approx(y.contact_damage, ref.contact_damage * 2.0), "yarasa ısırık hasarı sıradan yaratığın 2 katı: %.2f / %.2f" % [y.contact_damage, ref.contact_damage])
	_cleanup()


func test_ring_volley_fires_sixteen_balls_in_every_direction() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var player: FakePlayer = _player(Vector2(500, 760))
	var kit: RefCounted = boss._abilities._boss_kit
	kit._pumpkin_cd = 999.0
	kit._bat_cd = 999.0
	kit._salvo_cd = 999.0
	kit._dash_cd = 999.0
	kit._ring_cd = 0.0
	kit.process(0.05, player, 260.0)
	assert(kit._busy > 0.0 and boss.ability_move_lock > 0.0, "halka salvosu başladı (boss durur)")
	for i in range(60):
		kit.process(0.02, player, 260.0)
	var dirs: Array = []
	for c: Node in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("boss_spell.gd"):
			dirs.append((c.get("data") as Dictionary)["dir"])
	assert(dirs.size() == BossKitScript.RING_SHOTS, "halkada %d top: %d" % [BossKitScript.RING_SHOTS, dirs.size()])
	var mean := Vector2.ZERO
	for d: Vector2 in dirs:
		mean += d
	assert((mean / float(dirs.size())).length() < 0.05, "toplar her yöne eşit dağılmış (yön ortalaması ~0)")
	_cleanup()


func test_second_phase_shortens_every_cooldown() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var kit: RefCounted = boss._abilities._boss_kit
	assert(is_equal_approx(kit._haste(), 1.0), "tam canda hız normal")
	boss.health = boss.max_health * 0.4
	boss.item_shield_hp = 0.0
	boss.item_shield_max = boss.item_shield_max ## azami kalkan duruyor: (can + kalkan) oranı yarının altına inmeli
	assert(kit._phase2() and is_equal_approx(kit._haste(), BossKitScript.PHASE2_CD_MULT), "can + kalkan yarıdan azsa bekleme x0,65")
	_cleanup()


func test_dash_speeds_the_boss_up_then_returns_to_normal() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var player: FakePlayer = _player(Vector2(500, 760))
	var kit: RefCounted = boss._abilities._boss_kit
	kit._pumpkin_cd = 999.0
	kit._bat_cd = 999.0
	kit._salvo_cd = 999.0
	kit._ring_cd = 999.0
	kit._dash_cd = 0.0
	kit.process(0.05, player, 260.0)
	assert(kit._busy > 0.0 and boss.ability_move_lock > 0.0 and is_equal_approx(boss.gate_rush_mult, 1.0), "atılış hazırlığı: boss durur, hız normal")
	for i in range(40): ## 0,8 sn > DASH_WINDUP
		kit.process(0.02, player, 260.0)
	assert(is_equal_approx(boss.gate_rush_mult, BossKitScript.DASH_MULT) and boss.ability_move_lock <= 0.0, "atılış: hız çarpanı %.1f, kilit yok" % boss.gate_rush_mult)
	for i in range(60): ## DASH_TIME bitti
		kit.process(0.02, player, 260.0)
	assert(is_equal_approx(boss.gate_rush_mult, 1.0) and kit._dash_cd > 0.0, "atılış bitince hız normale döner, bekleme başlar")
	assert(BossKitScript.FIREBALL_SPEED >= 250.0 and BossKitScript.RING_SPEED >= 190.0, "ateş topu 250, halka 190")
	_cleanup()


func test_second_phase_fires_bigger_volleys_and_waves() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var kit: RefCounted = boss._abilities._boss_kit
	boss.health = boss.max_health * 0.3
	boss.item_shield_hp = 0.0
	assert(kit._phase2(), "faz 2")
	var player: FakePlayer = _player(Vector2(500, 760))
	kit._pumpkin_cd = 999.0
	kit._bat_cd = 999.0
	kit._ring_cd = 999.0
	kit._dash_cd = 999.0
	kit._salvo_cd = 0.0
	kit.process(0.05, player, 260.0)
	for i in range(80):
		kit.process(0.02, player, 260.0)
	var balls: int = 0
	for c: Node in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("boss_spell.gd"):
			balls += 1
	assert(balls == BossKitScript.SALVO_SHOTS_P2, "faz 2 salvosu %d top: %d" % [BossKitScript.SALVO_SHOTS_P2, balls])
	_cleanup()
