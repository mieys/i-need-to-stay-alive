extends SceneTree
## HAREKET YOKLAMASI (2026-11-08, kullanıcı: "duvarlarda collision sınırları tuhaf, arkasında durmamız gereken duvarların üstünde yürüyoruz,
## kutular yolu kesiyor"). Zindan biçimli haritada oyuncunun GERÇEK hareket adımını (WallSlide.resolve + GameManager.is_position_blocked_by_walls,
## player.gd _block_movement_into_terrain ile aynı) duvar yüzüne (kuzeye yürüyerek), duvar tepesine (güneye), duvar yanlarına ve nesnelere
## (yaratık/girdi gürültüsü olmadan) uygular; durduğu yerde AYAK ile engel hücresinin kenarı arasındaki px'i yazar (eksi = ayak engelin içinde).
## Kullanım: $env:HARITA="taskin_hisar"; Godot --headless --path . -s res://tools/harita_secimi/hareket_yoklama.gd
## Çıktı: YOKLAMA <tür> <yön> n=.. ort=.. en_az=.. en_çok=.. içeride=..

const WallSlide := preload("res://scripts/wall_slide.gd")
## dungeon_world.gd / map_profiles.gd autoload'lara başvurur: -s betiği autoload'lardan önce derlenir -> preload değil, _run içinde load()
var DungeonWorldScript: GDScript = null
var MapProfilesScript: GDScript = null
const FEET := 15.0 * 0.85
const SPEED := 90.0
const SAMPLES := 120

var _gm: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	for i in range(30):
		await process_frame
	DungeonWorldScript = load("res://scripts/dungeon/dungeon_world.gd")
	MapProfilesScript = load("res://scripts/map_profiles.gd")
	DungeonWorldScript.set("feet_rule_disabled", OS.get_environment("YOKLAMA_ESKI") == "1") ## eski kök kuralıyla karşılaştırma
	var data: Resource = MapProfilesScript.call("data")
	if data == null:
		print("YOKLAMA harita verisi yok")
		quit(1)
		return
	var w: int = data.size.x
	var h: int = data.size.y
	var cells: PackedByteArray = data.cells
	var blocked := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return true
		var c: int = cells[y * w + x]
		return c == 1 or c == 2 or c == 5
	var kinds := {1: "duvar", 2: "nesne", 5: "su"}
	var dirs := {"kuzeye": Vector2i(0, -1), "güneye": Vector2i(0, 1), "batıya": Vector2i(-1, 0), "doğuya": Vector2i(1, 0)}
	var origin: Vector2 = DungeonWorldScript.call("cell_center", Vector2i.ZERO) - Vector2(8, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for dn: String in dirs:
		var d: Vector2i = dirs[dn]
		var res: Dictionary = {} ## tür -> [boşluklar]
		var tries: int = 0
		while tries < SAMPLES * 40 and _count(res) < SAMPLES * 3:
			tries += 1
			## hedef: engel hücresi (x, y); önünde (d'nin tersinde) 4 hücre serbest, iki yanı da serbest (dar geçit değil)
			var x: int = rng.randi_range(2, w - 3)
			var y: int = rng.randi_range(2, h - 3)
			if not blocked.call(x, y):
				continue
			var code: int = cells[y * w + x]
			var kind: String = kinds.get(code, "?")
			if res.has(kind) and (res[kind] as Array).size() >= SAMPLES:
				continue
			var ok: bool = true
			for k in range(1, 5):
				var cx: int = x - d.x * k
				var cy: int = y - d.y * k
				if blocked.call(cx, cy) or blocked.call(cx + d.y, cy + d.x) or blocked.call(cx - d.y, cy - d.x):
					ok = false
					break
			if not ok:
				continue
			var start_cell := Vector2i(x - d.x * 4, y - d.y * 4)
			var feet: Vector2 = origin + (Vector2(start_cell) + Vector2(0.5, 0.5)) * 16.0
			var pos: Vector2 = feet - Vector2(0, FEET)
			if bool(_gm.call("is_position_blocked_by_walls", pos)):
				continue
			var vel := Vector2(d) * SPEED
			for step in range(200):
				var v: Vector2 = WallSlide.resolve(pos, vel, Callable(_gm, "is_position_blocked_by_walls"))
				if v.length() < 0.01:
					break
				pos += v / 60.0
			var f: Vector2 = pos + Vector2(0, FEET) - origin
			## engel hücresinin oyuncuya bakan kenarına ayağın uzaklığı
			var gap: float = 0.0
			match dn:
				"kuzeye": gap = f.y - float(y + 1) * 16.0
				"güneye": gap = float(y) * 16.0 - f.y
				"batıya": gap = f.x - float(x + 1) * 16.0
				"doğuya": gap = float(x) * 16.0 - f.x
			if not res.has(kind):
				res[kind] = []
			(res[kind] as Array).append(gap)
		for kind: String in res:
			var arr: Array = res[kind]
			var s: float = 0.0
			var mn: float = 1e9
			var mx: float = -1e9
			var inside: int = 0
			for g: float in arr:
				s += g
				mn = minf(mn, g)
				mx = maxf(mx, g)
				if g < 0.0:
					inside += 1
			print("YOKLAMA %s %s n=%d ort=%.1f en_az=%.1f en_çok=%.1f içeride=%d" % [kind, dn, arr.size(), s / maxf(1.0, float(arr.size())), mn, mx, inside])
	quit(0)


func _count(res: Dictionary) -> int:
	var n: int = 0
	for k: String in res:
		n += (res[k] as Array).size()
	return n
