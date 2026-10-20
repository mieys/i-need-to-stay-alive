extends Node

## Madde 325 (2026-10-20): koruma ücreti kalktı, yerine GÜVENLİ ALANDA ZAMAN DONMASI geldi (seyyar satıcı koruma bölgesi + demirci iç
## mekanı): can/kalkan yenilenmez, yetenek/ruhani/eşya bekleme sayaçları ilerlemez. Ayrıca ölü/yerde yatan oyuncunun bekleme sayaçları DOLAR.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const S: GDScript = preload("res://scripts/spiritual_skills.gd")
const WeaponShopScript: GDScript = preload("res://scripts/weapon_shop.gd")
const FoodDropScene: PackedScene = preload("res://scenes/food_drop.tscn")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1
var _prev_spirit: String = ""


func _make_player(char_id: int = 1, spirit: String = "") -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	_prev_spirit = GameManager.selected_spiritual
	GameManager.selected_char_id = char_id
	GameManager.selected_character = Characters.get_def(char_id)["skill"]
	GameManager.selected_spiritual = spirit if spirit != "" else S.PARA
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	player._last_damage_taken_at_msec = -999999
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	GameManager.selected_spiritual = _prev_spirit
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


# ------------------------------------------------------------------ güvenli alan tanımı

func test_safe_zone_is_merchant_zone_or_smithy_interior_but_not_the_open_map() -> void:
	var player: Node = _make_player()
	assert(not player.is_safe_zone_frozen(), "açık haritada zaman akar")
	player.is_in_merchant_zone = true
	assert(player.is_safe_zone_frozen(), "satıcı koruma bölgesinde zaman donar")
	player.is_in_merchant_zone = false
	player.global_position = WeaponShopScript.INTERIOR_OFFSET + Vector2(100.0, 50.0)
	assert(player.is_safe_zone_frozen(), "demirci iç mekanında zaman donar")
	player.global_position = Vector2(1000.0, 1000.0)
	assert(not player.is_safe_zone_frozen(), "dışarı çıkınca yeniden akar")
	assert(is_equal_approx(player._rdelta(0.5), 0.5), "akarken süre aynen geçer")
	player.is_in_merchant_zone = true
	assert(player._rdelta(0.5) == 0.0, "donukken yenilenme süresi 0")
	assert(player._cd_delta("cooldown", 0.5) == 0.0, "donukken bekleme 0")
	assert(is_equal_approx(player._cd_delta("active", 0.5), 0.5), "donukken AKTİF süre (buff/kanal) akmaya devam eder")
	_cleanup()


# ------------------------------------------------------------------ can / kalkan

func test_no_health_or_shield_is_restored_while_frozen() -> void:
	var player: Node = _make_player()
	player.item_shield_max = 200.0
	player.item_shield_hp = 20.0
	player.health = 30.0
	player.is_in_merchant_zone = true
	player.heal(40.0)
	player.heal_shield(50.0)
	assert(is_equal_approx(player.health, 30.0), "donukken heal() can basmaz: %s" % player.health)
	assert(is_equal_approx(player.item_shield_hp, 20.0), "donukken heal_shield() kalkan basmaz: %s" % player.item_shield_hp)
	player.is_in_merchant_zone = false
	player.heal(40.0, false)
	player.heal_shield(50.0, true, false)
	assert(is_equal_approx(player.health, 70.0), "bölge dışında heal() çalışır: %s" % player.health)
	assert(is_equal_approx(player.item_shield_hp, 70.0), "bölge dışında heal_shield() çalışır: %s" % player.item_shield_hp)
	_cleanup()


func test_passive_regen_does_not_tick_while_frozen() -> void:
	var player: Node = _make_player()
	player.heal_regen_bonus = 10.0
	player.health = 10.0
	var step: float = player.HEALTH_REGEN_TICK_INTERVAL + 0.05
	player.is_in_merchant_zone = true
	for i in range(5):
		player._process_regen(player._rdelta(step))
	assert(is_equal_approx(player.health, 10.0), "donukken can yenilenmesi işlemez: %s" % player.health)
	player.is_in_merchant_zone = false
	player._process_regen(player._rdelta(step))
	assert(player.health > 10.0, "bölge dışında yenilenme işler: %s" % player.health)
	_cleanup()


func test_shield_regen_does_not_tick_while_frozen() -> void:
	var player: Node = _make_player()
	player.item_shield_max = 100.0
	player.item_shield_hp = 0.0
	player.item_shield_regen_delay = 0.0
	player.is_in_merchant_zone = true
	for i in range(6):
		player._process_item_shield(player._rdelta(1.0))
		player._process_shield_regen_tick(player._rdelta(1.0))
	assert(is_equal_approx(player.item_shield_hp, 0.0), "donukken kalkan yenilenmesi işlemez: %s" % player.item_shield_hp)
	assert(not player._shield_regenerating, "donukken kalkan baloncuğu 'yenileniyor' görünmemeli")
	_cleanup()


# ------------------------------------------------------------------ bekleme sayaçları

func test_skill_cooldowns_freeze_in_safe_zone_but_not_outside() -> void:
	var player: Node = _make_player()
	player.skill_state = "cooldown"
	player.skill_timer = 20.0
	player.skill2_state = "cooldown"
	player.skill2_timer = 20.0
	player.skill3_state = "cooldown"
	player.skill3_timer = 20.0
	player.is_in_merchant_zone = true
	player._process_skill(player._cd_delta(player.skill_state, 5.0))
	player._process_skill2(player._cd_delta(player.skill2_state, 5.0))
	player._process_skill3(player._cd_delta(player.skill3_state, 5.0))
	assert(is_equal_approx(player.skill_timer, 20.0) and is_equal_approx(player.skill2_timer, 20.0) and is_equal_approx(player.skill3_timer, 20.0),
			"güvenli alanda Q/E/R beklemesi ilerlemez: %s %s %s" % [player.skill_timer, player.skill2_timer, player.skill3_timer])
	player.is_in_merchant_zone = false
	player._process_skill(player._cd_delta(player.skill_state, 5.0))
	assert(is_equal_approx(player.skill_timer, 15.0), "bölge dışında bekleme akar: %s" % player.skill_timer)
	_cleanup()


func test_spirit_cooldown_and_para_income_freeze_in_safe_zone() -> void:
	var player: Node = _make_player(1, S.PARA)
	GameManager.gold = 0
	player.is_in_merchant_zone = true
	for i in range(25):
		player._process_spirit(1.0)
	assert(GameManager.gold == 0, "güvenli alanda Para pasifi altın üretmez (dükkanda bekleyip kasma yok): %d" % GameManager.gold)
	player.is_in_merchant_zone = false
	for i in range(10):
		player._process_spirit(1.0)
	assert(GameManager.gold == 5, "bölge dışında 10 sn'de +5 altın: %d" % GameManager.gold)
	_cleanup()
	## Aktif ruhani yetenek (Taktik) bekleme sayacı.
	player = _make_player(1, S.TAKTIK)
	player.spirit_state = "cooldown"
	player.spirit_timer = 30.0
	player.is_in_merchant_zone = true
	player._process_spirit(10.0)
	assert(is_equal_approx(player.spirit_timer, 30.0), "güvenli alanda ruhani yetenek beklemesi ilerlemez: %s" % player.spirit_timer)
	player.is_in_merchant_zone = false
	player._process_spirit(10.0)
	assert(is_equal_approx(player.spirit_timer, 20.0), "bölge dışında ilerler: %s" % player.spirit_timer)
	_cleanup()


func test_item_cooldowns_and_item_heal_freeze_in_safe_zone() -> void:
	var player: Node = _make_player()
	player._item_olum_cd = 60.0
	player._item_invuln_timer = 5.0
	player.is_in_merchant_zone = true
	player._process_new_item_passives(10.0)
	assert(is_equal_approx(player._item_olum_cd, 60.0), "eşya beklemesi güvenli alanda donar: %s" % player._item_olum_cd)
	assert(is_equal_approx(player._item_invuln_timer, 0.0), "süreli koruma sayacı (aktif süre) akmaya devam eder")
	player.is_in_merchant_zone = false
	player._process_new_item_passives(10.0)
	assert(is_equal_approx(player._item_olum_cd, 50.0), "bölge dışında akar: %s" % player._item_olum_cd)
	_cleanup()


# ------------------------------------------------------------------ ölüyken bekleme dolar

func test_cooldowns_keep_running_while_dead() -> void:
	var player: Node = _make_player()
	player.skill_state = "cooldown"
	player.skill_timer = 10.0
	player.skill2_state = "cooldown"
	player.skill2_timer = 30.0
	player.skill3_state = "cooldown"
	player.skill3_timer = 5.0
	player.is_dead = true
	player.is_downed = true
	player._process_cooldowns_while_down(6.0)
	assert(is_equal_approx(player.skill_timer, 4.0), "ölüyken Q beklemesi akar: %s" % player.skill_timer)
	assert(is_equal_approx(player.skill2_timer, 24.0), "ölüyken E beklemesi akar: %s" % player.skill2_timer)
	assert(player.skill3_state == "ready" and is_equal_approx(player.skill3_timer, 0.0), "ölüyken biten bekleme hazıra döner: %s" % player.skill3_state)
	player._process_cooldowns_while_down(10.0)
	assert(player.skill_state == "ready", "ölüyken bekleme tamamen dolabilir")
	_cleanup()


func test_active_skill_stays_frozen_while_dead() -> void:
	var player: Node = _make_player()
	player.skill_state = "active"
	player.skill_timer = 5.0
	player.is_dead = true
	player._process_cooldowns_while_down(3.0)
	assert(player.skill_state == "active" and is_equal_approx(player.skill_timer, 5.0), "ölüyken AKTİF süre ilerlemez (diriltilince devam): %s" % player.skill_timer)
	_cleanup()


func test_spirit_cooldown_runs_while_dead_and_freezes_in_zone() -> void:
	var player: Node = _make_player(1, S.TAKTIK)
	player.spirit_state = "cooldown"
	player.spirit_timer = 30.0
	player.is_dead = true
	player._process_spirit(10.0)
	assert(is_equal_approx(player.spirit_timer, 20.0), "ölüyken ruhani yetenek beklemesi akar: %s" % player.spirit_timer)
	player._process_spirit(25.0)
	assert(player.spirit_state == "ready", "ölüyken ruhani yetenek hazıra döner")
	_cleanup()


func test_dead_player_cooldowns_do_not_run_inside_safe_zone() -> void:
	var player: Node = _make_player()
	player.skill_state = "cooldown"
	player.skill_timer = 10.0
	player.is_dead = true
	player.is_in_merchant_zone = true
	player._process_cooldowns_while_down(6.0)
	assert(is_equal_approx(player.skill_timer, 10.0), "güvenli alanda ölü de olsa bekleme donuk: %s" % player.skill_timer)
	_cleanup()


# ------------------------------------------------------------------ yemek güvenli alanda boşa yenmez

func test_food_is_not_wasted_inside_safe_zone() -> void:
	var player: Node = _make_player()
	player.health = 10.0
	player.is_in_merchant_zone = true
	var food: Node = FoodDropScene.instantiate()
	add_child(food)
	_spawned.append(food)
	food._on_body_entered(player)
	assert(not food.get_meta("claimed", false), "güvenli alanda yemek tüketilmez")
	assert(is_equal_approx(player.health, 10.0), "güvenli alanda yemek can basmaz: %s" % player.health)
	_cleanup()
