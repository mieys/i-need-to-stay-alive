extends Node

## ÜÇ KARDEŞ (ana harita K10 bossu, 2026-11-14; kardes_boss.gd): tablo/sahne sözleşmesi, kardeş statları, ortak 3 parçalı bar, öfke + imza devri,
## Kılıç atılması / kasırgası, Ok salvosu / yağmuru, Büyü ateş topu / meteoru, alan ve mermi isabet kuralları, sonsuz dalgada üçlü bütünlüğü.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const KitScript: GDScript = preload("res://scripts/kardes_boss.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const BossBarTopScript: GDScript = preload("res://scripts/boss_bar_top.gd")

var _made: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])


class FakeBoss extends Node2D:
	var is_dead: bool = false
	var health: float = 0.0
	var max_health: float = 0.0
	var item_shield_hp: float = 0.0
	var item_shield_max: float = 0.0


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and (str(c.get_script().resource_path).contains("kardes_") \
				or str(c.get_script().resource_path).contains("enemy_charge_lane")):
			c.free()
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
	return sp


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	_add(p)
	p.global_position = pos
	return p


func _boss(sp: Node, id: String, pos: Vector2, net_id: int) -> Node:
	var b: Node = sp._spawn_creature(id, pos, net_id)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, id, 10, 1)
	b._init_abilities()
	return b


func _kit(b: Node) -> RefCounted:
	return b._abilities._boss_kit


func _nodes(script_part: String) -> Array:
	var out: Array = []
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).contains(script_part):
			out.append(c)
	return out


func _step_kit(kit: RefCounted, player: Node2D, frames: int) -> void:
	for i in range(frames):
		kit.process(1.0 / 60.0, player, 300.0)


func _step_nodes(script_part: String, frames: int) -> void:
	for i in range(frames):
		for n: Node in _nodes(script_part):
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				n._physics_process(1.0 / 60.0)


func test_tables_scenes_and_sheets() -> void:
	assert(KitScript.TRIO_IDS == BossBarArtScript.TRIO_IDS, "kit ve bar aynı kardeş sırası")
	assert(SpawnerScript.NEW_BOSS_TIERS[10] == KitScript.TRIO_IDS, "ana harita K10 = Üç Kardeş")
	for id: String in KitScript.TRIO_IDS:
		var fam: String = id.trim_suffix("1")
		assert(SpawnerScript.SCENES.has(id) and SpawnerScript.ID_FAMILY[id] == fam, "doğuş tabloları: %s" % id)
		assert(AbilitiesScript.family_has_ability(fam), "yetenekli aile: %s" % fam)
		assert(SpawnerScript.BOSS_HOME_TIER[id] == 10 and is_equal_approx(SpawnerScript.boss_slot_damage_mult(id, 10), 1.0), "K10'a göre yazılı hasar")
		var b: Node = (SpawnerScript.SCENES[id] as PackedScene).instantiate()
		_add(b)
		assert(b.cell_size == 64 and b.special_textures.has("cast") and b.special_textures.has("attack"), "özel dokular: %s" % id)
		for tex: Texture2D in [b.walk_texture, b.idle_texture, b.hurt_texture, b.death_texture, b.attack_texture]:
			assert(tex != null and tex.get_height() == 256 and tex.get_width() % 64 == 0, "4 yön x 64 px sayfa: %s" % id)
	assert(BossBarArtScript.display_name("kardes_kilic1") == "KILIÇ KARDEŞ" and BossBarArtScript.TRIO_NAME == "ÜÇ KARDEŞ", "adlar")
	var kilic: Node = (SpawnerScript.SCENES["kardes_kilic1"] as PackedScene).instantiate()
	_add(kilic)
	assert(kilic.special_textures.has("dash") and kilic.special_textures.has("spin") and not kilic.is_ranged, "Kılıç: yakın dövüş + atılma/kasırga sayfaları")
	var ok: Node = (SpawnerScript.SCENES["kardes_ok1"] as PackedScene).instantiate()
	_add(ok)
	assert(ok.is_ranged and ok.ranged_range >= 300.0, "Ok: menzil tutar (vur-kaç)")
	for f: String in ["fx_arrow", "fx_fireball", "fx_fireball_boom", "fx_ice_arrow", "fx_ice_boom", "fx_lightning", "fx_meteor", "fx_ice_spikes", "fx_sword_aoe", "fx_fire_burst"]:
		assert(load("res://assets/enemies/kardesler/%s.png" % f) != null, "efekt dokusu: %s" % f)
	_cleanup()


func test_each_sibling_has_its_share_of_the_pool() -> void:
	var sp: Node = _spawner()
	var total_hp := 0.0
	var total_sh := 0.0
	for i in range(3):
		var b: Node = _boss(sp, KitScript.TRIO_IDS[i], Vector2(200 * i, 0), 777001 + i)
		total_hp += b.max_health
		total_sh += b.item_shield_max
		assert(is_equal_approx(b.shield_protection, 0.9), "soğurma %90")
	assert(is_equal_approx(total_hp, 420000.0) and is_equal_approx(total_sh, 540000.0), "toplam havuz 420.000 / 540.000: %.0f / %.0f" % [total_hp, total_sh])
	var medusa: Dictionary = SpawnerScript.boss_fixed_stats("medusa1", 10)
	assert(total_hp > float(medusa["health"]) and total_sh > float(medusa["shield"]), "en zor boss: Medusa'dan dayanıklı")
	_cleanup()


func test_the_shared_bar_has_three_parts_and_keeps_a_dead_siblings_maximum() -> void:
	var bosses: Array = []
	for i in range(3):
		var b := FakeBoss.new()
		_add(b)
		b.set_meta("creature_id", KitScript.TRIO_IDS[i])
		b.max_health = 100.0
		b.item_shield_max = 50.0
		b.health = [100.0, 50.0, 25.0][i]
		b.item_shield_hp = [50.0, 0.0, 25.0][i]
		bosses.append(b)
	var mem: Dictionary = {}
	var e: Dictionary = BossBarTopScript.trio_entry(bosses, mem)
	assert(e["name"] == "ÜÇ KARDEŞ" and (e["segs"] as Array).size() == 3, "tek ad, 3 parça")
	assert(is_equal_approx(e["segs"][0]["hp"], 1.0) and is_equal_approx(e["segs"][1]["hp"], 0.5) and is_equal_approx(e["segs"][2]["hp"], 0.25), "parça = kardeşin kendi canı")
	assert(is_equal_approx(e["segs"][1]["sh"], 0.0) and is_equal_approx(e["segs"][2]["sh"], 0.5), "parça kalkanı")
	assert(is_equal_approx(e["hp"], 175.0 / 300.0) and e["hp_text"] == "175 / 300", "toplam: %s" % e["hp_text"])
	## Ok Kardeş öldü (düğüm gitti): parçası boş, azami değeri toplamda kalır
	bosses[1].is_dead = true
	e = BossBarTopScript.trio_entry(bosses, mem)
	assert(is_equal_approx(e["segs"][1]["hp"], 0.0) and e["hp_text"] == "125 / 300", "ölen kardeş: %s" % e["hp_text"])
	_cleanup()


func test_a_dying_sibling_enrages_the_others_and_hands_down_its_signature() -> void:
	var sp: Node = _spawner()
	var kb: Node = _boss(sp, "kardes_kilic1", Vector2(0, 0), 777011)
	var ob: Node = _boss(sp, "kardes_ok1", Vector2(300, 0), 777012)
	var bb: Node = _boss(sp, "kardes_buyu1", Vector2(600, 0), 777013)
	var ok_contact: float = ob.contact_damage
	var ok_speed: float = ob.speed
	ob.item_shield_hp = 0.0
	_kit(kb).on_owner_died() ## Kılıç Kardeş öldü
	assert(_kit(ob).rage_level() == 1 and _kit(bb).rage_level() == 1, "kalanlar 1. kademe öfke")
	assert(_kit(ob).inherited() == ["dash"] and _kit(bb).inherited() == ["dash"], "Kılıç'ın atılması devredildi")
	assert(is_equal_approx(ob.contact_damage, ok_contact * 1.25) and is_equal_approx(ob.speed, ok_speed * 1.15), "hasar +%%25, hız +%%15")
	assert(is_equal_approx(ob.item_shield_hp, ob.item_shield_max * KitScript.RAGE_SHIELD_REFILL), "kalkan %35 doldu")
	_kit(ob).on_owner_died() ## Ok Kardeş de öldü: Büyü son kalan
	assert(_kit(bb).rage_level() == 2 and _kit(bb).inherited() == ["dash", "rain"], "son kalan: 2. kademe + iki imza")
	assert(is_equal_approx(_kit(bb)._scaled(100.0), 150.0), "yetenek hasarı x1,5")
	## Büyü Kardeş ölürse kimse kalmaz: çağrı güvenli
	_kit(bb).on_owner_died()
	_cleanup()


func test_blade_sibling_dashes_through_the_player_after_a_lane_warning() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, "kardes_kilic1", Vector2(0, 0), 777021)
	var kit: RefCounted = _kit(b)
	var p: FakePlayer = _player(Vector2(300, 0))
	kit._cd = {"dash": 0.0, "spin": 99.0, "wave": 99.0}
	_step_kit(kit, p, 10)
	assert(not _nodes("enemy_charge_lane").is_empty(), "atılma şeridi uyarısı")
	assert(p.hits.is_empty() and b.global_position.distance_to(Vector2.ZERO) < 1.0, "uyarı sırasında yerinde, hasar yok")
	_step_kit(kit, p, 40) ## uyarı 0,45 sn + 300 px / 1150 px/sn
	assert(p.hits.size() >= 1 and p.hits[0][1] == "kardes_cut", "atılma oyuncuyu kesti: %s" % str(p.hits))
	assert(is_equal_approx(float(p.hits[0][0]), KitScript.DASH_DAMAGE), "atılma hasarı %.0f" % KitScript.DASH_DAMAGE)
	assert(b.global_position.x > 250.0, "boss oyuncunun üstünden geçti: %.0f" % b.global_position.x)
	_cleanup()


func test_blade_whirlwind_hits_nearby_players_after_its_warning() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, "kardes_kilic1", Vector2(0, 0), 777031)
	var kit: RefCounted = _kit(b)
	var near: FakePlayer = _player(Vector2(90, 0))
	kit._cd = {"dash": 99.0, "spin": 0.0, "wave": 99.0}
	_step_kit(kit, near, 1)
	var zones: Array = _nodes("kardes_zone")
	assert(zones.size() == 1 and zones[0].data["style"] == "spin", "kasırga alanı")
	_step_nodes("kardes_zone", 20)
	assert(near.hits.is_empty(), "uyarı süresinde hasar yok")
	_step_nodes("kardes_zone", 30)
	assert(near.hits.size() == 1 and near.hits[0][1] == "kardes_spin" and is_equal_approx(float(near.hits[0][0]), KitScript.SPIN_DAMAGE), "kasırga: %s" % str(near.hits))
	_cleanup()


func test_bow_sibling_fires_a_volley_and_rains_arrows_on_every_player() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, "kardes_ok1", Vector2(0, 0), 777041)
	var kit: RefCounted = _kit(b)
	var p: FakePlayer = _player(Vector2(400, 0))
	kit._cd = {"volley": 0.0, "fan": 99.0, "rain": 99.0, "leap": 99.0}
	_step_kit(kit, p, 1)
	assert(_nodes("kardes_shot").size() == KitScript.VOLLEY_ARROWS, "salvo %d ok: %d" % [KitScript.VOLLEY_ARROWS, _nodes("kardes_shot").size()])
	assert(b._ranged_timer >= 4.0, "C++'ın düz büyü mermisi bastırıldı")
	kit._busy = 0.0
	kit._cd = {"volley": 99.0, "fan": 99.0, "rain": 0.0, "leap": 99.0}
	_step_kit(kit, p, 1)
	var rain: Array = _nodes("kardes_zone")
	assert(rain.size() == KitScript.RAIN_PER_PLAYER, "oyuncu başına %d ok alanı: %d" % [KitScript.RAIN_PER_PLAYER, rain.size()])
	assert(rain[0].global_position.distance_to(p.global_position) < 1.0, "ilk alan tam oyuncunun üstüne")
	_cleanup()


func test_bow_sibling_leaps_away_from_a_close_player() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, "kardes_ok1", Vector2(0, 0), 777051)
	var kit: RefCounted = _kit(b)
	var p: FakePlayer = _player(Vector2(-100, 0))
	kit._cd = {"volley": 99.0, "fan": 99.0, "rain": 99.0, "leap": 0.0}
	_step_kit(kit, p, 30)
	assert(b.global_position.x > 150.0, "oyuncudan uzağa sıçradı: %.0f" % b.global_position.x)
	assert(p.hits.is_empty(), "sıçrama hasarsız")
	_cleanup()


func test_spell_sibling_casts_fireballs_and_a_meteor_shower() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, "kardes_buyu1", Vector2(0, 0), 777061)
	var kit: RefCounted = _kit(b)
	var p: FakePlayer = _player(Vector2(400, 0))
	kit._cd = {"fire": 0.0, "ice": 99.0, "bolt": 99.0, "spike": 99.0, "meteor": 99.0, "blink": 99.0}
	_step_kit(kit, p, 40)
	var shots: Array = _nodes("kardes_shot")
	assert(shots.size() == KitScript.FIRE_COUNT, "%d ateş topu: %d" % [KitScript.FIRE_COUNT, shots.size()])
	assert(shots[0].data["kind"] == "fireball" and float(shots[0].data["splash"]) > 0.0, "yakan ateş topu + patlama alanı")
	for s: Node in shots:
		s.free()
	kit._busy = 0.0
	kit._cd = {"fire": 99.0, "ice": 99.0, "bolt": 99.0, "spike": 99.0, "meteor": 0.0, "blink": 99.0}
	_step_kit(kit, p, 1)
	var zones: Array = _nodes("kardes_zone")
	assert(zones.size() >= 4, "büyük + küçük meteorlar: %d" % zones.size())
	assert(zones[0].data["style"] == "meteor" and is_equal_approx(float(zones[0].damage), KitScript.METEOR_DAMAGE), "büyük meteor %.0f" % KitScript.METEOR_DAMAGE)
	_cleanup()


func test_spell_sibling_blinks_away_from_a_close_player() -> void:
	var sp: Node = _spawner()
	var b: Node = _boss(sp, "kardes_buyu1", Vector2(0, 0), 777071)
	var kit: RefCounted = _kit(b)
	var p: FakePlayer = _player(Vector2(60, 0))
	kit._cd = {"fire": 99.0, "ice": 99.0, "bolt": 99.0, "spike": 99.0, "meteor": 99.0, "blink": 0.0}
	_step_kit(kit, p, 1)
	assert(b.global_position.distance_to(p.global_position) >= KitScript.BLINK_DIST, "ışınlanıp uzaklaştı: %.0f" % b.global_position.distance_to(p.global_position))
	_cleanup()


func test_fireball_hits_once_and_splashes_with_burn() -> void:
	_spawner()
	var p: FakePlayer = _player(Vector2(100, 0))
	var shot: Node = AbilitiesScript.spawn_world_fx(get_tree(), "kardes_shot", Vector2(0, 0),
			{"style": "fireball", "dir": Vector2.RIGHT, "speed": 300.0, "kind": "fireball", "splash": 60.0}, true, null, 120.0)
	for i in range(40):
		if is_instance_valid(shot):
			shot._physics_process(1.0 / 60.0)
	var kinds: Array = []
	var total := 0.0
	for h: Array in p.hits:
		kinds.append(h[1])
		total += float(h[0])
	assert(kinds == ["fireball", "fireball"] and is_equal_approx(total, 180.0), "isabet 120 + patlama 60 (ikisi de yakar): %s" % str(p.hits))
	_cleanup()


func test_endless_wave_spawns_the_trio_whole() -> void:
	assert(SpawnerScript.with_whole_trio(["kardes_ok1"]) == ["kardes_ok1", "kardes_kilic1", "kardes_buyu1"], "bir kardeş seçildiyse üçü")
	assert(SpawnerScript.with_whole_trio(["minotaur1"]) == ["minotaur1"], "kardeşsiz liste aynen")
