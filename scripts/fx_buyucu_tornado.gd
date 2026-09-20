extends Node2D

## Silah/yetenek hedef seçiminde görünürlük şartı (bkz. VisionFogScript.can_target).
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

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
			e.take_damage(dmg, is_crit)

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
	


## Yeni sanat varlığı gerektirmeyen, script tabanlı basit bir döner huni
## görünümü (bkz. fx_skill_ring.gd/fx_stun_stars.gd ile AYNI yaklaşım -
## draw_arc/draw_circle ile birincil renk paletine uygun minimal bir efekt).
