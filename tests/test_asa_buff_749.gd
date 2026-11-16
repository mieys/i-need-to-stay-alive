extends Node

## Madde 749 (2026-11-16, kullanıcı seçimleri): Buz Asası yavaşlatması yaratığı yalnız buz mavisine boyar (kırağı / kristal yok); Arcane
## "C - Kaos Yarığı" + buff (atış 1,4 sn, yankı ŞANSSIZ - silah sayacıyla her 3. isabette kesin, %100); Zehir "B - Kabarcık" + buff
## (atış 1,3 sn, yük başına %10). Görsel sahneler yerinde mi.

const WeaponTraitsScript: GDScript = preload("res://scripts/weapon_traits/weapon_traits.gd")
const EchoScript: GDScript = preload("res://scripts/weapon_traits/yankilanan_buyu.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const ProjectileArt := preload("res://scripts/projectile_art.gd")

var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func _echo(stats: Dictionary) -> Node:
	var b: Node = EchoScript.new()
	b.set("stats", stats)
	_made.append(b)
	return b


func test_echo_opens_on_every_third_hit_of_the_weapon() -> void:
	var base: Dictionary = (WeaponTraitsScript.DEFS["yankilanan_buyu"] as Dictionary)["base"]["set"]
	assert(is_equal_approx(float(base["echo_chance"]), 0.0) and int(base["echo_pity"]) == 2, "şans yok, her 3. isabet")
	assert(is_equal_approx(float(base["echo_dmg"]), 1.0), "patlama silah hasarının %100'ü")
	var b: Node = _echo(base.duplicate())
	var got: Array = []
	for i in 6:
		got.append(bool(b.call("_echo_now")))
	assert(got == [false, false, true, false, false, true], "sayaç silaha bağlı: her 3. isabet (%s)" % str(got))
	## Sık Yankı (-1) -> her 2. isabet; final de -1 ekler -> ikisi birlikte her isabet
	var b2: Node = _echo({"echo_chance": 0.0, "echo_pity": 1})
	var got2: Array = []
	for i in 4:
		got2.append(bool(b2.call("_echo_now")))
	assert(got2 == [false, true, false, true], "Sık Yankı: her 2. isabet (%s)" % str(got2))
	var b3: Node = _echo({"echo_chance": 0.0, "echo_pity": 0})
	for i in 3:
		assert(bool(b3.call("_echo_now")), "Sık Yankı + final: her isabet")
	var ups: Array = (WeaponTraitsScript.DEFS["yankilanan_buyu"] as Dictionary)["upgrades"]
	assert(int((ups[0] as Dictionary)["add"]["echo_pity"]) == -1, "Sık Yankı -1")
	var fin: Dictionary = (WeaponTraitsScript.DEFS["yankilanan_buyu"] as Dictionary)["final"]
	assert(int(fin["add"]["echo_pity"]) == -1 and is_equal_approx(float(fin["set"]["echo_stun"]), 0.5), "final: bir isabet erken + sersemletme")
	_cleanup()


## Gerçek asa davranışı: 3 isabette bir "void_rift_open" sprite'ı doğar (hangi düşman olursa olsun), 0,8 sn sonra patlama sayfası + hasar.
func test_real_arcane_opens_rift_on_third_hit() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	var saved: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("arcane", 1, 0)] ## özellik kaydı girdide (oyundaki alım yolu gibi)
	var p: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p)
	_made.append(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(5000.0, 5000.0)
	assert(p.buy_weapon_copy("arcane", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	assert(beh != null and str(beh.get_script().resource_path).ends_with("yankilanan_buyu.gd"),
			"Arcane doğuştan Yankılanan Büyü: %s" % (str(beh.get_script().resource_path) if beh != null else "null"))
	var a: Node2D = EnemyScene.instantiate()
	add_child(a)
	_made.append(a)
	a.global_position = Vector2(4000.0, 4000.0)
	var b: Node2D = EnemyScene.instantiate()
	add_child(b)
	_made.append(b)
	b.global_position = Vector2(4400.0, 4000.0)
	await get_tree().physics_frame
	var proj := Node2D.new()
	add_child(proj)
	_made.append(proj)
	var rifts: Array = []
	for i in 6:
		beh.call("hit_extra", a if i % 2 == 0 else b, 10.0, true, proj)
		rifts.append(_sheet_count("void_rift_open"))
	assert(rifts == [0, 0, 1, 1, 1, 2], "her 3. isabette (iki farklı düşman) yarık: %s" % str(rifts))
	GameManager.owned_weapons = saved
	get_tree().current_scene = prev_scene
	for n in get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx_enchant_sprite.gd"):
			n.free()
	_cleanup()


## Gerçek Buz Asası isabeti (on_hit -> _generic_hit): ilk isabet yavaşlatır ve yaratığı yalnız buz mavisine boyar.
func test_real_buz_hit_tints_slime() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	var saved: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("buz_asasi", 1, 0)]
	var p: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p)
	_made.append(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(5000.0, 5000.0)
	assert(p.buy_weapon_copy("buz_asasi", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	assert(beh != null and bool(beh.call("flag", "slow_chill")), "Kırık Buz: slow_chill açık")
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	add_child(e)
	_made.append(e)
	e.global_position = Vector2(4000.0, 4000.0)
	await get_tree().physics_frame
	beh.call("on_hit", e, 1.0, true, null)
	assert(bool(e.call("_frost_chill_active")), "ilk isabet: buz mavisi ton düğümü")
	var target: CanvasItem = e.get("anim_sprite") if e.get("anim_sprite") != null else e.get("frame_sprite")
	var want: Color = e.get_script().get_script_constant_map()["FROST_SLOW_TINT_COLOR"]
	assert(target != null and target.modulate.is_equal_approx(want), "slime gövdesi buz mavisi: %s" % str(target.modulate if target else null))
	GameManager.owned_weapons = saved
	get_tree().current_scene = prev_scene
	_cleanup()


func _sheet_count(sheet: String) -> int:
	var c: int = 0
	for n in get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx_enchant_sprite.gd") and str(n.get("sheet")) == sheet:
			c += 1
	return c


func test_echo_pop_sheet_follows_radius_upgrade() -> void:
	var b: Node = _echo({"echo_radius": 45.0})
	assert(str(b.call("_pop_sheet")) == "void_rift_pop_45", "temel 45 birim sayfası")
	b.set("stats", {"echo_radius": 60.0})
	assert(str(b.call("_pop_sheet")) == "void_rift_pop_60", "Geniş Yankı 60 birim sayfası (ölçekleme yok)")
	for sheet in ["void_rift_open", "void_rift_pop_45", "void_rift_pop_60"]:
		var fr: SpriteFrames = load("res://assets/fx/enchant/%s_frames.tres" % sheet)
		assert(fr != null and fr.has_animation(&"play") and not fr.get_animation_loop(&"play"), "%s tek seferlik sayfa" % sheet)
	_cleanup()


func test_buff_numbers() -> void:
	var zeh: Dictionary = (WeaponTraitsScript.DEFS["sicrayan_zehir"] as Dictionary)["base"]["set"]
	assert(is_equal_approx(float(zeh["poison_dps"]), 0.10), "Zehir yükü saldırı gücünün %10'u")
	var buz: Dictionary = (WeaponTraitsScript.DEFS["kirik_buz"] as Dictionary)["base"]["set"]
	assert(bool(buz["slow_chill"]), "Buz yavaşlatması mavi ton açar")
	for pair in [["res://scenes/weapon_arcane.tscn", 1.4], ["res://scenes/weapon_tuftuf.tscn", 1.3]]:
		var w: Node = (load(pair[0]) as PackedScene).instantiate()
		var real: float = float(w.get("fire_rate")) / GameManager.WEAPON_ATTACK_SPEED_MULT
		assert(absf(real - float(pair[1])) < 0.01, "%s gerçek atış aralığı %.2f sn (%.3f)" % [pair[0], float(pair[1]), real])
		w.free()


func test_projectile_art_and_scenes() -> void:
	for key in ["arcane_projectile", "dart_projectile"]:
		assert(is_equal_approx(ProjectileArt.world_px(key), 1.0), "%s 1 dünya px pikseli" % key)
		assert(ProjectileArt.impact_on_body(key), "%s isabeti gövde hizasında" % key)
		assert(ResourceLoader.exists(ProjectileArt.muzzle_path(key)), "%s namlu sahnesi" % key)
	assert(not ProjectileArt.rotates("dart_projectile") and ProjectileArt.rotates("arcane_projectile"), "kabarcık dönmez, kaos döner")
	var arc: Node = (load("res://scenes/arcane_projectile.tscn") as PackedScene).instantiate()
	assert((arc.get("impact_scene") as PackedScene).resource_path == "res://scenes/fx_hit_void_crack.tscn", "Arcane isabeti kaos çatlağı")
	arc.free()
	var dart: Node = (load("res://scenes/dart_projectile.tscn") as PackedScene).instantiate()
	assert((dart.get("impact_scene") as PackedScene).resource_path == "res://scenes/fx_hit_kabarcik.tscn", "Zehir isabeti kabarcık")
	dart.free()
	for path in ["res://scenes/fx_hit_void_crack.tscn", "res://scenes/fx_namlu_kaos.tscn", "res://scenes/fx_hit_kabarcik.tscn",
			"res://scenes/fx_namlu_kabarcik.tscn", "res://scenes/fx_zehir_bulut.tscn"]:
		var fx: AnimatedSprite2D = (load(path) as PackedScene).instantiate() as AnimatedSprite2D
		assert(fx != null and fx.sprite_frames.has_animation(&"play") and not fx.sprite_frames.get_animation_loop(&"play"), "%s tek seferlik" % path)
		assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and is_equal_approx(fx.scale.x, 1.0), "%s piksel / ölçek 1" % path)
		fx.free()


func test_buz_slow_only_tints_blue() -> void:
	NetworkManager.is_multiplayer_active = false
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	_made.append(e)
	var plain: Node2D = EnemyScene.instantiate()
	add_child(plain)
	_made.append(plain)
	await get_tree().physics_frame
	e.call("apply_element", "slow", {"pct": 0.3, "dur": 1.5, "chill": true})
	assert(bool(e.call("_frost_chill_active")), "Buz yavaşlatması ton düğümü açtı")
	var fx: Node = e.get("_frost_chill_fx")
	assert(bool(fx.get("tint_only")) and fx.get("_back") == null and fx.get("_front") == null, "kırağı / kristal katmanı YOK")
	var target: CanvasItem = e.get("anim_sprite") if e.get("anim_sprite") != null else e.get("frame_sprite")
	var want: Color = e.get_script().get_script_constant_map()["FROST_SLOW_TINT_COLOR"]
	assert(target.modulate.is_equal_approx(want), "gövde buz mavisi: %s" % str(target.modulate))
	plain.call("apply_element", "slow", {"pct": 0.3, "dur": 1.5})
	assert(not bool(plain.call("_frost_chill_active")), "başka yavaşlatma tonlamaz")
	## Don Nova sonradan gelirse kırağı katmanları eklenir
	e.call("apply_element", "frost_slow", {"pct": 0.5, "dur": 2.0})
	assert(not bool(fx.get("tint_only")) and fx.get("_back") != null, "Don Nova katmanları ekledi")
	_cleanup()
