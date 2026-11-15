extends Node

## TAKIM ÜSLERİ (PvPvE, madde 607; plan docs/pvp/PLAN.md 2.2). Yalnız PvP modunda Main'e eklenir (main.gd). Görevleri:
## - YERLEŞİM (host / tek oyunculu MOD=pvp): haritanın birbirinden uzak iki rastgele noktası (base_placement.gd: ulaşılabilir, kampın sığdığı
##   boşluk, maden / bekçi kampından uzak) -> pvp_net.gd herkese yollar. Her makine kampı (team_camp.gd) + sınır perdesini kurar.
## - BAŞLANGIÇ: yerel oyuncu kendi takımının kampına taşınır.
## - İYİLEŞME (yerel oyuncu, kendi üssünde): girer girmez, şartsız, YAVAŞ: saniyede azami canın + azami mana kalkanının HEAL_FRACTION'ı.
## - YARATIK (host): üssün geri dönüş halkasına (RADIUS + REPEL_RING) giren yaratık hedefini bırakıp üsten uzağa hızla döner
##   (enemy.gd apply_base_repel = görselsiz korku kaçışı). Üsteki oyuncu yaratıkların hedefi değildir (shelters: enemy.gd /
##   enemy_world_bridge.gd), içindeki oyuncunun çevresinde yaratık doğmaz ve doğuş noktası üsse yakın düşmez (enemy_spawner.gd).
## - RAKİP OYUNCU: kendi makinesinde sınırı geçemez ("move_blockers" çemberi YALNIZ rakip takımın makinesinde gruba girer).
## Henüz YOK (sonraki aşamalar, docs/pvp/ILERLEME.md): PvP hasarı, üste PvP yasağı, ölünce üste doğuş, takım XP / görüş, minimap işareti,
## atılma / ışınlanma yeteneklerinin sınırda kesilmesi, yaratık için C++ sert sınırı.

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")
const BasePlacementScript := preload("res://scripts/pvp/base_placement.gd")
const TeamCampScript := preload("res://scripts/pvp/team_camp.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const GroundSlotScript := preload("res://scripts/ground_slot.gd")
const BorderShader: Shader = preload("res://shaders/shaman_aura_perde.gdshader")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const GuardCampsScript := preload("res://scripts/guard_camps.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")

## Koruma alanı yarıçapı BaseZones.radius'tan okunur (tam kampta RADIUS = 160, dar yerde küçülür; _build ayarlar).
const REPEL_RING := 80.0
const REPEL_TIME := 1.2
const REPEL_EVERY := 0.2
const HEAL_FRACTION := 0.02 ## saniyede azami can / mana kalkanının %2'si (boştan tama ~50 sn)
## Doğuş noktası payı enemy_spawner.gd BASE_SPAWN_MARGIN'de (tek yer).
const PLACE_STEP := 32.0
const AVOID_GUARD_CAMP := 520.0
const AVOID_MINE := 260.0
## Yerel oyuncunun başlangıç yeri: kamp ateşinin kütük karesinin hemen güneyi (küçük kamp merkezden +23'e iner; çadırlar ateşin iki yanında,
## çarpışma çemberleri kuzeyde); takımın kaçıncı oyuncusu olduğuna göre sola / sağa.
const START_OFFSETS: Array[Vector2] = [Vector2(-36, 66), Vector2(36, 66), Vector2(-96, 66), Vector2(96, 66)]
## Sınır perdesi renkleri (dünya efekti; Shaman E perdesiyle aynı shader): kendi üssün mavi, rakibinki kızıl.
const ALLY_COLORS: Array[Color] = [Color(0.290, 0.659, 1.0), Color(0.651, 0.847, 1.0)]
const ENEMY_COLORS: Array[Color] = [Color(0.86, 0.27, 0.22), Color(1.0, 0.62, 0.50)]

var _built: bool = false
var _repel_t: float = 0.0
## Geri dönüşe rağmen üssün İÇİNDE kalan (duvara takılan / içeri savrulan) yaratık: örnek kimliği -> içeride geçen süre. STUCK_SECONDS'u geçen
## halkanın dışındaki ilk boş noktaya ışınlanır (C++ sert sınırı yokken yedek; host).
var _inside_t: Dictionary = {}
const STUCK_SECONDS := 1.6
var _camps: Array[Node] = []
var _borders: Array[Node] = []


func _ready() -> void:
	BaseZonesScript.active = []
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.bases_received.connect(_on_bases_received)
	if _decides():
		## Harita çarpışması (terrain_collision) ve diğer Main çocukları kurulsun diye iki kare sonra.
		await get_tree().process_frame
		await get_tree().process_frame
		if is_inside_tree():
			_choose_and_publish()
	elif not PvpNetScript.bases.is_empty():
		_build(PvpNetScript.bases)
	elif net != null:
		net.request_bases()


func _decides() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _on_bases_received() -> void:
	if not _built and is_inside_tree():
		_build(PvpNetScript.bases)


func _choose_and_publish() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var origin: Vector2 = player.global_position if player != null else GameManager.get_map_world_rect().get_center()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var t0: int = Time.get_ticks_msec()
	var rect: Rect2 = GameManager.get_map_world_rect()
	var deco: Dictionary = _decor_mask(rect)
	var res: Dictionary = BasePlacementScript.pick(
			func(p: Vector2) -> bool: return GameManager.is_position_blocked_by_walls(p),
			func(p: Vector2) -> bool: return deco.has(_grid_key(rect, p)) or GameManager.is_position_blocked_by_terrain(p),
			origin, rect, PLACE_STEP, rng, _avoid_list())
	var picked: Array = res.get("bases", [])
	var clear: float = float(res.get("clear", 0.0))
	if picked.size() < 2:
		push_warning("PvP üs yeri bulunamadı, başlangıç noktasının iki yanı kullanılıyor")
		picked = [origin + Vector2(-600, 0), origin + Vector2(600, 0)]
		clear = BasePlacementScript.CLEAR_STEPS[-1]
	## Tam kampın sığdığı boşlukta kırpma yok (0); dar yerde kamp o yarıçapa küçülür.
	var camp_r: float = 0.0 if clear >= BasePlacementScript.CLEAR_STEPS[0] else clear
	print("PvP üsleri: %s kamp yarıçapı %s (%d ms)" % [str(picked), "tam" if camp_r <= 0.0 else str(camp_r), Time.get_ticks_msec() - t0])
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.publish_bases(picked, camp_r) ## bases_received -> _build
	else:
		PvpNetScript.bases = picked
		PvpNetScript.camp_radius = camp_r
		_build(picked)


## Kampın konmayacağı yerler: kenar bekçi kampları (yaratıklar geri döner ama kamp sürüsünün ortası olmaz), madenler (güvenli altın olmasın).
## Kampın üstüne gelmemesi gereken harita süsleri: ağaç / çalı / saklanma çalılığı / bina / maden / düşman üssü / büyük nesne katmanlarının
## ÇİZİLEN dikdörtgeni (taç dahil). terrain çarpışması yalnız gövdeyi sayıyordu: 2026-11-12 çekiminde haritanın küçük bir ağacı kamp ateşinin
## arkasından çıkıyordu. Anahtar = yerleşim ızgarası hücresi (PLACE_STEP).
## Küçük süs çalıları (Çalılar*) SAYILMAZ: haritanın her yerinde; sayılınca hiçbir yerde kampa yer kalmıyor, kamp kırpılıyordu (duman 2026-11-12).
const DECOR_LAYER_PREFIXES: Array[String] = ["Ağaç", "Saklanma", "Düşman", "Özel maden", "Maden", "Ev", "ev", "Köprü", "Blacksmith", "blacksmith",
		"Kayalar", "Eşya", "Orman parçaları"]


func _decor_mask(rect: Rect2) -> Dictionary:
	var out: Dictionary = {}
	var map_node: Node = get_parent().get_node_or_null("Harita") if get_parent() != null else null
	if map_node == null:
		return out
	for n: Node in map_node.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		var lname: String = str(layer.name)
		var hit: bool = false
		for pre: String in DECOR_LAYER_PREFIXES:
			if lname.begins_with(pre):
				hit = true
				break
		if not hit or layer.tile_set == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var center: Vector2 = layer.to_global(layer.map_to_local(cell))
			if not rect.grow(64.0).has_point(center):
				continue
			var size := Vector2(layer.tile_set.tile_size)
			var origin := Vector2.ZERO
			var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if src != null:
				size = Vector2(src.get_tile_texture_region(layer.get_cell_atlas_coords(cell)).size)
				var td: TileData = layer.get_cell_tile_data(cell)
				if td != null:
					origin = Vector2(td.texture_origin)
			var r := Rect2(center - size * 0.5 - origin, size)
			var a: Vector2i = _grid_key(rect, r.position)
			var b: Vector2i = _grid_key(rect, r.end)
			for gy in range(a.y, b.y + 1):
				for gx in range(a.x, b.x + 1):
					out[Vector2i(gx, gy)] = true
	return out


func _grid_key(rect: Rect2, p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - rect.position.x) / PLACE_STEP)), int(floor((p.y - rect.position.y) / PLACE_STEP)))


## Bekçi kampları SABİT tanımdan (guard_camps.gd CAMPS): GuardCamps kamplarını ilk tikinde kurar (_init_camps), üs seçimi ondan önce koşuyordu ->
## liste boştu, üs güneydoğudaki düşman üssü kamplarının ortasına düşebiliyordu (2026-11-12 çekimi). Yarıçap = kaçınma + kampın kendi yarıçapı.
func _avoid_list() -> Array:
	var out: Array = []
	var forest: TileMapLayer = GameManager.get_forest_layer()
	if forest != null and MapProfilesScript.feature("kenar_bekcileri"):
		for def: Dictionary in GuardCampsScript.CAMPS:
			var center: Vector2 = forest.to_global(forest.map_to_local(def["cell"]))
			out.append([center, AVOID_GUARD_CAMP + float(def.get("radius", 0.0))])
	var mine_sites: GDScript = load("res://scripts/mine_sites.gd") as GDScript
	if mine_sites != null:
		var sites: Variant = mine_sites.get("sites")
		if sites is Array:
			for s: Variant in sites:
				if s is Dictionary and (s as Dictionary).has("bounds"):
					out.append([((s as Dictionary)["bounds"] as Rect2).get_center(), AVOID_MINE])
	return out


func _build(centers: Array) -> void:
	if _built or centers.size() < TeamsScript.TEAM_COUNT:
		return
	_built = true
	BaseZonesScript.set_camp_radius(PvpNetScript.camp_radius) ## dar yerde (küçük kamp) koruma alanı da küçülür
	var zones: Array = []
	var my_team: int = TeamsScript.local_team()
	var main: Node = get_parent()
	for t in range(TeamsScript.TEAM_COUNT):
		var c: Vector2 = centers[t]
		zones.append({"center": c, "team": t})
		var camp: Node = TeamCampScript.new()
		camp.name = "TeamCamp%d" % t
		add_child(camp)
		camp.call("build", main, c, t, PvpNetScript.camp_radius)
		_camps.append(camp)
		var border := BaseBorder.new()
		border.name = "TeamBaseBorder%d" % t
		border.setup(c, BaseZonesScript.radius, ALLY_COLORS if t == my_team else ENEMY_COLORS)
		GroundSlotScript.add_on_floor(border, self) ## ekler: haritanın içi, zeminin hemen arkası (parent'sız düğüm ister)
		_borders.append(border)
		var barrier := BaseBarrier.new()
		barrier.name = "TeamBaseBarrier%d" % t
		barrier.block_radius = BaseZonesScript.radius
		barrier.position = c
		barrier.blocks_local = (t != my_team)
		add_child(barrier)
	BaseZonesScript.active = zones
	_move_local_player_home(my_team)
	_mark_minimap.call_deferred(my_team)


## Minimapte iki üs: kendi üssüm mavi, rakibinki kızıl, "K" (kamp) işareti (görev işareti arayüzü, kimlik 9100 + takım). Madde 617.
func _mark_minimap(my_team: int) -> void:
	var main: Node = get_parent()
	var hud: Node = main.get("hud") as Node if main != null else null
	var mm: Node = hud.get_node_or_null("MinimapControl") if hud != null else null
	if mm == null or not mm.has_method("set_mission_marker"):
		return
	for t in 2:
		var c: Vector2 = BaseZonesScript.center_of(t)
		if c != Vector2.INF:
			mm.call("set_mission_marker", 9100 + t, c, ALLY_COLORS[0] if t == my_team else ENEMY_COLORS[0], "K")


func _move_local_player_home(team: int) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var spot: Vector2 = home_spot(team)
	if player == null or spot == Vector2.INF:
		return
	player.global_position = spot
	if player.has_method("reset_physics_interpolation"):
		player.reset_physics_interpolation()


## Takımın üssündeki bu oyuncunun başlangıç / doğuş noktası (takım arkadaşları yan yana, duvara düşerse üssün merkezine yakın). Üs yoksa INF.
func home_spot(team: int) -> Vector2:
	var c: Vector2 = BaseZonesScript.center_of(team)
	if c == Vector2.INF:
		return Vector2.INF
	var members: Array = TeamsScript.members(team)
	members.sort()
	var idx: int = maxi(0, members.find(TeamsScript.local_peer()))
	var spot: Vector2 = c + START_OFFSETS[idx % START_OFFSETS.size()]
	if GameManager.is_position_blocked_by_walls(spot):
		spot = c + Vector2(0, 66)
	if GameManager.is_position_blocked_by_walls(spot):
		spot = c ## dar zindan: kamp ateşinin yanı (ateş engel değil)
	return spot


## Ölen yerel oyuncunun doğacağı nokta (player.gd _pvp_teleport_home).
func respawn_spot() -> Vector2:
	return home_spot(TeamsScript.local_team())


func _process(delta: float) -> void:
	if not _built:
		return
	_heal_local(delta)
	if _decides():
		_repel_t -= delta
		if _repel_t <= 0.0:
			_repel_t = REPEL_EVERY
			_repel_creatures()


func _heal_local(delta: float) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null or not (p is Node2D) or p.get("is_dead") == true or p.get("is_downed") == true:
		return
	if not BaseZonesScript.in_own_base((p as Node2D).global_position, TeamsScript.local_team()):
		return
	var max_hp: float = float(p.get("max_health"))
	if float(p.get("health")) < max_hp:
		p.call("heal", max_hp * HEAL_FRACTION * delta, false, &"s:pvp_us", true)
	var shield_max: float = float(p.get("item_shield_max"))
	if shield_max > 0.0 and float(p.get("item_shield_hp")) < shield_max:
		p.call("heal_shield", shield_max * HEAL_FRACTION * delta, false, false, &"s:pvp_us")


func _repel_creatures() -> void:
	var tree: SceneTree = get_tree()
	var reach: float = BaseZonesScript.radius + REPEL_RING
	var seen: Dictionary = {}
	for b: Dictionary in BaseZonesScript.active:
		var c: Vector2 = b["center"]
		for e: Node in EnemyQueryScript.candidates(tree, c, reach):
			if not is_instance_valid(e) or e.get("is_dead") == true or not e.has_method("apply_base_repel"):
				continue
			var d2: float = (e as Node2D).global_position.distance_squared_to(c)
			if d2 > reach * reach:
				continue
			e.call("apply_base_repel", c, REPEL_TIME)
			if d2 <= BaseZonesScript.radius * BaseZonesScript.radius:
				var id: int = e.get_instance_id()
				seen[id] = true
				var t: float = float(_inside_t.get(id, 0.0)) + REPEL_EVERY
				_inside_t[id] = t
				if t >= STUCK_SECONDS and e.has_method("teleport_to"):
					var out: Vector2 = _outside_spot(c, (e as Node2D).global_position)
					if out != Vector2.INF:
						e.call("teleport_to", out)
						_inside_t.erase(id)
	for id: int in _inside_t.keys():
		if not seen.has(id):
			_inside_t.erase(id)


## Üs merkezinden yaratığın yönünde (yoksa çevresinde) halkanın hemen dışındaki ilk engelsiz nokta.
func _outside_spot(c: Vector2, from: Vector2) -> Vector2:
	var base_dir: Vector2 = (from - c).normalized() if from.distance_squared_to(c) > 1.0 else Vector2.RIGHT
	var r: float = BaseZonesScript.radius + REPEL_RING + 24.0
	for k in range(16):
		var ang: float = (k / 2) * (TAU / 16.0) * (1.0 if k % 2 == 0 else -1.0)
		var p: Vector2 = c + base_dir.rotated(ang) * r
		if not GameManager.is_position_blocked_by_walls(p) and not BaseZonesScript.near_any(p, REPEL_RING):
			return p
	return Vector2.INF


func _exit_tree() -> void:
	BaseZonesScript.active = []
	BaseZonesScript.radius = BaseZonesScript.RADIUS
	for b: Node in _borders:
		if is_instance_valid(b):
			b.queue_free()
	_borders.clear()
	PvpNetScript.clear_match()


## Üs sınırı perdesi: Shaman E aura perdesinin shader'ı (madde 586), takım renginde, kalıcı. Haritanın içinde zemin katmanlarının hemen arkası
## (GroundSlot.add_on_floor): ağaç / ev / karakterlerin altı.
class BaseBorder extends Node2D:
	const MARGIN := 24.0
	var _mat: ShaderMaterial
	var _center: Vector2
	var _radius: float
	var _t: float = 0.0

	func setup(center: Vector2, radius: float, colors: Array[Color]) -> void:
		_center = center
		_radius = radius
		_mat = ShaderMaterial.new()
		_mat.shader = BorderShader
		_mat.set_shader_parameter("c_base", colors[0])
		_mat.set_shader_parameter("c_light", colors[1])
		_mat.set_shader_parameter("center", center)
		_mat.set_shader_parameter("radius", radius)
		_mat.set_shader_parameter("grow", 1.0)
		_mat.set_shader_parameter("alpha_mult", 0.8)
		material = _mat
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _ready() -> void:
		z_index = 0
		z_as_relative = true
		global_position = Vector2.ZERO
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_mat.set_shader_parameter("time_s", _t)

	func _draw() -> void:
		var h: float = _radius + MARGIN
		var a: Vector2 = to_local(_center - Vector2(h, h))
		var b: Vector2 = to_local(_center + Vector2(h, h))
		draw_rect(Rect2(a, b - a), Color.WHITE)


## Rakip takımın üssüne girişi engelleyen çember: "move_blockers" sözleşmesi (player.gd _block_movement_into_blockers). Gruba YALNIZ
## yerel oyuncu bu üssün rakibiyken girer (sözleşmeyi yalnız yerel oyuncu okur) - kendi üssün engel değildir.
class BaseBarrier extends Node2D:
	var block_radius: float = 280.0
	var blocks_local: bool = false

	func _ready() -> void:
		if blocks_local:
			add_to_group("move_blockers")

	func block_center() -> Vector2:
		return global_position
