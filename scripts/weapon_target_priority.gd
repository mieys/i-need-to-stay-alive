extends RefCounted

## Silah hedef ÖNCELİĞİ (kullanıcı isteği 2026-09-25): "kopya varken silahlar daima kopyalara odaklanmalıdır, boss
## varken de silahlar daima bosslara odaklanmalıdır".
##
## Kural: silahın menzilindeki (ve takımın gördüğü - sisteki hedeflenemez) canlı bir BOSS ya da "Kopyanı Öldür" görevi
## KOPYASI varsa, silah o anki normal kuralı (en yakın / Buz Asası'nın donmamışı / Tüftüf'ün canı yükseği) hiç
## uygulamadan bunlardan EN YAKININI hedefler. İkisi aynı anda varsa ikisi de aynı öncelikte (en yakını). Menzilde
## böyle bir hedef yoksa silah normal hedeflemesine döner (menzil dışındaki boss yüzünden susmaz).
##
## TEK kaynak: weapon.gd _get_target_enemy (gerçek hedef) VE remote_player.gd _get_target_for_weapon (diğer oyuncuların
## ekranındaki kozmetik nişan) ikisi de bunu çağırır - kaster ile izleyenler aynı yöne nişan alır (CLAUDE.md "iki yer"
## hata sınıfı). Sadece küçük "boss" / "mission_copies" gruplarını tarar - 200 yaratıklık "enemies" grubunu değil.

const BOSS_GROUP := &"boss"
const COPY_GROUP := &"mission_copies" ## bkz. mission_player_copy.gd _ready


## can_target: hedeflenebilirlik süzgeci (Callable(Node) -> bool); geçersiz Callable = süzgeç yok.
static func nearest_priority_target(tree: SceneTree, origin: Vector2, max_range: float, can_target: Callable = Callable()) -> Node2D:
	if tree == null:
		return null
	var best: Node2D = null
	var best_dist: float = INF
	for group_name: StringName in [BOSS_GROUP, COPY_GROUP]:
		for n: Node in tree.get_nodes_in_group(group_name):
			var e := n as Node2D
			if e == null or not is_instance_valid(e) or e.get("is_dead") == true or not e.is_in_group("enemies"):
				continue
			if can_target.is_valid() and not bool(can_target.call(e)):
				continue
			var d: float = origin.distance_to(e.global_position)
			if max_range > 0.0 and d > max_range:
				continue
			if d < best_dist:
				best_dist = d
				best = e
	return best
