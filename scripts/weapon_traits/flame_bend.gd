extends RefCounted

## Ateş Asası alevinin BÜKÜLMESİ (madde 640, 2026-11-13; kullanıcı: "asa sağa sola döndüğünde ateş efektinin gerçek hayattaki gibi uçtan başa
## yavaşça dönmesi ... asayı döndürdüğün an düz bir çizgi halinde olmamalı").
## Fizik: alevin ağızdan x uzaklıktaki parçası x / SPEED saniye ÖNCE ağızdan çıktı ve o anki bakış yönünde ilerliyor. Yani parça,
## şimdiki yöne göre theta(x) = yön(şimdi - x/SPEED) - yön(şimdi) kadar dönük durur: ağız hemen döner, uç geride kalıp kavis çizer.
## Tek kaynak: görsel (fx_enchant_sprite + shaders/flame_bend.gdshader, her ekranda kendi asasının bakışından) ve hasar alanı
## (ates_nefesi.gd flame_contains, kasterde) AYNI hesabı kullanır. Ağ alanı yok: her istemci kendi gördüğü asa yönünü kaydeder.
## Birimler: sanat pikseli (alev yerel ekseni, ağız 0), radyan.

const N := 16 ## alev boyunca örnek sayısı (shader'daki dizi boyu da 16)
const SPEED := 460.0 ## sanat px/sn - alevin ağızdan akış hızı (GIF'in "start" karelerinde ~23 px/kare x 16,7 fps ölçüldü)
const MAX_BEND := 1.22 ## ~70 derece: çok hızlı dönüşte uç bundan fazla geride kalmaz

var _t: PackedFloat64Array = PackedFloat64Array()
var _a: PackedFloat64Array = PackedFloat64Array() ## açısı SÜREKLİ (2pi atlamasız) tutulur


## Yeni bakış kaydı (saniye, dünya radyanı). Aynı anda gelen kayıt sonuncuyu günceller.
func push(t: float, ang: float) -> void:
	if _a.is_empty():
		_t.append(t)
		_a.append(ang)
		return
	var last: float = _a[_a.size() - 1]
	var cont: float = last + angle_difference(last, ang)
	if t <= _t[_t.size() - 1] + 0.0001:
		_a[_a.size() - 1] = cont
		return
	_t.append(t)
	_a.append(cont)
	## Alevin boyunca gereken geçmişten eskisini at (en uzun gecikme ~0,4 sn).
	var keep_from: float = t - 0.6
	var cut: int = 0
	while cut < _t.size() - 2 and _t[cut + 1] < keep_from:
		cut += 1
	if cut > 0:
		_t = _t.slice(cut)
		_a = _a.slice(cut)


## Geçmişi sil, tek yöne sabitle (yeni püskürtme: alev düz başlar).
func reset(t: float, ang: float) -> void:
	_t = PackedFloat64Array([t])
	_a = PackedFloat64Array([ang])


func _angle_at(t: float) -> float:
	if _a.is_empty():
		return 0.0
	if t <= _t[0]:
		return _a[0]
	for i in range(_t.size() - 1, 0, -1):
		if _t[i - 1] <= t:
			var span: float = _t[i] - _t[i - 1]
			var w: float = clampf((t - _t[i - 1]) / span, 0.0, 1.0) if span > 0.0 else 1.0
			return lerpf(_a[i - 1], _a[i], w)
	return _a[0]


## Alev boyunca N örnekte büküm açısı (şimdiki yöne göre, radyan). length = alevin boyu (sanat px).
func angles(t: float, length: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(N)
	if _a.is_empty():
		return out
	var cur: float = _a[_a.size() - 1]
	for i in N:
		var x: float = length * float(i) / float(N - 1)
		out[i] = clampf(_angle_at(t - x / SPEED) - cur, -MAX_BEND, MAX_BEND)
	return out


static func theta_at(bend: PackedFloat32Array, x: float, length: float) -> float:
	if bend.size() < N or length <= 0.0:
		return 0.0
	var f: float = clampf(x / length, 0.0, 1.0) * float(N - 1)
	var i: int = int(floor(f))
	var j: int = mini(i + 1, N - 1)
	return lerpf(bend[i], bend[j], f - float(i))


## Bükülmüş alevdeki nokta (ağıza göre, şimdiki yön ekseninde) -> düz alevdeki karşılığı (x boyunca, y yana).
## İleri eşleme: P = R(theta(x)) * (x, y); burada tersi birkaç adımda bulunur (shader'daki flame_bend.gdshader ile AYNI).
static func unbend(p: Vector2, bend: PackedFloat32Array, length: float) -> Vector2:
	if bend.size() < N:
		return p
	var q: Vector2 = p
	var x: float = p.length()
	for k in 3:
		q = p.rotated(-theta_at(bend, x, length))
		x = maxf(q.x, 0.0)
	return q
