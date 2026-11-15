extends RefCounted
## Tabanca / Tüfek / Pompalı / Makineli ŞARJÖR DOLDURMA zaman çizelgesi (2026-11-13, madde 645; kullanıcı: "şarjör doldururken mermi veya şarjör
## çıkarılıp eklenmiyor", sesler masaüstündeki 3 dosyadan). Prototip tools/proto_20261113/sarjor/index.html (kullanıcı onayladı).
## SAF fonksiyonlar - kaster (weapon.gd) ve uzak kukla (remote_player.gd) gun_reload_fx.gd üzerinden AYNISINI oynatır (CLAUDE.md
## "iki yer" kuralı). Kural / süre gun_mag_math.gd'de (değişmedi); burada sadece görünüş + ses anları.
##
## u = doldurma başından beri TEMEL saniye (silahın şarjörsüz atış aralığıyla ölçülmüş temel doldurma; gerçek süre kısalınca
## sürücü u'yu hızlı ilerletir). Parça koordinatları silahın KENDİ doku pikseli (namlu sağa; aynalanınca sürücü çevirir).
## Dokular + sesler tools/gen_gun_reload_fx.py (assets/fx/gun/reload/, assets/audio/gun/reload/).
##
## Sesler: [ad, anahtar an u, parça içindeki anahtar ofset sn]. Parça, anahtar anı tam olaya (şarjör oturur, kol çakılır...)
## denk gelecek kadar ÖNCE başlar. Doldurma kısalınca parça en çok MAX_RATE hızlanır (perde biraz yükselir), gerisi üst üste biner.

const MAX_RATE := 1.25

const BASE_LEN := {"tabanca": 1.89, "tufek": 2.34, "makineli": 2.35} ## pompalı fişek sayısına bağlı (length())
const TILT := {"tabanca": 0.62, "tufek": 0.42, "pompali": 0.34, "makineli": 0.40} ## rad, namlunun yukarı kalkışı

## Tabanca: eğik şarjör dokusunun (8x9) oturmuş sol-üst köşesi; dışarı s satır kayınca (-s/2, +s) (kabza 2 satırda 1 px sola eğik).
const TAB_MAG_AT := Vector2(5.0, 13.0)
const TAB_MAG_OUT := 11.0 ## bu kadar satır kayınca kabzadan tamamen çıkar ve düşer
const TAB_MAG_IN := 13.0 ## yeni şarjör bu kadar aşağıda belirir
const TUF_MAG_AT := Vector2(30.0, 16.0)
const POM_SHELL_X := 30.0
## Makineli (madde 652): uzun düz şarjörün (5x20, makineli_mag.png) oturmuş sol-üst köşesi; MAK_OUT satır kayınca düşer, yenisi MAK_IN
## satır aşağıda belirip yukarı kayar. Anlar: çıkar 0,30 / düşer 0,40 / oturur 1,20 / kurma kolu geri 1,60 - ileri 1,95.
const MAK_MAG_AT := Vector2(36.0, 28.0)
const MAK_OUT := 14.0
const MAK_IN := 16.0
const MAK := {"out": 0.30, "drop": 0.40, "appear": 0.80, "seat": 1.20, "back": 1.60, "fwd": 1.95}
const POM_FORE_AT := Vector2(41.0, 28.0)
const POM_FORE_BACK := 5.0
const SPARK_A := Color("fff7d6")
const SPARK_B := Color("ffd36b")

## Pompalı fişek anları: ilk fişek SHELL0, sonra SHELL_GAP arayla; pompa son fişekten sonra.
const SHELL0 := 0.32
const SHELL_GAP := 0.33
const MAX_SHELLS := 7 ## pompalı şarjörü (gun_mag_math.gd) ile aynı

## Atıştan sonraki pompa (pompali, pump_shot_sound.gd ile aynı 0,2 sn): kundak geri-ileri, kovan geri vuruşta çıkar.
const PUMP_SHOT := {"b0": 0.20, "b1": 0.27, "f0": 0.29, "f1": 0.36, "eject": 0.27}


static func has_reload(key: String) -> bool:
	return key == "tabanca" or key == "tufek" or key == "pompali" or key == "makineli"


static func shell_count(shells: int) -> int:
	return clampi(shells, 1, MAX_SHELLS) if shells > 0 else MAX_SHELLS


static func _last_shell(shells: int) -> float:
	return SHELL0 + float(shell_count(shells) - 1) * SHELL_GAP


static func length(key: String, shells: int = -1) -> float:
	if key == "pompali":
		return _last_shell(shells) + 0.70
	return float(BASE_LEN.get(key, 1.89))


## [ses adı, anahtar an u, parça içi anahtar ofset] - u'ya göre sıralı. Ses adı = assets/audio/gun/reload/<ad>.wav
static func sounds(key: String, shells: int = -1) -> Array:
	match key:
		"tabanca":
			return [["tabanca_out", 0.22, 0.065], ["tabanca_in", 0.86, 0.235], ["tabanca_rack", 1.545, 0.445]]
		"tufek":
			return [["tufek_out", 0.46, 0.32], ["tufek_in", 1.33, 0.35], ["tufek_bolt", 1.955, 0.355]]
		"pompali":
			var out: Array = []
			for i in shell_count(shells):
				out.append(["pompali_shell", SHELL0 + float(i) * SHELL_GAP, 0.07])
			out.append(["pompali_pump", _last_shell(shells) + 0.425, 0.285])
			return out
		"makineli": ## ofsetler = kaynak klipteki tepe anı (tools/gen_makineli_ses.py)
			return [["makineli_out", MAK["out"], 0.119], ["makineli_in", MAK["seat"], 0.241], ["makineli_back", MAK["back"], 0.391],
				["makineli_fwd", MAK["fwd"], 0.144]]
	return []


## Ses parçasının başlaması gereken u: anahtar an - ofset (gerçek sn) -> u biriminde (speed = temel sn / gerçek sn).
static func sound_start_u(at: float, key_offset: float, speed: float) -> float:
	var rate: float = clampf(speed, 1.0, MAX_RATE)
	return at - key_offset / rate * maxf(speed, 0.0001)


static func _pulse(u: float, at: float, dur: float) -> float:
	if u < at or dur <= 0.0:
		return 0.0
	var q: float = (u - at) / dur
	return 0.0 if q >= 1.0 else (1.0 - q) * (1.0 - q)


static func _kick(x: float) -> float:
	if x < 0.0 or x > 0.12:
		return 0.0
	var k: float = x / 0.12
	return k / 0.3 if k < 0.3 else pow(1.0 - (k - 0.3) / 0.7, 2.0)


static func _smooth(q: float) -> float:
	q = clampf(q, 0.0, 1.0)
	return q * q * (3.0 - 2.0 * q)


static func _back_ease(q: float) -> float:
	q = clampf(q, 0.0, 1.0)
	var c: float = 1.70158
	return 1.0 + (c + 1.0) * pow(q - 1.0, 3.0) + c * pow(q - 1.0, 2.0)


static func _seat_u(key: String) -> float:
	if key == "makineli":
		return float(MAK["seat"])
	return 0.86 if key == "tabanca" else (1.33 if key == "tufek" else -1.0)


static func _out_u(key: String) -> float:
	if key == "makineli":
		return float(MAK["out"])
	return 0.22 if key == "tabanca" else (0.46 if key == "tufek" else -1.0)


## Pompa kundağı geri kayması (doku px, negatif = geri): b0-b1 geri, f0-f1 ileri.
static func fore_dx(u: float, b0: float, b1: float, f0: float, f1: float) -> float:
	if u < b0 or u >= f1:
		return 0.0
	if u < b1:
		return -roundf(POM_FORE_BACK * _smooth((u - b0) / (b1 - b0)))
	if u < f0:
		return -POM_FORE_BACK
	return -roundf(POM_FORE_BACK * (1.0 - _smooth((u - f0) / (f1 - f0))))


## Poz: tilt (rad, + = namlu yukarı), lift (dünya px yukarı), kick (dünya px namlu boyunca GERİ), sx/sy (ikon ekseninde ölçek).
## u <= 0 ve u >= length'te nötr.
static func pose(key: String, u: float, shells: int = -1) -> Dictionary:
	var out := {"tilt": 0.0, "lift": 0.0, "kick": 0.0, "sx": 1.0, "sy": 1.0}
	var L: float = length(key, shells)
	if u <= 0.0 or u >= L:
		return out
	var tilt_max: float = float(TILT.get(key, 0.5))
	var up: float = 0.12 * L
	var down: float = L - 0.14 * L
	var tilt: float
	if u < up:
		tilt = tilt_max * _back_ease(u / up)
	elif u < down:
		tilt = tilt_max + sin((u - up) * 9.0) * 0.03
	else:
		tilt = tilt_max * (1.0 - _smooth((u - down) / (L - down)))
	var lift: float = 0.0
	var kick: float = 0.0
	var sx: float = 1.0
	var sy: float = 1.0
	var out_u: float = _out_u(key)
	var seat: float = _seat_u(key)
	if out_u > 0.0:
		lift += 2.6 * _pulse(u, out_u, 0.09)
	if seat > 0.0:
		lift -= 2.4 * _pulse(u, seat, 0.10)
		var sl: float = _pulse(u, seat, 0.08)
		sx = 1.0 + 0.07 * sl
		sy = 1.0 - 0.12 * sl
		tilt -= 0.14 * _pulse(u, seat, 0.10)
	match key:
		"tabanca":
			kick += 3.0 * _kick(u - 1.545) + 1.2 * _kick((u - 1.30) * 1.6)
		"tufek":
			kick += 1.6 * _kick(u - 1.735) + 3.0 * _kick(u - 1.955)
			tilt += 0.05 * _pulse(u, 1.64, 0.08)
		"pompali":
			for i in shell_count(shells):
				tilt -= 0.035 * _pulse(u, SHELL0 + float(i) * SHELL_GAP, 0.07)
			var ls: float = _last_shell(shells)
			kick += 1.4 * _kick(u - (ls + 0.29)) + 2.6 * _kick(u - (ls + 0.425))
		"makineli":
			kick += 1.8 * _kick(u - float(MAK["back"])) + 3.0 * _kick(u - float(MAK["fwd"]))
			tilt += 0.05 * _pulse(u, float(MAK["back"]), 0.08)
	out["tilt"] = tilt
	out["lift"] = lift
	out["kick"] = kick
	out["sx"] = sx
	out["sy"] = sy
	return out


## Parçalar: tex = gövde dokusu (&"" = asıl çizim, yoksa assets/fx/gun/reload/<ad>.png), back = silahın ARKASINDA çizilen
## [ad, sol-üst doku px, alfa] (kabzadan/yuvadan çıkan şarjör ve fişek gövdenin içinde gizli kalır), front = önünde,
## sparks = [doku px, renk, alfa] (şarjör oturunca 3 kıvılcım pikseli).
static func parts(key: String, u: float, shells: int = -1) -> Dictionary:
	var back: Array = []
	var front: Array = []
	var sparks: Array = []
	var tex: StringName = &""
	match key:
		"tabanca":
			if u >= 0.22 and u < 0.32:
				var q: float = (u - 0.22) / 0.10
				var s: float = TAB_MAG_OUT * q * q
				back.append([&"tabanca_mag", _half(TAB_MAG_AT + Vector2(-s * 0.5, s)), 1.0])
			if u >= 0.60 and u < 0.88:
				var a: float = clampf((u - 0.60) / 0.06, 0.0, 1.0)
				var s2: float = TAB_MAG_IN * (1.0 - _smooth((u - 0.62) / 0.24))
				back.append([&"tabanca_mag", _half(TAB_MAG_AT + Vector2(-s2 * 0.5, s2)), a])
			var ly: float = 0.0
			var bx: float = 0.0
			if u >= 1.24 and u < 1.27:
				ly = 1.0
			elif u >= 1.27 and u < 1.50:
				ly = 2.0
				bx = 1.0 if u >= 1.30 else 0.0
			elif u >= 1.50 and u < 1.545:
				ly = 1.0
			if ly > 0.0:
				tex = &"tabanca_toggle_open"
				front.append([&"tabanca_toggle", Vector2(4.0 - bx, 8.0 - ly), 1.0])
			_sparks(sparks, u, 0.86, Vector2(6.5, 23.0))
		"tufek":
			if u >= 0.23 and u < 0.52:
				tex = &"tufek_nomag"
				var dy: float = 1.0
				if u < 0.26:
					dy = (u - 0.23) / 0.03
				elif u >= 0.46:
					dy = 1.0 + 5.0 * pow((u - 0.46) / 0.06, 2.0)
				back.append([&"tufek_mag", _half(TUF_MAG_AT + Vector2(0.0, dy)), 1.0])
			elif u >= 0.52 and u < 1.33:
				tex = &"tufek_nomag"
			if u >= 1.05 and u < 1.33:
				var a2: float = clampf((u - 1.05) / 0.05, 0.0, 1.0)
				var q2: float = _smooth((u - 1.08) / 0.25)
				back.append([&"tufek_mag", _half(TUF_MAG_AT + Vector2(0.0, 7.0 * (1.0 - q2))), a2])
			if u >= 1.64 and u < 1.955:
				tex = &"tufek_bolt_open"
				if u >= 1.70:
					front.append([&"tufek_round", Vector2(22.0, 13.0), 1.0])
			_sparks(sparks, u, 1.33, Vector2(32.5, 22.0))
		"pompali":
			for i in shell_count(shells):
				var k: float = SHELL0 + float(i) * SHELL_GAP
				if u >= k - 0.16 and u < k + 0.05:
					var a3: float = clampf((u - (k - 0.16)) / 0.04, 0.0, 1.0)
					var y: float = 33.0
					var x: float = POM_SHELL_X
					if u >= k:
						y = 28.0
						x = POM_SHELL_X + 6.0 * (u - k) / 0.05
					elif u >= k - 0.14:
						y = 33.0 - 5.0 * _smooth((u - (k - 0.14)) / 0.12)
					back.append([&"pompali_shell", _half(Vector2(x, y)), a3])
			var ls: float = _last_shell(shells)
			var fx: float = fore_dx(u, ls + 0.20, ls + 0.29, ls + 0.38, ls + 0.425)
			if fx != 0.0:
				tex = &"pompali_nofore"
				front.append([&"pompali_fore", POM_FORE_AT + Vector2(fx, 0.0), 1.0])
		"makineli":
			var o0: float = float(MAK["out"]) - 0.08
			if u >= o0 and u < float(MAK["seat"]):
				tex = &"makineli_nomag"
			if u >= o0 and u < float(MAK["drop"]):
				var dy: float = 1.0
				if u < float(MAK["out"]):
					dy = (u - o0) / 0.08 ## kilit açılır: 1 satır
				else:
					dy = 1.0 + (MAK_OUT - 1.0) * pow((u - float(MAK["out"])) / (float(MAK["drop"]) - float(MAK["out"])), 2.0)
				back.append([&"makineli_mag", MAK_MAG_AT + Vector2(0.0, roundf(dy)), 1.0])
			if u >= float(MAK["appear"]) and u < float(MAK["seat"]):
				var a4: float = clampf((u - float(MAK["appear"])) / 0.05, 0.0, 1.0)
				var q4: float = _smooth((u - float(MAK["appear"])) / (float(MAK["seat"]) - float(MAK["appear"])))
				back.append([&"makineli_mag", MAK_MAG_AT + Vector2(0.0, roundf(MAK_IN * (1.0 - q4))), a4])
			_sparks(sparks, u, float(MAK["seat"]), Vector2(38.5, 28.0))
	return {"tex": tex, "back": back, "front": front, "sparks": sparks}


## Atış sonrası pompa (yalnız pompali): kundak parçası. u = atıştan beri gerçek sn.
static func pump_shot_parts(u: float) -> Dictionary:
	var fx: float = fore_dx(u, PUMP_SHOT["b0"], PUMP_SHOT["b1"], PUMP_SHOT["f0"], PUMP_SHOT["f1"])
	if fx == 0.0:
		return {"tex": &"", "back": [], "front": [], "sparks": []}
	return {"tex": &"pompali_nofore", "back": [], "front": [[&"pompali_fore", POM_FORE_AT + Vector2(fx, 0.0), 1.0]], "sparks": []}


static func _sparks(out: Array, u: float, seat: float, at: Vector2) -> void:
	if u < seat or u >= seat + 0.13:
		return
	var q: float = (u - seat) / 0.13
	for d in [[Vector2(-1.0, 0.9), SPARK_A], [Vector2(0.2, 1.3), SPARK_B], [Vector2(1.1, 0.8), SPARK_A]]:
		out.append([(at + (d[0] as Vector2) * 4.0 * q).floor(), d[1], 1.0 - q])


static func _half(v: Vector2) -> Vector2:
	return (v * 2.0).round() * 0.5


## Boş şarjörün düştüğü an (u) - yoksa -1 (pompalı fişekleri tek tek sürülür, şarjörü yok).
static func drop_u(key: String) -> float:
	if key == "makineli":
		return float(MAK["drop"])
	return 0.32 if key == "tabanca" else (0.52 if key == "tufek" else -1.0)


## Düşen şarjör: kopma anındaki merkezi (doku px), "üst" ekseni (doku uzayında, şarjörün ağzı) ve mags_drop.png satırı.
static func drop_piece(key: String) -> Dictionary:
	if key == "tabanca":
		return {"center": TAB_MAG_AT + Vector2(-TAB_MAG_OUT * 0.5, TAB_MAG_OUT) + Vector2(4.0, 4.5), "up": Vector2(0.5, -1.0).normalized(), "row": 0}
	if key == "tufek":
		return {"center": TUF_MAG_AT + Vector2(3.0, 9.0), "up": Vector2(0.0, -1.0), "row": 1}
	if key == "makineli":
		return {"center": MAK_MAG_AT + Vector2(0.0, MAK_OUT) + Vector2(2.5, 10.0), "up": Vector2(0.0, -1.0), "row": 2}
	return {}
