extends Node

## Kullanıcı bildirimi: "yaratıklar hareket etmediğinde/sabitlendiğinde/yürümediğinde idle
## pozisyonunda durmuyor; agrosu yokken bile yürüme pozisyonunda takılı kalıyor, bu tüm
## yaratıklarda geçerli". Kök neden: enemy.gd durum makinesinde IDLE yoktu (WALK/HURT/ATTACK/
## DEATH). Artık hareket GERÇEK yer değiştirmeden ölçülüp WALK <-> IDLE geçişi yapılıyor
## (bkz. enemy.gd _update_locomotion_state) ve idle sayfası walk sayfasının yolundan türetiliyor.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const State := preload("res://scripts/enemy.gd").State
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const DT := 1.0 / 30.0

var _spawned: Array[Node] = []


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _make_enemy(pos: Vector2 = Vector2.ZERO) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.speed = 90.0 ## sahnedeki ~62/28 px/sn yerine varsayılan hız: testler kısa sürsün
	_spawned.append(e)
	return e


func _creature_scene_paths() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://scenes/creatures")
	assert(dir != null, "creatures klasörü açılamadı")
	for f: String in dir.get_files():
		if f.begins_with("enemy_") and f.ends_with(".tscn"):
			out.append("res://scenes/creatures/" + f)
	out.sort()
	return out


## TÜM yaratıklarda: idle sayfası bulunmalı ve walk sayfasıyla aynı düzende olmalı.
func test_every_creature_gets_a_compatible_idle_sheet() -> void:
	var paths: Array[String] = _creature_scene_paths()
	assert(paths.size() >= 49, "Beklenen 49 yaratık sahnesi, bulunan: %d" % paths.size())
	for path: String in paths:
		var packed: PackedScene = load(path)
		var e: Node = packed.instantiate()
		add_child(e)
		var idle: Texture2D = e.get("idle_texture")
		var walk: Texture2D = e.get("walk_texture")
		var cell: int = int(e.get("cell_size"))
		assert(idle != null, "%s için idle sayfası türetilemedi" % path)
		if idle != null and walk != null:
			assert(idle.get_height() == walk.get_height(), "%s: idle/walk sayfa yükseklikleri farklı (4 yön satırı bekleniyor)" % path)
			assert(idle.get_width() % cell == 0, "%s: idle sayfa genişliği hücre boyunun katı olmalı" % path)
			assert(idle.get_width() != 0, "%s: idle sayfası boş" % path)
		e.free()


func test_a_stationary_enemy_switches_to_idle_and_shows_the_idle_sheet() -> void:
	var e := _make_enemy()
	assert(e._state == State.WALK, "başlangıç durumu WALK olmalı")
	for i: int in range(12): ## 0.4 sn hareketsiz
		e._update_locomotion_state(DT)
	assert(e._state == State.IDLE, "Hareketsiz yaratık IDLE'a geçmeli, durum: %s" % e._state)
	var idle: Texture2D = e.get("idle_texture")
	assert(e.frame_sprite.texture == idle, "IDLE'da idle sayfası gösterilmeli (yürüme karesinde takılı kalmamalı)")
	assert(e.frame_sprite.hframes == int(idle.get_width() / float(e.cell_size)), "hframes idle sayfasına göre ayarlanmalı")
	## idle karelerinin döngüde oynadığını doğrula
	var seen := {}
	for i: int in range(40):
		e._advance_frame_sprite(0.05)
		seen[e.frame_sprite.frame] = true
	assert(seen.size() > 1, "Idle animasyonu döngüde oynamalı")
	_cleanup()


func test_moving_enemy_stays_in_walk() -> void:
	var e := _make_enemy()
	for i: int in range(45): ## 1.5 sn, 90 px/sn
		e.global_position += Vector2(90.0 * DT, 0.0)
		e._update_locomotion_state(DT)
	assert(e._state == State.WALK, "Yürüyen yaratık WALK'ta kalmalı, durum: %s" % e._state)
	assert(e.frame_sprite.texture == e.walk_texture, "Yürürken yürüme sayfası gösterilmeli")
	_cleanup()


func test_short_pauses_do_not_flicker_but_real_stops_and_restarts_do_switch() -> void:
	var e := _make_enemy()
	for i: int in range(10):
		e.global_position += Vector2(3.0, 0.0)
		e._update_locomotion_state(DT)
	## 1 karelik duraksama IDLE'a geçirmemeli
	e._update_locomotion_state(DT)
	assert(e._state == State.WALK, "Tek karelik duraksamada poz titremesin (histerezis)")
	for i: int in range(10):
		e.global_position += Vector2(3.0, 0.0)
		e._update_locomotion_state(DT)
	for i: int in range(12):
		e._update_locomotion_state(DT)
	assert(e._state == State.IDLE, "Gerçekten durunca IDLE olmalı")
	for i: int in range(6):
		e.global_position += Vector2(3.0, 0.0)
		e._update_locomotion_state(DT)
	assert(e._state == State.WALK, "Tekrar hareket edince WALK'a dönmeli, durum: %s" % e._state)
	_cleanup()


## HURT/ATTACK önceliklidir; bitince yaratık hâlâ duruyorsa yürüme pozuna DÖNMEDEN IDLE olur.
func test_hurt_has_priority_then_falls_back_to_idle_when_still_stationary() -> void:
	var e := _make_enemy()
	e._enter_state(State.HURT, 0.2)
	for i: int in range(4):
		e._update_locomotion_state(DT)
		e._update_state_timer(DT)
	assert(e._state == State.HURT, "HURT sürerken IDLE'a geçilmemeli")
	for i: int in range(6): ## hurt süresi biter -> WALK -> (durduğu için) IDLE
		e._update_locomotion_state(DT)
		e._update_state_timer(DT)
	assert(e._state == State.IDLE, "HURT bitince duran yaratık IDLE'a geçmeli, durum: %s" % e._state)
	e._enter_state(State.DEATH)
	for i: int in range(12):
		e._update_locomotion_state(DT)
	assert(e._state == State.DEATH, "DEATH hiçbir zaman IDLE/WALK'a çevrilmemeli")
	_cleanup()


## Yedek: idle sayfası yoksa yürüme karelerini döndürmek yerine duruş karesinde beklesin.
func test_without_an_idle_sheet_the_walk_frames_are_not_cycled() -> void:
	var e := _make_enemy()
	e.idle_texture = null
	for i: int in range(12):
		e._update_locomotion_state(DT)
	assert(e._state == State.IDLE)
	var cols: int = maxi(e.frame_sprite.hframes, 1)
	for i: int in range(30):
		e._advance_frame_sprite(0.1)
		assert(e.frame_sprite.frame % cols == 0, "Idle sayfası yokken duruş karesinde (0) beklemeli")
	_cleanup()


## Yaratık yeniden yazımı (2026-10-03): host'ta "gerçek fizik döngüsü" = C++ EnemyWorld adımı (yürüme/bekleme tespiti
## step_loco_anim -> E_LOCO olayı -> enemy.gd _ew_on_loco). Test düğümü current_scene olduğu için yaratık kaydolur; köprüyü
## ELLE adımlarız (eski enemy._physics_process(DT) döngüsünün karşılığı).
func _step(frames: int, per_frame: Callable = Callable()) -> void:
	var b: Node = EnemyWorldBridgeScript._instance
	b.set_physics_process(false)
	for i: int in range(frames):
		b._physics_process(DT)
		if per_frame.is_valid() and per_frame.call(i):
			break
	b.set_physics_process(true)


## Gerçek fizik döngüsü: donmuş (sabitlenmiş) yaratık idle pozuna geçmeli.
func test_frozen_enemy_goes_idle_in_the_real_physics_loop() -> void:
	var e := _make_enemy()
	await get_tree().process_frame ## köprü ertelenerek eklenir
	e.is_frozen = true
	e._freeze_timer = 30.0
	e._ew_wake()
	_step(20)
	assert(e._state == State.IDLE, "Donmuş/sabitlenmiş yaratık IDLE'a geçmeli, durum: %s" % e._state)
	_cleanup()


## Gerçek kovalama: hedefe yürürken WALK; hedefin dibinde durunca (sürekli saldırıdaki ATTACK ya da
## saldırısız anlarda IDLE) ASLA yürüme pozunda kalmamalı.
func test_chasing_enemy_walks_then_never_walks_in_place_at_the_target() -> void:
	var target := Node2D.new()
	target.add_to_group("player")
	add_child(target)
	_spawned.append(target)
	target.global_position = Vector2(400.0, 0.0)
	var e := _make_enemy(Vector2.ZERO)
	await get_tree().process_frame
	var saw_walk: Array = [false]
	_step(60, func(_i: int) -> bool: ## 2 sn: hâlâ yolda
		if e._state == State.WALK:
			saw_walk[0] = true
		return false)
	assert(saw_walk[0] and e._state == State.WALK, "Hedefe yürürken WALK olmalı, durum: %s" % e._state)
	_step(240, func(_i: int) -> bool: return e.global_position.distance_to(target.global_position) < 60.0) ## hedefe varana kadar
	assert(e.global_position.distance_to(target.global_position) < 80.0, "Yaratık hedefe ulaşmalıydı: %s" % str(e.global_position))
	var walked_in_place: Array = [0]
	_step(150, func(i: int) -> bool: ## 5 sn hedefin dibinde
		if e._state == State.WALK and i > 6:
			walked_in_place[0] += 1
		return false)
	assert(walked_in_place[0] == 0, "Hedefin dibinde duran yaratık yürüme pozunda takılı kalmamalı (%d kare)" % walked_in_place[0])
	_cleanup()


## AGROSUZ dolaşma: hem yürüme hem duraklama görülmeli (duraklamada IDLE).
func test_wandering_enemy_without_a_target_idles_during_pauses() -> void:
	var e := _make_enemy(Vector2(1000.0, 1000.0)) ## "player" grubunda kimse yok -> hedefsiz dolaşma
	await get_tree().process_frame
	var seen: Dictionary = {}
	_step(3000, func(_i: int) -> bool: ## 100 sn
		if e._state == State.IDLE or e._state == State.WALK:
			seen[e._state] = true
		return seen.size() == 2)
	assert(seen.has(State.WALK), "Hedefsiz dolaşırken yürüme görülmeli")
	assert(seen.has(State.IDLE), "Hedefsiz dolaşırken duraklamalarda IDLE görülmeli (yürüme pozunda takılmamalı)")
	_cleanup()


## Host yaratığı ve istemci kuklası AYNI yürüme/bekleme kuralını kullanmalı - yoksa katılımcılarda sorun sürer. Yeni
## yolda ikisi de C++ step_loco_anim (host dalı + F_PUPPET dalı); C++'a kaydı olmayan istemci kuklası / ölüm dalı
## enemy.gd _update_locomotion_state.
func test_host_and_client_branches_both_update_locomotion() -> void:
	var cpp: String = FileAccess.get_file_as_string("res://gdextension/enemy_world/src/enemy_world.cpp")
	assert(cpp.count("step_loco_anim(i, delta);") >= 2, "C++'ta hem host hem kukla dalı step_loco_anim'i çağırmalı")
	var src: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert(src.count("_update_locomotion_state(delta)") >= 1, "Kayıtsız istemci / ölüm dalı _update_locomotion_state'i çağırmalı")