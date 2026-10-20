extends RefCounted

## Yakın dövüş ZİNCİRİ - TEK kaynak (madde 347; weapon.gd = gerçek/yetkili silah, remote_player.gd = kukla; altı vuruş modülü
## sword_swing / dagger_stab / topuz_slam / pence_hook / mizrak_thrust / kalkan_bash play()'in sonunda kullanır).
## Kullanıcı isteği 2026-10-20: "saldırıp illa tam konumuna döndükten sonra saldırma zorunluluğu olmasın ... üst üste saldırması
## gerektiği anlarda konumuna geri dönme zorunluluğu olmasına gerek yok".
##
## Eskiden her vuruş dinlenme yerine dönüşle bitiyordu ve hız katı saldırı hızıyla birlikte (en çok x3) büyüyordu ("daha hızlı dönüp
## saldırabilsin"): hızlı vuruşta silah her seferinde kafa üstünden hedefe koşup geri dönüyor, vuruşun kendisi 0,1 sn'lik okunmaz bir
## parıltıya dönüyordu. Şimdi:
##   1. Vuruştan sonra silah son pozunda BEKLER (hold_time; bıçak dinlenme yerine doğru yavaşça kayarak, drift_at): sonraki vuruş bu sürede
##      gelirse tween kesilir ve yeni vuruş ikonun o anki
##      yerinden başlar (her play()'in ilk adımı zaten ikonun o anki dönüşümünden çıkar) - silah hedefin başında art arda vurur.
##      Gelmezse (hedef öldü / menzilden çıktı) dinlenme yerine döner.
##   2. Hız katı artık dönüşü değil SADECE vuruş hareketini aralığa sığdırır (anim_speed): hareket aralığın FILL'ine sığıyorsa x1.
## Hasar zamanları (contact_delay) aynı hız katından hesaplandığı için vuruşla eş kalır; saniyedeki vuruş sayısı DEĞİŞMEZ.

const FILL := 0.85 ## vuruş hareketi (dönüş hariç) saldırı aralığının en çok bu kadarını kaplar - kalanı bir sonraki vuruşa kadar bekleme
const GRACE := 0.15 ## sonraki vuruş beklenenden bu kadar geç kalırsa dönüş başlar (ağ gecikmesi + hedef arama payı)
const HOLD_MAX := 0.5 ## yavaş vuran silah hedefin başında bundan uzun beklemez (aralığı uzunsa eskisi gibi dinlenip yeniden çıkar)
const SPEED_MAX := 3.0 ## = weapon.gd MELEE_EFFECT_SPEED_SCALE_MAX


## busy_1x: vuruş hareketinin hız 1'deki süresi (modülün busy_duration(1.0)), wait: saldırı aralığı (sn).
static func anim_speed(busy_1x: float, wait: float) -> float:
	if busy_1x <= 0.0 or wait <= 0.0:
		return 1.0
	return clampf(busy_1x / (wait * FILL), 1.0, SPEED_MAX)


## busy_fn(hız) -> vuruş hareketinin o hızdaki süresi. Pençe ana pozları kareden kısa kalmadığı için (madde 304 MIN_POSE) hareket hızla
## tam orantılı kısalmaz: anim_speed üstüne iki düzeltme adımı.
static func fit_speed(busy_fn: Callable, wait: float) -> float:
	var sp: float = anim_speed(float(busy_fn.call(1.0)), wait)
	for _i in range(2):
		var over: float = float(busy_fn.call(sp)) / maxf(0.001, wait * FILL)
		if over <= 1.0005 or sp >= SPEED_MAX:
			break
		sp = minf(sp * over, SPEED_MAX)
	return sp


## busy: vuruş hareketinin O HIZDAKİ süresi, wait: saldırı aralığı. Sonraki vuruşun beklenen anı + GRACE'e kadar.
static func hold_time(busy: float, wait: float) -> float:
	return clampf(wait - busy + GRACE, 0.0, HOLD_MAX)


## SADECE BIÇAK beklerken sabit durmaz (kullanıcı 2026-10-21: "sabit durmasınlar boştayken hafif geri döner gibi olsunlar yavaşça" ->
## ardından "sadece bıçak için böyle yap diğerleri önceki hali gibi olsun"): dinlenme yerine doğru yavaşça kayar - kayma oranı
## DRIFT_MAX x (1 - e^(-t / DRIFT_TAU)), yani başta biraz, sonra giderek yavaşlar (0,5 sn beklemede ~%29). Sonraki vuruş gelirse
## kaydığı yerden başlar; gelmezse dönüş oradan devam eder. Diğer beş silah append_hold ile son pozunda SABİT bekler.
const DRIFT_MAX := 0.4
const DRIFT_TAU := 0.4


## Bekleme anındaki kayma oranı (0 = vuruşun son pozu, 1 = dinlenme yeri).
static func drift_at(t: float) -> float:
	return DRIFT_MAX * (1.0 - exp(-maxf(0.0, t) / DRIFT_TAU))


## Tween'e bekleme ekler: ikon son pozunda, YEREL dönüşümüyle (karakterle birlikte gezer) SABİT durur. Her karede yeniden yazılır -
## takip/nişan kodu (weapon.gd _wf_update_facing, remote_player.gd _wf_melee_facing) bu arada onu kendi açısına çekmesin (tween
## _process'ten sonra işler).
static func append_hold(tw: Tween, icon: Node2D, hold: float) -> void:
	_append(tw, icon, hold, Vector2.ZERO, NAN, false)


## append_hold gibi ama ikon dinlenme yerine doğru yavaşça kayar (drift_at; bıçak). rest_pos/rest_rot: ikonun YEREL dinlenme
## konumu/rotasyonu. Ölçek/çarpıklık son pozdaki gibi kalır.
static func append_drift_hold(tw: Tween, icon: Node2D, hold: float, rest_pos: Vector2, rest_rot: float) -> void:
	_append(tw, icon, hold, rest_pos, rest_rot, true)


static func _append(tw: Tween, icon: Node2D, hold: float, rest_pos: Vector2, rest_rot: float, drift: bool) -> void:
	if hold <= 0.0:
		return
	var pose: Array = []
	tw.tween_method(func(e: float) -> void:
		if not is_instance_valid(icon):
			return
		if pose.is_empty():
			pose.append(icon.transform)
		var p0: Transform2D = pose[0]
		if not drift:
			icon.transform = p0
			return
		var f: float = drift_at(e * hold)
		var turn: float = angle_difference(p0.get_rotation(), rest_rot) * f
		icon.transform = Transform2D(p0.x.rotated(turn), p0.y.rotated(turn), p0.origin.lerp(rest_pos, f)), 0.0, 1.0, hold)
