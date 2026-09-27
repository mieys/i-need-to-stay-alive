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

## 2026-09-26 (kullanıcı: "boomerangın gidip gelme animasyonu çok göz yoruyor ve güzel görünmüyor ayrıca boyutu çok büyüyor
## fırlatınca, bu arada boomerang artık birimlerin içinden geçememeli çarpıp geri dönmeli ve hızlı dönerse tekrar
## fırlatılabilmeli. gidiş dönüş hızını düşür"):
##  - ÇARPIP DÖNER: gidişte İLK düşmana vurunca hemen geri döner (_begin_return - "uç nokta" kancaları da orada tetiklenir,
##    Kasırga'nın durması çarptığı yerde olur). Dönüşte HİÇ vurmaz (soru-cevapta seçildi) - sadece uç noktada durma
##    (apex_pause) sırasında vurur. Yakın düşmana çarpınca çabuk döner ve weapon.gd bir sonraki FireTimer tikinde yeniden
##    fırlatır. Diğer istemcilerdeki kozmetik kopya da düşmana değince aynı şekilde döner.
##  - SAKİN GÖRÜNÜM: 24 karelik (15 derece) dönüş sayfası (eskisi 12 kare/30 derece, hızlı dönüşte titriyordu), dönüş hızı
##    sahnede 900 -> 480 derece/sn, etrafındaki hava çizgileri (SpinFx) ve 3 hayaletten ikisi kaldırıldı (tek soluk
##    hayalet kalır), uca yaklaşırken yavaşlayıp dönüşte yeniden hızlanır (ani ters dönüş yok).
##  - BOYUT: gövde artık kafadaki ikonla BİREBİR aynı boyda (BODY_SCALE, eskiden ~%20 büyüktü) ve fırlatma anındaki 1.35x
##    "punch" büyümesi kaldırıldı.

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

## Hız eğrisi (bkz. dosya başı 2026-09-26 notu): gidişte uca yaklaştıkça hız APEX_SPEED_MIN'e iner (t^2 - başta tam hız),
## dönüşte RETURN_RAMP_TIME içinde tekrar tam hıza çıkar.
const APEX_SPEED_MIN := 0.35
const RETURN_RAMP_TIME := 0.3
var _return_ramp: float = 1.0

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
const RotFrames := preload("res://assets/weapons/boomerang/rot24_frames.tres")
const CatchFrames := preload("res://assets/fx/boomerang/catch_frames.tres")
const ROT_STEPS := 24
## Sanat pikseli başına ölçek - kafadaki ikonla AYNI: icon.png = art48 x4, weapon_boomerang.tscn Icon ölçeği (ICON_SCALE) x 0.9
## (weapon.gd menzilli-olmayan silah küçültmesi) x ICON_SIZE_MULT; ikisi de karakterin kök ölçeğiyle çarpılır (weapon.gd
## _fire_at proj.scale). 2026-09-26 (kullanıcı: "boyutunu da %20 küçült çok büyük görünüyor karakterin üstündeyken bile"):
## ikon 0.4125 -> 0.33 - ICON_SCALE sahnedeki değerle AYNI kalmalı (test_boomerang_bounce.gd kontrol eder).
const ICON_SCALE := 0.33
const BODY_SCALE := ICON_SCALE * 0.9 * WeaponOrbitMath.ICON_SIZE_MULT * 4.0
## Tek soluk hayalet (Trail1) - Trail2/3 gizli.
const GHOST_SCALE := 0.85
const GHOST_ALPHA := 0.28
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
	if spin_fx:
		spin_fx.visible = false ## hava çizgileri kaldırıldı (göz yoruyordu)
	for i in range(_trail_nodes.size()):
		var tn: AnimatedSprite2D = _trail_nodes[i]
		if tn:
			tn.sprite_frames = RotFrames
			tn.animation = &"spin"
			tn.stop()
			tn.visible = false ## Trail1 ilk _update_trail'de (ölçeği doğru kurulunca) görünür olur; Trail2/3 hep gizli
			tn.modulate = Color(GHOST_TINT.r, GHOST_TINT.g, GHOST_TINT.b, GHOST_ALPHA)
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
		var t: float = clampf(_traveled / maxf(1.0, throw_distance), 0.0, 1.0)
		var step: float = speed * lerpf(1.0, APEX_SPEED_MIN, t * t) * delta
		position += direction * step
		_traveled += step
		if _traveled >= throw_distance:
			_begin_return()
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
	_return_ramp = minf(1.0, _return_ramp + delta / RETURN_RAMP_TIME)
	var ease_out: float = 1.0 - (1.0 - _return_ramp) * (1.0 - _return_ramp)
	position += direction * speed * lerpf(APEX_SPEED_MIN, 1.0, ease_out) * delta
	_update_trail(delta)


## Gidiş bitti: en uzak noktaya varıldı YA DA bir düşmana çarpıldı. "Uç nokta" efsun kancaları (Kasırga durması, Çift
## Bumerang bölünmesi, Yıldırım/Alev hattının ucu) burada. Çarpma anı fizik sinyalinin içinde olduğu için yeni mermi
## doğuran kanca ertelenir (sinyal sırasında Area2D eklemek engellenir).
func _begin_return() -> void:
	if _returning:
		return
	_returning = true
	_return_ramp = 0.0
	_hit_this_leg.clear()
	if _apex_done:
		return
	_apex_done = true
	if apex_pause > 0.0:
		_pause_left = apex_pause
		_pause_clear = 0.33
	if not get_meta("network_spawned", false) and is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_boomerang_apex"):
		Callable(source_weapon, "enchant_on_boomerang_apex").call_deferred(self)


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
		## top_level olduğu için kökün ölçeğini (weapon.gd _fire_at: karakterin 0.5 kök ölçeği x efsun boyutu) MİRAS
		## ALMAZ - eskiden hayaletler gövdenin ~2 katı büyük çiziliyordu (2026-09-26 "fırlatınca boyutu çok büyüyor"un bir
		## parçası). Ölçek _ready'de değil burada: weapon.gd kökün ölçeğini add_child'dan SONRA ayarlıyor.
		t.global_scale = Vector2.ONE * BODY_SCALE * GHOST_SCALE * absf(global_scale.x)
		t.visible = i == 0
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
	if not is_instance_valid(body) or not body.is_in_group("enemies"):
		return
	## Dönüşte vurmaz (bkz. dosya başı 2026-09-26 notu) - sadece uç noktada dururken (Kasırga) keser.
	var pausing: bool = _pause_left > 0.0
	if _returning and not pausing:
		return
	## Ağ üzerinden spawnlanan görsel kopyalar hasar vermez — sadece darbe efektini/sesini oynatır ve gerçek bumerang gibi
	## çarptığı yerden döner.
	if get_meta("network_spawned", false):
		_spawn_impact()
		_play_impact_sound()
		if not _returning:
			_begin_return()
		return
	if not body.has_method("take_damage"):
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
	## Birimlerin içinden geçmez: gidişte çarptığı ilk düşmandan geri döner.
	if not _returning:
		_begin_return()


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
