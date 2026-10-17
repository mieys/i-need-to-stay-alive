extends Node

## Mermi sanatı (madde 201): Yay/Arbalet/Tüftüf/Fişek = A Zanaatkâr, Tabanca/Tüfek/Arcane/Buz = C Işık İzi (projectile_art.gd).
## Gövde yeni dokuda ve silah pikseli yoğunluğunda (yerel ölçek PUPPET_ICON_SCALE, kök sahip ölçeğiyle 0,5), yön belli olana dek gizli,
## ilk fizik adımında silahın eski çapraz sprite ofseti olsa bile UÇUŞ YÖNÜNE döner; iz "launch" -> "fly". Parçacık stilleri + fişek
## alevi (kademenin kuyruğunda, ikonun arkasında).

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
		assert(body != null and trail != null, "%s: gövde + iz" % key)
		assert(not body.visible and not trail.visible, "%s: yön belli olana dek gizli" % key)
		assert(is_equal_approx(body.scale.x, WeaponTierArt.PUPPET_ICON_SCALE), "%s: gövde silah pikselinde" % key)
		var tex: Texture2D = _body_tex(body)
		assert(tex.resource_path == ProjectileArt.DIR + str(cfg["name"]) + "_govde.png", "%s: yeni gövde dokusu" % key)
		assert(tex.get_width() % int(cfg["bf"]) == 0 and (tex.get_width() / int(cfg["bf"])) % 2 == 1 and tex.get_height() % 2 == 1,
				"%s: kare TEK boyutlu (pivot pikseli tam ortada)" % key)
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
		assert(body.visible and trail.visible, "%s: ilk adımda açılır" % key)
		assert(absf(angle_difference(body.global_rotation, dir.angle())) < 0.001, "%s: gövde uçuş yönünde" % key)
		assert(absf(angle_difference(trail.global_rotation, dir.angle())) < 0.001, "%s: iz uçuş yönünde" % key)
		assert(is_equal_approx(trail.global_scale.x, ProjectileArt.WORLD_PX), "%s: iz silah pikselinde (global)" % key)
		if is_instance_valid(p):
			p.queue_free()


func test_particle_styles_and_mapping() -> void:
	var map: Dictionary = ProjectileScript.get_script_constant_map()["PARTICLE_TRAILS"]
	assert(map["dart_projectile"] == "zehir_damla" and map["arcane_projectile"] == "arcane_c" and map["ice_bolt_projectile"] == "buz_c",
			"yeni parçacık stilleri bağlı")
	for st in ["zehir_damla", "arcane_c", "buz_c", "fisek_kivilcim", "fisek_duman"]:
		var cfg: Dictionary = ParticleTrail.STYLES[st]
		var cell: int = int(cfg["cell"])
		var sheet: Texture2D = cfg["sheet"]
		assert(sheet.get_size() == Vector2(cell * ParticleTrail.FRAMES, cell * ParticleTrail.VARIANTS), "%s sayfa boyu" % st)
		assert(is_equal_approx(float(cfg["texel"]), ProjectileArt.WORLD_PX), "%s silah pikselinde" % st)


func test_firework_flame_sits_on_tier_tail_behind_icon() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var f: Node2D = FireworkScene.instantiate()
	get_tree().current_scene.add_child(f)
	var icon: Sprite2D = f.get_node("Icon")
	var flame: AnimatedSprite2D = f.get_node("Sparkle")
	assert(flame.sprite_frames == ProjectileArt.fisek_flame_frames() and flame.is_playing(), "egzoz alevi oynuyor")
	assert(flame.get_index() < icon.get_index(), "alev roketin arkasında")
	assert(flame.position.is_equal_approx(ProjectileArt.fisek_tail(1) * WeaponTierArt.PUPPET_ICON_SCALE), "L1 kuyruğu")
	assert(is_equal_approx(flame.rotation, -PI / 4.0) and is_equal_approx(flame.scale.x, WeaponTierArt.PUPPET_ICON_SCALE), "çapraz + ikon pikseli")
	f.call("set_art_tier", 5)
	assert(flame.position.is_equal_approx(ProjectileArt.fisek_tail(5) * WeaponTierArt.PUPPET_ICON_SCALE), "L5 kuyruğu")
	f.queue_free()
