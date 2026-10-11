extends Node

## Şovalye Adam pasifi "Dirençli Duruş" (2026-10-12 rework): canı %40'un altındayken aldığı hasar %20 azalır (player.gd _low_hp_passive_active /
## take_damage). Eşik tam %40'ta aktif DEĞİL (altında), ölü/yere düşmüşken aktif sayılmaz, diğer karakterlerde hiç yok.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SOVALYE_CHAR_ID := 7

var _spawned: Array[Node] = []
var _saved_char: int = 0


func _make_player(char_id: int) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	_saved_char = GameManager.selected_char_id
	GameManager.selected_char_id = char_id
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	return p


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	GameManager.selected_char_id = _saved_char


## Hasar sonrası kaybedilen can (kalkan/kaçınma/kritik rastgeleliği olmasın diye kalkan 0, kaçınma 0).
func _hp_lost(p: Node, health_ratio: float, hit: float) -> float:
	p.item_shield_hp = 0.0
	p.health = p.max_health * health_ratio
	var before: float = p.health
	p._last_damage_taken_at_msec = -100000 ## temas kilidi (CONTACT_DAMAGE_IFRAME_MS) ikinci vuruşu yutmasın
	p.take_damage(hit)
	return before - p.health


func test_sovalye_takes_twenty_percent_less_below_forty_percent_health() -> void:
	var p: Node = _make_player(SOVALYE_CHAR_ID)
	assert(is_equal_approx(p.low_hp_damage_reduction, 0.20) and is_equal_approx(p.low_hp_threshold, 0.40), "Şovalye tanımından okunmalı")
	p.max_health = 1000.0
	var normal: float = _hp_lost(p, 0.50, 50.0)
	var low: float = _hp_lost(p, 0.39, 50.0)
	assert(normal > 0.0, "temel hasar işlemeli")
	assert(absf(low - normal * 0.8) < 0.01, "%40 altında hasar x0,8 olmalı: normal " + str(normal) + " / düşük canlı " + str(low))
	_cleanup()


func test_threshold_boundary_and_other_characters() -> void:
	var p: Node = _make_player(SOVALYE_CHAR_ID)
	p.max_health = 1000.0
	p.health = 400.0
	assert(not p._low_hp_passive_active(), "tam %40'ta aktif değil (eşiğin ALTINDA)")
	p.health = 399.0
	assert(p._low_hp_passive_active(), "%39,9'da aktif")
	_cleanup()
	var other: Node = _make_player(1) ## Talon
	other.max_health = 1000.0
	other.health = 100.0
	assert(not other._low_hp_passive_active(), "diğer karakterlerde pasif yok")
	_cleanup()
