extends Node

## Demirci + seyyar satıcı NPC'leri ve "ek animasyonlar" paketi (2026-10-13, madde 112): oturma klipleri 12 karakterde, Matthew/Elara yeni sayfalar,
## NPC kare dosyaları, demircinin yürünebilir raf noktaları/örs cebi/davranış akışı (selam -> örse yürü -> vur -> vedalaş), satıcının dükkana
## yaklaşıp selam/veda/düşünme akışı, derinlik sırasına girmeleri. Görüntü (piksel) doğrulaması gerçek pencerede yapıldı (tools/proto_20261013).

const ShopScript := preload("res://scripts/weapon_shop.gd")
const SmithScript := preload("res://scripts/blacksmith_npc.gd")
const MerchantNpcScript := preload("res://scripts/merchant_npc.gd")
const DepthScript := preload("res://scripts/depth_occluders.gd")
const CHAR_FRAMES: Array[String] = [
	"assasin", "buyucu", "elara", "korsan", "matthew", "melek", "necromancer", "hadime", "talha", "vampir", "shaman", "sovalye",
]
const DIRS: Array[String] = ["down", "left", "right", "up"]


## Oyuncu yerine geçen düğüm (grup "player", is_dead alanı; weapon_shop.gd _player CharacterBody2D bekler).
class FakePlayer extends CharacterBody2D:
	var is_dead: bool = false


var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## NPC'yi kendi başına çalışmaktan çıkarıp deterministik adımlarla ilerletir.
func _step(npc: Node, seconds: float, dt: float = 0.1) -> void:
	var t: float = 0.0
	while t < seconds:
		npc._process(dt)
		t += dt


func _make_player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_track(p)
	return p


# ------------------------------------------------------------------ animasyon paketi

func test_every_character_has_a_looping_four_frame_sit_clip_in_all_directions() -> void:
	for key in CHAR_FRAMES:
		var sf: SpriteFrames = load("res://assets/characters/%s_frames.tres" % key)
		assert(sf != null, "%s: kare dosyası yüklenemedi" % key)
		for d in DIRS:
			var clip: String = "sit_" + d
			assert(sf.has_animation(clip), "%s: %s yok" % [key, clip])
			assert(sf.get_frame_count(clip) == 4 and sf.get_animation_loop(clip), "%s: %s 4 kare + döngü olmalı" % [key, clip])
			var tex: Texture2D = sf.get_frame_texture(clip, 0)
			assert(tex != null and tex.get_size() == Vector2(48, 48), "%s: %s karesi 48x48 olmalı" % [key, clip])
		## Mevcut klipler bozulmadı
		assert(sf.has_animation("idle_down") and sf.has_animation("walk_left") and sf.has_animation("death_up"), "%s: eski klipler duruyor" % key)


func test_special_clips_survive_the_sit_patch() -> void:
	assert((load("res://assets/characters/vampir_frames.tres") as SpriteFrames).has_animation("bat_down"), "Vampir yarasa klibi")
	assert((load("res://assets/characters/hadime_frames.tres") as SpriteFrames).has_animation("ghostrise_down"), "Hadime hayalet kalkışı")
	assert((load("res://assets/characters/shaman_frames.tres") as SpriteFrames).has_animation("golem_slam_down"), "Shaman golem klipleri")


func test_matthew_and_elara_new_sheets_keep_frame_counts() -> void:
	var counts: Dictionary = {"idle": 4, "walk": 6, "run": 6, "eat": 3, "hurt": 2, "read": 4, "shrug": 4, "downed": 2, "death": 3, "strike": 4, "pickup": 4}
	for key in ["matthew", "elara"]:
		var sf: SpriteFrames = load("res://assets/characters/%s_frames.tres" % key)
		for sheet in counts:
			for d in DIRS:
				assert(sf.get_frame_count("%s_%s" % [sheet, d]) == counts[sheet], "%s: %s_%s kare sayısı" % [key, sheet, d])
			var tex: Texture2D = load("res://assets/characters/%s/sheets/%s.png" % [key, sheet])
			assert(tex.get_width() == 48 * int(counts[sheet]) and tex.get_height() == 192, "%s/%s.png boyutu" % [key, sheet])
		var portrait: Texture2D = load("res://assets/characters/%s_portrait.png" % key)
		assert(portrait.get_size() == Vector2(48, 48), "%s portre 48x48" % key)


func test_npc_frame_files_have_all_clips() -> void:
	var smith: SpriteFrames = load("res://assets/npc/demirci/demirci_frames.tres")
	var merchant: SpriteFrames = load("res://assets/npc/seyyar_satici/seyyar_satici_frames.tres")
	for d in DIRS:
		assert(smith.get_frame_count("idle_" + d) == 4 and smith.get_frame_count("walk_" + d) == 6 and smith.get_frame_count("strike_" + d) == 4, "demirci klipleri (%s)" % d)
		assert(smith.get_animation_loop("strike_" + d), "demirci vuruşu döngüde olmalı")
		assert(merchant.get_frame_count("idle_" + d) == 4 and merchant.get_frame_count("walk_" + d) == 6 and merchant.get_frame_count("think_" + d) == 4, "satıcı klipleri (%s)" % d)


# ------------------------------------------------------------------ demirci

func _make_shop() -> Node2D:
	var shop: Node2D = ShopScript.new()
	add_child(shop)
	_track(shop)
	await _frames(2)
	return shop


func test_blacksmith_exists_and_spots_are_open_floor() -> void:
	var shop: Node2D = await _make_shop()
	var smith: Node2D = shop.get_smith()
	assert(smith != null and smith.get_parent() == shop._interior, "demirci iç mekanın çocuğu")
	assert(smith.is_in_group("npc_actors"), "derinlik sırası için grupta")
	for spot: Dictionary in SmithScript.SHELF_SPOTS:
		var c: Vector2i = smith.cell_of(spot["pos"])
		assert(smith._main_cells.has(c), "raf noktası %s açık zeminde değil (hücre %s)" % [spot["pos"], c])
	var work: Vector2 = smith.work_feet()
	assert(smith._walkable.has(smith.cell_of(work)), "örsün arkası çalışma hücresi yürünebilir olmalı: %s" % work)
	assert(not smith._main_cells.has(smith.cell_of(work)), "örsün arkası kapalı cep (oyuncu giremez): tasarım varsayımı")
	_cleanup()


func test_blacksmith_paths_only_touch_walkable_cells_and_reach_the_anvil_pocket() -> void:
	var shop: Node2D = await _make_shop()
	var smith: Node2D = shop.get_smith()
	smith.set_process(false)
	var work: Vector2 = smith.work_feet()
	for spot: Dictionary in SmithScript.SHELF_SPOTS:
		smith.set_feet(spot["pos"])
		var to_anvil: PackedVector2Array = smith.path_to(work)
		assert(not to_anvil.is_empty() and to_anvil[to_anvil.size() - 1].distance_to(work) < 0.01, "yol örse varmalı (%s)" % spot["pos"])
		for p in to_anvil:
			assert(smith._walkable.has(smith.cell_of(p)), "örse giden yol duvara/eşyaya giriyor: %s (hücre %s)" % [p, smith.cell_of(p)])
		## Geri dönüş: cepten çıkış da duvardan geçmemeli.
		smith.set_feet(work)
		var back: PackedVector2Array = smith.path_to(spot["pos"])
		assert(back[back.size() - 1].distance_to(spot["pos"]) < 0.01, "yol rafa varmalı")
		for p in back:
			assert(smith._walkable.has(smith.cell_of(p)), "cepten dönen yol duvara giriyor: %s" % p)
	_cleanup()


func test_blacksmith_greets_walks_to_anvil_strikes_then_says_goodbye_at_the_door() -> void:
	var shop: Node2D = await _make_shop()
	var smith: Node2D = shop.get_smith()
	smith.set_process(false)
	assert(smith.state == SmithScript.State.REST_LOOK, "oyuncu yokken raflara bakıyor")
	var rest_feet: Vector2 = smith.feet()
	## Oyuncu içeri girer (kapının hemen önü, weapon_shop doğma noktası).
	var player: FakePlayer = _make_player(shop.INTERIOR_OFFSET + shop._interior_spawn_local)
	_step(smith, 0.1)
	assert(smith.state == SmithScript.State.GREET, "girişte selam")
	assert(smith._bubble.visible, "selam konuşma balonu görünür")
	_step(smith, 1.5)
	assert(smith.state == SmithScript.State.TO_ANVIL, "selamdan sonra örse yürür")
	var walked: float = 0.0
	var last: Vector2 = smith.feet()
	for i in 400:
		smith._process(0.1)
		var step_len: float = smith.feet().distance_to(last)
		assert(step_len < 6.0, "adım başına gerçekçi yürüyüş (46 px/sn): %s" % step_len)
		walked += step_len
		last = smith.feet()
		if smith.state == SmithScript.State.WORK:
			break
	assert(smith.state == SmithScript.State.WORK, "örse vardı ve çalışıyor")
	assert(walked > 20.0 or rest_feet.distance_to(smith.work_feet()) < 20.0, "yürüdü: %s" % walked)
	assert(smith.feet().distance_to(smith.work_feet()) < 1.5, "örsün arkasında durur")
	assert(smith.facing == "down" and smith.current_clip() == "strike_down", "örse dönük vurma klibi döngüde: %s" % smith.current_clip())
	assert(smith.sprite.is_playing(), "vuruş animasyonu oynuyor")
	## Kapıdan UZAKKEN vedalaşmaz; uzaklaşıp kapıya dönünce vedalaşır.
	_step(smith, 0.5)
	assert(smith.state == SmithScript.State.WORK, "girişte (kapıya yakın ama hiç uzaklaşmamış) veda yok")
	player.global_position = shop.INTERIOR_OFFSET + Vector2(-20.0, -60.0) ## örs önü: kapıdan > 100 px (silahlanır)
	_step(smith, 0.2)
	player.global_position = shop.INTERIOR_OFFSET + smith._door_local + Vector2(0, -30)
	_step(smith, 0.2)
	assert(smith.state == SmithScript.State.FAREWELL, "kapıya dönünce veda")
	assert(smith._bubble.visible, "veda balonu")
	assert(smith.current_clip().begins_with("idle_"), "vedada çekiç bırakılır: %s" % smith.current_clip())
	_step(smith, SmithScript.FAREWELL_TIME + 0.3)
	assert(smith.state == SmithScript.State.WORK and smith.current_clip() == "strike_down", "veda bitince işine döner")
	## Herkes çıkınca raf noktasına geri alınır.
	player.free()
	_step(smith, 0.2)
	assert(smith.state == SmithScript.State.REST_LOOK, "oyuncu çıkınca boşta")
	var on_spot: bool = false
	for spot: Dictionary in SmithScript.SHELF_SPOTS:
		if smith.feet().distance_to(spot["pos"]) < 1.0:
			on_spot = true
	assert(on_spot, "demirci raf noktalarından birine alındı: %s" % smith.feet())
	_cleanup()


func test_blacksmith_wanders_between_shelves_when_empty() -> void:
	var shop: Node2D = await _make_shop()
	var smith: Node2D = shop.get_smith()
	smith.set_process(false)
	shop._interior.visible = true ## görünürken yürür (gizliyken bile yürür ama bu yol testin gerçek akışı)
	var visited: Dictionary = {}
	for i in 1200:
		smith._process(0.1)
		for j in SmithScript.SHELF_SPOTS.size():
			if smith.feet().distance_to(SmithScript.SHELF_SPOTS[j]["pos"]) < 1.0:
				visited[j] = true
	assert(visited.size() >= 3, "zamanla birkaç farklı rafa gider: %s" % visited.keys())
	_cleanup()


# ------------------------------------------------------------------ seyyar satıcı

func _make_merchant() -> Array:
	var cart := Node2D.new()
	add_child(cart)
	cart.global_position = Vector2(4000, 4000)
	_track(cart)
	var npc: Node2D = MerchantNpcScript.new()
	cart.add_child(npc)
	npc.call("configure")
	npc.set_process(false)
	return [cart, npc]


func test_merchant_idles_then_greets_approaches_shop_and_says_goodbye() -> void:
	var m: Array = _make_merchant()
	var cart: Node2D = m[0]
	var npc: Node2D = m[1]
	await _frames(1)
	assert(npc.state == MerchantNpcScript.State.REST, "oyuncu yokken dinlenme")
	var rest_spot: bool = false
	for s: Vector2 in MerchantNpcScript.REST_SPOTS:
		if npc.feet().distance_to(s) < 1.0:
			rest_spot = true
	assert(rest_spot, "başlangıçta dinlenme noktalarından birinde")
	var player: FakePlayer = _make_player(cart.global_position + Vector2(0, 230))
	_step(npc, 0.1)
	assert(npc.state == MerchantNpcScript.State.TO_POST, "oyuncu yaklaşınca dükkana yürür")
	assert(npc._bubble.visible, "selam balonu")
	for i in 300:
		npc._process(0.1)
		if npc.state == MerchantNpcScript.State.SERVE:
			break
	assert(npc.state == MerchantNpcScript.State.SERVE, "dükkan noktasına vardı")
	assert(npc.feet().distance_to(MerchantNpcScript.SERVICE_POST) < 1.5, "tezgah önünde: %s" % npc.feet())
	assert(npc.facing == "down", "güneydeki oyuncuya bakıyor: %s" % npc.facing)
	## Doğudaki oyuncuya döner.
	player.global_position = cart.global_position + Vector2(250, 20)
	_step(npc, 0.5)
	assert(npc.facing == "right", "doğudaki oyuncuya döner: %s" % npc.facing)
	## Bekleme sırasında düşünme klibi de oynar.
	var thought: bool = false
	for i in 400:
		npc._process(0.1)
		if npc.current_clip().begins_with("think_"):
			thought = true
			break
	assert(thought, "ara sıra düşünme animasyonu")
	## Herkes uzaklaşınca veda + dinlenmeye dönüş.
	player.global_position = cart.global_position + Vector2(900, 0)
	_step(npc, 0.2)
	assert(npc.state == MerchantNpcScript.State.FAREWELL and npc._bubble.visible, "uzaklaşınca veda")
	_step(npc, MerchantNpcScript.FAREWELL_TIME + 0.2)
	assert(npc.state == MerchantNpcScript.State.REST, "dinlenmeye döndü")
	for i in 300:
		npc._process(0.1)
		if not npc.is_walking():
			break
	assert(not npc.is_walking(), "dinlenme noktasına vardı")
	_cleanup()


func test_merchant_rest_spots_are_inside_the_protection_bubble() -> void:
	var pts: Array[Vector2] = []
	pts.append_array(MerchantNpcScript.REST_SPOTS)
	pts.append(MerchantNpcScript.SERVICE_POST)
	for s: Vector2 in pts:
		assert(s.length() < GameManager.MERCHANT_ZONE_RADIUS, "nokta koruma baloncuğunun içinde olmalı: %s" % s)
	assert(MerchantNpcScript.APPROACH_RADIUS < MerchantNpcScript.LEAVE_RADIUS, "histerezis: yaklaşma < ayrılma yarıçapı")
	assert(MerchantNpcScript.APPROACH_RADIUS > GameManager.MERCHANT_ZONE_RADIUS, "oyuncu balona girmeden satıcı hazırlanır")


func test_traveling_merchant_visit_creates_and_frees_the_npc() -> void:
	var tm: Node2D = (load("res://scripts/traveling_merchant.gd") as GDScript).new()
	add_child(tm)
	_track(tm)
	tm._spawn_visual(Vector2(1500, 1500))
	var visual: Node2D = tm._visual
	assert(visual != null and visual.get_node_or_null("MerchantNpc") != null, "ziyarette satıcı görselin çocuğu olarak doğar")
	assert(visual.get_node_or_null("ProtectionBubble") != null, "koruma baloncuğu duruyor")
	tm._free_visual()
	await _frames(2)
	assert(not is_instance_valid(visual) or visual.is_queued_for_deletion(), "ziyaret bitince satıcı da gider")
	_cleanup()


# ------------------------------------------------------------------ derinlik

func test_npcs_join_depth_sorting_only_when_visible() -> void:
	var cart := Node2D.new()
	add_child(cart)
	_track(cart)
	var npc: Node2D = MerchantNpcScript.new()
	cart.add_child(npc)
	npc.call("configure")
	var chars: Array[Node2D] = DepthScript.character_nodes(get_tree())
	assert(chars.has(npc), "görünür NPC derinlik listesinde")
	cart.visible = false
	assert(not DepthScript.character_nodes(get_tree()).has(npc), "gizli NPC listede yok")
	_cleanup()
