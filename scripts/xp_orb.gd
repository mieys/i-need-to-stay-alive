extends Area2D

const DropAttraction := preload("res://scripts/drop_attraction.gd")

var xp_value: float = 5.0
## Kullanıcı isteği: "oyundaki exp orblarını silip yerine bunu koy" - hangi
## GÖRSEL/renk kullanılacağını belirler (1=yeşil...5=kırmızı, bkz. TIERS).
## Eskiden bu tier xp_value EŞİĞİNDEN türetiliyordu (küçük/orta/büyük) - artık
## orb'u DÜŞÜREN yaratığın Kademesinden ağırlıklı rastgele geliyor (bkz.
## enemy.gd _max_orb_tier_for_enemy_tier/_roll_orb_tier/_drop_xp) ki her
## Kademe aralığında hep AYNI renk düşmesin (kullanıcı isteği).
var xp_tier: int = 1
var is_magnetized: bool = false
var attract_speed: float = 0.0
## #32 DÜZELTME (kullanıcı bildirimi: "Mıknatısla çekilen objeler her zaman
## mıknatısı tutana gitmeli"): mıknatıs power-up'ı toplandığında bu objenin
## gitmesi GEREKEN spesifik oyuncunun peer id'si - bkz. attract_to_player()
## ve _resolve_attraction_target(). -1 = spesifik hedef yok (eski/normal
## "en yakın oyuncu" davranışı, ör. sıradan menzil-içi çekim).
var magnet_target_peer_id: int = -1

const ATTRACT_ACCEL := 720.0 ## genel hız ayarı: %20 düşürüldü
const MAX_ATTRACT_SPEED := 496.0

## Kullanıcı isteği: "5 adet orb bulunuyor her orbun kendi tierı var ... yüksek
## tierler diğerlerinden azıcık büyük olacak" - eskiden TEK bir jenerik
## (small/medium/large) sprite sheet vardı, tier'a göre sadece self_modulate
## ile renkleniyordu. Artık her tier'ın (bkz. assets/pickups/xp_orb/
## xp_orb_frames.tres) KENDİ özel çizilmiş rengi/görseli var (yeşil/mavi/mor/
## sarı/kırmızı) - tonlama kaldırıldı, gerçek sanat kendi rengiyle gösteriliyor.
## Boyut artışı "azıcık" istendiği için adım aralığı küçük tutuldu.
## DÜZELTME (kullanıcı isteği: "tüm orbları %60 küçült") - hem scale hem de
## ona bağlı çarpışma yarıçapı orantılı olarak ×0.4 (eski değerlerin %40'ı,
## yani %60 küçültülmüş) - xp_value'nun eskiden "%40 küçült" istendiğinde
## AYNI oranda (scale VE collision_radius birlikte) küçültüldüğü desenle
## tutarlı (bkz. Git geçmişi).
const TIERS := {
	1: {"anim": "green", "scale": 0.22, "collision_radius": 1.8},
	2: {"anim": "blue", "scale": 0.24, "collision_radius": 2.0},
	3: {"anim": "purple", "scale": 0.26, "collision_radius": 2.2},
	4: {"anim": "yellow", "scale": 0.28, "collision_radius": 2.4},
	5: {"anim": "red", "scale": 0.30, "collision_radius": 2.6},
}

## Kullanıcı isteği: "azıcık smooth büyüyüp küçülme animasyonu ekle" - sprite
## sheet'in kendi kare animasyonuna (yukarıdaki TIERS/xp_orb_frames.tres) EK
## olarak, saf sinüs tabanlı yumuşak bir "nefes alma" scale pulse'ı -
## fx_arcane_skull_bounce.gd'deki AYNI pulse deseni (1.0 + sin(t*hız)*genlik),
## ama "azıcık" istendiği için çok daha küçük genlik ve daha yavaş hız.
const PULSE_SPEED := 3.0
const PULSE_AMPLITUDE := 0.08

var _base_scale: float = 1.0
var _pulse_time: float = 0.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


## BUG DÜZELTMESİ (kullanıcı bildirimi: "Fps bir noktadan sonra hostta
## inanılmaz düşüyor") - kök neden: bu (host'taki GERÇEK, "network_spawned"
## OLMAYAN) orb'un hiçbir yaşam süresi yoktu - toplanana kadar SONSUZA KADAR
## `_process`/`_physics_process` çalıştırıp (bkz. _resolve_attraction_target,
## remote_players grubunu her karede tarıyor) sahnede kalıyordu. Bir maç
## boyunca kaçırılan/ulaşılamayan her orb böyle KALICI olarak birikiyor,
## zamanla host'un FPS'ini eritiyordu - client'lardaki kozmetik GÖRSEL
## KOPYALAR zaten 300sn'de bir kendi kendine temizleniyordu (bkz.
## network_manager.gd broadcast_drop), gerçek nesnede bu güvenlik ağı hiç
## yoktu. Artık gerçek orb da AYNI 300sn'de kendini temizliyor (bkz.
## _on_expire) - client'ların zaten sahip olduğu davranışla tutarlı.
const EXPIRE_SECONDS := 300.0


func _ready() -> void:
	add_to_group("xp_orbs")
	body_entered.connect(_on_body_entered)
	## Aynı anda düşen orb'ların (bkz. enemy.gd orb_count) hepsi AYNI fazda
	## nabız atıp mekanik görünmesin diye her orb rastgele bir başlangıç
	## fazıyla başlıyor.
	_pulse_time = randf() * TAU
	_setup_visual()
	get_tree().create_timer(EXPIRE_SECONDS).timeout.connect(_on_expire)


## bkz. sınıf üstü BUG DÜZELTMESİ notu. "network_spawned" kozmetik kopyalarda
## hiç çalışmaz - onların KENDİ 300sn fallback'i zaten var (bkz.
## network_manager.gd broadcast_drop).
func _on_expire() -> void:
	if not is_instance_valid(self) or get_meta("network_spawned", false):
		return
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host:
			return ## gerçek orb sadece host'ta var, bu dal normalde çalışmaz
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()


func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse: float = 1.0 + sin(_pulse_time * PULSE_SPEED) * PULSE_AMPLITUDE
	sprite.scale = Vector2(_base_scale, _base_scale) * pulse


func _setup_visual() -> void:
	var tier: Dictionary = TIERS.get(xp_tier, TIERS[1])

	sprite.play(tier["anim"])
	_base_scale = tier["scale"]
	sprite.scale = Vector2(_base_scale, _base_scale)

	## Bir fizik sorgu taşması (physics query flush) sırasında add_child
	## edilirse (ör. enemy.gd _drop_xp - artık call_deferred kullanıyor ama
	## burası da savunma amaçlı ertelemeli kalsın) çarpışma şeklini SENKRON
	## değiştirmek "Can't change this state while flushing queries" hatası
	## verip oyunu çökertiyordu - bkz. kullanıcı bildirimi.
	var new_shape: Shape2D = collision.shape.duplicate()
	new_shape.radius = tier["collision_radius"]
	collision.set_deferred("shape", new_shape)


func attract_to_player(target_peer_id: int = -1) -> void:
	is_magnetized = true
	magnet_target_peer_id = target_peer_id
	DropAttraction.wake(self) ## uyuyorsa (bkz. drop_attraction.gd) mıknatıs anında uyandırır


func _physics_process(delta: float) -> void:
	## Hedef seçimi + menzil kontrolü ortak/önbellekli yardımcıda (bkz. drop_attraction.gd PERF notu).
	var player: Node2D = DropAttraction.attraction_target(self, is_magnetized, magnet_target_peer_id)
	if player == null:
		if DropAttraction.last_query_far:
			DropAttraction.put_to_sleep(self) ## uyku/uyandırma: bkz. drop_attraction.gd
		return
	attract_speed = min(attract_speed + ATTRACT_ACCEL * delta, MAX_ATTRACT_SPEED)
	global_position = global_position.move_toward(player.global_position, attract_speed * delta)


## bkz. gold_drop.gd::_resolve_attraction_target aynı yorumu - XP takım
## havuzuna eklendiği için kimin topladığı puanı etkilemez, ama host'un
## GERÇEK orb'u eskiden SADECE host'a doğru çekildiği için katılımcının
## ekranında XP topları hep host'a doğru kayıyormuş gibi görünüyordu
## (kullanıcı bildirimi: "single playerdaki ve hosttaki gibi görünmüyor").
##
## BUG DÜZELTMESİ (kullanıcı bildirimi: "biri topladığında o eşya diğer
## oyunculara hâlâ o oyuncunun üzerinde/etrafında yığılmış/uçuyormuş gibi
## görünüyor, toplayanın kendi ekranında ise anında kayboluyor") - kök
## neden: bu tarama SADECE host'un GERÇEK (network_spawned olmayan) orb'u
## için çalışıyordu. Her istemcinin gördüğü kozmetik GÖRSEL KOPYA ise
## (yani host DIŞINDA herkesin ekranında gördüğü şey budur) koşulsuz
## SADECE o istemcinin KENDİ yerel oyuncusuna bakıyordu - remote_players
## grubu hiç taranmıyordu. Yani gerçek toplayan başka biriyse görsel kopya
## ya hiç hareket etmiyor ya da yanlış (izleyenin kendi) oyuncusuna doğru
## kayıyordu, remove_drop RPC'si gelene kadar (host'un asıl nesnesi zaten
## doğru hedefe gitmiş ve kaybolmuşken) ekranda asılı kalıyordu. Artık
## multiplayer aktifken HERKES (host'un gerçek nesnesi VE her istemcinin
## görsel kopyası) aynı "en yakın oyuncuyu bul" mantığını kullanıyor, böylece
## tüm ekranlarda orb her zaman GERÇEKTEN toplayan oyuncuya doğru gider.
## (Eski _resolve_attraction_target bu dosyadan kaldırıldı - yukarıdaki kurallar artık drop_attraction.gd
## attraction_target/_target_index'te, xp_orb.gd ile TEK ortak kopya.)


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu): "player_ally"
	## grubu asıl evcil hayvanları (bkz. player.gd add_to_group çağrısı)
	## dışlamak için var, ama remote_player.gd KENDİSİ de hem "player_ally"
	## hem "remote_players" grubuna ekleniyor - bu yüzden bu erken return,
	## aşağıdaki "remote_players" güvenlik ağını (host'un gerçek uzak oyuncu
	## kuklasıyla fiziksel çarpışması - bkz. altındaki DÜZELTME notu) gerçek
	## bir RemotePlayer için HİÇBİR ZAMAN çalıştırmıyordu, XP orb'unun RPC'si
	## kaybolursa sonsuza dek toplanamadan kalmasına yol açıyordu (gold_drop.gd
	## bu erken dönüşe sahip olmadığı için aynı sorunu hiç yaşamıyordu).
	if body.is_in_group("player_ally") and not body.is_in_group("remote_players"):
		return

	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		# Client tarafındaki GÖRSEL KOPYA: sadece bu istemcinin KENDİ yerel
		# oyuncusu tetiklesin - yoksa her istemci ekranında yakınına gelen
		# HERHANGİ bir uzak oyuncu için de host'a toplama isteği göndermeye
		# çalışırdı.
		if not body.is_in_group("player"):
			return
		# Hasat Çantası veya yerel toplama sesi için yerel oyuncuyu bilgilendir
		if body.has_method("on_xp_collected"):
			body.on_xp_collected()
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			## Verimlilik notu (derin multiplayer denetimi bulgusu) - bkz.
			## gold_drop.gd aynı DÜZELTME notu: broadcast yerine host'a hedefli.
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), drop_id, "xp")
			## Kritik çökme düzeltmesi: kendi görsel kopyamızı silmeden önce
			## NetworkManager._visual_drops kaydını da düşürüyoruz - yoksa
			## host'un gecikmeli "toplandı" onayı çoktan silinmiş bu node'a
			## erişmeye çalışıp client'ı çökertiyordu.
			NetworkManager.discard_visual_drop(drop_id)
		queue_free()
		return

	## BUG DÜZELTMESİ (kullanıcı bildirimi: "diğer karakterler birşey
	## toplayınca üstlerinde birikiyor ama yok olmuyor yine exp altın v.s.")
	## - kök neden: burası eskiden "remote_players" grubunu (host'un kendi
	## simülasyonundaki GERÇEK uzak oyuncu kuklalarını) koşulsuz reddediyordu.
	## Normal toplama, o uzak oyuncunun KENDİ ekranındaki kozmetik kopyasının
	## kendi yerel çarpışmasını tespit edip host'a bir request_drop_pickup
	## RPC'si göndermesiyle olur - ama bu RPC bir sebeple hiç gelmez/gecikirse
	## (ör. o istemcinin hesapladığı "en yakın oyuncu" host'unkiyle bir an
	## uyuşmazsa) host'un GERÇEK orb'u o oyuncunun üzerine mıknatısla yapışık
	## kalıp asla toplanmıyordu (host DIŞINDAKİ herkes bunu görüyordu - bkz.
	## gold_drop.gd'deki aynı düzeltme, orası zaten bunu kabul ediyordu).
	## Artık host'un GERÇEK fiziksel çarpışması da bir güvenlik ağı olarak
	## kabul ediliyor: kim gerçekten dokunursa toplama anında gerçekleşiyor.
	if not (body.is_in_group("player") or body.is_in_group("remote_players")):
		return

	if body.has_method("on_xp_collected"):
		body.on_xp_collected()

	if NetworkManager.is_multiplayer_active:
		# Host tarafındaki gerçek drop (host'un kendisi VEYA host'taki
		# gerçek bir uzak oyuncu kuklası dokunmuş olabilir - ikisi de
		# ortak takım XP'sine eklenir, kimin dokunduğu önemli değildir).
		if NetworkManager.is_host:
			NetworkManager.host_collect_xp(xp_value)
			var drop_id: int = int(get_meta("drop_network_id", 0))
			if drop_id > 0:
				NetworkManager.queue_remove_drop(drop_id)
			queue_free()
			return
	else:
		# Tek oyunculu mod: doğrudan ortak takıma ekle
		GameManager.add_team_xp(xp_value)
		queue_free()
