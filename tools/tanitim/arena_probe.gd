extends SceneTree

## TANITIM SAHNE 1 yoklaması (çöl "Altın Kumlar", HARITA=col): tüm oyun alanını tarar, 1360x840 dünya px'lik dikdörtgenin TAMAMEN yürünebilir
## (arazi/duvar engeli yok) olduğu merkezleri bulur, en iyi birkaçının ASCII haritasını basar ('#' engel, '.' açık, '+' merkez).
## Çalıştır: HARITA=col Godot --headless --path <proje> -s res://tools/tanitim/arena_probe.gd --log-file <dosya>   ("PROBE" satırlarını oku).

const STEP := 32.0
const HALF := Vector2(520.0, 320.0)


func _initialize() -> void:
	_run.call_deferred()


func _blocked(gm: Node, p: Vector2) -> bool:
	return bool(gm.call("is_position_blocked_by_terrain", p)) or bool(gm.call("is_position_blocked_by_walls", p))


func _run() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	gm.call("reset")
	gm.set("selected_char_id", 4)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(4).get("skill", 1))
	gm.set("debug_immortal", true)
	gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await process_frame
	t0 = Time.get_ticks_msec()
	while get_first_node_in_group("loading_overlay") != null and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	for i in 30:
		await process_frame
	## Engel ızgarası: tüm oyun alanı (hücre 16 px) STEP aralıkla
	var x0: float = 512.0
	var y0: float = 320.0
	var w: int = int(3888.0 / STEP)
	var h: int = int(3888.0 / STEP)
	var grid := PackedByteArray()
	grid.resize(w * h)
	for j in h:
		for i in w:
			grid[j * w + i] = 1 if _blocked(gm, Vector2(x0 + float(i) * STEP, y0 + float(j) * STEP)) else 0
	var tot: int = 0
	for v in grid:
		tot += v
	print("PROBE izgara %dx%d hazir, engelli %d / %d" % [w, h, tot, w * h])
	var hw: int = int(HALF.x / STEP)
	var hh: int = int(HALF.y / STEP)
	var best: Array = []
	var j: int = hh
	while j < h - hh:
		var i: int = hw
		while i < w - hw:
			var blocked_n: int = 0
			for dj in range(-hh, hh + 1):
				for di in range(-hw, hw + 1):
					blocked_n += grid[(j + dj) * w + (i + di)]
				if blocked_n > 12:
					break
			if blocked_n <= 12:
				best.append(Vector2(x0 + float(i) * STEP, y0 + float(j) * STEP))
			i += 2
		j += 2
	print("PROBE aday sayisi %d" % best.size())
	## Merkezden uzak, birbirinden ayrı en fazla 12 aday
	var picked: Array = []
	for c in best:
		var ok: bool = true
		for p in picked:
			if (p as Vector2).distance_to(c) < 700.0:
				ok = false
				break
		if ok:
			picked.append(c)
		if picked.size() >= 12:
			break
	for c in picked:
		print("PROBE aday (%d, %d)" % [int(c.x), int(c.y)])
	for n in mini(3, picked.size()):
		var c: Vector2 = picked[n]
		print("PROBE harita aday %d merkez (%d, %d)" % [n, int(c.x), int(c.y)])
		var y: float = -HALF.y - 128.0
		while y <= HALF.y + 128.0:
			var row := ""
			var x: float = -HALF.x - 128.0
			while x <= HALF.x + 128.0:
				var p: Vector2 = c + Vector2(x, y)
				row += "#" if _blocked(gm, p) else ("+" if (absf(x) < 1.0 and absf(y) < 1.0) else ".")
				x += STEP
			print("PROBE %+5d %s" % [int(y), row])
			y += STEP
	print("PROBE bitti")
	quit()
