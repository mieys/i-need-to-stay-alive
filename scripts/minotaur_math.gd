extends RefCounted

## MINOTAUR (Kademe 3 bossu) - TÜM ayar sabitleri ve saf (düğümsüz) hesaplar TEK yerde.
## Kullanan: minotaur_charge.gd (host'ta hücum durum makinesi), enemy_charge_lane.gd (uyarı şeridi, host + istemci),
## player.gd (savrulma mesafesi), testler. Hücum sayıları burada değişir; başka yerde kopyası YOK (bkz. CLAUDE.md madde 3).
##
## BOSS'UN İKİ HÜCUMU (kullanıcı isteği 2026-10-08):
##  1) BOYNUZ HÜCUMU (MODE_HORN): hedefe kilitlenir, yerde geniş bir uyarı şeridi belirir, sonra boynuzlarını indirip şerit boyunca
##     çok hızlı atılır. Oyuncunun yürüme hızından (252, eşya/kartla ~380) çok hızlıdır: "oyuncuya yetişebilecek şekilde" - kaçmanın tek yolu
##     şeridin yanına sıçramak. İlk HORN_HOMING_TIME sn hedefe doğru hafifçe kıvrılır (düz kaçanı yakalasın).
##  2) BOĞA KOŞUSU (MODE_STAMPEDE): "bazen durur, hızlanarak koşar" - uzaktaki hedefe önce durup kazır, sonra YAVAŞ YAVAŞ hızlanan,
##     hedefe doğru geniş kavisler çizen bir koşu. Duvara çarparsa sersemleyip uzun süre açık kalır.
## İsabet: şeridin içindeki her oyuncu hücum başına BİR kez vurulur (hasar + savrulma). Savrulan oyuncu/boss hiçbir zaman duvar/çarpışma
## karosunun içine girmez (clip_travel / clip_fling_distance, GameManager.is_position_blocked_by_walls ile aynı hücreler).

const MODE_HORN := 0
const MODE_STAMPEDE := 1

# ---------------------------------------------------------------- hücum seçimi / sıklık
const RANGE_MIN := 90.0 ## hedef bundan yakınsa hücum başlatmaz (yakın dövüş yeter)
const RANGE_MAX := 560.0 ## hedef bundan uzaksa hücum başlatmaz
const CD_MIN := 2.6 ## bir hücumdan (toparlanma dahil) sonra sonraki hücuma en az bu kadar sn
const CD_MAX := 4.6
const FIRST_CD_MIN := 1.5 ## doğuştan sonraki ilk hücuma kadar
const FIRST_CD_MAX := 3.0
const STAMPEDE_CHANCE := 0.35 ## uzaktaki hedefe karşı koşu seçme olasılığı
const STAMPEDE_MIN_DIST := 240.0

# ---------------------------------------------------------------- uyarı (windup)
const WINDUP_TIME := 0.95 ## durup hazırlanma süresi (her iki hücum)
const AIM_LOCK_AT := 0.4 ## bu ana kadar hedefi izler, sonra yön KİLİTLENİR ve uyarı şeridi belirir (oyuncuya WINDUP_TIME - AIM_LOCK_AT sn tepki süresi)
const STAMPEDE_STOP_TIME := 1.25 ## koşuda "durup kazıma" daha uzun (hızlanmadan önceki gerilim)

# ---------------------------------------------------------------- boynuz hücumu
const LANE_WIDTH := 76.0 ## şerit genişliği (dünya birimi) ~ boss gövdesi; isabet yarıçapı = LANE_WIDTH/2 + oyuncu yarıçapı
const HORN_SPEED := 640.0 ## px/sn (oyuncu 252)
const HORN_START_SPEED := 180.0
const HORN_EASE_TIME := 0.14 ## START_SPEED -> SPEED geçiş süresi
const HORN_OVERSHOOT := 170.0 ## hedefin ÖTESİNE bu kadar daha koşar
const HORN_MIN_LEN := 360.0
const HORN_MAX_LEN := 620.0
const HORN_HOMING_DEG := 45.0 ## derece/sn kıvrılma, sadece ilk HORN_HOMING_TIME sn
const HORN_HOMING_TIME := 0.35

# ---------------------------------------------------------------- boğa koşusu
const STAMPEDE_START_SPEED := 70.0
const STAMPEDE_TOP_SPEED := 520.0
const STAMPEDE_ACCEL := 300.0 ## px/sn^2 (tam hıza ~1,5 sn)
const STAMPEDE_TURN_DEG := 80.0 ## derece/sn (tam hızda dönüş yarıçapı ~370 px: son anda yana kaçan yakalanmaz)
const STAMPEDE_MAX_TIME := 3.6
const STAMPEDE_AFTER_HIT := 0.5 ## birine vurduktan sonra koşu bu kadar daha sürer
const STAMPEDE_PREVIEW_LEN := 260.0 ## uyarı şeridinin gösterdiği başlangıç uzunluğu
const STAMPEDE_LANE_WIDTH := 64.0 ## ~ boss gövde çapı (ölçekli yarıçap ~31,5): isabet yarıçapı = yarısı + oyuncu 11,4 = gövdeye değen vurulur

# ---------------------------------------------------------------- toparlanma
const RECOVER_TIME := 1.0
const RECOVER_WALL_TIME := 1.7 ## duvara çarpınca sersemleme (boss açıkta)
const ABORT_GAP_MSEC := 400 ## yetenek tiki bu kadar sessiz kalırsa (donma/korku...) hücum iptal

# ---------------------------------------------------------------- isabet / savrulma
const PLAYER_HIT_RADIUS := 11.4 ## player.gd PLAYER_BODY_RADIUS
const FLING_DISTANCE := 190.0 ## savrulma mesafesi (px); player.gd BOSS_FLING_MAX_SPEED ile ~196 px'e kadar çıkabilir
const FLING_SIDE_BIAS := 0.9 ## savrulma yönü = hücum yönü + yan bileşen (şeridin hangi tarafındaysa o yana)
const WALL_MARGIN := 22.0 ## boss merkezi duvar karosuna bu kadar yaklaşmadan durur (gövde yarıçapı ~32)
const FLING_WALL_MARGIN := 12.0 ## oyuncu merkezi duvardan bu kadar önce durur
const STEP := 8.0 ## duvar yoklama adımı (px)
const NET_SPEED_CAP := 760.0 ## istemci kuklasının ağ hızı tavanı (enemy.gd update_network_state, hücum süresince)

# ---------------------------------------------------------------- görsel pozlar (enemy.gd _pose_override)
const POSE_NONE := 0
const POSE_CROUCH := 1 ## windup: saldırı sayfasının 1-2. karesi (baş eğik, kazıma)
const POSE_CHARGE := 2 ## hücum: saldırı sayfasının 0-2. karesi döngü
const POSE_RISE := 3 ## toparlanma: saldırı sayfasının 3-5. karesi (boynuz savurup doğrulma), son karede kalır


## Hücum türü seçimi: uzak hedefte STAMPEDE_CHANCE olasılıkla koşu, yoksa boynuz hücumu. roll = 0..1 rastgele (test için dışarıdan).
static func pick_mode(dist: float, roll: float) -> int:
	if dist >= STAMPEDE_MIN_DIST and roll < STAMPEDE_CHANCE:
		return MODE_STAMPEDE
	return MODE_HORN


## Boynuz hücumunun t. saniyedeki hızı: HORN_START_SPEED'ten HORN_SPEED'e HORN_EASE_TIME'da çıkar, sonra sabit.
static func horn_speed(t: float) -> float:
	return lerpf(HORN_START_SPEED, HORN_SPEED, clampf(t / HORN_EASE_TIME, 0.0, 1.0))


## Koşunun bir sonraki hızı (sabit ivme).
static func stampede_speed(current: float, delta: float) -> float:
	return move_toward(current, STAMPEDE_TOP_SPEED, STAMPEDE_ACCEL * delta)


## Boynuz hücumu şeridinin uzunluğu: hedefin ötesine OVERSHOOT, [MIN, MAX] arasında (duvar kısaltması ayrı: clip_travel).
static func horn_length(dist_to_target: float) -> float:
	return clampf(dist_to_target + HORN_OVERSHOOT, HORN_MIN_LEN, HORN_MAX_LEN)


## dir'i target_dir'e doğru en fazla max_angle (radyan) döndürür.
static func turn_toward(dir: Vector2, target_dir: Vector2, max_angle: float) -> Vector2:
	if target_dir.length() < 0.001:
		return dir
	var diff: float = wrapf(target_dir.angle() - dir.angle(), -PI, PI)
	return dir.rotated(clampf(diff, -max_angle, max_angle)).normalized()


## p noktasının [a, b] doğru parçasına en kısa uzaklığı.
static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Savrulma yönü: hücum yönü + oyuncunun şeridin hangi yanında olduğuna göre yan bileşen ("etrafa savurur"). Tam eksendeyse sağa.
static func fling_direction(charge_dir: Vector2, boss_pos: Vector2, player_pos: Vector2) -> Vector2:
	var fwd: Vector2 = charge_dir.normalized() if charge_dir.length() > 0.001 else Vector2.RIGHT
	var side: Vector2 = fwd.orthogonal()
	var offset: float = (player_pos - boss_pos).dot(side)
	var sgn: float = -1.0 if offset < 0.0 else 1.0
	return (fwd + side * sgn * FLING_SIDE_BIAS).normalized()


## from'dan dir yönünde en çok max_len ilerlerken ilk engelin (blocked(Vector2) -> bool) ÖNÜNDE durulacak uzunluk. İlerleyen noktanın
## `margin` ilerisine bakılır (merkez değil, gövdenin önü duvara girmesin). Boş yol = max_len.
static func clip_travel(from: Vector2, dir: Vector2, max_len: float, blocked: Callable, margin: float = WALL_MARGIN, step: float = STEP) -> float:
	var d: Vector2 = dir.normalized()
	var s: float = step
	while s <= max_len + 0.001:
		if bool(blocked.call(from + d * (s + margin))):
			return maxf(s - step, 0.0)
		s += step
	return max_len


## Oyuncu savrulması için aynı kısaltma (daha küçük payla).
static func clip_fling_distance(from: Vector2, dir: Vector2, desired: float, blocked: Callable) -> float:
	return clip_travel(from, dir, desired, blocked, FLING_WALL_MARGIN, 6.0)


## a -> b adımında (<= ~STEP) herhangi bir noktanın `margin` ilerisi engelli mi? Adım küçük olduğundan uç + orta nokta yeter.
static func step_blocked(a: Vector2, b: Vector2, blocked: Callable, margin: float = WALL_MARGIN) -> bool:
	var d: Vector2 = b - a
	if d.length() < 0.001:
		return false
	var u: Vector2 = d.normalized()
	if bool(blocked.call(b + u * margin)):
		return true
	return bool(blocked.call(a + d * 0.5 + u * margin))


## Savrulma başlangıç hızı (px/sn): mesafeyi tam o kadar sönümle (KNOCKBACK_DECAY ivmesiyle) kat eder. v^2 = 2 a d.
static func fling_speed(distance: float, decay: float) -> float:
	return sqrt(maxf(2.0 * decay * distance, 0.0))
