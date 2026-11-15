extends RefCounted
## Tabanca + Tüfek + Pompalı + Makineli ŞARJÖR kuralı (2026-10-19, madde 296; kullanıcı: "şarjör mekaniği silahın mevcut dps'ini düşürmeyecek ...
## şuanda 1 dakikada ne kadar hasar verebiliyorsa şarjör sistemi ekleyince de 1 dakikada o kadar hasar verebilmeli",
## "saldırı hızı şarjör doldurma hızını arttıracak"). TEK kaynak: weapon.gd (kural), gun_reload_fx.gd + gun_reload_math.gd (doldurma görünüşü/sesi,
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
	## port: kovanın çıktığı nokta, silah dokusunun merkezine göre DOKU PİKSELİ (namlu sağa bakar; aynalanınca x ters çevrilir -
	## shell_casing_fx.gd icon_point). casing_row: assets/fx/gun/casings.png satırı (tools/gen_gun_mag_fx.py).
	## Doldurma görünüşü (düşen şarjör, fişekler, kol/sürgü/pompa, sesler) gun_reload_math.gd (2026-11-13).
	"tabanca": {"size": 6, "burst": 0.8, "pitch": 1.0, "port": Vector2(-6, -6), "casing_row": 0},
	"tufek": {"size": 5, "burst": 0.8, "pitch": 0.86, "port": Vector2(-7, -5), "casing_row": 1},
	## Pompalı (madde 448): 7 fişek (2026-11-14: 5 -> 7), kırmızı av fişeği kovanı (satır 4), şarjör DÜŞMEZ (fişekler tek tek sürülür).
	"pompali": {"size": 7, "burst": 0.8, "pitch": 0.78, "port": Vector2(-5, -4), "casing_row": 4},
	## Makineli (madde 652): 30 mermi, HIZLANAN şarjör ("ramp"): şarjör içi aralık sabit burst değil, şarjörün k. aralığı
	## max(floor, start * mult^k) * W (ilk atışlar ~2/sn, 23. aralıktan sonra ~12/sn). Doldurma yine döngüyü N*W'ye tamamlar
	## (reload_time) -> dakikadaki hasar şarjörsüz hâlle aynı. Kovan Tabanca'nın (satır 0); kovan deliği gövdenin üstünde.
	"makineli": {"size": 30, "burst": 1.0, "pitch": 1.08, "port": Vector2(4, -10), "casing_row": 0,
		"ramp": {"start": 1.6, "mult": 0.92, "floor": 0.27}},
}

## Hızlanan şarjörde iki atış arası en kısa süre (sn): saldırı hızı çok artınca aralık bunun altına inmez (kare başına bir tetik;
## saniyede en çok 20 atış). Doldurma bu sınırlı aralıklarla hesaplanır -> döngü N*W kalır (doldurma kısalır); ancak doldurma
## RAMP_MIN_RELOAD'un altına inmez - çok yüksek saldırı hızında (~x4 üstü) döngü N*W'yi biraz aşar (20 atış/sn tavanı zaten keser).
const RAMP_MIN_GAP := 0.05
const RAMP_MIN_RELOAD := 0.4


static func has_ramp(key: String) -> bool:
	return MAGS.get(key, {}).has("ramp")


## Hızlanan şarjörün k. aralığının W'ye oranı (k = 0: ilk atıştan sonraki aralık). floor_mult: en yüksek hız çarpanı (özellik finali
## "Kurşun Fırtınası" 0,75 = %33 daha hızlı tavan).
static func ramp_factor(key: String, k: int, floor_mult: float = 1.0) -> float:
	var r: Dictionary = MAGS.get(key, {}).get("ramp", {})
	if r.is_empty():
		return float(MAGS.get(key, {}).get("burst", 1.0))
	return maxf(float(r["floor"]) * floor_mult, float(r["start"]) * pow(float(r["mult"]), float(maxi(0, k))))


## k. aralığın gerçek süresi (sn).
static func ramp_gap(key: String, avg_wait: float, k: int, floor_mult: float = 1.0) -> float:
	return maxf(RAMP_MIN_GAP, ramp_factor(key, k, floor_mult) * avg_wait)


## k. aralık en yüksek hızda mı (özellik "Kızgın Mermiler" / final delmesi bunu sorar).
static func ramp_at_top(key: String, k: int, floor_mult: float = 1.0) -> bool:
	var r: Dictionary = MAGS.get(key, {}).get("ramp", {})
	if r.is_empty():
		return false
	return float(r["start"]) * pow(float(r["mult"]), float(maxi(0, k))) <= float(r["floor"]) * floor_mult + 0.0001


## 0..1 ısınma (namlu kızarması): aralık başlangıçtan tavana ne kadar indi.
static func ramp_heat(key: String, k: int, floor_mult: float = 1.0) -> float:
	var r: Dictionary = MAGS.get(key, {}).get("ramp", {})
	if r.is_empty():
		return 0.0
	var s: float = float(r["start"])
	var fl: float = float(r["floor"]) * floor_mult
	return clampf((s - ramp_factor(key, k, floor_mult)) / maxf(0.0001, s - fl), 0.0, 1.0)

## Hedef yokken yarım şarjör bu kadar sn sonra kendiliğinden dolar (savaş arası; çatışmada sürekli hedef olduğu için DPS'e girmez).
const IDLE_RELOAD_DELAY := 1.2


static func has_mag(key: String) -> bool:
	return MAGS.has(key)


static func mag_size(key: String) -> int:
	return int(MAGS.get(key, {}).get("size", 0))


static func cfg(key: String) -> Dictionary:
	return MAGS.get(key, {})


static func burst_wait(key: String, avg_wait: float) -> float:
	return avg_wait * float(MAGS.get(key, {}).get("burst", 1.0))


## Hızlanan şarjörde (has_ramp) TEMEL şarjör (size) ve temel hızlanmayla hesaplanır: özellik geliştirmeleri (büyük şarjör, sıcak
## başlangıç, yüksek tavan) doldurmayı UZATMAZ - onlar bilinçli güç artışı (diğer silahların "+1 sekme" geliştirmeleri gibi).
static func reload_time(key: String, avg_wait: float) -> float:
	var n: int = mag_size(key)
	if n <= 0:
		return 0.0
	if has_ramp(key):
		var fired: float = 0.0
		for k in n - 1:
			fired += ramp_gap(key, avg_wait, k)
		return maxf(RAMP_MIN_RELOAD, float(n) * avg_wait - fired)
	var b: float = float(MAGS[key].get("burst", 1.0))
	return maxf(0.0, (float(n) - float(n - 1) * b) * avg_wait)


## Bir tam döngünün süresi - testte şarjörsüz N * W ile eşit olmalı.
static func cycle_time(key: String, avg_wait: float) -> float:
	if has_ramp(key):
		var fired: float = 0.0
		for k in mag_size(key) - 1:
			fired += ramp_gap(key, avg_wait, k)
		return fired + reload_time(key, avg_wait)
	return float(mag_size(key) - 1) * burst_wait(key, avg_wait) + reload_time(key, avg_wait)
