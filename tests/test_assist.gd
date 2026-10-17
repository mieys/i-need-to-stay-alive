extends Node

## ASİST sistemi (2026-10-15, bkz. scripts/assist.gd): altın bölüşümü + destek kaydı + Şovalye kubbesi alanı.

const AssistScript = preload("res://scripts/assist.gd")

const T0 := 100000


func _dmg(d: float, t: int = T0) -> Dictionary:
	return {"dmg": d, "t": t}


func _sum(m: Dictionary) -> int:
	var s: int = 0
	for k in m.keys():
		s += int(m[k])
	return s


func test_small_gold_not_split() -> void:
	var r: Dictionary = AssistScript.compute(3, 1, {1: _dmg(50.0), 2: _dmg(50.0)}, {}, T0)
	assert(r == {1: 3}, "3 altın bölünmez: %s" % [r])


func test_damage_assist_split() -> void:
	var r: Dictionary = AssistScript.compute(10, 1, {1: _dmg(70.0), 2: _dmg(30.0)}, {}, T0)
	assert(int(r[1]) == 7 and int(r[2]) == 3 and _sum(r) == 10, "70/30 -> 7/3: %s" % [r])


func test_killer_keeps_at_least_half() -> void:
	var r: Dictionary = AssistScript.compute(10, 1, {1: _dmg(10.0), 2: _dmg(90.0)}, {}, T0)
	assert(int(r[1]) == 5 and int(r[2]) == 5, "öldüren en az yarı: %s" % [r])


func test_tiny_old_hit_is_not_assist() -> void:
	## %5 hasar + 8 sn'den eski vuruş = asist değil.
	var r: Dictionary = AssistScript.compute(10, 1, {1: _dmg(95.0), 2: _dmg(5.0, T0 - 20000)}, {}, T0)
	assert(r == {1: 10}, "eski küçük vuruş asist değil: %s" % [r])
	## Aynı %5 hasar ama son 8 sn içinde: asist sayılır ama payı 1 altına yetmiyorsa öldürende kalır.
	var r2: Dictionary = AssistScript.compute(10, 1, {1: _dmg(95.0), 2: _dmg(5.0, T0 - 2000)}, {}, T0)
	assert(_sum(r2) == 10 and int(r2[1]) >= 5, "toplam korunur: %s" % [r2])


func test_old_big_hit_is_not_assist() -> void:
	## Tüm asistler öldürmeden önceki 8 sn içinde olmalı: 8 sn'den eski büyük hasar bile asist vermez.
	var r: Dictionary = AssistScript.compute(10, 1, {1: _dmg(40.0), 2: _dmg(60.0, T0 - 9000)}, {}, T0)
	assert(r == {1: 10}, "8 sn'den eski hasar asist değil: %s" % [r])
	var r2: Dictionary = AssistScript.compute(10, 1, {1: _dmg(40.0), 2: _dmg(60.0, T0 - 7000)}, {}, T0)
	assert(r2.has(2) and int(r2[2]) == 5, "8 sn içindeki hasar asist: %s" % [r2])


func test_support_assist_needs_participant_target() -> void:
	## 3 oyuncu: 1 öldürür, 2 hasar verir, 3 (destek) 2'ye can bastı -> pay alır; 4 kimseye destek vermedi -> almaz.
	var support: Dictionary = {3: [2], 4: [9]}
	var r: Dictionary = AssistScript.compute(20, 1, {1: _dmg(60.0), 2: _dmg(40.0)}, support, T0)
	assert(r.has(3) and int(r[3]) >= 1, "destek asisti pay almalı: %s" % [r])
	assert(not r.has(4), "katılmayana destek asist değil: %s" % [r])
	assert(_sum(r) == 20 and int(r[1]) >= 10, "toplam 20, öldüren >=10: %s" % [r])


func test_support_for_killer_counts() -> void:
	var r: Dictionary = AssistScript.compute(20, 1, {1: _dmg(100.0)}, {3: [1]}, T0)
	assert(r.has(3) and int(r[3]) >= 1 and _sum(r) == 20, "öldürene destek de asist: %s" % [r])


func test_support_registry_expires_and_holds() -> void:
	AssistScript.reset()
	AssistScript.note_support(5, 6, 0.0, T0)
	assert(AssistScript.active_support(T0 + 7000).get(5, []) == [6], "8 sn içinde aktif")
	assert(AssistScript.active_support(T0 + 9000).is_empty(), "8 sn sonra düşer")
	AssistScript.note_support(5, 6, 10.0, T0) ## süren buff: bitişten sonra 8 sn daha
	assert(AssistScript.active_support(T0 + 15000).get(5, []) == [6], "buff sürerken aktif")
	assert(AssistScript.active_support(T0 + 19000).is_empty(), "buff bitişinden 8 sn sonra düşer")
	AssistScript.note_support(5, 5, 0.0, T0)
	assert(AssistScript.active_support(T0).is_empty() or not AssistScript.active_support(T0).has(5) or AssistScript.active_support(T0).get(5, []) != [5], "kendine destek yok")
	AssistScript.reset()


func test_zone_is_2_to_1_ellipse() -> void:
	var c := Vector2.ZERO
	assert(AssistScript._zone_contains(c, 126.0, Vector2(120, 0)), "yatay 120 içeride")
	assert(not AssistScript._zone_contains(c, 126.0, Vector2(0, 100)), "dikey 100 dışarıda (yarıçap 63)")
	assert(AssistScript._zone_contains(c, 126.0, Vector2(0, 60)), "dikey 60 içeride")


func test_kinds_reported() -> void:
	var kinds: Dictionary = {}
	AssistScript.compute(20, 1, {1: _dmg(50.0), 2: _dmg(30.0), 3: _dmg(20.0)}, {3: [1], 4: [1]}, T0, kinds)
	assert(int(kinds[2]) == AssistScript.KIND_DAMAGE, "salt hasar")
	assert(int(kinds[3]) == (AssistScript.KIND_DAMAGE | AssistScript.KIND_SUPPORT), "hasar + destek = 3")
	assert(int(kinds[4]) == AssistScript.KIND_SUPPORT, "salt destek")
