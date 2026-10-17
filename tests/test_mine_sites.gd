extends Node

## Maden kazma (kullanıcı isteği 2026-10-14): scripts/mine_sites.gd (maden bulma + tür) ve player.gd _process_mining (durunca kazma klibi, darbe karesinde altın).
## Gerçek harita + gerçek Player. Harita sol köşede BAKIR (turuncu), sağ köşede GRİ-MAVİ kristal madenler içerir (gri vuruş başına daha çok altın).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const MineSites := preload("res://scripts/mine_sites.gd")
const TerrainCollisionScript: GDScript = preload("res://scripts/terrain_collision.gd")
const CharAnim := preload("res://scripts/char_anim.gd")
const DepthScript: GDScript = preload("res://scripts/depth_occluders.gd")

var _harita: Node = null
var _forest: TileMapLayer = null


func _load_map() -> void:
	_harita = HaritaScene.instantiate()
	_harita.name = "Harita"
	(_harita as Node2D).position = Vector2(-2.0, 21.0) ## gerçek oyundaki konum (main.tscn)
	add_child(_harita)
	GameManager._terrain_su_layer = _harita.get_node("Su/Su")
	GameManager._terrain_ev_layer = _harita.get_node("ev/Ev")
	_forest = _harita.get_node("Orman parçaları/Orman parçaları")
	GameManager._terrain_forest_layer = _forest
	GameManager._terrain_layers_searched = true
	TerrainCollisionScript.reset()
	MineSites.reset()


func _unload_map() -> void:
	if is_instance_valid(_harita):
		_harita.free()
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	TerrainCollisionScript.reset()
	MineSites.reset()


func _first_site(gray: bool) -> Dictionary:
	for site: Dictionary in MineSites.ensure(_forest):
		if bool(site["gray"]) == gray:
			return site
	return {}


## Madenin hemen (sağ/alt kenar dışı) yanında, REACH içinde bir ayak noktası -> oyuncu kökü (ayak = kök + FEET_OFFSET).
func _root_next_to(site: Dictionary) -> Vector2:
	var b: Rect2 = site["bounds"]
	var feet := Vector2(b.get_center().x, b.end.y + 4.0)
	if MineSites.nearest(_forest, feet).is_empty():
		feet = (site["cells"][0] as Rect2).get_center()
	return feet - Vector2(0.0, DepthScript.FEET_OFFSET)


func test_sites_found_with_both_kinds() -> void:
	_load_map()
	var sites: Array = MineSites.ensure(_forest)
	assert(sites.size() >= 4, "maden sayısı beklenenden az: %d" % sites.size())
	var copper: int = 0
	var gray: int = 0
	for site: Dictionary in sites:
		var left: bool = (site["bounds"] as Rect2).get_center().x < 1000.0
		if bool(site["gray"]):
			gray += 1 ## sağ köşenin hepsi + sol köşede tek küçük gri-mavi kristal (8,233) var
		else:
			copper += 1
			assert(left, "bakır maden sağ köşede olmamalı (sol köşe): %s" % str(site["bounds"]))
	assert(copper >= 2 and gray >= 2, "iki tür de bulunmalı: bakır %d, gri %d" % [copper, gray])
	assert(MineSites.gold_per_hit(_first_site(true)) > MineSites.gold_per_hit(_first_site(false)), "gri maden bakırdan çok altın vermeli")
	_unload_map()


func test_nearest_respects_reach() -> void:
	_load_map()
	var site: Dictionary = _first_site(true)
	var cell: Rect2 = site["cells"][0]
	assert(not MineSites.nearest(_forest, cell.get_center()).is_empty(), "madenin içindeki nokta madene yakın sayılmalı")
	assert(MineSites.nearest(_forest, cell.get_center() + Vector2(0.0, 400.0)).is_empty(), "uzak nokta maden bulmamalı")
	_unload_map()


func test_player_mines_gold_on_hit_frame() -> void:
	_load_map()
	var site: Dictionary = _first_site(true)
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = _root_next_to(site)
	p._knockback_velocity = Vector2.ZERO
	p.velocity = Vector2.ZERO
	var gold0: int = GameManager.gold
	## Bekleme süresi dolmadan kazma başlamaz.
	p._process_mining(0.1)
	assert(not p._mining_active, "0,1 sn içinde kazma başlamamalı (MINE_START_DELAY)")
	p._process_mining(0.4)
	assert(p._mining_active, "madene yakın duran oyuncu kazmaya başlamalı")
	assert(p.anim.sprite_frames.has_animation(CharAnim.MINE_ANIM_PREFIX + p.facing), "yüz yönünde kazma klibi olmalı: " + p.facing)
	## Klip oynayıp darbe karesine gelince bir kez ödül.
	p._update_animation(false)
	assert(String(p.anim.animation) == CharAnim.MINE_ANIM_PREFIX + p.facing, "kazma klibi oynamalı: " + String(p.anim.animation))
	p.anim.frame = CharAnim.MINE_HIT_FRAME
	p._process_mining(0.016)
	assert(GameManager.gold == gold0 + MineSites.GOLD_PER_HIT_GRAY, "darbe karesinde gri maden altını eklenmeli: %d -> %d" % [gold0, GameManager.gold])
	p._process_mining(0.016)
	assert(GameManager.gold == gold0 + MineSites.GOLD_PER_HIT_GRAY, "aynı karede ikinci kez ödül verilmemeli")
	## Yürümeye başlayınca (gerçek hız) kazma kesilir.
	p.velocity = Vector2(80.0, 0.0)
	p.move_and_slide()
	p._process_mining(0.016)
	assert(not p._mining_active, "hareket edince kazma kesilmeli")
	p.free()
	GameManager.gold = gold0
	_unload_map()


func test_far_from_mine_does_not_mine() -> void:
	_load_map()
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = Vector2(1500.0, 1500.0)
	p._process_mining(1.0)
	assert(not p._mining_active, "madenden uzakta kazma olmamalı")
	p.free()
	_unload_map()


# ---------------------------------------------------------------- dayanıklılık / kırılma / yeniden doğma (mine_world.gd)

const MineWorldScript := preload("res://scripts/mine_world.gd")


func _world() -> Node:
	var w: Node = MineWorldScript.new()
	add_child(w)
	return w


func _blocked_count(site: Dictionary) -> int:
	var n: int = 0
	for gc: Vector2i in site["gcs"]:
		if TerrainCollisionScript._cells.has(gc):
			n += 1
	return n


func _tiles_present(site: Dictionary) -> int:
	var n: int = 0
	for t: Dictionary in site["tiles"]:
		if (t["layer"] as TileMapLayer).get_cell_source_id(t["cell"]) != -1:
			n += 1
	return n


func test_sites_have_durability_tiles_and_collision() -> void:
	_load_map()
	var sites: Array = MineSites.ensure(_forest)
	for site: Dictionary in sites:
		assert(int(site["max_hits"]) >= MineSites.MIN_HITS, "dayanıklılık en az MIN_HITS olmalı")
		assert(not (site["tiles"] as Array).is_empty(), "madenin karoları bulunmalı: %s" % str(site["bounds"]))
	var big: Dictionary = {}
	for site: Dictionary in sites:
		if big.is_empty() or (site["cells"] as Array).size() > (big["cells"] as Array).size():
			big = site
	assert(not (big["gcs"] as Array).is_empty(), "büyük madenin collision hücresi atanmalı")
	assert(int(big["max_hits"]) > MineSites.MIN_HITS, "büyük maden küçüklerden çok dayanmalı: %d" % int(big["max_hits"]))
	_unload_map()


func test_break_removes_tiles_and_collision_then_respawn_restores() -> void:
	_load_map()
	var w: Node = _world()
	var site: Dictionary = _first_site(true)
	var idx: int = int(site["index"])
	var tiles0: int = _tiles_present(site)
	var blocked0: int = _blocked_count(site)
	assert(tiles0 == (site["tiles"] as Array).size() and blocked0 > 0, "başlangıçta karolar var ve collision açık: %d/%d" % [tiles0, blocked0])
	w._set_broken(idx, true)
	assert(bool(site["broken"]) and _tiles_present(site) == 0, "kırılınca tüm karolar silinmeli")
	assert(_blocked_count(site) == 0, "kırılınca collision hücreleri açılmalı")
	assert(MineSites.nearest(_forest, (site["cells"][0] as Rect2).get_center()).is_empty() or MineSites.nearest(_forest, (site["cells"][0] as Rect2).get_center())["site"] != site, "kırık maden kazılmamalı")
	w._set_broken(idx, false)
	assert(_tiles_present(site) == tiles0, "yeniden doğunca karolar geri gelmeli")
	assert(_blocked_count(site) == blocked0, "yeniden doğunca collision geri gelmeli")
	assert(int(site["hp"]) == int(site["max_hits"]), "yeniden doğunca dayanıklılık dolmalı")
	w.free()
	_unload_map()


func test_hits_break_site_and_timer_respawns() -> void:
	_load_map()
	var w: Node = _world()
	var site: Dictionary = _first_site(false)
	var idx: int = int(site["index"])
	for i in range(int(site["max_hits"]) - 1):
		w._apply_hit(idx)
	assert(not bool(site["broken"]), "son vuruştan önce kırılmamalı")
	w._apply_hit(idx)
	assert(bool(site["broken"]), "dayanıklılık bitince maden kırılmalı")
	assert(is_equal_approx(float(site["respawn_left"]), MineSites.RESPAWN_SECONDS), "yeniden doğma sayacı başlamalı")
	w._apply_hit(idx) ## kırıkken vuruş sayılmaz
	site["respawn_left"] = 0.05
	w._physics_process(0.1)
	assert(not bool(site["broken"]), "süre dolunca (alanda oyuncu yokken) maden yeniden doğmalı")
	w.free()
	_unload_map()


func test_respawn_waits_while_player_inside() -> void:
	_load_map()
	var w: Node = _world()
	var site: Dictionary = _first_site(true)
	var idx: int = int(site["index"])
	w._set_broken(idx, true)
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = (site["bounds"] as Rect2).get_center() - Vector2(0.0, 12.0)
	site["respawn_left"] = 0.0
	w._physics_process(0.1)
	assert(bool(site["broken"]), "alanda oyuncu varken maden yeniden doğmamalı (içine sıkışmasın)")
	p.global_position = Vector2(1500.0, 1500.0)
	w._physics_process(0.1)
	assert(not bool(site["broken"]), "oyuncu uzaklaşınca doğmalı")
	p.free()
	w.free()
	_unload_map()


func test_client_applies_state_list() -> void:
	_load_map()
	var w: Node = _world()
	var a: Dictionary = _first_site(true)
	var b: Dictionary = _first_site(false)
	w._apply_state([int(a["index"])])
	assert(bool(a["broken"]) and not bool(b["broken"]), "liste yalnız listedeki madeni kırmalı")
	w._apply_state([int(b["index"])])
	assert(not bool(a["broken"]) and bool(b["broken"]), "liste değişince fark uygulanmalı (a doğar, b kırılır)")
	w._apply_state([])
	assert(not bool(a["broken"]) and not bool(b["broken"]), "boş liste hepsini doğurmalı")
	w.free()
	_unload_map()


## DepthOccluders kuruluyken (gerçek oyun): ön kopya katmanındaki karolar da silinir/geri gelir, derinlik kökleri çıkar/geri girer.
func test_break_updates_depth_front_copies() -> void:
	_load_map()
	var occ: Node = DepthScript.new()
	occ.call("setup", _harita)
	var w: Node = _world()
	var site: Dictionary = _first_site(true)
	var fronts_checked: int = 0
	var bases_before: int = 0
	for f: Dictionary in occ.fronts:
		if f["mode"] == "object":
			bases_before += (f["bases"] as Dictionary).size()
	for t: Dictionary in site["tiles"]:
		for f: Dictionary in occ.fronts:
			if f["layer"] == t["layer"] and f["mode"] == "object":
				assert((f["front"] as TileMapLayer).get_cell_source_id(t["cell"]) != -1, "ön kopyada karo olmalı")
				fronts_checked += 1
	assert(fronts_checked > 0, "madenin ön kopyası bulunmalı")
	w._set_broken(int(site["index"]), true)
	var bases_broken: int = 0
	for f: Dictionary in occ.fronts:
		if f["mode"] == "object":
			bases_broken += (f["bases"] as Dictionary).size()
	assert(bases_broken < bases_before, "kırılınca derinlik kökleri azalmalı: %d -> %d" % [bases_before, bases_broken])
	for t: Dictionary in site["tiles"]:
		for f: Dictionary in occ.fronts:
			if f["layer"] == t["layer"] and f["mode"] == "object":
				assert((f["front"] as TileMapLayer).get_cell_source_id(t["cell"]) == -1, "ön kopyadaki karo silinmeli")
	w._set_broken(int(site["index"]), false)
	var bases_after: int = 0
	for f: Dictionary in occ.fronts:
		if f["mode"] == "object":
			bases_after += (f["bases"] as Dictionary).size()
	assert(bases_after == bases_before, "doğunca derinlik kökleri geri gelmeli: %d vs %d" % [bases_after, bases_before])
	for t: Dictionary in site["tiles"]:
		for f: Dictionary in occ.fronts:
			if f["layer"] == t["layer"] and f["mode"] == "object":
				assert((f["front"] as TileMapLayer).get_cell_source_id(t["cell"]) != -1, "ön kopyadaki karo geri gelmeli")
	w.free()
	_unload_map()
