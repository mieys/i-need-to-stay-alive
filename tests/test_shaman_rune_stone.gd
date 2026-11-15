extends Node

## Madde 557: Shaman Q/E totemleri RÜN TAŞI (kullanıcının çizimleri, tools/gen_shaman_rune_stones.py + scripts/totem_rune_stone.gd).
## Sahne yapısı (%30 küçük, oyunun nesne gölgesi), ateş topu / kalkan dalgası çıkışının taşın rün merkezi olması, evrim -> rün satırı
## eşlemesi, sıralı rün döngüsü ve "parazitsiz" (kademesiz, titremesiz) parıltı.

const AttackTotemScene: PackedScene = preload("res://scenes/totem_attack.tscn")
const ShieldTotemScene: PackedScene = preload("res://scenes/totem_shield.tscn")
const RuneStone: GDScript = preload("res://scripts/totem_rune_stone.gd")
const NightGlowCatalog: GDScript = preload("res://scripts/night_glow_catalog.gd")
const STONE_SCALE := 0.632 ## Shaman pikseli 0,903 x 0,7 (kullanıcı: "%30 daha küçük")

var _spawned: Array = []


class FakeCaster extends Node2D:
	var evos: Dictionary = {}

	func has_evo(evo_id: String) -> bool:
		return evos.has(evo_id)


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Totem: süreç kapalı (rün taşını testte elle ilerletiriz; totem tik/ses/dalga işlemesin), sahte sahip.
func _make_totem(scene: PackedScene, evos: Array) -> Node2D:
	var caster := FakeCaster.new()
	add_child(caster)
	_spawned.append(caster)
	for e in evos:
		caster.evos[e] = true
	var totem: Node2D = scene.instantiate()
	totem.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(totem)
	_spawned.append(totem)
	totem.set("caster", caster)
	return totem


func _stone(totem: Node2D) -> Node:
	return totem.get_node("TotemSprite")


func test_totem_scenes_are_rune_stones() -> void:
	for pair in [[AttackTotemScene, "q"], [ShieldTotemScene, "e"]]:
		var inst: Node = (pair[0] as PackedScene).instantiate()
		var spr: Sprite2D = inst.get_node_or_null("TotemSprite") as Sprite2D
		assert(spr != null, "TotemSprite bir Sprite2D (rün taşı) olmalı")
		assert(spr.get_script() == RuneStone, "TotemSprite totem_rune_stone.gd taşımalı")
		assert(String(spr.get("kind")) == pair[1], "taş türü %s olmalı" % pair[1])
		assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "NEAREST olmalı")
		assert(is_equal_approx(spr.scale.x, STONE_SCALE) and is_equal_approx(spr.scale.y, STONE_SCALE), "taş %30 küçük (0,632) olmalı")
		assert(spr.texture.get_size() == Vector2(32, 32), "taş kullanıcının 32x32 çizimi olmalı")
		var sheet: Texture2D = spr.get("rune_sheet")
		assert(sheet != null and sheet.get_size() == Vector2(32 * RuneStone.COLS, 32 * RuneStone.RUNE_ROWS), "rün sayfası 2 sütun (çekirdek + hale) x 6 rün")
		var glow: Texture2D = spr.get("glow_texture")
		assert(glow != null and glow.get_size() == Vector2(36, 36), "taş parıltısı 36x36 (2 px pay)")
		inst.free()
	assert(not ResourceLoader.exists("res://assets/shaman/totem_attack_idle.png"), "eski v4 totem sayfası silinmiş olmalı")
	assert(not ResourceLoader.exists("res://assets/shaman/totem_shield_idle.png"), "eski v4 totem sayfası silinmiş olmalı")


## Derinlik (2026-11-11): taşın arkasındaki (yukarıdaki) karakter taşın ALTINDA kalır (totem z 2 > oyuncu z 1), önündeki/yanındaki karakterde
## totem z 0 (oyuncu üstte); totem yaratık/evcil ayak sıralamasına katılır.
func test_stone_draws_over_character_behind_it() -> void:
	for scene in [AttackTotemScene, ShieldTotemScene]:
		var totem: Node2D = _make_totem(scene, [])
		totem.global_position = Vector2(500.0, 500.0)
		assert(totem.is_in_group("ysort_props"), "totem y-sıralama grubunda olmalı")
		assert(totem.has_meta("_foot_visual") and is_equal_approx(float(totem.get_meta("_foot_local")), TotemBase.FOOT_Y), "ayak hizası totem kökü olmalı")
		var ch := FakeCaster.new()
		ch.add_to_group("player")
		add_child(ch)
		_spawned.append(ch)
		ch.global_position = Vector2(500.0, 500.0 - 20.0) ## ayağı taşın tepesinin altında, kökünün üstünde = ARKASINDA
		totem.call("_update_depth")
		assert(totem.z_index == TotemBase.DEPTH_FRONT_Z, "arkadaki karakterde totem üstte (z 2) olmalı, z=%d" % totem.z_index)
		ch.global_position = Vector2(500.0, 500.0 + 30.0) ## önünde
		totem.call("_update_depth")
		assert(totem.z_index == TotemBase.DEPTH_Z, "öndeki karakterde totem z 0 olmalı, z=%d" % totem.z_index)
		ch.global_position = Vector2(700.0, 480.0) ## yatayda uzak
		totem.call("_update_depth")
		assert(totem.z_index == TotemBase.DEPTH_Z, "uzaktaki karakter totemi yükseltmemeli")
		ch.remove_from_group("player")


## Gölge oyunun kendi nesne gölgesi (DropShadow - sandık/altın/mıknatıs), taşın alt kenarının hemen altında; eski dama gölge yok.
func test_uses_game_drop_shadow() -> void:
	for scene in [AttackTotemScene, ShieldTotemScene]:
		var totem: Node2D = _make_totem(scene, [])
		var sh: Node2D = totem.get_node_or_null("DropShadow") as Node2D
		assert(sh != null, "totemde DropShadow olmalı")
		assert(sh.get_script() == preload("res://scripts/drop_shadow.gd"), "gölge drop_shadow.gd olmalı")
		var spr: Sprite2D = _stone(totem)
		var used: Rect2i = spr.texture.get_image().get_used_rect()
		## Dinlenme konumu (dikilme animasyonu taşı başta PLANT_RISE_PIXELS aşağıdan getirir): sahnedeki değer.
		var rest: Node = (scene as PackedScene).instantiate()
		var rest_y: float = (rest.get_node("TotemSprite") as Node2D).position.y
		rest.free()
		var bottom: float = rest_y + (float(used.end.y) - 16.0) * spr.scale.y
		assert(absf(sh.position.y - bottom) < 0.6, "gölge taşın alt kenarında olmalı (%s / %s)" % [sh.position.y, bottom])
		assert(bottom > -1.0 and bottom < 3.0, "taşın alt kenarı düğüm kökünde (yer) olmalı: %s" % bottom)
	var src: String = FileAccess.get_file_as_string("res://scripts/totem_base.gd")
	assert(not src.contains("if ((ix + iy) & 1) == 0"), "eski dama (dither) gölge kalmamalı")
	assert(not src.contains("_draw_dotted_ring"), "noktalı halkalar (iç + menzil) kalmamalı")
	_cleanup()


## Kullanıcı: "dış halkaları kaldır, onları istemiyorum" - menzil halkası, halkada dönen rünler ve E'nin kalkan nabız halkası çizilmez.
func test_no_outer_rings() -> void:
	var base_src: String = FileAccess.get_file_as_string("res://scripts/totem_base.gd")
	assert(not base_src.contains("func _draw("), "totem tabanı yere halka/rün çizmemeli")
	assert(not base_src.contains("_draw_rune("), "menzil halkasında dönen rünler kalmamalı")
	var shield_src: String = FileAccess.get_file_as_string("res://scripts/totem_shield.gd")
	assert(not shield_src.contains("TotemShieldWave.spawn_pulse("), "E'nin kalkan nabız halkası çağrılmamalı")
	## Mor alan çemberi + tik nabız halkası da yok; alan hasarı açık.
	var totem: Node2D = _make_totem(ShieldTotemScene, [])
	assert(bool(totem.get("area_damage_enabled")) and not bool(totem.get("show_area_aura")), "E alan hasarı açık, çemberi kapalı")
	assert(totem.get_node_or_null("AreaAura") == null, "mor alan çemberi kurulmamalı")
	var before: int = totem.get_child_count()
	totem.call("_process_area_visuals", 0.01)
	assert(totem.get_child_count() == before, "tik nabız halkası doğmamalı")
	_cleanup()


## Rün sayfasının çekirdek sütunundaki çizgi piksellerinin (alfa 255) birleşik kutu merkezi, 32x32 karede.
func _rune_art_center(sheet: Texture2D) -> Vector2:
	var img: Image = sheet.get_image()
	if img.is_compressed():
		img.decompress()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for row in range(RuneStone.RUNE_ROWS):
		for y in range(32):
			for x in range(32):
				if img.get_pixel(x, row * 32 + y).a > 0.99:
					lo = Vector2(minf(lo.x, x), minf(lo.y, y))
					hi = Vector2(maxf(hi.x, x), maxf(hi.y, y))
	return (lo + hi) * 0.5 + Vector2(0.5, 0.5)


## "Ateş topları bu taştan atılacak" / "kalkan orbları bu taştan gönderilecek": çıkış noktası = taşın rün merkezi (1 birim tolerans),
## dikilme parlaması ve gece ışığı da aynı noktada.
func test_bolt_and_orb_leave_from_rune_center() -> void:
	var by_script: Dictionary = NightGlowCatalog.BY_SCRIPT
	for pair in [[AttackTotemScene, "BOLT_ORIGIN_OFFSET", "res://scripts/totem_attack.gd"], [ShieldTotemScene, "ORB_ORIGIN_OFFSET", "res://scripts/totem_shield.gd"]]:
		var inst: Node2D = (pair[0] as PackedScene).instantiate()
		var spr: Sprite2D = inst.get_node("TotemSprite")
		var art_c: Vector2 = _rune_art_center(spr.get("rune_sheet"))
		var expected: Vector2 = spr.position + (art_c - Vector2(16, 16)) * spr.scale
		var origin: Vector2 = (inst.get_script() as GDScript).get_script_constant_map()[pair[1]]
		assert(origin.distance_to(expected) <= 1.0, "%s %s rün merkezinde olmalı (beklenen %s)" % [pair[1], origin, expected])
		assert(Vector2(inst.get("rune_center")) == origin, "rune_center (dikilme parlaması) çıkışla aynı olmalı")
		assert(Vector2(by_script[pair[2]]["o"]) == origin, "gece ışığı 'o' rün merkezinde olmalı")
		inst.free()
	var shield_src: String = FileAccess.get_file_as_string("res://scripts/totem_shield.gd")
	assert(shield_src.contains("var src: Vector2 = global_position + ORB_ORIGIN_OFFSET"), "kalkan şeridi taştan çıkmalı (madde 567)")
	var attack_src: String = FileAccess.get_file_as_string("res://scripts/totem_attack.gd")
	assert(attack_src.count("TotemFireBolt.spawn(get_tree().current_scene, global_position + BOLT_ORIGIN_OFFSET") == 2, "gerçek ve ağ kopyası atışı taştan çıkmalı")


func test_rune_rows_follow_owned_evolutions() -> void:
	var q: Node2D = _make_totem(AttackTotemScene, [])
	assert(_stone(q).call("rune_rows") == [0], "evrimsiz: yalnız evrimsiz rün")
	var q2: Node2D = _make_totem(AttackTotemScene, ["shaman_qf", "shaman_q3", "shaman_e1"])
	assert(_stone(q2).call("rune_rows") == [0, 3, 5], "Q: evrimsiz + Çabuk Totem + final (E evrimi Q taşına girmez)")
	var e: Node2D = _make_totem(ShieldTotemScene, ["shaman_e1", "shaman_e2", "shaman_e3", "shaman_e4", "shaman_ef", "shaman_q1"])
	assert(_stone(e).call("rune_rows") == [0, 1, 3, 2, 4, 5], "E: tüm evrimler kart sırasıyla")
	## Her evrimin kendi, birbirinden farklı rünü var (final hep son satır).
	for k in ["q", "e"]:
		var seen: Dictionary = {}
		for evo_id: String in RuneStone.EVO_ORDER[k]:
			var row: int = int(RuneStone.EVO_ROW[evo_id])
			assert(row >= 1 and row < RuneStone.RUNE_ROWS and not seen.has(row), "%s farklı bir rün satırı almalı" % evo_id)
			seen[row] = true
		assert(int(RuneStone.EVO_ROW[RuneStone.EVO_ORDER[k][4]]) == 5, "final evrimi final rününü göstermeli")
	_cleanup()


## Görünen rün yuvaları: [satır, çekirdek alfası, hale alfası].
func _visible(stone: Node) -> Array:
	var out: Array = []
	for i in range(2):
		var s: Sprite2D = stone.get_node("Rune%d" % i)
		if s.visible:
			var h: Sprite2D = s.get_node("Halo")
			assert(s.frame % RuneStone.COLS == 0 and h.frame == s.frame + 1, "çekirdek sütun 0, hale aynı satırın sütun 1'i")
			out.append([s.frame / RuneStone.COLS, s.modulate.a, h.modulate.a])
	return out


## Madde 569 (prototip madde 568 A - Parlayan Oyma): rünler taşta SIRAYLA akkor yanar, en çok ikisi üst üste (çapraz geçiş), alfa kare
## kare sıçramaz; taş parıltısı rünle güçlenir; kıvılcımlar çizilir.
func test_runes_glow_in_turn() -> void:
	var totem: Node2D = _make_totem(AttackTotemScene, ["shaman_q1", "shaman_q2"])
	var stone: Node = _stone(totem)
	var glow: Sprite2D = stone.get_node("StoneGlow")
	var peaks: Array = []
	var prev: Dictionary = {}
	var max_glow: float = 0.0
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	while t < RuneStone.PERIOD * 6.0:
		stone.call("advance", dt)
		t += dt
		var vis: Array = _visible(stone)
		assert(vis.size() <= 2, "en çok iki rün üst üste (biri sönerken diğeri belirir)")
		var now: Dictionary = {}
		for v in vis:
			var row: int = int(v[0])
			now[row] = v
			if is_equal_approx(float(v[1]), 1.0) and (peaks.is_empty() or peaks[-1] != row):
				peaks.append(row)
			if prev.has(row):
				assert(absf(float(v[1]) - float(prev[row][1])) < 0.08, "rün alfası sıçramamalı")
				assert(absf(float(v[2]) - float(prev[row][2])) < 0.08, "hale sıçramamalı")
		prev = now
		max_glow = maxf(max_glow, glow.modulate.a)
	assert(peaks.slice(0, 6) == [0, 4, 1, 0, 4, 1], "rünler sırayla akkor olmalı: evrimsiz, Üçüncü Totem, Alev Dokunuşu ... (bulunan %s)" % [peaks])
	assert(max_glow >= 0.6, "taşın dış parıltısı rün yanarken güçlü olmalı (%s)" % max_glow)
	assert(stone.get_node_or_null("Sparks") != null, "kıvılcım katmanı olmalı")
	_cleanup()


## Kullanıcı: "rün taşı uçuyormuş gibi görünmüyor, yukarı aşağı süzülmüyor" -> taş yerden yukarıda tam piksel adımlarla salınır,
## rünler + parıltı taşla birlikte hareket eder, çıkış noktaları da.
func test_stone_floats_up_and_down() -> void:
	var totem: Node2D = _make_totem(ShieldTotemScene, [])
	var stone: Sprite2D = _stone(totem)
	var seen: Dictionary = {}
	var t: float = 0.0
	while t < RuneStone.BOB_PERIOD:
		stone.call("advance", 0.05)
		t += 0.05
		var off: float = stone.offset.y
		assert(is_equal_approx(off, roundf(off)), "süzülme tam taş pikseli adımlarla")
		var hw: float = float(stone.call("hover_world"))
		assert(hw <= -(RuneStone.HOVER_LIFT - RuneStone.BOB_AMP) + 0.4 and hw >= -(RuneStone.HOVER_LIFT + RuneStone.BOB_AMP) - 0.4, "taş yerden yukarıda (%s)" % hw)
		assert((stone.get_node("Rune0") as Node2D).position.y == off, "rün taşla birlikte")
		assert((stone.get_node("StoneGlow") as Node2D).position.y == off, "parıltı taşla birlikte")
		assert(is_equal_approx(Vector2(totem.call("_stone_hover")).y, hw), "çıkış noktaları taşla birlikte kayar")
		seen[off] = true
	assert(seen.size() >= 3, "taş yukarı aşağı salınmalı (görülen %s)" % [seen.keys()])
	_cleanup()


func test_single_rune_stays_lit_and_new_evolution_joins() -> void:
	var totem: Node2D = _make_totem(ShieldTotemScene, [])
	var stone: Node = _stone(totem)
	var t: float = 0.0
	while t < 4.0:
		stone.call("advance", 0.05)
		t += 0.05
		if t > RuneStone.T_IN + 0.05:
			var vis: Array = _visible(stone)
			assert(vis.size() == 1 and int(vis[0][0]) == 0 and is_equal_approx(float(vis[0][1]), 1.0), "evrim yokken evrimsiz rün hep yanmalı")
	(totem.get("caster") as FakeCaster).evos["shaman_e3"] = true
	var seen_new: bool = false
	t = 0.0
	while t < RuneStone.PERIOD * 3.0:
		stone.call("advance", 0.05)
		t += 0.05
		for v in _visible(stone):
			if int(v[0]) == 2:
				seen_new = true
	assert(seen_new, "yeni evrimin rünü (Yapışkan Zemin = satır 2) döngüye girmeli")
	_cleanup()


## Atışta taş hedefin tersine 1 taş pikseli geri teper ve kısa sürede yerine döner (madde 570).
func test_stone_kicks_back_on_fire() -> void:
	var totem: Node2D = _make_totem(AttackTotemScene, [])
	var stone: Sprite2D = _stone(totem)
	stone.call("advance", 0.01)
	var rest: Vector2 = stone.offset
	stone.call("kick", Vector2(-50, 0)) ## hedef solda
	stone.call("advance", 0.01)
	assert(stone.offset.x == rest.x + RuneStone.KICK_PX, "taş sağa (hedefin tersine) geri tepmeli (%s -> %s)" % [rest, stone.offset])
	for i in range(10):
		stone.call("advance", 0.02)
	assert(stone.offset.x == rest.x, "geri tepme kısa sürede biter")
	_cleanup()


## Atışta taş parlar (gerçek totem + ağ kopyası aynı kancayı çağırır) ve yumuşakça söner.
func test_flare_brightens_glow() -> void:
	var totem: Node2D = _make_totem(AttackTotemScene, [])
	var stone: Node = _stone(totem)
	for i in range(20):
		stone.call("advance", 0.05)
	var glow: Sprite2D = stone.get_node("StoneGlow")
	var before: float = glow.modulate.a
	totem.call("_flare_stone")
	stone.call("advance", 0.01)
	assert(glow.modulate.a > before + 0.1, "atışta taş parıltısı artmalı (%s -> %s)" % [before, glow.modulate.a])
	for i in range(20):
		stone.call("advance", 0.05)
	assert(glow.modulate.a < before + 0.1, "parlama sönmeli")
	_cleanup()
