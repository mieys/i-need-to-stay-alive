extends Node2D

const LevelUpScreenScene = preload("res://scenes/level_up_screen.tscn")
const PauseMenuScene = preload("res://scenes/pause_menu.tscn")
const RemotePlayerScene = preload("res://scenes/remote_player.tscn")
const ChestMenuScene = preload("res://scenes/chest_menu.tscn")
## Kullanıcı isteği: "kimsenin başlangıç silahı/kalkanı yok, oyuna başlayınca
## 3 silah kartından 1 seçilecek, sonra 2 kalkan kartından 1 seçilecek" - bkz.
## weapon_select_screen.gd (level_up_screen.gd'nin kart/animasyon/çok
## oyunculu bekleme desenini yeniden kullanan yeni, ayrı bir ekran).
## DÜZELTME (kullanıcı isteği: "level aralarında gelen silah seçimlerini
## kaldır, sadece ilk levelde silah ve kalkan seçim ekranı olacak") - eskiden
## bu ekran 5/10/15/20. levellerde (bkz. kaldırılan WEAPON_MILESTONE_LEVELS/
## _advance_level_up_queue'daki kilometre taşı bloğu) de tekrar açılıyordu;
## artık SADECE _start_initial_loadout_selection()'dan (oyunun en başında)
## çağrılıyor.
const WeaponSelectScreenScript = preload("res://scripts/weapon_select_screen.gd")

## bkz. _on_merchant_spawned/_on_merchant_departed - minimap'teki küçük "$"
## noktası (bkz. minimap.gd set_merchant_marker) yeterince fark edilmiyordu,
## kullanıcı isteği: "varolduğu sürece konumu ok ile gösterilmeli."
const MerchantArrowScript := preload("res://scripts/merchant_arrow.gd")
var _merchant_arrow: Control = null

## Kullanıcı isteği: LoL tarzı görüş alanı / savaş sisi - bkz. vision_fog.gd.
## Sahneye (main.tscn) elle eklenmiyor, kodla kuruluyor: Godot editörü main.tscn'i
## açık tutarken dışarıdan yapılan .tscn düzenlemeleri editörün "Kaydet"i ile
## sessizce ezilebiliyor (bkz. CLAUDE.md).
const VisionFogScript := preload("res://scripts/vision_fog.gd")

## Haritaya "gökyüzündeki bulutlar yer yer gölge düşürmüş" görünümü veren
## materyal. TEK bir paylaşılan kaynak (.tres) olarak tutuluyor - böylece
## koyuluk/leke boyutu gibi ayarlar tek bir dosyadan (editörde de canlı)
## değiştirilebiliyor ve TÜM katmanlar birebir aynı deseni paylaşıyor.
const CloudShadowMaterial := preload("res://shaders/cloud_shadows_material.tres")

## Haritanın kök node'u. Harita (Harita.tmx) main.tscn'e instance edilmiş bir
## alt sahne olduğu için içindeki node'lara .tscn içinden özellik override'ı
## YAZILAMIYOR (Godot editörü instance edilmiş alt sahnenin iç node'larına
## yapılan elle override'ları kaydederken düşürüyor). Bu yüzden materyal
## çalışma zamanında burada atanıyor.
const MAP_ROOT_PATH := "Harita"

## ÖNEMLİ: TileMapLayer haritayı "rendering quadrant"lara böler ve HER
## quadrant AYRI bir CanvasItem olarak çizilir. Shader dünya konumunu
## MODEL_MATRIX üzerinden hesapladığı için, varsayılan quadrant boyutunda
## (16 tile x 32px = 512px) bulut deseni her 512 pikselde bir sıfırlanıp
## gözle görülür DİKDÖRTGEN DİKİŞLER oluşturuyordu. Quadrant'ı haritanın
## tamamını kapsayacak kadar büyütmek tüm katmanı tek bir CanvasItem yapar
## ve desen kesintisiz akar.
## NOT: Godot dokümanına göre bu ayar Y-sort AÇIK olan katmanlarda etkisizdir
## (o katmanlarda tiller Y konumuna göre gruplanır) - bu yüzden aşağıda
## y_sort_enabled olan katmanlarda quadrant ayarı denenmiyor.
const MAP_QUADRANT_SIZE := 512

## Kullanıcı isteği: "'zemin çimen' katmanına doğal görünümlü bir shader
## ekle" - birkaç kez farklı tekniklerle denendi (yumuşak noise, sonra
## sert kenarlı/tile-ızgaralı hücresel desen), her defasında "hala kocaman/
## doğal durmuyor" bildirimiyle karşılaştı, sonunda kullanıcı fikrini
## değiştirip TAMAMEN kaldırılmasını istedi ("fikrimi değiştirdim sil
## shaderı"). Shader dosyası (cozy_ground.gdshader) silindi, "Zemin Çimen"
## katmanı artık hiçbir materyal almıyor - düz/orijinal haliyle kalıyor.
## TEKRAR EKLEMEDEN ÖNCE kullanıcıyla konuşulmalı.

@onready var player = $Player
@onready var hud = $HUD

var pause_menu_instance: Node = null
var _sync_timer: float = 0.0
const SYNC_INTERVAL := 0.05
var _remote_players: Dictionary = {}

## DÜZELTME (kullanıcı bildirimi: "ölüm ekranı yok ölünce hiçbir gösterge
## v.s yok"): bkz. _show_death_overlay/_on_player_died üstündeki notlar.
var _death_overlay_layer: CanvasLayer = null
var _death_overlay_label: Label = null
## Oyun sonu istatistik ekranı: peer_id (int) -> {"name": String, "dealt":
## float, "taken": float} - bkz. NetworkManager.match_stats_received/
## _on_match_stats_received, _show_death_overlay.
var _match_stats_by_peer: Dictionary = {}

## #54 (kullanıcı isteği: "Ölüm ekranında seçilebilir müttefik takip
## kamerası") - takım hâlâ hayattayken ("İzleyicisin" durumu) ölen oyuncu
## artık ok tuşlarıyla (bkz. _show_death_overlay'deki "SpectateRow") hayatta
## kalan müttefikler arasında geçiş yapıp kamerayı o an seçili olana takip
## ettirebiliyor - bkz. _begin_spectate_mode/_advance_spectate_target/_process.
var _spectate_active: bool = false
var _spectate_camera: Camera2D = null
var _spectate_target: Node = null
var _spectate_index: int = -1
const SPECTATE_CAMERA_FOLLOW_SPEED := 900.0

## Kullanıcı bildirimi: "bağlantım yaratıkların/silahların animasyonlarını
## bile veri olarak gönderiyor, halbuki bunlar oyunun kodlarıyla otomatik
## çalışmalı" - haklıydı: eskiden can/kalkan/silah envanteri/durum efektleri
## (nadiren değişen "durum" verisi) pozisyonla (her karede değişen "transform"
## verisi) AYNI pakette, saniyede 20 kez, DEĞİŞMESE BİLE gönderiliyordu. Artık
## ikisi ayrıldı: _rpc_update_player_transform (unreliable, her tick) SADECE
## gerçekten sürekli değişen şeyleri taşır; durum verisi _rpc_update_player_
## extra_state (reliable) ile SADECE değiştiğinde gönderilir - tam olarak
## diğer multiplayer oyunların yaptığı gibi (transform=stream, state=event).
## _last_sent_extra_state son gönderilen durumu tutar, karşılaştırma için.
var _last_sent_extra_state: Dictionary = {}
## Değişmese bile arada bir (aşağıdaki EXTRA_STATE_HEARTBEAT_TICKS'te bir)
## yeniden gönderiyoruz - böylece SONRADAN bağlanan/yeniden bağlanan bir
## oyuncu, tam o an hiçbir şey değişmese bile birkaç saniye içinde doğru
## durumu görür (güvenilir bir "keyframe" - salt delta'ya güvenmek, kaçırılan
## bir bağlantı anında kalıcı yanlış görünüme yol açabilirdi).
var _extra_state_tick: int = 0
const EXTRA_STATE_HEARTBEAT_TICKS := 40 ## 40 * 0.05sn = ~2 saniyede bir


func _ready() -> void:
	player.health_changed.connect(hud.update_health)
	GameManager.team_xp_changed.connect(hud.update_xp)
	GameManager.team_xp_changed.connect(_on_team_xp_changed_for_level_up_delay)
	GameManager.team_leveled_up.connect(_on_team_leveled_up)
	player.stats_changed.connect(_update_stats_display)
	player.died.connect(_on_player_died)
	NetworkManager.server_disconnected.connect(_on_multiplayer_server_disconnected)
	## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini
	## beklemeden tüm kartlarını seçebilsin... hepsi ortak bir bekleme
	## süresine bağlı olacak") - level_up_pending_peers/multiplayer_level_up_
	## all_chosen tabanlı ESKİ "her turda kilitlen" mekanizması, chest_busy_
	## peers ile AYNI desene (bkz. network_manager.gd "KART/SİLAH/KALKAN SEÇİM
	## KUYRUĞU SENKRONİZASYONU" notu) taşındı.
	NetworkManager.level_up_busy_state_changed.connect(_on_level_up_busy_state_changed)
	NetworkManager.multiplayer_level_up_timer_tick.connect(_on_level_up_countdown_tick)
	NetworkManager.merchant_spawned.connect(_on_merchant_spawned)
	NetworkManager.merchant_departed.connect(_on_merchant_departed)
	_merchant_arrow = Control.new()
	_merchant_arrow.name = "MerchantArrow"
	_merchant_arrow.set_script(MerchantArrowScript)
	var merchant_arrow_layer := CanvasLayer.new()
	merchant_arrow_layer.name = "MerchantArrowLayer"
	merchant_arrow_layer.layer = 40
	add_child(merchant_arrow_layer)
	merchant_arrow_layer.add_child(_merchant_arrow)
	## #58 DÜZELTME (kullanıcı bildirimi: "sandık açılımı esnasında oyun diğer
	## oyuncularda devam ediyor gibi görünüyor, kart bekleme ekranının aktif
	## kalması gerekiyor o esnada") - bkz. _on_chest_busy_state_changed().
	NetworkManager.chest_busy_state_changed.connect(_on_chest_busy_state_changed)
	## Kullanıcı bildirimi: "bazen hostta açılıp diğer oyunlarda açılmıyor" -
	## periyodik dükkanın açılıp açılmayacağı kararı artık HOST'tan geliyor
	## (bkz. network_manager.gd "MİNİ DÜKKAN KARARI" bloğu).
	NetworkManager.mini_shop_decision_received.connect(_on_mini_shop_decision_received)
	## Kullanıcı isteği: "sandık seçerken diğer oyuncularda da 25 saniyelik
	## bekleme süresi olmalı" - bekleme overlay'indeki geri sayım etiketini
	## günceller (bkz. _show_chest_wait_overlay/_on_chest_countdown_tick).
	NetworkManager.chest_countdown_tick.connect(_on_chest_countdown_tick)
	## Kullanıcı isteği: "host oyunu yeniden başlatabilsin fakat önce diğer
	## oyunculara onayı sorulsun" - bkz. network_manager.gd "YENİDEN BAŞLATMA
	## ONAYI" bloğu. İlki (client) gelen isteğe Onayla/Reddet diyaloğu
	## gösterir, ikincisi (herkes) oylama sonucunu bildirir.
	NetworkManager.restart_request_received.connect(_on_restart_request_received)
	NetworkManager.restart_vote_result.connect(_on_restart_vote_result)
	NetworkManager.host_left_game.connect(_on_host_left_game)
	NetworkManager.player_left_game.connect(_on_player_left_game)
	## DÜZELTME (kullanıcı bildirimi: "ölüm ekranı yok"): bkz. network_manager.gd
	## sync_game_over/game_over_synced - takım arkadaşları bizden ÖNCE ölüp
	## "izleyicisin" yazısını görmeye başlamış olabilir, son kişi de ölünce
	## bu sinyal onlara "OYUN BİTTİ"ye geçmeleri gerektiğini bildirir.
	NetworkManager.game_over_synced.connect(_on_game_over_synced)
	## Kullanıcı isteği: "birini diriltince ... dirilten kişide de" 3sn
	## dokunulmazlık - bkz. network_manager.gd grant_revive_invulnerability.
	NetworkManager.local_player_granted_revive_invulnerability.connect(_on_revive_invulnerability_granted)
	NetworkManager.match_stats_received.connect(_on_match_stats_received)
	## Chat (bkz. scripts/network_manager.gd chat_message_received notu) -
	## gelen her mesajı HUD'un sol chat penceresine ekler VE doğru karakterin
	## (gönderen kendisiyse yerel player, değilse eşleşen RemotePlayer)
	## üstünde mini balonu tetikler.
	NetworkManager.chat_message_received.connect(_on_chat_message_received)
	_update_stats_display()
	hud.update_level(GameManager.team_level)
	hud.update_xp(GameManager.team_xp, GameManager.team_xp_needed)
	
	if NetworkManager.is_multiplayer_active:
		_setup_multiplayer_players()

	## Görüş alanı sisi: dünyanın üstünde, HUD'un ALTINDA. VignetteOverlay ve HUD
	## aynı CanvasLayer katmanında (1) olduğu için çizim sırasını ağaç sırası
	## belirliyor - bu yüzden sisi HUD'dan hemen ÖNCEYE taşıyoruz, yoksa
	## add_child() onu en sona koyar ve HUD'un ÜSTÜNE çizerdi (arayüz kararırdı).
	var vision_fog: CanvasLayer = VisionFogScript.new()
	vision_fog.name = "VisionFog"
	add_child(vision_fog)
	move_child(vision_fog, hud.get_index())

	# Add loopable breezy cozy forest ambient sound
	var ambient: Node = preload("res://scripts/wind_breeze_ambient.gd").new()
	ambient.name = "WindBreezeAmbient"
	add_child(ambient)
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "oyunumu başlatınca bi ses bugda
	## kalıyor arkada sürekli çalıyor") - kök neden: oyun artık doğrudan evin
	## İÇİNDE başlıyor (bkz. house_interior.gd _ready() -> _do_enter_house(),
	## Main'in bir ÇOCUĞU olduğu için Main._ready()'den - yani BURADAN - ÖNCE
	## çalışır ve _set_outdoor_atmosphere_enabled(false) çağırır) ama o anda
	## bu WindBreezeAmbient düğümü HENÜZ VAR OLMADIĞI için o çağrı hiçbir şey
	## bulamayıp sessizce hiçbir iş yapmıyordu - ses yukarıdaki add_child()
	## satırıyla (kendi _ready()'sinde play() çağırıyor) SESLİ başlıyordu.
	## house_interior.gd'nin _process()'teki "referans geç bulunursa tekrar
	## dene" güvenlik ağı bunu normalde bir sonraki karede düzeltirdi, ama oyun
	## silah/kalkan seçim ekranlarıyla (bkz. _start_initial_loadout_selection,
	## get_tree().paused = true) BAŞLADIĞI için HouseInterior._process()
	## (PROCESS_MODE_ALWAYS değil) o seçim ekranları kapanana kadar hiç
	## ÇALIŞMIYORDU - ses tüm o süre boyunca (silah+kalkan seçimi) sessizce
	## çalmaya devam ediyordu. Artık burada, düğüm oluşturulur oluşturulmaz,
	## player.is_indoors (HouseInterior._ready() tarafından bizden ÖNCE zaten
	## doğru ayarlanmış) kontrol edilip gerekirse ANINDA (hiç duyulmadan)
	## duraklatılıyor.
	if is_instance_valid(player) and bool(player.get("is_indoors")):
		ambient.stream_paused = true
	# _apply_cloud_shadows()
	## Kullanıcı isteği: "'zemin çimen' katmanına doğal görünümlü bir shader
	## ekle" - birkaç farklı teknikle denendi, sonunda kullanıcı "fikrimi
	## değiştirdim, sil shaderı" dedi. Tamamen kaldırıldı (bkz. dosya başı
	## notu) - "Zemin Çimen" katmanı artık materyal almıyor.

	## Kullanıcı isteği: kimsenin artık başlangıç silahı/kalkanı yok (bkz.
	## player.gd - _grant_starting_weapon() çağrısı kaldırıldı, game_manager.gd
	## - shield_standart_level artık 0'dan başlıyor). GameManager.owned_weapons
	## boşsa bu YENİ bir koşu demektir - oyuncuyu ilk silah/kalkan seçim
	## ekranlarından geçirip öyle başlatıyoruz.
	## Kullanıcı isteği: "silah seçme kartının oyun başladıktan 2 saniye
	## sonra gelmesini istiyorum" - oyuncu ilk 2 saniye haritayı/karakterini
	## görsün diye ekran hemen değil, kısa bir gecikmeyle açılıyor (oyun bu
	## sırada duraklamıyor, bkz. _start_initial_loadout_selection).
	if GameManager.owned_weapons.is_empty():
		get_tree().create_timer(2.0).timeout.connect(_start_initial_loadout_selection)


## Bulut gölgesini haritanın TÜM tile katmanlarına uygular.
##
## Neden hepsine: efekt yalnızca çimene uygulandığında toprak/su/ağaç gibi
## diğer katmanlar aydınlık kalıyor, gölgeler onların üzerinde "kesiliyor" ve
## doğallık bozuluyordu (kullanıcı bildirimi: "bazı katmanlar doğallığını
## bozmuş"). Gerçek bir bulut gölgesi zeminin tamamına, üzerindeki her şeye
## birlikte düşer.
##
## Tüm katmanlar AYNI materyal örneğini paylaşır - desen dünya koordinatına
## bağlı olduğu için katmanlar arasında birebir hizalanır, ayrıca tek bir
## materyal olduğundan ayar değiştirmek hepsini birden etkiler.
func _apply_cloud_shadows() -> void:
	var map_root: Node = get_node_or_null(MAP_ROOT_PATH)
	if map_root == null:
		push_warning("Bulut gölgesi uygulanamadı: '%s' bulunamadı." % MAP_ROOT_PATH)
		return
	var applied: int = _apply_cloud_shadows_recursive(map_root)
	if applied == 0:
		push_warning("Bulut gölgesi uygulanacak TileMapLayer bulunamadı.")


## map_root altındaki (iç içe gruplar dahil) her TileMapLayer'a materyali
## atar; kaç katmana uygulandığını döndürür.
func _apply_cloud_shadows_recursive(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is TileMapLayer:
			var layer: TileMapLayer = child
			layer.material = CloudShadowMaterial
			## Dikişleri önlemek için - bkz. MAP_QUADRANT_SIZE yorumu.
			## Y-sort açık katmanlarda bu ayarın etkisi yok, boşuna culling
			## kaybetmemek için orada dokunulmuyor.
			if not layer.y_sort_enabled:
				layer.rendering_quadrant_size = MAP_QUADRANT_SIZE
			count += 1
		count += _apply_cloud_shadows_recursive(child)
	return count


func _process(delta: float) -> void:
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - shop_panel.gd/
	## merchant_shop_screen.gd gibi BİLEREK get_tree().paused kullanmayan
	## ekranlar açıkken bu genel ui_cancel kontrolü hâlâ çalışıp pause
	## menüsünü ÜSTLERİNE açardı (o ekranlar artık kendi ui_cancel'larını
	## kendileri işliyor, bkz. GameManager "ENGELLEYİCİ PANEL KAYDI" notu).
	if Input.is_action_just_pressed("ui_cancel") and not GameManager.is_game_over \
			and not GameManager.is_any_blocking_panel_open():
		_toggle_pause()
	
	if NetworkManager.is_multiplayer_active and is_instance_valid(player):
		_process_multiplayer_sync(delta)
	## #54: izleyici kamerasının seçili müttefiği takip etmesi - player node'u
	## bu noktada zaten queue_free() edilmiş/geçersiz olabilir (bkz. player.gd
	## die()), bu yüzden yukarıdaki "is_instance_valid(player)" şartından
	## BAĞIMSIZ, ayrı bir blok.
	if _spectate_active:
		_process_spectate_camera(delta)
	## NOT: level atlama geri sayımı artık BURADA tikletilmiyor - bu fonksiyon
	## Main node'unun (varsayılan process_mode = PAUSABLE) _process'i, tam da
	## geri sayımın çalışması GEREKEN anda (level atlanıp get_tree().paused =
	## true olduğunda) TAMAMEN DURUYORDU. Artık NetworkManager'ın kendi
	## PROCESS_MODE_ALWAYS _process'inde tikleniyor (bkz. network_manager.gd)
	## - kullanıcı bildirimi: "geri sayım paneli açılıyor ama geriye
	## saymıyor" tam olarak buydu.



func _setup_multiplayer_players() -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	for pid in NetworkManager.lobby_players.keys():
		if pid == my_id:
			continue
		var pinfo: Dictionary = NetworkManager.lobby_players[pid]
		_spawn_remote_player(pid, pinfo.get("char_id", 1), pinfo.get("name", "Oyuncu"))


func _spawn_remote_player(pid: int, char_id: int, p_name: String) -> void:
	if _remote_players.has(pid):
		return
	var rp := RemotePlayerScene.instantiate() as RemotePlayer
	add_child(rp)
	rp.setup(pid, char_id, p_name)
	## DÜZELTME (kullanıcı bildirimi: "spawn noktaları multiplayerda bazen
	## karakterin çok yakınında oluyor") - ±40px eskiden karakter sprite'ının
	## kendi boyutuyla aynı mertebedeydi, bu yüzden diğer oyuncu neredeyse
	## üst üste/içine binerek beliriyordu. ±150'ye çıkarıldı; bu sadece
	## RemotePlayer'ın gerçek konumu gelene kadarki İLK görsel konumu (bkz.
	## _rpc_update_player_transform), o yüzden gerçek gameplay'e etkisi yok.
	rp.global_position = player.global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	_remote_players[pid] = rp


func _process_multiplayer_sync(delta: float) -> void:
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		var cur_anim: String = ""
		if player.anim:
			cur_anim = player.anim.animation
		var weapon_keys: Array = []
		var weapon_tiers: Dictionary = {}
		for weapon: Node in player.owned_weapon_nodes:
			var weapon_key: String = str(weapon.get_meta("shop_key", ""))
			if not weapon_key.is_empty():
				weapon_keys.append(weapon_key)
				weapon_tiers[weapon_key] = int(weapon.get("tier") if "tier" in weapon else 1)
		## NOT: "owned_items" alanı BİLEREK kaldırıldı - remote_player.gd
		## bu alanı hiç okumuyordu (tamamen ölü veri), ama
		## GameManager.owned_items.duplicate() her karede (saniyede 20 kez)
		## kopyalanıp ağa gönderiliyordu. player.gd on_team_leveled_up()'ta
		## max_item_slots = level olduğu için bu dizi takım seviyesi arttıkça
		## SINIRSIZ büyüyor, yani bu paket her level atlamada biraz daha
		## şişiyordu. Ziva relay'i bunu bir "flood" olarak görüp bağlantıyı
		## sessizce kapatıyordu (bkz. network_manager.gd dosya başı notu -
		## "per-connection byte budget... floods are closed, not relayed"),
		## bu da host level atladığında katılımcıların donup oyundan
		## düşmesine yol açan asıl nedendi. LAN'da (ENet, böyle bir bütçe
		## sınırı yok) aynı büyüyen paket birkaç level daha dayanabiliyordu.

		# 1) SÜREKLİ kanal: SADECE pozisyon + o anki animasyon adı - her karede
		# gerçekten değişebilecek tek şeyler bunlar, bu yüzden unreliable +
		# yüksek frekansta kalmaya devam ediyor. Menzilli silahların nişan
		# dönüşü artık BURADA HİÇ YOK - her katılımcı zaten yaratıkların
		# konumunu biliyor (enemy sync), "en yakın düşmana dön" kararını
		# remote_player.gd kendi tarafında YEREL olarak hesaplıyor (bkz.
		# _update_local_weapon_aim) - tıpkı tek oyunculudaki gibi.
		_rpc_update_player_transform.rpc(
			player.global_position,
			cur_anim,
		)

		# 2) DURUM kanalı: can, kalkan, silah envanteri, durum efektleri gibi
		# NADİREN değişen veriler artık burada toplanıp SADECE bir öncekinden
		# farklıysa (ya da aşağıdaki heartbeat'te) gönderiliyor - bkz. yukarıki
		# _last_sent_extra_state yorumu.
		var extra: Dictionary = {
			"is_invisible": player.is_invisible if "is_invisible" in player else false,
			"is_shielded": player.is_shielded if "is_shielded" in player else false,
			"elara_double": player.elara_double_fire_active if "elara_double_fire_active" in player else false,
			"berserk": player._kurtadam_berserk_active if "_kurtadam_berserk_active" in player else false,
			"talon_giant": player._talon_ulti_active if "_talon_ulti_active" in player else false,
			## Talon'un Silah Salvosu (E)/Ayna Formu (R) yetenekleri silahları
			## karakter etrafında dairesel dizer (bkz. player.gd
			## _talon_set_weapons_circular) - bu SADECE yerel/yetkili weapon.gd
			## node'larını taşır, remote_player.gd'nin kozmetik ikon kopyaları bu
			## dizilimi BAŞKA hiçbir kanaldan öğrenemez. "" / "salvo" / "mirror"
			## (bkz. remote_player.gd _update_talon_formation).
			"talon_formation": ("salvo" if ("_talon_weapon_salvo_active" in player and player._talon_weapon_salvo_active) else ("mirror" if ("_talon_mirror_form_active" in player and player._talon_mirror_form_active) else "")),
			"matthew_dome": player.matthew_dome_active if "matthew_dome_active" in player else false,
			## Klasik canlanma sistemi (bkz. player.gd is_downed) - diğer
			## oyuncuların bu bayrağı görebilmesi lazım ki hem enemy.gd hedef
			## seçiminde downed oyuncuyu atlayabilsin hem de remote_player.gd
			## "yerde yatan" görselini gösterebilsin.
			"is_downed": player.is_downed if "is_downed" in player else false,
			## Kullanıcı isteği: "birisi düştüğünde diğerleri onu canlandırmak
			## için bir süre var ama o süre görünmüyor" - kalıcı ölüme kadar
			## kalan saniye (bkz. player.gd get_downed_remaining_seconds/
			## downed_timer_label.gd), müttefiklerin ekranında downed
			## oyuncunun solunda gösterilsin diye.
			"downed_remaining": player.get_downed_remaining_seconds() if player.has_method("get_downed_remaining_seconds") else 0.0,
			## Kullanıcı isteği: "içerideyken yaratıklar içeri saldıramamalı" -
			## host'un enemy.gd'si uzak (client) oyuncuların bu bayrağını
			## görebilmeli ki ev içindeki bir katılımcıyı da hedef dışı
			## bıraksın (bkz. remote_player.gd is_indoors, enemy.gd
			## _find_closest_target_player).
			"is_indoors": player.is_indoors if "is_indoors" in player else false,
			## Seyyar satıcının güvenli bölgesi - is_indoors ile AYNI amaç/desen
			## (bkz. player.gd is_in_merchant_zone üstündeki yorum).
			"is_in_merchant_zone": player.is_in_merchant_zone if "is_in_merchant_zone" in player else false,
			"weapon_tiers": weapon_tiers,
			## DÜZELTME (kullanıcı bildirimi #41: "Diğer oyuncuların kalkan
			## baloncukları sürekli görünür kalıyor"): remote_player.gd eskiden
			## sadece "item_shield_hp > 0.0" bakıyordu - bu, kalkan dolu/sabit
			## dururken bile baloncuğu SÜREKLİ gösteriyordu. Yerelde asıl
			## görünürlük kararı player.gd _update_shield_bubble()'daki
			## _bubble_active değişkeninde (is_shielded / hasar flaşı /
			## gerçek yenilenme mantığı) veriliyor - o kararı doğrudan
			## senkronize ediyoruz ki uzak kopya da AYNI anlarda görünsün.
			"shield_bubble_visible": player._bubble_active if "_bubble_active" in player else false,
			## DÜZELTME (derin multiplayer görsel denetimi): kalkan baloncuğunun
			## GÖRSEL türü (standart/enerji/kale/savaş - bkz. player.gd
			## SHIELD_TYPES/_owned_shield_type_key/shield_visual.set_shield_type)
			## hiç senkronize edilmiyordu; uzak oyuncular her zaman varsayılan
			## (standart) baloncuk görselini görüyordu.
			"shield_type": player._owned_shield_type_key() if player.has_method("_owned_shield_type_key") else "",
			## Şovalye Adam'ın Koruma Bariyeri (skill3 id 29) - bu oyuncu
			## şu an buflanmış mı (bkz. player.gd damage_redirect_percent/
			## has_active_damage_redirect_barrier) - shield_bubble_visible
			## ile AYNI desen, sadece görsel bir bayrak, gerçek mekanik
			## (hasar yansıtma) zaten player.gd take_damage()'ında.
			"barrier_link_active": player.has_active_damage_redirect_barrier() if player.has_method("has_active_damage_redirect_barrier") else false,
			## Kullanıcı isteği: "istatistiklerin oyun içinde de gözükebilsin,
			## grup penceresinde bir buton olacak, kimin ne kadar vurduğu
			## gösterilecek" - bkz. party_panel.gd _build_stats_popup. Maç
			## sonu istatistik ekranındaki _match_stats_by_peer/sync_match_stats
			## AYRI bir mekanizma (SADECE oyun bitince bir kerelik RPC ile
			## yayınlanır) - CANLI panel için o yeterli değil, bu yüzden zaten
			## sürekli akan bu DURUM kanalına (reliable + on-change/heartbeat +
			## should_throttle 5Hz sınırı, bkz. yukarısı) eklendi. player.gd
			## match_damage_dealt zaten hasar verildikçe canlı biriken bir
			## sayaç (bkz. player.gd on_damage_dealt/match_damage_dealt notu).
			"dmg_dealt": player.match_damage_dealt,
		}
		# Character modulate color for status effects
		## DÜZELTME (derin multiplayer görsel denetimi): bazı yetenekler
		## (ör. Büyücü Kız Don Nova/Meteor, Assasin Görünmezlik/Gölge Hücumu,
		## Kurt Adam Kudurmuş Saldırı) tonu KÖK `player.modulate` üzerine
		## uyguluyor, `player.anim.modulate` üzerine değil - Godot'ta
		## CanvasItem modulate alt öğelere çarpımsal olarak yayıldığı için
		## caster'ın kendi ekranında ikisi de doğru görünüyordu ama eskiden
		## sadece anim.modulate gönderiliyordu, kök tonlama hiç senkronize
		## edilmiyordu. İkisinin çarpımını (caster'ın GERÇEKTEN gördüğü etkin
		## renk) gönderiyoruz.
		if player.anim and is_instance_valid(player.anim):
			extra["modulate"] = player.modulate * player.anim.modulate

		## Klasik canlanma sistemi (bkz. player.gd is_downed/_go_down/
		## _process_downed): downed iken hp/max_hp alanları GERÇEK canı
		## DEĞİL, kurtarma kanalının ilerleme oranını (0.0-1.0) taşır - böylece
		## remote_player.gd downed müttefiğin ÜSTÜNDEKİ can çubuğunu bir
		## "kurtarma ilerlemesi" göstergesine çevirebiliyor (bkz. orada
		## overhead_bar.set_health). "dead" alanı da downed sürdüğü müddetçe
		## BİLEREK false gönderiliyor - yoksa remote_player.gd _play_death_
		## animation() bu oyuncunun kuklasını hemen queue_free() eder, henüz
		## kesinleşmemiş bir canlanma imkansız hale gelirdi.
		var is_player_downed: bool = player.is_downed if "is_downed" in player else false
		var send_hp: float = player.health
		var send_max_hp: float = player.max_health
		var send_dead: bool = player.is_dead
		if is_player_downed:
			send_hp = player.get_revive_progress_ratio() if player.has_method("get_revive_progress_ratio") else 0.0
			send_max_hp = 1.0
			send_dead = false

		var state_snapshot: Dictionary = {
			"hp": send_hp,
			"max_hp": send_max_hp,
			"s_hp": player.item_shield_hp,
			"s_max": player.item_shield_max,
			"p_zone": player.paladin_zone_active,
			"dead": send_dead,
			"weapon_keys": weapon_keys,
			"extra": extra,
		}
		_extra_state_tick += 1
		var is_heartbeat: bool = (_extra_state_tick % EXTRA_STATE_HEARTBEAT_TICKS) == 0
		## BUG DÜZELTMESİ (kullanıcı bildirimi: "multiplayerda bazen katılımcılar
		## lag sorunu yaşıyor") - kök neden: downed iken (_downed_time/
		## _revive_progress, bkz. yukarıdaki send_hp/downed_remaining) ve
		## saldırgan/Şimşek Hız kalkan modlarında (item_shield_hp sürekli
		## azalıyor, bkz. player.gd _process_item_shield) state_snapshot'taki
		## bazı alanlar HER KAREDE minik miktarlarda değişiyor - "sadece
		## değişince gönder" diff kontrolü (state_snapshot != _last_sent_
		## extra_state) bu yüzden sürekli true oluyor ve bu GÜVENİLİR (reliable)
		## RPC'yi downed/kalkan-drenaj süresince saniyede 20 kez (SYNC_INTERVAL)
		## tetikliyordu. Relay'in bağlantı başına byte/paket bütçesi bunu flood
		## sayıp bağlantıyı sessizce kapatabiliyor (bkz. yukarıdaki "owned_items"
		## notu - AYNI RPC'de daha önce yaşanmış, weapon.gd/pet script'lerindeki
		## should_throttle deseniyle çözülmüş BİREBİR AYNI hata sınıfı, o düzeltme
		## burada eksikti). Diff kontrolü DEĞİŞMEDİ (hâlâ gerçekten bir şey
		## değişmeden hiç göndermiyor), ama gönderim ayrıca en fazla saniyede 5
		## kezle (0.2sn) sınırlandırıldı - ender/gerçek durum değişiklikleri için
		## fark edilmeyecek kadar küçük bir gecikme, downed/drenaj gibi sürekli
		## değişen alanlar için ise 20Hz'den 5Hz'e (4 kat) düşüyor.
		if (is_heartbeat or state_snapshot != _last_sent_extra_state) and not NetworkManager.should_throttle("extra_state", 0.2):
			_last_sent_extra_state = state_snapshot.duplicate(true)
			_rpc_update_player_extra_state.rpc(
				send_hp,
				send_max_hp,
				player.item_shield_hp,
				player.item_shield_max,
				player.paladin_zone_active,
				send_dead,
				weapon_keys,
				extra
			)


## BUG DÜZELTMESİ (kullanıcı isteği: "dükkandan diriltme satın alınabilmeli")
## - kalıcı ölen bir oyuncunun RemotePlayer kuklası (bkz. remote_player.gd
## _play_death_animation) ölüm animasyonu bitince queue_free() ediliyor, ama
## bu sözlükteki kaydı HİÇ silinmiyordu. O oyuncu dükkandan diriltme satın
## alıp geri dönünce, has(sender_id) hâlâ true döndüğü için asla YENİ bir
## kukla oluşturulmuyordu (state sync RPC'leri sessizce is_instance_valid
## kontrolüne takılıp no-op oluyordu) - müttefikler o oyuncunun geri
## döndüğünü hiç göremiyordu. Artık geçersiz/silinmiş kayıtlar tespit edilip
## temizleniyor, _spawn_remote_player() kendi "zaten var" korumasına
## takılmadan yeni bir kukla kurabiliyor.
## DÜZELTME (kullanıcı bildirimi: "biri ölünce ve can hakkı kalmayınca
## karakter aniden spawnlanıp yok oluyor spawnlanıp yok oluyor tuhaf bir
## buga giriyor" + "birini diriltsek can hakkı olmasına rağmen bidaha
## diriltemiyoruz ve yok oluyor") - KÖK NEDEN bulundu: bu fonksiyon her
## çağrıldığında (özellikle _rpc_update_player_transform - GÜVENİLMEZ kanal,
## SANİYEDE 20 KEZ gönderiliyor) kayıtlı kukla geçersizse (kalıcı ölen bir
## oyuncunun kuklası ölüm animasyonu bitince queue_free() olur, bkz.
## remote_player.gd _play_death_animation) HİÇ SORGUSUZ yeni bir kukla
## spawn ediyordu. O yeni kukla ise ANINDA aynı "dead=true" durumunu alıp
## (bir sonraki extra_state paketinde, en geç ~2sn içinde) tekrar ölüm
## animasyonuna girip tekrar queue_free() ediliyordu - transform paketi
## saniyede 20 kez geldiği için bu spawn/despawn döngüsü sürekli tekrarlanıp
## "spawnlanıp yok oluyor spawnlanıp yok oluyor" hissi veriyordu. allow_spawn
## artık SADECE gerçekten yeni bir kukla gerektiren durumlarda true - transform
## paketleri (aşağıda) hiçbir zaman kendi başına spawn edemez, extra_state
## paketleri SADECE oyuncu GERÇEKTEN hayattaysa/downed'sa (dead=false) spawn
## edebilir - dead=true iken kukla yoksa (zaten kalıcı öldüyse) paket
## sessizce yok sayılır. Gerçek bir "yeniden spawn" SADECE dükkandan
## diriltme satın alınca (dead=false'a dönünce, bkz. _on_mini_shop_revive_
## pressed/player.gd revive_from_permadeath) meydana gelir.
func _get_or_spawn_remote_player(sender_id: int, allow_spawn: bool = true) -> RemotePlayer:
	if _remote_players.has(sender_id) and not is_instance_valid(_remote_players[sender_id]):
		_remote_players.erase(sender_id)
	if allow_spawn and not _remote_players.has(sender_id):
		var pinfo: Dictionary = NetworkManager.lobby_players.get(sender_id, {})
		_spawn_remote_player(sender_id, pinfo.get("char_id", 1), pinfo.get("name", "Oyuncu"))
	return _remote_players.get(sender_id, null)


@rpc("any_peer", "unreliable")
func _rpc_update_player_transform(pos: Vector2, cur_anim: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	## bkz. _get_or_spawn_remote_player üstündeki DÜZELTME notu - saf konum
	## paketi TEK BAŞINA asla yeni bir kukla oluşturamaz.
	var rp: RemotePlayer = _get_or_spawn_remote_player(sender_id, false)
	if rp and is_instance_valid(rp):
		rp.update_position_and_anim_from_net(pos, cur_anim)


@rpc("any_peer", "reliable")
func _rpc_update_player_extra_state(hp: float, max_hp: float, s_hp: float, s_max: float, p_zone: bool, dead: bool, weapon_keys: Array, extra: Dictionary = {}) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	## bkz. _get_or_spawn_remote_player üstündeki DÜZELTME notu - dead=true
	## iken (oyuncu GERÇEKTEN kalıcı ölüyken) kukla yoksa YENİDEN spawn
	## edilmiyor, paket sessizce yok sayılıyor.
	var rp: RemotePlayer = _get_or_spawn_remote_player(sender_id, not dead)
	if rp and is_instance_valid(rp):
		rp.update_extra_state_from_net(hp, max_hp, s_hp, s_max, p_zone, dead, weapon_keys, extra)


func _get_remote_player(pid: int) -> RemotePlayer:
	if _remote_players.has(pid):
		return _remote_players[pid]
	return null


func _toggle_pause() -> void:
	# Menü açılmadan önce oyuncunun input durumunu sıfırla ki tuş kilitlenmesi olmasın.
	var local_player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if local_player and local_player.has_method("clear_input_state"):
		local_player.call("clear_input_state")

	## DÜZELTME (KRİTİK - kullanıcı bildirimi #28: "Bir oyuncu ESC'den oyunu
	## durdurunca oyunun durmaması gerekiyor multiplayer'da"): get_tree().
	## paused, varsayılan PROCESS_MODE_PAUSABLE'a sahip TÜM sahne ağacını
	## durdurur - bu SADECE menüyü açan oyuncunun kendi ekranını değil, o
	## HOST'sa enemy_spawner.gd/enemy.gd gibi host-yetkili TÜM simülasyonu
	## dondurup diğer TÜM oyunculara da (istemedikleri hâlde) "oyun donmuş"
	## gibi yansıyordu. Artık multiplayer'da tree HİÇ duraklatılmıyor - sadece
	## menüyü açan oyuncunun KENDİ karakteri (bkz. player.gd
	## set_menu_input_locked) hareketsiz kalıyor, geri kalan her şey
	## (yaratıklar, diğer oyuncular, spawn) normal akmaya devam ediyor.
	## Açık/kapalı durumu artık get_tree().paused DEĞİL, pause_menu_instance'ın
	## geçerliliği ile takip ediliyor (pause_menu.gd'nin Devam Et/Ana Menü
	## butonları da menüyü DOĞRUDAN kapatıp kendi kilidini açıyor - bkz. o
	## dosyadaki _unlock_local_input).
	var use_real_pause: bool = not NetworkManager.is_multiplayer_active

	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
		if use_real_pause:
			get_tree().paused = false
		elif local_player and local_player.has_method("set_menu_input_locked"):
			local_player.call("set_menu_input_locked", false)
	else:
		pause_menu_instance = PauseMenuScene.instantiate()
		add_child(pause_menu_instance)
		if use_real_pause:
			get_tree().paused = true
		elif local_player and local_player.has_method("set_menu_input_locked"):
			local_player.call("set_menu_input_locked", true)


func _update_stats_display() -> void:
	var w = player.get_primary_weapon()
	if w:
		hud.update_stats(player.speed, w.damage, w.fire_rate, w.crit_chance, w.crit_damage)
	else:
		hud.update_stats(player.speed, 0.0, 0.0, 0.0, 0.0)


## ==============================================================================
## SİLAH / KALKAN SEÇİM AKIŞI (bkz. weapon_select_screen.gd üstündeki not)
## ==============================================================================
var _active_item_select_screen: Node = null

## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "multiplayerda bazen
## yaratıklar 5-10 dakika ara verip sonradan spawn olmaya başlıyorlar") - kök
## neden bulundu: sandık kuyruğunun (bkz. _try_open_next_pending_chest)
## boyutuna hiçbir üst sınır yoktu, her sandık kendi başına en fazla 25sn
## sürebiliyordu (bkz. NetworkManager sandık geri sayımı) - biriken 15-20
## sandığı olan TEK bir oyuncu bile TÜM takımı (host'un enemy_spawner.gd'si
## dahil, get_tree().paused = true onu da durdurur) 5-8+ dakika kilitleyip
## tam olarak bildirilen "5-10 dakika ara" belirtisini üretiyordu. Bu, o
## kuyruğun TOPLAM ne kadar süredir açık olduğunu izler - bir üst sınırı
## aşarsa (bkz. CHEST_QUEUE_TOTAL_TIMEOUT_MSEC) kalan sandıklar sırada
## bırakılıp (veri kaybı yok, bir sonraki seviye atlamasında devam eder) oyun
## hemen devam ettirilir.
var _chest_queue_batch_start_msec: int = -1
const CHEST_QUEUE_TOTAL_TIMEOUT_MSEC := 90000 ## 90 saniye


## DÜZELTME (kullanıcı isteği: "3 dakikada bir açılan dükkan ... oyun daha
## başlamadan öyle açılmalı") - ilk silah+kalkan seçimi bitince artık oyun
## direkt açılmıyor, ilk periyodik dükkan (bkz. _show_mini_shop_screen)
## araya giriyor - dükkan KAPANINCA (bkz. _on_mini_shop_screen_closed ->
## _finish_mini_shop_close) oyun zaten kendi başına açılıyor.
func _start_initial_loadout_selection() -> void:
	if not GameManager.owned_weapons.is_empty():
		return ## başka bir yol zaten doldurmuş (güvenlik payı)
	if is_instance_valid(player) and player.has_method("clear_input_state"):
		player.call("clear_input_state")
	get_tree().paused = true
	_show_item_select_screen("weapon", func(): _show_item_select_screen("shield", _finish_item_select_chain))


## `on_done`, bu ekran seçilir seçilmez (ağ beklemesi OLMADAN, bkz. aşağıdaki
## kök neden notu) hemen çağrılır - başlangıç akışında bir sonraki ekrana
## zincirlemek için kullanılıyor.
func _show_item_select_screen(mode: String, on_done: Callable) -> void:
	get_tree().paused = true
	## bkz. _show_level_up_screen'deki AYNI koruma notu.
	_hide_level_up_wait_overlay()
	var screen: CanvasLayer = WeaponSelectScreenScript.new()
	screen.mode = mode
	screen.player_ref = player
	screen.name = "WeaponSelectScreen" if mode == "weapon" else "ShieldSelectScreen"
	add_child(screen)
	_active_item_select_screen = screen
	## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini
	## beklemeden tüm kartlarını seçebilsin") - eskiden burada (multiplayer
	## dalında) on_done HİÇ çağrılmıyordu, NetworkManager.multiplayer_level_up_
	## all_chosen (TÜM oyuncular seçene kadar) beklenip main.gd _on_multiplayer_
	## level_up_all_chosen'da tetikleniyordu - yani silah seçilse bile kalkan
	## ekranı diğer oyuncu(lar) silahını seçmeden AÇILMIYORDU. Artık on_done
	## HER ZAMAN hemen çağrılıyor (silah seçilir seçilmez kalkan ekranı
	## açılır) - ağ senkronu SADECE zincirin gerçekten bittiği noktada
	## (bkz. _finish_item_select_chain) devreye giriyor.
	screen.item_chosen.connect(func(key: String):
		_grant_selected_item(mode, key)
		if _active_item_select_screen != null and is_instance_valid(_active_item_select_screen):
			_active_item_select_screen.queue_free()
		_active_item_select_screen = null
		on_done.call()
	)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.set_level_up_busy(true)
		NetworkManager.start_level_up_countdown()


## Silah + kalkan seçim zincirinin GERÇEK sonu (bkz. _show_item_select_screen
## çağrı zinciri) - bkz. _finish_level_up_phase.
func _finish_item_select_chain() -> void:
	_finish_level_up_phase(_show_mini_shop_screen)


func _grant_selected_item(mode: String, key: String) -> void:
	if not is_instance_valid(player):
		return
	if mode == "weapon":
		GameManager.owned_weapons.append({"key": key, "level": 1, "spent": 0})
		player.buy_weapon_copy(key, 1) ## bkz. player.gd - kendi içinde _reposition_weapon_icons() zaten çağırıyor
	else:
		GameManager.set(key + "_level", 1)
		if player.has_method("refresh_shield_stats"):
			player.refresh_shield_stats()


## ==============================================================================
## ORTAK LEVEL ATLAMA AKIŞI
## ==============================================================================
var _pending_level_ups: int = 0
var _active_level_up_screen: Node = null
## Bu oyuncunun kart/silah/kalkan seçim kuyruğu (bkz. _finish_level_up_phase)
## TAMAMEN bitti ama diğer oyuncu(lar) hâlâ meşgulken - "artık kimse meşgul
## değil" anını yakalayınca (bkz. _on_level_up_busy_state_changed) bir kez
## çağrılıp temizlenecek devam adımı (ör. sandık kuyruğuna geçiş, ya da mini
## dükkanı açma).
var _level_up_wait_resume_action: Callable = Callable()
## chest_wait_overlay ile AYNI görsel desen (bkz. _show_chest_wait_overlay) -
## sadece kart/silah/kalkan seçim kuyruğu için.
var _level_up_wait_overlay: CanvasLayer = null
var _level_up_wait_countdown_label: Label = null
var _level_up_wait_label: Label = null
## Kullanıcı isteği: "mini dükkan yerine direk dükkan açılsın" - artık ayrı
## bir MiniShopScreen sahnesi YOK, periyodik mola hud.gd'nin PAYLAŞILAN
## dükkan panelini açıyor (bkz. _show_mini_shop_screen). Bu bayrak o molanın
## şu an aktif olup olmadığını tutuyor (eskiden _active_mini_shop_screen bir
## Node referansıydı, artık kontrol edilecek ayrı bir sahne yok).
var _mini_shop_pause_active: bool = false
## DÜZELTME (kullanıcı isteği: "3 dakikada bir açılan dükkan sadece level
## atlama ekranından sonra çıkmalı" - eski süreye bağlı GameManager.
## mini_shop_due tetikleyicisi tamamen kaldırıldı) - bir level atlama akışı
## (_show_level_up_screen) başladığında true olur; akışın GERÇEKTEN bittiği
## (kilometre taşı silah seçimi + sandık kuyruğu dahil TÜMÜ kapandığı) an
## (bkz. _try_open_next_pending_chest'in "kuyruk boş" dalları) tüketilip
## dükkanı açar - normalde oyunu açacak olan get_tree().paused = false
## ÇAĞRILARININ YERİNE geçer (bkz. _resume_gameplay_after_level_flow).
var _mini_shop_pending_after_level_up: bool = false
## Kullanıcı bildirimi: "Level atladıktan sonra dükkan açılıyor ama ... bazen
## hostta açılıp diğer oyunlarda açılmıyor."
## - çok oyunculuda karar artık TEK yerde veriliyor: HOST kendi bekleme
## süresine bakıp karar verir ve yayınlar, client'lar kendi başına dükkan
## AÇMAZ (bkz. network_manager.gd "MİNİ DÜKKAN KARARI" bloğu). Aşağıdaki alanlar
## o beklemeyi ve "karar akış BİTMEDEN geldiyse sakla, karar anında uygula"
## durumunu tutar - host'un akışı bizden önce de sonra da bitebilir.
const MINI_SHOP_DECISION_WAIT := 3.0 ## host'tan karar gelmezse bu kadar sonra yerel karara düş
var _awaiting_mini_shop_decision: bool = false
var _mini_shop_decision_received: bool = false
var _mini_shop_decision_open: bool = false
## Kalıcı ölü oyuncu için küçük "Diriltme Satın Al" istemi - eski
## mini_shop_screen.gd _refresh_revive_row/_on_buy_revive_pressed ile AYNI
## mantık, artık dükkanın YANINDA ayrı, küçük bir CanvasLayer.
const MINI_SHOP_REVIVE_COST := 500
var _mini_shop_revive_prompt: CanvasLayer = null
var _mini_shop_revive_button: Button = null
## Çok oyunculuda "herkes kapatana kadar bekle" (bkz. _on_mini_shop_screen_
## closed) - _chest_wait_overlay ile AYNI görsel desen, sadece NetworkManager
## mini_shop_* sinyallerine bağlı.
var _mini_shop_wait_overlay: CanvasLayer = null
var _mini_shop_wait_label: Label = null
var _mini_shop_wait_countdown_label: Label = null
## Kullanıcı isteği: "bir kişi dükkanda çarpıya basınca diğerlerinin bekleme
## süresi başlayacak." - dükkanı hâlâ açık olan oyuncuya kalan süreyi gösteren
## küçük (tıklamayı engellemeyen) bildirim ve "ben dükkanı kapattım mı" bayrağı.
var _mini_shop_countdown_notice: CanvasLayer = null
var _mini_shop_countdown_notice_label: Label = null
var _mini_shop_closed_locally: bool = false
## #58: bkz. _try_open_next_pending_chest/_on_chest_busy_state_changed.
var _local_chest_menu_open: bool = false
var _chest_wait_overlay: CanvasLayer = null
var _chest_wait_countdown_label: Label = null
var _chest_wait_label: Label = null

## Kullanıcı isteği: "Exp orbu toplarken level atlama kartları çıkmasın, exp
## orbu toplamayı 1 saniye bıraktıktan sonra level atlama kartları ekranı
## gelsin." - eskiden bir seviye eşiği aşılır aşılmaz (GameManager.
## team_leveled_up) ekran ANINDA açılıp get_tree().paused = true yapıyordu
## (bkz. _show_level_up_screen); bir mıknatıs/toplama patlamasıyla aynı anda
## birden çok orb toplanırken bu, henüz oyuncuya doğru uçan orb'ların
## animasyonunu ortasında donduruyordu. Artık team_xp_changed (HER orb
## toplamasında, host VEYA client fark etmeksizin ateşlenir) son toplama
## zamanını günceller; bir seviye atlaması olduğunda ekranı hemen açmak
## yerine bu zaman damgası XP_PICKUP_SETTLE_DELAY kadar SESSİZ kalana kadar
## (yani toplama gerçekten durana kadar) beklenir.
const XP_PICKUP_SETTLE_DELAY := 1.0
var _last_xp_gain_time: float = 0.0
## Ekranı açma kararı zaten bekleme aşamasındaysa (settle süresi dolmayı
## bekliyorsa) aynı anda ikinci bir bekleme döngüsü başlatılmasın diye - bu
## sürede gelen YENİ seviye atlamaları normal _pending_level_ups kuyruğuna
## eklenir (aşağıdaki _on_team_leveled_up'taki AYNI kontrol).
var _level_up_screen_launch_pending: bool = false

func _on_team_xp_changed_for_level_up_delay(_current: float, _needed: float) -> void:
	_last_xp_gain_time = Time.get_ticks_msec() / 1000.0


func _on_team_leveled_up(new_level: int) -> void:
	hud.update_level(new_level)
	if is_instance_valid(player) and player.has_method("on_team_leveled_up"):
		player.on_team_leveled_up(new_level)
	if _active_level_up_screen != null and is_instance_valid(_active_level_up_screen):
		_pending_level_ups += 1
		return
	## Dükkan (periyodik mola) açıkken (nadir - senkronize edilmiş bir takım
	## XP RPC'si paused==true iken bile tetiklenebilir) bir level-up ekranını
	## ÜSTÜNE bindirmek yerine kuyruğa al, mola bitince _advance_level_up_
	## queue zaten sırayla işleyecek.
	if _mini_shop_pause_active:
		_pending_level_ups += 1
		return
	if _level_up_screen_launch_pending:
		_pending_level_ups += 1
		return
	_level_up_screen_launch_pending = true
	_open_level_up_screen_after_xp_settles()


## bkz. yukarıdaki XP_PICKUP_SETTLE_DELAY notu - son XP kazanımından itibaren
## en az 1 saniye sessizlik geçene kadar döngüyle bekler (bekleme sırasında
## yeni bir orb toplanırsa süre kendiliğinden uzar), sonra GERÇEKTEN güncel
## takım seviyesiyle ekranı açar. Oyun bu süre boyunca DURAKLAMAZ (bkz.
## _show_level_up_screen'in get_tree().paused = true satırı - o satıra ancak
## bu fonksiyon bittiğinde ulaşılır), yani uçmakta olan orb'lar rahatça
## toplanmaya devam edebilir.
func _open_level_up_screen_after_xp_settles() -> void:
	while is_inside_tree():
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _last_xp_gain_time
		var remaining: float = XP_PICKUP_SETTLE_DELAY - elapsed
		if remaining <= 0.0:
			break
		await get_tree().create_timer(remaining).timeout
	_level_up_screen_launch_pending = false
	if not is_inside_tree():
		return
	## Bekleme sırasında başka bir akış (ör. dükkan molası) devreye girmiş
	## olabilir - normal kuyruğa düş, _advance_level_up_queue zaten bunu
	## işleyecek.
	if _active_level_up_screen != null and is_instance_valid(_active_level_up_screen):
		_pending_level_ups += 1
		return
	if _mini_shop_pause_active:
		_pending_level_ups += 1
		return
	_show_level_up_screen(GameManager.team_level)


## DÜZELTME (kullanıcı isteği: "bundan sonra mini dükkan aralarında mini
## dükkan yerine direk dükkan açılsın") - periyodik molada artık
## MiniShopScreen'in kendi küçük/rasgele kart ızgarası DEĞİL, oyuncunun
## zaten bildiği TAM dükkan (+ eşleşen istatistik paneli, bkz. hud.gd
## open_shop_panel) açılıyor. Oyunu durdurma, çok oyunculu "herkes kapatana
## kadar bekle" senkronizasyonu (NetworkManager mini_shop_* API'si - isim
## DEĞİŞTİRİLMEDİ, zaten UI'dan bağımsızdı) ve kalıcı ölü oyuncunun
## diriltme satın alabilmesi (eski _refresh_revive_row/_on_buy_revive_pressed
## ile AYNI mantık, artık ayrı küçük bir istem) AYNEN korunuyor. Fonksiyon
## adı geriye dönük tutarlılık için değiştirilmedi. DÜŞEN tek şeyler: eski 3
## kartlık rastgele seçim/reroll (tam dükkan zaten HER ŞEYİ gösteriyor, gerek
## kalmadı) ve satın alma sonrası 25sn otomatik kapanma (tam dükkan diğer
## tüm kullanımlarda olduğu gibi elle kapatılana kadar açık kalıyor).
func _show_mini_shop_screen() -> void:
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "oyunum başladığında silah ve
	## kalkanı seçtikten sonra oyun donuyor") - GameManager.SHOP_ENABLED=false
	## yapılırken (bkz. o sabitin üstündeki not) SADECE periyodik molanın karar
	## kaynağı olan is_mini_shop_cooldown_ready() gated edilmişti. Ama bu
	## fonksiyon BAŞKA bir yoldan da (bkz. _start_initial_loadout_selection -
	## oyunun EN başında silah+kalkan seçimi bitince) o kontrolden hiç
	## GEÇMEDEN koşulsuz çağrılıyordu: oyun duraklatılıp hud.open_shop_panel()
	## çağrılıyordu, o da artık (yine SHOP_ENABLED yüzünden) hiçbir şey
	## yapmıyordu - panel hiç açılmadığı için "closed" sinyali de asla
	## gelmiyor, oyun SONSUZA KADAR duraklamış kalıyordu. Artık dükkan devre
	## dışıyken bu fonksiyonun KENDİSİ en başta çıkıp oyunu hemen devam
	## ettiriyor - hangi yoldan çağrılırsa çağrılsın (periyodik mola YA DA
	## ilk açılış) artık güvenli.
	if not GameManager.SHOP_ENABLED:
		get_tree().paused = false
		return
	if is_instance_valid(player) and player.has_method("clear_input_state"):
		player.call("clear_input_state")
	get_tree().paused = true
	_mini_shop_pause_active = true
	## Kullanıcı isteği: "Her seferinde 5 dakika bekleme süresine girmeli." -
	## dükkan HANGİ yoldan açılırsa açılsın (oyun başlamadan önceki ilk açılış
	## - bkz. _start_initial_loadout_selection - veya bir level atlaması
	## sonrası), açıldığı an bir sonraki açılış için 5 dakikalık geri sayım
	## sıfırdan başlar.
	GameManager.start_mini_shop_cooldown()
	## bkz. eski yorum: ölüm ekranı (layer=95) dükkanın (ShopPanel de HUD
	## katmanında) üstünde kalıp diriltme istemini gizleyebilir - geçici
	## olarak kapatılıyor, _finish_mini_shop_close() tekrar açıyor.
	if _death_overlay_layer and is_instance_valid(_death_overlay_layer):
		_death_overlay_layer.visible = false
	hud.open_shop_panel()
	## Yeni bir dükkan oturumu: "ben kapattım" bayrağı ve önceki oturumdan
	## kalma süre bildirimi temizlenir (bkz. _update_mini_shop_countdown_notice).
	_mini_shop_closed_locally = false
	_hide_mini_shop_countdown_notice()
	if not hud.shop_panel.closed.is_connected(_on_mini_shop_screen_closed):
		hud.shop_panel.closed.connect(_on_mini_shop_screen_closed, CONNECT_ONE_SHOT)
	_refresh_mini_shop_revive_prompt()
	if NetworkManager.is_multiplayer_active:
		NetworkManager.start_team_mini_shop_waiting()
		## Sayaç tikleri dükkan AÇILIRKEN bağlanıyor: hem kapatan oyuncunun
		## bekleme ekranı HEM DE hâlâ alışveriş yapanların "kalan süre"
		## bildirimi bu tiklerle güncelleniyor (eskiden tik yalnızca kapatma
		## anında bağlanıyordu - bkz. _on_mini_shop_screen_closed - o yüzden
		## dükkanı açık olan oyuncular kalan süreyi hiç göremiyordu).
		if not NetworkManager.multiplayer_mini_shop_timer_tick.is_connected(_on_mini_shop_countdown_tick):
			NetworkManager.multiplayer_mini_shop_timer_tick.connect(_on_mini_shop_countdown_tick)


## Kullanıcı isteği: "dükkandan diriltme satın alınabilmeli" - artık
## _on_mini_shop_revive_pressed'dan çağrılır. player.revive_from_permadeath()
## sadece Player'ın KENDİ durumunu (can/kalkan/kamera) toparlıyor - izleyici
## modundan çıkmak ve ölüm ekranını kapatmak (main.gd'nin sorumluluğundaki
## durum) burada yapılıyor.
func _revive_local_player() -> void:
	if not is_instance_valid(player) or not player.has_method("revive_from_permadeath"):
		return
	player.revive_from_permadeath()
	_end_spectate_mode()
	if _death_overlay_layer and is_instance_valid(_death_overlay_layer):
		_death_overlay_layer.queue_free()
	_death_overlay_layer = null
	_death_overlay_label = null


## Periyodik dükkan molası sırasında kalıcı ölü oyuncuya (is_downed/kurtarma
## kanalından AYRI, o normal müttefik-yakınlık kanalıyla çözülüyor) küçük,
## bağımsız bir "Diriltme Satın Al" istemi gösterir - tam dükkan panelinde bu
## özellik yok, bu yüzden yanına AYRI bir CanvasLayer olarak ekleniyor.
func _refresh_mini_shop_revive_prompt() -> void:
	var is_permanently_dead: bool = is_instance_valid(player) and bool(player.get("is_dead")) and not bool(player.get("is_downed"))
	if not is_permanently_dead:
		if _mini_shop_revive_prompt and is_instance_valid(_mini_shop_revive_prompt):
			_mini_shop_revive_prompt.queue_free()
		_mini_shop_revive_prompt = null
		_mini_shop_revive_button = null
		return
	if _mini_shop_revive_prompt and is_instance_valid(_mini_shop_revive_prompt):
		_mini_shop_revive_button.disabled = GameManager.gold < MINI_SHOP_REVIVE_COST
		return
	_mini_shop_revive_prompt = CanvasLayer.new()
	_mini_shop_revive_prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_mini_shop_revive_prompt.layer = 93 ## dükkanın (HUD katmanı) üstünde.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_top = -140.0
	panel.offset_bottom = -70.0
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.08, 0.97)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.83, 0.56, 0.30, 1.0)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	_mini_shop_revive_button = Button.new()
	_mini_shop_revive_button.text = "Diriltmeyi Satın Al (%d Altın)" % MINI_SHOP_REVIVE_COST
	_mini_shop_revive_button.disabled = GameManager.gold < MINI_SHOP_REVIVE_COST
	_mini_shop_revive_button.pressed.connect(_on_mini_shop_revive_pressed)
	panel.add_child(_mini_shop_revive_button)
	_mini_shop_revive_prompt.add_child(panel)
	add_child(_mini_shop_revive_prompt)
	UISound.connect_all_buttons(_mini_shop_revive_prompt)
	UISound.apply_wood_buttons(_mini_shop_revive_prompt)


func _on_mini_shop_revive_pressed() -> void:
	if not is_instance_valid(player) or not bool(player.get("is_dead")):
		return
	if GameManager.gold < MINI_SHOP_REVIVE_COST:
		return
	GameManager.gold -= MINI_SHOP_REVIVE_COST
	_revive_local_player()
	if _mini_shop_revive_prompt and is_instance_valid(_mini_shop_revive_prompt):
		_mini_shop_revive_prompt.queue_free()
	_mini_shop_revive_prompt = null
	_mini_shop_revive_button = null


## Dükkan (X butonu YA DA altın göstergesine tekrar tıklama - ikisi de
## hud.gd'deki "closed" sinyalini yayınlıyor, bkz. orası) kapanınca çağrılır.
## Tek oyunculuda hemen biter; çok oyunculuda level_up_screen.gd/eski
## mini_shop_screen.gd ile AYNI "herkes kapatana kadar bekle" deseni
## (NetworkManager mini_shop_* API'si, hiç değiştirilmedi).
func _on_mini_shop_screen_closed() -> void:
	if not _mini_shop_pause_active:
		return
	_mini_shop_closed_locally = true
	_hide_mini_shop_countdown_notice()
	if NetworkManager.is_multiplayer_active:
		_show_mini_shop_wait_overlay()
		if not NetworkManager.multiplayer_mini_shop_all_closed.is_connected(_finish_mini_shop_close):
			NetworkManager.multiplayer_mini_shop_all_closed.connect(_finish_mini_shop_close, CONNECT_ONE_SHOT)
		if not NetworkManager.multiplayer_mini_shop_timer_tick.is_connected(_on_mini_shop_countdown_tick):
			NetworkManager.multiplayer_mini_shop_timer_tick.connect(_on_mini_shop_countdown_tick)
		NetworkManager.mark_local_mini_shop_closed()
	else:
		_finish_mini_shop_close()


func _finish_mini_shop_close() -> void:
	_mini_shop_pause_active = false
	get_tree().paused = false
	_hide_mini_shop_wait_overlay()
	_hide_mini_shop_countdown_notice()
	_mini_shop_closed_locally = false
	if NetworkManager.multiplayer_mini_shop_timer_tick.is_connected(_on_mini_shop_countdown_tick):
		NetworkManager.multiplayer_mini_shop_timer_tick.disconnect(_on_mini_shop_countdown_tick)
	if _mini_shop_revive_prompt and is_instance_valid(_mini_shop_revive_prompt):
		_mini_shop_revive_prompt.queue_free()
	_mini_shop_revive_prompt = null
	_mini_shop_revive_button = null
	## bkz. _show_mini_shop_screen üstündeki not - diriltme satın alınmadan
	## kapatıldıysa (hâlâ kalıcı ölü) gizlenen ölüm ekranı tekrar görünür
	## olur; satın alındıysa _revive_local_player() onu zaten tamamen silmiş
	## olduğu için is_instance_valid burada false döner, no-op.
	if _death_overlay_layer and is_instance_valid(_death_overlay_layer):
		_death_overlay_layer.visible = true
	## bkz. _on_team_leveled_up üstündeki not - mola sırasında kuyruğa
	## alınmış bir level-up varsa, mola biter bitmez hemen gösterilsin -
	## aksi halde _pending_level_ups sonsuza dek boşaltılmadan kalırdı.
	if _pending_level_ups > 0:
		_advance_level_up_queue()


## bkz. _chest_wait_overlay ile AYNI görsel desen - periyodik dükkan
## molasında çok oyunculuda "herkes kapatana kadar" bekleme ekranı.
func _show_mini_shop_wait_overlay() -> void:
	if _mini_shop_wait_overlay and is_instance_valid(_mini_shop_wait_overlay):
		return
	_mini_shop_wait_overlay = CanvasLayer.new()
	_mini_shop_wait_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_mini_shop_wait_overlay.layer = 90
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini_shop_wait_overlay.add_child(dim)
	_mini_shop_wait_label = Label.new()
	_mini_shop_wait_label.text = "Diğer oyuncular alışverişi bitiriyor...\nLütfen bekleyin"
	_mini_shop_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mini_shop_wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mini_shop_wait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini_shop_wait_label.offset_bottom = -40.0
	_mini_shop_wait_label.add_theme_font_size_override("font_size", 28)
	_mini_shop_wait_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_mini_shop_wait_overlay.add_child(_mini_shop_wait_label)
	_mini_shop_wait_countdown_label = Label.new()
	_mini_shop_wait_countdown_label.text = "%ds" % int(ceil(NetworkManager.mini_shop_countdown)) if NetworkManager.mini_shop_timer_active else ""
	_mini_shop_wait_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mini_shop_wait_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mini_shop_wait_countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini_shop_wait_countdown_label.offset_top = 40.0
	_mini_shop_wait_countdown_label.add_theme_font_size_override("font_size", 32)
	_mini_shop_wait_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_mini_shop_wait_overlay.add_child(_mini_shop_wait_countdown_label)
	add_child(_mini_shop_wait_overlay)


func _hide_mini_shop_wait_overlay() -> void:
	if _mini_shop_wait_overlay and is_instance_valid(_mini_shop_wait_overlay):
		_mini_shop_wait_overlay.queue_free()
	_mini_shop_wait_overlay = null
	_mini_shop_wait_countdown_label = null
	_mini_shop_wait_label = null


func _on_mini_shop_countdown_tick(remaining: float) -> void:
	if _mini_shop_wait_countdown_label and is_instance_valid(_mini_shop_wait_countdown_label):
		_mini_shop_wait_countdown_label.text = "%ds" % int(ceil(remaining))
	_update_mini_shop_countdown_notice(remaining)


## Kullanıcı isteği: "bir kişi dükkanda çarpıya basınca diğerlerinin bekleme
## süresi başlayacak." - dükkanı KAPATAN oyuncu sayacı zaten _mini_shop_wait_
## overlay içinde görüyor; dükkanı HÂLÂ AÇIK olan oyuncular da ne kadar
## süreleri kaldığını görsün diye küçük, TIKLAMAYI ENGELLEMEYEN bir bildirim
## gösterilir (dim yok, mouse_filter IGNORE - alışverişe devam edilebilsin).
## Yalnızca İLK kapatmadan SONRA ortaya çıkar (bkz. is_mini_shop_wait_started):
## dükkan açılışında başlayan sayaç sadece "kimse dokunmazsa oyun donmasın"
## güvenlik ağıdır, bekleme süresi değildir.
func _update_mini_shop_countdown_notice(remaining: float) -> void:
	if not _mini_shop_pause_active or _mini_shop_closed_locally or not NetworkManager.is_mini_shop_wait_started():
		_hide_mini_shop_countdown_notice()
		return
	if _mini_shop_countdown_notice == null or not is_instance_valid(_mini_shop_countdown_notice):
		_mini_shop_countdown_notice = CanvasLayer.new()
		_mini_shop_countdown_notice.process_mode = Node.PROCESS_MODE_ALWAYS
		_mini_shop_countdown_notice.layer = 94 ## dükkanın (HUD katmanı) üstünde
		_mini_shop_countdown_notice_label = Label.new()
		_mini_shop_countdown_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mini_shop_countdown_notice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_mini_shop_countdown_notice_label.offset_top = 24.0
		_mini_shop_countdown_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mini_shop_countdown_notice_label.add_theme_font_size_override("font_size", 26)
		_mini_shop_countdown_notice_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		_mini_shop_countdown_notice.add_child(_mini_shop_countdown_notice_label)
		add_child(_mini_shop_countdown_notice)
	_mini_shop_countdown_notice_label.text = "Bir oyuncu dükkanı kapattı - kalan süre: %ds" % int(ceil(remaining))


func _hide_mini_shop_countdown_notice() -> void:
	if _mini_shop_countdown_notice and is_instance_valid(_mini_shop_countdown_notice):
		_mini_shop_countdown_notice.queue_free()
	_mini_shop_countdown_notice = null
	_mini_shop_countdown_notice_label = null


func _show_level_up_screen(new_level: int) -> void:
	if is_instance_valid(player) and player.has_method("clear_input_state"):
		player.call("clear_input_state")
	hud.update_level(new_level)
	get_tree().paused = true
	## Kendi kartımızı seçip bir sonraki turu HEMEN (ağı beklemeden) açarken
	## (bkz. _advance_level_up_queue) çok kısa bir pencerede başka bir eşin
	## meşgul-durumu değişikliği (bkz. _on_level_up_busy_state_changed) bizi
	## hâlâ meşgulken bile "bekleme" overlay'ini göstermiş olabilir - kendi
	## ekranımız gerçekten açıldığında bunu kesin olarak temizliyoruz.
	_hide_level_up_wait_overlay()
	## DÜZELTME (kullanıcı isteği: "Dükkan her level atladığında açılıyor
	## sadece 5 dakika bekleme süresi dolunca level atladıktan sonra
	## çıkmalı.") - eskiden HER level atlamasında koşulsuz true'ydu; artık
	## SADECE GameManager'daki 5 dakikalık bekleme süresi dolmuşsa bu level
	## atlamasının sonunda dükkan açılacak (bkz. _resume_gameplay_after_
	## level_flow), aksi halde oyun normal şekilde devam eder.
	_mini_shop_pending_after_level_up = GameManager.is_mini_shop_cooldown_ready()
	var screen = LevelUpScreenScene.instantiate()
	screen.name = "LevelUpScreen"
	add_child(screen)
	screen.upgrade_chosen.connect(_on_upgrade_chosen)
	_active_level_up_screen = screen
	if NetworkManager.is_multiplayer_active:
		NetworkManager.set_level_up_busy(true)
		NetworkManager.start_level_up_countdown()


## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini beklemeden
## tüm kartlarını falan seçebilsin FAKAT hepsini seçtikten sonra bekleme
## süresi başlayacak") - eskiden multiplayer'da burada ekran hiç kapanmıyor,
## NetworkManager.mark_local_upgrade_chosen() ile TÜM oyuncular o TEK turu
## bitirene kadar bekleniyordu - kendi kuyruğunda 5 kart olan bir oyuncu bile
## HER kartı diğer oyuncu(lar) aynı turu bitirmeden bir sonrakini
## GÖREMİYORDU. Artık singleplayer/multiplayer FARK ETMEKSİZİN ekran hemen
## kapanıp _advance_level_up_queue çağrılıyor - o fonksiyon, bu oyuncunun
## kendi kuyruğu bitmediyse ağı hiç beklemeden bir sonraki kartı hemen açar;
## kuyruk BİTTİYSE ancak o zaman (ve sadece o zaman) ağa "meşgul değilim"
## diye bildirir.
func _on_upgrade_chosen(id: String, tier: int) -> void:
	if is_instance_valid(player):
		player.apply_upgrade(id, tier)
	if _active_level_up_screen != null and is_instance_valid(_active_level_up_screen):
		_active_level_up_screen.queue_free()
	_active_level_up_screen = null
	_advance_level_up_queue()


func _advance_level_up_queue() -> void:
	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		call_deferred("_show_level_up_screen", GameManager.team_level)
	else:
		## Kullanıcı isteği: "alınan sandığın avatarın yanında simgesi
		## görünsün, level atlayınca biriken sandıklar otomatik açılsın" -
		## kuyruktaki TÜM seviye atlama ekranları bitince (yani burada
		## artık bekleyen bir sonraki yok), biriken sandıklar sırayla açılır.
		## DÜZELTME (kullanıcı isteği: "level aralarında gelen silah
		## seçimlerini kaldır, sadece ilk levelde silah ve kalkan seçim ekranı
		## olacak") - burada 5/10/15/20. levellerde araya bir silah seçim
		## ekranı daha sokan kilometre taşı bloğu TAMAMEN kaldırıldı (bkz.
		## WeaponSelectScreenScript üstündeki not) - normal seviye atlama
		## kart(lar)ı bitince artık doğrudan sandık kuyruğuna geçiliyor.
		## bkz. _chest_queue_batch_start_msec üstündeki BUG DÜZELTMESİ notu -
		## bu, taze bir sandık kuyruğu turunun BAŞLANGICI (level atlama
		## kart(lar)ı burada zaten bitti).
		_chest_queue_batch_start_msec = Time.get_ticks_msec()
		_finish_level_up_phase(_try_open_next_pending_chest)


## Bu oyuncunun kart/silah/kalkan seçim kuyruğu TAMAMEN bitti (bkz.
## _advance_level_up_queue/_finish_item_select_chain) - chest_busy_peers/
## _try_open_next_pending_chest'teki AYNI desen (bkz. network_manager.gd
## "KART/SİLAH/KALKAN SEÇİM KUYRUĞU SENKRONİZASYONU" notu): EN SON biten
## oyuncu da bitirene kadar next_step çağrılmaz, o ana kadar bir bekleme
## overlay'i gösterilir (bkz. _on_level_up_busy_state_changed).
func _finish_level_up_phase(next_step: Callable) -> void:
	if not NetworkManager.is_multiplayer_active:
		next_step.call()
		return
	NetworkManager.set_level_up_busy(false)
	if not NetworkManager.is_any_level_up_busy():
		NetworkManager.stop_level_up_countdown()
		_hide_level_up_wait_overlay()
		next_step.call()
	else:
		_level_up_wait_resume_action = next_step
		_show_level_up_wait_overlay()


## Herhangi bir eşte (kendimiz DAHİL) kart/silah/kalkan kuyruğu meşgul/boş
## durumu değiştiğinde tetiklenir - bkz. _on_chest_busy_state_changed ile
## AYNI desen. Kendi ekranımız (level-up kartı ya da silah/kalkan seçimi)
## hâlâ açıksa burada ekstra bir şey yapmaya gerek yok - o akış zaten kendi
## paused/overlay durumunu yönetiyor.
func _on_level_up_busy_state_changed() -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	if NetworkManager.is_any_level_up_busy():
		get_tree().paused = true
		if _active_level_up_screen == null and _active_item_select_screen == null:
			_show_level_up_wait_overlay()
	else:
		_hide_level_up_wait_overlay()
		## Artık kimse meşgul değil - bu oyuncunun kendi kuyruğu daha önce
		## bitip bekleyen bir devam adımı varsa (bkz. _finish_level_up_phase)
		## şimdi tetiklenir. Kuyruğumuz henüz bitmediyse (bu sinyal başka bir
		## eşin durumu yüzünden geldiyse) _level_up_wait_resume_action zaten
		## boş, hiçbir şey olmaz.
		if _level_up_wait_resume_action.is_valid():
			var action: Callable = _level_up_wait_resume_action
			_level_up_wait_resume_action = Callable()
			action.call()


## Bekleyen sandıklardan (bkz. GameManager.pending_chest_tiers -
## chest_drop.gd/NetworkManager.open_chest_for_peer artık dokunulduğu anda
## açmıyor, buraya ekliyor) bir sonrakini açar; o menü kapanınca (bkz.
## chest_menu.gd "closed" sinyali) kendini tekrar çağırıp kuyruk bitene kadar
## SIRAYLA devam eder - aynı anda birden fazla sandık menüsü üst üste
## açılmasın diye.
## #58 DÜZELTME (kullanıcı bildirimi: "sandık açılımı esnasında oyun diğer
## oyuncularda devam ediyor gibi görünüyor"): sandık kuyruğu HER oyuncuda
## AYRI/YEREL işliyor (biri 3 sandık toplamış, biri 1 - bkz. GameManager.
## pending_chest_tiers, ağdan bağımsız yerel bir liste), yani biri kendi
## kuyruğunu bitirip get_tree().paused = false yapınca bu SADECE kendi
## ekranını açıyordu - host'sa yaratık simülasyonu, değilse hareketi hemen
## devam ediyordu, diğer oyuncular hâlâ kart seçiyor olsa bile (level_up_
## pending_peers'ın AKSİNE bu hiç ağa duyurulmuyordu). Artık "meşgul" durumu
## NetworkManager.chest_busy_peers ile TÜM peer'lere bildiriliyor - hiçbir
## oyuncu, kuyruğu hâlâ dolu olan EN SON oyuncu da bitirene kadar devam
## edemiyor (bkz. _on_chest_busy_state_changed).
## bkz. _mini_shop_pending_after_level_up üstündeki not - level atlama +
## kilometre taşı + sandık akışının TAMAMEN bittiği HER çıkış noktasında
## (bkz. aşağıdaki 4 çağrı) doğrudan get_tree().paused = false yerine bu
## çağrılır: bir level atlamasından geliniyorsa oyunu açmak yerine periyodik
## dükkanı açar, değilse (ör. bağımsız bir sandık toplamasından geliniyorsa)
## eskisi gibi doğrudan oyunu açar.
func _resume_gameplay_after_level_flow() -> void:
	if not (_mini_shop_pending_after_level_up and is_instance_valid(player)):
		_mini_shop_pending_after_level_up = false
		get_tree().paused = false
		return
	## Bir level atlama akışından geliniyor: periyodik dükkan açılacak mı?
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		## CLIENT: kararı host verir (bkz. yukarıdaki not) - host'un kararı çoktan
		## gelmişse hemen uygula, gelmediyse kısa süre bekle.
		if _mini_shop_decision_received:
			_apply_mini_shop_decision(_mini_shop_decision_open)
		else:
			_awaiting_mini_shop_decision = true
			## NOT: create_timer varsayılan olarak process_always=true ile
			## oluşturulur, yani oyun DURAKLATILMIŞKEN (bu akışta olduğu gibi)
			## de sayar - buradaki bekleme için tam istediğimiz davranış.
			get_tree().create_timer(MINI_SHOP_DECISION_WAIT).timeout.connect(_on_mini_shop_decision_timeout)
		return
	## HOST (veya tek oyunculu): karar burada verilir ve tüm peer'lere yayınlanır.
	## Uygulama _apply_mini_shop_decision'a bırakılıyor ki host ve client
	## yolları AYNI korumalardan geçsin (ör. dükkan zaten açıkken duraklamayı
	## bozmamak).
	var open_shop: bool = GameManager.is_mini_shop_cooldown_ready()
	_mini_shop_pending_after_level_up = false
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_mini_shop_decision(open_shop)
	_apply_mini_shop_decision(open_shop)


## Host'un (veya tek oyunculuda yerel) kararını uygular: dükkan açılacaksa
## _show_mini_shop_screen (bu arada kendi 5 dakikalık bekleme süresini de
## sıfırlar), açılmayacaksa oyun kaldığı yerden devam eder.
func _apply_mini_shop_decision(open_shop: bool) -> void:
	_mini_shop_pending_after_level_up = false
	_awaiting_mini_shop_decision = false
	_mini_shop_decision_received = false
	if open_shop:
		## Dükkan zaten açıksa (ör. ilk yükleme akışından kalma) duraklamayı
		## bozmadan çık - ikinci kez açmaya çalışmak panel/sayaç durumunu
		## bozardı.
		if not _mini_shop_pause_active:
			_show_mini_shop_screen()
		return
	## "Açılmayacak" kararı geldi: dükkan açıkken gelirse mevcut duraklamayı
	## (ve açık dükkanı) bozma, sadece oyun devam ederken değişiklik yapma.
	if _mini_shop_pause_active:
		return
	get_tree().paused = false


func _on_mini_shop_decision_received(open_shop: bool) -> void:
	_mini_shop_decision_received = true
	_mini_shop_decision_open = open_shop
	## Karar akış BİTMEDEN geldiyse sadece saklanır; _resume_gameplay_after_
	## level_flow onu bulup uygular (host'un akışı bizden önce bitmiş olabilir).
	if _awaiting_mini_shop_decision:
		_apply_mini_shop_decision(open_shop)


func _on_mini_shop_decision_timeout() -> void:
	if not _awaiting_mini_shop_decision:
		return
	## Host'tan haber gelmedi (kopma/host değişimi olabilir) - oyunu askıda
	## bırakmamak için yerel karara düşülür.
	_apply_mini_shop_decision(GameManager.is_mini_shop_cooldown_ready())


func _try_open_next_pending_chest() -> void:
	## bkz. _chest_queue_batch_start_msec üstündeki BUG DÜZELTMESİ notu - bu
	## turun toplam süresi üst sınırı aştıysa, kalan sandıkları sırada
	## bırakıp (bir sonraki seviye atlamasında devam eder, kaybolmazlar) oyunu
	## hemen devam ettir.
	if _chest_queue_batch_start_msec >= 0 and Time.get_ticks_msec() - _chest_queue_batch_start_msec > CHEST_QUEUE_TOTAL_TIMEOUT_MSEC:
		push_warning("[Main] Sandık kuyruğu %.0f sn'yi aştı, kalanlar sırada bırakılıp oyun devam ettiriliyor." % (CHEST_QUEUE_TOTAL_TIMEOUT_MSEC / 1000.0))
		_chest_queue_batch_start_msec = -1
		_local_chest_menu_open = false
		if NetworkManager.is_multiplayer_active:
			NetworkManager.set_chest_busy(false)
			if not NetworkManager.is_any_chest_busy():
				_resume_gameplay_after_level_flow()
				NetworkManager.stop_chest_countdown()
		else:
			_resume_gameplay_after_level_flow()
		return
	if not GameManager.has_pending_chests() or not is_instance_valid(player):
		_chest_queue_batch_start_msec = -1
		_local_chest_menu_open = false
		if NetworkManager.is_multiplayer_active:
			NetworkManager.set_chest_busy(false)
			if not NetworkManager.is_any_chest_busy():
				_resume_gameplay_after_level_flow()
				## Kuyrukta hiçbir peer'de sandık kalmadı - bkz. NetworkManager
				## "SANDIK SEÇİM GERİ SAYIMI" notu, geri sayımın da bitmesi gerekiyor.
				NetworkManager.stop_chest_countdown()
		else:
			## Kuyruk gerçekten bitti (bkz. #18 yorumu yukarıda) - level atlama +
			## sandık açılışı akışının TAMAMI şimdi bitti, oyun burada açılır (ya
			## da bkz. _resume_gameplay_after_level_flow - bir level atlamasından
			## geliniyorsa oyun yerine periyodik dükkan açılır).
			_resume_gameplay_after_level_flow()
		return
	## Güvenlik: bu noktaya her zaman zaten duraklamış (level atlama
	## ekranından) gelinir, ama garanti olsun diye açıkça set ediliyor.
	get_tree().paused = true
	_local_chest_menu_open = true
	if NetworkManager.is_multiplayer_active:
		NetworkManager.set_chest_busy(true)
		## Kullanıcı isteği: "sandık seçerken diğer oyuncularda ve sandık
		## seçen kişide 25 saniyelik bekleme süresi olmuyor, onun da bekleme
		## süresi olması gerekiyor, tıpkı level kartı seçme ekranı gibi" -
		## her yeni sandık menüsü açıldığında geri sayım (yeniden) 25sn'ye
		## başlar (bkz. chest_menu.gd _on_countdown_tick).
		NetworkManager.start_chest_countdown()
	_hide_chest_wait_overlay()
	var tier: int = GameManager.pop_pending_chest()
	var menu: CanvasLayer = ChestMenuScene.instantiate() as CanvasLayer
	add_child(menu)
	if menu.has_method("setup"):
		menu.setup(player, tier)
	if menu.has_signal("closed"):
		menu.closed.connect(_try_open_next_pending_chest, CONNECT_ONE_SHOT)


## Diğer bir oyuncunun sandık kuyruğu meşgul/boş durumu değiştiğinde (bkz.
## NetworkManager.set_chest_busy) TÜM peer'lerde (kendi "call_local"
## yayınımız DAHİL) tetiklenir. Kendi sandık menümüz zaten açıksa (bkz.
## _local_chest_menu_open) burada ekstra bir şey yapmaya gerek yok - onun
## akışı zaten paused/overlay durumunu kendi başına yönetiyor.
func _on_chest_busy_state_changed() -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	if NetworkManager.is_any_chest_busy():
		get_tree().paused = true
		if not _local_chest_menu_open:
			_show_chest_wait_overlay()
	else:
		if not _local_chest_menu_open:
			get_tree().paused = false
		_hide_chest_wait_overlay()


func _show_chest_wait_overlay() -> void:
	if _chest_wait_overlay and is_instance_valid(_chest_wait_overlay):
		return
	_chest_wait_overlay = CanvasLayer.new()
	_chest_wait_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_chest_wait_overlay.layer = 90
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_chest_wait_overlay.add_child(dim)
	_chest_wait_label = Label.new()
	## Kullanıcı isteği: "kimi beklediğimiz yazsın" - bkz. network_manager.gd
	## get_chest_busy_names, aynı desen level_up_screen.gd/mini_shop_screen.gd
	## ile paylaşılıyor.
	_chest_wait_label.text = _chest_wait_message()
	_chest_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chest_wait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_wait_label.offset_bottom = -40.0
	_chest_wait_label.add_theme_font_size_override("font_size", 28)
	_chest_wait_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_chest_wait_overlay.add_child(_chest_wait_label)
	## Kullanıcı isteği: level kartı seçme ekranındaki "Diğer oyuncular
	## bekleniyor" panelindeki geri sayımla AYNI fikir - bekleyen oyuncular da
	## kararın en fazla ne kadar süreceğini görsün (bkz. NetworkManager
	## chest_countdown_tick / _on_chest_countdown_tick).
	_chest_wait_countdown_label = Label.new()
	_chest_wait_countdown_label.text = "%ds" % int(ceil(NetworkManager.chest_countdown)) if NetworkManager.chest_countdown_active else ""
	_chest_wait_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_wait_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chest_wait_countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_wait_countdown_label.offset_top = 40.0
	_chest_wait_countdown_label.add_theme_font_size_override("font_size", 32)
	_chest_wait_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_chest_wait_overlay.add_child(_chest_wait_countdown_label)
	add_child(_chest_wait_overlay)


func _hide_chest_wait_overlay() -> void:
	if _chest_wait_overlay and is_instance_valid(_chest_wait_overlay):
		_chest_wait_overlay.queue_free()
	_chest_wait_overlay = null
	_chest_wait_countdown_label = null
	_chest_wait_label = null


func _chest_wait_message() -> String:
	var names: String = NetworkManager.get_chest_busy_names() if NetworkManager.is_multiplayer_active else ""
	if names != "":
		return "Sandık ödülü seçiliyor: %s\nLütfen bekleyin" % names
	return "Bir oyuncu sandık ödülünü seçiyor...\nLütfen bekleyin"


func _on_chest_countdown_tick(remaining: float) -> void:
	if _chest_wait_countdown_label and is_instance_valid(_chest_wait_countdown_label):
		_chest_wait_countdown_label.text = "%ds" % int(ceil(remaining))
	if _chest_wait_label and is_instance_valid(_chest_wait_label):
		_chest_wait_label.text = _chest_wait_message()


## Host bir yeniden başlatma isteği gönderdiğinde (bkz. pause_menu.gd
## _on_restart/network_manager.gd request_restart_vote) HER client'ta
## (host'un kendisi HARİÇ - o isteği zaten kendi onayıyla başlattı)
## tetiklenir - pause menüsü açık olmasa bile görünmesi gerektiği için
## (host oyuncu her an yeniden başlatabilir) main.gd'nin kendi her-zaman-
## aktif katmanında, ayrı bir onay diyaloğu olarak gösteriliyor.
var _restart_confirm_dialog: CanvasLayer = null
## bkz. _show_death_overlay/_on_death_overlay_restart_pressed - ölüm
## overlay'indeki "Yeniden Başla" butonuna referans, host onay beklerken
## metnini/disabled durumunu güncelleyebilmek için (bkz. _on_restart_vote_result).
var _death_overlay_restart_btn: Button = null

func _on_restart_request_received() -> void:
	if _restart_confirm_dialog and is_instance_valid(_restart_confirm_dialog):
		return
	get_tree().paused = true
	_restart_confirm_dialog = CanvasLayer.new()
	_restart_confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_restart_confirm_dialog.layer = 95
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_confirm_dialog.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.09, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.6, 0.45, 0.2, 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	_restart_confirm_dialog.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "Host oyunu yeniden başlatmak istiyor.\nOnaylarsanız herkes odaya dönüp\nkarakterini yeniden seçecek. Onaylıyor musunuz?"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var approve_btn := Button.new()
	approve_btn.text = "Onayla"
	approve_btn.custom_minimum_size = Vector2(140, 44)
	approve_btn.add_theme_font_size_override("font_size", 20)
	ShopPanel._apply_wood_button_style(approve_btn)
	approve_btn.pressed.connect(func():
		NetworkManager.submit_restart_vote(true)
		_hide_restart_confirm_dialog()
	)
	btn_row.add_child(approve_btn)

	var reject_btn := Button.new()
	reject_btn.text = "Reddet"
	reject_btn.custom_minimum_size = Vector2(140, 44)
	reject_btn.add_theme_font_size_override("font_size", 20)
	ShopPanel._apply_wood_button_style(reject_btn)
	reject_btn.pressed.connect(func():
		NetworkManager.submit_restart_vote(false)
		_hide_restart_confirm_dialog()
	)
	btn_row.add_child(reject_btn)

	add_child(_restart_confirm_dialog)
	UISound.connect_all_buttons(_restart_confirm_dialog)


func _hide_restart_confirm_dialog() -> void:
	if _restart_confirm_dialog and is_instance_valid(_restart_confirm_dialog):
		_restart_confirm_dialog.queue_free()
	_restart_confirm_dialog = null


## Oylama sonucu (bkz. network_manager.gd _rpc_broadcast_restart_vote_result) -
## TÜM peer'lerde (host dahil, "call_local") tetiklenir. Onaylandıysa
## NetworkManager._return_to_lobby_for_restart() herkesi odaya (lobi) döndürür
## (duraklatmayı da orada kaldırır), burada ekstra bir şey yapmaya gerek yok.
## Reddedildiyse/zaman aşımına uğradıysa oyun kaldığı yerden devam eder.
func _on_restart_vote_result(approved: bool, rejecter_name: String) -> void:
	_hide_restart_confirm_dialog()
	## bkz. pause_menu.gd'nin AYNI restart_vote_result dinleyicisi - oylama
	## reddedilirse/zaman aşımına uğrarsa (ya da onaylanırsa, sahne zaten
	## değişeceği için zararsız) ölüm overlay'indeki buton "Onay bekleniyor..."
	## donuk halinde kalmasın.
	if _death_overlay_restart_btn and is_instance_valid(_death_overlay_restart_btn):
		_death_overlay_restart_btn.disabled = false
		_death_overlay_restart_btn.text = "Yeniden Başla"
	if approved:
		return
	get_tree().paused = false
	if rejecter_name != "":
		_show_network_toast("%s yeniden başlatmayı reddetti." % rejecter_name)
	else:
		_show_network_toast("Yeniden başlatma onaylanmadı (süre doldu).")


## _show_chest_wait_overlay ile BİREBİR AYNI görsel desen - kart/silah/kalkan
## seçim kuyruğu için (bkz. _finish_level_up_phase).
func _show_level_up_wait_overlay() -> void:
	if _level_up_wait_overlay and is_instance_valid(_level_up_wait_overlay):
		return
	_level_up_wait_overlay = CanvasLayer.new()
	_level_up_wait_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_level_up_wait_overlay.layer = 90
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_level_up_wait_overlay.add_child(dim)
	_level_up_wait_label = Label.new()
	_level_up_wait_label.text = _level_up_wait_message()
	_level_up_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_up_wait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_up_wait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_up_wait_label.offset_bottom = -40.0
	_level_up_wait_label.add_theme_font_size_override("font_size", 28)
	_level_up_wait_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_level_up_wait_overlay.add_child(_level_up_wait_label)
	_level_up_wait_countdown_label = Label.new()
	_level_up_wait_countdown_label.text = "%ds" % int(ceil(NetworkManager.level_up_countdown)) if NetworkManager.level_up_timer_active else ""
	_level_up_wait_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_up_wait_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_up_wait_countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_up_wait_countdown_label.offset_top = 40.0
	_level_up_wait_countdown_label.add_theme_font_size_override("font_size", 32)
	_level_up_wait_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_level_up_wait_overlay.add_child(_level_up_wait_countdown_label)
	add_child(_level_up_wait_overlay)


func _hide_level_up_wait_overlay() -> void:
	if _level_up_wait_overlay and is_instance_valid(_level_up_wait_overlay):
		_level_up_wait_overlay.queue_free()
	_level_up_wait_overlay = null
	_level_up_wait_countdown_label = null
	_level_up_wait_label = null


func _level_up_wait_message() -> String:
	var names: String = NetworkManager.get_level_up_busy_names() if NetworkManager.is_multiplayer_active else ""
	if names != "":
		return "Seçim yapılıyor: %s\nLütfen bekleyin" % names
	return "Bir oyuncu seçim yapıyor...\nLütfen bekleyin"


func _on_level_up_countdown_tick(remaining: float) -> void:
	if _level_up_wait_countdown_label and is_instance_valid(_level_up_wait_countdown_label):
		_level_up_wait_countdown_label.text = "%ds" % int(ceil(remaining))
	if _level_up_wait_label and is_instance_valid(_level_up_wait_label):
		_level_up_wait_label.text = _level_up_wait_message()



func _on_multiplayer_server_disconnected() -> void:
	if not is_inside_tree():
		return
	push_warning("[Main] Sunucu/Host bağlantısı kesildi.")
	_show_network_toast("Sunucu bağlantısı koptu. Ana menüye dönülüyor...")
	_return_to_menu_after_disconnect()


## Host odayı kapatıp (bkz. pause_menu.gd _on_menu) close_room() çağırdığında
## (veya bağlantısı koptuğunda) SADECE client'larda tetiklenir - kullanıcı
## bildirimi: "katılımcılar ... donuk vaziyette kalıyor olduğu yerde" artık
## net bir bildirimle ana menüye yönlendiriliyorlar.
## bkz. network_manager.gd grant_revive_invulnerability üstündeki not - bu
## RPC hedefli olduğu için sadece GERÇEKTEN dirilten kişinin istemcisinde
## tetiklenir, kendi (yerel) player'ına buff'ı burada uygular.
func _on_revive_invulnerability_granted(duration: float) -> void:
	if player and is_instance_valid(player) and player.has_method("grant_revive_invulnerability"):
		player.grant_revive_invulnerability(duration)


func _on_host_left_game() -> void:
	if not is_inside_tree():
		return
	_show_network_toast("Host oyundan ayrıldı. Ana menüye dönülüyor...")
	_return_to_menu_after_disconnect()


func _on_player_left_game(p_name: String, peer_id: int = 0) -> void:
	if not is_inside_tree():
		return
	_show_network_toast("%s oyundan ayrıldı." % p_name)
	_despawn_remote_player(peer_id)


## DÜZELTME (kullanıcı bildirimi: "necromancer oynayınca yaratıklar bazen
## kopyalanıyor ve insanlar rasgele oyundan atılıyor") - bkz. network_
## manager.gd _on_peer_disconnected üstündeki ayrıntılı not. Ayrılan/atılan
## oyuncunun RemotePlayer kuklası ve üstündeki TÜM necromancer/Matthew pet
## kozmetik kopyaları (bkz. remote_player.gd _pet_visuals, bunlar
## RemotePlayer'ın ÇOCUĞU DEĞİL, sahnenin köküne eklendiği için RemotePlayer
## queue_free() edilince kendiliğinden silinmezler - önce _despawn_pet_
## visual() ile açıkça temizlenmeleri gerekiyor) artık gerçekten sahneden
## kaldırılıyor - aksi halde biri atılıp yeniden bağlandığında eski
## (hayalet) kukla+yaratıkları donuk kalmaya devam edip yenileriyle yan yana
## görünüyordu.
func _despawn_remote_player(peer_id: int) -> void:
	if peer_id <= 0 or not _remote_players.has(peer_id):
		return
	var rp = _remote_players[peer_id]
	_remote_players.erase(peer_id)
	if is_instance_valid(rp):
		if rp.has_method("_despawn_pet_visual"):
			rp._despawn_pet_visual()
		rp.queue_free()


func _return_to_menu_after_disconnect() -> void:
	get_tree().paused = false
	var timer: SceneTreeTimer = get_tree().create_timer(1.6)
	timer.timeout.connect(func():
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)


## Basit, kendi kendini yok eden bir üst-orta bildirim etiketi (bkz.
## kullanıcı bildirimi: "oyundan çıktığını gösteren bir bildirim yok").
## Herhangi bir sahneye/panele bağımlı değil - doğrudan Main'e eklenir.
func _show_network_toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.92)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.6, 0.45, 0.2, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	## Kullanıcı isteği: "altın gönderildi bildiriminin dükkan butonunun
	## altında görünmesini istiyorum" - eskiden ekranın üst-ortasında
	## duruyordu ve hud.tscn'deki dükkan/envanter butonlarının (GoldIndicator,
	## sağ üstte) üzerine biniyordu. Artık sağ üstte, GoldIndicator'ın hemen
	## altında beliriyor (bkz. hud.gd _layout_shop_inventory_buttons -
	## GoldIndicator sağdan 178-10px, alt kenarı ~280px'te bitiyor).
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_top = 292
	panel.offset_left = -270
	panel.offset_right = -10
	layer.add_child(panel)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	panel.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)


## Seyyar satıcı (bkz. traveling_merchant.gd/network_manager.gd merchant_
## spawned/merchant_departed) - kullanıcı isteği: "dükkan geldiğinde
## oyunculara bildirim gelir ve ne tarafta olduğu haritada işaretle
## gösterilir." Bu iki fonksiyon HER peer'de (host dahil, "call_local")
## çalışır - bkz. _show_network_toast'ın AYNI local-only doğası.
## DÜZELTME (kullanıcı bildirimi: "seyyar satıcı bildirimi hala gelmiyor,
## ayrılınca bildiriliyor ama gelince bildirilmiyor, ne haritada ne de ok
## ile gösteriliyor") - kök neden: NetworkManager.merchant_spawned TİPLİ bir
## sinyal olarak `signal merchant_spawned(pos: Vector2, stock: Array)`
## şeklinde tanımlı (bkz. o dosya), ama bu handler SADECE `pos` alıyordu.
## Godot'un tipli sinyallerinde bu imza uyuşmazlığı bağlanan çağrılabiliri
## HİÇ ÇALIŞTIRMADAN sessizce başarısız oluyor - toast/minimap/ok üçü de bu
## yüzden birden hiç tetiklenmiyordu. merchant_departed parametresiz
## (birebir eşleşiyor) olduğu için o sorunsuz çalışıyordu - "ayrılınca
## bildiriliyor ama gelince bildirilmiyor" şikayeti tam olarak buydu.
func _on_merchant_spawned(pos: Vector2, _stock: Array) -> void:
	_show_network_toast("Bir seyyar satıcı haritada belirdi! Konumu haritada işaretlendi.")
	var minimap: Node = hud.get_node_or_null("MinimapControl")
	if minimap and minimap.has_method("set_merchant_marker"):
		minimap.set_merchant_marker(pos, true)
	if _merchant_arrow and is_instance_valid(_merchant_arrow):
		_merchant_arrow.set_target_active(pos, true)


func _on_merchant_departed() -> void:
	_show_network_toast("Seyyar satıcı haritadan ayrıldı.")
	var minimap: Node = hud.get_node_or_null("MinimapControl")
	if minimap and minimap.has_method("set_merchant_marker"):
		minimap.set_merchant_marker(Vector2.ZERO, false)
	if _merchant_arrow and is_instance_valid(_merchant_arrow):
		_merchant_arrow.set_target_active(Vector2.ZERO, false)


func _on_player_died() -> void:
	## Kullanıcı isteği: "host öldükten sonra eğer can kalmadıysa diğer
	## karakterle hayattaysa bile oyun kapanıyor, son karakter de ölmeden
	## oyun bitmemeli." Kök neden: bu fonksiyon "died" sinyaline bağlıydı ve
	## HANGİ oyuncu (host dahil) kalıcı olarak ölürse ölsün koşulsuz olarak
	## tüm lobiye oyun bitti mesajı yayınlıyordu. Artık "died" sinyali SADECE
	## bir oyuncu KALICI olarak öldüğünde tetikleniyor (reviveler tükendiyse
	## - bkz. player.gd die()/NetworkManager.try_use_revive).
	##
	## DÜZELTME (kullanıcı bildirimi: "ölüm ekranı yok ölünce hiçbir gösterge
	## v.s yok"): eskiden multiplayer'da burası SADECE oyun biterse (herkes
	## öldüyse) bir RPC yollayıp hiçbir görsel geri bildirim vermeden
	## return ediyordu - kod içinde bile "TODO: Show a spectate/you died
	## overlay" notu duruyordu, yani hiç yapılmamıştı. Artık ölen oyuncuya
	## HER durumda (tek oyunculu + çok oyunculu, takım hâlâ hayattaysa da,
	## oyun tamamen bittiyse de) bir ekran göstergesi çıkıyor - bkz.
	## _show_death_overlay.
	##
	## DÜZELTME (kullanıcı bildirimi: "herkes ölünce oyun bitmiyor bazen
	## bianda biri canlanıp bianda yok oluyor istatistikleri göremiyoruz") -
	## "herkes öldü mü" kararı BURADA (her ölen oyuncunun KENDİ yerel
	## remote_player görüntüsüne bakarak) verilmiyor artık - o görüntü genel
	## extra_state senkronunun bir PARÇASI olduğu için bayat olabiliyordu ve
	## kontrol sadece bir kez yapılıp asla tekrarlanmıyordu, bu yüzden oyun
	## bazen hiç bitmiyordu. Artık kalıcı ölüm SADECE host'a bildiriliyor
	## (bkz. NetworkManager.report_self_permanently_dead/
	## _check_all_players_dead) - host KESİN kayıtlarına göre karar verip
	## gerekirse HERKESE (bkz. _on_game_over_synced) yayınlıyor. Bu istatistik
	## yayınını da (bkz. _broadcast_local_match_stats) artık üstlendiği için
	## burada ayrıca çağırmaya gerek yok.
	if NetworkManager.is_multiplayer_active:
		NetworkManager.report_self_permanently_dead()
		_show_death_overlay(false)
		return
	GameManager.is_game_over = true
	_record_local_match_stats()
	_show_death_overlay(true)
	## DÜZELTME (kullanıcı bildirimi: "oyun bitince hiçbir butona basılmıyor
	## alt-f4 atmamız gerekiyor. ayrıca ... istatistik penceresi ekleyip...")
	## - eskiden burada 1.5sn sonra OTOMATİK ana menüye dönülüyordu, yani
	## istatistikleri görmeye vakit bile yoktu. Artık overlay kendi başına
	## çalışan bir "Ana Menüye Dön" butonu içeriyor (bkz. _show_death_overlay/
	## _on_death_overlay_menu_pressed) - oyuncu istatistiklere bakıp kendi
	## isteğiyle çıkıyor, otomatik sahne değişimi kaldırıldı.


## Oyun sonu istatistik ekranı: KENDİ toplamlarımızı topluyor. Tek oyunculuda
## direkt yerel sözlüğe eklenir (yayına gerek yok - tek oyuncu var); çok
## oyunculuda herkese (kendimiz dahil, "call_local") yayınlanır.
func _record_local_match_stats() -> void:
	if not is_instance_valid(player):
		return
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var my_name: String = NetworkManager.local_player_name if NetworkManager.is_multiplayer_active else "Sen"
	_match_stats_by_peer[my_id] = {"name": my_name, "dealt": player.match_damage_dealt, "taken": player.match_damage_taken}
	_refresh_match_stats_ui()


func _broadcast_local_match_stats() -> void:
	if not is_instance_valid(player):
		return
	NetworkManager.sync_match_stats.rpc(multiplayer.get_unique_id(), NetworkManager.local_player_name, player.match_damage_dealt, player.match_damage_taken)


func _on_match_stats_received(peer_id: int, player_name: String, damage_dealt: float, damage_taken: float) -> void:
	_match_stats_by_peer[peer_id] = {"name": player_name, "dealt": damage_dealt, "taken": damage_taken}
	_refresh_match_stats_ui()


## bkz. scripts/network_manager.gd chat_message_received notu - gelen HER
## mesajı (kendi yerel yankımız DAHİL, "call_local" RPC sayesinde) hud.gd'nin
## sol chat penceresine ekler VE doğru karakterin üstünde mini balonu
## tetikler: gönderen BİZSEK (peer_id kendi id'mizle eşleşiyorsa, ya da
## multiplayer hiç aktif değilse) yerel player, değilse eşleşen RemotePlayer.
func _on_chat_message_received(peer_id: int, player_name: String, text: String) -> void:
	if hud and hud.has_method("append_chat_message"):
		hud.append_chat_message(player_name, text)
	var my_id: int = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active else 0
	if not NetworkManager.is_multiplayer_active or peer_id == my_id:
		if is_instance_valid(player) and player.has_method("show_chat_bubble"):
			player.show_chat_bubble(text)
	else:
		var rp: RemotePlayer = _get_remote_player(peer_id)
		if rp and is_instance_valid(rp) and rp.has_method("show_chat_bubble"):
			rp.show_chat_bubble(text)


## Oyun sonu istatistik ekranındaki tabloyu (isim | verdiği hasar | tankladığı
## hasar) o ana kadar toplanmış _match_stats_by_peer'den yeniden çizer -
## sonuçlar (özellikle multiplayer'da diğer peer'lerin RPC'si) art arda
## geldikçe her seferinde çağrılır, overlay henüz kurulmadıysa (is_final
## olmadan önce) sessizce no-op.
func _refresh_match_stats_ui() -> void:
	if not _death_overlay_layer or not is_instance_valid(_death_overlay_layer):
		return
	var grid: GridContainer = _death_overlay_layer.get_node_or_null("VBox/StatsBox/StatsGrid")
	if not grid:
		return
	for child in grid.get_children():
		child.queue_free()
	var header_col := Color(0.75, 0.7, 0.6)
	for header_text in ["Oyuncu", "Verdiği Hasar", "Tankladığı Hasar"]:
		var h := Label.new()
		h.text = header_text
		h.add_theme_font_size_override("font_size", 15)
		h.add_theme_color_override("font_color", header_col)
		grid.add_child(h)
	var peer_ids: Array = _match_stats_by_peer.keys()
	peer_ids.sort_custom(func(a, b): return float(_match_stats_by_peer[a]["dealt"]) > float(_match_stats_by_peer[b]["dealt"]))
	for peer_id in peer_ids:
		var entry: Dictionary = _match_stats_by_peer[peer_id]
		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.add_theme_font_size_override("font_size", 16)
		grid.add_child(name_lbl)
		var dealt_lbl := Label.new()
		dealt_lbl.text = "%d" % int(round(float(entry.get("dealt", 0.0))))
		dealt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dealt_lbl.add_theme_font_size_override("font_size", 16)
		dealt_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		grid.add_child(dealt_lbl)
		var taken_lbl := Label.new()
		taken_lbl.text = "%d" % int(round(float(entry.get("taken", 0.0))))
		taken_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		taken_lbl.add_theme_font_size_override("font_size", 16)
		taken_lbl.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
		grid.add_child(taken_lbl)


## bkz. pause_menu.gd::_on_menu() - ölüm overlay'indeki "Ana Menüye Dön"
## butonu, oyun bitmiş olsa bile (ui_cancel/ESC devre dışı kalsa bile, bkz.
## _process) çalışan tek bağımsız çıkış yolu. AYNI temizlik: multiplayer'da
## host ise odayı kapatır (diğerlerini de düzgünce koparır), değilse sadece
## kendi bağlantısını keser.
func _on_death_overlay_menu_pressed() -> void:
	get_tree().paused = false
	if NetworkManager.is_multiplayer_active:
		if NetworkManager.is_host:
			NetworkManager.close_room()
		else:
			NetworkManager.disconnect_from_room(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## bkz. _show_death_overlay üstündeki DÜZELTME notu - pause_menu.gd
## _on_restart() ile BİREBİR AYNI mantık (host-onaylı oylama), lobiye hiç
## dönmeden doğrudan bu ekrandan yeniden başlatmayı sağlıyor.
func _on_death_overlay_restart_pressed() -> void:
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host or NetworkManager.restart_vote_pending:
			return
		NetworkManager.request_restart_vote()
		get_tree().paused = true
		if _death_overlay_restart_btn and is_instance_valid(_death_overlay_restart_btn):
			_death_overlay_restart_btn.disabled = true
			_death_overlay_restart_btn.text = "Onay bekleniyor..."
		return
	get_tree().paused = false
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## bkz. network_manager.gd sync_game_over/game_over_synced sinyali - takımın
## GERİ KALANI (bizden önce ölüp hâlâ "izleyicisin" yazısını görenler) son
## kişi de öldüğünde bu şekilde "OYUN BİTTİ"ye geçer.
func _on_game_over_synced() -> void:
	## Oyun sonu istatistik ekranı: bizden ÖNCE ölmüş olanlar _on_player_died()
	## içindeki all_dead dalını hiç görmedi (o dal sadece SON ölen kişide
	## tetiklenir), yani kendi istatistiklerini burada yayınlamaları gerekiyor
	## - yoksa tablo sadece son ölen kişiyi gösterirdi.
	_broadcast_local_match_stats()
	_show_death_overlay(true)


## DÜZELTME (kullanıcı bildirimi: "ölüm ekranı yok ölünce hiçbir gösterge
## v.s yok"): tam ekranı kaplamayan (oyun dünyası hâlâ arkada görünür kalır,
## bkz. player.gd die()'daki kamera düzeltmesi - artık ölüm anındaki
## konumda sabit kalıyor) yarı saydam üst bant + ortada büyük bir başlık.
## is_final=false: takımdan en az biri hâlâ hayatta, "izleyicisin" mesajı
## (kalıcı, kendi kendine kapanmaz - _on_game_over_synced ile güncellenir).
## is_final=true: oyun gerçekten bitti (tek oyunculu HER ZAMAN, çok
## oyunculuda herkes öldüğünde).
func _show_death_overlay(is_final: bool) -> void:
	if not _death_overlay_layer or not is_instance_valid(_death_overlay_layer):
		_death_overlay_layer = CanvasLayer.new()
		_death_overlay_layer.layer = 95
		add_child(_death_overlay_layer)

		var dim := ColorRect.new()
		dim.color = Color(0.05, 0.03, 0.02, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_death_overlay_layer.add_child(dim)

		var box := VBoxContainer.new()
		box.name = "VBox"
		box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		box.offset_top = 90
		box.offset_left = -260
		box.offset_right = 260
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		_death_overlay_layer.add_child(box)

		var title := Label.new()
		title.name = "Title"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 42)
		title.add_theme_color_override("font_color", Color(0.95, 0.25, 0.2))
		box.add_child(title)

		var sub := Label.new()
		sub.name = "Subtitle"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD
		sub.add_theme_font_size_override("font_size", 20)
		sub.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
		box.add_child(sub)

		## #54: sadece takım hâlâ hayattayken (is_final=false) anlamlı olan
		## müttefik-takip kamerası kontrolleri - iki ok butonu + o an
		## izlenen müttefiğin adı. Tek oyunculuda hiç görünmez (orada
		## is_final her zaman true, hiç müttefik de yok).
		var spectate_row := HBoxContainer.new()
		spectate_row.name = "SpectateRow"
		spectate_row.alignment = BoxContainer.ALIGNMENT_CENTER
		spectate_row.add_theme_constant_override("separation", 14)
		box.add_child(spectate_row)

		var prev_btn := Button.new()
		prev_btn.name = "PrevButton"
		prev_btn.text = "< Önceki"
		prev_btn.pressed.connect(_on_spectate_prev_pressed)
		spectate_row.add_child(prev_btn)

		var spectate_label := Label.new()
		spectate_label.name = "SpectateLabel"
		spectate_label.custom_minimum_size = Vector2(190, 0)
		spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spectate_label.add_theme_font_size_override("font_size", 18)
		spectate_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
		spectate_row.add_child(spectate_label)

		var next_btn := Button.new()
		next_btn.name = "NextButton"
		next_btn.text = "Sonraki >"
		next_btn.pressed.connect(_on_spectate_next_pressed)
		spectate_row.add_child(next_btn)

		## DÜZELTME (kullanıcı bildirimi: "oyun bitince hiçbir butona
		## basılmıyor alt-f4 atmamız gerekiyor") - overlay'in eskiden HİÇBİR
		## butonu yoktu (is_final olunca spectate_row de gizleniyordu, bkz.
		## aşağısı) ve ui_cancel (ESC) is_game_over true olunca devre dışı
		## kalıyordu (bkz. _process) - geriye tıklanabilecek TEK bir eleman
		## kalmıyordu. Bu buton HER ZAMAN (is_final olsun olmasın) görünür ve
		## çalışır, pause_menu.gd::_on_menu() ile AYNI temizliği yapar.
		var stats_box := VBoxContainer.new()
		stats_box.name = "StatsBox"
		stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(stats_box)

		var stats_title := Label.new()
		stats_title.name = "StatsTitle"
		stats_title.text = "İSTATİSTİKLER"
		stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_title.add_theme_font_size_override("font_size", 20)
		stats_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
		stats_box.add_child(stats_title)

		var stats_grid := GridContainer.new()
		stats_grid.name = "StatsGrid"
		stats_grid.columns = 3
		stats_grid.add_theme_constant_override("h_separation", 24)
		stats_box.add_child(stats_grid)

		var death_btn_row := HBoxContainer.new()
		death_btn_row.name = "DeathButtonRow"
		death_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		death_btn_row.add_theme_constant_override("separation", 16)
		box.add_child(death_btn_row)

		## DÜZELTME (kullanıcı bildirimi: "Oyunda herkes ölünce oyun buga
		## giriyor ve bitmek yerine oyunu bozuyor yeniden başlatma bile mümkün
		## olmuyor bazen menü açılmıyor") - kök neden: is_game_over true olunca
		## main.gd'nin genel ui_cancel/pause-toggle kontrolü (bkz. _process)
		## KASITLI olarak devre dışı kalıyor (ölüm overlay'iyle çakışmasın diye)
		## - ama bu overlay'in eskiden TEK çıkışı "Ana Menüye Dön"dü, oyuncular
		## tekrar oynamak için TÜM lobiyi yeniden kurmak zorunda kalıyordu.
		## pause_menu.gd _on_restart() ile BİREBİR AYNI host-onaylı oylama akışı
		## (bkz. _on_death_overlay_restart_pressed), sadece tetikleyici burası.
		_death_overlay_restart_btn = Button.new()
		_death_overlay_restart_btn.name = "RestartButton"
		_death_overlay_restart_btn.text = "Yeniden Başla"
		_death_overlay_restart_btn.custom_minimum_size = Vector2(200, 0)
		_death_overlay_restart_btn.pressed.connect(_on_death_overlay_restart_pressed)
		## pause_menu.gd _ready() ile AYNI kural: çok oyunculuda SADECE host
		## yeniden başlatmayı tetikleyebilir, client'larda gizli.
		if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
			_death_overlay_restart_btn.visible = false
		death_btn_row.add_child(_death_overlay_restart_btn)

		var menu_btn := Button.new()
		menu_btn.name = "BackToMenuButton"
		menu_btn.text = "Ana Menüye Dön"
		menu_btn.custom_minimum_size = Vector2(200, 0)
		menu_btn.pressed.connect(_on_death_overlay_menu_pressed)
		death_btn_row.add_child(menu_btn)

		## DÜZELTME (kullanıcı isteği: "Button resmini oyunumdaki tüm
		## butonlarla değiştir") - ölüm ekranındaki izleyici ok butonları ve
		## "Ana Menüye Dön" butonu hiç UISound çağırmıyordu. Tüm Main
		## ağacını değil sadece bu overlay'i taramak yeterli/daha ucuz.
		UISound.connect_all_buttons(_death_overlay_layer)
		UISound.apply_wood_buttons(_death_overlay_layer)

		_death_overlay_label = title

	var title_lbl: Label = _death_overlay_layer.get_node_or_null("VBox/Title")
	var sub_lbl: Label = _death_overlay_layer.get_node_or_null("VBox/Subtitle")
	var spectate_row_node: HBoxContainer = _death_overlay_layer.get_node_or_null("VBox/SpectateRow")
	var stats_box_node: VBoxContainer = _death_overlay_layer.get_node_or_null("VBox/StatsBox")
	if stats_box_node:
		stats_box_node.visible = is_final
	if is_final:
		_refresh_match_stats_ui()
		if title_lbl:
			title_lbl.text = "OYUN BİTTİ"
		if sub_lbl:
			sub_lbl.text = "Tüm takım elendi." if NetworkManager.is_multiplayer_active else "Öldün."
		if spectate_row_node:
			spectate_row_node.visible = false
		_end_spectate_mode()
	else:
		if title_lbl:
			title_lbl.text = "SEN ÖLDÜN"
		if sub_lbl:
			sub_lbl.text = "İzleyicisin - takım arkadaşların hâlâ hayatta. Herkes elenirse oyun burada biter."
		if spectate_row_node:
			spectate_row_node.visible = true
		_begin_spectate_mode()


## #54 DÜZELTME (kullanıcı isteği: "Ölüm ekranında seçilebilir müttefik
## takip kamerası"): bkz. player.gd die() - kamera ölüm anında Player'dan
## koparılıp sahnenin köküne taşınıyor (player.death_camera hâlâ geçerli bir
## referans, sadece artık başka bir node'un çocuğu). Burada o kamerayı
## devralıp hayatta kalan ilk müttefiğe kilitliyoruz.
func _begin_spectate_mode() -> void:
	if _spectate_active:
		return
	if not is_instance_valid(player) or not ("death_camera" in player):
		return
	var cam: Camera2D = player.death_camera
	if not cam or not is_instance_valid(cam):
		return
	_spectate_active = true
	_spectate_camera = cam
	_spectate_index = -1
	_advance_spectate_target(1)


func _end_spectate_mode() -> void:
	_spectate_active = false
	_spectate_target = null
	_spectate_camera = null


## Hayatta kalan TÜM müttefikleri (bkz. remote_player.gd, "remote_players"
## grubu) döner - kendi ölü karakterimiz zaten sahneden kalkmış olduğu için
## bu listeye asla girmez.
func _get_living_allies_for_spectate() -> Array:
	var result: Array = []
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and rp.get("is_dead") != true:
			result.append(rp)
	return result


func _advance_spectate_target(direction: int) -> void:
	var targets: Array = _get_living_allies_for_spectate()
	var label: Label = null
	if _death_overlay_layer and is_instance_valid(_death_overlay_layer):
		label = _death_overlay_layer.get_node_or_null("VBox/SpectateRow/SpectateLabel")
	if targets.is_empty():
		_spectate_target = null
		_spectate_index = -1
		if label:
			label.text = "Hayatta müttefik yok"
		return
	_spectate_index = wrapi(_spectate_index + direction, 0, targets.size())
	_spectate_target = targets[_spectate_index]
	if label:
		var display_name: String = str(_spectate_target.get("player_name")) if "player_name" in _spectate_target else "Müttefik"
		label.text = "İzleniyor: %s" % display_name


func _on_spectate_prev_pressed() -> void:
	_advance_spectate_target(-1)


func _on_spectate_next_pressed() -> void:
	_advance_spectate_target(1)


## Her karede seçili müttefiğin konumuna doğru yumuşakça kayar - müttefik
## ölür/geçersiz olursa otomatik olarak bir sonraki hayatta kalana geçer.
func _process_spectate_camera(delta: float) -> void:
	if not _spectate_camera or not is_instance_valid(_spectate_camera):
		_end_spectate_mode()
		return
	if not _spectate_target or not is_instance_valid(_spectate_target) or _spectate_target.get("is_dead") == true:
		_advance_spectate_target(1)
		if not _spectate_target:
			return
	_spectate_camera.global_position = _spectate_camera.global_position.move_toward(
		_spectate_target.global_position, SPECTATE_CAMERA_FOLLOW_SPEED * delta
	)
