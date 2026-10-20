extends Node

## 2026-10-17 (kullanıcı: "oyundaki tüm silahların saldırı hızını %30 azalt"): GameManager.WEAPON_ATTACK_SPEED_MULT (0.7) weapon.gd _effective_fire_wait'in
## SON adımında uygulanır -> her silahın atış aralığı taban / 0.7 (= %30 yavaş). Işın/alev tikleri aynı orandan, yay çekilişi alt sınırından yavaşlar.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const WeaponCatalogScript: GDScript = preload("res://scripts/weapon_catalog.gd")

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


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	GameManager.owned_weapons = _saved_weapons


func test_constant_is_seventy_percent() -> void:
	assert(is_equal_approx(GameManager.WEAPON_ATTACK_SPEED_MULT, 0.7), "saldırı hızı çarpanı 0.7 (-%30)")


## Her silah anahtarı: kart/eşya/pasif çarpanı 1 iken etkin aralık = taban / 0.7.
func test_every_weapon_is_thirty_percent_slower() -> void:
	for key in WeaponCatalogScript.KEYS:
		var p: Node2D = _make_player_with(str(key))
		var w: Node = p.owned_weapon_nodes[0]
		w.call("set_fire_rate_mult", 1.0)
		w.set("fire_rate_multiplier", 1.0)
		var base: float = float(w.get("_base_fire_rate"))
		var wait: float = float(w.call("_effective_fire_wait"))
		assert(base > 0.0, "%s taban aralığı yok" % key)
		assert(absf(wait - base / 0.7) < 0.0005, "%s: etkin aralık taban/0.7 olmalı: %f vs %f" % [key, wait, base / 0.7])
		_cleanup()


## Kart hızlanması ORANI korur: x2 hız -> aralık yarıya (ikisi de 0.7 cezalı) ve %600 üst sınırı hâlâ taban/7 üzerinden (sonra /0.7).
func test_card_speedup_and_cap_scale_with_the_penalty() -> void:
	var p: Node2D = _make_player_with("tufek")
	var w: Node = p.owned_weapon_nodes[0]
	w.set("fire_rate_multiplier", 1.0)
	w.call("set_fire_rate_mult", 1.0)
	var slow: float = float(w.call("_effective_fire_wait"))
	w.call("set_fire_rate_mult", 0.5)
	assert(absf(float(w.call("_effective_fire_wait")) - slow * 0.5) < 0.0005, "x2 saldırı hızı aralığı yarıya indirmeli")
	var base: float = float(w.get("_base_fire_rate"))
	w.call("set_fire_rate_mult", 1.0 / 20.0) ## sınırın çok ötesi
	assert(absf(float(w.call("_effective_fire_wait")) - base / (1.0 + GameManager.ATTACK_SPEED_CAP_PERCENT / 100.0) / 0.7) < 0.0005, "sınır: taban/5,5 (tavan %%450), sonra genel -%%30: %f" % float(w.call("_effective_fire_wait")))
	_cleanup()


## Işın silahı (Yıldırım Asası): tik aralığı etkin aralık / taban oranından gelir -> taban tik 1.0 sn yerine 1/0.7 sn.
func test_beam_tick_ratio_includes_the_penalty() -> void:
	var p: Node2D = _make_player_with("lightning_staff")
	var w: Node = p.owned_weapon_nodes[0]
	w.set("fire_rate_multiplier", 1.0)
	w.call("set_fire_rate_mult", 1.0)
	var ratio: float = float(w.call("_effective_fire_wait")) / float(w.get("_base_fire_rate"))
	assert(absf(ratio - 1.0 / 0.7) < 0.001, "ışın tik oranı 1/0.7: %f" % ratio)
	_cleanup()


## Yay: çekiliş animasyonu hızı alt sınırı 1.0 değil 0.7 -> döngü 0.625 sn yerine 0.625/0.7 sn.
func test_bow_draw_cycle_is_slower() -> void:
	var p: Node2D = _make_player_with("yay")
	var w: Node = p.owned_weapon_nodes[0]
	w.set("fire_rate_multiplier", 1.0)
	w.call("set_fire_rate_mult", 1.0)
	w.call("_start_draw_cycle")
	var spr: Node = w.get("icon_sprite")
	assert(spr is AnimatedSprite2D, "yay ikonu AnimatedSprite2D olmalı")
	assert(absf((spr as AnimatedSprite2D).speed_scale - 0.7) < 0.001, "yay çekiliş hızı 0.7: %f" % (spr as AnimatedSprite2D).speed_scale)
	_cleanup()
