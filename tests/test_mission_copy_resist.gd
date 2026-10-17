extends Node

## 2026-10-14 (kullanıcı: "kopya ilk levellerde çok dayanıklı çok az hasar veren bir şeyken late gamede tek yiyor"): kopya kaynak oyuncunun
## statlarına AYNEN sahip (çarpansız), verdiği/aldığı hasar %50 azalmayla başlar, oyunda geçen her 20 sn'de %1 artar, en çok %95.
## Hasar sayısı + vuran oyuncunun istatistik/can çalma kancaları da kopyada çalışır (yaratıklar gibi).

const CopyScript: GDScript = preload("res://scripts/mission_player_copy.gd")

var _spawned: Array[Node] = []
var _saved_time: float = 0.0


func _make_copy(max_hp: float = 200.0, max_shield: float = 0.0) -> Node2D:
	var c: Node2D = CopyScript.new()
	add_child(c)
	_spawned.append(c)
	c.call("setup", 1, 0, 0, max_hp, max_shield, 150.0, 100.0, true)
	c.global_position = Vector2(500.0, 500.0)
	return c


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	GameManager.game_time = _saved_time


func test_resist_schedule() -> void:
	_saved_time = GameManager.game_time
	assert(is_equal_approx(CopyScript.resist_at(0.0), 0.50), "başlangıç %50")
	assert(is_equal_approx(CopyScript.resist_at(19.9), 0.50), "20 sn dolmadan artmaz")
	assert(is_equal_approx(CopyScript.resist_at(20.0), 0.51), "20 sn -> %51")
	assert(is_equal_approx(CopyScript.resist_at(400.0), 0.70), "400 sn -> %70")
	assert(is_equal_approx(CopyScript.resist_at(900.0), 0.95), "900 sn -> %95 (tavan)")
	assert(is_equal_approx(CopyScript.resist_at(5000.0), 0.95), "tavan aşılmaz")
	assert(is_equal_approx(CopyScript.resist_at(-5.0), 0.50), "negatif süre güvenli")
	_cleanup()


func test_copy_has_source_stats_unchanged() -> void:
	_saved_time = GameManager.game_time
	var c: Node2D = _make_copy(200.0, 80.0)
	assert(is_equal_approx(float(c.get("max_health")), 200.0), "can çarpansız: %s" % str(c.get("max_health")))
	assert(is_equal_approx(float(c.get("max_shield")), 80.0), "kalkan çarpansız: %s" % str(c.get("max_shield")))
	assert(is_equal_approx(float(c.get("move_speed")), 150.0), "hız çarpansız: %s" % str(c.get("move_speed")))
	var c2: Node2D = _make_copy(200.0, 0.0)
	assert(is_zero_approx(float(c2.get("max_shield"))), "oyuncunun kalkanı yoksa kopyanın da yok")
	_cleanup()


func test_damage_taken_follows_resist() -> void:
	_saved_time = GameManager.game_time
	GameManager.game_time = 0.0
	var c: Node2D = _make_copy(200.0, 0.0)
	c.call("take_damage", 100.0)
	assert(is_equal_approx(float(c.get("health")), 150.0), "%%50 azaltma: 100 vuruş 50 yer, kalan %s" % str(c.get("health")))
	GameManager.game_time = 400.0 ## %70
	c.call("take_damage", 100.0)
	assert(is_equal_approx(float(c.get("health")), 120.0), "%%70 azaltma: 100 vuruş 30 yer, kalan %s" % str(c.get("health")))
	GameManager.game_time = 2000.0 ## %95
	c.call("take_damage", 100.0)
	assert(is_equal_approx(float(c.get("health")), 115.0), "%%95 azaltma: 100 vuruş 5 yer, kalan %s" % str(c.get("health")))
	_cleanup()


func test_damage_dealt_follows_resist() -> void:
	_saved_time = GameManager.game_time
	GameManager.game_time = 0.0
	var c: Node2D = _make_copy(200.0, 0.0)
	c.set("damage_bonus", 100.0)
	var d0: float = float(c.call("_weapon_hit_damage", 1.0))
	assert(is_equal_approx(d0, 50.0) or is_equal_approx(d0, 75.0), "başta verdiği hasar %%50 (kritikte x1,5): %s" % str(d0))
	GameManager.game_time = 900.0
	var d1: float = float(c.call("_weapon_hit_damage", 1.0))
	assert(is_equal_approx(d1, 5.0) or is_equal_approx(d1, 7.5), "15. dakikada %%95 az: %s" % str(d1))
	_cleanup()


func test_hit_shows_damage_number_and_credits_dealer() -> void:
	_saved_time = GameManager.game_time
	GameManager.game_time = 0.0
	var dealer := Node.new()
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar match_damage_dealt: float = 0.0\nvar healed_from: float = 0.0\nfunc on_dealer_hit(a: float, _area: bool = false) -> void:\n\thealed_from += a\n"
	gs.reload()
	dealer.set_script(gs)
	dealer.add_to_group("player")
	add_child(dealer)
	_spawned.append(dealer)
	var c: Node2D = _make_copy(200.0, 0.0)
	c.call("take_damage", 40.0)
	assert(is_equal_approx(float(dealer.get("match_damage_dealt")), 20.0), "maç istatistiği gerçek hasarı (%%50 azalmış) saymalı: %s" % str(dealer.get("match_damage_dealt")))
	assert(is_equal_approx(float(dealer.get("healed_from")), 20.0), "can çalma kancası çağrılmalı: %s" % str(dealer.get("healed_from")))
	assert((c.get("_dmg_ids") as Array).size() == 1, "hasar sayısı doğmalı")
	## Uzaktan gelen hasar (host'ta): sayı/istatistik vuran makinede yapılır, burada tekrarlanmaz.
	c.call("_apply_hit", 40.0)
	assert(is_equal_approx(float(dealer.get("match_damage_dealt")), 20.0), "uzaktan hasar vurana ikinci kez yazılmamalı")
	assert((c.get("_dmg_ids") as Array).size() == 1, "uzaktan hasar ikinci sayı doğurmamalı")
	assert(is_equal_approx(float(c.get("health")), 160.0), "iki vuruş toplam 40 hasar: %s" % str(c.get("health")))
	_cleanup()


## Kopyanın mermisi silahın kendi isabet efektini/sesini taşır (projectile.gd impact_scene / impact_sounds) - "silahlarının efektleri yok".
func test_copy_bolts_carry_weapon_impact_fx() -> void:
	var with_impact: int = 0
	var ranged: int = 0
	for key in CopyScript.RemotePlayerScript.WEAPON_SCENES.keys():
		var info: Dictionary = CopyScript.attack_info(str(key))
		if info.get("proj") != null:
			ranged += 1
			if not (info.get("impact", {}) as Dictionary).is_empty():
				with_impact += 1
	print("impact_fx: %d / %d menzilli silahta isabet efekti/sesi var" % [with_impact, ranged])
	assert(ranged > 0 and with_impact > 0, "en az bir menzilli silahın isabet efekti okunmalı (%d/%d)" % [with_impact, ranged])
