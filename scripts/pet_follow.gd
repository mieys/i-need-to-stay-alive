extends RefCounted

## EVCİL HAYVAN takibi (kullanıcı isteği 2026-10-13: "petler sahibini aynı hızda takip etmemeli, daha doğal takip etmeliler").
## Eski model sahibin hızını ileri besleyip sabit bir noktaya kilitleniyordu (kirpi/köpek) ya da sabit oranlı üstel süzgeçle noktaya yapışıyordu
## (kelebek/peri): hayvan sahibin tam hızında, hep aynı yerde, mekanik duruyordu. Yeni model:
##  - YER hayvanı (köpek, kirpi): sahibin hızı HİÇ kullanılmaz. Sahip START_RADIUS'tan uzaklaşınca yürümeye başlar, hızı sahibe olan uzaklığa göre
##    artar (yaklaştıkça yavaşlar, rahat bölgeye girince durur) ve yavaşça "soluyup" hızlanır/yavaşlar. Sahip koşarken geride, durunca
##    yaklaşıp durur; küçük adımlarda hiç kıpırdamaz (dur-kalk). Sabit bir "topuk noktası" yok: sahibin olduğu yere doğru gelir.
##  - HAVA hayvanı (kelebek, peri): hedef noktaya yaylı-sönümlü (spring) bir ivmeyle gider: sahip koşunca geride kalır, durunca hafif aşıp oturur;
##    hedefe ayrıca yavaş bir salınım (drift) eklenir, yani sahip dururken de mekanik donmaz.
## Sadece görsel hareket - ağ gerekmez (uzak kuklada aynı kural sahibin kuklasını izler).

## --- yer hayvanı
var comfort_radius: float = 34.0 ## sahibe bu kadar yaklaşınca durur
var start_radius: float = 60.0 ## sahip bu kadar uzaklaşınca yeniden yürümeye başlar (histerezis)
var gain: float = 5.0 ## (uzaklık - rahat bölge) başına hız (px/sn): sabit hızda koşan sahibin arkasında denge = rahat + hız/gain
var min_speed: float = 36.0
var surge: float = 0.14 ## hız dalgalanması (+-%14)
var active: bool = false
var _t: float = 0.0
var _phase: float = randf() * TAU
var _surge_freq: float = randf_range(1.3, 2.1)


## Sahibe doğru istenen hız (vektör). max_speed: yakalama üst sınırı. Rahat bölgedeyse sıfır.
func ground_velocity(pos: Vector2, owner_pos: Vector2, delta: float, max_speed: float) -> Vector2:
	_t += delta
	var to: Vector2 = owner_pos - pos
	var d: float = to.length()
	if active:
		if d <= comfort_radius:
			active = false
	elif d > start_radius:
		active = true
	if not active or d < 0.001:
		return Vector2.ZERO
	var spd: float = clampf((d - comfort_radius) * gain, min_speed, max_speed)
	spd *= 1.0 + surge * sin(_t * _surge_freq + _phase)
	return to / d * minf(spd, max_speed)


## --- hava hayvanı
const SPRING_K := 40.0 ## yay sertliği (1/sn^2)
const SPRING_C := 9.0 ## sönüm (1/sn): ~%70 sönümlü, hafif aşar
const DRIFT_X := 4.0 ## hedefe eklenen yavaş salınım (dünya px)
const DRIFT_Y := 3.0


## Hedef etrafındaki yavaş salınım (hayvan başına faz farklı).
func drift(t: float) -> Vector2:
	return Vector2(sin(t * 1.3 + _phase) * DRIFT_X, cos(t * 0.9 + _phase * 1.7) * DRIFT_Y)


## Bir yay adımı: [yeni konum, yeni hız]. Büyük karelerde kararlılık için alt adımlara bölünür.
static func spring_step(pos: Vector2, vel: Vector2, dest: Vector2, delta: float) -> Array:
	var remaining: float = minf(delta, 0.1)
	while remaining > 0.0:
		var dt: float = minf(remaining, 0.02)
		remaining -= dt
		vel += ((dest - pos) * SPRING_K - vel * SPRING_C) * dt
		pos += vel * dt
	return [pos, vel]
