extends Node

## Corvina (Necromancer) kiti 2026-11-16 (kullanıcı onayı): Q = Kemik Savaşçısı, E = Kemik Okçusu, R = Ölüler Ordusu.
## Statlar Corvina'nın saldırı gücünden (NecroArmyMath), görünüm alınan evrim sayısından (rütbe), evrimler skill_evolutions.gd DEFS[11].
## Birlik kareleri: test_necro_units.gd.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const NecroMath := preload("res://scripts/necro_army_math.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var hits: Array = []
	var stuns: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _area: bool = false) -> void:
		hits.append(amount)

	func apply_stun(d: float) -> void:
		stuns.append(d)


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 11
	GameManager.selected_character = int(Characters.DEFS[11]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	player.damage_bonus = 20.0
	player.crit_chance_bonus = -1.0 ## yetenek kritiği kapalı: hasar sayıları kesin
	return player


func _fake_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	add_child(e)
	e.global_position = pos
	e.add_to_group("enemies")
	_spawned.append(e)
	return e


## Doğuş animi bitmiş gibi (yerden kalkarken hasar almaz / vurmaz).
func _ready_unit(u: Node) -> Node:
	u.set("_action", "")
	return u


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for pet in get_tree().get_nodes_in_group("player_allies"):
		if is_instance_valid(pet):
			pet.free()
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


# ------------------------------------------------------------------ kit / metin

func test_kit_ids_and_texts_match_the_new_kit() -> void:
	var d: Dictionary = Characters.DEFS[11]
	assert(int(d["skill"]) == 19 and int(d["skill2"]) == 20 and int(d["skill3"]) == 44, "id'ler aynı kaldı")
	assert(str(d["skill_name"]) == "Kemik Savaşçısı" and str(d["skill2_name"]) == "Kemik Okçusu" and str(d["skill3_name"]) == "Ölüler Ordusu")
	var src: String = (load("res://scripts/player.gd") as GDScript).source_code
	assert(src.contains("20: _skill_necro_summon_archer()"), "E match'i okçu")
	assert(src.contains("44: _skill_necro_army()"), "R match'i ordu")
	assert(not src.contains("_skill_necro_skull") and not src.contains("_skill_necro_summon_golem"), "eski kit kalmadı")


# ------------------------------------------------------------------ bedel / sınır

func test_costs_and_caps_with_evolutions() -> void:
	var p: Node = _make_player()
	assert(p.necro_soul_cost("warrior") == 10 and p.necro_soul_cost("archer") == 6)
	assert(p.necro_unit_cap("warrior") == 5 and p.necro_unit_cap("archer") == 5)
	p.apply_skill_evolution("necro_q1", true)
	p.apply_skill_evolution("necro_q2", true)
	p.apply_skill_evolution("necro_e1", true)
	p.apply_skill_evolution("necro_e2", true)
	assert(p.necro_unit_cap("warrior") == 8 and p.necro_soul_cost("warrior") == 7, "Q1/Q2")
	assert(p.necro_unit_cap("archer") == 8 and p.necro_soul_cost("archer") == 4, "E1/E2")
	_cleanup()


func test_warrior_summon_pays_souls_starts_cooldown_and_respects_cap() -> void:
	var p: Node = _make_player()
	p.necro_souls = 10
	p._skill_necro_summon_warrior()
	assert(p.necro_souls == 0 and p.necro_unit_count("warrior") == 1, "10 ruh -> 1 savaşçı")
	assert(p.get_skill_progress() < 0.01, "Q bekleme süpürmesi başladı")
	p.necro_souls = 99
	p._skill_necro_summon_warrior()
	assert(p.necro_souls == 99, "3 sn beklemede çağrılmaz")
	for i in 6:
		p._necro_skeleton_cooldown_timer = 0.0
		p._skill_necro_summon_warrior()
	assert(p.necro_unit_count("warrior") == 5, "en fazla 5 savaşçı (%d)" % p.necro_unit_count("warrior"))
	assert(p.necro_unit_count("archer") == 0, "okçu sınırı ayrı")
	p.necro_souls = 6
	assert(p._necro_can_summon("archer"), "savaşçılar okçu sınırını doldurmaz")
	_cleanup()


# ------------------------------------------------------------------ AP'den statlar

func test_stats_come_from_attack_power_and_attack_speed() -> void:
	var p: Node = _make_player()
	var w: Node = p._spawn_necro_unit("warrior", Vector2(1000, 1000))
	var a: Node = p._spawn_necro_unit("archer", Vector2(1000, 1000))
	assert(is_equal_approx(w.max_health, 60.0 + 20.0 * 6.0) and is_equal_approx(w.max_shield, 40.0), "savaşçı can/kalkan (AP 20)")
	assert(is_equal_approx(w.attack_power, 8.0), "savaşçı vuruşu AP'nin %40'ı")
	assert(is_equal_approx(a.max_health, 30.0 + 20.0 * 3.0) and is_equal_approx(a.max_shield, 20.0) and is_equal_approx(a.attack_power, 6.0))
	var as_pct: float = p.get_attack_speed_bonus_percent()
	assert(is_equal_approx(w.attack_interval, 0.75 / (1.0 + minf(as_pct * 0.5, 200.0) / 100.0)), "saldırı hızının yarısı")
	assert(is_equal_approx(NecroMath.attack_interval("warrior", 1000.0), 0.75 / 3.0), "bonus üst sınırı +%200")
	_cleanup()


func test_hit_cap_and_shield_absorb() -> void:
	var p: Node = _make_player()
	var w: Node = _ready_unit(p._spawn_necro_unit("warrior", Vector2(1000, 1000)))
	var hp: float = w.health
	var cap: float = w.max_health * 0.15 ## 27 < kalkan 40
	w.take_damage(100000.0)
	assert(is_equal_approx(w.health, hp) and is_equal_approx(w.shield, 40.0 - cap), "tek vuruş %%15 tavanı, önce kalkan")
	w.take_damage(100000.0)
	assert(is_equal_approx(w.shield, 0.0) and is_equal_approx(w.health, hp - (cap - (40.0 - cap))), "kalkan bitince cana (%f)" % w.health)
	_cleanup()


# ------------------------------------------------------------------ rütbe (görünüm)

func test_rank_follows_evolution_count() -> void:
	var p: Node = _make_player()
	var seq_q: Array = [["necro_q1", "armored"], ["necro_q2", "armored"], ["necro_q3", "captain"], ["necro_q4", "captain"], ["necro_qf", "knight"]]
	assert(p.necro_unit_key("warrior") == "common")
	for step in seq_q:
		p.apply_skill_evolution(step[0], true)
		assert(p.necro_unit_key("warrior") == step[1], "%s -> %s (%s)" % [step[0], step[1], p.necro_unit_key("warrior")])
	var seq_e: Array = [["necro_e3", "archer"], ["necro_e1", "ghost_archer"], ["necro_e4", "ghost_archer"], ["necro_ef", "mage"]]
	assert(p.necro_unit_key("archer") == "archer")
	for step in seq_e:
		p.apply_skill_evolution(step[0], true)
		assert(p.necro_unit_key("archer") == step[1], "%s -> %s" % [step[0], step[1]])
	_cleanup()


func test_living_units_reskin_and_get_evolution_stats() -> void:
	var p: Node = _make_player()
	var w: Node = _ready_unit(p._spawn_necro_unit("warrior", Vector2(1000, 1000)))
	var base_hp: float = w.max_health
	p.apply_skill_evolution("necro_q3", true)
	w._poll_rank(1.0)
	assert(w.unit_key == "armored", "1 evrim: Zırhlı")
	assert(is_equal_approx(w.max_health, base_hp * 1.3), "Sert Kemikler +%30 yaşayana da")
	p.apply_skill_evolution("necro_q4", true)
	var fresh: Node = p._spawn_necro_unit("warrior", Vector2(1000, 1000))
	assert(is_equal_approx(fresh.lifespan, 40.0), "Dayanıklı Ruhlar +10 sn")
	var a: Node = p._spawn_necro_unit("archer", Vector2(1000, 1000))
	assert(a.pierce == 0)
	p.apply_skill_evolution("necro_e1", true)
	p.apply_skill_evolution("necro_e4", true)
	a._poll_rank(1.0)
	assert(a.unit_key == "ghost_archer" and a.pierce == 1, "Hayalet Okçu deler")
	assert(is_equal_approx(a.attack_range, 280.0 * 1.25) and is_equal_approx(a.dmg_mult, 1.15), "Kartal Gözü")
	_cleanup()


# ------------------------------------------------------------------ vuruşlar

func test_captain_cleaves_the_arc_and_knight_super_stuns_around() -> void:
	var p: Node = _make_player()
	var w: Node = _ready_unit(p._spawn_necro_unit("warrior", Vector2(1000, 1000)))
	var front_a: FakeEnemy = _fake_enemy(Vector2(1040, 1000))
	var front_b: FakeEnemy = _fake_enemy(Vector2(1035, 1018))
	var behind: FakeEnemy = _fake_enemy(Vector2(960, 1000))
	w.set_unit("captain")
	w._strike_target = front_a
	w._strike_anim = "attack"
	w._do_strike()
	assert(front_a.hits.size() == 1 and front_b.hits.size() == 1, "Yüzbaşı yaydaki ikisine de vurur")
	assert(behind.hits.is_empty(), "arkadakine vurmaz")
	w.set_unit("knight")
	w._strike_anim = "attack3"
	w._do_strike()
	assert(behind.hits.size() == 1 and behind.stuns.size() == 1, "Super çevresindeki herkese + sersemletme")
	assert(is_equal_approx(float(behind.hits[0]), 20.0 * 0.8), "Super AP'nin %80'i")
	_cleanup()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Uçtan uca (gerçek kareler): doğuş animi -> saldırı animi -> vuruş karesi -> hasar; okçuda ok gerçekten uçup vurur.
func test_warrior_and_archer_really_hit_over_frames() -> void:
	var p: Node = _make_player()
	var near: FakeEnemy = _fake_enemy(Vector2(1030, 1000))
	p._spawn_necro_unit("warrior", Vector2(1000, 1000))
	await _frames(150)
	assert(near.hits.size() >= 1, "savaşçı vuruyor (%d)" % near.hits.size())
	_cleanup()
	p = _make_player()
	var far: FakeEnemy = _fake_enemy(Vector2(1180, 1000))
	p._spawn_necro_unit("archer", Vector2(1000, 1000))
	await _frames(150)
	assert(far.hits.size() >= 1, "okçunun oku vuruyor (%d)" % far.hits.size())
	assert(is_equal_approx(float(far.hits[0]), 20.0 * 0.3), "ok AP'nin %30'u")
	_cleanup()


# ------------------------------------------------------------------ R ordusu

func test_army_size_composition_and_commander_refund() -> void:
	var p: Node = _make_player()
	p._skill_necro_army()
	var keys: Array = p._necro_army.map(func(u): return u.unit_key)
	assert(keys.size() == 12, "12 asker (%d)" % keys.size())
	assert(keys.count("captain") == 1 and keys.count("armored") == 3 and keys.count("common") == 8, str(keys)) ## 2026-11-16: hayalet kostüm yok
	assert(p.necro_unit_count("warrior") == 0, "ordu sınıra sayılmaz")
	p._necro_end_army(true)
	assert(p._necro_army.is_empty())
	p.apply_skill_evolution("necro_r1", true)
	p.apply_skill_evolution("necro_r2", true)
	p.apply_skill_evolution("necro_rf", true)
	p.necro_souls = 0
	p._skill_necro_army()
	assert(p._necro_army.size() == 19, "18 asker + komutan (%d)" % p._necro_army.size())
	assert(p.necro_commander_alive() and is_equal_approx(p._necro_army_timer, 30.0)) ## R2 2026-11-16: 15 -> 30
	p._process_necro_army(31.0)
	assert(p.necro_souls == 18, "hayatta kalan her asker 1 ruh (%d)" % p.necro_souls)
	_cleanup()


# ------------------------------------------------------------------ Kemik Büyücüsü diriltmesi

func test_mage_reborn_records_only_killed_units() -> void:
	var p: Node = _make_player()
	var w: Node = p._spawn_necro_unit("warrior", Vector2(1100, 1000))
	w._die()
	assert(p._necro_fallen.is_empty(), "final yokken kayıt tutulmaz")
	p.apply_skill_evolution("necro_ef", true)
	var w2: Node = p._spawn_necro_unit("warrior", Vector2(1100, 1000))
	w2._expire()
	assert(p._necro_fallen.is_empty(), "ömrü dolan diriltilmez")
	var w3: Node = p._spawn_necro_unit("warrior", Vector2(1100, 1000))
	w3._die()
	assert(p._necro_fallen.size() == 1)
	assert(p.necro_take_fallen(Vector2(2000, 2000), 100.0).is_empty(), "uzaktaki kayıt alınmaz")
	var rec: Dictionary = p.necro_take_fallen(Vector2(1000, 1000), 320.0)
	assert(str(rec.get("kind", "")) == "warrior" and p._necro_fallen.is_empty())
	var before: int = p.necro_unit_count("warrior")
	p.necro_reborn(rec)
	assert(p.necro_unit_count("warrior") == before + 1, "aynı türde geri döner")
	_cleanup()


# ------------------------------------------------------------------ E / R tekrar kullanılabilir (2026-11-16)

## Kullanıcı: "Necromancerın E sinde ve R sinde sorun var bikere kullanınca bidaha kullanılamıyor". E (20) ve R (44) aktif süresi 0:
## standart makine "active"te sayaç 0 iken hiç ilerlemiyordu -> bekleme/hazır olmuyordu.
func test_e_and_r_become_ready_again() -> void:
	var p: Node = _make_player()
	p.necro_souls = 100
	p.item_shield_max = 500.0
	p.item_shield_hp = 500.0
	p._activate_skill2()
	assert(p.necro_unit_count("archer") == 1, "ilk okçu (id %d, durum %s)" % [p.get_skill2_id(), p.skill2_state])
	for i in 30:
		p._process_skill2(0.05)
	assert(p.skill2_state == "ready", "E bekleme sonrası hazır olmalı (%s, %.2f)" % [p.skill2_state, p.skill2_timer])
	p._activate_skill2()
	assert(p.necro_unit_count("archer") == 2, "ikinci okçu")
	p._activate_skill3()
	assert(not p._necro_army.is_empty(), "ordu çağrıldı")
	assert(p.skill3_state == "cooldown", "R hemen beklemeye girmeli (%s)" % p.skill3_state)
	for i in 61:
		p._process_skill3(1.0)
	assert(p.skill3_state == "ready", "R 60 sn sonra hazır (%s, %.2f)" % [p.skill3_state, p.skill3_timer])
	_cleanup()
