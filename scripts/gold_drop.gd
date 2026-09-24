extends Area2D

const DropAttraction := preload("res://scripts/drop_attraction.gd")

const FloatingText := preload("res://scenes/floating_text.tscn")

const ATTRACT_ACCEL := 720.0 ## genel hız ayarı: %20 düşürüldü
const MAX_ATTRACT_SPEED := 496.0

var amount: int = 1
## Kullanıcı isteği (2026-09-21): bosslardan düşen altın, biri aldığında TÜM oyuncular arasında eşit paylaşılır
## (bkz. NetworkManager.host_share_boss_gold). enemy.gd _drop_gold boss için true yapar; SADECE host'taki gerçek drop'ta anlamlı.
var is_boss_gold: bool = false
var bob_time: float = 0.0
var _last_bob_offset: float = 0.0
var is_magnetized: bool = false
var attract_speed: float = 0.0
## #32 DÜZELTME (kullanıcı bildirimi: "Mıknatısla çekilen objeler her zaman
## mıknatısı tutana gitmeli"): bkz. xp_orb.gd aynı alan/yorum - mıknatıs
## power-up'ı toplandığında bu objenin gitmesi GEREKEN spesifik oyuncunun
## peer id'si. -1 = spesifik hedef yok (eski/normal "en yakın oyuncu"
## davranışı).
var magnet_target_peer_id: int = -1


## bkz. xp_orb.gd üstündeki AYNI BUG DÜZELTMESİ notu (kullanıcı bildirimi:
## "Fps bir noktadan sonra hostta inanılmaz düşüyor") - host'taki gerçek
## altın da artık client kozmetik kopyalarıyla (300sn fallback) tutarlı bir
## yaşam süresine sahip.
const EXPIRE_SECONDS := 300.0


func _ready() -> void:
	add_to_group("gold_drops")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(EXPIRE_SECONDS).timeout.connect(_on_expire)


func _on_expire() -> void:
	if not is_instance_valid(self) or get_meta("network_spawned", false):
		return
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host:
			return
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()


func _process(delta: float) -> void:
	bob_time += delta
	var bob_offset: float = sin(bob_time * 4.0) * 3.0
	position.y += bob_offset - _last_bob_offset
	_last_bob_offset = bob_offset


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


## BUG DÜZELTMESİ (kullanıcı bildirimi: "katılımcılar altın toplayınca yine
## hosta gidiyor altınlar") - kök neden: bu yakınlık/mıknatıs mantığı SADECE
## get_first_node_in_group("player")'a (yani HOST'un KENDİ karakterine)
## bakıyordu. Host'un GERÇEK/yetkili altın nesnesi, aslında bir KATILIMCI
## ona çok daha yakın olsa bile HER ZAMAN host'a doğru çekiliyordu - ve
## host'un gerçek çarpışması (fiziksel Area2D, ağ gecikmesi olmadan) neredeyse
## HER ZAMAN katılımcının RPC ile gecikmeli isteğinden önce tetiklendiği için
## altın sürekli host'a gidiyordu (kişisel altın RPC'leri doğruydu ama hiç
## devreye giremiyordu, çünkü gerçek nesne çoktan host tarafından toplanıp
## silinmiş oluyordu). Şimdi SADECE host'un kendi GERÇEK nesnesi için (client
## kozmetik görsel kopyası HÂLÂ eskisi gibi yalnızca kendi yerel oyuncusuna
## bakar) host kendi karakteri VE tüm RemotePlayer kuklaları arasından
## GERÇEKTEN en yakın olanı bulup ona doğru çekiyor.
## BUG DÜZELTMESİ (kullanıcı bildirimi: "biri topladığında o eşya diğer
## oyunculara hâlâ o oyuncunun üzerinde/etrafında yığılmış/uçuyormuş gibi
## görünüyor, toplayanın kendi ekranında ise anında kayboluyor") - kök
## neden: bu tarama eskiden SADECE host'un GERÇEK (network_spawned olmayan)
## nesnesi için çalışıyordu. Host DIŞINDA herkesin ekranında görülen şey
## kozmetik bir GÖRSEL KOPYA'dır ve bu kopyalar koşulsuz SADECE o istemcinin
## KENDİ yerel oyuncusuna bakıyordu - remote_players grubu hiç taranmıyordu.
## Yani gerçek toplayan başka biriyse görsel kopya ya hiç hareket etmiyor ya
## da izleyenin kendi oyuncusuna doğru kayıyordu, host'tan gelen remove_drop
## RPC'si (ağ gecikmesi + toplu gönderim aralığı kadar GEÇ) varana kadar
## ekranda asılı/yığılı kalıyordu. Artık multiplayer aktifken HERKES (host'un
## gerçek nesnesi VE her istemcinin görsel kopyası) aynı "en yakın oyuncuyu
## bul" mantığını kullanıyor, böylece tüm ekranlarda altın her zaman
## GERÇEKTEN toplayan oyuncuya doğru gider.
## (Eski _resolve_attraction_target bu dosyadan kaldırıldı - yukarıdaki kurallar artık drop_attraction.gd
## attraction_target/_target_index'te, xp_orb.gd ile TEK ortak kopya.)


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	## Kullanıcı isteği: "oyundaki para ortak olmamalı herkesin parası
	## kişisel olmalı" - artık hem yerel oyuncu HEM DE bir RemotePlayer
	## (gerçek uzak client) topladığında kabul ediliyor, ikisi de SADECE
	## KENDİ ekranındaki/hesabındaki altına eklenir (bkz. aşağı).
	if not (body.is_in_group("player") or body.is_in_group("remote_players")):
		return
	
	## Multiplayer: client tarafındaki görsel kopya → host'a toplama isteği gönder
	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			## Verimlilik notu (derin multiplayer denetimi bulgusu): eskiden
			## broadcast .rpc() ile HERKESE gönderiliyordu, host olmayan her
			## peer bunu anında no-op edip atıyordu (bkz. request_drop_pickup
			## "if not is_host: return") - relay'in bağlantı başına flood/kick
			## bütçesine (bkz. network_manager.gd dosya başı notu) gereksiz
			## yük. Artık sadece host'a hedefli gönderiliyor.
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), drop_id, "gold")
			## Kritik çökme düzeltmesi: bkz. xp_orb.gd aynı notu.
			NetworkManager.discard_visual_drop(drop_id)
		queue_free()
		return
	
	## Kişisel altın: host'un kendi oyuncusu topladıysa doğrudan kendi
	## GameManager'ına ekler; bir RemotePlayer (gerçek uzak client) topladıysa
	## SADECE o client'a RPC ile eklenir (bkz. remote_player.gd collect_gold)
	## - eskiden burada share_gold.rpc() TÜM peer'lere aynı miktarı
	## yayınlıyordu (ortak/paylaşımlı para), bu artık kaldırıldı.
	## Boss altını: çok oyunculuda tüm katılımcılar arasında eşit bölünür, her pay sahibine doğru uçar.
	var shared: bool = is_boss_gold and NetworkManager.is_multiplayer_active 			and NetworkManager.host_share_boss_gold(amount, global_position, body)
	if shared:
		pass
	elif body.is_in_group("player"):
		GameManager.gold += amount
		var ft = FloatingText.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.global_position = body.global_position + Vector2(14, -34)
		ft.setup("+%d altın" % amount, Color(1.0, 0.85, 0.25))
	elif body.has_method("collect_gold"):
		body.collect_gold(amount)
	
	if NetworkManager.is_multiplayer_active:
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	_play_pickup_sound()
	queue_free()


## The orb is about to be freed, but the sound should keep playing - detach
## the player from this node first so it isn't silenced mid-clip, and let it
## clean itself up once done (same trick used for the lightning strike fx).
func _play_pickup_sound() -> void:
	var sfx: AudioStreamPlayer2D = $PickupSound
	var world_pos: Vector2 = sfx.global_position
	remove_child(sfx)
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = world_pos
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
