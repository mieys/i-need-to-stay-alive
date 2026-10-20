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
	## 2026-10-19: eşik 4 -> 2 (ortalama öldürme altını 2-3; eşik 4'ken asist payı hep sıfırdı).
	var r: Dictionary = AssistScript.compute(1, 1, {1: _dmg(50.0), 2: _dmg(50.0)}, {}, T0)
	assert(r == {1: 1}, "1 altın bölünmez: %s" % [r])
	var r3: Dictionary = AssistScript.compute(3, 1, {1: _dmg(50.0), 2: _dmg(50.0)}, {}, T0)
	assert(r3 == {1: 2, 2: 1}, "3 altın artık bölünür (öldüren 2, asist 1): %s" % [r3])
	var r2: Dictionary = AssistScript.compute(2, 1, {1: _dmg(50.0), 2: _dmg(50.0)}, {}, T0)
	assert(r2 == {1: 1, 2: 1}, "2 altın bölünür: %s" % [r2])


func test_fractional_assist_gold_carries_over() -> void:
	## %5 hasar veren asistçinin payı 10 altında 0,5: tek öldürmede 0, ama birikir - 2. öldürmede 1 altın alır.
	var carry: Dictionary = {}
	var d: Dictionary = {1: _dmg(95.0), 2: _dmg(5.0)}
	var a: Dictionary = AssistScript.compute(10, 1, d, {}, T0, {}, carry)
	assert(a == {1: 10}, "1. öldürmede pay kesir: %s" % [a])
	var b: Dictionary = AssistScript.compute(10, 1, d, {}, T0, {}, carry)
	assert(b == {1: 9, 2: 1}, "2. öldürmede birikmiş 1 altın ödenir: %s" % [b])
	assert(float(carry.get(2, 0.0)) < 0.01, "ödenince kesir sıfırlanır: %s" % [carry])
	## Birikim olmadan (varsayılan boş sözlük) eski saf bölüşüm.
	var c: Dictionary = AssistScript.compute(10, 1, d, {}, T0)
	assert(c == {1: 10}, "carry verilmezse birikim yok: %s" % [c])


func test_carry_never_takes_killers_minimum() -> void:
	## Birikmiş kesirler toplansa bile öldüren en az %40'ının yukarı yuvarlanmışını tutar (2 altında en az 1).
	var carry: Dictionary = {2: 0.99}
	var r: Dictionary = AssistScript.compute(2, 1, {1: _dmg(10.0), 2: _dmg(90.0)}, {}, T0, {}, carry)
	assert(_sum(r) == 2 and int(r[1]) >= 1, "2 altında öldüren >=1: %s" % [r])
	var r5: Dictionary = AssistScript.compute(5, 1, {1: _dmg(10.0), 2: _dmg(90.0)}, {}, T0, {}, {2: 0.99})
	assert(_sum(r5) == 5 and int(r5[1]) >= 2, "5 altında öldüren >=2 (%%40 yukarı yuvarlı): %s" % [r5])


## TAKIM PAYI (2026-10-19, madde 308): altının %20'si yakındaki canlı oyunculara eşit, hasar/asist kuralından bağımsız.
func test_nearby_mates_filters_range_and_downed() -> void:
	var at := Vector2(1000.0, 1000.0)
	var cands: Array = [
		{"peer_id": 1, "pos": at + Vector2(100.0, 0.0), "down": false},
		{"peer_id": 2, "pos": at + Vector2(AssistScript.TEAM_SHARE_RANGE + 1.0, 0.0), "down": false},
		{"peer_id": 3, "pos": at + Vector2(0.0, 300.0), "down": true},
		{"peer_id": 4, "pos": at + Vector2(0.0, -AssistScript.TEAM_SHARE_RANGE), "down": false},
		{"peer_id": 4, "pos": at, "down": false},
		{"peer_id": 0, "pos": at, "down": false},
	]
	var m: Array = AssistScript.nearby_mates(cands, at)
	assert(m == [1, 4], "menzil içi + düşmemiş + tekil + geçerli id: %s" % [m])


func test_team_share_equal_split_excludes_killer() -> void:
	assert(AssistScript.team_share(20, 1, [1, 2]) == {2: 2}, "20 altın 2 kişi: havuz 4, kişi başı 2")
	assert(AssistScript.team_share(40, 1, [1, 2, 3, 4]) == {2: 2, 3: 2, 4: 2}, "40 altın 4 kişi: kişi başı 2")
	assert(AssistScript.team_share(20, 1, [2]) == {2: 2}, "öldüren listede olmasa da gruba sayılır")
	assert(AssistScript.team_share(20, 1, [1]).is_empty() and AssistScript.team_share(20, 1, []).is_empty(), "tek kişi: takım payı yok")
	assert(AssistScript.team_share(0, 1, [1, 2]).is_empty() and AssistScript.team_share(20, 0, [1, 2]).is_empty(), "altın/öldüren yoksa boş")


func test_team_share_carry_accumulates_and_is_capped() -> void:
	var carry: Dictionary = {}
	var a: Dictionary = AssistScript.team_share(10, 1, [1, 2, 3, 4], carry)
	assert(a.is_empty(), "kişi başı 0,5: ilk öldürmede 0: %s" % [a])
	var b: Dictionary = AssistScript.team_share(10, 1, [1, 2, 3, 4], carry)
	assert(b == {2: 1, 3: 1, 4: 1}, "ikinci öldürmede birikmiş kesirle 1 altın: %s" % [b])
	assert(AssistScript.team_share(1, 1, [1, 2], {2: 0.99}).is_empty(), "1 altınlık öldürmede hiçbir şey gitmez (tavan 0)")
	var d: Dictionary = AssistScript.team_share(4, 1, [1, 2, 3, 4, 5], {2: 0.99, 3: 0.99, 4: 0.99, 5: 0.99})
	assert(d == {2: 1, 3: 1}, "tavan floor(4 x 0,5) = 2: birikmiş kesirler öldüreni soyamaz: %s" % [d])


func test_team_share_plus_assist_keeps_total() -> void:
	var carry: Dictionary = {}
	for i in range(5):
		var team: Dictionary = AssistScript.team_share(20, 1, [1, 2, 3, 4], carry)
		var rest: int = 20 - _sum(team)
		var all: Dictionary = AssistScript.compute(rest, 1, {1: _dmg(70.0), 2: _dmg(30.0)}, {}, T0, {}, carry)
		for p in team.keys():
			all[p] = int(all.get(p, 0)) + int(team[p])
		assert(_sum(all) == 20 and int(all[1]) >= 6, "takım + asist toplamı korunur, öldüren >= 6: %s" % [all])
		assert(all.has(3) and all.has(4), "hasar vermeyen yakın oyuncular da takım payı alır: %s" % [all])


func test_reset_clears_carry() -> void:
	AssistScript.carry[7] = 0.5
	AssistScript.reset()
	assert(AssistScript.carry.is_empty(), "reset birikimi temizler")


func test_damage_assist_split() -> void:
	var r: Dictionary = AssistScript.compute(10, 1, {1: _dmg(70.0), 2: _dmg(30.0)}, {}, T0)
	assert(int(r[1]) == 7 and int(r[2]) == 3 and _sum(r) == 10, "70/30 -> 7/3: %s" % [r])


func test_killer_keeps_at_least_forty_percent() -> void:
	## KILLER_MIN_FRAC 0,5 -> 0,4 (2026-10-19).
	var r: Dictionary = AssistScript.compute(10, 1, {1: _dmg(10.0), 2: _dmg(90.0)}, {}, T0)
	assert(int(r[1]) == 4 and int(r[2]) == 6, "öldüren en az %%40: %s" % [r])


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
	assert(r2.has(2) and int(r2[2]) == 6, "8 sn içindeki hasar asist (öldüren %%40 payı alır): %s" % [r2])


func test_support_assist_needs_participant_target() -> void:
	## 3 oyuncu: 1 öldürür, 2 hasar verir, 3 (destek) 2'ye can bastı -> pay alır; 4 kimseye destek vermedi -> almaz.
	var support: Dictionary = {3: [2], 4: [9]}
	var r: Dictionary = AssistScript.compute(20, 1, {1: _dmg(60.0), 2: _dmg(40.0)}, support, T0)
	assert(r.has(3) and int(r[3]) >= 1, "destek asisti pay almalı: %s" % [r])
	assert(not r.has(4), "katılmayana destek asist değil: %s" % [r])
	assert(_sum(r) == 20 and int(r[1]) >= 8, "toplam 20, öldüren >=8 (%%40): %s" % [r])


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
