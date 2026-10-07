extends Node

## Kullanıcı isteği (2026-10-04): "büyücü kızın hortum yeteneğini Q2'ye (E) taşıyıp Q2'deki Don Nova'yı da boş kalan R kısmına taşı" -
## Hortum ile Don Nova yer değiştirdi: Set 1 = {E: Arcane Lanet, R: Don Nova}, Set 2 = {E: Hortum, R: Meteor Patlaması}.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var hits: Array = []
	var freezes: Array = []
	var frost_slows: Array = [] ## [yüzde, süre] - 2026-10-04: Don Nova artık dondurmuyor, %80 yavaşlatıyor

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)

	func apply_freeze_full(duration: float, _allow_boss: bool = false) -> void:
		freezes.append(duration)

	func apply_frost_slow(percent: float, duration: float) -> void:
		frost_slows.append([percent, duration])


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 4
	GameManager.selected_character = 3
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.damage_bonus = 100.0
	p.crit_chance_bonus = -p.ABILITY_BASE_CRIT_CHANCE
	p.item_shield_max = 10000.0
	p.item_shield_hp = 10000.0
	return p


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_sets_hold_swapped_skills() -> void:
	var p: Node = _make_player()
	assert(p.get_skill2_id() == 22 and p.get_skill3_id() == 23, "Set 1: E = Arcane Lanet (22), R = Don Nova (23): %d / %d" % [p.get_skill2_id(), p.get_skill3_id()])
	assert(p.get_buyucu_variation_name() == "Arcane Lanet" and p.get_buyucu_variation_name_r() == "Don Nova")
	p._skill_buyucu_switch_variation()
	assert(p.get_skill2_id() == 24 and p.get_skill3_id() == 25, "Set 2: E = Hortum (24), R = Meteor (25): %d / %d" % [p.get_skill2_id(), p.get_skill3_id()])
	assert(p.get_buyucu_variation_name() == "Hortum" and p.get_buyucu_variation_name_r() == "Meteor Patlaması")
	p._skill_buyucu_switch_variation()
	assert(p.get_skill2_id() == 22, "tekrar Set 1")
	_cleanup()


func test_descriptions_follow_slot_kind() -> void:
	var p: Node = _make_player()
	assert(p.get_buyucu_variation_desc().begins_with("TEMEL (Arcane Lanet)"), p.get_buyucu_variation_desc())
	assert(p.get_buyucu_variation_desc_r().begins_with("ULTİ (Don Nova)"), "R'deki Don Nova ULTİ etiketi: " + p.get_buyucu_variation_desc_r())
	p._skill_buyucu_switch_variation()
	assert(p.get_buyucu_variation_desc().begins_with("TEMEL (Hortum)"), "E'deki Hortum TEMEL etiketi: " + p.get_buyucu_variation_desc())
	assert(p.get_buyucu_variation_desc_r().begins_with("ULTİ (Meteor"), p.get_buyucu_variation_desc_r())
	_cleanup()


func test_don_nova_now_casts_from_r_with_ulti_cost() -> void:
	var p: Node = _make_player()
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	_spawned.append(e)
	e.global_position = Vector2(1100.0, 1000.0)
	var shield0: float = p.item_shield_hp
	await get_tree().physics_frame ## yaratık ızgarası (Enemy.get_enemies_near) bir sonraki fizik karesinde kurulur
	p._buyucu_try_activate_variation_r()
	assert(e.frost_slows == [[p.BUYUCU_NOVA_SLOW_PERCENT, p.BUYUCU_NOVA_SLOW_DURATION]] and e.freezes.is_empty() and e.hits.size() == 1,
		"R'de Don Nova %%80 yavaşlatır (dondurmaz) + vurur: %s %s %s" % [str(e.frost_slows), str(e.freezes), str(e.hits)])
	assert(p.item_shield_hp < shield0, "ULTİ kalkan bedeli ödendi")
	assert(p._buyucu_variation_cooldowns[1] > 44.0, "Don Nova kendi bekleme sayacını kullanır (45 sn)")
	assert(p.get_skill3_progress() < 0.1, "R halkası bekleme gösterir")
	## Aynı tuşa tekrar: bekleme yüzünden çalışmaz.
	e.frost_slows.clear()
	p._buyucu_try_activate_variation_r()
	assert(e.frost_slows.is_empty(), "bekleme süresindeyken tekrar çalışmaz")
	_cleanup()


func test_hortum_casts_from_e_and_marks_e_active() -> void:
	var p: Node = _make_player()
	p._skill_buyucu_switch_variation()
	assert(not p.is_skill2_active(), "hortum yokken E aktif görünmez")
	var shield0: float = p.item_shield_hp
	p._buyucu_try_activate_variation()
	assert(p.item_shield_hp < shield0, "E (TEMEL) kalkan bedeli ödendi")
	assert(p._buyucu_variation_cooldowns[2] > 29.0 and p._buyucu_variation_cooldowns[2] < 31.0, "Hortum 30 sn bekleme")
	assert(p._buyucu_active_tornadoes.size() == p.BUYUCU_TORNADO_COUNT, "3 hortum çıktı: %d" % p._buyucu_active_tornadoes.size())
	assert(p.is_skill2_active() and not p.is_skill3_active(), "hortum süresince E aktif, R değil")
	for t in p._buyucu_active_tornadoes:
		if is_instance_valid(t):
			t.free()
	_cleanup()


## 2026-10-04 bildirimi: "2. fazdaki bir yetenek aktifken faz değiştirince 1. fazdakiler çalışmıyor" - gerçek tuş basışlarıyla
## yetenekler çalışıyordu, ama hortum/meteor yaşarken faz değişince E/R butonu diğer varyasyonun "aktif" görselini taşıyordu.
func test_active_look_follows_the_variation_in_the_slot() -> void:
	var p: Node = _make_player()
	p._skill_buyucu_switch_variation() ## Set 2: E = Hortum, R = Meteor
	p._buyucu_try_activate_variation()
	assert(p.is_skill2_active(), "Set 2: hortum varken E aktif görünür")
	p._skill_buyucu_switch_variation() ## Set 1: E = Arcane Lanet
	assert(not p.is_skill2_active(), "Set 1'e geçince E butonu (Arcane) hortumun aktif görselini taşımaz")
	p._skill_buyucu_switch_variation()
	assert(p.is_skill2_active(), "Set 2'ye dönünce hortum hâlâ yaşıyorsa E tekrar aktif görünür")
	for t in p._buyucu_active_tornadoes:
		if is_instance_valid(t):
			t.free()
	p._buyucu_active_tornadoes.clear()
	p._skill_buyucu_meteor()
	assert(p.is_skill3_active() and p.get_skill3_active_fraction() > 0.9, "Set 2: meteor kanalında R aktif")
	p._skill_buyucu_switch_variation() ## Set 1: R = Don Nova
	assert(not p.is_skill3_active() and p.get_skill3_active_fraction() == 0.0, "Set 1'de R (Don Nova) meteor kanalının aktif görselini taşımaz")
	p._buyucu_meteor_channel_active = false
	p.is_buyucu_channeling = false
	_cleanup()
