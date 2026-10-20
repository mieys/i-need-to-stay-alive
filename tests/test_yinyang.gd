extends Node

## YİN YANG KİTABI (2026-10-20, madde 334): kayıtlar, kalkan alıcısı (menzilsiz, oransal en boş, eşitlikte sahibi, hepsi doluysa Yin),
## isabette kendine / dosta kalkan + Yang çarpanı, Yin hasarı, Denge geliştirmeleri (Kalın Sayfa, Ağır Yin, Sıcak Yang, Kara Mühür),
## FİNAL Tai Chi Mührü, kara kürenin yükselirken çarpmaması, ak kürenin kitaptan yükselip alıcıya uçması, kitabın nişanla dönmemesi.
## Gerçek oyuncu + gerçek kitap (test_gokkusagi_asasi.gd düzeni).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ProjScene: PackedScene = preload("res://scenes/yinyang_projectile.tscn")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const WeaponTraits := preload("res://scripts/weapon_traits/weapon_traits.gd")
const RemotePlayerScript := preload("res://scripts/remote_player.gd")
const YinYang := preload("res://scripts/yinyang_book.gd")
const LightScript := preload("res://scripts/yinyang_light.gd")
const MATTHEW := 3
const AP := 100.0


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var hits: Array = [] ## [miktar, alan mı]
	var elements: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, is_area: bool = false) -> void:
		hits.append([amount, is_area])

	func apply_element(kind: String, p: Dictionary) -> void:
		elements.append([kind, p.duplicate()])


class FakeAlly extends Node2D:
	var peer_id: int = 7
	var is_dead: bool = false
	var is_downed: bool = false
	var item_shield_max: float = 100.0
	var item_shield_hp: float = 100.0
	var got: float = 0.0

	func heal_shield(amount: float) -> void:
		got += amount
		item_shield_hp = minf(item_shield_max, item_shield_hp + amount)


var _spawned: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1


func _track(n: Node) -> Node:
	add_child(n)
	_spawned.append(n)
	return n


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	_track(e)
	e.global_position = pos
	return e


func _ally(hp: float, mx: float = 100.0) -> FakeAlly:
	var a := FakeAlly.new()
	a.add_to_group("remote_players")
	_track(a)
	a.item_shield_hp = hp
	a.item_shield_max = mx
	a.global_position = Vector2(700.0, 1100.0)
	return a


func _setup(ench: Dictionary = {}) -> Array:
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = MATTHEW
	GameManager.selected_character = int(Characters.DEFS[MATTHEW]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = _track(PlayerScene.instantiate())
	p.global_position = Vector2(1000.0, 1000.0)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [{"key": "yinyang", "level": 1}]
	assert(p.buy_weapon_copy("yinyang", 1), "silah verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	w.crit_chance = 0.0
	w.set_enchant(ench if not ench.is_empty() else {"id": "denge"})
	p.damage_bonus = AP
	p.item_shield_max = 100.0
	p.item_shield_hp = 100.0
	return [p, w]


## Gerçek kara küre: özellik kurar (alıcı seçimi), ilk fizik adımı (yükselme + ak küre), yükselmeyi bitirir.
func _shot(w: Node, target: Node2D, dmg: float = 50.0) -> Node:
	var proj: Node = ProjScene.instantiate()
	add_child(proj)
	proj.global_position = w.global_position
	proj.direction = (target.global_position - w.global_position).normalized()
	proj.damage = dmg
	proj.source_weapon = w
	w.enchant_behavior.configure_projectile(proj, target, false)
	proj._physics_process(0.01)
	proj._yy_t = YinYang.RISE
	return proj


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.owned_weapons = []
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for c in get_children():
		c.free()
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


func test_registered_everywhere() -> void:
	assert(WeaponCatalogScript.KEYS.has("yinyang") and WeaponCatalogScript.NAMES["yinyang"] == "Yin Yang Kitabı", "katalog + ad")
	assert(WeaponCatalogScript.DESCRIPTIONS.has("yinyang") and not WeaponCatalogScript.MELEE_KEYS.has("yinyang"), "açıklama, menzilli")
	assert(WeaponTraits.trait_of("yinyang") == "denge", "doğuştan özellik")
	assert(WeaponTierArt.has_art("yinyang") and WeaponTierArt.key_from_scene("res://scenes/weapon_yinyang.tscn") == "yinyang", "kademe sanatı")
	for lv in range(1, 6):
		assert(WeaponTierArt.texture("yinyang", lv) != null, "L%d dokusu" % lv)
	assert(RemotePlayerScript.WEAPON_SCENES.has("yinyang"), "uzak kukla sahnesi")
	var d: Dictionary = EnchantDefs.get_def("denge")
	assert(not d.is_empty() and (d["upgrades"] as Array).size() == 4 and d.has("final"), "4 geliştirme + final")
	var w: Node = (load("res://scenes/weapon_yinyang.tscn") as PackedScene).instantiate()
	assert(is_equal_approx(w.fire_rate, 1.2) and is_equal_approx(w.card_damage_bonus_ratio, 1.25) and is_equal_approx(w.attack_range, 170.0),
		"aralık 1,2 (/0,7 = 1,7 sn; yavaşlatma kullanıcı isteğiyle geri alındı), %125 SG (denge turu, BALANCE_REV 94), menzil 170")
	w.free()


func test_recipient_is_emptiest_player_anywhere_owner_on_tie_null_when_all_full() -> void:
	var s := _setup()
	var p: Node = s[0]
	p.item_shield_hp = 60.0
	var far := _ally(30.0)
	far.global_position = Vector2(9000.0, 9000.0) ## menzil yok
	assert(YinYang.pick_recipient(p) == far, "oransal en boş dost, ne kadar uzak olursa olsun")
	far.is_dead = true
	assert(YinYang.pick_recipient(p) == p, "ölü dost alamaz")
	far.is_dead = false
	far.item_shield_hp = 60.0
	assert(YinYang.pick_recipient(p) == p, "eşitlikte sahibi")
	p.item_shield_hp = 100.0
	far.item_shield_hp = 100.0
	assert(YinYang.pick_recipient(p) == null, "hepsi dolu -> null (Yin)")
	far.item_shield_max = 0.0
	p.item_shield_hp = 40.0
	assert(YinYang.pick_recipient(p) == p, "kalkan türü olmayan dost sayılmaz")
	_cleanup()


func test_hit_gives_shield_to_owner_and_yang_boosts_low_shield() -> void:
	var s := _setup()
	var p: Node = s[0]
	var w: Node = s[1]
	var hp_mult: float = p.heal_power_mult()
	p.item_shield_hp = 50.0
	var e := _enemy(Vector2(1120.0, 1000.0))
	var proj: Node = _shot(w, e)
	assert(proj.yy_rcp_peer > 0, "alıcı seçildi (tek kişilikte kendisi)")
	proj._on_body_entered(e)
	assert(e.hits.size() == 1 and is_equal_approx(float(e.hits[0][0]), 50.0), "tek hedef, ana hasar: %s" % str(e.hits))
	assert(absf(p.item_shield_hp - (50.0 + AP * 0.1 * hp_mult)) < 0.01, "isabet başına %%10 SG kalkan: %s" % str(p.item_shield_hp))
	## Yang: %30 altına 1,5 kat
	p.item_shield_hp = 20.0
	var e2 := _enemy(Vector2(1120.0, 1010.0))
	_shot(w, e2)._on_body_entered(e2)
	assert(absf(p.item_shield_hp - (20.0 + AP * 0.15 * hp_mult)) < 0.01, "Yang x1,5: %s" % str(p.item_shield_hp))
	_cleanup()


func test_shield_goes_to_ally_and_full_shields_turn_into_yin_damage() -> void:
	var s := _setup()
	var p: Node = s[0]
	var w: Node = s[1]
	var ally := _ally(40.0)
	var e := _enemy(Vector2(1120.0, 1000.0))
	var proj: Node = _shot(w, e)
	assert(proj.yy_rcp_peer == 7, "ağa giden alıcı kimliği = dostun peer_id'si")
	proj._on_body_entered(e)
	assert(ally.got > 0.0 and is_equal_approx(p.item_shield_hp, 100.0), "kalkan dosta gitti")
	## herkes dolu -> Yin: kalkan yerine +%20 SG alan hasarı
	ally.item_shield_hp = 100.0
	var e2 := _enemy(Vector2(1120.0, 1010.0))
	var proj2: Node = _shot(w, e2)
	assert(proj2.yy_rcp_peer == 0, "kimse alamıyor -> Yin")
	var got_before: float = ally.got
	proj2._on_body_entered(e2)
	assert(e2.hits.size() == 2 and bool(e2.hits[1][1]) and is_equal_approx(float(e2.hits[1][0]), AP * 0.2), "Yin hasarı: %s" % str(e2.hits))
	assert(is_equal_approx(ally.got, got_before), "Yin'de kalkan yok")
	_cleanup()


func test_denge_upgrades() -> void:
	var s := _setup({"id": "denge", "ups": [0, 1, 2, 3]})
	var p: Node = s[0]
	var w: Node = s[1]
	var hp_mult: float = p.heal_power_mult()
	p.item_shield_hp = 70.0 ## %70: Yang eşiğinin (%40) üstü
	var e := _enemy(Vector2(1120.0, 1000.0))
	_shot(w, e)._on_body_entered(e)
	assert(absf(p.item_shield_hp - (70.0 + AP * 0.13 * hp_mult)) < 0.01, "Kalın Sayfa %%13: %s" % str(p.item_shield_hp))
	var kinds: Array = e.elements.map(func(x): return x[0])
	assert(kinds.has("weaken"), "Kara Mühür zayıflatır: %s" % str(kinds))
	p.item_shield_hp = 35.0 ## Sıcak Yang: eşik %40, x2
	var e2 := _enemy(Vector2(1120.0, 1010.0))
	_shot(w, e2)._on_body_entered(e2)
	assert(absf(p.item_shield_hp - (35.0 + AP * 0.13 * 2.0 * hp_mult)) < 0.01, "Sıcak Yang x2: %s" % str(p.item_shield_hp))
	p.item_shield_hp = 100.0 ## Ağır Yin %35
	var e3 := _enemy(Vector2(1120.0, 1020.0))
	_shot(w, e3)._on_body_entered(e3)
	assert(e3.hits.size() == 2 and is_equal_approx(float(e3.hits[1][0]), AP * 0.35), "Ağır Yin: %s" % str(e3.hits))
	_cleanup()


func test_final_seal_every_sixth_hit_sends_shield_each_second() -> void:
	var s := _setup({"id": "denge", "ups": [0, 1, 2, 3], "final": true})
	var p: Node = s[0]
	var w: Node = s[1]
	var beh: Node = w.enchant_behavior
	for i in range(5):
		var e := _enemy(Vector2(1120.0, 1000.0 + i))
		_shot(w, e)._on_body_entered(e)
	assert(beh._seals.is_empty(), "5 vuruşta mühür yok")
	p.item_shield_hp = 100.0
	var e6 := _enemy(Vector2(1120.0, 1020.0))
	_shot(w, e6)._on_body_entered(e6)
	assert(beh._seals.size() == 1, "6. vuruşta mühür")
	var field_found: bool = false
	for c in get_children():
		if c.get("kind") == "field" and str((c.get("p") as Dictionary).get("sheet", "")) == "taichi_seal":
			field_found = true
	assert(field_found, "hasar alanı (field, taichi_seal sayfası)")
	p.item_shield_hp = 50.0
	beh.process_extra(1.0)
	assert(p.item_shield_hp > 50.0, "mühür saniyede kalkan gönderir")
	beh.process_extra(3.0)
	assert(beh._seals.is_empty(), "3 sn sonra biter")
	_cleanup()


func test_dark_orb_does_not_hit_while_rising() -> void:
	var s := _setup()
	var w: Node = s[1]
	var e := _enemy(Vector2(1010.0, 990.0))
	var proj: Node = ProjScene.instantiate()
	add_child(proj)
	proj.global_position = w.global_position
	proj.direction = Vector2.RIGHT
	proj.damage = 50.0
	proj.source_weapon = w
	w.enchant_behavior.configure_projectile(proj, e, false)
	proj._physics_process(0.05)
	assert(not proj.monitoring, "yükselirken çarpışma kapalı")
	proj._on_body_entered(e)
	assert(e.hits.is_empty(), "yükselirken vurmaz")
	var start: Vector2 = proj._yy_start
	proj._physics_process(0.1)
	assert(proj.global_position.y < start.y - 5.0, "kitaptan yukarı yükselir: %s -> %s" % [str(start), str(proj.global_position)])
	_cleanup()


func test_light_orb_rises_splits_and_flies_to_ally() -> void:
	var s := _setup()
	var w: Node = s[1]
	var ally := _ally(20.0)
	var e := _enemy(Vector2(1120.0, 1000.0))
	var proj: Node = _shot(w, e)
	var light: Node2D = null
	for c in get_children():
		if c.get_script() == LightScript:
			light = c
	assert(light != null and light.rcp == ally, "ak küre ayrı düğüm, hedefi dost")
	light._process(YinYang.RISE * 0.5)
	assert(light._phase == 0, "önce yükselir")
	light._process(YinYang.RISE * 0.6)
	assert(light._phase == 1, "tepede ayrılıp uçar")
	for i in range(60):
		light._process(0.02)
		if light._phase >= 2:
			break
	assert(light._phase == 2, "dosta vardı, belde tur atar")
	assert(light.global_position.distance_to(ally.global_position) < 14.0, "dostun yanında: %s" % str(light.global_position))
	_cleanup()


func test_attack_speed_bonuses_apply_fully() -> void:
	var s := _setup()
	var w: Node = s[1]
	var base_wait: float = w._effective_fire_wait()
	assert(absf(base_wait - 1.2 / GameManager.WEAPON_ATTACK_SPEED_MULT) < 0.01, "taban aralık 1,7 sn: %s" % str(base_wait))
	w.fire_rate_multiplier = 0.5 ## kartlardan +%100 saldırı hızı
	var fast: float = w._effective_fire_wait()
	assert(absf(base_wait / fast - 2.0) < 0.02, "+%%100 hızlanma tam işler (yarı oran geri alındı): x%s" % str(base_wait / fast))
	_cleanup()


func test_no_target_still_carries_shield_with_light_orb_only() -> void:
	var s := _setup()
	var p: Node = s[0]
	var w: Node = s[1]
	var hp_mult: float = p.heal_power_mult()
	p.item_shield_hp = 50.0
	w._on_fire_timer_timeout() ## görüşte/menzilde düşman yok
	assert(absf(p.item_shield_hp - (50.0 + AP * 0.1 * hp_mult)) < 0.01, "hedef yokken de kalkan: %s" % str(p.item_shield_hp))
	var lights: Array = get_children().filter(func(c): return c.get_script() == LightScript)
	assert(lights.size() == 1 and lights[0].rcp == p and lights[0].enemy == null, "yalnız ak küre, alıcıya")
	var projs: Array = get_children().filter(func(c): return c.get_script() == preload("res://scripts/yinyang_projectile.gd"))
	assert(projs.is_empty(), "kara küre (hasar) yok")
	var ally := _ally(10.0)
	p.item_shield_hp = 100.0
	w._on_fire_timer_timeout()
	assert(ally.got > 0.0, "en boş dosta gider")
	ally.item_shield_hp = 100.0
	var before: int = get_children().filter(func(c): return c.get_script() == LightScript).size()
	w._on_fire_timer_timeout()
	assert(get_children().filter(func(c): return c.get_script() == LightScript).size() == before, "herkes doluyken hiçbir şey olmaz")
	_cleanup()


func test_book_icon_stays_upright() -> void:
	var s := _setup()
	var w: Node = s[1]
	w.icon_sprite.rotation = 0.0
	w._face_dir(Vector2(0.0, 1.0), 1.0)
	assert(is_equal_approx(w.icon_sprite.rotation, 0.0), "kitap nişanla dönmez")
	_cleanup()
