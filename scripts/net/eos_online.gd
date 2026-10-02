extends Node

## EosOnline (autoload): Epic Online Services üzerinden İNTERNET odası (kullanıcı isteği 2026-10-02: "hem androidden hem
## pcden crossplay sağlanması radmin olmadan").
##
## Ne yapar: Epic'e oyuncu hesabı GEREKTİRMEYEN anonim (cihaz kimliği) girişi, Epic "lobi" servisinde oda ilanı açma/arama.
## Asıl oyun trafiği Epic P2P'den (NAT delme, gerekirse Epic relay) geçer - port açmak / Radmin GEREKMEZ. Bağlantının
## kendisi network_manager.gd host_online/join_online'da; bu dosya sadece Epic tarafını (platform, giriş, ilan) yönetir.
## Oda ilanı yalnızca bir "vitrin": katılımcılar Epic lobisine üye olmaz, host'un Epic kullanıcı kimliğiyle doğrudan
## P2P bağlanır (EOSGMultiplayerPeer.create_client). Oyuncu sayısı ilana host tarafından yazılır.
##
## Kimlik bilgileri: res://eos_credentials.cfg (git'e GİRMEZ - repo herkese açık; örnek: eos_credentials.example.cfg).
## Dosya yoksa/eksikse internet seçeneği kapalı kalır, LAN eskisi gibi çalışır.

signal lobbies_updated(lobbies: Array)

const CREDENTIALS_PATH := "res://eos_credentials.cfg"
const REQUIRED_KEYS := ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]
## P2P soket adı (host ve katılımcı aynı adı kullanmalı) ve oda ilanlarının "kovası" (sadece bu oyunun odaları aranır).
const SOCKET_ID := "INSAGAME" ## sadece harf/rakam (EOSG alt çizgiyi reddediyor)
const BUCKET_ID := "insa:v1"
const ATTR_HOST_NAME := "HOSTNAME"
const ATTR_PLAYERS := "PLAYERS"
const ATTR_MAX := "MAXPLAYERS"
const ATTR_IN_GAME := "INGAME"

var _platform_ready: bool = false
var _setup_running: bool = false
signal _setup_finished

var _lobby: HLobby = null
var _lobby_dirty: bool = false
var _lobby_updating: bool = false
var _pending_players: int = 1
var _pending_in_game: bool = false
var _searching: bool = false


func _ready() -> void:
	HLog.log_level = HLog.LogLevel.WARN


## Kimlik dosyası var ve zorunlu alanlar dolu mu? (Değilse lobi ekranı internet seçeneğini kapalı gösterir.)
func is_configured() -> bool:
	return _load_credentials() != null


func _load_credentials() -> HCredentials:
	var cfg := ConfigFile.new()
	if cfg.load(CREDENTIALS_PATH) != OK:
		return null
	for k in REQUIRED_KEYS:
		if str(cfg.get_value("eos", k, "")).strip_edges().is_empty():
			return null
	var c := HCredentials.new()
	c.product_name = str(cfg.get_value("eos", "product_name", "I need to stay alive"))
	c.product_version = str(cfg.get_value("eos", "product_version", "1.0"))
	c.product_id = str(cfg.get_value("eos", "product_id", "")).strip_edges()
	c.sandbox_id = str(cfg.get_value("eos", "sandbox_id", "")).strip_edges()
	c.deployment_id = str(cfg.get_value("eos", "deployment_id", "")).strip_edges()
	c.client_id = str(cfg.get_value("eos", "client_id", "")).strip_edges()
	c.client_secret = str(cfg.get_value("eos", "client_secret", "")).strip_edges()
	c.encryption_key = str(cfg.get_value("eos", "encryption_key", "")).strip_edges()
	return c


func local_user_id() -> String:
	return HAuth.product_user_id


## Platformu kurar ve anonim giriş yapar (ikisi de oturum başına BİR kez). Başarıda "" döner, yoksa oyuncuya
## gösterilecek hata metni.
func ensure_ready_async(display_name: String) -> String:
	var creds := _load_credentials()
	if creds == null:
		return "Epic ayarları eksik (eos_credentials.cfg)."
	if _setup_running:
		await _setup_finished
	if not _platform_ready:
		_setup_running = true
		## Epic arayüz katmanı (overlay) oyunun Vulkan çizimine karışmasın - kullanılmıyor.
		HPlatform.flags = EOS.Platform.PlatformFlags.DisableOverlay | EOS.Platform.PlatformFlags.DisableSocialOverlay
		_platform_ready = await HPlatform.setup_eos_async(creds)
		_setup_running = false
		_setup_finished.emit()
		if not _platform_ready:
			return "Epic başlatılamadı (kimlik bilgilerini kontrol et)."
		## Oyunun büyük RPC patlamaları Epic'in varsayılan gönderme kuyruğuna sığmayabilir - sınırsız kuyruk
		## (0 = EOS_P2P_MAX_QUEUE_SIZE_UNLIMITED; eklentide sabiti yok).
		HP2P.set_packet_queue_size(0, 0)
	if HAuth.product_user_id.is_empty():
		var shown: String = display_name.strip_edges().left(32)
		if shown.is_empty():
			shown = "Oyuncu"
		var ok: bool = await HAuth.login_anonymous_async(shown)
		if not ok or HAuth.product_user_id.is_empty():
			return "Epic girişi başarısız (internet bağlantısını kontrol et)."
	return ""


## ------------------------------------------------------------------ oda ilanı (host)
func host_lobby_async(host_name: String, max_players: int) -> bool:
	await close_lobby_async()
	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = BUCKET_ID
	opts.max_lobby_members = max_players
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.presence_enabled = false
	opts.disable_host_migration = true
	opts.enable_rtc_room = false
	opts.allow_invites = false
	opts.local_user_id = HAuth.product_user_id
	var lobby: HLobby = await HLobbies.create_lobby_async(opts)
	if lobby == null:
		return false
	_lobby = lobby
	_lobby.add_attribute(ATTR_HOST_NAME, host_name)
	_lobby.add_attribute(ATTR_PLAYERS, 1)
	_lobby.add_attribute(ATTR_MAX, max_players)
	_lobby.add_attribute(ATTR_IN_GAME, false)
	await _lobby.update_async()
	return true


func is_hosting_lobby() -> bool:
	return _lobby != null


## Host'ta oyuncu sayısı / oyun başladı bilgisini ilana yazar. Sık çağrılabilir: güncellemeler sıraya alınıp tek tek gider.
func set_lobby_state(players: int, in_game: bool) -> void:
	if _lobby == null:
		return
	_pending_players = players
	_pending_in_game = in_game
	_lobby_dirty = true
	if not _lobby_updating:
		_flush_lobby_state()


func _flush_lobby_state() -> void:
	_lobby_updating = true
	while _lobby_dirty and _lobby != null:
		_lobby_dirty = false
		_lobby.add_attribute(ATTR_PLAYERS, _pending_players)
		_lobby.add_attribute(ATTR_IN_GAME, _pending_in_game)
		await _lobby.update_async()
	_lobby_updating = false


func close_lobby_async() -> void:
	if _lobby == null:
		return
	var lobby: HLobby = _lobby
	_lobby = null
	## Süren bir ilan güncellemesi (set_lobby_state) bitmeden yok etmek Epic'te "UnexpectedError" veriyordu.
	while _lobby_updating:
		await get_tree().process_frame
	if lobby.is_owner():
		await lobby.destroy_async()
	else:
		await lobby.leave_async()


## ------------------------------------------------------------------ oda arama (katılımcı)
## Sonuç: [{lobby_id, host_id, host_name, players, max_players, in_game}] - kendi ilanımız hariç. lobbies_updated da yayınlanır.
func search_lobbies_async(display_name: String) -> Array:
	if _searching:
		return []
	_searching = true
	var out: Array = []
	var err: String = await ensure_ready_async(display_name)
	if err.is_empty():
		var found = await HLobbies.search_by_bucket_id_async(BUCKET_ID)
		if found != null:
			for l in found:
				var lobby: HLobby = l
				if lobby.owner_product_user_id.is_empty() or lobby.owner_product_user_id == HAuth.product_user_id:
					continue
				out.append({
					"lobby_id": lobby.lobby_id,
					"host_id": lobby.owner_product_user_id,
					"host_name": str(_attr(lobby, ATTR_HOST_NAME, "Oyuncu")),
					"players": int(_attr(lobby, ATTR_PLAYERS, 1)),
					"max_players": int(_attr(lobby, ATTR_MAX, lobby.max_members)),
					"in_game": bool(_attr(lobby, ATTR_IN_GAME, false)),
				})
	_searching = false
	lobbies_updated.emit(out)
	return out


func _attr(lobby: HLobby, key: String, fallback: Variant) -> Variant:
	var a: Dictionary = lobby.get_attribute(key)
	return a.get("value", fallback) if not a.is_empty() else fallback


func _exit_tree() -> void:
	## Oyun kapanırken ilanı kaldırmayı dene (bekleyemeyiz; Epic, sahibi düşen ilanı kendisi de bir süre sonra siler).
	if _lobby != null and _lobby.is_owner():
		var opts := EOS.Lobby.DestroyLobbyOptions.new()
		opts.lobby_id = _lobby.lobby_id
		EOS.Lobby.LobbyInterface.destroy_lobby(opts)
	_lobby = null
	## Epic platformunu kapat: kapatılmazsa SDK'nın arka plan iş parçacıkları süreci açık tutuyordu (gerçek Epic testinde
	## oyun quit() sonrası kapanmadı, 2026-10-02). EOSG eklentisi bunu kendisi yapmıyor.
	if _platform_ready:
		_platform_ready = false
		EOS.Platform.PlatformInterface.release()
		EOS.Platform.PlatformInterface.shutdown()
