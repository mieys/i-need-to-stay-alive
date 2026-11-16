extends Node

## Madde 709: Ayaz Dağı üşüme / ısınma / donma (scripts/kis_soguk.gd). Ateşten 120 sn uzak kalan donmaya başlar (kullanıcı: "2 dakikada 1
## ısınması gerekecek"), ateş başında birkaç saniyede ısınır; hız kaybı üşürken en çok %10, donarken %30. Yalnız Ayaz Dağı profilinde kurulur.

const Cold := preload("res://scripts/kis_soguk.gd")
const KisMeta := preload("res://scripts/kis_meta.gd")
const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const Badge := preload("res://scripts/status_effect_badge.gd")


func _run(cold: float, seconds: float, warm: bool, dt: float = 1.0 / 60.0) -> float:
	var t := 0.0
	while t < seconds - 0.0001:
		cold = Cold.step(cold, dt, warm)
		t += dt
	return cold


func test_two_minutes_until_freezing_and_quick_warmup() -> void:
	assert(is_equal_approx(Cold.FREEZE_AT, 120.0), "donma 2 dakikada başlar")
	var c: float = _run(0.0, 119.0, false)
	assert(not Cold.is_freezing(c), "119 sn: henüz donmuyor (%.2f)" % c)
	c = _run(c, 1.5, false)
	assert(Cold.is_freezing(c), "120 sn sonra donma başlar")
	c = _run(c, 600.0, false, 0.5)
	assert(is_equal_approx(c, Cold.MAX_COLD), "soğuk sınırsız birikmez")
	## ateş başında: en ağır donmadan 5 sn içinde, donma eşiğinden 4 sn içinde tamamen ısınır
	assert(_run(Cold.MAX_COLD, 5.05, true) == 0.0, "en ağır donmadan ~5 sn'de ısınır")
	assert(_run(Cold.FREEZE_AT, 4.05, true) == 0.0, "donma eşiğinden ~4 sn'de ısınır")
	assert(_run(Cold.FREEZE_AT, 2.0, true) > 0.0, "ısınma anlık değil")


func test_move_mult_curve() -> void:
	assert(Cold.move_mult(0.0) == 1.0)
	assert(is_equal_approx(Cold.move_mult(60.0), 0.95), "üşümenin ortası %5")
	assert(is_equal_approx(Cold.move_mult(Cold.FREEZE_AT - 0.01), 0.90), "üşüme sonu %10")
	assert(is_equal_approx(Cold.move_mult(Cold.FREEZE_AT + Cold.FREEZE_FULL * 0.5), 0.80), "donma ortası %20")
	assert(is_equal_approx(Cold.move_mult(Cold.MAX_COLD), 0.70), "en ağır donma %30")
	## %1 adımlı: üşürken çarpan her karede değişmez (move_speed paketi her karede gitmesin)
	var seen: Dictionary = {}
	var c := 0.0
	while c <= Cold.FREEZE_AT:
		seen[snappedf(Cold.move_mult(c), 0.0001)] = true
		c += 1.0 / 60.0
	assert(seen.size() <= 11, "üşüme boyunca en çok 11 farklı çarpan: %d" % seen.size())
	var prev := 1.0
	c = 0.0
	while c <= Cold.MAX_COLD:
		var m: float = Cold.move_mult(c)
		assert(m <= prev + 0.0001, "soğudukça hız artmaz (%.1f sn)" % c)
		prev = m
		c += 0.25


func test_warmth_ratio_tint_and_badge() -> void:
	assert(Cold.warmth_ratio(0.0) == 1.0 and Cold.warmth_ratio(Cold.FREEZE_AT) == 0.0 and Cold.warmth_ratio(Cold.MAX_COLD) == 0.0)
	assert(Cold.tint(0.0) == Color.WHITE and Cold.tint(Cold.TINT_FROM) == Color.WHITE, "ateşten ayrılır ayrılmaz mavileşmez")
	assert(Cold.tint(Cold.FREEZE_AT).is_equal_approx(Cold.TINT_CHILL))
	assert(Cold.tint(Cold.MAX_COLD).is_equal_approx(Cold.TINT_FREEZE))
	assert(Cold.TINT_FREEZE.b >= Cold.TINT_FREEZE.r, "ton buz mavisi")
	assert(Cold.status_entry(0.0).is_empty(), "sıcakken rozet yok")
	var e: Dictionary = Cold.status_entry(30.0)
	assert(e["kind"] == "cold" and is_equal_approx(float(e["remaining"]), 90.0), "üşürken donmaya kalan süre: %s" % str(e))
	e = Cold.status_entry(Cold.FREEZE_AT + 1.0)
	assert(e["kind"] == "freeze" and float(e["remaining"]) < 0.0, "donarken süresiz rozet")
	for kind: String in ["cold", "freeze"]:
		assert(Badge.INFO.has(kind), "rozet açıklaması: " + kind)
		assert(load(Badge.ICON_DIR + kind + ".png") is Texture2D, "rozet ikonu: " + kind)


func test_heat_sources_and_profile() -> void:
	var sources: Array = []
	for h: Array in KisMeta.HEAT_SOURCES:
		sources.append([h[1], float(h[2]) * float(h[2])])
	assert(Cold.is_warm_at(KisMeta.SPAWN, sources), "doğuş noktası Ocak Başı ateşinin yanında")
	assert(not Cold.is_warm_at(Vector2(2600.0, 2600.0), sources), "harita ortası soğuk")
	## feature() tanımsız bayrağı ana haritada AÇIK sayar - üşüme ayrı anahtarda (cold_climate), ana harita dahil hiçbir yerde sızmamalı
	if OS.get_environment("HARITA") != "":
		return
	var keep: String = GameManager.selected_map
	for id: String in MapProfiles.PROFILES:
		GameManager.selected_map = id
		assert(MapProfiles.cold_climate() == (id == "kis"), "üşüme yalnız Ayaz Dağı'nda: " + id)
	GameManager.selected_map = keep


func test_player_cold_speed_tint_bar_and_driver() -> void:
	var player: Node2D = (preload("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(5000.0, 5000.0)
	var full: float = player.get_effective_move_speed()
	player.set_kis_cold(Cold.FREEZE_AT)
	assert(is_equal_approx(player.get_effective_move_speed(), full * 0.90), "donma eşiğinde toplam hız x0,90")
	var sm: Color = (player.anim as CanvasItem).self_modulate
	assert(Color(sm.r, sm.g, sm.b).is_equal_approx(Cold.TINT_CHILL), "sprite tonu")
	assert(player.overhead_bar.show_warmth and player.overhead_bar.warmth_frozen, "ısı çubuğu donmuş görünür")
	var kinds: Array = []
	for s: Dictionary in player.get_status_effects():
		kinds.append(s["kind"])
	assert(kinds.has("freeze"), "HUD durum satırında donma rozeti")
	## sürücü: ısı noktası uzağındaki oyuncu soğur, yanına gelince ısınır; ölüyken sıfırlanır
	var src := Node2D.new()
	src.add_to_group(Cold.HEAT_GROUP)
	src.set_meta("yaricap", 100.0)
	add_child(src)
	src.global_position = Vector2(0.0, 0.0)
	var drv: Node = Cold.new()
	add_child(drv)
	drv.set_process(false)
	player.set_kis_cold(0.0)
	drv._process(10.0)
	assert(is_equal_approx(player.kis_cold, 10.0), "ateşten uzakta soğur")
	player.global_position = Vector2(50.0, 0.0)
	drv._process(0.1)
	assert(player.kis_cold < 10.0, "ateş yanında ısınır")
	player.global_position = Vector2(5000.0, 5000.0)
	player.set_kis_cold(Cold.MAX_COLD)
	player.is_dead = true
	drv._process(0.1)
	assert(player.kis_cold == 0.0, "ölünce sıfırlanır")
	player.is_dead = false
	assert(is_equal_approx(player.get_effective_move_speed(), full), "sıcakken hız normal")
	sm = (player.anim as CanvasItem).self_modulate
	assert(Color(sm.r, sm.g, sm.b).is_equal_approx(Color.WHITE) and not player.overhead_bar.show_warmth, "ton + çubuk temizlenir")
	drv.free()
	src.free()
	player.free()
