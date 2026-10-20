extends RefCounted

## BAŞLANGIÇ SİLAHI kataloğu (kullanıcı isteği 2026-10-03: "bundan sonra başlangıç silahı karakter seçim ekranından seçilsin
## oradan isteyen oyuncu istediği silahı seçebilsin başlangıç için. bu sayede başlangıçtaki silah seçme kartını
## kaldırıyoruz") - oyun başındaki 3 rastgele silah kartı ekranı (eski scripts/weapon_select_screen.gd) silindi; havuz aynı
## 15 silah, metinler o ekranın kartlarındaki metinler (değerler player.gd tier fonksiyonları + weapon_*.tscn'den). Seçim
## GameManager.selected_start_weapon'a yazılır (menu_weapon_picker.gd), oyun başlayınca main.gd _start_initial_loadout_selection
## onu verir. Ad/ikon listeleri chest_menu.gd / merchant_shop_screen.gd / inventory_panel.gd'deki kopyalarla AYNI (projenin
## bilinçli kopya deseni - bkz. o dosyalardaki notlar); yeni silah eklenirse oralara da eklenmeli.

const KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic", "gokkusagi", "mizrak", "kalkan", "yinyang"]
const DEFAULT_KEY := "dagger"
const NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç", "gokkusagi": "Gökkuşağı Asası", "mizrak": "Mızrak", "kalkan": "Kalkan", "yinyang": "Yin Yang Kitabı",
}
const ICONS := {
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
## bkz. player.gd buy_weapon_copy() - _configure_*_melee() yalnız bu 6 anahtar için; diğerleri menzilli.
const MELEE_KEYS := ["dagger", "pence", "topuz", "uzunkilic", "mizrak", "kalkan"]
## 2026-10-10 denge turu 2: Arbalet ateş hızı 0,72 -> 0,8 sn, Buz Asası oranı 0,693 -> 0,9, Arcane 0,99 -> 1,25, Tüftüf menzili 128 -> 150, Bıçak 0,765 -> 0,88,
## Pençe 0,9 -> 1,035, Fişek ateş aralığı 3,72 -> 3,2 sn (sahne dosyaları); Tüfek delme artışı ve Yıldırım sekmesi efsun tabanında (enchant_defs.gd). Eski "N + %X" metinleri düz hasarı olmayan silahlarda yanlıştı.
## 2026-10-12 deneme: TÜM hasar sayıları x1,5, Bıçak/Pençe/Topuz x2,1; 2026-10-14: genel çarpan x1,0'a döndü (Bıçak/Pençe/Topuz x1,4) - weapon.gd WEAPON_DAMAGE_MULT / MELEE_EXTRA_DAMAGE_MULT; eski değerler sahne oranlarıdır.
## 2026-10-17: TÜM silahların saldırı hızı -%30 (GameManager.WEAPON_ATTACK_SPEED_MULT 0,7): aşağıdaki "Ateş hızı" saniyeleri sahne oranı / 0,7 (gerçek atış aralığı).
## 2026-10-20 denge turu (BALANCE_REV 94): Bıçak %123 -> %154, Tüftüf %100 -> %160 + menzil 150 -> 180, Yay %64 -> %85, Kalkan ve Yin Yang %100 -> %125, Topuz alan payı %50 -> %35;
## Ateş Asası "%108" bayattı (-%30 saldırı hızı tiki 0,25 -> 0,36 sn yaptı: gerçek saniyede %76).
## 2026-10-17 (kullanıcı: "pençe çok güçsüz"): yüzdeler 10-12 denemesinin x1,5'iyle şişik kalmıştı (ör. Pençe %216, gerçek %145) ve "N +" düz
## hasarları yoktu - hepsi GERÇEK orana çekildi: sahne card_damage_bonus_ratio x WEAPON_DAMAGE_MULT (1,0) x yakın dövüş MELEE_EXTRA_DAMAGE_MULT (1,4;
## Bıçak/Pençe/Topuz), Uzunkılıç SWORD_AP_RATIO (1,2). Ateş Asası metni ayrı formül (püskürtme/saniye), dokunulmadı. Oran değişirse BURAYI da güncelle.
const DESCRIPTIONS := {
	"dagger": "HASAR: %154 saldırı gücü · Yakın dövüş, hedefin çevresine hafif alan hasarı",
	"fire_staff": "HASAR: saniyede %76 saldırı gücü (koni, alandaki herkese) · Menzil 140 · Sürekli alev püskürtür, 3 sn yakar (saniyede %14)", ## 2026-10-10 buff: Destiny püskürtmesi %15 -> %27 / 0,25 sn, menzil 110 -> 140, yanma %8 -> %14
	"lightning_staff": "HASAR: %140 saldırı gücü · Menzil 168 · Kesintisiz ışın",
	"tabanca": "HASAR: %115 saldırı gücü · Ateş hızı 1.3sn · Menzil 210 · 6 mermilik şarjör (saldırı hızı doldurmayı da hızlandırır)", ## 2026-10-10: oran 0,891 -> 1,15 (sahne card_damage_bonus_ratio)
	"tuftuf": "HASAR: %160 saldırı gücü (gerçek hasar: kalkanı deler) · Ateş hızı 2.0sn · Menzil 180",
	"tufek": "HASAR: %160 saldırı gücü · Ateş hızı 1.9sn · Menzil 302 · 5 mermilik şarjör (saldırı hızı doldurmayı da hızlandırır)", ## şarjör madde 296 (gun_mag_math.gd)
	"arcane": "HASAR: %125 saldırı gücü · Ateş hızı 2.1sn · Menzil 151",
	"yay": "HASAR: %85 saldırı gücü · Ateş hızı 1.1sn · Menzil 266 · Ateşten önce ok çeker", ## 2026-10-10: saldırı hızı +%20 (sahne fire_rate 0,7844 -> 0,6537)
	"crossbow": "HASAR: %99 saldırı gücü · Ateş hızı 1.1sn · Menzil 220",
	"boomerang": "HASAR: %81 saldırı gücü · Ateş hızı 0.5sn · Menzil 167 · Gidip döner, 2 kez vurabilir; saldırı hızı arttıkça daha hızlı gidip döner",
	"buz_asasi": "HASAR: %90 saldırı gücü · Ateş hızı 1.6sn · Menzil 151 · Her 2. isabet dondurur",
	"fisek": "HASAR: %208 saldırı gücü (sadece alan hasarı) · Ateş hızı 4.6sn · Menzil 227",
	"pence": "HASAR: %189 saldırı gücü · Yakın dövüş (menzil 110) · Çift pençe darbesi, çevresine alan hasarı (80)",
	"topuz": "HASAR: %132 saldırı gücü · Yakın dövüş (menzil 120) · Geniş alan hasarı (alandaki diğerlerine %35)",
	"uzunkilic": "HASAR: %120 saldırı gücü · Yakın dövüş (menzil 115) · Geniş savuruş (çevredekilere %70)",
	"mizrak": "HASAR: %120 saldırı gücü · Yakın dövüş (menzil 150) · Düz hatta delip geçer: hedefin arkasındakiler de tam hasar alır", ## madde 305 (sahne oranı 1,2)
	"kalkan": "HASAR: %125 saldırı gücü · Yakın dövüş (menzil 110) · Geniş darbe: önündeki herkes tam hasar alır ve 45 birim geri itilir (bosslar itilmez)", ## madde 338/342 (sahne oranı 1,0; madde 340 yavaşlatması geri alındı)
	"yinyang": "HASAR: %125 saldırı gücü · Ateş hızı 1.7sn · Menzil 170 · Tek hedef; her isabette kalkanı en boş oyuncuya (sen dahil, menzil yok) saldırı gücünün %10'u kadar mana kalkanı · Saldıracak düşman yokken de aynı aralıkla kalkan taşır", ## madde 334 (sahne fire_rate 1,2 / 0,7)
	"gokkusagi": "HASAR: saniyede %220 saldırı gücü (0,5 sn'de bir %110) · Menzil 185 · Kesintisiz ışın, ilk düşmanda durur", ## madde 306: sahne 1,1 oran x tik oranı 1,0 (2026-10-19 buff: 0,75 -> 1,1, menzil 168 -> 185), tik 0,35 / 0,7 = 0,5 sn
}


## Silahın doğuştan özelliği (efsun) metni: "<özellik adı>: <kısa açıklama>" - 2026-10-10 (kullanıcı: "efsunlar artık silahın bir parçası; oyun başında silah
## seçerken saldırı gücü oranı, saldırı hızı vb. yerine sadece silahın özelliği yazsın"). Kaynak EnchantDefs.TRAITS/DEFS (tek tablo).
static func trait_text(key: String) -> String:
	var id: String = EnchantDefs.trait_of(key)
	var d: Dictionary = EnchantDefs.get_def(id) if id != "" else {}
	if d.is_empty():
		return str(DESCRIPTIONS.get(key, ""))
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
	## Zanaatkâr seti (madde 196): arayüzde (silah seçici, lobi, Ruh Mağazası) 1. seviye sanatı; dosya yoksa eski ikon.
	var z: String = "res://assets/weapons/zanaat/%s_L1.png" % key
	if ResourceLoader.exists(z):
		return load(z) as Texture2D
	var p: String = str(ICONS.get(key, ""))
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null


static func category_label(key: String) -> String:
	return "Yakın Dövüş" if key in MELEE_KEYS else "Menzilli"


## Kategori yazı rengi (level/silah kartlarıyla aynı mürekkep tonları - UIKit).
static func category_color(key: String) -> Color:
	return UIKit.C_CAT_ATTACK if key in MELEE_KEYS else UIKit.C_CAT_UTILITY
