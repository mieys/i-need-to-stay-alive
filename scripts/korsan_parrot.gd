extends Node2D

## Evcil hayvan Papağan (korsan_parrot.gd; dosya/sınıf adları eski Korsan pasifinden kaldı).
## 2026-10-17 (madde 203, kullanıcı isteği): artık yerdeki altınları TOPLAMAZ. Sahibinin yakınındaki bir AĞACIN dibine uçar, 3-4 sn gagalar ve
## ağaçtan yere bir eşya düşer (yiyecek / kalkan orbu / mıknatıs / silah parçacığı, değersizden değerliye; zar `parrot_tree_loot.gd`), sonra omza
## döner ve kısa bir bekleme sonrası yeni bir ağaca gider.
##
## TEK script, iki mod:
##  - YEREL (player.gd, sahibin kendi ekranı): ağaç seçer, uçar, gagalar, ödülü düşürür. Her durum değişikliğini
##    NetworkManager.broadcast_korsan_parrot ile (güvenilir RPC) diğer oyunculara bildirir. Ödül: host / tek oyunculu doğrudan
##    ParrotTreeLoot.spawn, istemci NetworkManager.request_parrot_tree_drop ile host'tan ister (drop'lar host'ta gerçek).
##  - KUKLA (remote_player.gd, diğer oyuncuların ekranı): karar vermez; gelen olaya göre AYNI hareket/görsel kodla uçar / gagalar / konar.
## Omuzdayken oyuncunun normal çocuğu (akıcı konumunu kendiliğinden izler), uçarken top_level. Görsel: assets/characters/korsan_parrot.

const CharAnim := preload("res://scripts/char_anim.gd")
const FRAMES: SpriteFrames = preload("res://assets/characters/korsan_parrot/parrot_frames.tres")
const ANCHOR_OFFSET := Vector2(0.0, -6.0) ## hücrede ayak noktası (24, 30) -> düğüm orijini (bkz. gen_korsan_parrot.py)

const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const ParrotTreeLoot := preload("res://scripts/parrot_tree_loot.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")

const SPEED_MULT := 1.2 ## sahibin (etkin) hareket hızının katı
const MIN_SPEED := 120.0
const SCAN_RADIUS := 320.0 ## sahibe bu mesafedeki ağaçlar
const MIN_TREE_DIST := 48.0 ## bundan yakın ağaçlar seçilmez (omuzdan kalkmaya değmez)
const SAME_TREE_DIST := 40.0 ## az önce gagalanan ağaca tekrar gitme
const LEASH := 560.0 ## sahipten bu kadar uzaklaşırsa geri döner
const SCAN_INTERVAL := 0.5
const TREE_TRIES := 48 ## ağaç hücresi listesinden rastgele kaç deneme (liste binlerce hücre olabilir)
const PECK_MIN := 3.0 ## kullanıcı: "3-4 saniye gagalayarak"
const PECK_MAX := 4.0
const COOLDOWN := 60.0 ## omza döndükten sonra yeni ağaç aramadan önce bekleme (kullanıcı: "60 saniyede bir")
const PECK_BODY_OFFSET := Vector2(0.0, 3.0) ## papağan ağaç dibinin hemen önünde durur (y-sıralamada gövdenin önünde kalsın, tacın arkasında kaybolmasın)
const DROP_SCATTER := Vector2(10.0, 8.0) ## ödül ağaç dibinin etrafında bu kadar saçılır (+ biraz önüne)
const GRAB_DIST := 7.0
const LAND_DIST := 7.0

## Omuz noktaları: sahibin 48x48 karesinde (sanat pikseli) yöne göre tünek + papağanın bakışı + karakterin ARKASINDA mı
## (yan görünüşte arka omuzda, başın arkasında kalır).
const PERCH := {
	"down": {"p": Vector2(34, 24), "flip": false, "behind": false},
	"up": {"p": Vector2(32, 24), "flip": false, "behind": false},
	"left": {"p": Vector2(29, 24), "flip": true, "behind": true},
	"right": {"p": Vector2(19, 24), "flip": false, "behind": true},
}

enum State { PERCH, FLY_TO, RETURN, PECK }

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false

var state: int = State.PERCH
var _sprite: AnimatedSprite2D = null
var _behind: bool = false
var _flying: bool = false
var _speed: float = 200.0
var _target_pos: Vector2 = Vector2.ZERO ## ağaçta durulacak nokta (yerel: seçilen, kukla: bildirilen)
var _tree_base: Vector2 = Vector2.ZERO ## yerel: ağacın dibi (ödül buraya düşer)
var _last_tree: Vector2 = Vector2(INF, INF)
var _scan_timer: float = 0.0
var _cooldown: float = 3.0
var _peck_timer: float = 0.0
var _peck_clock: float = 0.0
var _arrived: bool = false ## kukla: hedefe vardı (gagalamaya başlar)
## "Buradayım" kalp atışı: papağan omuzda dururken HİÇ olay üretmediği için diğer ekranlardaki kukla ilk uçuşa kadar hiç kurulmuyordu.
const NET_HEARTBEAT := 8.0
var _net_idle: float = NET_HEARTBEAT - 1.0


func setup(body: Node2D, anim_src: AnimatedSprite2D, puppet: bool) -> void:
	owner_body = body
	char_anim = anim_src
	is_puppet = puppet
	name = "KorsanParrot"
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = ANCHOR_OFFSET
	add_child(_sprite)
	_sprite.play("perch")
	_sprite.frame = randi() % 4


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	if is_puppet:
		_process_puppet(delta)
	else:
		_process_local(delta)


## ---------------------------------------------------------------- yerel (karar veren) taraf

func _process_local(delta: float) -> void:
	_speed = maxf(MIN_SPEED, SPEED_MULT * (float(owner_body.get_effective_move_speed()) if owner_body.has_method("get_effective_move_speed") else 200.0))
	var busy: bool = owner_body.get("is_dead") == true or owner_body.get("is_downed") == true or owner_body.get("is_indoors") == true
	## güvenli alanda (satıcı koruması / demirci) evcil hayvan çalışmaz: sayaçlar donar, gagalayan omuza döner (madde 327)
	busy = busy or (owner_body.has_method("is_safe_zone_frozen") and owner_body.is_safe_zone_frozen())
	_net_idle += delta
	match state:
		State.PERCH:
			_perch_follow()
			if _net_idle >= NET_HEARTBEAT:
				_broadcast(State.PERCH, Vector2.ZERO)
			if busy:
				return
			_cooldown -= delta
			_scan_timer -= delta
			if _cooldown > 0.0 or _scan_timer > 0.0:
				return
			_scan_timer = SCAN_INTERVAL
			var found: Variant = _find_tree(owner_body.global_position)
			if found != null:
				_tree_base = found as Vector2
				_target_pos = _tree_base + PECK_BODY_OFFSET
				_take_off()
				state = State.FLY_TO
				_broadcast(State.FLY_TO, _target_pos)
		State.FLY_TO:
			if busy or global_position.distance_to(owner_body.global_position) > LEASH:
				_start_return()
				return
			if _fly_toward(_target_pos, delta, GRAB_DIST):
				state = State.PECK
				_peck_timer = randf_range(PECK_MIN, PECK_MAX)
				_peck_clock = 0.0
				_broadcast(State.PECK, _target_pos)
		State.PECK:
			if busy or global_position.distance_to(owner_body.global_position) > LEASH:
				_start_return()
				return
			_peck_timer -= delta
			_bob(delta)
			if _peck_timer <= 0.0:
				_drop_loot()
				_last_tree = _tree_base
				_start_return()
		State.RETURN:
			if _fly_toward(_shoulder_global(), delta, LAND_DIST):
				_land()
				_cooldown = COOLDOWN
				_broadcast(State.PERCH, Vector2.ZERO)


## Sahibin SCAN_RADIUS'u içinde, çok yakın olmayan rastgele bir ağaç dibi (yoksa null). Ağaç hücre listesi büyük: hepsini taramak yerine
## rastgele TREE_TRIES deneme (her ~6 sn'de bir çalışır).
func _find_tree(around: Vector2) -> Variant:
	var forest: TileMapLayer = GameManager.get_forest_layer()
	if forest == null:
		return null
	TerrainCollisionScript.ensure(forest)
	var cells: Array = TerrainCollisionScript.by_category.get("trees", [])
	if cells.is_empty():
		return null
	for i in range(TREE_TRIES):
		var base: Vector2 = TerrainCollisionScript.cell_world_base(cells[randi() % cells.size()])
		var d: float = base.distance_to(around)
		if d < MIN_TREE_DIST or d > SCAN_RADIUS:
			continue
		if base.distance_to(_last_tree) < SAME_TREE_DIST:
			continue
		return base
	return null


## Gagalama bitti: ödül ağaç dibinin hemen önüne düşer (gövde hücresi geçilmez olduğu için biraz güneyde, sahibin alabileceği yerde).
func _drop_loot() -> void:
	var pos: Vector2 = _tree_base + Vector2(randf_range(-DROP_SCATTER.x, DROP_SCATTER.x), DROP_SCATTER.y + randf_range(0.0, 6.0))
	BalanceLogScript.on_pet_drop() ## sahibin ekranında sayılır (kukla buraya gelmez) - evcil yuvası ipucu
	if not NetworkManager.is_multiplayer_active or NetworkManager.is_host:
		ParrotTreeLoot.spawn(get_tree(), pos, ParrotTreeLoot.roll())
	else:
		NetworkManager.request_parrot_tree_drop.rpc_id(NetworkManager._host_peer_id(), pos)


## Eski altın cevabı (host artık papağana altın vermiyor) - player.gd korsan_parrot_gold_result uyumu için boş.
func on_gold_result(_drop_id: int, _amount: int) -> void:
	pass


func _start_return() -> void:
	_reset_bob()
	state = State.RETURN
	_broadcast(State.RETURN, Vector2.ZERO)


func _broadcast(s: int, target: Vector2) -> void:
	_net_idle = 0.0
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_korsan_parrot.rpc(multiplayer.get_unique_id(), s, target, 0, _speed)


## ---------------------------------------------------------------- kukla (diğer oyuncuların ekranı)

## remote_player.gd -> korsan_parrot_event: sahibinin papağanı durum değiştirdi.
func apply_event(s: int, target: Vector2, _carry: int, spd: float) -> void:
	_speed = maxf(MIN_SPEED, spd)
	match s:
		State.FLY_TO, State.PECK:
			if state == State.PERCH:
				_take_off()
			if s == State.FLY_TO or target != _target_pos:
				_arrived = false
			state = s
			_target_pos = target
		State.RETURN:
			if state == State.PERCH:
				_take_off()
			_reset_bob()
			state = State.RETURN
		State.PERCH:
			## Konma olayı: uzaktaysa önce uçarak döner, varınca konar.
			if state != State.PERCH:
				_reset_bob()
				state = State.RETURN


func _process_puppet(delta: float) -> void:
	match state:
		State.PERCH:
			_perch_follow()
		State.FLY_TO, State.PECK:
			if not _arrived:
				_arrived = _fly_toward(_target_pos, delta, GRAB_DIST)
			elif state == State.PECK:
				_bob(delta)
		State.RETURN:
			if _fly_toward(_shoulder_global(), delta, LAND_DIST):
				_land()


## Gagalama: papağan hızlı hızlı gövdeye doğru eğilir (yerel y zıplaması, sprite ofsetine eklenir).
func _bob(delta: float) -> void:
	_peck_clock += delta
	if _sprite.animation != &"perch":
		_sprite.play("perch") ## gagalarken konmuş duruş, kafa vuruşu aşağıdaki ofsetle
	var nod: float = maxf(0.0, sin(_peck_clock * 14.0))
	_sprite.position = Vector2(0.0, nod * 2.0)


func _reset_bob() -> void:
	_peck_clock = 0.0
	if _sprite:
		_sprite.position = Vector2.ZERO
		if _flying:
			_sprite.play("fly")


## ---------------------------------------------------------------- ortak hareket/görsel

func _facing() -> String:
	return CharAnim.dir_of(String(char_anim.animation))


## Tünek noktası sahibin YEREL koordinatında (karakter sprite'ının dönüşümüyle: sprite merkezli, 48x48 hücre).
func _shoulder_local() -> Vector2:
	var cfg: Dictionary = PERCH.get(_facing(), PERCH["down"])
	var art: Vector2 = cfg["p"]
	return char_anim.transform * (art - Vector2(24.0, 24.0) + char_anim.offset)


func _shoulder_global() -> Vector2:
	return owner_body.to_global(_shoulder_local())


func _perch_follow() -> void:
	position = _shoulder_local()
	scale = char_anim.scale
	var cfg: Dictionary = PERCH.get(_facing(), PERCH["down"])
	_sprite.flip_h = bool(cfg["flip"])
	_set_behind(bool(cfg["behind"]))


func _take_off() -> void:
	_reset_bob()
	var gp: Vector2 = global_position
	top_level = true
	global_position = gp
	global_scale = char_anim.global_scale
	_flying = true
	_set_behind(false)
	_sprite.play("fly")


func _land() -> void:
	_reset_bob()
	top_level = false
	_flying = false
	state = State.PERCH
	_sprite.play("perch")
	_perch_follow()


## Hedefe _speed ile ilerler; vardıysa true. Bakış yönü hareket yönüne göre.
func _fly_toward(dest: Vector2, delta: float, arrive: float) -> bool:
	global_scale = char_anim.global_scale
	var to: Vector2 = dest - global_position
	var step: float = _speed * delta
	if to.length() <= maxf(arrive, step):
		global_position = dest
		return true
	global_position += to.normalized() * step
	if absf(to.x) > 0.5:
		_sprite.flip_h = to.x < 0.0
	return false


## Yan görünüşte papağan başın arkasında kalsın: karakter sprite'ından ÖNCE çizilecek sıraya alınır (aynı ebeveyn).
func _set_behind(b: bool) -> void:
	if b == _behind or get_parent() != char_anim.get_parent():
		return
	_behind = b
	var ai: int = char_anim.get_index()
	var si: int = get_index()
	if (b and si > ai) or (not b and si < ai):
		get_parent().move_child(self, ai)
