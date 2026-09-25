extends Node

## Kullanıcı isteği doğrulaması (2026-09-25): gün-gece döngüsü + hava durumu (bkz. scripts/atmosphere_math.gd,
## scripts/atmosphere.gd, scripts/night_glow_catalog.gd).
##
## Doğrulananlar:
##  - 10 dk'lık döngü, koşu sabah başlar, gündüz tamamen aydınlık (renk ayarı birim -> ekran geçişi hiç çizilmez),
##  - kararma KADEMELİ: ikindi hafif, gün batımında tekdüze artan, gece tam, gün doğumunda tekdüze azalan; hiçbir
##    anda sıçrama yok (döngü sınırı 600=0 dahil),
##  - görüş yarıçapı gece tam %25 dar, gündüz aynen, arası karanlıkla orantılı,
##  - gece zifiri DEĞİL (ortam parlaklığı alt sınırın üstünde) ve mavi kanal en az kararıyor (ay ışığı),
##  - ışıklar gündüz görünmez (kazanç 0), gece görünür; yağmurlu gündüz hafif görünür,
##  - yağmur sahneyi karartıp soldurur, rüzgar neredeyse dokunmaz,
##  - hava seçimi %50/%25/%25 dağılım,
##  - ışık kataloğu: istenen silah mermileri/namlu ateşleri/asa uçları kayıtlı, kan/toz parlamıyor.

const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
const GlowCatalog := preload("res://scripts/night_glow_catalog.gd")


func test_cycle_is_ten_minutes_and_starts_in_daylight() -> void:
	assert(is_equal_approx(AtmosphereMath.CYCLE_LENGTH, 600.0))
	assert(AtmosphereMath.phase_name(AtmosphereMath.START_TIME) == "Gündüz")
	assert(AtmosphereMath.darkness(AtmosphereMath.START_TIME) == 0.0)


func test_full_day_is_untouched() -> void:
	var g: Dictionary = AtmosphereMath.grade(150.0, 0.0, 0.0)
	assert(AtmosphereMath.is_identity(g))
	assert(float(g["light_gain"]) < 0.001)
	assert(is_equal_approx(AtmosphereMath.vision_multiplier(150.0), 1.0))


func test_darkness_is_gradual_and_continuous() -> void:
	var prev: float = AtmosphereMath.darkness(0.0)
	var t: float = 0.5
	while t <= AtmosphereMath.CYCLE_LENGTH:
		var d: float = AtmosphereMath.darkness(t)
		## 0.5 sn'de en fazla küçük bir adım (sıçrama yok). En dik yer 60 sn'lik gün batımı: ~0.022/0.5sn.
		assert(absf(d - prev) < 0.03)
		prev = d
		t += 0.5
	## İkindi hafifçe başlar (gün batımından önce), gece tam karanlık.
	assert(AtmosphereMath.darkness(AtmosphereMath.DAY_END - 10.0) > 0.0)
	assert(AtmosphereMath.darkness(AtmosphereMath.DAY_END - 10.0) < 0.2)
	assert(is_equal_approx(AtmosphereMath.darkness(450.0), 1.0))


func test_darkness_monotonic_through_dusk_and_dawn() -> void:
	var prev: float = -1.0
	var t: float = AtmosphereMath.DAY_END - AtmosphereMath.AFTERNOON_LEAD
	while t <= AtmosphereMath.DUSK_END:
		var d: float = AtmosphereMath.darkness(t)
		assert(d >= prev - 0.0001)
		prev = d
		t += 1.0
	prev = 2.0
	t = AtmosphereMath.NIGHT_END
	while t < AtmosphereMath.CYCLE_LENGTH:
		var d2: float = AtmosphereMath.darkness(t)
		assert(d2 <= prev + 0.0001)
		prev = d2
		t += 1.0


func test_night_vision_is_25_percent_narrower() -> void:
	assert(is_equal_approx(AtmosphereMath.vision_multiplier(450.0), 0.75))
	var dusk_mid: float = AtmosphereMath.vision_multiplier((AtmosphereMath.DAY_END + AtmosphereMath.DUSK_END) * 0.5)
	assert(dusk_mid < 1.0 and dusk_mid > 0.75)


func test_night_is_dark_blue_but_not_pitch_black() -> void:
	var g: Dictionary = AtmosphereMath.grade(465.0, 0.0, 0.0)
	var a: Color = g["ambient"]
	assert(AtmosphereMath.luminance(a) > 0.35)
	assert(AtmosphereMath.luminance(a) < 0.55)
	assert(a.b > a.g and a.g > a.r)
	assert(float(g["light_gain"]) > 0.7)
	assert(float(g["glow_gain"]) > 0.2)


## Kullanıcı geri bildirimi (2026-09-25): "gecenin karanlığını %20 azalt, parıltıları %20 azalt, karakterden çıkan
## parıltı sırıtmasın".
func test_night_darkness_and_glow_are_twenty_percent_lower() -> void:
	var raw: Color = AtmosphereMath.raw_time_grade(465.0)[0]
	var scaled: Color = AtmosphereMath.time_grade(465.0)[0]
	assert(is_equal_approx(1.0 - scaled.r, (1.0 - raw.r) * 0.8))
	assert(is_equal_approx(1.0 - scaled.b, (1.0 - raw.b) * 0.8))
	var g: Dictionary = AtmosphereMath.grade(465.0, 0.0, 0.0)
	var raw_gain: float = clampf((1.0 - AtmosphereMath.luminance(raw)) * AtmosphereMath.LIGHT_GAIN_SCALE, 0.0, 1.0)
	assert(is_equal_approx(float(g["light_gain"]), raw_gain * 0.8))
	## Karakter ışığı en karanlık anda bile parıltı (bloom) eşiğinin (shader bloom_threshold 0.2) altında kalır.
	var overlay_script: GDScript = load("res://scripts/atmosphere_overlay.gd")
	assert(float(overlay_script.PLAYER_LIGHT_ENERGY) * float(g["light_gain"]) < 0.2)


func test_sunset_is_warm_and_sunrise_is_pink() -> void:
	var sunset: Color = AtmosphereMath.grade(360.0, 0.0, 0.0)["ambient"]
	assert(sunset.r > sunset.g and sunset.g > sunset.b)
	var sunrise: Color = AtmosphereMath.grade(570.0, 0.0, 0.0)["ambient"]
	assert(sunrise.r > sunrise.b and sunrise.b > sunrise.g * 0.95)


func test_rain_dims_and_desaturates_wind_barely_changes() -> void:
	var clear: Dictionary = AtmosphereMath.grade(150.0, 0.0, 0.0)
	var rainy: Dictionary = AtmosphereMath.grade(150.0, 1.0, 0.0)
	var windy: Dictionary = AtmosphereMath.grade(150.0, 0.0, 1.0)
	assert(AtmosphereMath.luminance(rainy["ambient"]) < AtmosphereMath.luminance(clear["ambient"]) - 0.1)
	assert(float(rainy["saturation"]) < 0.85)
	assert(float(rainy["light_gain"]) > 0.1) ## yağmurlu gündüz ışıklar hafifçe görünür
	assert(absf(AtmosphereMath.luminance(windy["ambient"]) - 1.0) < 0.03)


func test_weather_pick_distribution() -> void:
	## 2026-09-25: Sağanak eklendi - 45/20/20/15.
	var counts := [0, 0, 0, 0]
	for i in range(1000):
		counts[AtmosphereMath.pick_weather((float(i) + 0.5) / 1000.0)] += 1
	assert(counts[AtmosphereMath.Weather.CLEAR] == 450)
	assert(counts[AtmosphereMath.Weather.WINDY] == 200)
	assert(counts[AtmosphereMath.Weather.RAINY] == 200)
	assert(counts[AtmosphereMath.Weather.STORM] == 150)


func test_storm_grade_darker_than_rain_and_flash_brightens() -> void:
	var rainy: Dictionary = AtmosphereMath.grade(150.0, 1.0, 0.0)
	var storm: Dictionary = AtmosphereMath.grade(150.0, 1.0, 1.0, 1.0)
	assert(AtmosphereMath.luminance(storm["ambient"]) < AtmosphereMath.luminance(rainy["ambient"]) - 0.1, "Sağanak yağmurdan koyu olmalı")
	var flash: Dictionary = AtmosphereMath.grade(465.0, 1.0, 1.0, 1.0, 1.0)
	assert(AtmosphereMath.luminance(flash["ambient"]) > 1.1, "Yıldırım flaşı gece bile ekranı aydınlatmalı")
	var t: Vector3 = AtmosphereMath.weather_targets(AtmosphereMath.Weather.STORM)
	assert(t == Vector3(1.0, 1.0, 1.0), "Sağanak = yağmur + rüzgar + fırtına tam şiddet")


func test_glow_catalog_covers_requested_weapons() -> void:
	for path in ["res://scenes/fire_projectile.tscn", "res://scenes/ice_bolt_projectile.tscn", "res://scenes/tabanca_projectile.tscn",
			"res://scenes/tufek_projectile.tscn", "res://scenes/firework_projectile.tscn", "res://scenes/fx_revolver_muzzle.tscn",
			"res://scenes/fx_tufek_muzzle.tscn", "res://scenes/fx_lightning_beam.tscn"]:
		assert(GlowCatalog.BY_SCENE.has(path))
		assert(ResourceLoader.exists(path))
	for path in ["res://scenes/weapon_fire.tscn", "res://scenes/weapon_buz_asasi.tscn", "res://scenes/weapon_lightning.tscn", "res://scenes/weapon_fisek.tscn"]:
		assert(GlowCatalog.WEAPON_TIPS.has(path))
		assert(ResourceLoader.exists(path))
	## Namlu ateşi kısa bir flaş.
	assert(float(GlowCatalog.BY_SCENE["res://scenes/fx_revolver_muzzle.tscn"]["d"]) > 0.0)
	## Kataloğa yazılmış her sahne/script gerçekten var (yeniden adlandırılınca ışık sessizce kaybolmasın).
	for path in GlowCatalog.BY_SCENE.keys():
		assert(ResourceLoader.exists(path))
	for path in GlowCatalog.BY_SCRIPT.keys():
		assert(ResourceLoader.exists(path))


func test_blood_and_dust_do_not_glow() -> void:
	var blood := AnimatedSprite2D.new()
	blood.scene_file_path = "res://scenes/fx_hit_blood_1.tscn"
	assert(GlowCatalog.profile_for(blood).is_empty())
	var unknown_fx := Node2D.new()
	unknown_fx.scene_file_path = "res://scenes/fx_brand_new_effect.tscn"
	assert(not GlowCatalog.profile_for(unknown_fx).is_empty()) ## yeni efekt varsayılan hafif parıltı alır
	blood.free()
	unknown_fx.free()
