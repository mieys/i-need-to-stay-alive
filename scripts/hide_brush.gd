extends RefCounted

## SAKLANMA ÇALILIĞI alanı (2026-10-09, kullanıcı: "oyundaki saklanma çalılarına girince oyuncular saklanabilsin; yaratıklar görürken girersek onlar da girip
## görebilsin, görmedikleri anda girersek istediğimiz kadar saklanabiliriz"). Alan = haritadaki "Saklanma Çalılığı" TileMapLayer'ının dolu hücreleri
## (Harita.tmx'te tools/hide_bush_proto/place_brush.py + add_brush.py üretir; katman Tiled'da başka bir gruba taşınabilir - AD'la aranır).
## Kural/yönetim: hide_brush_manager.gd. Buradaki işlevler saf okuma: katmanı bul, ayak noktası alanın içinde mi, durum -> saydamlık.

const LAYER_NAME := "Saklanma Çalılığı"
## Oyuncu kökünden ayak noktasına uzaklık (dünya px; depth_occluders FEET_OFFSET ile aynı mantık: 15 x BODY_REL).
const FEET_OFFSET := 15.0 * EntityScale.BODY_REL

## Çalıdaki oyuncunun durumu: 0 = çalıda değil, 1 = SAKLI (kimse göremez), 2 = çalıda ama en az bir yaratık GÖRDÜ (o yaratıklar hedefler).
const STATE_NONE := 0
const STATE_HIDDEN := 1
const STATE_SPOTTED := 2

static var _layer: TileMapLayer = null


## Harita düğümünün altında (en derinde) adı LAYER_NAME olan TileMapLayer.
static func find_layer(harita: Node) -> TileMapLayer:
	if harita == null:
		return null
	var stack: Array[Node] = [harita]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TileMapLayer and String(n.name) == LAYER_NAME:
			return n as TileMapLayer
		for c: Node in n.get_children():
			stack.append(c)
	return null


## Geçerli sahnedeki ("Main/Harita") çalılık katmanı; yoksa null (ana menü, ev içi, testler). Bulunamayan sonuç ÖNBELLEĞE ALINMAZ.
static func layer(tree: SceneTree) -> TileMapLayer:
	if _layer != null and is_instance_valid(_layer) and _layer.is_inside_tree():
		return _layer
	_layer = null
	if tree == null or tree.current_scene == null:
		return null
	_layer = find_layer(tree.current_scene.get_node_or_null("Harita"))
	return _layer


## Testler: katmanı elle ver (null = yeniden ara).
static func set_layer_override(l: TileMapLayer) -> void:
	_layer = l


static func reset() -> void:
	_layer = null


## `feet_world` (dünya) çalılığın dolu bir hücresinde mi?
static func contains(tree: SceneTree, feet_world: Vector2) -> bool:
	var l: TileMapLayer = layer(tree)
	if l == null:
		return false
	return l.get_cell_source_id(l.local_to_map(l.to_local(feet_world))) != -1


## Durum -> karakter sprite'ının saydamlığı (kendi ekranında ve başkalarının ekranında AYNI). Saklı: hafif soluk; görülmüş: daha az soluk (görüldüğünü hissettirir). 2026-10-10: 0,5/0,82 çalının yaprakları da bindirince karakter "görünmüyor" gibiydi -> 0,7/0,9.
static func alpha_for(state: int) -> float:
	match state:
		STATE_HIDDEN:
			return 0.7
		STATE_SPOTTED:
			return 0.9
	return 1.0
