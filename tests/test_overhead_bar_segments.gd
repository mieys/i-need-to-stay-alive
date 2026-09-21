extends Node

## Can barı bölme çizgileri (kullanıcı bildirimi 2026-09-21): kaç çizgi olursa olsun aralarındaki mesafe aynı, uçlar simetrik olmalı.

const OverheadBar: GDScript = preload("res://scripts/overhead_bar.gd")


func test_line_count_follows_health_and_is_capped() -> void:
	assert(OverheadBar._segment_line_count(30.0) == 0, "<=40 can: cizgi yok")
	assert(OverheadBar._segment_line_count(40.0) == 0)
	assert(OverheadBar._segment_line_count(41.0) == 1)
	assert(OverheadBar._segment_line_count(100.0) == 2, "100 can: 3 dilim")
	assert(OverheadBar._segment_line_count(200.0) == 4)
	assert(OverheadBar._segment_line_count(820.0) == OverheadBar.MAX_SEGMENT_LINES)
	assert(OverheadBar._segment_line_count(50000.0) == OverheadBar.MAX_SEGMENT_LINES)


func test_spacing_is_identical_for_every_line_count() -> void:
	var width: float = OverheadBar.WIDTH
	for lines in range(1, OverheadBar.MAX_SEGMENT_LINES + 1):
		var offs: Array[float] = OverheadBar._segment_line_offsets(width, lines)
		assert(offs.size() == lines, "cizgi sayisi %d" % lines)
		for i in range(1, offs.size()):
			assert(offs[i] - offs[i - 1] == offs[1] - offs[0] if offs.size() > 1 else true, "esit aralik (lines=%d)" % lines)
			assert(offs[i] - offs[i - 1] >= 1.0)
		## tam piksel konumlari
		for o in offs:
			assert(o == floor(o), "tam piksel (lines=%d)" % lines)
		## uclar simetrik: soldaki bosluk ile sagdaki bosluk 1 pikselden fazla farketmemeli
		var left: float = offs[0]
		var right: float = width - offs[offs.size() - 1]
		assert(absf(left - right) <= 1.0, "simetrik uclar (lines=%d): %s vs %s" % [lines, left, right])
		## cizgiler bar icinde
		assert(offs[0] > 0.0 and offs[offs.size() - 1] < width)


func test_spacing_uniform_for_odd_health_values() -> void:
	## 100 can (40'in kati degil) ve 5000 can (800'u asan): eski hal esitsiz cikiyordu
	for hp in [100.0, 130.0, 5000.0]:
		var lines: int = OverheadBar._segment_line_count(hp)
		var offs: Array[float] = OverheadBar._segment_line_offsets(OverheadBar.WIDTH, lines)
		for i in range(2, offs.size()):
			assert(offs[i] - offs[i - 1] == offs[1] - offs[0], "hp=%s" % hp)
