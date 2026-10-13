extends NpcActor
class_name MerchantNpc

## SEYYAR SATICI NPC'si (kullanıcı isteği 2026-10-13, madde 112): arabanın (traveling_merchant.gd görseli) yanında, KORUMA BALONCUĞUNUN içinde durur.
##  - OYUNCU YOKKEN: balonun içindeki dinlenme noktalarında bekler (idle), ara sıra düşünme klibine girer ("think"), ara sıra başka bir dinlenme noktasına yürür.
##  - OYUNCU YAKLAŞINCA (APPROACH_RADIUS): selam verir, dükkanına (arabanın tezgah önü, SERVICE_POST) yürür, oyunculara bakar (en yakına döner);
##    bekleme sırasında ara sıra düşünür.
##  - OYUNCULAR UZAKLAŞINCA (LEAVE_RADIUS, histerezis): "hoşça kal" der, dinlenme noktasına döner.
## Koordinatlar ARABA GÖRSELİNİN yerelinde (traveling_merchant.gd _load_baked_visual: çalışma kutusunun merkezi köke kaydırılır; çadır/araba/at karoları
## köke göre sabit) - yani ayak noktaları dünya px, kökte araba tezgahı (x ~ +5..+34, y ~ +5..+11), tekerlek altı y ~ +27.
## Tamamen yerel/kozmetik (ağ yok): oyuncu konumlarından türer, her istemci kendi satıcısını çalıştırır.

const FRAMES: SpriteFrames = preload("res://assets/npc/seyyar_satici/seyyar_satici_frames.tres")

enum State { REST, TO_POST, SERVE, FAREWELL }

## Dükkan noktası: tezgahın önü, tekerlekler arası (araba güney yüzü). Satıcı arabanın ÖNÜNDE (güney) durur: NPC z=1 karo katmanlarının (z=0) üstünde çizilir.
const SERVICE_POST := Vector2(18.0, 33.0)
## Dinlenme noktaları: at yanı, arabanın doğusu, arabanın önü. Hepsi balonun içinde (GameManager.MERCHANT_ZONE_RADIUS 185) ve araba/atın güneyinde
## (NPC kuzey tarafta karo katmanlarının üstünde "havada" görünürdü); noktalar arası düz çizgi tekerlek/at altından geçmez.
const REST_SPOTS: Array[Vector2] = [Vector2(-30.0, 38.0), Vector2(62.0, 31.0), Vector2(20.0, 50.0)]
const APPROACH_RADIUS := 280.0 ## oyuncu araba merkezine bu kadar yaklaşınca satıcı dükkana geçer (koruma balonu 185 + pay)
const LEAVE_RADIUS := 360.0 ## hepsi bu kadar uzaklaşınca vedalaşıp döner (APPROACH_RADIUS'tan büyük: sınırda gidip gelmeyi önler)
const GREETINGS: Array[String] = ["Merhaba, yolcu!", "Hoş geldin! Mallarıma bir göz at.", "Selam! Ne lazımdı?"]
const FAREWELLS: Array[String] = ["Hoşça kal!", "Yolun açık olsun!", "Yine beklerim!"]
const THINK_MIN := 7.0 ## iki düşünme arası (sn)
const THINK_MAX := 15.0
const THINK_TIME_MIN := 2.5 ## bir düşünme ne kadar sürer (sn)
const THINK_TIME_MAX := 4.0
const WANDER_MIN := 12.0
const WANDER_MAX := 24.0
const FAREWELL_TIME := 1.6
const RETARGET_INTERVAL := 0.3 ## en yakın oyuncuya dönme sıklığı (sn)

var state: State = State.REST
var _spot: int = 0
var _think_cd: float = 0.0
var _think_left: float = 0.0
var _wander_cd: float = 0.0
var _timer: float = 0.0
var _retarget_cd: float = 0.0


## traveling_merchant.gd çağırır; ebeveyn = araba görseli (yerel koordinatlar araba merkezine göre).
func configure() -> void:
	setup(FRAMES)
	name = "MerchantNpc"
	arrived.connect(_on_arrived)
	_spot = randi() % REST_SPOTS.size()
	set_feet(REST_SPOTS[_spot])
	play_idle(["down", "down", "left", "right"][randi() % 4])
	_think_cd = randf_range(THINK_MIN, THINK_MAX)
	_wander_cd = randf_range(WANDER_MIN, WANDER_MAX)


func _behave(delta: float) -> void:
	var near: Array[Node2D] = _players_within(LEAVE_RADIUS if state != State.REST else APPROACH_RADIUS)
	match state:
		State.REST:
			if not near.is_empty():
				_on_customers(near)
				return
			_tick_think(delta)
			if _think_left <= 0.0 and not is_walking():
				_wander_cd -= delta
				if _wander_cd <= 0.0:
					_wander()
		State.TO_POST:
			pass
		State.SERVE:
			if near.is_empty():
				_say_farewell()
				return
			_retarget_cd -= delta
			if _retarget_cd <= 0.0:
				_retarget_cd = RETARGET_INTERVAL
				_face_nearest(near)
			_tick_think(delta)
		State.FAREWELL:
			_timer -= delta
			if _timer <= 0.0:
				_return_to_rest()


## Düşünme: _think_cd bitince think klibi _think_left sn oynar, sonra idle'a döner (kilit "think" klibi yönü korur).
func _tick_think(delta: float) -> void:
	if _think_left > 0.0:
		_think_left -= delta
		if _think_left <= 0.0:
			unlock_clip()
			_think_cd = randf_range(THINK_MIN, THINK_MAX)
		return
	if is_walking():
		return
	_think_cd -= delta
	if _think_cd <= 0.0:
		_think_left = randf_range(THINK_TIME_MIN, THINK_TIME_MAX)
		lock_clip("think")


func _on_customers(near: Array[Node2D]) -> void:
	state = State.TO_POST
	_think_left = 0.0
	unlock_clip()
	_face_nearest(near)
	say(GREETINGS[randi() % GREETINGS.size()])
	walk_path(PackedVector2Array([SERVICE_POST]))


func _on_arrived() -> void:
	match state:
		State.TO_POST:
			state = State.SERVE
			_think_cd = randf_range(THINK_MIN * 0.5, THINK_MAX * 0.5)
			_face_nearest(_players_within(LEAVE_RADIUS))
		State.REST:
			play_idle()


func _say_farewell() -> void:
	state = State.FAREWELL
	_timer = FAREWELL_TIME
	_think_left = 0.0
	stop_walking()
	unlock_clip()
	say(FAREWELLS[randi() % FAREWELLS.size()])


func _return_to_rest() -> void:
	state = State.REST
	_spot = _other_spot()
	_wander_cd = randf_range(WANDER_MIN, WANDER_MAX)
	_think_cd = randf_range(THINK_MIN, THINK_MAX)
	walk_path(PackedVector2Array([REST_SPOTS[_spot]]))


func _wander() -> void:
	_spot = _other_spot()
	_wander_cd = randf_range(WANDER_MIN, WANDER_MAX)
	walk_path(PackedVector2Array([REST_SPOTS[_spot]]))


func _other_spot() -> int:
	return (_spot + 1 + randi() % (REST_SPOTS.size() - 1)) % REST_SPOTS.size()


## Araba merkezine (ebeveyn konumu) `radius` içindeki canlı oyuncular.
func _players_within(radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var origin: Vector2 = (get_parent() as Node2D).global_position
	for p: Node2D in NpcActor.live_players(get_tree()):
		if p.global_position.distance_to(origin) <= radius:
			out.append(p)
	return out


func _face_nearest(players: Array[Node2D]) -> void:
	var best: Node2D = null
	var best_d: float = INF
	for p: Node2D in players:
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	if best != null:
		face_point(get_parent().to_local(best.global_position) + Vector2(0.0, FEET_OFFSET))
