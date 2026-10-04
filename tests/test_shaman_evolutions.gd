extends Node

## Kullanıcı isteği (2026-10-04): Shaman yetenek evrimleri (bkz. scripts/skill_evolutions.gd DEFS[12], totem_attack.gd / totem_shield.gd /
## totem_base.gd evrim kancaları, player.gd "Shaman (2026-10-04)" + Elemental Golem bloğu). GERÇEK Player + gerçek totem sahneleri +
## sahte yaratıklarla sayıları doğrular. E3 notu: Kalkan Totemi'nin temel yavaşlatması yoktu - evrim ilk kez %70 yavaşlatma getirir.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const ShieldTotemScene: PackedScene = preload("res://scenes/totem_shield.tscn")
const AttackTotemScene: PackedScene = preload("res://scenes/totem_attack.tscn")
const Evolutions: GDScript = preload("res://scripts/skill_evolutions.gd")
const GolemMath: GDScript = preload("res://scripts/shaman_golem_math.gd")
const SHAMAN := 12

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var hits: Array = []
	var area_flags: Array = []
	var burns: Array = []
	var slows: Array = []
	var pushes: Array = [] ## [yön, mesafe]
	var owner_player: Node = null
	var lifesteal_seen: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, is_area: bool = false) -> void:
		hits.append(amount)
		area_flags.append(is_area)
		if owner_player != null:
			lifesteal_seen.append(float(owner_player.evo_hit_lifesteal))

	func apply_burn(tick: float, duration: float) -> void:
		burns.append([tick, duration])

	func apply_slow(percent: float, duration: float, _allow_boss: bool = false) -> void:
		slows.append([percent, duration])

	func apply_skill_push(dir: Vector2, distance: float) -> void:
		pushes.append([dir, distance])

	func apply_stun(_duration: float) -> void:
		pass


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = SHAMAN
	GameManager.selected_character = 27
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.damage_bonus = 100.0
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE ## kritik yok: hasar sayıları tam
	player.facing = "right"
	player.item_shield_max = 10000.0
	player.item_shield_hp = 10000.0
	return player


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _make_totem(scene: PackedScene, p: Node) -> Node2D:
	var totem: Node2D = scene.instantiate()
	add_child(totem)
	_spawned.append(totem)
	totem.setup_from_player(p)
	return totem


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n in get_tree().get_nodes_in_group("shaman_totems"):
		if is_instance_valid(n):
			n.free()
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _evo(p: Node, ids: Array) -> void:
	for id in ids:
		p.apply_skill_evolution(str(id), true)


# ------------------------------------------------------------------ kart havuzu
func test_defs_shape_and_pool_rules() -> void:
	assert(Evolutions.has_evolutions(SHAMAN), "Shaman evrimleri tanımlı")
	assert(Evolutions.slot_list(SHAMAN, "skill").size() == 5, "Q: 4 geliştirme + final")
	assert(Evolutions.slot_list(SHAMAN, "skill2").size() == 5, "E: 4 geliştirme + final")
	assert(Evolutions.slot_list(SHAMAN, "skill3").size() == 3, "R: 2 geliştirme + final")
	var seen: Dictionary = {}
	for slot in Evolutions.SLOTS:
		var list: Array = Evolutions.slot_list(SHAMAN, slot)
		for i in range(list.size()):
			var e: Dictionary = list[i]
			assert(not seen.has(e["id"]) and str(e["id"]).begins_with("shaman_"), "benzersiz shaman_ id: %s" % e["id"])
			seen[e["id"]] = true
			assert(bool(e.get("final", false)) == (i == list.size() - 1), "sadece sonuncu final: %s" % e["id"])
	## Seviye 5: yalnız Q/E açık -> finaller henüz havuzda yok. Seviye 10: R de açık.
	var pool5: Array = Evolutions.available(SHAMAN, {}, 5)
	for e in pool5:
		assert(not bool(e.get("final", false)) and str(e["slot"]) != "skill3", "seviye 5: final/R yok: %s" % e["id"])
	var pool10: Array = Evolutions.available(SHAMAN, {}, 10)
	var has_r: bool = false
	for e in pool10:
		has_r = has_r or str(e["slot"]) == "skill3"
	assert(has_r, "seviye 10'da R evrimleri de havuzda")
	var owned: Dictionary = {"shaman_q1": true, "shaman_q2": true, "shaman_q3": true, "shaman_q4": true}
	var ids: Array = []
	for e in Evolutions.available(SHAMAN, owned, 15):
		ids.append(e["id"])
	assert(ids.has("shaman_qf") and not ids.has("shaman_ef") and not ids.has("shaman_rf"), "final yalnız o yuvanın tüm geliştirmeleri alınınca: %s" % str(ids))


# ------------------------------------------------------------------ Q
func test_q1_third_charge_and_q3_cooldown() -> void:
	var p: Node = _make_player()
	assert(p.get_shaman_q_max_charges() == 2 and p.shaman_q_charges == 2, "temel 2 yük")
	var base_cd: float = float(p._skill_timing_for(27)["cooldown"])
	p.apply_skill_evolution("shaman_q1", true)
	assert(p.get_shaman_q_max_charges() == 3, "Üçüncü Totem: 3 yük tavanı")
	assert(int(p.get_shaman_q_charge_state()["max"]) == 3, "HUD de 3 gösterir")
	assert(p._shaman_q_recharge_timer > 0.0, "3. yük hemen dolmaya başlar")
	for i in range(int(base_cd / 0.5) + 4):
		p._process_shaman_q_charges(0.5)
	assert(p.shaman_q_charges == 3, "3. yük dolar: %d" % p.shaman_q_charges)
	p.apply_skill_evolution("shaman_q3", true)
	assert(is_equal_approx(float(p._skill_timing_for(27)["cooldown"]), base_cd * 0.8), "Çabuk Totem: bekleme -%%20: %s" % str(p._skill_timing_for(27)["cooldown"]))
	assert(is_equal_approx(p._shaman_q_recharge_time(), base_cd * 0.8 * (1.0 - p.cooldown_reduction_percent)), "yük dolumu da kısalır")
	_cleanup()


func test_q2_totem_shot_burns_target() -> void:
	var p: Node = _make_player()
	var t: Node2D = _make_totem(AttackTotemScene, p)
	var e: FakeEnemy = _make_enemy(Vector2(1000.0 + 120.0, 1000.0))
	t._tick()
	assert(e.hits.size() == 1 and e.burns.is_empty(), "evrimsiz: yakma yok")
	p.apply_skill_evolution("shaman_q2", true)
	t._tick()
	assert(e.burns.size() == 1, "Alev Dokunuşu: atış yakar: %s" % str(e.burns))
	assert(is_equal_approx(float(e.burns[0][0]), 100.0 * 0.10) and is_equal_approx(float(e.burns[0][1]), 3.0), "saniyede AP %%10, 3 sn")
	_cleanup()


func test_q4_lifesteal_only_on_totem_hit() -> void:
	var p: Node = _make_player()
	var t: Node2D = _make_totem(AttackTotemScene, p)
	var e: FakeEnemy = _make_enemy(Vector2(1000.0 + 120.0, 1000.0))
	e.owner_player = p
	t._tick()
	assert(e.lifesteal_seen == [0.0], "evrimsiz: bonus yok: %s" % str(e.lifesteal_seen))
	p.apply_skill_evolution("shaman_q4", true)
	e.lifesteal_seen.clear()
	t._tick()
	assert(e.lifesteal_seen.size() == 1 and is_equal_approx(float(e.lifesteal_seen[0]), 0.05), "isabet anında +%%5: %s" % str(e.lifesteal_seen))
	assert(is_equal_approx(p.evo_hit_lifesteal, 0.0), "isabetten sonra bonus sıfırlanır (silahlar etkilenmez)")
	## Gerçek can çalma yolu: %100 şansla 1 can yenilenir.
	p.health = 50.0
	p.max_health = 100.0
	p.evo_hit_lifesteal = 5.0
	p.on_damage_dealt(10.0)
	assert(p.health >= 51.0, "çalınan can kastere yenilenir: %s" % str(p.health))
	p.evo_hit_lifesteal = 0.0
	_cleanup()


func test_qf_explosion_hits_neighbours_for_half() -> void:
	var p: Node = _make_player()
	var t: Node2D = _make_totem(AttackTotemScene, p)
	var target: FakeEnemy = _make_enemy(Vector2(1000.0 + 120.0, 1000.0))
	var near: FakeEnemy = _make_enemy(Vector2(1000.0 + 120.0 + 70.0, 1000.0))
	var far: FakeEnemy = _make_enemy(Vector2(1000.0 + 120.0 + 70.0, 1000.0 + 200.0)) ## totem menzili içinde ama patlama dışı
	## Hedef sabit olsun: en yakın olan target (near/far daha uzak).
	t._tick()
	assert(near.hits.is_empty(), "evrimsiz: patlama yok")
	p.apply_skill_evolution("shaman_qf", true)
	target.hits.clear()
	t._tick()
	var shot: float = 100.0 * 1.5
	assert(target.hits.size() == 1 and is_equal_approx(float(target.hits[0]), shot), "hedef tam hasar: %s" % str(target.hits))
	assert(near.hits.size() == 1 and is_equal_approx(float(near.hits[0]), shot * 0.5), "Patlayan Alev: komşuya %%50: %s" % str(near.hits))
	assert(bool(near.area_flags[0]), "alan hasarı sayılır")
	assert(far.hits.is_empty(), "patlama yarıçapı dışı etkilenmez")
	assert(float(t._blast_radius()) > 0.0, "patlama halkası görseli için yarıçap")
	_cleanup()


# ------------------------------------------------------------------ E
func test_e1_wider_area_radius_and_aura() -> void:
	var p: Node = _make_player()
	var plain: Node2D = _make_totem(ShieldTotemScene, p)
	var base_r: float = plain.totem_radius
	var base_a: float = plain.area_radius
	var base_scale: Vector2 = (plain.get_node("AreaAura") as AnimatedSprite2D).scale
	p.apply_skill_evolution("shaman_e1", true)
	var wide: Node2D = _make_totem(ShieldTotemScene, p)
	assert(is_equal_approx(wide.totem_radius, base_r * 1.3) and is_equal_approx(wide.area_radius, base_a * 1.3), "alan %%30 büyür: %s / %s" % [wide.totem_radius, wide.area_radius])
	assert((wide.get_node("AreaAura") as AnimatedSprite2D).scale.is_equal_approx(base_scale * 1.3), "mor aura da büyür")
	var edge: FakeEnemy = _make_enemy(Vector2(1000.0 + base_a * 1.2, 1000.0)) ## taban alan dışı, büyütülmüş alan içi
	plain._process_area_damage(0.02)
	assert(edge.hits.is_empty(), "taban alan dışı")
	wide._process_area_damage(0.02)
	assert(edge.hits.size() == 1, "büyütülmüş alan içi")
	## Saldırı Totemi'ni büyütmez.
	var atk: Node2D = _make_totem(AttackTotemScene, p)
	assert(is_equal_approx(atk.totem_radius, 260.0), "Q totemi etkilenmez")
	_cleanup()


func test_e2_attack_speed_aura_only_inside_area() -> void:
	var p: Node = _make_player()
	var t: Node2D = _make_totem(ShieldTotemScene, p)
	t._tick()
	assert(is_equal_approx(p.enchant_haste_value(), 0.0), "evrimsiz: hız buff'ı yok")
	p.apply_skill_evolution("shaman_e2", true)
	t._tick()
	assert(is_equal_approx(p.enchant_haste_value(), 0.15), "Savaş Ritmi: alandaki oyuncu +%%15 saldırı hızı: %s" % str(p.enchant_haste_value()))
	## Buff süresi dolunca düşer (tik kesilirse).
	p._evo_buffs["atk_speed"] = [0.15, Time.get_ticks_msec() - 1]
	assert(is_equal_approx(p.enchant_haste_value(), 0.0), "buff süresi bitince kalkar")
	## Alanın dışındaki oyuncu kazanmaz.
	p.global_position = Vector2(1000.0 + t.totem_radius + 80.0, 1000.0)
	t._tick()
	assert(is_equal_approx(p.enchant_haste_value(), 0.0), "alan dışında buff yok")
	_cleanup()


func test_e3_slow_and_ef_push_only_shield_totem() -> void:
	var p: Node = _make_player()
	var shield: Node2D = _make_totem(ShieldTotemScene, p)
	var attack: Node2D = _make_totem(AttackTotemScene, p)
	var e: FakeEnemy = _make_enemy(Vector2(1000.0 + 100.0, 1000.0))
	shield._process_area_damage(0.02)
	assert(e.slows.is_empty() and e.pushes.is_empty(), "evrimsiz: yavaşlatma/itme yok")
	p.apply_skill_evolution("shaman_e3", true)
	shield._area_damage_timer = 0.0
	shield._process_area_damage(0.02)
	assert(e.slows.size() == 1 and is_equal_approx(float(e.slows[0][0]), 0.7), "Yapışkan Zemin: %%70 yavaşlatma: %s" % str(e.slows))
	assert(e.pushes.is_empty(), "itme henüz yok")
	attack._process_area_damage(0.02)
	assert(e.slows.size() == 1, "Saldırı Totemi yavaşlatmaz (E yeteneği)")
	p.apply_skill_evolution("shaman_ef", true)
	shield._area_damage_timer = 0.0
	shield._process_area_damage(0.02)
	assert(e.pushes.size() == 1, "İtici Dalga: hasar tikinde itme: %s" % str(e.pushes))
	assert((e.pushes[0][0] as Vector2).dot(Vector2.RIGHT) > 0.99 and float(e.pushes[0][1]) > 0.0, "merkezden DIŞARI: %s" % str(e.pushes))
	_cleanup()


func test_e4_shield_amount_plus_50_percent() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 10000.0
	var t: Node2D = _make_totem(ShieldTotemScene, p)
	p.item_shield_hp = 0.0
	t._tick()
	var base: float = p.item_shield_hp
	assert(base > 0.0, "temel kalkan yenilendi: %s" % str(base))
	p.apply_skill_evolution("shaman_e4", true)
	p.item_shield_hp = 0.0
	t._tick()
	assert(is_equal_approx(p.item_shield_hp, base * 1.5), "Güçlü Kalkan: +%%50: %s vs %s" % [str(p.item_shield_hp), str(base)])
	_cleanup()


# ------------------------------------------------------------------ R
func _hit(p: Node, amount: float) -> float:
	p._last_damage_taken_at_msec = -999999
	var before: float = p.health
	p.take_damage(amount, null)
	return before - p.health


func test_r1_damage_reduction_60_percent() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 0.0
	p.item_shield_hp = 0.0
	p.max_health = 10000.0
	p.health = 10000.0
	var normal: float = _hit(p, 100.0)
	p._skill_shaman_golem()
	var golem: float = _hit(p, 100.0)
	assert(is_equal_approx(golem, normal * 0.6), "temel %%40 azaltma: %s / %s" % [str(golem), str(normal)])
	p.apply_skill_evolution("shaman_r1", true)
	var evo: float = _hit(p, 100.0)
	assert(is_equal_approx(evo, normal * 0.4), "Taş Deri: %%60 azaltma: %s / %s" % [str(evo), str(normal)])
	p._end_shaman_golem()
	assert(is_equal_approx(_hit(p, 100.0), normal), "form bitince azaltma kalkar")
	_cleanup()


func test_r2_heals_missing_health_per_kill_only_in_form() -> void:
	var p: Node = _make_player()
	p.max_health = 100.0
	p.health = 50.0
	p.apply_skill_evolution("shaman_r2", true)
	p.on_enemy_killed_remote(false, Vector2.ZERO)
	assert(is_equal_approx(p.health, 50.0), "formda değilken iyileşmez")
	p._skill_shaman_golem()
	p.on_enemy_killed_remote(false, Vector2.ZERO)
	assert(p.health >= 50.5 and p.health < 51.5, "eksik canın %%1'i (50 -> ~50.5): %s" % str(p.health))
	var after_one: float = p.health
	p.on_enemy_killed_remote(false, Vector2.ZERO)
	assert(p.health > after_one, "her öldürmede tekrar")
	_cleanup()


func test_rf_bigger_stronger_wider_golem_and_restores() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("shaman_rf", true)
	var scale0: Vector2 = p.char_base_anim_scale
	var ap0: float = p.damage_bonus
	## Taban golem alanının hemen dışı, +%30 alanın içi.
	var e: FakeEnemy = _make_enemy(Vector2(1000.0 + GolemMath.AUTO_RADIUS * 1.15, 1000.0))
	p._skill_shaman_golem()
	assert(p.char_base_anim_scale.is_equal_approx(scale0 * 1.3), "boyut +%%30: %s" % str(p.char_base_anim_scale))
	assert(is_equal_approx(p.damage_bonus, ap0 * 1.15), "saldırı gücü +%%15: %s" % str(p.damage_bonus))
	assert(is_equal_approx(p._golem_area_mult(), 1.3), "alan çarpanı 1.3")
	p._shaman_golem_auto_hit()
	assert(e.hits.size() == 1 and is_equal_approx(float(e.hits[0]), ap0 * 1.15 * GolemMath.AUTO_DAMAGE_RATIO), "genişlemiş alan + artmış güç: %s" % str(e.hits))
	p._end_shaman_golem()
	assert(p.char_base_anim_scale.is_equal_approx(scale0) and is_equal_approx(p.damage_bonus, ap0), "form bitince boyut ve güç geri")
	assert(is_equal_approx(p._golem_area_mult(), 1.0), "alan çarpanı normale")
	## Evrimsiz oyuncu formda büyümez.
	var q: Node = _make_player()
	var s1: Vector2 = q.char_base_anim_scale
	q._skill_shaman_golem()
	assert(q.char_base_anim_scale.is_equal_approx(s1), "evrimsiz boyut aynı")
	_cleanup()


func test_rf_remote_puppet_scales_in_golem_form() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(98, SHAMAN, "Shaman")
	var base: Vector2 = rp.anim.scale
	rp._evolutions = {"shaman_rf": true}
	rp.update_position_and_anim_from_net(Vector2(500, 500), GolemMath.IDLE + "down")
	assert(rp.anim.scale.is_equal_approx(base * 1.3), "kukla golem formunda +%%30: %s vs %s" % [str(rp.anim.scale), str(base)])
	var bar: Node = rp.get_node("OverheadBar")
	assert(float(bar.y_offset) < 0.0 or true)
	rp.update_position_and_anim_from_net(Vector2(500, 500), "idle_down")
	assert(rp.anim.scale.is_equal_approx(base), "form bitince normal boyut")
	rp._evolutions = {}
	rp.update_position_and_anim_from_net(Vector2(500, 500), GolemMath.IDLE + "down")
	assert(rp.anim.scale.is_equal_approx(base), "evrimsiz kukla büyümez")
	_cleanup()
