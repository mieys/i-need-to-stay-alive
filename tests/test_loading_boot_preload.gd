extends Node

## Yükleme donması düzeltmeleri (madde 440): (1) yükleme ekranı, Main._ready sırasında çalışma anında okunan kaynakları iş parçacığında ön yükler
## (ortak liste + seçili karakter), (2) ağaç/ot sallanma kurulumundaki karo taraması önbellekli ve eski taramayla AYNI sonucu verir,
## (3) yükleme iş parçacığı düşük öncelikli.

const LoadingScript: GDScript = preload("res://scripts/loading_screen.gd")
const BootList := preload("res://scripts/boot_preload_list.gd")
const TreeSwayScript: GDScript = preload("res://scripts/tree_sway.gd")
const GrassSwayScript: GDScript = preload("res://scripts/grass_sway.gd")


func test_boot_list_paths_exist_and_are_unique() -> void:
	var seen: Dictionary = {}
	for p: String in BootList.PATHS:
		assert(ResourceLoader.exists(p), "ön yükleme listesindeki dosya yok: %s" % p)
		assert(not seen.has(p), "listede tekrar: %s" % p)
		seen[p] = true
	assert(BootList.PATHS.size() > 50, "liste dolu olmalı (günlükten üretilir)")


func test_boot_extra_includes_selected_character_resources() -> void:
	for cid: int in [0, 2, 5]:
		var def: Dictionary = Characters.get_def(cid)
		var paths: Array[String] = LoadingScript.boot_extra_paths(cid, "")
		var frames: String = str(def.get("frames", ""))
		if frames != "":
			assert(paths.has(frames), "karakter %d kare sayfası ön yüklenmeli: %s" % [cid, frames])
		for k: String in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon"]:
			if def.has(k):
				assert(paths.has(str(def[k])), "karakter %d %s ön yüklenmeli" % [cid, k])
		var uniq: Dictionary = {}
		for p: String in paths:
			assert(not uniq.has(p), "ön yükleme yolları tekrarsız olmalı: %s" % p)
			uniq[p] = true
		for bp: String in BootList.PATHS:
			assert(paths.has(bp), "ortak liste her karakterde olmalı: %s" % bp)


func test_loader_thread_is_low_priority() -> void:
	assert(LoadingScript.source_code.contains("Thread.PRIORITY_LOW"), "yükleme iş parçacığı düşük öncelikli başlamalı")


## Eski (önbelleksiz) tarama: ağaç kurulumundaki karo istatistiği.
func _brute_tile_stats(img: Image, region: Rect2i) -> Array:
	var opaque: int = 0
	var green: int = 0
	var last_row: int = -1
	var first_row: int = 16
	for y in range(region.size.y):
		for x in range(region.size.x):
			var px: Color = img.get_pixel(region.position.x + x, region.position.y + y)
			if px.a < 0.4:
				continue
			opaque += 1
			if px.h > 0.17 and px.h < 0.48 and px.s > 0.25:
				green += 1
			last_row = maxi(last_row, y)
			first_row = mini(first_row, y)
	return [opaque, green, last_row, first_row]


func _atlas_with_two_tiles() -> TileSetAtlasSource:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(3, 13): ## karo 0: yeşil gövde 3..12
		for x in range(4, 12):
			img.set_pixel(x, y, Color(0.2, 0.7, 0.2, 1.0))
	for y in range(5, 8): ## karo 1: kahverengi + yarı saydam
		for x in range(20, 28):
			img.set_pixel(x, y, Color(0.5, 0.3, 0.1, 1.0 if y < 7 else 0.2))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	return src


func test_tree_sway_tile_stats_match_brute_force_scan_and_are_cached() -> void:
	var src: TileSetAtlasSource = _atlas_with_two_tiles()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	var sway: Node = TreeSwayScript.new()
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
		var img: Image = src.texture.get_image()
		var want: Array = _brute_tile_stats(img, src.get_tile_texture_region(c))
		var got: Array = sway._tile_stats(src, 0, c)
		assert(got == want, "karo %s istatistiği eski taramayla aynı olmalı: %s != %s" % [c, got, want])
		assert(sway._tile_stats(src, 0, c) == got, "ikinci çağrı önbellekten aynı sonucu vermeli")
	assert(sway._tile_stat_cache.size() == 2, "iki farklı karo = iki önbellek girdisi")
	sway.free()


func test_grass_sway_opaque_rows_cache_matches_scan() -> void:
	var src: TileSetAtlasSource = _atlas_with_two_tiles()
	var img: Image = src.texture.get_image()
	var sway: Node = GrassSwayScript.new()
	var r0 := Rect2i(0, 0, 16, 16)
	var r1 := Rect2i(16, 0, 16, 16)
	assert(sway._opaque_rows(img, r0) == Vector2i(3, 12), "karo 0 opak satırları 3..12")
	assert(sway._opaque_rows(img, r1) == Vector2i(5, 7), "karo 1 opak satırları 5..7 (alfa 0,2 > 0,1 eşiği)")
	assert(sway._opaque_rows(img, r0) == Vector2i(3, 12), "önbellekten aynı sonuç")
	assert(sway._opaque_rows(img, Rect2i(0, 0, 16, 2)) == Vector2i(-1, -1), "boş bölge (-1,-1)")
	sway.free()
