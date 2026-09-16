extends Control
## class_name eklendi (kullanıcı isteği: mini dükkan aktivitesi) - yeni
## mini_shop_screen.gd, dükkanın kendi geliştirme fiyat formüllerini
## (MAX_LEVELS/_upgrade_cost/_copy_cost/_item_cost, hepsi zaten instance
## state'ine bağımsız/pure fonksiyonlardı) İKİNCİ bir kopya yazmadan doğrudan
## ShopPanel._upgrade_cost(...) gibi çağırabilsin diye.
class_name ShopPanel

## Kullanıcı isteği: "Dükkanı açınca sağında stat penceresinin de açılmasını
## istiyorum" + "mini dükkan yerine direk dükkan açılsın" - hud.gd (eşleşen
## istatistik panelini kapatmak için) VE main.gd (periyodik dükkan molasının
## ne zaman bittiğini anlamak için, bkz. main.gd _on_mini_shop_screen_closed)
## panel KENDİ X butonuyla kapandığında haberdar olmalı - eskiden hiçbir
## sinyal yoktu (inventory_panel.gd'deki "closed" ile AYNI desen).
signal closed

## Every purchasable item in the shop is a "leveled" item now: mine/spray/
## shield always worked this way, and the 4 shield mods used to be one-time
## bool purchases but were converted to leveled items too (10 levels) so
## buying them again keeps making them stronger instead of just unlocking
## them once.
## Silah yükseltmeleri (dagger/fire_staff/lightning_staff/tabanca/tuftuf/
## tufek) - hiçbiri "ana silah" değil, hepsi birebir aynı muamele gören,
## satılabilir/yükseltilebilir normal owned_weapons kopyaları (bkz.
## player.gd STARTING_WEAPON_BY_CHAR - hiçbir karakterin ayrı, ücretsiz bir
## ana silahı yok).
## Eski tek "Sihirli Kalkan" (100 seviye) kaldırıldı - artık 4 bağımsız
## kalkan TÜRÜ var (bkz. player.gd SHIELD_TYPES), her biri en fazla 30
## seviyeye kadar geliştirilebilir (bkz. kullanıcı isteği). Kalkan MODLARI
## (shield_mod_*) bundan tamamen bağımsız, değişmedi.
const SHIELD_TYPE_KEYS := ["shield_standart", "shield_enerji", "shield_kale", "shield_savas"]
## DÜZELTME (kullanıcı isteği: "Tüm silah/kalkan geliştirmelerini 100 levele
## yükseltip gelişim başına artan statları da buna göre güncelle... geliştirme
## bedellerini buna göre büyük miktarda ucuzlatıp dengele") - eskiden silahlar
## 10 (bazıları 30), kalkanlar 30, kalkan modları 10 seviyeye kapalıydı; artık
## HEPSİ 100 (aynı toplam güç, 100 küçük artışa yayılmış - bkz. player.gd
## _tier_from_level10/_visual_tier_from_level ve _upgrade_cost/
## _weapon_upgrade_cost üstündeki yeni fiyat eğrisi notu). mine/gold_collector
## (zaten 100'dü, silah/kalkan değil) ve spray (silah/kalkan değil, kapsam
## dışı) DOKUNULMADI.
## DÜZELTME (kullanıcı isteği: "Silah ve kalkan tierlarını 100 yapmanı
## istemiştim onu 20'ye düşürerek geliştirme bedellerinin fiyatını ve
## geliştirme başına artan gücünü buna göre eşitle. 100 leveldeki güç nasılsa
## 20 leveldeki güç de öyle olacak şekilde güncelle." + takip mesajı: "altın
## toplayıcı ve maden i de 100 levelden 20 levele düşür. ve onlar da aynı
## şekilde dengelensin.") - silah/kalkan/kalkan modu VE mine/gold_collector
## artık 20 (spray hâlâ kapsam dışı, 10'da kalıyor). Uç nokta gücü/toplam
## maliyet KORUNDU - bkz. player.gd _tier_from_level10 (max 100->20, uç
## noktalar aynı) ve aşağıdaki LEVEL_SCALE_TO_OLD_100/_upgrade_cost notu.
const MAX_LEVELS := {
	"spray": 10,
	"shield_standart": 20, "shield_enerji": 20, "shield_kale": 20, "shield_savas": 20,
	"dagger": 20, "fire_staff": 20, "lightning_staff": 20, "tabanca": 20, "tuftuf": 20, "tufek": 20, "arcane": 20, "yay": 20,
	"crossbow": 20, "boomerang": 20, "buz_asasi": 20, "fisek": 20, "pence": 20, "topuz": 20, "uzunkilic": 20,
	"shield_mod_resilience": 20, "shield_mod_thorny": 20,
	"shield_mod_turtle": 20, "shield_mod_aggressive": 20,
	"shield_mod_lightning": 20, "shield_mod_piercing": 20, "shield_mod_tank": 20,
}
const UPGRADE_NAMES := {
	"spray": "İtici Sprey",
	"shield_standart": "Standart Kalkan", "shield_enerji": "Enerji Kalkanı",
	"shield_kale": "Kale Kalkanı", "shield_savas": "Savaş Kalkanı",
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç",
	## Kullanıcı isteği: "kalkan modlarının adı artık savaş modları" - eski
	## mod isimleri (Metanet/Dikenli Kalkan/Kaplumbağa/Agresif/Şimşek Hız/
	## Delicilik/Tank) yerine yeni görsel setiyle gelen isimler kullanılıyor.
	## Anahtarlar (shield_mod_*) DEĞİŞMEDİ - sadece görüntülenen isim.
	"shield_mod_resilience": "Meditasyon", "shield_mod_thorny": "Yansıtma",
	"shield_mod_turtle": "Kırılmaz İrade", "shield_mod_aggressive": "Cinnet",
	"shield_mod_lightning": "Çeviklik", "shield_mod_piercing": "Teknik Savaş",
	"shield_mod_tank": "Savunma",
}

## Biriktirilebilir silahların ikonları - Geliştirmeler sekmesindeki her slot
## hangi silahı gösteriyorsa o silahın ikon dokusu burada aranır (bkz.
## _refresh_upgrade_page).
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
## "Silahlar" sekmesinde bağımsız bir KOPYA daha satın almanın taban fiyatı
## (bkz. _copy_cost) - eskiden "seviye" denen tek fiyat tablosunun tabanları
## burada KOPYA fiyatı olarak kullanılıyor. Seviye maliyeti (_upgrade_cost,
## aşağıda) tamamen ayrı - her kopyanın KENDİNE ÖZEL bir seviyesi var, hiçbir
## şey paylaşılmıyor (bkz. player.gd owned_weapon_nodes).
const COPY_COST_BASE := {
	"dagger": 60, "fire_staff": 80, "lightning_staff": 120, "tabanca": 100, "tuftuf": 90, "tufek": 100, "arcane": 110, "yay": 100,
	"crossbow": 100, "boomerang": 110, "buz_asasi": 95, "fisek": 120, "pence": 90, "topuz": 105, "uzunkilic": 100,
}
const WEAPON_KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
## player.gd MAX_OWNED_WEAPONS ile birebir aynı olmalı - dükkandan satın
## alınabilecek/başlangıçta sahip olunan, türü karışık olabilecek en fazla
## silah sayısı (başlangıç silahı dahil). Hiçbir karakterin ayrı bir ana
## silahı olmadığı için herkeste aynı: WEAPON_ICON_SLOTS.size() (bkz.
## player.gd) ile birebir = 5.
const MAX_OWNED_WEAPONS := 5
## Fiyat etiketi eklendiğinde kartın custom_minimum_size.y'sine eklenen ekstra
## boşluk (bkz. _ready() içindeki PriceLabel oluşturma döngüsü) - metnin
## kartın dışına taşmaması için.
const PRICE_LABEL_EXTRA_HEIGHT := 36.0

## NOT: "mine"/"gold_collector" satırları KALDIRILDI - kullanıcı isteğiyle
## ("altın toplayıcı ve madeni oyundan tamamen kaldır ve ekranın sağındaki
## arayüzlerini de sil") bu iki özellik oyundan tamamen çıktı: GameManager
## durumu/pasif üretimi, hud.gd'nin sağdaki üretim butonları, MAX_LEVELS/
## UPGRADE_NAMES kayıtları, maliyet dalları ve aşağıdaki fill bar'ları hepsi
## silindi. Sahnedeki (zaten kalıcı olarak gizli olan) ProductionPage/
## MineRow/GoldCollectorRow düğümleri artık hiçbir koddan referans almıyor.
## "Geliştirmeler" sekmesi artık silah TÜRÜNE göre değil, SIRAYA (index)
## göre çalışıyor - 5 hazır satır var ama her biri "boş bir slot", hangi
## silahı gösterdiği GameManager.owned_weapons[i]'ye göre her _refresh()'te
## yeniden belirleniyor (ikon/isim/seviye dahil). i < owned_weapons.size()
## olduğu sürece görünür, fazlası gizlenir. Bu yüzden dict değil, sıralı bir
## dizi - sıra ÖNEMLİ, owned_weapons ile aynı index'e karşılık gelmeli.
@onready var upgrade_slot_panels: Array = [
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/FireUpgradeRow,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/LightningUpgradeRow,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/TabancaUpgradeRow,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/TuftufUpgradeRow,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/TufekUpgradeRow,
]
@onready var upgrade_slot_rows: Array = [
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/FireUpgradeRow/Inner/RowVBox/HBox,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/LightningUpgradeRow/Inner/RowVBox/HBox,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/TabancaUpgradeRow/Inner/RowVBox/HBox,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/TuftufUpgradeRow/Inner/RowVBox/HBox,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage/TufekUpgradeRow/Inner/RowVBox/HBox,
]

## Dükkandaki her "seçilebilir" ürün satırının PanelContainer'ı (tıklama
## hedefi + seçiliyken vurgulanan kutu - bkz. self_modulate, _refresh_
## selection_highlight). Referans görselde her satırın kendi satın alma
## butonu / isim yazısı YOK: ikona tıklayıp seçiyorsun, sonra panelin
## altındaki TEK paylaşılan "Satın Al" butonuna basıyorsun (bkz. BuyBar,
## _on_row_gui_input, _on_buy_bar_pressed, _refresh_buy_bar). Açıklama metni
## de artık tıkla-aç bir Label değil, satırın kendi "tooltip_text"i (imleç
## üstünde bekletince görünür).
## "kind": "upgrade" -> _upgrade_cost + GameManager.<item>_level
##         "copy"    -> _copy_cost + owned_weapons'a yeni kopya ekler
## NOT: "mine"/"gold_collector" girdileri kullanıcı isteğiyle KALDIRILDI (bkz.
## yukarıdaki "satırlar KALDIRILDI" notu) - eskiden bu iki girdi, paylaşılan
## _upgrade_cost/MAX_LEVELS ve hud.gd'nin üretim butonları hâlâ bunlara
## baktığı için BİLEREK duruyordu; artık üçü de aynı anda kaldırıldığı için
## burada da hiçbir referans kalmadı.
@onready var selectable_rows := {
	"spray": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/SprayRow, "kind": "upgrade"},
	## Kullanıcı isteği: "Savunma sekmesi silinip İşlevsellik'e taşınsın" -
	## kalkan türleri artık OtherPage'in (İşlevsellik) içinde (bkz. shop_
	## panel.tscn'de move_node ile taşınmaları + DefenseTab/DefensePage'in
	## tamamen kaldırılması).
	"shield_standart": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/StandartShieldRow, "kind": "upgrade"},
	"shield_enerji": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/EnerjiShieldRow, "kind": "upgrade"},
	"shield_kale": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/KaleShieldRow, "kind": "upgrade"},
	"shield_savas": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/SavasShieldRow, "kind": "upgrade"},
	"dagger": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/DaggerRow, "kind": "copy"},
	"fire_staff": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/FireRow, "kind": "copy"},
	"lightning_staff": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/LightningRow, "kind": "copy"},
	"tabanca": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/TabancaRow, "kind": "copy"},
	"tuftuf": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/TuftufRow, "kind": "copy"},
	"tufek": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/TufekRow, "kind": "copy"},
	"arcane": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/ArcaneRow, "kind": "copy"},
	"yay": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/YayRow, "kind": "copy"},
	"crossbow": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/CrossbowRow, "kind": "copy"},
	"boomerang": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/BoomerangRow, "kind": "copy"},
	"buz_asasi": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/BuzAsasiRow, "kind": "copy"},
	"fisek": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/FisekRow, "kind": "copy"},
	"pence": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/PenceRow, "kind": "copy"},
	"topuz": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/TopuzRow, "kind": "copy"},
	"uzunkilic": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage/UzunkilicRow, "kind": "copy"},
	"shield_mod_resilience": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/ResilienceRow, "kind": "upgrade"},
	"shield_mod_thorny": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/ThornyRow, "kind": "upgrade"},
	"shield_mod_turtle": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/TurtleRow, "kind": "upgrade"},
	"shield_mod_aggressive": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/AggressiveRow, "kind": "upgrade"},
	"shield_mod_lightning": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/LightningSpeedRow, "kind": "upgrade"},
	"shield_mod_piercing": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/PiercingRow, "kind": "upgrade"},
	"shield_mod_tank": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage/TankRow, "kind": "upgrade"},
	## Eşyalar (bkz. scripts/items.gd) - "copy"a benzer ama kendi "item" türü:
	## seviyelenmezler, aynı eşyadan fazladan kopya alınabilir, hepsi TEK bir
	## slot havuzunu (player.gd get_max_item_slots) paylaşır (owned_weapons'un
	## kendi havuzundan bağımsız - bkz. _on_buy_item/_max_item_slots).
	"vitamin": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/VitaminRow, "kind": "item"},
	"eldiven": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/EldivenRow, "kind": "item"},
	"deri_cizme": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/DeriCizmeRow, "kind": "item"},
	"sigara": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/SigaraRow, "kind": "item"},
	"steroid": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/SteroidRow, "kind": "item"},
	"sansli_zar": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/SansliZarRow, "kind": "item"},
	"hasat_cantasi": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/HasatCantasiRow, "kind": "item"},
	"kalkan_yuzugu": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/KalkanYuzuguRow, "kind": "item"},
	"keskin_uclar": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/KeskinUclarRow, "kind": "item"},
	"kitelama_seti": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/KitelamaSetiRow, "kind": "item"},
	"kaos_kitabi": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/KaosKitabiRow, "kind": "item"},
	## DÜZELTME (kullanıcı bildirimi: "dükkanda bazı ekstralar görünmüyor. can
	## çalma ve bekleme süresinde azalma ekstrası görünmüyor.") - kök neden:
	## bu iki eşya items.gd'nin DEFS/KEYS listesinde zaten TANIMLIYDI ama
	## shop_panel.tscn'de karşılık gelen satır node'ları hiç oluşturulmamıştı
	## ve burada hiç eşlenmemişlerdi - dükkan HİÇBİR ZAMAN bu ikisini
	## çizmiyordu. Satırlar KaosKitabiRow ile BİREBİR aynı şablonla eklendi.
	"vampir_disi": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/VampirDisiRow, "kind": "item"},
	"yetenek_kitabi": {"panel": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage/YetenekKitabiRow, "kind": "item"},
}

## Şu an seçili (son tıklanan) ürünün anahtarı - boşsa hiçbir şey seçili
## değildir, paylaşılan buton "Seç..." yazıp devre dışı kalır.
var selected_key: String = ""

## Bir ürüne tıklanınca artık paylaşılan bir buton yerine dükkanın SOLUNDA
## açılan ayrı bir önizleme paneli gösteriliyor (bkz. kullanıcı bildirimi):
## büyük ikon önizlemesi + tüm açıklama/istatistik metni + satın alma butonu
## hep bu panelin içinde (bkz. _refresh_preview). Dükkan temasıyla aynı
## renkler (tan içerik + yeşil başlık) kullanıldı.
@onready var preview_panel: Control = $PreviewPanel
@onready var preview_name_label: Label = $PreviewPanel/PreviewNameLabel
@onready var preview_icon_holder: Control = $PreviewPanel/PreviewMargin/PreviewVBox/IconHolder
@onready var preview_status_label: Label = $PreviewPanel/PreviewMargin/PreviewVBox/StatusLabel
@onready var preview_desc_label: Label = $PreviewPanel/PreviewMargin/PreviewVBox/DescScroll/DescLabel
@onready var preview_buy_button: Button = $PreviewPanel/PreviewMargin/PreviewVBox/PreviewBuyButton
## Sadece seçili ürün sahip olunan kalkan türüyse görünür (bkz. _refresh_
## preview) - "sadece 1 kalkan alınabilmeli" kısıtlaması yüzünden, başka bir
## türe geçmeden önce bununla mevcut tür satılmalı.
@onready var preview_sell_button: Button = $PreviewPanel/PreviewMargin/PreviewVBox/PreviewSellButton

## 7 sekme tek satıra sığmayıp sağdan taşdığı için (bkz. kullanıcı bildirimi)
## TabBar artık HBoxContainer değil, 4 sütunlu bir GridContainer (2 satır:
## 4+3) - her butonun payına düşen genişlik neredeyse ikiye katlandı, metin
## artık hiçbir font boyutunda panelin dışına taşamaz.
@onready var tab_bar: GridContainer = $Frame/Margin/VBox/Body/TabBar
## "upgrades" ("Geliştirmeler") bilinçli olarak burada YOK - "Hepsi"
## sekmesinde diğer her şeyle birlikte görünmesin diye _on_tab_selected()
## onu ayrı ele alıyor (bkz. orada).
## "defense" (Savunma) bilinçli olarak burada YOK - kullanıcı isteğiyle
## "Diğer" (artık "İşlevsellik") sekmesine birleştirildi, ayrı bir sekme/
## sayfa olarak tamamen kaldırıldı (bkz. shop_panel.tscn'deki DefenseTab/
## DefensePage/DefenseHeader/DefenseDivider'ın silinmesi).
## Kullanıcı isteği: "Maden ve Altın Toplayıcı artık dükkan açmadan, ekranın
## sağındaki 2 ayrı dikey butona tıklanarak alınıp yükseltilebilsin" - bu
## ikisi ARTIK dükkanın "Üretim" sekmesinde YOK (bkz. hud.gd production_
## button.gd + _refresh_production_buttons/_on_production_button_pressed).
## "production" bu yüzden bilerek "pages"/"page_headers" sözlüklerinden
## ÇIKARILDI (aksi halde "Hepsi" sekmesi _on_tab_selected("all") ile onu
## yine göstermeye devam ederdi) - ProductionPage artık BOŞ kaldığı için
## (MineRow/GoldCollectorRow'dan başka içeriği yoktu) tüm sekme kalıcı
## olarak _ready()'de gizleniyor (bkz. aşağıdaki "Üretim sekmesi HUD'a
## taşındı" bloğu).
## GÜNCELLEME (kullanıcı isteği: "altın toplayıcı ve madeni oyundan tamamen
## kaldır ve ekranın sağındaki arayüzlerini de sil") - o sağdaki butonlar da
## kaldırıldığı için artık MAX_LEVELS/_upgrade_cost/_on_buy_upgrade (ve
## GameManager'daki maden/toplayıcı durumu) bu iki anahtarı HİÇ bilmiyor;
## burada sadece boş sekmenin gizlenmesi kaldı.
## DÜZELTME (kullanıcı isteği: "Savaş modlarını ... oyundan kaldır. Bunları
## kimse sevmedi.") - "mods" burada bilerek YOK, tıpkı "production" gibi
## (bkz. hemen üstteki not) - bu sayede "Hepsi" sekmesi (_on_tab_selected)
## onu bir daha göstermez. ModsTab/ModsPage/ModsHeader/ModsDivider _ready()'de
## kalıcı olarak gizleniyor (bkz. aşağıdaki "ProductionTab" ile AYNI blok).
@onready var pages := {
	"weapons": $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsPage,
	"other": $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage,
	"items": $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsPage,
}
## Her kategori sayfasının üstündeki başlık etiketi + ayırıcı çizgi (bkz.
## kullanıcı bildirimi: "kategoriler kafa karıştırıcı, ürün dizilimlerinde
## çizgiler yok") - "Hepsi" görünümünde art arda gelen kategoriler artık
## kendi başlıklarıyla (SİLAHLAR/SAVUNMA/...) ve altlarındaki ince bir
## çizgiyle net şekilde ayrılıyor. Sayfayla BİRLİKTE gizlenip gösterilmesi
## gerektiği için pages ile aynı anahtarları kullanan paralel bir dizi.
@onready var page_headers := {
	"weapons": [$Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsHeader, $Frame/Margin/VBox/Body/Scroll/PagesVBox/WeaponsDivider],
	## "production" burada da bilerek YOK - bkz. "pages" sözlüğü üstündeki yorum.
	"other": [$Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherHeader, $Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherDivider],
	"items": [$Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsHeader, $Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsDivider],
}
@onready var upgrades_page: GridContainer = $Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesPage
@onready var upgrade_header_nodes: Array[Control] = [
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesHeader,
	$Frame/Margin/VBox/Body/Scroll/PagesVBox/UpgradesDivider,
]

## Seçili ürün kutusunun vurgu stili - varsayılan PanelContainer stili (bkz.
## theme.tres SBF_panel) neredeyse siyah, self_modulate=1 ile göstermek
## siyah bir kutu gibi görünüyordu (bkz. kullanıcı bildirimi). Bunun yerine
## seçiliyken bu açık kahverengi/bej stil override ediliyor (bkz.
## _refresh_selection_highlight) - tek bir örnek oluşturulup paylaşılıyor.
var _selected_row_style: StyleBoxFlat
## Seçili OLMAYAN ürün kartının stili - envanter panelindeki "koyu içerik"
## kutusuyla birebir aynı (bkz. _ready(), kullanıcı isteği: dükkanın da
## envanter panelleriyle aynı arkaplan/kenarlık renklerine sahip olması).
var _card_normal_style: StyleBoxFlat

## ---------------------------------------------------------------------
## ENVANTER/İSTATİSTİK PANELİ RENK PALETİ
## ---------------------------------------------------------------------
## Kullanıcı isteği: "dükkan panelimi seviyorum ancak arkaplanları ve
## kenarlıkları renkleri pek hoşuma gitmiyor, tıpkı envanter panellerine
## yaptığın gibi yapmanı istiyorum". Aşağıdaki renkler inventory_panel.tscn
## ve stats_panel.tscn'deki StyleBoxFlat'lerden BİREBİR alındı.
##
## NOT: Bu stiller neden .tscn yerine KODDA uygulanıyor? Dükkan sahnesindeki
## arkaplanlar eskiden shop_redesign/*.png dokularına dayanan
## StyleBoxTexture'lardı. Bunları .tscn içinde StyleBoxFlat'e çevirmeyi
## denedim, ancak Godot editörü sahne açıkken kendi (eski) bellek kopyasını
## diske geri yazıp KAYNAK TÜRÜ değişen her stili eski haline döndürüyor
## (aynı sorunu hud.tscn'de de yaşadık). Kodda uygulamak bu sorundan tamamen
## bağımsız ve her çalıştırmada garanti.
const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)
## Ana pencerenin dış kontürü: arkaplandan ayrışsın ama pixel paletinden
## kopmasın diye koyu kahverengi tutuluyor.
const PAL_WINDOW_BORDER := Color(0.25, 0.15, 0.08, 1.0)
const PAL_HEADER_BG := Color(0.42, 0.28, 0.16, 1.0)
const PAL_HEADER_BORDER := Color(0.28, 0.17, 0.09, 1.0)
const PAL_CONTENT_BG := Color(0.23921569, 0.2, 0.14901961, 1.0)
const PAL_CONTENT_BORDER := Color(0.16862746, 0.13725491, 0.101960786, 1.0)
## Seçili/vurgulu ögelerde kullanılan altın sarısı aksan.
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)

## Açılış animasyonu - inventory_panel.gd/stats_panel.gd'deki BİREBİR aynı
## desen (kullanıcı isteği: "dükkan animasyonlu ease ease açılmıyor onu
## yapmamışsın" - o iki panelde vardı, dükkanda unutulmuştu). hud.gd bu
## paneli sadece "visible = not visible" ile açıp kapatıyor, davranışı hiç
## değiştirmeden animasyonu eklemek için NOTIFICATION_VISIBILITY_CHANGED
## dinleniyor - hud.gd'ye dokunmaya gerek yok.
const OPEN_ANIM_DURATION := 0.2
const OPEN_ANIM_START_SCALE := 0.9
var _open_tween: Tween = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_play_open_animation()


## Kısa, tek seferlik bir ease-out büyüme+belirme - zıplama/elastik yok, göz
## yormasın diye hızlı (bkz. OPEN_ANIM_DURATION).
func _play_open_animation() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	scale = Vector2(OPEN_ANIM_START_SCALE, OPEN_ANIM_START_SCALE)
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.set_trans(Tween.TRANS_CUBIC)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_ANIM_DURATION)
	_open_tween.tween_property(self, "scale", Vector2.ONE, OPEN_ANIM_DURATION)


## Paletten tek satırda StyleBoxFlat üretir - envanter/istatistik
## panellerindeki kutuların hepsi bu şekilde (düz renk + tek renk kenarlık +
## yuvarlatılmış köşe) tanımlı olduğu için tek bir yardımcı yeterli.
##
## DÜZELTME (kullanıcı isteği: "dükkan, envanter, kart seçim ekranı ve sandık
## seçim ekranı kartlarına/panellerine dışlarına çerçeve eklemeni istiyorum
## hafif gölgesi olsun ve panele sızsın, böyle çok çiğ duruyorlar") - artık
## HER kutu varsayılan olarak dışına doğru yumuşakça yayılan (bg'ye "sızan")
## hafif bir gölge alıyor. StyleBoxFlat'in yerleşik shadow_* özellikleri tam
## bunun için var - kutunun kendi kenarlığının HEMEN dışında, arkaplanın
## üzerine binen soft bir karartma çiziyor. with_shadow=false ile (ör. çok
## küçük/ince ayırıcı çizgiler için) devre dışı bırakılabilir.
static func _make_flat(bg: Color, border: Color, border_width: int, radius: int, with_shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	if with_shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(3, 4)
	return sb


## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni istiyorum.
## tıklanabilen bütün butonlar bununla değişecek" - ahşap plaka görseli
## (assets/ui/newui/button_wood.png). Oyundaki HER Button'ın (dükkan/mini
## dükkan/envanter/dükkan sekmeleri/level atlama/silah-kalkan seçimi/sandık/
## keybind/karakter seçimi/lobi v.b.) normal/hover/pressed/disabled
## stilleri artık TEK bu dokudan üretiliyor - önceki düz renkli StyleBoxFlat
## butonları (bkz. _make_flat'in KENDİSİ, hâlâ panel/kart arkaplanları için
## kullanılıyor, SADECE Button'lar bundan ayrıldı) yerini aldı. Tek bir
## PNG'den 4 durumu üretebilmek için StyleBoxTexture'ın modulate_color'ı
## kullanılıyor (bkz. assets/fonts/theme.tres'teki AYNI teknik, eski yeşil
## buton setinde de zaten vardı) - ayrı hover/pressed/disabled görseli
## ÜRETMEYE gerek yok, tek kaynak dosya asla iki yere kopyalanmıyor.
## DÜZELTME (kullanıcı isteği: "assets/ui/new shop design içindeki Button
## resmini oyunumdaki tüm butonlarla değiştir, boyutlarını bu resmi
## bozmayacak şekilde ayarla") - eski button_wood.png (94x34) yerine yeni
## doku (83x23). texture_margin'ler ayarlanıp 9-patch köşeler/kenarlık HİÇ
## esnemesin, sadece düz iç dolgu gerektiği kadar yatayda uzasın diye.
## DÜZELTME 2 (kullanıcı bildirimi: "bu butonlar seçtiğim butona benzemiyor,
## yanlış yapılmış" - ekran görüntüsünde geniş menü butonlarında ahşap damar
## çizgileri ortaya doğru gerilip bulanıklaşıyordu): ilk ölçüm SADECE tek bir
## orta satırı örneklemişti ve o satır tam damar çizgileri arasındaki boşluğa
## denk gelmişti - margin 7px çıkmıştı. Görselin TÜM satırları taranınca asıl
## damar deseninin sol/sağ kenardan ~20px içeri kadar uzandığı ortaya çıktı
## (bkz. y=7/11/15/18 satırlarındaki koyu pikseller x=19'a kadar gidiyor) -
## eski 7px margin bu deseni ortadan kesip esneyen bölgeye sızdırıyordu.
const ButtonWoodTexture := preload("res://assets/ui/new shop design/Button.png")
const BUTTON_WOOD_MARGIN_H := 20.0
const BUTTON_WOOD_MARGIN_V := 4.0
## Durum başına ton (bkz. yukarıdaki not) - normal=doku olduğu gibi,
## hover=hafif aydınlık, pressed=belirgin koyu/basılmış hissi, disabled=soluk/
## gri-mat. Tıpkı theme.tres'teki SBT_disabled'ın modulate_color'ı gibi.
const BUTTON_WOOD_TINT_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_WOOD_TINT_HOVER := Color(1.22, 1.14, 1.04, 1.0)
const BUTTON_WOOD_TINT_PRESSED := Color(0.72, 0.68, 0.64, 1.0)
const BUTTON_WOOD_TINT_DISABLED := Color(0.55, 0.55, 0.55, 0.75)
## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - "focus" stili
## eskiden BUTTON_WOOD_TINT_NORMAL ile AYNIYDI (bkz. aşağıdaki _apply_*
## fonksiyonları), yani klavye/gamepad odağı oyunda HİÇBİR yerde görünmüyordu
## (bu iki fonksiyon neredeyse her ekranın kendi butonlarında kullanılıyor,
## bkz. UISound.apply_wood_buttons). Belirgin ama göz yormayan altın bir
## parlaklık - mouse tıklamasından sonra da kısaca görünür (Godot'un
## varsayranı budur), bilerek yumuşak tutuldu.
const BUTTON_WOOD_TINT_FOCUS := Color(1.4, 1.15, 0.6, 1.0)

static func _make_wood_button_style(tint: Color = BUTTON_WOOD_TINT_NORMAL) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = ButtonWoodTexture
	sb.texture_margin_left = BUTTON_WOOD_MARGIN_H
	sb.texture_margin_right = BUTTON_WOOD_MARGIN_H
	sb.texture_margin_top = BUTTON_WOOD_MARGIN_V
	sb.texture_margin_bottom = BUTTON_WOOD_MARGIN_V
	sb.modulate_color = tint
	return sb


## bkz. _make_wood_button_style üstündeki notlar - herhangi bir Button'a TEK
## çağrıda normal/hover/pressed/disabled (+ focus, normal'le aynı) ahşap
## stilini uygular. Oyundaki HER dosyanın kendi 4 satırlık tekrar eden
## add_theme_stylebox_override bloğu yerine bunu çağırması yeterli.
static func _apply_wood_button_style(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.add_theme_stylebox_override("normal", _make_wood_button_style(BUTTON_WOOD_TINT_NORMAL))
	btn.add_theme_stylebox_override("hover", _make_wood_button_style(BUTTON_WOOD_TINT_HOVER))
	btn.add_theme_stylebox_override("pressed", _make_wood_button_style(BUTTON_WOOD_TINT_PRESSED))
	btn.add_theme_stylebox_override("disabled", _make_wood_button_style(BUTTON_WOOD_TINT_DISABLED))
	btn.add_theme_stylebox_override("focus", _make_wood_button_style(BUTTON_WOOD_TINT_FOCUS))


## Kullanıcı isteği: "dükkan kategori butonları veya aşırı dar olan butonlar
## için mini button dosyasını kullan" - Button.png GENİŞ bir dikdörtgen
## (83x23); kare/ikon-benzeri butonlara (kategori sekmeleri, kapat ikonları,
## kalkan modu slotları gibi) uygulanırsa kenarlığı orantısız/yassı görünürdü.
## mini button.png (30x30, KARE) bu tür butonlar için ayrı bir doku - aynı
## normal/hover/pressed/disabled tonlama tekniği, sadece kaynak dokusu ve
## kenarlık ölçüsü farklı. DÜZELTME (bkz. BUTTON_WOOD_MARGIN_H üstündeki
## "DÜZELTME 2" notu - AYNI ölçüm hatası burada da vardı): görselin TÜM
## piksellerini tarayınca ahşap damar deseninin her kenardan ~15px içeri
## kadar (30x30'luk görselin neredeyse TAMAMI) uzandığı ortaya çıktı - ama tam
## 15 kullanılınca (sol+sağ = tam 30 = kaynağın TAMAMI, orta esneme payı SIFIR)
## en küçük hedef boyutlarda (40x40 gibi) köşeler arasında BOŞLUK/delik
## oluştu (görsel olarak simüle edilip doğrulandı). 11 hem deseni byük ölçüde
## koruyor hem 40x40'tan büyük TÜM gerçek kullanım boyutlarında (40-64px)
## delik oluşturmuyor.
const MiniButtonWoodTexture := preload("res://assets/ui/new shop design/mini button.png")
const BUTTON_MINI_WOOD_MARGIN := 11.0

static func _make_mini_wood_button_style(tint: Color = BUTTON_WOOD_TINT_NORMAL) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = MiniButtonWoodTexture
	sb.texture_margin_left = BUTTON_MINI_WOOD_MARGIN
	sb.texture_margin_right = BUTTON_MINI_WOOD_MARGIN
	sb.texture_margin_top = BUTTON_MINI_WOOD_MARGIN
	sb.texture_margin_bottom = BUTTON_MINI_WOOD_MARGIN
	sb.modulate_color = tint
	return sb


static func _apply_mini_wood_button_style(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.add_theme_stylebox_override("normal", _make_mini_wood_button_style(BUTTON_WOOD_TINT_NORMAL))
	btn.add_theme_stylebox_override("hover", _make_mini_wood_button_style(BUTTON_WOOD_TINT_HOVER))
	btn.add_theme_stylebox_override("pressed", _make_mini_wood_button_style(BUTTON_WOOD_TINT_PRESSED))
	btn.add_theme_stylebox_override("disabled", _make_mini_wood_button_style(BUTTON_WOOD_TINT_DISABLED))
	btn.add_theme_stylebox_override("focus", _make_mini_wood_button_style(BUTTON_WOOD_TINT_FOCUS))


## Dükkanın tüm arkaplan/kenarlık stillerini envanter ve istatistik
## panelleriyle aynı palete çeker (bkz. PAL_* sabitleri ve oradaki not -
## bu iş bilerek .tscn'de değil BURADA yapılıyor).
func _apply_inventory_palette() -> void:
	## Ana pencere gövdesi + soldaki önizleme panelinin gövdesi.
	## Kullanıcı isteği: "dükkan panelinin kenarları oval olması gerekiyor" -
	## köşe yarıçapı büyük tutuluyor (28) ki pencere belirgin şekilde
	## yuvarlak/oval görünsün.
	var window_style: StyleBoxFlat = _make_flat(PAL_WINDOW_BG, PAL_WINDOW_BORDER, 4, 28)
	for path: String in ["Frame/ContentBG", "PreviewPanel/PreviewBG"]:
		var bg: Panel = get_node_or_null(path) as Panel
		if bg:
			## Sahnedeki eski doku stilinin üstüne binen renk çarpanı
			## (self_modulate) düz renkte yanlış tona sebep olur - nötrle.
			bg.self_modulate = Color(1, 1, 1, 1)
			bg.add_theme_stylebox_override("panel", window_style)

	## Başlık çubukları - envanterdeki başlıkla aynı: sadece ALT kenarlık.
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = PAL_HEADER_BG
	header_style.border_width_bottom = 4
	header_style.border_color = PAL_HEADER_BORDER
	header_style.corner_radius_top_left = 28
	header_style.corner_radius_top_right = 28
	header_style.shadow_color = Color(0, 0, 0, 0.35)
	header_style.shadow_size = 2
	header_style.shadow_offset = Vector2(3, 4)
	for path: String in ["Frame/HeaderBG", "PreviewPanel/PreviewHeaderBG"]:
		var header: Panel = get_node_or_null(path) as Panel
		if header:
			header.self_modulate = Color(1, 1, 1, 1)
			header.add_theme_stylebox_override("panel", header_style)

	## Sol kategori şeridi - envanterdeki "koyu içerik" tonu.
	var sidebar: Panel = get_node_or_null("Frame/SidebarBG") as Panel
	if sidebar:
		var sidebar_style := StyleBoxFlat.new()
		sidebar_style.bg_color = PAL_CONTENT_BG
		sidebar_style.border_width_right = 2
		sidebar_style.border_width_bottom = 2
		sidebar_style.border_color = PAL_CONTENT_BORDER
		sidebar_style.corner_radius_bottom_left = 12
		sidebar_style.shadow_color = Color(0, 0, 0, 0.35)
		sidebar_style.shadow_size = 2
		sidebar_style.shadow_offset = Vector2(3, 4)
		sidebar.self_modulate = Color(1, 1, 1, 1)
		sidebar.add_theme_stylebox_override("panel", sidebar_style)

	## Önizleme panelindeki açıklama kutusu - stats_panel.tscn'deki
	## GridScroll ile aynı (koyu içerik kutusu). Eskiden hiç stili yoktu, bu
	## yüzden temanın açık krem varsayılanına düşüp panelin geri kalanıyla
	## uyumsuz duruyordu.
	var desc_scroll: ScrollContainer = get_node_or_null(
		"PreviewPanel/PreviewMargin/PreviewVBox/DescScroll") as ScrollContainer
	if desc_scroll:
		var desc_style := _make_flat(PAL_CONTENT_BG, PAL_CONTENT_BORDER, 2, 12)
		desc_style.content_margin_left = 8.0
		desc_style.content_margin_right = 8.0
		desc_style.content_margin_top = 6.0
		desc_style.content_margin_bottom = 6.0
		desc_scroll.add_theme_stylebox_override("panel", desc_style)
		## BUG DÜZELTMESİ: kutunun arkaplanı koyulaştı ama içindeki metnin
		## rengi (.tscn'de hâlâ eski AÇIK temaya göre ayarlanmış koyu kahve,
		## Color(0.22,0.15,0.08)) hiç güncellenmemişti - koyu metin koyu
		## arkaplanın üstünde neredeyse tamamen görünmez oluyordu (bkz.
		## kullanıcı bildirimi: "eşyaların özelliklerini gösteren panelde
		## yazılar hiç görünmüyor"). Diğer panellerdeki açık krem metin
		## rengiyle aynısı uygulanıyor.
		var desc_label: Label = desc_scroll.get_node_or_null("DescLabel") as Label
		if desc_label:
			desc_label.add_theme_color_override("font_color", Color(0.96, 0.89, 0.74, 1))

	## Ana ürün listesi kaydırma alanı - sayfadaki ürünlerin kenarlara sıkışmasını
	## ve sağdaki dikey kaydırma çubuğuyla üst üste binmesini önlemek için
	## simetrik iç kenar boşlukları (paddings) uygulandı.
	var scroll: ScrollContainer = get_node_or_null("Frame/Margin/VBox/Body/Scroll") as ScrollContainer
	if scroll:
		var scroll_style := StyleBoxFlat.new()
		scroll_style.bg_color = PAL_CONTENT_BG
		scroll_style.border_width_left = 2
		scroll_style.border_width_top = 2
		scroll_style.border_width_right = 0
		scroll_style.border_width_bottom = 0
		scroll_style.border_color = PAL_CONTENT_BORDER
		scroll_style.corner_radius_bottom_right = 12
		scroll_style.shadow_color = Color(0, 0, 0, 0.35)
		scroll_style.shadow_size = 2
		scroll_style.shadow_offset = Vector2(3, 4)
		scroll_style.content_margin_left = 12.0
		scroll_style.content_margin_right = 16.0
		scroll_style.content_margin_top = 14.0
		scroll_style.content_margin_bottom = 14.0
		scroll.add_theme_stylebox_override("panel", scroll_style)

	# Asimetrik boşlukları (kırmızı oklarla işaretlenen üst ve alt boşlukları) kapatmak
	# ve kutucukların olduğu paneli sağa kaydırmak için hizalamalar.
	var margin_node: MarginContainer = get_node_or_null("Frame/Margin") as MarginContainer
	if margin_node:
		margin_node.add_theme_constant_override("margin_bottom", 0)
		margin_node.add_theme_constant_override("margin_top", 15)
		
	var vbox_node: VBoxContainer = get_node_or_null("Frame/Margin/VBox") as VBoxContainer
	if vbox_node:
		vbox_node.add_theme_constant_override("separation", 15)
		
	var body_node: HBoxContainer = get_node_or_null("Frame/Margin/VBox/Body") as HBoxContainer
	if body_node:
		body_node.add_theme_constant_override("separation", 20)

	## Aynı bug: seviye/sahiplik durumu yazısı (StatusLabel) da eski koyu
	## kahve renkteydi - artık koyulaşan genel pencere arkaplanında zayıf
	## okunuyordu, aynı açık krem tona çekildi.
	var status_label: Label = get_node_or_null(
		"PreviewPanel/PreviewMargin/PreviewVBox/StatusLabel") as Label
	if status_label:
		status_label.add_theme_color_override("font_color", Color(0.96, 0.89, 0.74, 1))

	## Satın alma / yükseltme butonları - hem önizleme panelindeki tek
	## "Satın Al" butonu hem de "Geliştirmeler" sekmesindeki 5 slotun kendi
	## butonu, oyundaki HER buton gibi ahşap plaka stiline sahip (bkz.
	## _apply_wood_button_style üstündeki kullanıcı isteği notu).
	var buy_buttons: Array[Button] = []
	var preview_buy: Button = get_node_or_null(
		"PreviewPanel/PreviewMargin/PreviewVBox/PreviewBuyButton") as Button
	if preview_buy:
		buy_buttons.append(preview_buy)
	var preview_sell: Button = get_node_or_null(
		"PreviewPanel/PreviewMargin/PreviewVBox/PreviewSellButton") as Button
	if preview_sell:
		buy_buttons.append(preview_sell)
	for row: Node in upgrade_slot_rows:
		var up_btn: Button = row.get_node_or_null("UpgradeButton") as Button
		if up_btn:
			buy_buttons.append(up_btn)
	for btn: Button in buy_buttons:
		_apply_wood_button_style(btn)

	## Kategori sekmeleri - seçili sekme "pressed" tonuyla (daha koyu/basılmış
	## görünsün diye) işaretleniyor, diğerleri normal ahşap kalıyor. Kare
	## (64x64) oldukları için GENİŞ Button.png yerine KARE mini button.png
	## kullanılıyor (bkz. _make_mini_wood_button_style üstündeki not).
	var bar: Node = get_node_or_null("Frame/Margin/VBox/Body/TabBar")
	if bar:
		for child: Node in bar.get_children():
			if child is Button:
				var tab: Button = child
				tab.add_theme_stylebox_override("normal", _make_mini_wood_button_style(BUTTON_WOOD_TINT_NORMAL))
				tab.add_theme_stylebox_override("hover", _make_mini_wood_button_style(BUTTON_WOOD_TINT_HOVER))
				tab.add_theme_stylebox_override("pressed", _make_mini_wood_button_style(BUTTON_WOOD_TINT_PRESSED))
				tab.add_theme_stylebox_override("focus", _make_mini_wood_button_style(BUTTON_WOOD_TINT_PRESSED))


var _ready_done := false

func _ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bu panel bilerek
	## get_tree().paused kullanmıyor (takım arkadaşları dışarıda oynamaya
	## devam edebilsin diye), bu yüzden main.gd'nin genel ui_cancel/pause-
	## toggle kontrolü bu panel açıkken de çalışıp pause menüsünü ÜSTÜNE
	## açardı - artık GameManager'a kaydolup (bkz. o dosyadaki "ENGELLEYİCİ
	## PANEL KAYDI" notu) kendi ui_cancel'ını kendi _process()'inde işliyor.
	GameManager.register_blocking_panel(self)
	pivot_offset = size * 0.5
	## Kullanıcı isteği (#34, ve tekrar: "dükkan paneli ekranın ortasında
	## açılsın sağ altta değil") - eskiden burada .tscn'deki köşe anchor'ına
	## rağmen açılışta merkeze zıplatan bir global_position hilesi vardı, ama
	## anchor'lar hâlâ köşedeyken bu Godot'un kendi layout yeniden
	## hesaplamasıyla ezilip panel köşeye geri dönebiliyordu. Artık kök
	## Control'ün anchor'ının KENDİSİ merkez (bkz. shop_panel.tscn) - ayrı bir
	## koda gerek yok, sürükleme sistemi (window_drag_handler.gd) zaten
	## global_position ile çalışıp anchor'dan bağımsız.
	## Kullanıcı isteği: dükkan artık envanter/istatistik panelleriyle AYNI
	## renk paletini kullanıyor (bkz. shop_panel.tscn üstündeki palet notu).
	## Seçili kart ve seçili olmayan kart stilleri - kutucukların kontürleri belirginleştirildi,
	## arka plan renkleri farklılaştırılarak sayfayla kaynaşması önlendi.
	_selected_row_style = _make_flat(Color(0.42, 0.33, 0.24, 1.0), PAL_ACCENT, 4, 16)
	_card_normal_style = _make_flat(Color(0.34, 0.27, 0.20, 1.0), Color(0.18, 0.12, 0.07, 1.0), 3, 16)
	_apply_inventory_palette()

	## NOT: Bu "Üretim" sekmesi kalıcı olarak gizleniyor. Sekmenin içeriği
	## (Maden/Altın Toplayıcı satırları) KULLANICI İSTEĞİYLE TAMAMEN KALDIRILDI
	## (bkz. yukarıdaki "satırlar KALDIRILDI" notu) - sahnedeki ProductionPage/
	## MineRow/GoldCollectorRow düğümleri artık hiçbir koddan referans almıyor,
	## bu blok yalnızca boş sekmenin görünmemesini garanti ediyor.
	var production_tab: Button = get_node_or_null("Frame/Margin/VBox/Body/TabBar/ProductionTab") as Button
	if production_tab:
		production_tab.visible = false
		production_tab.disabled = true
	var production_page: Control = get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/ProductionPage") as Control
	if production_page:
		production_page.visible = false
	var production_header: Control = get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/ProductionHeader") as Control
	if production_header:
		production_header.visible = false
	var production_divider: Control = get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/ProductionDivider") as Control
	if production_divider:
		production_divider.visible = false

	## DÜZELTME (kullanıcı isteği: "Savaş modlarını ve savaş modları için
	## skill panelinin aşağısına eklenen slotları oyundan kaldır. Bunları
	## kimse sevmedi.") - "Modlar" sekmesi (buton + sayfa + başlık + ayırıcı
	## çizgi) ProductionTab ile BİREBİR AYNI desenle kalıcı olarak gizlendi
	## (bkz. yukarıdaki "pages"/"page_headers" sözlüklerinden "mods"
	## çıkarılması - bu sayede _on_tab_selected("all") onu bir daha görünür
	## yapmaz). shield_mod_* satırları/COST sabitleri BİLEREK dokunulmadı -
	## MAX_LEVELS/_upgrade_cost/_refresh_price_labels gibi paylaşılan
	## fonksiyonlar hâlâ bunlara bakıyor, sadece artık hiçbir yerden
	## satın alınamıyorlar (sayfa erişilemez).
	var mods_tab: Button = get_node_or_null("Frame/Margin/VBox/Body/TabBar/ModsTab") as Button
	if mods_tab:
		mods_tab.visible = false
		mods_tab.disabled = true
	var mods_page: Control = get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsPage") as Control
	if mods_page:
		mods_page.visible = false
	var mods_header: Control = get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsHeader") as Control
	if mods_header:
		mods_header.visible = false
	var mods_divider: Control = get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/ModsDivider") as Control
	if mods_divider:
		mods_divider.visible = false

	## Kategori başlıkları koyu yeşil yerine kartlardaki metinle aynı
	## açık krem tonda; seçili sekme dışındaki başlıklar zaten gizlenir.
	for key: String in page_headers:
		var header_label: Label = page_headers[key][0] as Label
		header_label.add_theme_color_override("font_color", Color(0.96, 0.89, 0.74, 1))
		header_label.add_theme_font_size_override("font_size", 20)
		header_label.custom_minimum_size = Vector2(0, 32)
		header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var upgrades_header_label: Label = upgrade_header_nodes[0] as Label
	upgrades_header_label.custom_minimum_size = Vector2(0, 32)
	upgrades_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	UISound.connect_all_buttons(self)
	## bkz. ui_sound.gd apply_wood_buttons - dükkandaki geri kalan tüm
	## butonlar (satın al/sat/sekmeler/geliştir satırları) YUKARIDA
	## _apply_inventory_palette()'te zaten ayrı ayrı stillendi; bu SADECE
	## kare (44x44) olduğu için o taramanın bilerek atladığı Kapat butonu için.
	## Kare olduğu için (bkz. yukarısı) GENİŞ Button.png yerine mini button.png
	## kullanılıyor - bkz. _make_mini_wood_button_style üstündeki kullanıcı
	## isteği notu.
	ShopPanel._apply_mini_wood_button_style($Frame/Margin/VBox/TitleBar/CloseButton)
	$Frame/Margin/VBox/TitleBar/CloseButton.pressed.connect(_on_close_pressed)

	## Her satır kendi butonuna değil, tıklanınca seçilip (bkz. self_modulate
	## vurgusu) SOLDAKİ önizleme panelinin (PreviewPanel) tek "Satın Al"
	## butonuna bağlanıyor - bkz. selectable_rows üstündeki yorum.
	for key in selectable_rows:
		var entry: Dictionary = selectable_rows[key]
		var panel: PanelContainer = entry["panel"]
		var row_name_label: Label = panel.get_node_or_null("Inner/RowVBox/HBox/NameLabel") as Label
		if row_name_label:
			## DÜZELTME (kullanıcı bildirimi: "ekstralarda item isimleri dosya
			## isimleriyle adlandırılmış") - bu satır TÜM satırların (upgrade/
			## copy/item) isim etiketini UPGRADE_NAMES'ten okuyordu, ama
			## UPGRADE_NAMES sadece "upgrade"/"copy" türü anahtarları içeriyor
			## (silahlar/kalkanlar/modlar) - "item" türü (Ekstralar sekmesi,
			## bkz. items.gd) anahtarları orada YOK, bu yüzden .get(key, key)
			## FALLBACK'i devreye girip ham anahtarı (ör. "kalkan_yuzugu") ham
			## haliyle basıyordu - .tscn'de elle yazılmış doğru isim ("Kalkan
			## Yüzüğü") bu satırla EZİLİYORDU. "item" türü artık kendi asıl
			## kaynağından (Items.get_def) okunuyor.
			if entry.get("kind") == "item":
				row_name_label.text = Items.get_def(key).get("name", key.capitalize())
			else:
				row_name_label.text = UPGRADE_NAMES.get(key, key)
		panel.gui_input.connect(_on_row_gui_input.bind(key))
		
		# Açıklamayı kaydedip varsayılan hover tooltip'i kapatıyoruz
		panel.set_meta("description", panel.tooltip_text)
		panel.tooltip_text = ""
		
		# Eşyaların yeni pixel art ikonları için anahtar bilgisini ve opak modulate rengini ayarla
		if entry.get("kind") == "item":
			var icon_node = panel.get_node_or_null("Inner/RowVBox/HBox/Icon")
			if icon_node:
				if "item_key" in icon_node:
					icon_node.item_key = key
				icon_node.modulate = Color(1, 1, 1, 1)
		# Silah kopyalarının ikonlarını dükkanda da karakter üzerindeki (yeni v3) görsellerle eşleştir
		elif entry.get("kind") == "copy":
			var icon_node = panel.get_node_or_null("Inner/RowVBox/HBox/Icon")
			if icon_node and icon_node is TextureRect:
				var tex_path = WEAPON_ICON_TEXTURES.get(key)
				if tex_path != "":
					icon_node.texture = load(tex_path) as Texture2D

		## Kullanıcı isteği: "dükkandaki her eşyanın altında fiyatının
		## yazmasını istiyorum" - 39 kart hepsi .tscn'de elle kopyalanmış
		## olduğu için (bkz. selectable_rows üstündeki not) her birine tek
		## tek Label eklemek yerine burada TEK bir döngüyle ekleniyor. Kart
		## yüksekliği de PRICE_LABEL_EXTRA_HEIGHT kadar artırılıyor - aksi
		## halde bu yeni satır kartın alt kenarının dışına taşardı (bkz.
		## kullanıcı isteği "yazıların dışarı taşmamasına özen göster").
		var row_vbox: VBoxContainer = panel.get_node("Inner/RowVBox")
		var price_label := Label.new()
		price_label.name = "PriceLabel"
		## Kullanıcı isteği: "dükkandaki altın bedellerinin yazısını azcık
		## büyüt", sonra netleştirildi: "%30 büyüt" - 16->21 (×1.3), kutunun
		## yüksekliği de taşmaması için artırıldı. outline_size ince m5x7
		## fontunun detaylarını yutmasın diye orana göre küçültüldü (bkz.
		## hud.tscn'deki aynı düzeltme).
		price_label.custom_minimum_size = Vector2(104, 27)
		price_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.clip_text = true
		price_label.add_theme_font_size_override("font_size", 21)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		row_vbox.add_child(price_label)
		entry["price_label"] = price_label
		panel.custom_minimum_size.y += PRICE_LABEL_EXTRA_HEIGHT
	preview_buy_button.pressed.connect(_on_buy_bar_pressed)
	preview_sell_button.pressed.connect(_on_sell_shield)

	## Her slot butonunun bağlandığı SIRA sabit (0..4), hangi silahı temsil
	## ettiği (owned_weapons[i]) her _refresh()'te değişebilir - bkz.
	## upgrade_slot_rows üzerindeki yorum.
	for i in range(upgrade_slot_rows.size()):
		upgrade_slot_rows[i].get_node("UpgradeButton").pressed.connect(_on_upgrade_weapon.bind(i))
		upgrade_slot_rows[i].get_node("SellButton").pressed.connect(_on_sell_weapon.bind(i))

	$Frame/Margin/VBox/Body/TabBar/AllTab.pressed.connect(_on_tab_selected.bind("all"))
	$Frame/Margin/VBox/Body/TabBar/WeaponsTab.pressed.connect(_on_tab_selected.bind("weapons"))
	## DefenseTab (Savunma) kaldırıldı - kalkanlar artık "other" (İşlevsellik)
	## sekmesinin içinde, bkz. pages/page_headers/selectable_rows.
	## ProductionTab artık _ready() içinde kalıcı olarak gizli/disabled
	## (bkz. yukarıdaki "Üretim sekmesi HUD'a taşındı" notu) - bu bağlantı
	## bu yüzden asla tetiklenmiyor, sadece ileride biri butonu yanlışlıkla
	## tekrar görünür yaparsa "all" mantığıyla tutarlı davransın diye
	## kasıtlı olarak silinmedi.
	$Frame/Margin/VBox/Body/TabBar/ProductionTab.pressed.connect(_on_tab_selected.bind("production"))
	$Frame/Margin/VBox/Body/TabBar/OtherTab.pressed.connect(_on_tab_selected.bind("other"))
	$Frame/Margin/VBox/Body/TabBar/ModsTab.pressed.connect(_on_tab_selected.bind("mods"))
	$Frame/Margin/VBox/Body/TabBar/UpgradesTab.pressed.connect(_on_tab_selected.bind("upgrades"))
	$Frame/Margin/VBox/Body/TabBar/ItemsTab.pressed.connect(_on_tab_selected.bind("items"))

	_on_tab_selected("all")
	_refresh()


func _on_close_pressed() -> void:
	$AnimHelper.close_shop()
	## Animasyon bitene kadar beklemeden hemen yayınlanıyor - dinleyenler
	## (hud.gd eşleşen istatistik paneli, main.gd periyodik dükkan molası)
	## için "kullanıcı kapatmayı seçti" anı asıl önemli olan, görsel geçiş
	## kapanmayı bekletmemeli (bkz. shop_panel_anim.gd close_shop, ~160-320ms).
	closed.emit()


## Bir ürün ikonuna (satırın herhangi bir yerine) tıklanınca o ürünü "seçili"
## yapar - referans görselde satırların kendi butonu yok, seçili ürün panelin
## altındaki TEK paylaşılan "Satın Al" butonuyla (BuyBar) satın alınıyor.
func _on_row_gui_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_key = key
		_refresh()


## Şu an seviyesi >0 olan (yani "sahip olunan") tek kalkan türünün
## anahtarını döner - kullanıcı isteğiyle ("sadece 1 kalkan alınabilmeli")
## aynı anda en fazla biri olabilir, hiçbiri yoksa "" döner. player.gd'deki
## _owned_shield_type_key ile BİREBİR aynı mantık, dükkan burada GameManager'a
## doğrudan bakıyor (player her zaman sahnede olmayabilir - ör. ana menüde).
func _owned_shield_type() -> String:
	for key in SHIELD_TYPE_KEYS:
		if int(GameManager.get(key + "_level")) > 0:
			return key
	return ""


## BuyBar'daki paylaşılan butona basılınca, o an seçili ürünün TÜRÜNE göre
## (bkz. selectable_rows) doğru satın alma fonksiyonuna yönlendirir.
func _on_buy_bar_pressed() -> void:
	if selected_key == "" or not selectable_rows.has(selected_key):
		return
	var kind: String = selectable_rows[selected_key]["kind"]
	if kind == "upgrade":
		_on_buy_upgrade(selected_key)
	elif kind == "item":
		_on_buy_item(selected_key)
	else:
		_on_buy_copy(selected_key)


## "all" shows every category stacked together (scrollable if it doesn't
## fit); any other value shows just that one category's page. "Geliştirmeler"
## (upgrades_page) bilinçli olarak "all"a dahil DEĞİL - kullanıcı isteği
## üzerine ayrı tutuldu, sadece kendi sekmesi tıklandığında görünür, yoksa
## "Hepsi" görünümü hem silah satın alma hem de aynı silahların seviye/satış
## satırlarını art arda göstererek karmaşıklaşırdı.
func _on_tab_selected(category: String) -> void:
	for key in pages:
		var page_visible: bool = category == "all" or key == category
		pages[key].visible = page_visible
		## "Hepsi" görünümünde bütün kategori başlıkları; tek bir kategori
		## seçiliyken ise yalnızca seçili sayfanın kendi başlığı görünür.
		## Böylece hangi sekmenin açık olduğu içerikte de net anlaşılır.
		var show_header: bool = category == "all" or key == category
		for header_node: Control in page_headers[key]:
			header_node.visible = show_header
	upgrades_page.visible = category == "upgrades"
	for header_node: Control in upgrade_header_nodes:
		header_node.visible = category == "upgrades"


func _process(_delta: float) -> void:
	## NOT: Eskiden burada maden/altın toplayıcının dolum barları
	## (mine_fill_bar/gold_collector_fill_bar) güncelleniyordu - ikisi de
	## kullanıcı isteğiyle kaldırıldı (bkz. yukarıdaki aynı not).
	_refresh_price_labels()
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bkz. _ready()
	## içindeki register_blocking_panel notu; bu panel kendi ui_cancel'ını
	## kendi işliyor (main.gd'nin genel pause-toggle'ı bu panel açıkken
	## atlanıyor, bkz. GameManager.is_any_blocking_panel_open).
	if visible and Input.is_action_just_pressed("ui_cancel"):
		_on_close_pressed()


## Her kartın altındaki PriceLabel'ı günceller (bkz. _ready() içindeki
## oluşturma döngüsü) - her karede çalışır çünkü fiyatlar seviye/sahiplik
## değiştikçe (satın alma, satma) anında değişebilir. _display_cost_text
## _refresh_preview()'daki BİREBİR aynı maliyet mantığını (kind'e göre
## upgrade/item/copy) tekrar kullanır, sadece metne çeviriyor.
func _refresh_price_labels() -> void:
	for key in selectable_rows:
		var entry: Dictionary = selectable_rows[key]
		var price_label: Label = entry.get("price_label")
		if price_label:
			price_label.text = _display_cost_text(key)


## Bir kartın fiyat etiketinde gösterilecek metni hesaplar - "MAX"/"DOLU"
## durumları da dahil, _refresh_preview()'daki mantıkla tutarlı.
func _display_cost_text(key: String) -> String:
	var entry: Dictionary = selectable_rows[key]
	var kind: String = entry["kind"]
	if kind == "upgrade":
		var level: int = int(GameManager.get(key + "_level"))
		var max_level: int = MAX_LEVELS[key]
		if level >= max_level:
			return "MAX"
		return "%d Altın" % _upgrade_cost(key, level + 1)
	elif kind == "item":
		var owned_count: int = _item_count_owned(key)
		var slot_max: int = _max_item_slots()
		if GameManager.owned_items.size() >= slot_max:
			return "DOLU"
		return "%d Altın" % _item_cost(key, owned_count + 1)
	else:
		var count: int = _count_owned(key)
		if GameManager.owned_weapons.size() >= _max_owned_weapons():
			return "DOLU"
		return "%d Altın" % _copy_cost(key, count + 1)


## Cost to go from the current level to next_level. Every item uses the same
## "base * next_level^2" quadratic shape so the whole shop feels consistent,
## just with a base tuned to that item's level cap/power so maxing anything
## out is a comparably big late-run investment:
##   mine (100 lvl, passive income engine): 4   -> 40 000 gold at lvl 100
##   shield (100 lvl, core defense):        3   -> 30 000 gold at lvl 100
##   spray (10 lvl, utility knockback):     15  ->  1 500 gold at lvl 10
##   shield mods (10 lvl each):             50  ->  5 000 gold at lvl 10
##   dagger/fire_staff/lightning_staff/tabanca/tuftuf/tufek (10-30 lvl, "Geliştirmeler"
##   sekmesinde TÜM kopyalara birden uygulanan seviye): bkz. WEAPON_KEYS +
##   ilgili sabitler - fiyat tabanları aynı kaldı, sadece artık "silahı satın
##   alma" değil "sahip olunan silahı(ları) güçlendirme" fiyatı.
## TEST MODU: açıkken dükkandaki her şeyin fiyatı 1 altın oluyor, aşağıdaki
## gerçek fiyat tablosuna hiç bakılmıyor. Kullanıcı isteğiyle ("bütün
## eşyalara dengeli bir oyun deneyimi sunabilecek fiyatlar biç") artık
## KAPALI - gerçek, dengeli quadratic fiyat tablosu (aşağıdaki yorum bloğu)
## geçerli.
const DEBUG_ALL_COSTS_ONE := false

## Silah geliştirme (Geliştirmeler sekmesi) fiyat eğrisi - DÜZELTME (100-level
## rebalance, kullanıcı isteği: "geliştirme bedellerini buna göre büyük
## miktarda ucuzlatıp dengele"). Eski üstel eğri (base * level^1.6) 100
## seviyeye taşınsaydı son seviye BAŞLI BAŞINA astronomik olurdu (ör. base=100
## için ~e binlerce altın SADECE 100. seviye için) - kademe artık 100 küçük
## adıma yayıldığı için (bkz. player.gd _tier_from_level10) fiyat da öyle
## yayılmalı. Yeni eğri KAREKÖK tabanlı (level^0.5) - her tekil seviye ucuz
## kalıyor (level 2'de ~24 altın, level 100'de ~167 altın, base=100 için) VE
## 2-100 arası TOPLAM maliyet eski 2-10 arası toplamın kabaca %65'i (aynı
## base için) - hem "ucuzlat" hem "ufak ufak" isteğini birlikte karşılıyor.
const WEAPON_UPGRADE_COST_EXPONENT := 0.5
const WEAPON_UPGRADE_COST_MULT := 0.167
## Kalkan/kalkan modu için AYNI karekök eğrisi, kendi eski taban çarpanlarına
## (3 / 50) göre ayrıca kalibre edilmiş sabitler - ikisi de eski 2-30/2-10
## toplam maliyetin kabaca %65'ine denk gelecek şekilde seçildi.
const SHIELD_UPGRADE_COST_MULT := 9.166
const MOD_UPGRADE_COST_MULT := 0.372

## DÜZELTME (100->20 level rebalance): silah/kalkan/mod/mine/gold_collector
## artık 100 yerine 20 seviyeye kapalı (bkz. MAX_LEVELS üstündeki not) ama
## fiyat eğrilerinin ŞEKLİNİ (karekök/karesel) VE altındaki taban çarpanları
## (WEAPON_UPGRADE_COST_MULT vb.) DEĞİŞTİRMEDEN, "yeni seviye L'nin fiyatı,
## eski sistemdeki KARŞILIK GELEN seviyenin (L * 5, çünkü 100/20=5) fiyatına
## eşit olsun" mantığıyla eşitleniyor - next_level bu sabitle çarpılarak
## formüllere veriliyor, ayrı ayrı yeni MULT sabitleri hesaplamaya gerek
## kalmıyor. Sonuç: eski seviye 100'ün maliyeti neyse yeni seviye 20'nin
## maliyeti de AYNI (uç nokta korunuyor), aradaki her seviye orantılı.
const LEVEL_SCALE_TO_OLD_100 := 5.0

## DÜZELTME (kullanıcı bildirimi: "maden ve altın toplayıcının 20 level
## olmasını istemiştim, hala 100 level sınırındalar") - MAX_LEVELS sözlüğü
## zaten "mine"/"gold_collector" için 20 diyordu, ama hud.gd _refresh_
## production_buttons() bunu OKUMAK için `shop.call("_get_max_level", key)`
## kullanıyordu ve bu fonksiyon ShopPanel'de HİÇ TANIMLI DEĞİLDİ - has_method
## kontrolü her zaman false dönüp sessizce hardcoded "100" varsayılanına
## düşüyordu. Üretim butonları bu yüzden MAX_LEVELS'a hiç bakmadan hep 100'e
## kilitli görünüyordu. Artık gerçekten var, MAX_LEVELS'ı okuyor.
static func _get_max_level(item: String) -> int:
	return MAX_LEVELS.get(item, 100)

static func _weapon_upgrade_cost(base: int, next_level: int) -> int:
	return int(round(base * pow(float(next_level) * LEVEL_SCALE_TO_OLD_100, WEAPON_UPGRADE_COST_EXPONENT) * WEAPON_UPGRADE_COST_MULT))

static func _upgrade_cost(item: String, next_level: int) -> int:
	if DEBUG_ALL_COSTS_ONE:
		return 1
	match item:
		## NOT: "mine"/"gold_collector" maliyet dalları kullanıcı isteğiyle
		## kaldırıldı (bkz. yukarıdaki "satırlar KALDIRILDI" notu).
		## DÜZELTME (100-level rebalance): kalkanlar eskiden 30 seviyeye kapalı
		## saf karesel (3*level^2) büyüyordu - artık silahlarla AYNI karekök
		## eğrisine (bkz. WEAPON_UPGRADE_COST_EXPONENT/_MULT üstündeki not)
		## geçti, sadece kendi taban çarpanıyla (SHIELD_UPGRADE_COST_MULT).
		"shield_standart", "shield_enerji", "shield_kale", "shield_savas":
			return int(round(3 * pow(float(next_level) * LEVEL_SCALE_TO_OLD_100, WEAPON_UPGRADE_COST_EXPONENT) * SHIELD_UPGRADE_COST_MULT))
		"spray":
			return 15 * next_level * next_level
		"dagger":
			return _weapon_upgrade_cost(60, next_level)
		"fire_staff":
			return _weapon_upgrade_cost(80, next_level)
		"lightning_staff":
			return _weapon_upgrade_cost(120, next_level)
		"tabanca":
			return _weapon_upgrade_cost(100, next_level)
		"tuftuf":
			return _weapon_upgrade_cost(90, next_level)
		"tufek":
			return _weapon_upgrade_cost(100, next_level)
		"arcane":
			return _weapon_upgrade_cost(110, next_level)
		"yay":
			return _weapon_upgrade_cost(100, next_level)
		"crossbow":
			return _weapon_upgrade_cost(100, next_level)
		"boomerang":
			return _weapon_upgrade_cost(110, next_level)
		"buz_asasi":
			return _weapon_upgrade_cost(95, next_level)
		"fisek":
			return _weapon_upgrade_cost(120, next_level)
		"pence":
			return _weapon_upgrade_cost(90, next_level)
		"topuz":
			return _weapon_upgrade_cost(105, next_level)
		"uzunkilic":
			return _weapon_upgrade_cost(100, next_level)
		## DÜZELTME (100-level rebalance): kalkan modları eskiden 10 seviyeye
		## kapalı saf karesel (50*level^2) büyüyordu - AYNI karekök eğrisine
		## (kendi taban çarpanıyla) geçti.
		"shield_mod_resilience", "shield_mod_thorny", "shield_mod_turtle", "shield_mod_aggressive", "shield_mod_lightning", "shield_mod_piercing", "shield_mod_tank":
			return int(round(50 * pow(float(next_level) * LEVEL_SCALE_TO_OLD_100, WEAPON_UPGRADE_COST_EXPONENT) * MOD_UPGRADE_COST_MULT))
	return next_level


## "Silahlar" sekmesinde YENİ, bağımsız bir kopya satın almanın maliyeti -
## COPY_COST_BASE'teki tabanlar eskiden _upgrade_cost'un "silahı ilk kez
## açma" fiyatıydı, aynı "base * next_count^2" şekliyle burada yeniden
## kullanıldı. Seviye maliyetinden (_upgrade_cost) tamamen ayrı bir sayaç.
static func _copy_cost(item: String, _next_count: int) -> int:
	if DEBUG_ALL_COSTS_ONE:
		return 1
	## Kullanıcı isteği: "silahlardan fazladan kopya (en fazla 5) almak fiyatı
	## ARTTIRMASIN, hepsi aynı taban fiyattan satılsın" - eskiden her ek kopya
	## taban fiyatın yarısı kadar daha pahalıya geliyordu (1.=base, 2.=1.5*base,
	## ...), artık next_count'tan TAMAMEN bağımsız, hep aynı taban fiyat.
	## Seviye/tier yükseltme maliyeti (_upgrade_cost) buna dahil DEĞİL, kendi
	## karesel eğrisini korumaya devam ediyor - bu SADECE yeni bir kopya SATIN
	## ALMA fiyatı için.
	return int(COPY_COST_BASE.get(item, 100))


## O eşyadan (Items.KEYS'ten biri) şu an kaç kopya sahip olunduğunu sayar -
## _count_owned(silah) ile aynı fikir, sadece GameManager.owned_items'a bakıyor.
func _item_count_owned(key: String) -> int:
	var n := 0
	for entry in GameManager.owned_items:
		if entry.get("key", "") == key:
			n += 1
	return n


## Eşya kopyası fiyatı - _copy_cost ile birebir aynı "base * next_count^2"
## şekli, taban Items.DEFS[key]["cost_base"]'ten geliyor.
static func _item_cost(item: String, next_count: int) -> int:
	if DEBUG_ALL_COSTS_ONE:
		return 1
	var base: int = int(Items.get_def(item).get("cost_base", 50))
	return base * next_count * next_count


## Kaynak gerçek her zaman player.gd (get_max_item_slots) - burada sadece
## player yoksa (ör. dükkan panel önizlemesi) 0'a düşülür (henüz seviye
## atlanmadıysa da zaten 0, bkz. player.gd max_item_slots).
func _max_item_slots() -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_max_item_slots"):
		return player.get_max_item_slots()
	return 0


## Eşyalar sekmesi: KEYS'ten biri için yeni bir kopya satın alır - tüm eşya
## TÜRLERİ TEK bir slot havuzunu (_max_item_slots) paylaşır, silahlardan
## bağımsız. Geliştirilemezler, sadece kopya sayısı önemli (bkz. items.gd
## üstündeki "additive stacking" yorumu).
func _on_buy_item(item: String) -> void:
	if GameManager.owned_items.size() >= _max_item_slots():
		return
	var count: int = _item_count_owned(item)
	var cost: int = _item_cost(item, count + 1)
	if GameManager.gold < cost:
		return

	## ÖNEMLİ: player.buy_item() KENDİ İÇİNDE de aynı slot kontrolünü yapıyor
	## (bkz. player.gd) - GameManager.owned_items dizisine EKLEMEDEN ÖNCE
	## çağrılmalı, yoksa bu satın almanın kendisi diziye önce eklenmiş
	## sayılıp kontrol yanlışlıkla "dolu" görür (bkz. weapon kopyası
	## deseninden FARKLI, orada player tarafında ayrı bir kapasite kontrolü
	## yok - burada var, sıralama bu yüzden önemli).
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("buy_item") or not player.buy_item(item):
		return

	## Kullanıcı isteği: "oyundaki para ortak olmamalı herkesin parası kişisel
	## olmalı" - harcama artık başka hiçbir peer'e senkron edilmiyor (bkz.
	## spend_gold.rpc kaldırıldı), her oyuncunun altını kendi GameManager
	## kopyasında tamamen bağımsız yönetiliyor.
	GameManager.gold -= cost
	GameManager.owned_items.append({"key": item, "spent": cost})

	_refresh()


func _on_buy_upgrade(item: String) -> void:
	## Kullanıcı isteği: "sadece 1 kalkan alınabilmeli, birini alınca mevcut
	## kalkanı satmadan başka bir tane alınamamalı." Şu an BAŞKA bir tür
	## sahipse (seviyesi >0) ve tıklanan bu türden değilse, satın alma tamamen
	## reddedilir - önce _on_sell_shield() ile mevcut tür satılmalı.
	if item in SHIELD_TYPE_KEYS:
		var owned: String = _owned_shield_type()
		if owned != "" and owned != item:
			return
	## Savunma: MAX_LEVELS'ta bulunmayan bir anahtar gelirse (ör. kaldırılan
	## "mine"/"gold_collector") sessizce çık - yoksa aşağıdaki MAX_LEVELS[item]
	## erişimi çöker.
	if not MAX_LEVELS.has(item):
		return
	var level_prop := item + "_level"
	var current: int = GameManager.get(level_prop)
	var max_level: int = MAX_LEVELS[item]
	if current >= max_level:
		return
	var next_level: int = current + 1
	var cost: int = _upgrade_cost(item, next_level)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	GameManager.set(level_prop, next_level)

	var player = get_tree().get_first_node_in_group("player")
	match item:
		"shield_standart", "shield_enerji", "shield_kale", "shield_savas":
			if player and player.has_method("refresh_shield_stats"):
				player.refresh_shield_stats()
		"shield_mod_resilience", "shield_mod_thorny", "shield_mod_turtle", "shield_mod_aggressive", "shield_mod_lightning", "shield_mod_piercing", "shield_mod_tank":
			if player and player.has_method("refresh_mod_level"):
				player.refresh_mod_level(item)

	_refresh()


## O türden şu an kaç bağımsız kopya sahip olunduğunu sayar - kopya fiyatının
## (_copy_cost) "kaçıncı kopya" olduğunu bulmak için kullanılır.
func _count_owned(key: String) -> int:
	var n := 0
	for entry in GameManager.owned_weapons:
		if entry.get("key", "") == key:
			n += 1
	return n


## Kaynak gerçek her zaman player.gd (get_max_owned_weapons) - burada sadece
## player yoksa (ör. dükkan panel önizlemesi) sabit değere düşülür. Hiçbir
## karakterin ayrı bir ana silahı olmadığı için artık herkes için aynı (5).
func _max_owned_weapons() -> int:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_max_owned_weapons"):
		return player.get_max_owned_weapons()
	return MAX_OWNED_WEAPONS


## Silahlar sekmesi: WEAPON_KEYS'ten biri için bağımsız YENİ bir kopya satın
## alır - ana silahtan TAMAMEN bağımsız, kendine özel seviyesi 1'den başlar,
## diğer kopyalarla hiçbir şey paylaşmaz. Toplamda (türü fark etmeksizin)
## _max_owned_weapons()'a ulaşıldıysa yeni kopya alınamaz.
func _on_buy_copy(item: String) -> void:
	if GameManager.owned_weapons.size() >= _max_owned_weapons():
		return
	var count: int = _count_owned(item)
	var cost: int = _copy_cost(item, count + 1)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	GameManager.owned_weapons.append({"key": item, "level": 1, "spent": cost})

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("buy_weapon_copy"):
		player.buy_weapon_copy(item, 1)

	_refresh()


## Geliştirmeler sekmesi: SADECE owned_weapons[index] kopyasının kendine özel
## seviyesini arttırır - aynı türden başka kopyalar (varsa) hiç etkilenmez.
func _on_upgrade_weapon(index: int) -> void:
	if index < 0 or index >= GameManager.owned_weapons.size():
		return
	var entry: Dictionary = GameManager.owned_weapons[index]
	var key: String = entry.get("key", "")
	var level: int = entry.get("level", 1)
	var max_level: int = MAX_LEVELS[key]
	if level >= max_level:
		return
	var next_level: int = level + 1
	var cost: int = _upgrade_cost(key, next_level)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	entry["level"] = next_level
	entry["spent"] = int(entry.get("spent", 0)) + cost
	GameManager.owned_weapons[index] = entry

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_owned_weapon_level"):
		player.set_owned_weapon_level(index, next_level)

	_refresh()


## Geliştirmeler sekmesi: owned_weapons[index] kopyasını satar. İadenin
## tutarı, o kopyaya o ana kadar harcanan TOPLAM altının (kopya + seviye
## maliyetleri) %70'i - her kopya bağımsız olduğu için paylaşım/bölüştürme
## hesabına gerek yok, doğrudan o kopyanın kendi "spent" değeri kullanılır.
## Son kalan silah da satılabilir (kullanıcı isteğiyle bu kısıtlama
## kaldırıldı) - oyuncu bilerek silahsız kalabilir.
func _on_sell_weapon(index: int) -> void:
	if index < 0 or index >= GameManager.owned_weapons.size():
		return
	var entry: Dictionary = GameManager.owned_weapons[index]
	var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("remove_owned_weapon"):
		player.remove_owned_weapon(index)

	GameManager.owned_weapons.remove_at(index)
	GameManager.gold += refund

	_refresh()


## Sahip olunan TEK kalkan türünü tamamen satar (seviyeyi 0'a döndürür) -
## kullanıcı isteğiyle eklendi, başka bir türü satın alabilmek için önce bu
## çağrılmalı (bkz. _on_buy_upgrade'in başındaki engel). İade, o türe o ana
## kadar harcanan TOPLAM altının %70'i - silah satışıyla aynı oran, ama
## silahların aksine kalkan türleri "spent" değerini ayrıca saklamıyor, o
## yüzden 1'den mevcut seviyeye kadar _upgrade_cost() tekrar toplanarak
## hesaplanıyor.
func _on_sell_shield() -> void:
	var owned: String = _owned_shield_type()
	if owned == "":
		return
	var level: int = int(GameManager.get(owned + "_level"))
	var total_spent: int = 0
	for l in range(1, level + 1):
		total_spent += _upgrade_cost(owned, l)
	var refund: int = int(round(total_spent * 0.7))

	GameManager.set(owned + "_level", 0)
	GameManager.gold += refund

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("refresh_shield_stats"):
		player.refresh_shield_stats()

	_refresh()


func _refresh() -> void:
	_refresh_selection_highlight()
	_refresh_preview()
	_refresh_upgrade_page()


## Seçili ürünün satırını vurgulu gösterir, diğerlerinin kutusunu (referans
## görseldeki gibi) tamamen görünmez bırakır. Vurgu artık self_modulate'i
## tam açmak yerine (bu, temanın neredeyse siyah varsayılan panel stilini
## ortaya çıkarıyordu - bkz. kullanıcı bildirimi "arkaplanı siyah oluyor")
## _selected_row_style adlı açık kahverengi bir StyleBoxFlat override'ı ile
## yapılıyor; self_modulate sadece seçili olmayanları gizlemek için kalıyor.
func _refresh_selection_highlight() -> void:
	for key in selectable_rows:
		var panel: PanelContainer = selectable_rows[key]["panel"]
		if key == selected_key:
			panel.self_modulate = Color(1, 1, 1, 1)
			panel.add_theme_stylebox_override("panel", _selected_row_style)
		else:
			## Seçili olmayan ürün kartları HER ZAMAN görünür (net bir kart
			## sınırı olsun diye). ESKİDEN: stylebox override'ı tamamen
			## KALDIRILIP (remove_theme_stylebox_override) temanın neredeyse
			## siyah varsayılan paneline düşülüyor, sonra self_modulate ile
			## 1.55x aydınlatılıyordu - bu yüzden kartların rengi paletten
			## bağımsız, kontrolsüz bir kahverengiydi. ARTIK envanter
			## panelindeki "koyu içerik" kutusunun birebir aynısı olan
			## _card_normal_style uygulanıyor (bkz. _ready()) ve self_modulate
			## nötr (1,1,1,1) bırakılıyor - böylece renk tam olarak paletten
			## geliyor (kullanıcı isteği).
			panel.self_modulate = Color(1, 1, 1, 1)
			panel.add_theme_stylebox_override("panel", _card_normal_style)


## Dükkanın SOLUNDA açılan önizleme panelini (PreviewPanel) o an seçili
## ürüne göre günceller: büyük ikon (satırın kendi Icon'undan bire bir
## kopyalanır - texture'lı ya da vektörel fark etmez), isim, seviye/sahiplik
## durumu, tam açıklama metni (satırın tooltip_text'i) ve satın alma butonu.
## Hiçbir şey seçili değilse panel tamamen gizlenir.
func _refresh_preview() -> void:
	if selected_key == "" or not selectable_rows.has(selected_key):
		preview_panel.visible = false
		preview_sell_button.visible = false
		return

	preview_panel.visible = true
	var entry: Dictionary = selectable_rows[selected_key]
	var row_panel: PanelContainer = entry["panel"]
	var kind: String = entry["kind"]

	## DÜZELTME: bkz. _ready()'deki row_name_label AYNI düzeltme notu - "item"
	## türü anahtarlar UPGRADE_NAMES'te yok, fallback ham anahtarı basıyordu.
	if kind == "item":
		preview_name_label.text = Items.get_def(selected_key).get("name", selected_key.capitalize())
	else:
		preview_name_label.text = UPGRADE_NAMES.get(selected_key, selected_key)
	
	# Eşya açıklamalarının sadece statlardan ve pasiflerden ibaret olması sağlanır
	if kind == "item":
		preview_desc_label.text = Items.get_def(selected_key).get("desc", "")
	else:
		preview_desc_label.text = str(row_panel.get_meta("description", ""))

	## Büyük önizleme ikonu: satırın küçük Icon'unu (TextureRect ya da
	## shop_item_icon.gd'li vektör Control) aynen kopyalayıp büyütüyoruz -
	## böylece iki ayrı yerde aynı ikonu elle senkronize tutmaya gerek kalmıyor.
	for child in preview_icon_holder.get_children():
		child.queue_free()
	var src_icon: Control = row_panel.get_node("Inner/RowVBox/HBox/Icon")
	var big_icon: Control = src_icon.duplicate()
	if "item_key" in src_icon and "item_key" in big_icon:
		big_icon.item_key = src_icon.item_key
	big_icon.anchor_left = 0.5
	big_icon.anchor_right = 0.5
	big_icon.anchor_top = 0.5
	big_icon.anchor_bottom = 0.5
	big_icon.offset_left = -70.0
	big_icon.offset_right = 70.0
	big_icon.offset_top = -70.0
	big_icon.offset_bottom = 70.0
	big_icon.custom_minimum_size = Vector2(140, 140)
	preview_icon_holder.add_child(big_icon)

	if kind == "upgrade":
		var level: int = GameManager.get(selected_key + "_level")
		var max_level: int = MAX_LEVELS[selected_key]
		preview_status_label.text = "Seviye: %d/%d" % [level, max_level]

		var is_shield_type: bool = selected_key in SHIELD_TYPE_KEYS
		var owned_shield: String = _owned_shield_type() if is_shield_type else ""
		## "Sat" butonu SADECE şu an sahip olunan kalkan türü seçiliyken
		## görünür - başka bir kalkan türüne geçmeden önce bununla mevcut
		## tür satılmalı (bkz. _on_buy_upgrade'in başındaki engel).
		preview_sell_button.visible = is_shield_type and owned_shield == selected_key and level > 0
		if preview_sell_button.visible:
			var total_spent: int = 0
			for l in range(1, level + 1):
				total_spent += _upgrade_cost(selected_key, l)
			preview_sell_button.text = "Kalkanı Sat (+%d)" % int(round(total_spent * 0.7))

		if is_shield_type and owned_shield != "" and owned_shield != selected_key:
			## Başka bir tür zaten sahip - bu satın alınamaz, önce diğeri
			## satılmalı (bkz. kullanıcı isteği "sadece 1 kalkan alınabilir").
			preview_buy_button.text = "Önce %s Sat" % UPGRADE_NAMES.get(owned_shield, owned_shield)
			preview_buy_button.disabled = true
		elif level >= max_level:
			preview_buy_button.text = "MAX"
			preview_buy_button.disabled = true
		else:
			var cost: int = _upgrade_cost(selected_key, level + 1)
			preview_buy_button.text = "Satın Al (%d)" % cost
			preview_buy_button.disabled = GameManager.gold < cost
	elif kind == "item":
		preview_sell_button.visible = false
		var owned_count: int = _item_count_owned(selected_key)
		var slot_max: int = _max_item_slots()
		## Kısa ve tek satır tutuluyor - StatusLabel'in dar (PreviewPanel ~300px)
		## genişliğine güvenle sığması için (bkz. kullanıcı bildirimi: dükkanda
		## eşya önizleme panelindeki yazılar taşıyordu, StatusLabel'e ayrıca
		## autowrap_mode/clip_text de eklendi, bkz. shop_panel.tscn).
		preview_status_label.text = "Sahip: %d  Slot: %d/%d" % [owned_count, GameManager.owned_items.size(), slot_max]
		if GameManager.owned_items.size() >= slot_max:
			preview_buy_button.text = "DOLU"
			preview_buy_button.disabled = true
		else:
			var cost: int = _item_cost(selected_key, owned_count + 1)
			preview_buy_button.text = "Satın Al (%d)" % cost
			preview_buy_button.disabled = GameManager.gold < cost
	else:
		preview_sell_button.visible = false
		var count: int = _count_owned(selected_key)
		preview_status_label.text = "Sahip olunan: %d" % count
		if GameManager.owned_weapons.size() >= _max_owned_weapons():
			preview_buy_button.text = "DOLU"
			preview_buy_button.disabled = true
		else:
			var cost: int = _copy_cost(selected_key, count + 1)
			preview_buy_button.text = "Satın Al (%d)" % cost
			preview_buy_button.disabled = GameManager.gold < cost


## Geliştirmeler sekmesi artık silah TÜRÜNE göre değil, SIRAYA göre - her
## slot (upgrade_slot_panels[i]/upgrade_slot_rows[i]) i < owned_weapons.size()
## olduğu sürece görünür ve o index'teki kopyayı (ikonu, ismi, seviyesi,
## fiyatı) gösterir; fazlası gizlenir. Hiçbir karakterin ayrı bir ana
## silahı yok - başlangıç silahı DAHİL herkes burada, index 0'da görünür.
func _refresh_upgrade_page() -> void:
	for i in range(upgrade_slot_panels.size()):
		var panel: PanelContainer = upgrade_slot_panels[i]
		if i >= GameManager.owned_weapons.size():
			panel.visible = false
			continue
		panel.visible = true

		var entry: Dictionary = GameManager.owned_weapons[i]
		var key: String = entry.get("key", "")
		var level: int = entry.get("level", 1)
		var max_level: int = MAX_LEVELS.get(key, 10)
		var row: VBoxContainer = upgrade_slot_rows[i]

		var icon: TextureRect = row.get_node("Icon")
		var tex_path = WEAPON_ICON_TEXTURES.get(key)
		if tex_path is String:
			icon.texture = load(tex_path) as Texture2D
		else:
			icon.texture = tex_path

		var name_label: Label = row.get_node("NameLabel")
		name_label.text = "%s Lv%d/%d" % [UPGRADE_NAMES.get(key, key), level, max_level]

		var upgrade_button: Button = row.get_node("UpgradeButton")
		if level >= max_level:
			upgrade_button.text = "MAX"
			upgrade_button.disabled = true
		else:
			var cost: int = _upgrade_cost(key, level + 1)
			upgrade_button.text = str(cost)
			upgrade_button.disabled = GameManager.gold < cost
		_apply_wood_button_style(upgrade_button)

		var sell_button: Button = row.get_node("SellButton")
		var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))
		## Son kalan silah da satılabilir (bkz. _on_sell_weapon üstündeki not).
		sell_button.disabled = false
		sell_button.text = "Sat (%d)" % refund
		_apply_wood_button_style(sell_button)
