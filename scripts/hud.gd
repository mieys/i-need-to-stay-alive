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
const HudTheme := preload("res://scripts/hud_theme.gd") ## HUD teması "Kısık Ahşap" renkleri (madde 207)
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
	## Envanter açıkken geri (Escape / kumanda B-Start) duraklatma menüsünü AÇMASIN, envanteri kapatsın (bkz.
	## _unhandled_input; main.gd ui_cancel'ı engelleyici panel açıkken yok sayar).
	GameManager.register_blocking_panel(inventory_panel_instance)
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
	"DockFrame", "DockLegend", "DockDivider", "DockPet", "DockStats", "DockStatsToggle"]


func _register_ui_opacity() -> void:
	for path: String in UI_OPACITY_NODES:
		var n: Node = get_node_or_null(path)
		if n:
			UISound.register_ui_opacity(n)
	if _chat_scroll:
		UISound.register_ui_opacity(_chat_scroll)


## SİLAH PARÇACIĞI sayacı (kullanıcı isteği 2026-10-08, demirci dükkanında silah almak için): altın göstergesinin HEMEN altında aynı
## levha stilinde. hud.tscn'e YAZILMIYOR (editör sahneyi geri alıyor, bkz. _layout_shop_inventory_buttons notu) - kodla kurulur.
var _shard_indicator: PanelContainer = null
var _shard_label: Label = null
var _shard_shown: int = -1
const SHARD_ICON_PATH := "res://assets/pickups/weapon_shard/shard_icon.png"


func _ensure_shard_indicator() -> void:
	if is_instance_valid(_shard_indicator):
		return
	_shard_indicator = PanelContainer.new()
	_shard_indicator.name = "ShardIndicator"
	_shard_indicator.process_mode = Node.PROCESS_MODE_ALWAYS
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_shard_indicator.add_child(margin)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load(SHARD_ICON_PATH) as Texture2D
	icon.custom_minimum_size = Vector2(44, 44) ## 22 px sanat x2 (tam sayı ölçek, bulanıklaşmaz)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	_shard_label = Label.new()
	_shard_label.add_theme_font_size_override("font_size", 40)
	_shard_label.add_theme_color_override("font_color", HudTheme.SHARD) ## koyu levhada açık buz mavisi
	_shard_label.text = "0"
	box.add_child(_shard_label)
	add_child(_shard_indicator)
	_set_mouse_ignore_recursive(_shard_indicator)
	UISound.register_ui_opacity(_shard_indicator)
	if _gold_indicator_normal_style:
		_shard_indicator.add_theme_stylebox_override("panel", _gold_indicator_normal_style)
	if not GameManager.weapon_shards_changed.is_connected(_on_weapon_shards_changed):
		GameManager.weapon_shards_changed.connect(_on_weapon_shards_changed)
	_on_weapon_shards_changed(GameManager.weapon_shards)


func _on_weapon_shards_changed(total: int) -> void:
	if _shard_label and total != _shard_shown:
		_shard_shown = total
		_shard_label.text = str(total)


## Sol sütunun (ENVANTER + altın + parçacık) alt kenarı: grup paneli ve DEBUG düğmesi bunun altına yerleşir.
func _left_stack_bottom() -> float:
	var y: float = gold_indicator.get_global_rect().end.y
	if is_instance_valid(_shard_indicator) and _shard_indicator.visible:
		y = maxf(y, _shard_indicator.get_global_rect().end.y)
	return y


func _layout_shop_inventory_buttons() -> void:
	var minimap: Control = get_node_or_null("MinimapControl")
	if not minimap:
		return
	_ensure_shard_indicator()
	## Telefon (madde 273): çanta düğmesi + altın / parçacık sağ üst şeritte (bkz. _layout_mobile_top_right).
	if MobileUIScript.enabled and touch_controls != null:
		shop_toggle_button.visible = false
		_layout_mobile_top_right()
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
		## Kullanıcı isteği (2026-10-04): ENVANTER + altın, altlarındaki grup + sohbet düğmeleriyle AYNI genişlikte (üst üste
		## simetrik dursunlar) - iki kare düğme + aralık (bkz. _fit_mobile_party üst sıra).
		btn_w = MOBILE_TOGGLE_SIZE.x * 2.0 + 10.0

	# Envanter butonu üstte, altın göstergesi altında.
	envanter_toggle_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	envanter_toggle_button.offset_left = left_edge
	envanter_toggle_button.offset_right = left_edge + btn_w
	envanter_toggle_button.add_theme_font_size_override("font_size", 26 if MobileUIScript.enabled else 32)
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

	## Silah parçacığı sayacı: altın göstergesinin altında, aynı genişlik/ölçek. Yükseklik içeriğe göre (min boy) - altın kutusuyla aynı kural.
	var gold_h: float = maxf(btn_h, gold_indicator.get_combined_minimum_size().y)
	_shard_indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_shard_indicator.offset_left = left_edge
	_shard_indicator.offset_right = left_edge + btn_w
	_shard_indicator.offset_top = gold_indicator.offset_top + (gold_h + GAP) * mobile_u
	_shard_indicator.offset_bottom = _shard_indicator.offset_top + maxf(btn_h, _shard_indicator.get_combined_minimum_size().y)
	_shard_indicator.pivot_offset = Vector2.ZERO
	_shard_indicator.scale = Vector2.ONE * mobile_u
	_shard_indicator.visible = true

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
## 2026-10-17 (madde 207): HUD teması "Kısık Ahşap" - düğmeler "hud" varyantı, levhalar koyu kahve, yazılar açık.
func _style_envanter_and_gold_buttons() -> void:
	UIKit.style_button(envanter_toggle_button, "hud")
	UIKit.style_button(shop_toggle_button, "hud")

	## Altın göstergesi artık SADECE bir gösterge (kullanıcı isteği: "sadece
	## göstergeye çevir") - tıklanabilirlik/hover davranışı kaldırıldı, kendi
	## sabit rengi (PAL_WINDOW_BG, bkz. hud.tscn) korunuyor.
	## Kullanıcı isteği (2026-09-21): tüm arayüz UIKit kitiyle uyumlu - altın göstergesi başlık tahtası (plaque) stilinde.
	## 2026-09-25 sadeleştirme: plaque.png'nin altın perçinsiz kopyası (tools/simplify_hud_frames.py) - aynı paylar.
	var plaque_clean := MenuKit._tex_style("plaque.png", [6, 5, 6, 5], [22, 6, 22, 6], false, MenuKit.GAME_DIR)
	plaque_clean.texture = load("res://assets/ui/game/hud_plaque_clean.png")
	_gold_indicator_normal_style = plaque_clean
	gold_indicator.add_theme_stylebox_override("panel", _gold_indicator_normal_style)
	if is_instance_valid(_shard_indicator):
		_shard_indicator.add_theme_stylebox_override("panel", _gold_indicator_normal_style)
	## 2026-10-17: levha koyu kahve (gen_hud_tema.py) - açık altın yazı.
	if gold_indicator_label:
		gold_indicator_label.add_theme_color_override("font_color", HudTheme.PRICE)
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
	## 2026-10-14 (panel yeniden tasarımı, kullanıcı: "pasif ikonu çok büyük, pasif ikonları ufak olur genelde"): soldan sağa
	## Q E R, F, ince ayraç, KÜÇÜK pasif, küçük evcil hayvan yuvası (DockPet - SkillBar'ın dışında, ekran pikseli). Ölçüler
	## ekran pikseli hesaplanır, SkillBar çocuklarına yerel birime (px / k) çevrilerek yazılır. Dizi yerel 0'dan başlar -
	## SkillBar'ı panelin yetenek bölümüne _layout_player_dock oturtur.
	var k: float = DOCK_SKILL_PX / SPIRIT_ICON_BASE_SIZE
	var sz: float = SPIRIT_ICON_BASE_SIZE
	var x: float = 0.0 ## ekran pikseli
	var sig: String = ""
	var placed: int = 0
	for icon in [skill_icon, skill2_icon, skill3_icon, spirit_icon]:
		if icon == null or not icon.visible:
			continue
		if placed > 0:
			x += DOCK_SPIRIT_GAP if icon == spirit_icon else DOCK_SKILL_GAP
		icon.offset_left = x / k
		icon.offset_right = x / k + sz
		icon.offset_top = 0.0
		icon.offset_bottom = sz
		if not is_equal_approx(icon.frame_border, DOCK_SKILL_BORDER_PX / k):
			icon.frame_border = DOCK_SKILL_BORDER_PX / k ## F'nin kalın çerçevesi de aynı 48 px ikon alanını açar
			icon.queue_redraw()
		sig += "%s@%d," % [icon.name, int(x)]
		x += DOCK_SKILL_PX
		placed += 1
	_dock_divider_px = x + DOCK_GROUP_GAP * 0.5 - 1.0
	x += DOCK_GROUP_GAP
	if passive_icon and passive_icon.visible:
		var small: float = DOCK_SMALL_PX / k
		var top: float = (DOCK_SKILL_PX - DOCK_SMALL_PX) * 0.5 / k
		passive_icon.offset_left = x / k
		passive_icon.offset_right = x / k + small
		passive_icon.offset_top = top
		passive_icon.offset_bottom = top + small
		if not is_equal_approx(passive_icon.frame_border, DOCK_SMALL_BORDER_PX / k):
			passive_icon.frame_border = DOCK_SMALL_BORDER_PX / k
			passive_icon.queue_redraw()
		## 36 px'lik yuvada "P" harfi ikonun yarısını kapatıyor - pasif tuşla kullanılmaz, harf gizli.
		var key_label: CanvasItem = passive_icon.get_node_or_null("KeyLabel") as CanvasItem
		if key_label:
			key_label.visible = false
		sig += "P@%d," % int(x)
		x += DOCK_SMALL_PX + DOCK_SMALL_GAP
	_dock_pet_px = x
	x += DOCK_SMALL_PX
	_dock_row_px = x
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
##
## YENİDEN TASARIM (2026-10-14, kullanıcı: "can ve kalkan sayıları hiç okunmuyor, kalp geri sayımı çok ufak, pasif ikonu çok
## büyük, genel bir tasarım güncellemesi gerekiyor" -> iki tur prototipten "2" seçildi, tools/proto_20261014): panel artık
## ÖLÇEKSİZ, ölçüler 1920x1080 ekran pikseli (eski DOCK_SCALE 0,85 piksel yazıyı kesirli boyuta düşürüp bulandırıyordu).
## Üst sıra: Q E R  F | pasif (küçük) + evcil hayvan (küçük) + sağ uçta kalpler ve HER ZAMAN görünen sayaç levhası.
## Alt: solunda kalp/kalkan ikonu olan iki çubuk, sayılar çubuğun sağ ucunda (hud_pixel_bar.gd "merged").
## Sağa yapışık küçük panel: 5 efsanevi eşya yuvası (hud_legend_slots.gd). Panel + efsanevi paneli birlikte ortalanır.
const DOCK_H := 152.0
## 2026-10-17 (kullanıcı: "skill barı arayüz panelini %8 küçült"): tüm panel (çerçeve, yetenekler, çubuklar, kalpler, efsanevi, stat) bu çarpanla
## alt-orta çapasına göre küçülür; ölçüler 1920x1080 tasarım pikselinde yazılı, çarpan sadece _dock_place/_layout_player_dock'ta.
const DOCK_UI_SCALE := 0.92
const DOCK_PAD_TOP := 14.0
const DOCK_PAD_RIGHT := 12.0
const DOCK_BOTTOM_MARGIN := 30.0 ## kullanıcı: "bi 10px daha yukarı" (20 -> 30)
const DOCK_PORTRAIT_POS := Vector2(14.0, 12.0)
const DOCK_PORTRAIT := 84.0 ## hud_avatar_frame.png (96) x 0,875
const DOCK_BADGE_RECT := Rect2(34.0, 74.0, 44.0, 44.0)
const DOCK_CONTENT_X := 112.0 ## yetenek sırası ve çubukların sol kenarı
## 2026-10-17 (kullanıcı: "can ve kalkan barları çok büyük, skilleri büyüt"): 56 -> 64 px; çerçeve kenarı 8 px sabit -> ikon
## alanı tam 48 px = 144 px (48 sanat pikseli x3) yetenek ikonları 1/3 ölçekte BİREBİR keskin (eskiden ~41,7 px, piksel düşüyordu).
const DOCK_SKILL_PX := 64.0
const DOCK_SKILL_BORDER_PX := 8.0 ## Q/E/R/F çerçeve kenarı (ekran pikseli; frame_border = bu / k)
const DOCK_SMALL_BORDER_PX := 4.0 ## küçük pasif yuvanın çerçeve kenarı (ekran pikseli)
const DOCK_SKILL_GAP := 8.0
const DOCK_SPIRIT_GAP := 14.0 ## Q-E-R ile F arası
const DOCK_GROUP_GAP := 22.0 ## yetenekler ile küçük yuvalar (pasif/evcil) arası; ortasında ince ayraç
const DOCK_SMALL_PX := 36.0
const DOCK_SMALL_GAP := 4.0
const DOCK_HEARTS_GAP := 10.0
const DOCK_HEARTS_SIZE := Vector2(88.0, 64.0) ## 4 kalp (22 px aralık) sığar; revive_hearts_hud.gd panel kipi
const DOCK_HEARTS_TOP := 10.0
## Çubuklar inceldi (30/26 -> 24/22): 18 px sayı (14 px rakam + kontur) ve 20 px kalp/kalkan ikonu içine sığar; kazanılan yer yeteneklere.
const DOCK_HP_Y := 86.0
const DOCK_HP_H := 24.0
const DOCK_SHIELD_Y := 114.0
const DOCK_SHIELD_H := 22.0
const DOCK_BAR_RIGHT := 16.0
const DOCK_LEGEND_OVERLAP := 12.0 ## efsanevi paneli ana panelin altına bu kadar girer ("yapışık")
const DOCK_LEGEND_TOP := 6.0
const DOCK_DIVIDER_COLOR := HudTheme.DIVIDER
const SHIELD_VALUE_COLOR := Color("#bfe0ff")
## Telefon HUD'u eski ölçüleri korur (MOBILE_CLUSTER_H bunlara göre).
const MOBILE_HP_H := 22.0
const MOBILE_SHIELD_H := 16.0
const DOCK_BAR_GAP := 2.0
const PixelBarScript: GDScript = preload("res://scripts/hud_pixel_bar.gd")
const LegendSlotsScript: GDScript = preload("res://scripts/hud_legend_slots.gd")
const PetSlotScript: GDScript = preload("res://scripts/hud_pet_slot.gd")
## Mini stat paneli (ana panelin SOLUNA yapışık, efsanevi panelin aynası) + portre altındaki aç/kapa düğmesi (2026-10-14).
const StatPanelScript: GDScript = preload("res://scripts/hud_stat_panel.gd")
const StatToggleScript: GDScript = preload("res://scripts/hud_stat_toggle.gd")
const DOCK_STATS_TOGGLE_RECT := Rect2(24.0, 122.0, 64.0, 20.0) ## panel yereli: seviye rozetinin (DOCK_BADGE_RECT) altı
const SHIELD_BAR_COLOR := Color(0.24, 0.59, 0.91)

var dock_frame: Panel = null
var dock_legend: Control = null
var dock_pet: Control = null
var dock_stats: Control = null
var dock_stats_toggle: Control = null
var dock_divider: ColorRect = null
var dock_hp_bar: Control = null
var dock_shield_bar: Control = null
var _icons_lo := Vector2.ZERO
var _icons_hi := Vector2.ZERO
## Yetenek sırasının ekran pikseli ölçüleri (sıranın sol ucundan; bkz. _layout_ability_icons): ayraç, evcil yuvası, sıra sonu.
var _dock_divider_px: float = 0.0
var _dock_pet_px: float = 0.0
var _dock_row_px: float = 0.0


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
	if not MobileUIScript.enabled:
		## Efsanevi paneli ana panelin ARKASINDA (sol 12 px'i örtülür); ayraç + evcil yuvası hemen önünde.
		dock_legend = Control.new()
		dock_legend.name = "DockLegend"
		dock_legend.set_script(LegendSlotsScript)
		add_child(dock_legend)
		move_child(dock_legend, dock_frame.get_index())
		dock_divider = ColorRect.new()
		dock_divider.name = "DockDivider"
		dock_divider.color = DOCK_DIVIDER_COLOR
		dock_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dock_divider)
		move_child(dock_divider, dock_frame.get_index() + 1)
		dock_pet = Control.new()
		dock_pet.name = "DockPet"
		dock_pet.set_script(PetSlotScript)
		add_child(dock_pet)
		move_child(dock_pet, dock_frame.get_index() + 1)
		## Mini stat paneli de ana panelin ARKASINDA (sağ 12 px'i örtülür); aç/kapa düğmesi portrenin üstünde (en son çizilir).
		dock_stats = Control.new()
		dock_stats.name = "DockStats"
		dock_stats.set_script(StatPanelScript)
		add_child(dock_stats)
		move_child(dock_stats, dock_frame.get_index())
		dock_stats_toggle = Control.new()
		dock_stats_toggle.name = "DockStatsToggle"
		dock_stats_toggle.set_script(StatToggleScript)
		add_child(dock_stats_toggle)
		dock_stats_toggle.call("bind_panel", dock_stats)
	if revive_hearts:
		## Kalpler artık panelin İÇİNDE: çerçeveden sonra çizilmeli.
		if revive_hearts.get_index() < dock_frame.get_index():
			move_child(revive_hearts, dock_frame.get_index())
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
	c.offset_left = r.position.x * DOCK_UI_SCALE
	c.offset_top = r.position.y * DOCK_UI_SCALE
	c.offset_right = c.offset_left + r.size.x
	c.offset_bottom = c.offset_top + r.size.y
	c.pivot_offset = Vector2.ZERO
	c.scale = Vector2.ONE * DOCK_UI_SCALE


func _layout_player_dock() -> void:
	if MobileUIScript.enabled:
		_layout_mobile_hud()
		return
	var bar: Control = get_node_or_null("SkillBar")
	var cluster: Control = get_node_or_null("CharacterCluster")
	if bar == null or cluster == null or not is_instance_valid(dock_frame):
		return
	## Yetenek yuvaları SkillBar.scale ile 52 birim -> DOCK_SKILL_PX (64) px; gerisi ölçeksiz ekran pikseli.
	var k: float = DOCK_SKILL_PX / SPIRIT_ICON_BASE_SIZE
	bar.scale = Vector2.ONE * k * DOCK_UI_SCALE
	var dock_w: float = DOCK_CONTENT_X + _dock_row_px + DOCK_HEARTS_GAP + DOCK_HEARTS_SIZE.x + DOCK_PAD_RIGHT
	var legend_w: float = (LegendSlotsScript.PANEL_SIZE.x - DOCK_LEGEND_OVERLAP) if is_instance_valid(dock_legend) else 0.0
	var x0: float = roundf(-(dock_w + legend_w) * 0.5)
	var y0: float = -DOCK_BOTTOM_MARGIN - DOCK_H
	_dock_place(dock_frame, Rect2(x0, y0, dock_w, DOCK_H))
	_dock_place(cluster, Rect2(x0, y0, dock_w, DOCK_H))

	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = (x0 + DOCK_CONTENT_X - _icons_lo.x * k) * DOCK_UI_SCALE
	bar.offset_top = (y0 + DOCK_PAD_TOP - _icons_lo.y * k) * DOCK_UI_SCALE
	bar.offset_right = bar.offset_left + maxf(_icons_hi.x, 1.0)
	bar.offset_bottom = bar.offset_top + maxf(_icons_hi.y, 1.0)
	var small_y: float = y0 + DOCK_PAD_TOP + (DOCK_SKILL_PX - DOCK_SMALL_PX) * 0.5
	if is_instance_valid(dock_divider):
		_dock_place(dock_divider, Rect2(x0 + DOCK_CONTENT_X + _dock_divider_px, y0 + DOCK_PAD_TOP + 6.0, 2.0, DOCK_SKILL_PX - 12.0))
	if is_instance_valid(dock_pet):
		_dock_place(dock_pet, Rect2(x0 + DOCK_CONTENT_X + _dock_pet_px, small_y, DOCK_SMALL_PX, DOCK_SMALL_PX))

	## Portre (çerçeve 96 -> 84 px; kırpma kutusu aynı oranla ölçeklenir) + seviye rozeti.
	var pk: float = DOCK_PORTRAIT / 96.0
	_cluster_rect(cluster, "PortraitFrame", Rect2(DOCK_PORTRAIT_POS, Vector2(DOCK_PORTRAIT, DOCK_PORTRAIT)))
	_cluster_rect(cluster, "PortraitClip", Rect2((DOCK_PORTRAIT_POS + Vector2(12, 12) * pk).round(), Vector2(72, 72)))
	var clip: Control = cluster.get_node_or_null("PortraitClip") as Control
	if clip:
		clip.pivot_offset = Vector2.ZERO
		clip.scale = Vector2.ONE * pk
	_cluster_rect(cluster, "LevelBadge", DOCK_BADGE_RECT)
	_cluster_rect(cluster, "LevelLabel", DOCK_BADGE_RECT)

	## Can + kalkan: içerik genişliğince; ikon solda, sayı çubuğun sağ ucunda.
	var bar_w: float = dock_w - DOCK_CONTENT_X - DOCK_BAR_RIGHT
	if dock_hp_bar:
		dock_hp_bar.position = Vector2(DOCK_CONTENT_X, DOCK_HP_Y)
		dock_hp_bar.size = Vector2(bar_w, DOCK_HP_H)
		dock_hp_bar.set("icon_kind", "heart")
		dock_hp_bar.set("merged", true)
		dock_hp_bar.queue_redraw()
	if dock_shield_bar:
		dock_shield_bar.position = Vector2(DOCK_CONTENT_X, DOCK_SHIELD_Y)
		dock_shield_bar.size = Vector2(bar_w, DOCK_SHIELD_H)
		dock_shield_bar.set("icon_kind", "shield")
		dock_shield_bar.set("value_color", SHIELD_VALUE_COLOR)
		dock_shield_bar.set("merged", true)
		dock_shield_bar.queue_redraw()

	## Kalpler + sayaç levhası: üst sıranın sağ ucu.
	if revive_hearts:
		if revive_hearts.has_method("set_dock_mode"):
			revive_hearts.set_dock_mode(true)
		_dock_place(revive_hearts, Rect2(Vector2(x0 + dock_w - DOCK_PAD_RIGHT - DOCK_HEARTS_SIZE.x, y0 + DOCK_HEARTS_TOP), DOCK_HEARTS_SIZE))
	if is_instance_valid(dock_legend):
		_dock_place(dock_legend, Rect2(Vector2(x0 + dock_w - DOCK_LEGEND_OVERLAP, y0 + DOCK_LEGEND_TOP), LegendSlotsScript.PANEL_SIZE))
	## Mini stat paneli: sağ kenarı ana panelin altına girer, ALTI efsanevi panelin altıyla hizalı (sekmeler üstte). Açılınca dock
	## yeniden ORTALANMAZ (yerinden zıplamasın) - panel sola doğru açılır.
	## 2026-10-18: panel ÖLÇEKSİZ (scale 1, tam piksel konum) - DOCK_UI_SCALE 0,92 yazıyı/simgeyi düzensiz çiziyordu; sadece sağ-alt
	## köşesi ölçekli dock'a göre hesaplanır.
	if is_instance_valid(dock_stats):
		var ns: Vector2 = StatPanelScript.node_size()
		var legend_bottom: float = y0 + DOCK_LEGEND_TOP + LegendSlotsScript.PANEL_SIZE.y
		var br := Vector2(roundf((x0 + DOCK_LEGEND_OVERLAP) * DOCK_UI_SCALE), roundf(legend_bottom * DOCK_UI_SCALE))
		dock_stats.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		dock_stats.offset_left = br.x - ns.x
		dock_stats.offset_top = br.y - ns.y
		dock_stats.offset_right = br.x
		dock_stats.offset_bottom = br.y
		dock_stats.pivot_offset = Vector2.ZERO
		dock_stats.scale = Vector2.ONE
	if is_instance_valid(dock_stats_toggle):
		_dock_place(dock_stats_toggle, Rect2(Vector2(x0, y0) + DOCK_STATS_TOGGLE_RECT.position, DOCK_STATS_TOGGLE_RECT.size))


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
## Telefon: envanter/özellikler açıkken arkadaki karartma (bkz. _fit_mobile_inventory_panels).
var _mobile_inv_dim: ColorRect = null
const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const TouchScrollScript := preload("res://scripts/touch_scroll.gd")
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
## Telefon üst düğme sırası (altın göstergesinin altında, kullanıcı isteği 2026-10-04): grup aç/kapa, sohbet yaz, hasar
## sıralaması - bkz. _fit_mobile_party.
var mobile_party_toggle: Button = null
var mobile_chat_button: Button = null
var mobile_stats_button: Button = null


## Ekran kenarından içeri pay (tuval px): position = (sol, üst), size = (sağ, alt). Çentik/kamera deliği payı + HUD payı.
func _mobile_edges() -> Rect2:
	var u: float = MobileUIScript.HUD_SCALE
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Rect2(safe.position.x + MOBILE_MARGIN * u, safe.position.y + MOBILE_MARGIN * u,
			safe.size.x + MOBILE_MARGIN * u, safe.size.y + MOBILE_BOTTOM_MARGIN * u)


## ---------------------------------------------------------------- TELEFON HUD'u v2 (2026-10-18, madde 273)
## Kullanıcı onayı (2026-10-18, madde 253 "ML HUD" + "yapay zekâ gibi" temizliği; prototip tools/proto_20261018/mobil_proto.gd
## _ml_hud): Mobile Legends yerleşimi, PC'nin ahşap kiti.
##  - sol üst: KARE minimap (ahşap levha çerçeve) + sağında sohbet düğmesi (okunmamış rozeti) -> hızlı sohbet penceresi,
##  - minimapin altında grup paneli (PC party_panel, minimapla aynı genişlikte, altında "İstatistik"; sağındaki sekmeyle
##    katlanır, katlıyken portre sütunu), sağında son sohbet satırları,
##  - sağ üst: ahşap şerit (seviye rozeti, kalpler, altın, silah parçacığı, ping) + ayar (duraklat) + çanta (envanter),
##  - sağ kenar: R / E / Q üst üste eşit boy (ulti en üstte), ruhani F Q'nun solunda, pasif küçük R'nin solunda; etkileşim
##    (dükkan / demirci / kapı) düğmesi sadece yakındayken F sütununda,
##  - can/kalkan karakterin başında (overhead_bar), XP en altta (bottom_exp_bar), joystick sol altta.
## Ölçüler TUVAL px (telefonda tuval yüksekliği 1080, en EXPAND); kenarlar çentik payını içerir (_ph_bounds).
const PH_EDGE := 18.0 ## sol / üst kenar boşluğu (kullanıcı: "yapışık ama ufak da olsa bir aralık")
const PH_MAP := 300.0 ## minimap çerçevesi; iç harita PH_MAP - 2 x PH_MAP_INSET kare
const PH_MAP_INSET := 15.0
const PH_TEAM_W := 300.0 ## grup paneli = minimap genişliği
const PH_TAB := Vector2(40.0, 66.0) ## grup paneli katlama sekmesi
const PH_BTN := 72.0 ## sohbet / ayar düğmesi
const PH_BAG := 68.0 ## çanta (envanter) düğmesi
const PH_RIGHT := 100.0 ## sağ üst düğmelerin sağ kenar payı
const PH_SKILL := 162.0 ## yetenek halkası (54 px doku x3)
const PH_SKILL_X := 194.0 ## sağ sütun merkezi: sağ kenardan
const PH_SKILL_Y := [541.0, 329.0, 117.0] ## R / E / Q merkezleri: alt kenardan
const PH_COL_GAP := 216.0 ## F / pasif / etkileşim sütunu sağ sütunun bu kadar solunda
const PH_PASSIVE_K := 0.62 ## pasif ikon basılmaz, küçük durur
const PH_INTERACT := 108.0 ## etkileşim halkası (54 px doku x2)
const PH_INTERACT_Y := 390.0 ## etkileşim düğmesi merkezi: alt kenardan
const PH_STRIP_W := 508.0 ## ping yuvası (PH_PING_W) yoksa: rozet + kalpler + altın + parçacık
const PH_PING_W := 110.0 ## sadece istemcide (ENet gidiş-dönüş süresi); host / tek oyunculuda şerit bu kadar dar
const PH_STRIP_H := 60.0
const PH_STRIP_RIGHT := 186.0 ## şeridin sağ kenarı: sağ kenardan
const PH_JOY := Vector2(420.0, 208.0) ## joystick boştaki merkezi: sol kenardan / alt kenardan
const PH_INTERACT_TEXT := {"shop": "Dükkan", "smith": "Demirci", "house": "Kapı"}
## 16x16 simgeler (koddan, ayrı doku yok): dişli (ayar), çanta (envanter / dükkan), katlama okları, ev (kapı).
const GEAR_ICON_MAP: Array[String] = [
	"................",
	"......####......",
	".....######.....",
	"..##.######.##..",
	"..############..",
	"...##########...",
	".#####....#####.",
	".####......####.",
	".####......####.",
	".#####....#####.",
	"...##########...",
	"..############..",
	"..##.######.##..",
	".....######.....",
	"......####......",
	"................",
]
const BAG_ICON_MAP: Array[String] = [
	"................",
	"......####......",
	".....#....#.....",
	".....#....#.....",
	"...##########...",
	"..############..",
	".##############.",
	".######..######.",
	".#####....#####.",
	".######..######.",
	".##############.",
	".##############.",
	".##############.",
	"..############..",
	"................",
	"................",
]
const CHEV_L_ICON_MAP: Array[String] = [
	"................",
	"................",
	"........##......",
	".......###......",
	"......###.......",
	".....###........",
	"....###.........",
	"...###..........",
	"...###..........",
	"....###.........",
	".....###........",
	"......###.......",
	".......###......",
	"........##......",
	"................",
	"................",
]
const CHEV_R_ICON_MAP: Array[String] = [
	"................",
	"................",
	"......##........",
	"......###.......",
	".......###......",
	"........###.....",
	".........###....",
	"..........###...",
	"..........###...",
	".........###....",
	"........###.....",
	".......###......",
	"......###.......",
	"......##........",
	"................",
	"................",
]
const HOUSE_ICON_MAP: Array[String] = [
	"................",
	".......##.......",
	"......####......",
	".....######.....",
	"....########....",
	"...##########...",
	"..############..",
	"...##########...",
	"...###....###...",
	"...###....###...",
	"...###....###...",
	"...###....###...",
	"...###....###...",
	"...##########...",
	"................",
	"................",
]
const MobileQuickChatScript := preload("res://scripts/mobile_quick_chat.gd")
const MobilePartyColumnScript := preload("res://scripts/mobile_party_column.gd")
var _ph_map_frame: Panel = null
var _ph_map_edge: ColorRect = null
var _ph_strip: Panel = null
var _ph_ping: Label = null
var _ph_chat_badge: Control = null
var _ph_badge_label: Label = null
var _ph_unread: int = 0
var _ph_recent: Array = [] ## son sohbet satırları [[ad, metin], ...] - hızlı sohbet penceresinin kuyusu
var _ph_interact_icon: TextureRect = null
var _ph_interact_plate: PanelContainer = null
var _ph_interact_label: Label = null
var _ph_interact_kind: String = "?"
var _ph_quick_chat: Control = null
var _ph_party_column: Control = null
var _ph_send_btn: Button = null
var _ph_ping_timer: float = 0.0


## Etkileşim düğmesinin koyu iç dairesi (halka dokusunun deliği).
class PhDisc extends Control:
	var color: Color = Color("#271a11")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.5 * 0.87, color, true, -1.0, false)


## Güvenli alanın mutlak kenarları (tuval px): x sol, y üst, z sağ, w alt.
func _ph_bounds() -> Vector4:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Vector4(safe.position.x, safe.position.y, vp.x - safe.size.x, vp.y - safe.size.y)


## Düğümü tuvalde `r` dikdörtgenine koyar (ölçek 1, sol-üst çapa, tam piksel).
func _ph_place(c: Control, r: Rect2) -> void:
	if not is_instance_valid(c):
		return
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.pivot_offset = Vector2.ZERO
	c.scale = Vector2.ONE
	c.offset_left = roundf(r.position.x)
	c.offset_top = roundf(r.position.y)
	c.offset_right = roundf(r.end.x)
	c.offset_bottom = roundf(r.end.y)


## Simge düğmesinin 16x16 piksel simgesi tam katta (48 = x3, 32 = x2) ortada; ahşap düğmenin alt kalınlığı için 2 px yukarı.
func _ph_icon_fit(b: Control, px: float = 48.0) -> void:
	if not is_instance_valid(b):
		return
	var ic: Control = b.get_node_or_null("Icon") as Control
	if ic == null:
		return
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -px * 0.5
	ic.offset_right = px * 0.5
	ic.offset_top = -px * 0.5 - 2.0
	ic.offset_bottom = px * 0.5 - 2.0


## Can kümesinde telefonda sadece seviye rozeti kalır (şeritte); can/kalkan karakterin başında (overhead_bar).
func _ph_hide_cluster_bars() -> void:
	var cluster: Control = get_node_or_null("CharacterCluster")
	if cluster == null:
		return
	for c in cluster.get_children():
		if c is CanvasItem and not (String(c.name) in ["LevelBadge", "LevelLabel"]):
			(c as CanvasItem).visible = false


func _ph_build_frames() -> void:
	## Minimap çerçevesi: ahşap levha + haritanın çevresinde 3 px koyu kontur (ikisi de minimapin ARKASINDA).
	var minimap: Control = get_node_or_null("MinimapControl")
	_ph_map_frame = Panel.new()
	_ph_map_frame.name = "PhoneMapFrame"
	_ph_map_frame.add_theme_stylebox_override("panel", UIKit.panel_style("hud_plaque"))
	_ph_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph_map_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_ph_map_frame)
	_ph_map_edge = ColorRect.new()
	_ph_map_edge.name = "PhoneMapEdge"
	_ph_map_edge.color = HudTheme.OUTLINE
	_ph_map_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ph_map_edge)
	if minimap:
		move_child(_ph_map_frame, minimap.get_index())
		move_child(_ph_map_edge, minimap.get_index())
		minimap.set("square", true)
	## Sağ üst şerit: levha (göstergeler kendi düğümleriyle üstüne yerleşir - bkz. _layout_mobile_top_right).
	_ph_strip = Panel.new()
	_ph_strip.name = "PhoneTopStrip"
	_ph_strip.add_theme_stylebox_override("panel", UIKit.panel_style("hud_plaque"))
	_ph_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph_strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_ph_strip)
	move_child(_ph_strip, 0)
	var groove := Control.new()
	groove.name = "Groove"
	groove.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph_strip.add_child(groove)
	for i in 2:
		var g := ColorRect.new()
		g.color = HudTheme.OUTLINE if i == 0 else HudTheme.RIM_HI
		g.position = Vector2(i * 3.0, 0.0)
		g.size = Vector2(3.0, 36.0)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		groove.add_child(g)
	_ph_ping = Label.new()
	_ph_ping.name = "PhonePing"
	_ph_ping.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ph_ping.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(_ph_ping, 24, HudTheme.DIM, 0)
	add_child(_ph_ping)
	## Altın + parçacık göstergeleri şeridin üstünde: kendi levhaları kalkar (levha içinde levha olmasın), yazı 32 (m5x7 4x).
	var empty := StyleBoxEmpty.new()
	_gold_indicator_normal_style = empty
	_gold_indicator_hover_style = null
	gold_indicator.add_theme_stylebox_override("panel", empty)
	gold_indicator_label.add_theme_font_size_override("font_size", 32)
	var gm: MarginContainer = gold_indicator.get_node_or_null("GoldMargin") as MarginContainer
	_ensure_shard_indicator()
	var sm: MarginContainer = _shard_indicator.get_child(0) as MarginContainer if _shard_indicator.get_child_count() > 0 else null
	for m: MarginContainer in [gm, sm]:
		if m:
			for side: String in ["top", "bottom"]:
				m.add_theme_constant_override("margin_" + side, 0)
			for side2: String in ["left", "right"]:
				m.add_theme_constant_override("margin_" + side2, 2)
	_shard_indicator.add_theme_stylebox_override("panel", empty)
	if _shard_label:
		_shard_label.add_theme_font_size_override("font_size", 32)
	## Çanta (envanter): kare ahşap düğme + çanta simgesi.
	envanter_toggle_button.text = ""
	UIKit.style_button(envanter_toggle_button, "hud", true)
	if envanter_toggle_button.get_node_or_null("Icon") == null:
		var bi := TextureRect.new()
		bi.name = "Icon"
		bi.texture = _pixel_icon_texture(BAG_ICON_MAP)
		bi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bi.stretch_mode = TextureRect.STRETCH_SCALE
		bi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		envanter_toggle_button.add_child(bi)


func _ph_build_interact() -> void:
	var b := Button.new()
	b.name = "MobileInteract"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE ## basma işini touch_controls yapar
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.visible = false
	add_child(b)
	var disc := PhDisc.new()
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(disc)
	var ring := TextureRect.new()
	ring.texture = ROUND_FRAME
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(ring)
	_ph_interact_icon = TextureRect.new()
	_ph_interact_icon.name = "Icon"
	_ph_interact_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ph_interact_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ph_interact_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_ph_interact_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(_ph_interact_icon)
	_ph_icon_fit(b, 48.0)
	_ph_interact_icon.offset_top += 2.0 ## yuvarlak düğmede alt kalınlık yok - tam ortada
	_ph_interact_icon.offset_bottom += 2.0
	mobile_interact_button = b
	_ph_interact_plate = PanelContainer.new()
	_ph_interact_plate.name = "MobileInteractPlate"
	_ph_interact_plate.add_theme_stylebox_override("panel", UIKit.panel_style("hud_plaque"))
	_ph_interact_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph_interact_plate.visible = false
	_ph_interact_label = Label.new()
	_ph_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ph_interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(_ph_interact_label, 24, HudTheme.TEXT, 0)
	_ph_interact_plate.add_child(_ph_interact_label)
	add_child(_ph_interact_plate)


func _ph_build_chat_badge() -> void:
	var badge := ColorRect.new()
	badge.name = "UnreadBadge"
	badge.color = HudTheme.OUTLINE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(30, 30)
	badge.position = Vector2(PH_BTN - 20.0, -10.0)
	for part: Array in [[Color("#a8403a"), Vector2(3, 3), Vector2(24, 24)], [Color("#cf6a58"), Vector2(3, 3), Vector2(24, 3)]]:
		var r := ColorRect.new()
		r.color = part[0]
		r.position = part[1]
		r.size = part[2]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(r)
	_ph_badge_label = Label.new()
	_ph_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ph_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ph_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph_badge_label.position = Vector2(0, -2)
	_ph_badge_label.size = Vector2(30, 30)
	UIKit.style_label(_ph_badge_label, 24, HudTheme.TEXT, 0)
	badge.add_child(_ph_badge_label)
	badge.visible = false
	mobile_chat_button.add_child(badge)
	_ph_chat_badge = badge


func _ph_update_badge() -> void:
	if not is_instance_valid(_ph_chat_badge):
		return
	_ph_chat_badge.visible = _ph_unread > 0
	_ph_badge_label.text = str(mini(_ph_unread, 9)) if _ph_unread < 10 else "9+"


func _ph_toggle_quick_chat() -> void:
	if not is_instance_valid(_ph_quick_chat):
		_ph_quick_chat = MobileQuickChatScript.new()
		_ph_quick_chat.name = "MobileQuickChat"
		_ph_quick_chat.visible = false
		(_chat_layer if _chat_layer else self).add_child(_ph_quick_chat)
		_ph_quick_chat.connect("quick_message", func(t: String) -> void:
			_ph_quick_chat.visible = false
			_send_chat_message(t))
		_ph_quick_chat.connect("write_requested", func() -> void:
			_ph_quick_chat.visible = false
			_open_chat_input())
		_ph_quick_chat.connect("close_requested", func() -> void: _ph_quick_chat.visible = false)
	if _ph_quick_chat.visible:
		_ph_quick_chat.visible = false
	else:
		_close_chat_input()
		var b: Vector4 = _ph_bounds()
		_ph_quick_chat.position = Vector2(b.x + PH_EDGE + PH_MAP + 16.0, b.y + 110.0)
		_ph_quick_chat.call("set_recent", _ph_recent)
		_ph_quick_chat.visible = true
		_ph_unread = 0
		_ph_update_badge()
	UISound.play_click()


## Görünen etkileşim uyarısının sahibi: seyyar satıcı -> "shop", demirci -> "smith", ev -> "house" (yoksa "").
func _ph_interact_kind_now() -> String:
	for n in get_tree().get_nodes_in_group(&"interact_prompt"):
		if not (n is CanvasItem) or not (n as CanvasItem).is_visible_in_tree():
			continue
		var p: Node = n
		while p != null:
			var sc: Script = p.get_script() as Script
			if sc != null:
				var path: String = sc.resource_path
				if path.ends_with("traveling_merchant.gd"):
					return "shop"
				if path.ends_with("weapon_shop.gd"):
					return "smith"
				if path.ends_with("house_interior.gd"):
					return "house"
			p = p.get_parent()
	return ""


## Ping (ms): istemcide ENet sunucu bağlantısının gidiş-dönüş süresi; host / tek oyunculu / Epic soketinde -1 (yazı gizli).
func _ph_ping_ms() -> int:
	if not NetworkManager.is_multiplayer_active or not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return -1
	var mp: MultiplayerPeer = multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var peer: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(1)
		if peer != null:
			return int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return -1


## Her kare (telefon): etkileşim levhası + ping.
var _ph_modal_timer: float = 0.0
var _ph_party_suppressed: bool = false


## Telefonda ekranı kaplayan bir pencere açık mı: envanter/özellikler, kart/dükkan ekranları (reading_ui), duraklatma / zafer /
## Ruh Mağazası (gamepad_modal), oyun bitti (phone_fullscreen).
func _ph_modal_open() -> bool:
	if _mobile_hud_panel_open():
		return true
	for g: StringName in [&"reading_ui", &"gamepad_modal", &"phone_fullscreen"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n) and n.is_inside_tree() and not n.is_queued_for_deletion() and ReadingUiWatcherScript._is_shown(n):
				return true
	return false


func _ph_tick(delta: float) -> void:
	if is_instance_valid(_ph_interact_plate) and is_instance_valid(mobile_interact_button):
		var show: bool = mobile_interact_button.visible
		_ph_interact_plate.visible = show
		if show:
			var kind: String = _ph_interact_kind_now()
			if kind != _ph_interact_kind:
				_ph_interact_kind = kind
				_ph_interact_label.text = str(PH_INTERACT_TEXT.get(kind, "Kullan"))
				_ph_interact_icon.texture = _pixel_icon_texture(HOUSE_ICON_MAP if kind == "house" else BAG_ICON_MAP, HudTheme.PRICE)
			var br: Rect2 = mobile_interact_button.get_global_rect()
			var ps: Vector2 = _ph_interact_plate.get_combined_minimum_size()
			_ph_interact_plate.size = ps
			_ph_interact_plate.position = Vector2(roundf(br.get_center().x - ps.x * 0.5), roundf(br.end.y - 2.0))
	## Tam ekran telefon pencereleri açıkken grup paneli (katman 96) gizlenir - sol rayların / kartların üstüne binmesin.
	_ph_modal_timer -= delta
	if _ph_modal_timer <= 0.0:
		_ph_modal_timer = 0.1
		var modal: bool = _ph_modal_open()
		if modal != _ph_party_suppressed:
			_ph_party_suppressed = modal
			get_tree().call_group(&"party_panel", &"set_suppressed", "phone_modal", modal)
	_ph_ping_timer -= delta
	if _ph_ping_timer <= 0.0 and is_instance_valid(_ph_ping):
		_ph_ping_timer = 0.5
		var ms: int = _ph_ping_ms()
		_ph_ping.text = ("%d ms" % ms) if ms >= 0 else ""


## Sağ üst: çanta, şerit (seviye rozeti, kalpler, altın, parçacık, ping) - sabit yuvalar (altın büyüdükçe şerit kaymasın).
func _layout_mobile_top_right() -> void:
	if not is_instance_valid(_ph_strip):
		return
	var b: Vector4 = _ph_bounds()
	_ph_place(envanter_toggle_button, Rect2(b.z - PH_RIGHT - PH_BAG - 2.0, b.y + 108.0, PH_BAG, PH_BAG))
	_ph_icon_fit(envanter_toggle_button)
	var sw: float = PH_STRIP_W + (PH_PING_W if _ph_ping_ms() >= 0 else 0.0)
	var r := Rect2(b.z - PH_STRIP_RIGHT - sw, b.y + 26.0, sw, PH_STRIP_H)
	_ph_place(_ph_strip, r)
	var cy: float = r.position.y + 29.0
	var x: float = r.position.x + 16.0
	var cluster: Control = get_node_or_null("CharacterCluster")
	if cluster:
		_ph_place(cluster, Rect2(x, cy - 26.0, 52.0, 52.0))
		_cluster_rect(cluster, "LevelBadge", Rect2(0, 0, 52, 52))
		_cluster_rect(cluster, "LevelLabel", Rect2(0, 0, 52, 52))
	x += 52.0 + 18.0
	var groove: Control = _ph_strip.get_node_or_null("Groove") as Control
	if groove:
		groove.position = Vector2(roundf(x - r.position.x), 12.0)
	x += 6.0 + 18.0
	if revive_hearts:
		revive_hearts.set_anchors_preset(Control.PRESET_TOP_LEFT)
		revive_hearts.pivot_offset = Vector2.ZERO
		revive_hearts.scale = Vector2.ONE * 1.2
		revive_hearts.offset_left = x
		revive_hearts.offset_top = roundf(cy - 19.0)
		revive_hearts.offset_right = x + 90.0
		revive_hearts.offset_bottom = revive_hearts.offset_top + 32.0
	x += 108.0 + 20.0
	for pair: Array in [[gold_indicator, 150.0], [_shard_indicator, 110.0]]:
		var ind: Control = pair[0]
		if is_instance_valid(ind):
			ind.reset_size()
			var m: Vector2 = ind.get_combined_minimum_size()
			_ph_place(ind, Rect2(x, roundf(cy - m.y * 0.5), m.x, m.y))
			ind.visible = true
		x += float(pair[1])
	_ph_place(_ph_ping, Rect2(x, r.position.y + 2.0, maxf(0.0, r.end.x - x - 12.0), PH_STRIP_H - 4.0))


func _setup_mobile_hud() -> void:
	if not MobileUIScript.enabled or not is_inside_tree() or touch_controls != null:
		return
	if is_instance_valid(dock_frame):
		dock_frame.visible = false
	_ph_hide_cluster_bars()
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
	## Ayar (duraklat): sağ üst köşede dişli simgeli kare ahşap düğme (madde 273).
	mobile_pause_button = _make_mobile_icon_button("MobilePause", GEAR_ICON_MAP)
	mobile_pause_button.visible = true
	touch_controls.register_button(mobile_pause_button, &"ui_cancel", false)
	touch_controls.pause_button = mobile_pause_button
	## Etkileşim (dükkan / demirci / kapı): yuvarlak ahşap halka + simge, altında ahşap levhada ne olduğu.
	_ph_build_interact()
	touch_controls.register_button(mobile_interact_button, &"interact", true)
	touch_controls.interact_button = mobile_interact_button
	## Dokunuşu touch_controls bir eylem olarak basar (düğmeler joystick bölgesinde - fare olayı olsa joystick de başlardı).
	for act: StringName in [&"mobile_party_toggle", &"mobile_chat_open", &"mobile_party_stats"]:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
	mobile_party_toggle = _make_mobile_icon_button("MobilePartyToggle", CHEV_L_ICON_MAP)
	touch_controls.register_button(mobile_party_toggle, &"mobile_party_toggle", false)
	mobile_chat_button = _make_mobile_icon_button("MobileChat", CHAT_ICON_MAP)
	touch_controls.register_button(mobile_chat_button, &"mobile_chat_open", false)
	_ph_build_chat_badge()
	## Hasar/istatistik penceresi grup panelinin kendi alt düğmesinden ("İstatistik") açılır - bu düğme artık hep gizli.
	mobile_stats_button = _make_mobile_button("MobileStats", "İstatistik")
	mobile_stats_button.visible = false
	touch_controls.register_button(mobile_stats_button, &"mobile_party_stats", false)
	touch_controls.joy_exclude = _mobile_joy_exclude
	_ph_build_frames()
	_ph_party_column = MobilePartyColumnScript.new()
	_ph_party_column.name = "PhonePartyColumn"
	_ph_party_column.visible = false
	add_child(_ph_party_column)
	_ability_layout_sig = ""
	_layout_ability_icons()
	_update_ability_bar_frame()
	_layout_shop_inventory_buttons()
	_fit_mobile_inventory_panels.call_deferred()
	## Mutlak konumlar (madde 273) ekran boyutu değişince yenilenir: telefonda sistem çubukları / bölünmüş ekran, masaüstü
	## denemesinde pencere boyutu (yakalama betiği pencereyi açıldıktan sonra 2400x1080 yapıyor).
	if not get_viewport().size_changed.is_connected(_on_phone_viewport_resized):
		get_viewport().size_changed.connect(_on_phone_viewport_resized)
	if UISound.has_signal(&"touch_settings_changed") and not UISound.touch_settings_changed.is_connected(_on_touch_settings_changed):
		UISound.touch_settings_changed.connect(_on_touch_settings_changed)


func _on_touch_settings_changed() -> void:
	if not MobileUIScript.enabled or touch_controls == null:
		return
	_ability_layout_sig = ""
	_layout_mobile_ability_icons()


func _on_phone_viewport_resized() -> void:
	if not MobileUIScript.enabled or touch_controls == null:
		return
	_layout_mobile_hud.call_deferred()
	_layout_mobile_status_bar.call_deferred()
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
	## Kullanıcı bildirimi (2026-10-03): "envanter paneli çok kötü mobile uyumlu değil" - masaüstü panelleri küçültüp
	## sığdırmak yerine (eski yol) paneller telefon boyunda kendi yerleşimini kurar (prototip P1 "Büyütülmüş Klasik"):
	## özellikler solda, envanter sağda, ikisi ekranın neredeyse tamamı; arkada karartma (dokununca kapanır), paneller
	## HUD düğmelerinin üstünde (touch_controls panel açıkken yetenek düğmelerini de yok sayar).
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	var room: float = vp.x - safe.position.x - safe.size.x - 48.0
	var gap: float = 24.0
	var stats_w: float = clampf(roundf(room * 0.42), 760.0, 900.0)
	var inv_w: float = minf(1240.0, room - stats_w - gap)
	var x0: float = safe.position.x + roundf((vp.x - safe.position.x - safe.size.x - (stats_w + gap + inv_w)) * 0.5)
	var h: float = minf(1000.0, vp.y - 80.0)
	var y0: float = roundf((vp.y - h) * 0.5)
	## Madde 274 (prototip B "Yan Ray + Detay"): solda ray (geri, ÇANTA, ÖZELLİK), iki panel aynı alanı paylaşır; ÖZELLİK sekmesi
	## özellikler panelini çantanın üstünde gösterir. Paneller Gece Sıvası (inventory_panel / stats_panel _apply_night_style).
	var rail_w: float = 140.0
	x0 = safe.position.x + 24.0
	var full_w: float = vp.x - safe.position.x - safe.size.x - 48.0 - rail_w - gap
	stats_w = full_w
	inv_w = full_w
	if _mobile_inv_dim == null:
		_mobile_inv_dim = ColorRect.new()
		_mobile_inv_dim.name = "MobileInventoryDim"
		_mobile_inv_dim.color = Color(0.03, 0.03, 0.06, 0.6) ## Gece Sıvası lacivert karartma (madde 276)
		_mobile_inv_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mobile_inv_dim.visible = false
		_mobile_inv_dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
				if inventory_panel_instance.visible:
					_on_envanter_toggle())
		add_child(_mobile_inv_dim)
	## Envanter paneli PartyPanelLayer'da (katman 96, bkz. _ready) - karartma ve özellikler paneli de oraya, sırayla
	## karartma -> özellikler -> envanter (hepsi HUD düğmelerinin üstünde).
	var top_layer: Node = inventory_panel_instance.get_parent()
	## Sıra: karartma -> çanta -> özellikler (madde 276: ÖZELLİK sekmesinde özellikler çantanın ÜSTÜNDE, aynı alanda).
	for c in [_mobile_inv_dim, inventory_panel_instance, stats_panel_instance]:
		if c is Node and is_instance_valid(c) and top_layer != null:
			if c.get_parent() != top_layer:
				(c as Node).reparent(top_layer, false)
			top_layer.move_child(c, top_layer.get_child_count() - 1)
	var panel_rect := Rect2(x0 + rail_w + gap, y0, full_w, h)
	if stats_panel_instance.has_method("apply_mobile_layout"):
		stats_panel_instance.call("apply_mobile_layout", panel_rect)
	if inventory_panel_instance.has_method("apply_mobile_layout"):
		inventory_panel_instance.call("apply_mobile_layout", panel_rect)
	_ph_build_inv_rail(top_layer, Rect2(x0, y0, rail_w, h))
	## Ray karartmanın ÜSTÜNDE (eskiden karartma her yerleşimde sona alınıp rayı soluklaştırıyordu).
	if is_instance_valid(_ph_inv_rail) and _ph_inv_rail.get_parent() == top_layer and _mobile_inv_dim.get_parent() == top_layer:
		top_layer.move_child(_ph_inv_rail, _mobile_inv_dim.get_index() + 1)


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
	UIKit.style_button(b, "hud")
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
	## Madde 273: sabit yuvalar - sağ sütun R (üst) / E / Q (alt), sol sütun pasif (R hizası, küçük) / F (Q hizası). Açılmamış
	## yetenek gizli kalır ama yeri değişmez (MOBA düzeni). SkillBar yereli: 52 birim ikon x k = PH_SKILL px.
	var sz: float = SPIRIT_ICON_BASE_SIZE
	var k: float = PH_SKILL / sz
	var dx: float = PH_COL_GAP / k
	var dy1: float = (float(PH_SKILL_Y[0]) - float(PH_SKILL_Y[1])) / k
	var dy2: float = (float(PH_SKILL_Y[0]) - float(PH_SKILL_Y[2])) / k
	## Düğme boyutu ayarı (Ayarlar > DOKUNMATİK, %80-130): yuva merkezleri sabit, sadece düğmeler büyür/küçülür (130'da da
	## komşu yuvaya binmez: 162 x 1,3 = 211 < 212 satır / 216 sütun aralığı). Pasif düğme değil - ayara bağlı değil.
	var us: float = clampf(float(UISound.get("touch_button_scale_percent")) / 100.0, 0.8, 1.3)
	var slots: Array = [[skill3_icon, Vector2(dx, 0.0), us], [skill2_icon, Vector2(dx, dy1), us], [skill_icon, Vector2(dx, dy2), us],
			[spirit_icon, Vector2(0.0, dy2), us], [passive_icon, Vector2(0.0, 0.0), PH_PASSIVE_K]]
	var sig: String = "ph%d" % roundi(us * 100.0)
	for s: Array in slots:
		var c: Control = s[0]
		if c == null:
			continue
		var kk: float = float(s[2])
		var at: Vector2 = s[1]
		c.pivot_offset = Vector2.ZERO
		c.scale = Vector2.ONE * kk
		c.offset_left = at.x + sz * (1.0 - kk) * 0.5
		c.offset_top = at.y + sz * (1.0 - kk) * 0.5
		c.offset_right = c.offset_left + sz
		c.offset_bottom = c.offset_top + sz
		sig += "," + c.name + ("1" if c.visible else "0")
	if sig == _ability_layout_sig:
		return false
	_ability_layout_sig = sig
	return true


func _layout_mobile_hud() -> void:
	var bar: Control = get_node_or_null("SkillBar")
	if bar == null:
		return
	_ph_hide_cluster_bars()
	var b: Vector4 = _ph_bounds() ## x sol, y üst, z sağ, w alt
	## Yetenekler: SkillBar iki sütun x k (sol üst köşesi pasifin / F sütununun R hizası).
	var k: float = PH_SKILL / SPIRIT_ICON_BASE_SIZE
	var lx: float = b.z - PH_SKILL_X - PH_COL_GAP - PH_SKILL * 0.5
	var ty: float = b.w - float(PH_SKILL_Y[0]) - PH_SKILL * 0.5
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.pivot_offset = Vector2.ZERO
	bar.scale = Vector2.ONE * k
	bar.offset_left = roundf(lx)
	bar.offset_top = roundf(ty)
	bar.offset_right = bar.offset_left + (PH_COL_GAP + PH_SKILL) / k
	bar.offset_bottom = bar.offset_top + (float(PH_SKILL_Y[0]) - float(PH_SKILL_Y[2]) + PH_SKILL) / k
	_ability_layout_sig = ""
	_layout_mobile_ability_icons()
	## Minimap: sol üst, KARE, ahşap levha çerçeve + koyu iç kontur (minimap.gd square).
	var mm := Rect2(b.x + PH_EDGE, b.y + PH_EDGE, PH_MAP, PH_MAP)
	var inner: Rect2 = mm.grow(-PH_MAP_INSET)
	_ph_place(_ph_map_frame, mm)
	_ph_place(_ph_map_edge, inner.grow(3.0))
	var minimap: Control = get_node_or_null("MinimapControl")
	if minimap:
		minimap.set("square", true)
		var box: float = minimap.custom_minimum_size.x
		var s: float = inner.size.x / maxf(1.0, box - 4.0)
		minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
		minimap.pivot_offset = Vector2.ZERO
		minimap.scale = Vector2.ONE * s
		minimap.offset_left = inner.position.x - 2.0 * s
		minimap.offset_top = inner.position.y - 2.0 * s
		minimap.offset_right = minimap.offset_left + box
		minimap.offset_bottom = minimap.offset_top + box
	## Sohbet: minimapin sağında, üst hizada.
	_ph_place(mobile_chat_button, Rect2(mm.end.x + 16.0, mm.position.y, PH_BTN, PH_BTN))
	_ph_icon_fit(mobile_chat_button)
	## Sağ üst: ayar, altında çanta, solunda şerit.
	_ph_place(mobile_pause_button, Rect2(b.z - PH_RIGHT - PH_BTN, b.y + 20.0, PH_BTN, PH_BTN))
	_ph_icon_fit(mobile_pause_button)
	_layout_mobile_top_right()
	## Etkileşim: F sütununda, E'nin biraz üstünde (sadece yakındayken görünür - touch_controls).
	var ic := Vector2(b.z - PH_SKILL_X - PH_COL_GAP, b.w - PH_INTERACT_Y)
	_ph_place(mobile_interact_button, Rect2(ic - Vector2.ONE * PH_INTERACT * 0.5, Vector2.ONE * PH_INTERACT))
	if touch_controls:
		touch_controls.rest_center = Vector2(b.x + PH_JOY.x, b.w - PH_JOY.y)
	_fit_mobile_party()


## Telefonda grup paneli - kullanıcı bildirimi (2026-10-03): "bazı paneller bazı panellerin üstünde çıkıyor grup penceresi
## mesela". Eskiden minimapın altında SAĞ kenardaydı; sağ kenarı minimap + yetenek sütunu + görev penceresi de paylaştığı için
## 2-3 müttefikle Q/E/F düğmelerinin üstüne biniyordu. Artık SOL sütunda, altın göstergesinin altında (orası joysticke kadar
## boş). Kök sıfır genişlikte ve sağa yaslı (arka plan sola büyür, bkz. party_panel.gd) -> kök x = sol kenar + genişlik x ölçek.
## Satır sayısı arttıkça joystick alanına taşmasın diye küçülür (müttefik gelip gittikçe _process'ten yeniden çağrılır).
## 2026-10-04: grup paneli gizlenebilir - mobil oyunlardaki gibi grup SİMGELİ kare düğme, panelin ÜSTÜNDE (kullanıcı:
## "grup simgeli bi buton olacak oradan açılıp kapatılacak ... buton üstte olmalı"; yazılı "Grubu Gizle" reddedildi).
## Sohbet eskiden masaüstü yerinde, sol altta ufacık kalıp joystickin üstüne biniyordu; artık grup panelinin SAĞINDA (alt
## alta sığınca grup paneli çok küçülüyordu), m5x7 16 px x2 = 32 px keskin yazı. Grup kapalıyken sohbet sol kenara kayar.
const MOBILE_PARTY_SCALE := 0.8 ## x HUD_SCALE
const MOBILE_CHAT_K := 2.0 ## sohbet ölçeği (yazı 16 px -> 32 px, tam kat = keskin)
const MOBILE_CHAT_FONT := 16
const MOBILE_CHAT_W := 300.0 ## sohbet genişliği (ölçeksiz birim)
const MOBILE_CHAT_H := 138.0 ## ~3 satır + yazarken altta giriş kutusu (38)
const MOBILE_TOGGLE_SIZE := Vector2(56.0, 56.0) ## kare simge düğmesi (duraklat düğmesiyle aynı), ölçek HUD_SCALE
const MOBILE_STATS_MIN_W := 76.0 ## "Hasar" düğmesinin en dar hâli (yazı sığsın); genişliği panelin sağ kenarına kadar
## 16x16 düğme simgeleri - koddan üretilir, ayrı doku/import yok. Grup: önde bir, arkada iki kişi; sohbet: konuşma balonu.
const PARTY_ICON_MAP: Array[String] = [
	"................",
	"......####......",
	".....######.....",
	".##..######..##.",
	"####.######.####",
	"####.######.####",
	".##...####...##.",
	"................",
	".##...####...##.",
	"####.######.####",
	"####.######.####",
	"####.######.####",
	"####.######.####",
	".....######.....",
	".....######.....",
	"................",
]
const CHAT_ICON_MAP: Array[String] = [
	"................",
	"................",
	"..############..",
	".##############.",
	".##############.",
	".##############.",
	".###..#..#..###.",
	".###..#..#..###.",
	".##############.",
	".##############.",
	"..############..",
	"....###.........",
	"....##..........",
	"....#...........",
	"................",
	"................",
]
var _mobile_party_h: float = -1.0
var _mobile_party_open: bool = true


func _toggle_mobile_party() -> void:
	_mobile_party_open = not _mobile_party_open
	var party: Node = get_node_or_null("PartyPanelLayer/PartyPanel")
	if party and party.has_method("set_collapsed"):
		party.call("set_collapsed", not _mobile_party_open)
	if is_instance_valid(mobile_party_toggle):
		var ic: TextureRect = mobile_party_toggle.get_node_or_null("Icon") as TextureRect
		if ic:
			ic.texture = _pixel_icon_texture(CHEV_L_ICON_MAP if _mobile_party_open else CHEV_R_ICON_MAP)
	UISound.play_click()
	_fit_mobile_party()


func _pixel_icon_texture(map: Array[String], ink: Color = HudTheme.TEXT) -> Texture2D:
	## Telefon düğmeleri koyu ahşap ("hud") - simge açık krem (madde 207/273; eski koyu kahve mürekkep açık kite göreydi).
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in map.size():
		for x in map[y].length():
			if map[y][x] == "#":
				img.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(img)


## Kare ahşap düğme + ortasında 16x16 piksel simge (duraklat düğmesiyle aynı 56 birim).
func _make_mobile_icon_button(n: String, map: Array[String]) -> Button:
	var b: Button = _make_mobile_button(n, "")
	b.visible = false
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _pixel_icon_texture(map)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10.0
	icon.offset_top = 9.0
	icon.offset_right = -10.0
	icon.offset_bottom = -11.0
	b.add_child(icon)
	return b


## Joystick bölgesinde kalan dokunulabilir HUD: grup satırları (altın gönder) + açılır pencereleri, açıkken sohbet kutusu,
## taşan (kaydırılabilir) sohbet günlüğü - kullanıcı bildirimi (2026-10-05): sohbeti kaydırmak joystick'i de başlatıp karakteri
## yürütüyordu. Sığan (kaydırılmayan) sohbet joystick'e engel olmaz.
func _mobile_joy_exclude() -> Array:
	var out: Array = []
	var party: Node = get_node_or_null("PartyPanelLayer/PartyPanel")
	if party and party.has_method("touch_blocking_controls"):
		out.append_array(party.call("touch_blocking_controls"))
	if _chat_input and _chat_input.visible:
		out.append(_chat_input)
	if is_instance_valid(_ph_send_btn) and _ph_send_btn.visible:
		out.append(_ph_send_btn)
	if is_instance_valid(_ph_quick_chat) and _ph_quick_chat.visible:
		out.append(_ph_quick_chat)
	if _chat_scroll and is_instance_valid(_chat_scroll) and TouchScrollScript._scrollable(_chat_scroll):
		out.append(_chat_scroll)
	return out


func _open_mobile_stats() -> void:
	var party: Node = get_node_or_null("PartyPanelLayer/PartyPanel")
	if party == null or not party.has_method("toggle_stats_popup"):
		return
	## Grup kapalıyken sıralama penceresi (panelin çocuğu) görünmez - önce grubu aç.
	if not _mobile_party_open:
		_toggle_mobile_party()
	party.call("toggle_stats_popup", mobile_stats_button)


func _fit_mobile_party() -> void:
	## Madde 273: grup paneli minimapin ALTINDA, minimapla aynı genişlikte (PC party_panel x PH_TEAM_W / 270); altında kendi
	## "İstatistik" düğmesi; sağında katlama sekmesi (katlıyken portre sütunu + sekme sütunun yanında); son sohbet satırları
	## sekmenin sağında. Satırlar joystick halkasına inmez - sığmayanlar kaydırılır (set_max_list_height).
	var party: Control = get_node_or_null("PartyPanelLayer/PartyPanel") as Control
	if party == null:
		return
	var bg: Control = party.get_node_or_null("Background") as Control
	var b: Vector4 = _ph_bounds()
	var x0: float = b.x + PH_EDGE
	var top: float = b.y + PH_EDGE + PH_MAP + 16.0
	var w: float = bg.size.x if bg and bg.size.x > 0.0 else 270.0
	_mobile_party_h = bg.size.y if bg else 0.0
	var s: float = PH_TEAM_W / w
	var has_allies: bool = party.has_method("has_allies") and bool(party.call("has_allies"))
	var joy_top: float = b.w - PH_JOY.y - TouchControlsScript.JOY_RADIUS * MobileUIScript.HUD_SCALE - 24.0
	if party.has_method("set_footer_visible"):
		party.call("set_footer_visible", true)
	if party.has_method("set_footer_text"):
		party.call("set_footer_text", "İstatistik")
		party.call("set_footer_full_width", true)
	if party.has_method("set_max_list_height"):
		party.call("set_max_list_height", maxf(60.0, (joy_top - top) / s - 46.0)) ## 46: alt düğme + aralık (panel birimi)
	party.set_anchors_preset(Control.PRESET_TOP_LEFT)
	party.pivot_offset = Vector2.ZERO
	party.scale = Vector2.ONE * s
	party.offset_left = x0 + w * s ## kök sıfır genişlikte ve sağa yaslı (arka plan sola büyür)
	party.offset_right = party.offset_left
	party.offset_top = top
	party.offset_bottom = top
	var open: bool = _mobile_party_open
	var tab := Rect2(x0 + PH_TEAM_W + 6.0, top, PH_TAB.x, PH_TAB.y) if open else Rect2(x0 + 76.0, top + 6.0, PH_TAB.x, 60.0)
	if is_instance_valid(mobile_party_toggle):
		mobile_party_toggle.visible = has_allies
		_ph_place(mobile_party_toggle, tab)
		_ph_icon_fit(mobile_party_toggle, 32.0)
	if is_instance_valid(_ph_party_column):
		_ph_party_column.visible = has_allies and not open
		_ph_place(_ph_party_column, Rect2(x0 + 9.0, top, 60.0, maxf(80.0, joy_top - top)))
	if is_instance_valid(mobile_chat_button):
		mobile_chat_button.visible = has_allies or NetworkManager.is_multiplayer_active
	if is_instance_valid(mobile_stats_button):
		mobile_stats_button.visible = false
	var fx: float = (tab.end.x + 18.0) if has_allies else x0
	var chat_panel: Control = _chat_layer.get_node_or_null("ChatPanel") as Control if _chat_layer else null
	if chat_panel:
		chat_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		chat_panel.grow_vertical = Control.GROW_DIRECTION_END
		chat_panel.pivot_offset = Vector2.ZERO
		chat_panel.scale = Vector2.ONE * MOBILE_CHAT_K
		chat_panel.offset_left = fx
		chat_panel.offset_top = top + 10.0
		chat_panel.offset_right = fx + MOBILE_CHAT_W
		chat_panel.offset_bottom = top + 10.0 + MOBILE_CHAT_H


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
	## Madde 273: durum (buff/debuff) satırı sağ üst şeridin altında, şeridin sağ kenarına yaslı.
	if not is_instance_valid(status_bar):
		return
	if status_bar.get_parent() != self:
		status_bar.reparent(self, false)
	var b: Vector4 = _ph_bounds()
	var k: float = 1.2
	var w: float = 360.0
	var right: float = b.z - PH_STRIP_RIGHT
	status_bar.pivot_offset = Vector2.ZERO
	status_bar.scale = Vector2.ONE * k
	status_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_bar.offset_left = roundf(right - w * k)
	status_bar.offset_right = status_bar.offset_left + w
	status_bar.offset_top = b.y + 26.0 + PH_STRIP_H + 10.0
	status_bar.offset_bottom = status_bar.offset_top + STATUS_ROW_HEIGHT
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
	status_bar.offset_bottom = _icons_lo.y - (DOCK_PAD_TOP + 6.0) / k
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
	## Seviye rozeti altın halka + koyu yüz (tools/gen_hud_tema.py) - rakam açık, kontursuz.
	level_label.add_theme_color_override("font_color", HudTheme.TEXT)
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
	## Masaüstünde özellikler "Kahraman Çantası"nın içinde (madde 341); telefonda ayrı panel (rayın ÖZELLİK sekmesi).
	stats_panel_instance.visible = now_visible and MobileUIScript.enabled
	if _mobile_inv_dim:
		_mobile_inv_dim.visible = now_visible
	if is_instance_valid(_ph_inv_rail): ## telefon: ray + sekme (ÇANTA'dan açılır)
		_ph_inv_rail.visible = now_visible
		_ph_set_inv_tab(0)


## Envanter panelindeki X'e basılınca (inventory_panel.gd "closed" sinyali)
## eşleştiği istatistik panelini de birlikte kapatır.
func _on_envanter_closed() -> void:
	stats_panel_instance.visible = false
	if _mobile_inv_dim:
		_mobile_inv_dim.visible = false
	if is_instance_valid(_ph_inv_rail):
		_ph_inv_rail.visible = false


## ---------------------------------------------------------------- telefon envanter yan rayı (madde 276)
const ShopDarkKit := preload("res://scripts/shop_dark_kit.gd")
const ReadingUiWatcherScript := preload("res://scripts/reading_ui_watcher.gd")
var _ph_inv_rail: Control = null
var _ph_inv_tabs: Array = []
var _ph_inv_kit = null


func _ph_build_inv_rail(layer: Node, r: Rect2) -> void:
	if is_instance_valid(_ph_inv_rail) or layer == null:
		if is_instance_valid(_ph_inv_rail):
			_ph_inv_rail.position = r.position
			_ph_inv_rail.size = r.size
		return
	_ph_inv_kit = ShopDarkKit.new(ShopDarkKit.PAL_NIGHT)
	var bg := PanelContainer.new()
	bg.name = "PhoneInventoryRail"
	bg.theme = _ph_inv_kit.theme()
	var sb: StyleBoxFlat = _ph_inv_kit.sb(_ph_inv_kit.c("panel"), _ph_inv_kit.c("line_hi"), 3, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	bg.add_theme_stylebox_override("panel", sb)
	bg.visible = inventory_panel_instance.visible
	var col: VBoxContainer = _ph_inv_kit.v(14)
	bg.add_child(col)
	var back: Button = _ph_inv_kit.rail_back(108.0)
	back.tooltip_text = "Kapat"
	back.pressed.connect(_on_envanter_toggle)
	col.add_child(back)
	_ph_inv_tabs.clear()
	for i in 2:
		var t: Button = _ph_inv_kit.rail_tab(["ÇANTA", "ÖZELLİK"][i], [ShopDarkKit.G_BAG, ShopDarkKit.G_STAR][i], i == 0, 108.0, 110.0)
		t.pressed.connect(_ph_set_inv_tab.bind(i))
		col.add_child(t)
		_ph_inv_tabs.append(t)
	layer.add_child(bg)
	bg.position = r.position
	bg.size = r.size
	_ph_inv_rail = bg
	UISound.connect_all_buttons(bg)


func _ph_set_inv_tab(i: int) -> void:
	for j in _ph_inv_tabs.size():
		_ph_inv_kit.set_rail_tab(_ph_inv_tabs[j], j == i)
	if inventory_panel_instance.visible:
		stats_panel_instance.visible = i == 1
	## ÖZELLİK sekmesinde çanta (aynı alanda, altta) görünmesin - özellikler levhasının içinden seçiliyordu.
	inventory_panel_instance.modulate.a = 0.0 if i == 1 else 1.0


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


## Sandık sırası efekti (bkz. chest_pass_fx.gd): yerel oyuncunun alttaki can çubuğunun ekrandaki (canvas) ortası; HUD henüz
## kurulmadıysa / çubuk gizliyse Vector2.INF.
func get_own_bar_center() -> Vector2:
	for c: Control in [dock_hp_bar, dock_frame]:
		if is_instance_valid(c) and c.is_visible_in_tree():
			return c.get_global_transform_with_canvas() * (c.size * 0.5)
	return Vector2.INF


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
		return
	## Envanter kısayolu (klavye I / kumanda Select - bkz. GameManager "inventory") ve açıkken geri ile kapatma.
	## Geri ile kapatınca basış "kullanıldı" işaretlenir: main.gd duraklatma menüsünü aynı basışla açmasın (bkz.
	## GameManager.mark_ui_cancel_consumed).
	if inventory_panel_instance == null or (_chat_input and _chat_input.visible):
		return
	var inv_open: bool = inventory_panel_instance.visible
	if event.is_action_pressed("inventory") and (inv_open or not (get_tree().paused or GameManager.is_any_blocking_panel_open())):
		_on_envanter_toggle()
		get_viewport().set_input_as_handled()
	elif inv_open and event.is_action_pressed("ui_cancel"):
		GameManager.mark_ui_cancel_consumed()
		_on_envanter_toggle()
		get_viewport().set_input_as_handled()


## Telefon: sohbet yazma kutusu açıkken DIŞINA dokunmak kutuyu kapatır. Godot'da odaktaki bir LineEdit dışarı tıklanınca
## odağı bırakmaz; ekran klavyesi geri hareketiyle kapatılınca kutu açık kalıp `is_chat_typing` oyuncuyu (hareket + yetenek)
## kilitliyordu - çıkış yolu yoktu (kullanıcı bildirimi 2026-10-05: "takılı kalıp oyunu oynamama engel oluyor").
## Sohbet düğmesi kendi aç/kapa mantığını _process'te yürütür (burada yok sayılır, yoksa kapatıp hemen yeniden açardı).
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not (event as InputEventScreenTouch).pressed:
		return
	var pos: Vector2 = (event as InputEventScreenTouch).position
	var on_chat_btn: bool = is_instance_valid(mobile_chat_button) and mobile_chat_button.visible \
			and mobile_chat_button.get_global_rect().has_point(pos)
	## Telefon hızlı sohbet penceresi (madde 273): dışına dokunmak kapatır; sohbet düğmesi kendi aç/kapasını _process'te yürütür.
	if is_instance_valid(_ph_quick_chat) and _ph_quick_chat.visible and not on_chat_btn \
			and not _ph_quick_chat.get_global_rect().has_point(pos):
		_ph_quick_chat.visible = false
	if _chat_input == null or not _chat_input.visible:
		return
	if _chat_input.get_global_rect().has_point(pos):
		return
	if is_instance_valid(_ph_send_btn) and _ph_send_btn.visible and _ph_send_btn.get_global_rect().has_point(pos):
		return
	if on_chat_btn:
		return
	_close_chat_input()


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
	if MobileUIScript.enabled:
		## Telefonda sohbet parmakla kaydırılır (touch_scroll.gd); varsayılan kaydırma çubuğu (36 px, tema yok) kısa
		## mesajların yanında panelin en sağında yalnız başına duruyordu ("çok sağa kayık") ve parmağı joystick'ten çalıyordu.
		_chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
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
	if MobileUIScript.enabled:
		_chat_input.placeholder_text = "Mesajını yaz..."
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
	if MobileUIScript.enabled:
		## Telefon (madde 273): yazarken sağda ahşap "Gönder" (ekran klavyesinin Enter'ı "Bitti" olabiliyor). Odak almaz - yoksa
		## dokununca kutu odağı bırakıp metni silerdi (focus_exited); dokunuş _input'ta "kutunun dışı" sayılmaz.
		_ph_send_btn = Button.new()
		_ph_send_btn.name = "ChatSend"
		_ph_send_btn.text = "Gönder"
		_ph_send_btn.focus_mode = Control.FOCUS_NONE
		_ph_send_btn.visible = false
		UIKit.style_button(_ph_send_btn, "hud", false, 16)
		_ph_send_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_ph_send_btn.offset_left = -84.0
		_ph_send_btn.offset_top = -36.0
		_ph_send_btn.offset_right = 0.0
		_ph_send_btn.offset_bottom = 0.0
		_ph_send_btn.pressed.connect(func() -> void: _on_chat_input_submitted(_chat_input.text))
		panel.add_child(_ph_send_btn)
		_chat_input.offset_right = -90.0
	if MobileUIScript.enabled:
		_fit_mobile_party.call_deferred() ## telefonda sohbet sol sütunda (bkz. _fit_mobile_party)


func _open_chat_input() -> void:
	if not _chat_input:
		return
	_chat_input.visible = true
	_chat_input.text = ""
	_chat_input.grab_focus()
	if is_instance_valid(_ph_send_btn):
		_ph_send_btn.visible = true
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
	## Odağı da bırak: telefonda ekran klavyesi ancak böyle kapanır (focus_exited -> bu fonksiyona bir kez daha girer, zararsız).
	if _chat_input.has_focus():
		_chat_input.release_focus()
	_chat_input.visible = false
	_chat_input.text = ""
	if is_instance_valid(_ph_send_btn):
		_ph_send_btn.visible = false
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
		below_y = _left_stack_bottom() + 10.0
	var left_x: float = gold_indicator.get_global_rect().position.x if gold_indicator else 20.0
	_debug_button.position = Vector2(left_x, below_y)


func _unlock_debug_mode() -> void:
	var first: bool = not GameManager.debug_mode_unlocked
	GameManager.debug_mode_unlocked = true
	if _debug_button:
		_debug_button.visible = true
	if first:
		NetworkManager.announce_debug_action("DEBUG MODUNU AÇTI (her şey açık)")


## main.gd _on_chat_message_received tarafından (hem yerel yankı hem uzak
## oyunculardan gelen mesajlar için) çağrılır.
func append_chat_message(sender_name: String, text: String) -> void:
	if not _chat_log:
		return
	var line: Control
	if MobileUIScript.enabled:
		## Telefon (madde 273): harita üstünde düz piksel yazı + koyu kahve dış hat, ad altın, mesaj krem.
		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = true
		rl.scroll_active = false
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_font_size_override("normal_font_size", MOBILE_CHAT_FONT)
		rl.add_theme_color_override("default_color", HudTheme.TEXT)
		rl.add_theme_color_override("font_outline_color", HudTheme.OUTLINE)
		rl.add_theme_constant_override("outline_size", 4)
		rl.text = "[color=#%s]%s:[/color] %s" % [HudTheme.PRICE.to_html(false), sender_name.replace("[", "[lb]"), text.replace("[", "[lb]")]
		line = rl
		_ph_recent.append([sender_name, text])
		while _ph_recent.size() > 2:
			_ph_recent.pop_front()
		var window_open: bool = is_instance_valid(_ph_quick_chat) and _ph_quick_chat.visible
		if window_open:
			_ph_quick_chat.call("set_recent", _ph_recent)
		elif sender_name != NetworkManager.local_player_name:
			_ph_unread += 1
			_ph_update_badge()
	else:
		var lb := Label.new()
		lb.text = "%s: %s" % [sender_name, text]
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.add_theme_font_size_override("font_size", 18)
		lb.add_theme_color_override("font_color", Color(0.93, 0.9, 0.85, 1.0))
		lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lb.add_theme_constant_override("shadow_offset_x", 1)
		lb.add_theme_constant_override("shadow_offset_y", 1)
		line = lb
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
	## Telefon: grup panelinin boyu müttefik gelip gittikçe değişir - yeniden sığdır (bkz. _fit_mobile_party).
	if MobileUIScript.enabled and Engine.get_process_frames() % 20 == 0:
		var bg: Control = get_node_or_null("PartyPanelLayer/PartyPanel/Background") as Control
		var pp: Node = get_node_or_null("PartyPanelLayer/PartyPanel")
		var allies_now: bool = pp != null and pp.has_method("has_allies") and bool(pp.call("has_allies"))
		if (bg and not is_equal_approx(bg.size.y, _mobile_party_h)) or (is_instance_valid(mobile_party_toggle) 				and mobile_party_toggle.visible != allies_now):
			_fit_mobile_party()
	if MobileUIScript.enabled and touch_controls != null:
		if Input.is_action_just_pressed(&"mobile_party_toggle"):
			_toggle_mobile_party()
		if Input.is_action_just_pressed(&"mobile_chat_open"):
			## Madde 273: sohbet düğmesi hızlı sohbet penceresini açar/kapatır (yazma kutusu açıksa onu kapatır).
			if _chat_input and _chat_input.visible:
				_close_chat_input()
			else:
				_ph_toggle_quick_chat()
		if Input.is_action_just_pressed(&"mobile_party_stats"):
			_open_mobile_stats()
		_ph_tick(delta)
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
				## Büyücü Kız "Efsunlu Büyü" (Q finali, 2026-10-04): efsunlu varyasyonu taşıyan E/R butonu parıldar; efsunlu yetenek
				## diğer setteyse Q butonu sönük parıldar (set değiştir ipucu) - skill_icon.gd set_enchant_glow. Diğer karakterlerde 0.
				if ic and is_instance_valid(ic) and ic.has_method("set_enchant_glow") and player.has_method("is_buyucu_slot_enchanted"):
					var glow_on: bool = player.is_buyucu_slot_enchanted(pair[0])
					ic.set_enchant_glow((0.5 if pair[0] == "skill" else 1.0) if glow_on else 0.0)
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
				## İkon dizisi SET sırasındadır (characters.gd skill2_variation_icons: [Arcane Lanet, Hortum]) - varyasyon id'si değil set.
				var v_idx: int = player.buyucu_variation_set if "buyucu_variation_set" in player else 0
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
			## Cadı pasifi (Şans Tılsımı, 2026-10-13): eksik candan o an gelen şans.
			elif player.has_method("get_cadi_passive_luck") and GameManager.selected_char_id == 15:
				passive_icon.set_stack_count(player.get_cadi_passive_luck())
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
				## characters.gd "skill3_variation_icons" SET sırasındadır: [Don Nova, Meteor Patlaması] (2026-10-04'ten beri).
				var v_icons_r: Array = Characters.get_def(4).get("skill3_variation_icons", [])
				var v_local_idx_r: int = player.buyucu_variation_set if "buyucu_variation_set" in player else 0
				if v_local_idx_r >= 0 and v_local_idx_r < v_icons_r.size():
					var v_tex_r: Texture2D = _cached_texture(v_icons_r[v_local_idx_r])
					if v_tex_r:
						skill3_icon.custom_texture = v_tex_r
				skill3_icon.update_state(player.get_skill3_progress(), player.is_skill3_active(), player.get_buyucu_variation_cooldown_remaining_r(), player.get_skill3_active_fraction())
			## Cadı R (İksir Çantası, 2026-10-13): yük boncukları + SIRADAKİ iksirin ikonu/adı/açıklaması (kullanıcı: "rastgele olsun
			## fakat sonraki iksirin ne olduğunu görelim") - player.gd get_cadi_r_hud_state. Standart skill3 makinesi kullanılmaz.
			elif GameManager.selected_char_id == 15 and player.has_method("get_cadi_r_hud_state"):
				var cadi_r: Dictionary = player.get_cadi_r_hud_state()
				skill3_icon.skill_id = player.get_skill3_id()
				skill3_icon.name_override = str(cadi_r.get("name", ""))
				skill3_icon.desc_override = str(cadi_r.get("desc", ""))
				var cadi_tex: Texture2D = _cached_texture(str(cadi_r.get("icon", "")))
				if cadi_tex and skill3_icon.custom_texture != cadi_tex:
					skill3_icon.custom_texture = cadi_tex
				var cadi_has_charge: bool = int(cadi_r.get("charges", 0)) > 0
				skill3_icon.update_state(1.0 if cadi_has_charge else float(cadi_r.get("fraction", 0.0)), false, 0.0 if cadi_has_charge else float(cadi_r.get("remaining", 0.0)), 0.0)
				if skill3_icon.has_method("set_charges"):
					skill3_icon.set_charges(int(cadi_r.get("charges", 0)), int(cadi_r.get("max", 0)), float(cadi_r.get("fraction", 0.0)))
			else:
				skill3_icon.name_override = ""
				skill3_icon.desc_override = ""
				skill3_icon.update_state(player.get_skill3_progress(), player.is_skill3_active(), player.skill3_timer, player.get_skill3_active_fraction())
		## Ruhani Yetenek ikonu (F) - kendi durum makinesi (bkz. player.gd get_spirit_*).
		if spirit_icon and player.has_method("get_spirit_progress"):
			_place_spirit_icon()
			spirit_icon.update_state(player.get_spirit_progress(), player.is_spirit_active(), player.get_spirit_cooldown_remaining(), player.get_spirit_active_fraction())
