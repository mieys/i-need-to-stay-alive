extends Area2D

## Boomerang: normal projectile.gd'nin aksine çarpınca YOK OLMAZ - önce
## throw_distance kadar dümdüz gider, sonra fırlatan oyuncunun GÜNCEL
## (hareket ediyor olabilir) konumuna geri döner. Hem giderken hem dönerken
## yoluna çıkan her düşmana bir kez hasar verir (bkz. _hit_this_leg - gidiş
## ve dönüş AYRI birer "leg" sayılır, aynı düşman iki legde de ayrı ayrı
## vurulabilir ama TEK bir leg içinde aynı düşmana iki kez çarpmaz).
##
## GÖRSEL SİSTEM: Bullet (asıl boomerang sprite'ı) kafadaki ikonla BİREBİR
## AYNI ölçekte (0.4125), sürekli dönüyor (spin_speed_deg) ve fırlatma anında
## sadece kendi ölçeğini oynatan kısacık bir Tween "punch" efekti alıyor
## (bkz. _play_launch_punch).
##
## SpinFx (bulanıklık/iz efekti, 48x48 kare sayfası, bkz. spin_frames.tres
## "trail" animasyonu): ESKİDEN "loop=false" idi - BİR KEZ oynayıp SON
## KAREDE donuyordu ve hiçbir şey onu gizlemediği için tüm uçuş boyunca
## (hem gidiş hem dönüş) ekranda donuk kalıyordu (kullanıcı bunu "hep
## kocaman duruyor" olarak bildirmişti - asıl suçlu buydu, Bullet değil).
## Bu yüzden önceki düzeltme SpinFx'i sahneden TAMAMEN kaldırmıştı, ama bu
## da bumerangın spin/bulanıklık efektini tamamen kaybetmesine yol açtı.
## Doğru çözüm: spin_frames.tres'te "trail" artık loop=true (bkz. o
## dosya) - SpinFx _ready()'de play("trail") ile başlatılıyor ve mermi
## havada olduğu SÜRECE (Bullet ile birlikte, aynı köke child olarak)
## sürekli döngüde kalıyor; mermi _finish()'te queue_free() ile silinince
## SpinFx de onunla birlikte otomatik temizleniyor - "donup ekranda kalma"
## hatasına yapısal olarak kapalı. Ölçeği (1.72) Bullet'inkiyle (0.4125,
## 200px doku üzerinden) aynı görsel büyüklüğü hedefleyecek şekilde
## hesaplandı (48px doku * 1.72 ≈ 200px * 0.4125) - kafadaki ikondan daha
## büyük görünmesin diye.
##
## KUYRUKLU YILDIZ İZİ (Trail1/2/3, bkz. TRAIL_FOLLOW_SPEEDS): kullanıcı
## isteği "bu efektin (SpinFx) arkasından büyükken küçülen 3-4 tane olsun,
## kuyruklu yıldız gibi iz bıraksın". Trail1/2/3 SpinFx'in AYNI "trail"
## animasyonunu kullanır ama gittikçe küçülen ölçek (1.32 -> 0.92 -> 0.55)
## ve azalan opaklıkla (0.6 -> 0.38 -> 0.2) art arda dizilmiştir. Bunlar
## normal child OLSAYDI (top_level=false) ana gövdeyle birebir aynı anda
## hareket ederdi, hiç "geride kalmış" görünmezdi - bu yüzden top_level=true
## (weapon.gd'nin silah ikonu takip mantığıyla aynı teknik) ve HER karede
## _update_trail() içinde ana gövdenin konumuna doğru (her halka kendi
## hızında) lerp'lenerek GERÇEKTEN geride sürüklenen, dönüş anlarında
## (throw_distance sonunda geri dönerken) belirgin şekilde "kuyruk" çizen
## bir iz oluşturuyor.

@export var speed: float = 460.0
@export var throw_distance: float = 360.0
@export var spin_speed_deg: float = 900.0
@export var impact_scene: PackedScene
@export var impact_offset: Vector2 = Vector2.ZERO
@export var impact_sounds: Array[AudioStream] = []
@export var impact_sound_volume_db: float = -8.79
## Her isabette sesin pitch'ine eklenen KÜÇÜK rastgele sapma (±%8).
## Kullanıcı isteği: "ufak pitch değişimleri de ekle yoksa aynı ses sıkıcılığı
## olur" - tek bir kayıt art arda birebir aynı çalınınca (boomerang hem giderken
## hem dönerken vurabildiği için isabetler sık) kulak tırmalıyordu. Değeri
## büyütmek sapmayı belirginleştirir (ör. 0.15 = belirgin perde farkı).
@export var impact_pitch_jitter: float = 0.08
## Dönüş bacağında oyuncuya bu kadar yakınlaşınca "geri döndü" sayılır ve
## kendini serbest bırakır.
@export var return_arrival_distance: float = 24.0
## Fırlatma anındaki "punch" büyümesinin çarpanı ve süresi - sadece Bullet'in
## KENDİ ölçeğini oynatır, ayrı bir sprite/asset gerektirmez.
@export var launch_punch_scale_mult: float = 1.35
@export var launch_punch_duration: float = 0.14

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
## Efsun (bkz. weapon.gd enchant_on_*): isabet/uç nokta/yakalama bildirimleri. apex_pause > 0 = bumerang en uzak
## noktada bu kadar sn dönerek durur (Kasırga Bumerang) - uzak kopyaya EnchantFx.apply_projectile_look ile gelir.
var source_weapon: Node = null
var apex_pause: float = 0.0
var _pause_left: float = 0.0
var _pause_clear: float = 0.0
var _apex_done: bool = false
var is_crit: bool = false
var shield_pen_percent: float = 0.0

## weapon.gd bu ikisini _fire_at()'te doldurur (bkz. single_active_projectile).
var return_callback_target: Node = null
var player_node: Node2D = null

var _traveled: float = 0.0
var _returning: bool = false
var _hit_this_leg: Array = []

## Şaman pasifi (Totem Auraları): bu FIRLATMANIN TÜMÜ (gidiş + dönüş legi
## birlikte) TEK bir "saldırı" sayılır - yakma bu bumerang atışı başına EN
## FAZLA 1 düşmanda tetiklenebilir (bkz. enemy.gd try_shaman_weapon_burn()
## üstündeki kök neden notu). Leg değişince SIFIRLANMAZ (_hit_this_leg'in
## aksine) - iki leg birlikte tek saldırı.
var _shaman_burn_used: bool = false

@onready var bullet: Sprite2D = get_node_or_null("Bullet")
@onready var spin_fx: AnimatedSprite2D = get_node_or_null("SpinFx")
## Bullet'in kafadaki ikonla aynı "dinlenme" ölçeği (.tscn'den okunur) -
## launch-punch tween'i bu değerin üzerine kısaca binip geri buna döner.
var _base_bullet_scale: Vector2 = Vector2.ONE

## Kuyruklu yıldız izi halkaları - top_level=true olduğu için global_position'ları
## OTOMATİK takip etmiyorlar, bkz. _update_trail(). Her halka bir öncekinden
## daha YAVAŞ takip eder (küçük follow speed = daha fazla geride kalma), bu
## da gittikçe geriye sarkan bir kuyruk hissi veriyor.
@onready var _trail_nodes: Array = [
	get_node_or_null("Trail1"),
	get_node_or_null("Trail2"),
	get_node_or_null("Trail3"),
]
const TRAIL_FOLLOW_SPEEDS := [22.0, 14.0, 9.0] ## büyük = az gecikme (ön), küçük = çok gecikme (kuyruk ucu)

## YENİ GÖRÜNÜM (kullanıcı isteği 2026-09-24: "boomerangın görünüşünü yeniden tasarla (ikonuyla boomerangın oyun içi
## görüntüsü aynı olmalı)" + "kılıç ve boomerang silahlarına özel çalışma biçimlerine uygun yeni özel efektler" + "pixel
## sanatı ... spritesheet"): tools/gen_weapon_fx_sprites.py 48x48 bir bumerang çizer; icon.png onun TAM 4x büyütülmüşü,
## burada da AYNI çizimin 12 önceden döndürülmüş karesi (RotSprite) kullanılır - kare dönüş açısına göre SEÇİLİR, sprite
## kendisi döndürülmez (piksel ızgarası bozulmasın). SpinFx artık bumerangın etrafında dönen hava çizgileri; Trail1/2/3
## (kuyruklu yıldız) artık beyaz girdap değil, AYNI bumerangın küçülerek solan "hayalet" kopyaları. Geri yakalanınca
## kısa bir parıltı. Eski Bullet (icon.png'nin kendisi, düz döndürülen) gizlenir.
const RotFrames := preload("res://assets/weapons/boomerang/rot_frames.tres")
const WhooshFrames := preload("res://assets/fx/boomerang/whoosh_frames.tres")
const CatchFrames := preload("res://assets/fx/boomerang/catch_frames.tres")
const ROT_STEPS := 12
const BODY_SCALE := 1.5 ## dünya birimi / sanat pikseli (eski bumerangla ~aynı ekran boyu)
const WHOOSH_SCALE := 1.45
const GHOST_SCALES := [0.8, 0.62, 0.45] ## Trail1/2/3 - gövdeye göre
const GHOST_TINT := Color(1.0, 0.9, 0.75)
var _body: AnimatedSprite2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	## Oyuncu ölür/sahneden ayrılır gibi olağandışı bir durumda sonsuza kadar
	## havada asılı kalmasın diye bir güvenlik zaman aşımı.
	get_tree().create_timer(6.0).timeout.connect(_on_timeout)
	if bullet:
		bullet.visible = false ## bkz. "YENİ GÖRÜNÜM" notu
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = RotFrames
	_body.animation = &"spin"
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.scale = Vector2.ONE * BODY_SCALE
	add_child(_body)
	_base_bullet_scale = _body.scale
	_play_launch_punch()
	if spin_fx:
		spin_fx.sprite_frames = WhooshFrames
		spin_fx.scale = Vector2.ONE * WHOOSH_SCALE
		spin_fx.play("loop")
	for i in range(_trail_nodes.size()):
		var tn: AnimatedSprite2D = _trail_nodes[i]
		if tn:
			tn.sprite_frames = RotFrames
			tn.animation = &"spin"
			tn.stop()
			tn.scale = Vector2.ONE * BODY_SCALE * float(GHOST_SCALES[mini(i, GHOST_SCALES.size() - 1)])
			tn.modulate = Color(GHOST_TINT.r, GHOST_TINT.g, GHOST_TINT.b, tn.modulate.a)
	## SpinFx artık DÖNGÜLÜ (bkz. spin_frames.tres "trail" loop=true) - mermi
	## havada olduğu sürece sürekli oynar, _finish()'te projeyle birlikte
	## queue_free() olur. "Bir kez oynayıp donma" hatası artık mümkün değil.
	## Kuyruk halkaları top_level=true olduğu için _ready() anında henüz
	## (0,0) dünya konumundalar - hemen fırlatma noktasına ışınlanmazsa ilk
	## karede ekranın orta noktasından mermiye doğru "kayan" bir çizgi
	## görünür (bkz. _update_trail). Burada konumu bir kez eşitleyip
	## animasyonlarını başlatıyoruz.
	for t in _trail_nodes:
		if t:
			t.global_position = global_position


## Fırlatma anında kısacık bir büyü-küçül "punch" - Bullet'in KENDİ
## ölçeğini Tween'ler, ayrı bir sprite/asset oluşturmaz. Tween otomatik
## temizlendiği için SpinFx'teki gibi "donup ekranda kocaman kalma" hatasına
## yapısal olarak kapalıdır.
func _play_launch_punch() -> void:
	if _body == null:
		return
	_body.scale = _base_bullet_scale * launch_punch_scale_mult
	var tw := create_tween()
	tw.tween_property(_body, "scale", _base_bullet_scale, launch_punch_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	rotation += deg_to_rad(spin_speed_deg) * delta
	## SpinFx zaten KENDİ animasyon karelerinde (spin_frames.tres "trail",
	## 6 kareli döngüsel bir dönüş bulanıklığı) dönüşü gösteriyor - normal
	## (top_level=false) bir child olduğu için üstteki satırın döndürdüğü
	## Bullet/Area2D'nin rotation'ını OTOMATİK olarak da miras alıyordu, yani
	## dönüş iki kez üst üste biniyordu (kare animasyonu + gerçek node
	## rotasyonu) - bu da "spin efekti glitchleniyor/titriyor" olarak
	## bildirilen buga sebep oluyordu. Üst node'un rotasyonunu burada iptal
	## ederek SpinFx'in görsel dönüşünü SADECE kendi animasyon karelerine
	## bırakıyoruz.
	if spin_fx:
		spin_fx.rotation = -rotation
	## Dönüş: kare açıya göre seçilir, gövde düz tutulur (bkz. "YENİ GÖRÜNÜM" notu). Hayaletler bir-iki kare geriden gelir.
	var rot_frame: int = int(fposmod(rotation, TAU) / TAU * float(ROT_STEPS)) % ROT_STEPS
	if _body:
		_body.rotation = -rotation
		_body.frame = rot_frame
	for i in range(_trail_nodes.size()):
		if _trail_nodes[i]:
			(_trail_nodes[i] as AnimatedSprite2D).frame = (rot_frame - i - 1 + ROT_STEPS) % ROT_STEPS
	if _pause_left > 0.0:
		## Uç noktada duraklama: aynı düşmanları tekrar tekrar keser (1/3 sn'de bir).
		_pause_left -= delta
		_pause_clear -= delta
		if _pause_clear <= 0.0:
			_pause_clear = 0.33
			_hit_this_leg.clear()
		_update_trail(delta)
		return
	if not _returning:
		position += direction * speed * delta
		_traveled += speed * delta
		if _traveled >= throw_distance:
			_returning = true
			_hit_this_leg.clear()
			if not _apex_done:
				_apex_done = true
				if apex_pause > 0.0:
					_pause_left = apex_pause
					_pause_clear = 0.33
				if not get_meta("network_spawned", false) and is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_boomerang_apex"):
					source_weapon.enchant_on_boomerang_apex(self)
		_update_trail(delta)
		return
	if not is_instance_valid(player_node):
		_finish()
		return
	var to_player: Vector2 = player_node.global_position - global_position
	if to_player.length() <= return_arrival_distance:
		_finish()
		return
	direction = to_player.normalized()
	position += direction * speed * delta
	_update_trail(delta)


## Her kuyruk halkasını, ana gövdenin GÜNCEL konumuna doğru kendi hızında
## lerp'ler - bkz. TRAIL_FOLLOW_SPEEDS. top_level=true olduğu için
## global_position'ları otomatik güncellenmiyor, elle sürüklüyoruz.
## Rotasyonu da senkron tutuyoruz ki dönen bulanıklık dokusu tutarlı
## görünsün (aksi halde hep 0° sabit kalırdı).
func _update_trail(delta: float) -> void:
	for i in range(_trail_nodes.size()):
		var t = _trail_nodes[i]
		if not t:
			continue
		var speed_factor: float = TRAIL_FOLLOW_SPEEDS[i] if i < TRAIL_FOLLOW_SPEEDS.size() else 10.0
		t.global_position = t.global_position.lerp(global_position, clamp(speed_factor * delta, 0.0, 1.0))
		## Kuyruk halkaları da (SpinFx gibi) dönüşü KENDİ animasyon
		## karelerinden alıyor - buraya ayrıca ana gövdenin rotation'ını
		## yazmak aynı "çift dönüş" glitch'ine yol açıyordu, bu yüzden
		## kaldırıldı (bkz. _physics_process'teki SpinFx notu).


func _on_timeout() -> void:
	if is_instance_valid(self):
		_finish()


## Mermi oyuncuya ulaşınca (veya güvenlik zaman aşımında) çağrılır - weapon.gd'ye
## "havadaki mermi bitti, yeni atışa izin ver" bilgisini verir.
func _finish() -> void:
	_spawn_catch_sparkle()
	if get_meta("network_spawned", false):
		# Network copies: skip callback, just clean up
		queue_free()
		return
	if is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_boomerang_caught"):
		source_weapon.enchant_on_boomerang_caught(self)
	if is_instance_valid(return_callback_target) and return_callback_target.has_method("_on_boomerang_returned"):
		return_callback_target._on_boomerang_returned()
	queue_free()


## Geri yakalanma parıltısı (pişirilmiş 6 kare, tek sefer) - yakalayan oyuncunun üstünde. Hem gerçek hem kozmetik
## (diğer istemcilerdeki) mermide oynar, ikisi de _finish'ten geçer.
func _spawn_catch_sparkle() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = CatchFrames
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.scale = Vector2.ONE * 1.212
	fx.z_index = 20
	get_tree().current_scene.add_child(fx)
	fx.global_position = (player_node.global_position if is_instance_valid(player_node) else global_position) + Vector2(0, -10)
	fx.play("play")
	fx.animation_finished.connect(fx.queue_free)


func _on_body_entered(body: Node) -> void:
	## Ağ üzerinden spawnlanan görsel kopyalar hasar vermez —
	## sadece darbe efektini ve sesini oynatır.
	if get_meta("network_spawned", false):
		_spawn_impact()
		_play_impact_sound()
		return
	if not is_instance_valid(body) or not (body.is_in_group("enemies") and body.has_method("take_damage")):
		return
	if _hit_this_leg.has(body):
		return
	_hit_this_leg.append(body)
	body.take_damage(damage, is_crit, shield_pen_percent)
	if is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_projectile_hit"):
		source_weapon.enchant_on_projectile_hit(self, body, damage, not _returning)
	if not _shaman_burn_used and body.has_method("try_shaman_weapon_burn"):
		_shaman_burn_used = body.try_shaman_weapon_burn()
	_spawn_impact()
	_play_impact_sound()


func _spawn_impact() -> void:
	if not impact_scene:
		return
	var fx = impact_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + impact_offset


## impact_sounds doluysa aralarından rastgele birini seçip çalar (şu an tek
## ses: "boomerang isabet"). Mermi, çarptığı anda kendisi hemen yok olabildiği
## için ses mermiye değil doğrudan sahne köküne bağlı ayrı bir
## AudioStreamPlayer2D olarak çalınır - böylece kesilmeden bitene kadar çalar
## ve sonra kendini serbest bırakır (bkz. projectile.gd'deki aynı desen).
## Her seferinde küçük bir pitch sapması uygulanır (bkz. impact_pitch_jitter).
func _play_impact_sound() -> void:
	if impact_sounds.is_empty():
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = impact_sounds[randi() % impact_sounds.size()]
	s.volume_db = impact_sound_volume_db
	s.pitch_scale = randf_range(1.0 - impact_pitch_jitter, 1.0 + impact_pitch_jitter)
	s.max_distance = 1500.0
	s.global_position = global_position
	get_tree().current_scene.add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
