extends RefCounted

## ALTIN KUMLAR KUM FIRTINASI - oyun kuralı (madde 718; kullanıcı 2026-11-15: "çölde rasgele zamanlarda kum fırtınası olsun ve bu fırtına
## karakterleri yavaşlatsın"; görünüm onayı "Yeni 2 - kum yılanları"). Çölde hava seçimindeki Sağanak yuvası (AtmosphereMath.Weather.STORM,
## %15, 90-180 sn) kum fırtınasıdır: yağmur / yıldırım yok, rüzgar tam, atmosphere.gd sand_intensity 0 -> 1 (WEATHER_FADE_TIME 9 sn) yürür.
## Görsel: weather_sandstorm.gd + scenes/kum_firtinasi.gdshader. Saati / havayı host seçer (atmosphere.gd ağ deseni), şiddet her istemcide yerel.
##
## Yavaşlama: AÇIK HAVADAKİ yerel oyuncu (ev içi / zindan sığınak) şiddetle orantılı en fazla SLOW (%20) yavaşlar. atmosphere.gd her karede
## player.set_kum_firtinasi(k) yazar; hız çarpanı %1 adımlı -> uzak ekranlara main.gd extra["move_speed"] ile zaten gider (ayrı paket yok).
## Yaratıklar yavaşlamaz. Sayılar status_effect_badge.gd INFO["sandstorm"] metniyle aynı tutulmalı.

const SLOW := 0.20       ## tam fırtınada hız kaybı
const SLOW_STEP := 0.01  ## çarpan bu adımla yuvarlanır (move_speed paketi her karede değişmesin)
const BADGE_FROM := 0.05 ## HUD rozeti fırtına bu şiddeti geçince görünür


## k = açık havadaki fırtına şiddeti (0..1).
static func move_mult(k: float) -> float:
	return 1.0 - snappedf(SLOW * clampf(k, 0.0, 1.0), SLOW_STEP)


## HUD durum satırı (player.gd get_status_effects): fırtına sürdükçe süresiz rozet.
static func status_entry(k: float) -> Dictionary:
	if k < BADGE_FROM:
		return {}
	return {"id": "kum_firtinasi", "kind": "sandstorm", "is_buff": false, "stacks": 0, "remaining": -1.0, "duration": -1.0}


## Hava türü + harita -> [yağmur, rüzgar, sağanak, kum] hedef şiddetleri. Kum fırtınalı haritada (Altın Kumlar) Sağanak = kum fırtınası.
static func targets(weather_targets: Vector3, is_storm: bool, sandstorm_map: bool) -> Vector4:
	if sandstorm_map and is_storm:
		return Vector4(0.0, 1.0, 0.0, 1.0)
	return Vector4(weather_targets.x, weather_targets.y, weather_targets.z, 0.0)


## Rüzgar açısı -> shader eğimi / yönü (çizgiler rüzgar akıntılarıyla aynı yöne aksın).
static func wind_slope(angle: float) -> float:
	return clampf(tan(angle), -0.4, 0.4)


static func wind_sign(angle: float) -> float:
	return 1.0 if cos(angle) >= 0.0 else -1.0
