extends Node

## Madde 575: yeni havuz (Goblin / Gnoll / Kertenkele Adam / Pelte, her biri 3 kademe) - sahneler, kayıt tabloları, kademe yetenekleri ve iki
## yeni dünya efekti (creature_shot.gd, creature_nova.gd). Yetenek akışı test_early_abilities.gd gibi küçük bir kuklayla sınanır.

const Abilities := preload("res://scripts/enemy_abilities.gd")
const ShotScript := preload("res://scripts/creature_shot.gd")
const NovaScript := preload("res://scripts/creature_nova.gd")
const Spawner := preload("res://scripts/enemy_spawner.gd")
const Timing := preload("res://scripts/creature_attack_timing.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

const IDS := ["goblin1", "goblin2", "goblin3", "gnoll1", "gnoll2", "gnoll3",
	"kertenkele1", "kertenkele2", "kertenkele3", "pelte1", "pelte2", "pelte3"]


class StubEnemy extends Node2D:
	var contact_damage: float = 10.0
	var ability_move_lock: float = 0.0
	var is_dead: bool = false
	var is_raging: bool = false
	var incapacitated: bool = false
	var fam: String = ""
	var alert_calls: int = 0
	var attack_anim_calls: int = 0
	var rage_calls: int = 0
	var vfx: Array = []

	func _has_line_of_sight(_p: Node) -> bool:
		return true

	func _update_facing(_d: Vector2) -> void:
		pass

	func _play_ability_attack_anim() -> void:
		attack_anim_calls += 1

	func show_brush_alert() -> void:
		alert_calls += 1

	func is_incapacitated_now() -> bool:
		return incapacitated

	func apply_knockback_force(_dir: Vector2, _force: float) -> void:
		pass

	func emit_ability_vfx(kind: String, data: Dictionary) -> void:
		vfx.append([kind, data])

	func creature_family() -> String:
		return fam

	func _enter_rage_mode() -> void:
		rage_calls += 1
		is_raging = true


class StubPlayer extends Node2D:
	var is_dead: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _src: Node2D, kind: String) -> void:
		hits.append([amount, kind])


func _make(id: String) -> Array:
	var stub := StubEnemy.new()
	stub.fam = EnemyScript.family_of_id(id)
	stub.set_meta("creature_id", id)
	add_child(stub)
	var ab = Abilities.new()
	ab.setup(stub, stub.fam)
	return [stub, ab]


func test_scenes_load_and_sheets_match() -> void:
	for id: String in IDS:
		var path: String = "res://scenes/creatures/enemy_%s.tscn" % id
		var e: Node = (load(path) as PackedScene).instantiate()
		var spr: Sprite2D = e.get_node("Sprite2D") as Sprite2D
		for prop in ["walk_texture", "hurt_texture", "death_texture", "attack_texture"]:
			var tex: Texture2D = e.get(prop) as Texture2D
			assert(tex != null, "%s %s yüklenmeli" % [id, prop])
			assert(tex.get_height() == 256 and tex.get_width() % 64 == 0, "%s %s 64'lük 4 satır olmalı: %s" % [id, prop, tex.get_size()])
		var walk: Texture2D = e.get("walk_texture")
		assert(spr.hframes == walk.get_width() / 64 and spr.vframes == 4, "%s hframes yürüme sayfasıyla aynı" % id)
		assert(EnemyScript._derive_idle_texture(walk) != null, "%s bekleme (Idle) sayfası bulunmalı" % id)
		var cols: int = (e.get("attack_texture") as Texture2D).get_width() / 64
		var hit: int = Timing.hit_frame(path, cols)
		assert(hit >= 1 and hit < cols, "%s vuruş karesi klipte: %d / %d" % [id, hit, cols])
		e.free()


func test_registered_but_not_spawning_yet() -> void:
	for id: String in IDS:
		assert(Spawner.SCENES.has(id), "%s SCENES'te (debug menüsü) olmalı" % id)
		assert(Spawner.ID_FAMILY.get(id, "") == EnemyScript.family_of_id(id), "%s ID_FAMILY" % id)
		assert(Spawner.FAMILY_MULT.has(EnemyScript.family_of_id(id)), "%s FAMILY_MULT" % id)
		for tier in Spawner.TIER_ROSTER.keys():
			assert(not (Spawner.TIER_ROSTER[tier] as Array).has(id), "%s ANA haritanın doğuş listesinde OLMAMALI (madde 597: haritaya özel havuzlarda Aşama 2'de doğacak)" % id)
		assert(not Spawner.ELITE_BY_TIER.values().has(id), "%s ana haritanın elit tablosunda olmamalı (madde 597: diğer haritalarda Aşama 2'de doğacak)" % id)


func test_ability_per_tier() -> void:
	var expected: Dictionary = {"goblin1": false, "goblin2": true, "goblin3": true, "gnoll1": false, "gnoll2": true, "gnoll3": true,
		"kertenkele1": false, "kertenkele2": true, "kertenkele3": true, "pelte1": true, "pelte2": true, "pelte3": true}
	for id: String in expected.keys():
		var e: Node2D = (load("res://scenes/creatures/enemy_%s.tscn" % id) as PackedScene).instantiate()
		e.set_meta("creature_id", id)
		add_child(e)
		e.call("_init_abilities")
		assert((e.get("_abilities") != null) == bool(expected[id]), "%s yetenek nesnesi: beklenen %s" % [id, expected[id]])
		if e.get("_abilities") != null:
			assert(int(e.get("_abilities")._lvl) == int(id.right(1)), "%s kademe rakamı okunmalı" % id)
		e.free()


func test_shot_throw_and_cooldown() -> void:
	for id: String in ["goblin3", "kertenkele2"]:
		var pair: Array = _make(id)
		var stub: StubEnemy = pair[0]
		var ab = pair[1]
		var player := StubPlayer.new()
		add_child(player)
		player.global_position = Vector2(200, 0)
		ab._cd = 0.0
		ab._entry_delay = 0.0
		ab.process(0.016, player, 200.0)
		assert(stub.attack_anim_calls == 1 and stub.ability_move_lock > 0.0, "%s atışta klip + duraklama" % id)
		assert(ab._cd >= 5.0, "%s bekleme: %s" % [id, ab._cd])
		stub.queue_free()
		player.queue_free()


func test_shot_images() -> void:
	for style: String in ["spear", "spit", "crystal"]:
		var img: Image = ShotScript.build_image(style)
		var solid: int = 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.5:
					solid += 1
		assert(solid > 15, "%s dokusu dolu olmalı: %d" % [style, solid])


func test_shot_damages_only_when_authoritative() -> void:
	var player := StubPlayer.new()
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector2(500, 500)
	for style: String in ["spear", "crystal"]:
		for auth in [true, false]:
			var s := Node2D.new()
			s.set_script(ShotScript)
			s.set("data", {"style": style, "dir": Vector2.RIGHT, "speed": 200.0})
			s.set("authoritative", auth)
			s.set("damage", 6.0)
			add_child(s)
			s.global_position = Vector2(500, 500)
			s._physics_process(0.016)
			assert(s._poof >= 0.0, "%s oyuncuya değince kırılmalı" % style)
			s.queue_free()
	assert(player.hits.size() == 2, "yalnız yetkili kopyalar vurmalı: %s" % [player.hits])
	assert(str(player.hits[0][1]) == "spear" and str(player.hits[1][1]) == "crystal", "hasar türleri: %s" % [player.hits])
	player.remove_from_group("player")
	player.queue_free()


func test_nova_hits_after_warning_once() -> void:
	var player := StubPlayer.new()
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector2(1000, 1000)
	var src := StubEnemy.new()
	add_child(src)
	src.global_position = Vector2(1040, 1000) ## 40 px uzakta (yarıçap 80 içinde)
	var n := Node2D.new()
	n.set_script(NovaScript)
	n.set("data", {"style": "scythe", "warn": 0.3, "radius": 80.0})
	n.set("authoritative", true)
	n.set("source", src)
	n.set("damage", 14.0)
	add_child(n)
	n.global_position = src.global_position
	for i in 10: ## 0,16 sn: hâlâ uyarıda
		n._process(0.016)
	assert(player.hits.is_empty(), "uyarıda hasar yok")
	for i in 30:
		n._process(0.016)
	assert(player.hits.size() == 1 and str(player.hits[0][1]) == "scythe", "patlamada tek isabet: %s" % [player.hits])
	n.queue_free()
	## donmuş sahip: uyarı iptal, hasar yok
	var n2 := Node2D.new()
	n2.set_script(NovaScript)
	n2.set("data", {"style": "fire", "warn": 0.2, "radius": 80.0})
	n2.set("authoritative", true)
	n2.set("source", src)
	n2.set("damage", 9.0)
	add_child(n2)
	n2.global_position = src.global_position
	src.incapacitated = true
	n2._process(0.016)
	assert(n2.is_queued_for_deletion(), "sahibi donan alev halkası iptal olmalı")
	assert(player.hits.size() == 1, "iptal halka vurmaz")
	src.incapacitated = false
	## alev türü "firenova" (yanma)
	var n3 := Node2D.new()
	n3.set_script(NovaScript)
	n3.set("data", {"style": "fire", "warn": 0.0, "radius": 80.0})
	n3.set("authoritative", true)
	n3.set("source", src)
	n3.set("damage", 9.0)
	add_child(n3)
	n3.global_position = src.global_position
	for i in 10:
		n3._process(0.016)
	assert(player.hits.size() == 2 and str(player.hits[1][1]) == "firenova", "alev halkası yakar: %s" % [player.hits])
	n3.queue_free()
	player.remove_from_group("player")
	player.queue_free()
	src.queue_free()


func test_bomb_fuse_explodes_and_pops() -> void:
	var pair: Array = _make("pelte1")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	assert(ab.melee_blocked(), "bombanın düz temas vuruşu yok")
	var player := StubPlayer.new()
	add_child(player)
	ab._cd = 0.0
	ab.process(0.016, player, Abilities.BOMB_TRIGGER + 30.0)
	assert(ab._pending < 0.0, "menzil dışında fitil yanmaz")
	ab._cd = 0.0
	ab.process(0.016, player, 30.0)
	assert(ab._pending > 0.0 and stub.ability_move_lock > 0.0, "yakında fitil yanar ve durur")
	var t: float = 0.0
	while ab._pending >= 0.0 and t < 2.0:
		ab.process(0.016, player, 30.0)
		t += 0.016
	assert(stub.attack_anim_calls == 1, "fitilin sonunda saldırı klibi bir kez")
	assert(stub.vfx.size() == 1 and str(stub.vfx[0][0]) == "boss_event" and str(stub.vfx[0][1].get("k")) == "pop", "patlayınca dağılır: %s" % [stub.vfx])
	assert(absf(t - Abilities.BOMB_FUSE) < 0.05, "fitil süresi: %.2f" % t)
	## fitil sırasında donarsa patlamaz
	var pair2: Array = _make("pelte1")
	var stub2: StubEnemy = pair2[0]
	var ab2 = pair2[1]
	ab2._cd = 0.0
	ab2.process(0.016, player, 30.0)
	stub2.incapacitated = true
	for i in 80:
		ab2.process(0.016, player, 30.0)
	assert(stub2.vfx.is_empty(), "donmuş bomba patlamaz")
	for s in [stub, stub2, player]:
		s.queue_free()


func test_crystal_and_nova_flow() -> void:
	var pair: Array = _make("pelte3")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	player.global_position = Vector2(100, 0)
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, 100.0)
	assert(stub.attack_anim_calls == 1 and ab._pending > 0.0, "kristal: önce klip, sonra saçma")
	for i in 40:
		ab.process(0.016, player, 100.0)
	assert(ab._pending < 0.0 and ab._cd > 4.0, "saçma bitti, bekleme kuruldu")
	var pair2: Array = _make("kertenkele3")
	var stub2: StubEnemy = pair2[0]
	var ab2 = pair2[1]
	ab2._cd = 0.0
	ab2.process(0.016, player, 60.0)
	assert(ab2._pending > 0.0 and stub2.attack_anim_calls == 0, "tırpan: önce uyarı")
	for i in 60:
		ab2.process(0.016, player, 60.0)
	assert(stub2.attack_anim_calls == 1, "uyarı bitince savuruş klibi")
	assert(ab2.quiet_remaining() > 0.0, "beklemede uyuyabilir (sayaç)")
	for s in [stub, stub2, player]:
		s.queue_free()


func test_howl_enrages_only_nearby_gnolls() -> void:
	var pair: Array = _make("gnoll3")
	var howler: StubEnemy = pair[0]
	var ab = pair[1]
	howler.add_to_group("enemies")
	var near_gnoll := StubEnemy.new()
	near_gnoll.fam = "gnoll"
	near_gnoll.add_to_group("enemies")
	add_child(near_gnoll)
	near_gnoll.global_position = Vector2(100, 0)
	var far_gnoll := StubEnemy.new()
	far_gnoll.fam = "gnoll"
	far_gnoll.add_to_group("enemies")
	add_child(far_gnoll)
	far_gnoll.global_position = Vector2(Abilities.HOWL_RADIUS + 200.0, 0)
	var goblin := StubEnemy.new()
	goblin.fam = "goblin"
	goblin.add_to_group("enemies")
	add_child(goblin)
	goblin.global_position = Vector2(50, 0)
	var player := StubPlayer.new()
	add_child(player)
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, 150.0)
	assert(howler.rage_calls == 1 and near_gnoll.rage_calls == 1, "uluyan ve yakın gnoll öfkelenir")
	assert(far_gnoll.rage_calls == 0 and goblin.rage_calls == 0, "uzak gnoll ve başka aile öfkelenmez")
	assert(howler.alert_calls == 1 and ab._cd >= Abilities.HOWL_COOLDOWN_MIN, "uluma uyarısı + bekleme")
	for s in [howler, near_gnoll, far_gnoll, goblin, player]:
		s.queue_free()
