extends Node

## Kullanıcı isteklerinin doğrulaması (2026-09-21 turu):
## 1) Şovalye kalkan baloncuğu: içine giren DOST agroyu çekemesin - baloncuğa doğru yürüyen
##    her yaratık baloncuğun SAHİBİNE (Şovalye) odaklansın ve kalkana saldırsın.
## 2) Şovalye E (Kalkan Yenileme) çevredeki yaratıkların agrosunu 5sn kendine çekmeli.
## 3) Şovalye baloncuğu hasar azaltımı %95 (PALADIN_ULTI_SHIELD_COST_MULT 0.05).
## 4) Tüm kalkanların soğurması +5 puan; seviye başına +20 can / +2 saldırı gücü.
## 5) Can çalma kademeleri %1/1.5/2/2.5; Pençe can emme = verilen hasarın yüzdesi.
## 6) Talon Silah Salvosu: namlular (aynalanan tabanca/tüfek dahil) DIŞA baksın.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const PlayerScript: GDScript = preload("res://scripts/player.gd")
const LevelUpScreenScript: GDScript = preload("res://scripts/level_up_screen.gd")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")

const DT := 1.0 / 30.0

var _spawned: Array[Node] = []


func _track(node: Node) -> Node:
	_spawned.append(node)
	return node


func _cleanup() -> void:
	_reset_zone_cache()
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


## enemy.gd baloncuk sahiplerini kare başına BİR kez önbellekliyor (Engine.get_physics_frames);
## testte fizik karesi ilerlemediği için her senaryodan önce elle sıfırlanmalı.
func _reset_zone_cache() -> void:
	EnemyScript.reset_zone_owners_cache()


## Şovalye gibi davranan sahte oyuncu: enemy.gd'nin okuduğu alanlar + kalkan hasarı kaydı.
class FakePlayer extends Node2D:
	var paladin_zone_active: bool = false
	var paladin_zone_radius: float = 126.0
	var is_dead: bool = false
	var barrier_damage_taken: float = 0.0
	var normal_damage_taken: float = 0.0

	func take_paladin_barrier_damage(amount: float, _attacker: Node2D = null) -> void:
		barrier_damage_taken += amount

	func take_damage(amount: float, _source: Node = null) -> void:
		normal_damage_taken += amount


func _make_player(pos: Vector2, group: String = "player") -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group(group)
	add_child(p)
	p.global_position = pos
	_track(p)
	return p


func _make_enemy(pos: Vector2) -> Node2D:
	_reset_zone_cache()
	var enemy: Node2D = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.speed = 90.0
	_track(enemy)
	return enemy


## Baloncuk sahibi (grup "player") + baloncuğun İÇİNDE duran dost (grup "player_allies", enemy.gd
## bunu da aday sayıyor) ile yaratığın davranışını adım adım ölçer.
func test_creature_targets_bubble_owner_when_ally_is_inside() -> void:
	var paladin := _make_player(Vector2.ZERO)
	paladin.paladin_zone_active = true
	paladin.paladin_zone_radius = 126.0
	## Dost baloncuğun içinde ve yaratığa Şovalye'den DAHA YAKIN.
	var ally := _make_player(Vector2(80.0, 0.0), "player_allies")
	var enemy: Node2D = _make_enemy(Vector2(400.0, 0.0))
	enemy._cached_target_player = ally ## "en yakın hedef" = dost (bug'ın kaynağı)

	var target: Node2D = enemy._get_target_player()
	assert(target == paladin, "Baloncuktaki dost yerine baloncuğun sahibi hedef olmalı, bulunan: %s" % target)

	## Sonuç: yaratık sınıra yürüyüp KALKANA saldırmalı, dosta değil.
	var t: float = 0.0
	while t < 12.0:
		enemy._cached_target_player = ally
		enemy._physics_process(DT)
		t += DT
	assert(paladin.barrier_damage_taken > 0.0,
		"Yaratık baloncuğa (kalkana) saldırmalıydı, kalkan hasarı: %s" % paladin.barrier_damage_taken)
	assert(ally.get("normal_damage_taken") == 0.0 and paladin.normal_damage_taken == 0.0,
		"Baloncuk açıkken normal temas hasarı verilmemeli")
	var dist: float = enemy.global_position.distance_to(paladin.global_position)
	assert(dist >= 126.0 - 1.0, "Yaratık baloncuğun içine girmemeli, mesafe: %s" % dist)
	_cleanup()


func test_creature_far_from_bubble_keeps_normal_target() -> void:
	var paladin := _make_player(Vector2.ZERO)
	paladin.paladin_zone_active = true
	## Baloncuğun DIŞINDAKİ dost: kural devreye girmemeli.
	var ally := _make_player(Vector2(600.0, 0.0), "player_allies")
	var enemy: Node2D = _make_enemy(Vector2(800.0, 0.0))
	enemy._cached_target_player = ally
	assert(enemy._get_target_player() == ally, "Baloncuk dışındaki dost normal hedef kalmalı")
	## Baloncuk kapalıyken hiçbir şey değişmemeli.
	paladin.paladin_zone_active = false
	_reset_zone_cache()
	var inside_ally := _make_player(Vector2(60.0, 0.0), "player_allies")
	enemy._cached_target_player = inside_ally
	assert(enemy._get_target_player() == inside_ally, "Baloncuk kapalıyken hedef değişmemeli")
	_cleanup()


func test_taunt_locks_target_for_five_seconds_even_if_ally_is_closer() -> void:
	var paladin := _make_player(Vector2.ZERO)
	var ally := _make_player(Vector2(300.0, 0.0), "player_allies")
	var enemy: Node2D = _make_enemy(Vector2(340.0, 0.0)) ## dosta çok yakın, Şovalye'ye uzak
	enemy._cached_target_player = ally
	assert(enemy._get_target_player() == ally, "Kışkırtma öncesi en yakın hedef dost")

	assert(is_equal_approx(PlayerScript.PALADIN_TAUNT_DURATION, 5.0), "Kışkırtma süresi 5sn olmalı")
	enemy.apply_taunt(PlayerScript.PALADIN_TAUNT_DURATION, paladin)
	enemy._cached_target_player = ally
	assert(enemy._get_target_player() == paladin, "Kışkırtılan yaratık Şovalye'yi hedeflemeli")

	## 4.5sn sonra hâlâ kilitli, 5sn'yi geçince serbest.
	var t: float = 0.0
	while t < 4.5:
		ally.global_position = enemy.global_position + Vector2(10.0, 0.0) ## dost hep en yakın aday kalsın
		enemy._cached_target_player = ally
		enemy._physics_process(DT)
		t += DT
	ally.global_position = enemy.global_position + Vector2(10.0, 0.0)
	enemy._cached_target_player = ally
	assert(enemy._get_target_player() == paladin, "4.5sn sonra kışkırtma sürmeli")
	while t < 5.4:
		ally.global_position = enemy.global_position + Vector2(10.0, 0.0)
		enemy._cached_target_player = ally
		enemy._physics_process(DT)
		t += DT
	ally.global_position = enemy.global_position + Vector2(10.0, 0.0)
	enemy._cached_target_player = ally
	assert(enemy._get_target_player() == ally, "5sn sonra yaratık normal hedefine dönmeli")
	_cleanup()


func test_taunt_is_dropped_when_taunter_dies() -> void:
	var paladin := _make_player(Vector2.ZERO)
	var ally := _make_player(Vector2(300.0, 0.0), "player_allies")
	var enemy: Node2D = _make_enemy(Vector2(340.0, 0.0))
	enemy.apply_taunt(5.0, paladin)
	paladin.is_dead = true
	enemy._cached_target_player = ally
	assert(enemy._get_target_player() == ally, "Kışkırtan ölünce yaratık boşa kilitli kalmamalı")
	_cleanup()


func test_paladin_bubble_reduction_is_ninety_five_percent() -> void:
	assert(is_equal_approx(PlayerScript.PALADIN_ULTI_SHIELD_COST_MULT, 0.05),
		"Baloncuğun hasar azaltımı %%95 (çarpan 0.05) olmalı, bulunan: %s" % PlayerScript.PALADIN_ULTI_SHIELD_COST_MULT)
	var def: Dictionary = Characters.get_def(7)
	assert(str(def.get("skill_desc", "")).find("%95") != -1, "Ulti açıklaması %%95 yazmalı: %s" % def.get("skill_desc"))
	assert(str(def.get("skill2_desc", "")).find("5 saniye") != -1, "E açıklaması kışkırtmayı anlatmalı: %s" % def.get("skill2_desc"))


func test_shield_absorption_bases_are_up_five_points() -> void:
	var t: Dictionary = PlayerScript.SHIELD_TYPES
	assert(is_equal_approx(float(t["shield_standart"]["absorption"]), 0.65), "Standart 0.65")
	assert(is_equal_approx(float(t["shield_enerji"]["absorption"]), 0.55), "Enerji 0.55")
	assert(is_equal_approx(float(t["shield_kale"]["absorption"]), 0.75), "Kale 0.75")
	assert(is_equal_approx(float(t["shield_savas"]["absorption"]), 0.60), "Savaş 0.60")
	for key in t:
		assert(float(t[key]["absorption"]) <= PlayerScript.SHIELD_PROTECTION_CAP, "%s tavanı aşmamalı" % key)


func test_level_up_grants_twenty_health_and_two_damage() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_track(player)
	var hp0: float = player.max_health
	var dmg0: float = player.damage_bonus
	player.on_team_leveled_up(2)
	assert(is_equal_approx(player.max_health - hp0, 20.0), "Seviye başına +20 can, bulunan: %s" % (player.max_health - hp0))
	assert(is_equal_approx(player.damage_bonus - dmg0, 2.0), "Seviye başına +2 saldırı gücü, bulunan: %s" % (player.damage_bonus - dmg0))
	_cleanup()


func test_lifesteal_card_and_item_tiers() -> void:
	var expected: Array = [0.01, 0.015, 0.02, 0.025]
	for i in range(4):
		assert(is_equal_approx(TierSystem.lifesteal_percent_for_tier(i + 1), expected[i]), "Kart tier %d" % (i + 1))
		## Vampir Dişi eşyası: taban x ITEM_TIER_POWER AYNI merdiveni vermeli.
		var item_base: float = float(Items.get_def("vampir_disi")["stats"]["lifesteal_percent"])
		assert(is_equal_approx(item_base * float(Items.ITEM_TIER_POWER[i]), expected[i]), "Eşya tier %d" % (i + 1))
	## Kartın gerçekten uyguladığı değer ve ekranda yazan sayı.
	var screen: Node = LevelUpScreenScript.new()
	_track(screen)
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_track(player)
	for tier in range(1, 5):
		var before: float = player.lifesteal_percent
		player.apply_upgrade("lifesteal", tier)
		assert(is_equal_approx(player.lifesteal_percent - before, expected[tier - 1]),
			"apply_upgrade tier %d kazancı, bulunan: %s" % [tier, player.lifesteal_percent - before])
		var shown: String = screen._scaled_desc_value("+%1", tier, "lifesteal")
		var want: String = "+%%%s" % (str(int(expected[tier - 1] * 100.0)) if tier % 2 == 1 else "%.1f" % (expected[tier - 1] * 100.0))
		assert(shown == want, "Kart yazısı tier %d: '%s' beklenen '%s'" % [tier, shown, want])
	_cleanup()


func test_pence_life_drain_is_percent_of_damage_dealt() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_track(player)
	var weapon: Node = load("res://scenes/weapon_pence.tscn").instantiate()
	player.add_child(weapon)
	weapon.lifesteal_percent = 0.05 ## %5 can emme
	player.max_health = 500.0
	player.health = 100.0
	weapon._apply_weapon_lifesteal(200.0)
	assert(is_equal_approx(player.health, 110.0), "200 hasarın %%5'i = 10 can, bulunan: %s" % player.health)
	weapon._apply_weapon_lifesteal(40.0)
	assert(is_equal_approx(player.health, 112.0), "40 hasarın %%5'i = 2 can, bulunan: %s" % player.health)
	## Tam canda hiçbir şey olmamalı / tavanı aşmamalı.
	player.health = 499.0
	weapon._apply_weapon_lifesteal(1000.0)
	assert(is_equal_approx(player.health, 500.0), "Can tavanı aşılmamalı")
	_cleanup()


## Talon Silah Salvosu: hem düz hem aynalanan (tabanca/tüfek) silahlar HER slot açısında dışa
## bakmalı. Sprite'ın gerçekte baktığı yön, çizimin ileri açısı (forward) + rotasyon (aynalıysa
## ileri açı PI - forward olur) ile hesaplanıp slot açısıyla karşılaştırılıyor.
func test_talon_salvo_icon_pose_points_outward_for_every_angle_and_flip_state() -> void:
	var forwards: Array[float] = [-48.5, -13.51, -5.74, 134.0, 0.0, -92.36, -90.9]
	for forward_deg: float in forwards:
		var forward: float = deg_to_rad(forward_deg)
		for mirror: bool in [false, true]:
			for step in range(24):
				var angle: float = TAU * float(step) / 24.0 + 0.03
				var pose: Dictionary = TalonFormationMath.compute_icon_pose(angle, forward, mirror)
				var flipped: bool = pose["flip_h"] if mirror else false
				## flip_h: yerel x ayna -> çizimin ileri açısı PI - forward olur.
				var art_forward: float = (PI - forward) if flipped else forward
				var facing: float = art_forward + float(pose["rotation"])
				var diff: float = absf(angle_difference(facing, angle))
				assert(diff < 0.001, "Namlu dışa bakmıyor: forward=%s mirror=%s angle=%s facing=%s" % [forward_deg, mirror, angle, facing])


## Ayna durumu her yönde tutarlı olmalı: sola bakan slotlar aynalı, sağa bakanlar aynasız
## (weapon.gd _update_aim ile aynı kural, dizilim bitince geçiş sıçramasın).
func test_talon_salvo_mirror_state_matches_update_aim_rule() -> void:
	for step in range(24):
		var angle: float = TAU * float(step) / 24.0 + 0.03
		var pose: Dictionary = TalonFormationMath.compute_icon_pose(angle, deg_to_rad(-13.5), true)
		assert(bool(pose["flip_h"]) == (cos(angle) < 0.0), "flip_h, sola bakarken true olmalı: %s" % angle)


## Gerçek oyuncu + gerçek silah sahneleriyle: dizilim uygulandığında (bayat flip_h olsa bile) HER silahın
## sprite'ı slot açısında, yani merkezden DIŞA bakmalı.
func test_talon_formation_on_real_weapons_faces_outward_even_with_stale_mirror() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_track(player)
	for key in ["tabanca", "tufek", "fire_staff", "dagger"]:
		player.buy_weapon_copy(key, 1)
	var iconed: Array = player._talon_iconed_weapons()
	assert(iconed.size() >= 4, "Dört silah da ikonlu olmalı, bulunan: %d" % iconed.size())
	## Son nişanın bıraktığı BAYAT durum: aynalanan silahlar sola bakarken kalmış olsun.
	for w in iconed:
		if bool(w.mirror_icon_when_aiming_left):
			w.icon_sprite.flip_h = true
			w._icon_flipped = true
	for angle_offset: float in [0.0, 1.3, 2.9, 4.4, 6.0]:
		player._talon_set_weapons_circular(130.0, angle_offset)
		for i in range(iconed.size()):
			var w: Node = iconed[i]
			var slot: Dictionary = TalonFormationMath.compute_slot(i, iconed.size(), 130.0, angle_offset)
			var forward: float = deg_to_rad(float(w.sprite_forward_angle_deg))
			var art_forward: float = (PI - forward) if w.icon_sprite.flip_h else forward
			var facing: float = art_forward + w.icon_sprite.rotation
			var diff: float = absf(angle_difference(facing, float(slot["angle"])))
			assert(diff < 0.001, "%s namlusu dışa bakmıyor (offset %s, slot %d): fark %s rad" % [w.get_meta("shop_key"), angle_offset, i, diff])
	_cleanup()
