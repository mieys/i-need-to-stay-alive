extends Node

## 2026-10-11: silah özellikleri (scripts/weapon_traits/) HER düşmana işler - kullanıcı: "kopyanı öldür görevinde alev asasının püskürtmesi
## çalışmıyor". Kök neden: özellik kodu hedefi "apply_element'i olan" diye süzüyordu, görev kopyasında yoktu. Ayrıca Ateş Asası
## püskürtmesi saldırı hızıyla (diğer silahların atış aralığıyla aynı kaynak) hızlanır.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const CopyScript: GDScript = preload("res://scripts/mission_player_copy.gd")

var _spawned: Array[Node] = []
var _saved_weapons: Array = []


func _make_player_with(key: String) -> Node2D:
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	NetworkManager.is_multiplayer_active = false
	GameManager.owned_items = []
	GameManager.owned_weapons = []
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(2000.0, 2000.0)
	p.max_health = 100000.0
	p.health = 100000.0
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry(key, 1, 0)]
	assert(p.buy_weapon_copy(key, 1), "silah verilemedi: %s" % key)
	return p


func _make_copy(pos: Vector2) -> Node2D:
	var c: Node2D = CopyScript.new()
	add_child(c)
	_spawned.append(c)
	c.call("setup", 1, 0, 0, 1000.0, 0.0, 0.0, 0.0, true)
	c.global_position = pos
	return c


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	GameManager.owned_weapons = _saved_weapons


func test_fire_staff_spray_hurts_and_burns_the_mission_copy() -> void:
	var p: Node2D = _make_player_with("fire_staff")
	var w: Node = p.owned_weapon_nodes[0]
	var beh: Node = w.get("enchant_behavior")
	assert(beh != null and str(beh.get_script().resource_path) == "res://scripts/weapon_traits/ates_nefesi.gd", "Ateş Asası özelliği silah klasöründen: %s" % str(beh.get_script().resource_path if beh else "yok"))
	var c: Node2D = _make_copy(p.global_position + Vector2(70.0, 0.0))
	assert(beh.call("is_enemy", c), "görev kopyası özellik kodunda düşman sayılmalı")
	var hp0: float = float(c.get("health")) + float(c.get("shield"))
	var burned: bool = false
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and is_instance_valid(c):
		await get_tree().physics_frame
		if c.call("is_burning"):
			burned = true
	assert(is_instance_valid(c), "kopya bu sürede ölmemeli (canı yüksek)")
	var hp1: float = float(c.get("health")) + float(c.get("shield"))
	assert(hp1 < hp0, "püskürtme kopyaya hasar vermeli: %.1f -> %.1f" % [hp0, hp1])
	assert(burned, "püskürtme kopyayı yakmalı")
	_cleanup()


func test_spray_tick_scales_with_attack_speed() -> void:
	var p: Node2D = _make_player_with("fire_staff")
	var w: Node = p.owned_weapon_nodes[0]
	var beh: Node = w.get("enchant_behavior")
	w.call("set_fire_rate_mult", 1.0)
	var slow: float = float(beh.call("_interval"))
	w.call("set_fire_rate_mult", 0.5) ## saldırı hızı 2 kat (kart/eşya çarpanı)
	var fast: float = float(beh.call("_interval"))
	assert(absf(fast - slow * 0.5) < 0.005, "saldırı hızı 2 kat -> tik aralığı yarıya: %.3f -> %.3f" % [slow, fast])
	w.set("fire_rate_multiplier", 0.5) ## Matthew/Talon tarzı silah çarpanı da işler
	assert(float(beh.call("_interval")) < fast - 0.001, "silah hızlanması da püskürtmeyi hızlandırmalı")
	w.set("fire_rate_multiplier", 1.0)
	_cleanup()


func test_copy_element_inputs() -> void:
	var c: Node2D = _make_copy(Vector2(500.0, 500.0))
	c.call("apply_element", "stun", {"dur": 1.0})
	assert(c.call("_is_disabled_now"), "sersemletme kopyayı durdurur")
	c.call("apply_element", "bleed", {"tick": 5.0, "stacks": 3, "cap": 10})
	var hp0: float = float(c.get("health")) + float(c.get("shield"))
	c.call("_process_dots", 1.01)
	var hp1: float = float(c.get("health")) + float(c.get("shield"))
	assert(hp1 < hp0, "kanama saniyede hasar verir: %.1f -> %.1f" % [hp0, hp1])
	c.call("apply_element", "mark", {"stacks": 1}) ## bilinmeyen element: hata vermeden yok sayılır
	_cleanup()


## 2026-10-12 (kullanıcı: "kopyalar yaratık gibi algılanmıyor, yeteneklerimiz işlemiyor"): yetenekler `has_method("apply_slow")` vb. ile
## bakıp yoksa sessizce atlıyordu. Kopyada enemy.gd'nin yetenek giriş noktaları artık var ve kopyanın element sistemine yönleniyor.
func test_copy_exposes_creature_effect_api() -> void:
	var c: Node2D = _make_copy(Vector2(500.0, 500.0))
	for m in ["apply_burn", "apply_poison", "apply_bleed", "apply_bee_poison", "apply_slow", "apply_frost_slow", "apply_chill", "apply_stun",
			"apply_freeze_full", "apply_root", "apply_skill_push", "apply_fear", "apply_taunt", "apply_mark_stack", "get_mark_damage_mult",
			"is_shocked", "try_shaman_weapon_burn", "apply_element_host", "take_damage_host"]:
		assert(c.has_method(m), "kopyada yok: %s" % m)
	c.call("apply_slow", 0.5, 2.0)
	assert(is_equal_approx(float(c.get("_slow_pct")), 0.5), "yavaşlatma uygulanmalı")
	c.call("apply_stun", 1.0)
	assert(c.call("_is_disabled_now"), "apply_stun kopyayı durdurmalı")
	c.set("_stun_until_msec", 0)
	c.call("apply_freeze_full", 1.0)
	assert(c.call("is_frozen_now"), "apply_freeze_full kopyayı dondurmalı")
	c.call("apply_burn", 4.0, 3.0)
	assert(c.call("is_burning"), "apply_burn yakmalı")
	c.call("apply_mark_stack", 10)
	assert(float(c.call("get_mark_damage_mult")) > 1.0, "işaret hasar çarpanı vermeli")
	var hp0: float = float(c.get("health")) + float(c.get("shield"))
	c.call("apply_poison", 5.0, 5.0, 4.0)
	c.call("_process_dots", 1.01)
	assert(float(c.get("health")) + float(c.get("shield")) < hp0, "zehir/yanma saniyelik hasar vermeli")
	_cleanup()
