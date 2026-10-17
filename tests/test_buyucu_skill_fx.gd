extends Node

## Büyücü Kız yeni efektleri (2026-10-16, madde 188): Q kitap + set zerreleri, Arcane Lanet gözü + mühür, Hortum sayfaları + çözülme,
## pasifin güçlendirilmiş mermisi. Mekanik testleri test_buyucu_slot_swap / test_buyucu_evolutions'ta; burası sadece görsel düğümler.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const BounceScene: PackedScene = preload("res://scenes/fx_arcane_skull_bounce.tscn")
const TornadoScene: PackedScene = preload("res://scenes/fx_buyucu_tornado.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/arcane_projectile.tscn")

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 4
	GameManager.selected_character = 3
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	return p


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _sheets_under(root: Node) -> Array:
	var out: Array = []
	for c in root.find_children("*", "Sprite2D", true, false):
		if c is BuyucuFxScript.Sheet:
			out.append(c)
	return out


func _world_sheets(name: String) -> Array:
	var out: Array = []
	for c in get_tree().current_scene.get_children():
		if c is BuyucuFxScript.Sheet and (c as Sprite2D).texture == BuyucuFxScript.tex(name):
			out.append(c)
	return out


## Sayfa adları/kare sayıları üretici ile aynı: doku genişliği kare sayısına tam bölünür, kareler kare boyunda (sayfa tablosu kaymasın).
func test_sheet_table_matches_textures() -> void:
	var sizes := {"q_back_0": 64, "lanet_eye": 16, "lanet_brand": 40, "hortum_loop": 48, "surge_wave": 128, "surge_hit": 32}
	for n in BuyucuFxScript.SHEETS:
		var t: Texture2D = BuyucuFxScript.tex(n)
		assert(t != null, "sayfa yüklenir: %s" % n)
		var count: int = int(BuyucuFxScript.SHEETS[n])
		assert(t.get_width() % count == 0, "%s: genişlik %d, %d kareye bölünür" % [n, t.get_width(), count])
		if sizes.has(n):
			assert(t.get_width() / count == int(sizes[n]), "%s kare genişliği %d" % [n, sizes[n]])


## Q: hedef sete göre soğuk/sıcak sayfa, karakter sprite'ına hizalı (konum/offset/ölçek), arka katman karakterin altında, ön üstünde;
## sayfa bitince kendini siler.
func test_q_swap_book_layers() -> void:
	var p: Node = _make_player()
	p._skill_buyucu_switch_variation()
	var target: int = p.buyucu_variation_set
	var fx: Node = null
	for c in p.get_children():
		if str(c.scene_file_path).ends_with("fx_mage_swap.tscn"):
			fx = c
	assert(fx != null, "Q efekti karakterin çocuğu")
	var sheets: Array = _sheets_under(fx)
	assert(sheets.size() == 2, "arka + ön katman: %d" % sheets.size())
	var names: Array = []
	for s in sheets:
		names.append((s as Sprite2D).texture.resource_path.get_file())
		assert((s as Sprite2D).position == p.anim.position and (s as Sprite2D).offset == p.anim.offset, "karakter sprite'ına hizalı")
		assert((s as Sprite2D).scale.is_equal_approx(p.char_base_anim_scale.abs()), "karakter taban ölçeği")
	assert(names.has("q_back_%d.png" % target) and names.has("q_front_%d.png" % target), "hedef setin sayfaları: %s" % str(names))
	var zs: Array = sheets.map(func(s): return (s as CanvasItem).z_index)
	assert(zs.has(-1) and zs.has(2), "arka -1, ön 2: %s" % str(zs))
	for i in 30: ## 21 kare / 15 fps = 1,4 sn
		await get_tree().create_timer(0.1).timeout
	assert(not is_instance_valid(fx), "sayfa bitince efekt silinir")
	_cleanup()


## Arcane Lanet: göz uçar, varınca patlama + ayak mührü; ilk sekmede kalkış mührü; sonraki sekme büyük.
func test_lanet_eye_hop_and_impact() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var fx: Node2D = BounceScene.instantiate() as Node2D
	fx.set("hop", 2)
	get_tree().current_scene.add_child(fx)
	fx.call("setup_positions", Vector2(100, 100), Vector2(220, 130))
	var eye: Sprite2D = null
	for c in fx.get_children():
		if c is Sprite2D:
			eye = c
	assert(eye != null and eye.texture == BuyucuFxScript.tex("lanet_eye"), "lanet gözü sayfası")
	assert(is_equal_approx(eye.scale.x, BuyucuFxScript.PX * (1.0 + 0.12 * 2)), "3. sekme %%24 büyük: %.3f" % eye.scale.x)
	assert(_world_sheets("lanet_cast").is_empty(), "kalkış mührü sadece ilk sekmede")
	var mid_off: float = 0.0
	for i in 40: ## 124 birim / 750 = 0,17 sn (başsız koşuda kare süresi değişken - zamanla bekle)
		await get_tree().create_timer(0.02).timeout
		if not is_instance_valid(fx):
			break
		if is_instance_valid(fx):
			var t: float = clampf((fx.global_position.x - 100.0) / 120.0, 0.0, 1.0)
			var line_y: float = 100.0 + 30.0 * t
			mid_off = maxf(mid_off, line_y - fx.global_position.y)
	assert(not is_instance_valid(fx), "göz hedefe varınca silinir")
	assert(mid_off > 3.0, "kavisli (yukarı şişen) yol: %.1f" % mid_off)
	await get_tree().process_frame
	assert(_world_sheets("lanet_burst").size() == 1 and _world_sheets("lanet_brand").size() == 1, "patlama + ayak mührü")
	var brand: Node2D = _world_sheets("lanet_brand")[0]
	assert(brand.global_position.y > 130.0 and is_equal_approx(brand.global_position.x, 220.0), "mühür hedefin ayağında")
	var first: Node2D = BounceScene.instantiate() as Node2D
	get_tree().current_scene.add_child(first)
	first.call("setup_positions", Vector2(0, 0), Vector2(200, 0))
	assert(_world_sheets("lanet_cast").size() == 1, "ilk sekmede kalkış mührü")
	for i in 20:
		await get_tree().create_timer(0.05).timeout
	for c in get_tree().current_scene.get_children():
		if c is BuyucuFxScript.Sheet:
			c.free()


## Hortum: doğuş -> döngü sayfası; ömür bitince "ending" + çözülme sayfası, hasar biter, düğüm kendini siler. Uzak kopya da begin_out'la.
func test_tornado_sheets_and_unravel() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var t: Node2D = TornadoScene.instantiate() as Node2D
	get_tree().current_scene.add_child(t)
	t.call("setup", null, Vector2(500, 500), 100.0, 1.0, 1.0, 0.3, 46.0)
	var sh: Sprite2D = t.get("_sheet")
	assert(sh != null and sh.texture == BuyucuFxScript.tex("hortum_in"), "doğuş sayfası")
	assert(sh.offset == Vector2(0, -28) and is_equal_approx(sh.scale.x, BuyucuFxScript.PX), "zemin satırı düğüm orijininde")
	var ended := [false]
	t.connect("ending", func() -> void: ended[0] = true)
	for i in 8:
		await get_tree().create_timer(0.1).timeout
	assert(ended[0], "ömür (0,3 sn) bitince ending")
	assert(is_instance_valid(t) and t.get("_ending") == true, "çözülürken düğüm duruyor")
	assert(is_instance_valid(sh) and sh.texture == BuyucuFxScript.tex("hortum_out"), "çözülme sayfası")
	for i in 12:
		await get_tree().create_timer(0.1).timeout
	assert(not is_instance_valid(t), "çözülme bitince silinir")
	var remote: Node2D = TornadoScene.instantiate() as Node2D
	remote.call("mark_as_network_visual")
	get_tree().current_scene.add_child(remote)
	remote.call("begin_out")
	assert((remote.get("_sheet") as Sprite2D).texture == BuyucuFxScript.tex("hortum_out"), "uzak kopya da çözülür")
	remote.free()


## Pasif: güçlendirilmiş mermi namlu parlaması + mor iz + meta; ilk isabette mor patlama, ikinci isabette yok.
func test_surge_projectile_look() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var proj: Node2D = ProjectileScene.instantiate() as Node2D
	get_tree().current_scene.add_child(proj)
	proj.global_position = Vector2(300, 300)
	BuyucuFxScript.style_surge_projectile(proj)
	assert(proj.has_meta("buyucu_surge"), "güçlendirme işareti")
	assert(_world_sheets("surge_muzzle").size() == 1, "namlu parlaması")
	var trail: Node = null
	for c in proj.get_children():
		if c.get("width_px") != null:
			trail = c
	assert(trail != null and is_equal_approx(float(trail.get("len_px")), BuyucuFxScript.SURGE_TRAIL_LEN), "uzun mor iz")
	assert((trail.get("pal") as Array)[2] == BuyucuFxScript.ARC[2], "iz menekşe")
	proj.call("_spawn_impact")
	proj.call("_spawn_impact")
	assert(_world_sheets("surge_hit").size() == 1, "mor patlama ilk isabette bir kez")
	proj.free()
	for c in get_tree().current_scene.get_children():
		if c is BuyucuFxScript.Sheet:
			c.free()
	## Uzak kopya: EnchantFx look["surge"] aynı fonksiyonu çağırır.
	var proj2: Node2D = ProjectileScene.instantiate() as Node2D
	get_tree().current_scene.add_child(proj2)
	preload("res://scripts/enchant_fx.gd").apply_projectile_look(proj2, {"surge": true})
	assert(proj2.has_meta("buyucu_surge"), "uzak kopya da mor iz")
	proj2.free()
	for c in get_tree().current_scene.get_children():
		if c is BuyucuFxScript.Sheet:
			c.free()


## Meteor kanalı (2026-10-17): ayak altında çember (süreye göre fps) + korlar; süre bitince çember parçalanır, düğüm silinir.
## "Yükseliş" görünümü (buyucu_levitate.gd) ESKİ - burada sadece çember/korlar.
func test_meteor_channel_ring() -> void:
	var p: Node = _make_player()
	p._skill_buyucu_meteor()
	var fx: Node = null
	for c in p.get_children():
		if str(c.scene_file_path).ends_with("fx_buyucu_meteor_channel.tscn"):
			fx = c
	assert(fx != null, "kanal efekti karakterin çocuğu")
	var names: Array = []
	for s in _sheets_under(fx):
		names.append((s as Sprite2D).texture.resource_path.get_file())
		if (s as Sprite2D).texture == BuyucuFxScript.tex("r_ring"):
			assert(is_equal_approx(float(s.get("fps")), 45.0 / p.BUYUCU_METEOR_CHANNEL_TIME), "çember kanal süresinde dolar")
	assert(names.has("r_ring.png") and names.has("r_embers.png"), "çember + korlar: %s" % str(names))
	assert(p.modulate == Color.WHITE, "eski turuncu kanal rengi yok")
	p._buyucu_meteor_channel_active = false ## meteor düşürmesin
	p.is_dead = true ## ölünce çember hemen parçalanır (süre dolunca da aynı çıkış sayfası)
	for i in 8:
		await get_tree().create_timer(0.1).timeout
	assert(not is_instance_valid(fx), "çember parçalanıp silinir")
	p.is_dead = false
	_cleanup()


## Meteor düşüşü: uyarı + düşen kaya, isabette patlama + hasar halkası + krater; ölçek (Efsunlu Büyü) halkayı büyütür; sonunda silinir.
func test_meteor_strike_sheets() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var m: Node2D = preload("res://scenes/fx_meteor_strike.tscn").instantiate() as Node2D
	m.scale = Vector2.ONE * 1.25
	get_tree().current_scene.add_child(m)
	m.call("setup", Vector2(400, 400))
	var tex_of := func() -> Array:
		var out: Array = []
		for s in _sheets_under(m):
			out.append((s as Sprite2D).texture.resource_path.get_file().get_basename())
		return out
	assert((tex_of.call() as Array).has("meteor_warn") and (tex_of.call() as Array).has("meteor_fall"), "uyarı + kaya")
	var rock: Sprite2D = m.get("_rock")
	assert(rock.position.y < -300.0, "kaya yukarıdan başlar: %.0f" % rock.position.y)
	for i in 12:
		await get_tree().create_timer(0.05).timeout
	var t: Array = tex_of.call()
	assert(t.has("meteor_burst") and t.has("meteor_ring") and t.has("meteor_crater") and not t.has("meteor_fall"), "isabet sayfaları: %s" % str(t))
	for i in 34:
		await get_tree().create_timer(0.1).timeout
	assert(not is_instance_valid(m), "krater bitince silinir")
