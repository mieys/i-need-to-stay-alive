extends Node

## Madde 429 (kullanıcı 2026-11-06: "hasar sayıları çok göz yoruyor, karmaşık gösteriyor... kapatmadan"): damage_numbers.gd spawn_hit -
## aynı hedefe MERGE_WINDOW içinde gelen aynı türden hasar son sayıya eklenir (kritik hep ayrı), palet renkleri, soluk küçük/süreli sayılar,
## tür başına ömür, "fırla, fren yap, sön" yükselmesi ve ekran bütçesi (SCREEN_BUDGET).

const DnScript := preload("res://scripts/damage_numbers.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")

var _nodes: Array = []


func _dn() -> Node2D:
	var n := Node2D.new()
	n.set_script(DnScript)
	add_child(n)
	n.set_process(false) ## süre testte elle ilerletilir
	_nodes.append(n)
	return n


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _entries(dn: Node2D) -> Dictionary:
	return dn.get("_entries")


func test_hits_inside_the_window_merge_into_one_number() -> void:
	var dn := _dn()
	var ids: Array[int] = []
	dn.spawn_hit(null, Vector2.ZERO, 10, DnScript.KIND_HIT, ids, 5, 100.0)
	dn.call("_process", 0.05)
	dn.spawn_hit(null, Vector2.ZERO, 7, DnScript.KIND_HIT, ids, 5, 100.0)
	dn.spawn_hit(null, Vector2.ZERO, 3, DnScript.KIND_HIT, ids, 5, 100.0)
	assert(ids.size() == 1 and _entries(dn).size() == 1, "pencere içinde tek sayı: %d" % _entries(dn).size())
	var e = _entries(dn)[ids[0]]
	assert(int(e.value) == 20, "değerler toplanır: %d" % int(e.value))
	assert(bool(e.dirty), "metin karede bir kez yeniden çizilir")
	dn.call("_process", 0.01)
	assert(not bool(e.dirty) and String(e.key).begins_with("20|"), "yeni metin çizildi: %s" % String(e.key))
	## pencere geçince yeni sayı açılır
	dn.call("_process", DnScript.MERGE_WINDOW)
	dn.spawn_hit(null, Vector2.ZERO, 4, DnScript.KIND_HIT, ids, 5, 100.0)
	assert(ids.size() == 2, "pencere sonrası yeni sayı: %d" % ids.size())
	_cleanup()


func test_crits_never_merge_and_kinds_stay_apart() -> void:
	var dn := _dn()
	var ids: Array[int] = []
	## ayrı noktalar: üst üste binme kuralı (yer yoksa soluk sayı açılmaz) bu testi etkilemesin
	dn.spawn_hit(null, Vector2(0, 0), 50, DnScript.KIND_CRIT, ids, 5, 100.0)
	dn.spawn_hit(null, Vector2(40, 0), 60, DnScript.KIND_CRIT, ids, 5, 100.0)
	assert(ids.size() == 2, "kritik hep kendi sayısı")
	dn.spawn_hit(null, Vector2(80, 0), 5, DnScript.KIND_HIT, ids, 5, 100.0)
	dn.spawn_hit(null, Vector2(120, 0), 2, DnScript.KIND_DOT, ids, 5, 100.0, "dot:zehir")
	dn.spawn_hit(null, Vector2(160, 0), 2, DnScript.KIND_DOT, ids, 5, 100.0, "dot:yanma")
	assert(ids.size() == 5, "normal / zehir / yanma birbirine eklenmez: %d" % ids.size())
	dn.spawn_hit(null, Vector2(160, 0), 3, DnScript.KIND_DOT, ids, 5, 100.0, "dot:yanma")
	assert(ids.size() == 5 and int(_entries(dn)[ids[4]].value) == 5, "aynı süreli hasar eklenir")
	_cleanup()


func test_colors_come_from_the_palette() -> void:
	assert(DnScript.color_for(DnScript.KIND_HIT) == HudTheme.DMG_HIT)
	assert(DnScript.color_for(DnScript.KIND_CRIT) == HudTheme.DMG_CRIT)
	assert(DnScript.color_for(DnScript.KIND_DOT, "dot:zehir") == HudTheme.DMG_DOT_POISON)
	assert(DnScript.color_for(DnScript.KIND_DOT, "dot:ari_zehri") == HudTheme.DMG_DOT_POISON)
	assert(DnScript.color_for(DnScript.KIND_DOT, "dot:yanma") == HudTheme.DMG_DOT_BURN)
	assert(DnScript.color_for(DnScript.KIND_DOT, "dot:kanama") == HudTheme.DMG_DOT_BLEED)
	assert(DnScript.color_for(DnScript.KIND_DOT, "dot:baska") == HudTheme.DMG_DOT)
	assert(DnScript.OUTLINE_COLOR == HudTheme.OUTLINE, "kontür paletin koyu kahvesi")
	assert(HudTheme.DMG_HIT != Color.WHITE, "saf beyaz değil")


func test_small_and_dot_numbers_are_dimmer() -> void:
	assert(is_equal_approx(DnScript.alpha_mul_for(DnScript.KIND_HIT, 3, 1000.0), DnScript.SMALL_ALPHA), "azami canın %4'ünden küçük: soluk")
	assert(is_equal_approx(DnScript.alpha_mul_for(DnScript.KIND_HIT, 100, 1000.0), 1.0), "büyük vuruş tam")
	assert(is_equal_approx(DnScript.alpha_mul_for(DnScript.KIND_CRIT, 3, 1000.0), 1.0), "kritik hep tam")
	assert(is_equal_approx(DnScript.alpha_mul_for(DnScript.KIND_DOT, 500, 1000.0), DnScript.DOT_ALPHA), "süreli hasar hep soluk")
	assert(is_equal_approx(DnScript.alpha_mul_for(DnScript.KIND_HIT, 1, 0.0), 1.0), "azami can bilinmiyorsa tam")
	## birleşen küçük vuruşlar büyüyünce tam görünür olur
	var dn := _dn()
	var ids: Array[int] = []
	dn.spawn_hit(null, Vector2.ZERO, 3, DnScript.KIND_HIT, ids, 5, 100.0)
	var e = _entries(dn)[ids[0]]
	assert(is_equal_approx(float(e.alpha_mul), DnScript.SMALL_ALPHA))
	dn.spawn_hit(null, Vector2.ZERO, 5, DnScript.KIND_HIT, ids, 5, 100.0)
	assert(is_equal_approx(float(e.alpha_mul), 1.0), "toplam 8 >= %4: tam")
	_cleanup()


func test_lifetimes_per_kind() -> void:
	var dn := _dn()
	var a: Array[int] = []
	var b: Array[int] = []
	var c: Array[int] = []
	dn.spawn_hit(null, Vector2(0, 0), 50, DnScript.KIND_HIT, a, 5, 100.0)
	dn.spawn_hit(null, Vector2(40, 0), 50, DnScript.KIND_CRIT, b, 5, 100.0)
	dn.spawn_hit(null, Vector2(80, 0), 50, DnScript.KIND_DOT, c, 5, 100.0, "dot:zehir")
	var total_real := func(kind_life: float) -> float: return DnScript.TOTAL_TIME * kind_life / DnScript.LIFETIME
	var t_dot: float = total_real.call(DnScript.KIND_LIFE[2])
	var t_hit: float = total_real.call(DnScript.KIND_LIFE[0])
	var t_crit: float = total_real.call(DnScript.KIND_LIFE[1])
	assert(t_dot < t_hit and t_hit < t_crit, "süreli < normal < kritik")
	dn.call("_process", t_dot + 0.01)
	assert(not dn.is_alive(c[0]) and dn.is_alive(a[0]) and dn.is_alive(b[0]), "önce süreli hasar söner")
	dn.call("_process", t_hit - t_dot)
	assert(not dn.is_alive(a[0]) and dn.is_alive(b[0]), "sonra normal")
	dn.call("_process", t_crit - t_hit)
	assert(not dn.is_alive(b[0]), "en son kritik")
	_cleanup()


func test_rise_brakes_and_stops() -> void:
	var full: float = DnScript.LIFETIME * DnScript.RISE_TIME
	assert(is_equal_approx(DnScript._rise_of(0.0, 1.0), 0.0))
	assert(DnScript._rise_of(full * 0.3, 1.0) > DnScript.RISE * 0.6, "başta hızlı fırlar")
	assert(is_equal_approx(DnScript._rise_of(full, 1.0), DnScript.RISE), "RISE_TIME'da tam yükselir")
	assert(is_equal_approx(DnScript._rise_of(DnScript.LIFETIME, 1.0), DnScript.RISE), "sonra durur")
	assert(is_equal_approx(DnScript._rise_of(full, 1.3), DnScript.RISE * 1.3), "kritik daha çok yükselir")
	assert(not DnScript.KIND_POP[DnScript.KIND_HIT] and DnScript.KIND_POP[DnScript.KIND_CRIT], "pop yalnız kritikte")


func test_screen_budget_caps_live_numbers() -> void:
	var dn := _dn()
	var per: Array = []
	for i in range(DnScript.SCREEN_BUDGET):
		var ids: Array[int] = []
		dn.spawn_hit(null, Vector2(i * 40, 0), 50, DnScript.KIND_HIT, ids, 5, 100.0)
		per.append(ids)
	assert(_entries(dn).size() == DnScript.SCREEN_BUDGET)
	## soluk (küçük) yeni sayı yer açmaz
	var small: Array[int] = []
	dn.spawn_hit(null, Vector2.ZERO, 1, DnScript.KIND_HIT, small, 5, 100.0)
	assert(small.is_empty() and _entries(dn).size() == DnScript.SCREEN_BUDGET, "küçük vuruş bütçe doluyken açılmaz")
	var dot: Array[int] = []
	dn.spawn_hit(null, Vector2.ZERO, 90, DnScript.KIND_DOT, dot, 5, 100.0, "dot:zehir")
	assert(dot.is_empty(), "süreli hasar bütçe doluyken açılmaz")
	## büyük vuruş en eskiyi siler, toplam aynı kalır
	var first_id: int = (per[0] as Array)[0]
	dn.call("_process", 0.05)
	var big: Array[int] = []
	dn.spawn_hit(null, Vector2.ZERO, 80, DnScript.KIND_HIT, big, 5, 100.0)
	assert(big.size() == 1 and _entries(dn).size() == DnScript.SCREEN_BUDGET, "büyük vuruş yer açar: %d" % _entries(dn).size())
	## kritik de yer açar
	var crit: Array[int] = []
	dn.spawn_hit(null, Vector2.ZERO, 80, DnScript.KIND_CRIT, crit, 5, 100.0)
	assert(crit.size() == 1 and _entries(dn).size() == DnScript.SCREEN_BUDGET)
	assert(first_id > 0)
	_cleanup()


## Hedefin yanında doğar (saçılma HIT_SCATTER içinde), yaratık başına sınır korunur.
func test_scatter_and_per_target_cap() -> void:
	var dn := _dn()
	var ids: Array[int] = []
	for i in range(8):
		dn.spawn_hit(null, Vector2(100, 100), 50, DnScript.KIND_CRIT, ids, 5, 100.0)
	assert(ids.size() == 5 and _entries(dn).size() == 5, "hedef başı en çok 5")
	var up_max: float = DnScript.OVERLAP_H * DnScript.OVERLAP_TRIES
	for id in ids:
		var o: Vector2 = _entries(dn)[id].origin - Vector2(100, 100)
		assert(absf(o.x) <= DnScript.HIT_SCATTER.x + 0.001, "dar saçılma: %s" % str(o))
		assert(o.y <= DnScript.HIT_SCATTER.y + 0.001 and o.y >= -DnScript.HIT_SCATTER.y - up_max - 0.001, "yalnız yukarı kayar: %s" % str(o))
	_cleanup()


## Komşu yaratıkların sayıları üst üste binmez: aynı noktaya düşen ikinci sayı bir satır yukarı kayar.
func test_new_number_steps_up_instead_of_overlapping() -> void:
	var dn := _dn()
	var a: Array[int] = []
	var b: Array[int] = []
	seed(7)
	dn.spawn_hit(null, Vector2(0, 0), 19, DnScript.KIND_HIT, a, 5, 100.0)
	dn.spawn_hit(null, Vector2(0, 0), 36, DnScript.KIND_HIT, b, 5, 100.0)
	var pa: Vector2 = _entries(dn)[a[0]].origin
	var pb: Vector2 = _entries(dn)[b[0]].origin
	assert(absf(pa.x - pb.x) >= DnScript.OVERLAP_W or absf(pa.y - pb.y) >= DnScript.OVERLAP_H - 0.001, "üst üste binmemeli: %s / %s" % [str(pa), str(pb)])
	assert(pb.y < pa.y + DnScript.HIT_SCATTER.y * 2.0 + 0.001, "ikincisi aşağı kaymaz: %s / %s" % [str(pa), str(pb)])
	## sütun tamamen doluysa soluk (küçük) sayı açılmaz, tam sayı en üstte açılır
	for i in range(DnScript.OVERLAP_TRIES + 1):
		var col: Array[int] = []
		dn.spawn_hit(null, Vector2(0, -DnScript.OVERLAP_H * float(i)), 50, DnScript.KIND_CRIT, col, 5, 100.0)
	var before: int = _entries(dn).size()
	var dim: Array[int] = []
	dn.spawn_hit(null, Vector2(0, 0), 1, DnScript.KIND_HIT, dim, 5, 100.0)
	assert(dim.is_empty() and _entries(dn).size() == before, "yer yoksa soluk sayı açılmaz")
	var full: Array[int] = []
	dn.spawn_hit(null, Vector2(0, 0), 60, DnScript.KIND_HIT, full, 5, 100.0)
	assert(full.size() == 1, "tam sayı yine açılır")
	## uzaktaki sayı kaymaz
	var c: Array[int] = []
	dn.spawn_hit(null, Vector2(200, 0), 5, DnScript.KIND_HIT, c, 5, 100.0)
	assert(absf(_entries(dn)[c[0]].origin.y) <= DnScript.HIT_SCATTER.y + 0.001, "boş yerde olduğu yerde kalır")
	_cleanup()
