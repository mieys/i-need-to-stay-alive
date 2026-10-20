extends Node

## Necromancer yetenek evrimleri (kullanıcı isteği 2026-10-11, skill_evolutions.gd DEFS[11]): Q (iskelet) 4 + final, E (golem) 4 + final,
## R (kafatası) 2 + final. Temel değerler kasıtlı kötüleştirildi (yaratık sınırı 10, iskelet 8 ruh, golem 50 ruh, golemin sersemletmesi yok)
## ve evrimler geri getirir. Kafatasının kendi davranışı: test_necro_skull.gd.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const PlayerScript = preload("res://scripts/player.gd")
const SkullScript = preload("res://scripts/necro_skull.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var hits: Array = []
	var pushes: Array = []
	var taunts: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _area: bool = false) -> void:
		hits.append(amount)

	func apply_skill_push(dir: Vector2, dist: float, _ult: bool = false) -> void:
		pushes.append([dir, dist])

	func apply_taunt(duration: float, taunter: Node2D = null) -> void:
		taunts.append([duration, taunter])


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
	return player


func _fake_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	add_child(e)
	e.global_position = pos
	e.add_to_group("enemies")
	_spawned.append(e)
	return e


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


# ------------------------------------------------------------------ temel değerler + Q

func test_base_values_are_worse_and_evolutions_restore_them() -> void:
	var p: Node = _make_player()
	assert(PlayerScript.NECRO_MAX_ACTIVE_PETS == 10 and PlayerScript.NECRO_SKELETON_SOUL_COST == 8 and PlayerScript.NECRO_GOLEM_SOUL_COST == 50, "yeni temel değerler 10 / 8 / 50")
	assert(p.necro_max_active_pets() == 10 and p.necro_skeleton_soul_cost() == 8 and p.necro_golem_soul_cost() == 50)
	p.apply_skill_evolution("necro_q1", true)
	p.apply_skill_evolution("necro_q2", true)
	p.apply_skill_evolution("necro_e1", true)
	assert(p.necro_max_active_pets() == 20, "Kemik Ordusu: 20")
	assert(p.necro_skeleton_soul_cost() == 5, "Ucuz Ruhlar: 5")
	assert(p.necro_golem_soul_cost() == 35, "Ucuz Golem: 35")
	_cleanup()


func test_skeleton_hp_and_lifetime_evolutions() -> void:
	var p: Node = _make_player()
	var base: Node2D = p._spawn_necro_skeleton(Vector2(1000, 1000))
	p.apply_skill_evolution("necro_q3", true)
	p.apply_skill_evolution("necro_q4", true)
	var evo: Node2D = p._spawn_necro_skeleton(Vector2(1000, 1000))
	assert(absf(evo.max_health - base.max_health * 1.2) < 0.01, "Sert Kemikler: can +%%20 (%f -> %f)" % [base.max_health, evo.max_health])
	assert(absf(evo.lifespan - (base.lifespan + 7.5)) < 0.01, "Dayanıklı Ruhlar: +7,5sn (%f -> %f)" % [base.lifespan, evo.lifespan])
	_cleanup()


func test_skeleton_summon_respects_new_cap_and_cost() -> void:
	var p: Node = _make_player()
	p.necro_souls = 8
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == 0, "taban bedel 8 ruh")
	p.necro_souls = 7
	p._necro_skeleton_cooldown_timer = 0.0
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == 7, "7 ruh yetmez (evrimsiz)")
	for i in 12:
		p._spawn_necro_skeleton(Vector2(1000, 1000))
	p.necro_souls = 99
	p._necro_skeleton_cooldown_timer = 0.0
	var before: int = p.necro_souls
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == before, "10 yaratık sınırında çağrılmaz")
	p.apply_skill_evolution("necro_q1", true)
	p._necro_skeleton_cooldown_timer = 0.0
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == before - 8, "Kemik Ordusu ile sınır 20: çağrılır")
	_cleanup()


func test_q_final_sacrifices_skeletons_for_health_and_shield() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("necro_qf", true)
	p.damage_bonus = 100.0
	p.item_shield_max = 200.0
	p.item_shield_hp = 0.0
	var skeletons: Array = []
	for i in 3:
		skeletons.append(p._spawn_necro_skeleton(Vector2(1000, 1000)))
	p.health = p.max_health * 0.5
	p._process_necro_final_evos(0.016)
	for s in skeletons:
		assert(s.is_dead == false, "can %20 üstündeyken iskeletler tüketilmez")
	p.health = p.max_health * 0.10
	var hp0: float = p.health
	p._process_necro_final_evos(0.016)
	for s in skeletons:
		assert(s.is_dead, "can %20'nin altında tüm iskeletler tüketilir")
	assert(absf((p.health - hp0) - 30.0) < 0.01, "3 iskelet x yüzde 10 x 100 saldırı gücü = 30 can (yenilenen: %f)" % (p.health - hp0))
	assert(absf(p.item_shield_hp - 30.0) < 0.01, "aynı miktarda kalkan: %f" % p.item_shield_hp)
	_cleanup()


func test_q_final_does_not_eat_new_skeleton_until_rearmed() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("necro_qf", true)
	p.damage_bonus = 100.0
	p._spawn_necro_skeleton(Vector2(1000, 1000))
	p.health = p.max_health * 0.05
	p._process_necro_final_evos(0.016)
	var fresh: Node2D = p._spawn_necro_skeleton(Vector2(1000, 1000))
	p.health = p.max_health * 0.05 ## hâlâ düşük
	p._process_necro_final_evos(0.016)
	assert(not fresh.is_dead, "aynı düşük-can döneminde ikinci kez tetiklenmemeli")
	p.health = p.max_health * 0.9
	p._process_necro_final_evos(0.016) ## yeniden kurulur
	p.health = p.max_health * 0.05
	p._process_necro_final_evos(0.016)
	assert(fresh.is_dead, "can yükselip yeniden düşünce tekrar tetiklenir")
	_cleanup()


# ------------------------------------------------------------------ E

func test_golem_has_no_stun_slam_anymore() -> void:
	var p: Node = _make_player()
	var g: Node2D = p._spawn_necro_golem()
	assert(not g.has_method("_process_golem_slam"), "golemin periyodik sersemletmesi kaldırıldı")
	assert(FileAccess.get_file_as_string("res://scripts/golem_pet.gd").find("apply_stun") == -1, "golem kodunda sersemletme kalmamalı")
	_cleanup()


func test_golem_evolutions_hp_size_knockback() -> void:
	var p: Node = _make_player()
	var base: Node2D = p._spawn_necro_golem()
	assert(is_equal_approx(base.size_mult, 1.0) and base.evo_knockback == 0.0)
	p.apply_skill_evolution("necro_e2", true)
	p.apply_skill_evolution("necro_e3", true)
	p.apply_skill_evolution("necro_e4", true)
	var evo: Node2D = p._spawn_necro_golem()
	assert(absf(evo.max_health - base.max_health * 1.3) < 0.01, "Taş Gövde: can +%%30")
	assert(absf(evo.max_shield - base.max_shield * 1.3) < 0.01, "Taş Gövde: kalkan +%%30")
	assert(is_equal_approx(evo.size_mult, 1.2), "Dev Golem: boyut x1.2")
	assert(absf(evo.attack_power - base.attack_power * 1.2) < 0.01, "Dev Golem: hasar +%%20")
	assert(absf(evo.sprite.scale.x - base.sprite.scale.x * 1.2) < 0.001, "Dev Golem: görsel %%20 büyük")
	assert(evo.evo_knockback > 0.0, "Yıkıcı Yumruk: geri itme açık")
	_cleanup()


func test_golem_attack_knocks_back_only_with_evolution() -> void:
	var p: Node = _make_player()
	var g: Node2D = p._spawn_necro_golem()
	var e: FakeEnemy = _fake_enemy(g.global_position + Vector2(40, 0))
	g._focus_target = e
	g._attack_timer = 0.0
	g._process_attack(0.1)
	assert(e.hits.size() == 1, "golem vurmalı")
	assert(e.pushes.is_empty(), "evrimsiz itme yok")
	p.apply_skill_evolution("necro_e2", true)
	var g2: Node2D = p._spawn_necro_golem()
	g2.global_position = g.global_position
	g2._focus_target = e
	g2._attack_timer = 0.0
	g2._process_attack(0.1)
	assert(e.pushes.size() == 1, "Yıkıcı Yumruk: yaratık geri itilmeli")
	assert((e.pushes[0][0] as Vector2).x > 0.0, "golemden uzağa doğru")
	_cleanup()


func test_golem_big_form_hits_wider_area() -> void:
	var p: Node = _make_player()
	var g: Node2D = p._spawn_necro_golem()
	var far: FakeEnemy = _fake_enemy(g.global_position + Vector2(125, 0)) ## taban alan 110, büyük alan 132
	var near: FakeEnemy = _fake_enemy(g.global_position + Vector2(30, 0))
	g._focus_target = near
	g._attack_timer = 0.0
	g._process_attack(0.1)
	assert(far.hits.is_empty(), "taban alanın dışındaki yaratığa vurmaz")
	p.apply_skill_evolution("necro_e4", true)
	var big: Node2D = p._spawn_necro_golem()
	big.global_position = g.global_position
	big._focus_target = near
	big._attack_timer = 0.0
	big._process_attack(0.1)
	assert(far.hits.size() == 1, "Dev Golem: vuruş alanı %20 geniş")
	_cleanup()


func test_e_final_spawns_free_golem_and_taunts_everyone_with_cooldown() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("necro_ef", true)
	var near: FakeEnemy = _fake_enemy(p.global_position + Vector2(200, 0))
	var far_away: FakeEnemy = _fake_enemy(p.global_position + Vector2(5000, 0))
	p.necro_souls = 0
	p.health = p.max_health * 0.5
	p._process_necro_final_evos(0.016)
	assert(get_tree().get_nodes_in_group("player_allies").size() == 0, "can yüksekken golem doğmaz")
	p.health = p.max_health * 0.1
	p._process_necro_final_evos(0.016)
	var golems: Array = get_tree().get_nodes_in_group("player_allies")
	assert(golems.size() == 1, "bedelsiz 1 golem doğmalı (ruh 0)")
	assert(near.taunts.size() == 1 and near.taunts[0][1] == golems[0], "yakındaki yaratık golem tarafından kışkırtılmalı")
	assert(far_away.taunts.is_empty(), "çok uzaktaki yaratıklar istek yağmuru oluşturmasın")
	assert(is_equal_approx(p._necro_ef_cd, PlayerScript.EVO_NECRO_EF_COOLDOWN) and PlayerScript.EVO_NECRO_EF_COOLDOWN == 120.0, "120sn bekleme")
	## bekleme sürerken tekrar düşük canda tetiklenmez
	p.health = p.max_health * 0.9
	p._process_necro_final_evos(0.016)
	p.health = p.max_health * 0.1
	p._process_necro_final_evos(0.016)
	assert(get_tree().get_nodes_in_group("player_allies").size() == 1, "bekleme bitmeden ikinci golem yok")
	p._necro_ef_cd = 0.0
	p._process_necro_final_evos(0.016)
	assert(get_tree().get_nodes_in_group("player_allies").size() == 2, "bekleme bitince (hâlâ düşük canda) tetiklenir")
	_cleanup()


# ------------------------------------------------------------------ R yan etkileri (player tarafı)

func test_passive_skull_exists_only_after_r_unlock_and_r_activates_it() -> void:
	var p: Node = _make_player()
	p.level = 9
	p._process_necro(0.016)
	assert(not is_instance_valid(p._necro_skull), "R açılmadan (10. seviye) pasif kafatası yok")
	p.level = 10
	p._process_necro(0.016)
	assert(is_instance_valid(p._necro_skull), "10. seviyede pasif kafatası doğar")
	assert(not p._necro_skull.is_active())
	p._skill_necro_skull()
	assert(p._necro_skull.is_active(), "R: kafatası aktif (büyük) mod")
	p._end_necro_skull_active()
	assert(not p._necro_skull.is_active(), "R bitince pasife döner")
	if is_instance_valid(p._necro_skull):
		p._necro_skull.free()
	_cleanup()


func test_cursed_enemy_dying_can_become_skeleton() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("necro_rf", true)
	var e: FakeEnemy = _fake_enemy(p.global_position + Vector2(100, 0))
	p._necro_curse_mark(e, 10.0)
	assert(p._necro_curse.size() == 1)
	e.is_dead = true
	p._necro_curse_poll = 0.0
	seed(7)
	## %1 ihtimal: sonuç belirleyici olsun diye aynı ölümü seed'li zarla çok kez dene (tek ölüm = tek zar).
	var spawned: bool = false
	for i in 1500:
		var before: int = p._necro_active_pet_count()
		p._necro_curse_died(e)
		if p._necro_active_pet_count() > before:
			spawned = true
			break
	assert(spawned, "lanetli yaratık ölünce %1 ihtimalle iskelet doğar")
	p._process_necro_curse()
	assert(p._necro_curse.is_empty(), "ölen lanetli kayıttan düşer")
	_cleanup()


func test_curse_expires_without_death() -> void:
	var p: Node = _make_player()
	var e: FakeEnemy = _fake_enemy(p.global_position)
	p._necro_curse_mark(e, 0.0)
	p._necro_curse_poll = 0.0
	await get_tree().create_timer(0.05).timeout
	p._process_necro_curse()
	assert(p._necro_curse.is_empty(), "süresi dolan lanet kaydı temizlenir")
	_cleanup()
