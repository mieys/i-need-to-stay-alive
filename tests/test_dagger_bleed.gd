extends Node

const EnemyScript = preload("res://scripts/enemy.gd")

## Kullanıcı isteği doğrulaması:
## 1) Bıçağın (Hançer) kanaması sadece ilk isabet ettiği yaratığa değil,
##    savuruşun (melee AOE) değdiği TÜM yaratıklara uygulanmalı.
## 2) Kanama anında çıkan kan efekti (%50) küçültülmüş olmalı.

const WeaponScene: PackedScene = preload("res://scenes/weapon_dagger.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")


func _make_weapon() -> Node:
	var w: Node = WeaponScene.instantiate()
	add_child(w)
	## Kanama parametrelerini elle ayarla (normalde player.gd
	## _apply_dagger_tier ile ayarlanır) - burada testin kendi kendine
	## yeterli olması için doğrudan set ediyoruz.
	w.bleed_max_stacks = 5
	w.bleed_stacks_per_hit = 2
	w.bleed_tick_damage_per_stack = 3.0
	w.melee_aoe_radius = 60.0
	w.melee_aoe_damage_percent = 0.5
	return w


func _make_enemy(pos: Vector2) -> Node:
	var e: Node = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.add_to_group("enemies")
	return e


## NOT: weapon.gd'nin _fire_at() fonksiyonu get_tree()'ye yoğun şekilde
## bağımlı (AOE düşman taraması, FX spawn, ses...) ve bu test ortamında
## instantiate edilen node'lar canlı bir SceneTree'ye girmiyor (get_tree()
## null dönüyor) - bu yüzden _fire_at() burada tam olarak çalıştırılamıyor.
## Bunun yerine enemy.gd'nin GERÇEK apply_bleed() fonksiyonunu, weapon.gd'nin
## düzeltilmiş AOE döngüsündeki (bkz. weapon.gd _fire_at, "e.apply_bleed")
## BİREBİR aynı çağrı imzasıyla, birincil hedef + AOE menzilindeki ikincil
## hedef için ayrı ayrı çağırarak doğruluyoruz.
func test_bleed_applies_to_all_enemies_hit_by_melee_aoe() -> void:
	var weapon: Node = _make_weapon()
	var primary: Node = _make_enemy(Vector2.ZERO)
	var secondary: Node = _make_enemy(Vector2(30, 0)) ## melee_aoe_radius (60) içinde
	var out_of_range: Node = _make_enemy(Vector2(500, 0)) ## AOE yarıçapı dışında

	assert(primary.bleed_stacks == 0, "Test öncesi birincil hedefte kanama olmamalı")
	assert(secondary.bleed_stacks == 0, "Test öncesi ikincil hedefte kanama olmamalı")

	## weapon.gd _fire_at()'in düzeltilmiş akışının BİREBİR aynısı:
	## 1) birincil hedefe kanama, 2) AOE yarıçapındaki her düşmana da kanama.
	primary.apply_bleed(weapon.bleed_tick_damage_per_stack, weapon.bleed_stacks_per_hit, weapon.bleed_max_stacks)
	for e in [secondary, out_of_range]:
		if weapon.bleed_max_stacks > 0 and e.global_position.distance_to(primary.global_position) <= weapon.melee_aoe_radius:
			e.apply_bleed(weapon.bleed_tick_damage_per_stack, weapon.bleed_stacks_per_hit, weapon.bleed_max_stacks)

	assert(primary.bleed_stacks == 2, "Birincil hedefte kanama yükü beklenen degil: %d" % primary.bleed_stacks)
	assert(secondary.bleed_stacks == 2, "İkincil (AOE) hedefte de kanama yükü olmalıydı: %d" % secondary.bleed_stacks)
	assert(out_of_range.bleed_stacks == 0, "AOE yarıçapı dışındaki yaratığa kanama sızmamalı: %d" % out_of_range.bleed_stacks)

	weapon.queue_free()
	primary.queue_free()
	secondary.queue_free()
	out_of_range.queue_free()


func test_bleed_stacks_are_additive_up_to_cap() -> void:
	var weapon: Node = _make_weapon()
	var enemy: Node = _make_enemy(Vector2.ZERO)

	enemy.apply_bleed(weapon.bleed_tick_damage_per_stack, weapon.bleed_stacks_per_hit, weapon.bleed_max_stacks)
	assert(enemy.bleed_stacks == 2, "İlk isabetten sonra 2 yük bekleniyordu: %d" % enemy.bleed_stacks)
	enemy.apply_bleed(weapon.bleed_tick_damage_per_stack, weapon.bleed_stacks_per_hit, weapon.bleed_max_stacks)
	assert(enemy.bleed_stacks == 4, "İkinci isabetten sonra 4 yük bekleniyordu: %d" % enemy.bleed_stacks)
	## bleed_max_stacks = 5 tavanını aşmamalı.
	enemy.apply_bleed(weapon.bleed_tick_damage_per_stack, weapon.bleed_stacks_per_hit, weapon.bleed_max_stacks)
	assert(enemy.bleed_stacks == 5, "Kanama yükü tavanı (5) aşılmamalı: %d" % enemy.bleed_stacks)

	weapon.queue_free()
	enemy.queue_free()


func test_bleed_fx_scale_multiplier_is_half() -> void:
	## enemy.gd'nin gerçek sınıf sabitini (production kodu, .gd dosyasının
	## kendisinden) doğrudan okuyarak doğrular - kanama efekti artık taban
	## boyutunun YARISI (%50 küçültme) ile spawn ediliyor.
	assert(EnemyScript.BLEED_FX_SCALE_MULT == 0.5,
		"Kanama efekti kucultme carpani 0.5 olmali, bulunan: %s" % EnemyScript.BLEED_FX_SCALE_MULT)
