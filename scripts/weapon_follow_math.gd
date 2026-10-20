class_name WeaponFollowMath
extends RefCounted

## Süzülen silahların "HÜCUM" takibi (madde 245 prototipi E v2 -> oyunda 2026-10-17, madde 247).
## Yerel weapon.gd VE uzak kukla remote_player.gd AYNI fonksiyonları çağırır (CLAUDE.md "iki yer" hata sınıfı). Ağdan veri
## gerekmez: konum/hız/yaratıklar her istemcide zaten var, kural her ekranda aynı sonucu verir.
##   - Hücum konumu: silah başına yay (gidiş yönü x hız oranı); tepe 9, yanlar 5 dünya px öne çıkar, yatayda tepe 6 px alçalır;
##     durunca yay geri teper. Eski "lerp 9 x dt + 10 px kopma" gecikmesi kalktı (yürürken hep ~9 px geride kalıyordu).
##   - Uç yönü: hedef menzilde -> hedef (kaçarken geriye ateş); değil + yürüyor -> GİDİŞ YÖNÜ; duruyor + görüşte düşman -> ona (hazır).
##     Yakın dövüş menzildeyken dinlenme pozuna döner (savuruş oradan başlar).
##   - Görüş elipsinde (VisionFog, kendi görüşü + ağaç/duvar) düşman yoksa silahlar göğse çekilip kaybolur; görünce yay çizip
##     dönerek çıkar. HIDE_GRACE kadar düşmansız kalmadan çekilmez (kenarda gidip gelen yaratık titretmesin).
##   - En üst kademede (5) uç parıltısı (çıkışta ve durunca). Silahların arkasında iz / ardıl görüntü YOK (2026-10-18'de kaldırıldı, madde 255).
## Birimler: konumlar karakter kökünün YEREL uzayında (kök ölçeği 0,5 -> dünya = yerel x 0,5), hızlar dünya px/sn.

const VisionFogScript := preload("res://scripts/vision_fog.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

## ---------- hücum konumu ----------
const PUSH_TOP := 18.0 ## tepe slotu gidiş yönüne (9 dünya px)
const PUSH_SIDE := 10.0 ## yan slotlar (5 dünya px)
const LOW_TOP := 12.0 ## yatay yürüyüşte tepe alçalır (mızrak indirme, 6 dünya px)
const SPRING_W := [13.0, 11.0, 11.0] ## tepe biraz daha çabuk -> sırayla oturur
const SPRING_ZETA := 0.45 ## < 1: durunca hafif geri teper (fren)
const FULL_SPEED := 60.0 ## dünya px/sn: bu hızda hücum tam
const MOVING_SPEED := 25.0 ## dünya px/sn üstü "yürüyor" (uç gidiş yönüne)
const BOB_DAMP := 0.7 ## yürürken salınım %70 azalır
const BOB_AMPLITUDE := 3.5 ## yerel px (dünya 1,75) - weapon.gd HOVER_BOB_AMPLITUDE buradan
const BOB_SPEED := 2.2 ## rad/sn - weapon.gd HOVER_BOB_SPEED buradan
const TURN_RATE := 14.0 ## uç yönü dönüşü (lerp_angle hızı; nişan weapon.gd AIM_EASE_RATE 12)

## Slot türü: 0 tepe (|x| ~ 0), 1 sağ, 2 sol - itme miktarı, yay hızı ve çıkış/çekilme sırası buradan.
static func slot_kind(slot_local: Vector2) -> int:
	if absf(slot_local.x) < 1.0:
		return 0
	return 1 if slot_local.x > 0.0 else 2


static func move_target(vel: Vector2) -> Vector2:
	var L: float = vel.length()
	if L < 1.0:
		return Vector2.ZERO
	return vel / L * clampf(L / FULL_SPEED, 0.0, 1.0)


static func spring_w(kind: int) -> float:
	return float(SPRING_W[clampi(kind, 0, SPRING_W.size() - 1)])


## Yarı örtük Euler yay, mutlak sönüm. Dönen [x, v]. Uzun kare (takılma) 1/60'lık alt adımlara bölünür, patlamaz.
static func spring_step(x: Vector2, v: Vector2, target: Vector2, w: float, zeta: float, delta: float) -> Array:
	var steps: int = clampi(ceili(delta * 60.0), 1, 12)
	var h: float = delta / float(steps)
	for _i in steps:
		var a: Vector2 = (target - x) * (w * w) - v * (2.0 * zeta * w)
		v += a * h
		x += v * h
	return [x, v]


## Hücum ofseti (yerel): w = yay durumu (gidiş yönü x hız oranı, boyu ~0..1,2).
static func charge_offset(kind: int, w: Vector2) -> Vector2:
	if kind == 0:
		return w * PUSH_TOP + Vector2(0.0, LOW_TOP * minf(1.0, absf(w.x)))
	return w * PUSH_SIDE


static func bob_scale(w: Vector2) -> float:
	return 1.0 - minf(1.0, w.length()) * BOB_DAMP


## Ekran pikseline (zoom 2 -> 0,5 dünya px) yuvarlar - eski tam dünya pikseli yuvarlaması kesirli karaktere göre 1-2 ekran px titretiyordu.
static func snap_half(p: Vector2) -> Vector2:
	return (p * 2.0).round() * 0.5


## ---------- uç yönü ----------
## Ucun dünya yönü `dir` için ikon dönüşü; aynalanan ikonda (Tabanca) solda flip_h + (açı - PI + ileri). weapon.gd _update_aim formülü.
## Dönen [rotation, flip].
static func face_rotation(dir: Vector2, forward_rad: float, mirror: bool) -> Array:
	if not mirror:
		return [dir.angle() - forward_rad, false]
	var flip: bool = dir.x < 0.0
	return [(dir.angle() - PI + forward_rad) if flip else (dir.angle() - forward_rad), flip]


## Hedefsiz silahın bakacağı yön: yürüyor -> gidiş yönü, duruyor + görüşte düşman -> ona (hazır). ZERO = son açısında kal.
## (Hedef menzildeyse çağıran zaten nişan alır, buraya gelmez.)
static func idle_facing_dir(owner_vel: Vector2, focus_dir: Vector2) -> Vector2:
	if owner_vel.length() >= MOVING_SPEED:
		return owner_vel.normalized()
	if focus_dir.length() > 0.001:
		return focus_dir.normalized()
	return Vector2.ZERO


## ---------- görüşte düşman var mı ----------
const SCAN_INTERVAL_MS := 100
const META_SCAN := &"wf_scan"
const MAX_RAY_TRIES := 6 ## en yakından başlayarak en fazla bu kadar ağaç/duvar ışını

## Sahibin KENDİ görüş elipsinde (VisionFog.own_vision_contains: sisle aynı elips + ağaç/duvar ışını; takım görüşü sayılmaz)
## canlı, hedeflenebilir düşman var mı. Dönen {"seen": bool, "focus": en yakın görülen düşmanın dünya konumu ya da null}.
## Sahip başına SCAN_INTERVAL_MS önbellekli (aynı sahibin 3 silahı tek tarama yapar).
static func scan(owner: Node2D) -> Dictionary:
	var now: int = Time.get_ticks_msec()
	var cached: Variant = owner.get_meta(META_SCAN) if owner.has_meta(META_SCAN) else null ## get_meta(.., null) yoksa hata basar
	if cached is Dictionary and now - int(cached["t"]) < SCAN_INTERVAL_MS and int(cached["t"]) <= now:
		return cached
	var res: Dictionary = {"t": now, "seen": false, "focus": null}
	var tree: SceneTree = owner.get_tree() if owner.is_inside_tree() else null
	if tree != null:
		var src: Vector2 = owner.global_position
		var r: float = VisionFogScript.current_radius(tree)
		var ws: float = VisionFogScript.VISION_WIDTH_SCALE
		var cands: Array = []
		for e in EnemyQueryScript.candidates(tree, src, r * ws):
			if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or e.has_meta("untargetable"):
				continue
			var n: float = VisionFogScript.normalized_distance((e as Node2D).global_position - src, r, ws)
			if n <= 1.0:
				cands.append([n, (e as Node2D).global_position])
		cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for k in mini(cands.size(), MAX_RAY_TRIES):
			var p: Vector2 = cands[k][1]
			if VisionFogScript.own_vision_contains(tree, src, p):
				res["seen"] = true
				res["focus"] = p
				break
	owner.set_meta(META_SCAN, res)
	return res


## ---------- içe çekilme / çıkış ----------
enum { HIDDEN, REVEAL, SHOWN, RETRACT }
const REVEAL_T := 0.42
const REVEAL_STAGGER := 0.07 ## tepe -> sağ -> sol
const RETRACT_T := 0.30
const RETRACT_STAGGER := 0.04 ## sol -> sağ -> tepe
const HIDE_GRACE := 0.6
const CHEST := Vector2(0.0, -16.0) ## yerel (dünya -8): silahlar buradan çıkar / buraya çekilir
const REVEAL_SPIN := TAU
const RETRACT_SPIN := 3.8397243543875 ## 220 derece
const GLINT_REVEAL_AT := 0.78 ## çıkışın bu oranında uçta "şing"


static func reveal_stagger(kind: int) -> float:
	return REVEAL_STAGGER * float(clampi(kind, 0, 2))


static func retract_stagger(kind: int) -> float:
	return RETRACT_STAGGER * float(2 - clampi(kind, 0, 2))


## st: {"s": durum, "t": durumun başladığı an (sn), "seen_t": son görüldüğü an}. want = görüşte düşman (ya da silahın hedefi) var.
## force = başka bir sistem silahı yönetiyor (kubbe, Talon dizilimi): doğrudan SHOWN.
## instant = bekleme payı olmadan hemen çekil (sahibi öldü/yere düştü: silahlar çalıdaki gibi göğse girip kaybolur); want false olmalı.
static func step_visibility(st: Dictionary, want: bool, force: bool, now: float, kind: int, instant: bool = false) -> void:
	if not st.has("s"):
		st["s"] = HIDDEN
		st["t"] = now
	if force:
		st["s"] = SHOWN
		st["seen_t"] = now
		return
	if want:
		st["seen_t"] = now
	var s: int = int(st.get("s", HIDDEN))
	var t0: float = float(st.get("t", now))
	match s:
		HIDDEN:
			if want:
				st["s"] = REVEAL
				st["t"] = now
		REVEAL:
			if instant and not want:
				st["s"] = RETRACT ## çıkış yarıda kesilir, hemen içe
				st["t"] = now
			elif now - t0 >= reveal_stagger(kind) + REVEAL_T:
				st["s"] = SHOWN
				st["t"] = now
		SHOWN:
			if not want and (instant or now - float(st.get("seen_t", now)) >= HIDE_GRACE):
				st["s"] = RETRACT
				st["t"] = now
		RETRACT:
			if want:
				st["s"] = REVEAL
				st["t"] = now
			elif now - t0 >= retract_stagger(kind) + RETRACT_T:
				st["s"] = HIDDEN
				st["t"] = now


static func _ease_out_back(x: float, s: float = 1.9) -> float:
	var y: float = x - 1.0
	return 1.0 + (s + 1.0) * y * y * y + s * y * y


## Görünürlük pozu. home = olması gereken yerel konum (slot + hücum + salınım). Dönen {"pos", "scale", "spin" (rad), "alpha", "u"}.
## GİZLİ silah yerinde durur (görünmez) - hedef/atış merkezi değişmesin; çekilme bitince oraya ışınlanır.
static func pose(st: Dictionary, now: float, kind: int, home: Vector2) -> Dictionary:
	var s: int = int(st.get("s", HIDDEN))
	var el: float = now - float(st.get("t", now))
	var sgn: float = -1.0 if kind == 2 else 1.0
	if s == REVEAL:
		var u: float = clampf((el - reveal_stagger(kind)) / REVEAL_T, 0.0, 1.0)
		if u <= 0.0:
			return {"pos": CHEST, "scale": 0.25, "spin": 0.0, "alpha": 0.0, "u": 0.0}
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		var ctrl: Vector2 = CHEST + Vector2(home.x * 1.3, (home.y - CHEST.y) * 0.35 - 12.0)
		var q: float = 1.0 - e
		var p: Vector2 = CHEST * (q * q) + ctrl * (2.0 * q * e) + home * (e * e)
		return {"pos": p, "scale": 0.25 + 0.75 * _ease_out_back(u), "spin": sgn * REVEAL_SPIN * pow(1.0 - u, 4.0),
				"alpha": minf(1.0, u / 0.12), "u": u}
	if s == RETRACT:
		var u2: float = clampf((el - retract_stagger(kind)) / RETRACT_T, 0.0, 1.0)
		var e2: float = u2 * u2 * u2
		return {"pos": home.lerp(CHEST, e2), "scale": 1.0 - 0.8 * e2, "spin": -sgn * RETRACT_SPIN * e2,
				"alpha": 1.0 - clampf((u2 - 0.55) / 0.45, 0.0, 1.0), "u": u2}
	if s == HIDDEN:
		return {"pos": home, "scale": 1.0, "spin": 0.0, "alpha": 0.0, "u": 0.0}
	return {"pos": home, "scale": 1.0, "spin": 0.0, "alpha": 1.0, "u": 1.0}


## Silah görünür mü / ateş edebilecek kadar yerinde mi (çıkışın son %20'si dahil).
static func is_shown(st: Dictionary) -> bool:
	return int(st.get("s", HIDDEN)) == SHOWN


## ---------- uç parıltısı (sadece en üst kademe) ----------
const GLINT_TIER := 5 ## demirci geliştirmesinin son kademesi (WeaponTierArt.clamp_tier üst sınırı)
const GLINT_STOP_COOLDOWN := 1.2
const STOP_SPEED := 8.0 ## dünya px/sn altına inince "durdu"


static func has_glint(tier: int) -> bool:
	return tier >= GLINT_TIER


## Önceki karede yürüyordu, şimdi durdu mu.
static func just_stopped(prev_speed: float, speed: float) -> bool:
	return prev_speed >= MOVING_SPEED and speed < STOP_SPEED
