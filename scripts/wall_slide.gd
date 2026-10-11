extends RefCounted

## ENGELE TAKILINCA KAYMA (2026-10-11, kullanıcı: "oyuncu bir yere takılınca hafifçe gidebileceği doğru yöne doğru kayacak smooth bir oynanış").
## Hareket engeli bir hücre sorgusu (bkz. terrain_collision.gd); oyuncu ekseni engelli bulunca o eksen hızını sıfırlıyordu - köşeye/kıyı basamağına
## dik yürüyünce direkt kilitleniyordu. Burada engelli eksende hız sıfırlanır ve (neredeyse) tam karşıdan gidiyorsa, birkaç px yandaki şerit
## açıksa o yana doğru KAYILIR. Engel geniş bir duvarsa (MAX_SHIFT'ten uzun) kayma yok, eskisi gibi durulur. Saf işlev: testlenebilir.

const PROBE := 10.0        ## kökten ileriye yoklama mesafesi (player.gd'nin eski probe_dist'i)
const MAX_SHIFT := 6.0     ## bu kadar px yandaki boşluğa kayılır (köşe/basamak boyu; hücre ortasından bir hücrelik engelin etrafından DOLANMASIN)
const STEP := 2.0
const SLIDE_RATIO := 0.8   ## kayma hızı = engelli eksendeki hızın bu oranı
const HEAD_ON := 0.5       ## yandaki hız, engelli eksen hızının bu oranından küçükse "karşıdan" sayılır (yoksa oyuncu zaten kayıyor)


## pos: oyuncu kökü, vel: istenen hız, blocked: Callable(Vector2) -> bool. Ayarlanmış hızı döndürür.
static func resolve(pos: Vector2, vel: Vector2, blocked: Callable) -> Vector2:
	var out: Vector2 = vel
	var bx: bool = vel.x != 0.0 and blocked.call(pos + Vector2(signf(vel.x) * PROBE, 0.0))
	var by: bool = vel.y != 0.0 and blocked.call(pos + Vector2(0.0, signf(vel.y) * PROBE))
	if bx:
		out.x = 0.0
	if by:
		out.y = 0.0
	if bx and not by and absf(vel.y) < absf(vel.x) * HEAD_ON:
		var d: float = _slide_dir(pos, Vector2(signf(vel.x), 0.0), signf(vel.y), blocked)
		if d != 0.0:
			out.y = d * absf(vel.x) * SLIDE_RATIO
	elif by and not bx and absf(vel.x) < absf(vel.y) * HEAD_ON:
		var d2: float = _slide_dir(pos, Vector2(0.0, signf(vel.y)), signf(vel.x), blocked)
		if d2 != 0.0:
			out.x = d2 * absf(vel.y) * SLIDE_RATIO
	return out


## forward: engelli yöndeki birim vektör (eksen hizalı). Yan eksende -1/+1 (ya da 0 = kayma yok): en kısa kaymayla yoklaması açılan taraf;
## eşitlikte oyuncunun zaten bastığı yan yön (pref), o da yoksa +1.
static func _slide_dir(pos: Vector2, forward: Vector2, pref: float, blocked: Callable) -> float:
	var side := Vector2(forward.y, forward.x) ## forward yatayse (0,±1)'in mutlak hali: yan eksen birim vektörü
	side = Vector2(absf(side.x), absf(side.y))
	var s: float = STEP
	while s <= MAX_SHIFT:
		var free_pos: bool = not blocked.call(pos + side * s + forward * PROBE) and not blocked.call(pos + side * s)
		var free_neg: bool = not blocked.call(pos - side * s + forward * PROBE) and not blocked.call(pos - side * s)
		## Kaymanın kendi yönü de (PROBE kadar) açık olmalı, yoksa kayacağı yerde yine engele çarpar.
		free_pos = free_pos and not blocked.call(pos + side * PROBE)
		free_neg = free_neg and not blocked.call(pos - side * PROBE)
		if free_pos and free_neg:
			return pref if pref != 0.0 else 1.0
		if free_pos:
			return 1.0
		if free_neg:
			return -1.0
		s += STEP
	return 0.0
