extends RefCounted
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## BAŞLANGIÇ SİLAHI kataloğu (kullanıcı isteği 2026-10-03: "bundan sonra başlangıç silahı karakter seçim ekranından seçilsin
## oradan isteyen oyuncu istediği silahı seçebilsin başlangıç için. bu sayede başlangıçtaki silah seçme kartını
## kaldırıyoruz") - oyun başındaki 3 rastgele silah kartı ekranı (eski scripts/weapon_select_screen.gd) silindi; havuz aynı
## 15 silah, metinler o ekranın kartlarındaki metinler (değerler player.gd tier fonksiyonları + weapon_*.tscn'den). Seçim
## GameManager.selected_start_weapon'a yazılır (menu_weapon_picker.gd), oyun başlayınca main.gd _start_initial_loadout_selection
## onu verir. Ad/ikon listeleri chest_menu.gd / merchant_shop_screen.gd / inventory_panel.gd'deki kopyalarla AYNI (projenin
## bilinçli kopya deseni - bkz. o dosyalardaki notlar); yeni silah eklenirse oralara da eklenmeli.

const KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic", "gokkusagi", "mizrak", "kalkan", "yinyang", "pompali", "makineli"]
const DEFAULT_KEY := "dagger"
const NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Zehir Asası", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Çakram", "buz_asasi": "Buz Asası", "fisek": "Dinamit",
	"pence": "Tırpan", "topuz": "Balyoz", "uzunkilic": "Uzunkılıç", "gokkusagi": "Gökkuşağı Asası", "mizrak": "Mızrak", "kalkan": "Kalkan", "yinyang": "Yin Yang Kitabı", "pompali": "Pompalı Tüfek", "makineli": "Hafif Makineli Tüfek", ## madde 652: kullanıcı "adını hafif makineli tüfek yap, thompson kafa karıştırıcı" (anahtar makineli aynı: kayıt/ağ uyumu)
}
const ICONS := {
	"dagger": "res://assets/weapons/yeni/bicak.png",
	"fire_staff": "res://assets/weapons/yeni/fire_staff.png",
	"lightning_staff": "res://assets/weapons/yeni/yildirim_asasi.png",
	"tabanca": "res://assets/weapons/yeni/tabanca.png",
	"tuftuf": "res://assets/weapons/yeni/zehir_asasi.png",
	"tufek": "res://assets/weapons/yeni/tufek.png",
	"arcane": "res://assets/weapons/yeni/arcane.png",
	"yay": "res://assets/weapons/yeni/yay.png",
	"crossbow": "res://assets/weapons/yeni/arbalet.png",
	"boomerang": "res://assets/weapons/yeni/chakram.png",
	"buz_asasi": "res://assets/weapons/yeni/buz_asasi.png",
	"fisek": "res://assets/weapons/yeni/dinamit.png",
	"pence": "res://assets/weapons/yeni/tirpan.png",
	"topuz": "res://assets/weapons/yeni/topuz.png",
	"uzunkilic": "res://assets/weapons/yeni/uzunkilic.png",
	"gokkusagi": "res://assets/weapons/yeni/gokkusagi.png",
	"mizrak": "res://assets/weapons/zanaat/mizrak_L1.png",
	"kalkan": "res://assets/weapons/zanaat/kalkan_L1.png",
	"yinyang": "res://assets/weapons/zanaat/yinyang_L1.png",
	"pompali": "res://assets/weapons/pompali/icon.png",
	"makineli": "res://assets/weapons/makineli/icon.png", ## madde 652
}
## MENÜ ikonu (seçim ızgarası/vitrin): oyundaki çizimi yatay olan iki silah (namlu sağa) ızgarada diğerleri gibi ÇAPRAZ + 48x48 (96 kutuda tam 2x).
## Yatay 64x32 / 64x64 çizim `DK.icon` tam kat kuralıyla 1x kalıp "çok ufak" duruyordu. Oyundaki doku DEĞİŞMEZ; üretici tools/gen_silah_menu_ikon.py.
const MENU_ICONS := {
	"tufek": "res://assets/weapons/yeni/tufek_menu.png",
	"pompali": "res://assets/weapons/pompali/menu.png",
	"makineli": "res://assets/weapons/makineli/menu.png", ## madde 652
}
## bkz. player.gd buy_weapon_copy() - _configure_*_melee() yalnız bu 6 anahtar için; diğerleri menzilli.
const MELEE_KEYS := ["dagger", "pence", "topuz", "uzunkilic", "mizrak", "kalkan"]
## 2026-10-10 denge turu 2: Arbalet ateş hızı 0,72 -> 0,8 sn, Buz Asası oranı 0,693 -> 0,9, Arcane 0,99 -> 1,25, Tüftüf menzili 128 -> 150, Bıçak 0,765 -> 0,88,
## Pençe 0,9 -> 1,035, Fişek ateş aralığı 3,72 -> 3,2 sn (sahne dosyaları); Tüfek delme artışı ve Yıldırım sekmesi efsun tabanında (enchant_defs.gd). Eski "N + %X" metinleri düz hasarı olmayan silahlarda yanlıştı.
## 2026-10-12 deneme: TÜM hasar sayıları x1,5, Bıçak/Pençe/Topuz x2,1; 2026-10-14: genel çarpan x1,0'a döndü (Bıçak/Pençe/Topuz x1,4) - weapon.gd WEAPON_DAMAGE_MULT / MELEE_EXTRA_DAMAGE_MULT; eski değerler sahne oranlarıdır.
## 2026-10-17: TÜM silahların saldırı hızı -%30 (GameManager.WEAPON_ATTACK_SPEED_MULT 0,7): aşağıdaki "Ateş hızı" saniyeleri sahne oranı / 0,7 (gerçek atış aralığı).
## 2026-10-20 denge turu (BALANCE_REV 94): Bıçak %123 -> %154, Tüftüf %100 -> %160 + menzil 150 -> 180, Yay %64 -> %85, Kalkan ve Yin Yang %100 -> %125, Topuz alan payı %50 -> %35;
## Ateş Asası "%108" bayattı (-%30 saldırı hızı tiki 0,25 -> 0,36 sn yaptı: gerçek saniyede %76).
## 2026-11-14 denge turu (docs/balans/denge_plani_2026-11-14.md, BALANCE_REV 167): Tırpan oranı 1,35 -> 1,25 + alan payı %50 -> %35, Balyoz Sismik Dalga %70 -> %50 ve 8 -> 4 hedef, Gökkuşağı 1,1 -> 0,7 + saçılma 4 -> 3,
## Zehir ateş 2,0 -> 1,7 sn + zehir 4 -> 6 sn, Yin Yang kalkan %10 -> %15 + Yin %20 -> %40, Buz Asası destek (1,56 -> 1,0 sn, oran 0,9 -> 0,6, %30 yavaşlatma), Yıldırım sekme %35 -> %50, Pompalı 0,34 -> 0,38,
## Kalkan düz 6/18 -> 8/24, Arcane 2,1 -> 1,7 sn, Dinamit 4,6 -> 3,8 sn.
## 2026-10-17 (kullanıcı: "pençe çok güçsüz"): yüzdeler 10-12 denemesinin x1,5'iyle şişik kalmıştı (ör. Pençe %216, gerçek %145) ve "N +" düz
## hasarları yoktu - hepsi GERÇEK orana çekildi: sahne card_damage_bonus_ratio x WEAPON_DAMAGE_MULT (1,0) x yakın dövüş MELEE_EXTRA_DAMAGE_MULT (1,4;
## Bıçak/Pençe/Topuz), Uzunkılıç SWORD_AP_RATIO (1,2). Ateş Asası metni ayrı formül (püskürtme/saniye), dokunulmadı. Oran değişirse BURAYI da güncelle.
const DESCRIPTIONS := {
	"dagger": "HASAR: %154 saldırı gücü · Yakın dövüş, hedefin çevresine hafif alan hasarı",
	"fire_staff": "HASAR: saniyede %76 saldırı gücü (alevin değdiği herkese) · Menzil 160 · Sürekli alev püskürtür, 3 sn yakar (saniyede %14)", ## madde 639: koni -> flamethrower alevinin şekli, 160 birim ## 2026-10-10 buff: Destiny püskürtmesi %15 -> %27 / 0,25 sn, menzil 110 -> 140, yanma %8 -> %14
	"lightning_staff": "HASAR: %140 saldırı gücü · Menzil 168 · Kesintisiz ışın",
	"tabanca": "HASAR: %115 saldırı gücü · Ateş hızı 1.3sn · Menzil 210 · 6 mermilik şarjör (saldırı hızı doldurmayı da hızlandırır)", ## 2026-10-10: oran 0,891 -> 1,15 (sahne card_damage_bonus_ratio)
	"tuftuf": "HASAR: %160 saldırı gücü · Ateş hızı 1.7sn · Menzil 180", ## madde 592: "gerçek hasar" 2026-09-25 sade silah turunda kalkmıştı (always_true_damage yok), metin eskiydi
	"tufek": "HASAR: %160 saldırı gücü · Ateş hızı 1.9sn · Menzil 302 · 5 mermilik şarjör (saldırı hızı doldurmayı da hızlandırır)", ## şarjör madde 296 (gun_mag_math.gd)
	"arcane": "HASAR: %125 saldırı gücü · Ateş hızı 1.7sn · Menzil 151",
	"yay": "HASAR: %85 saldırı gücü · Ateş hızı 1.1sn · Menzil 266 · Ateşten önce ok çeker", ## 2026-10-10: saldırı hızı +%20 (sahne fire_rate 0,7844 -> 0,6537)
	"crossbow": "HASAR: %99 saldırı gücü · Ateş hızı 1.1sn · Menzil 220",
	"boomerang": "HASAR: %81 saldırı gücü · Ateş hızı 0.5sn · Menzil 167 · Çarptığı ilk düşmandan geri döner; saldırı hızı arttıkça daha hızlı gidip döner", ## madde 591: "2 kez vurabilir" yanlıştı (dönüşte vurmaz)
	"buz_asasi": "HASAR: %60 saldırı gücü · Ateş hızı 1.0sn · Menzil 151 · Her isabet %30 yavaşlatır, her 2. isabet dondurur",
	"fisek": "HASAR: %208 saldırı gücü (sadece alan hasarı) · Ateş hızı 3.8sn · Menzil 227",
	"pence": "HASAR: %175 saldırı gücü · Yakın dövüş (menzil 110) · Çift tırpan darbesi, çevresine alan hasarı (80, alandakilere %35)",
	"topuz": "HASAR: %132 saldırı gücü · Yakın dövüş (menzil 120) · Geniş alan hasarı (alandaki diğerlerine %35)",
	"uzunkilic": "HASAR: %120 saldırı gücü · Yakın dövüş (menzil 115) · Geniş savuruş (çevredekilere %70)",
	"mizrak": "HASAR: %120 saldırı gücü · Yakın dövüş (menzil 150) · Düz hatta delip geçer: hedefin arkasındakiler de tam hasar alır", ## madde 305 (sahne oranı 1,2)
	"kalkan": "HASAR: %150 saldırı gücü · Yakın dövüş (menzil 110) · Geniş darbe: önündeki herkes tam hasar alır ve 45 birim geri itilir (bosslar itilmez)", ## madde 338/342 (sahne oranı 1,0; madde 340 yavaşlatması geri alındı)
	"yinyang": "HASAR: %125 saldırı gücü · Ateş hızı 1.7sn · Menzil 170 · Tek hedef; her isabette kalkanı en boş oyuncuya (sen dahil, kitabın menzili içinde) saldırı gücünün %15'i kadar mana kalkanı · Saldıracak düşman yokken de aynı aralıkla kalkan taşır", ## madde 334 (sahne fire_rate 1,2 / 0,7)
	"pompali": "HASAR: 6 saçma x %42 saldırı gücü (yakında hepsi isabet eder: %252) · Ateş hızı 1.3sn · Menzil 330 · Ortaya yoğun dar koni, uzakta daha az saçma isabet eder · 7 fişeklik pompa (saldırı hızı doldurmayı da hızlandırır)", ## madde 448 (sahne oranı SAÇMA başına 0,42; 2026-11-14: 0,34 -> 0,38 -> 0,42, şarjör 5 -> 7)
	"makineli": "HASAR: %40 saldırı gücü · Ateş hızı şarjör içinde hızlanır (saniyede ~2 → ~12 mermi) · Menzil 200 · 30 mermilik şarjör, ~3,4 sn doldurma (saldırı hızı doldurmayı da hızlandırır)", ## madde 652 (sahne oranı 0,40 - madde 653 buff 0,26 -> 0,40; 0,55 denemesi 2026-11-14 geri alındı; fire_rate 0,21)
	"gokkusagi": "HASAR: saniyede %140 saldırı gücü (0,5 sn'de bir %70) · Menzil 185 · Kesintisiz ışın, ilk düşmanda durur · Işık saçılması: vurduğu düşmanın yakınındaki en çok 3 düşmana yarım hasar", ## madde 306: sahne 1,1 oran x tik oranı 1,0 (2026-10-19 buff: 0,75 -> 1,1, menzil 168 -> 185), tik 0,35 / 0,7 = 0,5 sn
}


## SİLAH STAT ÇUBUKLARI (kullanıcı isteği 2026-11-13): lobi SİLAH sekmesinde seçilen silahın [Saldırı, Saldırı Hızı, Savunma, Destek]
## değerleri, 1-10 (weapon_stat_bars.gd çizer). OYUNA ETKİSİ YOK - yalnız karşılaştırma için elle verilmiş puanlar (denge değil, BALANCE_REV
## gerekmez). Kaynak: DESCRIPTIONS'taki oran / ateş aralığı + özellik (Savunma = menzil, can emme, kalkan, itme, kitle kontrolü; Destek =
## takım arkadaşına kalkan, dondurma / göz kamaştırma gibi düşmanı etkisiz bırakma). Her silahın dörtlüsü farklı olmalı (test_start_weapon_pick).
## Silahın oranı / hızı / özelliği belirgin değişirse burayı da güncelle.
const STAT_BARS := {
	"dagger": [6, 7, 2, 2],
	"fire_staff": [5, 9, 4, 3],
	"lightning_staff": [6, 8, 3, 3],
	"tabanca": [5, 6, 3, 1],
	"tuftuf": [7, 4, 3, 3],
	"tufek": [8, 3, 5, 1],
	"arcane": [6, 4, 3, 2],
	"yay": [4, 6, 5, 2],
	"crossbow": [5, 6, 4, 2],
	"boomerang": [3, 9, 3, 2],
	"buz_asasi": [3, 7, 6, 9],
	"fisek": [9, 2, 4, 3],
	"pence": [8, 5, 5, 1],
	"topuz": [6, 4, 5, 3],
	"uzunkilic": [6, 5, 5, 2],
	"mizrak": [6, 5, 4, 1],
	"kalkan": [4, 4, 10, 3],
	"yinyang": [4, 4, 6, 10],
	"pompali": [9, 5, 3, 1],
	"makineli": [3, 10, 2, 1],
	"gokkusagi": [7, 7, 4, 6],
}
const STAT_BAR_MAX := 10


## [Saldırı, Saldırı Hızı, Savunma, Destek] (1..STAT_BAR_MAX); tabloda yoksa ortada [5, 5, 5, 5].
static func stat_bars(key: String) -> Array:
	return (STAT_BARS.get(key, [5, 5, 5, 5]) as Array).duplicate()


## Silahın doğuştan özelliği (efsun) metni: "<özellik adı>: <kısa açıklama>" - 2026-10-10 (kullanıcı: "efsunlar artık silahın bir parçası; oyun başında silah
## seçerken saldırı gücü oranı, saldırı hızı vb. yerine sadece silahın özelliği yazsın"). Kaynak EnchantDefs.TRAITS/DEFS (tek tablo).
static func trait_text(key: String) -> String:
	var id: String = EnchantDefs.trait_of(key)
	var d: Dictionary = EnchantDefs.get_def(id) if id != "" else {}
	if d.is_empty():
		return Loc.pct(Loc.t(str(DESCRIPTIONS.get(key, ""))))
	return "%s: %s" % [str(d.get("name", id)), str(d.get("desc", ""))]


static func is_valid(key: String) -> bool:
	return KEYS.has(key)


## Geçerli seçim (GameManager'da yoksa / bozuksa varsayılan).
static func selected() -> String:
	var k: String = str(GameManager.selected_start_weapon)
	return k if is_valid(k) else DEFAULT_KEY


static func display_name(key: String) -> String:
	return str(NAMES.get(key, key.capitalize()))


static func icon(key: String) -> Texture2D:
	## Madde 402: Zanaatkâr kademe sanatı kalktı - ICONS = oyundaki silahla aynı görünüş (kullanıcı çizimi / eski ikon / yeni silahın
	## 1. seviyesi; sabit sanat tablosu scripts/weapon_tier_art.gd ART ile aynı dosyalar).
	var p: String = str(ICONS.get(key, ""))
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null


## Seçim menülerindeki ikon (bkz. MENU_ICONS); çapraz sürümü olmayan silah / dosya henüz içe aktarılmamışsa `icon()`.
static func menu_icon(key: String) -> Texture2D:
	var p: String = str(MENU_ICONS.get(key, ""))
	if p != "" and ResourceLoader.exists(p):
		return load(p) as Texture2D
	return icon(key)


static func category_label(key: String) -> String:
	return "Yakın Dövüş" if key in MELEE_KEYS else "Menzilli"


## Kategori yazı rengi (level/silah kartlarıyla aynı mürekkep tonları - UIKit).
static func category_color(key: String) -> Color:
	return UIKit.C_CAT_ATTACK if key in MELEE_KEYS else UIKit.C_CAT_UTILITY
