extends RefCounted

## Talon E (Silah Salvosu) YAKIN DÖVÜŞ vuruş animasyonu - TEK kaynak (weapon.gd = yetkili silah, remote_player.gd = kozmetik kopya).
## Kullanıcı (2026-11-12): "yakın dövüş silahlarında zincire bağlı olarak saldırı animasyonu + saldırı spamlaması gerekiyor ama olmuyor".
## Madde 537'den beri salvoda yalnız 6 px'lik bir dürtme vardı (görünmüyordu); silaha özel savuruş modülleri (sword_swing_math...) planı
## DÜNYA koordinatında sabitlediği için çemberde dönen ikonu zincirden koparıyordu. Burada her silahın vuruşu ZİNCİR UCUNDAKİ yuvaya
## göre (dışa bakan eksende) örneklenir: ikon yuvasından hiç ayrılmaz, yuva döndükçe vuruş de döner. Her kare şu yazılır:
##   konum   = formasyon yuvası + sample(...)["pos"]   (formasyon birimi = oyuncu-yerel px = dünya px'in 2 katı: çember 130 birim = 65 dünya px;
##             yetkilide set_icon_offset, kuklada icon.position - ikisi aynı birim)
##   dönüş   = formasyon duruşu + sample(...)["rot"]   (radyan, saat yönü pozitif)
## Süre silahın atış aralığına sığar (spam: bir sonraki vuruş geldiğinde önceki bitmiş olur), hasar/temas weapon.gd _salvo_melee_contact.

const DUR_MIN := 0.07
const DUR_FILL := 0.9 ## vuruş, atış aralığının en çok bu kadarını kaplar
const DUR_MAX := {"sword": 0.22, "dagger": 0.18, "hammer": 0.26, "scythe": 0.24, "spear": 0.18, "shield": 0.2}

const SWORD_R := 34.0 ## sword_swing_math.gd ICON_RADIUS (17 dünya px) x2: ikon pivot etrafında bu yarıçapta döner
const SWORD_HALF := 1.3089969 ## 75 derece
const SCYTHE_R := 40.0
const SCYTHE_HALF := 1.7453293 ## 100 derece (tırpan daha geniş biçer)
const DAGGER_REACH := 26.0
const DAGGER_STABS := 3.0

## Anahtar kareler [t, dışa (x), yana (y, side ile çarpılır), dönüş (rad, side ile çarpılır)]. Aralığın SHARP'ta işaretli dilimi hızlanarak
## (darbe), diğerleri yumuşak girip çıkar.
const HAMMER := [[0.0, 0.0, 0.0, 0.0], [0.30, -16.0, 0.0, -1.2], [0.48, 28.0, 0.0, 0.95], [0.62, 28.0, 0.0, 0.95], [1.0, 0.0, 0.0, 0.0]]
const SPEAR := [[0.0, 0.0, 0.0, 0.0], [0.28, -16.0, 0.0, 0.0], [0.45, 40.0, 0.0, 0.0], [0.60, 40.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0]]
const SHIELD := [[0.0, 0.0, 0.0, 0.0], [0.30, -14.0, 0.0, 0.0], [0.48, 30.0, 0.0, 0.0], [0.62, 30.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0]]
const SHARP_SEGMENT := 1 ## HAMMER/SPEAR/SHIELD'da geri çekilmeden vuruşa geçen dilim


## Silah anahtarı (weapon_catalog KEYS) -> vuruş türü; yakın dövüş olmayan "" döner.
static func kind_of_key(key: String) -> String:
	match key:
		"uzunkilic":
			return "sword"
		"dagger":
			return "dagger"
		"topuz":
			return "hammer"
		"pence":
			return "scythe"
		"mizrak":
			return "spear"
		"kalkan":
			return "shield"
	return ""


## Vuruş süresi (sn): atış aralığına (wait) sığar, silaha göre üst sınırlı.
static func duration(kind: String, wait: float) -> float:
	return clampf(wait * DUR_FILL, DUR_MIN, float(DUR_MAX.get(kind, 0.2)))


## t (0..1): vuruşun ilerlemesi, side: +1/-1 (kılıç/tırpan/balyoz yay yönü, her vuruşta değişir), outward: yuvanın dışa baktığı açı (rad).
## Döner: {"pos": Vector2 (dünya ekseninde, formasyon birimi), "rot": float}. t 0 ve 1'de sıfır (yuvadan kopma/sıçrama yok).
static func sample(kind: String, t: float, side: float, outward: float) -> Dictionary:
	var u: Vector2 = Vector2.from_angle(outward)
	var s: float = 1.0 if side >= 0.0 else -1.0
	var x: float = clampf(t, 0.0, 1.0)
	match kind:
		"sword":
			return _orbit(u, outward, s, _arc(x), SWORD_R, SWORD_HALF)
		"scythe":
			return _orbit(u, outward, s, _arc(x), SCYTHE_R, SCYTHE_HALF)
		"dagger":
			var pulse: float = pow(absf(sin(x * PI * DAGGER_STABS)), 0.7)
			return {"pos": u * DAGGER_REACH * pulse, "rot": 0.0}
		"hammer":
			return _keyed(HAMMER, u, s, x)
		"spear":
			return _keyed(SPEAR, u, s, x)
		"shield":
			return _keyed(SHIELD, u, s, x)
	return {"pos": Vector2.ZERO, "rot": 0.0}


## Kılıç/tırpan: ikon, yuvanın ARKASINDAKİ bir pivot etrafında yay çizer (uç pivottan dışarı bakar); d = yayın o anki açısı (-1..1 x yarı açı).
## Kurulma (geriye yat) - süpürme - dinlenmeye dönüş.
static func _arc(x: float) -> float:
	if x < 0.2:
		return -_smooth(x / 0.2)
	if x < 0.65:
		return lerpf(-1.0, 1.0, _smooth((x - 0.2) / 0.45))
	return 1.0 - _smooth((x - 0.65) / 0.35)


static func _orbit(u: Vector2, outward: float, s: float, d_unit: float, radius: float, half: float) -> Dictionary:
	var d: float = s * d_unit * half
	return {"pos": (Vector2.from_angle(outward + d) - u) * radius, "rot": d}


static func _keyed(frames: Array, u: Vector2, s: float, x: float) -> Dictionary:
	var perp: Vector2 = Vector2(-u.y, u.x)
	for i in range(frames.size() - 1):
		var a: Array = frames[i]
		var b: Array = frames[i + 1]
		if x <= float(b[0]) or i == frames.size() - 2:
			var span: float = maxf(0.0001, float(b[0]) - float(a[0]))
			var k: float = clampf((x - float(a[0])) / span, 0.0, 1.0)
			var e: float = k * k * k if i == SHARP_SEGMENT else _smooth(k)
			var px: float = lerpf(float(a[1]), float(b[1]), e)
			var py: float = lerpf(float(a[2]), float(b[2]), e) * s
			var pr: float = lerpf(float(a[3]), float(b[3]), e) * s
			return {"pos": u * px + perp * py, "rot": pr}
	return {"pos": Vector2.ZERO, "rot": 0.0}


static func _smooth(k: float) -> float:
	var c: float = clampf(k, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
