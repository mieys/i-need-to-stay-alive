extends Node

## Yaratık yetenekleri (kullanıcı isteği 2026-09-24, bkz. scripts/enemy_abilities.gd) - statik kurallar ve pişirilmiş
## efekt kaynakları. (Oyun içi davranış - ışınlanma, lazer isabeti, asit tiki - gerçek 2 pencereli testle doğrulanmalı.)

const EnemyScript = preload("res://scripts/enemy.gd")
const AbilitiesScript = preload("res://scripts/enemy_abilities.gd")
const SpawnerScript = preload("res://scripts/enemy_spawner.gd")
const PlayerScript = preload("res://scripts/player.gd")


func test_family_parsing() -> void:
	assert(EnemyScript.family_of_id("vampire2") == "vampire")
	assert(EnemyScript.family_of_id("hayalet13") == "hayalet")
	assert(EnemyScript.family_of_id("golem") == "golem")
	assert(EnemyScript.family_of_id("") == "")


func test_which_families_have_active_abilities() -> void:
	for fam in ["hayalet", "vampire", "rontgen", "iblis", "agac"]:
		assert(AbilitiesScript.family_has_ability(fam), "%s yetenekli olmalı" % fam)
	for fam in ["golem", "zombie", "ork", "rat", "slime"]:
		assert(not AbilitiesScript.family_has_ability(fam), "%s aktif yetenek nesnesi oluşturmamalı" % fam)


func test_stat_traits_and_rage() -> void:
	var g: Dictionary = SpawnerScript.FAMILY_TRAITS["golem"]
	assert(is_equal_approx(g["health"], 1.3) and is_equal_approx(g["shield"], 1.3) and is_equal_approx(g["speed"], 0.8))
	var z: Dictionary = SpawnerScript.FAMILY_TRAITS["zombie"]
	assert(is_equal_approx(z["health"], 1.3) and not z.has("shield"), "zombide sadece can artar")
	assert(is_equal_approx(EnemyScript.ORK_RAGE_HP_THRESHOLD, 0.5))
	## normal öfke +%100 (x2), ork öfkesi bunun 1.5 katı artış: +%150 (x2.5)
	assert(is_equal_approx(EnemyScript.ORK_RAGE_SPEED_MULT, 2.5), "ork öfke hızı: %s" % EnemyScript.ORK_RAGE_SPEED_MULT)


func test_timings_match_request() -> void:
	## hayalet: 3-4 sn görünmez + 6-7 sn bekleme (~10 sn döngü)
	assert(AbilitiesScript.GHOST_INVIS_MIN >= 3.0 and AbilitiesScript.GHOST_INVIS_MAX <= 4.0)
	assert(AbilitiesScript.GHOST_COOLDOWN_MIN >= 6.0 and AbilitiesScript.GHOST_COOLDOWN_MAX <= 7.0)
	## vampir: görüldükten 1-6 sn sonra, 15 sn'de bir
	assert(is_equal_approx(AbilitiesScript.VAMPIRE_DELAY_MIN, 1.0) and is_equal_approx(AbilitiesScript.VAMPIRE_DELAY_MAX, 6.0))
	assert(is_equal_approx(AbilitiesScript.VAMPIRE_COOLDOWN, 15.0))
	## ağaç dikenleri 10 sn bekleme, zombi asidi 4 sn, yanma 3 sn, lazer kalkana x2
	assert(AbilitiesScript.THORNS_COOLDOWN >= 10.0 and AbilitiesScript.THORNS_WARN_TIME > 0.0)
	assert(is_equal_approx(AbilitiesScript.ACID_DURATION, 4.0))
	assert(is_equal_approx(PlayerScript.ENEMY_BURN_DURATION, 3.0))
	assert(is_equal_approx(PlayerScript.ENEMY_LASER_SHIELD_MULT, 2.0))
	assert(AbilitiesScript.LASER_WARN_TIME > 0.0, "lazerden önce uyarı çizgisi olmalı")


func test_baked_fx_resources_have_their_animations() -> void:
	var expect := {
		"ghost": ["vanish", "appear"], "fireball": ["fly"], "fire_impact": ["play"], "burn": ["loop"],
		"laser_flash": ["muzzle", "hit"], "vampire": ["blink"], "zombie": ["burst"],
		"acid": ["intro", "loop", "outro"], "thorns_warn": ["loop"], "thorns": ["erupt"],
	}
	for name in expect:
		var sf: SpriteFrames = load("res://assets/fx/enemy_abilities/%s_frames.tres" % name) as SpriteFrames
		assert(sf != null, "%s_frames.tres yüklenemedi (Godot import edildi mi?)" % name)
		for anim in expect[name]:
			assert(sf.has_animation(anim) and sf.get_frame_count(anim) > 0, "%s: '%s' animasyonu yok" % [name, anim])
	for i in range(4):
		assert(load("res://assets/fx/enemy_abilities/laser_beam_%d.png" % i) != null)
	assert(load("res://assets/fx/enemy_abilities/laser_warn.png") != null)
	assert(load("res://assets/ui/status/burn.png") != null)
