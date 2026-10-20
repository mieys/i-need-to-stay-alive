extends RefCounted
## Tabanca + Tüfek ŞARJÖR kuralı (2026-10-19, madde 296; kullanıcı: "şarjör mekaniği silahın mevcut dps'ini düşürmeyecek ...
## şuanda 1 dakikada ne kadar hasar verebiliyorsa şarjör sistemi ekleyince de 1 dakikada o kadar hasar verebilmeli",
## "saldırı hızı şarjör doldurma hızını arttıracak"). TEK kaynak: weapon.gd (kural), gun_reload_fx.gd (doldurma pozu/olaylar,
## kaster + kukla), shell_casing_fx.gd (kovan/şarjör çıkış noktaları), testler.
##
## W = weapon.gd _effective_fire_wait() (şarjörsüz ortalama atış aralığı; kart/eşya/yetenek/özellik hızları ve %600 sınırı dahil).
## Şarjör içi atış aralığı w = burst * W, doldurma R = (N - (N-1) * burst) * W.
## Bir döngü (N atış + doldurma) = (N-1)*w + R = N*W -> dakikadaki hasar şarjörsüz hâlle AYNI, HER saldırı hızında
## (doldurma da W ile ölçeklendiği için saldırı hızı doldurmayı aynı oranda hızlandırır).
## Mermi TETİK başına düşer (weapon.gd _on_fire_timer_timeout / arcane_surge), _fire_at başına değil: Elara R çift atış, Kaos Kitabı,
## Ilıdaric, Seri Parmak ek mermisi, Talon Q salvosu şarjör yemez (yoksa DPS düşerdi). Doldurma bitince hedef varsa HEMEN ateş
## (aradaki kare taşması bir sonraki atış aralığından düşülür) -> döngü tam N*W kalır.

const MAGS := {
	## size: şarjör; burst: şarjör içi aralık / W; pitch: doldurma + kovan sesi perdesi (tüfek daha pes, ağır).
	## port / mag_out: kovanın çıktığı / şarjörün düştüğü nokta, silah dokusunun merkezine göre DOKU PİKSELİ (48x48 zanaat sanatı,
	## namlu sağa bakar; aynalanınca x ters çevrilir - shell_casing_fx.gd icon_point).
	## casing_row / mag_row: assets/fx/gun/casings.png satırı (tools/gen_gun_mag_fx.py).
	"tabanca": {"size": 6, "burst": 0.8, "pitch": 1.0, "port": Vector2(-6, -6), "mag_out": Vector2(-10, 8), "casing_row": 0, "mag_row": 2},
	"tufek": {"size": 5, "burst": 0.8, "pitch": 0.86, "port": Vector2(-7, -5), "mag_out": Vector2(-6, 5), "casing_row": 1, "mag_row": 3},
}

## Hedef yokken yarım şarjör bu kadar sn sonra kendiliğinden dolar (savaş arası; çatışmada sürekli hedef olduğu için DPS'e girmez).
const IDLE_RELOAD_DELAY := 1.2

## Doldurma olayları (ilerleme 0..1): şarjör düşer / yeni şarjör oturur / horoz çekilir. Poz + ses bunlara bağlı.
const MAG_OUT_AT := 0.20
const MAG_IN_AT := 0.58
const COCK_AT := 0.80

const TILT := 0.72 ## rad (~41 derece): doldururken namlu yukarı kalkar
const LIFT_JERK := 2.6 ## dünya px: şarjör düşerken silah yukarı silkinir
const SLAM_DROP := 2.4 ## dünya px: yeni şarjör çakılınca aşağı iner
const COCK_KICK := 3.4 ## dünya px: horoz çekilirken silah namlu boyunca geri kayar


static func has_mag(key: String) -> bool:
	return MAGS.has(key)


static func mag_size(key: String) -> int:
	return int(MAGS.get(key, {}).get("size", 0))


static func cfg(key: String) -> Dictionary:
	return MAGS.get(key, {})


static func burst_wait(key: String, avg_wait: float) -> float:
	return avg_wait * float(MAGS.get(key, {}).get("burst", 1.0))


static func reload_time(key: String, avg_wait: float) -> float:
	var n: int = mag_size(key)
	if n <= 0:
		return 0.0
	var b: float = float(MAGS[key].get("burst", 1.0))
	return maxf(0.0, (float(n) - float(n - 1) * b) * avg_wait)


## Bir tam döngünün süresi - testte şarjörsüz N * W ile eşit olmalı.
static func cycle_time(key: String, avg_wait: float) -> float:
	return float(mag_size(key) - 1) * burst_wait(key, avg_wait) + reload_time(key, avg_wait)


## 0 -> 1 arası, `at` anında başlayıp `dur` içinde sönen darbe (karesel).
static func _pulse(t: float, at: float, dur: float) -> float:
	if t < at or dur <= 0.0:
		return 0.0
	var u: float = (t - at) / dur
	return 0.0 if u >= 1.0 else (1.0 - u) * (1.0 - u)


## Doldurma pozu, ilerleme t (0..1). tilt: namlunun yukarı kalkışı (rad, + = yukarı - çağıran ekran yönüne çevirir);
## lift: dünya px yukarı (+); kick: dünya px namlu boyunca GERİ (+); sx/sy: ikonun kendi eksenlerinde ölçek çarpanı.
## t = 0 ve t = 1'de poz nötr (silah nişan açısından başlar, nişana döner) - kaster weapon.gd ve kukla remote_player.gd aynısını oynatır.
static func pose(t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	var tilt: float
	if t < 0.14:
		var u: float = t / 0.14
		## hafif aşarak kalkar (back ease)
		var c: float = 1.70158
		tilt = TILT * (1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0))
	elif t < 0.86:
		tilt = TILT + sin((t - 0.14) * 9.0) * 0.035
	else:
		var u2: float = (t - 0.86) / 0.14
		tilt = TILT * (1.0 - u2 * u2 * (3.0 - 2.0 * u2))
	## yeni şarjör çakılınca namlu bir an aşağı (nişana doğru) iner
	tilt -= 0.16 * _pulse(t, MAG_IN_AT, 0.10)
	var lift: float = LIFT_JERK * _pulse(t, MAG_OUT_AT, 0.09) - SLAM_DROP * _pulse(t, MAG_IN_AT, 0.10)
	var kick: float = 0.0
	if t >= COCK_AT:
		var k: float = (t - COCK_AT) / 0.10
		if k < 0.35:
			kick = COCK_KICK * (k / 0.35)
		elif k < 1.0:
			kick = COCK_KICK * (1.0 - (k - 0.35) / 0.65) * (1.0 - (k - 0.35) / 0.65)
	var slam: float = _pulse(t, MAG_IN_AT, 0.08)
	return {"tilt": tilt, "lift": lift, "kick": kick, "sx": 1.0 + 0.07 * slam, "sy": 1.0 - 0.12 * slam}

