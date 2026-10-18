extends Node

## Yaratık hasar sayıları (scripts/damage_numbers.gd) - FPS turu (2026-10-18): çizilmiş canvas item havuzu, yaratık başına sınırlı doğurma
## (spawn_fixed_capped), swap-remove ile liste ve ömür/saydamlık zaman çizelgesi. (Görünümün eski sürümle piksel piksel aynı olduğu
## iki SubViewport'lu karşılaştırmayla gerçek çizicide ayrıca doğrulandı; bkz. docs/notlar FPS turu notu.)

const DnScript := preload("res://scripts/damage_numbers.gd")

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


func _consistent(dn: Node2D) -> bool:
	var list: Array = dn.get("_list")
	var entries: Dictionary = _entries(dn)
	if list.size() != entries.size():
		return false
	for i in range(list.size()):
		var e = list[i]
		if int(e.slot) != i or entries.get(int(e.id)) != e:
			return false
	return true


func test_capped_spawn_keeps_at_most_max_live_and_drops_dead_ids() -> void:
	var dn := _dn()
	var ids: Array[int] = []
	for i in range(8):
		dn.spawn_fixed_capped(null, Vector2(i, 0), str(10 + i), Color.WHITE, ids, 5)
	assert(ids.size() == 5, "yaratık başına en fazla 5 canlı sayı: %d" % ids.size())
	assert(_entries(dn).size() == 5, "sınırı aşan eski sayılar silinmeli: %d" % _entries(dn).size())
	for id in ids:
		assert(dn.is_alive(id))
	assert(_consistent(dn), "liste/sözlük tutarlı olmalı")
	## süresi dolan kimlikler bir sonraki doğurmada atılır
	dn.call("_process", DnScript.TOTAL_TIME + 0.1)
	assert(_entries(dn).is_empty(), "ömrü biten sayılar kalkmalı")
	dn.spawn_fixed_capped(null, Vector2.ZERO, "7", Color.WHITE, ids, 5)
	assert(ids.size() == 1 and dn.is_alive(ids[0]), "ölü kimlikler atılıp yenisi eklenmeli: %d" % ids.size())
	_cleanup()


func test_expired_item_is_pooled_and_reused_for_the_same_text_and_color() -> void:
	var dn := _dn()
	var id1: int = dn.spawn_fixed(null, Vector2.ZERO, "42", Color.WHITE)
	var ci1: RID = _entries(dn)[id1].ci
	dn.call("_process", DnScript.TOTAL_TIME + 0.05)
	assert(not dn.is_alive(id1))
	assert(int(dn.get("_free_count")) == 1, "ömrü biten çizilmiş item havuza girmeli")
	var id2: int = dn.spawn_fixed(null, Vector2.ZERO, "42", Color.WHITE)
	assert(_entries(dn)[id2].ci == ci1, "aynı metin + renk: çizilmiş item yeniden kullanılmalı")
	assert(int(dn.get("_free_count")) == 0)
	var id3: int = dn.spawn_fixed(null, Vector2.ZERO, "42", Color(1.0, 0.25, 0.2))
	assert(_entries(dn)[id3].ci != ci1, "farklı renk (kritik) aynı item'ı kullanmamalı")
	## erken silinen de havuza gider
	dn.remove(id2)
	assert(int(dn.get("_free_count")) == 1 and not dn.is_alive(id2))
	assert(_consistent(dn))
	_cleanup()


func test_pool_is_bounded() -> void:
	var dn := _dn()
	for i in range(DnScript.FREE_MAX + 40):
		dn.spawn_fixed(null, Vector2.ZERO, "t%d" % i, Color.WHITE)
	dn.call("_process", DnScript.TOTAL_TIME + 0.05)
	assert(_entries(dn).is_empty())
	assert(int(dn.get("_free_count")) == DnScript.FREE_MAX, "havuz sınırlı olmalı: %d" % int(dn.get("_free_count")))
	_cleanup()


func test_staggered_expiry_keeps_list_consistent() -> void:
	var dn := _dn()
	var first: Array = []
	for i in range(5):
		first.append(dn.spawn_fixed(null, Vector2(i, 0), "a%d" % i, Color.WHITE))
	dn.call("_process", 0.5)
	var second: Array = []
	for i in range(5):
		second.append(dn.spawn_fixed(null, Vector2(i, 10), "b%d" % i, Color.WHITE))
	assert(_consistent(dn))
	## ilk beşi aynı karede biter (0,5 + 0,5 >= 0,98), ikinci beşi yaşar
	dn.call("_process", 0.5)
	for id in first:
		assert(not dn.is_alive(id), "ilk grup bitmeli")
	for id in second:
		assert(dn.is_alive(id), "ikinci grup yaşamalı")
	assert(_consistent(dn), "swap-remove sonrası slotlar tutarlı olmalı")
	## sonra ikinci grubun ortadakileri erken silinir, kalanlar tutarlı
	dn.remove(second[2])
	dn.remove(second[0])
	assert(_consistent(dn) and _entries(dn).size() == 3)
	dn.call("_process", 0.6)
	assert(_entries(dn).is_empty() and _consistent(dn))
	_cleanup()


func test_alpha_timeline() -> void:
	assert(is_equal_approx(DnScript._alpha_of(0.0, 0.0), 0.0))
	assert(is_equal_approx(DnScript._alpha_of(DnScript.FADE_IN_DURATION * 0.5, 0.0), 0.5), "belirme doğrusal")
	assert(is_equal_approx(DnScript._alpha_of(DnScript.FADE_IN_DURATION + DnScript.HOLD * 0.5, 0.0), 1.0), "tutma evresi tam opak")
	assert(DnScript._alpha_of(DnScript.TOTAL_TIME - 0.001, 0.0) < 0.02, "sonda söner")
	assert(is_equal_approx(DnScript._alpha_of(DnScript.TOTAL_TIME + 0.1, 0.0), 0.0))


func test_alpha_set_on_item_follows_the_same_timeline() -> void:
	## _process satır içi saydamlık hesabı, kayıtta saklanan son değerle (alpha) _alpha_of'u eşler.
	var dn := _dn()
	var id: int = dn.spawn_fixed(null, Vector2.ZERO, "9", Color.WHITE)
	var e = _entries(dn)[id]
	var t: float = 0.0
	for k in range(40):
		dn.call("_process", 0.02)
		t += 0.02
		if t >= DnScript.TOTAL_TIME:
			break
		assert(absf(float(e.alpha) - DnScript._alpha_of(t, 0.0)) < 0.0001, "t=%.2f alpha=%.4f beklenen=%.4f" % [t, float(e.alpha), DnScript._alpha_of(t, 0.0)])
	_cleanup()
