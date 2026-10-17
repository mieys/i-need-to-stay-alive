extends RefCounted
## Mermi menzili = GÖRÜŞ ALANI (2026-10-14, kullanıcı: "silahların mermilerin menzili sınırsız gibi, ıskalayınca bile çok uzağa gitmemeli,
## görüş açısıyla sınırlı olmalı (yaratıklar dahil)"). Mermi atıldığı noktadan itibaren sisin görüş elipsini (vision_fog.gd: yarıçap x
## VISION_WIDTH_SCALE yatayda) aşınca silinir. Çıkış noktası merminin İLK fizik karesindeki konumudur (weapon.gd yönü/konumu add_child'dan
## sonra atar) - bu yüzden her istemcide (görsel kopyalar dahil) aynı yerde biter. Sis/atmosfer yoksa (menü, testler) VISION_RADIUS sınırı geçerli.

const VisionFogScript := preload("res://scripts/vision_fog.gd")

const META_ORIGIN := &"proj_range_origin"

static var _cached_frame: int = -1
static var _cached_radius: float = VisionFogScript.VISION_RADIUS


## Necromancer minyonları sahibinin görüş elipsinden çıkamaz (2026-10-17): konumu elipse (kenardan MARGIN payla) sıkıştırır.
const OWNER_LEASH_MARGIN := 0.92


static func owner_vision_radius(tree: SceneTree) -> float:
	return VisionFogScript.current_radius(tree)


## true = nokta sahibin görüş elipsinin içinde.
static func inside_owner_vision(pos: Vector2, owner_pos: Vector2, tree: SceneTree) -> bool:
	return VisionFogScript.normalized_distance(pos - owner_pos, VisionFogScript.current_radius(tree), VisionFogScript.VISION_WIDTH_SCALE) <= OWNER_LEASH_MARGIN


## Elipsin dışındaysa kenara çeker, içindeyse aynen döner.
static func clamp_to_owner_vision(pos: Vector2, owner_pos: Vector2, tree: SceneTree) -> Vector2:
	var radius: float = VisionFogScript.current_radius(tree)
	var off: Vector2 = pos - owner_pos
	var n: float = VisionFogScript.normalized_distance(off, radius, VisionFogScript.VISION_WIDTH_SCALE)
	if n <= OWNER_LEASH_MARGIN or n <= 0.0:
		return pos
	return owner_pos + off * (OWNER_LEASH_MARGIN / n)


## Elipsin içinde mi (true = uçmaya devam). Çıkış noktası yoksa şimdiki konum çıkış noktası olur.
static func within(node: Node2D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return true
	if not node.has_meta(META_ORIGIN):
		node.set_meta(META_ORIGIN, node.global_position)
		return true
	var frame: int = Engine.get_physics_frames()
	if frame != _cached_frame:
		_cached_frame = frame
		_cached_radius = VisionFogScript.current_radius(node.get_tree())
	var origin: Vector2 = node.get_meta(META_ORIGIN)
	return VisionFogScript.normalized_distance(node.global_position - origin, _cached_radius, VisionFogScript.VISION_WIDTH_SCALE) <= 1.0
