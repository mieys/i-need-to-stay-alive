extends RefCounted

## SEYYAR SATICI + DEMİRCİ (BİNASI DAHİL) GEÇİCİ OLARAK OYUNDAN KALDIRILDI - kullanıcı isteği (2026-10-28): "seyyar satıcıyı ve demirciyi
## geçici olarak oyundan kaldır (demirci binasını da kaldır)". TEK anahtar `enabled`; geri açmak için true yap + gölge/minimap'i yeniden
## pişir (aşağıya bak). Kapalıyken:
##   - main.gd `_enter_tree` (hiçbir çocuğun _ready'si çalışmadan ÖNCE) `WeaponShop` ve `TravelingMerchant` düğümlerini siler -> satıcı hiç
##     gelmez (ağ sinyali yok, koruma bölgesi yok), demirci kapısı/iç mekanı/NPC'si yok (minimap `_smith_pos` düğüm yoksa simge çizmez).
##   - Demirci BİNASI haritadan çıkarılır (`strip_building`): `ev/Blacksmith`, `ev/blacksmith kapı`, `ev/baca duman` katmanları tümden;
##     `ev/Ev ayrıntı` ve `ev/Ev Çatı 1` ortak katmanlarından da bina alanındaki hücreler (`BUILDING_CELLS`). Terrain collision / derinlik ön
##     kopyası / ağaç-bina ayak izi bu katmanları adla arar, bulamazsa atlar -> binanın engeli ve ön kopyası da kalkar.
##   - Harita.tmx ve scenes/harita_baked.tscn'e DOKUNULMAZ (kullanıcı Tiled'da düzenliyor; yeniden bake bina katmanlarını geri getirir, bu
##     fonksiyon onları yine ayıklar).
## PİŞMİŞ DOKULAR (assets/map/harita_golgeleri.png + assets/ui/minimap_map.png) bayrağa göre YENİDEN pişirilir: tools/bake_map_shadows.gd ve
## tools/bake_minimap.gd `strip_building`'i çağırır. Bayrağı değiştirince ikisini de tekrar pişir (tools/cayir_susleri/golge_minimap.ps1 ->
## python tools/bake_map_shadows.py <klasör> -> Godot --headless --import), yoksa binanın gölgesi/minimap izi yerinde kalır (veya geri açınca eksik olur).
## Bu dosya autoload kullanmaz: `-s` ile çalışan pişirme araçları da ön yükleyebilir.

## 2026-11-06 (kullanıcı: "seyyar satıcıyı geri aç ama %50 daha yavaş spawnlansın"): bayrak İKİYE ayrıldı. Seyyar satıcı geri açıldı
## (`merchant_enabled`, spawn yavaşlatması traveling_merchant.gd'de); DEMİRCİ (WeaponShop + binası) hâlâ kapalı (`enabled`) - bina
## kapalı kaldığı için gölge/minimap yeniden pişirilmedi. Demirciyi geri açmak = `enabled = true` + pişirme (yukarıya bak).
## false = DEMİRCİ dükkanı ve binası kapalı. Testler/araçlar çalışma anında değiştirebilir.
static var enabled: bool = false
## false = seyyar satıcı düğümü silinir (satıcı hiç gelmez). Ağ/spawn mantığı traveling_merchant.gd'de.
static var merchant_enabled: bool = true


## Sabit olarak ön yüklenmiş betikten (`const ShopsFlag := preload(...)`) `ShopsFlag.enabled = x` yazmak ayrıştırıcı hatası verir; testler bunu kullanır.
static func set_enabled(value: bool) -> void:
	enabled = value


static func set_merchant_enabled(value: bool) -> void:
	merchant_enabled = value

const SMITHY_NODE := "WeaponShop"
const MERCHANT_NODE := "TravelingMerchant"
const SHOP_NODES: Array[String] = [SMITHY_NODE, MERCHANT_NODE]
## Bina TEK başına bu katmanlarda (Harita'ya göre yol): tümden silinir.
const BUILDING_LAYERS: Array[String] = ["ev/Blacksmith", "ev/blacksmith kapı", "ev/baca duman"]
## Ana evle PAYLAŞILAN katmanlar: sadece BUILDING_CELLS içindeki hücreler silinir (çatı + ayrıntı; ana ev x >= 117 olduğundan karışmaz).
const SHARED_BUILDING_LAYERS: Array[String] = ["ev/Ev ayrıntı", "ev/Ev Çatı 1"]
## Demirci binası + çatısı + bacası (karo hücresi): x 76..90, y 138..148 (binanın dolu hücreleri x 77-87, y 139-147).
const BUILDING_CELLS: Rect2i = Rect2i(76, 138, 15, 11)


## Main'in dükkan düğümlerini siler + haritadan binayı çıkarır. Main'in `_enter_tree`'sinden çağrılır (çocuklar henüz ağaca girmedi).
static func strip_shops(main: Node) -> void:
	if main == null:
		return
	if not merchant_enabled:
		_free_child(main, MERCHANT_NODE)
	if not enabled:
		_free_child(main, SMITHY_NODE)
		strip_building(main.get_node_or_null("Harita"))


static func _free_child(main: Node, node_name: String) -> void:
	var n: Node = main.get_node_or_null(node_name)
	if n != null:
		main.remove_child(n)
		n.free()


## Demirci binasını harita düğümünden çıkarır (bayrak kapalıyken). Harita ağaçta olsun olmasın çalışır.
static func strip_building(harita: Node) -> void:
	if enabled or harita == null:
		return
	for path: String in BUILDING_LAYERS:
		var layer: Node = harita.get_node_or_null(path)
		if layer != null:
			layer.get_parent().remove_child(layer)
			layer.free()
	for path: String in SHARED_BUILDING_LAYERS:
		var shared := harita.get_node_or_null(path) as TileMapLayer
		if shared == null:
			continue
		for cell: Vector2i in shared.get_used_cells():
			if BUILDING_CELLS.has_point(cell):
				shared.erase_cell(cell)
