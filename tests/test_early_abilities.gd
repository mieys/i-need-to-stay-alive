extends Node

## Madde 368: erken oyun yetenekleri - İskelet "Kemik Atışı", Zombi "Atılış", Slime "Sıçrama" (enemy_abilities.gd) + kemik mermisi (enemy_bone.gd).
## Yaratık yerine küçük bir kuklayla sınanır (yetenek sınıfı yalnız sahibinin birkaç alanına/metoduna dokunur).

const Abilities := preload("res://scripts/enemy_abilities.gd")
const BoneScript := preload("res://scripts/enemy_bone.gd")


class StubEnemy extends Node2D:
	var contact_damage: float = 10.0
	var ability_move_lock: float = 0.0
	var is_dead: bool = false
	var incapacitated: bool = false
	var alert_calls: int = 0
	var attack_anim_calls: int = 0
	var knock: Array = [] ## [yön, güç]

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

	func apply_knockback_force(dir: Vector2, force: float) -> void:
		knock.append([dir, force])


class StubPlayer extends Node2D:
	var is_dead: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _src: Node2D, kind: String) -> void:
		hits.append([amount, kind])


func _make(fam: String) -> Array:
	var stub := StubEnemy.new()
	add_child(stub)
	var ab = Abilities.new()
	ab.setup(stub, fam)
	return [stub, ab]


func test_families_have_abilities() -> void:
	for fam in ["iskelet", "zombie", "slime"]:
		assert(Abilities.family_has_ability(fam), "%s ailesinin yeteneği olmalı" % fam)


## 2026-10-24: 1. seviye slime (sıçrama) ve 1. seviye iskelet (kemik atışı) yeteneksiz; aynı ailenin üst seviyeleri yeteneğini korur.
func test_level_one_slime_and_skeleton_have_no_ability() -> void:
	var expected: Dictionary = {"slime1": false, "iskelet1": false, "slime2": true, "iskelet2": true, "zombie1": true}
	for id: String in expected.keys():
		var e: Node2D = (load("res://scenes/creatures/enemy_%s.tscn" % id) as PackedScene).instantiate()
		e.set_meta("creature_id", id)
		add_child(e)
		e.call("_init_abilities")
		assert((e.get("_abilities") != null) == bool(expected[id]), "%s yetenek nesnesi: beklenen %s" % [id, expected[id]])
		e.free()


func test_lunge_telegraphs_then_pushes_toward_target() -> void:
	var pair: Array = _make("zombie")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	player.global_position = Vector2(150, 0)
	stub.global_position = Vector2.ZERO
	ab._cd = 0.0
	ab.process(0.016, player, 150.0)
	assert(ab._pending > 0.0, "uyarı duraklaması başlamalı")
	assert(stub.ability_move_lock > 0.0, "duraklama sırasında hareket kilidi")
	assert(stub.alert_calls == 1, "zombide '!' göstergesi 1 kez")
	assert(not ab.process_fast(0.016), "duraklama sürerken hızlı yol kapalı (itki zamanını process verir)")
	assert(ab.quiet_remaining() < 0.0, "duraklama sürerken uyutulmaz")
	assert(stub.knock.is_empty(), "duraklama bitmeden itki yok")
	ab.process(0.6, player, 150.0) ## 0,5 sn uyarı doldu
	assert(stub.knock.size() == 1, "uyarı bitince ilk itki")
	var dir: Vector2 = stub.knock[0][0]
	assert(dir.dot(Vector2.RIGHT) > 0.99, "itki oyuncuya doğru: %s" % dir)
	assert(is_equal_approx(float(stub.knock[0][1]), 400.0), "zombi atılış gücü (C++ hız tavanı 400)")
	assert(is_zero_approx(stub.ability_move_lock), "itkiden önce kilit kalkmış olmalı")
	assert(ab._cd >= 8.0 and ab._cd <= 11.0, "bekleme yeniden kurulmalı: %s" % ab._cd)
	## İtki evresi: C++ geri itme hızı 400'de kırpılır, mesafe için thrust süresince her karede itki verilir.
	assert(ab._thrust_left > 0.0, "itki evresi başlamalı")
	assert(not ab.process_fast(0.016) and ab.quiet_remaining() < 0.0, "itki sürerken hızlı yol kapalı ve uyutulmaz")
	ab.process(0.05, player, 150.0)
	ab.process(0.05, player, 150.0)
	assert(stub.knock.size() == 3, "itki evresinde her karede itki: %d" % stub.knock.size())
	ab.process(0.2, player, 150.0) ## evre biter
	assert(ab._thrust_left <= 0.0, "itki evresi bitmeli")
	assert(ab.process_fast(0.016), "bekleme sürerken hızlı yol açık")
	stub.queue_free()
	player.queue_free()


func test_lunge_needs_range_and_is_cancelled_when_disabled() -> void:
	var pair: Array = _make("slime")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	ab._cd = 0.0
	ab.process(0.016, player, 900.0) ## çok uzak
	assert(ab._pending < 0.0 and ab._cd > 0.0 and ab._cd <= 0.3 + 0.001, "menzil dışında kısa yeniden bakma: %s" % ab._cd)
	ab._cd = 0.0
	ab.process(0.016, player, 10.0) ## çok yakın
	assert(ab._pending < 0.0, "çok yakınken sıçramaz")
	ab._cd = 0.0
	ab.process(0.016, player, 120.0)
	assert(ab._pending > 0.0, "menzilde sıçrama başlar")
	assert(stub.alert_calls == 0, "slime '!' göstermez (kalabalık gürültüsü)")
	stub.incapacitated = true ## uyarı sırasında donarsa
	ab.process(0.5, player, 120.0)
	assert(stub.knock.is_empty(), "donmuş yaratık itki vermemeli")
	stub.queue_free()
	player.queue_free()


func test_lunge_countdown_is_dormancy_safe() -> void:
	var pair: Array = _make("zombie")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	ab._cd = 5.0
	assert(is_equal_approx(ab.quiet_remaining(), 5.0), "sessiz sayaç _cd olmalı")
	ab.fast_forward(2.0)
	assert(is_equal_approx(ab._cd, 3.0), "uyku atlaması sayacı düşürmeli")
	stub.queue_free()


func test_bone_throw_sets_cooldown_and_pauses() -> void:
	var pair: Array = _make("iskelet")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	ab._cd = 0.0
	ab._entry_delay = 0.0 ## giriş gecikmesi dolmuş say
	ab.process(0.016, player, 200.0)
	assert(stub.attack_anim_calls == 1, "atış animasyonu oynamalı")
	assert(stub.ability_move_lock > 0.0, "atışta kısa duraklama")
	assert(ab._cd >= Abilities.BONE_COOLDOWN_MIN and ab._cd <= Abilities.BONE_COOLDOWN_MAX, "bekleme: %s" % ab._cd)
	## menzil dışında atış yok
	ab._cd = 0.0
	stub.attack_anim_calls = 0
	ab.process(0.016, player, Abilities.BONE_RANGE + 50.0)
	assert(stub.attack_anim_calls == 0, "menzil dışında fırlatmaz")
	stub.queue_free()
	player.queue_free()


func test_bone_image_and_texture() -> void:
	var img: Image = BoneScript.build_image()
	assert(img.get_width() == 16 and img.get_height() == 10, "kemik dokusu boyutu: %s" % img.get_size())
	var cream: int = 0
	var dark: int = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.8:
				cream += 1
			elif c.a > 0.5:
				dark += 1
	assert(cream > 20 and dark > 20, "krem dolgu ve koyu kontür olmalı: %d / %d" % [cream, dark])


func test_bone_damages_player_only_when_authoritative() -> void:
	var player := StubPlayer.new()
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector2(500, 500)
	for auth in [true, false]:
		var bone := Node2D.new()
		bone.set_script(BoneScript)
		bone.set("data", {"dir": Vector2.RIGHT, "speed": 190.0})
		bone.set("authoritative", auth)
		bone.set("source", null)
		bone.set("damage", 7.0)
		bone.position = Vector2(500, 500)
		add_child(bone)
		bone.global_position = Vector2(500, 500)
		bone._physics_process(0.016)
		assert(bone._poof >= 0.0, "oyuncuya değen kemik kırılmalı (yetkili=%s)" % auth)
		bone.queue_free()
	assert(player.hits.size() == 1, "yalnız yetkili kopya hasar vermeli, bulunan: %d" % player.hits.size())
	assert(is_equal_approx(float(player.hits[0][0]), 7.0) and str(player.hits[0][1]) == "bone", "hasar miktarı ve türü: %s" % [player.hits])
	player.queue_free()


## Gerçek C++ EnemyWorld fiziğiyle: atılış / sıçrama itki dizisi (kare başına apply_knockback_force, toplam hız 400'de kırpılır) gerçekten
## beklenen yolu aldırır mı? Tek itki ~57 px; zombi atılışı (0,16 sn itki) ~110-135 px, slime sıçraması (0,06 sn) ~70-90 px olmalı.
func _thrust_distance(thrust: float, force: float) -> float:
	var w: Object = ClassDB.instantiate("EnemyWorld")
	var gw: int = 64
	var b := PackedByteArray()
	b.resize(gw * gw)
	w.call("set_grid", b, Vector2i.ZERO, Vector2i(gw, gw), 16.0, Vector2.ZERO)
	w.call("set_seed", 7)
	w.call("set_targets", PackedVector2Array([Vector2(100, 500)]), PackedInt32Array([0]), PackedByteArray([1]), PackedByteArray([0]),
		PackedFloat32Array([12.0]), PackedFloat32Array([0.0]), PackedInt64Array([1]))
	var s: int = int(w.call("add_enemy", null, null, Vector2(500, 500), {"radius": 14.0, "speed": 0.0, "contact_interval": 1.0}))
	for i in 2:
		w.call("step", 1.0 / 60.0)
	var x0: float = (w.call("get_position", s) as Vector2).x
	var frames: int = int(round(thrust * 60.0))
	w.call("apply_knockback_force", s, Vector2.RIGHT, force)
	for i in frames:
		w.call("step", 1.0 / 60.0)
		w.call("apply_knockback_force", s, Vector2.RIGHT, force)
	for i in 90: ## kalan ivme sönene kadar
		w.call("step", 1.0 / 60.0)
	return (w.call("get_position", s) as Vector2).x - x0


func test_thrust_distances_with_the_real_enemy_world() -> void:
	if not ClassDB.class_exists("EnemyWorld"):
		return
	var zd: float = _thrust_distance(float(Abilities.ZOMBIE_LUNGE["thrust"]), float(Abilities.ZOMBIE_LUNGE["force"]))
	var sd: float = _thrust_distance(float(Abilities.SLIME_HOP["thrust"]), float(Abilities.SLIME_HOP["force"]))
	assert(zd > 100.0 and zd < 150.0, "zombi atılışı yolu 100-150 px olmalı: %.1f" % zd)
	assert(sd > 60.0 and sd < 100.0, "slime sıçraması yolu 60-100 px olmalı: %.1f" % sd)
	assert(zd > sd + 20.0, "atılış sıçramadan belirgin uzun olmalı: %.1f / %.1f" % [zd, sd])
