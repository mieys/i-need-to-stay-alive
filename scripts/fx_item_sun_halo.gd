extends "res://scripts/item_trigger_fx_base.gd"

## GÜNEŞİN İRADESİ (gunesin_iradesi) tetiklenince - "Güneş Halesi" (madde 742, prototip A): başın ARKASINDA 8 ışınlı güneş açar
## (krem parlama + sıcak hale), 1 sn sonra küçülüp can çubuğunun üstüne çıkar ve iyileşme boyunca (6 sn = ITEM_GUNES_HEAL_TIME)
## 4 ışınlı küçük güneş olarak döner; gövdeden aralıkla sıcak pırıltılar yükselir. Tamamen zamana bağlı.

const HEAL_TIME := 6.0 ## = player.gd ITEM_GUNES_HEAL_TIME


func _setup() -> void:
	_life = HEAL_TIME


## Işınlı güneş: çift ışınlar uzun, tekler kısa (üçgen), ortada disk; tek konturla.
func _sun(center: Vector2, r: float, ray_len: float, rays: int, rot: float) -> void:
	for i in rays:
		var ang: float = rot + float(i) * TAU / float(rays)
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var ln: float = ray_len * (1.0 if i % 2 == 0 else 0.62)
		if ln < 0.6:
			continue
		var bw: float = clampf(r * 0.32, 0.9, 1.8)
		_poly(PackedVector2Array([center + (dir * (r - 0.5) + perp * bw) * PX, center + dir * (r + ln) * PX,
			center + (dir * (r - 0.5) - perp * bw) * PX]), 4, false)
	_disc(center, r, 3)


func _render(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	var km: float = _sstep(_k(t, 1.0, 1.35))
	var c: Vector2 = (_o + _w(Vector2(0, -10))).lerp(_o + OVER, km)
	var r: float = lerpf(7.0 * _eout(_k(t, 0.0, 0.18)), 2.6, km)
	var rl: float = lerpf(7.5 * _eout(_k(t, 0.12, 0.4)), 2.6, km)
	var behind: bool = km < 0.5
	var fin: float = _band(1.0 - _k(t, _life - 0.25, _life))
	if (L == BACK) == behind and r > 0.3:
		_halo(ci, c, lerpf(17.0, 6.0, km) * minf(1.0, r / 4.0), GOLD, fin)
		_sun(c, r, rl, 8 if behind else 4, t * 0.55)
		_flush(ci, GOLD, fin)
		if t >= 0.08 and t < 0.3:
			_spark(ci, c, lerpf(10.0, 3.0, _k(t, 0.08, 0.3)), GOLD[5], GOLD[3], 1.0)
	if L != TOP:
		return
	## iyileşme boyunca gövdeden yükselen sıcak pırıltılar
	for j in 11:
		var age: float = t - (1.25 + float(j) * 0.42)
		if age < 0.0 or age > 0.7:
			continue
		var p: Vector2 = _o + Vector2(sin(float(j) * 2.3) * 8.0 * _sc, CHEST.y + (6.0 - 15.0 * _eout(age / 0.7)) * _sc)
		_spark(ci, p, 2.0 if age < 0.35 else 1.0, GOLD[5], GOLD[3], _band(1.0 - _k(age, 0.45, 0.7)) * fin)
