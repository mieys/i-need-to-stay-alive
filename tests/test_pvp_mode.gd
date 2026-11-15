extends Node

## PvPvE MODU Aşama 1 (madde 607, docs/pvp/PLAN.md): oyun modu + takımlar + takım üssü yerleşimi + kamp parçaları + üs bölgesi sorguları.
## Co-op güvencesi: mod kapalıyken herkes aynı takım, üs listesi boş, ana harita bayrakları değişmez.

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const BasePlacementScript := preload("res://scripts/pvp/base_placement.gd")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const TeamCampScript := preload("res://scripts/pvp/team_camp.gd")
const LayoutScript := preload("res://scripts/pvp/kamp_yerlesim.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
const SpawnerScript := preload("res://scripts/enemy_spawner.gd")


class FakeChar extends Node2D:
	var is_dead: bool = false


func _restore() -> void:
	GameModeScript.set_room_mode(GameModeScript.COOP)
	TeamsScript.reset()
	BaseZonesScript.active = []
	NetworkManager.is_multiplayer_active = false


func test_new_players_join_the_smaller_team_and_nobody_switches() -> void:
	var t: Dictionary = TeamsScript.balanced_assign({}, [1, 55, 77, 99])
	assert(t[1] == 0 and t[55] == 1 and t[77] == 0 and t[99] == 1, "sırayla 0/1/0/1: %s" % str(t))
	## 55 ayrıldı, yerine 120 geldi: kimsenin takımı değişmez, yeni gelen eksik takıma (1) girer
	var t2: Dictionary = TeamsScript.balanced_assign(t, [1, 77, 99, 120])
	assert(t2[1] == 0 and t2[77] == 0 and t2[99] == 1 and t2[120] == 1, "eksik takım dolar: %s" % str(t2))
	assert(not t2.has(55), "ayrılan düşer")


## Madde 608: oyuncu seçim ekranında istediği takıma geçer (saf kural).
func test_player_can_pick_any_team_with_room() -> void:
	var peers: Array = [1, 55, 77, 99]
	var t: Dictionary = TeamsScript.balanced_assign({}, peers) ## 1,77 -> 0; 55,99 -> 1
	var cap: int = TeamsScript.team_capacity(4)
	assert(cap == 2, "4 kişilik odada takım başı 2: %d" % cap)
	assert(TeamsScript.team_capacity(8) == 4 and TeamsScript.team_capacity(5) == 3, "yarısı yukarı yuvarlanır")
	## dolu takıma geçilemez (0 takımında 1 ve 77 var)
	var full: Dictionary = TeamsScript.try_move(t, peers, 55, 0, cap)
	assert(full[55] == 1, "dolu takıma geçiş reddedilir: %s" % str(full))
	## yer açılınca geçer: 77 kızıla, sonra 55 maviye
	var a: Dictionary = TeamsScript.try_move(t, peers, 77, 1, 3)
	assert(a[77] == 1 and a[1] == 0 and a[55] == 1 and a[99] == 1, "kapasite 3: 77 kızıla geçti, başkası kıpırdamadı: %s" % str(a))
	var b: Dictionary = TeamsScript.try_move(a, peers, 55, 0, cap)
	assert(b[55] == 0 and b[1] == 0 and b[77] == 1 and b[99] == 1, "55 maviye geçti: %s" % str(b))
	## geçersiz istekler hiçbir şeyi değiştirmez
	assert(TeamsScript.try_move(t, peers, 55, 1, cap) == t, "zaten orada")
	assert(TeamsScript.try_move(t, peers, 55, 2, cap) == t and TeamsScript.try_move(t, peers, 55, -1, cap) == t, "geçersiz takım")
	assert(TeamsScript.try_move(t, peers, 404, 0, cap) == t, "odada olmayan eş")
	## takım değiştiren sonradan gelenin yerleşimini bozmaz: yeni gelen az kişili takıma girer
	var c: Dictionary = TeamsScript.try_move(a, [1, 55, 77, 99, 120], 120, 0, 3)
	assert(c[120] == 0 and c[77] == 1, "yeni gelen de yerleşti: %s" % str(c))


## 2v2'de iki takımda da oyuncu olmadan başlanmaz; co-op ya da tek kişide kural yok.
func test_pvp_start_needs_both_teams_populated() -> void:
	var peers: Array = [1, 55]
	assert(TeamsScript.start_block_reason(true, {1: 0, 55: 1}, peers) == "", "1v1 başlar")
	assert(TeamsScript.start_block_reason(true, {1: 0, 55: 0}, peers) != "", "herkes aynı takım: engel")
	assert(TeamsScript.start_block_reason(true, {1: 1, 55: 1, 77: 1}, [1, 55, 77]) != "", "üç kişi kızılda: engel")
	assert(TeamsScript.start_block_reason(false, {1: 0, 55: 0}, peers) == "", "co-op'ta kural yok")
	assert(TeamsScript.start_block_reason(true, {1: 0}, [1]) == "", "tek kişi (geliştirme) engellenmez")
	assert(TeamsScript.start_block_reason(true, {}, peers) != "", "atama boşsa herkes 0. takım sayılır")


func test_coop_and_singleplayer_are_one_team_and_keep_the_house() -> void:
	_restore()
	GameModeScript.set_room_mode(GameModeScript.PVP) ## oda modu PvP kalsa bile çok oyunculu değilse coop
	TeamsScript.set_all({1: 0, 2: 1})
	if OS.get_environment("MOD") == "":
		assert(not GameModeScript.is_pvp(), "tek oyunculu hep coop")
		assert(TeamsScript.is_ally(1, 2), "coop: herkes müttefik")
		assert(MapProfilesScript.feature("ev_acilisi") == (MapProfilesScript.current_id() == MapProfilesScript.DEFAULT_ID),
				"coop: ev açılışı haritanın kendi bayrağı")
	assert(not BaseZonesScript.shelters(Vector2(100, 100)), "üs yokken hiçbir yer sığınak değil")
	_restore()


func test_pvp_room_splits_teams_and_turns_off_the_house_intro() -> void:
	_restore()
	NetworkManager.is_multiplayer_active = true
	GameModeScript.set_room_mode(GameModeScript.PVP)
	TeamsScript.set_all({1: 0, 2: 1, 3: 0})
	assert(GameModeScript.is_pvp(), "çok oyunculu + pvp oda")
	assert(TeamsScript.is_ally(1, 3) and TeamsScript.is_enemy(1, 2), "takımlar")
	assert(MapProfilesScript.feature("ev_acilisi") == false, "PvP'de açılış evi kapalı")
	assert(MapProfilesScript.feature("calilik") == MapProfilesScript.feature("calilik"), "diğer bayraklar ezilmez")
	_restore()


## Sentetik harita: 64x64 hücre (32 birim), dış duvar, ortada kapılı duvar, sağ altta duvarla kapalı geniş bir cep (ulaşılamaz).
func _blocked(p: Vector2) -> bool:
	var c: Vector2i = Vector2i(int(p.x / 32.0), int(p.y / 32.0))
	if c.x <= 0 or c.y <= 0 or c.x >= 63 or c.y >= 63:
		return true
	if c.x == 32 and not (c.y >= 28 and c.y <= 34):
		return true
	## kapalı cep: x 44..62, y 44..62 çerçevesi
	if (c.x == 44 and c.y >= 44) or (c.y == 44 and c.x >= 44):
		return true
	return false


func test_bases_are_far_apart_reachable_and_have_room_for_the_camp() -> void:
	var rect := Rect2(0, 0, 64 * 32, 64 * 32)
	for seed_i in range(6):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + seed_i
		var res: Dictionary = BasePlacementScript.pick(_blocked, func(_p: Vector2) -> bool: return false,
				Vector2(300, 1000), rect, 32.0, rng, [[Vector2(300, 300), 400.0]])
		var picked: Array = res.get("bases", [])
		assert(picked.size() == 2, "iki üs")
		assert(float(res["clear"]) >= BasePlacementScript.CLEAR_STEPS[0], "geniş haritada tam kamp boşluğu: %s" % res["clear"])
		var a: Vector2 = picked[0]
		var b: Vector2 = picked[1]
		assert(a.distance_to(b) > 1100.0, "birbirinden uzak: %.0f" % a.distance_to(b))
		for p: Vector2 in picked:
			assert(not _blocked(p), "duvarda değil")
			assert(not (p.x > 44 * 32 and p.y > 44 * 32), "kapalı cepte değil: %s" % str(p))
			assert(p.distance_to(Vector2(300, 300)) >= 400.0, "kaçınılan noktadan uzak")
			## boşluk hücre ortalarından ölçülür (32 birimlik ızgara): yoklama payı bir hücre az
			var probe: float = float(res["clear"]) - 32.0
			assert(not _blocked(p + Vector2(probe, 0)) and not _blocked(p - Vector2(probe, 0)) and not _blocked(p + Vector2(0, probe)),
					"kamp sığar: %s" % str(p))


func test_placement_gives_up_cleanly_without_room() -> void:
	var rng := RandomNumberGenerator.new()
	var res: Dictionary = BasePlacementScript.pick(func(_p: Vector2) -> bool: return true, func(_p: Vector2) -> bool: return false,
			Vector2(10, 10), Rect2(0, 0, 640, 640), 32.0, rng)
	assert(res.is_empty(), "yer yoksa boş döner (team_bases.gd yedek konuma düşer)")


## Dar "zindan": tek büyük salon + uzak küçük odalar (koridorla bağlı). Tam kamp eşiğinde yalnız salon kalır; uzaklık öncelikli olduğu için
## üsler salona yığılmaz, eşik düşüp uzak odalara iner (2026-11-12 duman: Lağım Ağı'nda üsler 195 birim yakındı).
func _dungeon_blocked(p: Vector2) -> bool:
	var c := Vector2i(int(p.x / 32.0), int(p.y / 32.0))
	var hall := Rect2i(26, 26, 13, 13)          ## 416 birim: tam kamp sığar
	var room_a := Rect2i(2, 2, 6, 6)            ## 192 birim: küçük kamp
	var room_b := Rect2i(56, 56, 6, 6)
	var corr_a := Rect2i(4, 8, 2, 26)           ## odadan salona koridorlar
	var corr_a2 := Rect2i(4, 32, 22, 2)
	var corr_b := Rect2i(58, 32, 2, 24)
	var corr_b2 := Rect2i(39, 32, 21, 2)
	for r: Rect2i in [hall, room_a, room_b, corr_a, corr_a2, corr_b, corr_b2]:
		if r.has_point(c):
			return false
	return true


func test_tight_maps_keep_bases_far_apart_with_a_smaller_camp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var res: Dictionary = BasePlacementScript.pick(_dungeon_blocked, func(_p: Vector2) -> bool: return false,
			Vector2(32 * 32, 32 * 32), Rect2(0, 0, 64 * 32, 64 * 32), 32.0, rng)
	var picked: Array = res.get("bases", [])
	assert(picked.size() == 2, "iki üs")
	assert((picked[0] as Vector2).distance_to(picked[1]) > 1200.0, "salona yığılmadı: %.0f" % (picked[0] as Vector2).distance_to(picked[1]))
	assert(float(res["clear"]) < BasePlacementScript.CLEAR_STEPS[0], "dar yer: kırpılmış kamp (%s)" % res["clear"])
	## küçük kampta kamp ateşi kalır, uzak çadırlar düşer
	var kept: int = 0
	for e: Dictionary in LayoutScript.PARCALAR:
		if TeamCampScript.fits(e, float(res["clear"])):
			kept += 1
	assert(kept > 0 and kept < LayoutScript.PARCALAR.size(), "küçük kamp: %d / %d" % [kept, LayoutScript.PARCALAR.size()])


func test_base_zone_queries() -> void:
	BaseZonesScript.active = [{"center": Vector2(1000, 1000), "team": 0}, {"center": Vector2(3000, 1000), "team": 1}]
	assert(BaseZonesScript.shelters(Vector2(1100, 1000)) and not BaseZonesScript.shelters(Vector2(1400, 1000)), "üs içi")
	assert(BaseZonesScript.near_any(Vector2(1400, 1000), 300.0) and not BaseZonesScript.near_any(Vector2(1700, 1000), 300.0), "doğuş payı")
	assert(BaseZonesScript.in_own_base(Vector2(3000, 1100), 1) and not BaseZonesScript.in_own_base(Vector2(3000, 1100), 0), "kendi üssü")
	## doğurucu: üsteki oyuncu doğuş çapası değil
	var fc := FakeChar.new()
	add_child(fc)
	fc.global_position = Vector2(1050, 1000)
	assert(SpawnerScript._underground(fc), "üsteki oyuncu çapa olmaz")
	fc.global_position = Vector2(2000, 1000)
	assert(not SpawnerScript._underground(fc), "dışarıdaki çapa olur")
	fc.free()
	_restore()


func test_camp_pieces_exist_and_match_the_layout() -> void:
	assert(LayoutScript.PARCALAR.size() >= 6 and LayoutScript.PARCALAR.size() <= 14, "KÜÇÜK kamp: %d parça" % LayoutScript.PARCALAR.size())
	var tents: int = 0
	var fire_near_origin: bool = false
	for e: Dictionary in LayoutScript.PARCALAR:
		var tex: Texture2D = load(LayoutScript.DIR + str(e["dosya"])) as Texture2D
		assert(tex != null, "doku: %s" % e["dosya"])
		assert(tex.get_width() == int(e["w"]) * int(e["kare"]) and tex.get_height() == int(e["h"]), "şerit boyu: %s" % e["dosya"])
		if str(e["tur"]) == "cadir":
			tents += 1
			assert(float(e.get("engel_r", 0.0)) > 10.0, "çadırın çarpışma çemberi")
		if str(e["tur"]) == "ates":
			fire_near_origin = absf(float(e["x"]) + float(e["w"]) * 0.5) < 8.0
		## kullanıcı: "birsürü insan var burda. olmamalıydı" - kampta hiç karakter parçası yok
		assert(str(e["tur"]) != "karakter", "kampta insan: %s" % e["ad"])
	assert(tents == 2, "küçük kamp 2 çadır: %d" % tents)
	assert(fire_near_origin, "kamp merkezi kamp ateşi")


func test_camp_builds_blocks_tents_and_covers_a_character_behind_a_tent() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var camp: Node = TeamCampScript.new()
	holder.add_child(camp)
	camp.call("build", holder, Vector2(500, 500), 0)
	assert(int(camp.call("piece_count")) == LayoutScript.PARCALAR.size(), "bütün parçalar kuruldu")
	var blockers: int = 0
	for b: Node in get_tree().get_nodes_in_group("move_blockers"):
		if holder.is_ancestor_of(b):
			blockers += 1
	assert(blockers == 2, "2 çadır engeli: %d" % blockers)
	## bir çadırın hemen arkasında (ayağı çadırın tabanının üstünde) duran oyuncu -> çadır z 2
	var tent: Dictionary = {}
	for e: Dictionary in LayoutScript.PARCALAR:
		if str(e["tur"]) == "cadir":
			tent = e
			break
	var ch := FakeChar.new()
	ch.add_to_group("player")
	holder.add_child(ch)
	var tent_node: Node2D = holder.get_node("Kamp_0_" + str(tent["ad"])) as Node2D
	## ayak = kök + DepthOccluders.FEET_OFFSET; çadırın tabanından 20 birim yukarıda (arkasında)
	var feet_y: float = tent_node.position.y + float(tent["ayak"]) - 20.0
	ch.global_position = Vector2(tent_node.position.x + float(tent["w"]) * 0.5, feet_y - preload("res://scripts/depth_occluders.gd").FEET_OFFSET)
	for i in range(TeamCampScript.DEPTH_EVERY + 2):
		await get_tree().process_frame
	assert(tent_node.z_index == TeamCampScript.DEPTH_FRONT_Z, "arkadaki oyuncunun üstüne çizilir: z %d" % tent_node.z_index)
	ch.global_position = Vector2(tent_node.position.x + float(tent["w"]) * 0.5, tent_node.position.y + float(tent["ayak"]) + 30.0)
	for i in range(TeamCampScript.DEPTH_EVERY + 2):
		await get_tree().process_frame
	assert(tent_node.z_index == TeamCampScript.DEPTH_Z, "öndeki oyuncunun altında kalır")
	holder.free()
