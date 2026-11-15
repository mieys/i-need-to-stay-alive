extends Node

## 2026-11-13 (kullanıcı: "Talon'un Q'sunun bonusları ve saldırı olayı hemen aktifleşmiyor, bir süre bekleyip aktifleşiyor; ayrıca bu skill
## basıldığı anda oto saldırı bekleme süresi sıfırlanmalı"): FireTimer wait_time değişince SÜREN turu kısaltmaz -> Silah Salvosu (Q) basılınca
## eski (yavaş) aralığın kalanı beklenirdi. weapon.gd reset_attack_cooldown basışta turu sıfırlar: ilk atış hemen, sonrası güncel aralıkla.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const S: GDScript = preload("res://scripts/spiritual_skills.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1
var _prev_spirit: String = ""


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	_prev_spirit = GameManager.selected_spiritual
	GameManager.selected_char_id = 1
	GameManager.selected_character = Characters.get_def(1)["skill"]
	GameManager.selected_spiritual = S.PARA
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


func _weapon(player: Node, key: String) -> Node:
	player.buy_weapon_copy(key, 1)
	for w in player.owned_weapon_nodes:
		if w.get_meta("shop_key", "") == key:
			return w
	return null


## Süren yavaş tur: 3 sn aralık, 2.9 sn kaldı gibi.
func _slow_cycle(w: Node) -> void:
	w.fire_timer.start(3.0)
	w.fire_timer.wait_time = 3.0


func test_salvo_press_restarts_the_fire_cycle_at_the_new_rate() -> void:
	var player: Node = _make_player()
	var w: Node = _weapon(player, "dagger")
	assert(w != null, "silah alınmalı")
	_slow_cycle(w)
	assert(w.fire_timer.time_left > 2.5, "ön koşul: yavaş tur süruyor")
	player._skill_talon_weapon_salvo()
	assert(w.fire_timer.time_left <= 0.011, "basışta tur sıfırlanmalı (ilk atış hemen): kalan %f" % w.fire_timer.time_left)
	var expected: float = maxf(0.05, w._effective_fire_wait())
	assert(absf(w.fire_timer.wait_time - expected) < 0.0001, "sonraki aralık güncel (salvo) hızı olmalı: %f vs %f" % [w.fire_timer.wait_time, expected])
	assert(w.fire_timer.wait_time < w._base_fire_rate * 0.6, "salvo hız bonusu hemen işlemeli: %f (taban %f)" % [w.fire_timer.wait_time, w._base_fire_rate])
	_cleanup()


func test_salvo_press_resets_magazine_weapons_too() -> void:
	var player: Node = _make_player()
	var w: Node = _weapon(player, "tabanca")
	assert(w != null and w.max_ammo > 0, "şarjörlü silah alınmalı")
	_slow_cycle(w)
	player._skill_talon_weapon_salvo()
	assert(w.fire_timer.time_left <= 0.011, "şarjörlü silahta da tur sıfırlanmalı: %f" % w.fire_timer.time_left)
	var expected: float = maxf(0.05, w._mag_next_gap(maxf(0.05, w._effective_fire_wait())))
	assert(absf(w.fire_timer.wait_time - expected) < 0.0001, "şarjör aralığı güncel hızdan: %f vs %f" % [w.fire_timer.wait_time, expected])
	_cleanup()


func test_reload_in_progress_is_not_cancelled_by_the_reset() -> void:
	var player: Node = _make_player()
	var w: Node = _weapon(player, "tabanca")
	_slow_cycle(w)
	w.is_reloading = true
	w.reset_attack_cooldown()
	assert(w.fire_timer.time_left > 2.5, "doldururken zamanlayıcıya dokunulmaz (doldurma yarıda kesilmez)")
	w.is_reloading = false
	_cleanup()


func test_bow_skips_the_draw_so_the_first_arrow_is_immediate() -> void:
	var player: Node = _make_player()
	var bow: Node = _weapon(player, "yay")
	assert(bow != null and bow.draw_before_fire, "yay alınmalı")
	bow._draw_ready = false ## çekiliş sürüyor
	player._skill_talon_weapon_salvo()
	assert(bow._draw_ready, "salvo basışında yay çekilişi atlanıp ok hazır olmalı")
	_cleanup()


func test_beam_weapon_is_untouched() -> void:
	var player: Node = _make_player()
	var w: Node = _weapon(player, "lightning_staff")
	assert(w != null and w.continuous_beam, "ışın asası alınmalı")
	w.reset_attack_cooldown() ## ışında bekleme yok: sessizce no-op, çökmez
	player._skill_talon_weapon_salvo()
	_cleanup()
