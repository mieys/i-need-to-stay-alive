extends "res://scripts/mission_target.gd"

## KAÇAN HAZİNE (madde 496): altın slime oyunculardan kaçar, vuruldukça yere altın saçar (canının her %1/DROP_STEPS'ünde bir yığın), ölünce
## kalan yığınlar birden; süresi dolarsa kaçıp kaybolur (manager `escape()` çağırır, saçılan altın yerde kalır). Tek oyuncuda da yakalanabilsin
## diye: oyuncuların taban hızının RUN_SPEED_MULT'u kadar koşar ve RUN_TIME koştuktan sonra REST_TIME soluklanır (yakalama penceresi).
## Hareket SADECE host'ta (mission_target.gd ağ deseni, `_moving` = durum sürekli gider), istemci konuma yumuşakça yaklaşır.
## Görsel: Slime 1 yürüme sayfası (enemy_slime1.tscn ile aynı kare düzeni: 8 x 4, satır aşağı/yukarı/sol/sağ) altın tonu shader'ıyla.

const WALK_TEX: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png")
const GoldDropScene: PackedScene = preload("res://scenes/gold_drop.tscn")
const WallSlideScript := preload("res://scripts/wall_slide.gd")
const MissionSpotsScript := preload("res://scripts/mission_spots.gd")

const SPRITE_SCALE := 1.15 ## slime 0,949 - hazine biraz iri, kalabalıkta seçilsin
const SPRITE_OFFSET := Vector2(0, -4.86)
const ANIM_FPS := 11.4
const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3

const RUN_SPEED_MULT := 0.82
const WANDER_SPEED_MULT := 0.28
const FLEE_RADIUS := 380.0
const RUN_TIME := 5.0
const REST_TIME := 1.4
const ACCEL := 900.0
const PROBE := 26.0
const DIRS := 16
const DROP_STEPS := 8
const DROP_GOLD := 12

## Üç duraklı altın rampası (koyu kehribar -> doygun altın -> açık parıltı); slime açık renkli olduğu için parlaklık önce koyulaştırılır,
## yoksa her şey en açık durağa düşüp soluk bej görünüyordu (ilk gerçek çizici çekimi).
const GOLD_SHADER: Shader = preload("res://shaders/gorev_altin_ton.gdshader") ## fx_warmup EXTRA_SHADERS ısıtır

var base_speed: float = 252.0 ## manager yazar (oyuncuların taban hızı ortalaması)
var home: Vector2 = Vector2.ZERO
var _spr: Sprite2D = null
var _vel: Vector2 = Vector2.ZERO
var _run_acc: float = 0.0
var _rest_left: float = 0.0
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_t: float = 0.0
var _drops_done: int = 0
var _anim_t: float = 0.0
var _row: int = ROW_DOWN
var _last_pos: Vector2 = Vector2.ZERO
var _sparkle_t: float = 0.0


func _init() -> void:
	_body_radius = 15.0
	bar_offset = -30.0
	dmg_spawn_offset = Vector2(0, -30)
	_moving = true


func _build_visual() -> void:
	_spr = Sprite2D.new()
	_spr.texture = WALK_TEX
	_spr.hframes = 8
	_spr.vframes = 4
	_spr.scale = Vector2.ONE * SPRITE_SCALE
	_spr.offset = SPRITE_OFFSET
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = GOLD_SHADER
	_spr.material = mat
	add_child(_spr)
	_last_pos = global_position


## Görsel (her makinede): yürüme karesi + yön satırı hareketten; soluklanırken yavaş. Ara ara altın pırıltısı.
func _process(delta: float) -> void:
	if _spr == null or is_dead:
		return
	var moved: Vector2 = global_position - _last_pos
	_last_pos = global_position
	var speed_now: float = moved.length() / maxf(delta, 0.0001)
	if moved.length() > 0.05:
		if absf(moved.x) > absf(moved.y):
			_row = ROW_RIGHT if moved.x > 0.0 else ROW_LEFT
		else:
			_row = ROW_DOWN if moved.y > 0.0 else ROW_UP
	_anim_t += delta * (ANIM_FPS if speed_now > 20.0 else 3.0)
	_spr.frame = _row * 8 + (int(_anim_t) % 8)
	_sparkle_t -= delta
	if _sparkle_t <= 0.0:
		_sparkle_t = randf_range(0.35, 0.8)
		_spawn_sparkle()


func _spawn_sparkle() -> void:
	var p := Sprite2D.new()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.95, 0.6))
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = Vector2(randf_range(-12.0, 12.0), randf_range(-26.0, -6.0))
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", p.position.y - 8.0, 0.5)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _host_tick(delta: float) -> void:
	var threat: Node2D = _nearest_threat()
	var want: Vector2 = Vector2.ZERO
	var spd: float = base_speed * RUN_SPEED_MULT
	if is_disabled_now():
		want = Vector2.ZERO
	elif _rest_left > 0.0:
		_rest_left -= delta
	elif threat != null:
		_run_acc += delta
		if _run_acc >= RUN_TIME:
			_run_acc = 0.0
			_rest_left = REST_TIME
		want = _flee_dir((global_position - threat.global_position).normalized())
	else:
		_run_acc = maxf(0.0, _run_acc - delta)
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.5, 2.8)
			var to_home: Vector2 = home - global_position
			_wander_dir = to_home.normalized() if to_home.length() > 220.0 else Vector2.RIGHT.rotated(randf() * TAU)
		want = _flee_dir(_wander_dir)
		spd = base_speed * WANDER_SPEED_MULT
	var target_v: Vector2 = want * spd * slow_factor()
	_vel = _vel.move_toward(target_v, ACCEL * delta)
	_vel = WallSlideScript.resolve(global_position, _vel, Callable(self, "_blocked"))
	var next: Vector2 = global_position + _vel * delta
	if _blocked(next):
		_vel = Vector2.ZERO
		return
	global_position = next
	_keep_out_of_merchant_zone()


func _nearest_threat() -> Node2D:
	var best: Node2D = null
	var best_d: float = FLEE_RADIUS
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p) or not (p is Node2D) or p.get("is_dead") == true or p.get("is_downed") == true:
				continue
			if p.has_method("is_hadime_ghost") and bool(p.call("is_hadime_ghost")):
				continue
			var d: float = (p as Node2D).global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = p as Node2D
	return best


## İstenen yöne en yakın AÇIK yön (DIRS yönden, önü PROBE kadar boş); dönüşler yumuşak olsun diye mevcut hız yönüne küçük pay.
func _flee_dir(away: Vector2) -> Vector2:
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var cur: Vector2 = _vel.normalized() if _vel.length() > 1.0 else away
	var best: Vector2 = Vector2.ZERO
	var best_s: float = -INF
	for i in range(DIRS):
		var d: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(DIRS))
		if _blocked(global_position + d * PROBE) or _blocked(global_position + d * PROBE * 0.5):
			continue
		var s: float = d.dot(away) + d.dot(cur) * 0.3
		if s > best_s:
			best_s = s
			best = d
	return best


func _blocked(p: Vector2) -> bool:
	if GameManager.is_position_blocked_by_walls(p):
		return true
	if MissionSpotsScript.active() and not MissionSpotsScript.is_reachable_world(p):
		return true
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size != Vector2.ZERO and not rect.grow(-24.0).has_point(p):
		return true
	return GameManager.merchant_zone_active and GameManager.is_position_in_merchant_zone(p)


func _keep_out_of_merchant_zone() -> void:
	if not GameManager.merchant_zone_active:
		return
	var from_center: Vector2 = global_position - GameManager.merchant_zone_pos
	var dist: float = from_center.length()
	if dist >= GameManager.MERCHANT_ZONE_RADIUS:
		return
	var out_dir: Vector2 = from_center / dist if dist > 0.5 else Vector2.RIGHT
	global_position = GameManager.merchant_zone_pos + out_dir * (GameManager.MERCHANT_ZONE_RADIUS + 1.0)


## Host: kaybedilen canın her 1/DROP_STEPS'ünde bir altın yığını (ölünce kalanların hepsi).
func _on_hit_host(_amount: float) -> void:
	var want: int = DROP_STEPS if health <= 0.0 else int(floor((1.0 - health / maxf(max_health, 1.0)) * float(DROP_STEPS)))
	while _drops_done < mini(want, DROP_STEPS):
		_drops_done += 1
		_drop_gold(DROP_GOLD)


## enemy.gd _spawn_gold_drop ile aynı yol (host düşürür + çok oyunculuda yayınlar); birleştirme yok - yığınlar görünsün.
func _drop_gold(amount: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var drop = GoldDropScene.instantiate()
	drop.amount = amount
	drop.global_position = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 12.0))
	if NetworkManager.is_multiplayer_active:
		var drop_id: int = NetworkManager._gen_drop_id()
		drop.set_meta("drop_network_id", drop_id)
		NetworkManager.broadcast_drop.rpc("gold", drop.global_position, drop.amount, drop_id)
	scene_root.call_deferred("add_child", drop)


func dropped_gold_total() -> int:
	return _drops_done * DROP_GOLD


## Süre doldu: kaçıp kaybolur (host; istemciye ölüm yayınıyla aynı kanal - görsel `_on_vanish_fx` iki yerde de).
func escape() -> void:
	vanish()


func _on_death_fx() -> void:
	spawn_burst(get_tree(), global_position + Vector2(0, -10), Color(1.0, 0.85, 0.35), 1.4)


func _on_vanish_fx() -> void:
	spawn_burst(get_tree(), global_position + Vector2(0, -10), Color(1.0, 0.95, 0.7, 0.8), 0.9)
