extends RefCounted

## BAŞLANGIÇ SİLAHI kataloğu (kullanıcı isteği 2026-10-03: "bundan sonra başlangıç silahı karakter seçim ekranından seçilsin
## oradan isteyen oyuncu istediği silahı seçebilsin başlangıç için. bu sayede başlangıçtaki silah seçme kartını
## kaldırıyoruz") - oyun başındaki 3 rastgele silah kartı ekranı (eski scripts/weapon_select_screen.gd) silindi; havuz aynı
## 15 silah, metinler o ekranın kartlarındaki metinler (değerler player.gd tier fonksiyonları + weapon_*.tscn'den). Seçim
## GameManager.selected_start_weapon'a yazılır (menu_weapon_picker.gd), oyun başlayınca main.gd _start_initial_loadout_selection
## onu verir. Ad/ikon listeleri chest_menu.gd / merchant_shop_screen.gd / inventory_panel.gd'deki kopyalarla AYNI (projenin
## bilinçli kopya deseni - bkz. o dosyalardaki notlar); yeni silah eklenirse oralara da eklenmeli.

const KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
const DEFAULT_KEY := "dagger"
const NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç",
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
}
## bkz. player.gd buy_weapon_copy() - _configure_*_melee() yalnız bu 4 anahtar için; diğerleri menzilli.
const MELEE_KEYS := ["dagger", "pence", "topuz", "uzunkilic"]
const DESCRIPTIONS := {
	"dagger": "HASAR: 10 + %85 saldırı gücü · Yakın dövüş, hedefin çevresine hafif alan hasarı",
	"fire_staff": "HASAR: 13 + %100 saldırı gücü · Ateş hızı 1.4sn · Menzil 168 · Patlayıcı mermi",
	"lightning_staff": "HASAR: 12/sn + %140 saldırı gücü · Menzil 168 · Kesintisiz ışın",
	"tabanca": "HASAR: 17 + %99 saldırı gücü · Ateş hızı 0.9sn · Menzil 210",
	"tuftuf": "HASAR: %100 saldırı gücü · Ateş hızı 1.4sn · Menzil 128",
	"tufek": "HASAR: %160 saldırı gücü · Ateş hızı 1.3sn · Menzil 302",
	"arcane": "HASAR: 16 + %110 saldırı gücü · Ateş hızı 1.4sn · Menzil 168",
	"yay": "HASAR: 14 + %70 saldırı gücü · Ateş hızı 0.8sn · Menzil 266 · Ateşten önce ok çeker",
	"crossbow": "HASAR: 16 + %110 saldırı gücü · Ateş hızı 0.7sn · Menzil 245",
	"boomerang": "HASAR: 16 + %90 saldırı gücü · Ateş hızı 0.3sn · Menzil 167 · Gidip döner, 2 kez vurabilir; saldırı hızı arttıkça daha hızlı gidip döner",
	"buz_asasi": "HASAR: 12 + %77 saldırı gücü · Ateş hızı 1.4sn · Menzil 168",
	"fisek": "HASAR: 14 + %230 saldırı gücü (sadece alan hasarı) · Ateş hızı 3.7sn · Menzil 252",
	"pence": "HASAR: 20 + %100 saldırı gücü · Yakın dövüş (menzil 110) · Çift pençe darbesi",
	"topuz": "HASAR: 20 + %105 saldırı gücü · Yakın dövüş (menzil 120) · Geniş alan hasarı",
	"uzunkilic": "HASAR: 18 + %100 saldırı gücü · Yakın dövüş (menzil 115) · Geniş savuruş",
}


static func is_valid(key: String) -> bool:
	return KEYS.has(key)


## Geçerli seçim (GameManager'da yoksa / bozuksa varsayılan).
static func selected() -> String:
	var k: String = str(GameManager.selected_start_weapon)
	return k if is_valid(k) else DEFAULT_KEY


static func display_name(key: String) -> String:
	return str(NAMES.get(key, key.capitalize()))


static func icon(key: String) -> Texture2D:
	var p: String = str(ICONS.get(key, ""))
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null


static func category_label(key: String) -> String:
	return "Yakın Dövüş" if key in MELEE_KEYS else "Menzilli"


## Kategori yazı rengi (level/silah kartlarıyla aynı mürekkep tonları - UIKit).
static func category_color(key: String) -> Color:
	return UIKit.C_CAT_ATTACK if key in MELEE_KEYS else UIKit.C_CAT_UTILITY
