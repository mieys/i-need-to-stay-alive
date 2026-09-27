extends Node2D

## Korsan pasifi "Papağan" (kullanıcı isteği 2026-09-26): "Papağanı korsanın omzunda durur ve etrafta altın varsa uçarak
## altını alarak korsanın omzuna tekrar geri döner. Topladığı her altından 1 bonus kazanır, aynı anda en fazla 3 altın
## toplayıp getirebilir. Papağanın uçma hızı korsanın hareket hızının 1.2 katı kadardır. Topladığı altını ayağının altında
## tutarak korsana getirir." Eski pasif (öldürmede %10+ şansla 1 altın) kaldırıldı.
##
## TEK script, iki mod:
##  - YEREL (player.gd, Korsan oynayan kişinin kendi ekranı): altın arar, uçar, alır, getirir, altını hesaba ekler.
##    Her durum değişikliğini NetworkManager.broadcast_korsan_parrot ile (güvenilir RPC) diğer oyunculara bildirir.
##  - KUKLA (remote_player.gd, diğer oyuncuların ekranı): hiçbir karar vermez; gelen olaya göre AYNI hareket/görsel
##    kodu ile hedefe uçar / omza döner / konar ve ayağındaki altın sayısını gösterir (CLAUDE.md "iki ayrı yer" kuralı:
##    formül tek dosyada).
## Altın sahipliği (çok oyunculu): altınlar host'ta gerçek, istemcilerde görsel kopya (bkz. gold_drop.gd). Papağan altını
## aldığı AN: tek oyunculu / host -> NetworkManager.host_take_gold_for_parrot (host'ta "claimed" işareti - iki kişi aynı
## altını alamaz; boss altını her zamanki gibi herkese paylaştırılır, papağan sadece bonusunu getirir); istemci ->
## request_parrot_gold ile host'a sorar, cevap (miktar ya da "başkası aldı") parrot_gold_result ile gelir. Altın hesaba
## papağan omza KONDUĞUNDA eklenir (cevap henüz gelmediyse gelince).
##
## Görsel: assets/characters/korsan_parrot (tools/gen_korsan_parrot.py) - karakterle AYNI sanat pikseli yoğunluğu (sprite
## ölçeği karakterin sprite ölçeğinden kopyalanır). Omuzdayken oyuncunun normal çocuğu (oyuncunun akıcı/interpolasyonlu
## konumunu kendiliğinden izler), uçarken top_level.

const CharAnim := preload("res://scripts/char_anim.gd")
const FRAMES: SpriteFrames = preload("res://assets/characters/korsan_parrot/parrot_frames.tres")
const ANCHOR_OFFSET := Vector2(0.0, -6.0) ## hücrede ayak noktası (24, 30) -> düğüm orijini (bkz. gen_korsan_parrot.py)

## Kullanıcı isteği (aynı gün, ikinci tur): "papağan topladığında değil altını getirdiğinde altın sesi gelsin ve altın başına
## 1 ekstra altın değil gidiş geliş başına 1 bonus altın kazandırsın" - bonus artık TUR başına (taşınan altın sayısından
## bağımsız), ses toplarken değil omza konup teslim ederken (kuklada da, diğer oyuncular duysun).
const TRIP_BONUS := 1
const GOLD_SOUND: AudioStream = preload("res://assets/audio/gold_pickup.mp3")
const GOLD_SOUND_DB := -10.0 ## gold_drop.tscn PickupSound ile aynı

const MAX_CARRY := 3
const SPEED_MULT := 1.2 ## Korsan'ın (etkin) hareket hızının katı
const MIN_SPEED := 120.0
const SCAN_RADIUS := 320.0 ## Korsan'a bu mesafedeki altınlar
const MIN_GOLD_DIST := 64.0 ## bundan yakını Korsan zaten kendisi çekip alır (drop_attraction.gd DEFAULT_PICKUP_RANGE 60)
const NEXT_GOLD_RADIUS := 160.0 ## bir altını aldıktan sonra devam etmek için papağanın çevresi
const LEASH := 560.0 ## Korsan'dan bu kadar uzaklaşırsa geri döner
const SCAN_INTERVAL := 0.25
const GRAB_DIST := 7.0
const LAND_DIST := 7.0

## Omuz noktaları: Korsan'ın 48x48 karesinde (sanat pikseli) yöne göre tünek + papağanın bakışı + karakterin ARKASINDA mı
## (yan görünüşte arka omuzda, başın arkasında kalır).
const PERCH := {
	"down": {"p": Vector2(34, 24), "flip": false, "behind": false},
	"up": {"p": Vector2(32, 24), "flip": false, "behind": false},
	"left": {"p": Vector2(29, 24), "flip": true, "behind": true},
	"right": {"p": Vector2(19, 24), "flip": false, "behind": true},
}

enum State { PERCH, FLY_TO, RETURN }

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false

var state: int = State.PERCH
var _sprite: AnimatedSprite2D = null
var _coins: AnimatedSprite2D = null
var _behind: bool = false
var _flying: bool = false
var _speed: float = 200.0
var _target: Node2D = null ## yerel: hedef altın düğümü
var _target_pos: Vector2 = Vector2.ZERO ## kukla: hedef nokta
var _scan_timer: float = 0.0
## Yerel: taşınan altınlar [{"id": drop id, "amount": int}] - amount PENDING = istemcide host cevabı bekleniyor.
const PENDING := -2
var _carried: Array = []
## Omza konmuş ama host cevabı henüz gelmemiş altınlar (drop id -> tur no) ve bonusu henüz ödenmemiş turlar (tur no -> true;
## turdaki altınların HİÇBİRİ o an onaylı değilse bonus ilk onayla gelir).
var _awaiting: Dictionary = {}
var _bonus_due: Dictionary = {}
var _trip_no: int = 0
var _carry_visual: int = 0


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
	_coins = AnimatedSprite2D.new()
	_coins.sprite_frames = FRAMES
	_coins.animation = &"coins"
	_coins.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_coins.offset = ANCHOR_OFFSET
	_coins.visible = false
	add_child(_coins)
	_sprite.play("perch")
	_sprite.frame = randi() % 4


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	if is_puppet:
		_process_puppet(delta)
	else:
		_process_local(delta)
	_update_visual()


## ---------------------------------------------------------------- yerel (karar veren) taraf

func _process_local(delta: float) -> void:
	_speed = maxf(MIN_SPEED, SPEED_MULT * (float(owner_body.get_effective_move_speed()) if owner_body.has_method("get_effective_move_speed") else 200.0))
	var busy: bool = owner_body.get("is_dead") == true or owner_body.get("is_downed") == true or owner_body.get("is_indoors") == true
	match state:
		State.PERCH:
			_perch_follow()
			if busy:
				return
			_scan_timer -= delta
			if _scan_timer > 0.0:
				return
			_scan_timer = SCAN_INTERVAL
			var g: Node2D = _find_gold(owner_body.global_position, MIN_GOLD_DIST, SCAN_RADIUS)
			if g:
				_take_off()
				_set_target(g)
		State.FLY_TO:
			if busy or global_position.distance_to(owner_body.global_position) > LEASH:
				_start_return()
				return
			if not _is_takeable(_target):
				var next: Node2D = _find_gold(owner_body.global_position, MIN_GOLD_DIST, SCAN_RADIUS)
				if next:
					_set_target(next)
				else:
					_start_return()
				return
			if _fly_toward(_target.global_position, delta, GRAB_DIST):
				_grab(_target)
				_target = null
				var next2: Node2D = null
				if _carried.size() < MAX_CARRY and not busy:
					next2 = _find_gold(global_position, 0.0, NEXT_GOLD_RADIUS, owner_body.global_position)
				if next2:
					_set_target(next2)
				else:
					_start_return()
		State.RETURN:
			if _fly_toward(_shoulder_global(), delta, LAND_DIST):
				_land()
				_deposit()
				_broadcast(State.PERCH, Vector2.ZERO)


## En yakın alınabilir altın. from: arama merkezi, [min_d, max_d]: from'a uzaklık aralığı; leash_center verilirse ayrıca
## Korsan'a SCAN_RADIUS içinde olmalı.
func _find_gold(from: Vector2, min_d: float, max_d: float, leash_center: Variant = null) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var mp: bool = NetworkManager.is_multiplayer_active
	for n in get_tree().get_nodes_in_group("gold_drops"):
		var g := n as Node2D
		if g == null or not _is_takeable(g):
			continue
		## Host gerçek altına, istemci görsel kopyaya bakar (host'ta kopya yok ama yine de süzülür).
		if mp and NetworkManager.is_host and g.get_meta("network_spawned", false):
			continue
		var d: float = from.distance_to(g.global_position)
		if d < min_d or d > max_d:
			continue
		if leash_center != null and (leash_center as Vector2).distance_to(g.global_position) > SCAN_RADIUS:
			continue
		if d < best_d:
			best_d = d
			best = g
	return best


func _is_takeable(g: Variant) -> bool:
	if g == null or not is_instance_valid(g):
		return false
	var n := g as Node2D
	return n != null and n.is_inside_tree() and not n.is_queued_for_deletion() and not n.get_meta("claimed", false) \
		and not n.get_meta("parrot_taken", false)


func _grab(g: Node2D) -> void:
	if not _is_takeable(g):
		return
	g.set_meta("parrot_taken", true)
	var amount: int = 0
	var drop_id: int = int(g.get_meta("drop_network_id", 0))
	## Ses toplarken ÇALMAZ (bkz. TRIP_BONUS notu) - teslimde _play_gold_sound.
	if not NetworkManager.is_multiplayer_active:
		amount = int(g.get("amount"))
		g.queue_free()
	elif NetworkManager.is_host:
		amount = NetworkManager.host_take_gold_for_parrot(g, owner_body) ## düğümü kendisi serbest bırakır
		if amount < 0:
			return ## başkası çoktan aldı
	else:
		if drop_id <= 0:
			return
		NetworkManager.request_parrot_gold.rpc_id(NetworkManager._host_peer_id(), drop_id)
		NetworkManager.discard_visual_drop(drop_id)
		amount = PENDING
		g.queue_free()
	_carried.append({"id": drop_id, "amount": amount})
	_carry_visual = _carried.size()


## Omza konunca: onaylı altınların toplamı + TUR başına 1 bonus. Cevabı gelmemiş olanlar (istemci) cevap gelince eklenir;
## turda o an hiç onaylı altın yoksa bonus da ilk onayla gelir.
func _deposit() -> void:
	if _carried.is_empty():
		return
	_trip_no += 1
	var total: int = 0
	var any_ok: bool = false
	var any_pending: bool = false
	for c: Dictionary in _carried:
		var amt: int = int(c["amount"])
		if amt == PENDING:
			_awaiting[int(c["id"])] = _trip_no
			any_pending = true
		elif amt >= 0:
			total += amt
			any_ok = true
	if any_ok:
		total += TRIP_BONUS
	elif any_pending:
		_bonus_due[_trip_no] = true
	_carried.clear()
	_carry_visual = 0
	_play_gold_sound()
	_credit(total)


func _play_gold_sound() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = GOLD_SOUND
	s.volume_db = GOLD_SOUND_DB
	s.max_distance = 1500.0
	get_tree().current_scene.add_child(s)
	s.global_position = global_position
	s.finished.connect(s.queue_free)
	s.play()


func _credit(total: int) -> void:
	if total <= 0:
		return
	GameManager.gold += total
	if owner_body.has_method("_spawn_floating_text"):
		owner_body._spawn_floating_text("+%d altın" % total, Color(1.0, 0.85, 0.25))


## İstemci: host'un papağan altını cevabı (bkz. NetworkManager.parrot_gold_result). amount < 0 = başkası aldı.
func on_gold_result(drop_id: int, amount: int) -> void:
	for c: Dictionary in _carried:
		if int(c["id"]) == drop_id and int(c["amount"]) == PENDING:
			c["amount"] = amount if amount >= 0 else -1
			if amount < 0:
				_carried.erase(c)
				_carry_visual = _carried.size()
				_broadcast(state, _target.global_position if _is_takeable(_target) else Vector2.ZERO)
			return
	if _awaiting.has(drop_id):
		var trip: int = int(_awaiting[drop_id])
		_awaiting.erase(drop_id)
		if amount >= 0:
			var add: int = amount
			if _bonus_due.has(trip):
				_bonus_due.erase(trip)
				add += TRIP_BONUS
			_credit(add)


func _set_target(g: Node2D) -> void:
	_target = g
	state = State.FLY_TO
	_broadcast(State.FLY_TO, g.global_position)


func _start_return() -> void:
	_target = null
	state = State.RETURN
	_broadcast(State.RETURN, Vector2.ZERO)


func _broadcast(s: int, target: Vector2) -> void:
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_korsan_parrot.rpc(multiplayer.get_unique_id(), s, target, _carried.size(), _speed)


## ---------------------------------------------------------------- kukla (diğer oyuncuların ekranı)

## remote_player.gd -> korsan_parrot_event: sahibinin papağanı durum değiştirdi.
func apply_event(s: int, target: Vector2, carry: int, spd: float) -> void:
	_speed = maxf(MIN_SPEED, spd)
	_carry_visual = clampi(carry, 0, MAX_CARRY)
	match s:
		State.FLY_TO:
			if state == State.PERCH:
				_take_off()
			state = State.FLY_TO
			_target_pos = target
		State.RETURN:
			if state == State.PERCH:
				_take_off()
			state = State.RETURN
		State.PERCH:
			## Konma olayı: uzaktaysa önce uçarak döner, varınca konar (taşıdığı altın varınca teslim sesiyle kaybolur).
			if state != State.PERCH:
				state = State.RETURN


func _process_puppet(delta: float) -> void:
	match state:
		State.PERCH:
			_perch_follow()
		State.FLY_TO:
			_fly_toward(_target_pos, delta, GRAB_DIST) ## varınca bir sonraki olayı bekler (havada süzülür)
		State.RETURN:
			if _fly_toward(_shoulder_global(), delta, LAND_DIST):
				_land()
				if _carry_visual > 0:
					_play_gold_sound() ## sahibinin ekranındaki teslim sesiyle aynı an
				_carry_visual = 0


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
	_coins.flip_h = _sprite.flip_h
	_set_behind(bool(cfg["behind"]))


func _take_off() -> void:
	var gp: Vector2 = global_position
	top_level = true
	global_position = gp
	global_scale = char_anim.global_scale
	_flying = true
	_set_behind(false)
	_sprite.play("fly")


func _land() -> void:
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
		_coins.flip_h = _sprite.flip_h
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


func _update_visual() -> void:
	_coins.visible = _carry_visual > 0
	if _coins.visible:
		_coins.frame = clampi(_carry_visual, 1, MAX_CARRY) - 1
