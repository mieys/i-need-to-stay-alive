extends RefCounted

## MODAL PENCERE GÜVENLİ ALANI (kullanıcı bildirimi 2026-10-08: "oyundaki bazı arayüzler içeriğine göre büyüyüp küçülüyor dükkanlar gibi.
## grup panelinin altında kalınca çarpıya basamıyorum").
## KÖK NEDEN: grup paneli (party_panel.gd) kendi CanvasLayer'ında layer 96'da, yani TÜM modal pencerelerin (dükkanlar 80, mini dükkan 92...)
## ÜSTÜNDE durur - bilerek: hangi ekran açık olursa olsun müttefike altın gönderilebilsin (hud.gd "PartyPanelLayer" notu). Bedeli: içeriğe göre
## büyüyen/küçülen ve ekranın ortasına konan bir pencerenin sağ üst köşesi (kapat X düğmesi) paneli kaplayan şeridin ALTINA düşebiliyor
## (pencere ne kadar kısalırsa başlık çubuğu o kadar aşağı iner ve sağ sütundaki grup levhalarının arkasında kalır) - X'e basılamıyor.
## ÇÖZÜM: dükkan pencereleri artık ekranın tamamı yerine "güvenli alanda" (grup panelinin sol kenarına kadar) ortalanır ve gerekirse
## o alana sığacak kadar küçülür. Grup paneli görünür değilse (tek oyunculu / müttefik yok) alan eskisi gibi tüm ekrandır.
## Yeni içerik-boyutlu bir modal pencere eklersen yerleşiminde `ModalSafeArea.rect(...)` kullan (bkz. weapon_shop_screen.gd _apply_window_scale).

const GAP := 16.0 ## pencere ile panel arasındaki boşluk
const MAX_RESERVED_FRACTION := 0.4 ## şerit hiçbir zaman ekranın %40'ından fazlasını ayıramaz (çok dar ekranda pencere ezilmesin)
const PartyPanelScript: GDScript = preload("res://scripts/party_panel.gd")


## Grup panelinin kapladığı sağ şeridin genişliği (viewport birimi); panel yok / görünmüyorsa 0.
static func reserved_right(tree: SceneTree, view: Vector2) -> float:
	if tree == null:
		return 0.0
	var pp: Node = tree.get_first_node_in_group(&"party_panel")
	if pp == null or not (pp is CanvasItem) or not (pp as CanvasItem).is_visible_in_tree():
		return 0.0
	var left: float = view.x - PartyPanelScript.RIGHT_MARGIN - PartyPanelScript.ROW_WIDTH
	var bg: Control = pp.get_node_or_null("Background") as Control
	if bg != null and bg.is_visible_in_tree() and bg.size.x > 1.0:
		left = bg.get_global_rect().position.x
	return clampf(view.x - left + GAP, 0.0, view.x * MAX_RESERVED_FRACTION)


## Pencerelerin yerleşeceği alan: ekran eksi grup şeridi (sağdan).
static func rect(tree: SceneTree, view: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(view.x - reserved_right(tree, view), view.y))
