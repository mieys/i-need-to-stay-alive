extends Node

## Madde 597: İblis kademe yetenekleri - iblis1 düz ateş topu (eski), iblis2 "Kor Yağmuru" (creature_nova "ember"), iblis3 "Alev Küreleri"
## (creature_nova "orbs" + sırayla 3 ateş topu). Akış test_new_creature_pool.gd'deki gibi küçük bir kuklayla sınanır.

const Abilities := preload("res://scripts/enemy_abilities.gd")
const NovaScript := preload("res://scripts/creature_nova.gd")
const FireballScript := preload("res://scripts/enemy_fireball.gd")
const EnemyScript := preload("res://scripts/enemy.gd")


class StubEnemy extends Node2D:
	var contact_damage: float = 10.0
	var ability_move_lock: float = 0.0
	var is_dead: bool = false
	var incapacitated: bool = false
	var attack_anim_calls: int = 0

	func _has_line_of_sight(_p: Node) -> bool:
		return true

	func _update_facing(_d: Vector2) -> void:
		pass

	func _play_ability_attack_anim() -> void:
		attack_anim_calls += 1

	func is_incapacitated_now() -> bool:
		return incapacitated


class StubPlayer extends Node2D:
	var is_dead: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _src: Node2D, kind: String) -> void:
		hits.append([amount, kind])


func _make(id: String) -> Array:
	var stub := StubEnemy.new()
	stub.set_meta("creature_id", id)
	add_child(stub)
	var ab = Abilities.new()
	ab.setup(stub, EnemyScript.family_of_id(id))
	return [stub, ab]


## Sahnede (current_scene altında) verilen betikle doğmuş düğümler.
func _spawned(script: Script) -> Array:
	var out: Array = []
	var root: Node = get_tree().current_scene
	if root == null:
		return out
	for c in root.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _clear_spawned() -> void:
	for s in [FireballScript, NovaScript]:
		for n in _spawned(s):
			n.free()


func test_tier_digit_and_family() -> void:
	for i in range(1, 4):
		var id: String = "iblis%d" % i
		assert(EnemyScript.family_of_id(id) == "iblis", "%s ailesi iblis" % id)
		var pair: Array = _make(id)
		assert(int(pair[1]._lvl) == i, "%s kademe rakamı okunmalı" % id)
		(pair[0] as Node).queue_free()


func test_iblis1_still_plain_fireball() -> void:
	_clear_spawned()
	var pair: Array = _make("iblis1")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	player.global_position = Vector2(200, 0)
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, 200.0)
	assert(_spawned(FireballScript).size() == 1, "iblis1 tek ateş topu atar")
	assert(_spawned(NovaScript).is_empty(), "iblis1 kor/küre görseli doğurmaz")
	assert(ab._cd >= Abilities.FIREBALL_COOLDOWN_MIN and ab._pending < 0.0, "iblis1 bekleme: %s" % ab._cd)
	_clear_spawned()
	stub.queue_free()
	player.queue_free()


func test_iblis2_throws_ember_at_target_point() -> void:
	_clear_spawned()
	var pair: Array = _make("iblis2")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	player.global_position = Vector2(220, 40)
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, player.global_position.length())
	var novas: Array = _spawned(NovaScript)
	assert(novas.size() == 1, "iblis2 bir kor topu fırlatır")
	var n: Node2D = novas[0]
	assert(str(n.get("data")["style"]) == "ember", "stil ember")
	assert(n.global_position.distance_to(player.global_position) < 0.5, "hedefin O ANKİ noktasına iner")
	assert(is_equal_approx(float(n.get("damage")), stub.contact_damage * float(Abilities.EMBER["mult"])), "hasar %110")
	assert(stub.attack_anim_calls == 1 and stub.ability_move_lock > 0.0, "atışta klip + kısa duraklama")
	assert(_spawned(FireballScript).is_empty(), "iblis2 düz ateş topu atmaz")
	assert(ab._cd >= float(Abilities.EMBER["cd_min"]), "bekleme kuruldu")
	## çok yakında atmaz (zaten yakın dövüşte)
	_clear_spawned()
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, float(Abilities.EMBER["min"]) - 5.0)
	assert(_spawned(NovaScript).is_empty(), "minimum menzilin içinde atmaz")
	_clear_spawned()
	stub.queue_free()
	player.queue_free()


func test_ember_lands_after_flight_and_burns() -> void:
	var src := StubEnemy.new()
	add_child(src)
	src.global_position = Vector2(1300, 1000)
	var near := StubPlayer.new()
	near.add_to_group("player")
	add_child(near)
	near.global_position = Vector2(1020, 1000) ## inişe 20 px (yarıçap 40 içinde)
	var made: Array = []
	for auth in [true, false]:
		var n := Node2D.new()
		n.set_script(NovaScript)
		n.set("data", {"style": "ember", "warn": 0.3, "radius": 40.0, "from": Vector2(280, -10)})
		n.set("authoritative", auth)
		n.set("source", src)
		n.set("damage", 11.0)
		add_child(n)
		n.global_position = Vector2(1000, 1000)
		made.append(n)
	src.incapacitated = true ## top havadayken iblis dondu: iniş yine olur
	for i in 12: ## 0,19 sn: hâlâ uçuşta
		for n in made:
			n._process(0.016)
	assert(near.hits.is_empty(), "uçuşta hasar yok")
	for n in made:
		assert(not (n as Node).is_queued_for_deletion(), "iblis donsa da kor topu iptal olmaz")
		assert(n.global_position == Vector2(1000, 1000), "iniş noktası sabit (sahibi izlemez)")
	for i in 20:
		for n in made:
			n._process(0.016)
	assert(near.hits.size() == 1, "yalnız yetkili kopya, tek isabet: %s" % [near.hits])
	assert(str(near.hits[0][1]) == "ember" and is_equal_approx(float(near.hits[0][0]), 11.0), "tür ember (yanma): %s" % [near.hits])
	for n in made:
		n.queue_free()
	## yarıçap dışındaki oyuncu vurulmaz
	near.global_position = Vector2(1000 + 40.0 + Abilities.TARGET_BODY_RADIUS + 8.0, 1000)
	var n2 := Node2D.new()
	n2.set_script(NovaScript)
	n2.set("data", {"style": "ember", "warn": 0.05, "radius": 40.0, "from": Vector2(100, 0)})
	n2.set("authoritative", true)
	n2.set("damage", 11.0)
	add_child(n2)
	n2.global_position = Vector2(1000, 1000)
	for i in 10:
		n2._process(0.016)
	assert(near.hits.size() == 1, "yarıçap dışı vurulmaz")
	n2.queue_free()
	near.remove_from_group("player")
	near.queue_free()
	src.queue_free()


func test_iblis3_orbs_fire_three_in_sequence() -> void:
	_clear_spawned()
	var pair: Array = _make("iblis3")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	player.global_position = Vector2(250, 0)
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, 250.0)
	var novas: Array = _spawned(NovaScript)
	assert(novas.size() == 1 and str(novas[0].get("data")["style"]) == "orbs", "önce küre görseli")
	assert(ab._orbs_left == 3 and ab._pending > 0.0, "3 küre bekliyor")
	assert(stub.ability_move_lock > float(Abilities.ORBS["windup"]), "küreler dönerken durur")
	assert(_spawned(FireballScript).is_empty(), "küre dönerken atış yok")
	assert(not ab.process_fast(0.016) and ab.quiet_remaining() < 0.0, "dizi sürerken hızlı yol/uyku yok")
	var times: Array = []
	var t: float = 0.0
	var last: int = 0
	while t < 2.0:
		ab.process(0.016, player, 250.0)
		t += 0.016
		var c: int = _spawned(FireballScript).size()
		if c != last:
			times.append(t)
			last = c
	assert(last == 3, "üç ateş topu: %d" % last)
	assert(absf(float(times[0]) - float(Abilities.ORBS["windup"])) < 0.05, "ilki windup sonunda: %s" % [times])
	assert(absf(float(times[2]) - float(times[0]) - 2.0 * float(Abilities.ORBS["gap"])) < 0.05, "aralık gap: %s" % [times])
	for f in _spawned(FireballScript):
		assert(is_equal_approx(float(f.get("damage")), stub.contact_damage * float(Abilities.ORBS["mult"])), "küre başı %55")
	assert(stub.attack_anim_calls == 1, "ilk atışta saldırı klibi")
	assert(ab._orbs_left == 0 and ab._pending < 0.0 and ab.quiet_remaining() > 0.0, "dizi bitti, beklemede uyuyabilir")
	_clear_spawned()
	stub.queue_free()
	player.queue_free()


func test_iblis3_orbs_cancelled_with_visual() -> void:
	_clear_spawned()
	var pair: Array = _make("iblis3")
	var stub: StubEnemy = pair[0]
	var ab = pair[1]
	var player := StubPlayer.new()
	add_child(player)
	player.global_position = Vector2(250, 0)
	ab._cd = 0.0
	ab._entry_delay = 0.0
	ab.process(0.016, player, 250.0)
	var orbs: Node2D = _spawned(NovaScript)[0]
	## sahibi küreler dönerken dondu: görsel kendini siler (iki taraf aynı kural) -> kalan küreler atılmaz
	stub.incapacitated = true
	orbs._process(0.016)
	assert(orbs.is_queued_for_deletion(), "donan iblisin küreleri söner")
	orbs.free()
	stub.incapacitated = false
	for i in 120:
		ab.process(0.016, player, 250.0)
	assert(_spawned(FireballScript).is_empty(), "iptal edilen küreler atılmaz")
	assert(ab._orbs_left == 0 and ab._pending < 0.0, "dizi sıfırlandı")
	_clear_spawned()
	stub.queue_free()
	player.queue_free()


func test_orbs_visual_follows_owner_and_hides_launched() -> void:
	var src := StubEnemy.new()
	add_child(src)
	src.global_position = Vector2(500, 500)
	var n := Node2D.new()
	n.set_script(NovaScript)
	n.set("data", {"style": "orbs", "warn": 0.5, "first": 0.3, "gap": 0.1, "count": 3})
	n.set("authoritative", true)
	n.set("source", src)
	add_child(n)
	n.global_position = src.global_position
	assert(n.z_index > 0, "küreler iblisin önünde çizilir")
	src.global_position = Vector2(530, 510)
	n._process(0.016)
	assert(n.global_position == src.global_position, "küreler iblisle gider")
	src.is_dead = true
	n._process(0.016)
	assert(n.is_queued_for_deletion(), "iblis ölünce küreler söner")
	n.queue_free()
	src.queue_free()
