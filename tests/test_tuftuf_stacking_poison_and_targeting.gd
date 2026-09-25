extends Node

## Kullanıcı isteği: "Tüftüfün zehri 100 defaya kadar stacklenebilsin ve zehir 20 saniye boyunca her
## saniye saldırı gücünün %5'i kadar hasar versin, ayrıca tüftüf canı yüksek olan yaratıklara veya hiç
## zehirlenmemiş yaratıklara öncelik versin, öncelik sırası: (canı yüksek > hiç zehirlenmemiş > tüm yaratıklar)"

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const TuftufTargeting: GDScript = preload("res://scripts/tuftuf_targeting.gd")

var _spawned: Array[Node] = []


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _make_enemy() -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.max_health = 1000000.0
	e.health = 1000000.0
	_spawned.append(e)
	return e


## Zehir hasarını saniyede 0.1'lik adımlarla ilerletir.
func _run_poison(e: Node2D, seconds: float) -> void:
	var steps: int = int(round(seconds / 0.1))
	for i in range(steps):
		e._process_poison(0.1)


func test_stacks_add_up_to_one_hundred_and_then_refresh_the_oldest() -> void:
	var e: Node2D = _make_enemy()
	for i in range(150):
		e.apply_poison(2.0, 100.0, 20.0)
	assert(e.get_poison_stack_count() == 100, "Yük sayısı 100'de kalmalı, bulunan: %d" % e.get_poison_stack_count())
	assert(e.is_poisoned(), "Zehirli görünmeli (efekt kurulmuş olmalı)")
	## Yükler yaşlansın; üst sınırdayken yeni isabet EN ESKİ yükü tazelemeli, sayı artmamalı.
	_run_poison(e, 5.0)
	e.apply_poison(2.0, 100.0, 20.0)
	assert(e.get_poison_stack_count() == 100, "Üst sınırda yeni isabet yük sayısını artırmamalı")
	var refreshed: int = 0
	for t in e._poison_stack_time:
		if t > 19.5:
			refreshed += 1
	assert(refreshed == 1, "Tam bir yük tazelenmeli, tazelenen: %d" % refreshed)
	_cleanup()


func test_one_stack_deals_five_percent_attack_power_per_second_for_twenty_seconds() -> void:
	var e: Node2D = _make_enemy()
	var attack_power: float = 40.0
	var per_second: float = attack_power * 0.05 ## %5 = 2.0 (eski Tüftüf oranı; zehir artık silahta değil, enemy.gd altyapısı test ediliyor)
	assert(is_equal_approx(per_second, 2.0), "40 saldırı gücünün %%5'i 2 olmalı")
	e.apply_poison(per_second, 100.0, 20.0)
	var before: float = e.health
	_run_poison(e, 20.5)
	var dealt: float = before - e.health
	assert(absf(dealt - 40.0) < 0.5, "Tek yük 20sn'de 20x2=40 hasar vermeli, verilen: %s" % dealt)
	assert(e.get_poison_stack_count() == 0 and not e.is_poisoned(), "Süre bitince yük ve efekt kalkmalı")
	_cleanup()


func test_damage_scales_with_the_number_of_stacks() -> void:
	var e: Node2D = _make_enemy()
	for i in range(10):
		e.apply_poison(2.0, 100.0, 20.0)
	var before: float = e.health
	_run_poison(e, 5.0)
	var dealt: float = before - e.health
	## Hasar saniyede bir topluca uygulanıyor: uygulanan + henüz uygulanmamış birikmiş = tam 100.
	assert(absf(dealt + e._poison_damage_accum - 100.0) < 0.01,
		"10 yük 5sn'de 10x2x5=100 hasar biriktirmeli, uygulanan %s + bekleyen %s" % [dealt, e._poison_damage_accum])
	assert(dealt >= 80.0, "Tikler saniyede bir uygulanmalı, uygulanan: %s" % dealt)
	_cleanup()


## _apply_damage her vuruşa en az 1 hasar uyguluyor; küçük zehir tikleri 1'e şişmemeli (tek yük x 5 saldırı gücü = 0.25/sn).
func test_tiny_poison_ticks_are_not_inflated_by_the_minimum_damage_rule() -> void:
	var e: Node2D = _make_enemy()
	e.apply_poison(0.25, 100.0, 20.0)
	var before: float = e.health
	_run_poison(e, 20.5)
	var dealt: float = before - e.health
	assert(absf(dealt - 5.0) <= 1.0, "0.25/sn x 20sn = 5 hasar (en fazla 1 yuvarlama), verilen: %s" % dealt)
	_cleanup()


func test_each_stack_keeps_its_own_lifetime() -> void:
	var e: Node2D = _make_enemy()
	e.apply_poison(2.0, 100.0, 20.0)
	_run_poison(e, 10.0)
	e.apply_poison(2.0, 100.0, 20.0)
	assert(e.get_poison_stack_count() == 2, "İki yük olmalı")
	_run_poison(e, 10.5) ## ilk yük 20.5sn'de bitti, ikincinin 10.5sn'si geçti
	assert(e.get_poison_stack_count() == 1, "İlk yük bitmeli, ikincisi sürmeli, kalan: %d" % e.get_poison_stack_count())
	assert(e.is_poisoned(), "Kalan yük varken hâlâ zehirli olmalı")
	_run_poison(e, 10.0)
	assert(e.get_poison_stack_count() == 0 and not e.is_poisoned(), "İkinci yük de bitince zehir tamamen kalkmalı")
	_cleanup()


## enemy.gd'nin TuftufTargeting'in okuduğu alanları: global_position, health, is_dead, is_poisoned().
class FakeEnemy extends Node2D:
	var health: float = 100.0
	var is_dead: bool = false
	var poisoned: bool = false

	func is_poisoned() -> bool:
		return poisoned


func _fake(pos: Vector2, hp: float, poisoned: bool = false) -> FakeEnemy:
	var f := FakeEnemy.new()
	f.health = hp
	f.poisoned = poisoned
	add_child(f)
	f.global_position = pos
	_spawned.append(f)
	return f


func test_targeting_prefers_high_health_over_everything() -> void:
	var crowd: Array = []
	for i in range(6):
		crowd.append(_fake(Vector2(20.0 + i * 5.0, 0.0), 50.0)) ## zehirsiz, yakın, düşük can
	var tank := _fake(Vector2(120.0, 0.0), 400.0, true) ## uzak, ZEHİRLİ ama canı çok yüksek
	crowd.append(tank)
	var picked: Node2D = TuftufTargeting.pick(crowd, Vector2.ZERO, 200.0)
	assert(picked == tank, "Canı yüksek yaratık (zehirli olsa da) öncelikli olmalı")
	_cleanup()


func test_targeting_falls_back_to_unpoisoned_when_no_high_health() -> void:
	var poisoned_a := _fake(Vector2(10.0, 0.0), 100.0, true)
	var poisoned_b := _fake(Vector2(20.0, 0.0), 105.0, true)
	var fresh := _fake(Vector2(60.0, 0.0), 95.0, false) ## en az canlı ama zehirsiz
	var picked: Node2D = TuftufTargeting.pick([poisoned_a, poisoned_b, fresh], Vector2.ZERO, 200.0)
	assert(picked == fresh, "Yüksek canlı yokken zehirlenmemiş olan seçilmeli")
	_cleanup()


func test_targeting_falls_back_to_everyone_when_all_are_poisoned() -> void:
	var a := _fake(Vector2(10.0, 0.0), 100.0, true)
	var b := _fake(Vector2(20.0, 0.0), 110.0, true)
	var picked: Node2D = TuftufTargeting.pick([a, b], Vector2.ZERO, 200.0)
	assert(picked == b, "Hepsi zehirliyse menzildeki en canlı seçilmeli")
	_cleanup()


func test_targeting_ignores_dead_out_of_range_and_untargetable() -> void:
	var dead := _fake(Vector2(10.0, 0.0), 900.0)
	dead.is_dead = true
	var far := _fake(Vector2(999.0, 0.0), 900.0)
	var hidden := _fake(Vector2(30.0, 0.0), 900.0)
	var ok := _fake(Vector2(40.0, 0.0), 10.0)
	var picked: Node2D = TuftufTargeting.pick([dead, far, hidden, ok], Vector2.ZERO, 200.0, func(e): return e != hidden)
	assert(picked == ok, "Ölü/menzil dışı/görünmeyen yaratıklar aday olmamalı")
	assert(TuftufTargeting.pick([dead, far], Vector2.ZERO, 200.0) == null, "Aday yoksa null dönmeli")
	_cleanup()
