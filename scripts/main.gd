extends Node2D

const LevelUpScreenScene = preload("res://scenes/level_up_screen.tscn")
## Yetenek evrimleri (2026-09-28): evrim kartı seçimi "evo:<id>" olarak gelir (bkz. _on_upgrade_chosen).
const SkillEvolutionsScript := preload("res://scripts/skill_evolutions.gd")
const MissionCompleteWindowScript := preload("res://scripts/mission_complete_window.gd")
const GameNoticeScript := preload("res://scripts/game_notice.gd") ## bildirim levhaları (madde 264)
const WaitOverlayScript := preload("res://scripts/wait_overlay.gd") ## oyuncular bekleniyor ekranı (madde 264)
const EVO_CHOICE_PREFIX := SkillEvolutionsScript.CHOICE_PREFIX
const PauseMenuScene = preload("res://scenes/pause_menu.tscn")
const RemotePlayerScene = preload("res://scenes/remote_player.tscn")
const ChestMenuScene = preload("res://scenes/chest_menu.tscn")
const EnchantScreenScript = preload("res://scripts/enchant_screen.gd")
## Başlangıç silahı (kullanıcı isteği 2026-10-03): oyun başındaki 3 rastgele silah kartı ekranı (weapon_select_screen.gd)
## SİLİNDİ - silah karakter seçim ekranında / lobide seçiliyor (menu_weapon_picker.gd -> GameManager.selected_start_weapon),
## oyun başlayınca _start_initial_loadout_selection doğrudan verir.
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")

## bkz. _on_merchant_spawned/_on_merchant_departed - minimap'teki küçük "$"
## noktası (bkz. minimap.gd set_merchant_marker) yeterince fark edilmiyordu,
## kullanıcı isteği: "varolduğu sürece konumu ok ile gösterilmeli."
const MerchantArrowScript := preload("res://scripts/merchant_arrow.gd")
var _merchant_arrow: Control = null
const WorldEventBannerScript := preload("res://scripts/world_event_banner.gd")
var _world_event_banner: Control = null
## mission_id -> "capture_point"/"secure_area"/... (bkz. world_event_manager.gd
## MISSION_KIND_NAMES) - tamamlanma bildiriminde okunabilir bir isim göstermek için.
var _world_event_kind_by_id: Dictionary = {}
var _world_event_label_by_id: Dictionary = {} ## bkz. yukarıdaki not - announced'tan alınır
## mission_id -> Dictionary (kind'e özgü görsel node/dizi referansları - bkz.
## _on_world_event_started/_on_world_event_progress/_on_world_event_completed).
var _world_event_visuals: Dictionary = {}
const MissionVanScript := preload("res://scripts/mission_van.gd")
const MissionTreeScript := preload("res://scripts/mission_tree.gd")
const MissionCollectItemScript := preload("res://scripts/mission_collect_item.gd")
const MissionPlayerCopyScript := preload("res://scripts/mission_player_copy.gd")
const MissionZoneScript := preload("res://scripts/mission_zone.gd")
## Kullanıcı bildirimi (2026-09-24): "görev açıklaması yanda yazarken yazı çok çabuk kayboluyor" - görev bildirimleri
## (duyuru/başladı/bitti) artık genel 2.4sn yerine bu kadar ekranda kalıyor ve "BAŞLADI" bildirimi görevin ne
## istediğini de yazıyor (bkz. MISSION_DESCRIPTIONS).
const MISSION_TOAST_SECONDS := 9.0
## Tek bir görev merkezi olmayan türler (bkz. world_event_manager.gd HIDDEN_LOCATION_KINDS): pusula oku/minimap "!" yok.
## Topla'nın objeleri minimapte tek tek nokta olarak gösterilir (bkz. minimap.gd set_collect_dots).
const NO_SINGLE_LOCATION_KINDS := ["kill_your_copy", "collect"]
const MISSION_DESCRIPTIONS := {
	"capture_point": "Bayrağın çevresindeki dairede durarak bayrağı direğin tepesine kadar kaldır.",
	"secure_area": "İşaretli alanın içinde süre bitmeden yeterince yaratık öldür.",
	"collect": "Haritanın dört bir yanına saçılmış kristallerden yeterince topla (minimapte işaretli).",
	"escort_van": "Konvoyun çevresindeki dairede kalarak onu hedefe kadar it. Uzaklaşırsan geri kayar.",
	"defend_tree": "Ağacı yaratıklardan koru - büyümesini tamamlayana kadar yok olmasın.",
	"kill_your_copy": "Haritada bir yerde beliren mor tonlu kopyanı bul ve öldür.",
}

## Kullanıcı isteği: LoL tarzı görüş alanı / savaş sisi - bkz. vision_fog.gd.
## Sahneye (main.tscn) elle eklenmiyor, kodla kuruluyor: Godot editörü main.tscn'i
## açık tutarken dışarıdan yapılan .tscn düzenlemeleri editörün "Kaydet"i ile
## sessizce ezilebiliyor (bkz. CLAUDE.md).
const VisionFogScript := preload("res://scripts/vision_fog.gd")
## Gün-gece döngüsü + hava durumu (kullanıcı isteği 2026-09-25) - sis gibi kodla kuruluyor (aynı gerekçe).
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const GrassSwayScript := preload("res://scripts/grass_sway.gd")
const TreeSwayScript := preload("res://scripts/tree_sway.gd")
const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")
const ForestCanopyScript := preload("res://scripts/forest_canopy.gd")
const CreatureDepthScript := preload("res://scripts/creature_depth.gd")
const HideBrushManagerScript := preload("res://scripts/hide_brush_manager.gd")
const MineWorldScript := preload("res://scripts/mine_world.gd")
const GuardCampsScript := preload("res://scripts/guard_camps.gd")
const MapShadowsScript := preload("res://scripts/map_shadows.gd")
const GroundTexelPassScript := preload("res://scripts/ground_texel_pass.gd")
const MapColorGradeScript := preload("res://scripts/map_color_grade.gd")
const WaterFxScript := preload("res://scripts/water_fx.gd")
const FxWarmupScript := preload("res://scripts/fx_warmup.gd")
const WorldRenderScaleScript := preload("res://scripts/world_render_scale.gd")
const MobileUI := preload("res://scripts/mobile_ui.gd")
const SunCloudsScript := preload("res://scripts/sun_clouds.gd")
const RiverAmbienceScript := preload("res://scripts/river_ambience.gd")

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
const CameraMapLimitsScript: GDScript = preload("res://scripts/camera_map_limits.gd")
const DownedSpectateScript: GDScript = preload("res://scripts/downed_spectate.gd") ## yerdeki oyuncunun arkadaş izleme şeridi

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
## Vampir Çocuk R yarasa konum paketi: bir önceki gönderim dolu muydu (kapanışta tek bir boş paket için).
var _vampir_bats_last_sent_nonempty: bool = false
const SYNC_INTERVAL := 0.05
var _remote_players: Dictionary = {}

## DÜZELTME (kullanıcı bildirimi: "ölüm ekranı yok ölünce hiçbir gösterge
## v.s yok"): bkz. _show_death_overlay/_on_player_died üstündeki notlar.
var _death_overlay_layer: CanvasLayer = null
## Oyun bitti sesi bir kez (_show_death_overlay(true) hem son ölende hem game_over_synced'te çağrılabilir).
var _game_over_sfx_played: bool = false
var _death_overlay_label: Label = null
## Oyun sonu istatistik ekranı: peer_id (int) -> {"name": String, "dealt":
## float, "taken": float} - bkz. NetworkManager.match_stats_received/
## _on_match_stats_received, _show_death_overlay.
var _match_stats_by_peer: Dictionary = {}

## ZAFER + SONSUZ MOD + koşu sonu rekor/başarım (kullanıcı isteği 2026-10-05) - bkz. _on_victory_reached, _run_summary, _record_run.
const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const RunSummaryUIScript: GDScript = preload("res://scripts/run_summary_ui.gd")
const VictoryOverlayScript: GDScript = preload("res://scripts/victory_overlay.gd")
const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const EndlessMathScript: GDScript = preload("res://scripts/endless_math.gd")
const BossBarTopScript: GDScript = preload("res://scripts/boss_bar_top.gd")
const CameraShakeScript: GDScript = preload("res://scripts/camera_shake.gd")
const TierDisplayScript: GDScript = preload("res://scripts/tier_display.gd")
const GameOverBoardScript := preload("res://scripts/game_over_board.gd") ## oyun bitti ekranı gövdesi (madde 224)
const PhoneGameOverScript := preload("res://scripts/phone_game_over.gd") ## telefonda ölüm / oyun bitti görünümü
const ShopDarkKitScript := preload("res://scripts/shop_dark_kit.gd") ## oyun bitti ekranı Seyyar Satıcı kitinde (madde 224)
const DEATH_WINDOW_TOP := 72.0 ## ölüm/oyun bitti penceresinin üstü (madalyon bunun üstüne taşar)
var _boss_bar_top: Control = null ## üst ortadaki boss barı (boss_bar_top.gd)
var _victory_overlay: CanvasLayer = null
var _endless_label: Label = null
## Bu koşuda kırılan rekorlar / açılan başarımlar ({"records": [...], "achievements": [...]}) - ölüm ve zafer ekranında listelenir.
var _run_results: Dictionary = {"records": [], "achievements": []}
var _run_end_recorded: bool = false ## koşu sonu (toplamlar) bir kez işlensin: ölüm ekranı YA DA menüye çıkış (_exit_tree)

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
	FxWarmupScript.run(self) ## efekt shader'ları ilk kullanımda takılmasın (madde 215)
	player.health_changed.connect(hud.update_health)
	GameManager.team_xp_changed.connect(hud.update_xp)
	GameManager.team_xp_changed.connect(_on_team_xp_changed_for_level_up_delay)
	GameManager.team_leveled_up.connect(_on_team_leveled_up)
	player.stats_changed.connect(_update_stats_display)
	player.died.connect(_on_player_died)
	if player.has_signal("rose_from_permadeath"):
		player.rose_from_permadeath.connect(_on_player_rose_from_permadeath)
	NetworkManager.server_disconnected.connect(_on_multiplayer_server_disconnected)
	## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini
	## beklemeden tüm kartlarını seçebilsin... hepsi ortak bir bekleme
	## süresine bağlı olacak") - level_up_pending_peers/multiplayer_level_up_
	## all_chosen tabanlı ESKİ "her turda kilitlen" mekanizması, chest_busy_
	## peers ile AYNI desene (bkz. network_manager.gd "KART/SİLAH/KALKAN SEÇİM
	## KUYRUĞU SENKRONİZASYONU" notu) taşındı.
	NetworkManager.level_up_busy_state_changed.connect(_on_level_up_busy_state_changed)
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
	## Görev sistemi (bkz. world_event_manager.gd) - satıcı okuyla AYNI CanvasLayer deseni,
	## ayrı bir layer'da (aynı katmanda olsalar da iki script birbirinden habersiz, karışmasın).
	NetworkManager.creature_tier_reached.connect(_on_creature_tier_reached)
	NetworkManager.victory_reached.connect(_on_victory_reached)
	GameManager.run_about_to_reset.connect(_record_run_end_once)
	## Ruh Kıymığı: süre/kademe puanı dakikada bir de bankalanır (oyundan düşen/çöken oyuncu o ana kadarkini kaybetmesin, bkz. _bank_meta).
	var meta_timer := Timer.new()
	meta_timer.name = "MetaBankTimer"
	meta_timer.wait_time = 60.0
	meta_timer.autostart = true
	meta_timer.timeout.connect(_on_meta_bank_tick)
	add_child(meta_timer)
	NetworkManager.announce_meta_revive_bonus() ## kalıcı "Dirilme Hakkı" geliştirmesi (host'a bildirilir; tekli oyunda no-op)
	if not GameManager.run_record_suppressed:
		BalanceLogScript.reset() ## yeni koşu: balans telemetrisi sıfırdan (devirde koşu sürüyor, sayaçlar korunur)
	GameManager.run_record_suppressed = false ## yeni Main: devirden gelen bastırma bitti
	var record_skip: String = _record_skip_reason()
	_record_log("koşu başladı: kayıt %s" % ("AÇIK" if record_skip == "" else "KAPALI - " + record_skip))
	NetworkManager.endless_started.connect(_on_endless_started)
	NetworkManager.endless_layer_reached.connect(_on_endless_layer_reached)
	## Tek oyunculuda game_time karakter seçimi sırasında da akıyor - koşu süresi Main açıldığı andan sayılsın (bkz. GameManager.run_clock_origin).
	if not NetworkManager.is_multiplayer_active:
		GameManager.run_clock_origin = GameManager.game_time
	NetworkManager.world_event_announced.connect(_on_world_event_announced)
	NetworkManager.world_event_started.connect(_on_world_event_started)
	NetworkManager.world_event_progress.connect(_on_world_event_progress)
	NetworkManager.world_event_completed.connect(_on_world_event_completed)
	NetworkManager.world_event_item_collected.connect(_on_world_event_item_collected)
	NetworkManager.world_event_catchup.connect(_on_world_event_catchup)
	NetworkManager.host_migration_state.connect(_on_host_migration_state)
	## (Ekranın üst-ortasındaki ayrı görev pusulası - world_event_marker.gd - kaldırıldı: kullanıcı isteğiyle (2026-09-24)
	## görev konumu artık görev penceresinin İÇİNDE, her satırın yön oku + mesafesiyle - bkz. world_event_banner.gd.)
	_world_event_banner = Control.new()
	_world_event_banner.name = "WorldEventBanner"
	_world_event_banner.set_script(WorldEventBannerScript)
	var world_event_banner_layer := CanvasLayer.new()
	world_event_banner_layer.name = "WorldEventBannerLayer"
	world_event_banner_layer.layer = 40
	add_child(world_event_banner_layer)
	world_event_banner_layer.add_child(_world_event_banner)
	## Arayüz opaklığı ayarı (kullanıcı isteği 2026-09-25, bkz. UISound.ui_opacity_percent) - görev penceresi ve satıcı
	## oku da kalıcı arayüz parçası.
	UISound.register_ui_opacity(_world_event_banner)
	UISound.register_ui_opacity(_merchant_arrow)
	## KAMERA SARSINTISI sürücüsü (kullanıcı isteği 2026-10-05, bkz. camera_shake.gd): olaylar static API'yi çağırır, bu düğüm her kare
	## kamera ofsetine uygular. Önceki oyundan kalan travma temizlenir.
	CameraShakeScript.reset()
	var shake_driver := Node.new()
	shake_driver.name = "CameraShakeDriver"
	shake_driver.set_script(CameraShakeScript)
	add_child(shake_driver)
	## Üst ortadaki BOSS BARI (kullanıcı isteği 2026-10-05, prototip T1): canlı boss varken boss'un adı + kalkan + can; çoklu bossta
	## altta küçük plaketler. Boss'un üstünde artık sadece kafatası işareti var (bkz. enemy.gd _create_overhead_bar).
	var boss_bar_layer := CanvasLayer.new()
	boss_bar_layer.name = "BossBarLayer"
	boss_bar_layer.layer = 38
	add_child(boss_bar_layer)
	_boss_bar_top = Control.new()
	_boss_bar_top.name = "BossBarTop"
	_boss_bar_top.set_script(BossBarTopScript)
	## Telefonda üst orta görev satırlarıyla paylaşılıyor: bar onların altından başlar (PC'de sabit y=50, görevler sağ sütunda).
	_boss_bar_top.set("top_y_getter", func() -> float:
		if not MobileUI.enabled:
			return float(BossBarTopScript.TOP_Y)
		var y: float = float(BossBarTopScript.PHONE_TOP_Y)
		if _world_event_banner and is_instance_valid(_world_event_banner):
			y = maxf(y, float(_world_event_banner.call("get_rows_bottom_y")) + 8.0)
		return y)
	boss_bar_layer.add_child(_boss_bar_top)
	UISound.register_ui_opacity(_boss_bar_top)
	## Görev göstergeleri HUD'un SAĞ sütununun altında dursun (bkz. world_event_banner.gd): minimap + (varsa) grup paneli.
	## DÜZELTME (kullanıcı bildirimi 2026-09-25: "görev başlayınca sağda gözükmüyor") - eskiden ENVANTER/altın butonlarına
	## hizalanıyordu; onlar aynı gün SOLA taşınınca band ekranın sol dışına itiliyordu (sağ kenarı = envanterin sağ kenarı).
	var banner_anchors: Array = []
	for path: String in ["MinimapControl", "PartyPanelLayer/PartyPanel/Background"]:
		var anchor_node: Node = hud.get_node_or_null(path)
		if anchor_node != null:
			banner_anchors.append(anchor_node)
	_world_event_banner.set("hud_anchor_controls", banner_anchors)
	_notice_anchor_controls = banner_anchors ## sağ sütun bildirimleri de aynı sütunun altına (bkz. _notice_column)
	## #58 DÜZELTME (kullanıcı bildirimi: "sandık açılımı esnasında oyun diğer
	## oyuncularda devam ediyor gibi görünüyor, kart bekleme ekranının aktif
	## kalması gerekiyor o esnada") - bkz. _on_chest_busy_state_changed().
	NetworkManager.chest_busy_state_changed.connect(_on_chest_busy_state_changed)
	## Kullanıcı bildirimi: "bazen hostta açılıp diğer oyunlarda açılmıyor" -
	## periyodik dükkanın açılıp açılmayacağı kararı artık HOST'tan geliyor
	## (bkz. network_manager.gd "MİNİ DÜKKAN KARARI" bloğu).
	NetworkManager.mini_shop_decision_received.connect(_on_mini_shop_decision_received)
	## Kullanıcı isteği: "sandık seçerken diğer oyuncularda da 25 saniyelik bekleme süresi olmalı" - bekleme ekranı
	## (wait_overlay.gd) sayacı NetworkManager.chest_countdown'dan kendisi okur (2026-10-18; eskiden tik sinyaliyle etiket).
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
	NetworkManager.debug_action_announced.connect(_on_debug_action_announced)
	_update_stats_display()
	hud.update_level(GameManager.team_level)
	hud.update_xp(GameManager.team_xp, GameManager.team_xp_needed)
	
	if NetworkManager.is_multiplayer_active:
		_setup_multiplayer_players()

	## Kamera haritanın dışını göstermesin (bkz. camera_map_limits.gd).
	var camera_limits: Node = CameraMapLimitsScript.new()
	camera_limits.name = "CameraMapLimits"
	add_child(camera_limits)

	## Yere düşen oyuncu da arkadaşlarını izleyebilsin (bkz. downed_spectate.gd; ölüm ekranı izleyicisi _begin_spectate_mode ayrı).
	if NetworkManager.is_multiplayer_active:
		var downed_spectate: CanvasLayer = DownedSpectateScript.new()
		downed_spectate.name = "DownedSpectate"
		add_child(downed_spectate)

	## Görüş alanı sisi: dünyanın üstünde, HUD'un ALTINDA. VignetteOverlay ve HUD
	## aynı CanvasLayer katmanında (1) olduğu için çizim sırasını ağaç sırası
	## belirliyor - bu yüzden sisi HUD'dan hemen ÖNCEYE taşıyoruz, yoksa
	## add_child() onu en sona koyar ve HUD'un ÜSTÜNE çizerdi (arayüz kararırdı).
	var vision_fog: CanvasLayer = VisionFogScript.new()
	vision_fog.name = "VisionFog"
	add_child(vision_fog)
	move_child(vision_fog, hud.get_index())

	## Gün-gece + hava durumu (bkz. atmosphere.gd). Ekran renk geçişi katmanı sisin HEMEN ÖNCESİNE (aynı layer=1, ağaç
	## sırası): dünya -> gün/gece renkleri + gece ışıkları -> sis -> HUD. Sis de karartılmış sahneyi okur (bkz.
	## vision_fog.gd BackBufferCopy notu); HUD hiç etkilenmez.
	var atmosphere := AtmosphereScript.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	var atmosphere_layer: CanvasLayer = atmosphere.create_overlay_layer()
	add_child(atmosphere_layer)
	move_child(atmosphere_layer, vision_fog.get_index())
	## Güneş ışığı + bulut gölgeleri (bkz. sun_clouds.gd): renk geçişinin HEMEN önüne (gece/yağmur rengi bulutlara da uygulansın).
	var sun_clouds: CanvasLayer = SunCloudsScript.new()
	sun_clouds.name = "SunClouds"
	add_child(sun_clouds)
	move_child(sun_clouds, atmosphere_layer.get_index())
	## Güneş huzmesi: sisin HEMEN arkasına (HUD'dan önce) - gökyüzünden gelen ışık, sis onu karartmasın.
	add_child(sun_clouds.light_layer)
	move_child(sun_clouds.light_layer, vision_fog.get_index() + 1)

	## Sallanan otlar (bkz. grass_sway.gd / scenes/sallanan ot.gdshader): karo kök tablosu, havaya göre salınım ve yukarı/aşağı
	## önceliği (önünde kalan otlar oyuncunun üstüne çizilir).
	var harita_node: Node = get_node_or_null("Harita")
	if harita_node:
		## Nehir akıntısı sesi (bkz. river_ambience.gd) - yerel oyuncuya en yakın su noktasında. Kullanıcı isteği
		## (2026-09-27): üretilen ses iptal edildi, kullanıcı kendi sesini yükleyecek - ses dosyası (RiverAmbience SOUND_PATH)
		## yoksa bileşen hiç kurulmaz.
		if ResourceLoader.exists(RiverAmbienceScript.SOUND_PATH):
			var river := RiverAmbienceScript.new()
			river.name = "RiverAmbience"
			river.setup(harita_node)
			add_child(river)
		GrassSwayScript.new().setup(harita_node)
		## Sallanan ağaçlar ("Ağaç 0/1/2", bkz. tree_sway.gd / scenes/sallanan ağaç.gdshader).
		TreeSwayScript.new().setup(harita_node)
		## Derinlik (y-sıralama): ağaç/bina/maden önde kalınca oyuncunun üstüne çizilir (bkz. depth_occluders.gd; TreeSway'DEN SONRA kurulmalı).
		DepthOccludersScript.new().setup(harita_node)
		## Orman parçaları 2 karakterlerin üstünde; duvar geçen (uçan) karakter onun üstüne çıkar (bkz. forest_canopy.gd).
		ForestCanopyScript.new().setup(harita_node)
		## Harita gölgeleri (2026-10-02, "B - Tepe gölgesi"): pişmiş doku zeminin üstüne, objelerin altına (bkz. map_shadows.gd).
		MapShadowsScript.attach(harita_node)
		## Zemin shader'ları (çimen/toprak) dünya pikseli çözünürlüğünde çizilip büyütülür - telefonda GPU'nun en büyük yükü
		## (bkz. ground_texel_pass.gd, görüntü birebir aynı).
		## Harita görünümü (madde 181/184/186): renk ayarı, sakin doku, başıboş çimen karoları, plato deseni. Ön kopyalardan SONRA (onların
		## materyalleri de ayarlansın), zemin geçişinden ÖNCE (ground_texel_pass.gd ayrıntı ayarını değiştirilmiş orman shader'ına uygulasın).
		MapColorGradeScript.attach(harita_node)
		## Su (madde 214): akıntılı dalgacık shader'ına kıyı uzaklığı + akış dokuları, çarpışmasız su da aynı materyal (bkz. water_fx.gd).
		WaterFxScript.attach(harita_node)
		GroundTexelPassScript.attach(harita_node)
	## Yaratık-oyuncu derinliği: oyuncunun önünde duran yaratık oyuncunun üstüne çizilir (bkz. creature_depth.gd).
	var creature_depth: Node = CreatureDepthScript.new()
	creature_depth.name = "CreatureDepth"
	add_child(creature_depth)
	## Saklanma çalılığı kuralları (bkz. hide_brush_manager.gd): karar host'ta, görsel her peer'de.
	var hide_brush: Node = HideBrushManagerScript.new()
	hide_brush.name = "HideBrushManager"
	add_child(hide_brush)
	## Maden dayanıklılığı / kırılma / yeniden doğma (bkz. mine_world.gd): karar host'ta, görsel her peer'de.
	var mine_world: Node = MineWorldScript.new()
	mine_world.name = "MineWorld"
	add_child(mine_world)
	## Kenar bekçileri (haritanın kenarlarındaki yaratık kampları, bkz. guard_camps.gd): karar host'ta.
	var guard_camps: Node = GuardCampsScript.new()
	guard_camps.name = "GuardCamps"
	add_child(guard_camps)
	_install_draw_order_guard()
	## Grafik ayarı "Çözünürlük ölçeği" (bkz. world_render_scale.gd; %100'de hiçbir şey kurmaz).
	WorldRenderScaleScript.attach(self)

	# Add loopable breezy cozy forest ambient sound
	var ambient: Node = preload("res://scripts/wind_breeze_ambient.gd").new()
	ambient.name = "WindBreezeAmbient"
	add_child(ambient)
	## Boss varken çalan müzik (bkz. boss_music.gd).
	var boss_music: Node = preload("res://scripts/boss_music.gd").new()
	boss_music.name = "BossMusic"
	add_child(boss_music)
	## Şovalye kubbesindeki oyuncuların silahları bariyerin dış halkasına dizilir (bkz. dome_weapon_ring.gd).
	var dome_ring: Node = preload("res://scripts/dome_weapon_ring.gd").new()
	dome_ring.name = "DomeWeaponRing"
	add_child(dome_ring)
	## Akarsu sesi: suya yaklaştıkça yükselir, uzaklaştıkça kısılır (bkz. stream_ambient.gd).
	var stream_ambient: Node = preload("res://scripts/stream_ambient.gd").new()
	stream_ambient.name = "StreamAmbient"
	add_child(stream_ambient)
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
	## boşsa bu YENİ bir koşu demektir - oyuncuyu ilk silah seçim ekranından
	## geçirip öyle başlatıyoruz (kalkan 2026-09-29'dan beri seçilmiyor, herkes
	## Standart Kalkanla başlıyor - bkz. _grant_starting_shield).
	## Kullanıcı isteği: "silah seçme kartının oyun başladıktan 2 saniye
	## sonra gelmesini istiyorum" - oyuncu ilk 2 saniye haritayı/karakterini
	## görsün diye ekran hemen değil, kısa bir gecikmeyle açılıyor (oyun bu
	## sırada duraklamıyor, bkz. _start_initial_loadout_selection).
	if GameManager.owned_weapons.is_empty():
		_start_initial_loadout_selection.call_deferred()
	## Geç katılım (2026-10-04): Main artık ağaçta - host'tan yaratıkların/atmosferin/satıcının "yakalama" gönderimini iste
	## (eskiden host bunu istek gelir gelmez, istemci henüz yükleme ekranındayken gönderiyordu: paketler boşa gidiyordu).
	if NetworkManager.has_pending_rejoin():
		_restore_rejoined_player.call_deferred()
	NetworkManager.notify_main_ready_for_catchup.call_deferred()


## Geri katılım (2026-10-04): oyundan düşen oyuncu geri girdiğinde kaydedilmiş durumu uygular ve takım seviyesine eşitler (kaçırılan
## seviyelerin kartları rastgele - player.gd restore_from_rejoin_snapshot), evden çıkarıp son bilinen konuma koyar.
func _restore_rejoined_player() -> void:
	var pending: Dictionary = NetworkManager.take_pending_rejoin()
	if pending.is_empty() or not is_instance_valid(player):
		return
	var snap: Dictionary = pending.get("snap", {})
	var missed: int = player.restore_from_rejoin_snapshot(snap, GameManager.team_level)
	var house: Node = get_node_or_null("HouseInterior")
	if house != null and house.has_method("_do_exit_house"):
		house.call("_do_exit_house") ## oyun evde başlar - süren bir oyuna girenin dışarıda olması gerekir
	if snap.has("pos") and not bool(snap.get("indoors", false)):
		player.global_position = Vector2(snap["pos"])
		player.reset_physics_interpolation()
	if missed > 0:
		player._spawn_floating_text("%d SEVİYE KAÇIRDIN - RASTGELE KARTLAR VERİLDİ" % missed, Color(1.0, 0.85, 0.4), true, -58.0)


## Geri katılım için kendi durumumu host'a periyodik bildirir (main _process).
var _rejoin_report_timer: float = 4.0


func _process_rejoin_report(delta: float) -> void:
	if not NetworkManager.is_multiplayer_active or NetworkManager.is_host or not is_instance_valid(player):
		return
	_rejoin_report_timer -= delta
	if _rejoin_report_timer <= 0.0:
		_rejoin_report_timer = 6.0
		NetworkManager.report_rejoin_snapshot(player.get_rejoin_snapshot())


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
	## 2026-10-04: duraklatma "pause_game" (Esc + kumanda Start) - eskiden ui_cancel'dı, kumanda B'si de oyunu duraklatıyordu.
	if Input.is_action_just_pressed("pause_game") and not GameManager.is_game_over \
			and not GameManager.is_any_blocking_panel_open() and not GameManager.was_ui_cancel_consumed():
		_toggle_pause()
	
	_process_rejoin_report(delta)
	if NetworkManager.is_multiplayer_active and is_instance_valid(player):
		_process_multiplayer_sync(delta)
		_sweep_ghost_remote_players(delta)
	if not _remote_players.is_empty():
		_update_character_draw_order()
	_update_creature_draw_order()
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



## Güvenlik ağı: bağlantısı kalmamış peer'in kuklası (ayrılış bildirimi kaçsa bile) saniyede bir temizlenir.
## Host devri sürerken peer listesi geçici boş olduğu için atlanır.
var _ghost_sweep_timer: float = 0.0


func _sweep_ghost_remote_players(delta: float) -> void:
	_ghost_sweep_timer += delta
	if _ghost_sweep_timer < 1.0 or _remote_players.is_empty():
		return
	_ghost_sweep_timer = 0.0
	if NetworkManager.is_host_migrating() or not multiplayer.has_multiplayer_peer():
		return
	var connected: PackedInt32Array = multiplayer.get_peers()
	for pid in _remote_players.keys():
		if not connected.has(int(pid)):
			NetworkManager._net_log("hayalet kukla temizlendi: peer %d bağlı değil" % int(pid))
			_despawn_remote_player(int(pid))


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
	## Yerel Player ile AYNI z katmanı (main.tscn'de z_index = 1) - bkz. _update_character_draw_order.
	rp.z_index = player.z_index if is_instance_valid(player) else 1
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


## DÜZELTME (kullanıcı bildirimi: "bir karakter haritada üstteyken arkasında görünmek yerine önünde görünüyor" -
## Elara Talon'un üstündeyken fark edildi): sahnede y-sort YOK ve yerel Player z_index = 1 iken RemotePlayer
## kuklaları z_index = 0'daydı - yerel oyuncu Y'den bağımsız HEP öndeydi, kuklalar arasında da sıra sadece
## sahneye eklenme sırasıydı (bu yüzden her karakter çiftinde görülmüyordu). Main'e y_sort_enabled vermek
## harita/sis/FX gibi TÜM çocukların sırasını değiştirirdi; bunun yerine SADECE oyuncu düğümleri (hepsi Main'in
## doğrudan çocuğu, aynı z katmanında) kendi aralarında Y'ye göre (aşağıdaki önde) yeniden diziliyor. move_child
## yalnızca sıra gerçekten bozulduğunda çağrılıyor.
func _update_character_draw_order() -> void:
	var chars: Array[Node2D] = []
	if is_instance_valid(player) and player.get_parent() == self:
		chars.append(player)
	for rp in _remote_players.values():
		if is_instance_valid(rp) and rp.get_parent() == self:
			chars.append(rp)
	if chars.size() < 2:
		return
	chars.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.y < b.global_position.y)
	## Her karakter kendinden bir öncekinin (daha yukarıdakinin) ağaçta ARKASINDA olmalı. Öndeyse hemen
	## arkasına taşınır: daha büyük bir indekse move_child, öncekini bir geri kaydırıp bunu onun hemen
	## arkasına koyar; önceki çiftlerin göreli sırası bozulmaz.
	for i in range(1, chars.size()):
		var prev_idx: int = chars[i - 1].get_index()
		if chars[i].get_index() < prev_idx:
			move_child(chars[i], prev_idx)


## DÜZELTME (kullanıcı bildirimi 2026-09-26: "bütün yaratıkların y ekseni bozuk alttakilere üsttekilerin ayakları üstte
## görünüyor"): yaratıklar (enemy_spawner.gd _spawn_creature -> Main'e add_child), evcil hayvanlar ve görev kopyaları
## Main'in doğrudan çocukları ve aynı z katmanında (0); aralarındaki çizim sırası sadece SAHNEYE EKLENME sırasıydı - sonradan
## doğan, daha yukarıdaki yaratık aşağıdakinin üstüne çiziliyordu. Oyuncularla (_update_character_draw_order) aynı yöntem:
## Main'e y_sort vermeden sadece bu düğümler kendi aralarında yeniden diziliyor, move_child yalnız sıra bozuksa.
## Anahtar düğümün kök noktası DEĞİL AYAK hizası: kök gövde ortasında ve yaratık boyları çok farklı (boss, sıçan, golem) -
## merkeze göre sıralanınca büyük bir yaratığın ayağının hemen üstündeki küçük yaratık yine onun üstüne çiziliyordu.
## Ayak = sprite karesindeki en alt dolu piksel satırı (gölgeli sayfalarda gölgenin altı), doku başına bir kez ölçülür.
## "ysort_props": yerde duran küçük nesneler (Oakley çiçeği, 2026-10-19) yaratıklarla aynı ayak sırasına girer (oakley_flower.gd DERİNLİK notu).
const CREATURE_SORT_GROUPS: Array[String] = ["enemies", "player_ally", "player_allies", "ysort_props"]
static var _foot_row_cache: Dictionary = {} ## "doku yolu|hframes|vframes" -> kare üstünden ayak satırına px (kare boyu ile)


func _update_creature_draw_order() -> void:
	## İki karede bir yeter (yan yana yürüyen yaratıklar bir karede sıra değiştirmez); ~200 yaratıkta maliyeti yarıya indirir.
	if Engine.get_process_frames() % 2 != 0:
		return
	## Yaratık yeniden yazımı (Aşama 3): yeni yolda sıralama C++'ta ve düğümler TAŞINMAZ (draw index) - 2000 yaratıkta bu
	## fonksiyon GDScript'te ~10 ms/çağrıydı. Eski yol aşağıda aynen.
	var ew: Object = EnemyWorldBridgeScript.fog_world(get_tree())
	if ew != null:
		_update_creature_draw_order_ew(ew)
		return
	var nodes: Array[Node2D] = []
	var keys: Array = [] ## Vector2(ayak_y, nodes indeksi) - Array.sort() yerleşik karşılaştırmayla (lambda yok) sıralar
	var seen: Dictionary = {} ## iki gruptaki bir düğüm iki kez sayılmasın
	for group_name in CREATURE_SORT_GROUPS:
		for n in get_tree().get_nodes_in_group(group_name):
			var n2 := n as Node2D
			if n2 == null or n2.get_parent() != self or seen.has(n2):
				continue
			## PERF (yaratık yeniden yazımı Aşama 3, 1000 yaratıkta bu fonksiyon ~3,4 ms): görünmeyen (görüş sisinin gizlediği)
			## yaratık çizilmez, sırası önemsiz - sisin dışına çıktığı karede zaten bir sonraki geçişte (<= 2 kare) sıralanır.
			## Sis kapalıyken (ev içi / sis yok) herkes görünür, davranış eskisiyle aynı.
			if not n2.visible:
				continue
			seen[n2] = true
			keys.append(Vector2(_creature_foot_y(n2), nodes.size()))
			nodes.append(n2)
	if nodes.size() < 2:
		return
	keys.sort()
	## _update_character_draw_order ile aynı: her düğüm, kendinden bir önceki (daha yukarıdaki) düğümün ağaçta ARKASINDA
	## olmalı; öndeyse hemen arkasına taşınır, önceki çiftlerin göreli sırası bozulmaz.
	var prev: Node2D = nodes[int(keys[0].y)]
	for i in range(1, keys.size()):
		var cur: Node2D = nodes[int(keys[i].y)]
		var prev_idx: int = prev.get_index()
		if cur.get_index() < prev_idx:
			move_child(cur, prev_idx)
		prev = cur


const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

## ÇİZİM SIRASI KORUMASI (2026-10-09, kullanıcı: "solucanlar bazen glitchlenip diğerinin üstünde görünüyor"): yeni yolda yaratıkların sırası düğümler taşınmadan `canvas_item_set_draw_index` ile
## verilir (yukarıdaki not). Godot ise Main'in bir çocuğu AĞAÇTAN ÇIKINCA (ölen yaratık, biten FX/küre/hasar yazısı...) ondan sonraki TÜM kardeşlerin çizim indeksini ağaç sırasına geri sarar
## (NOTIFICATION_MOVED_IN_PARENT). Düzeltme en erken sonraki 2 karelik güncellemede geldiği için o kare(ler)de arkadaki yaratık öndekinin üstüne çiziliyordu (gerçek renderer ekran görüntüsüyle
## doğrulandı: çocuk silinince bir kare boyunca ters sıra) - büyük sprite'lı Yeraltı Canavarı uzuvlarında göze batıyordu. Çocuk çıkınca/sırası değişince bayrak kalkar, sıra o karenin ÇİZİMİNDEN
## HEMEN ÖNCE (RenderingServer.frame_pre_draw: süreç + silme kuyruğu bitmiş) yeniden uygulanır.
var _draw_order_dirty: bool = false


func _install_draw_order_guard() -> void:
	if not child_exiting_tree.is_connected(_mark_draw_order_dirty):
		child_exiting_tree.connect(_mark_draw_order_dirty)
	if has_signal(&"child_order_changed") and not is_connected(&"child_order_changed", _mark_draw_order_dirty):
		connect(&"child_order_changed", _mark_draw_order_dirty)
	if not RenderingServer.frame_pre_draw.is_connected(_on_frame_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)


func _mark_draw_order_dirty(_child: Node = null) -> void:
	_draw_order_dirty = true


func _on_frame_pre_draw() -> void:
	if not _draw_order_dirty:
		return
	_draw_order_dirty = false
	if not is_inside_tree():
		return
	var ew: Object = EnemyWorldBridgeScript.fog_world(get_tree())
	if ew != null:
		_update_creature_draw_order_ew(ew)


## Yeni yol: C++'a kayıtlı yaratıkların ayak y'sini C++ hesaplar (görsel + yerel ayak satırı bir kez set_foot ile verilir);
## kayıtsız olanlar (ölüm animasyonundaki yaratıklar, görev kopyaları, müttefikler) burada hesaplanıp ekstra olarak verilir.
## Kural _update_creature_draw_order ile aynı (Main'in doğrudan çocuğu, görünür, ayak y'sine göre); fark: ağaçtaki sıra
## değişmez, görünür düğümlerin işgal ettiği indeksler ayak sırasıyla canvas draw index olarak dağıtılır.
func _update_creature_draw_order_ew(ew: Object) -> void:
	for n in ew.call("foot_missing"):
		var n2 := n as Node2D
		if n2 == null:
			continue
		var vis: Node2D = _find_creature_visual(n2)
		ew.call("set_foot", int(n2.get("_ew_slot")), vis, _visual_foot_local(vis) if vis != null else 0.0)
	var extras: Array = []
	var foot := PackedFloat32Array()
	var seen: Dictionary = {}
	var cand: Array = EnemyWorldBridgeScript.fog_extra_enemies(get_tree())
	for group_name in CREATURE_SORT_GROUPS:
		if group_name != "enemies":
			cand.append_array(get_tree().get_nodes_in_group(group_name))
	for n in cand:
		var n2 := n as Node2D
		if n2 == null or not is_instance_valid(n2) or n2.get_parent() != self or seen.has(n2) or not n2.visible:
			continue
		seen[n2] = true
		extras.append(n2)
		foot.append(_creature_foot_y(n2))
	ew.call("draw_order", self, extras, foot)


## Yaratığın ayaklarının dünya y'si. Görsel (Sprite2D / AnimatedSprite2D) bulunamazsa kök noktası.
func _creature_foot_y(n: Node2D) -> float:
	## Serbest bırakılmış bir referans tipli değişkene atanırsa hata verir (bkz. GDScript freed == null notu) - önce kontrol.
	## get_meta(ad, null) varsayılanı "yok" sayılıp hata basıyor - has_meta ile.
	var vis_v: Variant = n.get_meta("_foot_visual") if n.has_meta("_foot_visual") else null
	var vis: Node2D = vis_v if is_instance_valid(vis_v) else null
	if vis == null:
		vis = _find_creature_visual(n)
		if vis == null:
			return n.global_position.y
		n.set_meta("_foot_visual", vis)
		n.set_meta("_foot_local", _visual_foot_local(vis))
	var local: float = n.get_meta("_foot_local")
	return vis.global_position.y + local * absf(vis.global_scale.y)


func _find_creature_visual(n: Node) -> Node2D:
	for child_name in ["Sprite2D", "AnimatedSprite2D"]:
		var c: Node = n.get_node_or_null(child_name)
		if c is Sprite2D or c is AnimatedSprite2D:
			return c as Node2D
	for c in n.get_children():
		if c is Sprite2D or c is AnimatedSprite2D:
			return c as Node2D
	return null


## Görselin kendi yerel koordinatında ayak satırının y'si (ölçekten önce). Ölçülemezse karenin alt kenarı.
func _visual_foot_local(vis: Node2D) -> float:
	var tex: Texture2D = null
	var frame_size := Vector2.ZERO
	var key := ""
	var centered := true
	var offset := Vector2.ZERO
	if vis is Sprite2D:
		var s := vis as Sprite2D
		tex = s.texture
		centered = s.centered
		offset = s.offset
		if tex:
			frame_size = tex.get_size() / Vector2(maxi(s.hframes, 1), maxi(s.vframes, 1))
			key = "%s|%d|%d" % [tex.resource_path, s.hframes, s.vframes]
	elif vis is AnimatedSprite2D:
		var a := vis as AnimatedSprite2D
		centered = a.centered
		offset = a.offset
		if a.sprite_frames and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			tex = a.sprite_frames.get_frame_texture(a.animation, 0)
			if tex:
				frame_size = tex.get_size()
				var atlas_region: Rect2 = (tex as AtlasTexture).region if tex is AtlasTexture else Rect2()
				key = "%s|%s" % [tex.resource_path if tex.resource_path != "" else str(tex.get_rid()), atlas_region]
	if tex == null or frame_size.y <= 0.0:
		return offset.y
	var foot_row: float = frame_size.y
	if key != "" and _foot_row_cache.has(key):
		foot_row = _foot_row_cache[key]
	else:
		var img: Image = tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var fr := Rect2i(Vector2i.ZERO, Vector2i(frame_size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var used: Rect2i = img.get_region(fr).get_used_rect()
			if used.size.y > 0:
				foot_row = float(used.end.y)
		if key != "":
			_foot_row_cache[key] = foot_row
	return offset.y + foot_row - (frame_size.y * 0.5 if centered else 0.0)


func _process_multiplayer_sync(delta: float) -> void:
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		var cur_anim: String = ""
		if player.anim:
			cur_anim = player.anim.animation
		var weapon_keys: Array = []
		var weapon_tiers: Dictionary = {}
		var ench_tiers: Array = []
		var any_ench: bool = false
		for weapon: Node in player.owned_weapon_nodes:
			var weapon_key: String = str(weapon.get_meta("shop_key", ""))
			if not weapon_key.is_empty():
				weapon_keys.append(weapon_key)
				weapon_tiers[weapon_key] = int(weapon.get("tier") if "tier" in weapon else 1)
				var et: int = int(weapon.get("enchant_glow_tier")) if "enchant_glow_tier" in weapon else 0
				ench_tiers.append(et)
				any_ench = any_ench or et > 0
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
		_transform_seq = (_transform_seq + 1) & 0xFFFF
		## Sadece Main'i hazır peer'lere (bkz. NetworkManager.main_rpc_targets): yükleme ekranındaki geri katılana / lobideki yabancıya gitmez.
		for target_peer: int in NetworkManager.main_rpc_targets():
			_rpc_update_player_transform.rpc_id(target_peer, player.global_position, cur_anim, _transform_seq)

		## Vampir Çocuk'un R yarasaları (bkz. vampir_bat_swarm.gd): 6 yarasanın dünya konumu bu SÜREKLİ
		## (unreliable, ~20Hz) kanaldan gider - hedef seçimi/hasar SADECE bu istemcide olduğu için diğer
		## istemcilerin yarasaları görebilmesinin tek yolu konumlarının yayınlanması. Sürü kapandığında
		## bir kez BOŞ dizi gönderilir (uzak kopya kendini siler; paket kaybolursa uzak taraf zaman
		## aşımıyla da siler, bkz. remote_player.gd VAMPIR_BATS_TIMEOUT).
		if player.has_method("get_vampir_swarm_net_positions"):
			var bat_positions: PackedVector2Array = player.get_vampir_swarm_net_positions()
			if not bat_positions.is_empty() or _vampir_bats_last_sent_nonempty:
				for target_peer: int in NetworkManager.main_rpc_targets():
					_rpc_update_vampir_bats.rpc_id(target_peer, bat_positions)
			_vampir_bats_last_sent_nonempty = not bat_positions.is_empty()

		# 2) DURUM kanalı: can, kalkan, silah envanteri, durum efektleri gibi
		# NADİREN değişen veriler artık burada toplanıp SADECE bir öncekinden
		# farklıysa (ya da aşağıdaki heartbeat'te) gönderiliyor - bkz. yukarıki
		# _last_sent_extra_state yorumu.
		var extra: Dictionary = {
			"is_invisible": player.is_invisible if "is_invisible" in player else false,
			## Büyücü Kız "Yükseliş" (R1 evrimi): Meteor kanalında havada - kukla yükselir, host'ta hedef alınamaz (remote_player.gd).
			"byc_fly": player.is_buyucu_airborne() if player.has_method("is_buyucu_airborne") else false,
			"is_shielded": player.is_shielded if "is_shielded" in player else false,
			## Elara'nın Sıvışma'sı (Q, id 12) - "yaratıkların içinden geçebilme" isteği diğer istemcilerde
			## de doğru çalışsın diye (bkz. remote_player.gd is_ghost_now/enemy.gd sert yapıştırma kontrolü).
			## Vampir'in Yarasa Formu'ndaki AYNI ihtiyaç animasyon adından çıkarılabiliyordu (bkz. remote_
			## player.gd _vampir_bat_form), Elara'nın özel bir animasyonu olmadığı için AYRI bir bayrak gerekiyor.
			"elara_evasion": player._elara_evasion_timer > 0.0 if "_elara_evasion_timer" in player else false,
			## Ninja'nın El Kitabı (eşya): host'taki yaratıklar bu oyuncunun kuklasını itmesin (remote_player is_ghost_now).
			"ninja": player.has_item("ninjanin_el_kitabi") if player.has_method("has_item") else false,
			## Ruhani Yetenek "Savaş Şevki" - infaz kontrolünün diğer istemcilerde de doğru çalışması için
			## (bkz. enemy.gd _attacker_has_savas_sevki, remote_player.gd has_savas_sevki). Seçim kendisi
			## ("hangi ruhani yetenek") ağa hiç gitmiyor (bkz. lobby_menu.gd notu) - sadece bu TEK bayrak.
			"has_savas_sevki": player.has_savas_sevki() if player.has_method("has_savas_sevki") else false,
			## Denge turu (2026-09-24): düşme/XP kararları host'ta verildiği için öldüren/toplayan UZAK oyuncunun
			## statları host'taki kuklasında olmalı - bkz. enemy.gd _killer_node (şans, Şanslı Zar altını) ve
			## xp_orb.gd/network_manager.gd XP toplama (Tecrübe Kazanımı). Değerler nadiren değişir (değişince gider).
			"luck": player.luck if "luck" in player else 0.0,
			"extra_gold": player.item_extra_gold_chance if "item_extra_gold_chance" in player else 0.0,
			"exp_gain": player.exp_gain_percent if "exp_gain_percent" in player else 0.0,
			"elara_double": player.elara_double_fire_active if "elara_double_fire_active" in player else false,
			## Elara E (Gerçek Hasar / odak) açık mı - uzak kopyada kehribar halka + silah parıltısı (elara_fx.gd, madde 178).
			"elara_focus": player.elara_true_damage_active if "elara_true_damage_active" in player else false,
			"talon_giant": player._talon_ulti_active if "_talon_ulti_active" in player else false,
			## Talon Ayna Formu (R) aktif mi - diger oyuncularda +%10 boyut ve alev aurasi icin (remote_player.gd _talon_form_active).
			## "talon_formation" bunun yerine gecmez: Silah Salvosu (E) acikken o "salvo" doner, R bilgisi kaybolurdu.
			"talon_form": player._talon_mirror_form_active if "_talon_mirror_form_active" in player else false,
			## Talon'un Silah Salvosu (E)/Ayna Formu (R) yetenekleri silahları
			## karakter etrafında dairesel dizer (bkz. player.gd
			## _talon_set_weapons_circular) - bu SADECE yerel/yetkili weapon.gd
			## node'larını taşır, remote_player.gd'nin kozmetik ikon kopyaları bu
			## dizilimi BAŞKA hiçbir kanaldan öğrenemez. "" / "salvo" / "mirror"
			## (bkz. remote_player.gd _update_talon_formation).
			"talon_formation": ("salvo" if ("_talon_weapon_salvo_active" in player and player._talon_weapon_salvo_active) else ("mirror" if ("_talon_mirror_form_active" in player and player._talon_mirror_form_active) else "")),
			"matthew_dome": player.matthew_dome_active if "matthew_dome_active" in player else false,
			## Oakley Koruyucu Büyü (R) hedefi mi - diğer oyuncularda yeşil yaprak bariyeri için (remote_player.gd _oakley_bond_on).
			"oakley_bond": player.oakley_bond_active if "oakley_bond_active" in player else false,
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
			## Gerçek yürüme hızı (bkz. player.gd get_effective_move_speed) - host'taki "Kopyanı Öldür" kopyası bu
			## oyuncuyu kopyalıyorsa hızını buradan alır (RemotePlayer'ın kendi hız bilgisi yok).
			"move_speed": player.get_effective_move_speed() if player.has_method("get_effective_move_speed") else 0.0,
			## Kalıcı hız (yetenek buff'sız) - host'taki "Kopyanı Öldür" kopyası bunu kopyalar (bkz. mission_player_copy.gd).
			"base_speed": player.get_base_move_speed() if player.has_method("get_base_move_speed") else 0.0,
			## Taban "Hasar" statı - host'taki kopya bu oyuncunun silah hasarını bundan türetir (bkz. mission_player_copy.gd).
			"dmg": player.damage_bonus,
			## 2026-10-11: host'taki kopya bu oyuncunun saldırı hızını ve kritik değerlerini de kopyalar (bkz. mission_player_copy.gd).
			"atk_iv": player.get_attack_interval_mult() if player.has_method("get_attack_interval_mult") else 1.0,
			"cc": float(player.get("crit_chance_bonus")) if "crit_chance_bonus" in player else 0.0,
			"cd": float(player.get("crit_damage_bonus")) if "crit_damage_bonus" in player else 0.0,
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
			## shield_enchant_defs.gd/_owned_shield_type_key/shield_visual.set_shield_type)
			## hiç senkronize edilmiyordu; uzak oyuncular her zaman varsayılan
			## (standart) baloncuk görselini görüyordu.
			"shield_type": player._owned_shield_type_key() if player.has_method("_owned_shield_type_key") else "",
			## Şovalye Adam'ın Koruma Bariyeri (skill3 id 29) - bu oyuncu
			## şu an buflanmış mı (bkz. player.gd damage_redirect_percent/
			## has_active_damage_redirect_barrier) - shield_bubble_visible
			## ile AYNI desen, sadece görsel bir bayrak, gerçek mekanik
			## (hasar yansıtma) zaten player.gd take_damage()'ında.
			"barrier_link_active": player.has_active_damage_redirect_barrier() if player.has_method("has_active_damage_redirect_barrier") else false,
			## Şovalye Adam E (Koruma Bariyeri) açık mı - Şovalye'nin KENDİ üstündeki "hasarı üstüne çekme" efekti diğer
			## oyuncularda da görünsün (bkz. player.gd paladin_guard_active / remote_player.gd _refresh_paladin_guard_visual).
			"paladin_guard": player.paladin_guard_active if "paladin_guard_active" in player else false,
			## Ruhani Yetenek "Kalkan Bağı" - BUG DÜZELTMESİ (bkz. remote_player.gd _refresh_kalkan_bagi_link_
			## visual üstündeki not): barrier_link_active ile AYNI desen, ama bir bool yerine partnerin
			## peer_id'sini taşıyor çünkü fx_kalkan_bagi_link.gd karşı ucun KONUMUNU bulmak için buna ihtiyaç
			## duyuyor - salt "aktif mi" yetmiyor.
			"kalkan_bagi_partner_peer_id": player._kalkan_bagi_partner_peer_id if "_kalkan_bagi_partner_peer_id" in player else 0,
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
			## Alınan hasar (kullanıcı isteği 2026-10-18: "grup istatistiklerinde alınan hasar da olmalı hem pc hem mobilde") -
			## aynı canlı panel (party_panel.gd _refresh_stats_popup) müttefiğin player.gd match_damage_taken'ını buradan okur.
			"dmg_taken": player.match_damage_taken,
			## Yetenek evrimleri (2026-09-28, player.gd skill_evolutions) - diğer oyuncularda kuklanın görsel kararları ve
			## host'taki simülasyon (Talon mermi kalkanı) bu listeden okur (remote_player.gd has_evo). Sıralı dizi: değişmedikçe
			## aynı kalır, durum kanalını boşuna tetiklemez.
			"evo": player.get_skill_evolution_ids() if player.has_method("get_skill_evolution_ids") else [],
			## Efsun mermi kalkanı (2026-09-30, player.gd get_enchant_ward_radius) - host'ta düşman mermileri kuklaya sorar.
			"ench_ward": player.get_enchant_ward_radius() if player.has_method("get_enchant_ward_radius") else 0.0,
		}
		## Efsun kademesi parıltısı (2026-10-04, enchant_weapon_glow.gd) - weapon_keys ile aynı sıra; efsunsuzken hiç eklenmez.
		if any_ench:
			extra["ench_tiers"] = ench_tiers
		# Character modulate color for status effects
		## DÜZELTME (derin multiplayer görsel denetimi): bazı yetenekler
		## (ör. Büyücü Kız Don Nova/Meteor, Assasin Görünmezlik/Gölge Hücumu)
		## tonu KÖK `player.modulate` üzerine
		## uyguluyor, `player.anim.modulate` üzerine değil - Godot'ta
		## CanvasItem modulate alt öğelere çarpımsal olarak yayıldığı için
		## caster'ın kendi ekranında ikisi de doğru görünüyordu ama eskiden
		## sadece anim.modulate gönderiliyordu, kök tonlama hiç senkronize
		## edilmiyordu. İkisinin çarpımını (caster'ın GERÇEKTEN gördüğü etkin
		## renk) gönderiyoruz.
		if player.anim and is_instance_valid(player.anim):
			extra["modulate"] = player.modulate * player.anim.modulate
		## Suriyeli Hadime: Q'da havaya süzülme, Karabasan formu, hayalet + cesedin yeri/klibi (bkz. player.gd
		## get_hadime_net_state / remote_player.gd _apply_hadime_net_state). Diğer karakterlerde anahtar hiç eklenmez.
		if player.has_method("get_hadime_net_state"):
			var hadime_state: Dictionary = player.get_hadime_net_state()
			if not hadime_state.is_empty():
				extra["hadime"] = hadime_state
		## Matthew (2026-10-12 rework, madde 98): Elektrik Topu formu, güçlenmiş yıldırım izi, kalkan parıltı basamağı (bkz. player.gd
		## matthew_net_state / remote_player.gd _apply_matthew_net_state). Diğer karakterlerde anahtar hiç eklenmez.
		if GameManager.selected_char_id == 3 and player.has_method("matthew_net_state"):
			extra["mt"] = player.matthew_net_state()
		## Cadı (2026-10-13): [Q açık mı, süpürgede mi] (bkz. player.gd get_cadi_net_state / remote_player.gd _apply_cadi_net_state).
		## Diğer karakterlerde anahtar hiç eklenmez.
		if GameManager.selected_char_id == 15 and player.has_method("get_cadi_net_state"):
			extra["cadi"] = player.get_cadi_net_state()
		## Cadı'nın süpürgesinde YOLCULUK (HER karakter): süpürgesine bindiğimiz cadının peer id'si. Binmiyorken anahtar yok.
		if "cadi_ride_host_peer" in player and int(player.cadi_ride_host_peer) != 0:
			extra["cride"] = int(player.cadi_ride_host_peer)

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
			for target_peer: int in NetworkManager.main_rpc_targets():
				_rpc_update_player_extra_state.rpc_id(
					target_peer,
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
	## HAYALET OYUNCU DÜZELTMESİ (2026-10-12, Epic odası: "oyuncu adında sahte oyuncular grupta"): ayrılan peer'den kuyrukta kalan son
	## güvenilir paket kopma sinyalinden SONRA işlenince lobby_players'ta olmayan gönderen için "Oyuncu" adlı kukla doğuyordu; ayrılış
	## bildirimi bir kez geldiği için kimse onu silmiyor, düşmanlar ona vurdukça host kapalı ID'ye RPC yağdırıyordu ("unknown peer ID").
	## Artık lobiden silinmiş / bağlı olmayan gönderen kukla doğuramaz.
	if allow_spawn and not _remote_players.has(sender_id) and NetworkManager.lobby_players.has(sender_id) \
			and multiplayer.get_peers().has(sender_id):
		var pinfo: Dictionary = NetworkManager.lobby_players.get(sender_id, {})
		_spawn_remote_player(sender_id, pinfo.get("char_id", 1), pinfo.get("name", "Oyuncu"))
	return _remote_players.get(sender_id, null)


## Konum paketlerinin sıra numarası (2026-10-08 MP denetimi bulgusu 4): kanal güvenilmez + sırasız, internette (Epic) ya da paket kaybı
## sonrası eski bir paket yenisinin ARDINDAN gelip kuklayı geri sıçratabiliyordu. uint16 sarar; alıcı eski/aynı numarayı atar.
## Kanal tipi (unreliable_ordered / aktarım kanalı) Epic'te garanti değil - bu yüzden sıra uygulama düzeyinde.
const EnemySyncCodecScript := preload("res://scripts/enemy_sync_codec.gd") ## seq_newer: konum paketi sıra kuralı
var _transform_seq: int = 0
var _remote_transform_last: Dictionary = {} ## gönderen peer -> [son seq, son kabul ms]
const TRANSFORM_RESYNC_MSEC := 1500 ## bu süredir yeni paket gelmediyse gelen numara (sayaç sıfırlanmış olabilir) kabul edilir


func _is_stale_transform(sender_id: int, seq: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var rec: Array = _remote_transform_last.get(sender_id, [])
	if rec.is_empty():
		_remote_transform_last[sender_id] = [seq, now]
		return false
	if EnemySyncCodecScript.seq_newer(seq, int(rec[0])) or now - int(rec[1]) > TRANSFORM_RESYNC_MSEC:
		_remote_transform_last[sender_id] = [seq, now]
		return false
	return true


@rpc("any_peer", "unreliable")
func _rpc_update_player_transform(pos: Vector2, cur_anim: String, seq: int = 0) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	if _is_stale_transform(sender_id, seq):
		return
	## bkz. _get_or_spawn_remote_player üstündeki DÜZELTME notu - saf konum
	## paketi TEK BAŞINA asla yeni bir kukla oluşturamaz.
	var rp: RemotePlayer = _get_or_spawn_remote_player(sender_id, false)
	if rp and is_instance_valid(rp):
		rp.update_position_and_anim_from_net(pos, cur_anim)


## Vampir Çocuk R yarasa konumları (bkz. _process_multiplayer_sync) - kozmetik sürüyü sürer.
@rpc("any_peer", "unreliable")
func _rpc_update_vampir_bats(positions: PackedVector2Array) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	var rp: RemotePlayer = _get_or_spawn_remote_player(sender_id, false)
	if rp and is_instance_valid(rp) and rp.has_method("update_vampir_bats_from_net"):
		rp.update_vampir_bats_from_net(positions)


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
## BAŞLANGIÇ SİLAHI / KALKANI (bkz. weapon_catalog.gd)
## ==============================================================================

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


## Kullanıcı isteği (2026-10-03): "bundan sonra başlangıç silahı karakter seçim ekranından seçilsin ... başlangıçtaki silah
## seçme kartını kaldırıyoruz" - eskiden oyun başladıktan 2 sn sonra 3 rastgele silah kartı açılıp oyunu duraklatıyor,
## çok oyunculuda herkesin seçmesi bekleniyordu. Artık silah menüde seçildiği için (GameManager.selected_start_weapon)
## oyun duraklamadan, kimseyi beklemeden başlar: seçilen silah + herkesin Standart Kalkanı hemen verilir. Dükkan açıksa
## (GameManager.SHOP_ENABLED) ilk periyodik dükkan eskisi gibi oyun başında araya girer.
func _start_initial_loadout_selection() -> void:
	if not GameManager.owned_weapons.is_empty():
		return ## başka bir yol zaten doldurmuş (güvenlik payı)
	if not is_instance_valid(player):
		return
	_grant_selected_item(WeaponCatalog.selected())
	_grant_starting_shield()
	if GameManager.SHOP_ENABLED:
		_show_mini_shop_screen()


func _grant_selected_item(key: String) -> void:
	if not is_instance_valid(player):
		return
	GameManager.owned_weapons.append(EnchantDefs.new_weapon_entry(key, 1, 0))
	player.buy_weapon_copy(key, 1) ## bkz. player.gd - kendi içinde _reposition_weapon_icons() zaten çağırıyor

## Herkesin başlangıç kalkanı: Standart Kalkan, seviye 1. Kalkan artık ne başlangıçta seçiliyor ne de dükkandan/seyyar
## satıcıdan alınıyor. Eskiden başlangıçta seçilen kalkan gibi boş başlar ve kendi kendine dolar (bkz. player.gd
## refresh_shield_stats).
func _grant_starting_shield() -> void:
	if not is_instance_valid(player):
		return
	GameManager.shield_standart_level = 1
	if player.has_method("refresh_shield_stats"):
		player.refresh_shield_stats()


## ==============================================================================
## ORTAK LEVEL ATLAMA AKIŞI
## ==============================================================================
var _pending_level_ups: int = 0
var _active_level_up_screen: Node = null
## Açılacak level-up ekranlarının seviyeleri (FIFO, bkz. _on_team_leveled_up / _show_level_up_screen).
var _level_up_screen_levels: Array[int] = []
## Bu oyuncunun kart/silah/kalkan seçim kuyruğu (bkz. _finish_level_up_phase)
## TAMAMEN bitti ama diğer oyuncu(lar) hâlâ meşgulken - "artık kimse meşgul
## değil" anını yakalayınca (bkz. _on_level_up_busy_state_changed) bir kez
## çağrılıp temizlenecek devam adımı (ör. sandık kuyruğuna geçiş, ya da mini
## dükkanı açma).
var _level_up_wait_resume_action: Callable = Callable()
## Oyuncular bekleniyor ekranı (wait_overlay.gd "level_up") - kart/silah/kalkan seçim kuyruğu için.
var _level_up_wait_overlay: CanvasLayer = null
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
## closed) - wait_overlay.gd "shop" (sayaç/kim dükkanda NetworkManager mini_shop_* verisinden).
var _mini_shop_wait_overlay: CanvasLayer = null
## Kullanıcı isteği: "bir kişi dükkanda çarpıya basınca diğerlerinin bekleme
## süresi başlayacak." - dükkanı hâlâ açık olan oyuncuya kalan süreyi gösteren
## küçük (tıklamayı engellemeyen) bildirim ve "ben dükkanı kapattım mı" bayrağı.
var _mini_shop_countdown_notice: CanvasLayer = null
var _mini_shop_countdown_notice_label: Control = null ## game_notice.gd levhası (canlı geri sayım)
var _mini_shop_closed_locally: bool = false
## #58: bkz. _try_open_next_pending_chest/_on_chest_busy_state_changed.
var _local_chest_menu_open: bool = false
var _chest_wait_overlay: CanvasLayer = null ## wait_overlay.gd "chest"

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
## KULLANICI İSTEĞİ (2026-09-21): "level atlama için gereken exp toplamama bekleme süresini multiplayerda 0.5 saniyeye
## düşür" - çok oyunculuda ekran 0.5 sn sessizlikten sonra açılır (tek oyunculu 1 sn olarak kalır).
const XP_PICKUP_SETTLE_DELAY_MULTIPLAYER := 0.5
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
	## Her level-up ekranının HANGİ seviyeye ait olduğu (yetenek evrimleri 5/10/15... seviyelerde kart yerine gelir) - ekranlar
	## sırayla açıldığı için FIFO. Eskiden ekran açılırken sadece GÜNCEL takım seviyesi biliniyordu: 4'ten 6'ya hızlı
	## atlanınca iki ekran da "6" sayılır, 5. seviyenin evrimi kaybolurdu.
	_level_up_screen_levels.append(new_level)
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
		var settle_delay: float = XP_PICKUP_SETTLE_DELAY_MULTIPLAYER if NetworkManager.is_multiplayer_active else XP_PICKUP_SETTLE_DELAY
		var remaining: float = settle_delay - elapsed
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
	## Host'un "kalıcı öldü" kaydı da silinir (2026-10-07): eskiden kalıyordu, diğerleri ölünce canlı oyuncu ölü sayılıp oyun erken bitiyordu.
	NetworkManager.report_self_alive_again()


## Kalıcı ölü oyuncunun diriltme hakkı yenilenince/varken yakında bir kurtarıcı olduğunda "yerde yatan" (kurtarılabilir) duruma
## dönmesi (bkz. player.gd _rise_from_permadeath_to_downed): izleyici modu ve ölüm ekranı kalkar, host kalıcı ölü kaydını siler.
func _on_player_rose_from_permadeath() -> void:
	_end_spectate_mode()
	if _death_overlay_layer and is_instance_valid(_death_overlay_layer):
		_death_overlay_layer.queue_free()
	_death_overlay_layer = null
	_death_overlay_label = null
	NetworkManager.report_self_alive_again()


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
	## 2026-09-27: alttaki oyuncu panelinin (hud.gd dock) üstünde.
	panel.offset_top = -300.0
	panel.offset_bottom = -230.0
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	## 2026-09-24: oyun içi bej kit penceresi (menülerle aynı dil).
	panel.theme = UIKit.theme()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	_mini_shop_revive_button = Button.new()
	_mini_shop_revive_button.add_theme_font_size_override("font_size", UIKit.FS_BODY)
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


## Bekleme ekranları (dükkan / sandık / level atlama - yalnız çok oyunculu): "B Ateş Işığı Şeridi" (wait_overlay.gd, madde 264) -
## vinyet + yatay koyu şerit, herkesin portresi + hazır/bekleniyor durumu + geri sayım. Eskiden ortada 720x220 bej kit penceresi.
## Periyodik dükkan
## molasında çok oyunculuda "herkes kapatana kadar" bekleme ekranı.
func _show_mini_shop_wait_overlay() -> void:
	if _mini_shop_wait_overlay and is_instance_valid(_mini_shop_wait_overlay):
		return
	_mini_shop_wait_overlay = WaitOverlayScript.open(self, "shop")


func _hide_mini_shop_wait_overlay() -> void:
	if _mini_shop_wait_overlay and is_instance_valid(_mini_shop_wait_overlay):
		_mini_shop_wait_overlay.queue_free()
	_mini_shop_wait_overlay = null


func _on_mini_shop_countdown_tick(remaining: float) -> void:
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
		## 2026-10-18 (madde 264): düz sarı yazı yerine bildirim levhası (game_notice.gd), sağda canlı "N sn"
		var n: Control = GameNoticeScript.toast("warn", "Bir oyuncu dükkanı kapattı", "Süre dolunca dükkan kapanır.", 0.0, MobileUI.enabled)
		n.call("set_countdown", remaining) ## boyut sayaçla belli olur - yerleştirmeden önce
		n.set_anchors_preset(Control.PRESET_CENTER_TOP)
		n.offset_left = -roundf(n.size.x * 0.5)
		n.offset_right = n.offset_left + n.size.x
		n.offset_top = 24.0
		n.offset_bottom = 24.0 + n.size.y
		_mini_shop_countdown_notice.add_child(n)
		_mini_shop_countdown_notice_label = n
		add_child(_mini_shop_countdown_notice)
	_mini_shop_countdown_notice_label.call("set_countdown", remaining)


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
	## Bu ekranın seviyesi (yetenek evrimi seviyesiyse level_up_screen.gd evrim kartlarını gösterir).
	var screen_level: int = _level_up_screen_levels.pop_front() if not _level_up_screen_levels.is_empty() else new_level
	screen.set("screen_level", screen_level)
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
		## Yetenek evrimi kartı (level_up_screen.gd evrim modu, "evo:<id>") - stat kartı değil.
		if id.begins_with(EVO_CHOICE_PREFIX):
			if player.has_method("apply_skill_evolution"):
				player.apply_skill_evolution(id.substr(EVO_CHOICE_PREFIX.length()))
		else:
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


## ================================================================ EFSUN EKRANI (2026-09-25)
## 2026-10-07'den beri sadece debug menüsünden ("Efsun ekranı aç") açılır: elit sandık artık epik eşya veriyor (bkz.
## _show_elite_chest), efsunlar oyundan çıkarıldı (EnchantDefs.enabled). Seçim bitince on_done çağrılır.
var _active_enchant_screen: Node = null


## intro_chest: ekran önce elit sandığın açılışını oynatır, kartlar sandıktan fırlar (enchant_screen.gd; efsun elit sandığı geri
## getirilirse kullanılır).
func _show_enchant_screen(on_done: Callable, intro_chest: bool = false) -> void:
	if is_instance_valid(player) and player.has_method("clear_input_state"):
		player.call("clear_input_state")
	get_tree().paused = true
	_hide_level_up_wait_overlay()
	var screen: CanvasLayer = EnchantScreenScript.new()
	screen.name = "EnchantScreen"
	screen.player_ref = player
	screen.use_chest_timer = true
	screen.intro_chest = intro_chest
	add_child(screen)
	_active_enchant_screen = screen
	screen.enchant_chosen.connect(func(choice: Dictionary) -> void:
		if str(choice.get("type", "")) != "skip" and is_instance_valid(player) and player.has_method("apply_enchant_choice"):
			player.apply_enchant_choice(choice)
		if is_instance_valid(screen):
			screen.queue_free()
		_active_enchant_screen = null
		on_done.call())


## Elit sandık (kullanıcı isteği 2026-10-07: "bundan sonra elit sandıklardan sadece epik item çıkacak çünkü efsunları
## kaldırmıştık"): normal sandıkla AYNI menü (chest_menu.gd), elit modda - elit sandık animasyonu, epik eşya kartı, AL/SAT.
## (2026-09-25'te elit sandık efsun ekranı açıyordu; o ekran sadece debug menüsünden / EnchantDefs.enabled ile açılır.)
## Menü kapanınca on_done (kuyruğun sonraki adımı) çağrılır.
func _show_elite_chest(on_done: Callable) -> void:
	if is_instance_valid(player) and player.has_method("clear_input_state"):
		player.call("clear_input_state")
	get_tree().paused = true
	_hide_level_up_wait_overlay()
	var menu: CanvasLayer = ChestMenuScene.instantiate() as CanvasLayer
	add_child(menu)
	menu.setup(player, 0, true)
	menu.closed.connect(on_done, CONNECT_ONE_SHOT)


## Debug menüsü (debug_menu.gd "Evrim ekranı aç", 2026-09-28): seviye beklemeden evrim kartları - tüm yuvalar açıkmış gibi
## (R dahil). Sadece bu oyuncunun oyunu durur, seçince devam eder (level-up kuyruğuna/çok oyunculu meşgul durumuna dokunmaz).
func debug_open_evolution_screen() -> bool:
	if _active_level_up_screen != null and is_instance_valid(_active_level_up_screen):
		return false
	if not is_instance_valid(player) or not SkillEvolutionsScript.has_evolutions(GameManager.selected_char_id):
		return false
	get_tree().paused = true
	var screen = LevelUpScreenScene.instantiate()
	screen.name = "LevelUpScreen"
	screen.set("screen_level", 99)
	screen.set("force_evolution", true)
	add_child(screen)
	_active_level_up_screen = screen
	screen.upgrade_chosen.connect(func(id: String, _tier: int) -> void:
		if id.begins_with(EVO_CHOICE_PREFIX) and is_instance_valid(player):
			player.apply_skill_evolution(id.substr(EVO_CHOICE_PREFIX.length()))
		if is_instance_valid(screen):
			screen.queue_free()
		_active_level_up_screen = null
		get_tree().paused = false)
	return true


## Debug menüsü "Tüm evrimleri ver": karakterin bütün evrimleri (finaller en sonda).
func debug_grant_all_evolutions() -> int:
	if not is_instance_valid(player) or not player.has_method("apply_skill_evolution"):
		return 0
	var n: int = 0
	for final_pass in [false, true]:
		for slot in SkillEvolutionsScript.SLOTS:
			for e in SkillEvolutionsScript.slot_list(GameManager.selected_char_id, slot):
				if bool(e.get("final", false)) == final_pass and not player.has_evo(str(e["id"])):
					player.apply_skill_evolution(str(e["id"]), true)
					n += 1
	return n


## Debug menüsü (debug_menu.gd "Efsun ekranı aç"): level beklemeden efsun ekranı. Çok oyunculuda diğer oyuncuları
## bekletmez (meşgul durumu yayınlanmaz), seçim bitince sadece bu oyuncunun oyunu devam eder.
func debug_open_enchant_screen() -> void:
	if _active_enchant_screen != null and is_instance_valid(_active_enchant_screen):
		return
	_show_enchant_screen(func() -> void: get_tree().paused = false)


## Debug menüsü (debug_menu.gd "Sandık aç" / "Elit sandık aç"): sandık açılışını level beklemeden gösterir; bitince
## sadece bu oyuncunun oyunu devam eder (sandık kuyruğuna/çok oyunculu meşgul durumuna dokunmaz).
func debug_open_chest(elite: bool) -> void:
	if not is_instance_valid(player) or _active_enchant_screen != null:
		return
	get_tree().paused = true
	var resume := func() -> void: get_tree().paused = false
	if elite:
		_show_elite_chest(resume)
		return
	var menu: CanvasLayer = ChestMenuScene.instantiate() as CanvasLayer
	add_child(menu)
	menu.setup(player, 0)
	menu.closed.connect(resume, CONNECT_ONE_SHOT)


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
		if _active_level_up_screen == null and _active_enchant_screen == null:
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
		## sandık akışının ilk menüsünde kart akışından kalan ORTAK süre devralınır,
		## sonraki sandıklar sayacı sıfırlamaz (bkz. NetworkManager.
		## _begin_shared_wait_clock, chest_menu.gd _on_countdown_tick).
		NetworkManager.start_chest_countdown()
	_hide_chest_wait_overlay()
	## Önce normal sandıklar (parça kartı), sonra elit sandıklar (elit açılış animasyonu + epik eşya kartı, bkz.
	## _show_elite_chest) - 2026-10-07: elit sandıktan efsun değil epik eşya çıkar.
	if GameManager.pending_chest_tiers.is_empty():
		GameManager.pop_pending_elite_chest()
		_show_elite_chest(Callable(self, "_try_open_next_pending_chest"))
		return
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
	## Kullanıcı isteği: "kimi beklediğimiz yazsın" - ekran kimin sandık açtığını (chest_busy_peers) ve 25 sn sayacı kendisi okur.
	_chest_wait_overlay = WaitOverlayScript.open(self, "chest")


func _hide_chest_wait_overlay() -> void:
	if _chest_wait_overlay and is_instance_valid(_chest_wait_overlay):
		_chest_wait_overlay.queue_free()
	_chest_wait_overlay = null


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
	dim.color = Color(0.12, 0.07, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_confirm_dialog.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	## 2026-09-24: oyun içi bej kit penceresi (menülerle aynı dil).
	panel.theme = UIKit.theme()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	_restart_confirm_dialog.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "Host oyunu yeniden başlatmak istiyor.\nOnaylarsanız herkes odaya dönüp\nkarakterini yeniden seçecek. Onaylıyor musunuz?"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(msg, 24, UIKit.C_TEXT, 0)
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var approve_btn := Button.new()
	approve_btn.text = "Onayla"
	approve_btn.custom_minimum_size = Vector2(170, 48)
	UIKit.style_button(approve_btn, "green", false, UIKit.FS_BODY)
	approve_btn.pressed.connect(func():
		NetworkManager.submit_restart_vote(true)
		_hide_restart_confirm_dialog()
	)
	btn_row.add_child(approve_btn)

	var reject_btn := Button.new()
	reject_btn.text = "Reddet"
	reject_btn.custom_minimum_size = Vector2(170, 48)
	UIKit.style_button(reject_btn, "red", false, UIKit.FS_BODY)
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


## Oyuncular bekleniyor ekranı (wait_overlay.gd "level_up") - kart/silah/kalkan seçim kuyruğu için (bkz. _finish_level_up_phase).
## Kim seçiyor (level_up_busy_peers) + 25 sn sayaç ekran tarafından okunur.
func _show_level_up_wait_overlay() -> void:
	if _level_up_wait_overlay and is_instance_valid(_level_up_wait_overlay):
		return
	_level_up_wait_overlay = WaitOverlayScript.open(self, "level_up")


func _hide_level_up_wait_overlay() -> void:
	if _level_up_wait_overlay and is_instance_valid(_level_up_wait_overlay):
		_level_up_wait_overlay.queue_free()
	_level_up_wait_overlay = null



func _on_multiplayer_server_disconnected() -> void:
	if not is_inside_tree():
		return
	push_warning("[Main] Sunucu/Host bağlantısı kesildi.")
	_show_notice("fail", "Sunucu bağlantısı koptu", "Ana menüye dönülüyor...")
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


## Host devri sürerken kısa bilgi (bkz. NetworkManager "HOST DEVRİ" bloğu). Metin boşsa (bitti/vazgeçildi) bir şey gösterilmez.
func _on_host_migration_state(text: String, done: bool) -> void:
	if text != "" and is_inside_tree():
		_show_network_toast(text, 14.0 if not done else 2.4) ## devir sürerken dünya donuk: bildirim bağlanma bitene kadar kalsın


func _on_host_left_game() -> void:
	if not is_inside_tree():
		return
	_show_notice("left", "Host oyundan ayrıldı", "Ana menüye dönülüyor...")
	_return_to_menu_after_disconnect()


func _on_player_left_game(p_name: String, peer_id: int = 0) -> void:
	if not is_inside_tree():
		return
	if not p_name.is_empty():
		## ayrılanın soluk portresi (kukla hemen aşağıda silinir - önce karakterini oku)
		var face: Texture2D = null
		var rp = _remote_players.get(peer_id)
		if rp != null and is_instance_valid(rp):
			var path: String = str(Characters.get_def(int(rp.get("char_id"))).get("portrait", ""))
			if path != "" and ResourceLoader.exists(path):
				face = load(path) as Texture2D
		_show_notice("left", "%s oyundan ayrıldı" % p_name, "", 2.4, -1.0, face)
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


## BİLDİRİMLER - "A Ahşap Levha" (kullanıcı seçimi 2026-10-18, madde 264; çizim scripts/game_notice.gd). Eskiden bej kit levhası +
## düz yazıydı (UIKit "window_tight"). Kendi kendini yok eden, tıklamayı yutmayan levhalar; doğrudan Main'e eklenir.
##  - Sağ sütun (PC): HUD'un sağ sütununun (minimap + grup paneli + görev satırları) ALTINA, sağ kenarı onlarla hizalı; aynı anda
##    birden fazlası ALT ALTA dizilir, satırlar/bildirimler eklenip kalktıkça her karede konum güncellenir.
##  - top_center (kullanıcı isteği 2026-10-05: "kademe atlamalarındaki bildirim ekranın üst ortasında çıksın"): kademe / sonsuz mod /
##    debug uyarısı üst ortada (y=56, FPS etiketi ve sonsuz mod yazısının altı), kendi yığını; boss barı görünürken onun altına.
##  - Telefon (kullanıcı bildirimi 2026-10-03: paneller üst üste): sağ sütun yetenek düğmeleriyle dolu - hepsi üst ortada, 32 px yazı.
var _active_toast_panels: Array = [] ## ekrandaki bildirimler, eskiden yeniye - alt alta dizilirler
## Sağ sütun bildirimlerinin hizalandığı HUD parçaları (minimap + grup paneli; _ready doldurur, bkz. world_event_banner.gd).
var _notice_anchor_controls: Array = []
const NOTICE_RIGHT_TOP_FALLBACK := 292.0


## Genel sistem bildirimi (bağlantı, host devri, yeniden başlatma oylaması...): ilk satır başlık, kalanı gövde.
## Türü belli bildirimler _show_notice / _show_banner_notice kullanır.
func _show_network_toast(text: String, hold_seconds: float = 2.4, top_center: bool = false) -> void:
	var parts: PackedStringArray = text.split("\n", true, 1)
	var body: String = parts[1] if parts.size() > 1 else ""
	if top_center:
		_show_banner_notice("info", parts[0], body, hold_seconds)
	else:
		_show_notice("info", parts[0], body, hold_seconds)


## Sağ sütun bildirimi. kind: game_notice.gd KIND_COLOR (ok/warn/start/fail/merchant/ach/left/info). countdown >= 0: başlıkta
## geri sayan "N sn" (görev uyarısı). portrait: "left" bildiriminde ayrılanın soluk portresi.
func _show_notice(kind: String, title: String, body: String = "", hold_seconds: float = 2.4, countdown: float = -1.0,
		portrait: Texture2D = null) -> Control:
	var n: Control = GameNoticeScript.toast(kind, title, body, hold_seconds, MobileUI.enabled)
	if countdown >= 0.0:
		n.call("set_countdown", countdown)
	if portrait != null:
		n.set("portrait", portrait)
	_present_notice(n, hold_seconds, false)
	return n


## Üst orta duyuru (kurdele + gövde; tier > 0 ise kuru kafa satırı). kind "tier"/"fail" kırmızı kurdele, diğerleri altın.
func _show_banner_notice(kind: String, ribbon_text: String, body: String = "", hold_seconds: float = 4.0, tier: int = 0) -> void:
	_present_notice(GameNoticeScript.banner(kind, ribbon_text, body, hold_seconds, tier), hold_seconds, true)


## Kademe duyurusu: kırmızı kurdelede başlık (KADEME VII / FİNAL KADEME) + altında zorluğu gösteren 6 kuru kafa (tier_display.gd).
func _tier_banner(title: String, tier: int) -> Control:
	return GameNoticeScript.banner("tier", title, "", 4.0, tier)


## Sağ sütun kenarı + üstü: HUD'un minimap + grup paneli parçalarının altı (görev satırları varsa onların altı).
func _notice_column() -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var right_edge: float = vp.x - 10.0
	var top_y: float = NOTICE_RIGHT_TOP_FALLBACK
	var found: bool = false
	for c in _notice_anchor_controls:
		if not (c is Control) or not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
			continue
		var r: Rect2 = (c as Control).get_global_rect()
		if not found:
			right_edge = r.end.x
			top_y = r.end.y
			found = true
		else:
			top_y = maxf(top_y, r.end.y)
	if found:
		top_y += 10.0
	if _world_event_banner and is_instance_valid(_world_event_banner):
		top_y = maxf(top_y, float(_world_event_banner.call("get_rows_bottom_y")) + 8.0)
	return Vector2(right_edge, top_y)


func _present_notice(panel: Control, hold_seconds: float, top_center: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var phone: bool = MobileUI.enabled
	var centered: bool = top_center or phone
	var sz: Vector2 = panel.size
	if centered:
		panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		panel.offset_left = -roundf(sz.x * 0.5)
		panel.offset_right = panel.offset_left + sz.x
	else:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.set_meta("top_center", top_center and not phone)
	layer.add_child(panel)
	_active_toast_panels.append(panel)
	var follow := func() -> void:
		if not is_instance_valid(panel):
			return
		var is_top: bool = bool(panel.get_meta("top_center", false))
		var y: float = 120.0 if phone else 56.0
		if not centered:
			var col: Vector2 = _notice_column()
			y = col.y
			panel.position.x = roundf(col.x - panel.size.x)
		## Üst ortadaki boss barı görünürken üst-orta bildirimler (telefonda tüm bildirimler) onun ALTINA yerleşir.
		if centered and _boss_bar_top and is_instance_valid(_boss_bar_top):
			var bar_bottom: float = float(_boss_bar_top.call("get_bottom_y"))
			if bar_bottom > 0.0:
				y = maxf(y, bar_bottom + 8.0)
		for other in _active_toast_panels:
			if other == panel:
				break
			if is_instance_valid(other) and bool((other as Control).get_meta("top_center", false)) == is_top:
				y += (other as Control).size.y + 8.0
		if centered:
			panel.offset_top = y
			panel.offset_bottom = y + panel.size.y
		else:
			panel.position.y = roundf(y)
	follow.call()
	get_tree().process_frame.connect(follow)
	layer.tree_exiting.connect(func() -> void:
		_active_toast_panels.erase(panel)
		if get_tree().process_frame.is_connected(follow):
			get_tree().process_frame.disconnect(follow))
	var tw := create_tween()
	tw.tween_interval(maxf(0.5, hold_seconds))
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
	_show_notice("merchant", "Seyyar Satıcı geldi", "Konumu haritada işaretlendi.", 4.0)
	EventSfx.play(get_tree(), &"merchant_arrive")
	var minimap: Node = hud.get_node_or_null("MinimapControl")
	if minimap and minimap.has_method("set_merchant_marker"):
		minimap.set_merchant_marker(pos, true)
	if _merchant_arrow and is_instance_valid(_merchant_arrow):
		_merchant_arrow.set_target_active(pos, true)


## Yaratık Kademesi arttı (kullanıcı isteği 2026-10-04) - HER peer'de çalışır (bkz. NetworkManager.broadcast_creature_tier_reached).
## tier == 16 = Final Kademe (enemy_spawner.gd FINAL_TIER).
func _on_creature_tier_reached(tier: int) -> void:
	if tier >= 16:
		CameraShakeScript.add(0.5) ## Final: tüm bosslar geliyor
	## 2026-10-05: sadece "KADEME <ROMEN>" + altında zorluğu gösteren 6 kuru kafa (bkz. tier_display.gd); eski "BAŞLADI - güçlendi" yazısı yok.
	_show_banner_notice("tier", TierDisplayScript.title(tier), "", 4.0, tier)
	GameManager.run_max_tier = maxi(GameManager.run_max_tier, tier)
	_note_run_progress()




## ==============================================================================
## ZAFER + SONSUZ MOD + KOŞU SONU REKOR/BAŞARIM (kullanıcı isteği 2026-10-05). Karar host'ta (enemy_spawner.gd "ZAFER + SONSUZ
## MOD" bloğu), buradaki her şey HER peer'de yerel çalışır; rekorlar/başarımlar herkesin KENDİ makinesinde (run_records.gd).
## ==============================================================================

## Koşunun anlık özeti - ölüm/zafer ekranı ve rekor kaydı AYNI sözlüğü kullanır (bkz. run_records.gd başı).
func _run_summary(victory: bool) -> Dictionary:
	return {
		"time": GameManager.run_elapsed(),
		"tier": GameManager.run_max_tier,
		"kills": GameManager.run_kills,
		"layer": GameManager.endless_layer if GameManager.endless_active else 0,
		"victory": victory or GameManager.victory_reached,
		"solo": not NetworkManager.is_multiplayer_active,
		"char_id": GameManager.selected_char_id,
		"level": GameManager.team_level,
	}


## kind: "progress" (kademe/kat ilerledi) | "victory" | "end" (koşu bitti). Sonuçları _run_results'a biriktirir.
## Debug modu (istediğin yaratığı doğurma) ve headless koşular (testler gerçek rekorları kirletmesin) HİÇ kayıt yazmaz.
func _record_run(kind: String) -> Dictionary:
	var skip: String = _record_skip_reason()
	if skip != "":
		_record_log_once("%s ATLANDI: %s" % [kind, skip])
		return {}
	var s: Dictionary = _run_summary(kind == "victory")
	var result: Dictionary
	match kind:
		"victory":
			result = RunRecordsScript.record_victory(s)
		"end":
			result = RunRecordsScript.record_run_end(s)
			_write_balance_record(s)
		_:
			result = RunRecordsScript.note_progress(s)
			BalanceLogScript.note_tier(GameManager.run_max_tier)
	RunRecordsScript.merge_results(_run_results, result)
	_bank_meta(s, kind, result)
	_record_log("%s yazıldı: süre=%.0f kademe=%d öldürme=%d solo=%s takım=%d" % [kind, float(s.get("time", 0.0)), int(s.get("tier", 0)),
			int(s.get("kills", 0)), str(s.get("solo", true)), BalanceLogScript.multiplayer_peer_count()])
	return result


## Kayıt kararı günlüğü (2026-10-17, madde 223): 4 kişilik 54 dakikalık bir host oyununda rekor/Ruh Kıymığı/balans kaydının HİÇBİRİ yazılmadı ve
## nedeni dosyalardan anlaşılamadı (dört yol da aynı kapıya bağlı: debug modu / headless). Artık her atlama ve yazım user://net_log.txt'ye
## "!kayıt: ..." satırı olarak düşer (solo/debug'da da yazılır, bkz. NetworkManager._net_log "!"). Atlama satırları Main başına BİR kez.
var _record_log_seen: Dictionary = {}
var _meta_tick_count: int = 0


## Kayıt yazımını engelleyen neden (boş = kayıt açık). Debug modu bayrağı işlem boyunca açık kalır (ana menüye dönmek kapatmaz).
func _record_skip_reason() -> String:
	if GameManager.debug_mode_unlocked:
		return "debug modu açık (GameManager.debug_mode_unlocked)"
	if DisplayServer.get_name() == "headless":
		return "headless"
	return ""


func _record_log(msg: String) -> void:
	if DisplayServer.get_name() == "headless":
		return ## testler gerçek net_log'u kirletmesin
	NetworkManager._net_log("!kayıt: " + msg)


func _record_log_once(msg: String) -> void:
	if _record_log_seen.has(msg):
		return
	_record_log_seen[msg] = true
	_record_log(msg)


## RUH KIYMIĞI (bkz. meta_progress.gd): süre + kademe + sonsuz kat puanı BANKALANIR (her çağrıda toplamla bankalanan arasındaki fark
## anında diske yazılır -> bağlantı kopsa/çökse kaybolmaz), zafer ve yeni başarım ödülü bir kez. Kazanç _run_results["shards"]'ta birikir
## (ölüm/zafer ekranında "+N Ruh Kıymığı"). Banka sayacı GameManager'da (host devrinde Main yeniden kurulur).
func _bank_meta(summary: Dictionary, kind: String, result: Dictionary) -> void:
	var gained: int = 0
	var banked: int = MetaProgressScript.bank_run(summary, GameManager.run_shards_banked)
	gained += banked - GameManager.run_shards_banked
	GameManager.run_shards_banked = banked
	if kind == "victory" and not GameManager.run_victory_shards_given:
		GameManager.run_victory_shards_given = true
		gained += MetaProgressScript.grant_victory()
	gained += MetaProgressScript.grant_achievements((result.get("achievements", []) as Array).size())
	_run_results["shards"] = int(_run_results.get("shards", 0)) + gained


func _on_meta_bank_tick() -> void:
	if _run_end_recorded:
		return
	if GameManager.run_record_suppressed:
		_record_log_once("tick ATLANDI: host devri (run_record_suppressed)")
		return
	var skip: String = _record_skip_reason()
	if skip != "":
		_record_log_once("tick ATLANDI: %s" % skip)
		return
	var before: int = GameManager.run_shards_banked
	_bank_meta(_run_summary(false), "tick", {})
	_meta_tick_count += 1
	if _meta_tick_count == 1 or _meta_tick_count % 10 == 0: ## her dakika yazılmaz (54 dk = 54 satır); ilk + her 10. tik
		_record_log("tick #%d: süre=%.0f banka %d -> %d" % [_meta_tick_count, GameManager.run_elapsed(), before, GameManager.run_shards_banked])


## Balans telemetrisi (bkz. balance_log.gd): koşu kaydı yerel dosyaya yazılır; istemciyse host'a da gönderilir (host kendi dosyasına ekler).
## Kayıp kayıt düzeltmesi (2026-10-12): istemci menüye çıkarken ÖNCE bağlantıyı kesiyor, kaydı SONRA (_exit_tree) yolluyordu -> o an
## bağlantı yok, kayıt host'a hiç gitmiyordu (4 kişilik oyunda yalnız 2 kayıt). Artık çıkış yolları flush_run_record_before_leave()
## ile kaydı bağlantı AÇIKKEN yollar; host bağlı değilse (düşmüş) yollamaya çalışmaz.
var _balance_sent_to_host: bool = false


func _write_balance_record(summary: Dictionary) -> void:
	var rec: Dictionary = BalanceLogScript.write_run(player, summary, "end")
	if rec.is_empty():
		_record_log("balans kaydı yazılmadı: %s" % BalanceLogScript.disabled_reason())
	var sent: bool = false
	if not rec.is_empty() and NetworkManager.is_multiplayer_active and not NetworkManager.is_host and multiplayer.has_multiplayer_peer():
		var host_id: int = NetworkManager._host_peer_id()
		if host_id > 0 and multiplayer.get_peers().has(host_id):
			NetworkManager.submit_balance_record.rpc_id(host_id, JSON.stringify(rec))
			_balance_sent_to_host = true
			sent = true
	if not rec.is_empty():
		_record_log("balans kaydı yazıldı: run_id=%s, host'a gönderildi=%s" % [str(rec.get("run_id", "")), str(sent)])
	BalanceLogScript.reset()


## Bağlantıyı kesmeden ÖNCE çağrılır (NetworkManager.flush_balance_before_leave). Koşu kaydını şimdi yazar/yollar; true = host'a RPC gitti
## (çıkan, paketin ağa çıkması için kısa süre beklemeli: ENet close() kuyruktaki paketleri atar).
func flush_run_record_before_leave() -> bool:
	_balance_sent_to_host = false
	_record_run_end_once()
	return _balance_sent_to_host


## Koşu ilerlerken (yeni kademe / sonsuz kat): en iyi değerler anında kaydedilir, yeni açılan başarım toast ile bildirilir.
func _note_run_progress() -> void:
	_announce_achievements(_record_run("progress"))


func _announce_achievements(result: Dictionary) -> void:
	for id in result.get("achievements", []):
		_show_notice("ach", "Başarım: %s" % AchievementsScript.name_of(str(id)), String(AchievementsScript.def_of(str(id)).get("desc", "")), 4.0)
		EventSfx.play(get_tree(), &"mission_success")


## Koşu ölüm ekranından geçmeden de bitebilir (menüye çıkış, yeniden başlatma) - toplamlar yine işlensin. 30 sn'den kısa koşu sayılmaz.
func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_on_frame_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)
	_record_run_end_once()


## Koşu sonu toplamları bir kez yazılır. İki tetik: Main kalkarken (_exit_tree: menüye çıkış) ve GameManager.reset() öncesi
## (yeniden başlatma: reset, Main kalkmadan ÖNCE süreyi/öldürmeyi sıfırlıyordu - bkz. GameManager.run_about_to_reset).
func _record_run_end_once() -> void:
	if GameManager.run_record_suppressed:
		_record_log_once("end ATLANDI: host devri (run_record_suppressed)")
		return ## host devri: koşu sürüyor, bu Main sadece yeniden kuruluyor
	if _run_end_recorded:
		return ## zaten işlendi (ölüm ekranı / menüye çıkıştan önce flush) - beklenen durum, günlüğe yazılmaz
	if GameManager.run_elapsed() < 30.0:
		_record_log_once("end ATLANDI: koşu süresi %.0f sn < 30 sn" % GameManager.run_elapsed())
		return
	_run_end_recorded = true
	_record_run("end")


## Final bosslarının hepsi öldü (HER peer'de, bkz. NetworkManager.victory_reached): zafer penceresi + zafer kaydı.
func _on_victory_reached(_elapsed: float) -> void:
	if _victory_overlay and is_instance_valid(_victory_overlay):
		return
	EventSfx.play(get_tree(), &"mission_success")
	CameraShakeScript.add(0.9) ## zafer anı: Final'in son bossu yıkıldı
	_record_run("victory") ## sonuçlar _run_results'ta birikir, pencerede gösterilir
	var is_host_or_solo: bool = not NetworkManager.is_multiplayer_active or NetworkManager.is_host
	_victory_overlay = CanvasLayer.new()
	_victory_overlay.set_script(VictoryOverlayScript)
	_victory_overlay.call("setup", _run_summary(true), is_host_or_solo, not NetworkManager.is_multiplayer_active)
	_victory_overlay.connect("continue_pressed", _on_victory_continue_pressed)
	_victory_overlay.connect("menu_pressed", _on_death_overlay_menu_pressed)
	add_child(_victory_overlay)
	_victory_overlay.call("set_results", _run_results)
	## Takım tablosu: herkes KENDİ toplamlarını yayınlar (tek oyunculuda yerel yazılır) - ölüm ekranıyla aynı akış.
	if NetworkManager.is_multiplayer_active:
		_broadcast_local_match_stats()
	else:
		_record_local_match_stats()
	_refresh_match_stats_ui()


## Host/tek oyunculu "Sonsuza Devam Et"e bastı: spawner sonsuz modu başlatır, herkese endless_started gider.
func _on_victory_continue_pressed() -> void:
	var spawner: Node = get_node_or_null("EnemySpawner")
	if spawner == null or not spawner.has_method("begin_endless") or not spawner.begin_endless():
		if _victory_overlay and is_instance_valid(_victory_overlay) and _victory_overlay.has_method("unlock_continue"):
			_victory_overlay.call("unlock_continue")


func _on_endless_started() -> void:
	if _victory_overlay and is_instance_valid(_victory_overlay):
		_victory_overlay.queue_free()
		_victory_overlay = null
	var started_text: String = "Her kat yaratıklar güçlenir"
	started_text += ", 3 katta bir boss dalgası gelir." if GameManager.endless_has_boss_waves() else "."
	_show_banner_notice("ok", "SONSUZ MOD BAŞLADI", started_text, 5.0)
	_update_endless_label()
	BalanceLogScript.note_layer(1, player) ## balans kaydı: kat 1 başlangıç anlık görüntüsü (madde 269)


func _on_endless_layer_reached(layer: int) -> void:
	var text: String = "Yaratıklar güçlendi."
	if GameManager.endless_has_boss_waves() and EndlessMathScript.is_boss_wave_layer(layer):
		text += " Bu katta BOSS DALGASI var!"
	_show_banner_notice("tier", "SONSUZ KAT %d" % layer, text, 4.0)
	_update_endless_label()
	BalanceLogScript.note_layer(layer, player) ## balans kaydı: kat başlangıç anlık görüntüsü (madde 269)
	_note_run_progress()


## Sonsuz moddayken üst-ortada küçük "SONSUZ MOD - KAT N" göstergesi (boss katında "BOSS DALGASI" eklenir).
func _update_endless_label() -> void:
	if not GameManager.endless_active:
		if _endless_label and is_instance_valid(_endless_label):
			_endless_label.visible = false
		return
	if _endless_label == null or not is_instance_valid(_endless_label):
		var layer := CanvasLayer.new()
		layer.name = "EndlessLabelLayer"
		layer.layer = 41
		add_child(layer)
		_endless_label = Label.new()
		_endless_label.name = "EndlessLabel"
		_endless_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_endless_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_endless_label.offset_top = 6
		_endless_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_endless_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIKit.style_label(_endless_label, 32 if MobileUI.enabled else 28, UIKit.C_CREAM, 6)
		layer.add_child(_endless_label)
	var text: String = "SONSUZ MOD - KAT %d" % GameManager.endless_layer
	if GameManager.endless_has_boss_waves() and EndlessMathScript.is_boss_wave_layer(GameManager.endless_layer):
		text += " - BOSS DALGASI"
	_endless_label.text = text
	_endless_label.visible = true


func _on_merchant_departed() -> void:
	_show_notice("merchant", "Seyyar Satıcı ayrıldı")
	EventSfx.play(get_tree(), &"merchant_leave")
	var minimap: Node = hud.get_node_or_null("MinimapControl")
	if minimap and minimap.has_method("set_merchant_marker"):
		minimap.set_merchant_marker(Vector2.ZERO, false)
	if _merchant_arrow and is_instance_valid(_merchant_arrow):
		_merchant_arrow.set_target_active(Vector2.ZERO, false)


## Rastgele dünya görevleri (bkz. world_event_manager.gd dosya başı notu) - satıcı
## bildirimleriyle BİREBİR AYNI dört parça (toast + minimap işareti + ok + burada AYRICA
## üst-orta ilerleme paneli): TÜM peer'lerde çalışır (call_local RPC, bkz. network_manager.gd).
## "Görev nerede" işareti UYARI aşamasında da (aktifleşmeden 1 dakika önce) gösterilir -
## kullanıcı isteği: "hangi görevin nerede başlayacağı ... haritada da gösterilecek".
## "toplama görevinde toplanması gereken objeler ve kopyaların konumu gösterilmeyecek"
## (kullanıcı isteği) - bu iki tür için pos=Vector2.ZERO/radius=0.0 gelir (bkz.
## world_event_manager.gd HIDDEN_LOCATION_KINDS), minimap/ok işareti BİLEREK atlanır.
func _on_world_event_announced(mission_id: int, kind: String, pos: Vector2, _radius: float, warn_seconds: float, label: String) -> void:
	_world_event_kind_by_id[mission_id] = kind
	_world_event_label_by_id[mission_id] = label
	if warn_seconds > 0.0: ## debug zorla-başlat uyarısız gelir (hemen _started)
		EventSfx.play(get_tree(), &"mission_warn")
	var loc_note: String = " Konumu haritada işaretlendi."
	if kind == "kill_your_copy":
		loc_note = ""
	elif kind == "collect":
		loc_note = " Kristaller başlayınca haritaya saçılacak."
	## başlıkta görevin adı + sağda başlamaya geri sayan "N sn" (debug zorla-başlat uyarısız gelir: sayaç yok)
	_show_notice("warn", label, "Görev yakında başlıyor." + loc_note, MISSION_TOAST_SECONDS, warn_seconds if warn_seconds > 0.0 else -1.0)
	if not NO_SINGLE_LOCATION_KINDS.has(kind):
		var minimap: Node = hud.get_node_or_null("MinimapControl")
		if minimap and minimap.has_method("set_mission_marker"):
			minimap.set_mission_marker(mission_id, pos, Color(0.7, 0.85, 1.0), "?")
	if _world_event_banner and is_instance_valid(_world_event_banner):
		_world_event_banner.upsert(mission_id, label, true) ## uyarı aşaması: kırmızı başlık + başlamaya geri sayım
		_world_event_banner.set_countdown(mission_id, warn_seconds)
		if not NO_SINGLE_LOCATION_KINDS.has(kind):
			_world_event_banner.set_target(mission_id, pos, _radius)


## Süren görevin geç katılana yakalaması (bkz. NetworkManager.broadcast_world_event_catchup): etiket/tür kaydı + bildirimsiz aynı kurulum +
## ilerleme + zaten toplanmış kristallerin gizlenmesi.
func _on_world_event_catchup(mission_id: int, kind: String, label: String, pos: Vector2, radius: float, remaining: float, extra: Dictionary,
		progress: float, target: float, collected: Array) -> void:
	if _world_event_visuals.has(mission_id):
		return ## bu görevi zaten biliyoruz (çift yakalama)
	_world_event_kind_by_id[mission_id] = kind
	_world_event_label_by_id[mission_id] = label
	_on_world_event_started(mission_id, kind, pos, radius, remaining, extra, true)
	_on_world_event_progress(mission_id, progress, target)
	for idx in collected:
		_on_world_event_item_collected(mission_id, int(idx))


func _on_world_event_started(mission_id: int, kind: String, pos: Vector2, _radius: float, duration: float, extra: Dictionary, quiet: bool = false) -> void:
	var label: String = String(_world_event_label_by_id.get(mission_id, kind))
	if not quiet:
		EventSfx.play(get_tree(), &"mission_start")
		_show_notice("start", "%s BAŞLADI" % label, String(MISSION_DESCRIPTIONS.get(kind, "")), MISSION_TOAST_SECONDS)
	if not NO_SINGLE_LOCATION_KINDS.has(kind):
		var minimap: Node = hud.get_node_or_null("MinimapControl")
		if minimap and minimap.has_method("set_mission_marker"):
			minimap.set_mission_marker(mission_id, pos, Color(1.0, 0.4, 0.3), "!")
	if _world_event_banner and is_instance_valid(_world_event_banner):
		_world_event_banner.upsert(mission_id, label, false)
		_world_event_banner.set_countdown(mission_id, duration) ## görevin bitişine geri sayım
		## Kullanıcı isteği (2026-09-24): toplama görevinde çubuk yerine toplanması gereken miktar yazsın.
		if kind == "collect":
			_world_event_banner.set_count_mode(mission_id, true)
			_world_event_banner.set_progress(mission_id, 0.0, float(extra.get("collect_target", 0)))
		if not NO_SINGLE_LOCATION_KINDS.has(kind):
			_world_event_banner.set_target(mission_id, pos, _radius)
	## Görev türüne özgü görseller (bkz. dosya başındaki mission_*.gd preload'ları). Ağacı Koru/
	## Kopyanı Öldür için GERÇEK (simüle edilen) düğüm world_event_manager.gd'de ZATEN bu
	## istemcide oluşmuş olabilir (host/solo) - o durumda burada İKİNCİ bir kozmetik kopya
	## YARATILMAZ (bkz. aşağıdaki is_multiplayer_active/is_host kontrolü, enemy.gd'nin AYNI
	## "sadece client kozmetik kurar" desenidir).
	var visuals: Dictionary = {"kind": kind}
	match kind:
		"capture_point", "secure_area":
			## Kullanıcı bildirimi (2026-09-24): bayrak/alan hiç çizilmiyordu - bkz. mission_zone.gd.
			var zone: Node2D = MissionZoneScript.new()
			get_tree().current_scene.add_child(zone)
			zone.global_position = pos
			zone.setup(kind, _radius)
			visuals["zone"] = zone
		"collect":
			var items: Array = []
			var positions: PackedVector2Array = extra.get("items", PackedVector2Array())
			for i in range(positions.size()):
				var item: Area2D = MissionCollectItemScript.new()
				get_tree().current_scene.add_child(item)
				item.global_position = positions[i]
				item.mission_id = mission_id
				item.item_index = i
				items.append(item)
			visuals["items"] = items
			var mm: Node = hud.get_node_or_null("MinimapControl")
			if mm and mm.has_method("set_collect_dots"):
				mm.call("set_collect_dots", mission_id, positions)
		"escort_van":
			var van: Node2D = MissionVanScript.new()
			get_tree().current_scene.add_child(van)
			var route: PackedVector2Array = extra.get("route", PackedVector2Array([extra.get("start", pos), extra.get("end", pos)]))
			van.setup(route, extra.get("push_radius", 130.0))
			visuals["van"] = van
		"defend_tree":
			if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
				var tree: Node2D = MissionTreeScript.new()
				get_tree().current_scene.add_child(tree)
				tree.global_position = pos
				tree.setup(1, false) ## simulated=false: sadece world_event_progress'ten can/kalkan alır
				visuals["tree"] = tree
				## Sadece kozmetik: istemcideki yaratıklar ağaca baksın (bkz. enemy.gd istemci bakış dalı). AI/hedef
				## seçimi host'ta; defend_tree_active istemcide false kalır. Ağaç silinince is_instance_valid false olur.
				GameManager.defend_tree_ref = tree
				visuals["tree_max_health"] = extra.get("max_health", 3000.0)
				visuals["tree_max_shield"] = extra.get("max_shield", 800.0)
			else:
				visuals["tree"] = GameManager.defend_tree_ref ## gerçek ağaç zaten burada
		"kill_your_copy":
			if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
				var copies: Array = []
				var copy_meta: Array = extra.get("copies", [])
				for i in range(copy_meta.size()):
					var m: Dictionary = copy_meta[i]
					var copy: CharacterBody2D = MissionPlayerCopyScript.new()
					get_tree().current_scene.add_child(copy)
					copy.global_position = m.get("pos", Vector2.ZERO)
					copy.setup(mission_id, i, int(m.get("char_id", 1)), float(m.get("max_hp", 100.0)),
						float(m.get("max_shield", 0.0)), Characters.BASE_MOVE_SPEED, 0.0, false)
					copy.set_weapon_keys(m.get("weapons", []))
					copies.append(copy)
				visuals["copies"] = copies
	_world_event_visuals[mission_id] = visuals


func _on_world_event_progress(mission_id: int, value: float, target: float) -> void:
	if _world_event_banner and is_instance_valid(_world_event_banner):
		_world_event_banner.set_progress(mission_id, value, target)
	var visuals: Dictionary = _world_event_visuals.get(mission_id, {})
	match visuals.get("kind"):
		"capture_point", "secure_area":
			var zone: Node = visuals.get("zone")
			if zone and is_instance_valid(zone):
				zone.call("set_progress", value, target)
		"escort_van":
			var van: Node = visuals.get("van")
			if van and is_instance_valid(van):
				## _players_in_radius > 0 mu bilmiyoruz (sadece value/target geliyor) - basit bir
				## ısı işareti: ilerleme SON karede ARTMIŞSA "itiliyor" say (görsel ipucu, oyunu
				## etkilemez, bkz. mission_van.gd _pushed - sadece renk).
				var prev: float = float(visuals.get("_last_progress", value))
				van.call("set_progress", value, target, value >= prev)
				visuals["_last_progress"] = value
				_world_event_visuals[mission_id] = visuals
		"defend_tree":
			var tree: Node = visuals.get("tree")
			## DÜZELTME (headless testte bulundu): "not is_host" TEK BAŞINA yanlıştı - tek
			## oyunculu modda is_host hiç true olmuyor (bkz. network_manager.gd), yani bu
			## dal SOLO'da da tetiklenip _activate_mission'ın genel (0.0, 1.0) ilk yayınıyla
			## GERÇEK ağacın canını/kalkanını anında sıfırlıyordu. Diğer tüm host/client
			## ayrımlarıyla (bkz. yukarıdaki _on_world_event_started) AYNI tam koşul gerekli:
			## sadece GERÇEKTEN aktif bir çok oyunculu oturumda, host OLMAYAN bir istemci.
			if tree and is_instance_valid(tree) and NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
				tree.call("apply_synced_health", value, target)


func _on_world_event_item_collected(mission_id: int, item_index: int) -> void:
	var visuals: Dictionary = _world_event_visuals.get(mission_id, {})
	var items: Array = visuals.get("items", [])
	if item_index >= 0 and item_index < items.size() and is_instance_valid(items[item_index]):
		items[item_index].call("mark_collected")
	var mm: Node = hud.get_node_or_null("MinimapControl")
	if mm and mm.has_method("remove_collect_dot"):
		mm.call("remove_collect_dot", mission_id, item_index)


func _on_world_event_completed(mission_id: int, kind: String, success: bool) -> void:
	var label: String = String(_world_event_label_by_id.get(mission_id, kind))
	## DÜZELTME (kullanıcı bildirimi: "ağacın canı bittiğinde görev başarısız olmuyor") - mekanizma
	## GERÇEKTEN çalışıyordu (headless testle doğrulandı: is_dead -> done/success=false -> bu
	## fonksiyon success=false ile çağrılıyor) ama HER başarısızlık "süresi doldu" diye
	## gösteriliyordu - defend_tree'de world_event_manager.gd _tick_mission "süre = hayatta kalma
	## hedefi" olacak şekilde TERSİNE çevrilmiş (bkz. o dosyadaki not), yani bu görev türünde
	## success=false SADECE ağaç öldüğünde olur, süre dolması asla değil - o yüzden burada AYRI,
	## doğru bir mesaj gösterilebilir (ağ üzerinden yeni bir "sebep" alanı eklemeye gerek yok).
	var fail_title: String = "%s süresi doldu" % label
	var fail_body: String = "Görev iptal edildi."
	if kind == "defend_tree" and not success:
		fail_title = "%s BAŞARISIZ" % label
		fail_body = "Ağaç yok edildi."
	## Başarı: "Görev Tamamlandı" penceresi (kullanıcı isteği 2026-10-02) - görev altını onun içinden altın paneline uçar
	## (bkz. mission_complete_window.gd). Başarısızlık eskisi gibi sağ üstte bildirim.
	if success:
		MissionCompleteWindowScript.open(self, label)
	else:
		_show_notice("fail", fail_title, fail_body, MISSION_TOAST_SECONDS)
	EventSfx.play(get_tree(), &"mission_success" if success else &"mission_fail")
	_world_event_kind_by_id.erase(mission_id)
	_world_event_label_by_id.erase(mission_id)
	var minimap: Node = hud.get_node_or_null("MinimapControl")
	if minimap and minimap.has_method("clear_mission_marker"):
		minimap.clear_mission_marker(mission_id)
	if minimap and minimap.has_method("clear_collect_dots"):
		minimap.call("clear_collect_dots", mission_id)
	if _world_event_banner and is_instance_valid(_world_event_banner):
		_world_event_banner.remove(mission_id)
	## Görsel temizlik - SADECE bu istemcinin kendi kurduğu (client-cosmetic veya
	## host/solo-gerçek referans) düğümleri; host/solo'nun GERÇEK ağaç/kopyaları zaten
	## world_event_manager.gd _end_mission'da kendi queue_free()'lerini yapıyor - burada
	## visuals["tree"]/["copies"] host/solo'da AYNI (referans) düğümlere işaret ediyor
	## olabilir, is_instance_valid kontrolü çift-free'yi zararsız kılıyor.
	var visuals: Dictionary = _world_event_visuals.get(mission_id, {})
	## Görev bitince (başarı ya da başarısızlık) toplanmamış tüm kristaller kalkar (kullanıcı isteği 2026-09-24).
	for item in visuals.get("items", []):
		if is_instance_valid(item) and not item.is_queued_for_deletion():
			(item as Node).queue_free()
	var van: Node = visuals.get("van")
	if van and is_instance_valid(van):
		van.queue_free()
	var zone: Node = visuals.get("zone")
	if zone and is_instance_valid(zone):
		zone.queue_free()
	var tree: Node = visuals.get("tree")
	if tree and is_instance_valid(tree) and NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		tree.queue_free() ## sadece client kozmetiği - host/solo'nunkini manager kendi siler
	for copy in visuals.get("copies", []):
		if is_instance_valid(copy) and NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
			copy.queue_free()
	_world_event_visuals.erase(mission_id)


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
		## 2026-10-19 (kullanıcı: "bazen bir oyuncu ölünce onda oyun sonucu ekranı açılmıyor"): ÖNCE izleyici ekranı, SONRA host'a
		## bildirim. Son ölen HOST ise report_self_permanently_dead() oyunu SENKRON bitirir (game_over_synced -> "OYUN BİTTİ");
		## izleyici ekranı bundan sonra çizilirse onu ezip "SEN ÖLDÜN / izleyicisin"e çevirir, istatistik kutusu da gizli kalırdı.
		_show_death_overlay(false)
		NetworkManager.report_self_permanently_dead()
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
	_match_stats_by_peer[my_id] = {"name": my_name, "dealt": player.match_damage_dealt, "taken": player.match_damage_taken, "kills": GameManager.run_kills}
	_refresh_match_stats_ui()


func _broadcast_local_match_stats() -> void:
	if not is_instance_valid(player):
		return
	NetworkManager.sync_match_stats.rpc(multiplayer.get_unique_id(), NetworkManager.local_player_name, player.match_damage_dealt, player.match_damage_taken, GameManager.run_kills)


func _on_match_stats_received(peer_id: int, player_name: String, damage_dealt: float, damage_taken: float, kills: int) -> void:
	_match_stats_by_peer[peer_id] = {"name": player_name, "dealt": damage_dealt, "taken": damage_taken, "kills": kills}
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
		EventSfx.play(get_tree(), &"chat") ## sadece başkasının mesajında (kendi yazdığında çalmaz)
		var rp: RemotePlayer = _get_remote_player(peer_id)
		if rp and is_instance_valid(rp) and rp.has_method("show_chat_bubble"):
			rp.show_chat_bubble(text)


## Birinin debug modunda yaptığı eylem (bkz. network_manager.gd debug_action_announced notu): üst ortada uyarı + sohbet kaydına satır
## (toast kaybolsa bile ne yapıldığı kalır). Gönderen KENDİMİZ de olsak gelir ("call_local") - ne yaptığını görmek zararsız.
func _on_debug_action_announced(player_name: String, text: String) -> void:
	var line: String = "[DEBUG] %s: %s" % [player_name, text]
	_show_banner_notice("fail", "DEBUG MODU UYARISI", line, 4.0)
	EventSfx.play(get_tree(), &"chat")
	if hud and hud.has_method("append_chat_message"):
		hud.append_chat_message("DEBUG", "%s: %s" % [player_name, text])


## Oyun sonu istatistik ekranındaki tabloyu (isim | verdiği hasar | tankladığı
## hasar) o ana kadar toplanmış _match_stats_by_peer'den yeniden çizer -
## sonuçlar (özellikle multiplayer'da diğer peer'lerin RPC'si) art arda
## geldikçe her seferinde çağrılır, overlay henüz kurulmadıysa (is_final
## olmadan önce) sessizce no-op.
func _refresh_match_stats_ui() -> void:
	## 2026-10-05: tablo çizimi run_summary_ui.gd'ye taşındı (zafer penceresiyle ORTAK) + "Öldürme" sütunu.
	if _victory_overlay and is_instance_valid(_victory_overlay):
		_victory_overlay.call("refresh_stats", _match_stats_by_peer)
	if not _death_overlay_layer or not is_instance_valid(_death_overlay_layer):
		return
	## 2026-10-17 (madde 224): ölüm ekranının tablosu artık game_over_board.gd'de portreli çiziliyor.
	var board: Control = _death_overlay_layer.get_node_or_null("Window/VBox/StatsBox/Board")
	if not board:
		return
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0 ## _record_local_match_stats ile AYNI anahtar
	board.call("set_team", _match_stats_by_peer, _match_stats_char_ids(my_id), my_id)


## Tablo portreleri için peer -> karakter id: kendimiz GameManager'dan, arkadaşlar sahnedeki kuklalarından (ölü bedenleri de
## orada durur; kopmuş bir arkadaşın kuklası yoksa portre yerine kuru kafa çizilir). Ek RPC alanı gerekmez.
func _match_stats_char_ids(my_id: int) -> Dictionary:
	var out: Dictionary = {my_id: GameManager.selected_char_id}
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and "char_id" in rp:
			out[int(rp.get("peer_id"))] = int(rp.get("char_id"))
	return out


## Ölüm ekranı (is_final) koşu özeti: üstte SÜRE/KADEME/(KAT)/ÖLDÜRME satırı, altta bu koşuda kırılan rekor + açılan başarımlar.
## Birden fazla kez çağrılabilir (hem son ölende hem game_over_synced'te) - eski satırlar silinip yeniden kurulur.
func _refresh_death_summary() -> void:
	if not _death_overlay_layer or not is_instance_valid(_death_overlay_layer):
		return
	var board: Control = _death_overlay_layer.get_node_or_null("Window/VBox/StatsBox/Board")
	if not board:
		return
	board.call("set_summary", _run_summary(false), _run_results)


## bkz. pause_menu.gd::_on_menu() - ölüm overlay'indeki "Ana Menüye Dön"
## butonu, oyun bitmiş olsa bile (ui_cancel/ESC devre dışı kalsa bile, bkz.
## _process) çalışan tek bağımsız çıkış yolu. AYNI temizlik: multiplayer'da
## host ise odayı kapatır (diğerlerini de düzgünce koparır), değilse sadece
## kendi bağlantısını keser.
func _on_death_overlay_menu_pressed() -> void:
	await NetworkManager.flush_balance_before_leave() ## koşu kaydı bağlantı kesilmeden host'a ulaşsın
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
	## Oyun bittikten sonra izleyici ekranına geri dönülmez (geç/sırası bozuk bir çağrı "OYUN BİTTİ"yi ezmesin).
	if GameManager.is_game_over:
		is_final = true
	if is_final and not _game_over_sfx_played:
		_game_over_sfx_played = true
		EventSfx.play(get_tree(), &"game_over")
	if not _death_overlay_layer or not is_instance_valid(_death_overlay_layer):
		_death_overlay_layer = CanvasLayer.new()
		_death_overlay_layer.layer = 95
		_death_overlay_layer.add_to_group(&"gamepad_modal") ## kumandayla düğmelere basılabilsin (bkz. gamepad_ui.gd)
		add_child(_death_overlay_layer)

		var dim := ColorRect.new()
		dim.name = "Dim" ## izleyicide düz karartma; oyun bitince vinyet (aşağıda)
		dim.color = Color(0.02, 0.02, 0.03, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_death_overlay_layer.add_child(dim)

		## Kullanıcı isteği (2026-09-24): oyun içi arayüzler menülerle aynı bej/ahşap kite geçti - ölüm/izleyici ekranı
		## artık bir kit penceresinde (eskiden dünya üstünde çıplak yazılar + 88 px'lik varsayılan fontla dev butonlar).
		## 2026-10-17 (madde 224, kullanıcı 4 prototipten "A - Ahşap Pano"yu seçti, renkler "seyyar satıcıya benzesin"): bej pencere
		## -> Seyyar Satıcı kiti (shop_dark_kit.gd PAL_SLATE: kayrak panel + altın vurgu), tepesinde kuru kafa madalyonu; gövde
		## (stat kutuları + portreli tablo + kazanımlar) game_over_board.gd. Başlık/alt yazı/düğmeler gerçek düğüm kaldı (kumanda,
		## ses, yeniden başlatma oylaması aynı).
		var kit = ShopDarkKitScript.new(ShopDarkKitScript.PAL_SLATE)
		var window := PanelContainer.new()
		window.name = "Window"
		window.theme = kit.theme()
		var win_style: StyleBoxFlat = kit.sb(kit.c("panel"), kit.c("line_hi"), 3, 8)
		win_style.shadow_color = Color(0, 0, 0, 0.45)
		win_style.shadow_size = 14
		win_style.shadow_offset = Vector2(0, 8)
		win_style.content_margin_left = 40
		win_style.content_margin_right = 40
		win_style.content_margin_top = 64 ## madalyon üst kenara biner
		win_style.content_margin_bottom = 28
		window.add_theme_stylebox_override("panel", win_style)
		window.custom_minimum_size = Vector2(760, 0)
		window.set_anchors_preset(Control.PRESET_CENTER_TOP)
		window.offset_top = DEATH_WINDOW_TOP
		window.offset_left = -380
		window.offset_right = 380
		window.grow_horizontal = Control.GROW_DIRECTION_BOTH
		window.resized.connect(_fit_death_window)
		_death_overlay_layer.add_child(window)

		var box := VBoxContainer.new()
		box.name = "VBox"
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 12)
		window.add_child(box)

		var medallion: Control = GameOverBoardScript.Medallion.new()
		medallion.name = "Medallion"
		medallion.lift = 60.0 ## merkez pencerenin üst kenarının 4 px altında (içerik payı 64)
		box.add_child(medallion)

		var title := Label.new()
		title.name = "Title"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.style_label(title, UIKit.FS_BIG, kit.c("bad"), 0)
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		title.add_theme_constant_override("shadow_offset_x", 4)
		title.add_theme_constant_override("shadow_offset_y", 4)
		box.add_child(title)

		var sub := Label.new()
		sub.name = "Subtitle"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD
		UIKit.style_label(sub, 24, kit.c("dim"), 0)
		sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		sub.add_theme_constant_override("shadow_offset_x", 3)
		sub.add_theme_constant_override("shadow_offset_y", 3)
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
		prev_btn.custom_minimum_size = Vector2(0, 44)
		prev_btn.add_theme_font_size_override("font_size", 24)
		prev_btn.pressed.connect(_on_spectate_prev_pressed)
		spectate_row.add_child(prev_btn)

		var spectate_label := Label.new()
		spectate_label.name = "SpectateLabel"
		spectate_label.custom_minimum_size = Vector2(220, 0)
		spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.style_label(spectate_label, 24, kit.c("accent"), 0)
		spectate_row.add_child(spectate_label)

		var next_btn := Button.new()
		next_btn.name = "NextButton"
		next_btn.text = "Sonraki >"
		next_btn.custom_minimum_size = Vector2(0, 44)
		next_btn.add_theme_font_size_override("font_size", 24)
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

		var board: Control = GameOverBoardScript.new()
		board.name = "Board" ## stat kutuları + portreli tablo + kazanımlar (_refresh_death_summary/_refresh_match_stats_ui doldurur)
		stats_box.add_child(board)

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
		_death_overlay_restart_btn.custom_minimum_size = Vector2(380, 64)
		_death_overlay_restart_btn.pressed.connect(_on_death_overlay_restart_pressed)
		## pause_menu.gd _ready() ile AYNI kural: çok oyunculuda SADECE host
		## yeniden başlatmayı tetikleyebilir, client'larda gizli.
		if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
			_death_overlay_restart_btn.visible = false
		death_btn_row.add_child(_death_overlay_restart_btn)

		var menu_btn := Button.new()
		menu_btn.name = "BackToMenuButton"
		menu_btn.text = "Ana Menüye Dön"
		menu_btn.custom_minimum_size = Vector2(380, 64)
		menu_btn.pressed.connect(_on_death_overlay_menu_pressed)
		death_btn_row.add_child(menu_btn)

		## DÜZELTME (kullanıcı isteği: "Button resmini oyunumdaki tüm
		## butonlarla değiştir") - ölüm ekranındaki izleyici ok butonları ve
		## "Ana Menüye Dön" butonu hiç UISound çağırmıyordu. Tüm Main
		## ağacını değil sadece bu overlay'i taramak yeterli/daha ucuz.
		UISound.connect_all_buttons(_death_overlay_layer)
		UISound.apply_wood_buttons(_death_overlay_layer)
		## Satıcı kiti düğmeleri (madde 224): Yeniden Başla = altın dolgu ("SATIN AL" gibi), Ana Menü + izleyici okları = çerçeveli koyu.
		kit.btn_style(_death_overlay_restart_btn, "primary")
		kit.btn_style(menu_btn, "ghost")
		kit.btn_style(prev_btn, "ghost")
		kit.btn_style(next_btn, "ghost")
		_death_overlay_restart_btn.add_theme_font_size_override("font_size", UIKit.FS_BODY)
		menu_btn.add_theme_font_size_override("font_size", UIKit.FS_BODY)

		_death_overlay_label = title

	var title_lbl: Label = _death_overlay_layer.get_node_or_null("Window/VBox/Title")
	var sub_lbl: Label = _death_overlay_layer.get_node_or_null("Window/VBox/Subtitle")
	var spectate_row_node: HBoxContainer = _death_overlay_layer.get_node_or_null("Window/VBox/SpectateRow")
	var stats_box_node: VBoxContainer = _death_overlay_layer.get_node_or_null("Window/VBox/StatsBox")
	if stats_box_node:
		stats_box_node.visible = is_final
	if is_final:
		## Koşu sonu: toplamlar + rekorlar + başarımlar bir kez işlenir (bkz. _record_run), özet satırı ekrana kurulur.
		if not _run_end_recorded:
			_run_end_recorded = true
			_record_run("end")
		_refresh_death_summary()
		_refresh_match_stats_ui()
		if title_lbl:
			title_lbl.text = "OYUN BİTTİ"
		if sub_lbl:
			sub_lbl.text = "Tüm takım elendi." if NetworkManager.is_multiplayer_active else "Öldün."
			if GameManager.endless_active:
				sub_lbl.text += " Sonsuz Kat %d'e kadar dayandınız." % GameManager.endless_layer if NetworkManager.is_multiplayer_active \
						else " Sonsuz Kat %d'e kadar dayandın." % GameManager.endless_layer
		if spectate_row_node:
			spectate_row_node.visible = false
		_end_spectate_mode()
		## madde 224: kenarlara koyulaşan vinyet + oyun içi göstergeler kalkar (sohbet kalır - "iyi oyundu" yazılabilsin)
		var dim_node: ColorRect = _death_overlay_layer.get_node_or_null("Dim")
		if dim_node and dim_node.material == null:
			dim_node.material = GameOverBoardScript.vignette_material()
		_hide_hud_for_game_over()
	else:
		if title_lbl:
			title_lbl.text = "SEN ÖLDÜN"
		if sub_lbl:
			sub_lbl.text = "İzleyicisin - takım arkadaşların hâlâ hayatta. Herkes elenirse oyun burada biter."
		if spectate_row_node:
			spectate_row_node.visible = true
		_begin_spectate_mode()
	## Telefon (2026-10-19, prototip S B_oyun_bitti): masaüstü penceresi gizli kalır (veri + düğme işleyicileri orada), üstüne
	## tam ekran telefon görünümü (phone_game_over.gd).
	if MobileUI.enabled:
		_show_phone_death_view(is_final)


func _show_phone_death_view(is_final: bool) -> void:
	var win: Control = _death_overlay_layer.get_node_or_null("Window")
	if win:
		win.visible = false
	var ph: Control = _death_overlay_layer.get_node_or_null("PhoneGameOver")
	if ph == null:
		ph = PhoneGameOverScript.new()
		ph.set("pc_window", win)
		_death_overlay_layer.add_child(ph)
	ph.call("set_final", is_final)


## Ölüm/oyun bitti penceresi ekrana sığmazsa (8 oyunculu tablo, çok başarım, telefon) üst ortadan küçülür (madde 224).
## Pencerenin her boyut değişiminde (tablo RPC'lerle doldukça) çağrılır.
func _fit_death_window() -> void:
	if not _death_overlay_layer or not is_instance_valid(_death_overlay_layer):
		return
	var win: Control = _death_overlay_layer.get_node_or_null("Window")
	if not win:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = minf(1.0, minf((vp.y - DEATH_WINDOW_TOP - 12.0) / maxf(win.size.y, 1.0), (vp.x - 32.0) / maxf(win.size.x, 1.0)))
	win.pivot_offset = Vector2(win.size.x * 0.5, 0.0)
	win.scale = Vector2(s, s)


## Oyun bitti: HUD'un oyun içi göstergeleri (yetenek paneli, grup paneli, minimap, altın...) gizlenir, sohbet katmanı kalır.
## Geri açılmaz - bu ekrandan sonra ya sahne değişir (yeniden başla / ana menü) ya da oyun biter.
func _hide_hud_for_game_over() -> void:
	if not hud or not is_instance_valid(hud):
		return
	var chat: Variant = hud.get("_chat_layer")
	for ch: Node in hud.get_children():
		if ch == chat:
			continue
		if ch is CanvasItem or ch is CanvasLayer:
			ch.set("visible", false)


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
		label = _death_overlay_layer.get_node_or_null("Window/VBox/SpectateRow/SpectateLabel")
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
