extends Node

## Shaman totemleri (kullanıcı isteği 2026-09-30): "Q yeteneğinin alan hasarı özelliğini E yeteneğine eklemeni istiyorum ve Q
## yeteneği artık 2 stack birikebilsin." - Kalkan Totemi (E) de alanındaki düşmanlara saniyede %20 AP vurur (kod totem_base.gd
## "ALAN HASARI", Saldırı Totemi'yle ortak), Saldırı Totemi (Q) 2 yüklü, her yük ayrı ayrı 45 sn'de yenilenir.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ShieldTotemScene: PackedScene = preload("res://scenes/totem_shield.tscn")
const AttackTotemScene: PackedScene = preload("res://scenes/totem_attack.tscn")

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var hits: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 12
	GameManager.selected_character = 27
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.damage_bonus = 100.0
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE ## kritik yok
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


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n in get_tree().get_nodes_in_group("shaman_totems"):
		if is_instance_valid(n):
			n.free()
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _totem_count(kind: String) -> int:
	var n: int = 0
	for t in get_tree().get_nodes_in_group("shaman_totems"):
		if is_instance_valid(t) and not t.is_queued_for_deletion() and str(t.get("totem_kind")) == kind:
			n += 1
	return n


func test_shield_totem_now_deals_area_damage_like_attack_totem() -> void:
	var p: Node = _make_player()
	var inside: FakeEnemy = _make_enemy(Vector2(1000.0 + 150.0, 1000.0))
	var outside: FakeEnemy = _make_enemy(Vector2(1000.0 + 230.0, 1000.0))
	for scene: PackedScene in [ShieldTotemScene, AttackTotemScene]:
		var totem: Node2D = scene.instantiate()
		add_child(totem)
		_spawned.append(totem)
		totem.setup_from_player(p)
		assert(bool(totem.get("area_damage_enabled")), "%s alan hasarı açık" % totem.name)
		## 2026-10-04: Saldırı Totemi'nin mor sınır çemberi kaldırıldı (kullanıcı isteği) - Kalkan Totemi'nde duruyor.
		assert((totem.get_node_or_null("AreaAura") != null) == (str(totem.get("totem_kind")) == "shield"), "%s mor alan aurası sadece Kalkan Totemi'nde" % totem.name)
		inside.hits.clear()
		totem._process_area_damage(0.02) ## ilk hasar dikildiği anda
		assert(inside.hits.size() == 1 and is_equal_approx(float(inside.hits[0]), 20.0), "%s alanda saniyede %%20 AP: %s" % [totem.name, str(inside.hits)])
		for i in range(40):
			totem._process_area_damage(0.02) ## 0.8 sn - henüz ikinci tik yok
		assert(inside.hits.size() == 1, "tik saniyede bir")
		for i in range(15):
			totem._process_area_damage(0.02)
		assert(inside.hits.size() == 2, "1 sn sonra ikinci tik")
		assert(outside.hits.is_empty(), "alan dışı (180) hasar almaz")
		totem.free()
		_spawned.erase(totem)
	_cleanup()


func test_attack_totem_has_two_charges_that_recharge_one_by_one() -> void:
	var p: Node = _make_player()
	assert(p.shaman_q_charges == 2, "2 yükle başlar")
	var st: Dictionary = p.get_shaman_q_charge_state()
	assert(int(st["charges"]) == 2 and int(st["max"]) == 2 and float(st["fraction"]) == 1.0, "HUD durumu: " + str(st))
	p._shaman_try_attack_totem()
	p._shaman_try_attack_totem()
	assert(_totem_count("attack") == 2, "iki totem aynı anda sahada: %d" % _totem_count("attack"))
	assert(p.shaman_q_charges == 0 and p.skill_state == "ready", "yükler bitti, standart makine hazırda kalır")
	p._shaman_try_attack_totem()
	assert(_totem_count("attack") == 2, "yük yokken totem dikilmez")
	st = p.get_shaman_q_charge_state()
	assert(float(st["remaining"]) > 44.0 and float(st["fraction"]) < 0.05, "sıradaki yük dolmaya başladı: " + str(st))
	for i in range(int(46.0 / 0.5)):
		p._process_shaman_q_charges(0.5)
	assert(p.shaman_q_charges == 1, "45 sn sonra 1 yük (sırayla): %d" % p.shaman_q_charges)
	for i in range(int(46.0 / 0.5)):
		p._process_shaman_q_charges(0.5)
	assert(p.shaman_q_charges == 2, "bir 45 sn daha -> 2")
	st = p.get_shaman_q_charge_state()
	assert(float(st["remaining"]) == 0.0 and float(st["fraction"]) == 1.0, "dolu: " + str(st))
	_cleanup()


func test_charge_not_spent_when_shield_cost_fails() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 1000.0
	p.item_shield_hp = 0.0
	p._shaman_try_attack_totem()
	assert(p.shaman_q_charges == 2 and _totem_count("attack") == 0, "kalkan yetmezse yük harcanmaz")
	_cleanup()


func test_cooldown_reduction_shortens_recharge() -> void:
	var p: Node = _make_player()
	p.cooldown_reduction_percent = 0.2
	p._shaman_try_attack_totem()
	assert(absf(float(p.get_shaman_q_charge_state()["remaining"]) - 45.0 * 0.8) < 0.01, "bekleme süresi azaltma yük süresine uygulanır")
	_cleanup()
