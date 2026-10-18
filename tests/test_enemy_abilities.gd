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
	## 2026-09-26: "oyundaki farelerin canını ve kalkanını %30 azalt" -> "%50 yapalım"
	var r: Dictionary = SpawnerScript.FAMILY_TRAITS["rat"]
	assert(is_equal_approx(r["health"], 0.5) and is_equal_approx(r["shield"], 0.5) and not r.has("speed"), "fare can/kalkan x0.5")
	assert(is_equal_approx(EnemyScript.ORK_RAGE_HP_THRESHOLD, 0.5))
	## normal öfke +%100 (x2), ork öfkesi bunun 1.5 katı artış: +%150 (x2.5)
	## 2026-09-25: öfke hızı kesintisi (x0.9/1.1) ork öfkesine de uygulanır.
	## 2026-10-06: ork özel yeteneği %15 zayıflatıldı - hız ARTIŞI +%150 -> +%127,5 (x2.275).
	assert(is_equal_approx(EnemyScript.ORK_RAGE_SPEED_MULT, (1.0 + 1.5 * 0.85) * 0.9 / 1.1), "ork öfke hızı: %s" % EnemyScript.ORK_RAGE_SPEED_MULT)
	assert(is_equal_approx(EnemyScript.RAGE_SPEED_MULT, 2.0 * 0.9 / 1.1), "normal öfke değişmemeli")


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

## Donmuş/sersemlemiş yaratığın uyarısı başlamış büyüsü (lazer, diken) iptal olur (kullanıcı: "donan düşmanlar hala uzaktan ateş edebiliyor").
class _FakeCaster extends Node2D:
	var frozen: bool = false
	func is_incapacitated_now() -> bool:
		return frozen


func test_frozen_caster_cancels_telegraphed_spell() -> void:
	var c := _FakeCaster.new()
	assert(not AbilitiesScript.caster_disabled(c, {}))
	c.frozen = true
	assert(AbilitiesScript.caster_disabled(c, {}))
	assert(not AbilitiesScript.caster_disabled(null, {"src": 5})) ## tek oyunculu/host'ta kaynak yoksa iptal yok
	c.free()


## FPS (2026-10-18): process_fast, bekleme sayacı sürerken process() ile BİREBİR aynı durum değişimini hedef sorgusu OLMADAN yapar (enemy.gd _ew_tick hızlı yolu).
class _FakeOwner extends Node2D:
	var is_ability_invisible: bool = false
	var is_dead: bool = false
	func set_ability_invisible(on: bool) -> void:
		is_ability_invisible = on
	func _find_closest_target_player() -> Node2D:
		return null


func _cooldown_trace(fam: String, use_fast: bool, steps: int, invisible_start: bool) -> Array:
	seed(7)
	var owner := _FakeOwner.new()
	var ab = AbilitiesScript.new()
	ab.setup(owner, fam)
	if invisible_start:
		owner.is_ability_invisible = true
		ab._timer = 0.4
	var trace: Array = []
	var dt: float = 1.0 / 60.0
	for i in range(steps):
		if not (use_fast and ab.process_fast(dt)):
			ab.process(dt, null, INF)
		trace.append([ab._cd, ab._timer, ab._pending, ab._vision_check, ab._entry_delay, owner.is_ability_invisible])
	owner.free()
	return trace


func test_process_fast_is_identical_to_process_for_cooldown_counters() -> void:
	for fam in ["hayalet", "vampire", "rontgen", "iblis", "agac"]:
		var plain: Array = _cooldown_trace(fam, false, 1200, false)
		var fast: Array = _cooldown_trace(fam, true, 1200, false)
		assert(plain == fast, "%s: process_fast sayaçları process ile aynı olmalı" % fam)
	## görünmez hayalet: süre sayacı + bitince görünür olma
	var inv_plain: Array = _cooldown_trace("hayalet", false, 120, true)
	var inv_fast: Array = _cooldown_trace("hayalet", true, 120, true)
	assert(inv_plain == inv_fast, "görünmez hayalet: process_fast aynı olmalı")
	assert(inv_plain[0][5] == true and inv_plain[119][5] == false, "hayalet 0,4 sn sonra yeniden görünür olmalı")


func test_process_fast_never_changes_state_when_it_returns_false() -> void:
	var owner := _FakeOwner.new()
	var ab = AbilitiesScript.new()
	ab.setup(owner, "iblis")
	ab._cd = 0.01 ## bu karede biter -> hızlı yol işi bırakmalı ve hiçbir şeyi DEĞİŞTİRMEMELİ
	var before: float = ab._cd
	assert(not ab.process_fast(1.0 / 60.0), "bekleme bu karede bitiyorsa asıl iş var: false")
	assert(ab._cd == before, "false dönerken sayaç değişmemeli (process kendisi azaltır)")
	ab._cd = 5.0
	assert(ab.process_fast(1.0 / 60.0) and is_equal_approx(ab._cd, 5.0 - 1.0 / 60.0), "bekleme sürerken sayaç azalır, true")
	owner.free()
