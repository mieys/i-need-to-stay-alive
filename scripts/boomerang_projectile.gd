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
## Efsun anahtarları (2026-09-30 yeni set - enchant_fx.gd apply_projectile_look "props" ile HEM kasterde HEM uzak kopyada):
##  enchant_pierce_all - gidişte düşmanlardan dönmez, içlerinden geçer (BIGerang)
##  enchant_grow / enchant_grow_max - isabet başına TOPLAMALI büyüme ve tavanı (gidiş + dönüş); enchant_grow_start - atışın
##    başlangıç boyutu (BIGerang büyüklüğü atıştan atışa taşır); enchant_size_dmg - hasar x (1 + (boyut-1) x bu);
##    enchant_out_speed_mult - gidiş hız çarpanı; enchant_titan - Final (girdap bu bayrağa + is_grown_max'a bakar)
##  hit_on_return / return_crit - dönüşte de (düşman başına bir kez) vurur, kesin kritik (Bumerang Testeresi Finali)
##  pause_hits - uç nokta duraklamasında bumerangın kendi vuruşları (false: testere hasarını efsun veriyor, çift sayılmasın)
var enchant_pierce_all: bool = false
var enchant_grow: float = 0.0
var enchant_grow_max: float = 1.0
var enchant_titan: bool = false
var enchant_grow_start: float = 1.0
var enchant_size_dmg: float = 0.0
var enchant_out_speed_mult: float = 1.0
var _grow_init: bool = false
var hit_on_return: bool = false
## Dönüş bacağının hız çarpanı (BIGerang: 1.4 - kullanıcı isteği 2026-10-01 "dönüş hızı %40 daha hızlı").
var enchant_return_speed_mult: float = 1.0
var return_crit: bool = false
var pause_hits: bool = true
var _grow_factor: float = 1.0
var _grow_base_scale: Vector2 = Vector2.ZERO
var is_crit: bool = false
var shield_pen_percent: float = 0.0

## SEKEN ÇELİK (madde 591, çakramın kalıcı özelliği - scripts/weapon_traits/seken_celik.gd): gidişte bir düşmana çarpınca sana dönmek
## yerine bounce_range içindeki en yakın, bu atışta henüz vurulmamış başka düşmana seker (bounce_left kez), sonra döner. Sekerek
## vurulan isabetin hasarı ilk isabetin bounce_dmg_mult katı. Sekme bacağı tam hızla düz gider; hedefe varamazsa bacak sonunda döner.
## Ağ: kaster her sekmede EnchantFx "chakram_leg" (güvenilir) yollar; uzak kopya kendi başına sekme SEÇMEZ - çarpınca NET_LEG_WAIT kadar
## yerinde bekler (mesaj gelince sekme noktasından yeni yöne, gelmezse kendisi döner). Kopya net_pid ile bulunur (_net_copies).
var bounce_left: int = 0
var bounce_range: float = 0.0
var bounce_dmg_mult: float = 1.0
var bounces_done: int = 0
var net_pid: int = 0:
	set(v):
		net_pid = v
		if v != 0 and get_meta("network_spawned", false):
			_net_copies[v] = get_instance_id()
## Bu atışta (gidiş + sekmeler) hasar verilen düşmanlar - sekme bunlara geri dönmez. Atışın vurduğu sayı: hit_count().
var _throw_hits: Array = []
var _first_damage: float = -1.0
var _leg_left: float = 0.0
var _await_leg: float = 0.0
var _leg_grace: float = 0.0
## Sekme bacağı en fazla hedefe uzaklığın bu katı + LEG_PAD kadar sürer (hedef kaçarsa boşa uçmasın).
const LEG_REACH := 1.25
const LEG_PAD := 24.0
## Uzak kopya: çarptığı yerde kasterin sekme mesajını en fazla bu kadar bekler.
const NET_LEG_WAIT := 0.35
## Mesaj geldiğinde kopya sekme noktasından bu kadar uzaktaysa oraya ışınlanır (yakınsa olduğu yerden yön değiştirir).
const NET_LEG_SNAP := 20.0
## Yön değiştiren kopya bu süre çarpışma saymaz (sekme noktasındaki düşmanın içinden çıkarken yeniden "çarpmasın").
const NET_LEG_GRACE := 0.12
static var _net_copies: Dictionary = {}

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
## ÇAKRAM (madde 589, 2026-11-11; kullanıcı: "boomerang da artık chakram oluyor onunla değiştir ve chakram için yeni özel efekt
## hazırla"): mekanik AYNI (anahtar `boomerang`, sahne/betik adları aynı - kayıt/ağ uyumu), görünüş kullanıcının 32x32 çakram çizimi.
## Hepsi tools/gen_chakram_fx.py ile, çizimin kendi ızgarasında (1 piksel = WeaponTierArt.WORLD_PX x SIZE_MULT["boomerang"] =
## 0,7475 dünya px, kafadaki ikonla aynı):
##  - gövde: 24 önceden döndürülmüş kare (RotSprite, 15 derece) - kare açıya göre SEÇİLİR, gövde düz tutulur (piksel ızgarası)
##  - ÇELİK GİRDAP: gövdenin ARKASINDA dönen bıçak halkası izi (whirl, aynı kare indeksi) - bıçak çentiklerini ve kenarın dışını
##    buz rengi basamaklı hilallerle doldurur; tek soluk hayalet (Trail1) artık bu halkanın yankısı (gövdesiz)
##  - isabet "Çelik Kesik" (cut): ön kenarda dönme yönünde süpüren hilal + temas yıldızı + kıvılcımlar, uçuş yönüne döner
##  - en uzak noktada dönüş parıltısı (ping, altın göbekte yıldız + ince halka; gövdeyle gider) / yakalamada daralan altın halka
## Hepsi bu betikte: kaster ve diğer istemcilerdeki kozmetik kopya AYNI sahne (ek RPC yok, CLAUDE.md iki-yer kuralı).
const WeaponTierArtScript := preload("res://scripts/weapon_tier_art.gd")
const RotFrames := preload("res://assets/weapons/chakram/spin_frames.tres")
const WhirlFrames := preload("res://assets/fx/chakram/whirl_frames.tres")
const CutFrames := preload("res://assets/fx/chakram/cut_frames.tres")
const PingFrames := preload("res://assets/fx/chakram/ping_frames.tres")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const CatchFrames := preload("res://assets/fx/chakram/catch_frames.tres")
const ROT_STEPS := 24
## weapon_boomerang.tscn Icon ölçeği (sahnedeki eski ikon; test_boomerang_bounce.gd kontrol eder). Oyunda ikon artık sabit sanat
## (weapon_tier_art.gd), ölçeği weapon.gd _apply_fixed_art verir.
const ICON_SCALE := 0.33
## Sanat pikseli başına yerel ölçek: kök karakterin ölçeğiyle (0,5) çarpılır (weapon.gd _fire_at proj.scale) -> dünya 0,7475 =
## kafadaki ikonun pikseli (WORLD_PX x SIZE_MULT).
const ART_WORLD_PX := WeaponTierArtScript.WORLD_PX * 1.3 ## = size_mult("boomerang"); test_boomerang_bounce.gd eşitliği denetler
const BODY_SCALE := ART_WORLD_PX / WeaponTierArtScript.OWNER_ROOT_SCALE
## Tek soluk hayalet (Trail1) - Trail2/3 sahneden kalktı. Artık gövde değil, Çelik Girdap halkasının yankısı.
const GHOST_SCALE := 0.85
const GHOST_ALPHA := 0.34
const GHOST_TINT := Color(1.0, 1.0, 1.0)
var _body: AnimatedSprite2D = null
var _whirl: AnimatedSprite2D = null
var _ping: AnimatedSprite2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	## Oyuncu ölür/sahneden ayrılır gibi olağandışı bir durumda sonsuza kadar
	## havada asılı kalmasın diye bir güvenlik zaman aşımı.
	get_tree().create_timer(6.0).timeout.connect(_on_timeout)
	if bullet:
		bullet.visible = false ## bkz. "YENİ GÖRÜNÜM" notu
	## Çelik Girdap önce eklenir = gövdenin ARKASINDA (yalnız çentiklerde ve kenarın dışında görünür).
	_whirl = AnimatedSprite2D.new()
	_whirl.name = "Whirl"
	_whirl.sprite_frames = WhirlFrames
	_whirl.animation = &"spin"
	_whirl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_whirl.scale = Vector2.ONE * BODY_SCALE
	add_child(_whirl)
	_body = AnimatedSprite2D.new()
	_body.name = "Body"
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
			tn.sprite_frames = WhirlFrames
			tn.animation = &"spin"
			tn.stop()
			tn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tn.visible = false ## Trail1 ilk _update_trail'de (ölçeği doğru kurulunca) görünür olur
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
	## BIGerang: önceki atışlardan taşınan boyutla başla (props apply_projectile_look ile doğumdan sonra gelir - burada uygulanır,
	## uzak kopyada da aynı props ile aynı boyut).
	if not _grow_init:
		_grow_init = true
		if enchant_grow > 0.0 and enchant_grow_start > 1.0:
			_set_grow(minf(enchant_grow_max, enchant_grow_start))
	_move_physics(delta)
	_ew_poll_hits()


## Yaratık yeniden yazımı (PLAN §4.3): EnemyWorld açıkken kayıtlı yaratıkların fizik gövdesi kapalı - onları
## body_entered yerine bu sorgu bulur ve AYNI _on_body_entered'a verir (giriş/çıkış anlamı aynı: uç noktada bekleyen
## Kasırga içeride duranı değil, çıkıp yeniden gireni tekrar keser - eski Area2D davranışı).
const EnemyWorldHits := preload("res://scripts/enemy_world/enemy_world_hits.gd")
var _ew_hits: RefCounted = null


func _ew_poll_hits() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var w: Object = EnemyWorldHits.world(get_tree())
	if w == null:
		return
	if _ew_hits == null:
		_ew_hits = EnemyWorldHits.new()
	for e in _ew_hits.poll(w, global_position, EnemyWorldHits.shape_radius(self)):
		if is_instance_valid(e):
			_on_body_entered(e)
	_ew_hits.mark(global_position)


func _move_physics(delta: float) -> void:
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
	if _whirl:
		_whirl.rotation = -rotation
		_whirl.frame = rot_frame
	if is_instance_valid(_ping):
		_ping.rotation = -rotation
	for i in range(_trail_nodes.size()):
		if _trail_nodes[i]:
			(_trail_nodes[i] as AnimatedSprite2D).frame = (rot_frame - i - 1 + ROT_STEPS) % ROT_STEPS
	_leg_grace = maxf(0.0, _leg_grace - delta)
	if _await_leg > 0.0:
		## Uzak kopya: çarptığı yerde kasterin sekme mesajını bekliyor (bkz. SEKEN ÇELİK notu); gelmezse kendisi döner.
		_await_leg -= delta
		if _await_leg <= 0.0:
			_begin_return()
		_update_trail(delta)
		return
	if _pause_left > 0.0:
		## Uç noktada duraklama: aynı düşmanları tekrar tekrar keser (1/3 sn'de bir).
		_pause_left -= delta
		_pause_clear -= delta
		if _pause_clear <= 0.0:
			_pause_clear = 0.33
			_hit_this_leg.clear()
		_update_trail(delta)
		return
	if not _returning and bounces_done > 0:
		## Sekme bacağı: tam hızla düz; hedefe varamazsa bacak sonunda döner.
		var leg_step: float = speed * enchant_out_speed_mult * delta
		position += direction * leg_step
		_leg_left -= leg_step
		if _leg_left <= 0.0:
			_begin_return()
		_update_trail(delta)
		return
	if not _returning:
		var t: float = clampf(_traveled / maxf(1.0, throw_distance), 0.0, 1.0)
		var step: float = speed * enchant_out_speed_mult * lerpf(1.0, APEX_SPEED_MIN, t * t) * delta
		position += direction * step
		_traveled += step
		if _traveled >= throw_distance:
			_spawn_ping() ## en uzak noktada dönüş parıltısı (çarparak dönüşte kesik efekti yeterli)
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
	position += direction * speed * enchant_return_speed_mult * lerpf(APEX_SPEED_MIN, 1.0, ease_out) * delta
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
	## BIGerang 2026-10-04: uç noktada artık küçülmez (büyüklük atıştan atışa taşınır - bkz. enchants/bigerang.gd).
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


## Geri yakalanma: daralan altın halka + parlama (pişirilmiş 7 kare, tek sefer) - yakalayan oyuncunun üstünde. Hem gerçek hem
## kozmetik (diğer istemcilerdeki) mermide oynar, ikisi de _finish'ten geçer.
func _spawn_catch_sparkle() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = CatchFrames
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.scale = Vector2.ONE * ART_WORLD_PX
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
	if pausing and not pause_hits:
		return
	if _returning and not pausing and not hit_on_return:
		return
	## Ağ üzerinden spawnlanan görsel kopyalar hasar vermez — sadece darbe efektini/sesini oynatır ve gerçek bumerang gibi
	## çarptığı yerden döner (efsunla delip geçiyorsa geçer, büyüyorsa aynı oranla büyür).
	if get_meta("network_spawned", false):
		if _hit_this_leg.has(body) or _await_leg > 0.0 or _leg_grace > 0.0:
			return
		_hit_this_leg.append(body)
		_spawn_impact()
		_spawn_cut()
		_play_impact_sound()
		_grow_on_hit()
		if not _returning and not enchant_pierce_all:
			if bounce_left > 0:
				_await_leg = NET_LEG_WAIT ## Seken Çelik: sekme yönünü kaster söyler (bkz. apply_net_leg)
			else:
				_begin_return()
		return
	if not body.has_method("take_damage"):
		return
	if _hit_this_leg.has(body):
		return
	_hit_this_leg.append(body)
	var hit_crit: bool = is_crit
	var hit_dmg: float = damage
	if enchant_size_dmg > 0.0 and _grow_factor > 1.0:
		hit_dmg *= 1.0 + (_grow_factor - 1.0) * enchant_size_dmg
	if _returning and not pausing and return_crit and not is_crit:
		hit_crit = true
		hit_dmg *= float(source_weapon.get("crit_damage")) if is_instance_valid(source_weapon) and "crit_damage" in source_weapon else 2.0
	BalanceLogScript.tag_weapon(source_weapon)
	body.take_damage(hit_dmg, hit_crit, shield_pen_percent)
	_throw_hits.append(body)
	_grow_on_hit()
	if is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_projectile_hit"):
		source_weapon.enchant_on_projectile_hit(self, body, damage, not _returning)
	if not _shaman_burn_used and body.has_method("try_shaman_weapon_burn"):
		_shaman_burn_used = body.try_shaman_weapon_burn()
	_spawn_impact()
	_spawn_cut()
	_play_impact_sound()
	## Birimlerin içinden geçmez: gidişte çarptığı ilk düşmandan geri döner (BIGerang efsunu hariç - delip geçer). Seken Çelik: önce
	## yakındaki başka bir düşmana seker (sekme hakkı ve hedef varsa).
	if not _returning and not enchant_pierce_all:
		if bounce_left > 0 and _try_bounce(body):
			return
		_begin_return()


## Bu atışın (gidiş + sekmeler) hasar verdiği düşman sayısı - Çelik Değirmen yalnız bir şeye vurmuş atışta kopya bırakır.
func hit_count() -> int:
	return _throw_hits.size()


## Kaster: body'den en yakın uygun düşmana sek (bkz. SEKEN ÇELİK notu). Hedef yoksa false (çağıran sana döndürür).
func _try_bounce(from_body: Node) -> bool:
	var nxt: Node2D = _pick_bounce_target((from_body as Node2D).global_position if from_body is Node2D else global_position)
	if nxt == null:
		return false
	if _first_damage < 0.0:
		_first_damage = damage
	bounce_left -= 1
	bounces_done += 1
	damage = _first_damage * bounce_dmg_mult
	var to: Vector2 = nxt.global_position - global_position
	if to.length() > 0.5:
		direction = to.normalized()
	_leg_left = to.length() * LEG_REACH + LEG_PAD
	_hit_this_leg = [from_body]
	if is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_boomerang_bounce"):
		source_weapon.enchant_on_boomerang_bounce(self, from_body, nxt)
	return true


## Sekme hedefi: bounce_range içinde, bu atışta vurulmamış, sahibin hedef alabileceği (görüş sisi / çalılık kuralı - weapon.gd
## _can_target) en yakın düşman. Yaratık sorgusu EnemyQuery kovası (Enemy.get_enemies_near), isabet başına bir kez.
func _pick_bounce_target(from_pos: Vector2) -> Node2D:
	if not is_inside_tree() or bounce_range <= 0.0:
		return null
	var best: Node2D = null
	var best_d: float = INF
	var can_check: bool = is_instance_valid(source_weapon) and source_weapon.has_method("_can_target")
	for e in Enemy.get_enemies_near(get_tree(), from_pos, bounce_range):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or not e.has_method("take_damage"):
			continue
		if _throw_hits.has(e) or (can_check and not bool(source_weapon.call("_can_target", e))):
			continue
		var d: float = (e as Node2D).global_position.distance_squared_to(from_pos)
		if d < best_d:
			best_d = d
			best = e
	return best


## Uzak kopya: kasterin sekme mesajı (EnchantFx "chakram_leg" -> apply_net_leg). Yön değiştirir; sekme noktasından uzaktaysa oraya ışınlanır.
func _net_leg(at: Vector2, to: Vector2) -> void:
	bounce_left = maxi(0, bounce_left - 1)
	bounces_done += 1
	if global_position.distance_to(at) > NET_LEG_SNAP:
		global_position = at
	var d: Vector2 = to - global_position
	if d.length() > 0.5:
		direction = d.normalized()
	_leg_left = d.length() * LEG_REACH + LEG_PAD
	_returning = false
	_await_leg = 0.0
	_leg_grace = NET_LEG_GRACE
	_hit_this_leg.clear()


static func apply_net_leg(pid: int, at: Vector2, to: Vector2) -> void:
	var id: int = int(_net_copies.get(pid, 0))
	if id == 0:
		return
	var c: Object = instance_from_id(id)
	if c == null or not is_instance_valid(c) or not c.has_method("_net_leg"):
		_net_copies.erase(pid)
		return
	c.call("_net_leg", at, to)


func _exit_tree() -> void:
	if net_pid != 0 and int(_net_copies.get(net_pid, 0)) == get_instance_id():
		_net_copies.erase(net_pid)


## BIGerang: her isabette (gidiş ve dönüş) toplamalı büyür, tavana kadar. Kök düğüm ölçeklenir - çarpışma alanı da büyür.
func _grow_on_hit() -> void:
	if enchant_grow <= 0.0:
		return
	_set_grow(minf(enchant_grow_max, _grow_factor + enchant_grow))


func _set_grow(factor: float) -> void:
	if _grow_base_scale == Vector2.ZERO:
		_grow_base_scale = scale
	_grow_factor = factor
	scale = _grow_base_scale * factor


func is_grown_max() -> bool:
	return enchant_grow > 0.0 and _grow_factor >= enchant_grow_max - 0.001


func _spawn_impact() -> void:
	if not impact_scene:
		return
	var fx = impact_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + impact_offset


## Ölçek çarpanı: çakramın şu anki dünya pikseli (BIGerang büyümesi dahil) / temel piksel.
func _art_grow() -> float:
	return maxf(0.01, absf(global_scale.x) / WeaponTierArtScript.OWNER_ROOT_SCALE)


## İsabet "Çelik Kesik" (cut_sheet: kare merkezi = çakramın merkezi, +x = uçuş yönü). Dönme hep saat yönünde - yalnız döndürülür,
## aynalanmaz (döndürme dönme yönünü korur). Kaster + kozmetik kopya aynı yoldan (ikisi de _on_body_entered).
func _spawn_cut() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = CutFrames
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.z_index = 20
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.global_rotation = (direction if not direction.is_zero_approx() else Vector2.RIGHT).angle()
	fx.global_scale = Vector2.ONE * ART_WORLD_PX * _art_grow()
	fx.play(&"play")
	fx.animation_finished.connect(fx.queue_free)


## En uzak noktada dönüş parıltısı: gövdeyle birlikte gider (çocuk; dönüşü _move_physics'te iptal edilir), bitince silinir.
func _spawn_ping() -> void:
	if is_instance_valid(_ping):
		return
	_ping = AnimatedSprite2D.new()
	_ping.name = "Ping"
	_ping.sprite_frames = PingFrames
	_ping.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ping.scale = Vector2.ONE * BODY_SCALE
	_ping.rotation = -rotation
	add_child(_ping)
	_ping.play(&"play")
	_ping.animation_finished.connect(_ping.queue_free)


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
