extends Node

## GÖKKUŞAĞI ASASI (2026-10-19, madde 306): kayıtlar, tik hasarı/aralığı (saniyede %150 SG, 0,5 sn), ışının ilk düşmanda durması ve finalde
## (beam_pierce) hattaki herkesi delmesi, Göz Kamaştıran Işık (3 sn tut -> 1,5 sn sersemletme; boss -> zayıflatma; hedef değişince sıfır),
## zayıflatılmış yaratığın verdiği hasar çarpanı. Gerçek oyuncu + gerçek asa (test_lightning_beam_sfx.gd düzeni).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const BeamScene: PackedScene = preload("res://scenes/fx_rainbow_beam.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const WeaponTraits := preload("res://scripts/weapon_traits/weapon_traits.gd")
const RemotePlayerScript := preload("res://scripts/remote_player.gd")
const MATTHEW := 3


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var is_elite: bool = false
	var hits: Array = []
	var elements: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)

	func apply_element(kind: String, p: Dictionary) -> void:
		elements.append([kind, p.duplicate()])


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
	GameManager.owned_weapons = [{"key": "gokkusagi", "level": 1}]
	assert(p.buy_weapon_copy("gokkusagi", 1), "silah verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	w.crit_chance = 0.0
	w.set_enchant(ench if not ench.is_empty() else {"id": "goz_kamastiran"})
	return [p, w]


func _open_beam(w: Node, target: Node2D) -> Node:
	var fx: Node = _track(BeamScene.instantiate())
	var origin: Node2D = w.muzzle if w.muzzle else w
	fx.setup(origin, target)
	w._beam_fx = fx
	w._beam_target = target
	w._update_beam_reach(target, origin)
	return fx


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
	assert(WeaponCatalogScript.KEYS.has("gokkusagi"), "katalogda")
	assert(WeaponCatalogScript.DESCRIPTIONS.has("gokkusagi") and WeaponCatalogScript.NAMES["gokkusagi"] == "Gökkuşağı Asası", "ad + açıklama")
	assert(WeaponTraits.trait_of("gokkusagi") == "goz_kamastiran", "doğuştan özellik")
	assert(WeaponTierArt.has_art("gokkusagi") and WeaponTierArt.key_from_scene("res://scenes/weapon_gokkusagi.tscn") == "gokkusagi", "kademe sanatı anahtarı")
	for lv in range(1, 6):
		assert(WeaponTierArt.texture("gokkusagi", lv) != null, "L%d dokusu" % lv)
	assert(RemotePlayerScript.WEAPON_SCENES.has("gokkusagi"), "uzak kukla sahnesi")
	var d: Dictionary = EnchantDefs.get_def("goz_kamastiran")
	assert(not d.is_empty() and (d["upgrades"] as Array).size() == 4 and d.has("final"), "4 geliştirme + final")


func test_tick_is_110_percent_every_half_second() -> void:
	var s := _setup()
	var w: Node = s[1]
	assert(is_equal_approx(w.beam_tick_interval / GameManager.WEAPON_ATTACK_SPEED_MULT, 0.5), "taban tik aralığı 0,5 sn")
	assert(is_equal_approx(w.card_damage_bonus_ratio * w.beam_tick_ratio / 0.5, 2.2), "saniyede %220 SG")
	var e := _enemy(Vector2(1100.0, 1000.0))
	w.damage = 20.0
	w._deal_beam_tick(e)
	assert(e.hits.size() == 1, "tek vuruş")
	assert(absf(float(e.hits[0]) - 20.0 * w.beam_tick_ratio) < 0.5, "tik = silah hasarı x oran: %s" % str(e.hits))
	_cleanup()


func test_beam_stops_at_first_enemy_until_final_pierces_the_line() -> void:
	var s := _setup()
	var w: Node = s[1]
	var first := _enemy(Vector2(1060.0, 970.0))
	var origin: Node2D = w.muzzle if w.muzzle else w
	var dir: Vector2 = (first.global_position - origin.global_position).normalized()
	var behind := _enemy(origin.global_position + dir * 120.0)
	var off_line := _enemy(origin.global_position + dir * 90.0 + dir.orthogonal() * 40.0)
	_open_beam(w, first)
	assert(w._beam_extra_targets.is_empty(), "temelde ışın ilk düşmanda durur")
	assert(w.beam_targets() == [first], "yalnız birincil hedef")
	w.set_enchant({"id": "goz_kamastiran", "ups": [0, 1, 2, 3], "final": true})
	w._update_beam_reach(first, origin)
	assert(w._beam_extra_targets.has(behind), "final: arkadaki delinir")
	assert(not w._beam_extra_targets.has(off_line), "hattın dışındaki vurulmaz")
	assert(w._beam_fx.pierce, "efekt menzil sonuna uzanır")
	assert(is_equal_approx(origin.global_position.distance_to(w._beam_end), w.attack_range), "uç = menzil sonu")
	_cleanup()


func test_three_second_hold_dazzles_and_switching_resets() -> void:
	var s := _setup()
	var w: Node = s[1]
	var a := _enemy(Vector2(1100.0, 990.0))
	var b := _enemy(Vector2(1100.0, 1040.0))
	_open_beam(w, a)
	var beh: Node = w.enchant_behavior
	assert(beh != null and beh.has_method("beam_glow"), "özellik davranışı kurulu")
	for i in range(5):
		beh.process_extra(0.5)
	assert(a.elements.is_empty(), "2,5 sn: henüz kamaşmadı")
	assert(absf(beh.beam_glow(a) - 2.5 / 3.0) < 0.01, "ışın tuttukça parlar")
	## hedef değişir -> a'nın sayacı sıfırlanır
	w._beam_target = b
	beh.process_extra(0.5)
	w._beam_target = a
	for i in range(5):
		beh.process_extra(0.5)
	assert(a.elements.is_empty(), "hedef değişince süre sıfırdan başlar")
	beh.process_extra(0.5)
	assert(a.elements.size() == 1 and a.elements[0][0] == "stun" and is_equal_approx(float(a.elements[0][1]["dur"]), 1.5), "3 sn -> 1,5 sn kamaşma: %s" % str(a.elements))
	assert(beh.beam_glow(a) >= 2.0, "kamaşma sürerken ışın en parlak")
	beh.process_extra(1.0)
	assert(a.elements.size() == 1, "kamaşma bitene kadar sayılmaz")
	_cleanup()


func test_boss_is_weakened_not_stunned_and_upgrades_apply() -> void:
	var s := _setup({"id": "goz_kamastiran", "ups": [0, 2, 3]})
	var w: Node = s[1]
	var boss := _enemy(Vector2(1100.0, 990.0))
	boss.is_boss = true
	var near := _enemy(Vector2(1130.0, 990.0))
	_open_beam(w, boss)
	var beh: Node = w.enchant_behavior
	beh.process_extra(2.0) ## Hızlı Kamaşma: 2 sn yeter
	var kinds: Array = boss.elements.map(func(x): return x[0])
	assert(kinds == ["weaken"], "boss kamaşmaz, zayıflar: %s" % str(kinds))
	assert(is_equal_approx(float(boss.elements[0][1]["pct"]), 0.2), "%20 az hasar")
	var nk: Array = near.elements.map(func(x): return x[0])
	assert(nk.has("stun") and nk.has("vuln"), "Işık Saçılması + Kör Nokta yakındakine: %s" % str(nk))
	assert(near.hits.size() == 1, "Işık Saçılması hasarı")
	_cleanup()


func test_weakened_enemy_deals_less_damage() -> void:
	_prev_scene = get_tree().current_scene
	NetworkManager.is_multiplayer_active = false
	var e: Node = _track(EnemyScene.instantiate())
	assert(is_equal_approx(Enemy.damage_mult_of(e), 1.0), "normalde tam hasar")
	e.apply_element_host("weaken", {"pct": 0.2, "dur": 3.0}, 0)
	assert(is_equal_approx(Enemy.damage_mult_of(e), 0.8), "zayıflatılmış: %80")
	assert(is_equal_approx(Enemy.damage_mult_of(null), 1.0), "kaynaksız hasar etkilenmez")
	_cleanup()
