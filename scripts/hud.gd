extends CanvasLayer

## Karakter panosu ve silah yuvası barı "BottomBar" sarmalayıcısının altında,
## yetenek ikonları ise AYRI bir "SkillBar" sarmalayıcısının altında (bkz.
## hud.tscn) - kullanıcı ana barı küçültüp yetenek ikonlarını büyütmek
## istediği için (zıt yönde ölçeklenmeleri gerektiği için) ikisi ayrıldı.
## İkisi de ekranın alt-orta noktasına göre sabit kalacak şekilde kendi
## scale/offset değerleriyle ayarlanıyor.
@onready var health_bar = $CharacterCluster/HealthBar
@onready var item_shield_bar = $CharacterCluster/ShieldBar
## Alt bardaki can/kalkan çubuklarının üstüne bindirilen sayısal değerler
## (bkz. kullanıcı isteği "alttaki ana barda kalkan ve can değerleri
## gözüksün") - eskiden bu barlar sadece görsel dolgu, hiç metin yoktu.
@onready var health_value_label: Label = $CharacterCluster/HealthValueLabel
@onready var shield_value_label: Label = $CharacterCluster/ShieldValueLabel
@onready var level_label: Label = $CharacterCluster/LevelLabel
@onready var portrait: TextureRect = $CharacterCluster/PortraitClip/Portrait
## #49 DÜZELTME (kullanıcı bildirimi: "Alttaki EXP barı hiç görünmüyor") -
## kök neden: HUD yeniden tasarlanırken (bkz. yukarıdaki CharacterCluster/
## SkillBar notu) bu bar hiç scenes/hud.tscn'e eklenmemişti VE aşağıdaki
## update_xp() boş bir "pass" idi. İkisi de düzeltildi - bkz. scenes/hud.tscn
## dosya sonundaki "XPBar" node'u.
@onready var xp_bar: Control = $XPBar
@onready var skill_icon = $SkillBar/SkillIcon
@onready var passive_icon = $SkillBar/PassiveIcon
@onready var skill2_icon = $SkillBar/Skill2Icon
## Üçüncü aktif yetenek ikonu (bkz. player.gd SKILL3_TIMING notu - Shaman'ın
## 3 totemi) - hud.tscn'de elle EKLENMEDİ (mevcut sahneyi bir editör
## olmadan elle düzenlemek riskli), Skill2Icon'un BİREBİR aynı düğüm
## yapısıyla (bkz. _create_skill3_icon) kod içinde PartyPanel'le AYNI
## "programatik Control + set_script + add_child" deseniyle kuruluyor.
var skill3_icon = null
## PERF (kullanıcı bildirimi: "Büyücü kız Q ile faz değiştirdiğinde oyuna drop giriyor" -
## ölçüm, gerçek renderer: değişimden HEMEN SONRAKİ karede ~80-90ms tek seferlik sıçrama,
## HER basışta - FX/ses/parçacıklar tamamen MASUM çıktı, tek başına salt buyucu_variation_
## set bayrağını değiştirmek bile aynı sıçramayı veriyordu). Kök neden: aşağıdaki `load(
## v_icons[v_idx])`/`load(v_icons_r[...])` HER KAREDE (Büyücü Kız seçiliyken _process'te,
## 60/sn) koşulsuz çağrılıyordu - `load()` sonucu skill_icon.gd'nin custom_texture'ına
## atanıyor, başka hiçbir yerde GÜÇLÜ referans TUTULMUYOR; varyasyon değişince eski texture
## custom_texture'dan düşüp Godot'un ResourceCache'inden (zayıf referans) DÜŞÜYOR - bir
## SONRAKİ kez o varyasyona dönülünce disk+PNG decode+GPU upload'u SIFIRDAN tekrar
## yapılıyordu (iki varyasyon arasında sürekli GİDİP-GELİNDİĞİ için bu HER basışta oluyordu,
## sadece ilk kullanımda değil). Çözüm: ikonları burada KENDİ güçlü referansımızla
## önbelleğe al - bir kez yüklendikten sonra ResourceCache'den asla düşmüyor.
var _buyucu_variation_icon_cache: Dictionary = {}

func _cached_texture(path: String) -> Texture2D:
	var cached: Variant = _buyucu_variation_icon_cache.get(path)
	if cached != null:
		return cached
	var tex: Texture2D = load(path)
	if tex:
		_buyucu_variation_icon_cache[path] = tex
	return tex
## Ruhani Yetenek butonu (F tuşu, bkz. spiritual_skills.gd/_create_spirit_icon) - 3. butonun sağında, diğer butonlar
## arasındaki boşlukla, biraz büyük ve farklı (mor-altın) çerçeve renginde.
## DÜZELTME (kullanıcı isteği 2026-09-22: "ruhani skillin boyutunu biraz ufalt") - eskiden %20 büyüktü (1.2051),
## artık %10 (1.10) - hâlâ diğerlerinden hafifçe ayırt edilebiliyor ama daha az baskın.
var spirit_icon = null
## Kullanıcı isteği (2026-09-24): "skill bar ve nerf buff barları pek uygun görünmüyor daha simetrik ve düzgün
## tasarlanmalı" - F artık diğer yuvalarla AYNI boyutta (1.10 -> 1.0); mor-altın çerçevesi zaten ayırt ediyor.
const SPIRIT_ICON_SCALE := 1.0
## Pasif (P) ve ruhani (F) yuvalarını Q-E-R grubundan ayıran, iki uçta EŞİT boşluk (bkz. _layout_ability_icons).
const ABILITY_GROUP_GAP := 22.0
const SPIRIT_ICON_BASE_SIZE := 52.0 ## diğer yetenek butonlarının boyutu (hud.tscn SkillIcon 52x52)
## DÜZELTME (kullanıcı isteği 2026-09-22: "skiller arasındaki mesafeyi arttır... arkaplanını da biraz
## genişletmen gerekiyor") - TÜM yetenek yuvaları arasındaki (Q-E, E-R, R-F) TEK paylaşılan boşluk sabiti,
## eskiden 4 idi. hud.tscn'deki Skill2Icon'un offset_left/right'ı VE _create_skill3_icon()'daki sabitler bu
## değere göre ELLE hesaplanmış sayılardır (52 + ABILITY_ICON_GAP katları) - burayı değiştirirsen o iki yeri de
## güncellemen gerekir (bkz. oradaki notlar). Arkaplan çerçevesi (_update_ability_bar_frame) zaten görünür
## ikonların gerçek dikdörtgenlerinin BİRLEŞİMİNİ aldığı için ayrıca büyütülmesine gerek YOK - boşluk artınca
## kendiliğinden genişler.
const ABILITY_ICON_GAP := 12.0
const SPIRIT_ICON_GAP := ABILITY_ICON_GAP
const SPIRIT_FRAME_TINT := Color(1, 1, 1, 1) ## artık tint yok: mor-altın çerçeve kendi dokusu (hud_skill_frame_spirit.png)
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
## Kullanıcı isteği (2026-09-22): "skill kutucuklarının olduğu yere arkasını kaplayacak bir çerçeve" - SkillBar'ın
## İLK çocuğu olarak eklenen, o anki GÖRÜNÜR ikonların (P/Q/E/R/F) etrafını saran tek bir "çukur" panel (bkz.
## _create_ability_bar_frame/_update_ability_bar_frame). Ayrı bir sahne/asset değil, UIKit.panel_style("inset")
## ile diğer paneller (envanter/stat/dükkan) ile AYNI dokuyu paylaşıyor.
var ability_bar_frame: Panel = null
## Kullanıcı isteği: "çerçeveler falan oval olmalı" - panel_ability_bar.png'nin köşeleri oval şeklinde
## büyük yarıçaplı (bkz. tools/gen_ui_kit.py), bu yüzden pay düz dikdörtgen bir panelden biraz daha geniş
## tutuluyor ki oval köşe köşedeki ikonun (P/F) üstüne binmesin. DÜZELTME (kullanıcı bildirimi: "çerçeve çok
## kalın, skiller içinde çok büyük görünüyor") - ilk denemenin 22'si (çok büyük bir yarıçapla birlikte)
## gereğinden kalın duruyordu, hem yarıçap hem bu pay küçültüldü (12'ye). SONRAKİ DÜZELTME (kullanıcı
## bildirimi: "arkaplanı biraz daha genişlet çok köşede durdu skiller") - 12 bu sefer TERSİNE çok DARDI,
## uçlardaki ikonlar (P/F) oval köşeye fazla yakın duruyordu - 20'ye çıkarıldı. SONRAKİ DÜZELTME (kullanıcı
## isteği: "şimdi çok az kısalt boyutunu... uzunluğunu" - barın toplam UZUNLUĞU) - 20 bu sefer biraz fazla
## geldi, 16'ya (aradaki bir değere) çekildi.
const ABILITY_BAR_FRAME_PAD := 16.0
## Kullanıcı isteği (2026-09-22): "buffların sağladığı etkiler... skill barın üstünde mini bir durum etkileri
## satırında olacak... bufflar solda debufflar sağda görünmeli" - bkz. _create_status_bar/_update_status_bar,
## rozetlerin kendisi scripts/status_effect_badge.gd.
var status_bar: Control = null
var status_buff_row: HBoxContainer = null
var status_debuff_row: HBoxContainer = null
const StatusEffectBadgeScene: PackedScene = preload("res://scenes/status_effect_badge.tscn")
@onready var shop_panel = $ShopPanel
@onready var revive_hearts = $ReviveHearts
## Dükkanın altındaki altın göstergesi (bkz. kullanıcı isteği: "dükkanın
## altına bir altın miktarı göstergesi ekle") - _layout_shop_inventory_
## buttons() içinde dükkanla aynı sağ kenara, hemen altına yerleştirilir ve
## dükkan açıkken/kapalıyken aynı anda görünür/gizli olacak şekilde
## _process()'te senkron tutulur.
@onready var gold_indicator: Control = $GoldIndicator
@onready var gold_indicator_label: Label = $GoldIndicator/GoldMargin/GoldHBox/Label
## Kullanıcı isteği: "oyuna fps göstergesi ekle ayarlardan açılıp
## kapatılabilsin" - görünürlük UISound.show_fps'e bağlı, ayarlar panelinden
## (pause_menu.gd/main_menu.gd FpsCheck) her değiştiğinde bu HUD açıkken de
## anında yansısın diye her karede senkronlanıyor (gold_indicator'ın dükkan
## açık/kapalı senkronuyla AYNI desen, bkz. yukarısı).
@onready var fps_label: Label = $FpsLabel
var _fps_update_timer: float = 0.0
@onready var shop_toggle_button: Button = $ShopToggleButton
@onready var envanter_toggle_button: Button = $EnvanterToggleButton
@onready var stats_panel_instance = $StatsPanelInstance
@onready var inventory_panel_instance = $InventoryPanelInstance
var player: Node = null

## NOT: Eskiden burada ekranın SAĞINDA, minimapın altında dinamik olarak
## üretilen iki "üretim butonu" vardı (Maden / Altın Toplayıcı) -
## _create_production_buttons()/_refresh_production_buttons()/
## _reposition_production_buttons()/_on_production_button_pressed() ve
## production_button.gd. Kullanıcı isteğiyle ("altın toplayıcı ve madeni
## oyundan tamamen kaldır ve ekranın sağındaki arayüzlerini de sil") HEPSİ
## kaldırıldı - bu butonlar zaten bu sahnede (hud.tscn) duran düğümler değil,
## tamamen kodla oluşturuluyordu, dolayısıyla sahnede silinecek bir şey yok.


## Bir sinyali sadece HENÜZ bağlı değilse bağlar - bkz. _ready() üstündeki
## not (test ortamında _ready() birden fazla kez tetiklenebiliyor).
func _connect_once(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _ready() -> void:
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir
	_setup_debug_mode()
	if passive_icon:
		passive_icon.frame_border = 4.0 ## küçük pasif çerçeve: 3 sanat pikseli kenar (bkz. skill_icon.gd frame_border)
	## is_inside_tree() koruması: test ortamında bu HUD sahnesi canlı bir
	## SceneTree'ye girmeden instantiate edilip test edilebiliyor
	## (bkz. tests/test_hud_gold_shop_toggle.gd) - get_tree() orada null
	## dönüyor, korumasız çağrı tüm _ready()'yi patlatırdı.
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")
	## Kalkan barı başlangıçta her zaman görünür
	item_shield_bar.visible = true
	shield_value_label.visible = true
	item_shield_bar.max_value = 1.0
	item_shield_bar.value = 0.0
	item_shield_bar.tint_progress = Color(0.24, 0.59, 0.91)
	shield_value_label.text = "0/0"
	if player:
		## Oyun başlangıcında can barını doldur - player._ready health_changed'i
		## main.gd bağlantıyı kurmadan yayınladığı için HUD ilk değeri kaçırır,
		## bu yüzden burada doğrudan başlangıç değerini ayarlıyoruz.
		update_health(player.health, player.max_health)
		skill_icon.skill_id = player.get_skill_character_id()
		if player.has_signal("item_shield_changed"):
			player.item_shield_changed.connect(_on_item_shield_changed)
	_create_skill3_icon()
	_create_spirit_icon()
	_create_ability_bar_frame()
	_create_status_bar()
	_create_player_dock()
	_setup_ability_icons()
	_setup_portrait()
	_layout_bar_kit()
	_setup_revive_display()
	_layout_shop_inventory_buttons()
	_style_envanter_and_gold_buttons()
	## DÜZELTME (kullanıcı bildirimi: "grup paneli görünmüyor, dostların
	## canları kalkanları avatarları görünmeliydi, oradan altın
	## gönderebilmeliydik") - kök neden: party_panel.gd'nin TÜM mantığı
	## (can/kalkan barları, avatar, altın hediye popup'ı) çoktan yazılmıştı
	## ama script hiçbir sahneye/node'a hiç EKLENMEMİŞTİ - proje genelinde
	## "party_panel"i instantiate eden veya add_child yapan TEK BİR satır
	## yoktu, yani kendi kendine mükemmel çalışsa bile ekranda asla
	## belirmiyordu. Programatik Control + set_script + add_child deseniyle
	## burada gerçekten sahneye ekleniyor (eskiden aynı desenin örneği
	## _create_production_buttons()'tı, o kullanıcı isteğiyle kaldırıldı) -
	## script kendi _ready()'sinde zaten kendi
	## pozisyonunu/UI'ını kurup (bkz. party_panel.gd _build_static_ui) sadece
	## gerçek müttefik varken (remote_players grubu doluyken) görünür oluyor.
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "mini dükkan açıkken grup penceresi
	## envanter v.b tıklanamıyor bu nedenle oyuncular diğerlerine para
	## gönderemiyor") - kök neden: party_panel HUD CanvasLayer'ının (varsayılan
	## layer=1) İÇİNDE düz bir Control olarak ekleniyordu. Mini dükkan (bkz.
	## mini_shop_screen.gd) kendi CanvasLayer'ını layer=92'de, TAM EKRAN
	## MOUSE_FILTER_STOP'lu bir karartma ile açıyor - bu karartma HUD'un
	## (layer 1, yani ALTTA) üstüne binip TÜM tıklamaları, altındaki parti
	## panelinin butonlarına hiç ulaşmadan yutuyordu (process_mode zaten
	## ALWAYS olduğu için duraklama bunun nedeni DEĞİLDİ - saf z-sıra/tıklama
	## kapması sorunuydu). Artık parti paneli kendi ayrı CanvasLayer'ında
	## (layer=96 - mini dükkan/tuş atama gibi TÜM bilinen modal ekranların
	## üstünde), böylece hangi modal ekran açık olursa olsun takım arkadaşına
	## altın göndermek her zaman mümkün.
	if is_inside_tree() and not has_node("PartyPanelLayer"):
		var party_layer := CanvasLayer.new()
		party_layer.name = "PartyPanelLayer"
		party_layer.layer = 96
		party_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(party_layer)
		var party_panel := Control.new()
		party_panel.name = "PartyPanel"
		party_panel.set_script(preload("res://scripts/party_panel.gd"))
		party_layer.add_child(party_panel)
		## Kullanıcı bildirimi "envanter v.b tıklanamıyor" da kapsıyor - envanter
		## paneli de (bkz. inventory_panel_instance, hud.tscn'de sahne-tanımlı)
		## AYNI sorunu yaşıyordu (HUD'un layer=1 katmanında, mini dükkanın
		## layer=92 karartmasının altında kalıyordu). Aynı yüksek katmana
		## taşınıyor - reparent, @onready referansını geçersiz kılmaz.
		if inventory_panel_instance and is_instance_valid(inventory_panel_instance):
			inventory_panel_instance.reparent(party_layer)
	## _connect_once: sahne birden fazla kez _ready() alırsa (ör. test
	## ortamı - bkz. tests/test_hud_gold_shop_toggle.gd) sinyallerin çifte
	## bağlanıp "already connected" hatası vermemesi için tüm bağlantılar
	## idempotent hale getirildi.
	_connect_once(envanter_toggle_button.pressed, _on_envanter_toggle)
	## DÜZELTME (kullanıcı isteği - fikir değişikliği, önceki turda tam
	## tersi istenmişti: "dükkan butonunu silip altın göstergesine
	## tıklandığında dükkan açılsın"): "Altın miktarını gösteren butonu
	## küçültüp bunu sadece göstergeye çevirerek dükkan için yeni bir
	## dükkan butonu oluştur. altın miktarı dükkan butonunun altında olsun."
	## ShopToggleButton artık TEKRAR görünür ve dükkanı O açıyor (bkz.
	## _layout_shop_inventory_buttons - artık gizlenmiyor, gold_indicator'ın
	## ESKİ yerine, üstte konumlanıyor). GoldIndicator artık SADECE bir
	## gösterge - tıklanabilirlik/hover imleci kaldırıldı.
	_connect_once(shop_toggle_button.pressed, _on_shop_toggle)
	## Kullanıcı isteği: "Dükkanı açınca sağında stat penceresinin de
	## açılmasını istiyorum" - dükkan KENDİ X butonuyla kapanınca da (bkz.
	## shop_panel.gd "closed" sinyali) eşleşen istatistik panelini kapatmak
	## için (aynı desen: inventory_panel_instance.closed -> _on_envanter_closed).
	_connect_once(shop_panel.closed, _on_shop_closed)
	_connect_once(inventory_panel_instance.closed, _on_envanter_closed)
	_create_chat_ui()
	_register_ui_opacity()
	_setup_mobile_hud()

	## NOT: Eskiden dükkan açılınca DÜKKAN/ENVANTER butonları gizleniyordu -
	## kullanıcı artık bunu istemiyor (bkz. kullanıcı bildirimi: "dükkana
	## basınca dükkan/envanter butonu kapanmasın"), bu yüzden bu davranış
	## kaldırıldı; butonlar panel açıkken de görünür kalır (bkz. aşağıdaki
	## artık kullanılmayan _update_toggle_buttons_visibility notu).


## Kullanıcı isteği (2026-09-25): "arayüzler için ayarlara opaklık ayarı getir" (bkz. UISound.ui_opacity_percent) - HUD'un
## KALICI parçaları bu opaklıkla çizilir. Dükkan/envanter panelleri ve sohbet YAZMA kutusu bilerek hariç (açıkken okunmalı).
const UI_OPACITY_NODES: Array[String] = ["BottomBar", "CharacterCluster", "SkillBar", "GoldIndicator", "MinimapControl",
	"ReviveHearts", "XPBar", "ShopToggleButton", "EnvanterToggleButton", "FpsLabel", "PartyPanelLayer/PartyPanel",
	"DockFrame", "HeartsTab"]


func _register_ui_opacity() -> void:
	for path: String in UI_OPACITY_NODES:
		var n: Node = get_node_or_null(path)
		if n:
			UISound.register_ui_opacity(n)
	if _chat_scroll:
		UISound.register_ui_opacity(_chat_scroll)


func _layout_shop_inventory_buttons() -> void:
	var minimap: Control = get_node_or_null("MinimapControl")
	if not minimap:
		return
	const ORIGINAL_BTN_W := 240.0
	const ORIGINAL_BTN_H := 62.0
	const SHRINK_RATIO := 0.7 ## %30 küçültme
	const GAP := 10.0
	## DÜZELTME (kullanıcı isteği: "ben butonları değil butonların içindeki
	## textleri büyütmeni istemiştim") - eskiden kutunun kendisi de fontla
	## AYNI oranda büyütülüyordu, kullanıcı sadece metnin büyümesini istiyor.
	## Kutu boyutu ORİJİNAL (168x43.4) kaldı, sadece font_size aşağıda 45'e
	## çıkarıldı - metin artık kutuya TAM sığmayabilir (clip_text zaten
	## açıktı, taşan kısmı kırpar).
	var btn_w: float = ORIGINAL_BTN_W * SHRINK_RATIO
	var btn_h: float = ORIGINAL_BTN_H * SHRINK_RATIO
	## Kullanıcı isteği (2026-09-25): "bundan sonra envanter ve altın göstergesi solda olsun grup paneli de sağda olsun" -
	## ENVANTER + altın artık SOL üstte, karakter kümesinin ve dirilme kalplerinin (ReviveHearts) altında; grup paneli sağda
	## minimapın altına geçti (bkz. party_panel.gd RIGHT_MARGIN/TOP_Y).
	## 2026-09-27: karakter kümesi (avatar/can/kalkan/seviye) ve kalpler alttaki oyuncu paneline taşındı (bkz.
	## _layout_player_dock) - sol üstte sadece ENVANTER + altın kaldı, en üste çıktılar.
	var left_edge: float = 20.0
	var top_y: float = 20.0
	var mobile_u: float = 1.0
	if MobileUIScript.enabled:
		## Telefon: can kümesinin altında, x HUD_SCALE (bkz. _layout_mobile_hud).
		mobile_u = MobileUIScript.HUD_SCALE
		var e: Rect2 = _mobile_edges()
		left_edge = e.position.x
		top_y = e.position.y + (MOBILE_CLUSTER_H + 6.0) * mobile_u

	# Envanter butonu üstte, altın göstergesi altında.
	envanter_toggle_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	envanter_toggle_button.offset_left = left_edge
	envanter_toggle_button.offset_right = left_edge + btn_w
	envanter_toggle_button.add_theme_font_size_override("font_size", 32)
	envanter_toggle_button.clip_text = true
	envanter_toggle_button.offset_top = top_y
	envanter_toggle_button.offset_bottom = top_y + btn_h

	## DÜZELTME (kullanıcı isteği: "3 dakikada bir açılan dükkan sadece level
	## atlama ekranından sonra çıkmalı ... oyundaki dükkan butonunu kaldır
	## sadece buradan satın alınabilecek") - ShopToggleButton artık HİÇ
	## gösterilmiyor, dükkana SADECE periyodik/level-atlama-sonrası tetikleme
	## ile ulaşılabiliyor (bkz. main.gd _show_mini_shop_screen ve
	## _resume_gameplay_after_level_flow). Buton tamamen gizli kalıyor,
	## tıklanamaz olduğu için pressed sinyaline bağlı olması zararsız.
	shop_toggle_button.visible = false

	# Altın göstergesi artık SADECE bir gösterge - envanter butonunun hemen altında.
	gold_indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
	gold_indicator.offset_left = left_edge
	gold_indicator.offset_right = left_edge + btn_w
	gold_indicator.offset_top = top_y + (btn_h + GAP) * mobile_u
	gold_indicator.offset_bottom = gold_indicator.offset_top + btn_h
	gold_indicator.visible = true
	for c: Control in [envanter_toggle_button, gold_indicator]:
		c.pivot_offset = Vector2.ZERO
		c.scale = Vector2.ONE * mobile_u

	## DÜZELTME (kullanıcı isteği: "dükkan paneli ekranın ortasında açılsın
	## sağ altta değil") - burada eskiden dükkan penceresini minimapın
	## üstünü kapatmasın diye sabit bir "sol-alt" konuma zorlayan bir blok
	## vardı (bkz. Git geçmişi: "sol alta doğru yakınlaşmasını istiyorum").
	## shop_panel.tscn'in kök anchor'ı artık zaten MERKEZ (bkz. oradaki not) -
	## bu kod HER ÇAĞRIDA o merkezlemeyi eski sabit konuma geri
	## döndürüyordu, panelin "sağ altta" görünmesinin asıl sebebi buydu.
	## Artık dükkan konumuna hiç dokunulmuyor, .tscn'deki merkez anchor
	## geçerliliğini koruyor.


## Kullanıcı isteği: "envanter ve dükkanın (artık altın göstergesi) aynı
## renkte olması" - ENVANTER butonu ve altın göstergesi (dükkan) artık
## BİREBİR aynı kahverengi/ahşap paleti paylaşıyor (envanter/dükkan
## pencerelerinin kendi PAL_WINDOW_BG'siyle de aynı). .tscn'e YAZILMIYOR
## (bkz. _layout_shop_inventory_buttons üstündeki not - editör sahneyi
## geri alıyor), bu yüzden stiller her çalıştırmada burada kodla üretiliyor.
const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)
const PAL_WINDOW_BORDER := Color(0.25, 0.15, 0.08, 1.0)
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)
var _gold_indicator_normal_style: StyleBox
var _gold_indicator_hover_style: StyleBoxFlat

func _make_toggle_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = border
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	return sb


## DÜZELTME (kullanıcı isteği: "oyundaki bütün butonları bununla
## değiştirmeni istiyorum") - ENVANTER/DÜKKAN butonları eskiden düz renkli
## ahşap kahverengisi StyleBoxFlat kullanıyordu (bkz. _make_toggle_style),
## artık oyundaki HER buton gibi gerçek ahşap plaka dokusuna sahip.
func _style_envanter_and_gold_buttons() -> void:
	ShopPanel._apply_wood_button_style(envanter_toggle_button)
	ShopPanel._apply_wood_button_style(shop_toggle_button)

	## Altın göstergesi artık SADECE bir gösterge (kullanıcı isteği: "sadece
	## göstergeye çevir") - tıklanabilirlik/hover davranışı kaldırıldı, kendi
	## sabit rengi (PAL_WINDOW_BG, bkz. hud.tscn) korunuyor.
	## Kullanıcı isteği (2026-09-21): tüm arayüz UIKit kitiyle uyumlu - altın göstergesi başlık tahtası (plaque) stilinde.
	## 2026-09-25 sadeleştirme: plaque.png'nin altın perçinsiz kopyası (tools/simplify_hud_frames.py) - aynı paylar.
	var plaque_clean := MenuKit._tex_style("plaque.png", [6, 5, 6, 5], [22, 6, 22, 6], false, MenuKit.GAME_DIR)
	plaque_clean.texture = load("res://assets/ui/game/hud_plaque_clean.png")
	_gold_indicator_normal_style = plaque_clean
	gold_indicator.add_theme_stylebox_override("panel", _gold_indicator_normal_style)
	## 2026-09-24: levha artık bej parşömen (oyun içi kit) - sahnedeki açık sarı yazı okunmuyordu, koyu altın.
	if gold_indicator_label:
		gold_indicator_label.add_theme_color_override("font_color", UIKit.C_GOLD)
		gold_indicator_label.add_theme_constant_override("outline_size", 0)
	_set_mouse_ignore_recursive(gold_indicator)


func _set_mouse_ignore_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_ignore_recursive(child)


## Skill2Icon'un hud.tscn'deki düğüm yapısını (TextureRect + BG/Cooldown/
## KeyLabel/StackBadge, bkz. skill_icon.gd) BİREBİR AYNI şekilde kod
## içinde kurar - SkillBar'a, Skill2Icon'un hemen sağına (aynı 4px boşluk
## deseniyle) eklenir. "skill3" alanı olmayan karakterlerde (çoğu karakter)
## _setup_ability_icons() bunu gizli tutar, hiçbir görsel fark yaratmaz.
func _create_skill3_icon() -> void:
	if not is_inside_tree():
		return
	var bar: Control = get_node_or_null("SkillBar")
	if not bar or bar.has_node("Skill3Icon"):
		return
	var icon := TextureRect.new()
	icon.name = "Skill3Icon"
	## DÜZELTME (kullanıcı isteği: "skiller arasındaki mesafeyi arttır") - Q (0-52) ve E'nin (bkz. hud.tscn
	## Skill2Icon, AYNI ABILITY_ICON_GAP'e göre elle hesaplanmış) hemen sağında, 2 tam yuva + 2 boşluk ötede.
	icon.offset_left = 2.0 * (SPIRIT_ICON_BASE_SIZE + ABILITY_ICON_GAP)
	icon.offset_top = 0.0
	icon.offset_right = icon.offset_left + SPIRIT_ICON_BASE_SIZE
	icon.offset_bottom = 52.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_script(preload("res://scripts/skill_icon.gd"))
	## DÜZELTME (kullanıcı bildirimi: "Tüm ultilerin ... bekleme süreleri
	## gösterilmiyor onun yerine içinde koyu bir bar doluyor") - kök neden:
	## icon burada AĞACA EKLENİP çocukları (Cooldown/StackBadge...) ANCAK SONRA
	## kuruluyordu; skill_icon.gd'nin `@onready var cooldown_label/stack_badge =
	## get_node_or_null(...)` referansları ağaca girerken (_ready öncesi) çözülür,
	## o an çocuklar henüz yoktu -> ikisi de null kalıyor, sayısal geri sayım ve
	## yük rozeti R ikonunda HİÇ çalışmıyordu (sadece koyu "bekleme örtüsü"
	## çiziliyordu). Artık çocuklar önce eklenir, ikon EN SON ağaca girer.

	var bg := TextureRect.new()
	bg.name = "BG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = preload("res://assets/ui/kit/hud_skill_frame.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.add_child(bg)

	var cooldown := Label.new()
	cooldown.name = "Cooldown"
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown.add_theme_font_size_override("font_size", 50)
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(cooldown)

	var key_label := Label.new()
	key_label.name = "KeyLabel"
	key_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	key_label.offset_left = -16.0
	key_label.offset_top = -18.0
	key_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	key_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	key_label.add_theme_color_override("font_color", Color(1, 1, 0.7, 1))
	key_label.add_theme_font_size_override("font_size", 25)
	key_label.text = "R"
	icon.add_child(key_label)

	var stack_badge := Label.new()
	stack_badge.name = "StackBadge"
	stack_badge.visible = false
	## DÜZELTME (kullanıcı bildirimi: "stacklenen skillerin dolma olayını
	## yanlış konumlandırmışsın, yeteneğin İÇİNDE görünmesi gerekiyor DIŞINDA
	## değil") - negatif offset'ler rozeti ikonun sol-üst köşesinin DIŞINA
	## taşırıyordu (bkz. hud.tscn'deki aynı düzeltme, SkillIcon/PassiveIcon/
	## Skill2Icon'un StackBadge'leri) - artık ikonun kendi 52x52 sınırının
	## İÇİNDE duruyor.
	## SONRAKİ DÜZELTME (kullanıcı isteği: "yük göstergeleri... sağ üstünde
	## belirtilmeli") - sol üstten sağ üste taşındı (hud.tscn'deki diğer üç
	## StackBadge ile AYNI, bu sefer koddan kurulduğu için anchor_*
	## property'leriyle).
	stack_badge.anchor_left = 1.0
	stack_badge.anchor_right = 1.0
	stack_badge.offset_left = -30.0
	stack_badge.offset_top = 4.0
	stack_badge.offset_right = -4.0
	stack_badge.offset_bottom = 28.0
	stack_badge.add_theme_color_override("font_color", Color(0.6, 0.95, 1, 1))
	stack_badge.add_theme_font_size_override("font_size", 32)
	stack_badge.text = "0"
	icon.add_child(stack_badge)

	bar.add_child(icon)
	skill3_icon = icon


## Ruhani Yetenek ikonu (F) - _create_skill3_icon ile AYNI düğüm yapısı (BG/Cooldown/KeyLabel/StackBadge, önce çocuklar sonra ikon
## ağaca girer - aynı @onready nedeni), ama: %20 büyük, mor-altın çerçeve tonu, tuş etiketi "F". Konumu her karede
## _place_spirit_icon() ile son GÖRÜNÜR yetenek butonunun sağına oturtulur (Q/E/R'nin hepsi olmayan karakterlerde boşluk kalmasın).
func _create_spirit_icon() -> void:
	if not is_inside_tree():
		return
	var bar: Control = get_node_or_null("SkillBar")
	if not bar or bar.has_node("SpiritIcon"):
		return
	var icon := TextureRect.new()
	icon.name = "SpiritIcon"
	var size_px: float = SPIRIT_ICON_BASE_SIZE * SPIRIT_ICON_SCALE
	icon.offset_left = 168.0
	icon.offset_right = 168.0 + size_px
	icon.offset_top = (SPIRIT_ICON_BASE_SIZE - size_px) * 0.5
	icon.offset_bottom = icon.offset_top + size_px
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_script(preload("res://scripts/skill_icon.gd"))

	var bg := TextureRect.new()
	bg.name = "BG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = preload("res://assets/ui/kit/hud_skill_frame_spirit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.modulate = SPIRIT_FRAME_TINT ## farklı çerçeve rengi (kullanıcı isteği)
	icon.add_child(bg)

	var cooldown := Label.new()
	cooldown.name = "Cooldown"
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown.add_theme_font_size_override("font_size", 50)
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(cooldown)

	var key_label := Label.new()
	key_label.name = "KeyLabel"
	key_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	key_label.offset_left = -16.0
	key_label.offset_top = -18.0
	key_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	key_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	key_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1))
	key_label.add_theme_font_size_override("font_size", 25)
	key_label.text = GameManager.get_action_key_label("skill4")
	icon.add_child(key_label)

	bar.add_child(icon)
	spirit_icon = icon
	icon.frame_border = 8.0 ## 6 sanat pikseli (=12 px) kalınlığındaki mor-altın çerçeve (SkillBar x1.5 => 8 birim)


## Ruhani ikonu son görünür yetenek butonunun (R, yoksa E, yoksa Q) sağına, aynı 4px boşlukla yerleştirir.
## (Eski ad korunuyor - hud.gd her karede çağırıyor.) Artık TÜM yetenek yuvalarını simetrik dizer: bkz. _layout_ability_icons.
func _place_spirit_icon() -> void:
	if _layout_ability_icons():
		_update_ability_bar_frame()


## Kullanıcı isteği (2026-09-24): simetrik yetenek çubuğu. Görünür yuvalar soldan sağa P | Q E R | F dizilir - hepsi
## AYNI boyutta (52), Q-E-R arası ABILITY_ICON_GAP, P ve F grubun iki ucunda EŞİT ABILITY_GROUP_GAP ile; bütün grup
## ekranın tam yatay ortasına oturur (eskiden Q yerel 0'dan başlıyordu, pasif 32 px'ti, F %10 büyüktü -> çubuk
## merkezden kayık ve iki ucu farklı görünüyordu). Yerleşim değiştiyse true döner (çerçeve/durum satırı güncellensin).
var _ability_layout_sig: String = ""

func _layout_ability_icons() -> bool:
	var bar: Control = get_node_or_null("SkillBar")
	if bar == null or skill_icon == null:
		return false
	if MobileUIScript.enabled and touch_controls != null:
		return _layout_mobile_ability_icons()
	var slots: Array = [] ## [Control, gap_before]
	var sz: float = SPIRIT_ICON_BASE_SIZE
	var group: Array = [skill_icon]
	if skill2_icon and skill2_icon.visible:
		group.append(skill2_icon)
	if skill3_icon and skill3_icon.visible:
		group.append(skill3_icon)
	if passive_icon and passive_icon.visible:
		slots.append([passive_icon, 0.0])
	for i in group.size():
		var gap: float = 0.0
		if not slots.is_empty():
			gap = ABILITY_GROUP_GAP if i == 0 else ABILITY_ICON_GAP
		slots.append([group[i], gap])
	if spirit_icon and spirit_icon.visible:
		slots.append([spirit_icon, ABILITY_GROUP_GAP])
	## 2026-09-27: dizi artık ekran ortasına değil yerel 0'dan başlar - SkillBar'ı oyuncu paneli (dock) yetenek bölümüne
	## oturtur (bkz. _layout_player_dock).
	var x: float = 0.0
	var sig: String = str(x) + "|" + str(slots.size())
	for sl in slots:
		var c: Control = sl[0]
		x += float(sl[1])
		c.offset_left = x
		c.offset_right = x + sz
		c.offset_top = 0.0
		c.offset_bottom = sz
		sig += "," + c.name
		x += sz
	if sig == _ability_layout_sig:
		return false
	_ability_layout_sig = sig
	return true


## Form hâli (player.gd get_hud_skill_override - bugün Shaman'ın Elemental Golem formundaki Q/E'si): doluysa ikonun adı/
## açıklaması/bekleme süresi/görseli form hâlininki; boşa dönünce (form bitti) karakterin normal ikonu geri yüklenir.
func _apply_hud_skill_override(icon, ov: Dictionary, slot: String) -> void:
	if icon == null or not is_instance_valid(icon):
		return
	if not ov.is_empty():
		icon.name_override = str(ov.get("name", ""))
		icon.desc_override = str(ov.get("desc", ""))
		icon.cooldown_override = float(ov.get("cooldown", -1.0))
		var tex: Texture2D = _cached_texture(str(ov.get("icon", ""))) if str(ov.get("icon", "")) != "" else null
		if tex and icon.custom_texture != tex:
			icon.custom_texture = tex
		icon.set_meta("hud_override", true)
	elif icon.has_meta("hud_override"):
		icon.remove_meta("hud_override")
		icon.name_override = ""
		icon.desc_override = ""
		icon.cooldown_override = -1.0
		var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
		if def.has(slot + "_icon"):
			var base_tex: Texture2D = _cached_texture(str(def[slot + "_icon"]))
			if base_tex:
				icon.custom_texture = base_tex


## characters.gd "skill2" alanı olan karakterlerde (ör. Oakley) ikinci bir
## yetenek ikonu da gösterilir - alanı olmayan karakterlerde Skill2Icon
## gizli kalır.
func _setup_ability_icons() -> void:
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	if def.has("skill_icon"):
		var tex: Texture2D = load(def["skill_icon"])
		if tex:
			skill_icon.custom_texture = tex
	var has_skill2: bool = def.has("skill2")
	skill2_icon.visible = has_skill2
	if has_skill2:
		skill2_icon.skill_id = def.get("skill2", 0)
		if def.has("skill2_icon"):
			var tex2: Texture2D = load(def["skill2_icon"])
			if tex2:
				skill2_icon.custom_texture = tex2

	## Üçüncü aktif yetenek (bkz. _create_skill3_icon) - "skill3" alanı olan
	## TEK karakter bugün Shaman, diğerlerinde gizli kalır.
	if skill3_icon:
		var has_skill3: bool = def.has("skill3")
		skill3_icon.visible = has_skill3
		if has_skill3:
			skill3_icon.skill_id = def.get("skill3", 0)
			if def.has("skill3_icon"):
				var tex3: Texture2D = load(def["skill3_icon"])
				if tex3:
					skill3_icon.custom_texture = tex3

	## Ruhani Yetenek: her karakterde görünür (seçilen yeteneğin ikonu). Pasif olan (Para) için de ikon gösterilir, sadece
	## bekleme/aktiflik çizilmez.
	if spirit_icon:
		var spirit_def: Dictionary = SpiritualSkillsScript.get_def(GameManager.selected_spiritual)
		spirit_icon.visible = SpiritualSkillsScript.is_valid(GameManager.selected_spiritual)
		spirit_icon.skill_id = -2
		if spirit_def.has("icon"):
			var spirit_tex: Texture2D = load(str(spirit_def["icon"]))
			if spirit_tex:
				spirit_icon.custom_texture = spirit_tex
		_place_spirit_icon()

	var has_passive: bool = def.has("passive") and not str(def["passive"]).is_empty()
	passive_icon.visible = has_passive
	if has_passive:
		## BUG DÜZELTMESİ (kullanıcı bildirimi: "bazı karakterlerin pasifi
		## oyun içindeyken görünmüyor"): "passive_icon" alanı olmayan bir
		## karakter (ör. yeni eklenen Şovalye Adam pasifi - henüz gerçek
		## sanat eseri ikonu yok) burada sessizce Öykü'nün ikonuna (varsayılan
		## değer) düşüyordu - yanlış ikon gösterip kafa karıştırmak yerine
		## artık characters.gd "passive_vector_id" ile skill_icon.gd'deki
		## doğru vektör ikonuna düşüyor (skill_icon/skill2_icon ile AYNI
		## custom_texture-yoksa-vektör deseni).
		passive_icon.skill_id = def.get("passive_vector_id", -1)
		passive_icon.custom_texture = null
		if def.has("passive_icon"):
			var p_tex: Texture2D = load(def["passive_icon"])
			if p_tex:
				passive_icon.custom_texture = p_tex
	_ability_layout_sig = ""
	_layout_ability_icons()
	_update_ability_bar_frame()


## Kullanıcı isteği (2026-09-22): "skill kutucuklarının olduğu yere arkasını kaplayacak bir çerçeve" - SkillBar'a
## _create_skill3_icon/_create_spirit_icon ile AYNI "programatik Control + add_child" desenle, ama İLK çocuk
## olarak (move_child ile) eklenir ki diğer ikonların ARKASINDA kalsın.
func _create_ability_bar_frame() -> void:
	if not is_inside_tree():
		return
	var bar: Control = get_node_or_null("SkillBar")
	if not bar or bar.has_node("AbilityBarFrame"):
		return
	var frame := Panel.new()
	frame.name = "AbilityBarFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UIKit.panel_style("ability_bar"))
	bar.add_child(frame)
	bar.move_child(frame, 0)
	ability_bar_frame = frame


## O anki karakterde GÖRÜNÜR olan yetenek ikonlarının (P/Q/E/R/F, hangileri varsa) yerel dikdörtgenlerinin
## birleşimini alıp çerçeveyi ona (+pay) oturtur - _setup_ability_icons() görünürlükleri/_place_spirit_icon()
## konumu belirledikten SONRA (o fonksiyonun sonunda) çağrılır, karakter değişmediği sürece bir daha gerekmez.
func _update_ability_bar_frame() -> void:
	var bar: Control = get_node_or_null("SkillBar")
	if not bar:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for child in bar.get_children():
		## Durum satırı ve eski çerçeve birleşime katılmaz (yalnız yetenek yuvaları).
		if child == ability_bar_frame or child == status_bar or not (child is Control):
			continue
		var c: Control = child
		if not c.visible:
			continue
		lo.x = minf(lo.x, c.offset_left)
		lo.y = minf(lo.y, c.offset_top)
		hi.x = maxf(hi.x, c.offset_right)
		hi.y = maxf(hi.y, c.offset_bottom)
	## 2026-09-27: yetenek yuvalarının eski oval çerçevesi yerine tüm oyuncu paneli tek çerçeve (DockFrame).
	if is_instance_valid(ability_bar_frame):
		ability_bar_frame.visible = false
	if lo.x == INF:
		lo = Vector2.ZERO
		hi = Vector2.ZERO
	_icons_lo = lo
	_icons_hi = hi
	_layout_player_dock()
	_update_status_bar_layout()


## ---------------------------------------------------------------- OYUNCU PANELİ (dock)
## Kullanıcı isteği (2026-09-27): "alttaki yetenek panelini değiştiriyoruz, yetenek paneli artık sol üstteki can ve kalkan
## barını avatar barını level ve kalan canların oranını da içerecek şekilde sığdırılmalı yeniden konumlandırılmalı ve
## yeniden tasarlanmalı" - 4 prototipten "B" seçildi: tek ahşap panel (ability_bar dokusu), solda portre + altında seviye
## rozeti, sağ üstte yetenek yuvaları, altlarında yetenek dizisi genişliğinde can (kalın) ve kalkan (ince) piksel çubukları,
## kalpler portrenin üstünde küçük bir sekmede. Sol üstteki eski küme kaldırıldı - AYNI düğümler (CharacterCluster,
## SkillBar, ReviveHearts) buraya taşındı (@onready referansları/testler geçerli). Eski levha çubukları (HealthBar/
## ShieldBar + çerçeve + yazı) gizli ama güncellenmeye devam eder; görünen çubuklar hud_pixel_bar.gd.
## Ölçüler 1920x1080 taban, ekranın alt-ortasına göre.
const DOCK_PAD_X := 16.0
const DOCK_PAD_TOP := 12.0
const DOCK_PAD_BOTTOM := 12.0
## Kullanıcı isteği (2026-09-27, ikinci tur): "alttaki karakter skilleri panelini biraz küçült üp exp barıyla arasında azıcık
## boşluk olmasını sağla" - panel bütünüyle DOCK_SCALE ile küçülür (portre/rozet/çubuklar CharacterCluster.scale ile, yetenek
## yuvaları SkillBar.scale ile - yerel yerleşim aynı kalır), XP şeridinin (bottom_exp_bar.gd BAR_HEIGHT 10) üstünde ~10 px boşluk.
const DOCK_SCALE := 0.85
const SKILLBAR_BASE_SCALE := 1.275 ## hud.tscn SkillBar ölçeği (panel küçültmesinden önce)
const DOCK_BOTTOM_MARGIN := 30.0 ## kullanıcı: "bi 10px daha yukarı" (20 -> 30)
const DOCK_PORTRAIT := 96.0 ## hud_avatar_frame.png doğal boyu
const DOCK_PORTRAIT_GAP := 14.0
const DOCK_ROW_GAP := 6.0
const DOCK_HP_H := 22.0
const DOCK_SHIELD_H := 16.0
const DOCK_BAR_GAP := 2.0
const DOCK_BADGE_OVERHANG := 26.0 ## seviye rozeti portre çerçevesinin altından bu kadar taşar (hud.tscn LevelBadge 70..122)
const HEARTS_TAB_W := 100.0
const HEARTS_TAB_H := 36.0
const HEARTS_TAB_TIMER_W := 64.0 ## kalp yenilenme sayacı (m:ss) görünürken sekme bu kadar genişler
const HEARTS_TAB_OVERLAP := 6.0
const PixelBarScript: GDScript = preload("res://scripts/hud_pixel_bar.gd")
const SHIELD_BAR_COLOR := Color(0.24, 0.59, 0.91)

var dock_frame: Panel = null
var hearts_tab: Panel = null
var dock_hp_bar: Control = null
var dock_shield_bar: Control = null
var _icons_lo := Vector2.ZERO
var _icons_hi := Vector2.ZERO
var _hearts_tab_wide: bool = false


func _create_player_dock() -> void:
	if not is_inside_tree() or has_node("DockFrame"):
		return
	var cluster: Control = get_node_or_null("CharacterCluster")
	dock_frame = Panel.new()
	dock_frame.name = "DockFrame"
	dock_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_frame.add_theme_stylebox_override("panel", UIKit.panel_style("ability_bar"))
	add_child(dock_frame)
	if cluster:
		move_child(dock_frame, cluster.get_index())
	hearts_tab = Panel.new()
	hearts_tab.name = "HeartsTab"
	hearts_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts_tab.add_theme_stylebox_override("panel", UIKit.panel_style("status_badge"))
	add_child(hearts_tab)
	if revive_hearts:
		move_child(hearts_tab, revive_hearts.get_index())
		if revive_hearts.has_method("set_regen_label_position"):
			revive_hearts.set_regen_label_position(Vector2(84.0, -3.0))
	if cluster:
		for n: String in ["HealthBar", "HealthBarFrame", "HealthValueLabel", "ShieldBar", "ShieldBarFrame", "ShieldValueLabel"]:
			var old: CanvasItem = cluster.get_node_or_null(n) as CanvasItem
			if old:
				old.visible = false
		dock_hp_bar = Control.new()
		dock_hp_bar.name = "DockHpBar"
		dock_hp_bar.set_script(PixelBarScript)
		cluster.add_child(dock_hp_bar)
		dock_shield_bar = Control.new()
		dock_shield_bar.name = "DockShieldBar"
		dock_shield_bar.set_script(PixelBarScript)
		dock_shield_bar.set("font_size", 16)
		dock_shield_bar.set("fill", SHIELD_BAR_COLOR)
		dock_shield_bar.set("ratio", 0.0)
		dock_shield_bar.set("text", "0/0")
		cluster.add_child(dock_shield_bar)
		## _ready ilk can/kalkan değerini dock kurulmadan ÖNCE yazıyor - gizli eski çubuklardan kopyala.
		var hp_span: float = maxf(float(health_bar.max_value), 0.001)
		dock_hp_bar.call("set_values", clampf(float(health_bar.value) / hp_span, 0.0, 1.0), health_bar.tint_progress, health_value_label.text)
		var sh_span: float = float(item_shield_bar.max_value)
		dock_shield_bar.call("set_values", clampf(float(item_shield_bar.value) / sh_span, 0.0, 1.0) if sh_span > 0.001 else 0.0,
			SHIELD_BAR_COLOR, shield_value_label.text)
	var bar: Control = get_node_or_null("SkillBar")
	if bar:
		bar.pivot_offset = Vector2.ZERO ## dock konumu SkillBar'ın sol üst köşesinden hesaplanır


func _dock_place(c: Control, r: Rect2) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.end.x
	c.offset_bottom = r.end.y


func _layout_player_dock() -> void:
	if MobileUIScript.enabled:
		_layout_mobile_hud()
		return
	var bar: Control = get_node_or_null("SkillBar")
	var cluster: Control = get_node_or_null("CharacterCluster")
	if bar == null or cluster == null or not is_instance_valid(dock_frame):
		return
	var sc: float = DOCK_SCALE
	bar.scale = Vector2.ONE * SKILLBAR_BASE_SCALE * sc
	var k: float = bar.scale.x
	## Yerel (küçültmesiz) ölçüler - eski yerleşimin aynısı; ekrandaki boyut = yerel x sc.
	var row_w: float = maxf((_icons_hi.x - _icons_lo.x) * SKILLBAR_BASE_SCALE, 200.0)
	var row_h: float = maxf((_icons_hi.y - _icons_lo.y) * SKILLBAR_BASE_SCALE, 40.0)
	var content_h: float = row_h + DOCK_ROW_GAP + DOCK_HP_H + DOCK_BAR_GAP + DOCK_SHIELD_H
	var dock_h: float = DOCK_PAD_TOP + content_h + DOCK_PAD_BOTTOM
	var dock_w: float = DOCK_PAD_X + DOCK_PORTRAIT + DOCK_PORTRAIT_GAP + row_w + DOCK_PAD_X
	var x0: float = roundf(-dock_w * sc * 0.5)
	var y1: float = -DOCK_BOTTOM_MARGIN
	var y0: float = roundf(y1 - dock_h * sc)
	_dock_place(dock_frame, Rect2(x0, y0, dock_w * sc, y1 - y0))
	_dock_place(cluster, Rect2(x0, y0, dock_w, dock_h))
	cluster.pivot_offset = Vector2.ZERO
	cluster.scale = Vector2.ONE * sc

	## Yetenek yuvaları: dock'un sağ üst bölümü (SkillBar ölçekli; yerel ikon dizisi _icons_lo'dan başlar).
	var sx: float = x0 + (DOCK_PAD_X + DOCK_PORTRAIT + DOCK_PORTRAIT_GAP) * sc
	var sy: float = y0 + DOCK_PAD_TOP * sc
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = sx - _icons_lo.x * k
	bar.offset_top = sy - _icons_lo.y * k
	bar.offset_right = bar.offset_left + maxf(_icons_hi.x, 1.0)
	bar.offset_bottom = bar.offset_top + maxf(_icons_hi.y, 1.0)

	## Portre + seviye rozeti (küme yerel koordinatı = dock sol üstü). Rozet dock'un içinde kalsın.
	var py: float = maxf(4.0, dock_h - 4.0 - DOCK_PORTRAIT - DOCK_BADGE_OVERHANG)
	py = minf(py, DOCK_PAD_TOP - 4.0)
	var fo := Vector2(DOCK_PAD_X, py)
	_cluster_rect(cluster, "PortraitFrame", Rect2(fo, Vector2(DOCK_PORTRAIT, DOCK_PORTRAIT)))
	_cluster_rect(cluster, "PortraitClip", Rect2(fo + Vector2(12, 12), Vector2(72, 72)))
	_cluster_rect(cluster, "LevelBadge", Rect2(fo + Vector2(22, 70), Vector2(52, 52)))
	_cluster_rect(cluster, "LevelLabel", Rect2(fo + Vector2(22, 70), Vector2(52, 52)))

	## Can + kalkan: yetenek dizisinin altında, onunla aynı genişlikte.
	var bx: float = DOCK_PAD_X + DOCK_PORTRAIT + DOCK_PORTRAIT_GAP
	var by: float = DOCK_PAD_TOP + row_h + DOCK_ROW_GAP
	if dock_hp_bar:
		dock_hp_bar.position = Vector2(bx, by)
		dock_hp_bar.size = Vector2(row_w, DOCK_HP_H)
	if dock_shield_bar:
		dock_shield_bar.position = Vector2(bx, by + DOCK_HP_H + DOCK_BAR_GAP)
		dock_shield_bar.size = Vector2(row_w, DOCK_SHIELD_H)

	_layout_hearts_tab(x0, y0)


## ---------------------------------------------------------------- TELEFON HUD'u (bkz. mobile_ui.gd)
## Kullanıcı isteği (2026-10-01): "skill barı, can kalkan barı androide uyumlu olarak yeniden tasarlanmalı" - masaüstü
## dock'u (portre + ahşap panel + yuvalar + çubuklar) telefonda dağılır, AYNI düğümler kullanılır:
##  - sol üst: seviye rozeti + oyunun kendi piksel can/kalkan çubukları (hud_pixel_bar.gd) + kalpler; portre/panel gizli,
##  - sağ alt: yetenek ikonları dikey sütun (alttan: Q, E, R, F, en üstte pasif), onaylanan ince yuvarlak ahşap çerçeve
##    (assets/ui/kit/hud_skill_frame_round.png, tools/gen_round_skill_frame.py) + ikon dairesel maskeli
##    (shaders/round_mask.gdshader); dokununca touch_controls.gd mevcut eylemlere basar,
##  - sol alt joystick, sağ üstte duraklat, etkileşim düğmesi sadece ev/satıcı uyarısı görünürken.
## Masaüstünde bu blok hiç çalışmaz.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const ROUND_FRAME: Texture2D = preload("res://assets/ui/kit/hud_skill_frame_round.png")
const ROUND_FRAME_SPIRIT: Texture2D = preload("res://assets/ui/kit/hud_skill_frame_spirit_round.png")
const ROUND_MASK_SHADER: Shader = preload("res://shaders/round_mask.gdshader")
## Aşağıdaki ölçüler "HUD birimi": ekrana MobileUI.HUD_SCALE (1.5) ile çarpılarak çıkar (genel arayüz ölçeği 1.0 - bkz.
## mobile_ui.gd: tüm ekranlar masaüstü tasarımıyla sığsın diye sadece bu öğeler büyür). Kenar payları çentik payını da içerir.
const MOBILE_MARGIN := 12.0
const MOBILE_BOTTOM_MARGIN := 18.0 ## alttaki XP şeridinin üstünde
const MOBILE_SKILL_PX := 88.0 ## yetenek düğmesi çapı (x1.5 -> 132 px, ~13 mm)
const MOBILE_SKILL_GAP := 12.0
const MOBILE_BAR_W := 250.0
const MOBILE_CLUSTER_H := 84.0 ## sol üst can kümesinin yüksekliği (envanter düğmesi altına gelir)
const MOBILE_RING_PX := 4.0 ## çerçeve halkası (dış hat + ahşap + iç hat) 54 px dokuda
const MOBILE_PASSIVE_K := 0.62 ## pasif ikon basılmaz - sütunun tepesinde küçük durur (sütun minimap'e uzanmasın)
const MOBILE_MINIMAP_K := 0.8 ## minimap x HUD_SCALE (164 -> ~223 px)
var touch_controls: Control = null
var mobile_pause_button: Button = null
var mobile_interact_button: Button = null


## Ekran kenarından içeri pay (tuval px): position = (sol, üst), size = (sağ, alt). Çentik/kamera deliği payı + HUD payı.
func _mobile_edges() -> Rect2:
	var u: float = MobileUIScript.HUD_SCALE
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Rect2(safe.position.x + MOBILE_MARGIN * u, safe.position.y + MOBILE_MARGIN * u,
			safe.size.x + MOBILE_MARGIN * u, safe.size.y + MOBILE_BOTTOM_MARGIN * u)


func _setup_mobile_hud() -> void:
	if not MobileUIScript.enabled or not is_inside_tree() or touch_controls != null:
		return
	if is_instance_valid(dock_frame):
		dock_frame.visible = false
	if is_instance_valid(hearts_tab):
		hearts_tab.visible = false
	var cluster: Control = get_node_or_null("CharacterCluster")
	if cluster:
		for n: String in ["PortraitFrame", "PortraitClip"]:
			var c: CanvasItem = cluster.get_node_or_null(n) as CanvasItem
			if c:
				c.visible = false
	for icon in [skill_icon, skill2_icon, skill3_icon, spirit_icon, passive_icon]:
		if icon:
			_apply_mobile_skill_look(icon, icon == spirit_icon)
	touch_controls = TouchControlsScript.new()
	touch_controls.name = "TouchControls"
	touch_controls.extra_block = _mobile_hud_panel_open
	add_child(touch_controls)
	for pair in [[skill_icon, &"skill"], [skill2_icon, &"skill2"], [skill3_icon, &"skill3"], [spirit_icon, &"skill4"]]:
		if pair[0]:
			touch_controls.register_button(pair[0], pair[1])
	mobile_pause_button = _make_mobile_button("MobilePause", "II")
	touch_controls.register_button(mobile_pause_button, &"ui_cancel", false)
	touch_controls.pause_button = mobile_pause_button
	mobile_interact_button = _make_mobile_button("MobileInteract", "ETKİLEŞİM")
	mobile_interact_button.visible = false
	touch_controls.register_button(mobile_interact_button, &"interact", false)
	touch_controls.interact_button = mobile_interact_button
	_ability_layout_sig = ""
	_layout_ability_icons()
	_update_ability_bar_frame()
	_layout_shop_inventory_buttons()
	_fit_mobile_inventory_panels.call_deferred()


## Envanter + özellikler panelleri (sahnede sabit konumlu, yan yana) birlikte ekrana sığacak kadar büyütülüp ortalanır -
## açılır ekranlarla aynı kural (bkz. mobile_ui.gd MenuFitter); paneller kendini yeniden konumlamadığı için bir kez yeter.
func _fit_mobile_inventory_panels() -> void:
	var panels: Array[Control] = []
	for c in [stats_panel_instance, inventory_panel_instance]:
		if c is Control and is_instance_valid(c):
			panels.append(c)
	if panels.is_empty():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var r: Rect2 = panels[0].get_global_rect()
	for c in panels:
		r = r.merge(c.get_global_rect())
	## Soldaki ENVANTER/altın sütununa ve sağdaki yetenek sütununa binmesin: her iki yandan sütun genişliği kadar dar
	## bir alana sığdırılır (simetrik), sonra ekranda ortalanır.
	var side: float = _mobile_edges().position.x + 168.0 * MobileUIScript.HUD_SCALE
	var avail := Vector2(vp.x - 2.0 * side, vp.y)
	var s: float = MobileUIScript.fit_scale(r.size, avail)
	var xf: Transform2D = MobileUIScript.fit_transform(r, s, vp)
	for c in panels:
		c.pivot_offset = Vector2.ZERO
		c.scale = c.scale * s
		c.global_position = xf * c.global_position


## Envanter/özellikler paneli oyunu duraklatmaz - açıkken joystick başlamasın ve çizilmesin (panelin üstüne binmesin).
func _mobile_hud_panel_open() -> bool:
	return (stats_panel_instance != null and stats_panel_instance.visible) \
			or (inventory_panel_instance != null and inventory_panel_instance.visible)


## Düğme görseli (ahşap stil); basma işini touch_controls yapar - fare olaylarını yutmasın (ikinci parmak da çalışsın).
func _make_mobile_button(n: String, text: String) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_font_size_override("font_size", 26)
	ShopPanel._apply_wood_button_style(b)
	add_child(b)
	return b


func _apply_mobile_skill_look(icon: Control, spirit: bool) -> void:
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE ## dokunuşta takılı kalan ipucu penceresi açılmasın
	var bg: TextureRect = icon.get_node_or_null("BG") as TextureRect
	if bg:
		bg.texture = ROUND_FRAME_SPIRIT if spirit else ROUND_FRAME
		bg.modulate = Color.WHITE
	var key: CanvasItem = icon.get_node_or_null("KeyLabel") as CanvasItem
	if key:
		key.visible = false
	var sz: float = SPIRIT_ICON_BASE_SIZE
	icon.set("frame_border", sz * MOBILE_RING_PX / 54.0)
	var mat := ShaderMaterial.new()
	mat.shader = ROUND_MASK_SHADER
	mat.set_shader_parameter("merkez", Vector2(sz, sz) * 0.5)
	mat.set_shader_parameter("yaricap", sz * 0.5 - sz * MOBILE_RING_PX / 54.0 + 0.6)
	icon.material = mat


func _mobile_column() -> Array:
	var col: Array = []
	for icon in [skill_icon, skill2_icon, skill3_icon, spirit_icon, passive_icon]:
		if icon and icon.visible:
			col.append(icon)
	return col


## SkillBar'ın ölçeği: ikon (52 birim) ekranda MOBILE_SKILL_PX * HUD_SCALE px olur.
func _mobile_skill_k() -> float:
	return MOBILE_SKILL_PX * MobileUIScript.HUD_SCALE / SPIRIT_ICON_BASE_SIZE


## Sütun yüksekliği (SkillBar yerel birimi): Q/E/R/F tam boy, pasif MOBILE_PASSIVE_K boy.
func _mobile_column_height(col: Array) -> float:
	var sz: float = SPIRIT_ICON_BASE_SIZE
	var gap: float = MOBILE_SKILL_GAP * MobileUIScript.HUD_SCALE / _mobile_skill_k()
	var h: float = 0.0
	for i in col.size():
		h += sz * (MOBILE_PASSIVE_K if col[i] == passive_icon else 1.0)
		if i > 0:
			h += gap
	return h


## Sütun: SkillBar yerelinde x=0, alttan yukarı. SkillBar sağ-alta yaslı (bkz. _layout_mobile_hud).
func _layout_mobile_ability_icons() -> bool:
	var col: Array = _mobile_column()
	var sz: float = SPIRIT_ICON_BASE_SIZE
	var gap: float = MOBILE_SKILL_GAP * MobileUIScript.HUD_SCALE / _mobile_skill_k()
	var n: int = col.size()
	var sig: String = "m|" + str(n)
	var bottom: float = _mobile_column_height(col)
	for i in n:
		var c: Control = col[i]
		var k: float = MOBILE_PASSIVE_K if c == passive_icon else 1.0
		var h: float = sz * k
		## Pasif küçük: ölçek düğümün kendisinde (maskeli çizim aynı kalsın), sütunun ortasına hizalı.
		c.pivot_offset = Vector2.ZERO
		c.scale = Vector2.ONE * k
		c.offset_left = (sz - h) * 0.5
		c.offset_right = c.offset_left + sz
		c.offset_top = bottom - h
		c.offset_bottom = c.offset_top + sz
		bottom -= h + gap
		sig += "," + c.name
	if sig == _ability_layout_sig:
		return false
	_ability_layout_sig = sig
	return true


func _layout_mobile_hud() -> void:
	var bar: Control = get_node_or_null("SkillBar")
	var cluster: Control = get_node_or_null("CharacterCluster")
	if bar == null or cluster == null:
		return
	var u: float = MobileUIScript.HUD_SCALE
	var e: Rect2 = _mobile_edges() ## sol, üst, sağ, alt
	## Yetenek sütunu: sağ alt.
	var sz: float = SPIRIT_ICON_BASE_SIZE
	var k: float = _mobile_skill_k()
	var col_h: float = maxf(_mobile_column_height(_mobile_column()), sz)
	bar.pivot_offset = Vector2.ZERO
	bar.scale = Vector2.ONE * k
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bar.offset_left = -e.size.x - sz * k
	bar.offset_top = -e.size.y - col_h * k
	bar.offset_right = bar.offset_left + sz
	bar.offset_bottom = bar.offset_top + col_h
	## Can kümesi: sol üst - seviye rozeti + iki piksel çubuk (yerel ölçüler HUD birimi, küme x HUD_SCALE).
	cluster.pivot_offset = Vector2.ZERO
	cluster.scale = Vector2.ONE * u
	cluster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cluster.offset_left = e.position.x
	cluster.offset_top = e.position.y
	cluster.offset_right = e.position.x + 60.0 + MOBILE_BAR_W
	cluster.offset_bottom = e.position.y + MOBILE_CLUSTER_H
	_cluster_rect(cluster, "LevelBadge", Rect2(0, 0, 52, 52))
	_cluster_rect(cluster, "LevelLabel", Rect2(0, 0, 52, 52))
	if dock_hp_bar:
		dock_hp_bar.position = Vector2(60.0, 4.0)
		dock_hp_bar.size = Vector2(MOBILE_BAR_W, DOCK_HP_H)
	if dock_shield_bar:
		dock_shield_bar.position = Vector2(60.0, 4.0 + DOCK_HP_H + DOCK_BAR_GAP)
		dock_shield_bar.size = Vector2(MOBILE_BAR_W, DOCK_SHIELD_H)
	if revive_hearts:
		revive_hearts.set_anchors_preset(Control.PRESET_TOP_LEFT)
		revive_hearts.pivot_offset = Vector2.ZERO
		revive_hearts.scale = Vector2.ONE * 0.8 * u
		revive_hearts.offset_left = e.position.x + 60.0 * u
		revive_hearts.offset_top = e.position.y + (4.0 + DOCK_HP_H + DOCK_BAR_GAP + DOCK_SHIELD_H + 6.0) * u
		revive_hearts.offset_right = revive_hearts.offset_left + 90.0
		revive_hearts.offset_bottom = revive_hearts.offset_top + 32.0
	## Minimap: sağ üst, can kümesiyle AYNI kenar payında (simetrik) ve x HUD_SCALE.
	var minimap: Control = get_node_or_null("MinimapControl")
	var mm_left: float = -e.size.x
	var mm_bottom: float = e.position.y
	if minimap:
		var mk: float = MOBILE_MINIMAP_K * u
		var mm: float = minimap.custom_minimum_size.x
		minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		minimap.pivot_offset = Vector2.ZERO
		minimap.scale = Vector2.ONE * mk
		minimap.offset_left = -e.size.x - mm * mk
		minimap.offset_right = minimap.offset_left + mm
		minimap.offset_top = e.position.y
		minimap.offset_bottom = e.position.y + mm
		mm_left = minimap.offset_left
		mm_bottom = e.position.y + mm * mk
	## Grup paneli (çok oyunculu): minimapın altı, sağ kenar payında.
	var party: Control = get_node_or_null("PartyPanelLayer/PartyPanel") as Control
	if party:
		party.pivot_offset = Vector2.ZERO
		party.scale = Vector2.ONE * u * 0.8
		party.offset_left = -e.size.x
		party.offset_right = -e.size.x
		party.offset_top = mm_bottom + 10.0 * u
		party.offset_bottom = party.offset_top
	## Duraklat: minimapın solunda, üst hizada; etkileşim: yetenek sütununun solunda, alt hizada.
	if is_instance_valid(mobile_pause_button):
		_place_mobile_button(mobile_pause_button, Control.PRESET_TOP_RIGHT, Vector2(mm_left - 10.0 * u, e.position.y),
				Vector2(56.0, 56.0))
	if is_instance_valid(mobile_interact_button):
		_place_mobile_button(mobile_interact_button, Control.PRESET_BOTTOM_RIGHT,
				Vector2(-e.size.x - sz * k - 18.0 * u, -e.size.y - 10.0 * u), Vector2(190.0, 64.0))
	## Joystick'in boştaki yeri: Q düğmesiyle ayna simetrisi (aynı kenar payı, aynı alt hiza).
	if touch_controls:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var q_r: float = sz * k * 0.5
		touch_controls.rest_center = Vector2(e.position.x + q_r + 40.0 * u, vp.y - e.size.y - q_r - 22.0 * u)


## Sağa yaslı telefon düğmesi: `corner` = düğmenin sağ-üst (TOP_RIGHT) ya da sağ-alt (BOTTOM_RIGHT) köşesi, ekranın o
## köşesine göre; `base` boyut HUD birimi (ölçek düğmenin kendisinde - metin de büyür).
func _place_mobile_button(b: Button, preset: int, corner: Vector2, base: Vector2) -> void:
	var u: float = MobileUIScript.HUD_SCALE
	b.set_anchors_preset(preset)
	b.pivot_offset = Vector2.ZERO
	b.scale = Vector2.ONE * u
	b.offset_left = corner.x - base.x * u
	b.offset_right = b.offset_left + base.x
	b.offset_top = corner.y - base.y * u if preset == Control.PRESET_BOTTOM_RIGHT else corner.y
	b.offset_bottom = b.offset_top + base.y


## Telefonda kasmanın CPU mu (oyun mantığı) GPU mu (çizim) olduğunu ayırt etmek için FPS etiketinin uzun hali
## (Ayarlar > FPS göstergesi açıkken): kare süresi, GPU çizim süresi, çizim komutu ve yaratık sayısı. GPU süresi kare
## süresine yakınsa darboğaz çizim, çok altındaysa oyun mantığı.
var _perf_measure_on: bool = false
func _mobile_perf_text() -> String:
	var vp_rid: RID = get_viewport().get_viewport_rid()
	if not _perf_measure_on:
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		_perf_measure_on = true
	var fps: float = Engine.get_frames_per_second()
	var frame_ms: float = 1000.0 / maxf(fps, 1.0)
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	return "FPS %d | kare %.1f ms | GPU %.1f ms | çizim %d | yaratık %d" % [int(fps), frame_ms, gpu_ms, draws, enemies]


## Durum (buff/debuff) satırı telefonda can kümesinin sağına, üst kenara taşınır (yetenek sütununun içinde yer yok).
func _layout_mobile_status_bar() -> void:
	if not is_instance_valid(status_bar):
		return
	if status_bar.get_parent() != self:
		status_bar.reparent(self, false)
	var u: float = MobileUIScript.HUD_SCALE
	var e: Rect2 = _mobile_edges()
	status_bar.pivot_offset = Vector2.ZERO
	status_bar.scale = Vector2.ONE * u
	status_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var w: float = 360.0
	status_bar.offset_left = e.position.x + (60.0 + MOBILE_BAR_W + 16.0) * u
	status_bar.offset_right = status_bar.offset_left + w
	status_bar.offset_top = e.position.y
	status_bar.offset_bottom = e.position.y + STATUS_ROW_HEIGHT
	if status_buff_row:
		status_buff_row.offset_left = 0.0
		status_buff_row.offset_right = w * 0.5 - STATUS_CENTER_GAP
		status_buff_row.offset_top = 0.0
		status_buff_row.offset_bottom = STATUS_ROW_HEIGHT
	if status_debuff_row:
		status_debuff_row.offset_left = w * 0.5 + STATUS_CENTER_GAP
		status_debuff_row.offset_right = w
		status_debuff_row.offset_top = 0.0
		status_debuff_row.offset_bottom = STATUS_ROW_HEIGHT


func _cluster_rect(cluster: Control, n: String, r: Rect2) -> void:
	var c: Control = cluster.get_node_or_null(n) as Control
	if c == null:
		return
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.end.x
	c.offset_bottom = r.end.y


## Kalpler portrenin üstünde küçük sekmede; yenilenme sayacı görünürken sekme sağa genişler (sayaç kalplerin yanında).
func _layout_hearts_tab(x0: float, y0: float) -> void:
	if not is_instance_valid(hearts_tab) or revive_hearts == null:
		return
	_hearts_tab_wide = revive_hearts.has_method("is_regen_visible") and bool(revive_hearts.is_regen_visible())
	## Panelle aynı oranda küçülür (DOCK_SCALE).
	var sc: float = DOCK_SCALE
	var w: float = roundf((HEARTS_TAB_W + (HEARTS_TAB_TIMER_W if _hearts_tab_wide else 0.0)) * sc)
	var h: float = roundf(HEARTS_TAB_H * sc)
	var tx: float = x0 + roundf(10.0 * sc)
	var tb: float = y0 + roundf(HEARTS_TAB_OVERLAP * sc)
	_dock_place(hearts_tab, Rect2(tx, tb - h, w, h))
	_dock_place(revive_hearts, Rect2(tx + roundf(8.0 * sc), tb - h + roundf(5.0 * sc), 90.0, 32.0))
	revive_hearts.pivot_offset = Vector2.ZERO
	revive_hearts.scale = Vector2.ONE * sc


## Kullanıcı isteği (2026-09-22): "bufflar solda debufflar sağda görünmeli" - iki HBoxContainer, biri sola
## yaslı (soldan sağa büyür), biri sağa yaslı (sağdan sola büyür); ability_bar_frame'in TAM ÜSTÜNE, onunla AYNI
## genişlikte oturur (bkz. _update_status_bar_layout).
func _create_status_bar() -> void:
	if not is_inside_tree():
		return
	var bar: Control = get_node_or_null("SkillBar")
	if not bar or bar.has_node("StatusBar"):
		return
	var root := Control.new()
	root.name = "StatusBar"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(root)
	status_bar = root

	var buffs := HBoxContainer.new()
	buffs.name = "BuffRow"
	buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buffs.add_theme_constant_override("separation", 4)
	## Merkezden SOLA büyür (çubuğun ortasına yaslı) - debufflar merkezden SAĞA; iki taraf simetrik.
	buffs.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buffs)
	status_buff_row = buffs

	var debuffs := HBoxContainer.new()
	debuffs.name = "DebuffRow"
	debuffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debuffs.add_theme_constant_override("separation", 4)
	debuffs.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(debuffs)
	status_debuff_row = debuffs


## StatusBar'ı (ve içindeki iki yarı) ability_bar_frame'in hemen üstüne, onunla AYNI genişlikte yerleştirir.
## Yükseklik status_effect_badge.tscn'in kendi boyuyla (HEIGHT, altındaki süre şeridi dahil) eşleşiyor.
const STATUS_ROW_HEIGHT := 42.0
const STATUS_CENTER_GAP := 4.0 ## buff ve debuff sıraları çubuğun ortasında bu kadar aralıkla karşılaşır


func _update_status_bar_layout() -> void:
	if not is_instance_valid(status_bar):
		return
	if MobileUIScript.enabled and touch_controls != null:
		_layout_mobile_status_bar()
		return
	## 2026-09-27: dock'un yetenek bölümünün TAM ÜSTÜNE, yetenek dizisiyle aynı genişlikte (SkillBar yerel koordinatı).
	var bar: Control = status_bar.get_parent() as Control
	var k: float = maxf(absf(bar.scale.x), 0.01) if bar else 1.0
	var w: float = _icons_hi.x - _icons_lo.x
	status_bar.offset_left = _icons_lo.x
	status_bar.offset_right = _icons_hi.x
	status_bar.offset_bottom = _icons_lo.y - (DOCK_PAD_TOP * DOCK_SCALE + 6.0) / k
	status_bar.offset_top = status_bar.offset_bottom - STATUS_ROW_HEIGHT
	if status_buff_row:
		status_buff_row.offset_left = 0.0
		status_buff_row.offset_right = w * 0.5 - STATUS_CENTER_GAP
		status_buff_row.offset_top = 0.0
		status_buff_row.offset_bottom = STATUS_ROW_HEIGHT
	if status_debuff_row:
		status_debuff_row.offset_left = w * 0.5 + STATUS_CENTER_GAP
		status_debuff_row.offset_right = w
		status_debuff_row.offset_top = 0.0
		status_debuff_row.offset_bottom = STATUS_ROW_HEIGHT


## Her karede player.gd get_status_effects()'i okuyup iki satırı (buff/debuff) senkron tutar - bkz. player.gd
## üstündeki AYNI notta yeni bir efekt eklemenin nasıl BURAYA hiç dokunmadan çalıştığı.
func _update_status_bar() -> void:
	if not is_instance_valid(status_buff_row) or not is_instance_valid(status_debuff_row):
		return
	if not player or not is_instance_valid(player) or not player.has_method("get_status_effects"):
		_sync_status_row(status_buff_row, [])
		_sync_status_row(status_debuff_row, [])
		return
	var effects: Array = player.get_status_effects()
	var buffs: Array = []
	var debuffs: Array = []
	for e in effects:
		if bool(e.get("is_buff", true)):
			buffs.append(e)
		else:
			debuffs.append(e)
	_sync_status_row(status_buff_row, buffs)
	_sync_status_row(status_debuff_row, debuffs)


func _sync_status_row(row: HBoxContainer, effects: Array) -> void:
	var seen: Dictionary = {}
	for e in effects:
		var id: String = str(e.get("id", ""))
		if id.is_empty():
			continue
		seen[id] = true
		var badge: Control = row.get_node_or_null(id)
		if not is_instance_valid(badge):
			badge = StatusEffectBadgeScene.instantiate()
			badge.name = id
			row.add_child(badge)
		if badge.has_method("apply"):
			badge.call("apply", e)
	for child in row.get_children():
		if not seen.has(child.name):
			child.queue_free()


## Karakter panosunun ortasındaki madalyona seçili karakterin portresini
## koyar (bkz. characters.gd "portrait" alanı).
## Kullanıcı isteği (2026-09-24): "can ve kalkan barını da uyumlu şekilde yeniden tasarla" + "barlar hiç değişmemiş çok
## çirkinler" - yeni levha dokusu (tools/gen_ui_kit.py bar_frame: 48x22 sanat px, 2x = 96x44): sağdaki ENVANTER/altın
## levhalarıyla aynı parşömen dil, solda 40 px'lik ikon ucu, sağda 12 px'lik çivili uç, çubuk yuvası levhanın 12..32 px'i.
## hud.tscn'deki eski ölçüler (pay 30/10, 36 px çerçeve, 24 px çubuk) yerine burada koddan uygulanıyor - .tscn editörde
## açıkken kaydedilip ezilme riski olmasın. Levhalar avatar çerçevesinin (0..96) boyuna yerleşir: can 4..48, kalkan 52..96.
const BAR_FRAME_PATCH_LEFT := 40
const BAR_FRAME_PATCH_RIGHT := 12
const BAR_FRAME_HEIGHT := 44.0
const BAR_SLOT_TOP := 12.0 ## levha üstünden çubuk yuvasına (sanat satırı 6)
const BAR_SLOT_HEIGHT := 20.0
const BAR_FRAME_TOPS := [4.0, 52.0]
const BAR_VALUE_FONT_SIZE := 24
## Kullanıcı isteği (2026-09-25): "sol üstteki can kalkan barının dolma barlarının oval ve içlerinin çizgisiz olmasını
## istiyorum" - %10 çentikleri (_add_bar_ticks) kaldırıldı; dolgu uçları tam yuvarlak yeni doku (tools/simplify_hud_frames.py
## hud_bar_fill_round 32x20, esneme payı 10 px - değer azaldıkça sağ uç yuvarlak kalır). Zemin de aynı paya uygun geniş kopya.
const BAR_FILL_ROUND := preload("res://assets/ui/kit/hud_bar_fill_round.png")
const BAR_UNDER_WIDE := preload("res://assets/ui/kit/hud_bar_under_wide.png")
const BAR_ROUND_MARGIN := 10


func _layout_bar_kit() -> void:
	var cluster: Node = get_node_or_null("CharacterCluster")
	if cluster == null:
		return
	var sets := [["HealthBar", "HealthBarFrame", "HealthValueLabel"], ["ShieldBar", "ShieldBarFrame", "ShieldValueLabel"]]
	for i in sets.size():
		var names: Array = sets[i]
		var bar: Control = cluster.get_node_or_null(names[0]) as Control
		var frame: NinePatchRect = cluster.get_node_or_null(names[1]) as NinePatchRect
		var lbl: Label = cluster.get_node_or_null(names[2]) as Label
		if bar == null or frame == null:
			continue
		var top: float = BAR_FRAME_TOPS[i]
		frame.patch_margin_left = BAR_FRAME_PATCH_LEFT
		frame.patch_margin_right = BAR_FRAME_PATCH_RIGHT
		frame.patch_margin_top = 0
		frame.patch_margin_bottom = 0
		frame.offset_top = top
		frame.offset_bottom = top + BAR_FRAME_HEIGHT
		bar.offset_left = frame.offset_left + BAR_FRAME_PATCH_LEFT
		bar.offset_right = frame.offset_right - BAR_FRAME_PATCH_RIGHT
		bar.offset_top = top + BAR_SLOT_TOP
		bar.offset_bottom = bar.offset_top + BAR_SLOT_HEIGHT
		var tpb := bar as TextureProgressBar
		if tpb != null:
			## Dolgu TextureProgressBar'ın kendi "progress" dokusuyla ÇİZİLMEZ: gerçek oyun görüntüsünde ölçüldü (2026-09-25),
			## 9 parçalı esnetmede kısmi dolum dokuyu KIRPIYOR - sağ uç kare kalıyordu. Artık zemin (under) bar'ın kendisinde,
			## dolgu ise genişliği değere göre ayarlanan bir NinePatchRect (iki ucu HER ZAMAN yuvarlak) - bkz. _refresh_round_fill.
			tpb.texture_progress = null
			tpb.texture_under = BAR_UNDER_WIDE
			tpb.nine_patch_stretch = true
			tpb.stretch_margin_left = 2
			tpb.stretch_margin_right = 2
			tpb.stretch_margin_top = 0
			tpb.stretch_margin_bottom = 0
			tpb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if not tpb.has_node("RoundFill"):
				var fill := NinePatchRect.new()
				fill.name = "RoundFill"
				fill.texture = BAR_FILL_ROUND
				fill.patch_margin_left = BAR_ROUND_MARGIN
				fill.patch_margin_right = BAR_ROUND_MARGIN
				fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tpb.add_child(fill)
				tpb.value_changed.connect(func(_v: float) -> void: _refresh_round_fill(tpb))
				tpb.resized.connect(func() -> void: _refresh_round_fill(tpb))
			_refresh_round_fill(tpb)
		if lbl:
			lbl.offset_left = bar.offset_left
			lbl.offset_right = bar.offset_right
			lbl.offset_top = bar.offset_top - 4.0
			lbl.offset_bottom = bar.offset_bottom + 4.0
			lbl.add_theme_font_size_override("font_size", BAR_VALUE_FONT_SIZE)
			lbl.add_theme_constant_override("outline_size", 6)




func _setup_portrait() -> void:
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	if def.has("portrait"):
		var tex: Texture2D = load(def["portrait"])
		if tex:
			portrait.texture = tex
			_fit_portrait_pixel_perfect(tex)
	_add_portrait_backdrop()
	## Seviye rozeti artık parşömen içli (tools/gen_ui_kit.py level_badge) - rakam koyu kahve, kontursuz.
	level_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	level_label.add_theme_constant_override("outline_size", 0)


## Kullanıcı isteği (2026-09-24): HUD avatarı da menülerle aynı dile geçti - portre oyun dünyasının önünde değil, menü
## kartlarındaki gibi sıcak bir sahnenin (krem->bej degrade + çimen tümseği, tools/gen_ui_kit.py avatar_bg) önünde durur.
func _add_portrait_backdrop() -> void:
	var clip: Control = portrait.get_parent() as Control
	if clip == null or clip.has_node("PortraitBG"):
		return
	var bg := TextureRect.new()
	bg.name = "PortraitBG"
	bg.texture = UIKit.tex("hud_avatar_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(bg)
	clip.move_child(bg, 0)


## Portre eskiden 72x72 kutuyu "cover" ile dolduruyordu - 48 px'lik portrede 1.5x (eşit olmayan pikseller). Artık TAM SAYI
## kat: 48x48 portreler 2x (96 px, kutu figürün 6..42 satırlarını gösterir - baş/gövde), 64x64 (Oakley) 1x.
func _fit_portrait_pixel_perfect(tex: Texture2D) -> void:
	var clip_size := Vector2(72, 72)
	var k: float = 2.0 if tex.get_height() <= 48 else 1.0
	var draw_size: Vector2 = tex.get_size() * k
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pos: Vector2 = ((clip_size - draw_size) * 0.5).floor()
	portrait.offset_left = pos.x
	portrait.offset_top = pos.y
	portrait.offset_right = pos.x + draw_size.x
	portrait.offset_bottom = pos.y + draw_size.y


## DÜZELTME (kullanıcı isteği: "multiplayerda canların takım canı değil
## kişisel olmasını istiyorum") - multiplayer'da başlangıç değeri artık
## paylaşılan GameManager.revives_remaining DEĞİL, bu istemcinin KENDİ
## peer_id'sine ait GameManager.get_peer_revives() - revives_updated sinyali
## zaten (bkz. network_manager.gd sync_revive_consumed) SADECE kendi hakkımız
## değişince tetikleniyor, bu yüzden abone olma kısmı değişmedi.
func _setup_revive_display() -> void:
	if revive_hearts and revive_hearts.has_method("set_revives"):
		var initial: int = GameManager.get_peer_revives(multiplayer.get_unique_id()) if NetworkManager.is_multiplayer_active else GameManager.revives_remaining
		revive_hearts.set_revives(initial)
		GameManager.revives_updated.connect(revive_hearts.set_revives)


## Kullanıcı isteği: "Dükkanı açınca sağında stat penceresinin de açılmasını
## istiyorum" - dükkan HANGİ yoldan açılırsa açılsın (altın göstergesine
## tıklama YA DA main.gd'nin periyodik dükkan molası, bkz. main.gd
## _show_mini_shop_screen) aynı eşleşmeyi garanti eden TEK, paylaşılan
## fonksiyon çifti (open/close_shop_panel).
func open_shop_panel() -> void:
	## bkz. GameManager.SHOP_ENABLED üstündeki kullanıcı isteği notu - dükkan
	## şu an SADECE bu bayrakla (bkz. is_mini_shop_cooldown_ready, periyodik
	## akışın karar kaynağı) devre dışı değil, buradaki manuel açılış yolu
	## (altın göstergesine tıklama, bkz. _on_shop_toggle) da AYNI bayrağa
	## bağlı - "dükkan asla açılmayacak" hiçbir yoldan.
	if not GameManager.SHOP_ENABLED:
		return
	shop_panel.visible = true
	_position_shop_and_stats_panels()
	stats_panel_instance.visible = true


func close_shop_panel() -> void:
	shop_panel.visible = false
	stats_panel_instance.visible = false
	## Dükkanla eşleşince %30 küçültülen ölçek (bkz. _position_shop_and_
	## stats_panels) SADECE dükkan açıkken geçerli - kapanınca sıfırlanıyor,
	## yoksa istatistik paneli sonradan ENVANTER düğmesiyle (bkz.
	## _on_envanter_toggle, bu ölçeği hiç yönetmiyor) açıldığında da küçük
	## kalırdı.
	stats_panel_instance.scale = Vector2.ONE
	## X butonu dışında (ör. burada, altın göstergesine tekrar tıklanınca)
	## kapatılan durumlarda da dinleyenler (bkz. main.gd periyodik dükkan
	## molası) haberdar olsun diye - shop_panel.gd _on_close_pressed'daki
	## AYNI sinyal, TEK kaynaktan (idempotent, sadece görünürken anlamlı).
	if shop_panel.has_signal("closed"):
		shop_panel.closed.emit()


## DÜZELTME (kullanıcı bildirimi: "3 dakikada bir açılan dükkanda panel ve
## stat paneli birbiriyle çakışıyor. Yan yana durmaları için dükkan panelini
## biraz sola çekip sağına da stat panelini sığdır") - kök neden: bu fonksiyon
## eskiden shop_panel'in KENDİ KENDİNE zaten ortalanmış olduğunu varsayıyordu
## (bkz. eski yorum: "shop_panel_anim.gd open_shop() zaten HER açılışta
## paneli yeniden ortalıyor"), ama o ortalama hiçbir yerden ÇAĞRILMIYORDU
## (shop_panel_anim.gd'nin open_shop() fonksiyonu tüm kod tabanında hiç
## kullanılmayan ölü kod - sadece close_shop() gerçekten çağrılıyordu).
## Yani dükkan paneli güvenilmez/eski bir konumda kalıyor, istatistik paneli
## de onun sağına yerleştirilmeye çalışılınca (özellikle dar ekranlarda)
## üst üste biniyordu. Artık İKİSİ BİRLİKTE, tek bir çift olarak viewport'ta
## ortalanıyor - dükkan solda, istatistik hemen sağında, aralarında sabit
## bir boşluk; panel sürüklenebilir olsa da (bkz. window_drag_handler.gd)
## her açılışta bu çift-düzen yeniden kuruluyor.
## DÜZELTME (kullanıcı isteği: "Dükkan penceresi açılınca bir iteme
## tıkladığımızda item arayüzü açılıyor ama arayüzler çok büyük olduğu için
## hem istatistik hem dükkan v.s ekrana sığmıyor. bu yüzden dükkanı biraz
## sağa doğru kaydırıp statlar penceresini %30 daralt.") - kök neden: bu
## fonksiyon şimdiye kadar dükkanın "item arayüzünü" (bir satıra tıklanınca
## açılan satın-alma önizleme paneli, bkz. shop_panel.gd/tscn PreviewPanel -
## shop_panel'in kendi SOLUNA, offset_left=-316 ile taşıyor) HİÇ hesaba
## katmıyordu, sadece Frame'in kendi genişliğini (shop_panel.size) biliyordu
## - çift (dükkan+stat) ortalanırken PreviewPanel ekranın SOLUNA taşabiliyordu.
## Artık PREVIEW_PANEL_WIDTH bu hesaba dahil, üçü (önizleme+dükkan+istatistik)
## TEK bir blok olarak ortalanıyor - dükkan bu sayede otomatik olarak biraz
## SAĞA kayıyor (önizleme paneline yer açılıyor). İstatistik paneli de
## STATS_PANEL_SCALE ile %30 küçültülüyor - "scale" kullanılıyor ki içindeki
## TÜM ikon/etiketler TEK bir oranla küçülsün, hiçbir iç layout kırılmasın/
## taşmasın (bkz. close_shop_panel/_on_shop_closed - kapanınca 1.0'a
## sıfırlanıyor, yoksa ENVANTER düğmesiyle açılan AYRI gösterim de küçük
## kalırdı).
const PREVIEW_PANEL_WIDTH := 316.0
const STATS_PANEL_SCALE := 0.7

func _position_shop_and_stats_panels() -> void:
	if not stats_panel_instance or not is_instance_valid(stats_panel_instance):
		return
	const GAP := 20.0
	stats_panel_instance.scale = Vector2(STATS_PANEL_SCALE, STATS_PANEL_SCALE)
	var vp_size: Vector2 = shop_panel.get_viewport_rect().size
	var shop_size: Vector2 = shop_panel.size
	var stats_size: Vector2 = stats_panel_instance.size * STATS_PANEL_SCALE
	var total_width: float = PREVIEW_PANEL_WIDTH + shop_size.x + GAP + stats_size.x
	## Dar ekranlarda (ör. 1280x720) blok viewport'tan geniş olabilir - sola
	## taşmasın diye en fazla 0'a kadar sıkıştır (üst üste binmek yerine sağa
	## taşması, tamamen ekran dışına/sola taşmasından daha az kötü).
	var span_start_x: float = max(0.0, (vp_size.x - total_width) * 0.5)
	shop_panel.global_position = Vector2(span_start_x + PREVIEW_PANEL_WIDTH, (vp_size.y - shop_size.y) * 0.5)
	var stats_y: float = shop_panel.global_position.y + (shop_size.y - stats_size.y) * 0.5
	stats_panel_instance.global_position = Vector2(
		shop_panel.global_position.x + shop_size.x + GAP,
		clamp(stats_y, 0.0, max(0.0, vp_size.y - stats_size.y))
	)


## bkz. yukarısı - dükkan panelinin KENDİ X butonuyla (shop_panel.gd
## _on_close_pressed -> "closed") kapanması, close_shop_panel() ÇAĞRILMADAN
## gerçekleşiyor, bu yüzden eşleşen istatistik panelini kapatmak için ayrıca
## dinleniyor.
func _on_shop_closed() -> void:
	shop_panel.visible = false
	stats_panel_instance.visible = false
	stats_panel_instance.scale = Vector2.ONE


func _on_shop_toggle() -> void:
	if shop_panel.visible:
		close_shop_panel()
	else:
		open_shop_panel()


## Kullanıcı isteği: "dükkan butonunu silip altın göstergesine tıklandığında
## dükkan açılsın" - altın göstergesi (PanelContainer, Button değil) bu
## yüzden tıklamayı kendi gui_input sinyalinden yakalıyor.
func _on_gold_indicator_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_shop_toggle()


func _on_gold_indicator_mouse_entered() -> void:
	if _gold_indicator_hover_style:
		gold_indicator.add_theme_stylebox_override("panel", _gold_indicator_hover_style)


func _on_gold_indicator_mouse_exited() -> void:
	if _gold_indicator_normal_style:
		gold_indicator.add_theme_stylebox_override("panel", _gold_indicator_normal_style)


## Tek bir ENVANTER butonu istatistik panelini VE yeni envanter (silah/altın/
## tecrübe) panelini birlikte açıp kapatıyor - referans görselde ikisi yan
## yana gösterildiği için (bkz. inventory_panel.gd üstündeki not).
func _on_envanter_toggle() -> void:
	var now_visible: bool = not inventory_panel_instance.visible
	inventory_panel_instance.visible = now_visible
	stats_panel_instance.visible = now_visible


## Envanter panelindeki X'e basılınca (inventory_panel.gd "closed" sinyali)
## eşleştiği istatistik panelini de birlikte kapatır.
func _on_envanter_closed() -> void:
	stats_panel_instance.visible = false


## Oval dolgu: bar'ın oranı kadar genişlikte, iki ucu yuvarlak NinePatchRect; rengi bar'ın tint_progress'i (bkz. _layout_bar_kit).
func _refresh_round_fill(bar: TextureProgressBar) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	var fill: NinePatchRect = bar.get_node_or_null("RoundFill") as NinePatchRect
	if fill == null:
		return
	var span: float = bar.max_value - bar.min_value
	var ratio: float = clampf((bar.value - bar.min_value) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var w: float = roundf(bar.size.x * ratio / 2.0) * 2.0 ## 2 px ızgara (sanat pikseli x2)
	fill.visible = w >= 2.0
	fill.position = Vector2.ZERO
	## Çok kısa dolumda iki yuvarlak uç birbirine girmesin: en az iki uç payı kadar genişlikte çizilir, dikeyde küçülür.
	var min_w: float = float(BAR_ROUND_MARGIN * 2)
	fill.size = Vector2(maxf(w, min_w), bar.size.y)
	fill.scale = Vector2(w / min_w, w / min_w) if w < min_w else Vector2.ONE
	if w < min_w:
		fill.position = Vector2(0.0, bar.size.y * (1.0 - fill.scale.y) * 0.5)
	fill.modulate = bar.tint_progress


func update_health(current: float, max_value: float) -> void:
	health_bar.max_value = max(max_value, 0.001)
	health_bar.value = current
	health_value_label.text = "%d/%d" % [int(round(max(current, 0.0))), int(round(max_value))]
	
	# Şirin retro piksel renk geçişi (Emerald Green'den Crimson Red'e)
	var pct: float = clamp(current / max(max_value, 1.0), 0.0, 1.0)
	## 2026-09-24 bar yeniden tasarımı: parşömen levhada daha canlı piksel yeşili -> kırmızı (dolgu dokusu düz beyaz, ton burada).
	var health_color: Color = Color(0.84, 0.22, 0.22).lerp(Color(0.36, 0.78, 0.29), pct)
	health_bar.tint_progress = health_color
	_refresh_round_fill(health_bar)
	if dock_hp_bar:
		dock_hp_bar.call("set_values", pct, health_color, health_value_label.text)


## main.gd hâlâ bu sinyale bağlanıyor (player.xp_changed) - HUD'da artık
## ayrı bir XP çubuğu yok (bkz. Envanter paneli - tecrübe miktarı orada
## gösteriliyor), o yüzden burada bilerek hiçbir şey yapmıyor.
## #49 DÜZELTME (kullanıcı bildirimi: "Alttaki EXP barı hiç görünmüyor") -
## eskiden bu fonksiyon boş bir "pass" idi (muhtemelen HUD yeniden
## tasarlanırken - bkz. CharacterCluster/SkillBar geçişi - eski bar
## kaldırılmış ama yenisi hiç eklenmemişti). Artık scenes/hud.tscn'in
## sonundaki gerçek "XPBar" (ProgressBar) node'unu güncelliyor.
func update_xp(current: float, needed: float) -> void:
	if not xp_bar:
		return
	if xp_bar.has_method("set_xp"):
		xp_bar.set_xp(current, needed)


func update_level(level: int) -> void:
	level_label.text = str(level)
	## 3 haneli seviyelerde rozetin içine sığması için yazıyı bir kademe küçült (m5x7: 16 = 1x, 32 = 2x).
	level_label.add_theme_font_size_override("font_size", 32 if level < 100 else 16)


## main.gd hâlâ bu fonksiyonu çağırıyor - HUD'da artık ayrı bir "hızlı
## bakış" stat yazısı yok, o yüzden bilerek hiçbir şey yapmıyor.
func update_stats(_speed: float, _damage: float, _fire_rate: float, _crit_chance: float, _crit_damage: float) -> void:
	pass


func _on_item_shield_changed(current: float, max_value: float) -> void:
	## (2026-09-27: görünen kalkan çubuğu artık oyuncu panelindeki dock_shield_bar - eski levha gizli ama güncel tutulur.)
	item_shield_bar.max_value = max(max_value, 0.001)
	item_shield_bar.value = current
	item_shield_bar.tint_progress = Color(0.24, 0.59, 0.91)
	_refresh_round_fill(item_shield_bar)
	if max_value > 0:
		shield_value_label.text = "%d/%d" % [int(round(max(current, 0.0))), int(round(max_value))]
	if dock_shield_bar:
		var sh_ratio: float = clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
		dock_shield_bar.call("set_values", sh_ratio, SHIELD_BAR_COLOR, shield_value_label.text)


## Kullanıcı isteği: "oyuna chat ekle, enter tuşuna basarak mesaj
## yazabiliriz" - kutu KAPALIYKEN Enter'a basmak burayı tetikleyip kutuyu
## açar. Kutu zaten AÇIKKEN (odaktayken) Enter'a basmak bu fonksiyona hiç
## ULAŞMAZ - odaklı bir LineEdit tuşu önce kendi _gui_input'unda işleyip
## "handled" işaretler (bkz. _on_chat_input_submitted, LineEdit'in kendi
## text_submitted sinyaline bağlı), yani iki taraf asla çakışmaz.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat") and _chat_input and not _chat_input.visible:
		_open_chat_input()
		get_viewport().set_input_as_handled()


## ==============================================================================
## CHAT (kullanıcı isteği: "oyuna chat ekle, enter tuşuna basarak mesaj
## yazabiliriz solda chat penceresi olacak ve karakterler konuşunca
## üstlerinde mini chat balonu çıkacak")
## ==============================================================================
## Ekranda GÖRÜNEN kısım (sol alttaki log + yazı kutusu) burada, hud.gd'de.
## Karakterin üstündeki balon AYRI bir sistem (bkz. scripts/chat_bubble.gd) -
## ağ senkronu network_manager.gd'nin chat_message_received sinyaliyle
## (main.gd _on_chat_message_received bu sinyali dinleyip hem burayı hem
## doğru karakterin balonunu güncelliyor) yapılıyor, bkz. o dosyalardaki
## notlar.
const CHAT_MAX_LOG_ENTRIES := 50

var _chat_layer: CanvasLayer = null
var _chat_log: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_input: LineEdit = null


func _create_chat_ui() -> void:
	_chat_layer = CanvasLayer.new()
	_chat_layer.name = "ChatLayer"
	_chat_layer.layer = 40 ## HUD'un üstünde, modal ekranların (90+) altında
	add_child(_chat_layer)

	var panel := Control.new()
	panel.name = "ChatPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 20.0
	panel.offset_right = 400.0
	panel.offset_top = -256.0
	panel.offset_bottom = -20.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_layer.add_child(panel)

	_chat_scroll = ScrollContainer.new()
	_chat_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chat_scroll.offset_bottom = -38.0
	_chat_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_chat_scroll)

	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.add_theme_constant_override("separation", 2)
	_chat_scroll.add_child(_chat_log)

	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_chat_input.offset_top = -34.0
	_chat_input.placeholder_text = "Mesaj yazmak için Enter'a bas..."
	_chat_input.max_length = 200
	_chat_input.visible = false
	## 2026-09-24: oyun içi bej kit (menülerle aynı dil) - bej çukur giriş kutusu + koyu yazı. (Eski koyu yarı saydam kutu,
	## genel temadaki giriş yazısı koyulaşınca okunmaz olurdu.) 16 px = m5x7 2x, mesaj satırlarıyla uyumlu.
	_chat_input.theme = UIKit.theme()
	_chat_input.add_theme_stylebox_override("normal", UIKit.panel_style("inset_tight"))
	_chat_input.add_theme_font_size_override("font_size", 16)
	_chat_input.text_submitted.connect(_on_chat_input_submitted)
	_chat_input.focus_exited.connect(_close_chat_input)
	panel.add_child(_chat_input)


func _open_chat_input() -> void:
	if not _chat_input:
		return
	_chat_input.visible = true
	_chat_input.text = ""
	_chat_input.grab_focus()
	if is_instance_valid(player) and "is_chat_typing" in player:
		player.is_chat_typing = true


## LineEdit'in KENDİ text_submitted sinyali (Enter'a basınca) - boş metinle
## gönderim, mesaj atmadan kutuyu kapatan bir "iptal" yolu olarak kullanılır.
func _on_chat_input_submitted(text: String) -> void:
	_close_chat_input()
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return
	## Debug modu (kullanıcı isteği: chate "baykusseverim" yazılınca debug butonu belirsin) -
	## GERÇEK bir sohbet mesajı olarak GÖNDERİLMİYOR (bkz. aşağıdaki return), sadece bu
	## istemcide bir komut olarak tüketiliyor - bkz. GameManager.debug_mode_unlocked notu.
	if trimmed.to_lower() == "baykusseverim":
		_unlock_debug_mode()
		return
	_send_chat_message(trimmed)


func _close_chat_input() -> void:
	if not _chat_input:
		return
	_chat_input.visible = false
	_chat_input.text = ""
	if is_instance_valid(player) and "is_chat_typing" in player:
		player.is_chat_typing = false


## DÜZELTME: sync_match_stats ile AYNI desen (bkz. network_manager.gd
## broadcast_chat_message notu) - "call_local" RPC'ler multiplayer'da
## gönderenin KENDİ mesajını da chat_message_received sinyalinden almasını
## sağlar, ayrı bir "yerel yankı" kodu gerekmez. Tek oyunculuda RPC hiç
## çağrılmaz (peer yok) - fonksiyon DOĞRUDAN (ağsız) çağrılıp AYNI sinyali
## yerel olarak tetikler.
func _send_chat_message(text: String) -> void:
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_chat_message.rpc(multiplayer.get_unique_id(), NetworkManager.local_player_name, text)
	else:
		NetworkManager.broadcast_chat_message(0, NetworkManager.local_player_name, text)


## ===================================================================================
## Debug modu (bkz. GameManager.debug_mode_unlocked notu / scripts/debug_menu.gd dosya başı
## notu) - chate "baykusseverim" (bkz. _on_chat_input_submitted) YA DA ana menüden "Debug
## Modu" (bkz. main_menu.gd) ile açılır. Buton kalıcı olarak KURULUR ama debug_mode_unlocked
## true olana kadar GİZLİ kalır - main_menu.gd'den gelen otomatik açılış zaten bu bayrağı
## sahne yüklenmeden önce true yapıyor, o yüzden burada sadece MEVCUT durumu okumak yeterli.
const DebugMenuScript := preload("res://scripts/debug_menu.gd")
var _debug_button: Button = null
var _debug_menu: Control = null

func _setup_debug_mode() -> void:
	_debug_menu = Control.new()
	_debug_menu.name = "DebugMenu"
	_debug_menu.set_script(DebugMenuScript)
	add_child(_debug_menu)

	_debug_button = Button.new()
	_debug_button.name = "DebugButton"
	_debug_button.text = "DEBUG"
	_debug_button.top_level = true ## bkz. world_event_banner.gd AYNI "CanvasLayer altında anchor güvenilmez" notu
	_debug_button.custom_minimum_size = Vector2(90, 36)
	_debug_button.visible = GameManager.debug_mode_unlocked
	_debug_button.pressed.connect(func() -> void: _debug_menu.call("toggle"))
	add_child(_debug_button)
	_position_debug_button()


func _position_debug_button() -> void:
	if not _debug_button:
		return
	## 2026-09-25: sağ sütun artık minimap + grup paneli - DEBUG butonu SOL sütunda, altın göstergesinin altında
	## (sol kenara hizalı - eski sağ kenar hizası için gereken gerçek genişlik/viewport hesabı artık yok).
	var below_y: float = 330.0
	if gold_indicator and gold_indicator.visible:
		below_y = gold_indicator.get_global_rect().end.y + 10.0
	var left_x: float = gold_indicator.get_global_rect().position.x if gold_indicator else 20.0
	_debug_button.position = Vector2(left_x, below_y)


func _unlock_debug_mode() -> void:
	GameManager.debug_mode_unlocked = true
	if _debug_button:
		_debug_button.visible = true


## main.gd _on_chat_message_received tarafından (hem yerel yankı hem uzak
## oyunculardan gelen mesajlar için) çağrılır.
func append_chat_message(sender_name: String, text: String) -> void:
	if not _chat_log:
		return
	var line := Label.new()
	line.text = "%s: %s" % [sender_name, text]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 18)
	line.add_theme_color_override("font_color", Color(0.93, 0.9, 0.85, 1.0))
	line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	line.add_theme_constant_override("shadow_offset_x", 1)
	line.add_theme_constant_override("shadow_offset_y", 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.add_child(line)
	while _chat_log.get_child_count() > CHAT_MAX_LOG_ENTRIES:
		var oldest: Node = _chat_log.get_child(0)
		_chat_log.remove_child(oldest)
		oldest.queue_free()
	## ScrollContainer içeriği büyüdükten SONRA (bir kare beklenmeden) en alta
	## kaydırmaya çalışırsa henüz eski content_height'a göre kaydırır - bkz.
	## Godot'un genel "layout bir kare sonra oturur" davranışı.
	await get_tree().process_frame
	if _chat_scroll and is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


var _shop_refresh_timer: float = 0.0


func _process(delta: float) -> void:
	## Altın göstergesi artık HER ZAMAN görünür (bkz. kullanıcı isteği: sağ
	## üstteki DÜKKAN/ENVANTER buton yığınının hemen altında, dükkan
	## açık/kapalı farketmeksizin) - sadece metni her karede güncelleniyor.
	## Ödül altınları (sandık/görev/boss payı) panele uçarken sayaç yoldakileri saymaz, paralar vardıkça tıkır tıkır
	## yükselir (bkz. gold_reward_fx.gd).
	gold_indicator_label.text = str(GoldRewardFx.display_gold())
	_position_debug_button()
	fps_label.visible = UISound.show_fps
	if UISound.show_fps:
		_fps_update_timer += delta
		if _fps_update_timer >= 0.2:
			_fps_update_timer = 0.0
			fps_label.text = _mobile_perf_text() if MobileUIScript.enabled else "FPS: %d" % Engine.get_frames_per_second()
			## Yaratık yeniden yazımı: yeni yol (C++ EnemyWorld) GERÇEKTEN çalışıyorsa belli olsun (anahtar kapalıyken metin aynı)
			if get_tree().current_scene and get_tree().current_scene.get_node_or_null("EnemyWorldBridge") != null:
				fps_label.text += " | C++ yaratık"
	_update_status_bar()
	if is_instance_valid(hearts_tab) and revive_hearts and revive_hearts.has_method("is_regen_visible") \
			and bool(revive_hearts.is_regen_visible()) != _hearts_tab_wide:
		_layout_player_dock()
	_shop_refresh_timer += delta
	if _shop_refresh_timer > 0.4:
		_shop_refresh_timer = 0.0
		if shop_panel.has_method("_refresh"):
			shop_panel._refresh()

	if player and is_instance_valid(player) and player.has_method("get_skill_progress"):
		## Yetenek yuvası kilidi (bkz. player.gd is_skill_slot_unlocked / skill_icon.gd set_locked_level).
		if player.has_method("is_skill_slot_unlocked"):
			var slot_icons: Array = [["skill", skill_icon], ["skill2", skill2_icon], ["skill3", skill3_icon]]
			for pair in slot_icons:
				var ic: Node = pair[1]
				if ic and is_instance_valid(ic) and ic.has_method("set_locked_level"):
					ic.set_locked_level(0 if player.is_skill_slot_unlocked(pair[0]) else player.get_skill_slot_unlock_level(pair[0]))
				## Yetenek evrimi boncukları (2026-09-28, skill_icon.gd set_evolution_progress) - final ancak diğerlerinden
				## sonra alınabildiği için "hepsi alındı" = final de alındı.
				if ic and is_instance_valid(ic) and ic.has_method("set_evolution_progress") and player.has_method("get_evolution_progress"):
					var evo_prog: Vector2i = player.get_evolution_progress(pair[0])
					ic.set_evolution_progress(evo_prog.x, evo_prog.y, evo_prog.y > 0 and evo_prog.x >= evo_prog.y)
		## Form hâli (Shaman Elemental Golem: Q = Sarsıcı Darbe) - ikon/ad/açıklama/bekleme karakterin kendi sayacından.
		var q_override: Dictionary = player.get_hud_skill_override("skill") if player.has_method("get_hud_skill_override") else {}
		_apply_hud_skill_override(skill_icon, q_override, "skill")
		## Shaman Q (Saldırı Totemi) yük sistemi (2026-09-30): yük varken hazır, yoksa sıradaki yükün dolumu + boncuklar
		## (Korsan/Assasin E'siyle aynı set_charges görünümü). Golem formunda (q_override) boncuklar gizli.
		var q_charges: Dictionary = player.get_shaman_q_charge_state() if q_override.is_empty() and player.has_method("get_shaman_q_charge_state") else {}
		## Assasin Çocuk Q = Şahin Hamlesi (2026-09-30 Q/E değişimiyle E ikonundan buraya) - aynı yük sözlüğü.
		if q_charges.is_empty() and q_override.is_empty() and player.has_method("get_assasin_dash_charge_state"):
			q_charges = player.get_assasin_dash_charge_state()
		if not q_override.is_empty():
			skill_icon.update_state(float(q_override["progress"]), false, float(q_override["remaining"]), 0.0)
		elif not q_charges.is_empty():
			var has_charge: bool = int(q_charges["charges"]) > 0
			skill_icon.update_state(1.0 if has_charge else float(q_charges["fraction"]), false, 0.0 if has_charge else float(q_charges["remaining"]), 0.0)
		else:
			skill_icon.update_state(player.get_skill_progress(), player.is_skill_active(), player.skill_timer, player.get_skill_active_fraction())
		if skill_icon.has_method("set_charges"):
			if q_charges.is_empty():
				skill_icon.set_charges(-1, 0, 0.0)
			else:
				skill_icon.set_charges(int(q_charges["charges"]), int(q_charges["max"]), float(q_charges["fraction"]))
		if skill2_icon.visible and player.has_method("get_skill2_progress"):
			## Büyücü Kız'ın TEMEL yeteneği artık 4 varyasyonlu ve standart
			## skill2_state/skill2_timer makinesini KULLANMIYOR (bkz. player.gd
			## _buyucu_try_activate_variation/_buyucu_variation_cooldowns) -
			## ikon her karede o anki varyasyonun kendi bekleme sayacını,
			## simge kimliğini, adını ve açıklamasını göstersin diye ayrı bir
			## dalda güncelleniyor. Diğer tüm karakterlerde override'lar
			## boşaltılıp eski davranış aynen kullanılıyor.
			var e_override: Dictionary = player.get_hud_skill_override("skill2") if player.has_method("get_hud_skill_override") else {}
			_apply_hud_skill_override(skill2_icon, e_override, "skill2")
			if not e_override.is_empty():
				skill2_icon.update_state(float(e_override["progress"]), false, float(e_override["remaining"]), 0.0)
			elif GameManager.selected_char_id == 4 and player.has_method("get_buyucu_variation_cooldown_remaining"):
				skill2_icon.skill_id = player.get_skill2_id()
				skill2_icon.name_override = player.get_buyucu_variation_name()
				skill2_icon.desc_override = player.get_buyucu_variation_desc()
				var v_idx: int = player.buyucu_variation if "buyucu_variation" in player else 0
				var v_icons: Array = Characters.get_def(4).get("skill2_variation_icons", [])
				if v_idx >= 0 and v_idx < v_icons.size():
					var v_tex: Texture2D = _cached_texture(v_icons[v_idx])
					if v_tex:
						skill2_icon.custom_texture = v_tex
				skill2_icon.update_state(player.get_skill2_progress(), player.is_skill2_active(), player.get_buyucu_variation_cooldown_remaining(), player.get_skill2_active_fraction())
			else:
				skill2_icon.name_override = ""
				skill2_icon.desc_override = ""
				skill2_icon.update_state(player.get_skill2_progress(), player.is_skill2_active(), player.skill2_timer, player.get_skill2_active_fraction())
		## Korsan'ın bomba şarj sayısı (TEMEL/skill2 ikonunun üstünde) ve
		## Necromancer'ın biriken ruh sayısı (pasif ikonunun üstünde) -
		## standart bekleme-süresi modeline uymayan yetenekler için özel bir
		## sayısal rozet (bkz. skill_icon.gd set_stack_count).
		## 2026-09-26: yük göstergesi artık sayı rozeti değil, maksimum yük kadar piksel boncuk (skill_icon.gd set_charges).
		if skill2_icon.has_method("set_charges"):
			skill2_icon.set_stack_count(-1) ## eski sayı rozeti bu yuvada artık kullanılmıyor
			if "korsan_bomb_charges" in player and player.get_skill2_id() == 17:
				skill2_icon.set_charges(player.korsan_bomb_charges, player.get_korsan_max_bomb_charges(), player.get_korsan_bomb_charge_fraction()) ## evrimle 3 -> 5
			## (Assasin Çocuk'un Şahin Hamlesi yük boncukları 2026-09-30'dan beri Q ikonunda - bkz. yukarıdaki q_charges.)
			else:
				skill2_icon.set_charges(-1, 0, 0.0)
		if passive_icon.has_method("set_stack_count"):
			## DÜZELTME (kullanıcı bildirimi: "Necromancer ölen düşmanlardan
			## ruh toplayamıyor" araştırması sırasında bulunan İKİNCİ bir
			## kurbanı - bkz. player.gd on_enemy_killed()'taki AYNI düzeltme
			## notu): burası da Golem'in eski Q/skill id'sine (20) göre
			## dallanıyordu, Golem R'ye taşınınca (Q artık İskelet, id 19)
			## ruh rozeti hiç gösterilmez olmuştu. Roster id'sine (11) göre.
			if player.has_method("get_necro_souls") and GameManager.selected_char_id == 11:
				passive_icon.set_stack_count(player.get_necro_souls())
			else:
				passive_icon.set_stack_count(-1)
		## Üçüncü aktif yetenek (bkz. _create_skill3_icon) - skill/skill2 ile
		## AYNI standart bekleme-süresi güncellemesi. DÜZELTME (Büyücü Kız
		## rework): R artık Hortum/Meteor Patlaması'nın 2'li seti - skill2_
		## icon'un yukarısındaki AYNI özel-durum deseni burada da tekrarlanıyor
		## (bkz. o bloktaki yorum), yoksa R ikonu HER ZAMAN aynı sabit ikonu/
		## adı gösterirdi, set değiştiğinde güncellenmezdi.
		if skill3_icon and skill3_icon.visible and player.has_method("get_skill3_progress"):
			if GameManager.selected_char_id == 4 and player.has_method("get_buyucu_variation_cooldown_remaining_r"):
				skill3_icon.skill_id = player.get_skill3_id()
				skill3_icon.name_override = player.get_buyucu_variation_name_r()
				skill3_icon.desc_override = player.get_buyucu_variation_desc_r()
				var v_idx_r: int = player.BUYUCU_SET_R_VARIATIONS[player.buyucu_variation_set] if "buyucu_variation_set" in player else 2
				## Şu an sadece "Hortum, Meteor Patlaması" için 2 ikon var (bkz.
				## characters.gd "skill3_variation_icons"), index'i bu diziye
				## eşlemek için R'nin varyasyon index'ini (2/3) 0/1'e kaydır.
				var v_icons_r: Array = Characters.get_def(4).get("skill3_variation_icons", [])
				var v_local_idx_r: int = v_idx_r - 2
				if v_local_idx_r >= 0 and v_local_idx_r < v_icons_r.size():
					var v_tex_r: Texture2D = _cached_texture(v_icons_r[v_local_idx_r])
					if v_tex_r:
						skill3_icon.custom_texture = v_tex_r
				skill3_icon.update_state(player.get_skill3_progress(), player.is_skill3_active(), player.get_buyucu_variation_cooldown_remaining_r(), player.get_skill3_active_fraction())
			else:
				skill3_icon.name_override = ""
				skill3_icon.desc_override = ""
				skill3_icon.update_state(player.get_skill3_progress(), player.is_skill3_active(), player.skill3_timer, player.get_skill3_active_fraction())
		## Ruhani Yetenek ikonu (F) - kendi durum makinesi (bkz. player.gd get_spirit_*).
		if spirit_icon and player.has_method("get_spirit_progress"):
			_place_spirit_icon()
			spirit_icon.update_state(player.get_spirit_progress(), player.is_spirit_active(), player.get_spirit_cooldown_remaining(), player.get_spirit_active_fraction())
