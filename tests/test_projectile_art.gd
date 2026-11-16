extends Node

## Mermi sanatı (madde 201): Yay/Arbalet/Tüftüf/Fişek = A Zanaatkâr, Tabanca/Tüfek/Arcane/Buz = C Işık İzi (projectile_art.gd).
## Gövde yeni dokuda ve silah pikseli yoğunluğunda (yerel ölçek PUPPET_ICON_SCALE, kök sahip ölçeğiyle 0,5), yön belli olana dek gizli,
## ilk fizik adımında silahın eski çapraz sprite ofseti olsa bile UÇUŞ YÖNÜNE döner; iz "launch" -> "fly". Parçacık stilleri; fişek
## (madde 402) yine eski roket + parıltı.

const ProjectileArt := preload("res://scripts/projectile_art.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const ParticleTrail := preload("res://scripts/fx_particle_trail.gd")
const ProjectileScript: GDScript = preload("res://scripts/projectile.gd")
const FireworkScene: PackedScene = preload("res://scenes/firework_projectile.tscn")


func _spawn(key: String) -> Node2D:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var p: Node2D = (load("res://scenes/%s.tscn" % key) as PackedScene).instantiate()
	p.set("impact_sounds", [] as Array[AudioStream])
	get_tree().current_scene.add_child(p)
	return p


func _body_tex(body: Node2D) -> Texture2D:
	if body is AnimatedSprite2D:
		return ((body as AnimatedSprite2D).sprite_frames.get_frame_texture(&"fly", 0) as AtlasTexture).atlas
	return (body as Sprite2D).texture


func test_every_art_projectile_gets_new_body_and_trail() -> void:
	for key in ProjectileArt.ART:
		var cfg: Dictionary = ProjectileArt.ART[key]
		var p := _spawn(key)
		var body: Node2D = p.get("_art_body")
		var trail: AnimatedSprite2D = p.get("_trail")
		var has_trail: bool = int(cfg["tf"]) > 0 ## Zehir Asası damlası (madde 410): iz şeridi yok, damlalar poison_drip_fx.gd
		assert(body != null and (trail != null) == has_trail, "%s: gövde + iz" % key)
		assert(not body.visible and (trail == null or not trail.visible), "%s: yön belli olana dek gizli" % key)
		## madde 749: "wpx" (Kaos / Kabarcık 1 dünya px) yoksa silah pikseli
		assert(is_equal_approx(body.scale.x, WeaponTierArt.PUPPET_ICON_SCALE * ProjectileArt.world_px(key) / ProjectileArt.WORLD_PX), "%s: gövde pikseli" % key)
		var tex: Texture2D = _body_tex(body)
		assert(tex.resource_path == ProjectileArt.DIR + str(cfg["name"]) + "_govde.png", "%s: yeni gövde dokusu" % key)
		assert(tex.get_width() % int(cfg["bf"]) == 0 and (tex.get_width() / int(cfg["bf"])) % 2 == 1 and tex.get_height() % 2 == 1,
				"%s: kare TEK boyutlu (pivot pikseli tam ortada)" % key)
		if not has_trail:
			p.queue_free()
			continue
		assert(trail.sprite_frames.get_frame_count(&"launch") == ProjectileArt.LAUNCH_FRAMES, "%s: uzayan iz kareleri" % key)
		assert(trail.sprite_frames.get_frame_count(&"fly") == int(cfg["tf"]), "%s: iz döngüsü" % key)
		assert(not trail.sprite_frames.get_animation_loop(&"launch") and trail.sprite_frames.get_animation_loop(&"fly"), "%s: döngüler" % key)
		var tw: int = ((trail.sprite_frames.get_frame_texture(&"fly", 0)) as AtlasTexture).region.size.x
		## izin baş pikseli (sağ kenar) gövde pivotunun gerisinde: offset.x + tw/2 - 0,5 < 0
		assert(trail.offset.x + tw / 2.0 - 0.5 < 0.0, "%s: iz gövdenin arkasında başlar" % key)
		p.queue_free()


func test_body_faces_flight_direction_despite_weapon_offset() -> void:
	## Tüftüf ve Arcane silahlarının eski çapraz sprite ofseti (weapon_*.tscn ranged_projectile_rotation_offset ~ -2,3 rad).
	for key in ["dart_projectile", "arcane_projectile", "tufek_projectile"]:
		var p := _spawn(key)
		var dir := Vector2(0.6, -0.8)
		p.set("direction", dir)
		p.rotation = dir.angle() - 2.351331587385021
		p.call("_physics_process", 0.0)
		var body: Node2D = p.get("_art_body")
		var trail: AnimatedSprite2D = p.get("_trail")
		assert(body.visible and (trail == null or trail.visible), "%s: ilk adımda açılır" % key)
		var want: float = dir.angle() if ProjectileArt.rotates(key) else 0.0 ## madde 749: Kabarcık dönmez
		assert(absf(angle_difference(body.global_rotation, want)) < 0.001, "%s: gövde uçuş yönünde (dönmeyen dik)" % key)
		if trail != null: ## Zehir Asası damlasının (dart_projectile, madde 410) iz şeridi yok
			assert(absf(angle_difference(trail.global_rotation, dir.angle())) < 0.001, "%s: iz uçuş yönünde" % key)
			assert(is_equal_approx(trail.global_scale.x, ProjectileArt.world_px(key)), "%s: iz kendi pikselinde (global)" % key)
		if is_instance_valid(p):
			p.queue_free()


func test_particle_styles_and_mapping() -> void:
	var map: Dictionary = ProjectileScript.get_script_constant_map()["PARTICLE_TRAILS"]
	assert(not map.has("dart_projectile") and not map.has("arcane_projectile") and map["ice_bolt_projectile"] == "buz_c",
			"parçacık stilleri: Zehir pufu poison_drip_fx.gd, Arcane Kaos yırtık izi sayfada (madde 749)")
	for st in ["zehir_damla", "arcane_c", "buz_c", "fisek_kivilcim", "fisek_duman"]:
		var cfg: Dictionary = ParticleTrail.STYLES[st]
		var cell: int = int(cfg["cell"])
		var sheet: Texture2D = cfg["sheet"]
		assert(sheet.get_size() == Vector2(cell * ParticleTrail.FRAMES, cell * ParticleTrail.VARIANTS), "%s sayfa boyu" % st)
		assert(is_equal_approx(float(cfg["texel"]), ProjectileArt.WORLD_PX), "%s silah pikselinde" % st)


## Madde 651: Fişek artık DİNAMİT - kafadaki çizimle aynı doku/piksel, fitil ucunda dönmeyen kıvılcım, alçak kavisle fırlatılır
## (yukarı uçmaz), havada takla atar, hedefe düşüp kısa sekmeden sonra patlar (hasarsız ağ kopyası burada: hasar yolu ayrı).
func test_dynamite_is_thrown_low_spins_and_explodes_at_target() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var f: Node2D = FireworkScene.instantiate()
	f.set("impact_sounds", [] as Array[AudioStream])
	f.set("impact_scene", null)
	get_tree().current_scene.add_child(f)
	f.set_meta("network_spawned", true)
	var start := Vector2(1000.0, 1000.0)
	var target := Vector2(1200.0, 1000.0)
	f.global_position = start
	f.scale = Vector2(0.5, 0.5) ## weapon.gd _fire_at: karakter ölçeği
	f.set("target_position", target)
	var icon: Sprite2D = f.get_node("Icon")
	var fuse: AnimatedSprite2D = f.get_node("Fuse")
	assert(icon.texture == WeaponTierArt.texture("fisek") and icon.texture.resource_path.ends_with("yeni/dinamit.png"), "dinamit çizimi")
	assert(fuse.is_playing() and fuse.sprite_frames.get_frame_count(&"loop") == 12, "fitil kıvılcımı oynuyor")
	assert(not f.has_node("Sparkle"), "roket parıltısı kalktı")
	var min_y: float = start.y
	var rot0: float = icon.rotation
	var spun: bool = false
	var exploded_at: float = -1.0
	var t: float = 0.0
	while t < 3.0:
		if not is_instance_valid(f) or f.is_queued_for_deletion():
			exploded_at = t
			break
		f.call("_process", 1.0 / 60.0)
		t += 1.0 / 60.0
		if not is_instance_valid(f) or f.is_queued_for_deletion():
			exploded_at = t
			break
		min_y = minf(min_y, f.global_position.y)
		if absf(angle_difference(icon.rotation, rot0)) > 1.0:
			spun = true
		assert(is_equal_approx(icon.global_scale.x, WeaponTierArt.WORLD_PX * WeaponTierArt.size_mult("fisek")), "dinamit pikseli = ikon pikseli")
		assert(is_zero_approx(fuse.global_rotation), "kıvılcım dönmez (korlar aşağı düşer)")
	assert(exploded_at > 0.0 and exploded_at < 1.15, "fırlatılıp ~1 sn içinde patlar: %f" % exploded_at)
	assert(start.y - min_y <= 52.5 and start.y - min_y >= 16.0, "alçak atış kavisi, yukarı uçmaz: %f" % (start.y - min_y))
	assert(spun, "havada takla atar")
	if is_instance_valid(f):
		assert(f.global_position.is_equal_approx(target), "hedef noktada patlar")
