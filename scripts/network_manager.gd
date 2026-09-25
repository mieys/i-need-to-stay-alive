extends Node

## Vampir Çocuk FX yardımcısı (broadcast_player_vfx "vampir_fx" dalı).
const VampirMathScript := preload("res://scripts/vampir_math.gd")
const PixelDrawScript := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript := preload("res://scripts/spiritual_skills.gd")

## NetworkManager: Godot'nun yerleşik ENet çoklu oyuncu altyapısı üzerinden DOĞRUDAN
## (host <-> client) bağlantı kurar. Kullanıcı isteği: "multiplayerdan ziva altyapısını
## kaldır, üyeliğimi iptal ettim, multiplayerda ziva seçeneği de olmayacak" - bulut
## relay'i (WebSocketMultiplayerPeer, oda kodu, "en düşük id host olur" seçimi, yeniden
## bağlanma denemeleri) TAMAMEN kaldırıldı; tek bağlantı yolu artık host_lan/join_lan.
##
## Host = ENet sunucusu = HER ZAMAN peer id 1 (bkz. _refresh_host). Host oyundan ayrılırsa
## oyun biter (host devri yok): katılımcılar server_disconnected/host_left_game sinyaliyle
## ana menüye döner. İnternet üzerinden oynamak için host'un portu (varsayılan 7777, UDP)
## yönlendirmesi ya da bir sanal ağ aracı (Radmin/Hamachi/ZeroTier vb.) gerekir.
##
## "Oda kodu" (room_code) artık sadece bağlantı bilgisi metnidir: host'ta "LAN:<port>",
## katılımcıda "<ip>:<port>" - lobide gösterilir.

signal lobby_updated
signal connection_status_changed(status_text: String)
signal game_started
signal server_disconnected
## Host oyunu kapatıp/ana menüye dönüp bağlantıyı tamamen kestiğinde SADECE
## client'larda (host'un kendisinde DEĞİL) yayınlanır - main.gd bunu dinleyip
## "Host oyundan ayrıldı" bildirimini gösterip ana menüye döndürür (bkz.
## kullanıcı bildirimi: "host oyunu kapattığında ... katılımcılar oyundan
## çıkınca veya bağlantısı kesilince oyundan çıktığını gösteren bir bildirim
## yok sadece donuk vaziyette kalıyor").
signal host_left_game
## Bir peer (host DEĞİL) lobiden/oyundan ayrıldığında (bkz. _on_peer_disconnected)
## kalan herkese "adı ayrıldı" bildirimi göstermek için yayınlanır (kullanıcı
## bildirimi: "katılımcılar oyundan çıkınca ... bildirim yok").
signal player_left_game(player_name: String, peer_id: int)
## DÜZELTME (kullanıcı bildirimi: "ölüm ekranı yok ölünce hiçbir gösterge
## v.s yok"): sync_game_over RPC'si eskiden SADECE is_game_over bayrağını
## sessizce true yapıyordu - takımdan önce ölüp "izleyicisin" ekranında
## bekleyen oyuncular, son kişi de öldüğünde bunu hiçbir şekilde ÖĞRENEMİYORDU
## (bkz. main.gd _show_death_overlay/_on_game_over_synced). Artık bu sinyal
## de yayınlanıyor, main.gd ekranı "OYUN BİTTİ"ye günceller.
signal game_over_synced
## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu - host migrasyonu):
## eski host ayrılıp bu peer host olduğunda (bkz. _refresh_host) enemy_
## spawner.gd gibi "sadece host çalıştırır" mantığı olan node'ların yerel
## sayaçları (ör. bir sonraki düşman ağ id'si, hangi boss Kademelerinin
## zaten doğduğu) hâlâ İLK/boş değerindeydi - bu da zaten geçmiş boss/final
## Kademelerin YENİDEN doğmasına ve ağ kimliklerinin halen hayatta olan
## nesnelerle çakışmasına yol açıyordu. Bu sinyal SADECE is_host false'tan
## true'ya geçtiğinde (yeni host olunduğunda) yayınlanır - ilgilenen
## node'lar kendi sayaçlarını sahnenin GÜNCEL durumundan yeniden tohumlar.
signal became_host
## Kullanıcı isteği: "oyundan çıkmış biri tekrar oda kodunu girerek hazır
## olma tuşuyla oyuna katılabilmeli, oyundaki son haliyle oyuna katılmalı" -
## host bu sinyali, geç katılan bir oyuncuyu kabul ettiğinde (bkz.
## request_join_in_progress_game) yayınlar; enemy_spawner.gd bunu dinleyip
## hâlâ hayatta olan tüm yaratıkları o SPESİFİK oyuncuya "yakalama" (catch-up)
## yayınıyla gönderir - aksi halde yeni katılan boş bir savaş alanı görürdü.
signal peer_needs_game_catchup(peer_id: int)

var is_multiplayer_active: bool = false
## Bağlantı bilgisi metni (bkz. dosya başı not) - lobide gösterilir.
var room_code: String = ""
## Bu istemci host mu? ENet sunucusu (peer id 1) = host (bkz. _refresh_host).
var is_host: bool = false
var local_player_name: String = "Oyuncu"
var local_char_id: int = 1

## DÜZELTME (kullanıcı isteği: "oyunda isim profili olsun 1 kere ismini
## yazınca bi daha yazman gerekmesin") - UISound'un ses/ekran ayarları
## için kullandığı AYNI ConfigFile deseni (bkz. ui_sound.gd SETTINGS_PATH).
## Kaydedilen isim _ready()'de local_player_name'e yüklenir (lobby_menu.gd
## bunu LineEdit'e önceden doldurur), her isim değişikliğinde (host_lan/
## join_lan/update_local_player_name) tekrar kaydedilir.
const PLAYER_NAME_CONFIG_PATH := "user://player_settings.cfg"

func _save_local_player_name() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", local_player_name)
	config.save(PLAYER_NAME_CONFIG_PATH)


func _load_saved_player_name() -> void:
	var config := ConfigFile.new()
	if config.load(PLAYER_NAME_CONFIG_PATH) == OK:
		var saved: String = str(config.get_value("player", "name", "")).strip_edges()
		if not saved.is_empty():
			local_player_name = saved

## Key: peer_id (int), Value: { "name": String, "char_id": int, "is_ready": bool, "is_host": bool }
var lobby_players: Dictionary = {}

## Yükleme ekranı senkronizasyonu (kullanıcı isteği: "multiplayerda herkesin
## yükleme barı dolmadan oyun başlamamalı") - bkz. loading_screen.gd ve
## mark_local_loading_done/all_players_loading_done. set_local_ready ile
## BİREBİR AYNI desen: her peer kendi sözlüğünü doğrudan günceller, RPC
## (call_local OLMADAN) sadece diğerlerine bildirir - host'un dinamik
## olarak değişebildiği bu mimaride (bkz. yukarıdaki _host_peer notu) tek
## bir "toplayıcı" otoriteye bağımlı kalmamak için her peer aynı tamamlanma
## kontrolünü kendi başına yapar. _rpc_start_game() sahne değişiminden hemen
## önce bunu temizler (bkz. orada).
var _loading_done: Dictionary = {} ## peer_id (int) -> true

var _peer: MultiplayerPeer = null

const MAX_PLAYERS := 8

## Şu an host kabul edilen gerçek peer id (bkz. _refresh_host). 0 = henüz
## belirlenmedi (bağlı değiliz).
var _host_peer: int = 0

## Relay, kötüye kullanımı önlemek için HER bağlantıya saniyelik mesaj/byte
## bütçesi uyguluyor ve bunu aşan "sel" (flood) durumunda bağlantıyı sessizce
## KAPATIYOR (bkz. Ziva multiplayer dokümanı: "Per-connection byte budget:
## each connection has a rolling messages-per-second and bytes-per-second
## limit. Floods are closed, not relayed."). Yoğun aksiyon anlarında (çok
## sayıda düşman/vuruş/efekt aynı anda ağa RPC gönderdiğinde) bu bütçe
## aşılırsa host veya katılımcı aniden oyundan düşer - kullanıcı bildirimi:
## "çok fazla aksiyon olduğunda birden hostun ya da katılımcının oyunu
## kapanıyor" tam olarak budur. Çözüm sunucu tarafında bir ayar DEĞİL - salt
## kozmetik/yüksek frekanslı RPC'leri (hasar sayıları, silah VFX'i gibi)
## göndermeden ÖNCE istemci tarafında sınırlamak gerekiyor (bkz. aşağıdaki
## should_throttle, çağrı yerleri için enemy.gd/weapon.gd içindeki
## "NetworkManager.should_throttle" kullanımlarına bakın).
var _last_broadcast_at: Dictionary = {} ## key(String) -> Time.get_ticks_msec() (int)

## DÜZELTME (kullanıcı bildirimi: "oyun ilerleyince yaratıklar çok
## çoğalmasa bile bir süre sonra fps aşırı düşüyor"): bu sözlük, tıpkı
## enemy_spawner.gd'nin daha önce düzeltilen _last_dead_sent'i gibi, HİÇBİR
## ZAMAN tek tek temizlenmiyordu - sadece tam bağlantı kopunca (bkz.
## _clear_peer_state) toptan siliniyordu. Anahtarlar "dmgnum_<yaratık_id>"
## (enemy.gd - HER hasar alan yaratık için) ve "petpos_<pet_instance_id>"
## (skeleton_pet.gd/wraith_pet.gd/player_pet.gd - HER çağrılan Necromancer
## yaratığı/Matthew tilkisi için) gibi BENZERSİZ, bir daha asla tekrar
## kullanılmayan kimlikler kullanıyor - yani bu Dictionary, oturum boyunca
## şimdiye kadar spawn olmuş/hasar almış HER ŞEYİN kalıcı bir kaydını
## tutarak sınırsız büyüyordu (uzun bir multiplayer oturumunda binlerce
## ölü anahtar birikip hem bellek hem de aşağıdaki should_throttle'ın her
## çağrısında büyüyen bir Dictionary üzerinde çalışması nedeniyle zamanla
## performansı düşürüyordu). Artık periyodik olarak (bkz. _process'teki
## çağrı) bir süredir hiç kullanılmamış anahtarlar süpürülüyor.
const THROTTLE_SWEEP_INTERVAL := 30.0 ## saniye
const THROTTLE_STALE_MS := 15000 ## bu süre kullanılmayan anahtar "ölü" sayılır
var _throttle_sweep_timer: float = 0.0

func _sweep_stale_throttle_keys() -> void:
	if _last_broadcast_at.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var stale_keys: Array = []
	for key in _last_broadcast_at.keys():
		if now - int(_last_broadcast_at[key]) > THROTTLE_STALE_MS:
			stale_keys.append(key)
	for key in stale_keys:
		_last_broadcast_at.erase(key)

## true dönerse ÇAĞIRAN TARAF O RPC'Yİ GÖNDERMEMELİDİR (bkz. yukarıdaki not) -
## aynı "key" için son gönderimden bu yana min_interval_sec'den az zaman
## geçmişse limitler. Sadece kozmetik/sık tekrarlı broadcast'ler için
## kullanılmalı; hasar/ekonomi gibi oyunun doğruluğunu etkileyen RPC'ler asla
## bu şekilde atlanmamalı.
func should_throttle(key: String, min_interval_sec: float) -> bool:
	var now: int = Time.get_ticks_msec()
	var last: int = _last_broadcast_at.get(key, 0)
	if now - last < int(min_interval_sec * 1000.0):
		return true
	_last_broadcast_at[key] = now
	return false


## Saniyede gönderilen paket sayısını ve toplu senkronizasyonları dengelemek
## için XP ve Drop silme tamponları (batching buffers)
var _pending_xp_sync: bool = false
var _xp_sync_timer: float = 0.0
const XP_SYNC_INTERVAL := 0.08 ## Saniyede max ~12.5 kez XP sync RPC
var _pending_removed_drops: Array = []
var _drop_remove_timer: float = 0.0
const DROP_REMOVE_INTERVAL := 0.05 ## Saniyede max 20 kez toplu drop silme

func _ready() -> void:
	_load_saved_player_name()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	## Level atlama geri sayımı (bkz. update_level_up_timer) TAM OLARAK
	## oyun duraklatılmışken (get_tree().paused = true, level atlama
	## ekranı açıkken) işlemesi gerekiyor - varsayılan process_mode
	## (PAUSABLE) bu autoload'ı da duraklatırdı. ALWAYS ile bağlantı
	## yeniden deneme mantığı da (aynı şekilde duraklatılmışken donmaması
	## gereken bir şey) artık bu sayede duraklamadan bağışık.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	## Level atlama geri sayımını her karede tikle - fonksiyonun kendisi
	## zaten level_up_timer_active değilse hemen çıkıyor, bu yüzden
	## koşulsuz çağırmak ucuz ve güvenli (bkz. main.gd _process üzerindeki
	## not - eskiden burası Main node'unun duraklayan _process'indeydi).
	update_level_up_timer(delta)
	## bkz. yukarıdaki "SANDIK SEÇİM GERİ SAYIMI" notu - level atlama
	## geri sayımıyla AYNI şekilde koşulsuz her karede tiklenir.
	update_chest_countdown(delta)
	## Mini dükkan (bkz. aşağıdaki "MİNİ DÜKKAN SENKRONİZASYONU" bloğu) -
	## level atlama/sandık geri sayımlarıyla AYNI şekilde koşulsuz tiklenir.
	update_mini_shop_timer(delta)
	## Yeniden başlatma onay oylaması (bkz. "YENİDEN BAŞLATMA ONAYI" bloğu) -
	## sadece host'ta ve bir oylama sürerken bir şey yapar.
	update_restart_vote_timer(delta)

	## bkz. _sweep_stale_throttle_keys üstündeki not - FPS'in zamanla düşmesi
	## bugu için düzeltme.
	_throttle_sweep_timer += delta
	if _throttle_sweep_timer >= THROTTLE_SWEEP_INTERVAL:
		_throttle_sweep_timer = 0.0
		_sweep_stale_throttle_keys()

	if is_multiplayer_active and is_host:
		_process_batched_syncs(delta)

	## LAN OTOMATİK KEŞİF: host'ken periyodik "buradayım" yayını, herkeste (bağlı
	## olsun olmasın, fonksiyonların kendisi no-op guard'lı) gelen paketleri dinleme.
	if _discovery_send_peer != null:
		_discovery_beacon_timer += delta
		if _discovery_beacon_timer >= DISCOVERY_BEACON_INTERVAL:
			_discovery_beacon_timer = 0.0
			_send_lan_beacon()
	_poll_lan_discovery()


func host_lan(port: int = 7777, player_name: String = "Oyuncu", char_id: int = 1) -> bool:
	disconnect_from_room(false)
	is_multiplayer_active = true
	local_player_name = player_name.strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Oyuncu"
	_save_local_player_name()
	local_char_id = char_id
	is_host = true
	_host_peer = 1
	## DÜZELTME (kullanıcı isteği: "ip adresimi otomatik olarak lan'da görünsün ipmi
	## sürekli yazmak istemiyorum") - eskiden burası sadece "LAN:<port>" yazıyordu,
	## gerçek IP'yi kullanıcı CMD'de "ipconfig" çalıştırıp KENDİSİ okuyup arkadaşına
	## SÖYLEMEK zorundaydı. Artık get_local_lan_ip() ile yerel ağ IP'si OTOMATİK
	## algılanıp buraya yazılıyor - lobby_menu.gd'deki bağlantı etiketi bunu doğrudan
	## gösterir, hiçbir yerde elle IP aramak/yazmak gerekmiyor.
	var detected_ip: String = get_local_lan_ip()
	room_code = "%s:%d" % [detected_ip, port] if detected_ip != "" else "LAN:%d" % port

	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		is_multiplayer_active = false
		connection_status_changed.emit("LAN Sunucu başlatılamadı: %s" % error_string(err))
		return false

	_peer = peer
	multiplayer.multiplayer_peer = _peer

	lobby_players[1] = {
		"name": local_player_name,
		"char_id": local_char_id,
		"is_ready": true,
		"is_host": true
	}

	connection_status_changed.emit("LAN Sunucu Kuruldu! Port: %d" % port)
	lobby_updated.emit()
	## Artık kendisi de ağda bir "beacon" (duyuru) yayınlar - bkz. LAN OTOMATİK KEŞİF
	## bloğu altındaki _start_lan_beacon notu. Katılan taraf IP'yi hiç YAZMADAN, lobi
	## ekranındaki "Bulunan Oyunlar" listesinden tıklayıp katılabilir.
	stop_lan_discovery_listen()
	_start_lan_beacon(port)
	return true


func join_lan(ip: String = "127.0.0.1", port: int = 7777, player_name: String = "Oyuncu", char_id: int = 1) -> bool:
	disconnect_from_room(false)
	is_multiplayer_active = true
	local_player_name = player_name.strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Oyuncu"
	_save_local_player_name()
	local_char_id = char_id
	is_host = false
	_host_peer = 1
	room_code = "%s:%d" % [ip, port]

	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		is_multiplayer_active = false
		connection_status_changed.emit("LAN Sunucuya bağlanılamadı: %s" % error_string(err))
		return false

	_peer = peer
	multiplayer.multiplayer_peer = _peer
	connection_status_changed.emit("LAN Sunucuya bağlanılıyor (%s:%d)..." % [ip, port])
	stop_lan_discovery_listen()
	return true


## ============================================================================
## LAN OTOMATİK KEŞİF (kullanıcı isteği: "ip adresimi otomatik olarak lan'da
## görünsün ipmi sürekli yazmak istemiyorum")
## ============================================================================
## Oyunun asıl bağlantısı (ENet, host_lan/join_lan) bundan TAMAMEN BAĞIMSIZ - bu
## katman SADECE aynı yerel ağdaki (LAN) host'ları BULUP IP:Port'u otomatik
## doldurmak için var, kendi ayrı UDP portunu (DISCOVERY_PORT) kullanır:
##   - Host: her ~1sn'de bir küçük bir "buradayım" paketini ağa YAYINLAR (broadcast).
##   - Henüz bağlanmamış herkes (lobby_menu.gd açıkken) bu portu dinler, gelen
##     paketlerin GÖNDEREN IP'sini (PacketPeerUDP.get_packet_ip() - istemcinin
##     KENDİ yazması GEREKMEYEN kısım tam olarak bu) + paketteki port/isim'i
##     "Bulunan Oyunlar" listesine ekler.
## Güvenlik duvarı/farklı alt ağ gibi sebeplerle keşif paketleri ulaşmazsa (ya da
## AYNI bilgisayarda ikinci bir test istemcisi zaten aynı portu dinliyorsa, bkz.
## CLAUDE.md "Test/doğrulama" - host+client'ı tek PC'de test etme) sessizce hiçbir
## şey BOZULMAZ: manuel IP:Port alanı her zaman olduğu gibi çalışmaya devam eder.
const DISCOVERY_PORT := 7778
const DISCOVERY_MAGIC := "INSA_LAN_v1"
const DISCOVERY_BEACON_INTERVAL := 1.0
const DISCOVERY_STALE_SEC := 4.0

signal lan_games_updated

var _discovery_send_peer: PacketPeerUDP = null
var _discovery_beacon_timer: float = 0.0
var _discovery_hosting_port: int = 0

var _discovery_listen_peer: PacketPeerUDP = null
var _discovery_listening: bool = false
## key "ip:port" (String) -> {"ip":String, "port":int, "name":String, "last_seen_msec":int}
var _discovered_games: Dictionary = {}


## Yerel ağdaki (192.168.x.x / 10.x.x.x / 172.16-31.x.x) IPv4 adresini döner, yoksa "".
## host_lan()'da room_code'a otomatik yazmak için kullanılır - kullanıcı bir daha CMD'de
## "ipconfig" çalıştırıp kendi IP'sini aramak zorunda kalmasın diye.
static func get_local_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		if _is_private_lan_ipv4(addr):
			return addr
	return ""


static func _is_private_lan_ipv4(ip: String) -> bool:
	if ip.count(".") != 3:
		return false
	if ip.begins_with("192.168.") or ip.begins_with("10."):
		return true
	if ip.begins_with("172."):
		var parts: PackedStringArray = ip.split(".")
		if parts.size() == 4 and parts[1].is_valid_int():
			var second: int = int(parts[1])
			return second >= 16 and second <= 31
	return false


func _start_lan_beacon(port: int) -> void:
	_discovery_hosting_port = port
	_discovery_beacon_timer = 0.0
	var peer := PacketPeerUDP.new()
	peer.set_broadcast_enabled(true)
	_discovery_send_peer = peer
	_send_lan_beacon()


func _stop_lan_beacon() -> void:
	_discovery_send_peer = null
	_discovery_hosting_port = 0


func _send_lan_beacon() -> void:
	if _discovery_send_peer == null:
		return
	## "|" ile ayrılan 3 alan: sihirli önek (rastgele ağ trafiğine yanlış tepki
	## vermemek için) + host adı ("|" karakteri ismde olamaz, güvenlik için değiştirilir)
	## + gerçek oyun (ENet) portu.
	var safe_name: String = local_player_name.replace("|", " ")
	var payload: PackedByteArray = ("%s|%s|%d" % [DISCOVERY_MAGIC, safe_name, _discovery_hosting_port]).to_utf8_buffer()
	var peer: PacketPeerUDP = _discovery_send_peer
	## DÜZELTME (gerçek makinede test edilip bulundu): genel yayın adresi
	## (255.255.255.255) bu makinede bir VPN/sanal ağ bağdaştırıcısı (Radmin/Hamachi
	## türü, bkz. dosya başı "internet üzerinden oynamak için..." notu) üzerinden
	## çıkıyor - gerçek LAN'a hiç ulaşmayabiliyor. Alt ağa YÖNELİK yayın adresini de
	## (ör. 192.168.1.255, /24 varsayımıyla - ev/ofis ağlarının BÜYÜK ÇOĞUNLUĞU) AYRICA
	## gönderiyoruz; aynı küçük paket saniyede bir kez, ikisi de göndermek zararsız.
	peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	peer.put_packet(payload)
	var subnet_bcast: String = _guess_subnet_broadcast(get_local_lan_ip())
	if subnet_bcast != "":
		peer.set_dest_address(subnet_bcast, DISCOVERY_PORT)
		peer.put_packet(payload)


static func _guess_subnet_broadcast(local_ip: String) -> String:
	if local_ip == "" or local_ip.count(".") != 3:
		return ""
	var parts: PackedStringArray = local_ip.split(".")
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]


## Lobi ekranı açıldığında (henüz bir odaya bağlanmamışken) çağrılır - bkz. lobby_menu.gd.
## Bağlanınca (host olunca ya da katılınca) OTOMATİK durdurulur (host_lan/join_lan).
func start_lan_discovery_listen() -> void:
	if _discovery_listening:
		return
	var peer := PacketPeerUDP.new()
	var err: Error = peer.bind(DISCOVERY_PORT)
	if err != OK:
		## Port başka bir yerel süreç tarafından tutuluyor olabilir (ör. AYNI PC'de
		## açılmış ikinci bir test istemcisi, bkz. CLAUDE.md) - sessizce vazgeç,
		## "Bulunan Oyunlar" listesi boş kalır ama manuel IP alanı bozulmaz.
		return
	_discovery_listen_peer = peer
	_discovery_listening = true
	_discovered_games.clear()


func stop_lan_discovery_listen() -> void:
	_discovery_listen_peer = null
	_discovery_listening = false
	_discovered_games.clear()


func get_discovered_lan_games() -> Array:
	var out: Array = _discovered_games.values()
	out.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	return out


func _poll_lan_discovery() -> void:
	if not _discovery_listening or _discovery_listen_peer == null:
		return
	var peer: PacketPeerUDP = _discovery_listen_peer
	var changed: bool = false
	while peer.get_available_packet_count() > 0:
		var buf: PackedByteArray = peer.get_packet()
		var parts: PackedStringArray = buf.get_string_from_utf8().split("|")
		if parts.size() == 3 and parts[0] == DISCOVERY_MAGIC and parts[2].is_valid_int():
			var ip: String = peer.get_packet_ip()
			var g_port: int = int(parts[2])
			var key: String = "%s:%d" % [ip, g_port]
			_discovered_games[key] = {"ip": ip, "port": g_port, "name": parts[1], "last_seen_msec": Time.get_ticks_msec()}
			changed = true
	## Beacon'ı kesilen (host kapanmış/ayrılmış) oyunları listeden düşür.
	var now: int = Time.get_ticks_msec()
	for key in _discovered_games.keys():
		if now - int(_discovered_games[key]["last_seen_msec"]) > int(DISCOVERY_STALE_SEC * 1000.0):
			_discovered_games.erase(key)
			changed = true
	if changed:
		lan_games_updated.emit()


func disconnect_from_room(show_status: bool = true) -> void:
	_clear_peer_state()
	if show_status:
		connection_status_changed.emit("Bağlantı kesildi.")


func _clear_peer_state() -> void:
	if _peer:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	is_multiplayer_active = false
	is_host = false
	_host_peer = 0
	room_code = ""
	lobby_players.clear()
	_last_broadcast_at.clear()
	_pending_xp_sync = false
	_xp_sync_timer = 0.0
	_pending_removed_drops.clear()
	_drop_remove_timer = 0.0
	## #58: bir sonraki oda/oyuna eski odadan kalma "biri hâlâ sandık açıyor"
	## durumuyla girilmesin diye.
	chest_busy_peers.clear()
	level_up_busy_peers.clear()
	level_up_timer_active = false
	## bkz. _is_game_in_progress/_is_rejoining_midgame üstündeki DÜZELTME
	## notu - eski odadan kalan bu bayraklarla yeni bir odaya girilmesin.
	_is_game_in_progress = false
	_is_rejoining_midgame = false
	## Oda kapandı/bağlantı kesildi - host'sak artık "buradayım" yayınını durdur
	## (bkz. LAN OTOMATİK KEŞİF bloğu). Dinleme YENİDEN başlatılmıyor burada -
	## lobby_menu.gd _ready()'de zaten tekrar start_lan_discovery_listen() çağırır.
	_stop_lan_beacon()


func _on_connected_to_server() -> void:
	var my_id: int = multiplayer.get_unique_id()
	## Sunucu (host) her zaman peer id 1'dir; bu callback sadece client'ta tetiklenir.
	is_host = false
	_host_peer = 1

	lobby_players[my_id] = {
		"name": local_player_name,
		"char_id": local_char_id,
		"is_ready": is_host,
		"is_host": is_host
	}

	connection_status_changed.emit("Sunucuya bağlanıldı! Adres: " + room_code)
	lobby_updated.emit()

	# Broadcast our info to everyone in the room
	_rpc_sync_player_info.rpc(local_player_name, local_char_id, is_host)


## Bağlı diğer peer'ler (Godot'nun multiplayer.get_peers() davranışı gereği KENDİMİZ hariç).
func _real_peers() -> Array:
	var out: Array = []
	if not multiplayer.has_multiplayer_peer():
		return out
	for p in multiplayer.get_peers():
		out.append(int(p))
	return out


## Host'u belirler: ENet sunucusu = peer id 1 = host, host devri YOK (bkz. dosya başı not).
## Parametre eski çağıranlarla uyum için duruyor, artık bir anlamı yok.
func _refresh_host(_include_self_floor: bool = true) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var was_host: bool = is_host
	var me: int = multiplayer.get_unique_id()
	_host_peer = 1
	is_host = (me == 1)
	if lobby_players.has(me):
		lobby_players[me]["is_host"] = is_host
	if is_host and not was_host:
		_on_became_host()


## bkz. became_host sinyali üstündeki DÜZELTME notu. _next_drop_id burada
## (autoload'ın kendi sorumluluğu olan tek sayaç) doğrudan yeniden
## tohumlanır; enemy_spawner.gd gibi diğer node'lar için sinyal yayınlanır.
func _on_became_host() -> void:
	var max_drop_id: int = 0
	for group_name in ["xp_orbs", "gold_drops", "food_drops", "magnet_drops", "chest_drops"]:
		for n: Node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(n):
				max_drop_id = max(max_drop_id, int(n.get_meta("drop_network_id", 0)))
	for id in _visual_drops.keys():
		max_drop_id = max(max_drop_id, int(id))
	_next_drop_id = max_drop_id + 1
	became_host.emit()


@rpc("any_peer", "reliable")
func _rpc_set_player_ready(is_ready: bool) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if lobby_players.has(sender_id):
		lobby_players[sender_id]["is_ready"] = is_ready
		lobby_updated.emit()


func set_local_ready(is_ready: bool) -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if my_id <= 0:
		return
	if lobby_players.has(my_id):
		lobby_players[my_id]["is_ready"] = is_ready
		lobby_updated.emit()
		_rpc_set_player_ready.rpc(is_ready)
	## Kullanıcı isteği: "oyundan çıkmış biri tekrar oda kodunu girerek hazır
	## olma tuşuyla oyuna katılabilmeli" - oyun zaten başlamışken (host bu
	## odada _rpc_start_game'i çoktan çalıştırdıysa) "HAZIRIM"a basmak,
	## host'un bir daha "OYUNU BAŞLAT"a basmasını beklemeden doğrudan bu
	## oyuncuyu oyuna sokma isteği gönderir.
	if is_ready and _is_game_in_progress and not is_host:
		request_join_in_progress_game.rpc_id(_host_peer_id())


## Kullanıcı isteği: "insanlar lobiye girdikten sonra ismini değiştiremiyor"
## - kök neden: local_player_name/lobby_players sadece host_lan/
## join_lan sırasında BİR KEZ yazılıyordu, odaya girdikten SONRA
## ismi değiştirip yeniden yayınlayan hiçbir yol yoktu (bkz. lobby_menu.gd
## PlayerNameInput - text_submitted artık bunu çağırıyor). Boşsa yok sayılır,
## host DAHİL herkes için çalışır (host da _rpc_sync_player_info ile kendi
## güncel ismini diğerlerine yayınlar).
func update_local_player_name(new_name: String) -> void:
	var trimmed: String = new_name.strip_edges()
	if trimmed.is_empty():
		return
	local_player_name = trimmed
	_save_local_player_name()
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if my_id > 0 and lobby_players.has(my_id):
		lobby_players[my_id]["name"] = trimmed
		lobby_updated.emit()
	if is_multiplayer_active and multiplayer.has_multiplayer_peer():
		_rpc_sync_player_info.rpc(local_player_name, local_char_id, is_host)


func all_players_ready() -> bool:
	if lobby_players.is_empty():
		return false
	for info: Dictionary in lobby_players.values():
		if not info.get("is_ready", false):
			return false
	return true


## Yerel oyuncu, loading_screen.gd'de main.tscn'i tamamen yükleyip barını
## doldurunca çağırılır. Tekli oyuncuda bu bilginin bir önemi yok (loading_
## screen zaten hemen devam eder), sadece multiplayer'da diğer herkese
## yayınlanır - bkz. all_players_loading_done.
func mark_local_loading_done() -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	_loading_done[my_id] = true
	if is_multiplayer_active and multiplayer.has_multiplayer_peer():
		_rpc_mark_loading_done.rpc()


@rpc("any_peer", "reliable")
func _rpc_mark_loading_done() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id > 0:
		_loading_done[sender_id] = true


## Tekli oyuncuda her zaman true (bekleyecek başka kimse yok). Multiplayer'da
## lobideki HERKES (bkz. lobby_players - oyun başlarken zaten tüm peer'lerde
## aynı) kendi yüklemesini bitirmiş olmalı. Bir oyuncu bağlantısı koparsa
## _on_peer_disconnected onu lobby_players'tan siler, böylece kalanlar onu
## sonsuza dek beklemeye devam etmez.
func all_players_loading_done() -> bool:
	if not is_multiplayer_active:
		return true
	## bkz. _is_rejoining_midgame üstündeki DÜZELTME notu - geç katılan
	## oyuncu diğerlerini beklemez, onlar zaten oyunda.
	if _is_rejoining_midgame:
		return true
	if lobby_players.is_empty():
		return true
	for pid in lobby_players.keys():
		if not _loading_done.get(pid, false):
			return false
	return true


## ==============================================================================
## YENİDEN BAŞLATMA ONAYI (kullanıcı isteği: "Multiplayerda host oyunu
## yeniden başlatabilsin eskiden yeniden başlatmayı seçerek fakat önce diğer
## oyunculara onayı sorulsun") - SADECE host isteği başlatabilir; TÜM
## bağlı oyunculara bir Onayla/Reddet sorusu gider, HERKES onaylarsa
## (host'un kendi isteği zaten kendiliğinden bir "evet" sayılır) HERKES odaya
## (lobi ekranına) döner: bağlantı ve oyuncu listesi korunur, "hazır" durumları
## sıfırlanır, herkes karakterini YENİDEN seçip hazır olur ve host "OYUNU
## BAŞLAT"a basınca normal start akışıyla (_rpc_start_game) yeni oyun başlar.
## DÜZELTME (kullanıcı bildirimi: "yeniden başlat butonuna basıp onay alınca oyun
## yeniden başlamıyor, ben zaten direkt aynı oyunu yeniden başlatsın istemiyorum,
## odaya atıp var olan oyuncularla tekrar karakter seçimi yaparak başlasın"):
##  1) kök neden - oylama sırasında ağaç DURAKLATILIYOR (pause_menu.gd/main.gd),
##     onaylanınca kimse duraklatmayı kaldırmıyordu; eskiden doğrudan
##     _rpc_start_game() ile açılan yükleme ekranı duraklı ağaçta hiç ilerlemeden
##     (_process çalışmıyor) sonsuza dek takılıyordu. Artık _return_to_lobby_for_restart
##     duraklatmayı kaldırır.
##  2) akış - aynı oyuna doğrudan yeniden giriş yerine oda ekranı.
## Herhangi biri reddederse ya da RESTART_VOTE_TIMEOUT içinde herkes cevap
## vermezse istek İPTAL edilir, kimse yeniden başlatılmaz.
## ==============================================================================
var restart_vote_pending: bool = false
var restart_vote_responses: Dictionary = {} ## peer_id -> bool (onayladı mı)
const RESTART_VOTE_TIMEOUT := 20.0
var _restart_vote_timer: float = 0.0

signal restart_request_received ## client: host onay istiyor, bir Onayla/Reddet diyaloğu göster
signal restart_vote_result(approved: bool, rejecter_name: String) ## herkes: oylama bitti, sonucu bildir


## Sadece host tarafından çağrılır (bkz. pause_menu.gd _on_restart).
func request_restart_vote() -> void:
	if not is_host or not is_multiplayer_active or restart_vote_pending:
		return
	restart_vote_pending = true
	restart_vote_responses.clear()
	_restart_vote_timer = RESTART_VOTE_TIMEOUT
	## Host isteği başlattığı için zaten onaylamış sayılır - kendine ayrıca
	## bir diyalog gösterilmez.
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if my_id > 0:
		restart_vote_responses[my_id] = true
	_rpc_request_restart_vote.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_restart_vote() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != _host_peer_id():
		return
	restart_request_received.emit()


## Her client (host HARİÇ - kendi oyu request_restart_vote()'ta zaten
## verildi) diyalogdaki cevabını bununla host'a gönderir.
func submit_restart_vote(approved: bool) -> void:
	if not is_multiplayer_active or is_host:
		return
	_rpc_submit_restart_vote.rpc_id(_host_peer_id(), multiplayer.get_unique_id(), approved)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_restart_vote(peer_id: int, approved: bool) -> void:
	if not is_host or not restart_vote_pending:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != peer_id:
		return
	restart_vote_responses[peer_id] = approved
	## Biri reddettiyse geri kalanları beklemeye gerek yok, hemen iptal et.
	if not approved:
		_finish_restart_vote(peer_id)
		return
	_check_restart_vote_complete()


func _check_restart_vote_complete() -> void:
	if not restart_vote_pending:
		return
	for pid in lobby_players.keys():
		if not restart_vote_responses.has(pid):
			return ## hâlâ birinin cevabı bekleniyor
	_finish_restart_vote(0)


## rejecter_peer_id > 0 ise İSTEK O KİŞİ YÜZÜNDEN reddedildi demektir (erken
## çıkış); 0 ise ya herkes onayladı ya da zaman aşımı (bkz. update_restart_
## vote_timer) - iki durumda da mevcut restart_vote_responses'a bakılarak
## nihai karar hesaplanır (zaman aşımında cevap vermeyenler "onaylamadı"
## sayılır, bkz. o fonksiyon).
func _finish_restart_vote(rejecter_peer_id: int) -> void:
	if not restart_vote_pending:
		return
	restart_vote_pending = false
	var all_approved: bool = rejecter_peer_id <= 0
	if all_approved:
		for approved in restart_vote_responses.values():
			if not approved:
				all_approved = false
				break
	var rejecter_name: String = get_player_names([rejecter_peer_id]) if rejecter_peer_id > 0 else ""
	_rpc_broadcast_restart_vote_result.rpc(all_approved, rejecter_name)


@rpc("any_peer", "call_local", "reliable")
func _rpc_broadcast_restart_vote_result(approved: bool, rejecter_name: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != _host_peer_id():
		return
	restart_vote_pending = false
	restart_vote_result.emit(approved, rejecter_name)
	## Onaylandıysa HER peer (host dahil) bu sonucu kendi tarafında işleyip odaya döner -
	## sonuç zaten tüm peer'lere güvenilir kanaldan gidiyor, ayrıca bir "başlat" RPC'sine gerek yok.
	if approved:
		_return_to_lobby_for_restart()


## true iken lobby_menu.gd açılışta "yeniden başlatma onaylandı" bilgisini gösterir (bir kez).
var restart_returned_to_lobby: bool = false


## Yeniden başlatma onaylanınca oyun oturumuna ait TÜM durumu sıfırlar - bağlantı (lobby_players,
## isimler, host) KORUNUR. Sahne değiştirmez (bkz. _return_to_lobby_for_restart), böylece
## tek başına test edilebilir.
func _reset_for_restart_lobby() -> void:
	get_tree().paused = false
	GameManager.reset()
	restart_vote_pending = false
	restart_vote_responses.clear()
	_restart_vote_timer = 0.0
	_loading_done.clear()
	_is_game_in_progress = false
	_is_rejoining_midgame = false
	## Önceki oyundan kalma "biri hâlâ sandık/level/dükkan ekranında" bekleme durumları yeni oyuna sızmasın.
	chest_busy_peers.clear()
	chest_countdown_active = false
	level_up_busy_peers.clear()
	level_up_timer_active = false
	mini_shop_pending_peers.clear()
	mini_shop_timer_active = false
	_mini_shop_first_close_happened = false
	_confirmed_dead_peers.clear()
	_pending_revive_responses.clear()
	_pending_removed_drops.clear()
	_visual_drops.clear()
	_pending_xp_sync = false
	## Lobideki ilk halinin aynısı: sadece host hazır, herkes karakterini yeniden seçip "HAZIRIM"a basar.
	for pid in lobby_players.keys():
		lobby_players[pid]["is_ready"] = (int(pid) == _host_peer_id())
	restart_returned_to_lobby = true


func _return_to_lobby_for_restart() -> void:
	_reset_for_restart_lobby()
	lobby_updated.emit()
	get_tree().change_scene_to_file("res://scenes/lobby_menu.tscn")


## network_manager.gd _process()'inden koşulsuz her karede tiklenir (diğer
## geri sayımlarla - level atlama/sandık/mini dükkan - AYNI desen).
func update_restart_vote_timer(delta: float) -> void:
	if not restart_vote_pending or not is_host:
		return
	_restart_vote_timer -= delta
	if _restart_vote_timer <= 0.0:
		## Zaman aşımı - cevap vermeyen herkes "onaylamadı" sayılır, bu
		## yüzden en az bir eksik varsa sonuç otomatik olarak "reddedildi".
		for pid in lobby_players.keys():
			if not restart_vote_responses.has(pid):
				restart_vote_responses[pid] = false
		_finish_restart_vote(0)


func close_room() -> void:
	if not is_host:
		return
	_rpc_close_room.rpc()
	disconnect_from_room()


@rpc("any_peer", "call_local", "reliable")
func _rpc_close_room() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != _host_peer_id():
		return
	## sender_id == 0 -> bu, host'un KENDİ çağrısı (yerel) - host'a "host
	## ayrıldı" bildirimi göstermeye gerek yok, sadece client'larda (sender_id
	## != 0, yani ağdan gelen bir çağrı olarak alındıysa) tetikleniyor.
	if sender_id != 0:
		host_left_game.emit()
	disconnect_from_room()


## Host = ENet sunucusu = HER ZAMAN peer id 1 - bkz. _refresh_host.
## Henüz belirlenmediyse (bağlı değilsek) 0 döner.
func _host_peer_id() -> int:
	return _host_peer


func _on_connection_failed() -> void:
	if not is_multiplayer_active:
		return
	_clear_peer_state()
	connection_status_changed.emit("Sunucuya bağlanılamadı. IP/port doğru mu ve host sunucuyu kurdu mu?")


func _on_server_disconnected() -> void:
	if not is_multiplayer_active:
		return
	_clear_peer_state()
	connection_status_changed.emit("Sunucu bağlantısı koptu.")
	server_disconnected.emit()


func _on_peer_connected(peer_id: int) -> void:
	# Send our info to the newly joined peer
	var my_info: Dictionary = lobby_players.get(multiplayer.get_unique_id(), {
		"name": local_player_name,
		"char_id": local_char_id,
		"is_ready": is_host,
		"is_host": is_host
	})
	_rpc_sync_player_info.rpc_id(peer_id, my_info["name"], my_info["char_id"], my_info.get("is_host", false))


func _on_peer_disconnected(peer_id: int) -> void:
	var left_name: String = ""
	if lobby_players.has(peer_id):
		left_name = str(lobby_players[peer_id].get("name", "Bir oyuncu"))
		lobby_players.erase(peer_id)
		## bkz. _check_all_players_dead üstündeki DÜZELTME notu - son canlı
		## oyuncu ölmek yerine bağlantısı koparsa, geride kalan (zaten kalıcı
		## ölü) takım sonsuza dek "izleyicisin" ekranında takılı kalmasın.
		_check_all_players_dead()
	## DÜZELTME: ayrılan peer kart/silah/kalkan seçerken kopmuşsa (level_up_
	## busy_peers'ta kalmış olabilir) TEMİZLENMEZSE geri kalan herkes
	## SONSUZA KADAR "bir oyuncu seçim yapıyor" bekleme durumunda donup
	## kalırdı - chest_busy_peers ile AYNI düzeltme.
	if level_up_busy_peers.has(peer_id):
		level_up_busy_peers.erase(peer_id)
		level_up_busy_state_changed.emit()
	## #58 DÜZELTME: ayrılan peer sandık seçerken kopmuşsa (chest_busy_peers'ta
	## kalmış olabilir) TEMİZLENMEZSE geri kalan herkes SONSUZA KADAR "bir
	## oyuncu sandık açıyor" bekleme ekranında donup kalırdı.
	if chest_busy_peers.has(peer_id):
		chest_busy_peers.erase(peer_id)
		chest_busy_state_changed.emit()
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "bazen bir anda tüm yaratıklar
	## donuyor") - level_up_pending_peers/chest_busy_peers'la AYNI temizlik,
	## eskiden mini_shop_pending_peers burada HİÇ temizlenmiyordu: ayrılan
	## peer mini dükkanı kapatmadan kopmuşsa, kalan oyuncular "herkes kapattı
	## mı" kontrolünü (_check_all_mini_shop_closed) bir daha asla hızlı yoldan
	## geçemiyor, her seferinde 30sn'lik sayacın dolmasını beklemek zorunda
	## kalıyordu.
	if mini_shop_pending_peers.has(peer_id):
		mini_shop_pending_peers.erase(peer_id)
		_check_all_mini_shop_closed()
	## Ayrılan peer host'tuysa, kalan en düşük id yeni host olur - hiçbir
	## zamanlayıcı/oylama gerekmez (bkz. dosya başı notu).
	_refresh_host()
	lobby_updated.emit()
	## Kullanıcı bildirimi: "katılımcılar oyundan çıkınca veya bağlantısı
	## kesilince oyundan çıktığını gösteren bir bildirim yok" - kalan
	## herkese kimin ayrıldığını gösteren bir toast bildirimi tetikler.
	## DÜZELTME (kullanıcı bildirimi: "necromancer oynayınca yaratıklar bazen
	## kopyalanıyor ve insanlar rasgele oyundan atılıyor"): buraya kadar
	## SADECE bir bildirim gösteriliyordu - ayrılan oyuncunun RemotePlayer
	## kuklası (ve varsa üstündeki necromancer yaratık kozmetik kopyaları,
	## bkz. remote_player.gd _pet_visuals) sahneden HİÇ kaldırılmıyordu.
	## Biri relay'in flood/bütçe sınırını aşıp (bkz. should_throttle üstündeki
	## Ziva notu) "atılıp" sonra yeniden bağlandığında, ESKİ (artık hayalet)
	## kuklası sahnede donuk kalmaya devam ederken YENİ bir peer_id ile TAZE
	## bir kukla daha oluşuyordu - "aynı oyuncu/yaratıkları ikiye katlanmış"
	## görüntüsünün asıl kaynağı muhtemelen buydu. Artık peer_id de sinyalle
	## birlikte gönderiliyor, main.gd bu id'ye ait RemotePlayer'ı (ve onun
	## tüm pet kozmetik kopyalarını) gerçekten sahneden kaldırıyor.
	if is_multiplayer_active and not left_name.is_empty():
		player_left_game.emit(left_name, peer_id)


@rpc("any_peer", "reliable")
func _rpc_sync_player_info(p_name: String, p_char_id: int, p_is_host: bool) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var prev_ready: bool = false
	if lobby_players.has(sender_id):
		prev_ready = lobby_players[sender_id].get("is_ready", false)
	else:
		prev_ready = (sender_id == _host_peer)
	lobby_players[sender_id] = {
		"name": p_name,
		"char_id": p_char_id,
		"is_ready": prev_ready,
		"is_host": (sender_id == _host_peer)
	}
	lobby_updated.emit()


## ==============================================================================
## KART/SİLAH/KALKAN SEÇİM KUYRUĞU SENKRONİZASYONU (level atlama kartları +
## başlangıç silah/kalkan seçimi)
## ==============================================================================
## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini beklemeden
## tüm kartlarını seçebilsin FAKAT hepsini seçtikten sonra bekleme süresi
## başlayacak... hepsi ortak bir bekleme süresine bağlı olacak ve bu bekleme
## süresi son kartı seçtikten sonra başlayacak") - eskiden bu ekranlar (bkz.
## silinen level_up_pending_peers/start_team_level_up_waiting/mark_local_
## upgrade_chosen/_check_all_upgrades_chosen) HER TUR (her tek kart seçimi)
## ayrı bir "herkes bu turu seçti mi" turu açıp kapatıyordu - bir oyuncunun
## kendi kuyruğunda (main.gd _pending_level_ups) 5 kart olsa bile HER kartı
## diğer oyuncu(lar) da AYNI turu bitirmeden bir sonrakini GÖREMİYORDU.
##
## Artık chest_busy_peers/start_chest_countdown ile BİREBİR AYNI, KANITLANMIŞ
## deseni kullanıyor (bkz. o bloktaki kök neden notu - sandık kuyruğu zaten
## bu deseni kullanıyordu): HER oyuncu kendi kuyruğunu TAMAMEN kendi hızında,
## ağdan bağımsız olarak bitirir (main.gd _advance_level_up_queue artık
## ağı hiç beklemeden bir sonraki kartı hemen açıyor); sadece kuyruğu
## TÜKENİNCE "meşgul değilim" diye bildirir - oyun, EN SON biten oyuncu da
## bitirene kadar devam etmez. Geri sayım (level_up_countdown) sandığınkiyle
## AYNI şekilde HER yeni kart/silah/kalkan ekranı açıldığında 25sn'ye
## resetlenir - biri hâlâ (kendi kuyruğundaki bir sonraki) kartı seçtiği
## sürece kimse zaman aşımına uğramaz.
var level_up_busy_peers: Dictionary = {} ## peer_id -> true (kuyruğu hâlâ dolu)
var level_up_timer_active: bool = false
var level_up_countdown: float = 25.0

signal level_up_busy_state_changed
signal multiplayer_level_up_timer_tick(remaining: float)


## main.gd _advance_level_up_queue()/_show_item_select_screen() tarafından
## çağrılır - yerel kart/silah/kalkan kuyruğu meşgul/boş olduğunda TÜM
## peer'lere (kendimiz DAHİL, "call_local") bildirir. bkz. set_chest_busy
## ile AYNI desen.
func set_level_up_busy(busy: bool) -> void:
	if not is_multiplayer_active:
		return
	_rpc_set_level_up_busy.rpc(multiplayer.get_unique_id(), busy)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_level_up_busy(peer_id: int, busy: bool) -> void:
	if busy:
		level_up_busy_peers[peer_id] = true
	else:
		level_up_busy_peers.erase(peer_id)
	level_up_busy_state_changed.emit()


func is_any_level_up_busy() -> bool:
	return not level_up_busy_peers.is_empty()


## bkz. start_chest_countdown ile AYNI desen: TEK bir "reliable"+"call_local"
## RPC TÜM peer'lerde geri sayımı aynı anda 25sn'ye başlatır/resetler, her
## istemci kendi _process()'inde BAĞIMSIZ tikler. Her YENİ kart/silah/kalkan
## ekranı açıldığında (main.gd _show_level_up_screen/_show_item_select_screen)
## tekrar çağrılır - biri hâlâ kendi kuyruğundaki bir sonrakini seçtiği
## sürece kimse zaman aşımına uğramaz.
func start_level_up_countdown() -> void:
	if is_multiplayer_active:
		_rpc_start_level_up_countdown.rpc()
	else:
		level_up_timer_active = true
		level_up_countdown = 25.0


@rpc("any_peer", "call_local", "reliable")
func _rpc_start_level_up_countdown() -> void:
	level_up_timer_active = true
	level_up_countdown = 25.0


func stop_level_up_countdown() -> void:
	if is_multiplayer_active:
		_rpc_stop_level_up_countdown.rpc()
	else:
		level_up_timer_active = false


@rpc("any_peer", "call_local", "reliable")
func _rpc_stop_level_up_countdown() -> void:
	level_up_timer_active = false


## Kullanıcı isteği: "25 saniyelik bekleme sürelerinde (kart seçim, sandık
## seçim, dükkan vb) kimi beklediğimiz yazsın" - verilen peer_id listesini
## lobby_players'taki isimlere çevirir; level_up_screen.gd/weapon_select_
## screen.gd/mini_shop_screen.gd/chest_menu.gd HEPSİ bunu çağırır - isim
## çözümleme mantığı TEK yerde.
func get_player_names(peer_ids: Array) -> String:
	var names: Array = []
	for pid in peer_ids:
		var pname: String = "Oyuncu"
		if lobby_players.has(pid):
			pname = str(lobby_players[pid].get("name", "Oyuncu"))
		names.append(pname)
	return ", ".join(names)


## Şu an kart/silah/kalkan kuyruğu dolu (hâlâ seçim yapmakla meşgul)
## oyuncuların isimleri - bkz. get_chest_busy_names ile AYNI desen.
func get_level_up_busy_names() -> String:
	return get_player_names(level_up_busy_peers.keys())


## Mini dükkanı henüz kapatmamış oyuncuların isimleri.
func get_mini_shop_pending_names() -> String:
	var pending: Array = []
	for pid in mini_shop_pending_peers.keys():
		if not mini_shop_pending_peers[pid]:
			pending.append(pid)
	return get_player_names(pending)


## Şu an sandık açmakla meşgul oyuncuların isimleri.
func get_chest_busy_names() -> String:
	return get_player_names(chest_busy_peers.keys())


func update_level_up_timer(delta: float) -> void:
	if not level_up_timer_active:
		return
	level_up_countdown = max(0.0, level_up_countdown - delta)
	multiplayer_level_up_timer_tick.emit(level_up_countdown)


## ==============================================================================
## MİNİ DÜKKAN SENKRONİZASYONU (kullanıcı isteği: "her 3 dakikada bir mini
## dükkan açılsın") - level_up_pending_peers/_rpc_peer_chose_upgrade/
## update_level_up_timer üstteki bloğun BİREBİR AYNI deseni, sadece "seçim
## yapıldı" yerine "kapat'a basıldı" tetikleyicisiyle. Mini dükkan mandatory
## pick GEREKTİRMEDİĞİ için (level-up'tan farklı - 0/1/2/3 kart alınabilir)
## "seçim" burada sadece "ekranı kapattım" anlamına geliyor.
## ==============================================================================
var mini_shop_pending_peers: Dictionary = {} ## peer_id -> bool (kapattı mı)
var mini_shop_timer_active: bool = false
var mini_shop_countdown: float = 30.0
## Kullanıcı isteği: "bir kişi dükkanda çarpıya basınca diğerlerinin bekleme
## süresi başlayacak." - dükkan açıldığında başlayan sayaç (aşağıdaki güvenlik
## ağı) DEĞİŞMEDİ; ek olarak İLK kapatma anında kalan oyuncular için bekleme
## süresi (yeniden) başlatılıyor. Bu bayrak "ilk kapatma oldu mu" ve "yeni bir
## dükkan oturumu başladı mı" durumunu tutar - ikinci/üçüncü kapatmalar süreyi
## uzatmasın diye sadece ilkinde sıfırlanır.
const MINI_SHOP_WAIT_AFTER_FIRST_CLOSE := 30.0
var _mini_shop_first_close_happened: bool = false

signal multiplayer_mini_shop_timer_tick(remaining: float)
signal multiplayer_mini_shop_all_closed


## BUG DÜZELTMESİ (kullanıcı bildirimi: "bazen bir anda tüm yaratıklar
## donuyor genel bir ağ sorunu var") - kök neden: mini dükkan mandatory pick
## gerektirmediği için (bkz. dosya başı notu) mini_shop_timer_active eskiden
## SADECE birisi "Kapat"a basınca/alışveriş yapınca (_rpc_peer_closed_mini_
## shop) devreye giriyordu. Mini dükkan 3 dakikada bir OTOMATİK açıldığı ve
## hiçbir zorunlu etkileşim gerektirmediği için, takımdaki HERKES aynı anda
## (ör. savaş ortasında) ekranı fark etmeyip hiç dokunmazsa bu sayaç asla
## başlamıyor, get_tree().paused HİÇBİR client'ta (host dahil) bir daha asla
## false olmuyordu - host'un enemy_spawner.gd/enemy.gd'si PAUSABLE olduğu
## için bu TÜM takımın yaratıklarının kalıcı olarak donması demekti. Sandık
## kuyruğundaki AYNI hata sınıfı zaten CHEST_QUEUE_TOTAL_TIMEOUT_MSEC ile
## koşulsuz bir üst sınırla çözülmüştü - burada da AYNI mantıkla, sayaç artık
## kimse dokunmasa bile ekran açılır açılmaz (her client kendi local
## açılışında bunu çağırıyor, bkz. main.gd _show_mini_shop_screen) koşulsuz
## başlıyor.
func start_team_mini_shop_waiting() -> void:
	if not is_multiplayer_active:
		return
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	for pid in lobby_players.keys():
		if not mini_shop_pending_peers.has(pid):
			mini_shop_pending_peers[pid] = false
	if my_id >= 1 and not mini_shop_pending_peers.has(my_id):
		mini_shop_pending_peers[my_id] = false
	## Yeni bir dükkan oturumu: "ilk kapatma" bayrağı sıfırlanır ki bu
	## oturumda da birileri çarpıya bastığında kalanların bekleme süresi
	## başlasın (bkz. _begin_mini_shop_waiting_after_first_close).
	_mini_shop_first_close_happened = false
	if not mini_shop_timer_active:
		mini_shop_timer_active = true
		mini_shop_countdown = MINI_SHOP_WAIT_AFTER_FIRST_CLOSE


## Kullanıcı isteği: "bir kişi dükkanda çarpıya basınca diğerlerinin bekleme
## süresi başlayacak." - dükkan açıldığında zaten bir GÜVENLİK
## sayacı başlıyor (bkz. yukarıdaki not: hiç kimse dokunmazsa oyun kalıcı
## olarak donmasın diye). Bu fonksiyon onun ÜSTÜNE, ilk kapatma anında kalan
## oyuncular için bekleme süresini YENİDEN 30 saniyeye kurar: o ana kadar
## rahatça alışveriş yapan oyuncular, birileri bitirir bitirmez "kalan süre"
## içinde kendi işlerini bitirmek zorunda kalır (süre dolarsa host herkesi
## zorla devam ettirir - bkz. update_mini_shop_timer).
## Tüm peer'lerde çağrılır (RPC "call_local"), böylece sayaç herkeste aynı anda
## sıfırlanır.
func _begin_mini_shop_waiting_after_first_close() -> void:
	if _mini_shop_first_close_happened:
		return ## sadece İLK kapatma süreyi başlatır, sonrakiler uzatmaz
	_mini_shop_first_close_happened = true
	mini_shop_timer_active = true
	mini_shop_countdown = MINI_SHOP_WAIT_AFTER_FIRST_CLOSE


## "Birisi çarpıya bastı mı?" - main.gd, dükkanı hâlâ açık olan oyunculara
## kalan süreyi gösterip göstermeyeceğine karar verirken kullanır (o sayaç
## dükkan açılır açılmaz DEĞİL, ilk kapatmadan sonra anlamlıdır).
func is_mini_shop_wait_started() -> bool:
	return _mini_shop_first_close_happened


func mark_local_mini_shop_closed() -> void:
	if not is_multiplayer_active:
		return
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	mini_shop_pending_peers[my_id] = true
	_rpc_peer_closed_mini_shop.rpc(my_id)


@rpc("any_peer", "call_local", "reliable")
func _rpc_peer_closed_mini_shop(p_id: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != p_id:
		return
	mini_shop_pending_peers[p_id] = true
	## Kullanıcı isteği: bir kişi çarpıya bastığı an DİĞERLERİNİN bekleme
	## süresi başlar (bkz. fonksiyon üstündeki not) - dükkan açılışında
	## başlayan güvenlik sayacının yerine geçmez, onu tazeler.
	_begin_mini_shop_waiting_after_first_close()
	_check_all_mini_shop_closed()


func _check_all_mini_shop_closed() -> void:
	if not is_host:
		return
	for pid in lobby_players.keys():
		if not mini_shop_pending_peers.has(pid):
			mini_shop_pending_peers[pid] = false
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if my_id >= 1 and not mini_shop_pending_peers.has(my_id):
		mini_shop_pending_peers[my_id] = false

	if mini_shop_pending_peers.is_empty():
		return
	var all_done: bool = true
	for pid in mini_shop_pending_peers.keys():
		if not mini_shop_pending_peers[pid]:
			all_done = false
			break
	if all_done:
		mini_shop_timer_active = false
		mini_shop_pending_peers.clear()
		_rpc_broadcast_mini_shop_all_closed.rpc()


func update_mini_shop_timer(delta: float) -> void:
	if not mini_shop_timer_active:
		return
	mini_shop_countdown = max(0.0, mini_shop_countdown - delta)
	multiplayer_mini_shop_timer_tick.emit(mini_shop_countdown)
	if mini_shop_countdown <= 0.0:
		if is_host:
			mini_shop_timer_active = false
			mini_shop_pending_peers.clear()
			_rpc_broadcast_mini_shop_all_closed.rpc()
		else:
			mini_shop_timer_active = false


@rpc("any_peer", "call_local", "reliable")
func _rpc_broadcast_mini_shop_all_closed() -> void:
	mini_shop_timer_active = false
	mini_shop_pending_peers.clear()
	multiplayer_mini_shop_all_closed.emit()


## ==============================================================================
## MİNİ DÜKKAN "ŞİMDİ AÇILSIN MI" KARARI (host otoritesi)
## ==============================================================================
## Kullanıcı bildirimi: "Level atladıktan sonra dükkan açılıyor ama ... bazen
## hostta açılıp diğer oyunlarda açılmıyor."
##
## KÖK NEDEN: 5 dakikalık bekleme süresi (GameManager._mini_shop_cooldown_
## remaining) HER peer'te YEREL sayılıyordu ve her peer kendi dükkan
## açılışında (bkz. main.gd _show_mini_shop_screen -> start_mini_shop_cooldown)
## kendi sayacını sıfırdan başlatıyordu. Peer'lerin dükkanı açıldığı AN farklı
## olduğu için (ör. ilk silah/kalkan seçimini herkes farklı anda bitiriyor,
## ayrıca kare hızı/duraklama süreleri farklı) sayaçlar birbirinden kayıyordu.
## Sonuç: AYNI level atlamasında host "süre doldu, dükkan açılsın" derken bir
## client "daha dolmadı" diyor, dükkan yalnızca bazı ekranlarda açılıyordu.
##
## ÇÖZÜM: karar TEK bir yerde veriliyor - çok oyunculuda HOST kendi bekleme
## süresine bakıp karar verir ve sonucu TÜM peer'lere yayınlar; client'lar
## kendi başlarına dükkan AÇMAZ, host'un kararını uygular (bkz. main.gd
## _resume_gameplay_after_level_flow/_on_mini_shop_decision_received).
## Client kararı alamazsa (kopma/host değişimi) kısa bir süre sonra yerel
## kararına düşer - oyun asla askıda kalmaz (bkz. main.gd
## MINI_SHOP_DECISION_WAIT/_on_mini_shop_decision_timeout).
signal mini_shop_decision_received(open_shop: bool)


## Host tarafından çağrılır (bkz. main.gd _resume_gameplay_after_level_flow) -
## "bu level atlamasından sonra dükkan açılacak mı" kararını yayınlar.
## "call_local" YOK: host kararı zaten doğrudan kendi akışında uyguluyor,
## ayrıca kendine mesaj göndermenin bir anlamı yok.
func broadcast_mini_shop_decision(open_shop: bool) -> void:
	if not is_multiplayer_active or not multiplayer.has_multiplayer_peer():
		return
	_rpc_mini_shop_decision.rpc(open_shop)


@rpc("any_peer", "reliable")
func _rpc_mini_shop_decision(open_shop: bool) -> void:
	## Kararı YALNIZCA host verir - başka bir peer'den gelen mesaj yok sayılır
	## (yoksa bir client takımın geri kalanına dükkan açtırabilirdi).
	if multiplayer.get_remote_sender_id() != _host_peer_id():
		return
	mini_shop_decision_received.emit(open_shop)


## ==============================================================================
## #58 DÜZELTME: SANDIK AÇILIŞI SENKRONİZASYONU
## ==============================================================================
## Kullanıcı bildirimi: "sandık açılımı esnasında oyun diğer oyuncularda
## devam ediyor gibi görünüyor kart bekleme ekranının aktif kalması
## gerekiyor o esnada." Sandık kuyruğu (bkz. GameManager.pending_chest_
## tiers) her oyuncuda AYRI/YEREL, ağdan bağımsız bir liste - biri 3 sandık
## toplamış, biri 1 olabilir. main.gd _try_open_next_pending_chest() eskiden
## kendi kuyruğu bitince SADECE kendi get_tree().paused'unu false yapıyordu -
## level_up_pending_peers'ın AKSİNE bu hiç ağa duyurulmuyordu, yani biri hâlâ
## kart seçerken kuyruğu daha kısa olan diğer oyuncu(lar)da oyun/simülasyon
## normal akmaya devam ediyordu. Artık her oyuncunun sandık kuyruğu meşgul/
## boş durumu chest_busy_peers üzerinden TÜM peer'lere bildiriliyor - hiçbir
## oyuncu, EN SON oyuncu da kendi kuyruğunu bitirene kadar devam edemiyor
## (bkz. main.gd _on_chest_busy_state_changed/_try_open_next_pending_chest).
var chest_busy_peers: Dictionary = {} ## peer_id -> true (kuyruğu hâlâ dolu)

signal chest_busy_state_changed


## main.gd _try_open_next_pending_chest() tarafından çağrılır - yerel sandık
## kuyruğu meşgul/boş olduğunda TÜM peer'lere (kendimiz DAHİL, "call_local")
## bildirir.
func set_chest_busy(busy: bool) -> void:
	if not is_multiplayer_active:
		return
	_rpc_set_chest_busy.rpc(multiplayer.get_unique_id(), busy)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_chest_busy(peer_id: int, busy: bool) -> void:
	if busy:
		chest_busy_peers[peer_id] = true
	else:
		chest_busy_peers.erase(peer_id)
	chest_busy_state_changed.emit()


func is_any_chest_busy() -> bool:
	return not chest_busy_peers.is_empty()


## ==============================================================================
## SANDIK SEÇİM GERİ SAYIMI (kullanıcı isteği: "bir oyuncu sandık seçerken
## diğer oyuncularda ve sandık seçen kişide 25 saniyelik bekleme süresi
## olmuyor, onun da bekleme süresi olması gerekiyor, tıpkı level kartı seçme
## ekranı gibi") - level atlama geri sayımıyla (bkz. yukarıdaki
## level_up_timer_active/level_up_countdown/update_level_up_timer) BİREBİR
## AYNI desen: TEK bir "reliable"+"call_local" RPC TÜM peer'lerde geri
## sayımı aynı anda 25sn'ye başlatır, sonrasında her istemci kendi
## _process()'inde BAĞIMSIZ tikler (sürekli RPC trafiği gerekmez). Sandık
## kuyrukları her oyuncuda AYRI/YEREL işlediği (bkz. chest_busy_peers notu)
## için start_chest_countdown() her YENİ sandık menüsü açıldığında (bkz.
## main.gd _try_open_next_pending_chest) tekrar çağrılıp süreyi 25sn'ye
## resetler - biri hâlâ (kendi kuyruğundaki bir sonraki) sandığı açtığı
## sürece kimse zaman aşımına uğramaz, sadece TEK bir karar 25sn'den uzun
## sürerse o kararı veren için otomatik seçim tetiklenir (bkz. chest_menu.gd
## _on_countdown_tick).
var chest_countdown_active: bool = false
var chest_countdown: float = 25.0

signal chest_countdown_tick(remaining: float)


func start_chest_countdown() -> void:
	if is_multiplayer_active:
		_rpc_start_chest_countdown.rpc()
	else:
		chest_countdown_active = true
		chest_countdown = 25.0


@rpc("any_peer", "call_local", "reliable")
func _rpc_start_chest_countdown() -> void:
	chest_countdown_active = true
	chest_countdown = 25.0


func stop_chest_countdown() -> void:
	if is_multiplayer_active:
		_rpc_stop_chest_countdown.rpc()
	else:
		chest_countdown_active = false


@rpc("any_peer", "call_local", "reliable")
func _rpc_stop_chest_countdown() -> void:
	chest_countdown_active = false


func update_chest_countdown(delta: float) -> void:
	if not chest_countdown_active:
		return
	chest_countdown = max(0.0, chest_countdown - delta)
	chest_countdown_tick.emit(chest_countdown)


@rpc("any_peer", "call_remote", "reliable")
func broadcast_weapon_attack(source_pos: Vector2, target_pos: Vector2, shop_key: String, _weapon_type: String) -> void:
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if not local_player:
		return
	## DÜZELTME (#55 - kullanıcı bildirimi: "topuzun görsel efektini
	## değiştirmiştim fakat multiplayerda diğer oyuncular eski versiyonunu
	## görüyor"): local oyuncu topuzu player.gd _configure_topuz_melee()
	## üzerinden zaten DOĞRU efekti (fx_topuz_slash.tscn) kullanıyordu, ama
	## bu kozmetik BROADCAST yolu (diğer oyunculara gösterilen kopya) hâlâ
	## eski/yanlış "fx_sovalye_slash.tscn"yi (şovalye kılıcının efekti)
	## yüklüyordu - iki yol birbirinden bağımsız, biri güncellenince öteki
	## unutulmuş.
	var slash_scene: PackedScene = null
	match shop_key:
		"dagger": slash_scene = load("res://scenes/fx_assasin_slash.tscn")
		"pence": slash_scene = load("res://scenes/fx_pence_slash.tscn")
		"uzunkilic": slash_scene = load("res://scenes/fx_uzunkilic_slash.tscn")
		"topuz": slash_scene = load("res://scenes/fx_topuz_slash.tscn")
		_: slash_scene = load("res://scenes/fx_assasin_slash.tscn")
	
	if slash_scene:
		var slash: Node2D = slash_scene.instantiate() as Node2D
		get_tree().current_scene.add_child(slash)
		var dir: Vector2 = (target_pos - source_pos).normalized()
		slash.global_position = target_pos - dir * 18.0
		slash.rotation = dir.angle()
		## DÜZELTME (2026-09-24, pençe efekti yenilenirken bulundu): kasterin kendi ekranında weapon.gd _spawn_slash_fx
		## efekti oyuncu kökünün ölçeğiyle (0.5, main.tscn) çarpıyor, bu kozmetik kopya çarpmıyordu - diğer oyuncular
		## TÜM yakın dövüş savuruşlarını 2 kat büyük görüyordu. Uzak kukla da aynı 0.5 ölçekte (remote_player.tscn).
		slash.scale *= (local_player as Node2D).scale



## Projectile broadcast: when a player fires a ranged weapon, other peers
## see the same projectile (visual-only, damage handled by host authority).
@rpc("any_peer", "call_remote", "unreliable")
func broadcast_projectile(scene_path: String, spawn_pos: Vector2, direction: Vector2, proj_speed: float, proj_scale: Vector2, target_pos: Vector2, player_id: int = 0) -> void:
	if not ResourceLoader.exists(scene_path):
		return
	var proj_scene: PackedScene = load(scene_path) as PackedScene
	if not proj_scene:
		return
	var proj: Node2D = proj_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(proj)
	proj.global_position = spawn_pos
	if "direction" in proj:
		proj.direction = direction
	if proj_speed > 0.0 and "speed" in proj:
		proj.speed = proj_speed
	if proj_scale != Vector2.ZERO:
		proj.scale = proj_scale
	if target_pos != Vector2.ZERO and "target_position" in proj:
		proj.target_position = target_pos
	if "face_direction" in proj and proj.face_direction:
		proj.rotation = direction.angle()
	# Tag as network-spawned so it doesn't deal duplicate damage on remote peers.
	proj.set_meta("network_spawned", true)
	# For boomerang return: set player_node to the remote player so it returns properly
	if player_id > 0 and "player_node" in proj:
		var rp: RemotePlayer = _find_remote_player(player_id)
		if rp:
			proj.player_node = rp
	if player_id > 0 and "return_callback_target" in proj:
		var rp2: RemotePlayer = _find_remote_player(player_id)
		if rp2:
			proj.return_callback_target = rp2


## Drop broadcast: when the host spawns XP/gold/food/chest drops, clients see
## visual-only copies (non-interactive) so the battlefield looks correct.
## Each drop gets a unique network_id so it can be removed when collected.
var _next_drop_id: int = 1
var _visual_drops: Dictionary = {}  # network_id -> Node2D (on clients)

func _gen_drop_id() -> int:
	var id := _next_drop_id
	_next_drop_id += 1
	return id

## Kullanıcı bildirimi: "altınar ve elmalar katılımcılarda görünmüyor onlar
## toplayamıyor bu yüzden hiç" - kök neden burasıydı: bu RPC eskiden
## "unreliable" idi, yani Ziva Cloud gibi yüksek gecikmeli/paket kaybı
## olabilen bir bağlantıda bu TEK SEFERLİK "böyle bir eşya var" mesajı
## sessizce kaybolabiliyordu - bir daha ASLA tekrar gönderilmediği için o
## eşya o client'ta HİÇ var olmuyordu. Şimdi "reliable" - tek seferlik ve
## kritik bir spawn olayı olduğu için garantili teslimat şart.
@rpc("any_peer", "call_remote", "reliable")
func broadcast_drop(drop_type: String, pos: Vector2, amount: int, network_id: int, real_xp_value: float = -1.0) -> void:
	var drop_scene: PackedScene = null
	match drop_type:
		"xp":
			drop_scene = load("res://scenes/xp_orb.tscn")
		"gold":
			drop_scene = load("res://scenes/gold_drop.tscn")
		"food":
			drop_scene = load("res://scenes/food_drop.tscn")
		"chest":
			drop_scene = load("res://scenes/chest_drop.tscn")
		## DÜZELTME (görünmezlik): Korsan'ın bıraktığı bomba önceden
		## _broadcast_skill_scene() ile gönderiliyordu - o yol kozmetik
		## kopyayı DOĞRUDAN atan oyuncunun RemotePlayer'ının ÇOCUĞU yapıp
		## konumunu (0,0) yerel ofsete sabitliyordu, yani bomba dünyada
		## bırakıldığı yerde DEĞİL, Korsan'ın üstünde/içinde görünüyordu ve
		## Korsan uzaklaşınca onunla birlikte kayıp gidiyordu - katılımcılar
		## için pratikte "bomba hiç görünmüyor" gibi algılanıyordu. Burada
		## var olan genel "dünya konumlu, kalıcı, id'li görsel obje" (drop)
		## sistemini bombalar için de kullanıyoruz - bkz. player.gd
		## _korsan_try_place_bomb (spawn) ve _skill_korsan_detonate_all
		## (remove_drop ile temizlik + patlama efekti).
		"korsan_bomb":
			drop_scene = load("res://scenes/korsan_bomb.tscn")
		"magnet":
			drop_scene = load("res://scenes/magnet_drop.tscn")
		_:
			return
	if not drop_scene:
		return
	var drop: Node2D = drop_scene.instantiate() as Node2D
	if "amount" in drop:
		drop.amount = amount
	## Kullanıcı bildirimi (eski): "expler orblar bazen diğer oyuncularda
	## farklı görünüyor" - kök neden host'tan gönderilen gerçek tier/değerin
	## kozmetik kopyaya hiç uygulanmamasıydı. DÜZELTME (5 orb tier güncellemesi
	## - bkz. xp_orb.gd TIERS/enemy.gd _roll_orb_tier): artık görsel tier
	## xp_value EŞİĞİNDEN DEĞİL, orb'u düşüren yaratığın Kademesinden (ağırlıklı
	## rastgele) geliyor - bu yüzden "amount" alanı burada GERÇEK bir xp miktarı değil,
	## doğrudan görsel tier numarası (1-5) taşıyor (kozmetik kopyalar zaten
	## gerçek XP vermez, sadece doğru RENKTE görünmesi gerekir). add_child'dan
	## ÖNCE atanıyor ki _ready()/_setup_visual() doğru tier'ı görsün.
	if drop_type == "xp" and "xp_tier" in drop:
		drop.xp_tier = amount
	## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu - host migrasyonu):
	## kozmetik kopyanın xp_value'su eskiden HİÇ ayarlanmıyordu (sadece görsel
	## xp_tier taşınıyordu), script varsayılanında (xp_orb.gd: 5.0) kalıyordu.
	## Normalde zararsızdı çünkü kozmetik kopyalar asla ödül hesaplamaz - AMA
	## eski host oyundan ayrılıp biri host olursa (bkz. NetworkManager.
	## became_host), o anda hayattaki bu kozmetik kopya artık O peer'in
	## tek/"gerçek" nesnesi olur; request_drop_pickup onu bulup bu (yanlış,
	## sabit) değeri ödüllendirirdi. Artık gerçek değer de birlikte taşınıyor.
	if drop_type == "xp" and real_xp_value >= 0.0 and "xp_value" in drop:
		drop.xp_value = real_xp_value
	## Kullanıcı isteği (5 yemek tier'i - bkz. food_drop.gd FOOD_TIERS): "amount"
	## burada da (xp_tier ile AYNI desen) gerçek bir heal miktarı değil,
	## host'un enemy.gd._drop_food()'da zaten ağırlıklı rastgele seçtiği
	## görsel/heal tier numarasını (1-5) taşıyor - kozmetik kopya add_child'dan
	## ÖNCE bunu görmeli ki _ready()/_setup_visual() doğru ikonu göstersin.
	if drop_type == "food" and "tier" in drop:
		drop.tier = amount
	get_tree().current_scene.add_child(drop)
	drop.global_position = pos
	# Multiplayer görsel kopya — client'lar body_entered ile toplayabilir
	# (request_drop_pickup RPC ile host'a iletilir).
	drop.set_meta("network_spawned", true)
	drop.set_meta("drop_network_id", network_id)
	# monitoring AÇIK bırakılıyor ki client oyuncu üzerine yürüdüğünde
	# body_entered tetiklensin ve request_drop_pickup RPC'si gönderilsin.
	# drop script'leri network_spawned meta'sını kontrol edip host'a yönlendirir.
	# Track for later removal
	_visual_drops[network_id] = drop
	## #53 DÜZELTME (kullanıcı bildirimi: "Yaratıkların düşürdüğü XP orbları
	## bir süre sonra kayboluyor"): kök neden bulundu - bu "fallback cleanup"
	## zamanlayıcısı SADECE 30 saniyeydi. Host'taki GERÇEK obje toplanana
	## kadar süresiz beklerken (bkz. xp_orb.gd/gold_drop.gd - hiçbir yaşam
	## süresi yok), diğer istemcilerdeki bu KOZMETİK GÖRSEL KOPYA 30sn sonra
	## remove_drop RPC'si hiç gelmemiş gibi otomatik siliniyordu - yoğun bir
	## çarpışmada ya da kimse hemen toplamadığında bu çok sık gerçekleşiyordu,
	## katılımcıların ekranında orb/altın/yemek 30sn'de "kayboluyormuş" gibi
	## görünüyordu (host'un kendi ekranı bu koddan etkilenmediği için host
	## bunu hiç yaşamıyordu). Bu zamanlayıcı sadece GERÇEK bir kaçak/paket
	## kaybı durumuna karşı son çare olmalı, normal oynanışta HİÇBİR ZAMAN
	## tetiklenmemeli - 30sn'den 5 dakikaya (300sn) çıkarıldı.
	var timer: SceneTreeTimer = get_tree().create_timer(300.0)
	timer.timeout.connect(func():
		if is_instance_valid(drop):
			_visual_drops.erase(network_id)
			drop.queue_free()
	)


## Game over sync: only called (see _check_all_players_dead below) once EVERY
## player is confirmed permanently dead - notifies all clients.
@rpc("any_peer", "call_remote", "reliable")
func sync_game_over() -> void:
	GameManager.is_game_over = true
	game_over_synced.emit()


## DÜZELTME (kullanıcı bildirimi: "herkes ölünce oyun bitmiyor bazen bianda
## biri canlanıp bianda yok oluyor istatistikleri göremiyoruz") - kök neden:
## "herkes öldü mü" kararı eskiden HER istemcide KENDİ yerel remote_player
## kuklalarının is_dead bayrağına bakılarak, SADECE o istemcinin kendi ölümü
## anında BİR KEZ veriliyordu (bkz. eski main.gd _on_player_died). O bayrak
## genel extra_state senkronunun (main.gd _process_multiplayer_sync, en
## fazla 5Hz + "sadece değişince gönder" throttle) bir PARÇASI - birden
## fazla oyuncu neredeyse aynı anda kalıcı ölürse, SON ölen oyuncunun
## ekranındaki diğerlerinin is_dead bilgisi henüz gelmemiş (bayat)
## olabiliyordu; kontrol SADECE O ANDA yapılıp bir daha ASLA tekrarlanmadığı
## için (bayat veri sonradan gelse bile) "herkes öldü" kararı hiç
## verilmiyor, oyun asla bitmiyordu - "izleyicisin" durumunda takılı kalan
## oyuncuların "biri canlanıp yok oluyor" hissi de muhtemelen aynı bayat
## veriden besleniyordu (spectate kamerası da AYNI is_dead alanına bakıyor).
##
## Artık kalıcı ölüm, genel extra_state'ten TAMAMEN BAĞIMSIZ, ayrı/anında/
## güvenilir bir RPC ile SADECE HOST'a bildiriliyor (bkz. report_player_
## permanently_dead/report_self_permanently_dead). Host kendi KESİN/güncel
## "kim kalıcı öldü" kümesini bu bildirimlerden tutuyor ve HER yeni
## bildirimde (+ bir peer ayrılınca, bkz. _on_peer_disconnected) yeniden
## kontrol ediyor - lobideki HERKES bu kümedeyse oyunu KESİN olarak
## bitiriyor. Karar artık dağınık/istemci-taraflı bir anlık görüntüye değil,
## TEK bir yetkili kaynağa (host) ve TEK bir güvenilir sinyale dayanıyor.
var _confirmed_dead_peers: Dictionary = {} ## peer_id -> true, SADECE host'ta anlamlı

@rpc("any_peer", "reliable")
func report_player_permanently_dead() -> void:
	if not is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	_mark_peer_permanently_dead(sender_id)


## bkz. report_player_permanently_dead üstündeki DÜZELTME notu - host'un
## KENDİ kalıcı ölümü için (RPC'ye gerek yok, zaten host üzerinde çalışıyor).
## Tek oyunculuda (is_multiplayer_active false) no-op - o akış zaten ayrı
## (main.gd _on_player_died'ın multiplayer dalına hiç girmiyor).
func report_self_permanently_dead() -> void:
	if not is_multiplayer_active:
		return
	if is_host:
		var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
		if my_id > 0:
			_mark_peer_permanently_dead(my_id)
	else:
		report_player_permanently_dead.rpc_id(_host_peer_id())


func _mark_peer_permanently_dead(peer_id: int) -> void:
	_confirmed_dead_peers[peer_id] = true
	_check_all_players_dead()


## bkz. report_player_permanently_dead üstündeki DÜZELTME notu - hem yeni bir
## ölüm bildiriminde hem bir peer ayrılınca (bkz. _on_peer_disconnected)
## çağrılır: son canlı oyuncu ölmek yerine bağlantısı koparsa bile geride
## kalanlar sonsuza kadar "izleyicisin" ekranında takılı kalmamalı.
func _check_all_players_dead() -> void:
	if not is_host or GameManager.is_game_over or lobby_players.is_empty():
		return
	for pid in lobby_players.keys():
		if not _confirmed_dead_peers.has(pid):
			return ## hâlâ hayatta/henüz bildirmemiş biri var
	GameManager.is_game_over = true
	game_over_synced.emit() ## host'un KENDİ ekranı için - "call_remote" kendine ulaşmaz
	sync_game_over.rpc()


## Oyun sonu istatistik ekranı (kullanıcı isteği: "oyun sonuna istatistik
## penceresi ekleyip kimin ne kadar vurduğunu ne kadar hasar tankladığını
## göster") - herkes oyun bittiğinde KENDİ toplamlarını (player.gd
## match_damage_dealt/match_damage_taken) buradan diğer herkese yayınlar.
## broadcast_player_vfx/broadcast_pet_spawn'daki AYNI desen: gönderen kendi
## peer_id'sini AÇIKÇA parametre olarak taşır (get_remote_sender_id() call_local
## RPC'lerde yerel çağrıda 0 döner, bu yüzden güvenilmez).
signal match_stats_received(peer_id: int, player_name: String, damage_dealt: float, damage_taken: float)

@rpc("any_peer", "call_local", "reliable")
func sync_match_stats(peer_id: int, player_name: String, damage_dealt: float, damage_taken: float) -> void:
	match_stats_received.emit(peer_id, player_name, damage_dealt, damage_taken)


## Sync game time from host to clients so difficulty scaling stays consistent.
@rpc("any_peer", "call_remote", "unreliable")
func sync_game_time(time: float) -> void:
	GameManager.game_time = time


## Chat (kullanıcı isteği: "oyuna chat ekle, enter tuşuna basarak mesaj
## yazabiliriz solda chat penceresi olacak ve karakterler konuşunca üstlerinde
## mini chat balonu çıkacak") - sync_match_stats ile AYNI desen: "call_local"
## sayesinde gönderen de KENDİ mesajını bu sinyalden alır, ayrı bir "yerel
## yankı" kodu yazmaya gerek YOK. Bir mesaj kaybolursa (unreliable VFX'lerin
## aksine) fark edilir/rahatsız edici olacağı için "reliable".
signal chat_message_received(peer_id: int, player_name: String, text: String)

@rpc("any_peer", "call_local", "reliable")
func broadcast_chat_message(peer_id: int, player_name: String, text: String) -> void:
	chat_message_received.emit(peer_id, player_name, text)


## Seyyar satıcı (kullanıcı isteği: "dükkan geldiğinde oyunculara bildirim
## gelir ve ne tarafta olduğu haritada işaretle gösterilir") - SADECE HOST
## karar verir (ne zaman/nerede, bkz. traveling_merchant.gd _process), "call_
## local" sayesinde host da KENDİ kararını bu sinyalden alır - chat_message_
## received ile AYNI desen.
## Kullanıcı isteği (İKİNCİ tur): "Seyyar satıcı dükkandan rasgele 8 item
## gösterecek." - stok (hangi 8 eşya/silah/kalkan, eşyalarınsa hangi tier'da)
## satıcı BELİRİRKEN host tarafından bir kez çekilir (bkz. traveling_
## merchant.gd _generate_stock) ve TÜM peer'lerin AYNI stoku görmesi için
## bu sinyalin payload'ına eklendi - her Dictionary {"type","key"} ve
## type=="item" ise ayrıca "tier" taşır (bkz. merchant_shop_screen.gd).
signal merchant_spawned(pos: Vector2, stock: Array)
signal merchant_departed()

@rpc("any_peer", "call_local", "reliable")
func broadcast_merchant_spawned(pos: Vector2, stock: Array) -> void:
	merchant_spawned.emit(pos, stock)

@rpc("any_peer", "call_local", "reliable")
func broadcast_merchant_departed() -> void:
	merchant_departed.emit()


## GÜN-GECE + HAVA DURUMU (kullanıcı isteği 2026-09-25, bkz. scripts/atmosphere.gd): saat ve hava durumunu SADECE host
## yürütür/seçer, bu RPC ile birkaç saniyede bir + her hava değişiminde herkese (sonradan katılana peer_needs_game_catchup
## ile hedefli) gönderir. state: {"t" döngü saniyesi, "w" hava türü, "ri"/"wi" yağmur/rüzgar şiddeti, "wa" rüzgar açısı,
## "wr" havanın kalan süresi (host devri olursa yeni host kaldığı yerden sürdürsün), "ts" debug saat hızı}.
## call_remote: host kendi durumunu zaten biliyor.
signal atmosphere_state_received(state: Dictionary)

@rpc("any_peer", "call_remote", "reliable")
func broadcast_atmosphere_state(state: Dictionary) -> void:
	atmosphere_state_received.emit(state)


## SAĞANAK YILDIRIMI (kullanıcı isteği 2026-09-25, bkz. scripts/weather_storm.gd): yıldırımın konumunu SADECE host seçer,
## bu RPC herkese (call_local: host dahil) iletir; her istemci aynı noktada uyarı + yıldırımı yerel oynatır. Yaratık
## hasarını host, oyuncu hasarını her istemci kendi oyuncusuna uygular. Ek veri yok (zamanlama sabit, WARN_TIME).
signal lightning_strike_received(pos: Vector2)

@rpc("any_peer", "call_local", "reliable")
func broadcast_lightning_strike(pos: Vector2) -> void:
	lightning_strike_received.emit(pos)


## =====================================================================================
## Rastgele dünya görevleri (bkz. world_event_manager.gd) - kullanıcı isteği (2026-09-23):
## "Oyuna rasgele aralıklarla gerçekleşen bir görev sistemi ekliyoruz". Seyyar satıcı
## AYNI deseni: karar HOST'ta (world_event_manager.gd, sadece NetworkManager.is_host'ta
## çalışır), sonuç bu RPC'lerle TÜM istemcilere (host dahil, call_local) yayılır - hiçbir
## istemci kendi başına görev seçmez/zamanlamaz, sadece host'un yayınını gösterir.
## `extra` görev TÜRÜNE özgü kurulum verisi taşır (ör. Topla görevinde toplanacak obje
## sayısı, Alanı Güvenceye Al'da hedef öldürme sayısı) - CLAUDE.md'nin uyardığı "iki ayrı
## yer" hatasından kaçınmak için bu sabitler SADECE world_event_manager.gd'de tanımlı,
## burada tekrar YAZILMIYOR.
signal world_event_announced(mission_id: int, kind: String, pos: Vector2, radius: float, warn_seconds: float, label: String)
signal world_event_started(mission_id: int, kind: String, pos: Vector2, radius: float, duration: float, extra: Dictionary)
signal world_event_progress(mission_id: int, value: float, target: float)
signal world_event_completed(mission_id: int, kind: String, success: bool)

@rpc("any_peer", "call_local", "reliable")
func broadcast_world_event_announced(mission_id: int, kind: String, pos: Vector2, radius: float, warn_seconds: float, label: String) -> void:
	world_event_announced.emit(mission_id, kind, pos, radius, warn_seconds, label)

@rpc("any_peer", "call_local", "reliable")
func broadcast_world_event_started(mission_id: int, kind: String, pos: Vector2, radius: float, duration: float, extra: Dictionary) -> void:
	world_event_started.emit(mission_id, kind, pos, radius, duration, extra)

@rpc("any_peer", "call_local", "reliable")
func broadcast_world_event_progress(mission_id: int, value: float, target: float) -> void:
	world_event_progress.emit(mission_id, value, target)

@rpc("any_peer", "call_local", "reliable")
func broadcast_world_event_completed(mission_id: int, kind: String, success: bool) -> void:
	world_event_completed.emit(mission_id, kind, success)

## Topla (Collect) görevi: obje konumları sabit olduğu için her istemci world_event_started'ın
## `extra["items"]` alanından KENDİ kozmetik kopyalarını kurar (bkz. mission_collect_item.gd) -
## ayrı bir "spawn" RPC'sine gerek yok. Bu RPC sadece TOPLAMA anını taşır: hangi istemcinin
## KENDİ yerel oyuncusu bir objeye dokunduysa "any_peer" ile burayı çağırır (host dahil kendi
## objesi için de), host bunu dinleyip (bkz. world_event_manager.gd) ilerlemeyi ilerletir VE
## bu AYNI RPC'nin call_local'ı sayesinde TÜM istemciler o objeyi (item_index) yerel kopyalarında
## gizler - iki taraf da (mantık + görsel) aynı yayından besleniyor, ayrı bir "kaldır" RPC'si
## gerekmiyor.
signal world_event_item_collected(mission_id: int, item_index: int)

@rpc("any_peer", "call_local", "reliable")
func broadcast_world_event_item_collected(mission_id: int, item_index: int) -> void:
	world_event_item_collected.emit(mission_id, item_index)

## "Kopyanı Öldür" (Kill your copy) - kopyalar sadece host'ta gerçek simüle edilir (enemy.gd'nin
## AYNI host-authoritative deseni), diğer istemcilerde kozmetik bir kopya bu yayınla pozisyonunu/
## canlılığını takip eder (bkz. mission_player_copy.gd) - enemy.gd'nin tam senkron sistemine
## (network_enemy_id/interest management) girmiyor çünkü Enemy tipi DEĞİL; bunun yerine AYRI,
## küçük, ilgi-alanı-YÖNETİMSİZ (kopya sayısı zaten oyuncu sayısı kadar, az) bir periyodik yayın.
## health_ratio: kopyanın can oranı (0..1) - kozmetik kopyaların can barı da güncellensin diye
## (yoksa host olmayan oyuncular barı hep DOLU görür, bkz. CLAUDE.md "kaster görür, diğerleri
## görmez" hata sınıfı).
## shield_ratio: kalkan oranı (0..1) - kopyanın kalkanı var (oyuncununkinin 3 katı, bkz. mission_player_copy.gd).
signal world_event_copy_state(mission_id: int, copy_index: int, pos: Vector2, alive: bool, health_ratio: float, shield_ratio: float)

@rpc("any_peer", "call_local", "unreliable")
func broadcast_world_event_copy_state(mission_id: int, copy_index: int, pos: Vector2, alive: bool, health_ratio: float = 1.0, shield_ratio: float = 0.0) -> void:
	world_event_copy_state.emit(mission_id, copy_index, pos, alive, health_ratio, shield_ratio)

## Host olmayan istemcinin kozmetik kopyaya verdiği hasar -> host'taki gerçek kopya (bkz. mission_player_copy.gd take_damage).
signal world_event_copy_damage_requested(mission_id: int, copy_index: int, amount: float)

@rpc("any_peer", "call_remote", "reliable")
func request_world_event_copy_damage(mission_id: int, copy_index: int, amount: float) -> void:
	if not is_host:
		return
	world_event_copy_damage_requested.emit(mission_id, copy_index, amount)

## Kopyaya itme (bkz. mission_player_copy.gd apply_knockback_distance) - hasar isteğiyle AYNI yol: istemcinin vuruşu
## host'taki GERÇEK kopyaya iletilir (yaratıklardaki request_enemy_knockback'in karşılığı).
signal world_event_copy_knockback_requested(mission_id: int, copy_index: int, dir: Vector2, distance: float)

@rpc("any_peer", "call_remote", "reliable")
func request_world_event_copy_knockback(mission_id: int, copy_index: int, dir: Vector2, distance: float) -> void:
	if not is_host:
		return
	world_event_copy_knockback_requested.emit(mission_id, copy_index, dir, distance)

## Kopyanın yakın dövüş savuruşu (bkz. mission_player_copy.gd _process_attacks) - hasar host'ta verilir, bu yayın
## diğer istemcilerdeki kozmetik kopyanın silah ikonlarının da AYNI anda savrulmasını sağlar.
signal world_event_copy_swing(mission_id: int, copy_index: int, dir: Vector2)

@rpc("any_peer", "call_remote", "unreliable")
func broadcast_world_event_copy_swing(mission_id: int, copy_index: int, dir: Vector2) -> void:
	world_event_copy_swing.emit(mission_id, copy_index, dir)

## Kopyanın menzilli mermisi (bkz. mission_player_copy.gd _fire_at) - host'ta gerçek mermi zaten
## hasar veriyor; bu yayın diğer istemcilerde AYNI atışın hasarsız, salt görsel kopyasını çizer.
@rpc("any_peer", "call_remote", "unreliable")
func broadcast_world_event_copy_bolt(from_pos: Vector2, to_pos: Vector2) -> void:
	## load() (preload/class_name DEĞİL): autoload <-> mission_player_copy.gd döngüsel derleme bağımlılığı olmasın.
	load("res://scripts/mission_player_copy.gd").spawn_bolt(from_pos, to_pos, 0.0, null, true)


## Remove a visual drop on all clients when it's collected on the host.
##
## NOT (kritik çökme düzeltmesi): "as Node2D" statik cast'i BİLEREK
## kaldırıldı. Bir client kendi görsel drop kopyasını topladığında
## (bkz. xp_orb.gd/gold_drop.gd/food_drop.gd/magnet_drop.gd/chest_drop.gd
## _on_body_entered'daki network_spawned dalı) o kopyayı KENDİSİ hemen
## queue_free() ediyor ve artık discard_visual_drop() ile _visual_drops'tan
## da siliyor. Ama host'un "toplandı, sil" onayı (bu RPC) ağ gecikmesi
## yüzünden GEÇ gelebilir - eski kodda bu RPC geldiğinde _visual_drops'ta
## hâlâ (silinmesi unutulmuş) bir kayıt bulunuyor, ve node ÇOKTAN
## silinmiş (freed) olduğu için "var drop: Node2D = ... as Node2D" satırı
## "Trying to cast a freed object" hatasıyla client'ı çökertiyordu -
## kullanıcı bildirimi: "host level atladığında/oyun ilerledikçe
## katılımcının oyunu donup kapanıyor" tam olarak buydu (Ziva Cloud'da
## gecikme yüksek olduğu için hemen, LAN'da düşük gecikme yüzünden birkaç
## level/dakika sonra tetikleniyordu). is_instance_valid() dondurulmuş
## (freed) nesnelerde de GÜVENLE çalışır - statik "as" cast'i ise çalışmaz,
## bu yüzden artık cast YAPILMADAN önce geçerlilik kontrol ediliyor.
@rpc("any_peer", "call_remote", "reliable")
func remove_drop(network_id: int) -> void:
	if _visual_drops.has(network_id):
		var drop = _visual_drops[network_id]
		_visual_drops.erase(network_id)
		if is_instance_valid(drop):
			drop.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func remove_drops_batch(drop_ids: Array) -> void:
	for drop_id in drop_ids:
		var net_id: int = int(drop_id)
		if _visual_drops.has(net_id):
			var drop = _visual_drops[net_id]
			_visual_drops.erase(net_id)
			if is_instance_valid(drop):
				drop.queue_free()


## Bir client kendi görsel drop kopyasını (network_spawned) doğrudan kendisi
## queue_free() ettiğinde (bkz. yukarıdaki not) _visual_drops sözlüğündeki
## karşılık gelen kaydı da temizlemek için çağrılır. Node zaten silindiği
## için burada TEKRAR queue_free() çağrılmaz - sadece artık sarkan
## (dangling) referans sözlükten kaldırılır, böylece host'tan daha sonra
## gelecek remove_drop/remove_drops_batch RPC'si bu ID'ye bir daha hiç
## dokunmaz.
func discard_visual_drop(network_id: int) -> void:
	_visual_drops.erase(network_id)


## Host tarafında drop silme isteğini tampona ekler
func queue_remove_drop(drop_network_id: int) -> void:
	if not is_host or drop_network_id <= 0:
		return
	if not _pending_removed_drops.has(drop_network_id):
		_pending_removed_drops.append(drop_network_id)


## Host tarafında XP ve Drop silme paketlerini toplu (batched) olarak gönderir
func _process_batched_syncs(delta: float) -> void:
	if _pending_xp_sync:
		_xp_sync_timer += delta
		if _xp_sync_timer >= XP_SYNC_INTERVAL:
			_xp_sync_timer = 0.0
			_pending_xp_sync = false
			sync_team_xp.rpc(GameManager.team_xp, GameManager.team_xp_needed, GameManager.team_level)
	
	if not _pending_removed_drops.is_empty():
		_drop_remove_timer += delta
		if _drop_remove_timer >= DROP_REMOVE_INTERVAL or _pending_removed_drops.size() >= 15:
			_drop_remove_timer = 0.0
			var batch_to_send: Array = _pending_removed_drops.duplicate()
			_pending_removed_drops.clear()
			if batch_to_send.size() == 1:
				remove_drop.rpc(int(batch_to_send[0]))
			elif batch_to_send.size() > 1:
				remove_drops_batch.rpc(batch_to_send)


@rpc("any_peer", "call_remote", "reliable")
func broadcast_wave_fx(from_pos: Vector2, target_node_path: String, wave_type: String, caster_peer_id: int = 0, target_peer_id: int = 0) -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	## Caster (ör. Oakley) her zaman BAŞKA bir gerçek oyuncudur (call_remote
	## kendi gönderene hiç gitmez) - bu yüzden onu görüntüleyen her istemcide
	## bir RemotePlayer kuklası olarak bulunur; ışının başlangıcı ona bağlanır
	## (bkz. fx_wave_beam.gd caster_node) ki caster hareket ettikçe takip etsin.
	var caster: Node2D = _find_remote_player(caster_peer_id) if caster_peer_id > 0 else null
	## Hedef İSE alıcı istemcinin KENDİSİ olabilir (Oakley müttefiğini
	## iyileştiriyorsa, o müttefiğin kendi ekranında hedef "RemotePlayer" değil
	## kendi yetkili Player node'udur - eski path tabanlı arama bu durumda hep
	## null dönüp ışının hedefe hiç ulaşmamış gibi görünmesine yol açıyordu).
	var target: Node2D = null
	if target_peer_id > 0:
		if my_id == target_peer_id:
			target = get_tree().get_first_node_in_group("player") as Node2D
		else:
			target = _find_remote_player(target_peer_id)
	if target == null:
		target = get_tree().root.get_node_or_null(target_node_path) as Node2D
	var wave_scene: PackedScene = load("res://scenes/fx_wave_beam.tscn")
	if wave_scene:
		var wave: Node2D = wave_scene.instantiate() as Node2D
		get_tree().current_scene.add_child(wave)
		if wave.has_method("setup"):
			wave.setup(from_pos, target, wave_type, caster)


## Kullanıcı isteği ("efekt sistemi" - iyileşme.png/kalkan.png): Melek'in
## Can Basma/Kalkan Yenileme yeteneğinin müttefik hedefinde beliren, süreklİ
## döngülü aura efektinin başlama/durma bildirimi. broadcast_wave_fx'teki
## AYNI hedef çözümleme deseni (_resolve_aura_target) - hedef bu isteği alan
## istemcinin KENDİ yerel oyuncusu olabilir (Melek başka birini
## iyileştiriyorsa, o kişinin kendi ekranında hedef bir RemotePlayer değil
## kendi yetkili Player node'udur) YA DA bir RemotePlayer kuklası.
## start/stop AYRI RPC'ler (wave_fx gibi tek seferlik değil): aura sürekli
## döngülü bir görsel, bağ HER tik'te değil SADECE bağlandığında/koptuğunda
## bir kez tetiklenmeli - aksi halde her saniye yeniden başlayıp intro'dan
## tekrar oynardı.
func _resolve_aura_target(target_peer_id: int) -> Node2D:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if target_peer_id <= 0:
		return null
	if my_id == target_peer_id:
		return get_tree().get_first_node_in_group("player") as Node2D
	return _find_remote_player(target_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func broadcast_ally_aura_start(_caster_peer_id: int, target_peer_id: int, aura_type: String) -> void:
	var target: Node2D = _resolve_aura_target(target_peer_id)
	if target and target.has_method("start_ally_aura_fx"):
		target.start_ally_aura_fx(aura_type)


@rpc("any_peer", "call_remote", "reliable")
func broadcast_ally_aura_stop(target_peer_id: int, aura_type: String) -> void:
	var target: Node2D = _resolve_aura_target(target_peer_id)
	if target and target.has_method("stop_ally_aura_fx"):
		target.stop_ally_aura_fx(aura_type)


## PERF DÜZELTMESİ (kullanıcı bildirimi: "birisi bianda çok fazla yaratık öldürünce oyun laglanıyor ve yaratıklar
## yerinde duruyor"): request_enemy_damage/request_enemy_effect/broadcast_enemy_vfx/forward_damage_to_peer/
## broadcast_enemy_projectile yaratığı ağ kimliğiyle bulmak için HER ÇAĞRIDA "enemies" grubunun tamamını
## kopyalayıp (get_nodes_in_group) tek tek get_meta ile tarıyordu. Tek bir alan hasarı onlarca yaratığı
## öldürünce aynı karede yüzlerce bu RPC'den gelir (katılımcının her isabeti bir request_enemy_damage; host'tan
## her yaratığa damage_number + hit_flash/death_state) - 300 yaratıkta tek karede on binlerce get_meta, yani tam
## o anda uzun bir takılma. Artık kimlik atanırken (TEK yer: enemy_spawner.gd _spawn_creature) bu sözlüğe
## kaydediliyor, sahneden çıkınca siliniyor - arama O(1).
var _enemies_by_net_id: Dictionary = {} ## network_enemy_id -> Enemy node


func register_enemy_net_id(enemy: Node, network_id: int) -> void:
	if network_id <= 0 or enemy == null:
		return
	_enemies_by_net_id[network_id] = enemy
	enemy.tree_exited.connect(_on_registered_enemy_exited.bind(network_id, enemy.get_instance_id()), CONNECT_ONE_SHOT)


func _on_registered_enemy_exited(network_id: int, instance_id: int) -> void:
	var cur: Variant = _enemies_by_net_id.get(network_id)
	## Aynı kimlik bu arada başka bir yaratığa verilmişse (host göçü sonrası yeniden tohumlanan sayaç) ona dokunma.
	if cur == null or not is_instance_valid(cur) or (cur as Object).get_instance_id() == instance_id:
		_enemies_by_net_id.erase(network_id)


func find_enemy_by_net_id(network_id: int) -> Node:
	if network_id <= 0:
		return null
	var e: Variant = _enemies_by_net_id.get(network_id)
	if e != null and is_instance_valid(e) and (e as Node).is_inside_tree():
		return e as Node
	return null


## Host-authoritative enemy damage: non-host clients send damage requests here.
## The host validates, applies damage to the enemy, and state syncs back to all peers.
@rpc("any_peer", "call_remote", "reliable")
func request_enemy_damage(network_id: int, amount: float, is_crit: bool, shield_pen_percent: float) -> void:
	if not is_host or get_tree().paused:
		return
	var target_enemy: Node = find_enemy_by_net_id(network_id)
	if target_enemy and is_instance_valid(target_enemy) and target_enemy.has_method("take_damage_host"):
		## Gerçek saldıran katılımcının peer id'si - Korsan'ın "öldürdüğün her
		## düşman 1 altın kazandırır" pasifi gibi öldürene özel ödüller için
		## (bkz. enemy.gd last_attacker_peer_id/_notify_kill_passives).
		## get_remote_sender_id() sadece BU RPC'nin işlendiği an geçerli
		## olduğu için burada okunup parametre olarak taşınıyor.
		var attacker_id: int = multiplayer.get_remote_sender_id()
		target_enemy.take_damage_host(amount, is_crit, shield_pen_percent, attacker_id)


## İstemcinin silah/mermi itişi -> host'taki gerçek yaratık (bkz. enemy.gd apply_knockback_distance). Konum host'ta
## hesaplanıp normal yaratık konum yayınıyla herkese gider.
@rpc("any_peer", "call_remote", "unreliable")
func request_enemy_knockback(network_id: int, dir: Vector2, distance: float) -> void:
	if not is_host or get_tree().paused:
		return
	var target_enemy: Node = find_enemy_by_net_id(network_id)
	if target_enemy and is_instance_valid(target_enemy) and target_enemy.has_method("apply_knockback_distance"):
		target_enemy.apply_knockback_distance(dir, distance)


## DÜZELTME (KRİTİK - multiplayer öldürme-bazlı pasifler): host, enemy.gd
## die() içinde gerçek öldürenin kendisi olmadığını (last_attacker_peer_id)
## tespit ettiğinde bunu doğrudan o istemciye bildirir - Korsan'ın "öldürme
## şansı" ve Necromancer'ın "ruh kazanımı" pasifleri artık SADECE host bizzat
## o karakteri oynarken değil, HANGİ istemci öldürürse o istemcide tetiklenir.
## DÜZELTME (Büyücü Kız'ın "her öldürdüğü yaratık patlar" pasifi): ölüm
## konumu artık üçüncü (isteğe bağlı) parametre olarak taşınıyor - bkz.
## enemy.gd die()'daki çağrı ve player.gd on_enemy_killed_remote/
## _buyucu_on_kill. Varsayılan Vector2.ZERO eski çağrılarla (parametresiz)
## geriye dönük uyumluluk için.
@rpc("any_peer", "call_remote", "reliable")
func notify_kill_passive(is_boss_kill: bool, death_pos: Vector2 = Vector2.ZERO) -> void:
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("on_enemy_killed_remote"):
		local_player.on_enemy_killed_remote(is_boss_kill, death_pos)


## Host-authoritative enemy status effect: non-host clients send poison/bleed/chill here.
@rpc("any_peer", "call_remote", "reliable")
func request_enemy_effect(network_id: int, effect_type: String, param1: float, param2: float, param3: float) -> void:
	if not is_host or get_tree().paused:
		return
	var target_enemy: Node = find_enemy_by_net_id(network_id)
	if not target_enemy or not is_instance_valid(target_enemy):
		return
	match effect_type:
		## Tüftüf zehri - param1=yükün saniyelik hasarı, param2=yük üst sınırı,
		## param3=yükün ömrü (bkz. enemy.gd apply_poison).
		"poison":
			if target_enemy.has_method("apply_poison"):
				target_enemy.apply_poison(param1, param2, param3)
		## Shaman pasifi (Totem Auraları) - bkz. enemy.gd apply_burn.
		"burn":
			if target_enemy.has_method("apply_burn"):
				target_enemy.apply_burn(param1, param3)
		"bleed":
			if target_enemy.has_method("apply_bleed"):
				target_enemy.apply_bleed(param1, int(param2), int(param3))
		"chill":
			if target_enemy.has_method("apply_chill"):
				target_enemy.apply_chill(int(param1))
		"mark":
			if target_enemy.has_method("apply_mark_stack"):
				target_enemy.apply_mark_stack(int(param1))
		"slow":
			if target_enemy.has_method("apply_slow"):
				target_enemy.apply_slow(param1, param2, param3 > 0.5)
		## Oakley'in Sarmaşıklar yeteneği - bkz. enemy.gd apply_root.
		"root":
			if target_enemy.has_method("apply_root"):
				target_enemy.apply_root(param1)
		## Oakley'in Arı Sürüsü yeteneği - bkz. enemy.gd apply_bee_poison.
		"bee_poison":
			if target_enemy.has_method("apply_bee_poison"):
				target_enemy.apply_bee_poison(param1)
		"stun":
			if target_enemy.has_method("apply_stun"):
				target_enemy.apply_stun(param1)
		## Büyücü Kız'ın "Don Nova" temel yeteneği (bkz. enemy.gd
		## apply_freeze_full) - "stun" ile AYNI host-yönlendirme deseni.
		"freeze":
			if target_enemy.has_method("apply_freeze_full"):
				target_enemy.apply_freeze_full(param1)
		## Melek'in yeni 3. yeteneği (Kutsal Korku) - param1=süre,
		## param2/param3=kaçış merkezinin x/y'si (bkz. enemy.gd apply_fear).
		"fear":
			if target_enemy.has_method("apply_fear"):
				target_enemy.apply_fear(Vector2(param2, param3), param1)
		## Necromancer ULTİ (Lanetli Kafatası) - rastgele yürüyen korku: param1=süre, param2>0.5 => bosslar da korkar
		## (bkz. enemy.gd apply_fear_wander).
		"fear_wander":
			if target_enemy.has_method("apply_fear_wander"):
				target_enemy.apply_fear_wander(param1, param2 > 0.5)
		## Şovalye'nin E yeteneği (Kışkırtma, bkz. enemy.gd apply_taunt) -
		## param1=süre, param2=kışkırtan oyuncunun peer id'si (host o peer'in
		## oyuncu node'unu kendi tarafında bulup yaratığın hedefi yapar).
		"taunt":
			if target_enemy.has_method("apply_taunt"):
				var taunter_peer: int = int(param2)
				var taunter: Node = _find_player_by_peer_id(taunter_peer) if taunter_peer > 0 else null
				target_enemy.apply_taunt(param1, taunter as Node2D)


## Broadcast enemy status VFX so all peers see poison/freeze/chill visuals.
## Kullanıcı bildirimi: "yaratıklar single playerdaki ve hosttaki
## animasyonlarla gelmiyorlar katılımcılarda" - bu RPC saldırı/yaralanma
## animasyonu/parlamasını tetiklemesini (attack_state/hit_flash) ve tüm durum efektlerini
## (poison/rage/freeze/stun start-stop) taşıyor. "unreliable" olarak
## işaretliydi; relay'in bağlantı başına byte bütçesi/sel koruması (bkz.
## dosya başı notu) veya sıradan paket kaybı bu paketleri SESSİZCE
## düşürebiliyordu - konum senkronu gibi "bir sonraki paket zaten düzeltir"
## türünden SÜREKLİ bir veri değil, TEK SEFERLİK, seyrek tetiklenen bir olay
## (yaratık ancak gerçekten saldırdığında/vurulduğunda gönderiliyor). Bu
## yüzden kaybolursa asla telafi edilmiyordu ve o yaratık katılımcının
## ekranında sonsuza dek yürüme animasyonunda donuk kalıyordu. En yaygın/en
## sağlıklı pratik: sürekli değişen transform verisi unreliable, seyrek/tek
## seferlik durum olayları reliable olmalı - bkz. enemy_spawner.gd
## _sync_enemy_positions (o hâlâ doğru şekilde unreliable, çünkü kaybolsa
## bile 0.15sn sonraki paket zaten üzerine yazacak).
## vfx_type listesi: poison_start/stop, freeze_start/stop, stun_start/stop, burn_start/stop, slow_start/stop, bleed,
## rage_start, chill_tint, damage_number, attack_state, hit_flash, death_state + yaratık yetenekleri (2026-09-24):
## ghost_vanish, ghost_reveal, vampire_blink (extra_data: from/to), fear_start (extra_data: duration)/fear_stop (korku
## göstergesi - Melek korkusu + Necromancer Lanetli Kafatası), taunt_start (extra_data: duration)/taunt_stop (Şovalye
## Kışkırtma'sının öfke damarı göstergesi), root_start (extra_data: duration)/root_stop (Oakley Sarmaşıklar'ın bacaklara
## sarılan dikenleri, bkz. fx_oakley_entangle.gd) - yeni bir dal eklersen buraya da yaz.
@rpc("any_peer", "call_remote", "reliable")
func broadcast_enemy_vfx(network_id: int, vfx_type: String, extra_data: Dictionary = {}) -> void:
	var target_enemy: Node = find_enemy_by_net_id(network_id)
	if not target_enemy or not is_instance_valid(target_enemy):
		return
	match vfx_type:
		"poison_start":
			if target_enemy.has_method("_spawn_poison_status_fx"):
				target_enemy._spawn_poison_status_fx()
		"poison_stop":
			if target_enemy.has_method("_remove_poison_status_fx"):
				target_enemy._remove_poison_status_fx()
		"freeze_start":
			## BUG DÜZELTMESİ (çok oyunculu genel kontrol sırasında bulundu):
			## host bu RPC'yi GERÇEK donma süresini extra_data["duration"]
			## içinde göndererek yayınlıyor (bkz. enemy.gd apply_freeze_full/
			## _start_freeze), ama burada hiç okunmadan argümansız çağrılıyordu -
			## _spawn_freeze_status_fx()'in varsayılanı (FREEZE_DURATION=Buz
			## Asası'nın süresi) kullanılıyordu. Büyücü Kız'ın Don Nova'sı
			## (BUYUCU_NOVA_FREEZE_DURATION=6.0, FARKLI bir süre) tetiklediğinde
			## host'ta doğru sürede biten efekt, diğer istemcilerde HEP 5sn'de
			## bitiyordu - kastın ekranında doğru, diğerlerinde yanlış süre.
			if target_enemy.has_method("_spawn_freeze_status_fx"):
				var freeze_duration: float = float(extra_data.get("duration", 5.0))
				target_enemy._spawn_freeze_status_fx(freeze_duration)
		"freeze_stop":
			if target_enemy.has_method("_remove_freeze_status_fx"):
				target_enemy._remove_freeze_status_fx()
		"stun_start":
			if target_enemy.has_method("_spawn_stun_status_fx"):
				var duration: float = float(extra_data.get("duration", 3.0))
				target_enemy._spawn_stun_status_fx(duration)
		"stun_stop":
			if target_enemy.has_method("_remove_stun_status_fx"):
				target_enemy._remove_stun_status_fx()
		"fear_start":
			if target_enemy.has_method("_spawn_fear_status_fx"):
				target_enemy._spawn_fear_status_fx(float(extra_data.get("duration", 3.0)))
		"fear_stop":
			if target_enemy.has_method("_remove_fear_status_fx"):
				target_enemy._remove_fear_status_fx()
		## Şovalye Adam Q (Kışkırtma) - yaratığın başının üstündeki öfke damarı (bkz. enemy.gd _set_taunt_visual).
		"taunt_start":
			if target_enemy.has_method("_spawn_taunt_status_fx"):
				target_enemy._spawn_taunt_status_fx(float(extra_data.get("duration", 5.0)))
		"taunt_stop":
			if target_enemy.has_method("_remove_taunt_status_fx"):
				target_enemy._remove_taunt_status_fx()
		## Oakley Sarmaşıklar - kök salan yaratığın bacaklarına sarılan dikenler (bkz. enemy.gd _set_root_visual).
		"root_start":
			if target_enemy.has_method("_spawn_entangle_fx"):
				target_enemy._spawn_entangle_fx(float(extra_data.get("duration", 4.0)))
		"root_stop":
			if target_enemy.has_method("_remove_entangle_fx"):
				target_enemy._remove_entangle_fx()
		## Shaman pasifi (Totem Auraları) yakma göstergesi - bkz. enemy.gd
		## apply_burn/_process_burn. Görsel, hasar mekaniğinden TAMAMEN ayrı;
		## sadece hedefin üzerindeki alev sprite'ını kurar/kaldırır.
		"burn_start":
			if target_enemy.has_method("_spawn_burn_status_fx"):
				target_enemy._spawn_burn_status_fx()
		"burn_stop":
			if target_enemy.has_method("_remove_burn_status_fx"):
				target_enemy._remove_burn_status_fx()
		## Yavaşlatma göstergesi (Alan Totemi) - bkz. enemy.gd apply_slow/
		## _spawn_slow_status_fx. duration, istemcinin kendi başına sayacağı
		## görsel ömürdür; yavaşlatma SİMÜLASYONU yalnızca host'ta çalışır.
		"slow_start":
			if target_enemy.has_method("_spawn_slow_status_fx"):
				var slow_fx_duration: float = float(extra_data.get("duration", 1.5))
				target_enemy._spawn_slow_status_fx(slow_fx_duration)
		"slow_stop":
			if target_enemy.has_method("_remove_slow_status_fx"):
				target_enemy._remove_slow_status_fx()
		"bleed":
			if target_enemy.has_method("_spawn_bleed_fx"):
				target_enemy._spawn_bleed_fx()
		"rage_start":
			if target_enemy.has_method("_enter_rage_mode"):
				target_enemy._enter_rage_mode()
		## Yaratık yetenekleri (2026-09-24, bkz. enemy_abilities.gd / enemy.gd on_ability_vfx): hayaletin görünmez
		## olması/görünür olması, vampirin ışınlanması (extra_data: from, to) - yaratığın KENDİ durumu değiştiği için
		## burada (dünyada duran etkiler ayrı RPC'de: broadcast_enemy_ability_fx).
		"ghost_vanish", "ghost_reveal", "vampire_blink":
			if target_enemy.has_method("on_ability_vfx"):
				target_enemy.on_ability_vfx(vfx_type, extra_data)
		"chill_tint":
			if target_enemy.has_method("_refresh_chill_tint"):
				target_enemy._refresh_chill_tint()
		"damage_number":
			if target_enemy.has_method("_spawn_floating_text"):
				var dmg_val: float = float(extra_data.get("amount", 0.0))
				var dmg_crit: bool = extra_data.get("is_crit", false)
				target_enemy._spawn_floating_text(dmg_val, dmg_crit)
		"attack_state":
			## DÜZELTME (mimari sadeleştirme): süre artık ağdan gelmiyor -
			## _enter_state_networked() bunu enemy.gd'nin KENDİ sabit
			## animasyon verisinden (_anim_length_for) hesaplıyor, host'un
			## hesapladığı değerle birebir aynı sonucu verir (bkz. enemy.gd
			## _broadcast_attack_state notu).
			if target_enemy.has_method("_enter_state_networked"):
				target_enemy._enter_state_networked()
		"hit_flash":
			## Yaratığın beyaz vuruş parlaması (eski "hurt_state" - HURT animasyonu
			## kaldırıldı, bkz. enemy.gd _broadcast_hit_flash).
			if target_enemy.has_method("_play_hit_flash_networked"):
				target_enemy._play_hit_flash_networked()
		"death_state":
			## enemy.gd _broadcast_death_state notuna bkz.: die() zaten en
			## başta is_dead kontrolüyle korunduğu için periyodik
			## _sync_enemy_positions'tan gelecek olası bir ikinci "öl"
			## çağrısıyla güvenle çakışabilir (no-op olur).
			if target_enemy.has_method("die"):
				target_enemy.die()


## Generic player VFX broadcast: muzzle flash, skill burst/ring, hit impacts, etc.
## vfx_type: "muzzle_flash", "skill_burst", "skill_ring", "hitscan_impact", "melee_hit",
## "skill_scene", "beam_start", "beam_stop", "beam_update", "paladin_barrier_flash",
## "shield_hit_flash", "oakley_bee_sting" (pos = sokulan yaratığın konumu, bkz. fx_oakley_bee_guard.gd)
## extra_data: {"scene_path": "...", "direction": Vector2, "color": Color, "scale": float, ...}
## Pet spawn/despawn - broadcast_player_vfx'ten (yukarısı) BİLEREK AYRI ve
## "reliable": o fonksiyon "unreliable" - kozmetik/yüksek frekanslı VFX'ler
## (namlu alevi vb.) için paket kaybı sorun değil, bir sonraki tekrar zaten
## gelir. Ama pet_spawn/pet_despawn TEK SEFERLİK, KALICI bir sahne durumu
## değişikliği (bir yaratık ekleniyor/çıkarılıyor) - "unreliable" kanalda bu
## paket kaybolursa BİR DAHA HİÇ tekrar gönderilmediği için o yaratık ilgili
## istemcide SONSUZA KADAR görünmez kalırdı (bkz. kullanıcı bildirimi:
## "Necromancer yaratık çağırınca diğer oyuncular hiç görmüyor" - kök
## nedenlerden biri buydu). instance_id: player.gd'de her çağırmaya
## üretilen benzersiz bir kimlik - remote_player.gd bunu Necromancer'ın aynı
## anda birden fazla yaratığını AYRI AYRI takip etmek için kullanıyor (bkz.
## orada _pet_visuals).
## DÜZELTME (kullanıcı bildirimi: "Necromancerin bazı yaratıkları bazı
## oyuncularda eksik gözüküyor"): "reliable" olması bu RPC'nin PAKETİNİN
## mutlaka ulaşacağını garanti eder, ama _find_remote_player(player_id) o an
## null dönerse (ör. bir yaratık, bu alıcı istemcide o oyuncunun RemotePlayer
## kuklası HENÜZ oluşturulmadan - yeni katılma/yeniden bağlanma sırasındaki
## kurulum gecikmesi yüzünden - çağrılan bir yaratık çağırma anına denk
## gelirse) çağrı sessizce hiçbir şey yapmadan döner ve bir daha ASLA tekrar
## denenmezdi - o TEK yaratık bu istemcide sonsuza kadar görünmez kalırdı,
## diğer (RemotePlayer zaten hazırken çağrılan) yaratıklar ise normal
## görünüyordu - "bazı yaratıklar bazı oyuncularda eksik" tam olarak bu
## demek. Artık RemotePlayer henüz yoksa birkaç kez kısa aralıklarla tekrar
## denenir (toplam ~2.5sn) - normal bağlantı kurulum gecikmesini kolayca
## karşılar, yine de bulunamazsa (oyuncu gerçekten ayrılmış olabilir) sessizce
## vazgeçilir.
@rpc("any_peer", "call_remote", "reliable")
func broadcast_pet_spawn(player_id: int, pet_scene: String, instance_id: String) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	var attempts: int = 0
	while not rp and attempts < 5:
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
		rp = _find_remote_player(player_id)
		attempts += 1
	if not rp:
		return
	if rp.has_method("_spawn_pet_visual"):
		rp._spawn_pet_visual(pet_scene, instance_id)


@rpc("any_peer", "call_remote", "reliable")
func broadcast_pet_despawn(player_id: int, instance_id: String) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	if not rp:
		return
	if rp.has_method("_despawn_pet_visual"):
		rp._despawn_pet_visual(instance_id)


## Pet konum senkronu - kullanıcı bildirimi: "necromancerin yaratıklarını
## ufacık ve çok hızlı hareket ederken görüyorlar". Kök neden: kozmetik pet
## kopyası, GERÇEK pet ile aynı script'i taşıyıp owner_player set edilmeden
## çalıştığı için (bkz. skeleton_pet.gd/wraith_pet.gd dosya başı notu)
## KENDİ BAŞINA "enemies" grubunu tarayıp en yakın yaratığı kovalıyordu -
## gerçek pet'ten tamamen bağımsız, senkronize olmayan bir yapay zeka.
## Artık gerçek pet (sahibinin istemcisinde) kendi konumunu/saldırı
## durumunu bu RPC ile periyodik yayınlıyor (bkz. skeleton_pet.gd/
## wraith_pet.gd/player_pet.gd _physics_process sonundaki broadcast bloğu),
## kozmetik kopya ise mark_as_network_visual() ile kendi yapay zekasını
## kapatıp SADECE buradan gelen konuma yumuşakça kayıyor - enemy.gd'nin
## istemci tarafı konum senkronuyla birebir aynı desen. "unreliable" +
## should_throttle: enemy pozisyon senkronuyla aynı sıklık sınıfında,
## saniyede onlarca kez gönderilebilecek yüksek frekanslı bir güncelleme.
## DÜZELTME (kritik hata: Necromancer'ın Golem'i multiplayer'da açıkken sürekli
## script hatası veriyordu) - golem_pet.gd _broadcast_network_state() bu
## fonksiyonu 6 argümanla (health_ratio/shield_ratio de ekleyerek) çağırıyordu
## ama burası hâlâ eski 4 parametreli haliyle duruyordu (bkz. dosya başı genel
## not - bu ikisi daha önce bir kez genişletilmişti ama Godot editörünün
## dosyayı açık tutup üzerine eski hafızadaki halini "Save All" ile geri
## yazması yüzünden sessizce eski haline dönmüştü). Şimdi tekrar genişletildi,
## bu sefer İSKELET/HORTLAK/Matthew'in tilkisi gibi çubuksuz pet'lerle GERİYE
## DÖNÜK UYUMLU kalması için health_ratio/shield_ratio varsayılan -1.0 (yani
## "bu pet'in çubuğu yok") - sadece Golem gerçekten 0.0-1.0 arası bir değer
## gönderiyor (bkz. remote_player.gd _update_pet_visual_state'teki dağıtım).
## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "necromancerın
## yaratıklarının animasyonları diğer oyunculara yanlış gösteriliyor") -
## sprite_row eklendi (bkz. skeleton_pet.gd/golem_pet.gd update_network_
## pet_state/update_network_golem_state üstündeki notlar) - eskiden yön hiç
## yayınlanmıyordu, kozmetik kopya kendi hareketinden yanlış tahmin ediyordu.
## DÜZELTME (kullanıcı isteği 2026-09-22: "tüm bu değişikliklerin multiplayerda
## da geçerli olmasını istiyorum, senkronizasyon kontrolü") - Matthew'in yeni
## Q'su (Tilki Hücumu) tilkiyi ANINDA ışınlıyor; kozmetik kopya normalde
## player_pet.gd _process_network_visual'da HER ZAMAN yumuşakça kayıyor
## (lerp), yani ışınlanma diğer oyunculara "Matthew'in tilkisi 0.3-0.5sn'de
## süzülerek geldi" gibi görünüyordu - kasterin ekranındaki ANINDA ışınlanmadan
## FARKLI (CLAUDE.md'deki "kaster doğru görür, diğerleri farklı görür" hata
## sınıfının bir varyasyonu). "teleport" eklendi: true ise kozmetik kopya
## _network_target_position'a kaymak YERİNE konuma ANINDA sıçrar (bkz.
## player_pet.gd update_network_pet_state).
@rpc("any_peer", "call_remote", "unreliable")
func broadcast_pet_state(player_id: int, instance_id: String, pos: Vector2, is_attacking: bool, health_ratio: float = -1.0, shield_ratio: float = -1.0, sprite_row: int = -1, teleport: bool = false) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	if not rp:
		return
	if rp.has_method("_update_pet_visual_state"):
		rp._update_pet_visual_state(instance_id, pos, is_attacking, health_ratio, shield_ratio, sprite_row, teleport)


## Kullanıcı isteği: "senkronize et, ben nasıl görüyosam diğer oyuncular da
## öyle görmeli" - Oakley'in Sarmaşıklar yeteneği (bkz. oakley_vine.gd) eskiden
## SADECE döken oyuncunun kendi istemcisinde vardı (kozmetik yayın yoktu,
## hasar/sabitleme enemy.gd üzerinden zaten senkronize oluyordu ama sarmaşığın
## KENDİSİ diğer oyunculara hiç görünmüyordu). broadcast_pet_spawn/despawn/
## state ile BİREBİR AYNI desen (bkz. o üçünün üstündeki notlar) - tek fark,
## sarmaşığın Line2D'si sadece kendi konumuna değil O ANKİ hedefine de bağlı
## olduğu için state mesajı hedef konumunu da taşıyor (kozmetik kopyanın
## gerçek bir Enemy referansı yok, bu yüzden hedefin KENDİSİ değil ANLIK
## KONUMU gönderiliyor).
@rpc("any_peer", "call_remote", "reliable")
func broadcast_oakley_vine_spawn(player_id: int, instance_id: String) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	if not rp:
		return
	if rp.has_method("_spawn_vine_visual"):
		rp._spawn_vine_visual(instance_id)


@rpc("any_peer", "call_remote", "reliable")
func broadcast_oakley_vine_despawn(player_id: int, instance_id: String) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	if not rp:
		return
	if rp.has_method("_despawn_vine_visual"):
		rp._despawn_vine_visual(instance_id)


@rpc("any_peer", "call_remote", "unreliable")
func broadcast_oakley_vine_state(player_id: int, instance_id: String, pos: Vector2, target_pos: Vector2, has_target: bool) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	if not rp:
		return
	if rp.has_method("_update_vine_visual_state"):
		rp._update_vine_visual_state(instance_id, pos, target_pos, has_target)


## Necromancer ULTİ'sinin diğer oyunculardaki kozmetik kafatasları (oyuncu peer id -> NecroSkull), bkz. "necro_skull" dalı.
const NecroSkullScript := preload("res://scripts/necro_skull.gd")
var _necro_skull_visuals: Dictionary = {}


@rpc("any_peer", "call_remote", "unreliable")
func broadcast_player_vfx(player_id: int, vfx_type: String, pos: Vector2, extra_data: Dictionary) -> void:
	var rp: RemotePlayer = _find_remote_player(player_id)
	if not rp:
		return
	match vfx_type:
		"muzzle_flash":
			var scene_path: String = str(extra_data.get("scene_path", ""))
			if scene_path.is_empty():
				return
			if not ResourceLoader.exists(scene_path):
				return
			var fx_scene: PackedScene = load(scene_path) as PackedScene
			if not fx_scene:
				return
			var fx: Node2D = fx_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(fx)
			fx.global_position = pos
			fx.rotation = float(extra_data.get("rotation", 0.0))
		## DÜZELTME (kullanıcı bildirimi: "bazı karakterler ve yetenekleri
		## multiplayerda çalışmıyor ve görünmüyor") - Matthew'in Vahşi Hız
		## (TEMEL) yeteneğindeki hız çizgisi izi eskiden diğer istemcilere HİÇ
		## yayınlanmıyordu (bkz. player.gd _spawn_matthew_speed_line). "muzzle_
		## flash" ile AYNI world-space spawn mantığı ama fx_speed_line.gd'nin
		## görünümü kendi `setup(direction, color)` çağrısına bağlı olduğu
		## için (sadece `rotation` set etmek hiçbir şey çizdirmez, bkz. o
		## script'in _draw()'ı) ayrı bir dal gerekti.
		"speed_line":
			var sl_scene_path: String = str(extra_data.get("scene_path", ""))
			if sl_scene_path.is_empty() or not ResourceLoader.exists(sl_scene_path):
				return
			var sl_scene: PackedScene = load(sl_scene_path) as PackedScene
			if not sl_scene:
				return
			var sl_fx: Node2D = sl_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(sl_fx)
			sl_fx.global_position = pos
			if sl_fx.has_method("setup"):
				sl_fx.setup(Vector2(extra_data.get("direction", Vector2.LEFT)), Color(extra_data.get("color", Color(1.0, 0.9, 0.2, 0.8))))
		"skill_burst":
			if rp.has_method("_spawn_burst_vfx"):
				rp._spawn_burst_vfx(float(extra_data.get("radius", 80.0)), Color(extra_data.get("color", Color.WHITE)))
		"skill_ring":
			if rp.has_method("_spawn_ring_vfx"):
				rp._spawn_ring_vfx(float(extra_data.get("radius", 120.0)), Color(extra_data.get("color", Color.WHITE)))
		"skill_scene":
			var scene_path: String = str(extra_data.get("scene_path", ""))
			if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
				return
			var skill_scene: PackedScene = load(scene_path) as PackedScene
			if not skill_scene:
				return
			var skill_fx: Node = skill_scene.instantiate()
			rp.add_child(skill_fx)
			if "position" in extra_data:
				skill_fx.set("position", Vector2(extra_data["position"]))
		"hitscan_impact":
			var scene_path: String = str(extra_data.get("scene_path", ""))
			if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
				return
			var impact_scene: PackedScene = load(scene_path) as PackedScene
			if not impact_scene:
				return
			var impact_fx: Node2D = impact_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(impact_fx)
			impact_fx.global_position = pos
			## DÜZELTME: bazı hitscan_impact fx'leri (örn. fx_meteor_strike,
			## fx_skill_ring) setup() çağrılmadan konum/yarıçap/renk bilgisini
			## kaybediyordu - fx_meteor_strike (0,0)'a düşüyor, fx_skill_ring
			## sabit 80px/beyaz kalıyordu. extra_data'daki alanlara göre doğru
			## setup() imzasını çağırıyoruz.
			if impact_fx.has_method("setup"):
				if bool(extra_data.get("setup_pos", false)):
					impact_fx.call("setup", pos)
				elif extra_data.has("radius"):
					impact_fx.call("setup", float(extra_data.get("radius", 80.0)), Color(extra_data.get("color", Color.WHITE)))
		## Oakley Arı Sürüsü (ikinci tasarım, fx_oakley_bee_guard.gd): kasterin arısı bu noktadaki yaratığa daldı -
		## kuklanın üstündeki kozmetik sürüden bir arı aynı noktaya dalıp sokma efektini oynatır (hasar VERMEZ - zehir/itme sadece
		## kasterin kopyasında; burada da uygulansa host-yetkili enemy.gd'de yük katlanırdı).
		"oakley_bee_sting":
			for child in rp.get_children():
				if child is OakleyBeeGuard and not child.is_queued_for_deletion():
					child.remote_sting(pos)
					break
		## Oakley'in Çiçek yeteneği - bkz. player.gd _try_oakley_flower/
		## scripts/oakley_flower.gd. chain_lightning/arcane_skull_bounce ile
		## AYNI desen: uzak istemcide gerçek Oakley referansı olmadığı için
		## gerekli tüm veri (saldırı gücü snapshot'ı + benzersiz kimlik)
		## extra_data ile taşınıyor.
		"oakley_flower_spawn":
			var flower_scene: Script = load("res://scripts/oakley_flower.gd")
			if not flower_scene:
				return
			var flower := Node2D.new()
			flower.set_script(flower_scene)
			get_tree().current_scene.add_child(flower)
			flower.global_position = pos
			if flower.has_method("setup"):
				flower.call("setup", float(extra_data.get("caster_damage_bonus", 0.0)), str(extra_data.get("flower_id", "")))
		## Oakley'nin pasifinin çiçek bırakma anındaki anlık "sihirli bağ"
		## çizgisi (kullanıcı isteği: "çiçek bırakırken bıraktığı yere doğru
		## bıraktığı esnada ince bir sihirli bağ efekti oluşacak anlık") -
		## "oakley_flower_spawn" ile AYNI desen, pos=Oakley'nin konumu,
		## extra_data.end_pos=çiçeğin düştüğü nokta.
		"oakley_flower_bond":
			var bond_scene: Script = load("res://scripts/fx_oakley_flower_bond.gd")
			if not bond_scene:
				return
			var bond := Node2D.new()
			bond.set_script(bond_scene)
			get_tree().current_scene.add_child(bond)
			if bond.has_method("setup"):
				bond.call("setup", pos, Vector2(extra_data.get("end_pos", pos)))
		"chain_lightning":
			## Şimşek Asası'nın düşmandan düşmana sıçrama efekti (bkz.
			## weapon.gd _spawn_chain_lightning_fx) - uzak oyuncularda gerçek
			## Enemy node referansı olmadığı için iki sabit pozisyon (from_pos/
			## pos) kullanan setup_positions() ile kuruluyor.
			var chain_scene: PackedScene = load("res://scenes/fx_lightning_chain.tscn") as PackedScene
			if not chain_scene:
				return
			var chain_fx: Node2D = chain_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(chain_fx)
			if chain_fx.has_method("setup_positions"):
				chain_fx.setup_positions(Vector2(extra_data.get("from_pos", pos)), pos)
		## Necromancer ULTİ (Lanetli Kafatası, bkz. necro_skull.gd dosya başı): extra_data.phase = "start" (pos = doğuş),
		## "leg" (pos = hedef, from/dur), "end". Her oyuncu için tek kozmetik kafatası (_necro_skull_visuals) - hasar/korku
		## YOK, sadece yetkili kafatasının bacaklarını aynı sürede uçar ve bacak sonunda aynı çarpma efektini oynatır.
		"necro_skull":
			var phase: String = str(extra_data.get("phase", ""))
			var skull: Node = _necro_skull_visuals.get(player_id)
			if skull != null and not is_instance_valid(skull):
				skull = null
			if phase == "end":
				if skull and skull.has_method("network_end"):
					skull.network_end()
				_necro_skull_visuals.erase(player_id)
				return
			if skull == null or phase == "start":
				if skull and skull.has_method("network_end"):
					skull.network_end()
				var start_pos: Vector2 = pos if phase == "start" else Vector2(extra_data.get("from", pos))
				skull = NecroSkullScript.new()
				skull.setup_network(start_pos)
				get_tree().current_scene.add_child(skull)
				_necro_skull_visuals[player_id] = skull
			if phase == "leg" and skull.has_method("network_leg"):
				skull.network_leg(Vector2(extra_data.get("from", pos)), pos, float(extra_data.get("dur", 0.5)))
		"arcane_skull_bounce":
			## Büyücü Kız'ın Arcane Lanet varyasyonu - "chain_lightning" ile
			## BİREBİR AYNI gerekçe (bkz. yukarısı): uzak oyuncularda gerçek
			## Enemy node referansı olmadığı için setup_positions() ile iki
			## sabit pozisyon arasında uçuruluyor.
			var skull_scene: PackedScene = load("res://scenes/fx_arcane_skull_bounce.tscn") as PackedScene
			if not skull_scene:
				return
			var skull_fx: Node2D = skull_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(skull_fx)
			if skull_fx.has_method("setup_positions"):
				skull_fx.setup_positions(Vector2(extra_data.get("from_pos", pos)), pos)
		"melee_hit":
			var scene_path: String = str(extra_data.get("scene_path", ""))
			if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
				return
			var hit_scene: PackedScene = load(scene_path) as PackedScene
			if not hit_scene:
				return
			var hit_fx: Node2D = hit_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(hit_fx)
			hit_fx.global_position = pos
			hit_fx.rotation = float(extra_data.get("rotation", 0.0))
			## DÜZELTME (kullanıcı bildirimi: "talon ultisini açınca... efektler
			## büyümediği için büyümemiş gibi görünüyor" + "bıçak kesme efekti
			## çok büyük görünüyor diğer oyunculara"): bu kopya eskiden hiçbir
			## ölçek uygulamıyordu - gönderen taraftaki hit_impact_scale_mult
			## VE Talon Devleşme'nin aoe_radius_multiplier'ı (bkz. weapon.gd
			## _spawn_melee_hit_fx, artık "scale_mult" alanıyla gönderiyor)
			## katılımcı ekranında tamamen yok sayılıyordu.
			var scale_mult: float = float(extra_data.get("scale_mult", 1.0))
			if scale_mult != 1.0:
				hit_fx.scale *= scale_mult
			## DÜZELTME (kullanıcı isteği: "her bir yaratığa vurduğunda vuruş
			## ses efekti... çıksın" - Assasin Çocuk'un Gölge Hücumu ultisi,
			## bkz. player.gd _spawn_assasin_dash_hit_fx): "melee_hit" eskiden
			## hiç ses taşımıyordu, sadece görsel efekt. İsteğe bağlı
			## "sound_path" alanı varsa isabet konumunda bir kerelik 2D ses
			## çalınıyor - weapon_sound broadcast'indeki AYNI kalıcı/tek
			## seferlik AudioStreamPlayer2D deseni.
			var hit_sound_path: String = str(extra_data.get("sound_path", ""))
			if not hit_sound_path.is_empty() and ResourceLoader.exists(hit_sound_path):
				var hit_sound_res: AudioStream = load(hit_sound_path) as AudioStream
				if hit_sound_res:
					var hit_asp: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
					get_tree().current_scene.add_child(hit_asp)
					hit_asp.global_position = pos
					hit_asp.stream = hit_sound_res
					hit_asp.pitch_scale = float(extra_data.get("pitch", 1.0))
					## bkz. "weapon_sound" case'indeki aynı düzeltme - eskiden 0dB
					## (tam ses) çalıyordu, mesafeyle de yeterince azalmıyordu.
					hit_asp.volume_db = float(extra_data.get("volume_db", -10.0))
					hit_asp.max_distance = 900.0
					hit_asp.attenuation = 1.6
					hit_asp.finished.connect(hit_asp.queue_free)
					hit_asp.play()
		"beam_start":
			if rp.has_method("_start_beam_vfx"):
				rp._start_beam_vfx(str(extra_data.get("beam_type", "")), pos, extra_data)
		"beam_stop":
			if rp.has_method("_stop_beam_vfx"):
				rp._stop_beam_vfx()
		"beam_update":
			if rp.has_method("_update_beam_vfx"):
				var origin_pos: Vector2 = Vector2(extra_data.get("from_pos", Vector2.ZERO))
				rp._update_beam_vfx(pos, origin_pos)
		"weapon_sound":
			var snd_path: String = str(extra_data.get("sound_path", ""))
			if not snd_path.is_empty() and ResourceLoader.exists(snd_path):
				var snd_res: AudioStream = load(snd_path) as AudioStream
				if snd_res:
					var asp: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
					rp.add_child(asp)
					asp.stream = snd_res
					## DÜZELTME (kullanıcı bildirimi: "silahların sesleri çok yüksek
					## ve kafa ağrıtıyor" + "oyuncular uzakken bile diğer oyuncuların
					## silah seslerini duyabiliyor, uzaklığa göre azalıp artması
					## gerek"): eskiden volume_db hiç taşınmıyordu, yani her uzak
					## silah sesi kaynağındaki (-8/-9/-10dB) seviyeyi yok sayıp
					## DAİMA 0dB (tam ses) çalıyordu - kalabalık bir maçta herkesin
					## silahı en yüksek sesteydi. Artık gönderen tarafın gerçek
					## volume_db'si taşınıyor (yoksa -10dB'ye düşülüyor). Ayrıca
					## max_distance düşürüldü ve "attenuation" üsteli artırıldı ki
					## ses mesafeyle daha belirgin ve daha erken azalsın.
					asp.volume_db = float(extra_data.get("volume_db", -10.0))
					asp.max_distance = 900.0
					asp.attenuation = 1.6
					asp.pitch_scale = float(extra_data.get("pitch", 1.0))
					asp.finished.connect(asp.queue_free)
					asp.play()
		"weapon_recoil":
			## recoil_distance artık ağdan gelmiyor - _animate_weapon_recoil
			## bu silahın kendi sabit değerini yerel diziden okuyor.
			if rp.has_method("_animate_weapon_recoil"):
				rp._animate_weapon_recoil(int(extra_data.get("slot_index", 0)))
		## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "boomerang ve
		## fişek ... diğer oyunculara yeni bir projectile fırlatılıyormuş
		## gibi görünüyor") - bkz. weapon.gd _broadcast_weapon_icon_visibility
		## üstündeki notu. Tabanca'nın reload gizlemesi de AYNI kök nedene
		## sahipti, aynı kanaldan çözüldü.
		"weapon_icon_visibility":
			if rp.has_method("_set_weapon_icon_visible"):
				rp._set_weapon_icon_visible(int(extra_data.get("slot_index", -1)), bool(extra_data.get("visible", true)))
		"weapon_fire":
			if rp.has_method("_animate_weapon_fire_full"):
				rp._animate_weapon_fire_full(extra_data)
			elif rp.has_method("_animate_weapon_fire"):
				var fire_dir: Vector2 = Vector2(float(extra_data.get("direction_x", 0.0)), float(extra_data.get("direction_y", -1.0)))
				rp._animate_weapon_fire(int(extra_data.get("slot_index", 0)), fire_dir, bool(extra_data.get("is_melee", false)), float(extra_data.get("attack_range", 100.0)))
		## Kullanıcı bildirimi: "Şovalye adamın kalkan baloncuğuna vurulduğu
		## andaki çatlama ve kalkanın hasar alma efekti şovalye adam
		## haricinde kimseye görünmüyor... bir oyuncu ne görüyorsa onu diğer
		## oyuncular da görmeli" - bkz. player.gd flash_paladin_barrier() ve
		## fx_paladin_barrier.gd flash_from_angle() üstündeki yorumlar.
		"paladin_barrier_flash":
			if rp._barrier_visual and is_instance_valid(rp._barrier_visual) and rp._barrier_visual.has_method("flash_from_angle"):
				rp._barrier_visual.flash_from_angle(float(extra_data.get("angle", 0.0)))
		## Aynı bildirim: Sihirli Kalkan/kalkan modu hasar aldığında oynayan
		## baloncuk parıldaması (+ isteğe bağlı halka efekti) da eskiden
		## sadece sahibinin kendi ekranında görünüyordu (bkz. player.gd
		## _broadcast_shield_visual_flash()).
		"shield_hit_flash":
			var flash_angle: float = float(extra_data.get("angle", 0.0))
			if rp.shield_visual and rp.shield_visual.has_method("flash"):
				rp.shield_visual.flash(flash_angle)
			if bool(extra_data.get("with_ring", false)):
				var hit_fx := Node2D.new()
				hit_fx.set_script(load("res://scripts/fx_shield_hit.gd"))
				rp.add_child(hit_fx)
				hit_fx.position = Vector2.ZERO
				if hit_fx.has_method("setup"):
					hit_fx.setup(flash_angle)
		## Vampir Çocuk pixel FX'i (bkz. vampir_math.gd spawn_fx / vampir_fx.gd): kind = "hit" (vuruş
		## patlaması), "puff" (Yarasa Formu geçişi), "drain" (Kan Emme - "points" kaynak konumları,
		## damlalar bu kukla'ya akar; "text" varsa "+1 Maks. Can" gibi kukla üstünde yazı).
		## Yarasa formunun kendisi/silahların çekilmesi bu kanaldan DEĞİL, animasyon adından gelir.
		## Genel pixel parçacık patlaması (pixel_draw.gd spawn_burst) - Korsan bomba tozu/duman/kıvılcımı vb.
		## Ruhani Yetenekler (bkz. spiritual_skills.gd, player.gd _spirit_* bloğu): "spirit_blink" = ışınlanma efekti
		## (kind "streak": Taktiksel, from=pos -> extra.to; kind "column": Dükkan, pos'ta ışık sütunu), "spirit_cancel" =
		## Dükkan odaklanması iptal (kukladaki kanal FX'ini adıyla bulup kapatır). Karakter-bağlı aura FX'leri (adc/tank/taktik/
		## dukkan) `skill_scene` ile, Can'ın takım FX'i _rpc_spirit_team_buff ile gider.
		"spirit_blink":
			var blink := Node2D.new()
			blink.set_script(load("res://scripts/fx_spirit_blink.gd"))
			get_tree().current_scene.add_child(blink)
			blink.call("setup", str(extra_data.get("kind", "streak")), pos, Vector2(extra_data.get("to", pos)))
		"spirit_cancel":
			var cancel_target: Node = rp.get_node_or_null(str(extra_data.get("node", "FxSpiritDukkan")))
			if cancel_target != null and cancel_target.has_method("cancel"):
				cancel_target.call("cancel")
		"pixel_burst":
			PixelDrawScript.spawn_burst(get_tree().current_scene, pos, str(extra_data.get("palette", "fire")), int(extra_data.get("count", 14)), float(extra_data.get("speed", 140.0)), float(extra_data.get("life", 0.5)))
		"vampir_fx":
			var vampir_kind: String = str(extra_data.get("kind", "hit"))
			var vampir_opts: Dictionary = {}
			if vampir_kind == "drain":
				vampir_opts["points"] = extra_data.get("points", PackedVector2Array())
				vampir_opts["sink"] = rp
			VampirMathScript.spawn_fx(get_tree().current_scene, vampir_kind, pos, vampir_opts)
			## extra_data "text" (Q'nun "+1 Maks. Can" yazısı) artık uzak ekranlarda GÖSTERİLMİYOR - kullanıcı isteği
			## (2026-09-25): başka oyuncuların can/hasar sayıları görünmemeli. Yazıyı sadece Vampir kendisi görür.


## DÜZELTME (kullanıcı bildirimi: "multiplayerda genel olarak bazı hosta
## görünüp diğer oyunculara görünmeyen efektler animasyonlar yaratıklar v.s
## olabiliyor" - derin araştırma sonucu): kök neden burasıydı. Eskiden
## main_node._get_remote_player() (SADECE var olanı döner, YARATMAZ)
## kullanılıyordu - transform senkronu (bkz. main.gd _rpc_update_player_
## transform, "unreliable") ile bu fonksiyonu çağıran her RPC (broadcast_
## player_vfx/broadcast_pet_spawn/broadcast_pet_despawn/broadcast_pet_state)
## TAMAMEN AYRI, sırasız (unreliable, ordering garantisi yok) kanallar -
## yani bir yeteneğin görsel efekti, o oyuncunun konumunu bildiren İLK paket
## bu istemciye ulaşmadan ÖNCE işlenirse (özellikle yüksek gecikmeli/paket
## kayıplı bir bağlantıda - bkz. Ziva Cloud notları - bu sadece bağlantının
## en başında değil, OTURUM BOYUNCA herhangi bir anda olabilir) RemotePlayer
## kuklası bu istemcide HENÜZ YOK demektir - efekt sessizce yok sayılırdı.
## "Bazı" efektlerin bazen host'ta görünüp katılımcılarda görünmemesinin,
## özellikle NADİR/tek seferlik olanların (ör. Şovalye ultisinin patlama
## efekti - ~180sn'de bir, "unreliable" bir paket kaybolursa BİR DAHA ASLA
## tekrar gelmez) neden özellikle etkilendiğinin kök nedeni budur. Artık
## main.gd _get_or_spawn_remote_player() kullanılıyor - kukla yoksa hemen
## (lobby_players'taki bilinen karakter/isimle) oluşturulup konumu bir
## sonraki transform paketiyle zaten düzeltilecek, efekt asla sessizce
## kaybolmaz.
func _find_remote_player(player_id: int) -> RemotePlayer:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_get_or_spawn_remote_player"):
		return main_node._get_or_spawn_remote_player(player_id)
	if main_node and main_node.has_method("_get_remote_player"):
		return main_node._get_remote_player(player_id)
	# Fallback: search by node name
	for child: Node in get_tree().current_scene.get_children():
		if child is RemotePlayer and child.peer_id == player_id:
			return child
	return null


## Gold sharing: when any player picks up gold, all players receive the same amount.
@rpc("any_peer", "call_remote", "reliable")
func share_gold(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.gold += amount


## Gold spending: when a player spends gold in the shop, deduct from all peers.
@rpc("any_peer", "call_remote", "reliable")
func spend_gold(amount: int) -> void:
	GameManager.gold = max(0, GameManager.gold - amount)


## Yaratık yetenekleri (2026-09-24, bkz. enemy_abilities.gd): host'taki yetkili lazer/diken/asit/ateş topu bir
## RemotePlayer kuklasına değince (remote_player.gd take_special_damage) hasar TÜRÜYLE birlikte gerçek oyuncuya
## iletilir - forward_damage_to_peer ile aynı mimari, türe özel kurallar (yanma, kalkana x2) player.gd
## take_special_damage'da o oyuncunun kendi makinesinde uygulanır.
@rpc("any_peer", "call_remote", "reliable")
func forward_special_damage_to_peer(amount: float, enemy_net_id: int, kind: String) -> void:
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if not local_player or not is_instance_valid(local_player):
		return
	var enemy_node: Node2D = find_enemy_by_net_id(enemy_net_id) as Node2D
	if local_player.has_method("take_special_damage"):
		local_player.take_special_damage(amount, enemy_node, kind)
	elif local_player.has_method("take_damage"):
		local_player.take_damage(amount, enemy_node)


## Yaratık yeteneklerinin DÜNYADA duran etkileri (kind: "laser"/"thorns"/"acid"/"fireball", bkz. enemy_abilities.gd
## spawn_world_fx) - host yetkili (hasar veren) örneği kendisi doğurur, istemciler burada SADECE görsel kopyayı doğurur
## (authoritative=false: hasar vermez). Tek seferlik/seyrek olay olduğu için reliable (bkz. broadcast_enemy_vfx notu).
@rpc("any_peer", "call_remote", "reliable")
func broadcast_enemy_ability_fx(kind: String, pos: Vector2, data: Dictionary) -> void:
	var abilities_script: GDScript = load("res://scripts/enemy_abilities.gd")
	abilities_script.spawn_world_fx(get_tree(), kind, pos, data, false)


## Host bir yaratığın bir RemotePlayer kuklasına (=gerçek bir uzak client)
## vurduğunu tespit ettiğinde (bkz. remote_player.gd take_damage/
## take_paladin_barrier_damage) bu RPC ile GERÇEK client'a "sen hasar
## aldın" der - gerçek hasar hesaplaması (zırh/kalkan/can/ölüm) SADECE o
## client'ın kendi yetkili Player node'unda olur, host burada hiçbir şeyi
## kendi hesaplamaz. Bu, "yaratıklar katılımcıya saldırıyor ama katılımcı
## hasar almıyor" bug'ının kök nedenini (RemotePlayer'da take_damage hiç
## yoktu) düzeltir.
@rpc("any_peer", "call_remote", "reliable")
func forward_damage_to_peer(amount: float, enemy_net_id: int, is_barrier_damage: bool) -> void:
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if not local_player or not is_instance_valid(local_player):
		return
	var enemy_node: Node2D = find_enemy_by_net_id(enemy_net_id) as Node2D
	if is_barrier_damage:
		if local_player.has_method("take_paladin_barrier_damage"):
			local_player.take_paladin_barrier_damage(amount, enemy_node)
	else:
		if local_player.has_method("take_damage"):
			local_player.take_damage(amount, enemy_node)


## Host bir sandığı GERÇEK bir uzak client'ın topladığını tespit ettiğinde
## (bkz. chest_drop.gd _open_for_player) bu RPC ile o client'a "bu sandık
## senin" der - itemler SADECE o client'ın kendi GameManager'ına (kişisel
## envanterine) eklenir, host'a hiç dokunmaz. Kullanıcı isteği: "sandık
## alınca sol üstteki avatarın yanına simge görünsün, biriken sandıklar
## seviye atlayınca otomatik açılsın" - artık burada ANINDA menü AÇILMIYOR,
## sadece o client'ın kendi kuyruğuna ekleniyor (bkz. chest_drop.gd
## _open_chest_for'daki aynı değişiklik, main.gd _try_open_next_pending_chest).
@rpc("any_peer", "call_remote", "reliable")
func open_chest_for_peer(chest_tier: int) -> void:
	GameManager.add_pending_chest(chest_tier)


## ---------- Ortak ödül dağıtımı (kullanıcı isteği, 2026-09-21) ----------
## Sandık: "bir oyuncu sandığı alırsa o sandık RASTGELE birine verilir, herkesin eşit şansı vardır, sadece 1 kişi
## alabilir, her sandıkta yeniden hesaplanır". Boss altını: "biri aldığında diğer oyuncular arasında eşit paylaştırılır
## (herkesin payı kendisine doğru uçar)". İkisi de SADECE host'ta çalışır (gerçek drop host'ta yaşar, bkz. chest_drop.gd/
## gold_drop.gd) - tek oyunculuda hiçbir şey değişmez.
##
## Katılımcılar: host'un yerel oyuncusu + tüm uzak oyuncular; kalıcı olarak ölmüş (is_dead) olanlar dışarıda
## (ödülü kullanamazlar). [{"peer_id": int, "node": Node}]
func get_reward_participants() -> Array:
	var out: Array = []
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.get("is_dead") != true:
		out.append({"peer_id": multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1, "node": local_p})
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(rp) or rp.get("is_dead") == true or not ("peer_id" in rp) or int(rp.peer_id) <= 0:
			continue
		out.append({"peer_id": int(rp.peer_id), "node": rp})
	return out


## Sandığı TOPLAYAN oyuncuya verir. Kullanıcı isteği (2026-09-24): "sandık alınca sandığın sandığı alan kişiye verilmesi
## gerekiyor diğer oyunculara değil" - 2026-09-21'deki "rastgele birine (1/N)" kuralı KALDIRILDI. picker_peer_id
## katılımcılar arasında değilse (bulunamadı/ölü) yedek olarak eski rastgele seçim kullanılır, sandık boşa gitmez.
## Döner: kazanan peer id (0 = kimse yok, çağıran kendi yerel yoluna düşer). Kazanan host'sa yerel kuyruğa eklenir,
## uzak bir client ise open_chest_for_peer ile.
func host_award_chest(chest_tier: int, picker_peer_id: int = 0) -> int:
	if not is_host:
		return 0
	var participants: Array = get_reward_participants()
	if participants.is_empty():
		return 0
	var candidate_ids: Array = []
	for p: Dictionary in participants:
		candidate_ids.append(int(p["peer_id"]))
	var winner_id: int = picker_peer_id if candidate_ids.has(picker_peer_id) else pick_chest_winner(candidate_ids)
	if winner_id == (multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1):
		GameManager.add_pending_chest(chest_tier)
	else:
		open_chest_for_peer.rpc_id(winner_id, chest_tier)
	_rpc_announce_chest_winner.rpc(winner_id)
	return winner_id


## Sandık kazananı: her katılımcının şansı EŞİT (1/N), ağırlık yok. Test edilebilsin diye ayrı saf fonksiyon.
static func pick_chest_winner(peer_ids: Array) -> int:
	if peer_ids.is_empty():
		return 0
	return int(peer_ids[randi() % peer_ids.size()])


## Boss altını payları: amount, katılımcılara EŞİT bölünür; artan (amount % N) toplayana (yoksa ilk katılımcıya) gider.
## Toplam her zaman amount'a eşit kalır. Dönen: peer_id -> pay.
static func compute_gold_shares(amount: int, peer_ids: Array, picker_id: int) -> Dictionary:
	var shares: Dictionary = {}
	if peer_ids.is_empty() or amount <= 0:
		return shares
	var count: int = peer_ids.size()
	@warning_ignore("integer_division")
	var base_share: int = amount / count
	var remainder: int = amount - base_share * count
	for pid in peer_ids:
		shares[int(pid)] = base_share
	var remainder_to: int = picker_id if shares.has(picker_id) else int(peer_ids[0])
	shares[remainder_to] = int(shares[remainder_to]) + remainder
	return shares


## Sandığın kime düştüğü HERKESİN ekranında kazananın üstünde yazar (kazanan kendi ekranında "SANDIK SENİN!").
@rpc("any_peer", "call_local", "reliable")
func _rpc_announce_chest_winner(winner_id: int) -> void:
	var node: Node = _find_player_by_peer_id(winner_id)
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var text: String = "SANDIK SENİN!" if winner_id == local_id else "%s sandığı kazandı" % get_player_names([winner_id])
	var ft_scene: PackedScene = load("res://scenes/floating_text.tscn") as PackedScene
	if ft_scene == null or get_tree().current_scene == null:
		return
	var ft: Node2D = ft_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(ft)
	ft.global_position = (node as Node2D).global_position + Vector2(0, -52)
	if ft.has_method("setup"):
		ft.call("setup", text, Color(1.0, 0.85, 0.3))


## Ruhani Yetenek "Can" (bkz. player.gd _spirit_cast_can): kaster bunu çağırır, HER istemci (kaster dahil, call_local) kendi yerel
## oyuncusuna %8 can + %15 kalkan + 3sn dokunulmazlık uygular (apply_spirit_can_buff) ve herkesin üzerinde şifa/bariyer efektini gösterir.
## "Mesafe fark etmeksizin": RPC herkese gittiği için menzil kontrolü yok. Ölmüş oyuncular etkilenmez (apply_spirit_can_buff kendi içinde eler).
@rpc("any_peer", "call_local", "reliable")
func _rpc_spirit_team_buff(caster_id: int) -> void:
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.has_method("apply_spirit_can_buff"):
		local_p.apply_spirit_can_buff()
	## Kaster BİZSEK arkadaşlara bastığımız can/kalkanı kuklalarının üstünde görelim (kullanıcı isteği 2026-09-25);
	## her hedef kendi miktarını apply_spirit_can_buff ile kendi ekranında zaten görüyor, üçüncü kişiler görmez.
	var is_caster: bool = multiplayer.has_multiplayer_peer() and caster_id == multiplayer.get_unique_id()
	if is_caster:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			if not is_instance_valid(rp) or rp.get("is_dead") == true or rp.get("is_downed") == true \
					or not rp.has_method("show_support_number"):
				continue
			rp.show_support_number(float(rp.get("max_health")) * SpiritualSkillsScript.CAN_HEAL_PERCENT, false)
			rp.show_support_number(float(rp.get("item_shield_max")) * SpiritualSkillsScript.CAN_SHIELD_PERCENT, true)
	## Efekt: yerelde apply_spirit_can_buff kendi oyuncumuza doğurdu; burada SADECE uzak kuklalara.
	var scene: PackedScene = load("res://scenes/fx_spirit_can.tscn") as PackedScene
	if scene == null:
		return
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and rp.get("is_dead") != true:
			rp.add_child(scene.instantiate())


## Boss altınını toplayan (picker) dahil tüm katılımcılar arasında EŞİT böler; artan (amount % N) toplayana gider.
## Her pay ilgili oyuncunun KİŞİSEL altınına eklenir (bkz. grant_personal_gold) ve HERKESİN ekranında toplanma noktasından
## payın sahibine doğru bir altın uçar (bkz. _rpc_gold_share_fx / fx_gold_share.gd). Döner: false = paylaşılacak kimse yok
## (tek katılımcı) - çağıran altını eskisi gibi doğrudan verir.
func host_share_boss_gold(amount: int, from_pos: Vector2, picker: Node) -> bool:
	if not is_host or amount <= 0:
		return false
	var participants: Array = get_reward_participants()
	if participants.size() <= 1:
		return false
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var picker_id: int = local_id
	if picker != null and is_instance_valid(picker) and not picker.is_in_group("player") and "peer_id" in picker:
		picker_id = int(picker.peer_id)
	var peer_ids: Array = []
	for p: Dictionary in participants:
		peer_ids.append(int(p["peer_id"]))
	var shares: Dictionary = compute_gold_shares(amount, peer_ids, picker_id)
	for pid in shares.keys():
		var share: int = int(shares[pid])
		if share <= 0:
			continue
		if int(pid) == local_id:
			grant_personal_gold(share)
		else:
			grant_personal_gold.rpc_id(int(pid), share)
	var fx_shares: Dictionary = {}
	for pid in shares.keys():
		if int(shares[pid]) > 0:
			fx_shares[pid] = shares[pid]
	_rpc_gold_share_fx.rpc(from_pos, fx_shares)
	return true


## Herkesin ekranında: toplanma noktasından her payın sahibine doğru uçan altınlar (kozmetik, altın host'ta zaten verildi).
@rpc("any_peer", "call_local", "reliable")
func _rpc_gold_share_fx(from_pos: Vector2, shares: Dictionary) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var index: int = 0
	for pid in shares.keys():
		var target: Node = _find_player_by_peer_id(int(pid))
		if target == null or not is_instance_valid(target) or not (target is Node2D):
			continue
		var fx := Node2D.new()
		fx.set_script(load("res://scripts/fx_gold_share.gd"))
		root.add_child(fx)
		fx.call("setup", from_pos, target, index, int(pid) == local_id)
		index += 1


## Şans faktörüyle her oyuncunun kişisel altınına doğrudan ekleme yapar -
## bkz. remote_player.gd collect_gold. Kullanıcı isteği: "oyundaki para
## ortak olmamalı herkesin parası kişisel olmalı" - eskiden share_gold TÜM
## peer'lere aynı miktarı ekliyordu (ortak havuz), artık SADECE ilgili
## client'a (rpc_id ile hedeflenmiş) uygulanıyor.
@rpc("any_peer", "call_remote", "reliable")
func grant_personal_gold(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.gold += amount
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and is_instance_valid(local_player):
		var ft_scene: PackedScene = load("res://scenes/floating_text.tscn") as PackedScene
		if ft_scene:
			var ft = ft_scene.instantiate()
			get_tree().current_scene.add_child(ft)
			ft.global_position = local_player.global_position + Vector2(14, -34)
			if ft.has_method("setup"):
				ft.setup("+%d altın" % amount, Color(1.0, 0.85, 0.25))


## Parti panelindeki altın ikonu (bkz. party_panel.gd _on_gift_amount_pressed)
## bir müttefike altın göndermek için bunu ÇAĞIRIR (bu bir RPC DEĞİL, sadece
## GÖNDEREN tarafta yerel bir doğrulama+düşme fonksiyonu) - altın kişisel
## olduğu için (bkz. grant_personal_gold üstündeki yorum) burada SADECE
## gönderenin KENDİ GameManager.gold'undan düşülür, sonra hedeflenen client'a
## receive_gold_gift RPC'siyle haber verilir. is_multiplayer_active
## kontrolü zaten burada da var (party_panel.gd tarafında da kontrol
## ediliyor ama çift güvenlik için burada tekrar edildi).
func request_give_gold(to_player_id: int, amount: int) -> bool:
	if not is_multiplayer_active or amount <= 0 or to_player_id <= 0:
		return false
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if to_player_id == my_id:
		return false
	if GameManager.gold < amount:
		return false
	GameManager.gold -= amount
	receive_gold_gift.rpc_id(to_player_id, local_player_name, amount)
	return true


## request_give_gold()'un karşı ucu - SADECE hedeflenen client'ta çalışır
## (rpc_id ile gönderildi). grant_personal_gold'un "kişisel altına ekle +
## dalgalı yazı göster" desenini birebir izler, tek fark: mesaj metni normal
## bir altın toplamayla KARIŞMASIN diye kimden geldiğini belirtip "hediye"
## kelimesini açıkça kullanır (kullanıcı isteği: "bir HEDİYE olduğu belli
## olsun, normal toplama gibi görünmesin").
@rpc("any_peer", "call_remote", "reliable")
func receive_gold_gift(from_name: String, amount: int) -> void:
	if amount <= 0:
		return
	GameManager.gold += amount
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and is_instance_valid(local_player):
		var ft_scene: PackedScene = load("res://scenes/floating_text.tscn") as PackedScene
		if ft_scene:
			var ft = ft_scene.instantiate()
			get_tree().current_scene.add_child(ft)
			ft.global_position = local_player.global_position + Vector2(14, -34)
			if ft.has_method("setup"):
				ft.setup("%s'ten +%d altın hediye!" % [from_name, amount], Color(1.0, 0.85, 0.25))


## Shared XP: the peer who picks up an orb awards the same amount to every from receiving the amount
## twice; Player.add_xp() already applies it locally.
@rpc("any_peer", "call_remote", "reliable")
func sync_ally_heal(target_peer_id: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("heal"):
		local_player.heal(amount)


## BUG DÜZELTMESİ (kullanıcı bildirimi: "oakley ve meleğin kalkan yenileme
## yeteneği takım arkadaşlarına kalkan vermiyor") - sync_ally_heal'in (can)
## BİREBİR AYNI deseni, sadece kalkan için. Eskiden player.gd
## _process_healer_shield_tick() müttefik hedefine DOĞRUDAN .heal_shield()
## çağırıyordu - hedef bir RemotePlayer (gerçek uzak oyuncu) ise bu SADECE
## caster'ın ekranındaki kozmetik kuklayı değiştiriyordu, gerçek oyuncunun
## kendi istemcisindeki kalkanı hiç artmıyordu (bkz. player.gd
## _apply_heal_to_ally üstündeki AYNI kök neden açıklaması, can için zaten
## bu RPC deseniyle çözülmüştü).
@rpc("any_peer", "call_remote", "reliable")
func sync_ally_shield_heal(target_peer_id: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("heal_shield"):
		## Kullanıcı isteği (2026-09-25): arkadaşın bastığı kalkan hedefin KENDİ ekranında da üstünde yazsın
		## (kaster kendi ekranında kuklanın üstünde görüyor - bkz. player.gd _apply_shield_heal_to_ally).
		## heal_shield() genel yenilemede de (regen, toplama) çağrıldığı için sayı orada değil, burada.
		if local_player.has_method("show_received_shield_number"):
			local_player.show_received_shield_number(amount)
		local_player.heal_shield(amount)


## Şovalye Adam'ın Koruma Bariyeri (skill3, id 29) - sync_ally_heal ile AYNI
## "hedefin kendi peer_id'sine RPC" deseni, sadece bir sayı yerine hedefin
## KENDİ Player'ındaki damage_redirect_* alanlarını set ediyor (bkz.
## player.gd _apply_damage_redirect_to_ally/take_damage). percent<=0 buff'ı
## kaldırır (bkz. player.gd _end_paladin_barrier).
@rpc("any_peer", "call_remote", "reliable")
func sync_damage_redirect_buff(target_peer_id: int, source_peer_id: int, percent: float, duration: float) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if not local_player or not ("damage_redirect_percent" in local_player):
		return
	if percent > 0.0:
		local_player.damage_redirect_percent = percent
		local_player.damage_redirect_peer_id = source_peer_id
		local_player.damage_redirect_timer = duration
	else:
		local_player.damage_redirect_percent = 0.0
		local_player.damage_redirect_peer_id = 0


## Oakley'nin YENİ R'si (Koruyucu Büyü, skill3 id 39) - sync_damage_redirect_
## buff ile AYNI "hedefin kendi peer_id'sine RPC, hedefin KENDİ Player'ındaki
## alanları set et" deseni (bkz. player.gd _apply_oakley_bond_to_target/
## take_damage/_process_oakley_bond). Heal/kalkan miktarları CAST ANINDA
## Oakley'nin saldırı gücünden sabitlenmiş halde geliyor - hedef bundan sonra
## tamamen yerel çalışır, Oakley'nin GÜNCEL statlarına bir daha erişmeye
## gerek yok.
@rpc("any_peer", "call_remote", "reliable")
func sync_oakley_bond_buff(target_peer_id: int, heal_per_hit: float, shield_per_hit: float, reduction: float, duration: float) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if not local_player or not ("oakley_bond_active" in local_player):
		return
	local_player.oakley_bond_active = true
	local_player.oakley_bond_heal_per_hit = heal_per_hit
	local_player.oakley_bond_shield_per_hit = shield_per_hit
	local_player.oakley_bond_damage_reduction = reduction
	local_player.oakley_bond_timer = duration
	if local_player.has_method("ensure_oakley_leaf_barrier"):
		local_player.ensure_oakley_leaf_barrier()


## Koruma Bariyeri'nin gerçek etkisi - buflanmış dostun take_damage()'ı
## post-armor hasarının bir dilimini buraya gönderir (bkz. player.gd take_
## damage() içindeki yeni dal), Şovalye'nin KENDİ take_damage()'ından
## geçirir - kullanıcı isteği: "yansıyan hasar şovalye adamın zırhından
## sonra hesaplanır" DEĞİL, Şovalye'nin zırhı BU noktada normal şekilde
## uygulanacak (bypass YOK).
@rpc("any_peer", "call_remote", "reliable")
func sync_redirected_damage(target_peer_id: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("take_damage"):
		local_player.take_damage(amount)


## Ruhani Yetenek "Kalkan Bağı" - iki oyuncu arasında BAĞIMSIZ, iki taraflı bir bağ (Oakley'nin Koruyucu
## Büyü'sünden farklı: TEK yönlü bir "hedef" YOK, ikisi de birbirine eşit şekilde bağlı). Bağı KURAN taraf
## kendi tarafını doğrudan yerel olarak set eder (bkz. player.gd _spirit_cast_kalkan_bagi), bu RPC SADECE
## PARTNERİN kendi client'ında AYNI bayrakları set etmesi için (active=false = bağ bitti, hem toggle-kapatma
## hem mesafe kopması BURADAN geçer, bkz. player.gd _end_kalkan_bagi).
@rpc("any_peer", "call_remote", "reliable")
func sync_kalkan_bagi_bond(target_peer_id: int, source_peer_id: int, active: bool) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("receive_kalkan_bagi_bond"):
		local_player.receive_kalkan_bagi_bond(source_peer_id, active)


## Kalkan Bağı'nın gerçek mekaniği: bu oyuncunun kalkanında GERÇEKTEN işleyen (clamp sonrası) her
## artış/azalışın %50'si (bkz. spiritual_skills.gd KALKAN_BAGI_MIRROR_RATIO) partnerin kalkanına da uygulanır
## - "her türlü kalkan değişikliği" (hasar/yetenek bedeli/kalkan artışı) TEK bir yoldan geçtiği için (bkz.
## player.gd heal_shield/_spend_ability_shield_cost/take_damage - hepsi _kalkan_bagi_mirror() çağırır) burada
## ikinci bir kaynak YOK, sadece o TEK fonksiyonun sonucu iletiliyor.
@rpc("any_peer", "call_remote", "reliable")
func sync_kalkan_bagi_shield_delta(target_peer_id: int, delta_amount: float) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("receive_kalkan_bagi_shield_delta"):
		local_player.receive_kalkan_bagi_shield_delta(delta_amount)


## Host otoritesinde ortak takım EXP toplama
func host_collect_xp(amount: float) -> void:
	if not is_host:
		return
	var old_level: int = GameManager.team_level
	GameManager.add_team_xp(amount)
	# Seviye atlandıysa bekletmeden hemen sync gönder, aksi halde timer ile batchle
	if GameManager.team_level > old_level:
		_pending_xp_sync = false
		_xp_sync_timer = 0.0
		sync_team_xp.rpc(GameManager.team_xp, GameManager.team_xp_needed, GameManager.team_level)
	else:
		_pending_xp_sync = true


## Host'tan tüm istemcilere takım XP durumunu yayınlar
@rpc("any_peer", "call_remote", "reliable")
func sync_team_xp(current_xp: float, needed_xp: float, current_level: int) -> void:
	GameManager.set_team_xp_state(current_xp, needed_xp, current_level)


## DÜZELTME (kullanıcı isteği: "multiplayerda canların takım canı değil
## kişisel olmasını istiyorum") - eskiden TEK new_remaining tüm takıma
## uygulanıyordu. Artık HANGİ oyuncunun hakkının değiştiğini de taşıyor -
## bkz. GameManager.peer_revives. Her istemci kendi peer_revives kopyasını
## günceller ama revives_updated sinyalini (HUD'un dinlediği) SADECE
## KENDİ hakkı değiştiyse yayınlar - böylece herkes SADECE kendi kalan
## canını görür, başkasınınkini değil.
@rpc("any_peer", "call_local", "reliable")
func sync_revive_consumed(peer_id: int, new_remaining: int) -> void:
	GameManager.peer_revives[peer_id] = new_remaining
	if peer_id == multiplayer.get_unique_id():
		GameManager.revives_updated.emit(new_remaining)


## Dirilme hakkı yenilenme sayacı (bkz. GameManager._process_revive_regen) - host, bir oyuncunun hakkı 0'a düşüp
## 5 dakikalık sayaç başlayınca ve sonra periyodik olarak kalan süreyi yayınlar; istemciler kalbin altındaki geri
## sayımı buradan gösterir. seconds_left < 0: sayaç bitti/iptal.
@rpc("authority", "call_remote", "reliable")
func sync_revive_regen(peer_id: int, seconds_left: float) -> void:
	GameManager.apply_revive_regen_sync(peer_id, seconds_left)


## Kullanıcı isteği: "birini diriltince 3 saniye boyunca ölümsüzlük veren bir
## buff olmalı dirilten ve diriltilen kişide" - dirilen kişi kendi
## player.gd'sinde YEREL olarak _complete_revive()'da halledebiliyor, ama
## dirilten (rescuer) BAŞKA bir peer'in kendi Player'ı olabileceği için
## (bu istemcide sadece onun RemotePlayer kuklası var) buff'ı GERÇEKTEN
## uygulayabilecek olan sadece kendi istemcisi - bu RPC hedefli (rpc_id) o
## peer'e "kendi local player'ına dokunulmazlık ver" der.
signal local_player_granted_revive_invulnerability(duration: float)

@rpc("any_peer", "reliable")
func grant_revive_invulnerability(duration: float) -> void:
	local_player_granted_revive_invulnerability.emit(duration)


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu): eskiden her client
## kendi yerel GameManager.revives_remaining kopyasını OKUYUP azaltıp SONRA
## yayınlıyordu - iki oyuncu takımın son hakkını aynı ağ karesinde harcamaya
## çalışırsa (aynı anda ölmek/kanalı bitirmek gayet olağan bir co-op durumu)
## ikisi de "1 hak var" görüp ikisi de canlanabiliyordu. Artık TEK yetkili
## karar host'ta veriliyor: host kendi isteğini doğrudan, client'lar ise
## request_use_revive RPC'siyle host'a SORUP (aynı anda gelen istekler
## Godot'ta RPC'ler tek iş parçacığında sırayla işlendiği için birbirini
## ARTIK ezemiyor) yanıtı bekliyor - bkz. player.gd die()/_complete_revive()
## artık `await` ile çağırıyor.
var _pending_revive_responses: Dictionary = {} ## request_id (int) -> granted (bool)
var _revive_request_seq: int = 0

func try_use_revive() -> bool:
	if not is_multiplayer_active or is_host:
		return _consume_revive_authoritative(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0)

	_revive_request_seq += 1
	var request_id: int = _revive_request_seq
	request_use_revive.rpc_id(_host_peer_id(), request_id)

	var waited: float = 0.0
	while not _pending_revive_responses.has(request_id) and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	if _pending_revive_responses.has(request_id):
		var granted: bool = _pending_revive_responses[request_id]
		_pending_revive_responses.erase(request_id)
		return granted

	## Host'tan zamanında yanıt gelmedi (ör. tam bu sırada host değişti) -
	## sonsuza dek beklemek yerine eski (iyimser/yerel) davranışa düşülüyor.
	push_warning("[NetworkManager] Revive isteğine host'tan yanıt gelmedi, yerel yedek kullanıldı.")
	return _consume_revive_authoritative(multiplayer.get_unique_id())


## Gerçek azaltma/yayın burada, TEK yerde yapılır - host kendi isteği için
## doğrudan, request_use_revive üzerinden client istekleri için de bunu
## çağırır, tekli oyuncuda da (is_multiplayer_active false) aynı fonksiyon.
## DÜZELTME (kullanıcı isteği: "multiplayerda canların takım canı değil
## kişisel olmasını istiyorum herkesin 3 canı olacak") - artık HANGİ
## oyuncunun (peer_id) hakkının tüketileceği parametre olarak alınıyor,
## GameManager.peer_revives üzerinden HER OYUNCUYA AYRI tutuluyor. Tekli
## oyunculuda (is_multiplayer_active false) eski paylaşılan/tek revives_
## remaining alanı hâlâ kullanılıyor (zaten tek oyuncu olduğu için "kişisel"
## davranışıyla birebir aynı sonucu veriyor).
func _consume_revive_authoritative(peer_id: int) -> bool:
	if not is_multiplayer_active:
		if GameManager.revives_remaining <= 0:
			return false
		GameManager.revives_remaining -= 1
		GameManager.revives_updated.emit(GameManager.revives_remaining)
		return true
	var remaining: int = GameManager.get_peer_revives(peer_id)
	if remaining <= 0:
		return false
	remaining -= 1
	GameManager.peer_revives[peer_id] = remaining
	sync_revive_consumed.rpc(peer_id, remaining)
	return true


@rpc("any_peer", "reliable")
func request_use_revive(request_id: int) -> void:
	if not is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var granted: bool = _consume_revive_authoritative(sender_id)
	_respond_use_revive.rpc_id(sender_id, request_id, granted)


@rpc("any_peer", "reliable")
func _respond_use_revive(request_id: int, granted: bool) -> void:
	_pending_revive_responses[request_id] = granted



## BUG DÜZELTMESİ (kullanıcı bildirimi: "oyunda seçtiğin karakterde farklı
## bir karakter seçmişsin gibi gösteriyor sana ama diğer oyunculara normal
## gösteriyor") - kök neden: host'un peer id'si HER ZAMAN 1'dir (bkz.
## host_lan() - "_host_peer = 1", "lobby_players[1] = {...}"). Buradaki
## eski "my_id > 1" koşulu host'u BİLEREK dışarıda bırakıyordu - host
## lobide karakterini host_lan()'dan SONRA değiştirirse (ör. odayı açtıktan
## sonra fikrini değiştirip başka bir karakter kartına tıklarsa)
## lobby_players[1]["char_id"] hiç güncellenmiyor VE _rpc_update_character
## hiç yayınlanmıyordu - oyun başlayınca _rpc_start_game() hâlâ bu BAYAT
## (host_lan() anındaki İLK seçim) değeri lobby_players[my_id]["char_id"]'den
## okuyup GameManager.selected_char_id'ye atadığı için host'un KENDİ ekranı
## yanlış/eski karakteri gösteriyordu. Artık host da (my_id > 1 koşulu
## kaldırıldı) tıpkı diğer her peer gibi kendi sözlük girdisini günceller
## VE değişikliği yayınlar.
func update_local_character(char_id: int) -> void:
	local_char_id = char_id
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if lobby_players.has(my_id):
		lobby_players[my_id]["char_id"] = char_id
		lobby_updated.emit()
		_rpc_update_character.rpc(char_id)


@rpc("any_peer", "reliable")
func _rpc_update_character(char_id: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if lobby_players.has(sender_id):
		lobby_players[sender_id]["char_id"] = char_id
		lobby_updated.emit()


func start_multiplayer_game() -> void:
	if not is_host or not all_players_ready():
		return
	_rpc_start_game.rpc()


@rpc("any_peer", "call_local", "reliable")
func _rpc_start_game() -> void:
	## Sadece host (bkz. _host_peer_id / _refresh_host) oyunu başlatabilir.
	## sender_id == 0, çağrının call_local ile YEREL olarak tetiklendiği
	## anlamına gelir (host kendi RPC'sini böyle alır).
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != _host_peer_id():
		return

	## Normal, TÜM grubun birlikte başladığı akış - bkz. _is_rejoining_midgame
	## üstündeki DÜZELTME notu. Bir önceki oturumda geç katılıp bu bayrağı
	## true bırakmış olabilir; burada sıfırlanmazsa sıradaki NORMAL/toplu
	## başlangıçta da yanlışlıkla "diğerlerini bekleme" moduna düşerdi.
	_is_rejoining_midgame = false
	GameManager.reset()
	# Set local player selected character from our lobby info
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if lobby_players.has(my_id):
		GameManager.selected_char_id = lobby_players[my_id]["char_id"]
	else:
		GameManager.selected_char_id = local_char_id
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	GameManager.selected_character = def.get("skill", 1)

	## Yükleme ekranı senkronizasyonu - bkz. yukarıdaki _loading_done notu.
	## Burada temizlemek (sahne değişiminden hemen önce, TÜM peer'lerde bu
	## RPC'nin kendi işlendiği anda) yarış durumunu pratikte imkansız hale
	## getiriyor: bir peer "yüklemem bitti" RPC'sini ancak KENDİSİ bu satırı
	## (dolayısıyla temizliği) zaten geçtikten SONRA gönderebilir.
	_loading_done.clear()

	_is_game_in_progress = true
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


## Kullanıcı isteği: "oyundan çıkmış biri tekrar oda kodunu girerek hazır
## olma tuşuyla oyuna katılabilmeli" - true iken lobide "HAZIRIM"a basmak
## (bkz. set_local_ready) doğrudan bu oyuncuyu oyuna sokar, host'un tekrar
## "OYUNU BAŞLAT"a basmasını beklemez (host zaten o ekranı çoktan geçti).
var _is_game_in_progress: bool = false
## _rpc_join_in_progress_game() ile ekrana giren oyuncu için true olur -
## loading_screen.gd bunu "tek oyunculu gibi davran, diğerlerini bekleme"
## sinyali olarak okur, çünkü diğer herkes zaten oyunun içinde, hiçbiri o an
## yükleme ekranından geçmiyor (bkz. all_players_loading_done).
var _is_rejoining_midgame: bool = false


## Zaten oyunu (main.tscn) başlatmış bir odaya SONRADAN katılan bir oyuncu
## için - normal _rpc_start_game() ile AYNI karakter kurulumu ama TÜM
## peer'lerin yükleme barını beklemesi (bkz. _loading_done/all_players_
## loading_done) atlanır, çünkü diğer herkes zaten çoktan oyunda.
@rpc("any_peer", "reliable")
func _rpc_join_in_progress_game() -> void:
	GameManager.reset()
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if lobby_players.has(my_id):
		GameManager.selected_char_id = lobby_players[my_id]["char_id"]
	else:
		GameManager.selected_char_id = local_char_id
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	GameManager.selected_character = def.get("skill", 1)
	_is_rejoining_midgame = true
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


## Client tarafı: lobide (oyun zaten başlamışken) "HAZIRIM"a basınca çağrılır
## (bkz. set_local_ready). Host'a "beni de oyuna al" isteği gönderir.
@rpc("any_peer", "reliable")
func request_join_in_progress_game() -> void:
	if not is_host:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	_rpc_join_in_progress_game.rpc_id(sender_id)
	## enemy_spawner.gd bunu dinleyip hâlâ hayatta olan yaratıkları bu
	## SPESİFİK oyuncuya "yakalama" yayınıyla gönderir (bkz. sinyal üstündeki
	## DÜZELTME notu).
	peer_needs_game_catchup.emit(sender_id)


# =============================================================================
# MULTIPLAYER SENKRONİZASYON — Eksiklerin kapatılması
# =============================================================================

## Düşman mermi broadcast: host bir düşman mermi spawn ettiğinde client'lara
## görsel kopya gönderir (hasarsız). Client'lar böylece düşman ateşini görür.
@rpc("any_peer", "call_remote", "unreliable")
func broadcast_enemy_projectile(spawn_pos: Vector2, direction: Vector2, is_homing: bool, proj_tint: Color, enemy_net_id: int) -> void:
	var proj_scene: PackedScene = load("res://scenes/enemy_projectile.tscn") as PackedScene
	if not proj_scene:
		return
	var proj: Node2D = proj_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(proj)
	proj.global_position = spawn_pos
	if "direction" in proj:
		proj.direction = direction
	if "homing" in proj:
		proj.homing = is_homing
	if "tint" in proj:
		proj.tint = proj_tint
	# Görsel kopya — hasar vermez
	proj.set_meta("network_spawned", true)
	# Kaynak düşmanı bulup bağla (görsel amaçlı)
	if enemy_net_id > 0 and "source" in proj:
		var src: Node = find_enemy_by_net_id(enemy_net_id)
		if src:
			proj.source = src


## Client drop toplama isteği: client bir drop'un üzerine yürüdüğünde
## host'a "ben şu drop'u topladım" der. Host gerçek drop'u bulup işler.
@rpc("any_peer", "call_remote", "reliable")
func request_drop_pickup(drop_network_id: int, drop_type: String) -> void:
	## Kullanıcı bildirimi: "topladıkları şeyler kaybolmuyor, üstlerinde
	## birikiyor (exp, altın v.s) ve bu sadece diğer oyunculara görünüyor" -
	## kök neden: bu fonksiyon host'un ağacı DURAKLATILMIŞKEN (level-up
	## ekranı, duraklatma menüsü, dükkan/sandık menüsü) sessizce hiçbir şey
	## yapmadan geri dönüyordu. Toplayan client kendi görsel kopyasını ANINDA
	## ve koşulsuz sildiği için onun ekranı temiz kalıyor, ama host'un GERÇEK
	## drop'u (ve dolayısıyla diğer client'ların görsel kopyaları) hiç
	## silinmiyor, mıknatıslanmaya devam edip toplayanın üzerine sonsuza kadar
	## yığılıyordu. Toplama muhasebesinin (xp/altın toplamı, node silme)
	## fizik/duraklama durumuna bağımlı olmasına gerek yok - sadece host
	## kontrolü yeterli.
	if not is_host:
		return
	# Host kendi _visual_drops'unda gerçek drop'u arar (host da visual kopya tutar)
	# ama asıl drop enemy.gd tarafından spawn edilmiş gerçek drop'tur.
	# Host üzerinde gerçek drop'lar gruplara kayıtlıdır.
	var real_drop: Node = null
	match drop_type:
		"xp":
			for orb: Node in get_tree().get_nodes_in_group("xp_orbs"):
				if is_instance_valid(orb) and int(orb.get_meta("drop_network_id", -1)) == drop_network_id:
					real_drop = orb
					break
		"gold":
			for g: Node in get_tree().get_nodes_in_group("gold_drops"):
				if is_instance_valid(g) and int(g.get_meta("drop_network_id", -1)) == drop_network_id:
					real_drop = g
					break
		"food":
			for f: Node in get_tree().get_nodes_in_group("food_drops"):
				if is_instance_valid(f) and int(f.get_meta("drop_network_id", -1)) == drop_network_id:
					real_drop = f
					break
		"magnet":
			for m: Node in get_tree().get_nodes_in_group("magnet_drops"):
				if is_instance_valid(m) and int(m.get_meta("drop_network_id", -1)) == drop_network_id:
					real_drop = m
					break
		"chest":
			for c: Node in get_tree().get_nodes_in_group("chest_drops"):
				if is_instance_valid(c) and int(c.get_meta("drop_network_id", -1)) == drop_network_id:
					real_drop = c
					break
	
	if real_drop and is_instance_valid(real_drop):
		## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu): burada eskiden
		## "bu zaten alındı mı" diye bir işaret YOKTU. queue_free() deferred
		## olduğu için düğüm o an hâlâ grubun üyesi kalıyor - iki oyuncu aynı
		## yığına (özellikle aynı anda toplanan bir sandığa/altına) neredeyse
		## aynı anda basarsa, host'un aynı ağ karesinde işlediği iki
		## request_drop_pickup çağrısı da AYNI hâlâ-canlı düğümü bulup ödülü
		## İKİ KERE veriyordu. Artık herhangi bir ödül mantığı çalışmadan ÖNCE,
		## senkron olarak "alındı" işaretleniyor - ikinci istek burada durur.
		if real_drop.get_meta("claimed", false):
			return
		real_drop.set_meta("claimed", true)
		var sender_id: int = multiplayer.get_remote_sender_id()
		match drop_type:
			"food":
				# Yemek: host drop'u işler ve iyileşmeyi istek atan client'a senkronize eder
				## Yemek can yüzdesi yiyenin MAKSİMUM canına göre (bkz. food_drop.gd FOOD_TIER_HEAL_PERCENT): yiyen host'un kendisiyse
				## kendi max_health'i, uzak bir istemciyse host'taki kuklasının (state kanalından gelen) max_health'i.
				var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
				var eater_is_host: bool = sender_id == local_id or sender_id == 0
				var eater: Node = get_tree().get_first_node_in_group("player") if eater_is_host else _find_remote_player(sender_id)
				var eater_max: float = float(eater.max_health) if (eater != null and "max_health" in eater) else 100.0
				var heal_amount: float = real_drop.get_heal_amount(eater_max) if real_drop.has_method("get_heal_amount") else 0.16 * eater_max
				if eater_is_host:
					if eater and eater.has_method("heal"):
						eater.heal(heal_amount)
				else:
					sync_food_heal.rpc(heal_amount, sender_id) ## uzaktaki oyuncuya heal sync gönder
				real_drop.queue_free()
			"magnet":
				## #32 DÜZELTME (kullanıcı bildirimi: "Mıknatısla çekilen
				## objeler her zaman mıknatısı tutana gitmeli"): bu istek,
				## mıknatısı GERÇEKTEN toplayan client'ın (sender_id) kendi
				## görsel kopyasından geliyor - yani hedef oyuncu tam olarak
				## sender_id. Eskiden buradan sync_magnet_pickup.rpc() hedefsiz
				## (-1) çağrılıyordu, bu da her istemcide objelerin "an
				## itibarıyla en yakın oyuncu"ya gitmesine yol açıyordu.
				## AYRICA: "call_remote" modundaki bu RPC host'ta YEREL
				## ÇALIŞMAZ, bu yüzden host'un kendi GERÇEK (yetkili) xp/altın
				## objeleri hiç mıknatıslanmıyordu - şimdi host'ta da
				## doğrudan call_group ile tetikleniyor.
				get_tree().call_group("xp_orbs", "attract_to_player", sender_id)
				get_tree().call_group("gold_drops", "attract_to_player", sender_id)
				sync_magnet_pickup.rpc(sender_id)
				real_drop.queue_free()
			"chest":
				# Sandık: istek atan oyuncu için aç
				var sender_player: Node = _find_player_by_peer_id(sender_id)
				if sender_player and is_instance_valid(sender_player):
					if real_drop.has_method("_open_for_player"):
						real_drop._open_for_player(sender_player)
					elif real_drop.has_method("_on_body_entered"):
						real_drop._on_body_entered(sender_player)
			"xp":
				## Ortak EXP: Host doğrudan GameManager'ın ortak havuzuna ekler ve herkese yayınlar
				if "xp_value" in real_drop:
					## Tecrübe Kazanımı: toplayan oyuncunun bonusu (bkz. xp_orb.gd xp_gain_mult_for).
					var xp_local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
					var xp_collector: Node = get_tree().get_first_node_in_group("player") if (sender_id == xp_local_id or sender_id == 0) else _find_remote_player(sender_id)
					var xp_mult: float = real_drop.xp_gain_mult_for(xp_collector) if real_drop.has_method("xp_gain_mult_for") else 1.0
					host_collect_xp(real_drop.xp_value * xp_mult)
				real_drop.queue_free()
			_:
				# Gold: host tarafında normal toplama işle
				if real_drop.has_method("_on_body_entered"):
					var sender_player: Node = _find_player_by_peer_id(sender_id)
					if sender_player and is_instance_valid(sender_player):
						real_drop._on_body_entered(sender_player)
				elif real_drop.has_method("_collect"):
					real_drop._collect()
	# Görsel kopyayı tüm client'larda temizle (batch ile)
	queue_remove_drop(drop_network_id)


## Yemek iyileştirmesi senkronizasyonu: bir oyuncu yemek topladığında
## iyileşme miktarı tüm peer'lere iletilir.
@rpc("any_peer", "call_remote", "reliable")
func sync_food_heal(heal_amount: float, target_peer_id: int) -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if local_id != target_peer_id:
		return
	var local_player: Node = get_tree().get_first_node_in_group("player")
	if local_player and local_player.has_method("heal"):
		local_player.heal(heal_amount)


## Mıknatıs senkronizasyonu: bir oyuncu mıknatıs topladığında
## tüm client'larda mıknatıs efekti tetiklenir.
## #32 DÜZELTME: artık hangi oyuncunun mıknatısı gerçekten aldığı
## (target_peer_id) da iletiliyor - xp_orb.gd/gold_drop.gd bu id ile
## objelerin HER ZAMAN o SPESİFİK oyuncuya gitmesini sağlıyor, eskisi gibi
## "an itibarıyla en yakın oyuncu"ya değil (bkz. attract_to_player).
@rpc("any_peer", "call_remote", "reliable")
func sync_magnet_pickup(target_peer_id: int = -1) -> void:
	get_tree().call_group("xp_orbs", "attract_to_player", target_peer_id)
	get_tree().call_group("gold_drops", "attract_to_player", target_peer_id)


## Oakley'nin Çiçek yeteneği (bkz. player.gd _try_oakley_flower/scripts/
## oakley_flower.gd) - her istemci çiçeği KENDİ bağımsız kopyası olarak
## oluşturduğu için (bkz. oakley_flower.gd dosya başı notu), biri alınca
## diğer istemcilerdeki kopyaların da kaldırılması gerekiyor. flower_id ile
## "oakley_flowers" grubunda eşleşen TEK kopya kaldırılıyor - network_id
## tabanlı remove_drop/remove_drops_batch ile AYNI desen, sadece anahtar
## sözlük değil grup+String kimlik.
@rpc("any_peer", "call_remote", "reliable")
func broadcast_flower_picked(flower_id: String) -> void:
	for f: Node in get_tree().get_nodes_in_group("oakley_flowers"):
		if is_instance_valid(f) and str(f.get("flower_id")) == flower_id:
			if f.has_method("remove_remotely"):
				f.call("remove_remotely")
			break


## Sandık açma isteği: client bir sandığa yaklaştığında host'a bildirir.
## Host sandığı açar ve itemleri ilgili oyuncuya verir.
@rpc("any_peer", "call_remote", "reliable")
func request_chest_open(drop_network_id: int, player_peer_id: int) -> void:
	if not is_host or get_tree().paused:
		return
	var real_chest: Node = null
	for c: Node in get_tree().get_nodes_in_group("chest_drops"):
		if is_instance_valid(c) and int(c.get_meta("drop_network_id", -1)) == drop_network_id:
			real_chest = c
			break
	if not real_chest or not is_instance_valid(real_chest):
		return
	## bkz. request_drop_pickup üstündeki aynı "claimed" DÜZELTME notu -
	## burada da aynı çift-ödül yarışı mümkündü.
	if real_chest.get_meta("claimed", false):
		return
	real_chest.set_meta("claimed", true)

	var player: Node = _find_player_by_peer_id(player_peer_id)
	if not player or not is_instance_valid(player):
		return
	
	# Sandığı host tarafında aç
	if real_chest.has_method("_open_for_player"):
		real_chest._open_for_player(player)
	# Görsel kopyayı temizle
	remove_drop.rpc(drop_network_id)


## Peer ID'ye göre oyuncu node'unu bulur.
func _find_player_by_peer_id(peer_id: int) -> Node:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	if peer_id == local_id or peer_id == 0:
		return get_tree().get_first_node_in_group("player")
	# Remote player ara
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_get_remote_player"):
		return main_node._get_remote_player(peer_id)
	for child: Node in get_tree().current_scene.get_children():
		if child is RemotePlayer and child.peer_id == peer_id:
			return child
	return null
