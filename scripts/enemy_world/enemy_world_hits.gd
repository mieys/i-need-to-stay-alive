extends RefCounted

## Mermi/alan için Area2D.body_entered EŞLENİĞİ (yaratık yeniden yazımı, PLAN §4.3). EnemyWorld açıkken kayıtlı
## yaratıkların fizik gövdesi KAPALI (enemy.gd _ew_try_register) - Area2D onları artık görmez. Mermi her fizik adımının
## SONUNDA poll() çağırır: son konumdan bu konuma süpürülen çember (mermi yarıçapı) ile kesişen yaratıklardan BU KARE
## "içeri giren"leri (ilk temas sırasıyla) döner; içeride kalanlar tekrar dönmez, çıkan sonra yeniden girerse yeniden
## döner - body_entered ile aynı anlam (bumerangın uç nokta "tekrar kesme"si gibi davranışlar değişmesin).
## EnemyWorld kapalıyken / istemcide world() null döner ve mermi eskisi gibi sadece body_entered'a güvenir. Kayıtsız
## "enemies" (görev kopyası) fizik gövdesini koruduğu için body_entered ile gelmeye devam eder - çift isabet olmaz.

var _inside: Dictionary = {} ## instance_id -> true (bir önceki poll'da temas eden)
var _last: Vector2 = Vector2.ZERO
var _has_last: bool = false


const BridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")


## Bu sahnede çalışan EnemyWorld (yoksa null). Ucuz: köprünün statik örneğine bakar.
static func world(tree: SceneTree) -> Object:
	var b: Node = BridgeScript._instance
	if b == null or not is_instance_valid(b) or not b.is_inside_tree() or b.get_tree() != tree:
		return null
	return b.world


## pos: merminin GÜNCEL konumu, radius: çarpışma çemberinin dünya yarıçapı. Dönen düğümleri çağıran işledikten
## (ve gerekirse mermiyi ışınladıktan) sonra mark(global_position) çağrılmalı.
func poll(w: Object, pos: Vector2, radius: float) -> Array:
	var from: Vector2 = _last if _has_last else pos
	var hits: Array = w.call("query_segment", from, pos, radius)
	var now: Dictionary = {}
	var entered: Array = []
	for e in hits:
		var id: int = (e as Object).get_instance_id()
		now[id] = true
		if not _inside.has(id):
			entered.append(e)
	_inside = now
	_last = pos
	_has_last = true
	return entered


## İsabet işlendikten sonraki konum (delici mermi yaratığın merkezine ışınlanır - sonraki süpürme oradan başlasın).
func mark(pos: Vector2) -> void:
	_last = pos
	_has_last = true


## Yarıçap: merminin CollisionShape2D çemberi x global ölçek (kritik x1,4, bumerang büyümesi dahil).
static func shape_radius(owner: Node2D) -> float:
	var cs: CollisionShape2D = owner.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is CircleShape2D):
		return 6.0
	return (cs.shape as CircleShape2D).radius * absf(cs.global_scale.x)
