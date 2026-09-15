extends Area2D

@export var speed: float = 400.0 ## genel hız ayarı: 500'den %20 düşürüldü
@export var impact_scene: PackedScene
## impact_scene, çarpma anında yaratığın global_position'ında (yani genelde
## AYAK hizasında - collision/hareket orijini çoğu yaratıkta gövdenin
## merkezi değil tabanı) belirir. 0 = eskisi gibi tam o noktada (diğer tüm
## silahler - fire/tabanca/tufek/lightning zaten iyi görünüyor, davranışları
## değişmez). Tüftüf'ün zehir isabet efekti (fx_poison_hit) yaratığın hafif
## altında çıktığı için (bkz. kullanıcı bildirimi) dart_projectile.tscn'de
## yukarı doğru bir düzeltme değeri veriliyor.
@export var impact_offset: Vector2 = Vector2.ZERO
## 0 = only the enemy directly hit takes damage (default). > 0 = area damage:
## every enemy within this radius of the impact point is also hit.
@export var splash_radius: float = 0.0
## true ise mermi, saldırı yönüne göre döner (bkz. weapon.gd _fire_at) -
## düz ColorRect'li mermilerde fark etmez, yönlü bir sprite kullanan
## mermilerde (ör. Büyücü Kız'ın büyü mermisi) gereklidir.
@export var face_direction: bool = false
## true ise "impact" animasyonu, uçuş rotasyonunun tam 180° tersinde çizilir
## - mermi çarpıp geri patlamış gibi görünür (ör. Büyücü Kız'ın patlaması).
@export var impact_rotation_flip: bool = false

## Çarpma anında bu listeden RASTGELE biri çalınır (ör. Tabanca'nın 7 farklı
## "et'e mermi isabeti" sesi) - boşsa hiçbir şey çalmaz. Ses, mermi çarpma
## anında hemen queue_free() olsa bile kesilmeden bitirebilsin diye mermiye
## değil sahnenin köküne (get_tree().current_scene) bağlı, bağımsız bir
## AudioStreamPlayer2D olarak çalınır - bkz. _play_impact_sound().
@export var impact_sounds: Array[AudioStream] = []
@export var impact_sound_volume_db: float = -8.79

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var is_crit: bool = false
var shield_pen_percent: float = 0.0
var knockback_force: float = 0.0 ## Talon'un öfkesinden VEYA Kitelama Seti eşyasının itme gücünden gelir (bkz. weapon.gd _fire_at) - diğer durumlarda 0, no-op.
## Kitelama Seti pasifi (bkz. items.gd/enemy.gd apply_slow) - weapon.gd
## _fire_at tarafından knockback_force ile birebir aynı şekilde atanır. 0 =
## bu mermiyi ateşleyen oyuncunun bu eşyası yok (no-op, diğer tüm mermiler).
var slow_percent: float = 0.0
var slow_duration: float = 5.0

## Tüftüf'ün zehiri (bkz. weapon.gd poison_tick_damage/poison_ramp_per_tick/
## poison_duration) - 0 = bu mermi zehir uygulamaz (diğer tüm mermiler).
var poison_tick_damage: float = 0.0
var poison_ramp_per_tick: float = 0.0
var poison_duration: float = 0.0

## Tüfeğin delici mermisi: birincil hedeften (her zaman TAM hasar
## alır) sonra pierce_count kadar EK düşmana daha çarpar, her ek isabette
## hasar pierce_damage_percent'e düşer. 0 = delmez (diğer tüm mermiler) -
## bkz. weapon.gd.
var pierce_count: int = 0
var pierce_damage_percent: float = 0.3
var _hit_bodies: Array = [] ## aynı düşmana iki kez çarpmasın diye

## Tabanca'nın "yük" (mark) mekaniği: hedefte biriken yük sayısının azami
## tavanı (0 = bu mermi mark uygulamaz, diğer tüm mermiler) - bkz.
## weapon.gd mark_max_stacks, enemy.gd apply_mark_stack/get_mark_damage_mult.
var mark_max_stacks: int = 0

## Buz Asası'nın donma mekaniği: etkinse her isabette hedefi dondurur
## (0 = bu mermi donma uygulamaz) - bkz. enemy.gd apply_chill.
var chill_stacks: int = 0

## Arcane Asası pasifi: bu mermiyi ateşleyen weapon.gd düğümü - hedef bu
## mermiyle ölürse notify_kill() ile bildirilir (bkz. _on_body_entered sonu).
## null veya "notify_kill" metodu olmayan her şeyde no-op (diğer tüm mermiler).
var source_weapon: Node = null

@onready var color_rect: ColorRect = get_node_or_null("ColorRect")
## Opsiyonel: düz renkli ColorRect yerine kare kare oynayan bir
## AnimatedSprite2D kullanan mermiler için (ör. Büyücü Kız). "fly"
## animasyonu uçuş başında oynar - döngüsüzse (loop:false) biterse son
## karesinde donup kalır, döngülüyse (loop:true, ör. Arcane Asası) mermi
## hedefe varana kadar sürekli tekrar eder (bkz. "appear" aşağıda - böylece
## mermi yok oluyormuş gibi görünen bir "sönme" karesinde takılı kalmaz).
## "impact" (varsa) çarpma anında bir kez oynatılıp bittiğinde mermi yok
## olur. Bu animasyonlar yoksa davranış eskisiyle birebir aynıdır (anında
## yok olma).
## "appear" (opsiyonel, ör. Arcane Asası'nın büyü parlaması): varsa "fly"
## yerine ÖNCE bir kez oynar, bitince otomatik "fly"a geçilir - böylece
## "başlangıç" görseli sadece atışın en başında (bir kerelik) görünür,
## atış hâlâ yoldayken tekrar tekrar oynamaz/görünmez (bkz. _on_appear_
## finished).
@onready var anim: AnimatedSprite2D = get_node_or_null("Anim")

var _impacted: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(self): queue_free())
	if is_crit:
		if color_rect:
			color_rect.color = Color(1.0, 0.35, 0.15, 1.0)
		scale *= 1.4

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("appear"):
		anim.animation_finished.connect(_on_appear_finished, CONNECT_ONE_SHOT)
		anim.play("appear")
	elif anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")


## "appear" bitince (ör. Arcane büyü parlaması) - mermi bu sırada hedefe
## çarpıp "impact"e geçmediyse (bkz. _impacted) sürekli tekrar eden "fly"
## animasyonuna geçilir; çarpma "appear" bitmeden gerçekleştiyse (çok yakın
## mesafe) bu callback zaten "impact" oynatılmışken tetiklenir, _impacted
## kontrolü onu ezmesini engeller.
func _on_appear_finished() -> void:
	if _impacted:
		return
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if _impacted:
		return
	## Network-spawned projectiles are visual-only — the host's own projectile
	## handles the actual damage authoritatively.
	if get_meta("network_spawned", false):
		_spawn_impact()
		_play_impact_sound()
		_finish_or_play_impact()
		return
	if not is_instance_valid(body) or not (body.is_in_group("enemies") and body.has_method("take_damage")):
		return
	if _hit_bodies.has(body):
		return
	_hit_bodies.append(body)
	## Mermi, hitbox'ların çakıştığı kenarda değil, yaratığın tam
	## merkezinde patlasın diye çarpma anında yaratığın konumuna
	## ışınlanır - görsel efekt (ve varsa impact_scene) hep buradan
	## çizilir, "hitbox'a değme" değil "yaratığın üstü" hissi verir.
	if body is Node2D:
		global_position = body.global_position
	## Delici mermi (Tüfek): BİRİNCİL hedef (ilk çarpılan düşman) her zaman
	## tam hasar alır, mermi onu delip geçtikten sonra vurduğu her düşman
	## pierce_damage_percent kadarını alır.
	var is_primary_hit: bool = _hit_bodies.size() == 1
	var hit_damage: float = damage if is_primary_hit else damage * pierce_damage_percent
	## Tabanca: bu hedefte ÖNCEDEN birikmiş yük varsa (önceki isabetlerden)
	## bu vuruşa hemen uygulanır, SONRA yeni bir yük eklenir (bkz. enemy.gd) -
	## yani ilk isabet hiç bonus almaz, N'inci isabet (N-1) yük kadar bonus alır.
	if mark_max_stacks > 0 and body.has_method("get_mark_damage_mult"):
		hit_damage *= body.get_mark_damage_mult()
	body.take_damage(hit_damage, is_crit, shield_pen_percent)
	## Arcane Asası pasifi: take_damage() ölümcülse ÖLÜME kadar tamamen
	## senkron çalışır (bkz. enemy.gd take_damage/die - yield/await yok), bu
	## yüzden hemen ardından is_dead kontrolü güvenilir bir "bu vuruş öldürdü
	## mü" testi. source_weapon null/notify_kill'siz her mermide no-op.
	if body.get("is_dead") == true and is_instance_valid(source_weapon) \
			and source_weapon.has_method("notify_kill"):
		source_weapon.notify_kill()
	if mark_max_stacks > 0 and body.has_method("apply_mark_stack"):
		body.apply_mark_stack(mark_max_stacks)
	if chill_stacks > 0 and body.has_method("apply_chill"):
		body.apply_chill(chill_stacks)
	if poison_tick_damage > 0.0 and body.has_method("apply_poison"):
		body.apply_poison(poison_tick_damage, poison_ramp_per_tick, poison_duration)
	if slow_percent > 0.0 and body.has_method("apply_slow"):
		body.apply_slow(slow_percent, slow_duration)
	_apply_knockback(body)
	if splash_radius > 0.0:
		_apply_splash_damage(body)
	_spawn_impact()
	_play_impact_sound()
	## Hâlâ delme hakkı varsa (pierce_count kadar EK düşman) mermi hiç
	## durmadan yoluna devam eder - impact animasyonu oynatılmaz/yok
	## olmaz, sadece pierce_count tükenince gerçek çarpma sonlanır.
	if _hit_bodies.size() <= pierce_count:
		return
	_finish_or_play_impact()


func _apply_knockback(target: Node2D) -> void:
	if knockback_force <= 0.0 or not is_instance_valid(target):
		return
	## NOT: target.global_position - global_position BURADA KULLANILMAZ -
	## _on_body_entered çarpma anında merminin global_position'ını zaten
	## hedefle BİREBİR AYNI noktaya taşıyor (bkz. yukarısı), bu da farkı her
	## zaman sıfır (yönsüz) vektöre indirip itmeyi tamamen etkisiz
	## kılıyordu (bkz. kullanıcı bildirimi: "itme gücü vermiyor, yaratıkları
	## geri itmiyor"). Bunun yerine merminin UÇUŞ YÖNÜ (direction) kullanılır -
	## hedefi merminin gittiği yöne doğru iter, ki zaten görsel/fiziksel
	## olarak beklenen davranış budur.
	var dir: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	## Artık anında ışınlama değil - enemy.gd'nin kendi yumuşak/sönümlenen
	## itiş sistemine devrediliyor (bkz. enemy.gd apply_knockback_force).
	if target.has_method("apply_knockback_force"):
		target.apply_knockback_force(dir, min(knockback_force, 400.0))
	else:
		target.global_position += dir * min(knockback_force, 400.0)


func _apply_splash_damage(direct_hit: Node) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == direct_hit or not is_instance_valid(e):
			continue
		if not e.has_method("take_damage"):
			continue
		if global_position.distance_to(e.global_position) <= splash_radius:
			e.take_damage(damage, is_crit, shield_pen_percent)


func _spawn_impact() -> void:
	if not impact_scene:
		return
	var fx = impact_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + impact_offset


## impact_sounds doluysa aralarından rastgele birini seçip çalar - mermi
## çarptığı anda kendisi hemen yok olabildiği için ses, mermiye değil doğrudan
## sahnenin köküne bağlı ayrı bir AudioStreamPlayer2D olarak çalınır, böylece
## kesilmeden bitene kadar çalmaya devam eder ve sonra kendini serbest bırakır.
func _play_impact_sound() -> void:
	if impact_sounds.is_empty():
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = impact_sounds[randi_range(0, impact_sounds.size() - 1)]
	s.volume_db = impact_sound_volume_db
	s.pitch_scale = randf_range(0.92, 1.08)
	s.max_distance = 1500.0
	s.global_position = global_position
	get_tree().current_scene.add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## Yaratığa çarpınca: animasyonlu mermi ise hareketi durdurup "impact"
## animasyonunu bir kez oynatır ve bitince yok olur; yoksa eskisi gibi
## anında yok olur.
func _finish_or_play_impact() -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("impact"):
		_impacted = true
		monitoring = false
		if color_rect:
			color_rect.visible = false
		if impact_rotation_flip:
			## Anim'in kendi (yerel) rotasyonuna 180° eklenir - toplam
			## (parent + local) rotasyon, uçuş rotasyonunun tam tersi olur.
			anim.rotation += PI
		anim.animation_finished.connect(queue_free)
		anim.play("impact")
	else:
		queue_free()
