extends Node2D

## Silah/yetenek hedef seçiminde görünürlük şartı (bkz. VisionFogScript.can_target).
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const PixelDraw := preload("res://scripts/pixel_draw.gd")

## Büyücü Kız'ın TEMEL yeteneğinin 3. varyasyonu ("Hortum") için bağımsız
## bir hortum varlığı - bkz. player.gd _skill_buyucu_tornado(). Oyuncunun
## etrafında BUYUCU_TORNADO_RADIUS yarıçapında rastgele yaratıklara doğru
## dolaşır, değdiği yaratığa saniyede en fazla 1 kez hasar verir.
##
## DÜZELTME (kullanıcı bildirimi: "bazı karakterler ve yetenekleri
## multiplayerda çalışmıyor ve görünmüyor"): eskiden bu varlık SADECE döken
## oyuncunun kendi ekranında simüle ediliyordu (aşağıdaki eski not hâlâ
## doğru: hasar zaten host-yetkili take_damage() ile herkeste senkronize
## oluyordu, sadece GÖRSEL tarafı eksikti). Artık Necromancer'ın iskelet/
## golem'leriyle BİREBİR AYNI "gerçek pet" deseni kullanılıyor (bkz. player.gd
## _skill_buyucu_tornado - broadcast_pet_spawn/despawn/state) - SADECE döken
## istemcide gerçek yapay zeka/hasar çalışır, diğer istemcilerde SADECE
## kozmetik bir kopya (mark_as_network_visual) son bildirilen konuma
## yumuşakça kayar.

var owner_player: Node2D = null
var origin: Vector2 = Vector2.ZERO
var wander_radius: float = 380.0
var damage_amount: float = 0.0
var hit_interval: float = 1.0
var touch_radius: float = 46.0
var lifetime: float = 15.0

var _elapsed: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
## Kullanıcı isteği: "büyücü kızın hortumlarını %40 yavaşlat" - eski taban
## 170.0'ın %60'ı (170 * 0.6 = 102).
var _speed: float = 102.0
var _hit_timers: Dictionary = {} ## enemy instance_id -> kalan bekleme (sn)
var _spin: float = 0.0

## bkz. skeleton_pet.gd dosya başındaki "kozmetik kopya" notu - AYNI desen.
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false


func mark_as_network_visual() -> void:
	_is_network_visual = true


## Kullanıcı isteği: "hortumlarını ... %20 küçült" - node'un tüm çizimi
## (_draw) kendi yerel orijinine göre yapılıyor, bu yüzden scale'i %80'e
## indirmek görseli orantılı küçültüyor. touch_radius (isabet/hasar
## menzili) BİLEREK değiştirilmedi - istek sadece görsel küçültme,
## yeteneğin etki alanını değiştirmek değildi.
## DÜZELTME: bu artık _ready()'de (setup() DEĞİL) uygulanıyor - kozmetik
## kopyada hiç setup() çağrılmıyor (bkz. skeleton_pet.gd'deki AYNI desen),
## ama görsel ölçeği yine de doğru olmalı.
func _ready() -> void:
	scale = Vector2(1.05, 1.05)


func setup(p_owner: Node2D, p_origin: Vector2, p_radius: float, p_damage: float,
		p_hit_interval: float, p_lifetime: float, p_touch_radius: float) -> void:
	owner_player = p_owner
	origin = p_origin
	wander_radius = p_radius
	damage_amount = p_damage
	hit_interval = p_hit_interval
	lifetime = p_lifetime
	touch_radius = p_touch_radius
	global_position = origin + Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0))
	_pick_new_target()
	set_process(true)


## Yakında bir yaratık varsa ona doğru yönel ("rasgele konumlarda ...
## yaratıklara doğru hareket ederek" isteğiyle uyumlu), yoksa yarıçap
## içinde rastgele bir noktaya doğru dolaş.
func _pick_new_target() -> void:
	var candidates: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not VisionFogScript.can_target(e):
			continue
		if origin.distance_to(e.global_position) <= wander_radius:
			candidates.append(e)
	if candidates.size() > 0:
		var pick: Node2D = candidates[randi_range(0, candidates.size() - 1)]
		_target_pos = pick.global_position
	else:
		var angle: float = randf() * TAU
		var dist: float = randf_range(40.0, wander_radius)
		_target_pos = origin + Vector2(cos(angle), sin(angle)) * dist


func _process(delta: float) -> void:
	queue_redraw()
	if _is_network_visual:
		_process_network_visual(delta)
		return
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	_spin += delta * 6.0

	var to_target: Vector2 = _target_pos - global_position
	if to_target.length() < 24.0:
		_pick_new_target()
	else:
		global_position += to_target.normalized() * _speed * delta
	## Yarıçap dışına taşarsa yeni bir hedefe yönel (elastik sınır).
	if global_position.distance_to(origin) > wander_radius:
		_pick_new_target()

	for key in _hit_timers.keys():
		_hit_timers[key] = max(0.0, (_hit_timers[key] as float) - delta)

	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) > touch_radius:
			continue
		var id: int = e.get_instance_id()
		if _hit_timers.get(id, 0.0) > 0.0:
			continue
		_hit_timers[id] = hit_interval
		if e.has_method("take_damage"):
			## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" -
			## her ayrı temas kendi kritik zarını atıyor (player.gd'deki
			## paylaşılan crit_chance_bonus/crit_damage_bonus statlarını
			## kullanarak, bkz. o dosyadaki _roll_ability_crit/_apply_
			## ability_crit).
			var dmg: float = damage_amount
			var is_crit: bool = false
			if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
				is_crit = owner_player._roll_ability_crit()
				dmg = owner_player._apply_ability_crit(dmg, is_crit)
			e.take_damage(dmg, is_crit, 0.0, true)

	_broadcast_network_state()


## bkz. skeleton_pet.gd'deki AYNI fonksiyon - GERÇEK hortum kendi konumunu
## periyodik olarak yayınlıyor, kozmetik kopyalar sadece buna yumuşakça
## kayıyor (hiç kendi rastgele dolaşma/hasar mantığı çalıştırmıyor).
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.2):
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, false)


## broadcast_pet_state RPC'sinin çağırdığı istemci tarafı karşılığı - "is_
## attacking" parametresi bu efekt için anlamsız, kullanılmıyor.
## DÜZELTME: remote_player.gd _update_pet_visual_state() bu fonksiyonu
## sprite_row dahil 3 argümanla çağırıyor (bkz. skeleton_pet.gd/player_pet.gd
## AYNI düzeltme) - eski 2 parametreli imza "too many arguments" hatasıyla
## sessizce başarısız olup tornadoyu diğer oyunculara hareketsiz gösteriyordu.
func update_network_pet_state(pos: Vector2, _is_attacking: bool, _sprite_row: int = -1) -> void:
	_network_target_position = pos
	_network_state_received = true


func _process_network_visual(delta: float) -> void:
	_spin += delta * 6.0
	if _network_state_received:
		global_position = global_position.lerp(_network_target_position, min(1.0, delta * 10.0))
	


## ---------------------------------------------------------------- GÖRÜNÜM (kullanıcı isteği 2026-09-22: "hortum efektini sıfırdan, daha iyi, pixel tarzda")
## Eski hâli 48x48 raster sprite'tı. Yeni hortum tamamen prosedürel 1-texel pixel-art (gerçek pet/kozmetik kopya AYNI sahneyi + script'i kurar,
## yani her istemcide aynı görünür): sallanan koni gövde + yatay dönen rüzgar şeritleri (perspektifli: ön tarafta uzun/parlak, arkada kısa/soluk) +
## kat kat dönen kesikli halkalar + tepede bulut başlığı + spiral yükselen döküntü + arcane (mor) kıvılcımlar + yerde toz halkası ve gölge.
const FUNNEL_H := 84.0 ## huni yüksekliği (px)
const R_BOTTOM := 5.0
const R_TOP := 27.0
const BASE_Y := 12.0 ## huni tabanının (yer temas noktası) node orijinine göre y'si
const C_DARK := Color(0.26, 0.34, 0.62, 1.0)
const C_MID := Color(0.56, 0.75, 0.96, 1.0)
const C_LIGHT := Color(0.9, 0.97, 1.0, 1.0)
const C_ARCANE := Color(0.84, 0.58, 1.0, 1.0)
const C_DUST := Color(0.72, 0.66, 0.56, 1.0)


func _funnel_radius(h: float) -> float:
	return lerpf(R_BOTTOM, R_TOP, pow(h, 1.3))


func _funnel_center(h: float) -> Vector2:
	return Vector2(sin(_spin * 0.55 + h * 3.4) * 4.0 * h, BASE_Y - FUNNEL_H * h)


## Perspektifli (yassı) elips halka: ön yarı (sin>0) parlak, arka yarı soluk; dashed ise her 3. nokta atlanır (dönüyormuş hissi için phase kayar).
func _ellipse_ring(center: Vector2, rx: float, ry: float, phase: float, front_col: Color, back_col: Color, dashed: bool) -> void:
	var n: int = maxi(16, int(TAU * rx / PixelDraw.TEXEL))
	for i in range(n):
		if dashed and (i % 3) == 0:
			continue
		var a: float = TAU * float(i) / float(n) + phase
		var front: bool = sin(a) > 0.0
		PixelDraw.px(self, center + Vector2(cos(a) * rx, sin(a) * ry), 1, front_col if front else back_col)


func _draw() -> void:
	var t: float = PixelDraw.TEXEL
	## --- Yer gölgesi: yassı dither elips ---
	var sh_rx: int = int(17.0 / t)
	var sh_ry: int = int(5.5 / t)
	for iy in range(-sh_ry, sh_ry + 1):
		var hw: int = int(float(sh_rx) * sqrt(maxf(0.0, 1.0 - pow(float(iy) / float(maxi(sh_ry, 1)), 2.0))))
		for ix in range(-hw, hw + 1):
			if ((ix + iy) & 1) == 0:
				PixelDraw.px(self, Vector2(float(ix) * t, BASE_Y + 3.0 + float(iy) * t), 1, Color(0.0, 0.0, 0.0, 0.34))
	## --- Taban toz halkası (yatay dönen) ---
	_ellipse_ring(Vector2(0, BASE_Y + 2.0), 15.0, 4.6, _spin * 1.4, Color(C_DUST, 0.75), Color(C_DUST, 0.3), true)
	_ellipse_ring(Vector2(0, BASE_Y + 3.0), 21.0, 6.4, -_spin * 1.0, Color(C_DUST, 0.42), Color(C_DUST, 0.16), true)
	## --- Gövde: satır satır (her satır 1 texel): yarı saydam koyu taban, kenar konturu, dönen rüzgar şeritleri ---
	var rows: int = int(FUNNEL_H / t)
	for r in range(rows + 1):
		var h: float = float(r) / float(rows)
		var c: Vector2 = _funnel_center(h)
		var rad: float = _funnel_radius(h)
		var half_w: int = int(rad / t)
		if half_w < 1:
			continue
		PixelDraw.rect(self, c, half_w * 2, 1, Color(C_DARK, 0.4))
		PixelDraw.px(self, c + Vector2(-rad, 0), 1, Color(C_DARK, 0.95))
		PixelDraw.px(self, c + Vector2(rad, 0), 1, Color(C_DARK, 0.95))
		PixelDraw.px(self, c + Vector2(-rad + t, 0), 1, Color(C_MID, 0.55)) ## ışık alan sol kenar
		for k in range(4):
			var theta: float = _spin * (1.5 + 0.6 * (1.0 - h)) - h * 7.0 + float(k) * TAU / 4.0
			var cs: float = cos(theta)
			if cs < -0.25:
				continue ## arka yüz (gövdenin gerisinde) - çizilmez
			var x: float = c.x + sin(theta) * rad * 0.92
			var len_t: int = int(2.0 + 3.0 * absf(cs))
			PixelDraw.rect(self, Vector2(x, c.y), len_t, 1, Color(C_LIGHT, 0.95) if cs > 0.2 else Color(C_MID, 0.6))
	## --- Kat kat dönen kesikli halkalar (huniye hacim verir) ---
	for h2 in [0.1, 0.28, 0.46, 0.64, 0.82, 1.0]:
		var c2: Vector2 = _funnel_center(h2)
		var rad2: float = _funnel_radius(h2)
		_ellipse_ring(c2, rad2, rad2 * 0.3, _spin * (1.2 + h2) + h2 * 5.0, Color(C_LIGHT, 0.85), Color(C_MID, 0.3), true)
	## --- Tepede bulut başlığı: geniş, koyu iki halka + arcane parıltı ---
	var top: Vector2 = _funnel_center(1.0)
	_ellipse_ring(top + Vector2(0, -2.0), R_TOP + 5.0, (R_TOP + 5.0) * 0.28, -_spin * 0.8, Color(C_DARK, 0.9), Color(C_DARK, 0.4), false)
	_ellipse_ring(top + Vector2(0, -4.0), R_TOP - 6.0, (R_TOP - 6.0) * 0.26, _spin * 0.6, Color(C_ARCANE, 0.55), Color(C_ARCANE, 0.2), true)
	## --- Spiral yükselen döküntü (yaprak/toz taneleri): yükseldikçe geniş ---
	for i in range(11):
		var hh: float = fposmod(float(i) * 0.37 + _spin * 0.06 * (1.0 + 0.25 * float(i % 3)), 1.0)
		var ang: float = _spin * 2.6 + float(i) * 2.4
		var cc: Vector2 = _funnel_center(hh)
		var rr: float = _funnel_radius(hh) * 1.2
		var p: Vector2 = cc + Vector2(cos(ang) * rr, sin(ang) * rr * 0.3)
		var debris: Color = [Color(0.36, 0.26, 0.18), Color(0.4, 0.62, 0.3), C_LIGHT][i % 3]
		PixelDraw.px(self, p, 1, Color(debris, 0.95 if sin(ang) > -0.2 else 0.4))
	## --- Arcane (mor) kıvılcımlar: hızlı yörünge ---
	for i in range(5):
		var h3: float = 0.15 + 0.16 * float(i)
		var ang2: float = -_spin * 3.6 + float(i) * 1.7
		var c3: Vector2 = _funnel_center(h3)
		var rr3: float = _funnel_radius(h3) * 1.05
		PixelDraw.px(self, c3 + Vector2(cos(ang2) * rr3, sin(ang2) * rr3 * 0.3), 1, Color(C_ARCANE, 0.95))
