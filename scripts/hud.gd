extends CanvasLayer

## Alt orta bar eskiden sahip olunan silahların ikonlarını gösteriyordu -
## kullanıcı isteğiyle artık SAVAŞ MODLARI (Meditasyon/Yansıtma/Kırılmaz
## İrade/Cinnet/Çeviklik/Teknik Savaş/Savunma - eski adlarıyla Metanet/
## Dikenli/Kaplumbağa/Agresif/Şimşek Hız/Delicilik/Tank, bkz. MODE_KEYS'in
## anahtar sırası) için kullanılıyor: tıklanarak ya da 1-2-3-4-5
## kısayollarıyla aktif mod seçilebiliyor (bkz. _refresh_shield_
## mode_slots/_unhandled_input). Silah ikonları hâlâ Envanter panelinde
## (inventory_panel.gd) görülebiliyor, sadece bu bardan kaldırıldı.
## Sabit sıra - en fazla 5 slot olduğu için 7 moddan SAHİP OLUNAN ilk 5'i
## (bu sırayla) gösterilir.
const MODE_KEYS := ["resilience", "thorny", "turtle", "aggressive", "lightning", "piercing", "tank"]
## Kullanıcı isteği: "kalkan modlarının adı artık savaş modları ve
## görselleri bunlarla değiştirilecek" - eskiden burada tek bir vektörel
## kalkan ikonu MODE_TINTS ile mod başına renklendiriliyordu (bkz. eski
## shop_item_icon.gd "shield" çizimi), şimdi shop_panel.tscn'deki
## ModsPage satırlarıyla BİREBİR aynı gerçek görsel setinden gelen kendi
## texture'ı var, tint YOK (bkz. _refresh_shield_mode_slots).
const MODE_TEXTURES := {
	"resilience": preload("res://assets/ui/battle_modes/resilience.png"),
	"thorny": preload("res://assets/ui/battle_modes/thorny.png"),
	"turtle": preload("res://assets/ui/battle_modes/turtle.png"),
	"aggressive": preload("res://assets/ui/battle_modes/aggressive.png"),
	"lightning": preload("res://assets/ui/battle_modes/lightning.png"),
	"piercing": preload("res://assets/ui/battle_modes/piercing.png"),
	"tank": preload("res://assets/ui/battle_modes/tank.png"),
}

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
## Ruhani Yetenek butonu (F tuşu, bkz. spiritual_skills.gd/_create_spirit_icon) - 3. butonun sağında, diğer butonlar
## arasındaki boşlukla, biraz büyük ve farklı (mor-altın) çerçeve renginde.
## DÜZELTME (kullanıcı isteği 2026-09-22: "ruhani skillin boyutunu biraz ufalt") - eskiden %20 büyüktü (1.2051),
## artık %10 (1.10) - hâlâ diğerlerinden hafifçe ayırt edilebiliyor ama daha az baskın.
var spirit_icon = null
const SPIRIT_ICON_SCALE := 1.10
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
@onready var shop_toggle_button: Button = $ShopToggleButton
@onready var envanter_toggle_button: Button = $EnvanterToggleButton
@onready var stats_panel_instance = $StatsPanelInstance
@onready var inventory_panel_instance = $InventoryPanelInstance
## Kalkan modu slotları (bkz. yukarıdaki MODE_KEYS) - sırayla i. slot, o an
## sahip olunan modların (shield_mod_*_level > 0) i'incisini gösterir.
## DÜZELTME: "Savaş modları" barı (ShieldModeBarBG) sahneden tamamen
## silinmiş (BottomBar artık boş) ama bu dizi hâlâ sabit "$Path" ile onlara
## erişmeye çalışıyordu - node yoksa bu sabit erişim _ready()'yi FATAL
## şekilde patlatır (bkz. test hataları: "Node not found:
## BottomBar/ShieldModeBarBG/ShieldModeSlot1" sonrası HUD'un geri kalan
## @onready'leri de bozuluyordu). get_node_or_null'a çevrildi - node'lar
## dönerse (ileride bar geri eklenirse) davranış AYNI, yoksa dizi güvenle
## null içerir (aşağıdaki tüm kullanımlar zaten is_instance_valid kontrollü).
@onready var shield_mode_slots: Array = [
	get_node_or_null("BottomBar/ShieldModeBarBG/ShieldModeSlot1"),
	get_node_or_null("BottomBar/ShieldModeBarBG/ShieldModeSlot2"),
	get_node_or_null("BottomBar/ShieldModeBarBG/ShieldModeSlot3"),
	get_node_or_null("BottomBar/ShieldModeBarBG/ShieldModeSlot4"),
]
## 1-2-3-4-5 kısayolları (bkz. game_manager.gd _setup_input_actions) -
## sırayla shield_mode_slots'un aynı index'iyle eşleşir.
const SLOT_SHORTCUT_ACTIONS := [
	"shield_mode_slot_1", "shield_mode_slot_2", "shield_mode_slot_3",
	"shield_mode_slot_4",
]

## Savaş modları aniden art arda değiştirilemesin diye - kullanıcı isteği:
## "2sn bekleme süresi ekle değiştirmek için aniden değiştirilmesin". Bu süre
## boyunca hem tıklama hem 1-5 kısayolları görmezden gelinir (bkz.
## _on_shield_mode_slot_pressed) ve slotlar hafifçe solgunlaşıp devre dışı
## kalarak (bkz. _refresh_shield_mode_slots) bekleme durumunu belli eder.
const MODE_SWITCH_COOLDOWN := 2.0
var _mode_switch_cooldown_remaining: float = 0.0

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
	if passive_icon:
		passive_icon.frame_border = 4.0 ## küçük pasif çerçeve: 3 sanat pikseli kenar (bkz. skill_icon.gd frame_border)
	## DÜZELTME (kullanıcı isteği: "kategori butonları veya aşırı dar olan
	## butonlar için mini button dosyasını kullan") - kalkan modu slotları
	## (52x52, kare ikon butonları) custom_minimum_size YERİNE offset ile
	## boyutlandırıldığı için ui_sound.gd'nin _looks_like_icon_slot kontrolünü
	## atlayıp yukarıdaki genel taramadan GENİŞ (Button.png) stille çıkıyordu -
	## kare oldukları için burada KARE mini button.png stiliyle EZİLİYOR.
	for slot: Button in shield_mode_slots:
		if is_instance_valid(slot):
			ShopPanel._apply_mini_wood_button_style(slot)
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
	_setup_ability_icons()
	_setup_portrait()
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
	## DÜZELTME (kullanıcı isteği: "Savaş modlarını ve savaş modları için
	## skill panelinin aşağısına eklenen slotları oyundan kaldır. Bunları
	## kimse sevmedi.") - slot butonları artık kurulmuyor/bağlanmıyor, üstlerini
	## saran bar (ShieldModeBarBG - skill panelinin altındaki o 4 slotluk şerit)
	## kalıcı olarak gizleniyor (bkz. shop_panel.gd'deki "ProductionTab" ile
	## AYNI desen - dükkandaki "Modlar" sekmesi de aynı şekilde kalıcı olarak
	## gizlendi, bkz. o dosyadaki not). Node'lar sahneden SİLİNMEDİ, sadece
	## erişilemez/görünmez halde kalıyorlar.
	var shield_mode_bar: Control = get_node_or_null("BottomBar/ShieldModeBarBG") as Control
	if shield_mode_bar:
		shield_mode_bar.visible = false

	_create_chat_ui()

	## NOT: Eskiden dükkan açılınca DÜKKAN/ENVANTER butonları gizleniyordu -
	## kullanıcı artık bunu istemiyor (bkz. kullanıcı bildirimi: "dükkana
	## basınca dükkan/envanter butonu kapanmasın"), bu yüzden bu davranış
	## kaldırıldı; butonlar panel açıkken de görünür kalır (bkz. aşağıdaki
	## artık kullanılmayan _update_toggle_buttons_visibility notu).


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
	var right_edge: float = minimap.offset_right
	var top_y: float = minimap.offset_bottom + GAP

	# Envanter butonu en üstte (bkz. kullanıcı isteği - eskisi gibi).
	envanter_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	envanter_toggle_button.offset_right = right_edge
	envanter_toggle_button.offset_left = right_edge - btn_w
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
	gold_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gold_indicator.offset_right = right_edge
	gold_indicator.offset_left = right_edge - btn_w
	gold_indicator.offset_top = envanter_toggle_button.offset_bottom + GAP
	gold_indicator.offset_bottom = gold_indicator.offset_top + btn_h
	gold_indicator.visible = true

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
	_gold_indicator_normal_style = UIKit.panel_style("plaque")
	gold_indicator.add_theme_stylebox_override("panel", _gold_indicator_normal_style)
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
func _place_spirit_icon() -> void:
	if spirit_icon == null:
		return
	var left: float = SPIRIT_ICON_BASE_SIZE + SPIRIT_ICON_GAP ## Q'nun sağı
	if skill2_icon.visible:
		left = 2.0 * (SPIRIT_ICON_BASE_SIZE + SPIRIT_ICON_GAP)
	if skill3_icon and skill3_icon.visible:
		left = 3.0 * (SPIRIT_ICON_BASE_SIZE + SPIRIT_ICON_GAP)
	var width: float = SPIRIT_ICON_BASE_SIZE * SPIRIT_ICON_SCALE
	spirit_icon.offset_left = left
	spirit_icon.offset_right = left + width


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
	if not is_instance_valid(ability_bar_frame):
		return
	var bar: Control = ability_bar_frame.get_parent()
	if not bar:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for child in bar.get_children():
		if child == ability_bar_frame or not (child is Control):
			continue
		var c: Control = child
		if not c.visible:
			continue
		lo.x = minf(lo.x, c.offset_left)
		lo.y = minf(lo.y, c.offset_top)
		hi.x = maxf(hi.x, c.offset_right)
		hi.y = maxf(hi.y, c.offset_bottom)
	if lo.x == INF:
		ability_bar_frame.visible = false
		return
	ability_bar_frame.visible = true
	ability_bar_frame.offset_left = lo.x - ABILITY_BAR_FRAME_PAD
	ability_bar_frame.offset_top = lo.y - ABILITY_BAR_FRAME_PAD
	ability_bar_frame.offset_right = hi.x + ABILITY_BAR_FRAME_PAD
	ability_bar_frame.offset_bottom = hi.y + ABILITY_BAR_FRAME_PAD
	_update_status_bar_layout()


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
	buffs.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(buffs)
	status_buff_row = buffs

	var debuffs := HBoxContainer.new()
	debuffs.name = "DebuffRow"
	debuffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debuffs.add_theme_constant_override("separation", 4)
	debuffs.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(debuffs)
	status_debuff_row = debuffs


## StatusBar'ı (ve içindeki iki yarı) ability_bar_frame'in hemen üstüne, onunla AYNI genişlikte yerleştirir.
## Yükseklik status_effect_badge.tscn'in kendi boyuyla (HEIGHT, altındaki süre şeridi dahil) eşleşiyor.
const STATUS_ROW_HEIGHT := 42.0


func _update_status_bar_layout() -> void:
	if not is_instance_valid(status_bar) or not is_instance_valid(ability_bar_frame):
		return
	var w: float = ability_bar_frame.offset_right - ability_bar_frame.offset_left
	status_bar.offset_left = ability_bar_frame.offset_left
	status_bar.offset_right = ability_bar_frame.offset_right
	status_bar.offset_bottom = ability_bar_frame.offset_top - 6.0
	status_bar.offset_top = status_bar.offset_bottom - STATUS_ROW_HEIGHT
	if status_buff_row:
		status_buff_row.offset_left = 0.0
		status_buff_row.offset_right = w * 0.5
		status_buff_row.offset_top = 0.0
		status_buff_row.offset_bottom = STATUS_ROW_HEIGHT
	if status_debuff_row:
		status_debuff_row.offset_left = w * 0.5
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
func _setup_portrait() -> void:
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	if def.has("portrait"):
		var tex: Texture2D = load(def["portrait"])
		if tex:
			portrait.texture = tex


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


func update_health(current: float, max_value: float) -> void:
	health_bar.max_value = max(max_value, 0.001)
	health_bar.value = current
	health_value_label.text = "%d/%d" % [int(round(max(current, 0.0))), int(round(max_value))]
	
	# Şirin retro piksel renk geçişi (Emerald Green'den Crimson Red'e)
	var pct: float = clamp(current / max(max_value, 1.0), 0.0, 1.0)
	var health_color: Color = Color(0.76, 0.17, 0.25).lerp(Color(0.24, 0.73, 0.42), pct)
	health_bar.tint_progress = health_color


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
	## Kalkan barı artık her zaman görünür (eski davranış: sadece max_value>0 ise görünürdü)
	item_shield_bar.visible = true
	shield_value_label.visible = true
	item_shield_bar.max_value = max(max_value, 0.001)
	item_shield_bar.value = current
	item_shield_bar.tint_progress = Color(0.24, 0.59, 0.91)
	if max_value > 0:
		shield_value_label.text = "%d/%d" % [int(round(max(current, 0.0))), int(round(max_value))]


## O an SAHİP OLUNAN (seviyesi >0) modların listesini MODE_KEYS sırasıyla
## döner - en fazla 5 slot olduğu için fazlası (7. moda kadar) görünmez.
func _owned_shield_modes() -> Array:
	var owned: Array = []
	for mode in MODE_KEYS:
		if int(GameManager.get("shield_mod_" + mode + "_level")) > 0:
			owned.append(mode)
	return owned


## Savaş modları/slotları oyundan kaldırıldı (kullanıcı isteği: "Savaş
## modlarını ve savaş modları için skill panelinin aşağısına eklenen
## slotları oyundan kaldır. Bunları kimse sevmedi.") - bar zaten _ready()'de
## kalıcı gizlendi (ShieldModeBarBG.visible = false), bu fonksiyon artık
## no-op.
func _refresh_shield_mode_slots() -> void:
	return


## Bir slota tıklanınca YA DA aynı index'in kısayol tuşuna basılınca çağrılır
## - zaten aktif olan moda tekrar basmak onu kapatır (bkz. player.gd
## set_active_shield_mode, shield_mode_selector.gd'deki eski davranışla aynı).
## Savaş modları oyundan kaldırıldı (bkz. _refresh_shield_mode_slots
## üstündeki not) - slot butonları artık hiçbir sinyale bağlanmıyor
## (_ready()) ve 1-4 kısayolları da artık hiçbir şey yapmıyor, no-op.
func _on_shield_mode_slot_pressed(_index: int) -> void:
	return


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
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color(0.1, 0.08, 0.08, 0.85)
	input_sb.border_color = Color(0.83, 0.56, 0.30, 1.0)
	input_sb.border_width_left = 2
	input_sb.border_width_top = 2
	input_sb.border_width_right = 2
	input_sb.border_width_bottom = 2
	input_sb.set_corner_radius_all(6)
	input_sb.content_margin_left = 8.0
	input_sb.content_margin_right = 8.0
	_chat_input.add_theme_stylebox_override("normal", input_sb)
	_chat_input.add_theme_stylebox_override("focus", input_sb)
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
	gold_indicator_label.text = str(GameManager.gold)
	_update_status_bar()
	if _mode_switch_cooldown_remaining > 0.0:
		_mode_switch_cooldown_remaining = max(0.0, _mode_switch_cooldown_remaining - delta)
		_refresh_shield_mode_slots()
	_shop_refresh_timer += delta
	if _shop_refresh_timer > 0.4:
		_shop_refresh_timer = 0.0
		if shop_panel.has_method("_refresh"):
			shop_panel._refresh()
		_refresh_shield_mode_slots()

	if player and is_instance_valid(player) and player.has_method("get_skill_progress"):
		skill_icon.update_state(player.get_skill_progress(), player.is_skill_active(), player.skill_timer, player.get_skill_active_fraction())
		if skill2_icon.visible and player.has_method("get_skill2_progress"):
			## Büyücü Kız'ın TEMEL yeteneği artık 4 varyasyonlu ve standart
			## skill2_state/skill2_timer makinesini KULLANMIYOR (bkz. player.gd
			## _buyucu_try_activate_variation/_buyucu_variation_cooldowns) -
			## ikon her karede o anki varyasyonun kendi bekleme sayacını,
			## simge kimliğini, adını ve açıklamasını göstersin diye ayrı bir
			## dalda güncelleniyor. Diğer tüm karakterlerde override'lar
			## boşaltılıp eski davranış aynen kullanılıyor.
			if GameManager.selected_char_id == 4 and player.has_method("get_buyucu_variation_cooldown_remaining"):
				skill2_icon.skill_id = player.get_skill2_id()
				skill2_icon.name_override = player.get_buyucu_variation_name()
				skill2_icon.desc_override = player.get_buyucu_variation_desc()
				var v_idx: int = player.buyucu_variation if "buyucu_variation" in player else 0
				var v_icons: Array = Characters.get_def(4).get("skill2_variation_icons", [])
				if v_idx >= 0 and v_idx < v_icons.size():
					var v_tex: Texture2D = load(v_icons[v_idx])
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
		if skill2_icon.has_method("set_stack_count"):
			if "korsan_bomb_charges" in player and player.get_skill2_id() == 17:
				skill2_icon.set_stack_count(player.korsan_bomb_charges)
				if skill2_icon.has_method("set_charge_progress"):
					skill2_icon.set_charge_progress(player.get_korsan_bomb_charge_fraction())
			## Assasin Çocuk'un yeni TEMEL'i (Şahin Hamlesi, id 5) de Korsan'ın
			## bombasıyla AYNI şarj deseninde - bkz. player.gd
			## assasin_dash2_charges/ASSASIN_DASH2_MAX_CHARGES.
			elif "assasin_dash2_charges" in player and player.get_skill2_id() == 5:
				skill2_icon.set_stack_count(player.assasin_dash2_charges)
				if skill2_icon.has_method("set_charge_progress"):
					skill2_icon.set_charge_progress(player.get_assasin_dash2_charge_fraction())
			else:
				skill2_icon.set_stack_count(-1)
				if skill2_icon.has_method("set_charge_progress"):
					skill2_icon.set_charge_progress(-1.0)
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
					var v_tex_r: Texture2D = load(v_icons_r[v_local_idx_r])
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
