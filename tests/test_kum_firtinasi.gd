extends Node

## Madde 718: Altın Kumlar KUM FIRTINASI (scripts/kum_firtinasi.gd, weather_sandstorm.gd, atmosphere.gd sand_intensity). Çölde Sağanak yuvası
## kum fırtınasıdır (yağmur / sağanak / yıldırım yok); açık havadaki oyuncu şiddetle orantılı en fazla %20 yavaşlar, HUD'da rozet.

const Sand := preload("res://scripts/kum_firtinasi.gd")
const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const Badge := preload("res://scripts/status_effect_badge.gd")


class FakePlayer extends Node:
	var k: float = -1.0

	func set_kum_firtinasi(v: float) -> void:
		k = v


func test_move_mult_and_badge() -> void:
	assert(Sand.move_mult(0.0) == 1.0)
	assert(is_equal_approx(Sand.move_mult(0.5), 0.90), "yarım şiddet %10")
	assert(is_equal_approx(Sand.move_mult(1.0), 0.80), "tam fırtına %20")
	assert(is_equal_approx(Sand.move_mult(3.0), 0.80), "sınır")
	## %1 adımlı: fırtına gelirken çarpan her karede değişmez (move_speed paketi her karede gitmesin)
	assert(Sand.move_mult(0.501) == Sand.move_mult(0.5))
	assert(Sand.status_entry(0.0).is_empty() and Sand.status_entry(Sand.BADGE_FROM * 0.5).is_empty())
	var e: Dictionary = Sand.status_entry(0.6)
	assert(str(e.get("kind")) == "sandstorm" and not bool(e.get("is_buff")) and float(e.get("remaining")) < 0.0)
	assert(Badge.INFO.has("sandstorm"), "rozet açıklaması")
	assert(str(Badge.INFO["sandstorm"][1]).contains("%" + str(int(round(Sand.SLOW * 100.0)))), "açıklamadaki yüzde SLOW ile aynı")
	assert(ResourceLoader.exists("res://assets/ui/status/sandstorm.png"), "rozet ikonu")


func test_targets_and_wind_direction() -> void:
	var storm3: Vector3 = AtmosphereMath.weather_targets(AtmosphereMath.Weather.STORM)
	assert(Sand.targets(storm3, true, true) == Vector4(0.0, 1.0, 0.0, 1.0), "çölde sağanak = kum fırtınası, yağmur / yıldırım yok")
	assert(Sand.targets(storm3, true, false) == Vector4(1.0, 1.0, 1.0, 0.0), "diğer haritalarda sağanak aynen")
	var windy: Vector3 = AtmosphereMath.weather_targets(AtmosphereMath.Weather.WINDY)
	assert(Sand.targets(windy, false, true) == Vector4(0.0, 1.0, 0.0, 0.0), "çölde rüzgarlı havada kum fırtınası yok")
	assert(Sand.wind_sign(0.2) == 1.0 and Sand.wind_sign(PI - 0.2) == -1.0)
	assert(is_equal_approx(Sand.wind_slope(0.2), tan(0.2)) and is_equal_approx(Sand.wind_slope(PI - 0.2), tan(PI - 0.2)))


func test_profile_only_desert() -> void:
	if OS.get_environment("HARITA") != "":
		return
	var prev: String = str(GameManager.selected_map)
	for id: String in MapProfiles.ids():
		GameManager.selected_map = id
		assert(MapProfiles.sandstorm() == (id == "col"), "kum fırtınası yalnız Altın Kumlar'da: %s" % id)
	GameManager.selected_map = "col"
	assert(MapProfiles.map_weather(AtmosphereMath.Weather.STORM) == AtmosphereMath.Weather.STORM, "çölde sağanak yuvası açığa çevrilmez")
	GameManager.selected_map = prev


func test_atmosphere_drives_sand_layer_and_local_slow() -> void:
	if OS.get_environment("HARITA") != "":
		return
	var prev: String = str(GameManager.selected_map)
	GameManager.selected_map = "col"
	var fake := FakePlayer.new()
	fake.add_to_group("player")
	add_child(fake)
	var atm: Node2D = AtmosphereScript.new()
	add_child(atm)
	var layer: CanvasLayer = atm.create_sand_layer()
	assert(layer != null, "çölde kum katmanı kurulur")
	add_child(layer)
	atm.set_process(false)
	assert(atm.debug_set_weather(AtmosphereMath.Weather.STORM))
	for i in 30:
		atm._process(0.5)
	assert(is_equal_approx(float(atm.sand_intensity), 1.0), "9 sn'de tam şiddet")
	assert(float(atm.rain_intensity) == 0.0 and float(atm.storm_intensity) == 0.0, "yağmur / sağanak (yıldırım) yok")
	assert(is_equal_approx(fake.k, 1.0), "yerel oyuncuya şiddet yazılır")
	assert((layer.get_node("Kum") as CanvasItem).visible, "ekran katmanı görünür")
	assert(str(atm.debug_describe()).contains("Kum Fırtınası"))
	## ağ: istemci host'un şiddetini durumla alır
	assert(atm._state().has("ki"))
	atm.debug_set_weather(AtmosphereMath.Weather.CLEAR)
	for i in 30:
		atm._process(0.5)
	assert(float(atm.sand_intensity) == 0.0 and fake.k == 0.0, "fırtına diner, yavaşlama kalkar")
	assert(not (layer.get_node("Kum") as CanvasItem).visible, "şiddet 0 iken katman gizli (sıfır maliyet)")
	layer.queue_free()
	atm.queue_free()
	fake.queue_free()
	GameManager.selected_map = "ana"
	var atm2: Node2D = AtmosphereScript.new()
	add_child(atm2)
	assert(atm2.create_sand_layer() == null, "ana haritada kum katmanı yok")
	atm2.queue_free()
	GameManager.selected_map = prev


func test_player_speed_and_status() -> void:
	var player: Node2D = (preload("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var full: float = player.get_effective_move_speed()
	player.set_kum_firtinasi(1.0)
	assert(is_equal_approx(player.get_effective_move_speed(), full * 0.80), "tam fırtınada toplam hız x0,80")
	var kinds: Array = []
	for s: Dictionary in player.get_status_effects():
		kinds.append(s["kind"])
	assert(kinds.has("sandstorm"), "HUD durum satırında kum fırtınası rozeti")
	player.set_kum_firtinasi(0.0)
	assert(is_equal_approx(player.get_effective_move_speed(), full), "fırtına dinince hız geri gelir")
	player.queue_free()
