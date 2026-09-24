extends CanvasLayer

## Kullanıcı isteği: "bundan sonra kimsenin başlangıç silahı ve başlangıç
## kalkanı yok, oyuna başlayınca önüne 3 adet rasgele silah seçme kartı
## açılacak (tıpkı level atlama kartları gibi ama silah bazlı) ve 2 kez
## karıştırma hakkı olacak, silah seçtikten sonra 2 adet kalkan seçme kartı
## çıkacak ve aynı karıştırma hakları kullanılacak, ayrıca 5/10/15/20.
## levelde de yine silah seçme hakkı gelecek."
##
## Bu ekran level_up_screen.gd'nin KART GÖRSELİ / GİRİŞ ANİMASYONU / ÇOK
## OYUNCULU KUYRUK desenini birebir taklit eder (aynı StyleBoxFlat renkleri+
## kart boyutu, aynı NetworkManager.set_level_up_busy/start_level_up_
## countdown mekanizması - bkz. network_manager.gd "KART/SİLAH/KALKAN SEÇİM
## KUYRUĞU SENKRONİZASYONU" notu - o RPC katmanı seçimin NE olduğunu hiç
## bilmiyor, sadece "bu eş hâlâ meşgul mü" takip ediyor).
## İki modu var: "weapon" (3 kart, WEAPON_KEYS havuzundan) ve "shield"
## (2 kart, SHIELD_KEYS havuzundan) - level_up_screen'in aksine reroll ALTIN
## MALİYETLİ DEĞİL, sabit REROLL_MAX hakkı var, ekran her açıldığında
## sıfırdan başlar ("aynı karıştırma hakları kullanılacak" - kullanıcı isteği).

signal item_chosen(key: String)

## main.gd, add_child()'dan ÖNCE ayarlamalı.
var mode: String = "weapon"
## CountLabel'da "zaten sahip olunan kopya" bilgisi için (bkz. _populate_cards).
var player_ref: Node = null

const REROLL_MAX := 2

## 2026-09-24: kartlar bej parşömen - kategori renkleri koyu tonlar (TEK kaynak UIKit, level kartlarıyla aynı).
const CAT_MELEE_COLOR := UIKit.C_CAT_ATTACK
const CAT_RANGED_COLOR := UIKit.C_CAT_UTILITY
const CAT_SHIELD_COLOR := UIKit.C_CAT_DEFENSE

## bkz. chest_menu.gd üstündeki aynı not - shop_panel.gd bir class_name
## tanımlamadığı için oradaki const'lara erişmenin en basit/açık yolu bu
## paralel kopya deseni (diğer script'lerle tutarlı).
const WEAPON_KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç",
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
}
## bkz. player.gd buy_weapon_copy() - _configure_*_melee() SADECE bu 4 anahtar
## için çağrılıyor, geri kalan tüm silahler menzilli/projectile.
const MELEE_WEAPON_KEYS := ["dagger", "pence", "topuz", "uzunkilic"]

## bkz. player.gd SHIELD_TYPES - isimler oradan (player_ref üzerinden)
## okunuyor, burada sadece anahtar sırası tutuluyor.
const SHIELD_KEYS := ["shield_standart", "shield_enerji", "shield_kale", "shield_savas"]

## Kullanıcı isteği: "ayrıntılarını direk kartın içine mini bir panel olarak
## ekle aşağı kaydırarak okuyabilelim" (bkz. _populate_cards - her kartın
## içinde daima açık, kaydırılabilir bir açıklama kutusu).
## Kullanıcı isteği (güncel): "kartlardaki yetenek açıklamalarını hasar +
## saldırı gücü oranı ve kademe geliştirmeleri olarak ayrı ayrı basit bir
## şekilde açıkla" - her kartta iki ayrı bölüm var: ilk satır HASAR + saldırı
## gücü oranı (menzil/ateş hızı da kısaca), ikinci satır KADEME geliştirmeleri.
## Değerler mevcut player.gd tier fonksiyonları + weapon_*.tscn dosyalarından
## alındı (eski metinlerdeki birçok sayı güncel koddan sapmıştı - örn. Ateş
## Asası hasarı 16 değil 13, Tüfek 35 değil 22, Yay saldırı gücü oranı %90
## değil %70).
const WEAPON_DESCRIPTIONS := {
	"dagger": "HASAR: 10 + %85 saldırı gücü · Yakın dövüş, hedefe kanama yükü bırakır\nKADEME (100): Kanama kapasitesi kademeyle artar (1→10). 30/50/70/100'da isabet başına +1 kanama yükü. Kanama: kademe + %5 saldırı gücü/sn.",
	"fire_staff": "HASAR: 13 + %100 saldırı gücü · Ateş hızı 1.4sn · Menzil 168 · Patlayıcı mermi\nKADEME (100): Her seviye ufak hasar ve hafif ateş hızı artışı. 30/50/70/100'de kümülatif +%8 hasar (100'de +%32).",
	"lightning_staff": "HASAR: 12/sn + %140 saldırı gücü · Menzil 168 · Kesintisiz ışın\nKADEME (100): +12 saniyelik hasar/kademe. 30/50/70/100'da +1 zincir sıçrama (2→5 hedefe).",
	"tabanca": "HASAR: 17 + %99 saldırı gücü · Ateş hızı 0.9sn · Menzil 210 · Aynı hedefe isabet yükü biriktirir (tavan %70)\nKADEME (100): 30/50/70'de +%10 ateş hızı +%5 yük; 100'de +%12 ateş hızı +%5 yük (tavan %90'a çıkar).",
	"tuftuf": "HASAR: 5 + %55 saldırı gücü · Ateş hızı 1.4sn · Menzil 238 · Hedefi zehirler: her isabet 1 yük ekler (en fazla 100 yük), her yük 20sn boyunca saniyede saldırı gücünün %5'i kadar hasar verir · Öncelik: canı yüksek > hiç zehirlenmemiş > tümü\nKADEME (100): +5 hasar ve +%8 ateş hızı/kademe (zehir kademeye bağlı değil).",
	"tufek": "HASAR: 22 + %195 saldırı gücü · Ateş hızı 1.3sn · Menzil 336 · Delici mermi\nKADEME (100): +20 hasar ve +%3 kalkan delme/kademe. 30/50/70/100'da delme sayısı 2/3/4/5, delici hasar %40/50/60/70.",
	"arcane": "HASAR: 16 + %110 saldırı gücü · Ateş hızı 1.4sn · Menzil 168 · Kuyruklu yıldız mermisi\nKADEME (100): +16 hasar/kademe. 30/50/70/100'da kümülatif +%8 hasar (10'da +%32).",
	"yay": "HASAR: 14 + %70 saldırı gücü · Ateş hızı 0.8sn · Menzil 266 · Ateşten önce ok çeker\nKADEME (100): +10 hasar/kademe, ateş hızı artar. Her 3. atışta ekstra ok; 30/50/70/100'da +1 ekstra ok (→+5).",
	"crossbow": "HASAR: 16 + %110 saldırı gücü · Ateş hızı 0.7sn · Menzil 245\nKADEME (100): +16 hasar ve +%4 kritik şans/kademe. 30/50/70/100'da kümülatif +%10 kritik hasar (10'da +%40).",
	"boomerang": "HASAR: 16 + %90 saldırı gücü · Ateş hızı 0.3sn · Menzil 167 · Gidip döner, 2 kez vurabilir\nKADEME (100): +16 hasar/kademe. 30/50/70/100'da kümülatif +%10 fırlatma/dönüş hızı (10'da +%40).",
	"buz_asasi": "HASAR: 12 + %77 saldırı gücü · Ateş hızı 1.4sn · Menzil 168 · Her isabette boss olmayan hedefi 3sn dondurur · Donmamış hedefleri önceliklendirir\nKADEME (100): +12 hasar ve +%6 ateş hızı/kademe. Donma süresi ve donmamış hedef önceliği değişmez.",
	"fisek": "HASAR: 14 + %230 saldırı gücü (sadece alan hasarı) · Ateş hızı 3.7sn · Menzil 252\nKADEME (100): Hasar kademeyle büyümez. 30/50/70/100'da kümülatif +%15 patlama yarıçapı (10'da +%60).",
	"pence": "HASAR: 20 + %100 saldırı gücü · Yakın dövüş (menzil 110) · Verdiği hasarın yüzdesi kadar can emer\nKADEME (100): +20 hasar/kademe. Can emme tabanı %0.3; 30/50/70/100'da +%0.2 (10'da %1.1).",
	"topuz": "HASAR: 20 + %105 saldırı gücü · Yakın dövüş (menzil 120) · Geniş alan hasarı\nKADEME (100): +20 hasar/kademe. 30/50/70/100'da kümülatif +%10 kalkan delme (10'da +%40).",
	"uzunkilic": "HASAR: 18 + %100 saldırı gücü · Yakın dövüş (menzil 115) · Geniş savuruş\nKADEME (100): Hasar kademeyle büyümez. +%5 kalkan delme/kademe. 30/50/70/100'da kümülatif +%10 ekstra silah hasarı (10'da +%40).",
}
const SHIELD_DESCRIPTIONS := {
	"shield_standart": "Dengeli bir kalkan. 150 kalkan gücü, %65 hasar emilimi. Vurulduktan 8 saniye sonra yenilenmeye başlar (10/sn). Her seviye ufak ufak +güç/+yenilenme, bekleme azalır (en az 1.5sn) - seviye 100'de toplamda eskiden 30 seviyede olduğu kadar (+10 güç, +1 yenilenme, -0.1sn bekleme/eski-seviye). 100 seviyeye kadar geliştirilebilir.",
	"shield_enerji": "Hızlı yenilenen ama zayıf bir kalkan. 90 kalkan gücü, %55 hasar emilimi. Vurulduktan 4.5 saniye sonra yenilenmeye başlar (12/sn). Her seviye ufak ufak +güç/+yenilenme, bekleme azalır (en az 1.5sn) - seviye 100'de toplamda eskiden 30 seviyede olduğu kadar. 100 seviyeye kadar geliştirilebilir.",
	"shield_kale": "Çok güçlü ama yavaş yenilenen bir kalkan. 180 kalkan gücü, %75 hasar emilimi. Vurulduktan 9 saniye sonra yenilenmeye başlar (8/sn). Her seviye ufak ufak +güç/+yenilenme, bekleme azalır (en az 1.5sn) - seviye 100'de toplamda eskiden 30 seviyede olduğu kadar. 100 seviyeye kadar geliştirilebilir.",
	"shield_savas": "Savaş sırasında da yenilenir, hiç bekleme süresi yok. 100 kalkan gücü, %60 hasar emilimi, sürekli 3.6/sn yenilenir. Her seviye ufak ufak +güç/+yenilenme - seviye 100'de toplamda eskiden 30 seviyede olduğu kadar. 100 seviyeye kadar geliştirilebilir.",
}

var _cards: Array = []
var _card_tweens: Array = []
var _reroll_left: int = REROLL_MAX
var _has_chosen: bool = false

var _reroll_button: Button = null
var _countdown_panel: PanelContainer = null
var _countdown_label: Label = null
var _waiting_label: Label = null
var _cards_container: HBoxContainer = null

## Kullanıcı isteği: "ayrıntıları direk kartın içine mini bir panel olarak
## ekle, kartların boyunu ve genişliğini buna göre biraz arttır" - eski
## (238,406) boyutu artık aşağı kaydırılabilir bir açıklama kutusuna yer
## açacak şekilde büyütüldü. Aşağıdaki tüm dikey konumlar (kart kapsayıcısı/
## karıştır butonu/geri sayım paneli) CARD_SIZE.y'den TÜRETİLİYOR (bkz.
## _build_ui) - bu sabit tekrar değişirse hepsi otomatik doğru yerde kalır.
## Kullanıcı isteği (2026-09-24): oyun içi arayüzler menülerle aynı bej/ahşap kite geçti - kart artık level atlama
## kartlarıyla AYNI aileden: Sıradan tier'in ahşap kartı (tools/gen_menu_kit.py tier_card, 100x160 sanat px = 300x480),
## dokunun kendi boyutunda çizildiği için her sanat pikseli tam 3 ekran pikseli.
const CARD_SIZE := Vector2(300, 480)
const CARD_ANIM_DURATION := 0.26
const CARD_ANIM_STAGGER := 0.07
const CARD_ANIM_RISE := 22.0
const CARD_ANIM_START_SCALE := 0.92


func _card_count() -> int:
	return 3 if mode == "weapon" else 2


const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
## Başlangıç silah/kalkan kart seçimi açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1
	_build_ui()
	_populate_cards()
	_animate_cards_in()
	## DÜZELTME (kullanıcı isteği: "Button resmini oyunumdaki tüm butonlarla
	## değiştir") - bu ekran (silah/kalkan seçim kartları + karıştır butonu)
	## hiç UISound çağırmıyordu, ne tık sesi ne yeni ahşap buton stili
	## alıyordu. Kartlar (CARD_SIZE 272x486, dikey oranlı) ui_sound.gd'nin
	## _looks_like_icon_slot filtresine takılıp OLDUĞU GİBİ kalıyor - sadece
	## RerollButton (geniş, custom_minimum_size'ı YOK, offset ile
	## boyutlandırılmış) yeni Button.png stilini alıyor.
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self)

	## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini
	## beklemeden tüm kartlarını seçebilsin") - set_level_up_busy(true)/
	## start_level_up_countdown() artık burada DEĞİL, main.gd
	## _show_item_select_screen'de (bu ekranı add_child ettiği yerde)
	## çağrılıyor - tek sorumluluk noktası (bkz. o dosyadaki kök neden notu).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.multiplayer_level_up_timer_tick.connect(_on_timer_tick)
		if _waiting_label:
			_waiting_label.text = "Süre dolarsa otomatik seçilir"
		if _countdown_panel:
			_countdown_panel.visible = NetworkManager.level_up_timer_active
			if _countdown_panel.visible and _countdown_label:
				_countdown_label.text = "%ds" % int(ceil(NetworkManager.level_up_countdown))


func _on_timer_tick(remaining: float) -> void:
	if _countdown_panel:
		_countdown_panel.visible = true
	if _countdown_label:
		_countdown_label.text = "%ds" % int(ceil(remaining))
	if remaining <= 0.0 and not _has_chosen:
		_auto_pick_random_card()


func _auto_pick_random_card() -> void:
	if _has_chosen or _cards.is_empty():
		return
	var idx: int = randi() % _cards.size()
	var card: Button = _cards[idx]
	if is_instance_valid(card):
		card.pressed.emit()


## ==============================================================================
## GÖRSEL KURULUM - level_up_screen.tscn ile AYNI StyleBoxFlat renkleri/kart
## boyutu (bkz. o dosyadaki CardStyle_normal/pressed/hover/disabled).
## ==============================================================================
func _build_ui() -> void:
	## Oyun içi bej kit teması (CanvasLayer temayı çocuklarına aktarmaz - her üst düzey Control'e ayrı verilir).
	var theme_res: Theme = UIKit.theme()

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.12, 0.07, 0.03, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.name = "Title"
	title.text = "SİLAHINI SEÇ" if mode == "weapon" else "KALKANINI SEÇ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.theme = theme_res
	## Başlık: menülerdeki gibi parşömen kurdele, koyu yazı (kurdele dokusunun kendi yüksekliği 72 px).
	title.add_theme_stylebox_override("normal", UIKit.panel_style("banner"))
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_TEXT, 0)
	var title_w: float = MenuKit.font().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FS_TITLE).x + 132.0
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -roundf(title_w * 0.5)
	title.offset_right = roundf(title_w * 0.5)
	title.offset_top = 24.0
	title.offset_bottom = 96.0
	add_child(title)

	_cards_container = HBoxContainer.new()
	_cards_container.name = "CardsContainer"
	_cards_container.add_theme_constant_override("separation", 20)
	if theme_res:
		_cards_container.theme = theme_res
	_cards_container.set_anchors_preset(Control.PRESET_CENTER)
	_cards_container.anchor_left = 0.5
	_cards_container.anchor_top = 0.5
	_cards_container.anchor_right = 0.5
	_cards_container.anchor_bottom = 0.5
	var half_w: float = (_card_count() * CARD_SIZE.x + (_card_count() - 1) * 20.0) * 0.5
	var half_h: float = CARD_SIZE.y * 0.5
	_cards_container.offset_left = -half_w
	_cards_container.offset_right = half_w
	_cards_container.offset_top = -half_h
	_cards_container.offset_bottom = half_h
	add_child(_cards_container)

	_reroll_button = Button.new()
	_reroll_button.name = "RerollButton"
	if theme_res:
		_reroll_button.theme = theme_res
	_reroll_button.clip_text = true
	_reroll_button.set_anchors_preset(Control.PRESET_CENTER)
	_reroll_button.anchor_left = 0.5
	_reroll_button.anchor_top = 0.5
	_reroll_button.anchor_right = 0.5
	_reroll_button.anchor_bottom = 0.5
	_reroll_button.offset_left = -220.0
	_reroll_button.offset_right = 220.0
	_reroll_button.offset_top = half_h + 20.0
	_reroll_button.offset_bottom = half_h + 68.0
	_reroll_button.add_theme_font_size_override("font_size", UIKit.FS_BODY)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	add_child(_reroll_button)
	_refresh_reroll_button()

	_countdown_panel = PanelContainer.new()
	_countdown_panel.name = "CountdownPanel"
	_countdown_panel.visible = false
	_countdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	_countdown_panel.theme = theme_res
	_countdown_panel.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_panel.anchor_left = 0.5
	_countdown_panel.anchor_top = 0.5
	_countdown_panel.anchor_right = 0.5
	_countdown_panel.anchor_bottom = 0.5
	_countdown_panel.offset_left = -140.0
	_countdown_panel.offset_right = 140.0
	_countdown_panel.offset_top = half_h + 88.0
	_countdown_panel.offset_bottom = half_h + 156.0
	add_child(_countdown_panel)

	var cd_vbox := VBoxContainer.new()
	cd_vbox.add_theme_constant_override("separation", 2)
	_countdown_panel.add_child(cd_vbox)

	_waiting_label = Label.new()
	_waiting_label.text = "Diğer oyuncular bekleniyor"
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	_waiting_label.add_theme_font_size_override("font_size", 32)
	cd_vbox.add_child(_waiting_label)

	_countdown_label = Label.new()
	_countdown_label.name = "CountdownLabel"
	_countdown_label.text = "25s"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", UIKit.C_GOLD)
	_countdown_label.add_theme_font_size_override("font_size", 58)
	cd_vbox.add_child(_countdown_label)


func _refresh_reroll_button() -> void:
	_reroll_button.text = "Karıştır (%d hak kaldı)" % _reroll_left
	_reroll_button.disabled = _reroll_left <= 0 or _has_chosen


## Kart zemini: Sıradan tier'in ahşap kartı (bkz. CARD_SIZE notu) - hover biraz aydınlık, basılı biraz koyu.
static func _build_card_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = UIKit.game_tex("tier_card_1.png")
	style.modulate_color = tint
	return style


## ==============================================================================
## KARTLAR
## ==============================================================================
func _weapon_category(key: String) -> Dictionary:
	if key in MELEE_WEAPON_KEYS:
		return {"label": "Yakın Dövüş", "color": CAT_MELEE_COLOR}
	return {"label": "Menzilli", "color": CAT_RANGED_COLOR}


func _owned_weapon_copy_count(key: String) -> int:
	if not is_instance_valid(player_ref):
		return 0
	var count: int = 0
	for w in player_ref.owned_weapon_nodes:
		if is_instance_valid(w) and w.get_meta("shop_key", "") == key:
			count += 1
	return count


func _owned_shield_level(key: String) -> int:
	if not is_instance_valid(player_ref):
		return 0
	return int(GameManager.get(key + "_level"))


## Kullanıcı isteği: "rerollanan şeyler rerollandığında asla önceki
## seçeneklerden birini içermemeli" - bu ekranda GÖSTERİLMİŞ (ilk açılış +
## tüm reroll'lar) tüm anahtarları tutar. Kalkan modunda sadece 4 tür
## olduğundan (2'şer gösteriliyor) havuz 1 reroll sonra tükenebilir - bu
## durumda son çare olarak sıfırlanır.
var _shown_keys: Array = []

func _draw_pool(count: int) -> Array:
	var full_pool: Array = WEAPON_KEYS if mode == "weapon" else SHIELD_KEYS
	var available: Array = full_pool.filter(func(k): return not _shown_keys.has(k))
	if available.size() < count:
		_shown_keys.clear()
		available = full_pool.duplicate()
	available.shuffle()
	## Havuz istenen sayıdan azsa (kalkan modunda 4 tür var, 2 isteniyor -
	## sorun yok, ama ileride azalırsa) tekrar kullanılabilir.
	while available.size() < count:
		available.append_array(full_pool)
	var result: Array = available.slice(0, count)
	for k in result:
		_shown_keys.append(k)
	return result


func _populate_cards() -> void:
	for c in _cards_container.get_children():
		c.queue_free()
	_cards.clear()
	_card_tweens.clear()

	var pool: Array = _draw_pool(_card_count())
	var normal_style := _build_card_style(Color(1, 1, 1, 1))
	var pressed_style := _build_card_style(Color(0.88, 0.86, 0.82, 1))
	var hover_style := _build_card_style(Color(1.1, 1.08, 1.04, 1))
	var disabled_style := _build_card_style(Color(0.7, 0.68, 0.64, 1))

	for key in pool:
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.clip_contents = true
		card.clip_text = true
		card.add_theme_stylebox_override("normal", normal_style)
		card.add_theme_stylebox_override("pressed", pressed_style)
		card.add_theme_stylebox_override("hover", hover_style)
		card.add_theme_stylebox_override("disabled", disabled_style)
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.pressed.connect(_on_card_pressed.bind(key, card))

		var category := Label.new()
		category.add_theme_font_size_override("font_size", UIKit.FS_BODY)
		category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		category.set_anchors_preset(Control.PRESET_TOP_WIDE)
		## Kart dokusunun başlık bandı: sanat satır 7..17 (21..54 px).
		category.offset_left = 30.0
		category.offset_top = 21.0
		category.offset_right = -30.0
		category.offset_bottom = 54.0

		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 12)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		## Parşömen iç alanı (çerçeve + emaye bant 7 sanat px = 21 px, başlık bandının altı 57 px).
		content.offset_left = 27.0
		content.offset_top = 60.0
		content.offset_right = -27.0
		content.offset_bottom = -27.0

		var icon_holder := CenterContainer.new()
		icon_holder.custom_minimum_size = Vector2(0, 100)
		content.add_child(icon_holder)

		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_label.add_theme_font_size_override("font_size", 40)
		name_label.add_theme_color_override("font_color", UIKit.C_TEXT)
		content.add_child(name_label)

		var count_label := Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		count_label.add_theme_font_size_override("font_size", 24)
		count_label.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
		content.add_child(count_label)

		## Kullanıcı isteği: "ayrıntıları direk kartın içine mini bir panel
		## olarak ekle aşağı kaydırarak okuyabilelim" - ayrı bir buton/panel
		## yerine kartın İÇİNDE, dükkan açıklama kutusuyla aynı renkte
		## (SBF_content_dark) daima açık, kaydırılabilir küçük bir metin
		## kutusu. ScrollContainer kendi mouse_filter'ıyla tekerlek olayını
		## kendi tüketir - bu yüzden içeriği kaydırmak alttaki kart Button'ının
		## "pressed" sinyalini TETİKLEMEZ (bkz. _draw_pool üstündeki genel not).
		var desc_scroll := ScrollContainer.new()
		desc_scroll.custom_minimum_size = Vector2(0, 90)
		desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desc_scroll.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
		content.add_child(desc_scroll)

		var desc_label := Label.new()
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.custom_minimum_size = Vector2(1, 0)
		## Kullanıcı isteği (güncel): açıklamada "Hasar:" ve "Kademe:" bölüm
		## başlıkları büyük harfle ayrılmış iki satır olarak gösteriliyor
		## (Label'da BBCode desteklenmediği için başlıklar düz büyük harfli
		## metin - bkz. WEAPON_DESCRIPTIONS).
		## DÜZELTME (kullanıcı isteği: "fontu değiştirmeden düzeltemez misin,
		## bu fontu çok seviyorum") - font (m5x7.ttf) DEĞİŞMEDİ. m5x7'nin
		## kendi import ayarları (bkz. assets/fonts/m5x7.ttf.import)
		## antialiasing KAPALI ve keep_rounding_remainders açık - yani piksel
		## hizalı bir font, kendi tasarım biriminin (7px) TAM KATI olmayan
		## boyutlarda (27 gibi) glif başına tutarsız kalınlıkta/bulanık
		## basabiliyor. 27 -> 28'e (7'nin katı) çekildi; yoğun, sarılmış
		## paragraf metninde ince piksel harflerin birbirine karışmaması için
		## satır arası boşluk eklendi, metin rengi saf beyaza yakın çekilip
		## kontrast arttırıldı.
		## 2026-09-24: bej çukur kutuda koyu yazı; 24 px (m5x7 3x - keskin) + satır arası.
		desc_label.add_theme_color_override("font_color", UIKit.C_TEXT)
		desc_label.add_theme_font_size_override("font_size", 24)
		desc_label.add_theme_constant_override("line_spacing", 6)
		desc_label.add_theme_constant_override("outline_size", 0)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_scroll.add_child(desc_label)

		if mode == "weapon":
			var cat_info: Dictionary = _weapon_category(key)
			category.text = cat_info["label"]
			category.add_theme_color_override("font_color", cat_info["color"])
			name_label.text = WEAPON_NAMES.get(key, key.capitalize())
			var icon_path: String = WEAPON_ICON_TEXTURES.get(key, "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var tex_rect := TextureRect.new()
				tex_rect.texture = load(icon_path)
				tex_rect.custom_minimum_size = Vector2(96, 96)
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon_holder.add_child(tex_rect)
			var owned: int = _owned_weapon_copy_count(key)
			count_label.text = ("%dx sahipsin" % owned) if owned > 0 else ""
			desc_label.text = WEAPON_DESCRIPTIONS.get(key, "")
		else:
			category.text = "Kalkan"
			category.add_theme_color_override("font_color", CAT_SHIELD_COLOR)
			var shield_def: Dictionary = {}
			if is_instance_valid(player_ref):
				shield_def = player_ref.SHIELD_TYPES.get(key, {})
			name_label.text = str(shield_def.get("name", key.capitalize()))
			var shield_icon_script: GDScript = load("res://scripts/shop_item_icon.gd")
			var icon_ctrl: Control = Control.new()
			icon_ctrl.set_script(shield_icon_script)
			icon_ctrl.custom_minimum_size = Vector2(96, 96)
			icon_ctrl.set("item_type", "shield")
			icon_holder.add_child(icon_ctrl)
			var owned_lvl: int = _owned_shield_level(key)
			count_label.text = ("Zaten seviye %d" % owned_lvl) if owned_lvl > 0 else ""
			desc_label.text = SHIELD_DESCRIPTIONS.get(key, "")

		card.add_child(category)
		card.add_child(content)
		_cards_container.add_child(card)
		_cards.append(card)
		_card_tweens.append(null)


func _on_reroll_pressed() -> void:
	if _reroll_left <= 0 or _has_chosen:
		return
	_reroll_left -= 1
	_populate_cards()
	_refresh_reroll_button()
	_animate_cards_in()


## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini beklemeden
## tüm kartlarını seçebilsin") - bkz. level_up_screen.gd _on_card_pressed
## üstündeki AYNI kök neden notu: ekran artık burada AÇIK tutulup
## kilitlenmiyor, main.gd _grant_selected_item/on_done zinciri (bkz.
## _show_item_select_screen) seçim anında hemen bir sonraki adıma geçiyor.
func _on_card_pressed(key: String, _card: Button) -> void:
	if _has_chosen:
		return
	_has_chosen = true
	item_chosen.emit(key)


## ==============================================================================
## GİRİŞ ANİMASYONU - level_up_screen.gd _animate_cards_in() ile birebir aynı.
## ==============================================================================
func _animate_cards_in() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.modulate.a = 0.0
			card.scale = Vector2(CARD_ANIM_START_SCALE, CARD_ANIM_START_SCALE)
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		if not is_instance_valid(card):
			continue
		if _card_tweens[i] and _card_tweens[i].is_valid():
			_card_tweens[i].kill()
		card.pivot_offset = card.size * 0.5
		var base_y: float = card.position.y
		card.position.y = base_y + CARD_ANIM_RISE
		var delay: float = i * CARD_ANIM_STAGGER
		var tween := create_tween()
		_card_tweens[i] = tween
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "modulate:a", 1.0, CARD_ANIM_DURATION).set_delay(delay)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_ANIM_DURATION).set_delay(delay)
		tween.tween_property(card, "position:y", base_y, CARD_ANIM_DURATION).set_delay(delay)
