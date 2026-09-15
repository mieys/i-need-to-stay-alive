extends Node2D

## Fişek: normal mermilerin aksine yol boyunca hiçbir düşmana çarpışma hasarı
## vermez (üstlerinden "uçarak" geçer) - yukarı fırlayıp yumuşak, TEK PARÇA
## bir kavis (quadratic Bezier) çizerek hedefin (ateş anındaki, SABİT)
## noktasına iner ve orada ANINDA geniş bir alan hasarı patlatır.
## GÜNCELLEME: eskiden "rise" (düz çizgi, launch->apex) + "descend" (düz
## çizgi, apex->target) diye İKİ AYRI doğrusal faz halinde hareket
## ediyordu; rotasyon da rise sırasında ayrı bir lerp ile hesaplanıp,
## descend sırasında ise SABİT kalıyordu. Sonuç: hareketin yönüyle burnun
## baktığı yön birbirinden kopuk, "kırık" (smooth olmayan) bir yörünge
## hissi. Kullanıcı isteği: "ucu yukarı şekilde yukarı fırlayıp ucunun
## dönüş açısıyla beraber aynı anda dönüp yaratıkların üstünde patlaması" -
## yani rotasyon HER an gerçek hareket yönünü (eğrinin o andaki teğetini)
## takip etmeli. Artık TEK bir sürekli Bezier eğrisi (launch -> apex ->
## target) var ve rotasyon her karede o eğrinin teğetinden hesaplanıyor -
## böylece hem yörünge hem dönüş baştan sona pürüzsüz ve birbiriyle her an
## tam tutarlı (t=0'da teğet yukarı bakar -> "ucu yukarı fırlar", t=1'de
## teğet doğrudan hedefe iner -> "yaratığın üstünde patlar").

@export var flight_duration: float = 1.15
## Kullanıcı isteği: "havai fişekler animasyon anında yukarı doğru daha çok
## uçsun öyle üstlerine çakılsın" - eskiden 90px idi, kavis (rise_height +
## apex_horizontal_bias) çok yatık kalıyordu. Artık belirgin biçimde önce
## yukarı fırlayıp sonra hedefin üstüne dik gibi çakılan bir mermi hissi
## için hem tepe yüksekliği hem de tepe noktasının ATIŞ tarafına yakın
## durması (aşağıdaki apex_horizontal_bias) birlikte kullanılıyor.
@export var rise_height: float = 230.0
## Bezier tepe noktasının ateş/hedef arasında hangi orana oturduğu (0 =
## tam ateş noktasında, 1 = tam hedefte). 0.5 (eski davranış) tepe
## noktasını TAM ORTAYA koyduğu için iniş de çıkış kadar "yatık" oluyordu.
## Daha düşük bir değer (ateşe yakın) erken fazı büyük ölçüde DİKEY
## yükselişe, geç fazı ise hedefin üstüne DİK bir iniş/çakılmaya ayırır -
## gerçek havai fişek/havan topu hissi.
@export var apex_horizontal_bias: float = 0.3
## Kullanıcı isteği ("AoE olan silahler tek hedefli silahlerle aynı hasarı/
## ateş hızını yakalamamalı" dengelemesi kapsamında): TAM hasarlı, alan
## çapında sınırsız hedef vuran bu mermi eskiden hem çok hızlı ateşliyor
## (fire_rate) hem de çok geniş bir alanı (70px) kapsıyordu - grup temizleme
## gücü tek-hedefli silahlerin tek-hedef DPS'inin kat kat üzerindeydi. Alan
## biraz daraltıldı (70 -> 55). Yeni kullanıcı isteği: "havai fişeğin saldırı
## hızını %50 azaltıp saldırı gücü oranını %50 arttır hasar alanının
## boyutunu %20 arttır" - fire_rate/card_damage_bonus_ratio bkz.
## weapon_fisek.tscn, buradaki alan 55 -> 66 (+%20, patlama FX'i de
## fx_hit_big_burst.tscn'de aynı oranda büyütüldü).
@export var splash_radius: float = 66.0
@export var impact_scene: PackedScene
@export var impact_sounds: Array[AudioStream] = []
@export var impact_sound_volume_db: float = -8.79

var damage: float = 10.0
var is_crit: bool = false
var shield_pen_percent: float = 0.0
## weapon.gd _fire_at() bunu ateş yönüne göre dolduruyor - target_position
## henüz (0,0) ise (güvenlik durumu) ilk yörünge tahmininde kullanılır,
## gerçek iniş noktası her zaman target_position (aşağıda).
var direction: Vector2 = Vector2.RIGHT
## weapon.gd _fire_at() bunu hedefin ateş anındaki SABİT konumuna ayarlar -
## fişek yolda hedefin öldürülmesi/kaçması gibi durumlardan etkilenmeden hep
## bu noktaya iner (diğer tüm mermiler gibi "ateş anında yakalanan hedef
## konumu" mantığı, bkz. weapon.gd target_pos_at_attack).
var target_position: Vector2 = Vector2.ZERO
## Kafanın üstündeki ikonu havadayken gizleyip inince tekrar gösteren silaha
## geri bildirim - bkz. weapon.gd hide_icon_while_projectile_flying /
## _on_ranged_projectile_landed(). weapon.gd bu bayrağı açmadıkça hiç
## atanmaz, no-op.
var return_callback_target: Node = null

var _launch_position: Vector2
var _apex_position: Vector2
var _elapsed: float = 0.0
var _trajectory_ready: bool = false
var _done: bool = false

@onready var launch_sound: AudioStreamPlayer2D = get_node_or_null("LaunchSound")
@onready var sparkle: AnimatedSprite2D = get_node_or_null("Sparkle")

## fişek ikonu (assets/weapons/fisek/icon.png) zaten doğal olarak yukarı
## (burun yukarıda) çizilmiş - yani hareket yönü tam yukarıyken (Vector2(0,-1))
## rotation 0 olmalı. Vector2(0,-1).angle() == -PI/2 olduğundan, gerçek
## hareket yönünün açısına +PI/2 eklenerek "burun yukarı" sanatına kalibre
## ediliyor (bkz. _rotation_for_tangent).
const ROTATION_CORRECTION := PI / 2.0


func _ready() -> void:
	if sparkle and sparkle.sprite_frames and sparkle.sprite_frames.has_animation("loop"):
		sparkle.play("loop")


## weapon.gd _fire_at() önce add_child() çağırıp SONRA global_position/
## direction/target_position atıyor (bkz. weapon.gd) - bu sıralama diğer tüm
## mermiler için sorun değil çünkü onlar yönü her frame'de canlı okuyor, ama
## fişek eskiden bunu SADECE _ready() içinde bir kere hesaplıyordu - yani
## add_child() sırasında _ready() senkron çalıştığında henüz atanmamış (hâlâ
## varsayılan (0,0)/RIGHT/ZERO) değerlerle tüm yörüngeyi yanlış donduruyordu.
## Bu yüzden yörünge hesabı _ready() yerine ilk _process() tick'ine
## ertelenir - o noktada weapon.gd'nin atamaları kesinlikle tamamlanmış olur.
func _init_trajectory() -> void:
	_trajectory_ready = true
	_launch_position = global_position
	if target_position == Vector2.ZERO:
		target_position = global_position + direction * 300.0
	## Kavisin tepe noktası: ateş/hedef arasında apex_horizontal_bias oranına
	## oturur (varsayılan ateşe yakın), yukarı doğru rise_height kadar
	## kaldırılmış - bu, hem belirgin bir "yukarı fırlama" hem de "hedefin
	## üzerine dik çakılma" hissini TEK, sürekli bir eğride birleştirir.
	_apex_position = _launch_position.lerp(target_position, apex_horizontal_bias) + Vector2(0, -rise_height)
	rotation = _rotation_for_tangent(_bezier_tangent(0.0))
	if launch_sound:
		launch_sound.play()


func _bezier_point(t: float) -> Vector2:
	var u: float = 1.0 - t
	return _launch_position * (u * u) + _apex_position * (2.0 * u * t) + target_position * (t * t)


## Bezier eğrisinin B(t)'nin türevi - o andaki GERÇEK hareket yönü (rotasyon
## bundan hesaplanır, konumdan bağımsız ayrı bir lerp'ten DEĞİL).
func _bezier_tangent(t: float) -> Vector2:
	return (_apex_position - _launch_position) * (2.0 * (1.0 - t)) + (target_position - _apex_position) * (2.0 * t)


func _rotation_for_tangent(tangent: Vector2) -> float:
	if tangent.length() < 0.001:
		return rotation
	return tangent.angle() + ROTATION_CORRECTION


func _process(delta: float) -> void:
	if not _trajectory_ready:
		_init_trajectory()
	if _done:
		return
	_elapsed += delta
	var t: float = clamp(_elapsed / max(0.01, flight_duration), 0.0, 1.0)
	global_position = _bezier_point(t)
	rotation = _rotation_for_tangent(_bezier_tangent(t))

	if t >= 1.0:
		_explode()


func _explode() -> void:
	_done = true
	## Ağ üzerinden spawnlanan görsel kopyalar hasar vermez —
	## sadece darbe efektini ve sesini oynatır.
	if get_meta("network_spawned", false):
		_spawn_impact()
		_play_impact_sound()
		queue_free()
		return
	## Şaman pasifi (Totem Auraları): bu patlama TEK bir "saldırı" sayılır -
	## yakma EN FAZLA 1 düşmanda tetiklenebilir (bkz. enemy.gd
	## try_shaman_weapon_burn() üstündeki kök neden notu).
	var _shaman_burn_applied: bool = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not e.has_method("take_damage"):
			continue
		if global_position.distance_to(e.global_position) <= splash_radius:
			e.take_damage(damage, is_crit, shield_pen_percent)
			if not _shaman_burn_applied and e.has_method("try_shaman_weapon_burn"):
				_shaman_burn_applied = e.try_shaman_weapon_burn()
	_spawn_impact()
	_play_impact_sound()
	if is_instance_valid(return_callback_target) and return_callback_target.has_method("_on_ranged_projectile_landed"):
		return_callback_target._on_ranged_projectile_landed()
	queue_free()


func _spawn_impact() -> void:
	if not impact_scene:
		return
	var fx = impact_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position


func _play_impact_sound() -> void:
	if impact_sounds.is_empty():
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = impact_sounds[randi() % impact_sounds.size()]
	s.volume_db = impact_sound_volume_db
	s.pitch_scale = randf_range(0.92, 1.08)
	s.max_distance = 1500.0
	s.global_position = global_position
	get_tree().current_scene.add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
