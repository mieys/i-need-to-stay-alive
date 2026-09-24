extends RefCounted

## Oyuncu yaratıklarının (Necromancer iskeleti/golemi) duvar dolanma yapay zekası - kullanıcı bildirimi (2026-09-24):
## "Necromancerın tüm yaratıkları duvarları dolanmayı bilmiyor engelleri aşma yapay zekasına sahip değil". Eskiden
## hedefe/sahibine DÜZ çizgide yürüyüp orman duvarına dayanınca orada kalıyorlardı. Yaratıklarla (enemy.gd
## _route_direction) AYNI yöntem ve AYNI A* ızgarası (enemy_pathing.gd): düz çizgi açıkken hiçbir şey değişmez; araya
## orman duvarı girince seyrek aralıklarla yol bulunur ve dönüş noktaları izlenir. Yol bulunamazsa (kapalı cep) düz
## yön döner (eski davranış). Kare başına A* bütçesi (MAX_NEW_PATHS_PER_FRAME) yaratıklarla paylaşılır.
##
## Kullanım: her pet kendi örneğini tutar (`var _router := PetRouterScript.new()`), hareket yönünü
## `_router.direction(global_position, hedef_konum, delta)` ile alır.

const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const LINE_CHECK_INTERVAL := 0.2
const REPLAN_INTERVAL := 1.0
const RETRY_AFTER_FAIL := 2.0
const WAYPOINT_REACHED := 10.0
const GOAL_MOVED_REPLAN := 48.0

var _route: PackedVector2Array = PackedVector2Array()
var _index: int = 0
var _goal: Vector2 = Vector2.ZERO
var _line_timer: float = 0.0
var _replan_timer: float = 0.0
var _line_blocked: bool = false
## Son direction() çağrısında bir yol izleniyor muydu (bakış yönü için).
var following_route: bool = false


func direction(from: Vector2, to: Vector2, delta: float) -> Vector2:
	var straight: Vector2 = (to - from).normalized() if from.distance_to(to) > 0.5 else Vector2.ZERO
	following_route = false
	if not EnemyPathingScript.enabled or from.distance_to(to) > EnemyPathingScript.MAX_ROUTE_DISTANCE:
		_route = PackedVector2Array()
		return straight
	_line_timer -= delta
	if _line_timer <= 0.0:
		_line_timer = LINE_CHECK_INTERVAL * randf_range(0.8, 1.2)
		_line_blocked = EnemyPathingScript.line_blocked(from, to)
		if not _line_blocked:
			_route = PackedVector2Array()
	if not _line_blocked:
		return straight
	_replan_timer -= delta
	var goal_moved: bool = not _route.is_empty() and _goal.distance_to(to) > GOAL_MOVED_REPLAN
	if (_route.is_empty() or _replan_timer <= 0.0 or goal_moved) and EnemyPathingScript.can_request():
		_route = EnemyPathingScript.find_path(from, to)
		_index = 0
		_goal = to
		_replan_timer = (REPLAN_INTERVAL if not _route.is_empty() else RETRY_AFTER_FAIL) * randf_range(0.8, 1.2)
	while _index < _route.size() and from.distance_to(_route[_index]) < WAYPOINT_REACHED:
		_index += 1
	if _index >= _route.size():
		return straight
	following_route = true
	return (_route[_index] - from).normalized()


## Hedefe giden düz çizgi şu an orman duvarı tarafından kesiliyor mu (son kontrol).
func is_line_blocked() -> bool:
	return _line_blocked
