extends CanvasLayer

## Sandıklar artık otomatik/sırayla açıldığı için (bkz. main.gd
## _try_open_next_pending_chest) bu menü kapandığında bir sonrakinin
## açılabilmesi gerekiyor - bu sinyal tam olarak bunun için.
signal closed

var cards_container: HBoxContainer = null
var title_label: Label = null

var _player: Node = null
var _chest_tier: int = 0 ## "KADEME" - hangi dünya evresinden gelen sandık (bkz. CHEST_TITLES), eşya güç tier'ından AYRI bir kavram
## Elit sandık (kullanıcı isteği 2026-10-07: "elit sandıklardan sadece epik item çıkacak çünkü efsunları kaldırmıştık"): havuz
## sadece EPİK eşyalar (bkz. item_pool), kart epik çerçeveli, sandık/ışık elit görünümlü. Normal sandık: sadece parça.
var _is_elite: bool = false
## Kullanıcı isteği: "4 lü tier sistemi bundan sonra sandıklara da geliyor,
## sandık gelince üç tane gelmek yerine 1 tane gelecek ve çıkan eşyanın
## tier'ı olacak" - bu, çekilen TEK eşyanın TierSystem tier'ı (1-4,
## Sıradan/Nadir/Epik/Efsanevi). setup() doldurur, _build_card()/
## _on_al_pressed bunu okur.
var _reward_tier: int = 1
## bkz. _play_chest_open_sequence - açılış animasyonu (chest_open_anim.gd); ödül kartı bunun ağzından fırlar.
var _chest_icon: Control = null
## Sandık (kartın ARKASINDA, yerleşimden bağımsız), kartın arkasındaki ışık katmanı ve kıvılcım katmanı (en üstte).
var _stage: Control = null
var _rays_layer: Control = null
var _fx_layer: Control = null
var _rays: Node = null

## Kullanıcı isteği: "bir oyuncu sandık seçerken diğer oyuncularda ve sandık
## seçen kişide 25 saniyelik bekleme süresi olmuyor, onun da bekleme süresi
## olması gerekiyor, tıpkı level kartı seçme ekranı gibi" - level_up_screen.gd
## _on_level_up_timer_tick/_auto_pick_random_card ile AYNI desen: süre
## dolduğunda henüz karar verilmediyse rastgele (uygun/açık) bir karta
## otomatik "AL" basılmış gibi davranılır, kimse sonsuza kadar herkesi
## bekletemez.
var _has_chosen: bool = false
@onready var countdown_panel: PanelContainer = $CenterContainer/VBox/CountdownPanel
@onready var countdown_label: Label = $CenterContainer/VBox/CountdownPanel/VBox/CountdownLabel

# Chest tier titles and borders
const CHEST_TITLES := {
	0: "KADEME I-II SANDIK",
	1: "KADEME III-IV SANDIK",
	2: "KADEME V-VI SANDIK",
	3: "KADEME VII-VIII SANDIK",
	4: "KADEME IX-X SANDIK",
	5: "KADEME XI+ SANDIK"
}

## Kullanıcı isteği (2026-09-25): "sandık açarken daha iyi ve ödüllendirici heyecan uyandırıcı sandık açma animasyonu" -
## eski 4 karelik kapak açılışı (chest_tier_*.png) yerine yeni piksel sayfa + ışık/ses/flaş (bkz. chest_open_anim.gd).
const ChestOpenAnim := preload("res://scripts/chest_open_anim.gd")
const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const RewardReveal := preload("res://scripts/reward_reveal.gd")
const RewardRays := preload("res://scripts/reward_rays.gd")
## KULLANICI BİLDİRİMİ (2026-09-21): "Sandık açıldığında sandık özelliklerini gösteren kart ufakken yazılar kocaman kalıyor bu
## yüzden doğru düzgün görünmüyor yazıları." KÖK NEDEN: kart içeriği kenardan sadece 16 px içeride başlıyordu ama çerçeve dokusunun
## (TierSystem.FRAME_TEXTURES) süslü kenarları/mücevheri çok daha içeride - başlık çerçevenin üstüne biniyor, açıklama çerçeve
## çizgilerinin dışına taşıyor, AL/SAT butonları alt çerçeveyi örtüyordu; uzun açıklamalı eşyalarda ise sabit 24 px yazı kartı
## uzatıyordu. Artık içerik, çerçevenin İÇİNDEKİ alana oturuyor (level_up_screen.tscn Content kutusu 28/54/28/52'ydi ama yan çubuklara
## değiyordu - burada biraz daha dar); yazı boyutları o alana göre seçiliyor (_fit_card_texts: isim tek satıra, açıklama alana SIĞANA kadar küçülür).
const CARD_SIZE := Vector2(300, 480)
## 2026-09-25: kartlar savaş kartı dokusuna geçti (tools/gen_menu_kit.py tier_card) - içerik artık kenar paylarıyla değil,
## dokunun sabit bölgelerine (TierCardFx.HEADER_RECT / CREST_CENTER / RIBBON_RECT / PLAQUE_INNER_RECT) yerleşiyor. Yazılar
## m5x7'nin keskin durduğu 32 px'te (üst satır/kurdele), açıklama levhada 24 px'ten başlayıp sığana kadar küçülür.
const TierCardFx := preload("res://scripts/tier_card_fx.gd")
const CARD_TIER_FONT_SIZE := 32
const CARD_POWER_FONT_SIZE := 24
const CARD_NAME_FONT_SIZE := 32
const CARD_NAME_MIN_FONT_SIZE := 20
const CARD_DESC_FONT_SIZE := 24
const CARD_DESC_MIN_FONT_SIZE := 13
const CARD_ICON_SIZE := 96.0
const CARD_BUTTON_HEIGHT := 44.0
const CARD_BUTTON_FONT_SIZE := 24
## Telefon (kullanıcı isteği 2026-10-03: "sandık açma ekranını da mobille uyumlu hale getir"): level/efsun ekranlarıyla aynı
## kural (mobile_ui.gd CHOICE_*) - kart 3x yerine k katı (5/3 -> 500x800, doku tam 5x sanat px), kart içi bölgeler k ile
## ölçeklenir, yazılar telefon boylarında; AL sağ kenarda, SAT sol kenarda dikey büyük düğmeler; sandık animasyonu da k kat.
## Masaüstünde k = 1, her şey eskisi gibi.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
var _k: float = 1.0
var _side_holder: Control = null
var _side_buttons: Array = []


func _kr(r: Rect2) -> Rect2:
	return Rect2((r.position * _k).round(), (r.size * _k).round())


func _mobile() -> bool:
	return _k > 1.0

## DÜZELTME/YENİ ÖZELLİK (kullanıcı isteği: "bundan sonra yere düşen
## sandıklardan rasgele 3 silah düşecek 3 silahtan birini seçmemiz
## gerekecek... silah almak istemeyen silahı satabilir" - kullanıcının
## seçtiği yaklaşım: "hem eşya hem silah karışık gelsin", yani her sandık
## kartı ayrı ayrı rastgele bir EŞYA ya da bir SİLAH olabilir). Bu liste
## shop_panel.gd'deki WEAPON_KEYS/UPGRADE_NAMES/WEAPON_ICON_TEXTURES ile
## BİREBİR aynı verinin bilinçli bir kopyası (WEAPON_COST_BASE aşağıda,
## shop_panel.gd'nin ESKİ COPY_COST_BASE taban fiyatlarının bir kopyasıydı -
## dükkan fiyatlandırması kullanıcı isteğiyle silah sayısına göre kademeli
## hale geldiğinden ayrıldı, ama sandık ÖNİZLEME değeri için bu sabit taban
## fiyatlar hâlâ doğru/yeterli, kasıtlı olarak DEĞİŞTİRİLMEDİ) - shop_panel.gd
## bir class_name TANIMLAMADIĞI için oradaki const'lara güvenli/açık bir
## şekilde erişmenin en basit yolu bu (diğer script'lerdeki paralel
## const kopyalama deseniyle tutarlı).
const WEAPON_KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic", "gokkusagi", "mizrak", "kalkan", "yinyang"]
const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç", "gokkusagi": "Gökkuşağı Asası", "mizrak": "Mızrak", "kalkan": "Kalkan", "yinyang": "Yin Yang Kitabı",
}
const WEAPON_ICON_TEXTURES := {
	"dagger": "res://assets/weapons/base_knife/icon_v2.png",
	"fire_staff": "res://assets/weapons/fire/firestaff_icon_v3.png",
	"lightning_staff": "res://assets/weapons/lightning/icon_v3.png",
	"tabanca": "res://assets/weapons/tabanca/icon_v2.png",
	"tuftuf": "res://assets/weapons/tuftuf/icon_v2.png",
	"tufek": "res://assets/weapons/tufek/icon.png",
	"arcane": "res://assets/weapons/arcane/icon_v3.png",
	"yay": "res://assets/weapons/yay/draw1.png",
	"crossbow": "res://assets/weapons/crossbow/icon.png",
	"boomerang": "res://assets/weapons/boomerang/icon.png",
	"buz_asasi": "res://assets/weapons/buz_asasi/icon_v3.png",
	"fisek": "res://assets/weapons/fisek/icon.png",
	"pence": "res://assets/weapons/pence/icon.png",
	"topuz": "res://assets/weapons/topuz/icon.png",
	"uzunkilic": "res://assets/weapons/uzunkilic/icon.png",
	"gokkusagi": "res://assets/weapons/zanaat/gokkusagi_L1.png",
	"mizrak": "res://assets/weapons/zanaat/mizrak_L1.png",
	"kalkan": "res://assets/weapons/zanaat/kalkan_L1.png",
	"yinyang": "res://assets/weapons/zanaat/yinyang_L1.png",
}
const WEAPON_COST_BASE := {
	"dagger": 60, "fire_staff": 80, "lightning_staff": 120, "tabanca": 100, "tuftuf": 90, "tufek": 100, "arcane": 110, "yay": 100,
	"crossbow": 100, "boomerang": 110, "buz_asasi": 95, "fisek": 120, "pence": 90, "topuz": 105, "uzunkilic": 100, "gokkusagi": 120, "mizrak": 100,
	"kalkan": 100, "yinyang": 110,
}

func _get_game_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GameManager")

func _get_ui_sound() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/UISound")

const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
## Sandık kart seçimi açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


## Elit sandığın kart çerçevesi: TierSystem 3 = "Epik" (Items.KADEME_EPIK ile aynı ad/renk).
const ELITE_CARD_TIER := 3


## Sandıktan çıkabilecek eşyalar: normal sandık = parçalar (1. kademe), elit sandık = epikler (2. kademe). Efsanevi hiçbir
## sandıktan çıkmaz. Sadece destekçilere çıkan eşyalar (Items.is_support_only) char_id destekçi karakter değilse elenir.
## player verilirse: sınırına ulaşmış bir stat içeren eşyalar elenir (2026-10-13; hepsi elenirse süzme uygulanmaz - sandık boş açılmasın, eşya satılabilir).
## Elit sandık: zaten SAHİP olunan epikler elenir (2026-10-14, epikler tekil - bkz. items.gd; hepsine sahipse süzme uygulanmaz, kart satılabilir).
static func item_pool(elite: bool, char_id: int = -1, player: Node = null) -> Array:
	var kademe: int = Items.KADEME_EPIK if elite else Items.KADEME_PARCA
	var pool: Array = Items.KEYS.filter(func(k) -> bool:
		return Items.kademe(str(k)) == kademe and (not Items.is_support_only(str(k)) or Items.is_ally_support_char(char_id)))
	if elite:
		var fresh: Array = pool.filter(func(k) -> bool: return not Items.owns(GameManager.owned_items, str(k)))
		if not fresh.is_empty():
			pool = fresh
	if player != null and is_instance_valid(player) and player.has_method("item_has_capped_stat"):
		var useful: Array = pool.filter(func(k) -> bool: return not player.item_has_capped_stat(str(k)))
		if not useful.is_empty():
			return useful
	return pool


func setup(player: Node, chest_tier: int, elite: bool = false) -> void:
	_player = player
	_chest_tier = chest_tier
	_is_elite = elite
	_k = MobileUIScript.choice_card_scale(get_viewport(), CARD_SIZE, 1, 0.0)
	## Bu sandığın yerden gelen altını (varsa) şimdi alınır: kartın üstünde yazar, kart inince oradan uçar.
	_chest_gold = GameManager.pop_pending_chest_gold(elite)

	if not title_label:
		title_label = get_node_or_null("CenterContainer/VBox/Title")
	if not cards_container:
		cards_container = get_node_or_null("CenterContainer/VBox/CardsContainer")
	if cards_container:
		cards_container.add_theme_constant_override("separation", 20)

	## 2026-09-24: oyun içi bej kit (menülerle aynı dil, bir ton koyu): sıcak karartma, kurdele başlık, kit penceresinde geri
	## sayım; kart içi yazılar koyu (CanvasLayer temayı aktarmaz - kök Control'e verilir).
	if has_node("Dim"):
		($Dim as ColorRect).color = Color(0.12, 0.07, 0.03, 0.62)
	var center_node: Control = get_node_or_null("CenterContainer") as Control
	if center_node:
		center_node.theme = UIKit.theme()
	if title_label:
		title_label.add_theme_stylebox_override("normal", UIKit.panel_style("banner"))
		UIKit.style_label(title_label, UIKit.FS_TITLE, UIKit.C_TEXT, 0)
		title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title_label.custom_minimum_size = Vector2(0, 72)
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cd_panel: PanelContainer = get_node_or_null("CenterContainer/VBox/CountdownPanel") as PanelContainer
	if cd_panel:
		cd_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
		var wl: Label = cd_panel.get_node_or_null("VBox/WaitingLabel") as Label
		if wl:
			wl.add_theme_color_override("font_color", UIKit.C_TEXT)
		var cl: Label = cd_panel.get_node_or_null("VBox/CountdownLabel") as Label
		if cl:
			cl.add_theme_color_override("font_color", UIKit.C_GOLD)

	# Update Title
	if title_label:
		title_label.text = "ELİT SANDIK" if _is_elite else CHEST_TITLES.get(_chest_tier, "EŞYA SANDIĞI")
	if _mobile():
		_setup_phone_chrome()

	# Clear existing children just in case
	if cards_container:
		for child in cards_container.get_children():
			child.queue_free()
		## Sandık açılış animasyonu bitene kadar (bkz. _play_chest_open_
		## sequence) kart alanı boş kalıyor - ödül kartı sandığın İÇİNDEN
		## çıkıyormuş gibi görünecek, o yüzden animasyon bitene kadar bu
		## container gizli.
		cards_container.visible = false

	## Kullanıcı isteği (İKİNCİ tur): "sandık gelince üç tane gelmek yerine 1
	## tane gelecek ve çıkan eşyanın tier'ı olacak çünkü bundan sonra
	## 'ekstralar' eşyalarının tierları olacak." - eskiden 3 aday sunulup biri
	## seçiliyordu (bkz. altındaki eski "silah çıkma ihtimalini kaldır" notu,
	## HÂLÂ geçerli: sadece items.gd'deki pasif eşyalar, silah havuzu yok);
	## artık TEK bir eşya + TEK bir rastgele TierSystem tier'ı (1-4,
	## level_up_screen.gd'deki kartlarla AYNI nadir dağılımı, bkz.
	## tier_system.gd) çekilip doğrudan gösteriliyor. "SAT" butonu (bkz.
	## _build_card) hâlâ duruyor - istemiyorsa altına çevirebilir.
	## 2026-10-02: ekstralar silindi (bkz. items.gd) - liste boşken sandık açılış animasyonunu oynatıp BOŞ çıkar
	## (kullanıcı seçimi: "Boş açılsın"), bkz. _reveal_reward_card "empty" dalı.
	## 2026-10-02 yeni eşya sistemi: sandıktan SADECE parça (1. kademe) çıkar, eski Tier1-4 güç çarpanı yok (kullanıcı
	## seçimi) - kart çerçevesi parçanın kademesi (Tier 1 rengi). 2026-10-07: ELİT sandıktan sadece EPİK çıkar (item_pool).
	var parts: Array = item_pool(_is_elite, GameManager.selected_char_id, _player)
	var item_key: String = str(parts[randi() % parts.size()]) if not parts.is_empty() else ""
	_reward_tier = ELITE_CARD_TIER if _is_elite else 1
	var candidate: Dictionary = {"type": "item", "key": item_key} if item_key != "" else {"type": "empty"}

	# Connect UI sounds
	var ui_sound = _get_ui_sound()
	if ui_sound and ui_sound.has_method("connect_all_buttons"):
		ui_sound.connect_all_buttons(self)

	_play_chest_open_sequence(candidate)


## Kullanıcı isteği: "Sandıklar açılırken öncesinde sandık ekrana gelecek
## (biraz görünür olmalı boyut olarak) açma animasyonu görünecek ve içinden
## çıkan eşya kartı sandığın içinden animasyonlu olarak çıkarak oyuncuya
## gösterilecek." - 2026-09-25'ten beri tam açılış animasyonu (chest_open_anim.gd: sallanma, ışık, patlama, altınlar).
## İKİNCİ tur (aynı gün: "kart içinden fırlamış gibi görünmüyor"): sandık artık VBox'ta değil, kartın ARKASINDAKİ ayrı bir
## katmanda (_stage) ekranın ortasında durur - eskiden kart eklenince VBox yeniden yerleşip sandığı kaydırıyordu ve kart
## animasyonun tamamı + bekleme bittikten sonra sadece büyüyerek beliriyordu. Artık kapağın patladığı an (burst) kart
## sandığın ağzından fırlar (reward_reveal.gd), indiğinde parlar ve arkasında tier'a göre ışık huzmeleri yanar.
func _play_chest_open_sequence(candidate: Dictionary) -> void:
	if not cards_container:
		_reveal_reward_card(candidate) ## güvenlik ağı - sahne beklenmedik şekilde eksikse animasyonsuz devam et
		return
	var center_node: Node = get_node_or_null("CenterContainer")
	_stage = _make_layer("ChestStage")
	_rays_layer = _make_layer("RewardRays")
	if center_node:
		## Sıra: Dim, sandık, ışık, kart (CenterContainer) - kart her şeyin önünde.
		move_child(_stage, center_node.get_index())
		move_child(_rays_layer, center_node.get_index())
	_fx_layer = _make_layer("RewardFx")

	## Işığın rengi çıkacak eşyanın nadirliği (_reward_tier, setup'ta çekildi) - kart görünmeden önce ipucu.
	var anim: Control = ChestOpenAnim.new()
	anim.setup(_is_elite, _reward_tier)
	## Kart paralardan SONRA çıkıyor: ödül çınlaması kapak patlayınca değil kart ekrana inip oturunca çalar (kullanıcı isteği 2026-10-08).
	anim.chime_on_burst = false
	_stage.add_child(anim)
	var view: Vector2 = get_viewport().get_visible_rect().size
	anim.size = anim.custom_minimum_size
	anim.position = (view - anim.size) * 0.5
	_chest_icon = anim
	_chest_center = anim.position + anim.size * Vector2(0.5, 0.52) ## RewardReveal.chest_mouth ile aynı nokta (ölçek animasyonundan bağımsız)

	anim.pivot_offset = anim.custom_minimum_size * 0.5
	anim.scale = Vector2(0.6, 0.6) * _k
	anim.modulate.a = 0.0
	var pop_in := create_tween()
	pop_in.set_parallel(true)
	pop_in.set_ease(Tween.EASE_OUT)
	pop_in.set_trans(Tween.TRANS_BACK)
	pop_in.tween_property(anim, "modulate:a", 1.0, 0.2)
	pop_in.tween_property(anim, "scale", Vector2.ONE * _k, 0.3)
	anim.burst.connect(func() -> void:
		if is_instance_valid(self):
			_on_chest_burst(candidate, anim)
	, CONNECT_ONE_SHOT)


## Kapak patladığı an (kullanıcı isteği 2026-10-08: "sandık açma animasyonunda önce para animasyonu görünsün sonra item çıksın, tıpkı
## item satarkenki sandıktan altın çıkma animasyonu gibi"): sandığın vereceği altın ÖNCE ağzından fışkırıp panele uçar, eşya kartı paraların
## fırlaması bitince çıkar (uçuştaki son paralar kart çıkarken sürer). Altın yoksa (görev/debug sandığı) kart hemen çıkar; oyuncu animasyonu
## atladıysa (tıklama/tuş) kısa bir an sonra.
const CHEST_GOLD_CARD_DELAY := 0.2 ## son para fırladıktan sonra kartın çıkmasına kalan ek süre
const CHEST_GOLD_CARD_DELAY_MAX := 1.0 ## büyük altında bile eşya en geç bu kadar sonra çıkar
const CHEST_GOLD_SKIPPED_DELAY := 0.15


static func chest_card_delay(gold: int, skipped: bool) -> float:
	if gold <= 0:
		return 0.0
	if skipped:
		return CHEST_GOLD_SKIPPED_DELAY
	return minf(GoldRewardFx.burst_duration(gold) + CHEST_GOLD_CARD_DELAY, CHEST_GOLD_CARD_DELAY_MAX)


func _on_chest_burst(candidate: Dictionary, anim: Control) -> void:
	var delay: float = chest_card_delay(_chest_gold, bool(anim.get("skipped")))
	if _chest_gold > 0:
		_release_chest_gold(_chest_center, true)
	if delay > 0.0:
		await get_tree().create_timer(delay, true).timeout
		if not is_instance_valid(self) or is_queued_for_deletion():
			return
	_reveal_reward_card(candidate)


## Sandığın ekrandaki ağzı - SAT altını buradan fışkırır (bkz. _on_sat_pressed). Animasyonsuz yolda ekranın ortası.
var _chest_center: Vector2 = Vector2(960.0, 560.0)
var _card_icon: TextureRect = null ## kartın eşya ikonu (SAT'ta parçalanır)


func _make_layer(layer_name: String) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## Kart sandığın ağzından fırlar (reward_reveal.gd fly_out), AL/SAT satırları kart indikten sonra belirir; inişte parıltı +
## tier ışığı, tier 2+ kartta boşta parlama döngüsü. Sandık kart indikten sonra aşağı kayarak söner.
func _reveal_reward_card(candidate: Dictionary) -> void:
	if str(candidate.get("type", "")) == "empty":
		_reveal_empty_chest()
		return
	if cards_container:
		var column = _build_card(candidate)
		## Yazı boyutu yerleşim bittikten sonra ayarlanıyor (bkz. _fit_card_texts) - o bir kareye kadar ayarsız yazı görünmesin.
		column.modulate.a = 0.0
		cards_container.add_child(column)
		cards_container.visible = true
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
		if not _mobile():
			_fit_card_texts(column)
		var card_panel: Control = column.get_child(0) as Control
		var buttons: Array = []
		for b in _side_buttons:
			if is_instance_valid(b):
				(b as Control).modulate.a = 0.0
				buttons.append(b)
		for i in range(1, column.get_child_count()):
			var b: Control = column.get_child(i) as Control
			if b:
				b.modulate.a = 0.0
				buttons.append(b)
		column.modulate.a = 1.0
		var tier: int = int(card_panel.get_meta("reward_tier", _reward_tier)) if card_panel else _reward_tier
		if card_panel and is_instance_valid(_rays_layer):
			_rays = RewardRays.new()
			_rays_layer.add_child(_rays)
			_rays.setup(card_panel, card_panel.size if _mobile() else CARD_SIZE * _k, 3.0 * _k, tier, _is_elite)
		if card_panel:
			## Sütunun tamamı uçar (kart + gizli butonlar); pivot kartın ortası.
			var mouth: Vector2 = RewardReveal.chest_mouth(_chest_icon) if is_instance_valid(_chest_icon) else card_panel.get_global_rect().get_center()
			RewardReveal.launch_sparks(_fx_layer, mouth, tier, _is_elite)
			var tw: Tween = RewardReveal.fly_out(self, column, mouth, 0.0, 0.08, card_panel.position + card_panel.size * 0.5)
			tw.tween_callback(func() -> void:
				if not is_instance_valid(card_panel):
					return
				var frame: TextureRect = card_panel.get_node_or_null("Frame") as TextureRect
				RewardReveal.land_fx(self, card_panel, frame, tier, _is_elite, _fx_layer, _rays)
				ChestOpenAnim.play_reward_chime(get_tree(), tier, _is_elite)
				TierCardFx.start_idle_shine(self, frame, tier, 1.2)
				for b in buttons:
					if is_instance_valid(b):
						create_tween().tween_property(b, "modulate:a", 1.0, 0.2)
				_hide_chest()
				_release_chest_gold(card_panel.get_global_transform_with_canvas() * (card_panel.size * 0.5))
			)
		else:
			_release_chest_gold(_chest_center)
	else:
		if is_instance_valid(_chest_icon):
			_hide_chest()
		_release_chest_gold(_chest_center)

	## bkz. dosya başındaki _has_chosen notu - geri sayım main.gd tarafından
	## zaten başlatılmış durumda (bkz. _try_open_next_pending_chest
	## NetworkManager.start_chest_countdown), burada sadece gösterilip
	## dinleniyor - level_up_screen.gd _ready()'deki AYNI desen. Açılış
	## animasyonu bitene kadar BAĞLANMIYOR ki 25sn süresi tam o birkaç
	## onda saniyelik pencerede dolarsa henüz var olmayan bir karta
	## otomatik basmaya çalışılmasın (bkz. _on_countdown_tick).
	## Ayarlar > Otomatik Kart Seçimi (auto_pick.gd): kart indikten sonra AL (slot varsa) / SAT kendiliğinden basılır.
	if AutoPickScript.enabled():
		get_tree().create_timer(AutoPickScript.DELAY, true).timeout.connect(_auto_pick_best_card)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.chest_countdown_tick.connect(_on_countdown_tick)
		if countdown_panel:
			countdown_panel.visible = NetworkManager.chest_countdown_active
			if countdown_panel.visible and countdown_label:
				countdown_label.text = "%ds" % int(ceil(NetworkManager.chest_countdown))


## Ekstra listesi boş (bkz. items.gd): kapak açılınca kart yerine "Sandık boş" yazısı belirir, sandık söner, menü
## kendiliğinden kapanır.
const EMPTY_CHEST_HOLD := 1.6


## Kullanıcı isteği (2026-10-02): "sandık açılırken kart çıkar çıkmaz ordan gitmesini istiyorum altın barına" - bu
## sandığın yerden gelen altın payı (GameManager.pending_chest_gold, bkz. chest_drop.gd _award_chest_gold) setup'ta alınır.
## Aynı gün: "sandık kartlarında vereceği altın da yazsın kartın üstünde ve gelecek altınlar o altın göstergesinden gitsin
## altın sayısı paneline" - kartın üst kenarında altın rozeti (_build_gold_badge), kart inince paralar rozetten uçar.
## Görev/debug sandığının bekleyen altını yoksa rozet de yok. Ekran paralar fırlamadan kapanırsa altın yine verilir.
var _chest_gold: int = 0
var _chest_gold_released: bool = false
var _gold_badge: Control = null
const GoldCoinFrames := preload("res://assets/pickups/gold/gold_coin_frames.tres")


## from_chest: paralar sandığın ağzından (kapak patlayınca, bkz. _on_chest_burst); değilse (güvenlik ağları) kartın altın satırından.
func _release_chest_gold(from_screen: Vector2, from_chest: bool = false) -> void:
	if _chest_gold_released:
		return
	_chest_gold_released = true
	if _chest_gold > 0:
		if not from_chest and is_instance_valid(_gold_badge) and _gold_badge.is_inside_tree():
			from_screen = _gold_badge.get_global_transform_with_canvas() * (_gold_badge.size * 0.5)
		GoldRewardFx.give_now_from_screen(get_tree(), _chest_gold, from_screen)


func _exit_tree() -> void:
	## Güvenlik ağı: kart inmeden ekran kapandıysa (ör. oyun bitti) sandığın altını kaybolmasın.
	if not _chest_gold_released and _chest_gold > 0 and is_inside_tree():
		_release_chest_gold(_chest_center)


## Parşömen levhanın altında (açıklamanın altındaki boş alanda) altın satırı: altın ikonu + "+120 Altın". Kart sütunuyla
## birlikte sandıktan fırlar; kart inince paralar bu satırdan altın paneline uçar. (İlk deneme kartın üst kenarındaki koyu
## rozetti - eşyanın adını örtüyordu.)
func _build_gold_badge(parent: Control) -> Control:
	var row := HBoxContainer.new()
	row.name = "GoldRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.texture = GoldCoinFrames.get_frame_texture(&"spin", 0)
	coin.custom_minimum_size = Vector2(48.0, 48.0) if _mobile() else Vector2(32.0, 32.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin)
	var lbl := Label.new()
	lbl.text = "+%d Altın" % _chest_gold
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(lbl, 40 if _mobile() else CARD_DESC_FONT_SIZE, UIKit.C_GOLD, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	parent.add_child(row)
	return row


func _reveal_empty_chest() -> void:
	_release_chest_gold(_chest_center)
	_has_chosen = true
	var lbl := Label.new()
	lbl.text = "Sandık boş"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(lbl, UIKit.FS_TITLE, UIKit.C_CREAM, 6)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var parent: Control = _fx_layer if is_instance_valid(_fx_layer) else null
	if parent:
		parent.add_child(lbl)
	else:
		add_child(lbl)
	lbl.position = Vector2(0.0, _chest_center.y - 150.0)
	lbl.size = Vector2(view.x, 64.0)
	lbl.modulate.a = 0.0
	create_tween().tween_property(lbl, "modulate:a", 1.0, 0.2)
	_hide_chest()
	## Metoda bağlı (lambda değil): menü bu arada başka yoldan kapanıp silinirse bağlantı kendiliğinden düşer.
	get_tree().create_timer(EMPTY_CHEST_HOLD, true).timeout.connect(_on_empty_chest_done)


func _on_empty_chest_done() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_close()


## Açık sandığı kart indikten sonra aşağı kaydırıp söndürür.
func _hide_chest() -> void:
	if not is_instance_valid(_chest_icon):
		return
	var chest: Control = _chest_icon
	var tw := create_tween().set_parallel(true)
	tw.tween_property(chest, "modulate:a", 0.0, 0.3).set_delay(0.1)
	tw.tween_property(chest, "position:y", chest.position.y + 40.0, 0.4).set_delay(0.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(chest):
			chest.queue_free()
	)


## Kullanıcı isteği (2026-09-24): "sandık açma kartında 1 tuşu alma tuşunu 2 tuşu satma tuşunu tetikleyecek şekilde
## kısayollansın. butonlara dokunma" - level_up_screen.gd _unhandled_input'la AYNI desen: tuş, ilgili butonun pressed
## sinyalini (fare tıklamasıyla birebir aynı yol) tetikler; butonların kendisi/görünümü değişmedi. Kart henüz açılış
## animasyonundayken (kart yok), AL devre dışıyken (SLOTLAR DOLU) ya da sohbet yazılırken hiçbir şey yapmaz.
func _unhandled_input(event: InputEvent) -> void:
	if _has_chosen or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var meta_key: String = ""
	match event.keycode:
		KEY_1, KEY_KP_1:
			meta_key = "al_button"
		KEY_2, KEY_KP_2:
			meta_key = "sat_button"
	if meta_key == "" or not cards_container:
		return
	if _player and is_instance_valid(_player) and bool(_player.get("is_chat_typing")):
		return
	for card in cards_container.get_children():
		if not card.has_meta(meta_key):
			continue
		var btn: Button = card.get_meta(meta_key)
		if is_instance_valid(btn) and not btn.disabled:
			get_viewport().set_input_as_handled()
			btn.pressed.emit()
		return


func _on_countdown_tick(remaining: float) -> void:
	if countdown_panel:
		countdown_panel.visible = true
	if countdown_label:
		countdown_label.text = "%ds" % int(ceil(remaining))
	if remaining <= 0.0 and not _has_chosen:
		_auto_pick_random_card()


## Süre dolduğunda henüz karar verilmediyse (bkz. yukarıdaki _on_countdown_tick)
## uygun (slotu dolu olmayan) kartlardan rastgele biri "AL" tıklanmış gibi
## seçilir - hiçbiri uygun değilse (tüm slotlar doluysa) sandık ödülü boşa
## harcanıp menü kapatılır, herkes sonsuza kadar bu karara takılı kalmaz.
const AutoPickScript := preload("res://scripts/auto_pick.gd")


## Otomatik seçim: tek kart - AL basılabiliyorsa AL (eşya/silah almak satmaktan hep değerli), slotlar doluysa SAT (ödül boşa gitmesin).
func _auto_pick_best_card() -> void:
	if not is_instance_valid(self) or _has_chosen or not cards_container:
		return
	for card in cards_container.get_children():
		if card.has_meta("al_button"):
			var al: Button = card.get_meta("al_button")
			if is_instance_valid(al) and not al.disabled:
				al.pressed.emit()
				return
	for card in cards_container.get_children():
		if card.has_meta("sat_button"):
			var sat: Button = card.get_meta("sat_button")
			if is_instance_valid(sat) and not sat.disabled:
				sat.pressed.emit()
				return
	_auto_pick_random_card()


func _auto_pick_random_card() -> void:
	if _has_chosen or not cards_container:
		return
	var eligible: Array = []
	for card in cards_container.get_children():
		if card.has_meta("al_button"):
			var al: Button = card.get_meta("al_button")
			if is_instance_valid(al) and not al.disabled:
				eligible.append(al)
	if eligible.is_empty():
		_close()
		return
	var al_btn: Button = eligible[randi() % eligible.size()]
	al_btn.pressed.emit()

## DÜZELTME/YENİ ÖZELLİK: artık ham bir item_key yerine {"type","key"}
## şeklinde bir aday alıyor - bkz. setup() üstündeki not. type=="weapon"
## için isim/ikon/maliyet WEAPON_* sabitlerinden, type=="item" için (eskisi
## gibi) Items.get_def()'ten okunuyor.
## Kullanıcı isteği: "çıkan eşyanın tier'ı olacak" - _reward_tier (1-4, bkz.
## setup()) SADECE eşyalar (is_weapon==false) için geçerli; kartın çerçeve
## rengini VE yeni bir tier-adı etiketini (Sıradan/Nadir/Epik/Efsanevi,
## TierSystem ile level atlama kartlarıyla AYNI görsel dil) belirler. Gerçek
## güç çarpanı (bkz. Items.ITEM_TIER_POWER) _on_al_pressed'e kadar taşınır.
func _build_card(candidate: Dictionary) -> Control:
	if _mobile():
		return _build_phone_card(candidate)
	var card_type: String = candidate.get("type", "item")
	var item_key: String = candidate.get("key", "")
	var is_weapon: bool = card_type == "weapon"
	var item_def: Dictionary = {} if is_weapon else Items.get_def(item_key)
	var display_name: String = WEAPON_NAMES.get(item_key, item_key.capitalize()) if is_weapon else item_def.get("name", item_key.capitalize())
	var desc_text: String = "Yeni bir silah - kalıcı olarak edinilir." if is_weapon else Items.describe(item_key)
	var icon_path: String = WEAPON_ICON_TEXTURES.get(item_key, "") if is_weapon else Items.icon_path(item_key)
	var cost_base: int = WEAPON_COST_BASE.get(item_key, 80) if is_weapon else Items.cost(item_key)
	var power_mult: float = 1.0

	## 2026-09-25 savaş kartı (bkz. scripts/tier_card_fx.gd): kart dokusu artık sabit bölgelere bölünmüş (üst satır / kalkan
	## arması / tier kurdelesi / parşömen levha). Eşyaların açıklamaları uzun (250 karaktere kadar) - AL/SAT butonları levhaya
	## sığmayıp açıklamayı okunmaz boyuta küçülteceği için kartın ALTINA taşındı: CardsContainer'a eklenen öğe artık kart +
	## buton satırlarından oluşan bir sütun (name_label/desc_label/al_button/sat_button meta'ları sütunda - _unhandled_input,
	## _auto_pick_random_card ve _fit_card_texts onları cards_container çocuklarından okur).
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)

	# 1. Main Card Container
	var card := PanelContainer.new()
	column.add_child(card)
	## Kullanıcı isteği: "sandık ödülü seçim kartı level kartlarıyla aynı
	## boyutlarda görünsün" - level_up_screen.tscn'deki Card1/2/3 ile birebir
	## aynı boyut. DÜZELTME (kullanıcı isteği: "kartları büyütmekle ilgili
	## değişikliği geri al") - level kartları 300x480'e döndürülünce bu da
	## eşleşmeye devam etsin diye AYNI şekilde 300x480'e döndürüldü (eski
	## 238x406'ya DEĞİL - o değer zaten level kartlarıyla eşleşmiyordu, bu
	## yüzden ilk etapta düzeltilmişti).
	card.custom_minimum_size = CARD_SIZE * _k # Match level up card dimensions
	card.set_meta("glow_card_size", CARD_SIZE * _k)
	card.set_meta("glow_pad", TierCardFx.GLOW_PAD * _k)

	var sb := StyleBoxFlat.new()
	## Kullanıcı isteği: "sandık ödülü seçme kartı da tiera bağlı olarak level
	## atlama kartları gibi olmalı (aynı kartları kullan arkaplan için)" ve
	## (İKİNCİ tur) "tierı olmayanlar tier 1 kartı kullanmalı" - HER kart
	## (eşya/silah fark etmeksizin) artık düz renk yerine TierSystem.FRAME_
	## TEXTURES (level_up_screen.gd ile PAYLAŞILAN aynı 4 doku) bir "Frame"
	## TextureRect olarak arkaya ekleniyor, panelin kendi StyleBoxFlat'ı
	## SADECE gölge için var, tamamen saydam. Silahın (is_weapon) tier'ı
	## olmadığı için varsayılan olarak tier 1 (Sıradan, gri) kullanılır.
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(12)
	## DÜZELTME (kullanıcı isteği: "sandık seçim ekranı kartlarına dışlarına
	## çerçeve eklemeni istiyorum hafif gölgesi olsun ve panele sızsın, böyle
	## çok çiğ duruyorlar") - kartın kenarlığının hemen dışına, arkaplana
	## doğru yumuşakça yayılan hafif bir gölge eklendi.
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(3, 4)
	card.add_theme_stylebox_override("panel", sb)

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## KRİTİK: expand_mode verilmezse TextureRect'in minimum boyutu
	## DOKUNUN GERÇEK piksel boyutu (499x665) olur ve bu, anchor'ların
	## kartı küçültme isteğini EZER - kart devasa bir kareye dönüşür
	## (bkz. merchant_shop_screen.gd _build_card'daki AYNI hata/notu -
	## seyyar satıcı ekranında kullanıcı ekran görüntüsüyle yakalandı).
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	TierCardFx.apply_frame(frame, _reward_tier if not is_weapon else 1)
	card.set_meta("reward_tier", _reward_tier if not is_weapon else 1)
	card.add_child(frame)

	## Bölgeler TierCardFx'teki dikdörtgenlere mutlak konumla yerleşiyor (PanelContainer çocuğu düz bir Control kartı kaplar).
	var layout := Control.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(layout)

	# 2. Üst satır: eşya/silah adı (koyu tier zemini üstünde krem yazı). Uzunsa _fit_card_texts tek satıra sığana dek küçültür.
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.position = _kr(TierCardFx.HEADER_RECT).position
	name_lbl.size = _kr(TierCardFx.HEADER_RECT).size
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(name_lbl, _name_fs(), UIKit.C_CREAM, 4)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = false
	layout.add_child(name_lbl)
	## Ağaca girmeden önce Label en küçük boyutunu varsayılan temanın büyük yazısıyla ölçüp kutusunu büyütüyor (375x70) ve bir
	## daha küçültmüyor - doğru boyut, kart ağaca eklendikten sonra (ertelenmiş) yeniden verilir.
	name_lbl.set_deferred("size", _kr(TierCardFx.HEADER_RECT).size)
	column.set_meta("name_label", name_lbl)

	# 3. İkon: kalkan armasının parşömen yüzünde (eşya ikonları 32x32 -> 3x = kartın kendi 3 px piksel yoğunluğu).
	var icon_rect := TextureRect.new()
	icon_rect.size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE) * _k
	icon_rect.position = (TierCardFx.CREST_CENTER * _k - icon_rect.size * 0.5).round()
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(icon_rect)
	_card_icon = icon_rect ## SAT'ta bu ikon parçalanır (bkz. _on_sat_pressed)

	# 4. Kurdele: tier adı (silahların tier'ı yok - "Silah").
	var tier_lbl := Label.new()
	tier_lbl.text = "Silah" if is_weapon else Items.KADEME_NAMES[Items.kademe(item_key) - 1]
	tier_lbl.position = _kr(TierCardFx.RIBBON_RECT).position
	tier_lbl.size = _kr(TierCardFx.RIBBON_RECT).size
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(tier_lbl, 48 if _mobile() else CARD_TIER_FONT_SIZE, UIKit.C_CREAM, 4)
	layout.add_child(tier_lbl)
	tier_lbl.set_deferred("size", _kr(TierCardFx.RIBBON_RECT).size) ## bkz. name_lbl notu

	# 5. Parşömen levha: güç yüzdesi (eşyalar) + açıklama.
	var vbox := VBoxContainer.new()
	vbox.position = _kr(TierCardFx.PLAQUE_INNER_RECT).position
	vbox.size = _kr(TierCardFx.PLAQUE_INNER_RECT).size
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(vbox)

	## (2026-09-21) Label -> RichTextLabel (level atlama kartlarındaki Desc ile aynı tür): autowrap'lı bir Label metnin yüksekliğini
	## kartın MİNİMUM boyutuna yansıtıp kartı uzatıyordu; fit_content'siz RichTextLabel ise kalan alana sabit sığar ve
	## _fit_card_texts uzun açıklamayı o alana SIĞANA kadar küçültür.
	var desc_lbl := RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.fit_content = false
	desc_lbl.scroll_active = false
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.text = "[center]%s[/center]" % desc_text.replace("[", "[lb]")
	desc_lbl.add_theme_color_override("default_color", UIKit.C_TEXT)
	_set_desc_font_size(desc_lbl, _desc_fs())
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)
	column.set_meta("desc_label", desc_lbl)

	## Sandığın vereceği altın: parşömenin altında satır (bkz. _build_gold_badge).
	if _chest_gold > 0:
		_gold_badge = _build_gold_badge(vbox)

	# Check slots limit (SİLAH ve EŞYA için AYRI limitler - bkz. is_weapon)
	var has_slots: bool = true
	var gm = _get_game_manager()
	if is_weapon:
		if _player and gm and "owned_weapons" in gm:
			var max_w: int = 3
			if _player.has_method("get_max_owned_weapons"):
				max_w = _player.get_max_owned_weapons()
			has_slots = gm.owned_weapons.size() < max_w
	elif _player and gm and "owned_items" in gm:
		var part_slots: int = 1
		if _player.has_method("get_max_item_slots"):
			part_slots = _player.get_max_item_slots()
		has_slots = Items.purchase_block_reason(item_key, gm.owned_items, part_slots, {"consume": []}) == ""

	## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni
	## istiyorum" - eski yeşil (Al)/kırmızı (Sat) renk ayrımı kaldırıldı,
	## artık oyundaki HER buton gibi ShopPanel'in paylaşılan ahşap plaka
	## stiline sahipler (bkz. shop_panel.gd _apply_wood_button_style).
	
	# 7. Al Button
	## Kullanıcı isteği: "alma ve satma butonlarındaki fontlar dahil" - level
	## atlama kartlarının en küçük kart-içi fontuyla (CountLabel, 28) aynı
	## boyuta getirildi. Sonraki istek ("kartların boyutunu %30 küçült ...
	## butonlar bu değişikliğe uyumlu olmalı"): buton yüksekliği kartla
	## birlikte küçüldü (50->44) ama büyüyen 28px fontu hâlâ rahat sığdıracak
	## kadar bırakıldı.
	var al_btn := Button.new()
	al_btn.custom_minimum_size = Vector2(0, CARD_BUTTON_HEIGHT)
	al_btn.add_theme_font_size_override("font_size", CARD_BUTTON_FONT_SIZE)
	## DÜZELTME (kullanıcı isteği: "butonlardaki yazıların rengini beyaz
	## yapıp dışlarına siyah kontür ekle") - eskiden burada krem rengi bir
	## font_color override'ı vardı, artık kaldırıldı ki tüm butonlarla AYNI
	## şekilde temanın (theme.tres) beyaz+siyah kontürlü varsayılanını alsın.
	## 2026-09-24: AL = onay (adaçayı), SAT = ten - kit butonları, koyu yazı.
	UIKit.style_button(al_btn, "green", false, CARD_BUTTON_FONT_SIZE)
	if has_slots:
		al_btn.text = "AL"
	else:
		al_btn.text = "SLOTLAR DOLU"
		al_btn.disabled = true
	al_btn.pressed.connect(_on_al_pressed.bind(candidate, cost_base, power_mult))
	if _mobile():
		al_btn.text = "AL" if has_slots else "SLOTLAR\nDOLU"
		_add_side_button(al_btn, false, 64)
	else:
		column.add_child(al_btn)
	## bkz. _auto_pick_random_card - süre dolduğunda hangi kartların hâlâ
	## seçilebilir ("AL" tıklanabilir) olduğunu bulmak için doğrudan referans.
	column.set_meta("al_button", al_btn)

	# 8. Sat Button
	var refund_gold: int = int(round(cost_base * Items.SELL_REFUND_RATIO))
	var sat_btn := Button.new()
	sat_btn.custom_minimum_size = Vector2(0, CARD_BUTTON_HEIGHT)
	sat_btn.add_theme_font_size_override("font_size", CARD_BUTTON_FONT_SIZE)
	## bkz. al_btn üstündeki ayni not - font_color override'i kaldirildi.
	UIKit.style_button(sat_btn, "wood", false, CARD_BUTTON_FONT_SIZE)
	sat_btn.text = "SAT (+%d Altın)" % refund_gold
	sat_btn.pressed.connect(_on_sat_pressed.bind(item_key, refund_gold))
	if _mobile():
		sat_btn.text = "SAT\n+%d Altın" % refund_gold
		_add_side_button(sat_btn, true, 40)
	else:
		column.add_child(sat_btn)
	column.set_meta("sat_button", sat_btn) ## bkz. _unhandled_input (2 kısayolu)
	
	return column

## Telefon: AL / SAT ekranın kenarında (karta değil ekrana bağlı - kart sandıktan uçarken düğmeler yerinde bekler).
func _add_side_button(btn: Button, left: bool, fs: int) -> void:
	if _side_holder == null:
		_side_holder = Control.new()
		_side_holder.name = "SideButtons"
		_side_holder.theme = UIKit.theme()
		_side_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		_side_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_side_holder)
	## Kullanıcı bildirimi (2026-10-03): "butonları çok kenarda" - tek kartlı ekranda düğmeler ekran kenarında değil, kartın
	## hemen iki yanında (kart ekranın ortasında, 500 px; düğmeler kartın 48 px dışında).
	var view: Vector2 = get_viewport().get_visible_rect().size
	var bw: float = 280.0
	var bh: float = 300.0
	var half: float = CARD_SIZE.x * _k * 0.5 + 48.0
	var x: float = view.x * 0.5 - half - bw if left else view.x * 0.5 + half
	var r := Rect2(roundf(x), roundf(view.y * 0.5 + 36.0 - bh * 0.5), bw, bh)
	_side_holder.add_child(btn)
	btn.custom_minimum_size = Vector2.ZERO
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", fs)
	btn.position = r.position
	btn.size = r.size
	_side_buttons.append(btn)


func _name_fs() -> int:
	return 48 if _mobile() else CARD_NAME_FONT_SIZE


func _desc_fs() -> int:
	return 40 if _mobile() else CARD_DESC_FONT_SIZE


static func _set_desc_font_size(desc_lbl: RichTextLabel, font_size: int) -> void:
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		desc_lbl.add_theme_font_size_override(key, font_size)


## Kart yerleşimi bittikten SONRA (etiketlerin gerçek boyutu belli) yazıları kartın iç alanına sığdırır: isim tek satıra sığana
## kadar küçülür (alt sınır CARD_NAME_MIN_FONT_SIZE, o da yetmezse alt satıra kayar); açıklama CARD_DESC_FONT_SIZE'dan başlayıp
## metnin yüksekliği ayrılan alana SIĞANA kadar (alt sınır CARD_DESC_MIN_FONT_SIZE) küçülür. Kısa metinler tam boyutta kalır.
func _fit_card_texts(card: Control) -> void:
	var name_lbl: Label = card.get_meta("name_label", null) as Label
	if name_lbl and is_instance_valid(name_lbl) and name_lbl.size.x > 0.0:
		var font: Font = name_lbl.get_theme_font("font")
		var fs: int = _name_fs()
		while fs > CARD_NAME_MIN_FONT_SIZE and font.get_string_size(name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_lbl.size.x:
			fs -= 1
		name_lbl.add_theme_font_size_override("font_size", fs)
		if font.get_string_size(name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_lbl.size.x:
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc_lbl: RichTextLabel = card.get_meta("desc_label", null) as RichTextLabel
	if desc_lbl and is_instance_valid(desc_lbl) and desc_lbl.size.y > 0.0:
		var dfs: int = _desc_fs()
		_set_desc_font_size(desc_lbl, dfs)
		while dfs > CARD_DESC_MIN_FONT_SIZE and float(desc_lbl.get_content_height()) > desc_lbl.size.y:
			dfs -= 1
			_set_desc_font_size(desc_lbl, dfs)


## DÜZELTME/YENİ ÖZELLİK: artık candidate dict alıyor ({"type","key"}, bkz.
## setup() üstündeki not) - type=="weapon" ise bedava bir silah kopyası
## veriliyor (shop_panel.gd _on_buy_copy ile AYNI desen ama gold_HARCAMADAN -
## sandık ödülü ücretsizdir, tıpkı eşyalar gibi), type=="item" ise eskisi
## gibi davranıyor.
## power_mult: bkz. _build_card üstündeki not - sandıktan çekilen eşyanın
## tier'ına göre güç çarpanı (Items.ITEM_TIER_POWER), player.buy_item()'a
## AYNEN iletilir VE owned_items kaydına "power" olarak yazılır ki eşya
## envanterden satılınca (bkz. player.gd remove_owned_item) AYNI çarpanla
## geri alınsın - yoksa Tier 2+ bir eşya satıldığında fazlası kalıcı kalırdı.
func _on_al_pressed(candidate: Dictionary, item_cost: int, power_mult: float = 1.0) -> void:
	_has_chosen = true
	if not _player or not is_instance_valid(_player):
		_close()
		return

	var gm = _get_game_manager()
	if not gm:
		_close()
		return

	var item_key: String = candidate.get("key", "")
	if candidate.get("type", "item") == "weapon":
		var max_w: int = 3
		if _player.has_method("get_max_owned_weapons"):
			max_w = _player.get_max_owned_weapons()
		if gm.owned_weapons.size() >= max_w or gm.owns_weapon(item_key):
			return
		## shop_panel.gd _on_buy_copy ile AYNI sıra: önce deftere (owned_weapons)
		## ekle, sonra gerçek silah node'unu spawn et - tek fark burada gold
		## hiç harcanmıyor (sandık ödülü).
		gm.owned_weapons.append(EnchantDefs.new_weapon_entry(item_key, 1, 0))
		if _player.has_method("buy_weapon_copy"):
			_player.buy_weapon_copy(item_key, 1)
		_close()
		return

	## Parça slotu kontrolü + kayıt player.acquire_item'da (tüketimsiz - sandık parçası bedava).
	if _player.has_method("acquire_item") and not _player.acquire_item(item_key, {"cost": 0, "consume": [], "full": item_cost}, 0):
		return

	_close()

func _on_sat_pressed(_item_key: String, refund_amount: int) -> void:
	_has_chosen = true
	## Kullanıcı isteği (2026-10-08): "item satınca itemin parçalanıp altına dönüşme animasyonu olsun, sandıktan altın çıkma yerine" -
	## kartın üstündeki eşya ikonu parçalanır, parçalar altın paraya dönüp sol üstteki altın paneline uçar (gold_reward_fx.gd
	## give_shattered - altını da o ekler; menü hemen kapanır, animasyon sahnede sürer). Ikon bulunamazsa (beklenmedik) eski sandık altını.
	var icon: TextureRect = _card_icon if is_instance_valid(_card_icon) and _card_icon.texture != null and _card_icon.is_inside_tree() else null
	if icon != null:
		var xf: Transform2D = icon.get_global_transform_with_canvas()
		var top_left: Vector2 = xf * Vector2.ZERO
		var bottom_right: Vector2 = xf * icon.size
		GoldRewardFx.give_shattered(get_tree(), refund_amount, (top_left + bottom_right) * 0.5, icon.texture, (bottom_right - top_left).abs())
	else:
		GoldRewardFx.give_from_screen(get_tree(), refund_amount, _chest_center, &"chest")
	_spawn_gold_floating_text(refund_amount)
	_close()

func _spawn_gold_floating_text(amount: int) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var FloatingTextScene = load("res://scenes/floating_text.tscn")
	if FloatingTextScene:
		var ft = FloatingTextScene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.follow_target = _player
		ft.follow_offset = Vector2(0, -30)
		ft.global_position = _player.global_position + Vector2(0, -30)
		ft.setup("+%d" % amount, Color(1.0, 0.82, 0.2), true)

func _close() -> void:
	if NetworkManager.chest_countdown_tick.is_connected(_on_countdown_tick):
		NetworkManager.chest_countdown_tick.disconnect(_on_countdown_tick)
	get_tree().paused = false
	closed.emit()
	queue_free()
## ---------------------------------------------------------------- TELEFON (madde 276; kullanıcı onayı 2026-10-18, madde 253
## "Seçenek 1"; prototip tools/proto_20261018/mobil_proto.gd S_sandik). Kullanıcı: "arttırılmış gibi göstermek yerine direk
## verdiği statlar ve pasif gözüksün, pasif solgun gözükmesin önemli bir açıklama o çünkü". Gece Sıvası (B) kart: kademe renkli
## kenar + şerit, büyük ikon, ad, eşyanın KENDİ stat satırları (Items.describe satırları), ayrı PASİF kutusu (parlak yazı);
## SAT kartın solunda (+altın), AL sağında ("çantaya ekle"); başlık sol üstte, geri sayım sağ üstte; SAT'ın üstünde çantadaki aynı
## kademe eşyalar. Prototipteki sıra/"Senden sonra" satırı oyunda bu menüye gelen bir veri değil - yok. Kart sandıktan yine
## fırlar (Frame görünmez kalır, animasyon/ışık kodları aynı).
const PH_CHEST_W := 880.0
const PH_SIDE_BTN := Vector2(460, 280)
const PH_PANEL := Color("#23233a")
const PH_INSET := Color("#12121f")
const PH_LINE := Color("#3b3a5a")
const PH_LINE_HI := Color("#5f5c86")
const PH_TEXT := Color("#efe6d6")
const PH_DIM_TEXT := Color("#a7a2c0")
const PH_ACCENT := Color("#f4c56e")
const PH_ACCENT_TEXT := Color("#231a0a")
const PH_GOOD := Color("#a8d69a")
const PH_KADEME_COL := [Color("#c39a64"), Color("#6f9df2"), Color("#b98af2")] ## parça / epik / efsanevi
const PH_KADEME_UPPER := ["PARÇA", "EPİK", "EFSANEVİ"]
const PH_BAG_LABEL := ["Çantandaki parçalar", "Çantandaki epikler", "Çantandaki efsaneviler"]
var _phone_chrome: Control = null


## Başlığın arkasında üstten aşağı sönen koyu şerit (prototipteki üst karartma) - alttaki HUD başlığı bozmasın.
static func top_fade(width: float, h: float = 190.0, alpha: float = 0.75) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.03, 0.06, alpha))
	g.set_color(1, Color(0.03, 0.03, 0.06, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var tr := TextureRect.new()
	tr.name = "PhoneTopFade"
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = Vector2.ZERO
	tr.size = Vector2(width, h)
	return tr


static func _ph_box(fill: Color, border: Color, bw: int, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.corner_detail = 6
	return sb


func _ph_lbl(parent: Control, text: String, r: Rect2, fs: int, c: Color, align: HorizontalAlignment, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if not wrap else VERTICAL_ALIGNMENT_TOP
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(l, fs, c, 0)
	parent.add_child(l)
	l.position = r.position
	l.size = r.size
	l.set_deferred("size", r.size)
	return l


## Başlık (sol üst) + alt satır, geri sayım levhası (sağ üst) - ortadaki eski başlık/geri sayım düzeni telefonda gizli.
func _setup_phone_chrome() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	if has_node("Dim"):
		($Dim as ColorRect).color = Color(0.03, 0.03, 0.06, 0.62)
	if title_label:
		title_label.visible = false
	_phone_chrome = Control.new()
	_phone_chrome.name = "PhoneChrome"
	_phone_chrome.theme = UIKit.theme()
	_phone_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_phone_chrome)
	_phone_chrome.add_child(top_fade(view.x))
	var x0: float = safe.position.x + 96.0
	_ph_lbl(_phone_chrome, title_label.text if title_label else "SANDIK", Rect2(x0, 20, 1100, 84), 64, PH_ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	_ph_lbl(_phone_chrome, "Al ya da sat", Rect2(x0, 100, 900, 48), 32, PH_DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	if countdown_panel:
		countdown_panel.add_theme_stylebox_override("panel", _ph_box(Color(PH_PANEL, 0.94), PH_LINE, 3, 14))
		countdown_panel.reparent(_phone_chrome, false)
		countdown_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		countdown_panel.size = Vector2(420, 120)
		countdown_panel.position = Vector2(view.x - safe.size.x - 96.0 - 420.0, 24.0)
		if countdown_label:
			UIKit.style_label(countdown_label, 64, PH_ACCENT, 0)
			countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var wl: Label = countdown_panel.get_node_or_null("VBox/WaitingLabel") as Label
		if wl:
			UIKit.style_label(wl, 32, PH_DIM_TEXT, 0)
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_phone_card(candidate: Dictionary) -> Control:
	var card_type: String = candidate.get("type", "item")
	var item_key: String = candidate.get("key", "")
	var is_weapon: bool = card_type == "weapon"
	var item_def: Dictionary = {} if is_weapon else Items.get_def(item_key)
	var display_name: String = WEAPON_NAMES.get(item_key, item_key.capitalize()) if is_weapon else item_def.get("name", item_key.capitalize())
	var desc_text: String = "Yeni bir silah - kalıcı olarak edinilir." if is_weapon else Items.describe(item_key)
	var icon_path: String = WEAPON_ICON_TEXTURES.get(item_key, "") if is_weapon else Items.icon_path(item_key)
	var cost_base: int = WEAPON_COST_BASE.get(item_key, 80) if is_weapon else Items.cost(item_key)
	var kd: int = 1 if is_weapon else clampi(Items.kademe(item_key), 1, 3)
	var kc: Color = PH_KADEME_COL[kd - 1]
	var stat_lines: Array = []
	var passive: String = ""
	for ln: String in desc_text.split("\n"):
		if ln.strip_edges() == "":
			continue
		if ln.begins_with("Pasif:"):
			passive = ln.substr(6).strip_edges()
		else:
			stat_lines.append(ln)
	var w: float = PH_CHEST_W
	## Pasif kutusu metnin satır sayısı kadar uzar (48 px yazı, kutu iç genişliği w - 120).
	var pass_lines: int = 0
	if passive != "":
		var f: Font = UIKit.theme().default_font if UIKit.theme().default_font else ThemeDB.fallback_font
		pass_lines = maxi(1, int(ceil(f.get_string_size(passive, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x / (w - 120.0))) + 0)
	var pass_h: float = (70.0 + pass_lines * 50.0) if passive != "" else 0.0
	var gold_h: float = 64.0 if _chest_gold > 0 else 0.0
	var h: float = 392.0 + stat_lines.size() * 58.0 + (pass_h + 28.0 if passive != "" else 0.0) + gold_h + 24.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(w, h)
	card.add_theme_stylebox_override("panel", _ph_box(Color(PH_PANEL, 0.97), kc, 4, 18))
	card.set_meta("glow_card_size", Vector2(w, h))
	card.set_meta("reward_tier", _reward_tier if not is_weapon else 1)
	column.add_child(card)
	## Animasyon / ışık / parıltı kodları kartın Frame'ini bekler (land_fx, start_idle_shine) - telefonda görünmez tutulur.
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.visible = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	TierCardFx.apply_frame(frame, _reward_tier if not is_weapon else 1)
	card.add_child(frame)
	var lay := Control.new()
	lay.name = "Layout"
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lay)
	var band := Panel.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", _ph_box(Color(kc, 0.3), Color(0, 0, 0, 0), 0, 14))
	band.position = Vector2(4, 4)
	band.size = Vector2(w - 8.0, 72)
	lay.add_child(band)
	_ph_lbl(lay, "SİLAH" if is_weapon else PH_KADEME_UPPER[kd - 1], Rect2(0, 4, w, 72), 48, kc.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(w * 0.5 - 96.0, 96.0)
	icon_rect.size = Vector2(192, 192)
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(icon_rect)
	_card_icon = icon_rect ## SAT'ta bu ikon parçalanır (bkz. _on_sat_pressed)
	var name_lbl: Label = _ph_lbl(lay, display_name, Rect2(16, 300, w - 32.0, 72), 64, PH_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.clip_text = true
	var y: float = 392.0
	for ln: String in stat_lines:
		_ph_lbl(lay, ln, Rect2(16, y, w - 32.0, 56), 48, PH_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
		y += 58.0
	if passive != "":
		var pb := Panel.new()
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.add_theme_stylebox_override("panel", _ph_box(Color(PH_INSET, 0.92), Color(PH_ACCENT, 0.7), 2, 12))
		pb.position = Vector2(36, y + 14.0)
		pb.size = Vector2(w - 72.0, pass_h)
		lay.add_child(pb)
		_ph_lbl(lay, "PASİF", Rect2(60, y + 24.0, 300, 44), 32, PH_ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
		_ph_lbl(lay, passive, Rect2(60, y + 72.0, w - 120.0, pass_lines * 50.0 + 4.0), 48, PH_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
		y += pass_h + 28.0
	if _chest_gold > 0:
		var gold_holder := VBoxContainer.new()
		gold_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gold_holder.position = Vector2(0, y + 4.0)
		gold_holder.size = Vector2(w, 56)
		lay.add_child(gold_holder)
		_gold_badge = _build_gold_badge(gold_holder)

	var has_slots: bool = true
	var gm = _get_game_manager()
	if is_weapon:
		if _player and gm and "owned_weapons" in gm:
			var max_w: int = 3
			if _player.has_method("get_max_owned_weapons"):
				max_w = _player.get_max_owned_weapons()
			has_slots = gm.owned_weapons.size() < max_w
	elif _player and gm and "owned_items" in gm:
		var part_slots: int = 1
		if _player.has_method("get_max_item_slots"):
			part_slots = _player.get_max_item_slots()
		has_slots = Items.purchase_block_reason(item_key, gm.owned_items, part_slots, {"consume": []}) == ""
	var power_mult: float = 1.0
	var refund_gold: int = int(round(cost_base * Items.SELL_REFUND_RATIO))
	var al_btn := Button.new()
	al_btn.disabled = not has_slots
	al_btn.pressed.connect(_on_al_pressed.bind(candidate, cost_base, power_mult))
	_ph_side_button(al_btn, false, "AL" if has_slots else "DOLU", "çantaya ekle" if has_slots else "yer yok", true)
	column.set_meta("al_button", al_btn)
	var sat_btn := Button.new()
	sat_btn.pressed.connect(_on_sat_pressed.bind(item_key, refund_gold))
	_ph_side_button(sat_btn, true, "SAT", "+%d altın" % refund_gold, false)
	column.set_meta("sat_button", sat_btn)
	_ph_bag_row(kd, is_weapon, has_slots)
	return column


## Telefon AL / SAT: kartın iki yanında büyük düğme (ana yazı + alt satır), ekrana bağlı (kart sandıktan uçarken yerinde bekler).
func _ph_side_button(btn: Button, left: bool, main: String, sub: String, primary: bool) -> void:
	if _side_holder == null:
		_side_holder = Control.new()
		_side_holder.name = "SideButtons"
		_side_holder.theme = UIKit.theme()
		_side_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		_side_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_side_holder)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var half: float = PH_CHEST_W * 0.5 + 40.0
	var x: float = view.x * 0.5 - half - PH_SIDE_BTN.x if left else view.x * 0.5 + half
	var r := Rect2(roundf(x), roundf(view.y * 0.5 - 20.0), PH_SIDE_BTN.x, PH_SIDE_BTN.y)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	var fill: Color = PH_ACCENT if primary else PH_PANEL
	var border: Color = PH_ACCENT.darkened(0.35) if primary else PH_LINE_HI
	btn.add_theme_stylebox_override("normal", _ph_box(fill, border, 4, 18))
	btn.add_theme_stylebox_override("hover", _ph_box(fill.lightened(0.08), border, 4, 18))
	btn.add_theme_stylebox_override("pressed", _ph_box(fill.darkened(0.12), border, 4, 18))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", _ph_box(Color(PH_PANEL, 0.6), PH_LINE, 3, 18))
	_side_holder.add_child(btn)
	btn.position = r.position
	btn.size = r.size
	var tc: Color = PH_ACCENT_TEXT if primary and not btn.disabled else (PH_DIM_TEXT if btn.disabled else PH_TEXT)
	_ph_lbl(btn, main, Rect2(0, 52, r.size.x, 112), 96 if primary else 64, tc, HORIZONTAL_ALIGNMENT_CENTER)
	_ph_lbl(btn, sub, Rect2(0, 172, r.size.x, 48), 32, tc if primary else PH_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_side_buttons.append(btn)


## SAT düğmesinin üstünde: çantadaki aynı kademe eşyalar (silahsa silahlar) - dolu yuvalar ikonla, sıradaki boş yuva "+".
func _ph_bag_row(kd: int, is_weapon: bool, has_slots: bool) -> void:
	if _side_holder == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var x0: float = roundf(view.x * 0.5 - PH_CHEST_W * 0.5 - 40.0 - PH_SIDE_BTN.x)
	var y0: float = roundf(view.y * 0.5 - 20.0 - 220.0)
	var icons: Array = []
	var gm = _get_game_manager()
	if is_weapon:
		if gm and "owned_weapons" in gm:
			for wk in gm.owned_weapons:
				icons.append(str(WEAPON_ICON_TEXTURES.get(str(wk.get("key", wk)) if wk is Dictionary else str(wk), "")))
	elif gm and "owned_items" in gm:
		for it in gm.owned_items:
			var key: String = str((it as Dictionary).get("key", "")) if it is Dictionary else str(it)
			if key != "" and Items.kademe(key) == kd:
				icons.append(Items.icon_path(key))
	## Satır tek kapta: kart inince düğmelerle birlikte belirir (_side_buttons, bkz. _reveal_reward_card).
	var row := Control.new()
	row.name = "PhoneBagRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_side_holder.add_child(row)
	_side_buttons.append(row)
	_ph_lbl(row, "Silahların" if is_weapon else PH_BAG_LABEL[kd - 1], Rect2(x0, y0, PH_SIDE_BTN.x, 44), 32, PH_DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	var plus_done: bool = false
	for j in 5:
		var sr := Rect2(x0 + j * 92.0, y0 + 52.0, 80, 80)
		var filled: bool = j < icons.size()
		var plus: bool = not filled and not plus_done and has_slots
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", _ph_box(Color(PH_ACCENT, 0.15) if plus else Color(PH_INSET, 0.9), PH_ACCENT if plus else PH_LINE, 3 if plus else 2, 10))
		slot.position = sr.position
		slot.size = sr.size
		row.add_child(slot)
		if filled and str(icons[j]) != "" and ResourceLoader.exists(str(icons[j])):
			var ic := TextureRect.new()
			ic.texture = load(str(icons[j])) as Texture2D
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.position = Vector2(8, 8)
			ic.size = Vector2(64, 64)
			slot.add_child(ic)
		elif plus:
			plus_done = true
			_ph_lbl(slot, "+", Rect2(0, -4, 80, 80), 64, PH_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
