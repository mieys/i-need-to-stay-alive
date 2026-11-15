extends RefCounted

## Uzak oyuncudaki ışının (Yıldırım / Gökkuşağı) ağdan gelen uç konumlarını yumuşatır. Kaster ışın konumunu ~20 Hz yollar
## (weapon.gd should_throttle 0.05); sabit hedefe kilitli ışında fark edilmez, ama Talon E'de ışın saniyede ~2/3 tur dönerken her
## güncelleme 12-14 derece = ~80 px sıçrama olurdu. Son iki örnek arasında doğrusal ara değer: görüntü en çok bir güncelleme aralığı
## (~50 ms) geriden gelir; 14 derecelik kirişte kısalma %0,7 (görünmez).

var _from_a: Vector2 = Vector2.ZERO
var _to_a: Vector2 = Vector2.ZERO
var _from_b: Vector2 = Vector2.ZERO
var _to_b: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _interval: float = 0.05 ## son iki örneğin gerçek aralığından (üstel ortalama) öğrenilir
var _count: int = 0


## Yeni ağ örneği. Aralık 0,02-0,15 sn'ye kırpılır (paket kaybında / ilk örnekte uç değerler görüntüyü bozmasın).
func push(from_pos: Vector2, to_pos: Vector2) -> void:
	if _count == 0:
		_from_a = from_pos
		_to_a = to_pos
	else:
		_from_a = _from_b
		_to_a = _to_b
		_interval = lerpf(_interval, clampf(_t, 0.02, 0.15), 0.5)
	_from_b = from_pos
	_to_b = to_pos
	_t = 0.0
	_count += 1


func step(delta: float) -> void:
	_t += delta


func from_pos() -> Vector2:
	return _from_a.lerp(_from_b, _k())


func to_pos() -> Vector2:
	return _to_a.lerp(_to_b, _k())


func _k() -> float:
	if _count < 2:
		return 1.0
	return clampf(_t / maxf(0.001, _interval), 0.0, 1.0)
