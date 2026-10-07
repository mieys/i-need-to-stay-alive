extends Node

## Kullanıcı isteği (2026-10-05): boss'un can/kalkanı ekranın üst ortasında kendi barında (T1 Ahşap Plaket), boss'un üstünde sadece
## kafatası işareti. scripts/boss_bar_top.gd, boss_skull_marker.gd, boss_bar_art.gd, enemy.gd get_boss_marker_offset.

const BarScript: GDScript = preload("res://scripts/boss_bar_top.gd")
const ArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")

const BOSS_IDS := ["iskelet3", "lich3", "ork3", "agac3", "golem3", "rontgen2", "rontgen3", "demon3", "hayalet3", "mantar3", "rat3",
		"vampire3", "zombie3", "iblis3"]


## Boss taklidi: bar sadece bu alanları okuyor.
class FakeBoss extends Node2D:
	var is_dead: bool = false
	var health: float = 100.0
	var max_health: float = 100.0
	var item_shield_hp: float = 50.0
	var item_shield_max: float = 100.0


var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()


func _bar() -> Control:
	var c := Control.new()
	c.set_script(BarScript)
	add_child(c)
	_made.append(c)
	return c


func _boss(id: String, pos: Vector2, hp: float = 100.0, sh: float = 50.0) -> FakeBoss:
	var b := FakeBoss.new()
	b.health = hp
	b.item_shield_hp = sh
	b.set_meta("creature_id", id)
	b.add_to_group("boss")
	add_child(b)
	b.global_position = pos
	_made.append(b)
	return b


# ---------------------------------------------------------------- saf seçim kuralı
func _items(dists: Array) -> Array:
	var out: Array = []
	for i in range(dists.size()):
		out.append({"id": i + 1, "dist": float(dists[i])})
	return out


func test_nearest_boss_is_the_main_one_and_the_rest_follow_by_distance() -> void:
	assert(BarScript.order_bosses(_items([900, 300, 600]), 0) == [2, 3, 1], "en yakın ana, kalanlar yakından uzağa")
	assert(BarScript.order_bosses([], 0).is_empty(), "boss yoksa boş")
	assert(BarScript.order_bosses(_items([500]), 7) == [1], "tek boss")


func test_main_boss_keeps_focus_until_another_is_clearly_closer() -> void:
	## 1. boss ana; 2. boss biraz daha yakın -> ana el değiştirmemeli (histerezis)
	assert(BarScript.order_bosses(_items([500, 450]), 1)[0] == 1, "az farkla el değiştirmemeli")
	## 2. boss ÇOK daha yakın -> el değiştirir
	assert(BarScript.order_bosses(_items([1500, 100]), 1)[0] == 2, "belirgin yakınlıkta ana boss değişmeli")
	## eski ana boss artık yok (öldü) -> en yakın
	assert(BarScript.order_bosses(_items([800, 200]), 99)[0] == 2, "eski ana boss listede yoksa en yakın")


func test_ties_are_stable() -> void:
	assert(BarScript.order_bosses(_items([300, 300, 300]), 0) == [1, 2, 3], "eşit mesafede kimlik sırası (titremesin)")


# ---------------------------------------------------------------- isimler
func test_every_boss_family_has_a_display_name() -> void:
	for id in BOSS_IDS:
		var n: String = ArtScript.display_name(id)
		assert(n != "" and n == n.to_upper(), "'%s' için büyük harfli bir ad olmalı: '%s'" % [id, n])
	assert(ArtScript.display_name("agac3") == "AĞAÇ" and ArtScript.display_name("golem3") == "GOLEM")
	assert(ArtScript.display_name("bilinmeyen9") == "BİLİNMEYEN" or ArtScript.display_name("bilinmeyen9") == "BILINMEYEN",
			"tabloda olmayan aile kendi adıyla (büyük harf) gösterilmeli")
	for id in SpawnerScript.FINAL_CREATURES:
		assert(ArtScript.display_name(id) != "", "Final bossu adsız: %s" % id)


# ---------------------------------------------------------------- kafa konumu
func test_head_top_is_measured_from_the_real_boss_sprites() -> void:
	for id in BOSS_IDS:
		var scene: PackedScene = SpawnerScript.SCENES.get(id)
		assert(scene != null, "sahne yok: %s" % id)
		var e: Node = scene.instantiate()
		add_child(e)
		var head: Variant = ArtScript.head_top_local(e.get("frame_sprite"))
		assert(head != null, "%s için kafa konumu ölçülemedi (doku okunamadı?)" % id)
		assert(float(head) < 0.0, "%s: kafa kökün üstünde olmalı (y<0): %s" % [id, str(head)])
		assert(float(head) > -400.0, "%s: kafa konumu saçma: %s" % [id, str(head)])
		var marker_top: float = e.call("get_boss_marker_offset")
		assert(is_equal_approx(marker_top, float(head) - ArtScript.PLATE_GAP - ArtScript.PLATE_SIZE),
				"%s: plaka kafanın PLATE_GAP üstünde olmalı" % id)
		e.free()


func test_head_is_closer_than_the_old_formula_on_the_golem() -> void:
	var e: Node = (SpawnerScript.SCENES.get("golem3") as PackedScene).instantiate()
	add_child(e)
	var old: float = e.call("get_overhead_bar_offset")
	var head: float = float(ArtScript.head_top_local(e.get("frame_sprite")))
	assert(head > old, "golemde eski formül kafadan çok yukarıdaydı: yeni kafa %s, eski çubuk %s" % [str(head), str(old)])
	e.free()


func test_head_top_follows_the_current_sprite_frame() -> void:
	var e: Node = (SpawnerScript.SCENES.get("golem3") as PackedScene).instantiate()
	add_child(e)
	var spr: Sprite2D = e.get("frame_sprite")
	var seen := {}
	for f in range(spr.hframes * spr.vframes):
		spr.frame = f
		seen[snappedf(float(ArtScript.head_top_local(spr)), 0.01)] = true
	assert(seen.size() >= 3, "golemde kareler arasında kafa yüksekliği değişir, ölçüm kare başına olmalı: %d farklı değer" % seen.size())
	e.free()


func test_marker_glides_with_the_head_and_hides_when_the_boss_dies() -> void:
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	_made.append(sp)
	get_tree().current_scene = self
	var boss: Node = sp.call("_spawn_creature", "golem3", Vector2.ZERO, 1)
	boss.call("apply_boss_stats", 1000.0, 10.0, 1.7, 12)
	boss.call("set_overhead_bar_always_visible")
	var bar: Node2D = boss.get("_overhead_bar")
	var spr: Sprite2D = boss.get("frame_sprite")
	## en alçak ve en yüksek kafalı iki kareyi bul
	var lo_f: int = 0
	var hi_f: int = 0
	var lo: float = INF
	var hi: float = -INF
	for f in range(spr.hframes * spr.vframes):
		spr.frame = f
		var h: float = float(ArtScript.head_top_local(spr))
		if h < lo:
			lo = h
			lo_f = f
		if h > hi:
			hi = h
			hi_f = f
	spr.frame = lo_f
	bar.call("set_offset", float(boss.call("get_boss_marker_offset")))
	var y_high: float = float(bar.get("y_offset"))
	spr.frame = hi_f
	bar.call("_process", 1.0) ## uzun kare: hedefe varır
	var y_low: float = float(bar.get("y_offset"))
	assert(y_low > y_high + 3.0, "kafa alçalınca işaret de inmeli: %s -> %s" % [str(y_high), str(y_low)])
	assert(is_equal_approx(y_low, roundf(float(boss.call("get_boss_marker_offset")))), "işaret hedefe oturmalı ve tam birimde olmalı")
	boss.set("is_dead", true)
	bar.call("_process", 0.016)
	assert(not bar.visible, "boss ölünce işaret gizlenmeli")
	boss.free()


func test_head_measurement_is_cached_per_sheet() -> void:
	var e1: Node = (SpawnerScript.SCENES.get("lich3") as PackedScene).instantiate()
	add_child(e1)
	var a: Variant = ArtScript.head_top_local(e1.get("frame_sprite"))
	var b: Variant = ArtScript.head_top_local(e1.get("frame_sprite"))
	assert(a == b, "aynı sayfa aynı sonucu vermeli")
	e1.free()


func test_boss_gets_the_skull_marker_instead_of_the_old_bar() -> void:
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	_made.append(sp)
	get_tree().current_scene = self
	var boss: Node = sp.call("_spawn_creature", "golem3", Vector2.ZERO, 1)
	boss.call("apply_boss_stats", 1000.0, 10.0, 1.7, 12)
	boss.call("set_overhead_bar_always_visible")
	var bar: Node = boss.get("_overhead_bar")
	assert(bar != null and bar.visible, "boss'un üstünde işaret görünür olmalı")
	assert(String(bar.get_script().resource_path).ends_with("boss_skull_marker.gd"), "eski can/kalkan çubuğu değil kafatası işareti: %s" % bar.get_script().resource_path)
	assert(is_equal_approx(float(bar.get("y_offset")), roundf(float(boss.call("get_boss_marker_offset")))), "işaret kafaya göre yerleşmeli (tam birime yuvarlı)")
	## eski çubuk arayüzü çökmeden çalışmalı (enemy.gd hasar alınca çağırıyor)
	boss.call("_show_overhead_bar")
	bar.call("set_health", 5.0, 10.0)
	bar.call("set_shield", 5.0, 10.0)
	boss.free()


# ---------------------------------------------------------------- arayüz
func test_bar_is_hidden_without_bosses_and_shows_name_when_one_appears() -> void:
	_cleanup()
	var bar: Control = _bar()
	bar.call("refresh")
	assert(not bar.visible and float(bar.call("get_bottom_y")) == 0.0, "boss yokken bar görünmemeli")
	_boss("golem3", Vector2(100, 0), 78.0, 40.0)
	bar.call("refresh")
	assert(bar.visible, "boss varken bar görünmeli")
	var entry: Dictionary = bar.get("_entry")
	assert(entry["name"] == "GOLEM", "ad GOLEM olmalı: %s" % str(entry))
	assert(is_equal_approx(float(entry["hp"]), 0.78) and is_equal_approx(float(entry["sh"]), 0.4), "can/kalkan oranı: %s" % str(entry))
	assert(float(bar.call("get_bottom_y")) > BarScript.TOP_Y, "bar alt kenarı üst kenarın altında olmalı")
	_cleanup()


func test_shield_ratio_is_zero_when_the_boss_has_no_shield_yet() -> void:
	_cleanup()
	var bar: Control = _bar()
	var b: FakeBoss = _boss("lich3", Vector2.ZERO)
	b.item_shield_max = 0.0
	b.item_shield_hp = 0.0
	bar.call("refresh")
	assert(is_equal_approx(float((bar.get("_entry") as Dictionary)["sh"]), 0.0), "kalkan maksı 0 iken oran 0 olmalı (0'a bölme yok)")
	_cleanup()


func test_dead_bosses_are_ignored_and_the_bar_fades_out() -> void:
	_cleanup()
	var bar: Control = _bar()
	var b: FakeBoss = _boss("ork3", Vector2.ZERO)
	bar.call("refresh")
	assert(bar.visible)
	b.is_dead = true
	bar.call("refresh")
	await get_tree().create_timer(0.5).timeout ## solma süresi
	assert(not bar.visible, "tüm bosslar ölünce bar kaybolmalı")
	assert(float(bar.call("get_bottom_y")) == 0.0)
	_cleanup()


func test_many_bosses_still_show_exactly_one_bar() -> void:
	_cleanup()
	var bar: Control = _bar()
	for i in range(13): ## Final Kademe: 13 boss birden
		_boss(BOSS_IDS[i % BOSS_IDS.size()], Vector2(100 * (i + 1), 0))
	bar.call("refresh")
	var entry: Dictionary = bar.get("_entry")
	assert(entry["name"] == ArtScript.display_name(BOSS_IDS[0]), "kamera merkezine en yakın boss gösterilmeli: %s" % str(entry))
	## TEK bar: sadece ana plaket kadar yer kaplar (küçük plaket / ek yazı yok)
	assert(is_equal_approx(bar.size.y, float(ArtScript.TOP_H) * bar.get("scale_px")), "bar tek plaket yüksekliğinde olmalı: %s" % str(bar.size))
	assert(bar.size.x <= 1920.0 and float(bar.call("get_bottom_y")) <= 220.0, "bar ekranda fazla yer kaplıyor: %s alt=%s" % [str(bar.size), str(bar.call("get_bottom_y"))])
	_cleanup()


func test_main_boss_does_not_flip_between_two_equally_close_bosses() -> void:
	_cleanup()
	var bar: Control = _bar()
	var a: FakeBoss = _boss("golem3", Vector2(400, 0))
	var b: FakeBoss = _boss("lich3", Vector2(420, 0))
	bar.call("refresh")
	var first: String = (bar.get("_entry") as Dictionary)["name"]
	for i in range(5): ## iki boss birbirine yaklaşıp uzaklaşıyor
		a.global_position = Vector2(400 + (10 if i % 2 == 0 else -10), 0)
		b.global_position = Vector2(420 + (-10 if i % 2 == 0 else 10), 0)
		bar.call("refresh")
		assert((bar.get("_entry") as Dictionary)["name"] == first, "bar titreyip el değiştirmemeli")
	_cleanup()


func test_drawing_runs_without_errors_for_all_layouts() -> void:
	_cleanup()
	var bar: Control = _bar()
	for n in [1, 2, 3, 6]:
		for c: Node in get_tree().get_nodes_in_group("boss"):
			c.free()
		for i in range(n):
			_boss(BOSS_IDS[i], Vector2(100 * (i + 1), 0), 30.0 + 10 * i, 0.0 if i == 1 else 80.0)
		bar.call("refresh")
		await get_tree().process_frame ## _draw bu karede çalışır (script hatası koşturucuda yakalanır)
	_cleanup()
